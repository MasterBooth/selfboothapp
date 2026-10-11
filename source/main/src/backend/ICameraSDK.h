#pragma once
/*=============================================================================
 * ICameraSDK.h — SDK-agnostic camera interface
 *
 * Both CanonSDKAdapter and SonySDKAdapter implement this interface.
 * DualSDKController selects between them at runtime.
 *=============================================================================*/

#include <string>
#include <vector>
#include <functional>
#include <cstdint>

// Forward-declare only — full type pulled in by adapters and CameraEventBridge.
namespace CameraApp { class ICameraEventListener; }

class ICameraSDK {
public:
    virtual ~ICameraSDK() = default;

    // SDK-agnostic camera list entry
    struct CameraInfo {
        std::string name;
        std::string portName;
    };

    // Flat state snapshot returned by getState() (value type, never nullptr)
    struct State {
        bool valid        = false;
        int  iso          = 0;
        int  av           = 0;  // Canon: EdsUInt32 av code; Sony: fstop*100
        int  tv           = 0;  // Canon: EdsUInt32 tv code; Sony: packed (num<<16|den)
        int  whiteBalance = 0;
        int  exposureComp = 0;
        int  colorTemp    = 5200;
    };

    // Returns "Canon" or "Sony" (or "None" before initialize() selects a backend)
    virtual std::string sdkType() const = 0;

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------
    virtual bool initialize() = 0;
    virtual void shutdown() = 0;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------
    virtual void addEventListener(CameraApp::ICameraEventListener* listener) = 0;
    virtual void removeEventListener(CameraApp::ICameraEventListener* listener) = 0;

    // -----------------------------------------------------------------------
    // Discovery & connection
    // -----------------------------------------------------------------------
    virtual bool findCameras(std::vector<CameraInfo>& outCameras) = 0;
    virtual bool connectCamera(int index) = 0;

    // Preferred camera brand for dual-SDK builds: "Canon" or "Sony".
    // Single-SDK adapters ignore this (no-op default).
    virtual void setPreferredBrand(const std::string& /*brand*/) {}

    virtual bool disconnectCamera() = 0;
    virtual bool isConnected() const = 0;

    // Keep-alive: reset the camera's idle auto-power-off timer (Canon
    // ExtendShutDownTimer). Sent periodically by the Qt watchdog to stop the
    // camera/USB sleeping after a long idle period. Default no-op (returns true)
    // for SDKs without such a command — callers gate on sdkType() == "Canon".
    // Returns false only on a real failure (treated as a possible silent hang).
    virtual bool extendKeepAlive() { return true; }

    // -----------------------------------------------------------------------
    // Capture
    // -----------------------------------------------------------------------
    virtual bool takePhoto() = 0;
    virtual bool takePhotoNoAF() = 0;
    virtual void setRemoteShutterMode(bool /*on*/) {}

    // -----------------------------------------------------------------------
    // Live view
    // -----------------------------------------------------------------------
    virtual bool startLiveView() = 0;
    virtual bool stopLiveView() = 0;
    virtual bool startLiveViewStreaming() = 0;
    virtual bool stopLiveViewStreaming() = 0;
    virtual void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> cb) = 0;
    virtual void setFujiLiveViewOptions(const std::string& /*size*/,
                                        const std::string& /*quality*/) {}

    // -----------------------------------------------------------------------
    // Properties  (propId uses Canon EdsPropertyID constants throughout)
    // -----------------------------------------------------------------------
    virtual bool getPropertyStrings(uint32_t propId,
                                    std::vector<std::string>& outList,
                                    std::string& outCurrent) = 0;
    virtual bool setISO(int iso) = 0;
    virtual bool setShutterSpeed(const std::string& value) = 0;
    virtual bool setAperture(const std::string& value) = 0;
    virtual bool setWhiteBalance(int mode) = 0;
    virtual bool setColorTemperature(int kelvin) = 0;
    virtual bool setExposureComp(int stopValue) = 0;
    virtual bool setImageQuality(int quality) = 0;

    // -----------------------------------------------------------------------
    // State & diagnostics
    // -----------------------------------------------------------------------
    virtual State       getState()       const = 0;
    virtual std::string getCameraModel() const = 0;
    virtual std::string getLastError()   const = 0;
    virtual void        setSaveFolder(const std::string& path) = 0;
};
