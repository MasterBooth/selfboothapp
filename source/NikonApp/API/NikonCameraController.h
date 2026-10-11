#pragma once

/*=============================================================================
 * NikonCameraController.h - Public API for Nikon Camera Operations
 *
 * Drop-in sibling of CameraApp::CameraController (Canon) and
 * SonyApp::SonyCameraController (Sony). PhotoboothDashboard selects between
 * them at runtime via DualSDKController.
 *
 * Internally wraps the Nikon "Control Service Layer" SDK
 * (ControlServiceLayer.dll, MAID 3.0) loaded dynamically at runtime.
 * Thread-safety: public methods are guarded by an internal mutex.
 *
 * MVP scope: detect / connect / capture-to-folder / live-view streaming.
 * Property control (ISO/Tv/Av/WB/EV) is stubbed for a later phase.
 *=============================================================================*/

#ifdef _WIN32
#include <windows.h>
#endif

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <cstdint>

// Re-expose Canon/CameraApp event types so CameraEventBridge & adapters
// compile unchanged. CameraApp types are pure Qt-agnostic C++.
#include "../../CameraApp/API/CameraController.h"

namespace NikonApp {

// ---------------------------------------------------------------------------
// Re-export CameraApp event types (no code duplication)
// ---------------------------------------------------------------------------
using CameraEventType      = CameraApp::CameraEventType;
using CameraEvent          = CameraApp::CameraEvent;
using ICameraEventListener = CameraApp::ICameraEventListener;
using LiveViewFrame        = CameraApp::LiveViewFrame;

// ---------------------------------------------------------------------------
// Nikon camera info (mirrors SonyCameraInfo)
// ---------------------------------------------------------------------------
struct NikonCameraInfo {
    std::string name;
    std::string portName;
    int         index = 0;
};

// ---------------------------------------------------------------------------
// Nikon camera state — mirrors SonyCameraState interface.
// MVP: values are placeholders (0); populated in a later phase.
// ---------------------------------------------------------------------------
class NikonCameraState {
public:
    NikonCameraState() = default;

    int iso()          const { return m_iso; }
    int av()           const { return m_av; }
    int tv()           const { return m_tv; }
    int whiteBalance() const { return m_wb; }
    int exposureComp() const { return m_ev; }
    int batteryLevel() const { return m_battery; }

    // Generic property getter (Canon property ID → mapped Nikon value).
    uint32_t getProperty(uint32_t canonPropId) const;

    void setIso(int v)       { m_iso = v; }
    void setAv(int v)        { m_av = v; }
    void setTv(int v)        { m_tv = v; }
    void setWb(int v)        { m_wb = v; }
    void setEv(int v)        { m_ev = v; }
    void setBattery(int v)   { m_battery = v; }
    void setColorTemp(int v) { m_colorTemp = v; }

private:
    int m_iso       = 0;
    int m_av        = 0;
    int m_tv        = 0;
    int m_wb        = 0;
    int m_ev        = 0;
    int m_battery   = 0;
    int m_colorTemp = 5200;
};

// ---------------------------------------------------------------------------
// MAIN API — NikonCameraController
// Public interface mirrors SonyCameraController / CameraApp::CameraController.
// ---------------------------------------------------------------------------
class NikonCameraController {
public:
    static NikonCameraController& instance();

    NikonCameraController(const NikonCameraController&) = delete;
    NikonCameraController& operator=(const NikonCameraController&) = delete;

    // SDK lifecycle ---------------------------------------------------------
    bool initialize();
    void shutdown();

    // Discovery -------------------------------------------------------------
    bool findCameras(std::vector<NikonCameraInfo>& outCameras);
    int  getCameraCount();

    // Connection ------------------------------------------------------------
    bool connectCamera(int cameraIndex);
    bool disconnectCamera();
    bool isConnected() const;

    // Capture ---------------------------------------------------------------
    bool takePhoto();        // AF + shutter
    bool takePhotoNoAF();    // shutter only (MF)
    bool takeBulbPhoto(int /*exposureMs*/) { return false; }   // not in MVP
    std::string getLastPhotoPath() const;
    void setAutoDownload(bool /*enabled*/) {}  // n/a — SDK saves to folder

    // Live view -------------------------------------------------------------
    bool startLiveView();
    bool stopLiveView();
    bool isLiveViewActive() const;
    bool getLiveViewFrame(LiveViewFrame& outFrame);
    bool startLiveViewStreaming();
    bool stopLiveViewStreaming();

    // Focus / zoom (no-op in MVP) ------------------------------------------
    bool driveLensNear()   { return false; }
    bool driveLensFar()    { return false; }
    bool startAutofocus()  { return false; }
    bool stopAutofocus()   { return false; }
    bool setLiveViewZoomFit() { return true; }
    bool setLiveViewZoom5x()  { return true; }
    bool setLiveViewZoom10x() { return true; }

    // Parameter control (STUB in MVP — return false) -----------------------
    bool setISO(int iso);
    bool setShutterSpeed(const std::string& value);
    bool setAperture(const std::string& value);
    bool setWhiteBalance(int mode);
    bool setColorTemperature(int kelvin);
    bool setMeteringMode(int mode);
    bool setImageQuality(int quality);
    bool setDriveMode(int mode);
    bool setExposureComp(int stopValue);

    bool getPropertyStrings(uint32_t canonPropId,
                            std::vector<std::string>& outList,
                            std::string& outCurrent);

    // Image management ------------------------------------------------------
    void        setSaveFolder(const std::string& folderPath);
    std::string getSaveFolder() const;

    // State & diagnostics ---------------------------------------------------
    const NikonCameraState* getState() const;
    std::string getCameraModel() const;
    std::string getLastError() const;
    uint32_t    getLastErrorCode() const { return m_lastErrorCode; }

    // Events & callbacks ----------------------------------------------------
    void addEventListener(ICameraEventListener* listener);
    void removeEventListener(ICameraEventListener* listener);
    void setLogCallback(std::function<void(const std::string&)> callback);
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback);

    bool extendKeepAlive() { return true; }

    // PImpl — public so the .cpp's C-style SDK callbacks/helpers can name it.
    class Impl;

private:
    NikonCameraController();
    ~NikonCameraController();

    std::unique_ptr<Impl> m_impl;

    mutable std::string m_lastError;
    mutable uint32_t    m_lastErrorCode = 0;
};

} // namespace NikonApp
