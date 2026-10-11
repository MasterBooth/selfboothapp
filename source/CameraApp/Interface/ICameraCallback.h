#pragma once

/*=============================================================================
 * ICameraCallback.h - Abstract callback interface for UI integration
 *
 * Layer: Interface
 * Purpose: Defines the contract between the camera engine and any UI layer.
 *          Qt, MFC, WinForms, or any other UI framework implements this
 *          interface to receive camera events on the UI thread.
 *
 * Thread safety: These callbacks may fire from the SDK or worker thread.
 *                Implementations must marshal to their UI thread if needed.
 *============================================================================*/

#include "../Core/Types.h"

namespace CameraApp {

class ICameraCallback {
public:
    virtual ~ICameraCallback() = default;

    // -----------------------------------------------------------------------
    // Connection events
    // -----------------------------------------------------------------------
    virtual void onCameraConnected(const std::string& cameraName) = 0;
    virtual void onCameraDisconnected() = 0;

    // -----------------------------------------------------------------------
    // Property events
    // -----------------------------------------------------------------------

    // A camera property value has changed
    virtual void onPropertyChanged(EdsPropertyID propertyId, EdsUInt32 value) = 0;

    // The list of valid values for a property has changed
    virtual void onPropertyDescChanged(EdsPropertyID propertyId,
                                       const PropertyDescriptor& desc) = 0;

    // -----------------------------------------------------------------------
    // Capture events
    // -----------------------------------------------------------------------

    // Shutter confirmed — camera has the image, USB download is about to start.
    // Fires before onFileDownloaded so the UI can start the next countdown immediately.
    virtual void onShutterFired() {}

    // Download progress (0-100)
    virtual void onDownloadProgress(const std::string& fileName,
                                    EdsUInt32 percent) = 0;

    // A file has been downloaded successfully
    virtual void onFileDownloaded(const DownloadedFile& file) = 0;

    // Capture error (AF fail, no card, etc.)
    virtual void onCaptureError(EdsError error, const std::string& message) = 0;

    // -----------------------------------------------------------------------
    // Live View events
    // -----------------------------------------------------------------------

    // A new Live View frame is available for display
    virtual void onLiveViewFrame(const uint8_t* jpegData, size_t dataSize,
                                 const LiveViewFrame& metadata) = 0;

    // Live View started/stopped
    virtual void onLiveViewStateChanged(bool active) = 0;

    // -----------------------------------------------------------------------
    // Error / Status
    // -----------------------------------------------------------------------
    virtual void onError(const std::string& message) = 0;
    virtual void onStatusMessage(const std::string& message) = 0;
};

} // namespace CameraApp
