#pragma once

/*=============================================================================
 * CameraState.h - Camera state model (thread-safe)
 *
 * Layer: Camera
 * Purpose: Stores current camera property values and valid descriptors.
 *          Thread-safe: EDSDK callbacks update state from SDK thread,
 *          while UI reads from main thread.
 *============================================================================*/

#include "../Core/Types.h"
#include <mutex>
#include <map>

namespace CameraApp {

class CameraState {
public:
    // -----------------------------------------------------------------------
    // Connection state
    // -----------------------------------------------------------------------
    enum class ConnectionStatus {
        Disconnected,
        Connecting,
        Connected,
        Error
    };

    void setConnectionStatus(ConnectionStatus status) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_connectionStatus = status;
    }

    ConnectionStatus connectionStatus() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_connectionStatus;
    }

    bool isConnected() const {
        return connectionStatus() == ConnectionStatus::Connected;
    }

    // -----------------------------------------------------------------------
    // Property values
    // -----------------------------------------------------------------------
    void setProperty(EdsPropertyID propId, EdsUInt32 value) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_properties[propId] = value;
    }

    EdsUInt32 getProperty(EdsPropertyID propId, EdsUInt32 defaultVal = 0) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_properties.find(propId);
        return (it != m_properties.end()) ? it->second : defaultVal;
    }

    void setPropertyString(EdsPropertyID propId, const std::string& value) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_stringProperties[propId] = value;
    }

    std::string getPropertyString(EdsPropertyID propId) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_stringProperties.find(propId);
        return (it != m_stringProperties.end()) ? it->second : "";
    }

    // -----------------------------------------------------------------------
    // Property descriptors (valid values)
    // -----------------------------------------------------------------------
    void setPropertyDesc(EdsPropertyID propId, const PropertyDescriptor& desc) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_descriptors[propId] = desc;
    }

    PropertyDescriptor getPropertyDesc(EdsPropertyID propId) const {
        std::lock_guard<std::mutex> lock(m_mutex);
        auto it = m_descriptors.find(propId);
        return (it != m_descriptors.end()) ? it->second : PropertyDescriptor{};
    }

    // -----------------------------------------------------------------------
    // Shortcut accessors for common properties
    // -----------------------------------------------------------------------
    EdsUInt32 aeMode() const       { return getProperty(kEdsPropID_AEMode); }
    EdsUInt32 tv() const           { return getProperty(kEdsPropID_Tv); }
    EdsUInt32 av() const           { return getProperty(kEdsPropID_Av); }
    EdsUInt32 iso() const          { return getProperty(kEdsPropID_ISOSpeed); }
    EdsUInt32 whiteBalance() const { return getProperty(kEdsPropID_WhiteBalance); }
    EdsUInt32 meteringMode() const { return getProperty(kEdsPropID_MeteringMode); }
    EdsUInt32 imageQuality() const { return getProperty(kEdsPropID_ImageQuality); }
    EdsUInt32 driveMode() const    { return getProperty(kEdsPropID_DriveMode); }
    EdsUInt32 exposureComp() const { return getProperty(kEdsPropID_ExposureCompensation); }
    EdsUInt32 batteryLevel() const { return getProperty(kEdsPropID_BatteryLevel); }
    EdsUInt32 availableShots() const { return getProperty(kEdsPropID_AvailableShots); }

    std::string modelName() const  { return getPropertyString(kEdsPropID_ProductName); }
    std::string bodyId() const     { return getPropertyString(kEdsPropID_BodyIDEx); }

    // -----------------------------------------------------------------------
    // LiveView state
    // -----------------------------------------------------------------------
    void setEvfActive(bool active) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_evfActive = active;
    }

    bool isEvfActive() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_evfActive;
    }

    void setEvfOutputDevice(EdsUInt32 device) {
        setProperty(kEdsPropID_Evf_OutputDevice, device);
    }

    EdsUInt32 evfOutputDevice() const {
        return getProperty(kEdsPropID_Evf_OutputDevice);
    }

    // -----------------------------------------------------------------------
    // Autofocus state (for AF synchronization)
    // -----------------------------------------------------------------------
    void setAfActive(bool active) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_afActive = active;
    }

    bool isAfActive() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_afActive;
    }

    void setAfLastError(EdsError error) {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_afLastError = error;
    }

    EdsError afLastError() const {
        std::lock_guard<std::mutex> lock(m_mutex);
        return m_afLastError;
    }

    // -----------------------------------------------------------------------
    // Reset all state
    // -----------------------------------------------------------------------
    void reset() {
        std::lock_guard<std::mutex> lock(m_mutex);
        m_connectionStatus = ConnectionStatus::Disconnected;
        m_properties.clear();
        m_stringProperties.clear();
        m_descriptors.clear();
        m_evfActive = false;
        m_afActive = false;
        m_afLastError = EDS_ERR_OK;
    }

private:
    mutable std::mutex                          m_mutex;
    ConnectionStatus                            m_connectionStatus = ConnectionStatus::Disconnected;
    std::map<EdsPropertyID, EdsUInt32>          m_properties;
    std::map<EdsPropertyID, std::string>        m_stringProperties;
    std::map<EdsPropertyID, PropertyDescriptor> m_descriptors;
    bool                                        m_evfActive = false;
    bool                                        m_afActive = false;
    EdsError                                    m_afLastError = EDS_ERR_OK;
};

} // namespace CameraApp
