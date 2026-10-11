# Quick Start: Device Busy Fix Implementation

**Time to fix**: 2-4 weeks
**Complexity**: Medium
**Priority**: CRITICAL (blocks camera reliability)

---

## What to Do Now

### Step 1: Copy CommandQueue.h
- File already created: `Core/CommandQueue.h`
- Add to Visual Studio project under Core/ folder
- Add to CMakeLists.txt if using CMake

### Step 2: Add Include to CameraFacade
**File**: `Interface/CameraFacade.h` (at top)

```cpp
#include "../Core/CommandQueue.h"
```

### Step 3: Add CommandQueue Member
**File**: `Interface/CameraFacade.h` (in class definition)

```cpp
class CameraFacade {
    // ... existing members ...

    CommandQueue m_commandQueue;  // ← Add this line

public:
    // ... existing methods ...

    // Constructor - initialize queue
    CameraFacade() {
        m_commandQueue.start();  // Start executor thread
    }

    // Destructor - shutdown queue
    ~CameraFacade() {
        m_commandQueue.stop();   // Stop executor thread
    }

    CommandQueue& commandQueue() { return m_commandQueue; }
};
```

### Step 4: Wire Up to Sub-Controllers
**File**: `Interface/CameraFacade.h` (in constructor)

```cpp
CameraFacade::CameraFacade() {
    m_commandQueue.start();

    // After creating sub-controllers:
    m_device->setCommandQueue(&m_commandQueue);
    m_capture->setCommandQueue(&m_commandQueue);
    m_liveView->setCommandQueue(&m_commandQueue);
}
```

### Step 5: Add Accessor Methods to Controllers

**File**: `Camera/CameraDevice.h`

```cpp
class CameraDevice {
    // ... existing members ...

    CommandQueue* m_commandQueue = nullptr;  // ← Add

public:
    void setCommandQueue(CommandQueue* q) { m_commandQueue = q; }  // ← Add
};
```

**File**: `Capture/CaptureController.h`

```cpp
class CaptureController {
    CommandQueue* m_commandQueue = nullptr;  // ← Add

public:
    void setCommandQueue(CommandQueue* q) { m_commandQueue = q; }  // ← Add
};
```

**File**: `LiveView/LiveViewController.h`

```cpp
class LiveViewController {
    CommandQueue* m_commandQueue = nullptr;  // ← Add

public:
    void setCommandQueue(CommandQueue* q) { m_commandQueue = q; }  // ← Add
};
```

### Step 6: Start with One Operation

Pick the simplest operation to migrate first. Example: **Property Get**

**File**: `Camera/CameraProperties.h`

Find this method (around line 30):
```cpp
Result getUInt32(EdsPropertyID propId, EdsUInt32& outValue) {
    return ErrorHandler::executeWithRetry("GetProperty",
        [&]() -> EdsError {
            return EdsGetPropertyData(m_camera.cameraRef(), propId,
                                     0, sizeof(outValue), &outValue);
        });
}
```

Replace with:
```cpp
Result getUInt32(EdsPropertyID propId, EdsUInt32& outValue) {
    if (!m_commandQueue) {
        // Fallback if queue not initialized (during testing)
        return ErrorHandler::executeWithRetry("GetProperty",
            [&]() -> EdsError {
                return EdsGetPropertyData(m_camera.cameraRef(), propId,
                                         0, sizeof(outValue), &outValue);
            });
    }

    EdsError result = EDS_ERR_OK;
    std::promise<EdsError> promise;
    auto future = promise.get_future();

    m_commandQueue->enqueue(
        CommandType::PropertyGet,
        CommandPriority::LOW,
        "GetProperty(0x" + ErrorHandler::toHex((uint32_t)propId) + ")",
        [&]() -> EdsError {
            return EdsGetPropertyData(m_camera.cameraRef(), propId,
                                     0, sizeof(outValue), &outValue);
        },
        [&](EdsError err) {
            result = err;
            promise.set_value(err);
        });

    future.wait();
    return ErrorHandler::check(result, "GetProperty");
}
```

### Step 7: Test One Operation

Create simple test:
```cpp
void testPropertyRead() {
    Camera camera;
    camera.connect();

    EdsUInt32 iso = 0;
    auto result = camera.properties().getUInt32(
        kEdsPropID_ISOSpeed, iso);

    ASSERT_TRUE(result.ok());
    ASSERT_GT(iso, 0);
    cout << "ISO: " << iso << endl;
}
```

Run and verify:
- ✅ Property reads work
- ✅ No crashes
- ✅ No Device Busy errors
- ✅ Logs show queue execution

### Step 8: Migrate Property Set

**File**: `Camera/CameraProperties.h` (around line 120)

Same pattern as getUInt32, but use:
- `CommandType::PropertySet`
- `CommandPriority::NORMAL`
- `EdsSetPropertyData()` instead of EdsGetPropertyData

### Step 9: Migrate UILock

**File**: `Camera/CameraDevice.h`

Find UILock code (around line 93):
```cpp
err = EDS_ERR_DEVICE_BUSY;
for (int i = 0; i < 10 && err == EDS_ERR_DEVICE_BUSY; ++i) {
    err = EdsSendStatusCommand(m_info.ref,
                              kEdsCameraStatusCommand_UILock, 0);
    if (err == EDS_ERR_DEVICE_BUSY) {
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
    }
}
```

Replace with:
```cpp
EdsError err = EDS_ERR_OK;
std::promise<EdsError> promise;
auto future = promise.get_future();

m_commandQueue->enqueue(
    CommandType::UILock,
    CommandPriority::CRITICAL,
    "UILock",
    [&]() -> EdsError {
        return EdsSendStatusCommand(m_info.ref,
                                    kEdsCameraStatusCommand_UILock, 0);
    },
    [&](EdsError error) {
        err = error;
        promise.set_value(error);
    });

future.wait();

if (err != EDS_ERR_OK) {
    ErrorHandler::log(LogLevel::Error,
        "UILock failed: 0x" + ErrorHandler::toHex(err));
    return false;
}
```

### Step 10: Migrate EVF Download

**File**: `LiveView/LiveViewController.h` (around line 187)

Find:
```cpp
auto result = ErrorHandler::executeWithRetry("DownloadEvfImage",
    [&]() -> EdsError {
        return EdsDownloadEvfImage(m_camera.cameraRef(), evfImage);
    });
```

Replace with:
```cpp
EdsError result = EDS_ERR_OK;
std::promise<EdsError> promise;
auto future = promise.get_future();

m_commandQueue->enqueue(
    CommandType::EVFDownload,
    CommandPriority::LOW,
    "EVFDownload(frame #" + std::to_string(m_totalFrames) + ")",
    [&]() -> EdsError {
        return EdsDownloadEvfImage(m_camera.cameraRef(), evfImage);
    },
    [&](EdsError err) {
        result = err;
        promise.set_value(err);
    });

future.wait();

if (!ErrorHandler::check(result, "EdsDownloadEvfImage").ok()) {
    return result;
}
```

---

## Testing as You Go

After each operation migrated, test immediately:

```cpp
void quickTest() {
    Camera camera;

    // Test 1: Property read
    EdsUInt32 iso = 0;
    ASSERT_TRUE(camera.properties().getUInt32(
        kEdsPropID_ISOSpeed, iso).ok());
    cout << "✓ Property read OK" << endl;

    // Test 2: Property write
    ASSERT_TRUE(camera.properties().setUInt32(
        kEdsPropID_ISOSpeed, 400).ok());
    cout << "✓ Property write OK" << endl;

    // Test 3: Connect and take picture
    ASSERT_TRUE(camera.connect().ok());
    ASSERT_TRUE(camera.takePicture().ok());
    cout << "✓ Capture OK" << endl;

    // Test 4: No Device Busy errors
    auto stats = camera.commandQueue().getStats();
    ASSERT_EQ(stats.totalFailed, 0) << "No operations should fail";
    cout << "✓ Zero Device Busy errors" << endl;
}
```

---

## Compilation Fixes

If you get compilation errors:

### Error: "CommandQueue undeclared"
**Fix**: Add include
```cpp
#include "../Core/CommandQueue.h"
```

### Error: "CommandType undefined"
**Fix**: Make sure CommandQueue.h is included (defines CommandType enum)

### Error: "promise not found"
**Fix**: Add include
```cpp
#include <promise>  // or #include <future>
```

### Error: "toHex not found"
**Fix**: Use ErrorHandler::toHex()
```cpp
ErrorHandler::toHex((uint32_t)value)
```

---

## Debugging

### Check Queue Stats
```cpp
auto stats = facade.commandQueue().getStats();
cout << "Total enqueued: " << stats.totalEnqueued << endl;
cout << "Total executed: " << stats.totalExecuted << endl;
cout << "Total failed: " << stats.totalFailed << endl;
cout << "Avg queue wait: " << stats.avgQueueWaitMs << "ms" << endl;
cout << "Avg exec time: " << stats.avgExecTimeMs << "ms" << endl;
```

### Check Queue Depth
```cpp
cout << "Queue depth: " << facade.commandQueue().depth() << " items" << endl;
```

### Monitor Logs
Look for `[CommandQueue::exec]` messages:
```
[CommandQueue::exec] [GetProperty(0x0001)] priority=3 attempt=1 queue_wait=2ms exec_time=8ms => OK
[CommandQueue::exec] [SetProperty(...)] priority=2 attempt=1 queue_wait=5ms exec_time=12ms => OK
[CommandQueue::exec] [EVFDownload(...)] priority=3 attempt=1 queue_wait=1ms exec_time=35ms => OK
```

---

## Common Mistakes to Avoid

### ❌ Mistake 1: Forgetting to Wait
```cpp
// WRONG - doesn't wait for execution
m_commandQueue->enqueue(...);
return getValueThatWasJustSet();  // Value might not be set yet!
```

**Fix**:
```cpp
// RIGHT - wait before returning
m_commandQueue->enqueue(...);
future.wait();  // Block until done
return result;  // Now safe
```

### ❌ Mistake 2: Capturing Wrong Variables
```cpp
// WRONG - variable goes out of scope
EdsUInt32 value = 0;
m_commandQueue->enqueue(..., [&]() { /* value */ });
// value destroyed before callback runs!
```

**Fix**:
```cpp
// RIGHT - capture by value or keep alive
std::shared_ptr<int> value = std::make_shared<int>(0);
m_commandQueue->enqueue(..., [value]() { /* value */ });
// or
int value = 0;
m_commandQueue->enqueue(..., [value]() { /* value */ });
```

### ❌ Mistake 3: Using Wrong Priority
```cpp
// WRONG - capture command blocked by property polling
m_commandQueue->enqueue(CommandType::Capture, Priority::LOW, ...);
// Live view + polling might delay capture for seconds!
```

**Fix**:
```cpp
// RIGHT - capture is critical
m_commandQueue->enqueue(CommandType::Capture, Priority::CRITICAL, ...);
```

---

## Success Indicators

✅ **All Operations Migrated**
- [ ] CameraProperties (get/set)
- [ ] UILock, SetCapacity, SetSaveTarget
- [ ] EdsSendCommand (capture, AF)
- [ ] EdsDownloadEvfImage
- [ ] Descriptors and metadata

✅ **Zero Device Busy Errors**
- [ ] Boot completes without errors
- [ ] Property changes succeed immediately
- [ ] Captures don't fail due to Device Busy
- [ ] LiveView doesn't interfere with operations

✅ **Performance Improvements**
- [ ] Boot time <2 seconds (was 45s)
- [ ] Property change <1 second (was 5-40s)
- [ ] Queue depth <5 items under normal load
- [ ] No operation blocks others >500ms

---

## Next: What to Do After Quick Start

1. **Migrate remaining operations** (all files listed in integration guide)
2. **Test concurrency** (multiple operations simultaneously)
3. **Boot optimization** (load only critical properties)
4. **Hardware testing** (Canon EOS R100)
5. **Performance tuning** (adjust delays if needed)

---

## Timeline

| Day | Task |
|-----|------|
| 1 | Steps 1-5 (setup CommandQueue) |
| 2-3 | Steps 6-10 (migrate key operations) |
| 4-5 | Test and fix issues |
| 6-7 | Migrate remaining operations |
| 8 | Full integration testing |
| 9-10 | Hardware validation |

---

## Troubleshooting

**Q**: Queue keeps growing, never drains?
**A**: Check that commands are completing. Look for `[CommandQueue::exec]` logs. If missing, queue isn't running - verify `start()` was called.

**Q**: Operations take longer than before?
**A**: 50ms inter-command delay is minimal. If ops take >1 second, check for Device Busy retries in logs.

**Q**: Getting "Device Busy" still?
**A**: May not have migrated all operations. Check all EdsSetPropertyData/EdsGetPropertyData/EdsSendCommand calls.

**Q**: Crashes or memory errors?
**A**: Check variable capture in lambdas. Use `std::make_shared` or value capture, not reference capture.

---

## Getting Help

**Check logs**:
```
[CommandQueue::exec] - Shows queue execution timing
[SDK] - Shows SDK call details
[ERR] - Shows any errors
```

**Enable debug logging**:
```cpp
// Add to main_gui.cpp
ErrorHandler::setLogLevel(LogLevel::Debug);
```

**Run single test**:
```cpp
testPropertyRead();  // Verify just one operation
testConcurrent();    // Verify concurrent ops don't race
testLiveViewCapture(); // Verify LV doesn't block capture
```

---

## You've Got This!

This fix is critical for reliability. The CommandQueue pattern is proven in professional camera software. Once implemented, your application will be rock-solid.

**Start with Steps 1-5 today. Test Step 6. Then migrate the rest incrementally.**

Good luck! 🚀

