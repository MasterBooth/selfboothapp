// CaptureWorker.h -- fires the shutter via the release mode supported by the
// camera's current priority mode.
//
// The resulting image is NOT returned here; it appears in the shared queue and
// is delivered by ImageDownloader. This class only owns the release command and
// its AF/shot-status reporting.
#pragma once

#include "CameraContext.h"
#include <string>

class CaptureWorker {
public:
    explicit CaptureWorker(CameraContext* ctx) : m_ctx(ctx) {}

    // Single-shot AF + shutter + release. In PC priority the Fuji SDK sample
    // uses legacy XSDK_Release(S1ON) then XSDK_Release(S2_S1OFF); ReleaseEx is
    // kept as a fallback for bodies/modes that require it.
    // Returns false on release failure; `err`/`afStatus` explain why.
    bool capture(CameraError& err, long& afStatus, bool useAf = true);

    // Burst: fire N frames back-to-back. Downloads are drained asynchronously by
    // ImageDownloader, so ensure the poll thread is running first.
    bool burst(int frames, CameraError& err);

private:
    CameraContext* m_ctx;
};
