#pragma once
/*=============================================================================
 * SonySDKAdapter.h — ICameraSDK adapter wrapping SonyApp::SonyCameraController
 *
 * Include path "API/SonyCameraController.h" is resolved via SONYAPP_ROOT
 * which is added to target_include_directories when USE_SONY_SDK or
 * USE_DUAL_SDK is set in CMakeLists.txt.
 *=============================================================================*/

#include "ICameraSDK.h"
#include "API/SonyCameraController.h"   // SonyApp::SonyCameraController

class SonySDKAdapter final : public ICameraSDK {
public:
    // Singleton — lifetime tied to the program
    static SonySDKAdapter& instance() {
        static SonySDKAdapter s;
        return s;
    }

    std::string sdkType() const override { return "Sony"; }

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------
    bool initialize() override { return m_ctrl.initialize(); }
    void shutdown()   override { m_ctrl.shutdown(); }

    // -----------------------------------------------------------------------
    // Events  (Sony re-exports CameraApp event types, so same listener type)
    // -----------------------------------------------------------------------
    void addEventListener(CameraApp::ICameraEventListener* l) override {
        m_ctrl.addEventListener(l);
    }
    void removeEventListener(CameraApp::ICameraEventListener* l) override {
        m_ctrl.removeEventListener(l);
    }

    // -----------------------------------------------------------------------
    // Discovery & connection
    // -----------------------------------------------------------------------
    bool findCameras(std::vector<CameraInfo>& out) override {
        std::vector<SonyApp::SonyCameraInfo> cams;
        bool ok = m_ctrl.findCameras(cams);
        out.clear();
        for (auto& c : cams)
            out.push_back({ c.name, c.portName });
        return ok;
    }
    bool connectCamera(int i) override { return m_ctrl.connectCamera(i); }
    bool disconnectCamera()   override { return m_ctrl.disconnectCamera(); }
    bool isConnected() const  override { return m_ctrl.isConnected(); }

    // -----------------------------------------------------------------------
    // Capture
    // -----------------------------------------------------------------------
    bool takePhoto()     override { return m_ctrl.takePhoto(); }
    bool takePhotoNoAF() override { return m_ctrl.takePhotoNoAF(); }

    // -----------------------------------------------------------------------
    // Live view
    // -----------------------------------------------------------------------
    bool startLiveView()           override { return m_ctrl.startLiveView(); }
    bool stopLiveView()            override { return m_ctrl.stopLiveView(); }
    bool startLiveViewStreaming()  override { return m_ctrl.startLiveViewStreaming(); }
    bool stopLiveViewStreaming()   override { return m_ctrl.stopLiveViewStreaming(); }
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> cb) override {
        m_ctrl.setLiveViewFrameCallback(std::move(cb));
    }

    // -----------------------------------------------------------------------
    // Properties  (Sony already accepts Canon EdsPropertyID values)
    // -----------------------------------------------------------------------
    bool getPropertyStrings(uint32_t propId,
                            std::vector<std::string>& list,
                            std::string& cur) override {
        return m_ctrl.getPropertyStrings(propId, list, cur);
    }
    bool setISO(int v)                        override { return m_ctrl.setISO(v); }
    bool setShutterSpeed(const std::string& v) override { return m_ctrl.setShutterSpeed(v); }
    bool setAperture(const std::string& v)     override { return m_ctrl.setAperture(v); }
    bool setWhiteBalance(int v)               override { return m_ctrl.setWhiteBalance(v); }
    bool setColorTemperature(int v)           override { return m_ctrl.setColorTemperature(v); }
    bool setExposureComp(int v)               override { return m_ctrl.setExposureComp(v); }
    bool setImageQuality(int v)               override { return m_ctrl.setImageQuality(v); }

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------
    State getState() const override {
        const auto* s = m_ctrl.getState();
        if (!s) return {};
        return State{
            /*valid*/        true,
            /*iso*/          s->iso(),
            /*av*/           s->av(),
            /*tv*/           s->tv(),
            /*whiteBalance*/ s->whiteBalance(),
            /*exposureComp*/ s->exposureComp(),
            /*colorTemp*/    static_cast<int>(s->getProperty(0x00000107))  // PropColorTemp
        };
    }

    std::string getCameraModel() const override { return m_ctrl.getCameraModel(); }
    std::string getLastError()   const override { return m_ctrl.getLastError(); }
    void setSaveFolder(const std::string& p) override { m_ctrl.setSaveFolder(p); }

private:
    SonySDKAdapter() : m_ctrl(SonyApp::SonyCameraController::instance()) {}
    SonyApp::SonyCameraController& m_ctrl;
};
