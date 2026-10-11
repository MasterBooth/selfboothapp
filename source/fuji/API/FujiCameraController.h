#pragma once

#include "../../CameraApp/API/CameraController.h"

#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace FujiApp {

using CameraEvent         = CameraApp::CameraEvent;
using CameraEventType     = CameraApp::CameraEventType;
using ICameraEventListener = CameraApp::ICameraEventListener;
using LiveViewFrame       = CameraApp::LiveViewFrame;

struct FujiCameraInfo {
    std::string name;
    std::string portName;
    int index = 0;
};

class FujiCameraState {
public:
    int iso() const { return m_iso; }
    int av() const { return m_av; }
    int tv() const { return m_tv; }
    int whiteBalance() const { return m_wb; }
    int exposureComp() const { return m_ev; }
    int batteryLevel() const { return m_battery; }
    uint32_t getProperty(uint32_t canonPropId) const;

    void setIso(int value) { m_iso = value; }
    void setAv(int value) { m_av = value; }
    void setTv(int value) { m_tv = value; }
    void setWb(int value) { m_wb = value; }
    void setEv(int value) { m_ev = value; }
    void setBattery(int value) { m_battery = value; }
    void setColorTemp(int value) { m_colorTemp = value; }

private:
    int m_iso = 0;
    int m_av = 0;
    int m_tv = 0;
    int m_wb = 0;
    int m_ev = 0;
    int m_battery = 0;
    int m_colorTemp = 5200;
};

class FujiCameraController {
public:
    static FujiCameraController& instance();

    FujiCameraController(const FujiCameraController&) = delete;
    FujiCameraController& operator=(const FujiCameraController&) = delete;

    bool initialize();
    void shutdown();

    bool findCameras(std::vector<FujiCameraInfo>& outCameras);
    int getCameraCount();

    bool connectCamera(int cameraIndex);
    bool disconnectCamera();
    bool isConnected() const;

    bool takePhoto();
    bool takePhotoNoAF();
    bool takeBulbPhoto(int exposureMs);
    std::string getLastPhotoPath() const;
    void setAutoDownload(bool enabled);
    void setRemoteShutterMode(bool on);

    bool startLiveView();
    bool stopLiveView();
    bool isLiveViewActive() const;
    void setLiveViewOptions(const std::string& size, const std::string& quality);
    bool getLiveViewFrame(LiveViewFrame& outFrame);
    bool startLiveViewStreaming();
    bool stopLiveViewStreaming();

    bool driveLensNear() { return false; }
    bool driveLensFar() { return false; }
    bool startAutofocus() { return false; }
    bool stopAutofocus() { return false; }
    bool setLiveViewZoomFit() { return true; }
    bool setLiveViewZoom5x() { return true; }
    bool setLiveViewZoom10x() { return true; }

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

    bool setParameters(const CameraApp::CameraParameters& params);
    bool getParameters(CameraApp::CameraParameters& params) const;

    void setSaveFolder(const std::string& folderPath);
    std::string getSaveFolder() const;

    const FujiCameraState* getState() const;
    std::string getCameraModel() const;
    std::string getLastError() const;
    uint32_t getLastErrorCode() const { return m_lastErrorCode; }

    void addEventListener(ICameraEventListener* listener);
    void removeEventListener(ICameraEventListener* listener);
    void setLogCallback(std::function<void(const std::string&)> callback);
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback);

    bool extendKeepAlive() { return true; }

private:
    FujiCameraController();
    ~FujiCameraController();

    class Impl;
    std::unique_ptr<Impl> m_impl;

    mutable std::string m_lastError;
    mutable uint32_t m_lastErrorCode = 0;
};

} // namespace FujiApp
