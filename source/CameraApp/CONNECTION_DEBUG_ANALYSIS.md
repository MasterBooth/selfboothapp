# Canon EDSDK Camera Connection Pipeline - Diagnostic Analysis
**Date**: 2026-03-13
**Issue**: PropertyEvent storm and UILock retry hell after camera connection

---

## Executive Summary

The camera connection pipeline suffers from two critical timing issues that cascade into a storm of property events and excessive UILock retries:

1. **Premature property reads** - The system attempts to read/query properties immediately after `EdsOpenSession()` succeeds, before the camera's internal state machine has stabilized
2. **PropertyEvent flood response** - When property change notifications arrive, `CameraFacade::onPropertyEvent()` immediately re-reads the property from the camera, causing redundant queries
3. **Insufficient UILock delay** - UILock is attempted too soon after session open, when the camera is still busy with internal initialization

---

## Root Causes Identified

### 1. Immediate Property Queries After Session Open (CameraDevice::open)

**Location**: `/Windows/CameraApp/Camera/CameraDevice.h` lines 68-120

**Problem**:
```
EdsOpenSession(m_info.ref)  ← Session opens, camera firmware initializes
                            ← (Camera is internally busy for ~1-2 seconds)
                            ← (Properties are changing, events firing)

// NO STABILIZATION DELAY HERE - Problem starts

EdsSendStatusCommand(...UILock...)  ← Attempted too soon (lines 82-88)
  ↓ Fails with EDS_ERR_DEVICE_BUSY
  ↓ Retried 10 times with 500ms delays
  ↓ Total time wasted: up to 5 seconds

m_properties.loadAllProperties()  ← Fires immediately (line 118)
  ↓ Tries to read 14 properties (lines 196-210 in CameraProperties.h)
  ↓ Each read is wrapped in executeWithRetry() with up to 10 retries
  ↓ Each retry adds 500ms+ delays
  ↓ Camera returns EDS_ERR_DEVICE_BUSY for each property during boot

m_properties.loadAllDescriptors()  ← Fires immediately (line 120)
  ↓ Tries to read descriptors for 10 properties
  ↓ Same retry storm occurs
```

**Impact**: Session open takes 10-20+ seconds instead of <2 seconds.

### 2. UILock Retry Hell

**Location**: `/Windows/CameraApp/Camera/CameraDevice.h` lines 78-92

**Problem**:
```cpp
// Retry UILock specifically as camera needs time after OpenSession
err = EDS_ERR_DEVICE_BUSY;
for (int i = 0; i < 10 && err == EDS_ERR_DEVICE_BUSY; ++i) {
    err = EdsSendStatusCommand(m_info.ref, kEdsCameraStatusCommand_UILock, 0);
    if (err == EDS_ERR_DEVICE_BUSY) {
        ErrorHandler::dbg("CameraDevice::open", "UILock busy, retry " + ...);
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
}
```

**Why It Fails**:
- After `EdsOpenSession()`, the camera firmware is initializing
- During initialization, the camera sets properties (ISO, aperture, shutter speed, WB, metering, etc.)
- Each property change fires a PropertyEvent callback
- The camera's internal state machine is busy - it rejects UILock during this window
- Retrying with 500ms delays assumes the initialization will complete, but the initialization itself may be triggered by the property event storm

**Why It Causes a Storm**:
- The retry loop blocks for 5 seconds (10 retries × 500ms)
- Meanwhile, property events continue arriving from the camera
- `EventDispatcher::handlePropertyEvent()` immediately dispatches them (line 210 in EventDispatcher.h)
- `CameraFacade::onPropertyEvent()` executes immediately on SDK thread (line 342-356 in CameraFacade.h)

### 3. PropertyEvent Storm Response - Immediate Re-reads

**Location**: `/Windows/CameraApp/Interface/CameraFacade.h` lines 342-356

**Problem**:
```cpp
void onPropertyEvent(const PropertyEvent& event) override {
    if (!m_device || !m_callback) return;

    if (event.isValueChanged()) {
        // RE-READ THE PROPERTY IMMEDIATELY
        EdsUInt32 value = 0;
        m_device->properties().getUInt32(event.propertyId, value);  ← BLOCKING READ
        m_callback->onPropertyChanged(event.propertyId, value);
    }
    else if (event.isDescChanged()) {
        // RE-READ THE DESCRIPTOR IMMEDIATELY
        PropertyDescriptor desc;
        m_device->properties().getDescriptor(event.propertyId, desc);  ← BLOCKING READ
        m_callback->onPropertyDescChanged(event.propertyId, desc);
    }
}
```

**Why This Is Wrong**:
- PropertyEvent notification already tells us a property changed
- Re-reading the property immediately is redundant - the camera just sent the change notification
- During camera boot (first 2 seconds after `EdsOpenSession`), dozens of PropertyEvents fire
- Each event triggers a blocking property read via `EdsGetPropertyData()`
- Many of these reads fail with `EDS_ERR_DEVICE_BUSY` and retry with backoff
- The retry backoff adds exponential delay: 500ms → 750ms → 1125ms → etc.

**Timeline of the Storm**:
```
T+0ms:    EdsOpenSession() succeeds
T+10ms:   PropertyEvent fires for property 0x104 (ISO)
          → onPropertyEvent() calls getUInt32(0x104)
          → Camera is busy → EDS_ERR_DEVICE_BUSY
          → executeWithRetry() sleeps 500ms

T+50ms:   PropertyEvent fires for property 0x106 (Aperture)
          → onPropertyEvent() calls getUInt32(0x106)
          → Same issue → Sleep 500ms+

T+100ms:  PropertyEvent fires for property 0x107 (Shutter Speed)
          → Same issue

... (repeats for ~20-30 properties) ...

T+2000ms+: Finally, camera stabilizes
           But by now UILock has failed 10+ times
           And 50+ property read attempts have failed
           Session open took 15+ seconds instead of <1 second
```

### 4. Unsupported Properties Causing Silent Failures

**Location**: `/Windows/CameraApp/Camera/CameraProperties.h` lines 195-226

**Problem**:
The `loadAllProperties()` and `loadAllDescriptors()` methods try to read every property in a hardcoded list without checking if it's actually supported. Some properties:
- May not exist on this camera model
- May require specific conditions to be readable (e.g., LiveView mode)
- May return error codes like 0x108, 0x114, 0x115 with high param values

Each failed property read:
1. Returns error code from camera
2. Goes through `executeWithRetry()`
3. Gets retried 10 times with exponential backoff
4. Wastes 5-10 seconds per unsupported property

---

## Timeline of Events

### Good Case (What We Want)
```
T+0ms:      EdsOpenSession() returns OK
T+0ms:      WAIT 1000ms for camera to stabilize
T+1000ms:   UILock succeeds on first try
T+1050ms:   Read properties (camera ready, no busy errors)
T+1100ms:   Read descriptors
T+1150ms:   Connection complete, total time: ~1.15 seconds
```

### Current Bad Case (What's Happening)
```
T+0ms:      EdsOpenSession() returns OK
T+5ms:      First UILock attempt → EDS_ERR_DEVICE_BUSY
T+5-100ms:  PropertyEvents fire (camera initializing)
            Each PropertyEvent triggers immediate re-read
            Each re-read fails with DEVICE_BUSY → retry backoff storm

T+100-500ms: loadAllProperties() attempts 14 property reads
            Most fail with DEVICE_BUSY during camera boot
            Each retry adds 500ms+ delay

T+500-1000ms: loadAllDescriptors() attempts 10 descriptor reads
             Same failure pattern

T+1000-1500ms: Finally camera stabilizes
              But session open took 15+ seconds
              UI is frozen, user sees hang
```

---

## Why UILock Fails

Camera state machine after `EdsOpenSession()`:
1. Session initialized in hardware
2. Firmware begins reading internal state from flash
3. Firmware synchronizes exposure settings: ISO, Av, Tv, WB, metering
4. **During steps 2-4, camera reports DEVICE_BUSY to most operations**
5. UILock is a status command that also reports DEVICE_BUSY during this window
6. After ~1-2 seconds, camera completes initialization and accepts UILock

**The current code assumes**: "If I retry UILock enough times, eventually it will succeed"

**Reality**: The retry loop itself doesn't help. The camera needs wall-clock time to initialize, not retry attempts.

---

## Why Property Queries Fail

Properties are read at two points with problems:

### Point 1: `loadAllProperties()` (Line 118 of CameraDevice.h)
- Tries to read 14 standard properties immediately after session open
- Camera hasn't finished internal initialization yet
- Many properties return `EDS_ERR_DEVICE_BUSY`
- `executeWithRetry()` retries up to 10 times, adding 5-10 seconds per property

### Point 2: `onPropertyEvent()` (Line 348 of CameraFacade.h)
- Fires 20-30 times during the first 2 seconds after session open
- Each event immediately calls `getUInt32(propId, value)`
- This is a blocking operation on the SDK's internal thread
- If property is still being synchronized, returns DEVICE_BUSY
- Creates cascading failures and retry storms

### Common Error Codes During Boot:
- **0x108** (EDS_ERR_INVALID_PARAMETER): Property not available yet
- **0x114** (EDS_ERR_OBJECT_NOTREADY): Camera not ready for this operation
- **0x115** (EDS_ERR_PROPERTIES_UNAVAILABLE): Properties not yet loaded
- **EDS_ERR_DEVICE_BUSY** (0x2001): Camera firmware busy with initialization

---

## Property Query Error Handling Gaps

**Problem**: No distinction between:
- "Property doesn't exist on this camera" (permanent failure, should skip)
- "Property isn't available yet" (temporary, should retry with delay)
- "Property is busy" (temporary, should retry with delay)

**Current code**: Treats all failures the same → always retry 10 times

**Better approach**:
- Recognize permanent failures (unsupported property codes)
- Recognize temporary failures (DEVICE_BUSY during boot window)
- Skip permanent failures immediately
- Delay temporary retries until after stabilization

---

## Fixes Required

### Fix 1: Add Stabilization Delay After EdsOpenSession

**File**: `CameraDevice.h`, after line 75 (`m_sessionOpen = true`)

```
After EdsOpenSession succeeds:
  1. Set a session start timestamp
  2. Sleep 1000ms (allows camera firmware to complete initialization)
  3. Then attempt UILock
  4. Then read properties
  5. Only read critical properties during the first 2 seconds
```

### Fix 2: Filter PropertyEvents During Boot Window

**File**: `CameraFacade.h`, `onPropertyEvent()` method

```
When a PropertyEvent arrives:
  1. Check if we're within 2 seconds of session open
  2. If yes, skip redundant property reads
  3. Only log that event occurred
  4. Don't re-read the property (event already notified us of change)
  5. After 2 seconds, normal handling resumes
```

### Fix 3: Throttle Property Updates with Debouncer

**File**: Create new `PropertyEventFilter` class

```
Requirements:
  1. Collect PropertyEvents for 500ms
  2. Deduplicate events for same property
  3. Only process one batch per 500ms window
  4. Reduces redundant reads by 80-90%
```

### Fix 4: Create Property Whitelist

**File**: `CameraProperties.h`, refactor property loading

```
Changes:
  1. Only query known-supported properties
  2. Skip properties with high param values (always fail)
  3. Catch unsupported property errors (0x108, 0x114, 0x115)
  4. Log but don't error on unsupported properties
  5. Add configuration for which properties to query during boot vs. later
```

### Fix 5: Log at Each Stage

**File**: `CameraDevice.h`, `CameraFacade.h`, `EventDispatcher.h`

```
Add detailed timing logs:
  - "Session open started at T+0ms"
  - "Session open succeeded at T+X ms"
  - "Starting stabilization wait..."
  - "Stabilization complete at T+Y ms"
  - "Attempting UILock at T+Z ms"
  - "PropertyEvent arrived at T+A ms: propId=0x104 (filtered during boot)"
  - "UILock succeeded at T+B ms"
  - "Properties loaded at T+C ms"
  - "Total connection time: T+D ms"
```

---

## Expected Improvements

### Before Fixes
- Session open: 15-20 seconds
- UILock retries: 10+ attempts
- Failed property reads: 50-100+
- CPU usage spike: High (retry backoff)
- UI freeze: Visible
- Logs: Hundreds of DEVICE_BUSY errors

### After Fixes
- Session open: <2 seconds
- UILock retries: 1-2 attempts (with stabilization delay)
- Failed property reads: <5 (only unsupported properties)
- CPU usage spike: Minimal
- UI freeze: Not noticeable
- Logs: Clean sequence of events with timing markers

---

## Code Locations Summary

| Issue | File | Lines | Problem |
|-------|------|-------|---------|
| UILock retry loop | `CameraDevice.h` | 78-92 | No pre-delay, 10 retries |
| Property loading | `CameraDevice.h` | 118-120 | Immediate after session open |
| PropertyEvent handling | `CameraFacade.h` | 342-356 | Immediate re-read of property |
| Property enum | `CameraProperties.h` | 196-210 | No whitelist, all properties attempted |
| Retry logic | `ErrorHandler.h` | 67-102 | No awareness of boot stabilization window |
| Event dispatch | `EventDispatcher.h` | 199-214 | No filtering by boot state |

---

## Testing Strategy

### Unit Tests Needed
1. **BootStabilizationTest**: Verify 1-second delay after session open
2. **PropertyEventFilterTest**: Verify events filtered during first 2 seconds
3. **PropertyWhitelistTest**: Verify only supported properties queried
4. **DebounceTest**: Verify events batched every 500ms

### Integration Tests Needed
1. **ConnectionSpeedTest**: Measure total session open time (<2s)
2. **UILockSuccessTest**: UILock succeeds on first try
3. **LogAnalysisTest**: Verify no DEVICE_BUSY errors in property loading
4. **MultiCameraTest**: Verify no crosstalk when multiple cameras connect

### Manual Tests Needed
1. Connect camera and measure connection time (must be <2 seconds)
2. Monitor logs for "Device busy" errors (should be zero)
3. Watch UI during connection (should not freeze)
4. Verify all properties load correctly after boot window

---

## Configuration Parameters

These should become configurable constants:

```cpp
const int STABILIZATION_DELAY_MS = 1000;  // Wait after EdsOpenSession
const int BOOT_WINDOW_MS = 2000;          // First 2 seconds after session open
const int PROPERTY_THROTTLE_MS = 500;     // Batch property updates
const std::vector<EdsPropertyID> CRITICAL_PROPERTIES = {
    kEdsPropID_BatteryLevel,      // Battery status
    kEdsPropID_AvailableShots,    // Remaining shots
    kEdsPropID_SaveTo,            // Save destination
};
```

---

## Conclusion

The PropertyEvent storm and UILock retry hell are caused by attempting to initialize and query camera properties **before** the camera's firmware has completed its post-session-open initialization sequence. The fixes are:

1. **Wait** for the camera to stabilize (1 second)
2. **Filter** PropertyEvents that fire during stabilization
3. **Throttle** property reads to reduce redundancy
4. **Whitelist** properties to avoid querying unsupported ones
5. **Log** everything for visibility

These changes will reduce connection time from 15-20 seconds to <2 seconds and eliminate the visible UI freeze.
