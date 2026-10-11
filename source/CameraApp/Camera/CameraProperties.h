#pragma once

/*=============================================================================
 * CameraProperties.h - Camera property read/write operations
 *
 * Layer: Camera
 * Purpose: Wraps all EDSDK property get/set operations with proper error
 *          handling and retry logic. Updates CameraState on success.
 *============================================================================*/

#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "CameraState.h"

#include <functional>
#include <future>

namespace CameraApp {

// Forward declaration
class CommandQueue;

class CameraProperties {
public:
    // Boot window check callback type
    using BootWindowCheck = std::function<bool()>;

    CameraProperties(EdsCameraRef camera, CameraState& state, BootWindowCheck bootCheck = nullptr)
        : m_camera(camera), m_state(state), m_bootCheck(bootCheck) {}

    // -----------------------------------------------------------------------
    // Read a UInt32 property (with CommandQueue if available)
    // -----------------------------------------------------------------------
    Result getUInt32(EdsPropertyID propId, EdsUInt32& outValue) {
        if (!m_commandQueue) {
            // Fallback to direct retry without queue
            return ErrorHandler::executeWithRetry(
                "GetProperty(" + std::to_string(propId) + ")",
                [&]() -> EdsError {
                    EdsError err = EdsGetPropertyData(
                        m_camera, propId, 0, sizeof(EdsUInt32), &outValue);
                    if (err == EDS_ERR_OK) {
                        m_state.setProperty(propId, outValue);
                    }
                    return err;
                });
        }

        // Use CommandQueue for serialized operation
        EdsError result = EDS_ERR_OK;
        std::promise<EdsError> promise;
        auto future = promise.get_future();

        m_commandQueue->enqueue(
            CommandType::PropertyGet,
            CommandPriority::NORMAL,
            "GetUInt32(0x" + std::to_string((uint32_t)propId) + ")",
            [&]() -> EdsError {
                EdsError err = EdsGetPropertyData(
                    m_camera, propId, 0, sizeof(EdsUInt32), &outValue);
                if (err == EDS_ERR_OK) {
                    m_state.setProperty(propId, outValue);
                }
                return err;
            },
            [&](EdsError err) {
                result = err;
                promise.set_value(err);
            });

        future.wait();
        return ErrorHandler::check(result, "GetProperty");
    }

    // -----------------------------------------------------------------------
    // Read a string property
    // -----------------------------------------------------------------------
    Result getString(EdsPropertyID propId, std::string& outValue) {
        EdsChar buf[EDS_MAX_NAME] = {};

        auto result = ErrorHandler::executeWithRetry(
            "GetPropertyString(" + std::to_string(propId) + ")",
            [&]() -> EdsError {
                return EdsGetPropertyData(
                    m_camera, propId, 0, sizeof(buf), buf);
            });

        if (result.ok()) {
            outValue = buf;
            m_state.setPropertyString(propId, outValue);
        }
        return result;
    }

    // -----------------------------------------------------------------------
    // Read full property value (auto-detect type)
    // -----------------------------------------------------------------------
    Result getValue(EdsPropertyID propId, PropertyValue& outValue) {
        EdsDataType dataType;
        EdsUInt32   size;

        auto result = ErrorHandler::executeWithRetry(
            "GetPropertySize",
            [&]() -> EdsError {
                return EdsGetPropertySize(
                    m_camera, propId, 0, &dataType, &size);
            });
        if (!result.ok()) return result;

        outValue.propertyId = propId;
        outValue.dataType   = dataType;
        outValue.size       = size;

        switch (dataType) {
        case kEdsDataType_UInt32: {
            result = getUInt32(propId, outValue.uint32Val);
            break;
        }
        case kEdsDataType_Int32: {
            result = ErrorHandler::executeWithRetry("GetInt32",
                [&]() -> EdsError {
                    return EdsGetPropertyData(
                        m_camera, propId, 0, sizeof(EdsInt32), &outValue.int32Val);
                });
            break;
        }
        case kEdsDataType_String: {
            result = getString(propId, outValue.stringVal);
            break;
        }
        default: {
            outValue.rawData.resize(size);
            result = ErrorHandler::executeWithRetry("GetRawProperty",
                [&]() -> EdsError {
                    return EdsGetPropertyData(
                        m_camera, propId, 0, size, outValue.rawData.data());
                });
            break;
        }
        }

        return result;
    }

    // -----------------------------------------------------------------------
    // Write a UInt32 property
    // -----------------------------------------------------------------------
    Result setUInt32(EdsPropertyID propId, EdsUInt32 value) {
        if (!m_commandQueue) {
            // Fallback to direct retry without queue
            return ErrorHandler::executeWithRetry(
                "SetProperty(" + std::to_string(propId) + ")",
                [&]() -> EdsError {
                    EdsUInt32 val = value;  // Use local copy
                    EdsError err = EdsSetPropertyData(
                        m_camera, propId, 0, sizeof(EdsUInt32), &val);
                    if (err == EDS_ERR_OK) {
                        m_state.setProperty(propId, value);
                    }
                    return err;
                });
        }

        // Use CommandQueue for serialized operation
        EdsError result = EDS_ERR_OK;
        std::promise<EdsError> promise;
        auto future = promise.get_future();

        m_commandQueue->enqueue(
            CommandType::PropertySet,
            CommandPriority::NORMAL,
            "SetUInt32(0x" + std::to_string((uint32_t)propId) + ")",
            [this, propId, value]() -> EdsError {
                EdsUInt32 val = value;  // Copy value for safety
                EdsError err = EdsSetPropertyData(
                    m_camera, propId, 0, sizeof(EdsUInt32), &val);
                if (err == EDS_ERR_OK) {
                    m_state.setProperty(propId, value);
                }
                return err;
            },
            [&](EdsError err) {
                result = err;
                promise.set_value(err);
            });

        future.wait();
        return ErrorHandler::check(result, "SetProperty");
    }

    // -----------------------------------------------------------------------
    // Write a string property
    // -----------------------------------------------------------------------
    Result setString(EdsPropertyID propId, const std::string& value) {
        return ErrorHandler::executeWithRetry(
            "SetPropertyString",
            [&]() -> EdsError {
                return EdsSetPropertyData(
                    m_camera, propId, 0,
                    static_cast<EdsUInt32>(value.size() + 1),
                    value.c_str());
            });
    }

    // -----------------------------------------------------------------------
    // Write raw data property
    // -----------------------------------------------------------------------
    Result setRaw(EdsPropertyID propId, EdsUInt32 size, const void* data) {
        return ErrorHandler::executeWithRetry(
            "SetPropertyRaw",
            [&]() -> EdsError {
                return EdsSetPropertyData(m_camera, propId, 0, size, data);
            });
    }

    // -----------------------------------------------------------------------
    // Get property descriptor (valid values list)
    // -----------------------------------------------------------------------
    Result getDescriptor(EdsPropertyID propId, PropertyDescriptor& outDesc) {
        EdsPropertyDesc edsDesc;

        auto result = ErrorHandler::executeWithRetry(
            "GetPropertyDesc(" + std::to_string(propId) + ")",
            [&]() -> EdsError {
                return EdsGetPropertyDesc(m_camera, propId, &edsDesc);
            });

        if (result.ok()) {
            outDesc.propertyId = propId;
            outDesc.access     = edsDesc.access;
            outDesc.values.clear();
            outDesc.values.reserve(edsDesc.numElements);

            for (int i = 0; i < edsDesc.numElements; ++i) {
                outDesc.values.push_back(edsDesc.propDesc[i]);
            }

            m_state.setPropertyDesc(propId, outDesc);
        }
        return result;
    }

    // -----------------------------------------------------------------------
    // Convenience: Set common properties
    // -----------------------------------------------------------------------
    Result setTv(EdsUInt32 value)          { return setUInt32(kEdsPropID_Tv, value); }
    Result setAv(EdsUInt32 value)          { return setUInt32(kEdsPropID_Av, value); }
    Result setIso(EdsUInt32 value)         { return setUInt32(kEdsPropID_ISOSpeed, value); }
    Result setWhiteBalance(EdsUInt32 val)  { return setUInt32(kEdsPropID_WhiteBalance, val); }
    Result setMeteringMode(EdsUInt32 val)  { return setUInt32(kEdsPropID_MeteringMode, val); }
    Result setImageQuality(EdsUInt32 val)  { return setUInt32(kEdsPropID_ImageQuality, val); }
    Result setDriveMode(EdsUInt32 val)     { return setUInt32(kEdsPropID_DriveMode, val); }
    Result setExposureComp(EdsUInt32 val)  { return setUInt32(kEdsPropID_ExposureCompensation, val); }

    Result setSaveTarget(SaveTarget target) {
        return setUInt32(kEdsPropID_SaveTo, static_cast<EdsUInt32>(target));
    }

    // -----------------------------------------------------------------------
    // Color Temperature (Kelvin) support
    // -----------------------------------------------------------------------
    // Get current color temperature in Kelvin
    EdsUInt32 getCurrentColorTemperature() const {
        // Try to read from state if available (cached)
        auto currentWB = m_state.whiteBalance();

        // Map white balance preset to Kelvin value
        // These are typical mappings for Canon cameras
        switch (currentWB) {
            case 0:  return 3200;   // Tungsten
            case 1:  return 3500;   // White Fluorescent
            case 2:  return 5200;   // Daylight
            case 3:  return 6500;   // Cloudy
            case 4:  return 7500;   // Shade
            case 5:  return 5200;   // Flash (default daylight equivalent)
            case 9:  return 5200;   // Custom WB (use default)
            default: return 5200;   // Unknown - use daylight default
        }
    }

    // Get supported color temperatures for this camera
    std::vector<ColorTemperatureValue> getSupportedColorTemperatures() const {
        std::vector<ColorTemperatureValue> temps;

        // Add standard color temperatures
        temps.push_back(ColorTemperatureValue(3200, "Tungsten 3200K", 0));
        temps.push_back(ColorTemperatureValue(3500, "White Fluorescent 3500K", 1));
        temps.push_back(ColorTemperatureValue(5200, "Daylight 5200K", 2));
        temps.push_back(ColorTemperatureValue(6500, "Cloudy 6500K", 3));
        temps.push_back(ColorTemperatureValue(7500, "Shade 7500K", 4));
        temps.push_back(ColorTemperatureValue(5200, "Flash 5200K", 5));

        return temps;
    }

    // Set a TRUE color temperature in Kelvin.
    // Canon EDSDK only honours kEdsPropID_ColorTemperature when the white
    // balance mode is kEdsWhiteBalance_ColorTemp (9), so we switch the WB
    // mode first, then write the Kelvin value. Canon accepts 2500–10000 K
    // in 100 K steps; values are clamped and rounded to the nearest step.
    Result setColorTemperatureByKelvin(EdsUInt32 kelvin) {
        if (kelvin < 2500)  kelvin = 2500;
        if (kelvin > 10000) kelvin = 10000;
        kelvin = ((kelvin + 50) / 100) * 100;   // round to nearest 100 K

        ErrorHandler::log(LogLevel::Info,
            "setColorTemperatureByKelvin: applying real Kelvin=" +
            std::to_string(kelvin));

        // 1) WB mode must be Color Temperature, otherwise Kelvin is ignored.
        Result wbRes = setWhiteBalance(
            static_cast<EdsUInt32>(kEdsWhiteBalance_ColorTemp));
        if (!wbRes.ok()) {
            ErrorHandler::log(LogLevel::Warning,
                "setColorTemperatureByKelvin: failed to switch WB to "
                "ColorTemp mode: " + wbRes.message);
            return wbRes;
        }

        // 2) Write the actual Kelvin value.
        return setUInt32(kEdsPropID_ColorTemperature, kelvin);
    }

    // Set color temperature by preset enum
    Result setColorTemperature(ColorTemperature temp) {
        return setColorTemperatureByKelvin(static_cast<EdsUInt32>(temp));
    }

    // -----------------------------------------------------------------------
    // Load all common properties from camera into state
    // -----------------------------------------------------------------------
    Result loadAllProperties() {
        // Skip full property loading if called during boot window
        // Only read critical properties immediately
        if (m_bootCheck && m_bootCheck()) {
            ErrorHandler::dbg("CameraProperties::loadAllProperties",
                "Boot window active - loading only critical properties");

            // Load only critical properties during boot
            EdsUInt32 val;
            getUInt32(kEdsPropID_BatteryLevel, val);
            getUInt32(kEdsPropID_AvailableShots, val);

            // String properties
            std::string str;
            getString(kEdsPropID_ProductName, str);
            getString(kEdsPropID_BodyIDEx, str);

            ErrorHandler::log(LogLevel::Info,
                "Loaded critical properties for " + m_state.modelName() + " (boot window)");
            return Result::Ok();
        }

        const EdsPropertyID props[] = {
            kEdsPropID_AEMode,
            kEdsPropID_Tv,
            kEdsPropID_Av,
            kEdsPropID_ISOSpeed,
            kEdsPropID_MeteringMode,
            kEdsPropID_ExposureCompensation,
            kEdsPropID_ImageQuality,
            kEdsPropID_WhiteBalance,
            kEdsPropID_ColorTemperature,
            kEdsPropID_DriveMode,
            kEdsPropID_BatteryLevel,
            kEdsPropID_AvailableShots,
            kEdsPropID_Evf_OutputDevice,
            kEdsPropID_Evf_AFMode,
            kEdsPropID_SaveTo
        };

        EdsUInt32 val;
        for (auto propId : props) {
            getUInt32(propId, val);  // Best-effort, don't fail on unsupported
        }

        // String properties
        std::string str;
        getString(kEdsPropID_ProductName, str);
        getString(kEdsPropID_BodyIDEx, str);

        ErrorHandler::log(LogLevel::Info,
            "Loaded all properties for " + m_state.modelName());
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Load descriptors for common adjustable properties
    // -----------------------------------------------------------------------
    Result loadAllDescriptors() {
        // Skip descriptor loading during boot window
        if (m_bootCheck && m_bootCheck()) {
            ErrorHandler::dbg("CameraProperties::loadAllDescriptors",
                "Boot window active - deferring descriptor loading");
            return Result::Ok();
        }

        const EdsPropertyID descs[] = {
            kEdsPropID_AEMode,
            kEdsPropID_Tv,
            kEdsPropID_Av,
            kEdsPropID_ISOSpeed,
            kEdsPropID_MeteringMode,
            kEdsPropID_ExposureCompensation,
            kEdsPropID_ImageQuality,
            kEdsPropID_WhiteBalance,
            kEdsPropID_DriveMode,
            kEdsPropID_Evf_AFMode
        };

        PropertyDescriptor desc;
        for (auto propId : descs) {
            getDescriptor(propId, desc);  // Best-effort
        }

        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // CommandQueue accessor (set by CameraDevice)
    // -----------------------------------------------------------------------
    void setCommandQueue(CommandQueue* queue) { m_commandQueue = queue; }
    CommandQueue* commandQueue() { return m_commandQueue; }

private:
    EdsCameraRef   m_camera;
    CameraState&   m_state;
    BootWindowCheck m_bootCheck;
    CommandQueue*  m_commandQueue = nullptr;  // Set by CameraDevice
};

} // namespace CameraApp
