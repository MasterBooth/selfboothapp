#pragma once

/*=============================================================================
 * CameraController.h - Clean Public API for Camera Operations
 *
 * This is the ONLY file external modules should include.
 * All camera operations go through this unified interface.
 *
 * Thread-safety: All methods are thread-safe (internal CommandQueue)
 * Error handling: All methods return bool with error details in getLastError()
 *=============================================================================*/

#include "../Core/Types.h"
#include "../Camera/CameraState.h"
#include <string>
#include <vector>
#include <functional>
#include <memory>

namespace CameraApp {

// ---------------------------------------------------------------------------
// CAMERA EVENTS - Callback interfaces for UI
// ---------------------------------------------------------------------------

enum class CameraEventType {
    Connected,              // Camera connected successfully
    Disconnected,           // Camera disconnected
    CaptureStarted,         // Capture beginning
    CaptureCompleted,       // Photo saved
    CaptureError,           // Capture failed
    LiveViewStarted,        // EVF enabled
    LiveViewStopped,        // EVF disabled
    LiveViewFrameReceived,  // New frame in stream
    PropertyChanged,        // ISO, WB, etc. changed
    DownloadProgress,       // Image download in progress
};

struct CameraEvent {
    CameraEventType type;
    std::string message;
    EdsPropertyID propertyId = 0;
    EdsUInt32 propertyValue = 0;
    int downloadPercent = 0;
    std::string fileName;

    CameraEvent() : type(CameraEventType::Connected) {}
};

// Event listener interface
class ICameraEventListener {
public:
    virtual ~ICameraEventListener() = default;
    virtual void onCameraEvent(const CameraEvent& event) = 0;
};

// ---------------------------------------------------------------------------
// CAMERA PARAMETERS - Grouped property control
// ---------------------------------------------------------------------------

struct CameraParameters {
    int iso = 400;
    std::string shutterSpeed = "1/250";
    std::string aperture = "f/5.6";
    int exposureComp = 0;
    int whiteBalance = 0;
    int colorTemperature = 5200;
    int afMode = 0;
    int meteringMode = 0;
    int imageQuality = 0;
    int driveMode = 0;

    CameraParameters() = default;
};

// ---------------------------------------------------------------------------
// MAIN API - CameraController
// ---------------------------------------------------------------------------

class CameraController {
public:
    // Singleton access
    static CameraController& instance();

    // Non-copyable
    CameraController(const CameraController&) = delete;
    CameraController& operator=(const CameraController&) = delete;

    // -----------------------------------------------------------------------
    // SDK LIFECYCLE
    // -----------------------------------------------------------------------

    /**
     * Initialize the Canon EDSDK.
     * Must be called once before any camera operations.
     *
     * @return True if SDK initialized successfully
     */
    bool initialize();

    /**
     * Shutdown the Canon EDSDK and cleanup resources.
     * Should be called before application exit.
     */
    void shutdown();

    // -----------------------------------------------------------------------
    // CAMERA DISCOVERY
    // -----------------------------------------------------------------------

    /**
     * Enumerate all connected Canon cameras.
     *
     * @param[out] outCameras Vector of available cameras
     * @return True if enumeration succeeded (may be empty list)
     */
    bool findCameras(std::vector<CameraInfo>& outCameras);

    /**
     * Get count of connected cameras.
     *
     * @return Number of connected cameras (0 if none)
     */
    int getCameraCount();

    // -----------------------------------------------------------------------
    // CONNECTION MANAGEMENT
    // -----------------------------------------------------------------------

    /**
     * Connect to a camera by index.
     * Must call this before any camera-specific operations.
     *
     * @param cameraIndex Index from findCameras() results
     * @return True if connection successful
     */
    bool connectCamera(int cameraIndex);

    /**
     * Disconnect from the current camera.
     * Stops live view and capture if active.
     *
     * @return True if disconnection successful
     */
    bool disconnectCamera();

    /**
     * Check if a camera is currently connected.
     *
     * @return True if connected
     */
    bool isConnected() const;

    // -----------------------------------------------------------------------
    // PHOTO CAPTURE API
    // -----------------------------------------------------------------------

    /**
     * Take a single photo with autofocus.
     * Image is automatically downloaded and saved.
     *
     * @return True if capture successful
     */
    bool takePhoto();

    /**
     * Take a single photo WITHOUT autofocus.
     *
     * @return True if capture successful
     */
    bool takePhotoNoAF();

    /**
     * Take a photo using bulb mode (long exposure).
     *
     * @param exposureMs Duration of exposure in milliseconds
     * @return True if successful
     */
    bool takeBulbPhoto(int exposureMs);

    /**
     * Get the path where last photo was saved.
     *
     * @return Full file path or empty string if no photo taken
     */
    std::string getLastPhotoPath() const;

    /**
     * Set auto-download on/off.
     * When enabled, images are automatically downloaded after capture.
     *
     * @param enabled True to enable auto-download (default)
     */
    void setAutoDownload(bool enabled);

    /**
     * Allow the camera's physical remote shutter to trigger captures.
     * Keeps host transfer enabled while releasing the camera UI lock.
     */
    void setRemoteShutterMode(bool on);

    // -----------------------------------------------------------------------
    // LIVE VIEW STREAMING API
    // -----------------------------------------------------------------------

    /**
     * Start live view (Electronic Viewfinder).
     * Does NOT start streaming - call startLiveViewStreaming() for that.
     *
     * @return True if EVF enabled on camera
     */
    bool startLiveView();

    /**
     * Stop live view.
     *
     * @return True if EVF disabled
     */
    bool stopLiveView();

    /**
     * Check if live view is active.
     *
     * @return True if EVF is active
     */
    bool isLiveViewActive() const;

    /**
     * Download a single live view frame.
     * Use this for on-demand frame capture.
     *
     * @param[out] outFrame The JPEG frame data
     * @return True if frame downloaded successfully
     */
    bool getLiveViewFrame(LiveViewFrame& outFrame);

    /**
     * Start continuous live view frame streaming.
     * Frames will be delivered to registered event listeners.
     *
     * @return True if streaming started
     */
    bool startLiveViewStreaming();

    /**
     * Stop live view streaming.
     *
     * @return True if streaming stopped
     */
    bool stopLiveViewStreaming();

    // -----------------------------------------------------------------------
    // LENS FOCUS CONTROL (during Live View)
    // -----------------------------------------------------------------------

    /**
     * Drive lens toward near (MFD - Minimum Focus Distance).
     * Only works when live view is active.
     *
     * @return True if command sent successfully
     */
    bool driveLensNear();

    /**
     * Drive lens toward far (∞ - Infinity).
     * Only works when live view is active.
     *
     * @return True if command sent successfully
     */
    bool driveLensFar();

    /**
     * Trigger autofocus during live view.
     *
     * @return True if AF started
     */
    bool startAutofocus();

    /**
     * Stop autofocus during live view.
     *
     * @return True if AF stopped
     */
    bool stopAutofocus();

    // -----------------------------------------------------------------------
    // LIVE VIEW ZOOM CONTROL
    // -----------------------------------------------------------------------

    /**
     * Set live view zoom to fit entire frame in window.
     *
     * @return True if zoom set successfully
     */
    bool setLiveViewZoomFit();

    /**
     * Set live view zoom to 5x (magnified view).
     *
     * @return True if zoom set successfully
     */
    bool setLiveViewZoom5x();

    /**
     * Set live view zoom to 10x (maximum magnification).
     *
     * @return True if zoom set successfully
     */
    bool setLiveViewZoom10x();

    // -----------------------------------------------------------------------
    // CAMERA PARAMETER CONTROL
    // -----------------------------------------------------------------------

    /**
     * Set ISO (sensitivity).
     *
     * @param iso ISO value (e.g., 100, 200, 400, 800, 1600, 3200)
     * @return True if set successfully
     */
    bool setISO(int iso);

    /**
     * Set shutter speed.
     *
     * @param value Shutter speed as string ("1/1000", "2", "15", "bulb")
     * @return True if set successfully
     */
    bool setShutterSpeed(const std::string& value);

    /**
     * Set aperture (f-stop).
     *
     * @param value Aperture as string ("f/2.8", "5.6", "f/16")
     * @return True if set successfully
     */
    bool setAperture(const std::string& value);

    /**
     * Set white balance mode.
     *
     * @param mode WB preset (0=Auto, 1=Daylight, 2=Cloudy, etc.)
     * @return True if set successfully
     */
    bool setWhiteBalance(int mode);

    /**
     * Set white balance by color temperature (Kelvin).
     *
     * @param kelvin Color temperature (3200, 5200, 6500, 7500)
     * @return True if set successfully
     */
    bool setColorTemperature(int kelvin);

    /**
     * Set metering mode.
     *
     * @param mode Metering pattern (0=Evaluative, 1=Partial, 2=Spot, 3=Center-weighted)
     * @return True if set successfully
     */
    bool setMeteringMode(int mode);

    /**
     * Set image quality.
     *
     * @param quality Quality format (0=JPEG, 1=RAW, 2=RAW+JPEG)
     * @return True if set successfully
     */
    bool setImageQuality(int quality);

    /**
     * Set drive mode (single/continuous/timer).
     *
     * @param mode Drive pattern (0=Single, 1=Continuous, 2=Timer 10s, 3=Timer 2s)
     * @return True if set successfully
     */
    bool setDriveMode(int mode);

    /**
     * Set exposure compensation.
     *
     * @param stopValue EV compensation (-2 to +2)
     * @return True if set successfully
     */
    bool setExposureComp(int stopValue);

    /**
     * Get a camera property as a list of human-readable strings and the
     * current value as a human-readable string.
     * Uses EdsGetPropertyDesc to query valid values from the camera.
     *
     * Supported propIds: kEdsPropID_ISOSpeed, kEdsPropID_Tv, kEdsPropID_Av,
     *                    kEdsPropID_WhiteBalance, kEdsPropID_ExposureCompensation
     *
     * @param propId    EDSDK property ID
     * @param outList   Human-readable list of valid values
     * @param outCurrent Human-readable current value
     * @return True if list populated successfully
     */
    bool getPropertyStrings(EdsPropertyID propId,
                            std::vector<std::string>& outList,
                            std::string& outCurrent);

    /**
     * Apply multiple camera parameters at once.
     * More efficient than individual setters.
     *
     * @param params Camera parameters struct
     * @return True if all parameters set successfully
     */
    bool setParameters(const CameraParameters& params);

    /**
     * Get the current camera parameters.
     *
     * @param[out] params Current camera settings
     * @return True if read successfully
     */
    bool getParameters(CameraParameters& params) const;

    // -----------------------------------------------------------------------
    // IMAGE MANAGEMENT
    // -----------------------------------------------------------------------

    /**
     * Set the folder where captured images are saved.
     *
     * @param folderPath Full path to save directory
     */
    void setSaveFolder(const std::string& folderPath);

    /**
     * Get current save folder.
     *
     * @return Full path to save directory
     */
    std::string getSaveFolder() const;

    // -----------------------------------------------------------------------
    // STATE & DIAGNOSTICS
    // -----------------------------------------------------------------------

    /**
     * Get camera state information.
     * Returns nullptr if not connected.
     *
     * @return Pointer to camera state (read-only)
     */
    const CameraState* getState() const;

    /**
     * Get model name of connected camera.
     *
     * @return Camera model string or empty if not connected
     */
    std::string getCameraModel() const;

    /**
     * Get last error message.
     *
     * @return Error message string
     */
    std::string getLastError() const;

    /**
     * Get last error code.
     *
     * @return EDSDK error code or EDS_ERR_OK
     */
    EdsError getLastErrorCode() const;

    // -----------------------------------------------------------------------
    // CALLBACKS & EVENTS
    // -----------------------------------------------------------------------

    /**
     * Register an event listener to receive camera events.
     *
     * @param listener Pointer to listener implementation
     */
    void addEventListener(ICameraEventListener* listener);

    /**
     * Unregister an event listener.
     *
     * @param listener Pointer to same listener previously added
     */
    void removeEventListener(ICameraEventListener* listener);

    /**
     * Set log callback for debug output.
     *
     * @param callback Function called with log messages
     */
    void setLogCallback(std::function<void(const std::string& msg)> callback);

    /**
     * Set a callback to receive raw JPEG live view frames directly.
     * Called on the live view thread — marshal to UI thread if needed.
     *
     * @param callback Function receiving (jpegData pointer, byteSize)
     */
    void setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> callback);

    // -----------------------------------------------------------------------
    // ADVANCED (optional)
    // -----------------------------------------------------------------------

    /**
     * Keep camera awake by extending shutdown timer.
     * Call periodically if performing long operations.
     *
     * @return True if extended successfully
     */
    bool extendKeepAlive();

private:
    CameraController();
    ~CameraController();

    class Impl;
    std::unique_ptr<Impl> m_impl;
};

} // namespace CameraApp
