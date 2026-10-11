#pragma once

/*=============================================================================
 * EventDispatcher.h - Bridges EDSDK C callbacks to C++ event listeners
 *
 * Layer: Event
 * Purpose: Registers as the EDSDK callback handler. When the SDK fires
 *          a callback, this class translates it into typed CameraEvent
 *          objects and dispatches them to all registered IEventListeners.
 *
 * Thread safety: EDSDK callbacks fire on SDK's internal thread.
 *                Listeners must handle their own thread synchronization.
 *============================================================================*/

#include "IEventListener.h"
#include "../Core/ErrorHandler.h"

#include <vector>
#include <mutex>
#include <algorithm>
#include <functional>
#include <sstream>

namespace CameraApp {

class EventDispatcher {
public:
    // -----------------------------------------------------------------------
    // Listener management
    // -----------------------------------------------------------------------
    void addListener(IEventListener* listener) {
        std::lock_guard<std::mutex> lock(m_mutex);
        if (std::find(m_listeners.begin(), m_listeners.end(), listener)
            == m_listeners.end()) {
            m_listeners.push_back(listener);
            ErrorHandler::dbg("EventDispatcher::addListener", "Event được đăng ký (listener=" + ptrStr(listener) + ")");
        }
    }

    void removeListener(IEventListener* listener) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_listeners.erase(
            std::remove(m_listeners.begin(), m_listeners.end(), listener),
            m_listeners.end());
        ErrorHandler::dbg("EventDispatcher::removeListener", "Event được huỷ (listener=" + ptrStr(listener) + ")");
    }

    // -----------------------------------------------------------------------
    // Set callback to handle object events internally (e.g., auto-download)
    // This is separate from listeners - used by CaptureController
    // -----------------------------------------------------------------------
    using ObjectEventCallback = std::function<void(EdsBaseRef objectRef)>;

    void setTransferRequestHandler(ObjectEventCallback handler) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_transferHandler = std::move(handler);
    }

    // -----------------------------------------------------------------------
    // Register EDSDK callbacks for a camera reference
    // -----------------------------------------------------------------------
    Result registerCallbacks(EdsCameraRef camera) {
        ErrorHandler::dbg("EventDispatcher::registerCallbacks",
            "Registering all EDSDK callbacks for camera ref=" + ptrStr(camera));
        EdsError err;

        err = EdsSetObjectEventHandler(
            camera, kEdsObjectEvent_All,
            &EventDispatcher::handleObjectEvent, this);
        ErrorHandler::dbgResult("EventDispatcher", "SetObjectEventHandler", err);
        if (err != EDS_ERR_OK)
            return ErrorHandler::check(err, "EdsSetObjectEventHandler");

        err = EdsSetPropertyEventHandler(
            camera, kEdsPropertyEvent_All,
            &EventDispatcher::handlePropertyEvent, this);
        ErrorHandler::dbgResult("EventDispatcher", "SetPropertyEventHandler", err);
        if (err != EDS_ERR_OK)
            return ErrorHandler::check(err, "EdsSetPropertyEventHandler");

        err = EdsSetCameraStateEventHandler(
            camera, kEdsStateEvent_All,
            &EventDispatcher::handleStateEvent, this);
        ErrorHandler::dbgResult("EventDispatcher", "SetStateEventHandler", err);
        if (err != EDS_ERR_OK)
            return ErrorHandler::check(err, "EdsSetCameraStateEventHandler");

        ErrorHandler::log(LogLevel::Info, "Event callbacks registered successfully");
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Dispatch typed events to all listeners
    // -----------------------------------------------------------------------
    // -----------------------------------------------------------------------
    // Dispatch typed events to all listeners
    // -----------------------------------------------------------------------
    void dispatch(const ObjectEvent& event) {
        std::vector<IEventListener*> listenersCopy;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            listenersCopy = m_listeners;
        }
        for (auto* listener : listenersCopy) {
            listener->onObjectEvent(event);
        }
    }

    void dispatch(const PropertyEvent& event) {
        std::vector<IEventListener*> listenersCopy;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            listenersCopy = m_listeners;
        }
        for (auto* listener : listenersCopy) {
            listener->onPropertyEvent(event);
        }
    }

    void dispatch(const StateEvent& event) {
        std::vector<IEventListener*> listenersCopy;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            listenersCopy = m_listeners;
        }
        for (auto* listener : listenersCopy) {
            listener->onStateEvent(event);
        }
    }

    void dispatch(const DownloadProgressEvent& event) {
        std::vector<IEventListener*> listenersCopy;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            listenersCopy = m_listeners;
        }
        for (auto* listener : listenersCopy) {
            listener->onDownloadProgress(event);
        }
    }

    void dispatch(const ConnectionEvent& event) {
        std::vector<IEventListener*> listenersCopy;
        {
            std::lock_guard<std::mutex> lock(m_mutex);
            listenersCopy = m_listeners;
        }
        for (auto* listener : listenersCopy) {
            listener->onConnectionChanged(event);
        }
    }

private:
    // -----------------------------------------------------------------------
    // Static EDSDK callback handlers (C-style → C++ dispatch)
    // -----------------------------------------------------------------------
    static EdsError EDSCALLBACK handleObjectEvent(
        EdsObjectEvent inEvent, EdsBaseRef inRef, EdsVoid* inContext)
    {
        auto* self = static_cast<EventDispatcher*>(inContext);
        if (!self) return EDS_ERR_OK;

        ErrorHandler::dbg("EventDispatcher::handleObjectEvent",
            "Event được trigger: ObjectEvent 0x" + hexStr(inEvent) + " ref=" + ptrStr(inRef) +
            (inEvent == kEdsObjectEvent_DirItemRequestTransfer ? " [TRANSFER_REQUEST]" :
             inEvent == kEdsObjectEvent_DirItemCreated ? " [DIR_ITEM_CREATED]" : "") +
            " Thread đang xử lý event: " + getThreadIdStr());

        ObjectEvent event(inEvent, inRef);

        // If transfer request, call internal handler OUTSIDE the lock to avoid deadlock
        // (download handler calls dispatch() which also locks m_mutex)
        if (event.isTransferRequest()) {
            ObjectEventCallback handler;
            {
                std::lock_guard<std::mutex> lock(self->m_mutex);
                handler = self->m_transferHandler;
            }
            if (handler) {
                ErrorHandler::dbg("EventDispatcher::handleObjectEvent",
                    "Calling transfer handler for ref=" + ptrStr(inRef));
                handler(inRef);
            } else {
                ErrorHandler::dbg("EventDispatcher::handleObjectEvent",
                    "No transfer handler registered!");
            }
        }

        self->dispatch(event);

        // Don't release inRef here - download handler needs it
        if (!event.isTransferRequest() && inRef) {
            EdsRelease(inRef);
        }

        return EDS_ERR_OK;
    }

    static EdsError EDSCALLBACK handlePropertyEvent(
        EdsPropertyEvent inEvent, EdsPropertyID inPropertyID,
        EdsUInt32 inParam, EdsVoid* inContext)
    {
        auto* self = static_cast<EventDispatcher*>(inContext);
        if (!self) return EDS_ERR_OK;

        ErrorHandler::dbg("EventDispatcher::handlePropertyEvent",
            "Event được trigger: PropertyEvent 0x" + hexStr(inEvent) + " propId=0x" + hexStr(inPropertyID) +
            " param=" + std::to_string(inParam) + " Thread đang xử lý event: " + getThreadIdStr());

        PropertyEvent event(inEvent, inPropertyID, inParam);
        self->dispatch(event);

        return EDS_ERR_OK;
    }

    static EdsError EDSCALLBACK handleStateEvent(
        EdsStateEvent inEvent, EdsUInt32 inEventData, EdsVoid* inContext)
    {
        auto* self = static_cast<EventDispatcher*>(inContext);
        if (!self) return EDS_ERR_OK;

        ErrorHandler::dbg("EventDispatcher::handleStateEvent",
            "Event được trigger: StateEvent 0x" + hexStr(inEvent) + " data=0x" + hexStr(inEventData) +
            (inEvent == kEdsStateEvent_Shutdown ? " [SHUTDOWN]" :
             inEvent == kEdsStateEvent_WillSoonShutDown ? " [WILL_SHUTDOWN]" :
             inEvent == kEdsStateEvent_CaptureError ? " [CAPTURE_ERROR]" : "") +
            " Thread đang xử lý event: " + getThreadIdStr());

        StateEvent event(inEvent, inEventData);
        self->dispatch(event);

        if (event.isWillShutdown()) {
            ErrorHandler::log(LogLevel::Info,
                "Camera will shutdown soon - extending timer");
        }

        return EDS_ERR_OK;
    }

    // Hex formatting helpers
    static std::string hexStr(uint32_t val) {
        char buf[16]; snprintf(buf, sizeof(buf), "%08X", val);
        return buf;
    }
    static std::string ptrStr(const void* p) {
        char buf[24]; snprintf(buf, sizeof(buf), "%p", p);
        return buf;
    }

    static std::string getThreadIdStr() {
        std::stringstream ss;
        ss << std::this_thread::get_id();
        return ss.str();
    }

    std::mutex                    m_mutex;
    std::vector<IEventListener*>  m_listeners;
    ObjectEventCallback           m_transferHandler;
};

} // namespace CameraApp
