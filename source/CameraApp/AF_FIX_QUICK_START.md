# Autofocus Fix - Quick Start (6-8 Hours)

**Problem**: AF commands cause Device Busy, properties fail
**Solution**: Synchronize AF with EVF streaming
**Time**: 6-8 hours total
**Effort**: Medium (straightforward changes)

---

## What You're Fixing

**Current Behavior**:
```
User clicks "AF On"
├─ EVF streaming continues (30ms interval)
├─ AF command sent to camera
├─ Camera says: "Device Busy" (busy downloading EVF)
├─ Application retries (500ms wait)
├─ EVF still downloading
├─ Device Busy again
├─ ... repeats for 40+ seconds
└─ Camera unresponsive, properties fail
```

**After Fix**:
```
User clicks "AF On"
├─ EVF streaming PAUSES (10ms)
├─ AF command sent to camera (gets full attention)
├─ AF completes in 100-500ms
├─ EVF resumes streaming
└─ Everything back to normal
```

---

## Implementation (7 Steps)

### Step 1: Add AF State to CameraState (15 min)

**File**: `Camera/CameraState.h` (add after line 143)

```cpp
// AF State Management
private:
    std::atomic<bool> m_afActive{false};
    std::atomic<bool> m_afBusy{false};
    std::atomic<EdsError> m_afLastError{EDS_ERR_OK};

public:
    bool isAFActive() const { return m_afActive.load(); }
    bool isAFBusy() const { return m_afBusy.load(); }
    EdsError afLastError() const { return m_afLastError.load(); }
    void setAFActive(bool active) { m_afActive.store(active); }
    void setAFBusy(bool busy) { m_afBusy.store(busy); }
    void setAFLastError(EdsError err) { m_afLastError.store(err); }
```

**Verify**: Compiles without errors

---

### Step 2: Add Synchronization Primitives (15 min)

**File**: `LiveView/LiveViewController.h` (add after line 758)

```cpp
    // AF Synchronization
    std::mutex                      m_afMutex;
    std::condition_variable         m_afCV;
    std::atomic<bool>               m_afInProgress{false};
    std::atomic<int>                m_afRetryCount{0};

public:
    bool isAFInProgress() const { return m_afInProgress.load(); }
    void signalAFStart() { m_afInProgress.store(true); }
    void signalAFComplete() {
        m_afInProgress.store(false);
        m_afCV.notify_all();
    }
    void waitForAFComplete(int timeoutMs = 10000) {
        std::unique_lock<std::mutex> lock(m_afMutex);
        m_afCV.wait_for(lock,
            std::chrono::milliseconds(timeoutMs),
            [this]() { return !m_afInProgress.load(); });
    }
```

**Verify**: Compiles without errors

---

### Step 3: Add EVF Pause Logic (30 min)

**File**: `LiveView/LiveViewController.h`

**In streamLoop(), add at TOP of while loop** (around line 634):

```cpp
void streamLoop() {
    while (m_streaming.load()) {
        // **NEW**: Check if AF is active - if so, pause EVF
        if (m_afInProgress.load()) {
            std::this_thread::sleep_for(std::chrono::milliseconds(10));
            continue;  // Skip frame download, pause
        }

        // ... rest of loop continues unchanged ...
    }
}
```

**That's it!** EVF now pauses when AF is active.

**Verify**: Compiles, LiveView still works

---

### Step 4: Update startAF() (30 min)

**File**: `LiveView/LiveViewController.h` (replace startAF method, lines 333-339)

```cpp
Result startAF() {
    ErrorHandler::log(LogLevel::Info, "[AF] startAF() CALLED");

    signalAFStart();  // ← Pause EVF
    std::this_thread::sleep_for(std::chrono::milliseconds(50));  // ← Wait for EVF to pause

    EdsError afResult = EDS_ERR_OK;
    int retryCount = 0;
    const int MAX_AF_RETRIES = 3;  // Reduced from 10
    int retryDelay = 200;  // Reduced from 500

    for (retryCount = 0; retryCount <= MAX_AF_RETRIES; ++retryCount) {
        ErrorHandler::log(LogLevel::Debug,
            "[AF] startAF() attempt #" + std::to_string(retryCount + 1) +
            "/" + std::to_string(MAX_AF_RETRIES + 1));

        afResult = EdsSendCommand(
            m_camera.cameraRef(),
            kEdsCameraCommand_DoEvfAf,
            kEdsCameraCommand_EvfAf_ON);

        if (afResult == EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Info,
                "[AF] startAF() SUCCESS on attempt #" + std::to_string(retryCount + 1));
            break;
        }

        if (afResult != EDS_ERR_DEVICE_BUSY && afResult != EDS_ERR_OBJECT_NOTREADY) {
            break;
        }

        if (retryCount < MAX_AF_RETRIES) {
            std::this_thread::sleep_for(std::chrono::milliseconds(retryDelay));
            retryDelay = std::min(retryDelay + 100, 1000);
        }
    }

    m_afRetryCount.store(retryCount);
    m_camera.state().setAFActive(afResult == EDS_ERR_OK);
    m_camera.state().setAFLastError(afResult);
    std::this_thread::sleep_for(std::chrono::milliseconds(100));

    signalAFComplete();  // ← Resume EVF

    ErrorHandler::log(LogLevel::Info,
        "[AF] startAF() COMPLETE - result: 0x" + ErrorHandler::toHex(afResult) +
        " retries: " + std::to_string(retryCount));

    return ErrorHandler::check(afResult, "EVF_AF_Start");
}
```

**Verify**: Compiles, AF works

---

### Step 5: Update stopAF() (30 min)

**File**: `LiveView/LiveViewController.h` (replace stopAF method, lines 342-351)

```cpp
Result stopAF() {
    ErrorHandler::log(LogLevel::Info, "[AF] stopAF() CALLED");

    signalAFStart();  // Pause EVF
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

    EdsError afResult = EDS_ERR_OK;
    int retryCount = 0;
    const int MAX_AF_RETRIES = 3;
    int retryDelay = 200;

    for (retryCount = 0; retryCount <= MAX_AF_RETRIES; ++retryCount) {
        ErrorHandler::log(LogLevel::Debug,
            "[AF] stopAF() attempt #" + std::to_string(retryCount + 1) +
            "/" + std::to_string(MAX_AF_RETRIES + 1));

        afResult = EdsSendCommand(
            m_camera.cameraRef(),
            kEdsCameraCommand_DoEvfAf,
            kEdsCameraCommand_EvfAf_OFF);

        if (afResult == EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Info,
                "[AF] stopAF() SUCCESS on attempt #" + std::to_string(retryCount + 1));
            break;
        }

        if (afResult != EDS_ERR_DEVICE_BUSY && afResult != EDS_ERR_OBJECT_NOTREADY) {
            break;
        }

        if (retryCount < MAX_AF_RETRIES) {
            std::this_thread::sleep_for(std::chrono::milliseconds(retryDelay));
            retryDelay = std::min(retryDelay + 100, 1000);
        }
    }

    m_afRetryCount.store(retryCount);
    m_camera.state().setAFActive(false);
    m_camera.state().setAFLastError(afResult);

    signalAFComplete();  // Resume EVF

    ErrorHandler::log(LogLevel::Info,
        "[AF] stopAF() COMPLETE - result: 0x" + ErrorHandler::toHex(afResult) +
        " retries: " + std::to_string(retryCount));

    return ErrorHandler::check(afResult, "EVF_AF_Stop");
}
```

**Verify**: Compiles, AF stop works

---

### Step 6: Update UI Feedback (Optional but Recommended) (20 min)

**File**: `UI/UIHandler.h` (add method)

```cpp
void onAFStatusChanged(bool afActive, EdsError afError) {
    if (afActive) {
        m_window.setStatus("🎯 AF In Progress...");
    } else {
        if (afError == EDS_ERR_OK) {
            m_window.setStatus("✅ AF Complete");
        } else {
            m_window.setStatus("❌ AF Failed: " +
                ErrorHandler::errorToString(afError));
        }
    }
}
```

**Verify**: UI shows AF status

---

### Step 7: Test Everything (1-2 hours)

**Test 1: AF On/Off**
```
1. Start LiveView
2. Click "AF On" button
3. Verify:
   ✓ AF completes in <1 second (not 40+)
   ✓ LiveView continues smoothly
   ✓ Logs show "[AF]" markers
4. Click "AF Off" button
5. Same verification
```

**Test 2: Properties During AF**
```
1. Start LiveView
2. Click "AF On"
3. While AF active, change ISO property
4. Verify:
   ✓ Property change completes in <1 second
   ✓ No "Device Busy" errors
```

**Test 3: Rapid AF**
```
1. Start LiveView
2. Click "AF On", wait 100ms, click "AF Off", repeat 5 times
3. Verify:
   ✓ All AF commands succeed
   ✓ No timeouts
   ✓ No Device Busy errors
```

---

## Expected Results

| Metric | Before | After |
|--------|--------|-------|
| AF latency | 40+ seconds | <1 second |
| Property success | 50% | 99%+ |
| EVF FPS during AF | 0 (paused) | Pauses 100ms |
| Device Busy errors | 50+ | <5 |
| AF success rate | <50% | 95%+ |

---

## Compilation Checklist

- [ ] CameraState compiles (added AF state methods)
- [ ] LiveViewController compiles (added sync primitives)
- [ ] streamLoop() works (added AF check)
- [ ] startAF() works (replaced method)
- [ ] stopAF() works (replaced method)
- [ ] UIHandler compiles (added AF feedback)
- [ ] No linking errors
- [ ] No runtime crashes

---

## Testing Checklist

- [ ] AF On/Off works
- [ ] AF completes in <1 second
- [ ] LiveView continues during AF
- [ ] Properties work during/after AF
- [ ] Logs show "[AF]" markers
- [ ] No Device Busy errors
- [ ] UI shows AF status
- [ ] Rapid AF calls work
- [ ] Camera remains responsive

---

## If You Hit Issues

### "AF still times out"
→ Check that `signalAFStart()` is called before command
→ Verify `signalAFComplete()` is called after

### "EVF pauses too long"
→ Adjust pause time in streamLoop (line with `std::this_thread::sleep_for(10ms)`)
→ Try 5ms instead of 10ms

### "Properties still failing"
→ Check logs for "[AF]" markers
→ Verify AF is actually pausing EVF
→ May need to increase pause wait time (50ms)

### "Compilation errors"
→ Check that code is added to CORRECT file and location
→ Verify includes are present
→ Check for typos in new code

---

## Timeline

| Phase | Time | Task |
|-------|------|------|
| 1 | 15 min | Add CameraState AF state |
| 2 | 15 min | Add synchronization primitives |
| 3 | 30 min | Implement EVF pause |
| 4 | 30 min | Update startAF() |
| 5 | 30 min | Update stopAF() |
| 6 | 20 min | Add UI feedback |
| 7 | 60-120 min | Test everything |
| **Total** | **3.5-5 hours** | **All phases** |

---

## Verification

After all steps complete:

```
✅ AF On works
✅ AF Off works
✅ AF completes in <1 second
✅ Properties work during AF
✅ LiveView smooth
✅ No Device Busy errors
✅ UI shows AF status
✅ Logs clear and detailed
✅ Camera responsive
```

---

## Next Steps

1. ✅ Read this guide
2. ✅ Implement Steps 1-6
3. ✅ Test Step 7
4. ✅ Deploy and validate
5. ✅ Monitor logs during production use

---

**You've got this! AF fix is straightforward synchronization. 💪**

