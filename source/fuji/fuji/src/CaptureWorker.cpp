#include "CaptureWorker.h"
#include "Logger.h"
#include "MediaRecordPolicy.h"
#include "SdkGuard.h"

#include <chrono>
#include <thread>

static const char* TAG = "Capture";

namespace {

bool isBusyStopError(long sdkErr) {
    return sdkErr == XSDK_ERRCODE_BUSY
        || sdkErr == XSDK_ERRCODE_FORCEMODE_BUSY
        || sdkErr == XSDK_ERRCODE_RUNNING_OTHER_FUNCTION;
}

bool shouldFallbackRelease(CameraError err) {
    return err == CameraError::Busy
        || err == CameraError::Unsupported
        || err == CameraError::ShootError;
}

const char* captureModeLabel(bool focusBeforeRelease) {
    return focusBeforeRelease ? "AF" : "NO_AF";
}

long captureReleaseMode(bool focusBeforeRelease) {
    return focusBeforeRelease
        ? XSDK_RELEASE_EX_S1_ON_S2_ON_S2_OFF_S1_OFF
        : XSDK_RELEASE_EX_S2_ON_S2_OFF_S1_OFF;
}

} // namespace

void CaptureWorker::setStillOptions(long imageSize, long imageQuality) {
    m_stillImageSize.store(imageSize);
    m_stillImageQuality.store(imageQuality);
}

bool CaptureWorker::capture(CameraError& err, long& afStatus, bool focusBeforeRelease) {
    const long stillImageSize = m_stillImageSize.load();
    const long stillImageQuality = m_stillImageQuality.load();
    const long releaseMode = captureReleaseMode(focusBeforeRelease);
    const char* modeLabel = captureModeLabel(focusBeforeRelease);

    CameraContext::Lock lk(m_ctx->mtx);
    FujiSdkLibrary* lib = m_ctx->lib;
    if (!m_ctx->handle) { err = CameraError::NotConnected; return false; }

    bool faulted = false;
    long stopRc = sdkGuardL(TAG, "StopLiveView", faulted, [&]{
        return lib->SetProp(m_ctx->handle, API_CODE_StopLiveView, 0);
    });
    if (faulted) { err = CameraError::Communication; return false; }
    if (stopRc == XSDK_COMPLETE) {
        Logger::instance().info(TAG, "StopLiveView complete rc=0x%lX", stopRc);
    } else {
        long api = 0, sdkErr = 0;
        CameraError mapped = m_ctx->lastError(&api, &sdkErr);
        Logger::instance().warn(TAG, "StopLiveView rc=0x%lX api=0x%lX err=0x%lX mapped=%d",
                                stopRc, api, sdkErr, static_cast<int>(mapped));

        if (isBusyStopError(sdkErr)) {
            std::this_thread::sleep_for(std::chrono::milliseconds(80));
            faulted = false;
            stopRc = sdkGuardL(TAG, "StopLiveView retry", faulted, [&]{
                return lib->SetProp(m_ctx->handle, API_CODE_StopLiveView, 0);
            });
            if (faulted) { err = CameraError::Communication; return false; }
            if (stopRc == XSDK_COMPLETE) {
                Logger::instance().info(TAG, "StopLiveView retry complete rc=0x%lX", stopRc);
            } else {
                api = 0;
                sdkErr = 0;
                mapped = m_ctx->lastError(&api, &sdkErr);
                Logger::instance().warn(TAG, "StopLiveView retry rc=0x%lX api=0x%lX err=0x%lX mapped=%d",
                                        stopRc, api, sdkErr, static_cast<int>(mapped));
            }
        }
    }

    if (stillImageSize > 0) {
        faulted = false;
        const long sizeRc = sdkGuardL(TAG, "SetImageSize", faulted, [&]{
            return lib->SetProp(m_ctx->handle, API_CODE_SetImageSize, 1, stillImageSize);
        });
        if (faulted) { err = CameraError::Communication; return false; }
        if (sizeRc == XSDK_COMPLETE) {
            Logger::instance().info(TAG, "SetImageSize requested=0x%lX rc=0x%lX",
                                    stillImageSize, sizeRc);
        } else {
            long api = 0, sdkErr = 0;
            CameraError mapped = m_ctx->lastError(&api, &sdkErr);
            Logger::instance().warn(TAG, "SetImageSize requested=0x%lX failed rc=0x%lX api=0x%lX err=0x%lX mapped=%d",
                                    stillImageSize, sizeRc, api, sdkErr, static_cast<int>(mapped));
        }
    } else {
        Logger::instance().trace(TAG, "SetImageSize skipped: camera default");
    }

    if (stillImageQuality > 0) {
        faulted = false;
        long qualityRc = sdkGuardL(TAG, "SetImageQuality", faulted, [&]{
            return lib->SetProp(m_ctx->handle, API_CODE_SetImageQuality, 1, stillImageQuality);
        });
        if (faulted) { err = CameraError::Communication; return false; }
        if (qualityRc == XSDK_COMPLETE) {
            Logger::instance().info(TAG, "SetImageQuality requested=0x%lX rc=0x%lX",
                                    stillImageQuality, qualityRc);
        } else {
            long api = 0, sdkErr = 0;
            CameraError mapped = m_ctx->lastError(&api, &sdkErr);
            Logger::instance().warn(TAG, "SetImageQuality requested=0x%lX failed rc=0x%lX api=0x%lX err=0x%lX mapped=%d",
                                    stillImageQuality, qualityRc, api, sdkErr, static_cast<int>(mapped));

            if (stillImageQuality == SDK_IMAGEQUALITY_SUPERFINE) {
                faulted = false;
                qualityRc = sdkGuardL(TAG, "SetImageQuality(FINE fallback)", faulted, [&]{
                    return lib->SetProp(m_ctx->handle, API_CODE_SetImageQuality, 1, SDK_IMAGEQUALITY_FINE);
                });
                if (faulted) { err = CameraError::Communication; return false; }
                if (qualityRc == XSDK_COMPLETE) {
                    Logger::instance().info(TAG, "SetImageQuality fallback FINE rc=0x%lX", qualityRc);
                } else {
                    api = 0;
                    sdkErr = 0;
                    mapped = m_ctx->lastError(&api, &sdkErr);
                    Logger::instance().warn(TAG, "SetImageQuality fallback FINE failed rc=0x%lX api=0x%lX err=0x%lX mapped=%d",
                                            qualityRc, api, sdkErr, static_cast<int>(mapped));
                }
            }
        }
    } else {
        Logger::instance().trace(TAG, "SetImageQuality skipped: camera default");
    }

    faulted = false;
    long prep = sdkGuardL(TAG, "SetPriorityMode(CAMERA)", faulted, [&]{
        return lib->SetPriorityMode(m_ctx->handle, XSDK_PRIORITY_CAMERA);
    });
    if (faulted) { err = CameraError::Communication; return false; }
    if (prep != XSDK_COMPLETE)
        Logger::instance().warn(TAG, "SetPriorityMode(CAMERA) before capture failed rc=0x%lX", prep);

    if (!applyConfiguredMediaRecord(m_ctx, TAG, &err) && err == CameraError::Communication)
        return false;

    long shotOpt = 0;
    afStatus = 0;
    faulted = false;
    long rc = sdkGuardL(TAG, "ReleaseEx(CAMERA)", faulted, [&]{
        return lib->ReleaseEx(m_ctx->handle,
                              releaseMode,
                              &shotOpt, &afStatus);
    });
    if (faulted) { err = CameraError::Communication; return false; }
    if (rc != XSDK_COMPLETE) {
        long api = 0, sdkErr = 0;
        err = m_ctx->lastError(&api, &sdkErr);
        Logger::instance().warn(TAG,
                                "[FujiCapture] mode=%s release=0x%lX ok=false priority=CAMERA rc=0x%lX api=0x%lX err=0x%lX mapped=%d af=%ld",
                                modeLabel, releaseMode, rc, api, sdkErr, static_cast<int>(err), afStatus);

        if (shouldFallbackRelease(err)) {
            faulted = false;
            prep = sdkGuardL(TAG, "SetPriorityMode(PC fallback)", faulted, [&]{
                return lib->SetPriorityMode(m_ctx->handle, XSDK_PRIORITY_PC);
            });
            if (faulted) { err = CameraError::Communication; return false; }
            if (prep != XSDK_COMPLETE)
                Logger::instance().warn(TAG, "SetPriorityMode(PC fallback) failed rc=0x%lX", prep);

            shotOpt = 0;
            afStatus = 0;
            faulted = false;
            rc = sdkGuardL(TAG, "ReleaseEx(PC fallback)", faulted, [&]{
                return lib->ReleaseEx(m_ctx->handle,
                                      releaseMode,
                                      &shotOpt, &afStatus);
            });
            if (faulted) { err = CameraError::Communication; return false; }
            if (rc == XSDK_COMPLETE) {
                err = CameraError::None;
                Logger::instance().info(TAG,
                                        "[FujiCapture] mode=%s release=0x%lX ok=true priority=PC af=%ld shotOpt=%ld",
                                        modeLabel, releaseMode, afStatus, shotOpt);
                Logger::instance().info(TAG, "shutter fired (af=%ld)", afStatus);
                return true;
            }

            api = 0;
            sdkErr = 0;
            err = m_ctx->lastError(&api, &sdkErr);
            Logger::instance().error(TAG,
                                     "[FujiCapture] mode=%s release=0x%lX ok=false priority=PC rc=0x%lX api=0x%lX err=0x%lX mapped=%d af=%ld",
                                     modeLabel, releaseMode, rc, api, sdkErr, static_cast<int>(err), afStatus);
            return false;
        }

        Logger::instance().error(TAG,
                                 "[FujiCapture] mode=%s release=0x%lX ok=false fallback=false mapped=%d af=%ld",
                                 modeLabel, releaseMode, static_cast<int>(err), afStatus);
        return false;
    }
    err = CameraError::None;
    Logger::instance().info(TAG,
                            "[FujiCapture] mode=%s release=0x%lX ok=true priority=CAMERA af=%ld shotOpt=%ld",
                            modeLabel, releaseMode, afStatus, shotOpt);
    Logger::instance().info(TAG, "shutter fired (af=%ld)", afStatus);
    return true;
}

bool CaptureWorker::burst(int frames, CameraError& err) {
    for (int i = 0; i < frames; ++i) {
        long af = 0;
        if (!capture(err, af)) return false;
    }
    return true;
}
