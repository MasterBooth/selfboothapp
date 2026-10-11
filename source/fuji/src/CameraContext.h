// CameraContext.h -- the shared, lock-guarded SDK state for one open camera.
//
// CRITICAL DESIGN NOTE
// --------------------
// The FUJIFILM X SDK is NOT thread-safe per handle. The official HotFolder
// sample wraps every SDK call in a single CriticalSection. We reproduce that:
// all workers (poll/download, capture, live-view control, property) share ONE
// recursive_mutex. A call is *never* made to the SDK without holding it.
//
// Because ReadImageInfo/ReadImage/DeleteImage form a 3-call transaction on a
// shared internal cursor, the whole transaction must hold the lock, or a
// concurrent capture()/property call could interleave and corrupt the cursor.
#pragma once

#include "FujiSdkLibrary.h"
#include "ICamera.h"
#include <mutex>

struct CameraContext {
    FujiSdkLibrary*      lib    = nullptr;
    XSDK_HANDLE          handle = nullptr;
    std::recursive_mutex mtx;   // the one true SDK lock (== the CriticalSection)

    using Lock = std::lock_guard<std::recursive_mutex>;

    // Translate the SDK's (apiCode, errCode) pair into our vendor-neutral enum.
    // Call ONLY after an SDK call returned XSDK_ERROR, while still holding mtx.
    CameraError lastError(long* outApi = nullptr, long* outErr = nullptr) {
        long api = 0, err = 0;
        if (lib && lib->GetErrorNumber)
            lib->GetErrorNumber(handle, &api, &err);
        if (outApi) *outApi = api;
        if (outErr) *outErr = err;
        switch (err) {
            case XSDK_ERRCODE_NOERR:              return CameraError::None;
            case XSDK_ERRCODE_BUSY:
            case XSDK_ERRCODE_FORCEMODE_BUSY:
            case XSDK_ERRCODE_RUNNING_OTHER_FUNCTION: return CameraError::Busy;
            case XSDK_ERRCODE_TIMEOUT:
            case XSDK_ERRCODE_AF_TIMEOUT:         return CameraError::Timeout;
            case XSDK_ERRCODE_COMMUNICATION:      return CameraError::Communication;
            case XSDK_ERRCODE_UNSUPPORTED:        return CameraError::Unsupported;
            case XSDK_ERRCODE_SHOOT_ERROR:        return CameraError::ShootError;
            case XSDK_ERRCODE_FRAME_FULL:         return CameraError::FrameFull;
            case XSDK_ERRCODE_CARDFULL:           return CameraError::CardFull;
            case XSDK_ERRCODE_HARDWARE:           return CameraError::Hardware;
            default:                              return CameraError::Unknown;
        }
    }
};
