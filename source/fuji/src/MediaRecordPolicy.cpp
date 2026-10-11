#include "MediaRecordPolicy.h"

#include "Logger.h"
#include "RuntimeConfig.h"
#include "SdkGuard.h"

bool applyConfiguredMediaRecord(CameraContext* ctx, const char* tag, CameraError* err) {
    if (err) *err = CameraError::None;
    if (!ctx || !ctx->handle || !ctx->lib) {
        if (err) *err = CameraError::NotConnected;
        return false;
    }

    long mediaRecord = 0;
    const MediaRecordMode mode = runtimeConfig().mediaRecordMode;
    if (!mediaRecordSdkValue(mode, mediaRecord)) {
        Logger::instance().trace(tag, "media record follows camera setting");
        return true;
    }

    bool faulted = false;
    const long rc = sdkGuardL(tag, "SetMediaRecord", faulted, [&] {
        return ctx->lib->SetMediaRecord(ctx->handle, mediaRecord);
    });
    if (faulted) {
        if (err) *err = CameraError::Communication;
        return false;
    }
    if (rc != XSDK_COMPLETE) {
        CameraError mapped = ctx->lastError();
        if (err) *err = mapped;
        Logger::instance().warn(tag, "SetMediaRecord(%s) failed", mediaRecordModeName(mode));
        return false;
    }

    Logger::instance().info(tag, "SetMediaRecord(%s)", mediaRecordModeName(mode));
    return true;
}
