#pragma once

/*=============================================================================
 * CaptureController.h - Photo capture control
 *
 * Layer: Capture
 * Purpose: Orchestrates the photo capture workflow:
 *          1. Send shutter command to camera
 *          2. Wait for DirItemRequestTransfer callback
 *          3. Download the captured image via FileDownloader
 *
 *          Supports: single shot, press-and-hold shutter, bulb mode.
 *============================================================================*/

#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "../Camera/CameraDevice.h"
#include "FileDownloader.h"

#include <functional>
#include <future>

namespace CameraApp {

// Forward declaration
class CommandQueue;

class CaptureController {
public:
    CaptureController(CameraDevice& camera, FileDownloader& downloader)
        : m_camera(camera), m_downloader(downloader)
    {
        ErrorHandler::dbg("CaptureController::ctor",
            "Registering transfer request handler on dispatcher");
        // Register auto-download handler for transfer requests
        m_camera.dispatcher().setTransferRequestHandler(
            [this](EdsBaseRef objectRef) {
                onTransferRequest(objectRef);
            });
    }

    ~CaptureController() {
        ErrorHandler::dbg("CaptureController::dtor", "Unregistering transfer handler");
        m_camera.dispatcher().setTransferRequestHandler(nullptr);
    }

    // -----------------------------------------------------------------------
    // Take a single picture (AF -> capture -> release)
    // The image will be auto-downloaded via the transfer callback.
    // -----------------------------------------------------------------------
    Result takePicture() {
        ErrorHandler::log(LogLevel::Info, "========== CaptureController::takePicture() START ==========");
        ErrorHandler::log(LogLevel::Debug,
            "PRE-STATE: autoDownload=" + std::string(m_autoDownload ? "Y" : "N") +
            " cameraRef=0x" + std::to_string((uintptr_t)m_camera.cameraRef()));

        // Press shutter completely (includes AF)
        ErrorHandler::log(LogLevel::Info, "[Capture Step 1] Sending PressShutterButton COMPLETELY (with AF)");
        auto result = pressShutter(ShutterAction::Completely);
        if (!result.ok()) {
            ErrorHandler::log(LogLevel::Error,
                "FAILED at ShutterButton_Completely: " + result.message + " (0x" +
                std::to_string(result.code) + ")");
            return result;
        }
        ErrorHandler::log(LogLevel::Info, "SUCCESS - Shutter pressed completely");

        ErrorHandler::log(LogLevel::Info, "[Capture Step 2] Releasing shutter (ShutterButton OFF)");
        // Release shutter
        result = pressShutter(ShutterAction::Off);
        if (!result.ok()) {
            ErrorHandler::log(LogLevel::Error,
                "FAILED at ShutterButton_Off: " + result.message);
        } else {
            ErrorHandler::log(LogLevel::Info,
                "SUCCESS - Shutter released. NOW WAITING FOR TRANSFER CALLBACK FROM CAMERA...");
        }
        return result;
    }

    // -----------------------------------------------------------------------
    // Take picture without auto-focus
    // -----------------------------------------------------------------------
    Result takePictureNoAF() {
        ErrorHandler::dbg("CaptureController::takePictureNoAF",
            "START - Sending ShutterButton_Completely_NonAF");
        auto result = pressShutter(ShutterAction::CompletelyNoAF);
        if (!result.ok()) {
            ErrorHandler::dbg("CaptureController::takePictureNoAF",
                "FAILED at CompletelyNoAF: " + result.message);
            return result;
        }
        ErrorHandler::dbg("CaptureController::takePictureNoAF",
            "Sending ShutterButton_Off");
        return pressShutter(ShutterAction::Off);
    }

    // -----------------------------------------------------------------------
    // Shutter button control (for half-press, full-press, release)
    // -----------------------------------------------------------------------
    Result pressShutter(ShutterAction action) {
        ErrorHandler::dbg("CaptureController::pressShutter",
            "Lệnh chụp được gửi (action=" + std::to_string(static_cast<int>(action)) +
            " cameraRef=" + std::to_string((uintptr_t)m_camera.cameraRef()) + ")");

        if (!m_commandQueue) {
            // Fallback to direct retry without queue
            auto res = ErrorHandler::executeWithRetry("PressShutter",
                [&]() -> EdsError {
                    return EdsSendCommand(
                        m_camera.cameraRef(),
                        kEdsCameraCommand_PressShutterButton,
                        static_cast<EdsInt32>(action));
                });
            ErrorHandler::dbg("CaptureController::pressShutter", "Camera phản hồi: " + res.message);
            return res;
        }

        // Use CommandQueue with CRITICAL priority for capture operations
        EdsError result = EDS_ERR_OK;
        std::promise<EdsError> promise;
        auto future = promise.get_future();

        m_commandQueue->enqueue(
            CommandType::Capture,
            CommandPriority::CRITICAL,
            "PressShutter(action=" + std::to_string(static_cast<int>(action)) + ")",
            [this, action]() -> EdsError {
                return EdsSendCommand(
                    m_camera.cameraRef(),
                    kEdsCameraCommand_PressShutterButton,
                    static_cast<EdsInt32>(action));
            },
            [&](EdsError err) {
                result = err;
                promise.set_value(err);
            });

        future.wait();
        ErrorHandler::dbg("CaptureController::pressShutter", "Queue result: " + ErrorHandler::check(result, "PressShutter").message);
        return ErrorHandler::check(result, "PressShutter");
    }

    // -----------------------------------------------------------------------
    // Half-press shutter (AF only, no capture)
    // -----------------------------------------------------------------------
    Result autofocus() {
        ErrorHandler::dbg("CaptureController::autofocus", "START - Half-press");
        auto result = pressShutter(ShutterAction::Halfway);
        if (!result.ok()) return result;

        // Keep half-pressed briefly for AF to acquire
        std::this_thread::sleep_for(std::chrono::milliseconds(500));
        return pressShutter(ShutterAction::Off);
    }

    // -----------------------------------------------------------------------
    // Bulb mode control (with CommandQueue if available)
    // -----------------------------------------------------------------------
    Result bulbStart() {
        ErrorHandler::dbg("CaptureController::bulbStart", "START");

        if (!m_commandQueue) {
            return ErrorHandler::executeWithRetry("BulbStart",
                [&]() -> EdsError {
                    return EdsSendCommand(
                        m_camera.cameraRef(),
                        kEdsCameraCommand_BulbStart, 0);
                });
        }

        EdsError result = EDS_ERR_OK;
        std::promise<EdsError> promise;
        auto future = promise.get_future();

        m_commandQueue->enqueue(
            CommandType::Capture,
            CommandPriority::CRITICAL,
            "BulbStart",
            [this]() -> EdsError {
                return EdsSendCommand(
                    m_camera.cameraRef(),
                    kEdsCameraCommand_BulbStart, 0);
            },
            [&](EdsError err) {
                result = err;
                promise.set_value(err);
            });

        future.wait();
        return ErrorHandler::check(result, "BulbStart");
    }

    Result bulbEnd() {
        ErrorHandler::dbg("CaptureController::bulbEnd", "END");

        if (!m_commandQueue) {
            return ErrorHandler::executeWithRetry("BulbEnd",
                [&]() -> EdsError {
                    return EdsSendCommand(
                        m_camera.cameraRef(),
                        kEdsCameraCommand_BulbEnd, 0);
                });
        }

        EdsError result = EDS_ERR_OK;
        std::promise<EdsError> promise;
        auto future = promise.get_future();

        m_commandQueue->enqueue(
            CommandType::Capture,
            CommandPriority::CRITICAL,
            "BulbEnd",
            [this]() -> EdsError {
                return EdsSendCommand(
                    m_camera.cameraRef(),
                    kEdsCameraCommand_BulbEnd, 0);
            },
            [&](EdsError err) {
                result = err;
                promise.set_value(err);
            });

        future.wait();
        return ErrorHandler::check(result, "BulbEnd");
    }

    // -----------------------------------------------------------------------
    // Enable/disable auto-download after capture
    // -----------------------------------------------------------------------
    void setAutoDownload(bool enabled) { m_autoDownload = enabled; }
    bool isAutoDownload() const { return m_autoDownload; }

    // -----------------------------------------------------------------------
    // CommandQueue accessor (set by CameraFacade)
    // -----------------------------------------------------------------------
    void setCommandQueue(CommandQueue* queue) { m_commandQueue = queue; }
    CommandQueue* commandQueue() { return m_commandQueue; }

    // -----------------------------------------------------------------------
    // Shutter-fired callback — fires as soon as the camera reports a transfer
    // request (before USB download starts). Lets the UI start the next
    // countdown immediately instead of waiting for the full file download.
    // -----------------------------------------------------------------------
    void setShutterFiredCallback(std::function<void()> cb) {
        m_shutterFiredCallback = std::move(cb);
    }

    // -----------------------------------------------------------------------
    // Get the last downloaded file info
    // -----------------------------------------------------------------------
    const DownloadedFile& lastDownload() const { return m_lastDownload; }

private:
    // Called by EventDispatcher when camera signals a file is ready.
    // Must return quickly — runs on the EDSDK callback thread (= main/UI thread on
    // Windows when Qt pumps Windows messages).  Blocking here freezes the UI for
    // the full USB-transfer duration (1-3 s).  Instead we enqueue the download on
    // the CommandQueue executor thread so the callback returns immediately.
    void onTransferRequest(EdsBaseRef objectRef) {
        ErrorHandler::log(LogLevel::Info,
            "========== CaptureController::onTransferRequest() FIRED ==========");
        ErrorHandler::log(LogLevel::Debug,
            "objectRef=0x" + std::to_string((uintptr_t)objectRef) +
            " autoDownload=" + std::string(m_autoDownload ? "Y" : "N"));

        if (!m_autoDownload) {
            ErrorHandler::log(LogLevel::Warning,
                "Auto-download is DISABLED, cancelling transfer");
            EdsDownloadCancel(static_cast<EdsDirectoryItemRef>(objectRef));
            EdsRelease(objectRef);
            return;
        }

        // Notify UI immediately — shutter confirmed, USB download is about to start.
        // This lets the photobooth start the next countdown without waiting for the
        // full file transfer (1-3 s on slow machines).
        if (m_shutterFiredCallback) {
            m_shutterFiredCallback();
        }

        auto dirItem = static_cast<EdsDirectoryItemRef>(objectRef);

        if (m_commandQueue) {
            // Async path: enqueue with CRITICAL priority so it runs before any
            // property-set commands and returns immediately to the caller.
            // The EdsDirectoryItemRef stays valid until EdsDownload/EdsDownloadCancel
            // is called, so it is safe to pass to the executor thread.
            ErrorHandler::log(LogLevel::Info,
                "Queueing file download on executor thread (async, non-blocking)...");
            m_commandQueue->enqueue(
                CommandType::FileDownload,
                CommandPriority::CRITICAL,
                "FileDownload",
                [this, dirItem]() -> EdsError {
                    auto result = m_downloader.download(dirItem, m_lastDownload);
                    if (!result.ok()) {
                        ErrorHandler::log(LogLevel::Error,
                            "Download FAILED: " + result.message +
                            " (0x" + std::to_string(result.code) + ")");
                    } else {
                        ErrorHandler::log(LogLevel::Info,
                            "Download COMPLETE: " + m_lastDownload.fileName +
                            " size=" + std::to_string(m_lastDownload.fileSize) + " bytes" +
                            " saved_to=" + m_lastDownload.localPath);
                    }
                    return result.ok() ? EDS_ERR_OK : static_cast<EdsError>(result.code);
                });
        } else {
            // Sync fallback (no CommandQueue — should not happen in normal flow)
            ErrorHandler::log(LogLevel::Warning,
                "CommandQueue unavailable — downloading synchronously (may block UI)");
            auto result = m_downloader.download(dirItem, m_lastDownload);
            if (!result.ok()) {
                ErrorHandler::log(LogLevel::Error,
                    "Download FAILED: " + result.message +
                    " (0x" + std::to_string(result.code) + ")");
            } else {
                ErrorHandler::log(LogLevel::Info,
                    "Download COMPLETE: " + m_lastDownload.fileName);
            }
        }
    }

    CameraDevice&    m_camera;
    FileDownloader&  m_downloader;
    DownloadedFile   m_lastDownload;
    CommandQueue*    m_commandQueue = nullptr;
    bool             m_autoDownload = true;
    std::function<void()> m_shutterFiredCallback;
};

} // namespace CameraApp
