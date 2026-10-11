// ImageDownloader.h -- the single poll thread that drains the SDK image queue.
//
// Fuji delivers BOTH Live View frames and captured stills through one FIFO:
//     XSDK_ReadImageInfo  -> describes the next item (format, size, dimensions)
//     XSDK_ReadImage      -> copies its bytes and consumes the top item
//     XSDK_DeleteImage    -> drops an unread/bad top item only
// There is exactly ONE such loop in the whole engine. LiveViewWorker only
// toggles Start/StopLiveView; CaptureWorker only fires the shutter. Both of
// their outputs surface HERE, demultiplexed by imgInfo.lFormat.
#pragma once

#include "CameraContext.h"
#include <atomic>
#include <chrono>
#include <functional>
#include <thread>

class ImageDownloader {
public:
    explicit ImageDownloader(CameraContext* ctx) : m_ctx(ctx) {}
    ~ImageDownloader() { stop(); }

    // Demux callbacks (invoked on the poll thread).
    std::function<void(const ImageFrame&)> onLiveFrame;
    std::function<void(const ImageFrame&)> onStill;
    std::function<void(CameraError, const std::string&)> onError;
    std::function<void()> onDisconnected;

    void start();
    void stop();

    // How often to poll when the queue is empty (ms). ~8ms keeps Live View
    // latency low without spinning the CPU.
    void setIdlePollMs(int ms) { m_idleMs = ms; }

private:
    void run();
    bool pumpOnce();   // process at most one queue item; returns true if it did

    CameraContext*    m_ctx;
    std::thread       m_thread;
    std::atomic<bool> m_running{false};
    int               m_idleMs = 8;
    uint64_t          m_seq = 0;
    uint64_t          m_pumps = 0;   // TEMP: pump counter for diagnostic tracing
    uint64_t          m_liveFrameCount = 0;
    std::chrono::steady_clock::time_point m_lastStillTime{};
    int               m_stillBurstCount = 0;
};
