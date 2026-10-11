#pragma once

#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#pragma comment(lib, "gdiplus.lib")

/*=============================================================================
 * LiveViewController.h - Electronic Viewfinder (EVF) streaming control
 *
 * Layer: LiveView
 * Purpose: Manages the Live View lifecycle:
 *          - Start/Stop EVF output to PC
 *          - Download individual JPEG frames with metadata
 *          - Drive lens focus during Live View
 *          - Control EVF autofocus
 *          - Zoom control (Fit / 5x / 10x)
 *
 * Usage pattern:
 *   liveView.start();
 *   while (running) {
 *       LiveViewFrame frame;
 *       if (liveView.downloadFrame(frame).ok()) {
 *           // Render frame.jpegData to screen
 *       }
 *   }
 *   liveView.stop();
 *============================================================================*/

#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "../Camera/CameraDevice.h"

namespace CameraApp {
// Forward declaration
class CommandQueue;
}

#include <atomic>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <functional>
#include <chrono>
#include <sstream>
#include <algorithm>
#include <cstring>

namespace CameraApp {

class LiveViewController {
public:
    // Frame callback - called each time a new frame is available
    using FrameCallback = std::function<void(const LiveViewFrame& frame)>;

    static constexpr EdsUInt64 EVF_BUFFER_SIZE = 2 * 1024 * 1024;  // 2MB

    explicit LiveViewController(CameraDevice& camera)
        : m_camera(camera) {
        ErrorHandler::dbg("LiveViewController::ctor",
            "Created, cameraRef=" + std::to_string((uintptr_t)camera.cameraRef()));
    }

    ~LiveViewController() {
        ErrorHandler::dbg("LiveViewController::dtor", "Destroying, calling stop()");
        stop();
    }

    // -----------------------------------------------------------------------
    // Start Live View output to PC
    // -----------------------------------------------------------------------
    Result start() {
        ErrorHandler::log(LogLevel::Info, "========== LiveViewController::start() CALLED ==========");
        ErrorHandler::dbg("LiveViewController::start",
            "PRE-STATE: isEvfActive=" + std::string(m_camera.state().isEvfActive() ? "Y" : "N") +
            " cameraRef=0x" + toHex((uintptr_t)m_camera.cameraRef()) +
            " sessionOpen=" + std::string(m_camera.isSessionOpen() ? "Y" : "N"));

        if (m_camera.state().isEvfActive()) {
            ErrorHandler::log(LogLevel::Warning, "EVF already active, skipping init");
            return Result::Ok();
        }

        if (!m_camera.isSessionOpen()) {
            ErrorHandler::log(LogLevel::Error, "CANNOT START EVF - session not open!");
            return Result::FromError(EDS_ERR_SESSION_NOT_OPEN, "Session not open");
        }

        // Enable EVF mode
        ErrorHandler::log(LogLevel::Info, "[EVF Step 1] Setting Evf_Mode property to 1");
        EdsUInt32 evfMode = 1;
        auto result = ErrorHandler::executeWithRetry("StartEVF_Mode",
            [&]() -> EdsError {
                return EdsSetPropertyData(
                    m_camera.cameraRef(), kEdsPropID_Evf_Mode,
                    0, sizeof(evfMode), &evfMode);
            });
        if (!result.ok()) {
            ErrorHandler::log(LogLevel::Error,
                "FAILED at Evf_Mode: " + result.message + " (0x" + toHex(result.code) + ")");
            return result;
        }
        ErrorHandler::log(LogLevel::Info, "SUCCESS - Evf_Mode=1");

        // Set output device to PC (add PC bit to current device)
        EdsUInt32 device = m_camera.state().evfOutputDevice();
        ErrorHandler::log(LogLevel::Info,
            "[EVF Step 2] Setting output device: current=0x" + toHex(device) + " -> adding PC bit");
        device |= kEdsEvfOutputDevice_PC;

        result = ErrorHandler::executeWithRetry("StartEVF_Output",
            [&]() -> EdsError {
                return EdsSetPropertyData(
                    m_camera.cameraRef(), kEdsPropID_Evf_OutputDevice,
                    0, sizeof(device), &device);
            });
        if (!result.ok()) {
            ErrorHandler::log(LogLevel::Error,
                "FAILED at Evf_OutputDevice: " + result.message + " (0x" + toHex(result.code) + ")");
            return result;
        }
        ErrorHandler::log(LogLevel::Info, "SUCCESS - OutputDevice=0x" + toHex(device));

        m_camera.state().setEvfActive(true);
        m_camera.state().setEvfOutputDevice(device);

        // Fix A: pre-allocate EVF stream/image buffers for zero-alloc frame loop
        allocateEvfBuffers();

        ErrorHandler::log(LogLevel::Info, "========== LiveView STARTED SUCCESSFULLY ==========");
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Stop Live View
    // -----------------------------------------------------------------------
    Result stop() {
        ErrorHandler::dbg("LiveViewController::stop", "Stop LiveView - stopping streaming first...");
        stopStreaming();  // Stop background thread first (must precede buffer release)
        releaseEvfBuffers();  // Fix A: safe to release now that stream thread is joined

        if (!m_camera.state().isEvfActive()) {
            ErrorHandler::dbg("LiveViewController::stop", "EVF not active, nothing to stop");
            return Result::Ok();
        }

        // Remove PC from output device
        EdsUInt32 device = m_camera.state().evfOutputDevice();
        ErrorHandler::dbg("LiveViewController::stop",
            "Removing PC from outputDevice=0x" + toHex(device));
        device &= ~kEdsEvfOutputDevice_PC;

        auto result = ErrorHandler::executeWithRetry("StopEVF",
            [&]() -> EdsError {
                return EdsSetPropertyData(
                    m_camera.cameraRef(), kEdsPropID_Evf_OutputDevice,
                    0, sizeof(device), &device);
            });

        m_camera.state().setEvfActive(false);
        m_camera.state().setEvfOutputDevice(device);

        ErrorHandler::log(LogLevel::Info, "Live View stopped");
        return result;
    }

    // -----------------------------------------------------------------------
    // Download a single Live View frame (synchronous)
    //
    // Fix A: reuses persistent m_evfStream / m_evfImage (pre-allocated in start()).
    //        Each frame resets the stream write-position with EdsSeek instead of
    //        destroying and recreating a 2 MB buffer.  Falls back to per-frame
    //        allocation when the persistent buffers are not available.
    //
    // Fix B: when called from the streaming loop (m_frameCallback is set) the
    //        JPEG is delivered via outFrame.rawJpegPtr pointing directly into the
    //        EDSDK stream buffer — zero memcpy.  The pointer is valid only for
    //        the synchronous duration of the callback invocation in streamLoop().
    //        For the single-frame path (no callback) the data is still copied
    //        into outFrame.jpegData for backward compatibility.
    // -----------------------------------------------------------------------
    Result downloadFrame(LiveViewFrame& outFrame) {
        // --- Fix A: select persistent vs. per-frame buffers ---
        bool usePersist = (m_evfStream != nullptr && m_evfImage != nullptr);
        EdsStreamRef   workStream   = nullptr;
        EdsEvfImageRef workEvfImage = nullptr;

        if (usePersist) {
            // Reset stream write position to 0 — no reallocation
            EdsError seekErr = EdsSeek(m_evfStream, 0, kEdsSeek_Begin);
            if (seekErr != EDS_ERR_OK) {
                if (m_frameLogCounter++ < 3) {
                    ErrorHandler::log(LogLevel::Warning,
                        "EdsSeek reset failed (0x" + toHex(static_cast<uint32_t>(seekErr)) +
                        "), falling back to per-frame alloc");
                }
                usePersist = false;
            } else {
                workStream   = m_evfStream;
                workEvfImage = m_evfImage;
            }
        }

        if (!usePersist) {
            // Fallback: per-frame allocation (same as original behaviour)
            EdsError err = EdsCreateMemoryStream(EVF_BUFFER_SIZE, &workStream);
            if (err != EDS_ERR_OK) {
                if (m_frameLogCounter++ < 3) {
                    ErrorHandler::log(LogLevel::Error,
                        "EdsCreateMemoryStream FAILED: 0x" + toHex(static_cast<uint32_t>(err)) +
                        " (" + ErrorHandler::errorToString(err) + ")");
                }
                return ErrorHandler::check(err, "EdsCreateMemoryStream(EVF)");
            }
            err = EdsCreateEvfImageRef(workStream, &workEvfImage);
            if (err != EDS_ERR_OK) {
                if (m_frameLogCounter++ < 3) {
                    ErrorHandler::log(LogLevel::Error,
                        "EdsCreateEvfImageRef FAILED: 0x" + toHex(static_cast<uint32_t>(err)) +
                        " (" + ErrorHandler::errorToString(err) + ")");
                }
                EdsRelease(workStream);
                return ErrorHandler::check(err, "EdsCreateEvfImageRef");
            }
        }

        // --- Download the EVF image ---
        Result result;
        if (!m_commandQueue) {
            result = ErrorHandler::executeWithRetry("DownloadEvfImage",
                [&]() -> EdsError {
                    return EdsDownloadEvfImage(m_camera.cameraRef(), workEvfImage);
                });
        } else {
            EdsError evfErr = EDS_ERR_OK;
            std::promise<EdsError> promise;
            auto future = promise.get_future();
            m_commandQueue->enqueue(
                CommandType::EVFDownload,
                CommandPriority::HIGH,
                "EVFDownload(frame #" + std::to_string(m_totalFrames) + ")",
                [&]() -> EdsError {
                    return EdsDownloadEvfImage(m_camera.cameraRef(), workEvfImage);
                },
                [&](EdsError error) {
                    evfErr = error;
                    promise.set_value(error);
            });
            future.wait();
            if (evfErr == EDS_ERR_OBJECT_NOTREADY || evfErr == EDS_ERR_DEVICE_BUSY) {
                result = Result::FromError(evfErr, "EVF frame not ready");
            } else {
                result = ErrorHandler::check(evfErr, "DownloadEvfImage");
            }
        }

        if (!result.ok()) {
            if (result.code != EDS_ERR_OBJECT_NOTREADY
                    && result.code != EDS_ERR_DEVICE_BUSY
                    && m_frameLogCounter++ < 5) {
                ErrorHandler::log(LogLevel::Error,
                    "EdsDownloadEvfImage FAILED (attempt #" + std::to_string(m_totalFrames) + "): " +
                    result.message);
            }
            if (!usePersist) { EdsRelease(workEvfImage); EdsRelease(workStream); }
            return result;
        }

        // --- Get pointer and actual byte count ---
        EdsVoid*  dataPtr = nullptr;
        EdsGetPointer(workStream, &dataPtr);

        // EdsGetPosition == bytes written; EdsGetLength == buffer capacity (2 MB)
        EdsUInt64 length = 0;
        EdsGetPosition(workStream, &length);
        if (length == 0 || length > EVF_BUFFER_SIZE) {
            EdsGetLength(workStream, &length);
        }

        // Log first frames and periodically
        if (m_totalFrames < 3) {
            char ptrHex[32];
            snprintf(ptrHex, sizeof(ptrHex), "0x%p", dataPtr);
            ErrorHandler::log(LogLevel::Debug,
                "Frame #" + std::to_string(m_totalFrames) +
                ": ptr=" + std::string(ptrHex) +
                " size=" + std::to_string(length) + "B" +
                " persist=" + (usePersist ? "Y" : "N"));
        } else if (m_totalFrames % 100 == 0) {
            ErrorHandler::dbg("LiveViewController::downloadFrame",
                "Frame #" + std::to_string(m_totalFrames) + " size=" + std::to_string(length) + "B");
        }

        // --- Extract EVF metadata (workEvfImage still valid at this point) ---
        EdsGetPropertyData(workEvfImage, kEdsPropID_Evf_Zoom,
            0, sizeof(outFrame.zoom), &outFrame.zoom);
        EdsGetPropertyData(workEvfImage, kEdsPropID_Evf_ImagePosition,
            0, sizeof(outFrame.imagePosition), &outFrame.imagePosition);
        EdsGetPropertyData(workEvfImage, kEdsPropID_Evf_ZoomRect,
            0, sizeof(outFrame.zoomRect), &outFrame.zoomRect);
        EdsGetPropertyData(workEvfImage, kEdsPropID_Evf_CoordinateSystem,
            0, sizeof(outFrame.coordinateSystem), &outFrame.coordinateSystem);
        EdsError histErr = EdsGetPropertyData(workEvfImage, kEdsPropID_Evf_Histogram,
            0, sizeof(outFrame.histogram), outFrame.histogram);
        outFrame.histogramValid = (histErr == EDS_ERR_OK);

        // --- Deliver JPEG data ---
        if (dataPtr && length > 0) {
            auto* jpegBytes = static_cast<const uint8_t*>(dataPtr);

            // JPEG header validation
            if (length >= 2 && (jpegBytes[0] != 0xFF || jpegBytes[1] != 0xD8)) {
                char hdr[32];
                snprintf(hdr, sizeof(hdr), "0x%02X 0x%02X", jpegBytes[0], jpegBytes[1]);
                ErrorHandler::log(LogLevel::Warning,
                    "INVALID JPEG HEADER! Expected 0xFF 0xD8, got " + std::string(hdr) +
                    " — frame may be corrupted");
            }

            if (m_frameCallback) {
                // Fix B: streaming path — expose raw EDSDK pointer, zero memcpy.
                // Pointer is valid until the next EdsSeek call at the start of
                // the following downloadFrame() invocation.
                outFrame.rawJpegPtr  = jpegBytes;
                outFrame.rawJpegSize = static_cast<size_t>(length);
            } else {
                // Single-frame download path — copy into jpegData (backward compat)
                outFrame.jpegData.resize(static_cast<size_t>(length));
                memcpy(outFrame.jpegData.data(), dataPtr, static_cast<size_t>(length));
            }
        }

        // --- Cleanup: only release per-frame allocations ---
        // Persistent buffers (m_evfStream / m_evfImage) stay alive until stop()
        if (!usePersist) {
            EdsRelease(workEvfImage);
            EdsRelease(workStream);
        }

        m_totalFrames++;
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Start continuous frame streaming on a background thread
    // -----------------------------------------------------------------------
    void startStreaming(FrameCallback callback) {
        ErrorHandler::dbg("LiveViewController::startStreaming",
            "START - stopping existing stream first...");
        stopStreaming();

        m_frameCallback = std::move(callback);
        m_streaming.store(true);
        m_totalFrames = 0;
        m_frameLogCounter = 0;

        // Ensure GDI+ is initialized process-wide before the first stream thread uses it
        ensureGdiplusInitialized();

        ErrorHandler::dbg("LiveViewController::startStreaming",
            "Launching stream thread with COM init, interval=" +
            std::to_string(m_frameIntervalMs) + "ms");

        m_streamThread = std::thread([this]() {
            ComThreadGuard comGuard;  // COM init for this thread
            ErrorHandler::dbg("LiveViewController::streamThread",
                "Thread started, COM initialized, entering streamLoop");
            streamLoop();
        });
    }

    // -----------------------------------------------------------------------
    // Stop background streaming
    // -----------------------------------------------------------------------
    void stopStreaming() {
        bool wasStreaming = m_streaming.exchange(false);
        if (wasStreaming) {
            ErrorHandler::dbg("LiveViewController::stopStreaming",
                "Signaling stream thread to stop...");
        }
        if (m_streamThread.joinable()) {
            ErrorHandler::dbg("LiveViewController::stopStreaming",
                "Waiting for stream thread to join...");
            m_streamThread.join();
            ErrorHandler::dbg("LiveViewController::stopStreaming", "Thread joined OK");
        }
    }

    bool isStreaming() const { return m_streaming.load(); }

    // -----------------------------------------------------------------------
    // Lens focus drive (during Live View)
    // -----------------------------------------------------------------------
    Result driveLens(FocusDrive direction) {
        ErrorHandler::dbg("LiveViewController::driveLens",
            "direction=" + std::to_string(static_cast<int>(direction)));
        return ErrorHandler::executeWithRetry("DriveLens",
            [&]() -> EdsError {
                return EdsSendCommand(
                    m_camera.cameraRef(),
                    kEdsCameraCommand_DriveLensEvf,
                    static_cast<EdsInt32>(direction));
            });
    }

    // -----------------------------------------------------------------------
    // EVF Autofocus control (with EVF pause synchronization)
    // -----------------------------------------------------------------------
    Result startAF() {
        ErrorHandler::log(LogLevel::Info, "[AF] startAF: BEGIN - requesting EVF pause");

        // Step 1: Signal EVF to pause (set AF state)
        m_afInProgress.store(true);
        m_camera.state().setAfActive(true);

        // Step 2: Wait for EVF to pause (brief delay to ensure download completes)
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        ErrorHandler::log(LogLevel::Debug, "[AF] startAF: EVF paused, sending AF command");

        // Step 3: Execute AF command with REDUCED retries (3 instead of 10)
        EdsError afError = EDS_ERR_OK;
        int afRetries = 0;
        const int MAX_AF_RETRIES = 3;
        const int AF_INITIAL_DELAY_MS = 200;

        for (afRetries = 0; afRetries < MAX_AF_RETRIES; afRetries++) {
            afError = EdsSendCommand(
                m_camera.cameraRef(),
                kEdsCameraCommand_DoEvfAf,
                kEdsCameraCommand_EvfAf_ON);

            if (afError == EDS_ERR_OK) {
                ErrorHandler::log(LogLevel::Debug, "[AF] startAF: Command sent OK (attempt " + std::to_string(afRetries + 1) + ")");
                break;
            }

            if (afError == EDS_ERR_DEVICE_BUSY) {
                ErrorHandler::log(LogLevel::Warning, "[AF] startAF: Device busy (attempt " + std::to_string(afRetries + 1) + "/" + std::to_string(MAX_AF_RETRIES) + ")");
                if (afRetries < MAX_AF_RETRIES - 1) {
                    int delayMs = AF_INITIAL_DELAY_MS * (afRetries + 1);
                    std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
                }
            } else {
                ErrorHandler::log(LogLevel::Error, "[AF] startAF: Command failed with error 0x" + toHex(afError));
                break;
            }
        }

        // Step 4: Wait for AF to complete (typically 100-500ms)
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        ErrorHandler::log(LogLevel::Debug, "[AF] startAF: AF command processing complete");

        // Step 5: Signal EVF to resume
        m_afInProgress.store(false);
        m_camera.state().setAfActive(false);
        m_afCondition.notify_all();

        if (afError == EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Info, "[AF] startAF: SUCCESS (completed in ~100ms)");
            return Result::Ok();
        } else {
            ErrorHandler::log(LogLevel::Error, "[AF] startAF: FAILED with error 0x" + toHex(afError));
            m_camera.state().setAfLastError(afError);
            return Result::FromError(afError, "AF start failed");
        }
    }

    Result stopAF() {
        ErrorHandler::log(LogLevel::Info, "[AF] stopAF: BEGIN - requesting EVF pause");

        // Step 1: Signal EVF to pause
        m_afInProgress.store(true);
        m_camera.state().setAfActive(true);

        // Step 2: Wait for EVF to pause
        std::this_thread::sleep_for(std::chrono::milliseconds(50));
        ErrorHandler::log(LogLevel::Debug, "[AF] stopAF: EVF paused, sending AF command");

        // Step 3: Execute AF command with reduced retries
        EdsError afError = EDS_ERR_OK;
        int afRetries = 0;
        const int MAX_AF_RETRIES = 3;
        const int AF_INITIAL_DELAY_MS = 200;

        for (afRetries = 0; afRetries < MAX_AF_RETRIES; afRetries++) {
            afError = EdsSendCommand(
                m_camera.cameraRef(),
                kEdsCameraCommand_DoEvfAf,
                kEdsCameraCommand_EvfAf_OFF);

            if (afError == EDS_ERR_OK) {
                ErrorHandler::log(LogLevel::Debug, "[AF] stopAF: Command sent OK (attempt " + std::to_string(afRetries + 1) + ")");
                break;
            }

            if (afError == EDS_ERR_DEVICE_BUSY) {
                ErrorHandler::log(LogLevel::Warning, "[AF] stopAF: Device busy (attempt " + std::to_string(afRetries + 1) + "/" + std::to_string(MAX_AF_RETRIES) + ")");
                if (afRetries < MAX_AF_RETRIES - 1) {
                    int delayMs = AF_INITIAL_DELAY_MS * (afRetries + 1);
                    std::this_thread::sleep_for(std::chrono::milliseconds(delayMs));
                }
            } else {
                ErrorHandler::log(LogLevel::Error, "[AF] stopAF: Command failed with error 0x" + toHex(afError));
                break;
            }
        }

        // Step 4: Wait for AF to complete
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
        ErrorHandler::log(LogLevel::Debug, "[AF] stopAF: AF command processing complete");

        // Step 5: Signal EVF to resume
        m_afInProgress.store(false);
        m_camera.state().setAfActive(false);
        m_afCondition.notify_all();

        if (afError == EDS_ERR_OK) {
            ErrorHandler::log(LogLevel::Info, "[AF] stopAF: SUCCESS (completed in ~100ms)");
            return Result::Ok();
        } else {
            ErrorHandler::log(LogLevel::Error, "[AF] stopAF: FAILED with error 0x" + toHex(afError));
            m_camera.state().setAfLastError(afError);
            return Result::FromError(afError, "AF stop failed");
        }
    }

    // -----------------------------------------------------------------------
    // Zoom control
    // -----------------------------------------------------------------------
    Result setZoom(EdsUInt32 zoomLevel) {
        ErrorHandler::dbg("LiveViewController::setZoom",
            "level=" + std::to_string(zoomLevel));
        return m_camera.properties().setUInt32(kEdsPropID_Evf_Zoom, zoomLevel);
    }

    Result setZoomPosition(EdsPoint position) {
        return ErrorHandler::executeWithRetry("SetZoomPosition",
            [&]() -> EdsError {
                return EdsSetPropertyData(
                    m_camera.cameraRef(), kEdsPropID_Evf_ZoomPosition,
                    0, sizeof(position), &position);
            });
    }

    // -----------------------------------------------------------------------
    // Set AF frame position in Live View
    // -----------------------------------------------------------------------
    Result setAFFramePosition(EdsPoint position) {
        return ErrorHandler::executeWithRetry("SetFramePoint",
            [&]() -> EdsError {
                return EdsSetFramePoint(
                    m_camera.cameraRef(), position, true);
            });
    }

    // -----------------------------------------------------------------------
    // Set streaming frame interval (minimum delay between frames)
    // -----------------------------------------------------------------------
    void setFrameIntervalMs(int ms) {
        m_frameIntervalMs = (ms > 0) ? ms : 0;
    }

    // -----------------------------------------------------------------------
    // CommandQueue accessor (set by CameraFacade)
    // -----------------------------------------------------------------------
    void setCommandQueue(CommandQueue* queue) { m_commandQueue = queue; }
    CommandQueue* commandQueue() { return m_commandQueue; }

private:
    // Hex helper
    static std::string toHex(uint32_t val) {
        char buf[16]; snprintf(buf, sizeof(buf), "%08X", val);
        return buf;
    }

    // GDI+ process-wide initialization (call once before first decode attempt)
    static void ensureGdiplusInitialized() {
        // Static local: initialized exactly once per process, safe for concurrent callers
        struct GdiplusInit {
            ULONG_PTR token = 0;
            GdiplusInit() {
                Gdiplus::GdiplusStartupInput input;
                Gdiplus::Status status = Gdiplus::GdiplusStartup(&token, &input, nullptr);
                if (status == Gdiplus::Ok) {
                    ErrorHandler::log(LogLevel::Info, "[GDI+] GdiplusStartup OK (token=" + std::to_string(token) + ")");
                } else {
                    ErrorHandler::log(LogLevel::Error, "[GDI+] GdiplusStartup FAILED status=" + std::to_string((int)status));
                }
            }
            ~GdiplusInit() {
                if (token) {
                    Gdiplus::GdiplusShutdown(token);
                }
            }
        };
        static GdiplusInit s_gdiplusInit;
    }

    // Decode JPEG to HBITMAP (runs in streaming thread)
    static bool decodeJpegToBitmap(const uint8_t* jpegData, size_t jpegSize,
                                   HBITMAP& outBitmap, int& outWidth, int& outHeight) {
        static uint64_t decodeAttempt = 0;
        decodeAttempt++;

        if (!jpegData || jpegSize == 0) {
            ErrorHandler::log(LogLevel::Error,
                "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: null data!");
            return false;
        }

        // **VALIDATION**: Check JPEG magic header (0xFFD8)
        uint8_t byte0 = jpegData[0];
        uint8_t byte1 = (jpegSize > 1) ? jpegData[1] : 0;

        if (jpegSize < 2 || byte0 != 0xFF || byte1 != 0xD8) {
            ErrorHandler::log(LogLevel::Error,
                "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                " FAILED: INVALID JPEG HEADER! size=" + std::to_string(jpegSize) +
                " byte0=0x" + std::to_string((int)byte0) +
                " byte1=0x" + std::to_string((int)byte1) +
                " (expected 0xFFD8)");
            return false;
        }

        // Create COM stream from JPEG bytes
        // **IMPORTANT**: We'll create the HGLOBAL with GMEM_MOVEABLE so it can be relocated
        // This is necessary for CreateStreamOnHGlobal compatibility
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, jpegSize);
        if (!hMem) {
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: GlobalAlloc(" + std::to_string(jpegSize) + " bytes)!");
            }
            return false;
        }

        // Lock the handle to get a pointer
        void* pMem = GlobalLock(hMem);
        if (!pMem) {
            GlobalFree(hMem);
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: GlobalLock!");
            }
            return false;
        }

        // **CRITICAL**: Copy JPEG data into the GLOBAL buffer
        // This buffer will be wrapped in IStream, so must be stable
        memcpy(pMem, jpegData, jpegSize);
        GlobalUnlock(hMem);  // Unlock to allow COM to manage it

        // Create IStream wrapper around the HGLOBAL
        // Second parameter TRUE means IStream owns the handle and will free it
        IStream* pStream = nullptr;
        HRESULT hrStream = CreateStreamOnHGlobal(hMem, TRUE, &pStream);
        if (!SUCCEEDED(hrStream)) {
            GlobalFree(hMem);
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: CreateStreamOnHGlobal(0x" + std::to_string((uint32_t)hrStream) + ")!");
            }
            return false;
        }

        if (!pStream) {
            GlobalFree(hMem);
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: CreateStreamOnHGlobal returned null stream!");
            }
            return false;
        }

        // Decode JPEG using GDI+ (IN STREAMING THREAD - not in paint routine!)
        // **CRITICAL**: This happens in background thread, so GDI+ must be initialized (it is via ComThreadGuard)
        Gdiplus::Image image(pStream);
        Gdiplus::Status status = image.GetLastStatus();
        if (status != Gdiplus::Ok) {
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: GDI+ Image decode error (status=" + std::to_string((int)status) + ")" +
                    " - JPEG data may be invalid or corrupted");
            }
            return false;
        }

        // Get dimensions
        int width = image.GetWidth();
        int height = image.GetHeight();

        if (width <= 0 || height <= 0) {
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: Invalid dimensions " + std::to_string(width) + "x" +
                    std::to_string(height) + " (must be > 0)");
            }
            return false;
        }

        if (decodeAttempt <= 5) {
            ErrorHandler::log(LogLevel::Debug,
                "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                " Image decoded OK: " + std::to_string(width) + "x" + std::to_string(height));
        }

        // Create device context for bitmap creation
        // GetDC(NULL) gets the desktop DC, which we use as a reference
        HDC hdc = GetDC(NULL);
        if (!hdc) {
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: GetDC(NULL)!");
            }
            return false;
        }

        // Create a bitmap compatible with the screen
        // Bitmap dimensions: width x height (in pixels)
        HBITMAP hBitmap = CreateCompatibleBitmap(hdc, width, height);
        if (!hBitmap) {
            ReleaseDC(NULL, hdc);
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: CreateCompatibleBitmap(" + std::to_string(width) + "x" +
                    std::to_string(height) + ")!");
            }
            return false;
        }

        // Create a compatible device context (memory DC) for drawing
        HDC hdcMem = CreateCompatibleDC(hdc);
        if (!hdcMem) {
            DeleteObject(hBitmap);
            ReleaseDC(NULL, hdc);
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: CreateCompatibleDC!");
            }
            return false;
        }

        // Select bitmap into memory DC to make it the current drawing surface
        HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMem, hBitmap);
        if (!hOldBitmap) {
            DeleteObject(hBitmap);
            DeleteDC(hdcMem);
            ReleaseDC(NULL, hdc);
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) + " FAILED: SelectObject!");
            }
            return false;
        }

        // Draw the decoded JPEG image to the bitmap using GDI+
        Gdiplus::Graphics graphics(hdcMem);
        Gdiplus::Status graphicsStatus = graphics.GetLastStatus();
        if (graphicsStatus != Gdiplus::Ok) {
            SelectObject(hdcMem, hOldBitmap);
            DeleteObject(hBitmap);
            DeleteDC(hdcMem);
            ReleaseDC(NULL, hdc);
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: Graphics object status=" + std::to_string((int)graphicsStatus));
            }
            return false;
        }

        // Draw the image to the bitmap
        Gdiplus::Status drawStatus = graphics.DrawImage(&image, 0, 0, width, height);
        if (drawStatus != Gdiplus::Ok) {
            SelectObject(hdcMem, hOldBitmap);
            DeleteObject(hBitmap);
            DeleteDC(hdcMem);
            ReleaseDC(NULL, hdc);
            pStream->Release();
            if (true) {  // Always log decode errors
                ErrorHandler::log(LogLevel::Error,
                    "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                    " FAILED: DrawImage status=" + std::to_string((int)drawStatus));
            }
            return false;
        }

        // Restore old bitmap
        SelectObject(hdcMem, hOldBitmap);

        // Cleanup resources
        DeleteDC(hdcMem);
        ReleaseDC(NULL, hdc);
        pStream->Release();  // IStream will free the HGLOBAL

        // Success! Return bitmap handle
        outBitmap = hBitmap;
        outWidth = width;
        outHeight = height;

        if (decodeAttempt <= 5) {
            ErrorHandler::log(LogLevel::Info,
                "[DecodeJPEG] attempt#" + std::to_string(decodeAttempt) +
                " SUCCESS: Bitmap created " + std::to_string(width) + "x" + std::to_string(height) +
                " pixels, handle=0x" + std::to_string((uintptr_t)hBitmap));
        }

        return true;
    }

    // Background streaming loop
    void streamLoop() {
        ErrorHandler::log(LogLevel::Info,
            "LiveView streaming loop started on thread " + getThreadIdStr() +
            " target_interval=" + std::to_string(m_frameIntervalMs) + "ms");

        int consecutiveErrors = 0;
        int successFrames     = 0;
        int skippedFrames     = 0;
        auto loopStartTime    = std::chrono::high_resolution_clock::now();

        // Fix C: percentile-based, windowed skip-threshold control.
        // Collect download times in a circular buffer; after warmup, compute
        // p90 to use as the frame-skip threshold only — NOT as sleep duration.
        // m_frameIntervalMs (30 ms) stays fixed as the max-FPS cap; since Canon
        // downloads take 40+ ms, the cap rarely fires and adds no artificial delay.
        constexpr int kPerfWindow = 32;          // ~1-2 s of history at 20 fps
        int  dlTimes[kPerfWindow] = {};
        int  dlHead   = 0;
        int  dlFilled = 0;
        int  p90Budget = INT_MAX;  // skip threshold — INT_MAX = no skipping during warmup

        while (m_streaming.load()) {
            auto frameStartTime = std::chrono::high_resolution_clock::now();

            // AF PAUSE: yield while AF command is in progress
            if (m_afInProgress.load()) {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                continue;
            }

            LiveViewFrame frame;
            auto result = downloadFrame(frame);

            // Measure download time (used for skip logic and Fix C)
            auto downloadElapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::high_resolution_clock::now() - frameStartTime).count();

            if (!result.ok()) {
                consecutiveErrors++;
                if (consecutiveErrors == 1 || consecutiveErrors % 50 == 0) {
                    ErrorHandler::log(LogLevel::Warning,
                        "Frame download ERROR #" + std::to_string(consecutiveErrors) +
                        ": " + result.message);
                }
                if (consecutiveErrors > 20) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(100));
                }
                continue;
            }

            consecutiveErrors = 0;

            // Fix C: update rolling window for p90 skip-threshold calculation.
            dlTimes[dlHead] = static_cast<int>(downloadElapsedMs);
            dlHead   = (dlHead + 1) % kPerfWindow;
            if (dlFilled < kPerfWindow) dlFilled++;

            if (dlFilled >= kPerfWindow / 2) {   // wait for half-window warmup
                int sorted[kPerfWindow];
                std::memcpy(sorted, dlTimes, dlFilled * sizeof(int));
                std::sort(sorted, sorted + dlFilled);
                p90Budget = sorted[static_cast<int>(dlFilled * 0.90f)];
                if (successFrames % 100 == 0) {
                    ErrorHandler::dbg("LiveViewController::streamLoop",
                        "Budget FPS: p90_skip=" + std::to_string(p90Budget) +
                        "ms  sleep_cap=" + std::to_string(m_frameIntervalMs) + "ms (fixed)");
                }
            }

            // Deliver JPEG to callback.
            // Fix B: frame.dataSize() returns rawJpegSize when rawJpegPtr is set
            // (no jpegData copy in the streaming path).
            if (frame.dataSize() > 0) {
                // Skip if this download was slower than p90 of recent history.
                // Every 3rd skipped frame is still delivered to prevent display freeze.
                bool isBehind     = (p90Budget != INT_MAX) &&
                                    (downloadElapsedMs > p90Budget);
                bool skipDelivery = isBehind && (skippedFrames % 3 != 2);

                if (skipDelivery) {
                    skippedFrames++;
                } else {
                    if (m_frameCallback) {
                        m_frameCallback(frame);
                    }
                    successFrames++;
                    skippedFrames = 0;

                    if (successFrames == 1) {
                        ErrorHandler::log(LogLevel::Info,
                            "FIRST FRAME delivered: frame#=" + std::to_string(m_totalFrames) +
                            " jpeg_size=" + std::to_string(frame.dataSize()) + " bytes");
                    } else if (successFrames % 100 == 0) {
                        auto totalDuration = std::chrono::duration_cast<std::chrono::seconds>(
                            std::chrono::high_resolution_clock::now() - loopStartTime);
                        float fps = totalDuration.count() > 0
                            ? (float)successFrames / totalDuration.count() : 0.0f;
                        ErrorHandler::dbg("LiveViewController::streamLoop",
                            "Delivered " + std::to_string(successFrames) + " frames" +
                            " avg_fps=" + std::to_string(fps) +
                            " interval=" + std::to_string(m_frameIntervalMs) + "ms");
                    }
                }
            }

            // Deadline-based throttle: sleep only the remaining time to reach
            // the target interval.  If download already took ≥ target time,
            // start the next frame immediately (no artificial delay).
            if (m_frameIntervalMs > 0) {
                auto elapsedMs = std::chrono::duration_cast<std::chrono::milliseconds>(
                    std::chrono::high_resolution_clock::now() - frameStartTime).count();
                int remainingMs = m_frameIntervalMs - static_cast<int>(elapsedMs);
                if (remainingMs > 0) {
                    std::this_thread::sleep_for(std::chrono::milliseconds(remainingMs));
                }
            }
        }

        auto totalDuration = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::high_resolution_clock::now() - loopStartTime);
        float avgFps = totalDuration.count() > 0
            ? (float)successFrames / totalDuration.count() : 0;
        ErrorHandler::log(LogLevel::Info,
            "LiveView streaming STOPPED. Stats:"
            " delivered=" + std::to_string(successFrames) +
            " skipped=" + std::to_string(skippedFrames) +
            " total_downloaded=" + std::to_string(m_totalFrames) +
            " runtime=" + std::to_string(totalDuration.count()) + "s" +
            " avg_fps=" + std::to_string(avgFps));
    }

    static std::string getThreadIdStr() {
        std::stringstream ss;
        ss << std::this_thread::get_id();
        return ss.str();
    }

    // Fix A helpers — allocate / release persistent EVF stream + image ref
    void allocateEvfBuffers() {
        if (!m_evfStream) {
            EdsError err = EdsCreateMemoryStream(EVF_BUFFER_SIZE, &m_evfStream);
            if (err != EDS_ERR_OK) {
                ErrorHandler::log(LogLevel::Warning,
                    "EVF pre-alloc: EdsCreateMemoryStream failed 0x" + toHex(static_cast<uint32_t>(err)));
                m_evfStream = nullptr;
                return;
            }
        }
        if (!m_evfImage) {
            EdsError err = EdsCreateEvfImageRef(m_evfStream, &m_evfImage);
            if (err != EDS_ERR_OK) {
                ErrorHandler::log(LogLevel::Warning,
                    "EVF pre-alloc: EdsCreateEvfImageRef failed 0x" + toHex(static_cast<uint32_t>(err)));
                m_evfImage = nullptr;
                // keep m_evfStream alive; it will be reused if we retry
            }
        }
        if (m_evfStream && m_evfImage) {
            ErrorHandler::log(LogLevel::Info,
                "EVF pre-alloc: persistent stream+image ready (" +
                std::to_string(EVF_BUFFER_SIZE / 1024) + " KB)");
        }
    }

    void releaseEvfBuffers() {
        if (m_evfImage) {
            EdsRelease(m_evfImage);
            m_evfImage = nullptr;
        }
        if (m_evfStream) {
            EdsRelease(m_evfStream);
            m_evfStream = nullptr;
        }
    }

    CameraDevice&                  m_camera;
    FrameCallback                  m_frameCallback;
    std::atomic<bool>              m_streaming{false};
    std::thread                    m_streamThread;
    int                            m_frameIntervalMs = 30;  // ~33 fps max
    uint64_t                       m_totalFrames = 0;
    uint64_t                       m_frameLogCounter = 0;

    // Fix A: persistent EVF buffers — allocated once in start(), released in stop().
    // Reset with EdsSeek per frame instead of create/destroy (saves ~2MB malloc/free/frame).
    EdsStreamRef                   m_evfStream  = nullptr;
    EdsEvfImageRef                 m_evfImage   = nullptr;

    // AF synchronization primitives
    std::mutex                     m_afMutex;
    std::condition_variable        m_afCondition;
    std::atomic<bool>              m_afInProgress{false};

    // CommandQueue for operation serialization (set by CameraFacade)
    CommandQueue*                  m_commandQueue = nullptr;
};

} // namespace CameraApp
