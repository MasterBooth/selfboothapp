# Canon EDSDK Camera Control - Debug Logging Enhancement Summary

**Date:** 2026-03-13
**Status:** ✅ BUILD SUCCESSFUL
**Executables:**
- `build/Debug/CameraApp.exe` (Console)
- `build/Debug/CameraAppGUI.exe` (GUI with Live View)

---

## Overview

Comprehensive debug logging has been added to all critical control flows in the Canon EDSDK camera control application. This logging system provides detailed diagnostics at every step of:

1. **Live View (EVF) Initialization and Streaming**
2. **Photo Capture Workflow**
3. **Image Download/Transfer**
4. **SDK Event Handling**

The logging output includes:
- **Timestamps** (HH:MM:SS.mmm format)
- **Log Levels** [DBG], [INF], [WRN], [ERR]
- **Function Context** with parameter details
- **SDK Error Codes** (hex format with human-readable descriptions)
- **Frame Statistics** (count, size, delivery rate)
- **Threading Information** (which thread processed events)

---

## Enhanced Files

### 1. **LiveView/LiveViewController.h**

#### `start()` Method
Logs each step of EVF initialization:
```
========== LiveViewController::start() CALLED ==========
PRE-STATE: isEvfActive=N cameraRef=0x... sessionOpen=Y
[EVF Step 1] Setting Evf_Mode property to 1
SUCCESS - Evf_Mode=1
[EVF Step 2] Setting output device: current=0x... -> adding PC bit
SUCCESS - OutputDevice=0x...
========== LiveView STARTED SUCCESSFULLY ==========
```

**Logs:**
- Pre-condition validation (session open?)
- Each property set operation with success/failure
- Output device value changes
- Final success/failure status

#### `downloadFrame()` Method
Logs each frame download attempt:
```
Frame #0: dataPtr=0x... stream_len=XXXX bytes jpeg_copied=YYYY bytes
Frame #100: size=2048 bytes (periodic updates)
```

**Logs:**
- Stream creation (success/failure)
- EVF image reference creation
- JPEG data extracted (pointer, stream length, copied size)
- Failures with error codes and descriptions

#### `streamLoop()` Method
Continuous frame streaming statistics:
```
LiveView streaming loop started on thread 0x... interval=30ms
FIRST FRAME SUCCESS! frame#=0 size=2048000 bytes duration=150ms
Delivered 50 frames (total_received=150) avg_fps=33.3 last_frame_ms=30
...
LiveView streaming STOPPED. Stats: total_frames_received=500 successful_delivered=480 runtime=15s avg_fps=32.0
```

**Logs:**
- Thread ID and configuration
- First successful frame delivery (critical milestone)
- Periodic frame statistics (every 50 frames)
- Frame download errors with retry counts
- Final streaming session statistics

### 2. **Capture/CaptureController.h**

#### `takePicture()` Method
Detailed shutter command flow:
```
========== CaptureController::takePicture() START ==========
PRE-STATE: autoDownload=Y cameraRef=0x...
[Capture Step 1] Sending PressShutterButton COMPLETELY (with AF)
SUCCESS - Shutter pressed completely
[Capture Step 2] Releasing shutter (ShutterButton OFF)
SUCCESS - Shutter released. NOW WAITING FOR TRANSFER CALLBACK FROM CAMERA...
```

**Logs:**
- Auto-download state
- Each shutter command sent
- Success/failure of each step
- Error codes if commands fail

#### `onTransferRequest()` Method
Image transfer initiation (CRITICAL for capture):
```
========== CaptureController::onTransferRequest() FIRED ==========
objectRef=0x... autoDownload=Y
Starting file download from camera...
Download COMPLETE: IMG_001.CR3 size=45000000 bytes saved_to=/path/to/image/IMG_001.CR3
```

**Logs:**
- **THIS IS WHERE CAPTURE SUCCESS IS VERIFIED** - if this callback doesn't fire, capture failed
- Object reference received from camera
- Auto-download state
- Download success/failure with full file path

### 3. **Capture/FileDownloader.h**

#### `download()` Method
Step-by-step file transfer:
```
========== FileDownloader::download() START ==========
dirItem=0x... saveDir='/path/to/image/'
FILE INFO: name='IMG_001.CR3' size=45000000 bytes
Will save to: '/path/to/image/IMG_001.CR3'
[Download Step 1] Creating file stream...
SUCCESS - file stream created
[Download Step 2] Downloading 45000000 bytes...
SUCCESS - file downloaded to local stream
[Download Step 3] Signaling download complete to camera...
SUCCESS - camera notified
========== Download COMPLETE: /path/to/image/IMG_001.CR3 ==========
```

**Logs:**
- Save directory verification
- File name and size from camera
- Each SDK operation (create stream, download, complete)
- Success/failure with error codes

### 4. **Event/EventDispatcher.h**

#### Callback Handlers
Real-time event logging:
```
Event được trigger: ObjectEvent 0x XXXXXXXX ref=0x... [TRANSFER_REQUEST] Thread đang xử lý event: 0x...
Calling transfer handler for ref=0x...
Event được trigger: PropertyEvent 0x XXXXXXXX propId=0x... param=123 Thread đang xử lý event: 0x...
Event được trigger: StateEvent 0x XXXXXXXX data=0x... [SHUTDOWN] Thread đang xử lý event: 0x...
```

**Logs:**
- All SDK callback events with event codes
- Event type identification
- Thread ID (identifies which SDK thread fired the event)
- Object/property references

---

## Log Output Destinations

Logs are written to **three** places simultaneously:

1. **`app.log` file** (in working directory)
   - Persistent record for debugging sessions
   - Survives application crashes
   - Human-readable format with timestamps

2. **Console/Terminal** (via `printf()`)
   - Real-time monitoring
   - Visible during execution
   - Essential for live debugging

3. **Debug Output** (via `OutputDebugStringA()`)
   - Windows debugger integration
   - Visible in Visual Studio Output pane
   - IDE-aware formatting

---

## How to Use This Logging

### Running CameraAppGUI with Logging

```bash
cd "path/to/CameraApp/build/Debug"
CameraAppGUI.exe
```

A **console window** will appear alongside the GUI showing real-time logs.

### Monitoring Live View Issues

1. Start `CameraAppGUI.exe`
2. Connect camera
3. Click "Start LV"
4. **Watch the console for:**
   - `========== LiveViewController::start() CALLED ==========`
   - `[EVF Step 1]` and `[EVF Step 2]` progress
   - `FIRST FRAME SUCCESS!` message (critical)
   - Frame delivery statistics

**If Live View fails:**
- Check for `FAILED at Evf_Mode:` or `FAILED at Evf_OutputDevice:` messages
- Verify session is open (log should show `sessionOpen=Y`)
- Look for error codes like `0xFFFFxxxx` and their descriptions

### Monitoring Capture Issues

1. With Live View active (or not), click "Take Picture"
2. **Watch the console for:**
   - `========== CaptureController::takePicture() START ==========`
   - `[Capture Step 1]` and `[Capture Step 2]` progress
   - `========== CaptureController::onTransferRequest() FIRED ==========` (CRITICAL)

**If capture fails:**
- Look for error messages in `takePicture()` - usually indicates camera won't accept commands
- **Most Common Issue:** `onTransferRequest()` never fires = transfer callback not registered
- Check `FileDownloader::download()` logs for file save failures

### Analyzing Frame Delivery

The `streamLoop()` logs show:
- **First successful frame:** Verifies EVF is actually producing data
- **Periodic stats:** Shows FPS and delivery success rate
- **Consecutive errors:** If errors exceed a threshold, application backs off

Expected output (working system):
```
LiveView streaming loop started on thread 0x... interval=30ms
FIRST FRAME SUCCESS! frame#=0 size=2000000 bytes duration=150ms
Delivered 50 frames (total_received=150) avg_fps=33.3
...
LiveView streaming STOPPED. Stats: total_frames_received=500 successful_delivered=480 runtime=15s avg_fps=32.0
```

---

## Error Code Legend

Common EDSDK error codes in hex format:

| Code | Meaning |
|------|---------|
| `0x00000000` | OK |
| `0x00000008` | DEVICE_BUSY (camera busy, will retry) |
| `0x00000022` | OBJECT_NOTREADY (frame not ready, will retry) |
| `0x00000001` | SESSION_NOT_OPEN (session wasn't established) |
| `0x00000002` | SESSION_ALREADY_OPEN (only one session allowed) |
| `0xFFFF0000` | COMM_DISCONNECTED (camera unplugged) |
| Other | See `ErrorHandler::errorToString()` in ErrorHandler.h |

---

## Critical Debug Points

### Live View Initialization Sequence

```
start() called
  ├─ Check: sessionOpen=Y, isEvfActive=N
  ├─ [Step 1] SetPropertyData(Evf_Mode=1)
  ├─ [Step 2] SetPropertyData(Evf_OutputDevice |= PC)
  └─ SUCCESS → startStreaming() can be called
```

If either step fails with an error code, Live View will not work.

### Capture Sequence

```
takePicture() called
  ├─ [Step 1] EdsSendCommand(PressShutterButton_Completely)
  ├─ [Step 2] EdsSendCommand(PressShutterButton_Off)
  └─ [Critical] Waiting for onTransferRequest() callback...
      └─ [If fired] FileDownloader::download() starts
          └─ SUCCESS → file saved to disk
      └─ [If NOT fired] Capture failed (transfer callback never came)
```

**Key:** If you see Step 1 and 2 succeed but `onTransferRequest()` never logs, the camera isn't sending the transfer request. This usually indicates:
1. Camera lens cap is on (AF fails, no capture)
2. Camera is in wrong mode (not in capture mode)
3. Memory card issue
4. Camera settings don't allow capture

---

## Performance Metrics from Logs

The logging provides several key metrics:

### Frame Delivery Rate
```
avg_fps = successful_frames / runtime_seconds
```
- **Expected:** 30+ FPS for 30ms interval
- **Below 20 FPS:** Frame download taking too long
- **0 FPS:** EVF frames not being retrieved

### Frame Size
```
JPEG data in stream: XXXX bytes
```
- **Expected:** 1.5-2.5 MB for typical EVF JPEG at 720p
- **Very small:** Stream not capturing full data
- **Constant 0:** EVF not producing data

### Latency
```
duration=XXXms
```
- **Expected:** 25-35ms per frame (includes retry overhead)
- **Consistently >50ms:** Camera or USB bandwidth issue
- **Varies wildly:** Inconsistent camera responsiveness

---

## Build Information

- **Compiler:** MSVC 19.50 (Visual Studio 2026)
- **Architecture:** x64
- **Configuration:** Debug (with full logging, no optimizations)
- **DLLs Required:** EDSDK.dll, EdsImage.dll (copied to build directory)
- **Image Save Path:** `./image/` (relative to executable)

---

## Next Steps for Debugging

1. **Run CameraAppGUI.exe** with camera connected
2. **Observe console logs** as you test each feature
3. **Identify where logs stop** - that's where the failure occurs
4. **Cross-reference error codes** with the legend above
5. **Check `app.log` file** for complete history if app crashes

If Live View shows black screen but logs show successful frame delivery:
- Issue is in frame rendering (MainWindow::renderLiveViewFrame)
- JPEG data is being retrieved but not displayed

If Capture logs show successful Steps 1-2 but transfer never fires:
- Issue is in camera state or command execution
- Camera may not be in capture-ready state

---

## Files Modified

- ✅ `LiveView/LiveViewController.h` - Enhanced frame download and streaming logs
- ✅ `Capture/CaptureController.h` - Enhanced capture command and transfer logging
- ✅ `Capture/FileDownloader.h` - Enhanced download step-by-step logging
- ✅ `Event/EventDispatcher.h` - Already had comprehensive callback logging
- ℹ️ `Core/ErrorHandler.h` - Uses existing logging infrastructure

---

**Happy Debugging!** 🎥
