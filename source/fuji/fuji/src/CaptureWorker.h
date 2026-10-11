// CaptureWorker.h -- fires the shutter via XSDK_ReleaseEx.
//
// The resulting image is NOT returned here; it appears in the shared queue and
// is delivered by ImageDownloader. This class only owns the release command and
// its AF/shot-status reporting.
#pragma once

#include "CameraContext.h"
#include <atomic>
#include <string>

class CaptureWorker {
public:
    explicit CaptureWorker(CameraContext* ctx) : m_ctx(ctx) {}
    void setStillOptions(long imageSize, long imageQuality);

    // Single-shot release. When focusBeforeRelease is true this uses the full
    // S1+S2 sequence; otherwise it fires S2 directly for MF/no-AF captures.
    // Returns false on release failure; `err`/`afStatus` explain why.
    bool capture(CameraError& err, long& afStatus, bool focusBeforeRelease = true);

    // Burst: fire N frames back-to-back. Downloads are drained asynchronously by
    // ImageDownloader, so ensure the poll thread is running first.
    bool burst(int frames, CameraError& err);

private:
    CameraContext* m_ctx;
    std::atomic<long> m_stillImageSize{0};
    std::atomic<long> m_stillImageQuality{0};
};
