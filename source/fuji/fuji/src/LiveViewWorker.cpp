#include "LiveViewWorker.h"
#include "Logger.h"
#include "MediaRecordPolicy.h"
#include "RuntimeConfig.h"
#include "SdkGuard.h"

#include <string>

static const char* TAG = "LiveView";

// The model-dependent setters take (handle, apiCode, apiParam=1, value).
// This mirrors live_view_control.py: SetLiveViewImageQuality/Size/Mode then
// StartLiveView (apiParam=0, no value). Each call is SEH-guarded so a fault in
// the variadic model-dependent interface cannot take the process down.
bool LiveViewWorker::start(long quality, long size, long mode) {
    CameraContext::Lock lk(m_ctx->mtx);
    FujiSdkLibrary* lib = m_ctx->lib;
    if (!m_ctx->handle) return false;

    const std::string requestedSizeLabel = size > 0 ? std::to_string(size) : "native";
    Logger::instance().info(TAG, "requesting live view quality=0x%lX size=%s mode=0x%lX",
                            quality, requestedSizeLabel.c_str(), mode);

    bool faulted = false;
    long prep = sdkGuardL(TAG, "SetPriorityMode(CAMERA)", faulted, [&]{
        return lib->SetPriorityMode(m_ctx->handle, XSDK_PRIORITY_CAMERA);
    });
    if (faulted) return false;
    if (prep != XSDK_COMPLETE)
        Logger::instance().warn(TAG, "SetPriorityMode(CAMERA) before live view failed");

    // These are best-effort: not every body honours every knob, so we log but
    // do not abort if one returns XSDK_ERROR.
    long qualityRc = sdkGuardL(TAG, "SetLiveViewImageQuality", faulted,
                               [&]{ return lib->SetProp(m_ctx->handle, API_CODE_SetLiveViewImageQuality, 1, quality); });
    Logger::instance().info(TAG, "SetLiveViewImageQuality requested=0x%lX rc=0x%lX", quality, qualityRc);
    if (qualityRc != XSDK_COMPLETE)
        Logger::instance().warn(TAG, "SetLiveViewImageQuality unsupported; falling back to camera/SDK default");

    long sizeRc = XSDK_COMPLETE;
    if (size > 0) {
        sizeRc = sdkGuardL(TAG, "SetLiveViewImageSize", faulted,
                           [&]{ return lib->SetProp(m_ctx->handle, API_CODE_SetLiveViewImageSize, 1, size); });
        Logger::instance().info(TAG, "SetLiveViewImageSize requested=0x%lX rc=0x%lX", size, sizeRc);
        if (sizeRc != XSDK_COMPLETE)
            Logger::instance().warn(TAG, "SetLiveViewImageSize unsupported; falling back to camera/SDK default");
    } else {
        Logger::instance().info(TAG, "SetLiveViewImageSize skipped: native/auto");
    }

    long modeRc = sdkGuardL(TAG, "SetLiveViewMode", faulted,
                            [&]{ return lib->SetProp(m_ctx->handle, API_CODE_SetLiveViewMode, 1, mode); });
    Logger::instance().info(TAG, "SetLiveViewMode requested=0x%lX rc=0x%lX", mode, modeRc);
    if (modeRc != XSDK_COMPLETE)
        Logger::instance().warn(TAG, "SetLiveViewMode unsupported");

    bool diagFaulted = false;
    long actualQuality = 0;
    long actualQualityRc = sdkGuardL(TAG, "GetLiveViewImageQuality", diagFaulted,
                                     [&]{ return lib->GetProp(m_ctx->handle, API_CODE_GetLiveViewImageQuality, 1, &actualQuality); });
    if (!diagFaulted && actualQualityRc == XSDK_COMPLETE)
        Logger::instance().info(TAG, "actual live view quality=0x%lX", actualQuality);

    diagFaulted = false;
    long actualSize = 0;
    long actualSizeRc = sdkGuardL(TAG, "GetLiveViewImageSize", diagFaulted,
                                  [&]{ return lib->GetProp(m_ctx->handle, API_CODE_GetLiveViewImageSize, 1, &actualSize); });
    if (!diagFaulted && actualSizeRc == XSDK_COMPLETE)
        Logger::instance().info(TAG, "actual live view size=0x%lX", actualSize);

    long rc = sdkGuardL(TAG, "StartLiveView", faulted,
                        [&]{ return lib->SetProp(m_ctx->handle, API_CODE_StartLiveView, 0); });
    if (rc != XSDK_COMPLETE) {
        if (!faulted) {
            long api = 0, err = 0;
            m_ctx->lastError(&api, &err);
            if (err == XSDK_ERRCODE_RUNNING_OTHER_FUNCTION) {
                m_active = true;
                Logger::instance().warn(TAG, "StartLiveView reported running/busy; treating stream as active");
                return true;
            }
            Logger::instance().error(TAG, "StartLiveView failed (api=0x%lX err=0x%lX)", api, err);
        } else {
            Logger::instance().error(TAG, "StartLiveView failed");
        }
        return false;
    }
    m_active = true;
    Logger::instance().info(TAG, "live view started quality=0x%lX size=%s mode=0x%lX",
                            quality, requestedSizeLabel.c_str(), mode);
    return true;
}

void LiveViewWorker::stop() {
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return;
    bool faulted = false;
    sdkGuardL(TAG, "StopLiveView", faulted,
              [&]{ return m_ctx->lib->SetProp(m_ctx->handle, API_CODE_StopLiveView, 0); });
    m_active = false;

    if (runtimeConfig().restorePcPriorityOnLiveStop) {
        faulted = false;
        sdkGuardL(TAG, "SetPriorityMode(PC)", faulted,
                  [&]{ return m_ctx->lib->SetPriorityMode(m_ctx->handle, XSDK_PRIORITY_PC); });
        if (!faulted)
            applyConfiguredMediaRecord(m_ctx, TAG);
    }
    Logger::instance().info(TAG, "live view stopped");
}
