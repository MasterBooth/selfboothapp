#pragma once

/*=============================================================================
 * SonyCameraController.h - Public API for Sony Camera Operations
 *
 * Drop-in replacement for CameraApp::CameraController (Canon EDSDK wrapper).
 * Same public interface — PhotoboothDashboard switches between them at
 * compile-time via CameraBackend.h.
 *
 * Internally wraps Sony Camera Remote SDK (SCRSDK / Cr_Core.dll).
 * Thread-safety: All public methods are thread-safe.
 *=============================================================================*/

#ifdef _WIN32
#include <windows.h>
#endif

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <cstdint>

// Re-expose Canon event types so CameraEventBridge compiles unchanged
// CameraApp types are pure Qt-agnostic C++ — safe to include here.
#include "../../CameraApp/API/CameraController.h"

namespace SonyApp {

// ---------------------------------------------------------------------------
// Re-export CameraApp event types for use in bridge (no code duplication)
// ---------------------------------------------------------------------------
using CameraEventType    = CameraApp::CameraEventType;
using CameraEvent        = CameraApp::CameraEvent;
using ICameraEventListener = CameraApp::ICameraEventListener;
using LiveViewFrame      = CameraApp::LiveViewFrame;

// ---------------------------------------------------------------------------
// Sony camera info (mirrors CameraApp::CameraInfo without EDSDK ref)
// ---------------------------------------------------------------------------
struct SonyCameraInfo {
    std::string name;
    std::string portName;
    std::string guid;
    int         index = 0;
};

// ---------------------------------------------------------------------------
// Sony camera state — mirrors CameraApp::CameraState interface
// ---------------------------------------------------------------------------
class SonyCameraState {
public:
    SonyCameraState() = default;

    int    iso()          const { return m_iso; }
    int    av()           const { return m_av; }   // fstop * 100 (e.g., 280 = F2.8)
    int    tv()           const { return m_tv; }   // Sony packed (num<<16|den)
    int    whiteBalance() const { return m_wb; }   // Sony WB code mapped to Canon code
    int    exposureComp() const { return m_ev; }
    int    batteryLevel() const { return m_battery; }

    // Generic property getter (Canon property ID → mapped Sony value)
    // Used by PhotoboothDashboard for kEdsPropID_ColorTemperature etc.
    uint32_t getProperty(uint32_t canonPropId) const;

    // Internal setters (used by SonyCameraController)
    void setIso(int v)          { m_iso = v; }
    void setAv(int v)           { m_av = v; }
    void setTv(int v)           { m_tv = v; }
    void setWb(int v)           { m_wb = v; }
    void setEv(int v)           { m_ev = v; }
    void setBattery(int v)      { m_battery = v; }
    void setColorTemp(int v)    { m_colorTemp = v; }

private:
    int m_iso        = 0;
    int m_av         = 0;
    int m_tv         = 0;
    int m_wb         = 0;
    int m_ev         = 0;
    int m_battery    = 0;
    int m_colorTemp  = 5200;
};

// ---------------------------------------------------------------------------
// MAIN API — SonyCameraController
// Public interface identical to CameraApp::CameraController
// ---------------------------------------------------------------------------
class SonyCameraController {
public:
    // Singleton access (mirrors CameraApp pattern)
    static SonyCameraController& instance();

    SonyCameraController(const SonyCameraController&) = delete;
    SonyCameraController& operator=(const SonyCameraController&) = delete;

    // -----------------------------------------------------------------------
    // SDK LIFECYCLE
    // -----------------------------------------------------------------------
    bool initialize();
    void shutdown();

    // -----------------------------------------------------------------------
    // CAMERA DISCOVERY
    // -----------------------------------------------------------------------
    bool findCameras(std::vector<SonyCameraInfo>& outCameras);
    int  getCameraCount();

    // -----------------------------------------------------------------------
    // CONNECTION MANAGEMENT
    // -----------------------------------------------------------------------
    bool connectCamera(int cameraIndex);
    bool disconnectCamera();
    bool isConnected() const;

    // -----------------------------------------------------------------------
    // PHOTO CAPTURE
    // -----------------------------------------------------------------------
    bool takePhoto();           // AF + shutter
    bool takePhotoNoAF();       // Shutter only (MF mode)
    bool takeBulbPhoto(int exposureMs);
    std::string getLastPhotoPath() const;
    void setAutoDownload(bool enabled) { (void)enabled; }   // not applicable

    // -----------------------------------------------------------------------
    // LIVE VIEW
    // -----------------------------------------------------------------------
    bool startLiveView();
    bool stopLiveView();
    bool isLiveViewActive() const;
    bool getLiveViewFrame(LiveViewFrame& outFrame);
    bool startLiveViewStreaming();
    bool stopLiveViewStreaming();

    // -----------------------------------------------------------------------
    // FOCUS CONTROL (during live view)
    // -----------------------------------------------------------------------
    bool driveLensNear();
    bool driveLensFar();
    bool startAutofocus();
    bool stopAutofocus();

    // -----------------------------------------------------------------------
    // LIVE VIEW ZOOM CONTROL (no-op on Sony — camera controls zoom)
    // -----------------------------------------------------------------------
    bool setLiveViewZoomFit()  { return true; }
    bool setLiveViewZoom5x()   { return true; }
    bool setLiveViewZoom10x()  { return true; }

    // -----------------------------------------------------------------------
    // CAMERA PARAMETER CONTROL
    // -----------------------------------------------------------------------
    bool setISO(int iso);
    bool setShutterSpeed(const std::string& value);   // "1/250", "2\"", "BULB"
    bool setAperture(const std::string& value);       // "f/2.8" or "2.8"
    bool setWhiteBalance(int mode);                   // Canon WB code
    bool setColorTemperature(int kelvin);
    bool setMeteringMode(int mode);
    bool setImageQuality(int quality);
    bool setDriveMode(int mode);
    bool setExposureComp(int stopValue);

    // -----------------------------------------------------------------------
    // PROPERTY STRING QUERY
    // Accepts Canon EdsPropertyID values for drop-in compatibility.
    // Internally maps to Sony CrDevicePropertyCode.
    // -----------------------------------------------------------------------
    bool getPropertyStrings(uint32_t canonPropId,
                            std::vector<std::string>& outList,
                            std::string& outCurrent);

    bool setParameters(const CameraApp::CameraParameters& params);
    bool getParameters(CameraApp::CameraParameters& params) const;

    // -----------------------------------------------------------------------
    // IMAGE MANAGEMENT
    // -----------------------------------------------------------------------
    void        setSaveFolder(const std::string& folderPath);
    std::string getSaveFolder() const;

    // -----------------------------------------------------------------------
    // STATE & DIAGNOSTICS
    // -----------------------------------------------------------------------
    const SonyCameraState* getState() const;
    std::string getCameraModel() const;
    std::string getLastError() const;

    // Compatibility: Canon returns EdsError; Sony returns 0 (no error) or non-zero
    uint32_t getLastErrorCode() const { return m_lastErrorCode; }

    // -----------------------------------------------------------------------
    // CALLBACKS & EVENTS
    // -----------------------------------------------------------------------
    void addEventListener(ICameraEventListener* listener);
    void removeEventListener(ICameraEventListener* listener);
    void setLogCallback(std::function<void(const std::string&)> callback);
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback);

    // -----------------------------------------------------------------------
    // ADVANCED
    // -----------------------------------------------------------------------
    bool extendKeepAlive() { return true; }

private:
    SonyCameraController();
    ~SonyCameraController();

    class Impl;
    std::unique_ptr<Impl> m_impl;

    mutable std::string  m_lastError;
    mutable uint32_t     m_lastErrorCode = 0;
};

} // namespace SonyApp
