#pragma once

/*=============================================================================
 * CameraFacade.h - High-level unified API for camera control
 *
 * Layer: Interface
 * Purpose: Single entry point for all camera operations. Composes all
 *          internal modules and exposes a simple, clean API.
 *          This is what the UI layer interacts with.
 *
 * Architecture:
 *   UI Layer (Qt/MFC/etc.)
 *       │
 *       ▼
 *   CameraFacade  ─── ICameraCallback (events back to UI)
 *       │
 *       ├── CameraManager      (discovery)
 *       ├── CameraDevice       (session lifecycle)
 *       │   ├── CameraState    (state model)
 *       │   └── CameraProperties (property r/w)
 *       ├── CaptureController  (photo capture)
 *       │   └── FileDownloader (file transfer)
 *       ├── LiveViewController (EVF streaming)
 *       └── EventDispatcher    (callback routing)
 *============================================================================*/

#include "../Core/EDSDKContext.h"
#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "../Core/CommandQueue.h"
#include "../Event/EventDispatcher.h"
#include "../Event/IEventListener.h"
#include "../Camera/CameraManager.h"
#include "../Camera/CameraDevice.h"
#include "../Capture/CaptureController.h"
#include "../Capture/FileDownloader.h"
#include "../LiveView/LiveViewController.h"
#include "ICameraCallback.h"

#include <memory>
#include <vector>

namespace CameraApp {

class CameraFacade : public IEventListener {
public:
    CameraFacade() {
        // Start CommandQueue executor thread
        m_commandQueue.start();
        ErrorHandler::log(LogLevel::Debug, "CameraFacade::ctor: CommandQueue started");
    }

    ~CameraFacade() {
        // Stop CommandQueue executor thread
        m_commandQueue.stop();
        shutdown();
    }

    // Non-copyable
    CameraFacade(const CameraFacade&) = delete;
    CameraFacade& operator=(const CameraFacade&) = delete;

    // -----------------------------------------------------------------------
    // Set the UI callback handler
    // -----------------------------------------------------------------------
    void setCallback(ICameraCallback* callback) {
        m_callback = callback;
    }

    // -----------------------------------------------------------------------
    // Set log callback for debug output
    // -----------------------------------------------------------------------
    void setLogCallback(LogCallback callback) {
        ErrorHandler::setLogCallback(std::move(callback));
    }

    // -----------------------------------------------------------------------
    // Initialize SDK
    // -----------------------------------------------------------------------
    Result initialize() {
        auto result = EDSDKContext::instance().initialize();
        if (!result.ok()) return result;

        m_dispatcher.addListener(this);
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // CAMERA DISCOVERY
    // -----------------------------------------------------------------------

    Result enumerateCameras(std::vector<CameraInfo>& outCameras) {
        return m_cameraManager.enumerate(outCameras);
    }

    // -----------------------------------------------------------------------
    // CONNECTION
    // -----------------------------------------------------------------------

    Result connect(const CameraInfo& cameraInfo,
                   SaveTarget saveTarget = SaveTarget::Host) {
        // Clean up previous connection
        disconnect();

        // Create new device
        m_device = std::make_unique<CameraDevice>(cameraInfo, m_dispatcher);
        m_device->setRemoteShutterMode(m_remoteShutterMode);
        auto result = m_device->open(saveTarget);
        if (!result.ok()) {
            m_device.reset();
            return result;
        }

        // Create sub-controllers
        m_downloader = std::make_unique<FileDownloader>(m_dispatcher);
        m_downloader->setSaveDirectory(m_pendingSaveDir); // FIX: Ensure downloader uses configured dir instead of default

        m_capture    = std::make_unique<CaptureController>(*m_device, *m_downloader);
        m_liveView   = std::make_unique<LiveViewController>(*m_device);

        // Wire up CommandQueue to sub-controllers for operation serialization
        m_device->setCommandQueue(&m_commandQueue);
        m_capture->setCommandQueue(&m_commandQueue);
        m_liveView->setCommandQueue(&m_commandQueue);
        ErrorHandler::log(LogLevel::Debug, "CameraFacade::connect: CommandQueue wired to sub-controllers");

        // Notify UI as soon as shutter fires (before USB download starts) so the
        // photobooth can advance to the next countdown without waiting for the file.
        m_capture->setShutterFiredCallback([this]() {
            if (m_callback) m_callback->onShutterFired();
        });

        return Result::Ok();
    }

    Result disconnect() {
        if (m_liveView) {
            m_liveView->stop();
            m_liveView.reset();
        }
        m_capture.reset();
        m_downloader.reset();

        Result result = Result::Ok();
        if (m_device) {
            result = m_device->close();
            m_device.reset();
        }
        return result;
    }

    bool isConnected() const {
        return m_device && m_device->state().isConnected();
    }

    // -----------------------------------------------------------------------
    // CAPTURE
    // -----------------------------------------------------------------------

    Result takePicture() {
        if (!ensureConnected()) return notConnectedError();
        ErrorHandler::dbg("CameraFacade::takePicture", "Thời điểm capture: " + std::to_string(std::chrono::system_clock::now().time_since_epoch().count()));
        return m_capture->takePicture();
    }

    Result takePictureNoAF() {
        if (!ensureConnected()) return notConnectedError();
        return m_capture->takePictureNoAF();
    }

    Result pressShutter(ShutterAction action) {
        if (!ensureConnected()) return notConnectedError();
        return m_capture->pressShutter(action);
    }

    Result autofocus() {
        if (!ensureConnected()) return notConnectedError();
        return m_capture->autofocus();
    }

    Result bulbStart() {
        if (!ensureConnected()) return notConnectedError();
        return m_capture->bulbStart();
    }

    Result bulbEnd() {
        if (!ensureConnected()) return notConnectedError();
        return m_capture->bulbEnd();
    }

    void setSaveDirectory(const std::string& dir) {
        if (m_downloader) {
            m_downloader->setSaveDirectory(dir);
        }
        m_pendingSaveDir = dir;
        ErrorHandler::dbg("CameraFacade::setSaveDirectory", "Thư mục lưu ảnh: " + dir);
    }

    void setAutoDownload(bool enabled) {
        if (m_capture) {
            m_capture->setAutoDownload(enabled);
        }
    }

    void setRemoteShutterMode(bool on) {
        m_remoteShutterMode = on;
        if (m_device) {
            m_device->setRemoteShutterMode(on);
        }
    }

    // -----------------------------------------------------------------------
    // LIVE VIEW
    // -----------------------------------------------------------------------

    Result startLiveView() {
        if (!ensureConnected()) return notConnectedError();

        auto result = m_liveView->start();
        if (result.ok() && m_callback) {
            m_callback->onLiveViewStateChanged(true);
        }
        return result;
    }

    Result stopLiveView() {
        if (!m_liveView) return Result::Ok();

        auto result = m_liveView->stop();
        if (m_callback) {
            m_callback->onLiveViewStateChanged(false);
        }
        return result;
    }

    Result downloadLiveViewFrame(LiveViewFrame& outFrame) {
        if (!ensureConnected() || !m_liveView) return notConnectedError();
        return m_liveView->downloadFrame(outFrame);
    }

    void startLiveViewStreaming() {
        if (!m_liveView) return;

        m_liveView->startStreaming([this](const LiveViewFrame& frame) {
            if (m_callback) {
                m_callback->onLiveViewFrame(
                    frame.data(), frame.dataSize(), frame);
            }
        });
    }

    void stopLiveViewStreaming() {
        if (m_liveView) {
            m_liveView->stopStreaming();
        }
    }

    Result driveLens(FocusDrive direction) {
        if (!m_liveView) return notConnectedError();
        return m_liveView->driveLens(direction);
    }

    Result liveViewAFStart() {
        if (!m_liveView) return notConnectedError();
        return m_liveView->startAF();
    }

    Result liveViewAFStop() {
        if (!m_liveView) return notConnectedError();
        return m_liveView->stopAF();
    }

    Result setLiveViewZoom(EdsUInt32 level) {
        if (!m_liveView) return notConnectedError();
        return m_liveView->setZoom(level);
    }

    // -----------------------------------------------------------------------
    // PROPERTIES
    // -----------------------------------------------------------------------

    Result setTv(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setTv(value);
    }

    Result setAv(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setAv(value);
    }

    Result setIso(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setIso(value);
    }

    Result setWhiteBalance(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setWhiteBalance(value);
    }

    // -----------------------------------------------------------------------
    // Color Temperature (Kelvin) control
    // -----------------------------------------------------------------------
    EdsUInt32 getCurrentColorTemperature() {
        if (!ensureConnected()) return 5200;  // Default daylight
        return m_device->properties().getCurrentColorTemperature();
    }

    std::vector<ColorTemperatureValue> getSupportedColorTemperatures() {
        if (!ensureConnected()) return std::vector<ColorTemperatureValue>();
        return m_device->properties().getSupportedColorTemperatures();
    }

    Result setColorTemperatureByKelvin(EdsUInt32 kelvin) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setColorTemperatureByKelvin(kelvin);
    }

    Result setColorTemperature(ColorTemperature temp) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setColorTemperature(temp);
    }

    Result setMeteringMode(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setMeteringMode(value);
    }

    Result setImageQuality(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setImageQuality(value);
    }

    Result setDriveMode(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setDriveMode(value);
    }

    Result setExposureComp(EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setExposureComp(value);
    }

    Result setProperty(EdsPropertyID propId, EdsUInt32 value) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().setUInt32(propId, value);
    }

    Result getProperty(EdsPropertyID propId, EdsUInt32& outValue) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().getUInt32(propId, outValue);
    }

    Result getPropertyDescriptor(EdsPropertyID propId, PropertyDescriptor& outDesc) {
        if (!ensureConnected()) return notConnectedError();
        return m_device->properties().getDescriptor(propId, outDesc);
    }

    // -----------------------------------------------------------------------
    // STATE ACCESS
    // -----------------------------------------------------------------------

    const CameraState* cameraState() const {
        return m_device ? &m_device->state() : nullptr;
    }

    // -----------------------------------------------------------------------
    // KEEP-ALIVE
    // -----------------------------------------------------------------------

    Result extendShutdownTimer() {
        if (!ensureConnected()) return notConnectedError();
        return m_device->extendShutdownTimer();
    }

    // -----------------------------------------------------------------------
    // SHUTDOWN
    // -----------------------------------------------------------------------

    void shutdown() {
        disconnect();
        m_dispatcher.removeListener(this);
        EDSDKContext::instance().terminate();
    }

private:
    // -----------------------------------------------------------------------
    // IEventListener implementation - routes events to ICameraCallback
    // -----------------------------------------------------------------------
    void onObjectEvent(const ObjectEvent& event) override {
        // Object events handled by CaptureController's transfer handler
    }

    void onPropertyEvent(const PropertyEvent& event) override {
        if (!m_device || !m_callback) return;

        // Filter property events during boot window (first 2 seconds after session open)
        // to avoid triggering redundant reads while camera firmware is initializing
        if (m_device->isBootingUp()) {
            ErrorHandler::dbg("CameraFacade::onPropertyEvent",
                std::string("[Filtered] PropertyEvent propId=") + std::to_string(event.propertyId) +
                " during boot window - skipping redundant property read");
            return;  // Skip redundant reads during boot
        }

        if (event.isValueChanged()) {
            // Re-read the property from camera and update state
            EdsUInt32 value = 0;
            m_device->properties().getUInt32(event.propertyId, value);
            m_callback->onPropertyChanged(event.propertyId, value);
        }
        else if (event.isDescChanged()) {
            PropertyDescriptor desc;
            m_device->properties().getDescriptor(event.propertyId, desc);
            m_callback->onPropertyDescChanged(event.propertyId, desc);
        }
    }

    void onStateEvent(const StateEvent& event) override {
        if (!m_callback) return;

        if (event.isShutdown()) {
            m_callback->onStatusMessage("Camera is shutting down");
            disconnect();
            m_callback->onCameraDisconnected();
        }
        else if (event.isWillShutdown()) {
            // Auto-extend timer to keep camera awake
            extendShutdownTimer();
        }
        else if (event.isCaptureError()) {
            m_callback->onCaptureError(event.stateData,
                ErrorHandler::errorToString(event.stateData));
        }
    }

    void onDownloadProgress(const DownloadProgressEvent& event) override {
        if (!m_callback) return;

        if (event.completed && event.success) {
            DownloadedFile file;
            file.fileName = event.fileName;
            file.success  = true;
            m_callback->onFileDownloaded(file);
        } else {
            m_callback->onDownloadProgress(event.fileName, event.percent);
        }
    }

    void onConnectionChanged(const ConnectionEvent& event) override {
        if (!m_callback) return;

        if (event.connected) {
            m_callback->onCameraConnected(event.cameraName);
        } else {
            m_callback->onCameraDisconnected();
        }
    }

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------
    bool ensureConnected() const {
        return m_device && m_device->isSessionOpen();
    }

    static Result notConnectedError() {
        return Result::FromError(EDS_ERR_SESSION_NOT_OPEN,
                                 "Camera not connected");
    }

    static std::string hexStr(uint32_t val) {
        char buf[16];
        snprintf(buf, sizeof(buf), "%08X", val);
        return buf;
    }

    // -----------------------------------------------------------------------
    // Command Queue accessor for sub-controllers
    // -----------------------------------------------------------------------
    CommandQueue& commandQueue() {
        return m_commandQueue;
    }

    // -----------------------------------------------------------------------
    // Members
    // -----------------------------------------------------------------------
    CommandQueue                            m_commandQueue;
    ICameraCallback*                        m_callback = nullptr;
    EventDispatcher                         m_dispatcher;
    CameraManager                           m_cameraManager;
    std::unique_ptr<CameraDevice>           m_device;
    std::unique_ptr<FileDownloader>          m_downloader;
    std::unique_ptr<CaptureController>       m_capture;
    std::unique_ptr<LiveViewController>      m_liveView;
    std::string                             m_pendingSaveDir = "./image/";
    bool                                    m_remoteShutterMode = false;
};

} // namespace CameraApp
