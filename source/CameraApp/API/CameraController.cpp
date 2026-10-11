/*=============================================================================
 * CameraController.cpp - Implementation of clean public API
 *
 * This layer bridges the clean public API to the existing internal modules.
 * Clients don't need to know about CameraFacade, CameraManager, etc.
 *=============================================================================*/

#include "CameraController.h"
#include "../Interface/CameraFacade.h"
#include "../Camera/CameraManager.h"
#include "../Core/ErrorHandler.h"
#include <memory>
#include <vector>
#include <iostream>
#include <thread>
#include <algorithm>
#include <stdexcept>

namespace CameraApp {

class CameraController::Impl : public ICameraCallback {
public:
    Impl() : m_lastErrorCode(EDS_ERR_OK) {}

    // -----------------------------------------------------------------------
    // ICameraCallback implementation
    // -----------------------------------------------------------------------

    void onCameraConnected(const std::string& modelName) override {
        CameraEvent event;
        event.type = CameraEventType::Connected;
        event.message = "Connected to " + modelName;
        dispatchEvent(event);
    }

    void onCameraDisconnected() override {
        CameraEvent event;
        event.type = CameraEventType::Disconnected;
        event.message = "Camera disconnected";
        dispatchEvent(event);
    }

    void onLiveViewStateChanged(bool active) override {
        CameraEvent event;
        if (active) {
            event.type = CameraEventType::LiveViewStarted;
            event.message = "Live view started";
        } else {
            event.type = CameraEventType::LiveViewStopped;
            event.message = "Live view stopped";
        }
        dispatchEvent(event);
    }

    void onLiveViewFrame(const uint8_t* data, size_t size, const LiveViewFrame& frame) override {
        // Deliver raw JPEG directly via frame callback (zero-copy to avoid overhead)
        if (m_frameCallback && data && size > 0) {
            m_frameCallback(data, size);
        }
        CameraEvent event;
        event.type = CameraEventType::LiveViewFrameReceived;
        event.message = "New live view frame";
        dispatchEvent(event);
    }

    void onPropertyChanged(EdsPropertyID propId, EdsUInt32 value) override {
        CameraEvent event;
        event.type = CameraEventType::PropertyChanged;
        event.propertyId = propId;
        event.propertyValue = value;
        event.message = "Property changed";
        dispatchEvent(event);
    }

    void onPropertyDescChanged(EdsPropertyID propId, const PropertyDescriptor& desc) override {
        // Property descriptor changed - not needed for basic API
    }

    void onShutterFired() override {
        // Fire CaptureStarted the moment the camera signals it has an image ready
        // for transfer.  This happens before the USB download begins, so the UI
        // can start the next countdown immediately without blocking on the file.
        CameraEvent event;
        event.type    = CameraEventType::CaptureStarted;
        event.message = "Shutter fired — downloading image";
        dispatchEvent(event);
    }

    void onFileDownloaded(const DownloadedFile& file) override {
        CameraEvent event;
        event.type = CameraEventType::CaptureCompleted;
        event.fileName = file.fileName;
        event.message = "Image saved: " + file.fileName;
        m_lastPhotoPath = file.fileName;
        dispatchEvent(event);
    }

    void onDownloadProgress(const std::string& fileName, EdsUInt32 percent) override {
        CameraEvent event;
        event.type = CameraEventType::DownloadProgress;
        event.fileName = fileName;
        event.downloadPercent = static_cast<int>(percent);
        event.message = "Downloading: " + std::to_string(percent) + "%";
        dispatchEvent(event);
    }

    void onCaptureError(EdsError errorCode, const std::string& errorMsg) override {
        CameraEvent event;
        event.type = CameraEventType::CaptureError;
        event.message = "Capture error: " + errorMsg;
        m_lastError = errorMsg;
        m_lastErrorCode = errorCode;
        dispatchEvent(event);
    }

    void onError(const std::string& message) override {
        m_lastError = message;
    }

    void onStatusMessage(const std::string& msg) override {
        m_lastError = msg;
    }

    // -----------------------------------------------------------------------
    // Event dispatcher
    // -----------------------------------------------------------------------

    void addEventListener(ICameraEventListener* listener) {
        if (listener) {
            auto it = std::find(m_listeners.begin(), m_listeners.end(), listener);
            if (it == m_listeners.end()) {
                m_listeners.push_back(listener);
            }
        }
    }

    void removeEventListener(ICameraEventListener* listener) {
        auto it = std::find(m_listeners.begin(), m_listeners.end(), listener);
        if (it != m_listeners.end()) {
            m_listeners.erase(it);
        }
    }

    void setLogCallback(std::function<void(const std::string&)> callback) {
        m_facade.setLogCallback([callback](LogLevel level, const std::string& msg) {
            if (level >= LogLevel::Info) {
                callback(msg);
            }
        });
    }

private:
    void dispatchEvent(const CameraEvent& event) {
        for (auto listener : m_listeners) {
            if (listener) {
                listener->onCameraEvent(event);
            }
        }
    }

public:
    CameraFacade m_facade;
    std::vector<ICameraEventListener*> m_listeners;
    std::string m_lastError;
    EdsError m_lastErrorCode;
    std::string m_lastPhotoPath;
    std::string m_savePath = "./image/";
    std::function<void(const uint8_t*, size_t)> m_frameCallback;
};

// ============================================================================
// Singleton implementation
// ============================================================================

CameraController& CameraController::instance() {
    static CameraController s_instance;
    return s_instance;
}

CameraController::CameraController()
    : m_impl(std::make_unique<Impl>()) {}

CameraController::~CameraController() = default;

// ============================================================================
// SDK LIFECYCLE
// ============================================================================

bool CameraController::initialize() {
    auto result = m_impl->m_facade.initialize();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    m_impl->m_facade.setCallback(m_impl.get());
    return true;
}

void CameraController::shutdown() {
    m_impl->m_facade.shutdown();
}

// ============================================================================
// CAMERA DISCOVERY
// ============================================================================

bool CameraController::findCameras(std::vector<CameraInfo>& outCameras) {
    auto result = m_impl->m_facade.enumerateCameras(outCameras);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

int CameraController::getCameraCount() {
    std::vector<CameraInfo> cameras;
    if (findCameras(cameras)) {
        return static_cast<int>(cameras.size());
    }
    return 0;
}

// ============================================================================
// CONNECTION MANAGEMENT
// ============================================================================

bool CameraController::connectCamera(int cameraIndex) {
    std::vector<CameraInfo> cameras;
    if (!findCameras(cameras)) {
        m_impl->m_lastError = "Failed to enumerate cameras";
        return false;
    }

    if (cameraIndex < 0 || cameraIndex >= static_cast<int>(cameras.size())) {
        m_impl->m_lastError = "Invalid camera index";
        m_impl->m_lastErrorCode = EDS_ERR_SESSION_NOT_OPEN;
        return false;
    }

    auto result = m_impl->m_facade.connect(cameras[cameraIndex], SaveTarget::Host);
    CameraManager::releaseAll(cameras);

    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }

    // Set save path if previously configured
    m_impl->m_facade.setSaveDirectory(m_impl->m_savePath);

    return true;
}

bool CameraController::disconnectCamera() {
    auto result = m_impl->m_facade.disconnect();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::isConnected() const {
    return m_impl->m_facade.isConnected();
}

// ============================================================================
// PHOTO CAPTURE API
// ============================================================================

bool CameraController::takePhoto() {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.takePicture();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::takePhotoNoAF() {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.takePictureNoAF();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::takeBulbPhoto(int exposureMs) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.bulbStart();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }

    std::this_thread::sleep_for(std::chrono::milliseconds(exposureMs));

    result = m_impl->m_facade.bulbEnd();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }

    return true;
}

std::string CameraController::getLastPhotoPath() const {
    return m_impl->m_lastPhotoPath;
}

void CameraController::setAutoDownload(bool enabled) {
    m_impl->m_facade.setAutoDownload(enabled);
}

void CameraController::setRemoteShutterMode(bool on) {
    m_impl->m_facade.setRemoteShutterMode(on);
}

// ============================================================================
// LIVE VIEW STREAMING API
// ============================================================================

bool CameraController::startLiveView() {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.startLiveView();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::stopLiveView() {
    auto result = m_impl->m_facade.stopLiveView();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::isLiveViewActive() const {
    auto state = m_impl->m_facade.cameraState();
    return state && state->isEvfActive();
}

bool CameraController::getLiveViewFrame(LiveViewFrame& outFrame) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.downloadLiveViewFrame(outFrame);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::startLiveViewStreaming() {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    m_impl->m_facade.startLiveViewStreaming();
    return true;
}

bool CameraController::stopLiveViewStreaming() {
    m_impl->m_facade.stopLiveViewStreaming();
    return true;
}

// ============================================================================
// LENS FOCUS CONTROL
// ============================================================================

bool CameraController::driveLensNear() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.driveLens(FocusDrive::Near2);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::driveLensFar() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.driveLens(FocusDrive::Far2);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::startAutofocus() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.liveViewAFStart();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::stopAutofocus() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.liveViewAFStop();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

// ============================================================================
// LIVE VIEW ZOOM CONTROL
// ============================================================================

bool CameraController::setLiveViewZoomFit() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.setLiveViewZoom(kEdsEvfZoom_Fit);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setLiveViewZoom5x() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.setLiveViewZoom(kEdsEvfZoom_x5);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setLiveViewZoom10x() {
    if (!isLiveViewActive()) {
        m_impl->m_lastError = "Live view not active";
        return false;
    }

    auto result = m_impl->m_facade.setLiveViewZoom(kEdsEvfZoom_x10);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

// ============================================================================
// CAMERA PARAMETER CONTROL
// ============================================================================

// ============================================================================
// SHARED LOOKUP TABLES (ISO, WB, EV) — used by setISO, getPropertyStrings, etc.
// ============================================================================

struct IsoEntry  { EdsUInt32 code; const char* label; int number; };
struct WbEntry   { EdsUInt32 code; const char* label; };
struct EvEntry   { EdsInt32  code; const char* label; };

static const IsoEntry kIsoMap[] = {
    { 0x00, "Auto",   0      },
    { 0x28, "6",      6      }, { 0x30, "12",     12     }, { 0x38, "25",     25     },
    { 0x40, "50",     50     },
    { 0x48, "100",    100    }, { 0x4b, "125",    125    }, { 0x4d, "160",    160    },
    { 0x50, "200",    200    }, { 0x53, "250",    250    }, { 0x55, "320",    320    },
    { 0x58, "400",    400    }, { 0x5b, "500",    500    }, { 0x5d, "640",    640    },
    { 0x60, "800",    800    }, { 0x63, "1000",   1000   }, { 0x65, "1250",   1250   },
    { 0x68, "1600",   1600   }, { 0x6b, "2000",   2000   }, { 0x6d, "2500",   2500   },
    { 0x70, "3200",   3200   }, { 0x73, "4000",   4000   }, { 0x75, "5000",   5000   },
    { 0x78, "6400",   6400   }, { 0x7b, "8000",   8000   }, { 0x7d, "10000",  10000  },
    { 0x80, "12800",  12800  }, { 0x83, "16000",  16000  }, { 0x85, "20000",  20000  },
    { 0x88, "25600",  25600  }, { 0x8b, "32000",  32000  }, { 0x8d, "40000",  40000  },
    { 0x90, "51200",  51200  }, { 0x93, "64000",  64000  }, { 0x95, "80000",  80000  },
    { 0x98, "102400", 102400 }, { 0xa0, "204800", 204800 }, { 0xa8, "409600", 409600 },
};

static const WbEntry kWbMap[] = {
    { 0, "Auto" }, { 1, "Daylight" }, { 2, "Shade" },
    { 3, "Cloudy" }, { 4, "Tungsten" }, { 5, "Fluorescent" },
    { 6, "Flash" }, { 8, "Custom" }, { 9, "Color Temp" }, { 15, "AWB White" },
};

static const EvEntry kEvMap[] = {
    { 24, "+3" }, { 21, "+2 2/3" }, { 19, "+2 1/3" }, { 16, "+2" },
    { 13, "+1 2/3" }, { 11, "+1 1/3" }, { 8, "+1" }, { 5, "+2/3" },
    { 3, "+1/3" }, { 0, "0" },
    { -3, "-1/3" }, { -5, "-2/3" }, { -8, "-1" }, { -11, "-1 1/3" },
    { -13, "-1 2/3" }, { -16, "-2" }, { -19, "-2 1/3" }, { -21, "-2 2/3" },
    { -24, "-3" },
};

// Forward-declare Tv/Av tables (defined further below in this file) for reverse lookup
static std::string tvCodeToLabel(EdsUInt32 code);
static std::string avCodeToLabel(EdsUInt32 code);

static std::string isoCodeToLabel(EdsUInt32 code) {
    for (auto& e : kIsoMap) if (e.code == code) return e.label;
    return "";
}
static std::string wbCodeToLabel(EdsUInt32 code) {
    for (auto& e : kWbMap) if (e.code == code) return e.label;
    return "";
}
static std::string evCodeToLabel(EdsInt32 code) {
    for (auto& e : kEvMap) if (e.code == code) return e.label;
    return "";
}

bool CameraController::setISO(int iso) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    // Map human-readable ISO number → EDSDK raw code
    EdsUInt32 code = 0;
    bool found = false;
    for (auto& e : kIsoMap) {
        if (e.number == iso) { code = e.code; found = true; break; }
    }
    if (!found) {
        m_impl->m_lastError = "Unknown ISO value: " + std::to_string(iso);
        return false;
    }

    auto result = m_impl->m_facade.setIso(code);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setShutterSpeed(const std::string& value) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    // Canon EDSDK Tv (shutter speed) property value table.
    // Accepts both fraction strings ("1/1000") and decimal strings ("0.5", "2").
    // If the caller passes the raw EDSDK numeric code as a decimal string,
    // it is used directly (e.g. "120" = 0x78 = 1/1000).
    // Canon EDSDK standard Tv codes — higher code = faster shutter = less light
    static const struct { const char* label; EdsUInt32 code; } kTvTable[] = {
        { "bulb",   0x0C }, { "30",     0x10 }, { "25",     0x13 },
        { "20",     0x14 }, { "15",     0x18 }, { "13",     0x1B },
        { "10",     0x1C }, { "8",      0x20 }, { "6",      0x23 },
        { "5",      0x25 }, { "4",      0x28 }, { "3.2",    0x2B },
        { "2.5",    0x2D }, { "2",      0x30 }, { "1.6",    0x33 },
        { "1.3",    0x35 }, { "1",      0x38 }, { "0.8",    0x3B },
        { "0.6",    0x3D }, { "0.5",    0x40 }, { "0.4",    0x43 },
        { "0.3",    0x44 }, { "1/4",    0x48 }, { "1/5",    0x4B },
        { "1/6",    0x4C }, { "1/8",    0x50 }, { "1/10",   0x53 },
        { "1/13",   0x55 }, { "1/15",   0x58 }, { "1/20",   0x5B },
        { "1/25",   0x5D }, { "1/30",   0x60 }, { "1/40",   0x63 },
        { "1/50",   0x65 }, { "1/60",   0x68 }, { "1/80",   0x6B },
        { "1/100",  0x6D }, { "1/125",  0x70 }, { "1/160",  0x73 },
        { "1/200",  0x75 }, { "1/250",  0x78 }, { "1/320",  0x7B },
        { "1/400",  0x7D }, { "1/500",  0x80 }, { "1/640",  0x83 },
        { "1/800",  0x85 }, { "1/1000", 0x88 }, { "1/1250", 0x8B },
        { "1/1600", 0x8D }, { "1/2000", 0x90 }, { "1/2500", 0x93 },
        { "1/3200", 0x95 }, { "1/4000", 0x98 }, { "1/5000", 0x9B },
        { "1/6400", 0x9D }, { "1/8000", 0xA0 },
    };

    EdsUInt32 tv = 0;
    bool found = false;

    // Try label match (case-insensitive string match)
    for (auto& entry : kTvTable) {
        if (value == entry.label) {
            tv = entry.code;
            found = true;
            break;
        }
    }

    // If not found by label, try parsing as a raw integer EDSDK code
    if (!found) {
        try {
            unsigned long raw = std::stoul(value, nullptr, 0);
            if (raw > 0 && raw <= 0xFF) {
                tv = static_cast<EdsUInt32>(raw);
                found = true;
            }
        } catch (...) {}
    }

    if (!found) {
        m_impl->m_lastError = "Unknown shutter speed value: " + value;
        return false;
    }

    auto result = m_impl->m_facade.setTv(tv);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setAperture(const std::string& value) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    // Canon EDSDK Av (aperture) property value table.
    // Accepts "f/5.6", "5.6", "f5.6", or raw EDSDK codes as decimal strings.
    static const struct { const char* label; EdsUInt32 code; } kAvTable[] = {
        { "1",    0x08 }, { "1.1",  0x0B }, { "1.2",  0x0C }, { "1.4",  0x10 },
        { "1.6",  0x13 }, { "1.8",  0x15 }, { "2",    0x18 }, { "2.2",  0x1B },
        { "2.5",  0x1D }, { "2.8",  0x20 }, { "3.2",  0x23 }, { "3.5",  0x25 },
        { "4",    0x28 }, { "4.5",  0x2B }, { "5",    0x2D }, { "5.6",  0x30 },
        { "6.3",  0x33 }, { "7.1",  0x35 }, { "8",    0x38 }, { "9",    0x3B },
        { "10",   0x3D }, { "11",   0x40 }, { "13",   0x43 }, { "14",   0x45 },
        { "16",   0x48 }, { "18",   0x4B }, { "20",   0x4D }, { "22",   0x50 },
        { "25",   0x53 }, { "29",   0x55 }, { "32",   0x58 }, { "36",   0x5B },
        { "40",   0x5D }, { "45",   0x60 },
    };

    // Normalize: strip leading "f/" or "f"
    std::string norm = value;
    if (norm.size() >= 2 && norm[0] == 'f' && norm[1] == '/') norm = norm.substr(2);
    else if (norm.size() >= 1 && norm[0] == 'f') norm = norm.substr(1);

    EdsUInt32 av = 0;
    bool found = false;

    for (auto& entry : kAvTable) {
        if (norm == entry.label) {
            av = entry.code;
            found = true;
            break;
        }
    }

    // Fallback: try raw integer EDSDK code
    if (!found) {
        try {
            unsigned long raw = std::stoul(norm, nullptr, 0);
            if (raw > 0 && raw <= 0xFF) {
                av = static_cast<EdsUInt32>(raw);
                found = true;
            }
        } catch (...) {}
    }

    if (!found) {
        m_impl->m_lastError = "Unknown aperture value: " + value;
        return false;
    }

    auto result = m_impl->m_facade.setAv(av);
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setWhiteBalance(int mode) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.setWhiteBalance(static_cast<EdsUInt32>(mode));
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setColorTemperature(int kelvin) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.setColorTemperatureByKelvin(static_cast<EdsUInt32>(kelvin));
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setMeteringMode(int mode) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.setMeteringMode(static_cast<EdsUInt32>(mode));
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setImageQuality(int quality) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.setImageQuality(static_cast<EdsUInt32>(quality));
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setDriveMode(int mode) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.setDriveMode(static_cast<EdsUInt32>(mode));
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setExposureComp(int stopValue) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.setExposureComp(static_cast<EdsUInt32>(stopValue));
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

bool CameraController::setParameters(const CameraParameters& params) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    // Set each parameter individually
    bool success = true;

    if (!setISO(params.iso)) success = false;
    if (!setWhiteBalance(params.whiteBalance)) success = false;
    if (!setMeteringMode(params.meteringMode)) success = false;
    if (!setImageQuality(params.imageQuality)) success = false;
    if (!setDriveMode(params.driveMode)) success = false;

    return success;
}

bool CameraController::getParameters(CameraParameters& params) const {
    if (!isConnected()) {
        return false;
    }

    auto state = m_impl->m_facade.cameraState();
    if (!state) {
        return false;
    }

    // Read parameters from camera state
    // This is a simplified version - full implementation would
    // read actual values via getProperty()

    return true;
}

// ============================================================================
// IMAGE MANAGEMENT
// ============================================================================

void CameraController::setSaveFolder(const std::string& folderPath) {
    m_impl->m_savePath = folderPath;
    m_impl->m_facade.setSaveDirectory(folderPath);
}

std::string CameraController::getSaveFolder() const {
    return m_impl->m_savePath;
}

// ============================================================================
// STATE & DIAGNOSTICS
// ============================================================================

const CameraState* CameraController::getState() const {
    return m_impl->m_facade.cameraState();
}

std::string CameraController::getCameraModel() const {
    auto state = m_impl->m_facade.cameraState();
    return state ? state->modelName() : "";
}

std::string CameraController::getLastError() const {
    return m_impl->m_lastError;
}

EdsError CameraController::getLastErrorCode() const {
    return m_impl->m_lastErrorCode;
}

// ============================================================================
// CALLBACKS & EVENTS
// ============================================================================

void CameraController::addEventListener(ICameraEventListener* listener) {
    m_impl->addEventListener(listener);
}

void CameraController::removeEventListener(ICameraEventListener* listener) {
    m_impl->removeEventListener(listener);
}

void CameraController::setLogCallback(std::function<void(const std::string& msg)> callback) {
    m_impl->setLogCallback(callback);
}

void CameraController::setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback) {
    m_impl->m_frameCallback = std::move(callback);
}

// ============================================================================
// ADVANCED
// ============================================================================

bool CameraController::extendKeepAlive() {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    auto result = m_impl->m_facade.extendShutdownTimer();
    if (!result.ok()) {
        m_impl->m_lastError = result.message;
        m_impl->m_lastErrorCode = result.code;
        return false;
    }
    return true;
}

// ============================================================================
// REVERSE LOOKUP HELPERS for Tv/Av (tables defined in setShutterSpeed/setAperture above)
// ============================================================================

static std::string tvCodeToLabel(EdsUInt32 code) {
    // Canon EDSDK standard Tv codes — higher code = faster shutter = less light
    static const struct { EdsUInt32 code; const char* label; } kTvRev[] = {
        { 0x0C, "bulb" }, { 0x10, "30" },  { 0x13, "25" },  { 0x14, "20" },  { 0x15, "20" },
        { 0x18, "15" },   { 0x1B, "13" },  { 0x1C, "10" },  { 0x1D, "10" },  { 0x20, "8" },
        { 0x23, "6" },    { 0x24, "6" },   { 0x25, "5" },   { 0x28, "4" },   { 0x2B, "3.2" },
        { 0x2C, "3" },    { 0x2D, "2.5" }, { 0x30, "2" },   { 0x33, "1.6" }, { 0x34, "1.5" },
        { 0x35, "1.3" },  { 0x38, "1" },   { 0x3B, "0.8" }, { 0x3C, "0.7" }, { 0x3D, "0.6" },
        { 0x40, "0.5" },  { 0x43, "0.4" }, { 0x44, "0.3" }, { 0x45, "0.3" }, { 0x48, "1/4" },
        { 0x4B, "1/5" },  { 0x4C, "1/6" }, { 0x4D, "1/6" }, { 0x50, "1/8" }, { 0x53, "1/10" },
        { 0x54, "1/10" }, { 0x55, "1/13" },{ 0x58, "1/15" },{ 0x5B, "1/20" },{ 0x5C, "1/20" },
        { 0x5D, "1/25" }, { 0x60, "1/30" },{ 0x63, "1/40" },{ 0x64, "1/45" },{ 0x65, "1/50" },
        { 0x68, "1/60" }, { 0x6B, "1/80" },{ 0x6C, "1/90" },{ 0x6D, "1/100"},{ 0x70, "1/125" },
        { 0x73, "1/160" },{ 0x74, "1/180"},{ 0x75, "1/200"},{ 0x78, "1/250"},{ 0x7B, "1/320" },
        { 0x7C, "1/350" },{ 0x7D, "1/400"},{ 0x80, "1/500"},{ 0x83, "1/640"},{ 0x84, "1/750" },
        { 0x85, "1/800" },{ 0x88, "1/1000"},{ 0x8B,"1/1250"},{ 0x8C,"1/1500"},{ 0x8D, "1/1600"},
        { 0x90, "1/2000"},{ 0x93, "1/2500"},{ 0x94,"1/3000"},{ 0x95,"1/3200"},{ 0x98, "1/4000"},
        { 0x9B, "1/5000"},{ 0x9C, "1/6000"},{ 0x9D,"1/6400"},{ 0xA0, "1/8000"},
    };
    for (auto& e : kTvRev) if (e.code == code) return e.label;
    return "";
}

static std::string avCodeToLabel(EdsUInt32 code) {
    static const struct { EdsUInt32 code; const char* label; } kAvRev[] = {
        { 0x08, "1" }, { 0x0B, "1.1" }, { 0x0C, "1.2" }, { 0x10, "1.4" },
        { 0x13, "1.6" }, { 0x15, "1.8" }, { 0x18, "2" }, { 0x1B, "2.2" },
        { 0x1D, "2.5" }, { 0x20, "2.8" }, { 0x23, "3.2" }, { 0x25, "3.5" },
        { 0x28, "4" }, { 0x2B, "4.5" }, { 0x2D, "5" }, { 0x30, "5.6" },
        { 0x33, "6.3" }, { 0x35, "7.1" }, { 0x38, "8" }, { 0x3B, "9" },
        { 0x3D, "10" }, { 0x40, "11" }, { 0x43, "13" }, { 0x45, "14" },
        { 0x48, "16" }, { 0x4B, "18" }, { 0x4D, "20" }, { 0x50, "22" },
        { 0x53, "25" }, { 0x55, "29" }, { 0x58, "32" }, { 0x5B, "36" },
        { 0x5D, "40" }, { 0x60, "45" },
    };
    for (auto& e : kAvRev) if (e.code == code) return e.label;
    return "";
}

// ============================================================================
// getPropertyStrings — public API for Qt layer to populate lists
// ============================================================================

bool CameraController::getPropertyStrings(EdsPropertyID propId,
                                           std::vector<std::string>& outList,
                                           std::string& outCurrent) {
    if (!isConnected()) {
        m_impl->m_lastError = "Camera not connected";
        return false;
    }

    // Get valid raw codes from camera
    PropertyDescriptor desc;
    auto res = m_impl->m_facade.getPropertyDescriptor(propId, desc);
    if (!res.ok() || desc.isEmpty()) return false;

    // Read current raw value from cached state
    EdsUInt32 currentRaw = 0;
    if (auto* state = m_impl->m_facade.cameraState()) {
        currentRaw = state->getProperty(propId);
    }

    // Convert each raw code → label
    outList.clear();
    for (EdsInt32 rawSigned : desc.values) {
        auto raw = static_cast<EdsUInt32>(rawSigned);
        std::string label;
        switch (propId) {
        case kEdsPropID_ISOSpeed:            label = isoCodeToLabel(raw); break;
        case kEdsPropID_Tv:                  label = tvCodeToLabel(raw);  break;
        case kEdsPropID_Av:                  label = avCodeToLabel(raw);  break;
        case kEdsPropID_WhiteBalance:        label = wbCodeToLabel(raw);  break;
        case kEdsPropID_ExposureCompensation:label = evCodeToLabel(rawSigned); break;
        default: break;
        }
        if (!label.empty()) outList.push_back(label);
    }

    // Convert current value
    switch (propId) {
    case kEdsPropID_ISOSpeed:            outCurrent = isoCodeToLabel(currentRaw); break;
    case kEdsPropID_Tv:                  outCurrent = tvCodeToLabel(currentRaw);  break;
    case kEdsPropID_Av:                  outCurrent = avCodeToLabel(currentRaw);  break;
    case kEdsPropID_WhiteBalance:        outCurrent = wbCodeToLabel(currentRaw);  break;
    case kEdsPropID_ExposureCompensation:outCurrent = evCodeToLabel(static_cast<EdsInt32>(currentRaw)); break;
    default: outCurrent = std::to_string(currentRaw); break;
    }

    return !outList.empty();
}

} // namespace CameraApp
