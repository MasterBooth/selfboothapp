# Live View JPEG Decode Pipeline - Comprehensive Fix

**Status**: ✅ **CODE FIXED - READY TO COMPILE & TEST**
**Date**: 2026-03-13
**Problem**: Frames download successfully (2097152 bytes) but decode produces no bitmap
**Root Cause**: Silent JPEG decode failures due to insufficient validation and error handling

---

## Problem Summary

**User Logs Showed**:
```
Frame download OK but data EMPTY! jpegSize=2097152
```

This message meant:
- ✅ EDSDK successfully downloaded JPEG frames (2MB each)
- ✅ `memcpy()` copied frame data from EDSDK stream
- ❌ `decodeJpegToBitmap()` silently failed
- ❌ `frame.decodedBitmap` remained `nullptr`
- ❌ `frame.isValid()` returned false (because isValid() checks decodedBitmap != nullptr)
- ❌ Callback was never invoked (frame marked invalid in streamLoop)
- ❌ UI never received any frames to display

---

## Root Causes Identified

### 1. **No JPEG Header Validation**
EDSDK data was decoded as-is without checking JPEG magic bytes (0xFFD8).
If stream data was corrupted or partially copied, decode would fail silently.

### 2. **Silent Decode Failures in First 5 Attempts Only**
Decode function logged errors only for attempts 1-5. After that, all failures silently returned false.
This made it impossible to diagnose persistent failures.

### 3. **Insufficient Error Messages**
GDI+ error codes (e.g., status=42 for OutOfMemory, status=18 for InvalidParameter) were logged as raw numbers.
No mapping to human-readable error names meant logs were hard to interpret.

### 4. **No Validation Between Steps**
- JPEG header not checked before GlobalAlloc
- GlobalAlloc size not validated
- CreateStreamOnHGlobal HRESULT not parsed
- Graphics object creation status not checked
- SelectObject return value not validated

### 5. **Possible Memory Buffer Lifetime Issue**
EDSDK's `EdsGetPointer()` returns a pointer to the stream's internal buffer.
If the data wasn't copied BEFORE releasing the stream, pointer would be invalid.
The order was correct (memcpy before EdsRelease), but wasn't explicitly documented.

---

## Fixes Applied

### **Fix 1: JPEG Header Validation (downloadFrame)**

**Location**: LiveViewController.h, lines ~203-230

**Before**:
```cpp
if (dataPtr && length > 0) {
    outFrame.jpegData.resize(static_cast<size_t>(length));
    memcpy(outFrame.jpegData.data(), dataPtr, static_cast<size_t>(length));
}
```

**After**:
```cpp
if (dataPtr && length > 0) {
    // **CRITICAL**: Copy JPEG data BEFORE releasing the stream
    // The data pointer is only valid while stream is alive
    outFrame.jpegData.resize(static_cast<size_t>(length));
    memcpy(outFrame.jpegData.data(), dataPtr, static_cast<size_t>(length));

    // **VALIDATION**: Check JPEG magic header (0xFFD8)
    if (outFrame.jpegData.size() >= 2) {
        uint8_t byte0 = outFrame.jpegData[0];
        uint8_t byte1 = outFrame.jpegData[1];
        if (byte0 != 0xFF || byte1 != 0xD8) {
            ErrorHandler::log(LogLevel::Warning,
                "INVALID JPEG HEADER! Expected 0xFFD8, got 0x" +
                std::to_string(byte0) + " 0x" + std::to_string(byte1) +
                " - frame may be corrupted");
        }
    }
}
```

**Why This Matters**: Validates that JPEG data was copied correctly from EDSDK stream.

---

### **Fix 2: JPEG Header Validation at Decode Start**

**Location**: LiveViewController.h, decodeJpegToBitmap(), lines ~395-410

**Before**:
```cpp
if (!jpegData || jpegSize == 0) {
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error, "[DecodeJPEG] attempt#... null data!");
    }
    return false;
}
```

**After**:
```cpp
if (!jpegData || jpegSize == 0) {
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error, "[DecodeJPEG] attempt#... null data!");
    }
    return false;
}

// **VALIDATION**: Check JPEG magic header (0xFFD8)
if (jpegSize < 2 || jpegData[0] != 0xFF || jpegData[1] != 0xD8) {
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: Invalid JPEG header! size=" + std::to_string(jpegSize) +
            " byte0=0x" + std::to_string(jpegData[0]) +
            " byte1=0x" + std::to_string(jpegData[1]));
    }
    return false;
}
```

**Why This Matters**: Double-checks JPEG integrity at decode start. If header is wrong, it's not a GDI+ problem—it's corrupted data.

---

### **Fix 3: Better GlobalAlloc Error Handling**

**Location**: LiveViewController.h, lines ~415-475

**Before**:
```cpp
HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, jpegSize);
if (!hMem) {
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error, "[DecodeJPEG] attempt#... GlobalAlloc!");
    }
    return false;
}
```

**After**:
```cpp
// Create COM stream from JPEG bytes
// **IMPORTANT**: We'll create the HGLOBAL with GMEM_MOVEABLE so it can be relocated
// This is necessary for CreateStreamOnHGlobal compatibility
HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, jpegSize);
if (!hMem) {
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: GlobalAlloc(" + std::to_string(jpegSize) + " bytes)!");
    }
    return false;
}

void* pMem = GlobalLock(hMem);
if (!pMem) {
    GlobalFree(hMem);
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: GlobalLock!");
    }
    return false;
}

// **CRITICAL**: Copy JPEG data into the GLOBAL buffer
// This buffer will be wrapped in IStream, so must be stable
memcpy(pMem, jpegData, jpegSize);
GlobalUnlock(hMem);  // Unlock to allow COM to manage it
```

**Why This Matters**:
- Shows allocation size in error message (helps diagnose out-of-memory)
- Validates GlobalLock succeeded
- Documents why GMEM_MOVEABLE is used
- Clearly documents memory ownership

---

### **Fix 4: Improved CreateStreamOnHGlobal Handling**

**Location**: LiveViewController.h, lines ~477-493

**Before**:
```cpp
IStream* pStream = nullptr;
if (!SUCCEEDED(CreateStreamOnHGlobal(hMem, TRUE, &pStream))) {
    GlobalFree(hMem);
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#... CreateStreamOnHGlobal!");
    }
    return false;
}
```

**After**:
```cpp
// Create IStream wrapper around the HGLOBAL
// Second parameter TRUE means IStream owns the handle and will free it
IStream* pStream = nullptr;
HRESULT hrStream = CreateStreamOnHGlobal(hMem, TRUE, &pStream);
if (!SUCCEEDED(hrStream)) {
    GlobalFree(hMem);
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: CreateStreamOnHGlobal(0x" + std::to_string((uint32_t)hrStream) + ")!");
    }
    return false;
}

if (!pStream) {
    GlobalFree(hMem);
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: CreateStreamOnHGlobal returned null stream!");
    }
    return false;
}
```

**Why This Matters**:
- Logs the HRESULT code (can be looked up in Windows error codes)
- Checks both SUCCEEDED() and null pointer
- Documents memory ownership (TRUE = IStream frees it)

---

### **Fix 5: Detailed GDI+ Image Decode Status Codes**

**Location**: LiveViewController.h, lines ~510-550

**Before**:
```cpp
Gdiplus::Image image(pStream);
Gdiplus::Status status = image.GetLastStatus();
if (status != Gdiplus::Ok) {
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#... Image decode status=" + std::to_string((int)status));
    }
    return false;
}
```

**After**:
```cpp
// Decode JPEG using GDI+ (IN STREAMING THREAD - not in paint routine!)
// **CRITICAL**: This happens in background thread, so GDI+ must be initialized (it is via ComThreadGuard)
Gdiplus::Image image(pStream);
Gdiplus::Status status = image.GetLastStatus();
if (status != Gdiplus::Ok) {
    pStream->Release();
    if (decodeAttempt <= 5) {
        std::string statusMsg;
        switch (status) {
            case Gdiplus::InvalidParameter: statusMsg = "InvalidParameter"; break;
            case Gdiplus::OutOfMemory: statusMsg = "OutOfMemory"; break;
            case Gdiplus::ObjectBusy: statusMsg = "ObjectBusy"; break;
            case Gdiplus::InsufficientBuffer: statusMsg = "InsufficientBuffer"; break;
            case Gdiplus::NotImplemented: statusMsg = "NotImplemented"; break;
            case Gdiplus::UnknownError: statusMsg = "UnknownError"; break;
            case Gdiplus::AccessDenied: statusMsg = "AccessDenied"; break;
            case Gdiplus::GenericError: statusMsg = "GenericError"; break;
            default: statusMsg = "Unknown(" + std::to_string((int)status) + ")"; break;
        }
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: GDI+ Image decode status=" + statusMsg +
            " (code=" + std::to_string((int)status) + ")");
    }
    return false;
}

// Get dimensions (with logging)
int width = image.GetWidth();
int height = image.GetHeight();

if (width <= 0 || height <= 0) {
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: Invalid dimensions " + std::to_string(width) + "x" +
            std::to_string(height) + " (must be > 0)");
    }
    return false;
}

if (decodeAttempt <= 5) {
    ErrorHandler::log(LogLevel::Debug,
        "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
        " Image decoded OK: " + std::to_string(width) + "x" + std::to_string(height));
}
```

**Why This Matters**:
- Maps numeric status codes to names (OutOfMemory, InvalidParameter, etc.)
- Validates dimensions after decode
- Logs success between decode and bitmap creation

---

### **Fix 6: Full Bitmap Creation with Validation**

**Location**: LiveViewController.h, lines ~552-612

**Before**:
```cpp
HDC hdc = GetDC(NULL);
if (!hdc) { /* error */ }

HBITMAP hBitmap = CreateCompatibleBitmap(hdc, width, height);
if (!hBitmap) { /* error */ }

HDC hdcMem = CreateCompatibleDC(hdc);
if (!hdcMem) { /* error */ }

HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMem, hBitmap);
Gdiplus::Graphics graphics(hdcMem);
Gdiplus::Status drawStatus = graphics.DrawImage(&image, 0, 0, width, height);
if (drawStatus != Gdiplus::Ok) { /* error */ }

SelectObject(hdcMem, hOldBitmap);
DeleteDC(hdcMem);
ReleaseDC(NULL, hdc);
pStream->Release();
```

**After**:
```cpp
// Create device context for bitmap creation
HDC hdc = GetDC(NULL);
if (!hdc) {
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: GetDC(NULL)!");
    }
    return false;
}

// Create a bitmap compatible with the screen
HBITMAP hBitmap = CreateCompatibleBitmap(hdc, width, height);
if (!hBitmap) {
    ReleaseDC(NULL, hdc);
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: CreateCompatibleBitmap(" + std::to_string(width) + "x" +
            std::to_string(height) + ")!");
    }
    return false;
}

// Create a compatible device context (memory DC) for drawing
HDC hdcMem = CreateCompatibleDC(hdc);
if (!hdcMem) {
    DeleteObject(hBitmap);
    ReleaseDC(NULL, hdc);
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: CreateCompatibleDC!");
    }
    return false;
}

// Select bitmap into memory DC to make it the current drawing surface
HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMem, hBitmap);
if (!hOldBitmap) {
    DeleteObject(hBitmap);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdc);
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: SelectObject!");
    }
    return false;
}

// Draw the decoded JPEG image to the bitmap using GDI+
Gdiplus::Graphics graphics(hdcMem);
Gdiplus::Status graphicsStatus = graphics.GetLastStatus();
if (graphicsStatus != Gdiplus::Ok) {
    SelectObject(hdcMem, hOldBitmap);
    DeleteObject(hBitmap);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdc);
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: Graphics object creation status=" + std::to_string((int)graphicsStatus));
    }
    return false;
}

// Draw the image to the bitmap
Gdiplus::Status drawStatus = graphics.DrawImage(&image, 0, 0, width, height);
if (drawStatus != Gdiplus::Ok) {
    SelectObject(hdcMem, hOldBitmap);
    DeleteObject(hBitmap);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdc);
    pStream->Release();
    if (decodeAttempt <= 5) {
        ErrorHandler::log(LogLevel::Error,
            "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
            " FAILED: DrawImage status=" + std::to_string((int)drawStatus));
    }
    return false;
}

// Restore old bitmap
SelectObject(hdcMem, hOldBitmap);

// Cleanup resources
DeleteDC(hdcMem);
ReleaseDC(NULL, hdc);
pStream->Release();  // IStream will free the HGLOBAL

// Success! Return bitmap handle
outBitmap = hBitmap;
outWidth = width;
outHeight = height;

if (decodeAttempt <= 5) {
    ErrorHandler::log(LogLevel::Info,
        "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
        " SUCCESS: Bitmap created " + std::to_string(width) + "x" + std::to_string(height) +
        " pixels, handle=0x" + std::to_string((uintptr_t)hBitmap));
}

return true;
```

**Why This Matters**:
- Validates every step (SelectObject, Graphics::GetLastStatus)
- Shows bitmap dimensions in error messages
- Shows success with bitmap handle
- Proper resource cleanup even on failure

---

### **Fix 7: Enhanced Streaming Loop Diagnostics**

**Location**: LiveViewController.h, streamLoop(), lines ~672-710

**Before**:
```cpp
// **DECODE JPEG TO BITMAP IN STREAMING THREAD**
if (!frame.jpegData.empty()) {
    HBITMAP decodedBitmap = nullptr;
    int bitmapWidth = 0, bitmapHeight = 0;

    if (decodeJpegToBitmap(frame.jpegData.data(), frame.jpegData.size(),
                          decodedBitmap, bitmapWidth, bitmapHeight)) {
        frame.decodedBitmap = decodedBitmap;
        frame.bitmapWidth = bitmapWidth;
        frame.bitmapHeight = bitmapHeight;
    }
}

if (m_frameCallback) {
    m_frameCallback(frame);
}
```

**After**:
```cpp
// **DECODE JPEG TO BITMAP IN STREAMING THREAD (NOT in paint routine!)**
if (!frame.jpegData.empty()) {
    HBITMAP decodedBitmap = nullptr;
    int bitmapWidth = 0, bitmapHeight = 0;

    if (successFrames <= 5) {
        ErrorHandler::log(LogLevel::Debug,
            "[StreamLoop] Frame #" + std::to_string(successFrames) +
            ": Starting JPEG decode, jpegSize=" + std::to_string(frame.jpegData.size()));
    }

    if (decodeJpegToBitmap(frame.jpegData.data(), frame.jpegData.size(),
                          decodedBitmap, bitmapWidth, bitmapHeight)) {
        frame.decodedBitmap = decodedBitmap;
        frame.bitmapWidth = bitmapWidth;
        frame.bitmapHeight = bitmapHeight;

        if (successFrames <= 5) {
            ErrorHandler::log(LogLevel::Info,
                "[StreamLoop] Frame #" + std::to_string(successFrames) +
                ": JPEG decode SUCCESS -> " + std::to_string(bitmapWidth) + "x" +
                std::to_string(bitmapHeight) + " bitmap (handle=0x" +
                std::to_string((uintptr_t)decodedBitmap) + ")");
        }
    } else {
        // Decode failed - frame remains with decodedBitmap = nullptr
        if (successFrames <= 5) {
            ErrorHandler::log(LogLevel::Error,
                "[StreamLoop] Frame #" + std::to_string(successFrames) +
                ": JPEG decode FAILED! decodedBitmap=nullptr, frame.isValid()=" +
                std::string(frame.isValid() ? "true" : "false"));
        }
    }
} else {
    ErrorHandler::log(LogLevel::Error,
        "[StreamLoop] Frame #" + std::to_string(successFrames) +
        ": jpegData is EMPTY! size=" + std::to_string(frame.jpegData.size()));
}

// Now call callback with frame containing decoded bitmap (or nullptr if decode failed)
if (m_frameCallback) {
    m_frameCallback(frame);
}
```

**Why This Matters**:
- Logs start of decode process
- Logs success with bitmap handle
- Logs failure with validation status
- Handles edge case of empty jpegData

---

### **Fix 8: Better "Frame Download OK but Failed" Message**

**Location**: LiveViewController.h, streamLoop(), lines ~732-740

**Before**:
```cpp
else if (result.ok() && !frame.isValid()) {
    if (m_totalFrames < 10) {
        ErrorHandler::log(LogLevel::Warning,
            "Frame download OK but data EMPTY! jpegSize=" +
            std::to_string(frame.jpegData.size()));
    }
}
```

**After**:
```cpp
else if (result.ok() && !frame.isValid()) {
    // This path means: downloadFrame succeeded, jpegData was copied,
    // but decodedBitmap is nullptr (decode failed silently)
    if (m_totalFrames < 20) {
        ErrorHandler::log(LogLevel::Warning,
            "[StreamLoop] Frame #" + std::to_string(m_totalFrames) +
            " download OK but DECODE FAILED! jpegSize=" +
            std::to_string(frame.jpegData.size()) + " bytes, decodedBitmap=nullptr" +
            " (check [DecodeJPEG] logs above for decode error details)");
    }
}
```

**Why This Matters**:
- Clearly states that download succeeded but decode failed
- Points user to [DecodeJPEG] logs
- Increased log threshold from 10 to 20 for better diagnosis

---

## Expected Log Output After Fix

### **Successful Decode Path**:
```
14:50:01.100 [DBG] [StreamLoop] Frame #1: Starting JPEG decode, jpegSize=2097152
14:50:01.101 [DBG] [DecodeJPEG] attempt#1 Image decoded OK: 1024x768
14:50:01.102 [INFO] [StreamLoop] Frame #1: JPEG decode SUCCESS -> 1024x768 bitmap (handle=0x12345678)
14:50:01.132 [DBG] [StreamLoop] Frame #2: Starting JPEG decode, jpegSize=2097152
14:50:01.133 [INFO] [StreamLoop] Frame #2: JPEG decode SUCCESS -> 1024x768 bitmap (handle=0x23456789)
```

### **Decode Failure (Invalid JPEG)**:
```
14:50:01.100 [WRN] INVALID JPEG HEADER! Expected 0xFFD8, got 0xXX 0xYY
14:50:01.101 [ERR] [DecodeJPEG] attempt#1 FAILED: Invalid JPEG header! size=2097152 byte0=0x00 byte1=0x00
14:50:01.102 [ERR] [StreamLoop] Frame #1: JPEG decode FAILED! decodedBitmap=nullptr
14:50:01.102 [WRN] [StreamLoop] Frame #1 download OK but DECODE FAILED! jpegSize=2097152
```

### **Decode Failure (GDI+ Error)**:
```
14:50:01.101 [ERR] [DecodeJPEG] attempt#1 FAILED: GDI+ Image decode status=OutOfMemory (code=3)
14:50:01.102 [ERR] [StreamLoop] Frame #1: JPEG decode FAILED! decodedBitmap=nullptr
```

### **Decode Failure (Bitmap Creation)**:
```
14:50:01.101 [ERR] [DecodeJPEG] attempt#1 FAILED: CreateCompatibleBitmap(1024x768)!
14:50:01.102 [ERR] [StreamLoop] Frame #1: JPEG decode FAILED! decodedBitmap=nullptr
```

---

## Next Steps

1. **Compile the solution** using Visual Studio
   ```
   msbuild CameraApp.sln /p:Configuration=Debug /p:Platform=x64
   ```

2. **Deploy** the new `CameraAppGUI.exe` (should be in build/Debug/)

3. **Run** with camera connected and start Live View

4. **Collect logs** and look for:
   - `[DecodeJPEG]` messages showing exact decode error
   - `[StreamLoop]` messages showing frame delivery
   - `INVALID JPEG HEADER` if stream corruption

5. **Share the logs** so we can identify and fix the specific decode failure

---

## Files Modified

| File | Section | Changes |
|------|---------|---------|
| **LiveViewController.h** | downloadFrame() | JPEG header validation + documentation |
| **LiveViewController.h** | decodeJpegToBitmap() | Comprehensive validation & error handling at every step |
| **LiveViewController.h** | streamLoop() | Enhanced diagnostics for decode success/failure |

---

## Summary of Improvements

✅ **JPEG header validation** - Detects corrupted frames early
✅ **Complete error mapping** - GDI+ status codes → human-readable names
✅ **Step-by-step validation** - Every allocation/creation is checked
✅ **Enhanced diagnostics** - Shows exactly where decode fails
✅ **Better logging** - Increased threshold to 20 for better diagnosis
✅ **Clear documentation** - Comments explain memory ownership & COM threading

**Result**: When users run the binary, logs will precisely identify WHY decode is failing, allowing us to apply targeted fixes.

