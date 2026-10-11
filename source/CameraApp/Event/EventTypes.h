#pragma once

/*=============================================================================
 * EventTypes.h - Camera event type definitions
 *
 * Layer: Event
 * Purpose: Defines all event types that the camera system can emit.
 *          These flow from EDSDK callbacks → EventDispatcher → Listeners.
 *============================================================================*/

#include "../Core/Types.h"

namespace CameraApp {

// ---------------------------------------------------------------------------
// Event categories
// ---------------------------------------------------------------------------
enum class EventCategory {
    Object,     // File/directory events from camera
    Property,   // Camera property changes
    State,      // Camera state changes
    Download,   // Download progress/completion
    LiveView,   // LiveView frame events
    Connection  // Connection state changes
};

// ---------------------------------------------------------------------------
// Base internal camera event (renamed to avoid conflict with API/CameraController.h)
// ---------------------------------------------------------------------------
struct BaseEvent {
    EventCategory  category;
    EdsUInt32      eventCode = 0;  // Original EDSDK event code
    void*          contextData = nullptr;

    BaseEvent() : category(EventCategory::State) {}
    BaseEvent(EventCategory cat, EdsUInt32 code = 0)
        : category(cat), eventCode(code) {}
    virtual ~BaseEvent() = default;
};

// ---------------------------------------------------------------------------
// Object event - file ready for transfer, directory changes
// ---------------------------------------------------------------------------
struct ObjectEvent : BaseEvent {
    EdsBaseRef objectRef = nullptr;

    ObjectEvent() : BaseEvent(EventCategory::Object) {}
    ObjectEvent(EdsUInt32 code, EdsBaseRef ref)
        : BaseEvent(EventCategory::Object, code), objectRef(ref) {}

    bool isTransferRequest() const {
        return eventCode == kEdsObjectEvent_DirItemRequestTransfer;
    }
    bool isItemCreated() const {
        return eventCode == kEdsObjectEvent_DirItemCreated;
    }
};

// ---------------------------------------------------------------------------
// Property event - a camera property changed or its valid values changed
// ---------------------------------------------------------------------------
struct PropertyEvent : BaseEvent {
    EdsPropertyID propertyId = 0;
    EdsUInt32     param      = 0;

    PropertyEvent() : BaseEvent(EventCategory::Property) {}
    PropertyEvent(EdsUInt32 code, EdsPropertyID propId, EdsUInt32 p = 0)
        : BaseEvent(EventCategory::Property, code),
          propertyId(propId), param(p) {}

    bool isValueChanged() const {
        return eventCode == kEdsPropertyEvent_PropertyChanged;
    }
    bool isDescChanged() const {
        return eventCode == kEdsPropertyEvent_PropertyDescChanged;
    }
};

// ---------------------------------------------------------------------------
// State event - camera state changes (shutdown, error, etc.)
// ---------------------------------------------------------------------------
struct StateEvent : BaseEvent {
    EdsUInt32 stateData = 0;

    StateEvent() : BaseEvent(EventCategory::State) {}
    StateEvent(EdsUInt32 code, EdsUInt32 data = 0)
        : BaseEvent(EventCategory::State, code), stateData(data) {}

    bool isShutdown() const {
        return eventCode == kEdsStateEvent_Shutdown;
    }
    bool isWillShutdown() const {
        return eventCode == kEdsStateEvent_WillSoonShutDown;
    }
    bool isCaptureError() const {
        return eventCode == kEdsStateEvent_CaptureError;
    }
};

// ---------------------------------------------------------------------------
// Download progress event
// ---------------------------------------------------------------------------
struct DownloadProgressEvent : BaseEvent {
    std::string fileName;
    EdsUInt32   percent = 0;
    bool        completed = false;
    bool        success   = false;

    DownloadProgressEvent()
        : BaseEvent(EventCategory::Download) {}
};

// ---------------------------------------------------------------------------
// Connection event
// ---------------------------------------------------------------------------
struct ConnectionEvent : BaseEvent {
    bool connected = false;
    std::string cameraName;

    ConnectionEvent()
        : BaseEvent(EventCategory::Connection) {}
    ConnectionEvent(bool conn, const std::string& name = "")
        : BaseEvent(EventCategory::Connection),
          connected(conn), cameraName(name) {}
};

} // namespace CameraApp
