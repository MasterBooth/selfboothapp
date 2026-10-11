#include "CaptureWorker.h"
#include "Logger.h"
#include "MediaRecordPolicy.h"
#include "SdkGuard.h"

#include <chrono>
#include <thread>

static const char* TAG = "Capture";

namespace {

bool isBusySdkError(long sdkErr) {
    return sdkErr == XSDK_ERRCODE_BUSY
        || sdkErr == XSDK_ERRCODE_FORCEMODE_BUSY
        || sdkErr == XSDK_ERRCODE_RUNNING_OTHER_FUNCTION;
}

bool releaseLegacyWithRetry(CameraContext* ctx,
                            long releaseMode,
                            const char* label,
                            long* shotOpt,
                            long* afStatus,
                            CameraError& err,
                            long* outSdkErr = nullptr) {
    FujiSdkLibrary* lib = ctx->lib;
    CameraError lastMapped = CameraError::Unknown;
    long lastApi = 0;
    long lastSdkErr = 0;

    for (int attempt = 1; attempt <= 4; ++attempt) {
        bool faulted = false;
        const long rc = sdkGuardL(TAG, label, faulted, [&]{
            return lib->Release(ctx->handle, releaseMode, shotOpt, afStatus);
        });
        if (faulted) {
            err = CameraError::Communication;
            return false;
        }
        if (rc == XSDK_COMPLETE) {
            err = CameraError::None;
            Logger::instance().info(TAG, "%s complete mode=0x%lX af=%ld shotOpt=%ld attempt=%d",
                                    label, releaseMode, *afStatus, *shotOpt, attempt);
            return true;
        }

        lastApi = 0;
        lastSdkErr = 0;
        lastMapped = ctx->lastError(&lastApi, &lastSdkErr);
        Logger::instance().warn(TAG,
                                "%s failed rc=0x%lX api=0x%lX err=0x%lX mapped=%d af=%ld attempt=%d",
                                label, rc, lastApi, lastSdkErr,
                                static_cast<int>(lastMapped), *afStatus, attempt);
        if (!isBusySdkError(lastSdkErr))
            break;
        std::this_thread::sleep_for(std::chrono::milliseconds(60));
    }

    if (outSdkErr) *outSdkErr = lastSdkErr;
    err = lastMapped;
    return false;
}

bool releaseExWithRetry(CameraContext* ctx,
                        long releaseMode,
                        const char* label,
                        long* shotOpt,
                        long* afStatus,
                        CameraError& err,
                        long* outSdkErr = nullptr) {
    FujiSdkLibrary* lib = ctx->lib;
    CameraError lastMapped = CameraError::Unknown;
    long lastApi = 0;
    long lastSdkErr = 0;

    for (int attempt = 1; attempt <= 4; ++attempt) {
        bool faulted = false;
        const long rc = sdkGuardL(TAG, label, faulted, [&]{
            return lib->ReleaseEx(ctx->handle, releaseMode, shotOpt, afStatus);
        });
        if (faulted) {
            err = CameraError::Communication;
            return false;
        }
        if (rc == XSDK_COMPLETE) {
            err = CameraError::None;
            Logger::instance().info(TAG, "%s complete mode=0x%lX af=%ld shotOpt=%ld attempt=%d",
                                    label, releaseMode, *afStatus, *shotOpt, attempt);
            return true;
        }

        lastApi = 0;
        lastSdkErr = 0;
        lastMapped = ctx->lastError(&lastApi, &lastSdkErr);
        Logger::instance().warn(TAG,
                                "%s failed rc=0x%lX api=0x%lX err=0x%lX mapped=%d af=%ld attempt=%d",
                                label, rc, lastApi, lastSdkErr,
                                static_cast<int>(lastMapped), *afStatus, attempt);
        if (!isBusySdkError(lastSdkErr))
            break;
        std::this_thread::sleep_for(std::chrono::milliseconds(60));
    }

    if (outSdkErr) *outSdkErr = lastSdkErr;
    err = lastMapped;
    return false;
}

void cancelReleaseBestEffort(CameraContext* ctx) {
    FujiSdkLibrary* lib = ctx->lib;
    long shotOpt = 0;
    long af = 0;
    bool faulted = false;
    sdkGuardL(TAG, "Release(CANCEL)", faulted, [&]{
        return lib->Release(ctx->handle, XSDK_RELEASE_CANCEL, &shotOpt, &af);
    });

    faulted = false;
    sdkGuardL(TAG, "ReleaseEx(CANCEL)", faulted, [&]{
        return lib->ReleaseEx(ctx->handle, XSDK_RELEASE_EX_CANCEL, &shotOpt, &af);
    });
}

} // namespace

bool CaptureWorker::capture(CameraError& err, long& afStatus, bool useAf) {
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

        if (isBusySdkError(sdkErr)) {
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

    faulted = false;
    long prep = sdkGuardL(TAG, "SetPriorityMode(PC)", faulted, [&]{
        return lib->SetPriorityMode(m_ctx->handle, XSDK_PRIORITY_PC);
    });
    if (faulted) { err = CameraError::Communication; return false; }
    if (prep != XSDK_COMPLETE)
        Logger::instance().warn(TAG, "SetPriorityMode(PC) before capture failed rc=0x%lX", prep);

    if (!applyConfiguredMediaRecord(m_ctx, TAG, &err) && err == CameraError::Communication)
        return false;

    faulted = false;
    long priorityMode = XSDK_PRIORITY_PC;
    const long priorityRc = sdkGuardL(TAG, "GetPriorityMode", faulted, [&]{
        return lib->GetPriorityMode(m_ctx->handle, &priorityMode);
    });
    if (faulted) { err = CameraError::Communication; return false; }
    if (priorityRc != XSDK_COMPLETE) {
        long api = 0;
        long sdkErr = 0;
        const CameraError mapped = m_ctx->lastError(&api, &sdkErr);
        Logger::instance().warn(TAG, "GetPriorityMode failed rc=0x%lX api=0x%lX err=0x%lX mapped=%d; assume PC",
                                priorityRc, api, sdkErr, static_cast<int>(mapped));
        priorityMode = XSDK_PRIORITY_PC;
    }

    long shotOpt = 0;
    afStatus = 0;

    if (priorityMode == XSDK_PRIORITY_PC) {
        Logger::instance().info(TAG, "capture release path=legacy-pc use_af=%d", useAf ? 1 : 0);
        long sdkErr = 0;

        if (useAf) {
            if (releaseLegacyWithRetry(m_ctx, XSDK_RELEASE_S1ON, "Release(S1ON)",
                                       &shotOpt, &afStatus, err, &sdkErr)) {
                std::this_thread::sleep_for(std::chrono::milliseconds(80));
                if (releaseLegacyWithRetry(m_ctx, XSDK_RELEASE_S2_S1OFF, "Release(S2_S1OFF)",
                                           &shotOpt, &afStatus, err, &sdkErr)) {
                    Logger::instance().info(TAG, "shutter fired via legacy PC AF path (af=%ld)", afStatus);
                    return true;
                }
                cancelReleaseBestEffort(m_ctx);
            }
        } else {
            if (releaseLegacyWithRetry(m_ctx, XSDK_RELEASE_SHOOT_S1OFF, "Release(SHOOT_S1OFF)",
                                       &shotOpt, &afStatus, err, &sdkErr)) {
                Logger::instance().info(TAG, "shutter fired via legacy PC No-AF path (af=%ld)", afStatus);
                return true;
            }
        }

        if (sdkErr == XSDK_ERRCODE_UNSUPPORTED) {
            shotOpt = 0;
            afStatus = 0;
            Logger::instance().warn(TAG, "legacy PC primary release unsupported; trying Release(S2_S1OFF) direct");
            if (releaseLegacyWithRetry(m_ctx, XSDK_RELEASE_S2_S1OFF, "Release(S2_S1OFF direct)",
                                       &shotOpt, &afStatus, err, &sdkErr)) {
                Logger::instance().info(TAG, "shutter fired via legacy PC direct S2 path (af=%ld)", afStatus);
                return true;
            }
        }

        if (sdkErr != XSDK_ERRCODE_UNSUPPORTED) {
            Logger::instance().error(TAG, "legacy PC release sequence failed mapped=%d af=%ld",
                                     static_cast<int>(err), afStatus);
            return false;
        }

        Logger::instance().warn(TAG, "legacy PC release unsupported; falling back to ReleaseEx");
    }

    Logger::instance().info(TAG, "capture release path=release-ex priority=0x%lX", priorityMode);
    long sdkErr = 0;
    if (releaseExWithRetry(m_ctx, XSDK_RELEASE_EX_S2_ON_S2_OFF_S1_OFF, "ReleaseEx(S2_ON_S2_OFF_S1_OFF)",
                           &shotOpt, &afStatus, err, &sdkErr)) {
        Logger::instance().info(TAG, "shutter fired via ReleaseEx S2 path (af=%ld)", afStatus);
        return true;
    }

    if (useAf) {
        if (releaseExWithRetry(m_ctx, XSDK_RELEASE_EX_S1_ON_S2_ON_S2_OFF_S1_OFF,
                               "ReleaseEx(S1_ON_S2_ON_S2_OFF_S1_OFF)",
                               &shotOpt, &afStatus, err, &sdkErr)) {
            Logger::instance().info(TAG, "shutter fired via ReleaseEx combined AF path (af=%ld)", afStatus);
            return true;
        }
    }

    cancelReleaseBestEffort(m_ctx);
    Logger::instance().error(TAG, "all Fuji release commands failed mapped=%d af=%ld",
                             static_cast<int>(err), afStatus);
    return false;
}

bool CaptureWorker::burst(int frames, CameraError& err) {
    for (int i = 0; i < frames; ++i) {
        long af = 0;
        if (!capture(err, af)) return false;
    }
    return true;
}
