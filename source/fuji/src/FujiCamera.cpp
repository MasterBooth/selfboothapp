#include "FujiCamera.h"
#include "Logger.h"
#include "MediaRecordPolicy.h"
#include "RuntimeConfig.h"
#include "SdkGuard.h"

static const char* TAG = "FujiCamera";

FujiCamera::FujiCamera(FujiSdkLibrary* lib, XSDK_HANDLE handle, const CameraInfo& info)
    : m_info(info)
{
    m_ctx.lib = lib;
    m_ctx.handle = handle;
    m_downloader = std::make_unique<ImageDownloader>(&m_ctx);
    m_liveView   = std::make_unique<LiveViewWorker>(&m_ctx);
    m_capture    = std::make_unique<CaptureWorker>(&m_ctx);
    m_props      = std::make_unique<PropertyManager>(&m_ctx);

    // Wire the demux out of the poll thread into our public callbacks.
    m_downloader->onLiveFrame = [this](const ImageFrame& f){ if (onLiveFrame) onLiveFrame(f); };
    m_downloader->onStill     = [this](const ImageFrame& f){ if (onImage)     onImage(f);     };
    m_downloader->onError     = [this](CameraError e, const std::string& s){ if (onError) onError(e, s); };
    m_downloader->onDisconnected = [this]{ if (onDisconnected) onDisconnected(); };
}

FujiCamera::~FujiCamera() { close(); }

bool FujiCamera::open() {
    CameraContext::Lock lk(m_ctx.mtx);
    if (!m_ctx.handle) return false;

    applyConfiguredMediaRecord(&m_ctx, TAG);

    // Start the single poll thread now; it stays running for the whole session
    // and carries both live frames and stills.
    Logger::instance().trace(TAG, "open: -> start poll thread");
    m_downloader->start();
    Logger::instance().info(TAG, "session ready: %s (%s)",
                            m_info.model.c_str(), m_info.serial.c_str());
    return true;
}

void FujiCamera::close() {
    // Order matters: stop the poll thread BEFORE Close() so no ReadImage races
    // against the handle being torn down.
    if (m_downloader) m_downloader->stop();
    if (m_liveView && m_liveView->active()) m_liveView->stop();

    CameraContext::Lock lk(m_ctx.mtx);
    if (m_ctx.handle) {
        bool faulted = false;
        sdkGuardL(TAG, "XSDK_Close", faulted, [&]{ return m_ctx.lib->Close(m_ctx.handle); });
        m_ctx.handle = nullptr;   // drop the handle regardless of a fault on close
        Logger::instance().info(TAG, "camera closed");
    }
}

void FujiCamera::setLiveViewOptions(long quality, long size, long mode) {
    m_liveViewQuality = quality;
    m_liveViewSize = size;
    m_liveViewMode = mode;
    const std::string sizeLabel = m_liveViewSize > 0
        ? ("0x" + std::to_string(m_liveViewSize))
        : "native";
    Logger::instance().info(TAG, "live view options quality=0x%lX size=%s mode=0x%lX",
                            m_liveViewQuality,
                            sizeLabel.c_str(),
                            m_liveViewMode);
}

bool FujiCamera::startLiveView() {
    return m_liveView->start(m_liveViewQuality, m_liveViewSize, m_liveViewMode);
}
void FujiCamera::stopLiveView()  { m_liveView->stop(); }

bool FujiCamera::capture() {
    return captureImpl(true);
}

bool FujiCamera::captureNoAf() {
    return captureImpl(false);
}

bool FujiCamera::captureImpl(bool useAf) {
    const bool restartLiveView = m_liveView && m_liveView->active();
    CameraError err = CameraError::None;
    long af = 0;
    bool ok = m_capture->capture(err, af, useAf);
    if (!ok && onError) onError(err, "capture failed");

    if (restartLiveView) {
        if (!m_liveView->start(m_liveViewQuality, m_liveViewSize, m_liveViewMode))
            Logger::instance().warn(TAG, "live view restart after manual capture failed");
    }
    return ok;
}

bool FujiCamera::burst(int frames) {
    CameraError err = CameraError::None;
    bool ok = m_capture->burst(frames, err);
    if (!ok && onError) onError(err, "burst failed");
    return ok;
}

// ------- Exposure properties (delegate to PropertyManager) -------
// int<->long widening is lossless here (all SDK codes fit in 32 bits).

bool FujiCamera::setIso(int iso)      { return m_props->setIso(iso); }
bool FujiCamera::getIso(int& iso) {
    long v = 0;
    if (!m_props->getIso(v)) return false;
    iso = static_cast<int>(v);
    return true;
}

bool FujiCamera::setShutterSpeed(int code, bool bulb) {
    return m_props->setShutterSpeed(code, bulb ? 1 : 0);
}
bool FujiCamera::getShutterSpeed(int& code, bool& bulb) {
    long c = 0, b = 0;
    if (!m_props->getShutterSpeed(c, b)) return false;
    code = static_cast<int>(c);
    bulb = (b != 0);
    return true;
}

bool FujiCamera::setAperture(int fnumberX100) { return m_props->setAperture(fnumberX100); }
bool FujiCamera::getAperture(int& fnumberX100) {
    long v = 0;
    if (!m_props->getAperture(v)) return false;
    fnumberX100 = static_cast<int>(v);
    return true;
}

bool FujiCamera::setExposureBias(int code) { return m_props->setExposureBias(code); }
bool FujiCamera::getExposureBias(int& code) {
    long v = 0;
    if (!m_props->getExposureBias(v)) return false;
    code = static_cast<int>(v);
    return true;
}

bool FujiCamera::setFilmSimulation(int sim) { return m_props->setFilmSimulation(sim); }

// ------- Capability enumeration -------
static std::vector<int> toIntVec(const std::vector<long>& in) {
    std::vector<int> out;
    out.reserve(in.size());
    for (long v : in) out.push_back(static_cast<int>(v));
    return out;
}

std::vector<int> FujiCamera::capIso()          { return toIntVec(m_props->capIso()); }
std::vector<int> FujiCamera::capShutterSpeed() { return toIntVec(m_props->capShutterSpeed()); }
std::vector<int> FujiCamera::capAperture()     { return toIntVec(m_props->capAperture()); }
std::vector<int> FujiCamera::capExposureBias() { return toIntVec(m_props->capExposureBias()); }
