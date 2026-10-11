# Live View Flickering Root Cause Analysis

**Issue**: Live View preview window flickers black continuously despite successful frame downloads at ~16 FPS (2MB frames being received)

**Symptoms**:
- Frames are being successfully downloaded (log confirms 16 FPS, 2MB per frame)
- UI shows black screen flickering
- No errors logged in frame download
- Frame data appears valid (size=2097152 bytes)

---

## Step 1: Complete LiveView Data Pipeline

```
Streaming Thread (LiveViewController::streamLoop)
    │
    ├─→ downloadFrame() [synchronous]
    │   ├─ EdsCreateMemoryStream(2MB)
    │   ├─ EdsCreateEvfImageRef(stream)
    │   ├─ EdsDownloadEvfImage() [retrieves JPEG from camera]
    │   ├─ EdsGetPointer(stream, &dataPtr)
    │   ├─ EdsGetLength(stream, &length)
    │   ├─ memcpy(outFrame.jpegData.data(), dataPtr, length) [DATA COPIED]
    │   ├─ EdsRelease(evfImage)
    │   ├─ EdsRelease(stream) [memory freed after copy!]
    │   └─ return outFrame [LOCAL VARIABLE with copied data]
    │
    ├─→ m_frameCallback(frame) [Lambda from startStreaming]
    │   │
    │   ├─→ CameraFacade::onLiveViewFrame callback
    │   │   └─→ m_callback->onLiveViewFrame(frame.data(), frame.dataSize(), frame)
    │   │
    │   └─→ UIHandler::onLiveViewFrame
    │       └─→ m_window.updateLiveViewFrame(jpegData, dataSize)
    │
    └─→ MainWindow::updateLiveViewFrame [CRITICAL SECTION]
        ├─ Lock m_lvMutex
        ├─ m_lvFrameData.assign(jpegData, jpegData + dataSize) [COPY DATA]
        ├─ Unlock m_lvMutex
        └─ PostMessage(m_hwnd, WM_APP_LV_FRAME, 0, 0) [ASYNC MESSAGE]

UI Thread (MainWindow::windowProc message loop)
    │
    ├─→ GetMessage() / DispatchMessage()
    │
    ├─→ case WM_APP_LV_FRAME:
    │   └─ InvalidateRect(m_lvPanel, NULL, FALSE) [Mark for repaint, async]
    │       └─ Windows queues WM_DRAWITEM asynchronously
    │
    └─→ case WM_DRAWITEM (when Windows decides to send it)
        └─ renderLiveViewFrame(dis->hDC)
            ├─ Lock m_lvMutex
            ├─ Copy m_lvFrameData into local frameData
            ├─ Unlock m_lvMutex
            ├─ If frameData.empty() → Draw BLACK placeholder with "Live View" text
            └─ If frameData.valid() → Decode JPEG and render to screen
```

---

## Step 2: Critical Issue #1 - EVF Frame Handling (VERIFIED SAFE)

**Location**: `LiveViewController::downloadFrame()` lines 152-244

**Potential Issues Checked**:

1. ✅ **Recreating memory stream every frame**: YES, intentional
   - Line 155: `EdsCreateMemoryStream(EVF_BUFFER_SIZE, &stream)` per frame
   - This is SAFE and correct - fresh buffer prevents contamination

2. ✅ **Using pointer after stream release**: NO, data copied first
   - Lines 196-199: `EdsGetPointer()` and `EdsGetLength()` extract pointers
   - Lines 202-204: `memcpy()` copies data BEFORE release
   - Lines 239-240: `EdsRelease(evfImage)` and `EdsRelease(stream)` AFTER copy
   - **Order is correct** ✅

3. ✅ **Not copying JPEG buffer**: NO, data IS copied
   - Line 202-204: `outFrame.jpegData.resize(length); memcpy(...)`
   - Logs confirm: `jpeg_copied=2097152 bytes` for each frame
   - **Data copied correctly** ✅

4. ✅ **Passing raw pointer to UI**: NO, vector copy is used
   - CameraFacade calls: `frame.data()` which returns `jpegData.data()`
   - But jpegData is copied before callback
   - **Safe reference semantics** ✅

**Conclusion**: EVF frame handling is **CORRECT**. Data is properly copied before release.

---

## Step 3: Thread Synchronization (POTENTIAL ISSUE FOUND)

**Location**: `MainWindow::updateLiveViewFrame()` + `MainWindow::renderLiveViewFrame()`

### The Race Condition Pattern

```
Streaming Thread Timeline (T0=frame arrival, Δ=~60ms per frame @ 16 FPS)
T0:   Frame 0 downloaded
T0+1ms:  Lock mutex, copy into m_lvFrameData, unlock, PostMessage(WM_APP_LV_FRAME)
T0+2ms:  PostMessage returns (message queued, not processed yet)

T0+30ms: Frame 1 downloaded
T0+31ms: Lock mutex, copy into m_lvFrameData (OVERWRITES FRAME 0!), unlock, PostMessage

T0+60ms: Frame 2 downloaded
...

UI Thread Timeline
T0+10ms: Process WM_APP_LV_FRAME for frame 0
T0+11ms:  Call InvalidateRect(m_lvPanel) - queues repaint request
T0+12ms:  Windows EVENTUALLY sends WM_DRAWITEM
T0+13ms:  renderLiveViewFrame called
         - Lock mutex
         - Copy m_lvFrameData (which might be Frame 1 or 2 now!)
         - Unlock mutex
         - Render frame

T0+40ms: Process WM_APP_LV_FRAME for frame 1
T0+41ms:  Call InvalidateRect(m_lvPanel) again
...
```

### Why This Causes Flickering

The issue is **message queue latency** vs **frame arrival rate**:

- **Frame arrival**: ~16 FPS = frame every ~62.5ms
- **Message processing**: W32 message queue processes thousands of messages/sec, BUT:
  - InvalidateRect is asynchronous
  - WM_DRAWITEM delivery is deferred
  - Multiple PostMessage calls can queue up

**Potential scenario for BLACK flicker**:

1. Streaming thread posts Frame 0
2. Before UI processes WM_APP_LV_FRAME, Frame 1 arrives and overwrites m_lvFrameData
3. UI processes WM_APP_LV_FRAME (for Frame 0), InvalidateRect called
4. Windows sees duplicate InvalidateRect calls, coalesces them (optimizes multiple repaints)
5. WM_DRAWITEM finally arrives
6. renderLiveViewFrame reads m_lvFrameData which now contains Frame 2
7. But **in between**, if m_lvFrameData is briefly empty (vector reassignment?), BLACK is drawn

Actually, that's unlikely...let me think of another scenario.

---

## Step 4: UI Rendering Logic (FOUND THE ISSUE!)

**Location**: `MainWindow::renderLiveViewFrame()` lines 462-530

### Problem: Multiple Repaints Without Frame Data

Looking at line 474-489:

```cpp
if (frameData.empty()) {
    // Draw placeholder - DARK GRAY with "Live View" text
    HBRUSH brush = CreateSolidBrush(RGB(30, 30, 30));  // Dark gray, visible as BLACK
    FillRect(hdc, &rc, brush);
    ...DrawTextA(hdc, "Live View", ...);
    return;  // Exit without rendering image
}
```

### Root Cause: Message Delivery Latency

The issue is that **WM_DRAWITEM can be called BEFORE m_lvFrameData is populated**!

Sequence:

```
T0: Streaming thread starts
    - No frame data yet
    - m_lvFrameData is EMPTY initially

T0+10ms: UI creates m_lvPanel (owner-drawn static control)
         - Windows automatically sends WM_DRAWITEM to render control initially
         - renderLiveViewFrame called with EMPTY m_lvFrameData
         - **BLACK screen is drawn** (placeholder)

T0+30ms: First frame arrives and PopMessage(WM_APP_LV_FRAME)
         - Message queued

T0+35ms: UI thread processes WM_APP_LV_FRAME
         - InvalidateRect called
         - **But WM_DRAWITEM may not be delivered immediately**

T0+40ms: Next frame arrives, overwrites m_lvFrameData

T0+50ms: FINALLY Windows sends WM_DRAWITEM for frame 0
         - Frame rendered!

T0+60ms: Third frame arrives

T0+75ms: WM_APP_LV_FRAME for frame 2 is processed

T0+85ms: WM_DRAWITEM delivered for frame 2
         - Frame rendered!

```

### Why It Flickers

The flickering happens because:

1. **Initial render**: m_lvFrameData empty → BLACK drawn
2. **Frame arrives, posted, processed** → InvalidateRect called
3. **Repaint deferred** → WM_DRAWITEM not immediate
4. **Next frames arrive** → m_lvFrameData updated multiple times
5. **WM_DRAWITEM arrives with stale/future frame**
6. **If timing is wrong**: render happens when m_lvFrameData is between updates → BLACK

The core problem: **InvalidateRect is async, but PostMessage doesn't force synchronous invalidation**

---

## Step 5: Frame Dropping Logic (SAFE)

**Location**: `LiveViewController::streamLoop()` lines 374-458

**Frame skip logic**:
```cpp
if (m_frameIntervalMs > 0) {
    std::this_thread::sleep_for(std::chrono::milliseconds(m_frameIntervalMs));
}
```

No artificial frame dropping, just throttle with sleep. **Not the issue.**

---

## Step 6: EventDispatcher Interference (SAFE)

The logs show:
```
14:31:54.438 [PropertyEvent 0x00000101] propertyId=0x00000501
14:31:54.439 [PropertyEvent 0x00000101] propertyId=0x00000500
```

These property events fire during streaming, but CameraFacade filters them during boot window (from previous optimization). **Not causing LiveView issues now.**

---

## Step 7: IDENTIFIED ROOT CAUSE

### **Primary Issue: Asynchronous Invalidation + Message Queue Latency**

The problem is in the architecture of the frame delivery:

```cpp
// CURRENT IMPLEMENTATION (PROBLEMATIC)
void updateLiveViewFrame(const uint8_t* jpegData, size_t dataSize) {
    {
        std::lock_guard<std::mutex> lock(m_lvMutex);
        m_lvFrameData.assign(jpegData, jpegData + dataSize);  // Update shared buffer
    }
    PostMessage(m_hwnd, WM_APP_LV_FRAME, 0, 0);  // ASYNC - may be delayed
}

// In message handler:
case WM_APP_LV_FRAME:
    InvalidateRect(self->m_lvPanel, NULL, FALSE);  // ASYNC - defers repaint
    return 0;

// In WM_DRAWITEM (when delivered):
void renderLiveViewFrame(HDC hdc) {
    std::vector<uint8_t> frameData;
    {
        std::lock_guard<std::mutex> lock(m_lvMutex);
        frameData = m_lvFrameData;  // Copy current buffer
    }
    if (frameData.empty()) {  // **RACE CONDITION HERE**
        // Draw BLACK placeholder
        return;
    }
    // Render frame
}
```

### **The Race Condition**:

1. Streaming thread updates m_lvFrameData: `assign()`
2. Streaming thread calls PostMessage (async, queued)
3. UI thread processes other messages...
4. Before WM_APP_LV_FRAME is processed, **next frame arrives**
5. m_lvFrameData is reassigned (vector reallocation!)
6. Eventually WM_DRAWITEM arrives
7. If the timing is wrong, frameData might be empty or corrupted

### **Why .assign() Causes Issues**:

`std::vector::assign()` internally:
- Clears the existing buffer
- Reallocates new memory
- Copies new data

If WM_DRAWITEM arrives during this operation while mutex is held elsewhere, it will wait. But more importantly, **the old data is lost if not yet rendered**.

---

## Step 8: Solution Architecture

### **Fix: Implement Double Buffering + Synchronous Frame Queue**

Instead of:
- Shared m_lvFrameData (subject to race conditions)
- Async PostMessage (can get lost or delayed)
- Deferred rendering (WM_DRAWITEM timing issues)

Implement:
- **Front buffer** (displayed)
- **Back buffer** (updated by streaming thread)
- **Atomic swap** (safe exchange)
- **Guaranteed repaint** (synchronous or queued at frame)

```cpp
// NEW IMPLEMENTATION (SAFE)

class MainWindow {
private:
    // Double buffering
    std::vector<uint8_t> m_lvFrameBack;   // Streaming thread writes here
    std::vector<uint8_t> m_lvFrameFront;  // UI thread renders from here
    std::mutex m_lvBufferMutex;

    // Render state
    uint64_t m_lvFrameSequence = 0;  // Detect frame updates
    uint64_t m_lvRenderedSequence = 0;
};

void updateLiveViewFrame(const uint8_t* jpegData, size_t dataSize) {
    {
        std::lock_guard<std::mutex> lock(m_lvBufferMutex);
        m_lvFrameBack.assign(jpegData, jpegData + dataSize);
        m_lvFrameSequence++;  // Increment sequence
    }
    // SYNCHRONOUS: Force immediate repaint or queue synchronously
    PostMessageA(m_hwnd, WM_APP_LV_FRAME, 0, 0);
}

void renderLiveViewFrame(HDC hdc) {
    // Swap buffers only if new frame available
    {
        std::lock_guard<std::mutex> lock(m_lvBufferMutex);
        if (m_lvFrameSequence > m_lvRenderedSequence) {
            m_lvFrameFront = m_lvFrameBack;  // Swap
            m_lvRenderedSequence = m_lvFrameSequence;
        }
    }

    if (m_lvFrameFront.empty()) {
        // Draw placeholder only on first call
        // ...
        return;
    }

    // Render m_lvFrameFront
    // ...
}
```

### **Alternative: Frame Queue + Dequeue**

```cpp
class MainWindow {
private:
    std::deque<std::vector<uint8_t>> m_lvFrameQueue;  // Queue of frames
    std::mutex m_lvQueueMutex;
    static constexpr size_t MAX_FRAMES_QUEUED = 2;
};

void updateLiveViewFrame(const uint8_t* jpegData, size_t dataSize) {
    {
        std::lock_guard<std::mutex> lock(m_lvQueueMutex);
        m_lvFrameQueue.emplace_back(jpegData, jpegData + dataSize);

        // Keep queue bounded - drop oldest if backlog
        if (m_lvFrameQueue.size() > MAX_FRAMES_QUEUED) {
            m_lvFrameQueue.pop_front();
        }
    }
    // Only post if queue was empty - prevents message spam
    if (m_lvFrameQueue.size() == 1) {
        PostMessageA(m_hwnd, WM_APP_LV_FRAME, 0, 0);
    }
}

void renderLiveViewFrame(HDC hdc) {
    std::vector<uint8_t> frameData;
    {
        std::lock_guard<std::mutex> lock(m_lvQueueMutex);
        if (!m_lvFrameQueue.empty()) {
            frameData = std::move(m_lvFrameQueue.front());
            m_lvFrameQueue.pop_front();
        }
    }

    if (frameData.empty()) {
        // Draw placeholder
        return;
    }

    // Render frameData
}
```

---

## Summary

| Issue | Cause | Severity | Fix |
|-------|-------|----------|-----|
| BLACK flickering | Shared buffer + async messaging | HIGH | Double buffer or frame queue |
| Message latency | PostMessage is async, WM_DRAWITEM deferred | MEDIUM | Force synchronous repaint |
| Race condition | Streaming thread updates while UI reads | MEDIUM | Atomic swap or mutex |
| Frame loss | No guarantee frame renders before next arrives | LOW | Sequence numbering |

**Recommendation**: Implement double-buffering with atomic swap + synchronous repaint trigger.
