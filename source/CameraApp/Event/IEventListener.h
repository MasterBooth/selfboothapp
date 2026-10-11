#pragma once

/*=============================================================================
 * IEventListener.h - Event listener interface
 *
 * Layer: Event
 * Purpose: Abstract interface for components that want to receive camera
 *          events. UI layers implement this to react to camera changes.
 *============================================================================*/

#include "EventTypes.h"

namespace CameraApp {

// ---------------------------------------------------------------------------
// Interface for receiving camera events
// ---------------------------------------------------------------------------
class IEventListener {
public:
    virtual ~IEventListener() = default;

    // Called when a file is ready to download from camera
    virtual void onObjectEvent(const ObjectEvent& event) {}

    // Called when a camera property changes value or valid range
    virtual void onPropertyEvent(const PropertyEvent& event) {}

    // Called when camera state changes (shutdown, error, etc.)
    virtual void onStateEvent(const StateEvent& event) {}

    // Called during file download with progress updates
    virtual void onDownloadProgress(const DownloadProgressEvent& event) {}

    // Called when camera connection state changes
    virtual void onConnectionChanged(const ConnectionEvent& event) {}
};

} // namespace CameraApp
