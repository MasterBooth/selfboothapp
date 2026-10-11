// LiveViewWorker.h -- manages Live View *state* only (not frame delivery).
//
// Frames come out of ImageDownloader. This class just configures quality/size/
// mode via the model-dependent SetProp interface and sends Start/StopLiveView.
#pragma once

#include "CameraContext.h"

class LiveViewWorker {
public:
    explicit LiveViewWorker(CameraContext* ctx) : m_ctx(ctx) {}

    // Configure then start. Quality/size/mode use SDK_LIVEVIEW_* constants.
    // size <= 0 means native/auto: skip SetLiveViewImageSize and use whatever
    // the body/SDK returns.
    bool start(long quality = SDK_LIVEVIEW_QUALITY_FINE,
               long size    = 0,
               long mode    = SDK_LIVEVIEW_MODE1);
    void stop();
    bool active() const { return m_active; }

private:
    CameraContext* m_ctx;
    bool           m_active = false;
};
