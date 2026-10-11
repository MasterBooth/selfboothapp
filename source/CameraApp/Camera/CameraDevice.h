#pragma once

/*=============================================================================
 * CameraDevice.h - Single camera session and lifecycle management
 *
 * Layer: Camera
 * Purpose: Represents a connected camera. Manages the session lifecycle
 *          (open/close), UI lock, save target, and capacity reporting.
 *          Owns CameraState and CameraProperties for this camera.
 *============================================================================*/

#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "../Event/EventDispatcher.h"
#include "CameraState.h"
#include "CameraProperties.h"

#include <memory>
#include <thread>
#include <chrono>

namespace CameraApp {

// Forward declaration to avoid circular includes
class CommandQueue;

class CameraDevice {
public:
    explicit CameraDevice(const CameraInfo& info, EventDispatcher& dispatcher)
        : m_info(info)
        , m_dispatcher(dispatcher)
        , m_properties(info.ref, m_state,
            [this]() { return this->isBootingUp(); }) {}

    ~CameraDevice() {
        if (m_sessionOpen) {
            close();
        }
    }

    // Non-copyable
    CameraDevice(const CameraDevice&) = delete;
    CameraDevice& operator=(const CameraDevice&) = delete;

    // -----------------------------------------------------------------------
    // Open session - establishes connection with camera
    // -----------------------------------------------------------------------
    Result open(SaveTarget saveTarget = SaveTarget::Host) {
        ErrorHandler::dbg("CameraDevice::open",
            "Kết nối camera='" + m_info.name + "' port='" + m_info.portName +
            "' saveTarget=" + std::to_string(static_cast<int>(saveTarget)));

        if (m_sessionOpen) {
            ErrorHandler::dbg("CameraDevice::open", "Session already open, returning error");
            return Result::FromError(EDS_ERR_SESSION_ALREADY_OPEN,
                                     "Session already open");
        }

        m_state.setConnectionStatus(CameraState::ConnectionStatus::Connecting);

        // Register event callbacks
        ErrorHandler::dbg("CameraDevice::open", "Step 1: Registering event callbacks...");
        auto result = m_dispatcher.registerCallbacks(m_info.ref);
        if (!result.ok()) {
            ErrorHandler::dbg("CameraDevice::open", "FAILED at registerCallbacks: " + result.message);
            m_state.setConnectionStatus(CameraState::ConnectionStatus::Error);
            return result;
        }

        // Open session
        ErrorHandler::dbg("CameraDevice::open", "Step 2: Mở session (EdsOpenSession)...");
        EdsError err = EdsOpenSession(m_info.ref);
        ErrorHandler::dbgResult("CameraDevice::open", "Trạng thái camera trả về từ SDK (EdsOpenSession)", err);
        if (err != EDS_ERR_OK) {
            m_state.setConnectionStatus(CameraState::ConnectionStatus::Error);
            return ErrorHandler::check(err, "EdsOpenSession");
        }

        m_sessionOpen = true;
        m_sessionOpenTime = std::chrono::high_resolution_clock::now();

        // Step 3: Wait for stabilization
        ErrorHandler::dbg("CameraDevice::open",
            "Session opened, waiting 1 second for camera firmware stabilization...");
        std::this_thread::sleep_for(std::chrono::milliseconds(1000));
        auto stabilizeTime = std::chrono::high_resolution_clock::now();
        auto stabilizeMs = std::chrono::duration_cast<std::chrono::milliseconds>(
            stabilizeTime - m_sessionOpenTime).count();
        ErrorHandler::log(LogLevel::Info,
            "Stabilization complete at T+" + std::to_string(stabilizeMs) + "ms");

        if (!m_remoteShutterMode) {
            // Lock UI on camera
            ErrorHandler::dbg("CameraDevice::open", "Step 4: UILock (should succeed immediately now)...");

            // Retry UILock specifically as camera needs time after OpenSession
            err = EDS_ERR_DEVICE_BUSY;
            for (int i = 0; i < 10 && err == EDS_ERR_DEVICE_BUSY; ++i) {
                err = EdsSendStatusCommand(m_info.ref, kEdsCameraStatusCommand_UILock, 0);
                if (err == EDS_ERR_DEVICE_BUSY) {
                    ErrorHandler::dbg("CameraDevice::open", "UILock busy, retry " + std::to_string(i+1));
                    std::this_thread::sleep_for(std::chrono::milliseconds(500));
                }
            }
            ErrorHandler::dbgResult("CameraDevice::open", "UILock", err);
            if (err != EDS_ERR_OK) {
                ErrorHandler::log(LogLevel::Warning, "UILock failed (non-fatal)");
            }
        } else {
            ErrorHandler::dbg("CameraDevice::open",
                "Step 4: UILock skipped for remote shutter mode");
        }

        // Set save destination
        ErrorHandler::dbg("CameraDevice::open", "Step 5: SetSaveTarget...");
        result = m_properties.setSaveTarget(saveTarget);
        if (!result.ok()) {
            ErrorHandler::log(LogLevel::Warning,
                "SetSaveTarget failed: " + result.message);
        }

        // Set host capacity (when saving to PC)
        if (saveTarget == SaveTarget::Host || saveTarget == SaveTarget::Both) {
            ErrorHandler::dbg("CameraDevice::open", "Step 6: SetCapacity...");
            EdsCapacity cap = m_hostCapacity.toEds();
            err = EdsSetCapacity(m_info.ref, cap);
            ErrorHandler::dbgResult("CameraDevice::open", "EdsSetCapacity", err);
            if (err != EDS_ERR_OK) {
                ErrorHandler::log(LogLevel::Warning, "SetCapacity failed");
            }
        }

        // Load current properties and descriptors
        ErrorHandler::dbg("CameraDevice::open", "Step 7: Loading properties...");
        m_properties.loadAllProperties();
        ErrorHandler::dbg("CameraDevice::open", "Step 8: Loading descriptors...");
        m_properties.loadAllDescriptors();

        m_state.setConnectionStatus(CameraState::ConnectionStatus::Connected);

        // Notify listeners
        ConnectionEvent event(true, m_state.modelName());
        m_dispatcher.dispatch(event);

        ErrorHandler::log(LogLevel::Info,
            "Connected to " + m_state.modelName() +
            " (Body: " + m_state.bodyId() + ")");

        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Close session - disconnects from camera
    // -----------------------------------------------------------------------
    Result close() {
        ErrorHandler::dbg("CameraDevice::close", "Đóng session...");
        if (!m_sessionOpen) {
            ErrorHandler::dbg("CameraDevice::close", "Session not open, nothing to close");
            return Result::Ok();
        }

        // Unlock UI
        ErrorHandler::dbg("CameraDevice::close", "UIUnLock...");
        EdsSendStatusCommand(m_info.ref, kEdsCameraStatusCommand_UIUnLock, 0);

        // Close session
        ErrorHandler::dbg("CameraDevice::close", "Đóng session (EdsCloseSession)...");
        EdsError err = EdsCloseSession(m_info.ref);
        ErrorHandler::dbgResult("CameraDevice::close", "Trạng thái camera trả về (EdsCloseSession)", err);
        m_sessionOpen = false;

        m_state.setConnectionStatus(CameraState::ConnectionStatus::Disconnected);

        // Notify listeners
        ConnectionEvent event(false, m_state.modelName());
        m_dispatcher.dispatch(event);

        m_state.reset();

        if (err != EDS_ERR_OK) {
            return ErrorHandler::check(err, "EdsCloseSession");
        }

        ErrorHandler::log(LogLevel::Info, "Camera session closed");
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Send a keep-alive to prevent auto power-off
    // -----------------------------------------------------------------------
    Result extendShutdownTimer() {
        return ErrorHandler::executeWithRetry("ExtendTimer",
            [&]() -> EdsError {
                return EdsSendCommand(
                    m_info.ref,
                    kEdsCameraCommand_ExtendShutDownTimer, 0);
            });
    }

    // -----------------------------------------------------------------------
    // Accessors
    // -----------------------------------------------------------------------
    EdsCameraRef       cameraRef() const   { return m_info.ref; }
    const CameraInfo&  info() const        { return m_info; }
    CameraState&       state()             { return m_state; }
    const CameraState& state() const       { return m_state; }
    CameraProperties&  properties()        { return m_properties; }
    EventDispatcher&   dispatcher()        { return m_dispatcher; }
    bool               isSessionOpen() const { return m_sessionOpen; }

    void setHostCapacity(const HostCapacity& cap) { m_hostCapacity = cap; }

    void setRemoteShutterMode(bool on) {
        m_remoteShutterMode = on;
        if (!m_sessionOpen) return;

        EdsError err = EdsSendStatusCommand(
            m_info.ref,
            on ? kEdsCameraStatusCommand_UIUnLock
               : kEdsCameraStatusCommand_UILock,
            0);
        ErrorHandler::dbgResult(
            "CameraDevice::setRemoteShutterMode",
            on ? "UIUnLock" : "UILock",
            err);
        if (err != EDS_ERR_OK) {
            ErrorHandler::log(
                LogLevel::Warning,
                std::string("Failed to ") + (on ? "unlock" : "lock")
                    + " camera UI for remote shutter mode (non-fatal)");
        }
    }

    void setCommandQueue(CommandQueue* queue) {
        m_commandQueue = queue;
        // Also wire to CameraProperties for operation serialization
        if (m_commandQueue) {
            m_properties.setCommandQueue(queue);
        }
    }

    CommandQueue* commandQueue() { return m_commandQueue; }

    // -----------------------------------------------------------------------
    // Boot window detection (2 seconds after session open)
    // -----------------------------------------------------------------------
    bool isBootingUp() const {
        if (!m_sessionOpen) return false;
        auto elapsed = std::chrono::high_resolution_clock::now() - m_sessionOpenTime;
        return elapsed < std::chrono::milliseconds(2000);
    }

private:
    CameraInfo        m_info;
    EventDispatcher&  m_dispatcher;
    CameraState       m_state;
    CameraProperties  m_properties;
    HostCapacity      m_hostCapacity;
    CommandQueue*     m_commandQueue = nullptr;  // Set by CameraFacade
    bool              m_sessionOpen = false;
    bool              m_remoteShutterMode = false;
    std::chrono::high_resolution_clock::time_point m_sessionOpenTime;
};

} // namespace CameraApp
