#pragma once
/*=============================================================================
 * CanonSDKAdapter.h — ICameraSDK adapter wrapping CameraApp::CameraController
 *
 * Include path "API/CameraController.h" is resolved via CAMERAAPP_ROOT
 * which is always added to target_include_directories in CMakeLists.txt.
 *=============================================================================*/

#include "ICameraSDK.h"
#include "API/CameraController.h"   // CameraApp::CameraController

class CanonSDKAdapter final : public ICameraSDK {
public:
    // Singleton — lifetime tied to the program (same as CameraApp::CameraController)
    static CanonSDKAdapter& instance() {
        static CanonSDKAdapter s;
        return s;
    }

    std::string sdkType() const override { return "Canon"; }

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------
    bool initialize() override { return m_ctrl.initialize(); }
    void shutdown()   override { m_ctrl.shutdown(); }

    // -----------------------------------------------------------------------
    // Events
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
        std::vector<CameraApp::CameraInfo> cams;
        bool ok = m_ctrl.findCameras(cams);
        out.clear();
        for (auto& c : cams)
            out.push_back({ c.name, c.portName });
        return ok;
    }
    bool connectCamera(int i) override { return m_ctrl.connectCamera(i); }
    bool disconnectCamera()   override { return m_ctrl.disconnectCamera(); }
    bool isConnected() const  override { return m_ctrl.isConnected(); }

    // Canon keep-alive — EdsSendCommand(kEdsCameraCommand_ExtendShutDownTimer).
    bool extendKeepAlive() override { return m_ctrl.extendKeepAlive(); }

    // -----------------------------------------------------------------------
    // Capture
    // -----------------------------------------------------------------------
    bool takePhoto()     override { return m_ctrl.takePhoto(); }
    bool takePhotoNoAF() override { return m_ctrl.takePhotoNoAF(); }
    void setRemoteShutterMode(bool on) override { m_ctrl.setRemoteShutterMode(on); }

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
    // Properties
    // -----------------------------------------------------------------------
    bool getPropertyStrings(uint32_t propId,
                            std::vector<std::string>& list,
                            std::string& cur) override {
        return m_ctrl.getPropertyStrings(static_cast<EdsPropertyID>(propId), list, cur);
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
            /*iso*/          static_cast<int>(s->iso()),
            /*av*/           static_cast<int>(s->av()),
            /*tv*/           static_cast<int>(s->tv()),
            /*whiteBalance*/ static_cast<int>(s->whiteBalance()),
            /*exposureComp*/ static_cast<int>(s->exposureComp()),
            /*colorTemp*/    static_cast<int>(s->getProperty(0x00000107))  // kEdsPropID_ColorTemperature
        };
    }

    std::string getCameraModel() const override { return m_ctrl.getCameraModel(); }
    std::string getLastError()   const override { return m_ctrl.getLastError(); }
    void setSaveFolder(const std::string& p) override { m_ctrl.setSaveFolder(p); }

private:
    CanonSDKAdapter() : m_ctrl(CameraApp::CameraController::instance()) {}
    CameraApp::CameraController& m_ctrl;
};
