#pragma once

/*=============================================================================
 * Types.h - Common type definitions and forward declarations
 *
 * Layer: Core
 * Purpose: Central type definitions used across all modules.
 *          Wraps EDSDK types into application-level abstractions.
 *============================================================================*/

#include "EDSDK.h"
#include "EDSDKTypes.h"
#include "EDSDKErrors.h"

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <cstdint>

namespace CameraApp {

// ---------------------------------------------------------------------------
// Result type for all SDK operations
// ---------------------------------------------------------------------------
struct Result {
    EdsError code;
    std::string message;

    bool ok() const { return code == EDS_ERR_OK; }
    bool isBusy() const { return code == EDS_ERR_DEVICE_BUSY; }
    bool isNotReady() const { return code == EDS_ERR_OBJECT_NOTREADY; }
    bool isDisconnected() const { return code == EDS_ERR_COMM_DISCONNECTED; }

    static Result Ok() { return { EDS_ERR_OK, "" }; }
    static Result FromError(EdsError err, const std::string& msg = "") {
        return { err, msg };
    }
};

// ---------------------------------------------------------------------------
// Camera identification
// ---------------------------------------------------------------------------
struct CameraInfo {
    std::string name;
    std::string portName;
    std::string bodyId;
    EdsUInt32   deviceSubType = 0;
    EdsCameraRef ref = nullptr;
};

// ---------------------------------------------------------------------------
// Camera property value container
// ---------------------------------------------------------------------------
struct PropertyValue {
    EdsPropertyID   propertyId = 0;
    EdsDataType     dataType   = kEdsDataType_Unknown;
    EdsUInt32       size       = 0;

    // Typed storage
    EdsUInt32       uint32Val  = 0;
    EdsInt32        int32Val   = 0;
    std::string     stringVal;
    std::vector<uint8_t> rawData;

    // Convenience helpers
    bool isValid() const { return dataType != kEdsDataType_Unknown; }
};

// ---------------------------------------------------------------------------
// Property descriptor (valid values list)
// ---------------------------------------------------------------------------
struct PropertyDescriptor {
    EdsPropertyID           propertyId = 0;
    std::vector<EdsInt32>   values;
    EdsInt32                access = 0;

    bool isEmpty() const { return values.empty(); }
    bool contains(EdsInt32 val) const {
        for (auto v : values) { if (v == val) return true; }
        return false;
    }
};

// ---------------------------------------------------------------------------
// Save destination
// ---------------------------------------------------------------------------
enum class SaveTarget : EdsUInt32 {
    Camera = kEdsSaveTo_Camera,
    Host   = kEdsSaveTo_Host,
    Both   = kEdsSaveTo_Both
};

// ---------------------------------------------------------------------------
// Shutter action
// ---------------------------------------------------------------------------
enum class ShutterAction : EdsInt32 {
    Off              = kEdsCameraCommand_ShutterButton_OFF,
    Halfway          = kEdsCameraCommand_ShutterButton_Halfway,
    Completely       = kEdsCameraCommand_ShutterButton_Completely,
    HalfwayNoAF      = kEdsCameraCommand_ShutterButton_Halfway_NonAF,
    CompletelyNoAF   = kEdsCameraCommand_ShutterButton_Completely_NonAF
};

// ---------------------------------------------------------------------------
// Focus drive direction (for LiveView lens drive)
// ---------------------------------------------------------------------------
enum class FocusDrive : EdsUInt32 {
    Near1 = kEdsEvfDriveLens_Near1,
    Near2 = kEdsEvfDriveLens_Near2,
    Near3 = kEdsEvfDriveLens_Near3,
    Far1  = kEdsEvfDriveLens_Far1,
    Far2  = kEdsEvfDriveLens_Far2,
    Far3  = kEdsEvfDriveLens_Far3
};

// ---------------------------------------------------------------------------
// Color Temperature (Kelvin) - standard presets
// ---------------------------------------------------------------------------
enum class ColorTemperature : EdsUInt32 {
    Tungsten3200K   = 3200,    // Tungsten light
    Tungsten3500K   = 3500,    // Studio tungsten
    DayLight5200K   = 5200,    // Daylight
    Cloudy6500K     = 6500,    // Cloudy/overcast
    Shade7500K      = 7500,    // Shade
    Custom          = 0        // User-defined value
};

// ---------------------------------------------------------------------------
// Color Temperature mapping helper
// ---------------------------------------------------------------------------
struct ColorTemperatureValue {
    EdsUInt32 kelvin;           // Actual Kelvin value (e.g., 3200, 6500, etc.)
    std::string label;          // Display label (e.g., "Daylight 5200K")
    EdsInt32   whiteBalanceId;  // Corresponding WB preset (if any)

    ColorTemperatureValue() : kelvin(5200), label("Daylight 5200K"), whiteBalanceId(0) {}
    ColorTemperatureValue(EdsUInt32 k, const std::string& l, EdsInt32 wb = 0)
        : kelvin(k), label(l), whiteBalanceId(wb) {}
};

// ---------------------------------------------------------------------------
// LiveView frame data (optimized for fast rendering)
// ---------------------------------------------------------------------------
struct LiveViewFrame {
    // JPEG data (for backward compatibility)
    std::vector<uint8_t> jpegData;

    // Pre-decoded bitmap (for fast rendering without GDI+)
    // HBITMAP is Windows device-independent bitmap handle
    // Created in streaming thread during JPEG decode
    HBITMAP              decodedBitmap = nullptr;
    int                  bitmapWidth = 0;
    int                  bitmapHeight = 0;

    // Metadata
    EdsUInt32            zoom          = 0;
    EdsPoint             imagePosition = {};
    EdsRect              zoomRect      = {};
    EdsSize              coordinateSystem = {};
    EdsUInt32            histogram[256 * 4] = {};
    bool                 histogramValid = false;

    // Transient raw pointer into the EDSDK stream buffer (Fix B).
    // Only valid synchronously during the streaming callback — do not cache.
    // When set, data()/dataSize() return this pointer (zero-copy path).
    // Null in single-frame download mode (jpegData is used instead).
    const uint8_t*       rawJpegPtr  = nullptr;
    size_t               rawJpegSize = 0;

    bool isValid() const { return decodedBitmap != nullptr; }
    const uint8_t* data() const { return rawJpegPtr ? rawJpegPtr : jpegData.data(); }
    size_t dataSize() const { return rawJpegPtr ? rawJpegSize : jpegData.size(); }

    ~LiveViewFrame() {
        if (decodedBitmap) {
            DeleteObject(decodedBitmap);
            decodedBitmap = nullptr;
        }
    }
};

// ---------------------------------------------------------------------------
// Downloaded file info
// ---------------------------------------------------------------------------
struct DownloadedFile {
    std::string fileName;
    std::string localPath;
    EdsUInt64   fileSize = 0;
    bool        success  = false;
};

// ---------------------------------------------------------------------------
// Capacity info to send to camera
// ---------------------------------------------------------------------------
struct HostCapacity {
    EdsInt32 freeClusters  = 0x7FFFFFFF;
    EdsInt32 bytesPerSector = 0x1000;

    EdsCapacity toEds() const {
        EdsCapacity cap;
        cap.numberOfFreeClusters = freeClusters;
        cap.bytesPerSector       = bytesPerSector;
        cap.reset                = true;
        return cap;
    }
};

} // namespace CameraApp
