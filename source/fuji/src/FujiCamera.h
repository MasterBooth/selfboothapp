// FujiCamera.h -- ICamera implementation over the FUJIFILM X SDK.
//
// Owns: the CameraContext (handle + lock), the three workers, and the poll
// thread. CameraManager constructs it after a successful XSDK_OpenEx.
#pragma once

#include "ICamera.h"
#include "CameraContext.h"
#include "ImageDownloader.h"
#include "LiveViewWorker.h"
#include "CaptureWorker.h"
#include "PropertyManager.h"
#include <memory>

class FujiCamera : public ICamera {
public:
    // Takes an already-opened handle (post OpenEx) and the loaded library.
    FujiCamera(FujiSdkLibrary* lib, XSDK_HANDLE handle, const CameraInfo& info);
    ~FujiCamera() override;

    bool open() override;             // finishes session setup (priority/media/poll)
    void close() override;
    bool isOpen() const override { return m_ctx.handle != nullptr; }
    CameraInfo info() const override { return m_info; }

    bool startLiveView() override;
    void stopLiveView()  override;
    void setLiveViewOptions(long quality, long size, long mode) override;
    bool capture() override;
    bool captureNoAf() override;
    bool burst(int frames) override;

    bool setIso(int iso) override;
    bool getIso(int& iso) override;
    bool setShutterSpeed(int code, bool bulb = false) override;
    bool getShutterSpeed(int& code, bool& bulb) override;
    bool setAperture(int fnumberX100) override;
    bool getAperture(int& fnumberX100) override;
    bool setExposureBias(int code) override;
    bool getExposureBias(int& code) override;
    bool setFilmSimulation(int sim) override;

    std::vector<int> capIso() override;
    std::vector<int> capShutterSpeed() override;
    std::vector<int> capAperture() override;
    std::vector<int> capExposureBias() override;

private:
    bool captureImpl(bool useAf);

    CameraContext                    m_ctx;
    CameraInfo                       m_info;
    std::unique_ptr<ImageDownloader> m_downloader;
    std::unique_ptr<LiveViewWorker>  m_liveView;
    std::unique_ptr<CaptureWorker>   m_capture;
    std::unique_ptr<PropertyManager> m_props;
    long m_liveViewQuality = SDK_LIVEVIEW_QUALITY_FINE;
    long m_liveViewSize = 0; // native/auto
    long m_liveViewMode = SDK_LIVEVIEW_MODE1;
};
