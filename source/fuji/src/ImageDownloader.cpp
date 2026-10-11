#include "ImageDownloader.h"
#include "Logger.h"
#include "SdkGuard.h"
#include <chrono>

// Reject an absurd frame size before we resize() a multi-GB buffer. A healthy
// still is well under this; anything larger means a corrupt lDataSize.
static constexpr long kMaxFrameBytes = 256 * 1024 * 1024;  // 256 MB

static const char* TAG = "Downloader";

static const char* frameKindName(ImageFrame::Kind kind) {
    switch (kind) {
        case ImageFrame::Kind::Live: return "live";
        case ImageFrame::Kind::Jpeg: return "jpeg";
        case ImageFrame::Kind::Raw:  return "raw";
        case ImageFrame::Kind::Heif: return "heif";
    }
    return "unknown";
}

void ImageDownloader::start() {
    if (m_running.exchange(true)) return;
    m_thread = std::thread(&ImageDownloader::run, this);
}

void ImageDownloader::stop() {
    if (!m_running.exchange(false)) return;
    if (m_thread.joinable()) m_thread.join();
}

void ImageDownloader::run() {
    Logger::instance().info(TAG, "poll thread started");
    while (m_running.load()) {
        bool processed = pumpOnce();
        if (!processed)
            std::this_thread::sleep_for(std::chrono::milliseconds(m_idleMs));
    }
    Logger::instance().info(TAG, "poll thread stopped");
}

bool ImageDownloader::pumpOnce() {
    FujiSdkLibrary* lib = m_ctx->lib;
    XSDK_ImageInformation info{};
    info.lFormat = XSDK_IMAGEFORMAT_NONE;

    // Whole read transaction under one lock (see CameraContext note).
    CameraContext::Lock lk(m_ctx->mtx);
    if (!m_ctx->handle) return false;

    // TEMP trace: pinpoint the exact SDK call if the poll thread faults.
    if (m_pumps < 5) Logger::instance().trace(TAG, "pump #%llu: -> ReadImageInfo",
                                               static_cast<unsigned long long>(m_pumps));
    ++m_pumps;

    bool faulted = false;
    long info_rc = sdkGuardL(TAG, "ReadImageInfo", faulted,
                             [&]{ return lib->ReadImageInfo(m_ctx->handle, &info); });
    if (faulted) { if (onDisconnected) onDisconnected(); return false; }

    if (info_rc != XSDK_COMPLETE) {
        long api = 0, err = 0;
        CameraError ce = m_ctx->lastError(&api, &err);
        // A communication error here means the cable was pulled / camera slept.
        if (ce == CameraError::Communication) {
            Logger::instance().error(TAG, "communication lost during ReadImageInfo");
            if (onDisconnected) onDisconnected();
        }
        return false;
    }

    // Low byte holds the base format; high byte carries rotation (0x06/0x03/0x08).
    long base = info.lFormat & 0x00FF;
    if (base == XSDK_IMAGEFORMAT_NONE) return false;   // queue empty

    Logger::instance().trace(TAG, "pump: format=0x%lX size=%ld %ldx%ld",
                             info.lFormat, info.lDataSize,
                             info.lImagePixWidth, info.lImagePixHeight);

    // Drop items that report no / absurd payload; still pop them so the queue
    // never stalls the camera-side buffer.
    if (info.lDataSize <= 0 || info.lDataSize > kMaxFrameBytes) {
        if (info.lDataSize > kMaxFrameBytes)
            Logger::instance().warn(TAG, "dropping frame with implausible size %ld", info.lDataSize);
        sdkGuardL(TAG, "DeleteImage", faulted, [&]{ return lib->DeleteImage(m_ctx->handle); });
        if (faulted) { if (onDisconnected) onDisconnected(); return false; }
        return true;
    }

    ImageFrame frame;
    frame.width  = info.lImagePixWidth;
    frame.height = info.lImagePixHeight;
    frame.seq    = ++m_seq;
    frame.data.resize(static_cast<size_t>(info.lDataSize));

    long rc = sdkGuardL(TAG, "ReadImage", faulted,
                        [&]{ return lib->ReadImage(m_ctx->handle, frame.data.data(),
                                                   static_cast<unsigned long>(info.lDataSize)); });
    if (faulted) { if (onDisconnected) onDisconnected(); return false; }
    if (rc != XSDK_COMPLETE) {
        m_ctx->lastError();
        sdkGuardL(TAG, "DeleteImage", faulted, [&]{ return lib->DeleteImage(m_ctx->handle); });
        if (faulted) { if (onDisconnected) onDisconnected(); return false; }
        return true;                       // still popped so the queue drains
    }

    // Always DeleteImage after a successful read to free the camera-side slot;
    // failing to do so eventually returns XSDK_ERRCODE_FRAME_FULL.
    sdkGuardL(TAG, "DeleteImage", faulted, [&]{ return lib->DeleteImage(m_ctx->handle); });
    if (faulted) { if (onDisconnected) onDisconnected(); return false; }

    switch (base) {
        case XSDK_IMAGEFORMAT_LIVE:
            frame.kind = ImageFrame::Kind::Live;
            ++m_liveFrameCount;
            if (m_liveFrameCount == 1 || (m_liveFrameCount % 150) == 0) {
                Logger::instance().info(TAG, "live frame #%llu %ldx%ld bytes=%zu",
                                        static_cast<unsigned long long>(m_liveFrameCount),
                                        info.lImagePixWidth, info.lImagePixHeight,
                                        frame.data.size());
            }
            if (onLiveFrame) onLiveFrame(frame);
            break;
        case XSDK_IMAGEFORMAT_JPEG:
            frame.kind = ImageFrame::Kind::Jpeg;
            {
                const auto now = std::chrono::steady_clock::now();
                if (m_lastStillTime.time_since_epoch().count() != 0 &&
                    now - m_lastStillTime <= std::chrono::seconds(1)) {
                    ++m_stillBurstCount;
                } else {
                    m_stillBurstCount = 1;
                }
                m_lastStillTime = now;
                Logger::instance().info(TAG, "still received kind=%s bytes=%zu burst=%d",
                                        frameKindName(frame.kind), frame.data.size(), m_stillBurstCount);
            }
            if (onStill) onStill(frame);
            break;
        case XSDK_IMAGEFORMAT_RAW:
            frame.kind = ImageFrame::Kind::Raw;
            {
                const auto now = std::chrono::steady_clock::now();
                if (m_lastStillTime.time_since_epoch().count() != 0 &&
                    now - m_lastStillTime <= std::chrono::seconds(1)) {
                    ++m_stillBurstCount;
                } else {
                    m_stillBurstCount = 1;
                }
                m_lastStillTime = now;
                Logger::instance().info(TAG, "still received kind=%s bytes=%zu burst=%d",
                                        frameKindName(frame.kind), frame.data.size(), m_stillBurstCount);
            }
            if (onStill) onStill(frame);
            break;
        case XSDK_IMAGEFORMAT_HEIF:
            frame.kind = ImageFrame::Kind::Heif;
            {
                const auto now = std::chrono::steady_clock::now();
                if (m_lastStillTime.time_since_epoch().count() != 0 &&
                    now - m_lastStillTime <= std::chrono::seconds(1)) {
                    ++m_stillBurstCount;
                } else {
                    m_stillBurstCount = 1;
                }
                m_lastStillTime = now;
                Logger::instance().info(TAG, "still received kind=%s bytes=%zu burst=%d",
                                        frameKindName(frame.kind), frame.data.size(), m_stillBurstCount);
            }
            if (onStill) onStill(frame);
            break;
        default:
            break;
    }
    return true;
}
