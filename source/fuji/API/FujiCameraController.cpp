#include "API/FujiCameraController.h"

#include "CameraManager.h"
#include "ICamera.h"
#include "Logger.h"
#include "XsdkApi.h"

#include <algorithm>
#include <atomic>
#include <cctype>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <mutex>
#include <sstream>

namespace FujiApp {

namespace fs = std::filesystem;

static const char* frameExtension(ImageFrame::Kind kind)
{
    switch (kind) {
    case ImageFrame::Kind::Jpeg:
    case ImageFrame::Kind::Live:
        return "jpg";
    case ImageFrame::Kind::Raw:
        return "raf";
    case ImageFrame::Kind::Heif:
        return "heic";
    }
    return "bin";
}

uint32_t FujiCameraState::getProperty(uint32_t canonPropId) const
{
    switch (canonPropId) {
    case 0x00000402: return static_cast<uint32_t>(m_iso);
    case 0x00000405: return static_cast<uint32_t>(m_av);
    case 0x00000404: return static_cast<uint32_t>(m_tv);
    case 0x00000106: return static_cast<uint32_t>(m_wb);
    case 0x00000107: return static_cast<uint32_t>(m_colorTemp);
    case 0x00000103: return static_cast<uint32_t>(m_ev);
    default: return 0;
    }
}

class FujiCameraController::Impl {
public:
    bool initialize();
    void shutdown();
    bool findCameras(std::vector<FujiCameraInfo>& outCameras);
    bool connectCamera(int cameraIndex);
    bool disconnectCamera();
    bool isConnected() const;
    bool takePhoto();
    bool takePhotoNoAF();
    bool startLiveView();
    bool stopLiveView();
    bool isLiveViewActive() const;
    void setLiveViewOptions(const std::string& size, const std::string& quality);
    bool startLiveViewStreaming();
    bool stopLiveViewStreaming();
    void setSaveFolder(const std::string& folderPath);
    std::string getSaveFolder() const;
    std::string getLastPhotoPath() const;
    std::string getCameraModel() const;
    std::string getLastError() const;
    const FujiCameraState* getState() const;
    void addEventListener(ICameraEventListener* listener);
    void removeEventListener(ICameraEventListener* listener);
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback);
    void setLogCallback(std::function<void(const std::string&)> callback);
    void setRemoteShutterMode(bool on);
    void setLastError(const std::string& error);

private:
    void notify(CameraEvent event);
    void wireCallbacks(ICamera* camera);
    std::string saveStill(const ImageFrame& frame);

    mutable std::mutex m_mutex;
    std::unique_ptr<CameraManager> m_manager;
    std::unique_ptr<ICamera> m_camera;
    std::vector<FujiCameraInfo> m_detected;
    std::vector<ICameraEventListener*> m_listeners;
    std::function<void(const uint8_t*, size_t)> m_liveViewFrameCallback;
    std::function<void(const std::string&)> m_logCallback;
    FujiCameraState m_state;
    std::string m_saveFolder = "captures";
    std::string m_lastPhotoPath;
    std::string m_cameraModel;
    std::string m_lastError;
    bool m_initialized = false;
    bool m_liveViewActive = false;
    bool m_liveViewStreaming = false;
    bool m_remoteShutterMode = false;
    long m_liveViewQuality = SDK_LIVEVIEW_QUALITY_FINE;
    long m_liveViewSize = 0; // auto/native
    long m_liveViewMode = SDK_LIVEVIEW_MODE1;
    std::atomic<uint64_t> m_savedSeq{0};
};

bool FujiCameraController::Impl::initialize()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_initialized) return true;

    m_manager = std::make_unique<CameraManager>();
    if (!m_manager->initialize(L"XAPI.dll")) {
        setLastError("FUJIFILM X SDK init failed; check XAPI.dll beside BOOTHME.exe");
        m_manager.reset();
        return false;
    }

    m_initialized = true;
    return true;
}

void FujiCameraController::Impl::shutdown()
{
    std::unique_ptr<ICamera> camera;
    std::unique_ptr<CameraManager> manager;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        camera = std::move(m_camera);
        manager = std::move(m_manager);
        m_initialized = false;
        m_liveViewActive = false;
        m_liveViewStreaming = false;
        m_detected.clear();
    }

    if (camera) {
        camera->onLiveFrame = nullptr;
        camera->onImage = nullptr;
        camera->onError = nullptr;
        camera->onDisconnected = nullptr;
        camera->close();
    }
    if (manager) manager->shutdown();
}

bool FujiCameraController::Impl::findCameras(std::vector<FujiCameraInfo>& outCameras)
{
    outCameras.clear();
    if (!initialize()) return false;

    std::vector<std::string> cameras;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        cameras = m_manager ? m_manager->detect(XSDK_DSC_IF_USB) : std::vector<std::string>{};
        m_detected.clear();
        for (size_t i = 0; i < cameras.size(); ++i) {
            FujiCameraInfo info;
            info.name = cameras[i];
            info.portName = "FUJIFILM USB";
            info.index = static_cast<int>(i);
            m_detected.push_back(info);
        }
        outCameras = m_detected;
    }
    return !outCameras.empty();
}

bool FujiCameraController::Impl::connectCamera(int cameraIndex)
{
    if (!initialize()) return false;

    std::unique_ptr<ICamera> camera;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_manager) {
            setLastError("FUJIFILM SDK manager is not initialized");
            return false;
        }
        camera = m_manager->open(cameraIndex);
        if (!camera) {
            setLastError("Failed to open FUJIFILM camera");
            return false;
        }
        CameraInfo info = camera->info();
        m_cameraModel = info.model.empty() ? "FUJIFILM Camera" : info.model;
        wireCallbacks(camera.get());
        camera->setLiveViewOptions(m_liveViewQuality, m_liveViewSize, m_liveViewMode);
        m_camera = std::move(camera);
    }

    CameraEvent event;
    event.type = CameraEventType::Connected;
    event.message = m_cameraModel;
    notify(event);
    return true;
}

bool FujiCameraController::Impl::disconnectCamera()
{
    std::unique_ptr<ICamera> camera;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        camera = std::move(m_camera);
        m_liveViewActive = false;
        m_liveViewStreaming = false;
    }

    if (camera) {
        camera->onLiveFrame = nullptr;
        camera->onImage = nullptr;
        camera->onError = nullptr;
        camera->onDisconnected = nullptr;
        camera->close();
    }

    CameraEvent event;
    event.type = CameraEventType::Disconnected;
    event.message = "FUJIFILM camera disconnected";
    notify(event);
    return true;
}

bool FujiCameraController::Impl::isConnected() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_camera && m_camera->isOpen();
}

bool FujiCameraController::Impl::takePhoto()
{
    ICamera* camera = nullptr;
    bool remoteMode = false;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_camera || !m_camera->isOpen()) {
            setLastError("FUJIFILM camera is not connected");
            Logger::instance().warn("FujiCtrl", "takePhoto rejected connected=false remote=%d",
                                    m_remoteShutterMode ? 1 : 0);
            return false;
        }
        camera = m_camera.get();
        remoteMode = m_remoteShutterMode;
    }

    Logger::instance().info("FujiCtrl", "takePhoto begin connected=true remote=%d",
                            remoteMode ? 1 : 0);
    const bool ok = camera->capture();
    if (!ok) {
        Logger::instance().warn("FujiCtrl", "takePhoto failed remote=%d last_error=%s",
                                remoteMode ? 1 : 0, getLastError().c_str());
        return false;
    }

    Logger::instance().info("FujiCtrl", "takePhoto complete remote=%d", remoteMode ? 1 : 0);
    CameraEvent started;
    started.type = CameraEventType::CaptureStarted;
    started.message = "FUJIFILM shutter fired";
    notify(started);
    return true;
}

bool FujiCameraController::Impl::takePhotoNoAF()
{
    ICamera* camera = nullptr;
    bool remoteMode = false;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_camera || !m_camera->isOpen()) {
            setLastError("FUJIFILM camera is not connected");
            Logger::instance().warn("FujiCtrl", "takePhotoNoAF rejected connected=false remote=%d",
                                    m_remoteShutterMode ? 1 : 0);
            return false;
        }
        camera = m_camera.get();
        remoteMode = m_remoteShutterMode;
    }

    Logger::instance().info("FujiCtrl", "takePhotoNoAF begin connected=true remote=%d",
                            remoteMode ? 1 : 0);
    const bool ok = camera->captureNoAf();
    if (!ok) {
        Logger::instance().warn("FujiCtrl", "takePhotoNoAF failed remote=%d last_error=%s",
                                remoteMode ? 1 : 0, getLastError().c_str());
        return false;
    }

    Logger::instance().info("FujiCtrl", "takePhotoNoAF complete remote=%d", remoteMode ? 1 : 0);
    CameraEvent started;
    started.type = CameraEventType::CaptureStarted;
    started.message = "FUJIFILM shutter fired";
    notify(started);
    return true;
}

void FujiCameraController::Impl::setLiveViewOptions(const std::string& size, const std::string& quality)
{
    auto lower = [](std::string value) {
        std::transform(value.begin(), value.end(), value.begin(),
                       [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
        return value;
    };

    const std::string normalizedSize = lower(size);
    const std::string normalizedQuality = lower(quality);

    long sdkSize = 0;
    if (normalizedSize == "l")
        sdkSize = SDK_LIVEVIEW_SIZE_L;
    else if (normalizedSize == "m")
        sdkSize = SDK_LIVEVIEW_SIZE_M;
    else if (normalizedSize == "s")
        sdkSize = SDK_LIVEVIEW_SIZE_S;

    long sdkQuality = SDK_LIVEVIEW_QUALITY_FINE;
    if (normalizedQuality == "normal")
        sdkQuality = SDK_LIVEVIEW_QUALITY_NORMAL;
    else if (normalizedQuality == "basic")
        sdkQuality = SDK_LIVEVIEW_QUALITY_BASIC;

    ICamera* camera = nullptr;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_liveViewSize = sdkSize;
        m_liveViewQuality = sdkQuality;
        camera = m_camera.get();
    }

    if (camera)
        camera->setLiveViewOptions(m_liveViewQuality, m_liveViewSize, m_liveViewMode);
}

bool FujiCameraController::Impl::startLiveView()
{
    ICamera* camera = nullptr;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (!m_camera || !m_camera->isOpen()) {
            setLastError("FUJIFILM camera is not connected");
            return false;
        }
        camera = m_camera.get();
        camera->setLiveViewOptions(m_liveViewQuality, m_liveViewSize, m_liveViewMode);
    }

    const bool ok = camera->startLiveView();
    if (ok) {
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_liveViewActive = true;
        }
        CameraEvent event;
        event.type = CameraEventType::LiveViewStarted;
        event.message = "FUJIFILM live view started";
        notify(event);
    } else {
        setLastError("Failed to start FUJIFILM live view");
    }
    return ok;
}

bool FujiCameraController::Impl::stopLiveView()
{
    ICamera* camera = nullptr;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        camera = m_camera.get();
    }
    if (camera) camera->stopLiveView();

    {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_liveViewActive = false;
    }

    CameraEvent event;
    event.type = CameraEventType::LiveViewStopped;
    event.message = "FUJIFILM live view stopped";
    notify(event);
    return true;
}

bool FujiCameraController::Impl::isLiveViewActive() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_liveViewActive;
}

bool FujiCameraController::Impl::startLiveViewStreaming()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_liveViewStreaming = true;
    return m_camera && m_camera->isOpen();
}

bool FujiCameraController::Impl::stopLiveViewStreaming()
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_liveViewStreaming = false;
    return true;
}

void FujiCameraController::Impl::setSaveFolder(const std::string& folderPath)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_saveFolder = folderPath.empty() ? "captures" : folderPath;
}

std::string FujiCameraController::Impl::getSaveFolder() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_saveFolder;
}

std::string FujiCameraController::Impl::getLastPhotoPath() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_lastPhotoPath;
}

std::string FujiCameraController::Impl::getCameraModel() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_cameraModel;
}

std::string FujiCameraController::Impl::getLastError() const
{
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_lastError;
}

const FujiCameraState* FujiCameraController::Impl::getState() const
{
    return &m_state;
}

void FujiCameraController::Impl::addEventListener(ICameraEventListener* listener)
{
    if (!listener) return;
    std::lock_guard<std::mutex> lock(m_mutex);
    if (std::find(m_listeners.begin(), m_listeners.end(), listener) == m_listeners.end())
        m_listeners.push_back(listener);
}

void FujiCameraController::Impl::removeEventListener(ICameraEventListener* listener)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_listeners.erase(std::remove(m_listeners.begin(), m_listeners.end(), listener), m_listeners.end());
}

void FujiCameraController::Impl::setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_liveViewFrameCallback = std::move(callback);
}

void FujiCameraController::Impl::setLogCallback(std::function<void(const std::string&)> callback)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_logCallback = std::move(callback);
}

void FujiCameraController::Impl::setRemoteShutterMode(bool on)
{
    std::lock_guard<std::mutex> lock(m_mutex);
    m_remoteShutterMode = on;
}

void FujiCameraController::Impl::setLastError(const std::string& error)
{
    m_lastError = error;
    if (m_logCallback) m_logCallback(error);
}

void FujiCameraController::Impl::notify(CameraEvent event)
{
    std::vector<ICameraEventListener*> listeners;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        listeners = m_listeners;
    }
    for (auto* listener : listeners) {
        if (listener) listener->onCameraEvent(event);
    }
}

void FujiCameraController::Impl::wireCallbacks(ICamera* camera)
{
    camera->onLiveFrame = [this](const ImageFrame& frame) {
        std::function<void(const uint8_t*, size_t)> cb;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            cb = m_liveViewFrameCallback;
        }
        if (cb && !frame.data.empty())
            cb(frame.data.data(), frame.data.size());
    };

    camera->onImage = [this](const ImageFrame& frame) {
        const std::string path = saveStill(frame);
        if (path.empty()) return;

        CameraEvent event;
        event.type = CameraEventType::CaptureCompleted;
        event.message = "FUJIFILM image saved";
        event.fileName = path;
        notify(event);
    };

    camera->onError = [this](CameraError, const std::string& message) {
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            setLastError(message);
        }
        CameraEvent event;
        event.type = CameraEventType::CaptureError;
        event.message = message;
        notify(event);
    };

    camera->onDisconnected = [this] {
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_liveViewActive = false;
            m_liveViewStreaming = false;
        }
        CameraEvent event;
        event.type = CameraEventType::Disconnected;
        event.message = "FUJIFILM camera disconnected";
        notify(event);
    };
}

std::string FujiCameraController::Impl::saveStill(const ImageFrame& frame)
{
    std::string folder;
    {
        std::lock_guard<std::mutex> lock(m_mutex);
        folder = m_saveFolder;
    }

    try {
        fs::path dir = folder.empty() ? fs::path("captures") : fs::path(folder);
        fs::create_directories(dir);

        const auto now = std::chrono::system_clock::now().time_since_epoch();
        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now).count();
        const uint64_t seq = ++m_savedSeq;

        std::ostringstream name;
        name << "fuji_" << ms << "_" << seq << "." << frameExtension(frame.kind);
        fs::path output = dir / name.str();

        std::ofstream stream(output, std::ios::binary);
        if (!stream) {
            std::lock_guard<std::mutex> lock(m_mutex);
            setLastError("Cannot open FUJIFILM output file");
            return {};
        }
        stream.write(reinterpret_cast<const char*>(frame.data.data()), static_cast<std::streamsize>(frame.data.size()));
        if (!stream.good()) {
            std::lock_guard<std::mutex> lock(m_mutex);
            setLastError("Failed writing FUJIFILM output file");
            return {};
        }

        const std::string path = output.string();
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            m_lastPhotoPath = path;
        }
        return path;
    } catch (const std::exception& e) {
        std::lock_guard<std::mutex> lock(m_mutex);
        setLastError(e.what());
    }
    return {};
}

FujiCameraController& FujiCameraController::instance()
{
    static FujiCameraController s;
    return s;
}

FujiCameraController::FujiCameraController()
    : m_impl(std::make_unique<Impl>())
{
}

FujiCameraController::~FujiCameraController() = default;

bool FujiCameraController::initialize() { return m_impl->initialize(); }
void FujiCameraController::shutdown() { m_impl->shutdown(); }
bool FujiCameraController::findCameras(std::vector<FujiCameraInfo>& outCameras) { return m_impl->findCameras(outCameras); }
int FujiCameraController::getCameraCount()
{
    std::vector<FujiCameraInfo> cameras;
    return findCameras(cameras) ? static_cast<int>(cameras.size()) : 0;
}
bool FujiCameraController::connectCamera(int cameraIndex) { return m_impl->connectCamera(cameraIndex); }
bool FujiCameraController::disconnectCamera() { return m_impl->disconnectCamera(); }
bool FujiCameraController::isConnected() const { return m_impl->isConnected(); }
bool FujiCameraController::takePhoto() { return m_impl->takePhoto(); }
bool FujiCameraController::takePhotoNoAF() { return m_impl->takePhotoNoAF(); }
bool FujiCameraController::takeBulbPhoto(int) { return false; }
std::string FujiCameraController::getLastPhotoPath() const { return m_impl->getLastPhotoPath(); }
void FujiCameraController::setAutoDownload(bool) {}
void FujiCameraController::setRemoteShutterMode(bool on) { m_impl->setRemoteShutterMode(on); }
bool FujiCameraController::startLiveView() { return m_impl->startLiveView(); }
bool FujiCameraController::stopLiveView() { return m_impl->stopLiveView(); }
bool FujiCameraController::isLiveViewActive() const { return m_impl->isLiveViewActive(); }
void FujiCameraController::setLiveViewOptions(const std::string& size, const std::string& quality) { m_impl->setLiveViewOptions(size, quality); }
bool FujiCameraController::getLiveViewFrame(LiveViewFrame&) { return false; }
bool FujiCameraController::startLiveViewStreaming() { return m_impl->startLiveViewStreaming(); }
bool FujiCameraController::stopLiveViewStreaming() { return m_impl->stopLiveViewStreaming(); }
bool FujiCameraController::setISO(int) { return false; }
bool FujiCameraController::setShutterSpeed(const std::string&) { return false; }
bool FujiCameraController::setAperture(const std::string&) { return false; }
bool FujiCameraController::setWhiteBalance(int) { return false; }
bool FujiCameraController::setColorTemperature(int) { return false; }
bool FujiCameraController::setMeteringMode(int) { return false; }
bool FujiCameraController::setImageQuality(int) { return false; }
bool FujiCameraController::setDriveMode(int) { return false; }
bool FujiCameraController::setExposureComp(int) { return false; }
bool FujiCameraController::getPropertyStrings(uint32_t, std::vector<std::string>& outList, std::string& outCurrent)
{
    outList.clear();
    outCurrent.clear();
    return false;
}
bool FujiCameraController::setParameters(const CameraApp::CameraParameters&) { return false; }
bool FujiCameraController::getParameters(CameraApp::CameraParameters&) const { return false; }
void FujiCameraController::setSaveFolder(const std::string& folderPath) { m_impl->setSaveFolder(folderPath); }
std::string FujiCameraController::getSaveFolder() const { return m_impl->getSaveFolder(); }
const FujiCameraState* FujiCameraController::getState() const { return m_impl->getState(); }
std::string FujiCameraController::getCameraModel() const { return m_impl->getCameraModel(); }
std::string FujiCameraController::getLastError() const { return m_impl->getLastError(); }
void FujiCameraController::addEventListener(ICameraEventListener* listener) { m_impl->addEventListener(listener); }
void FujiCameraController::removeEventListener(ICameraEventListener* listener) { m_impl->removeEventListener(listener); }
void FujiCameraController::setLogCallback(std::function<void(const std::string&)> callback) { m_impl->setLogCallback(std::move(callback)); }
void FujiCameraController::setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback) { m_impl->setLiveViewFrameCallback(std::move(callback)); }

} // namespace FujiApp
