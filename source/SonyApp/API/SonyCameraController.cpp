/*=============================================================================
 * SonyCameraController.cpp - Sony SDK implementation
 *
 * Internally uses Sony Camera Remote SDK (SCRSDK).
 * The public API mirrors CameraApp::CameraController for drop-in compatibility.
 *=============================================================================*/

#include "SonyCameraController.h"

#ifdef _WIN32
#include <windows.h>
#include <shlobj.h>
#endif

#include <sstream>
#include <iomanip>
#include <algorithm>
#include <thread>
#include <mutex>
#include <atomic>
#include <condition_variable>
#include <chrono>
#include <filesystem>
#include <map>

// Sony CRSDK headers (path relative to PhotoboothDashboard or adjusted via include dir)
#include "../../RemoteCli/app/CRSDK/CameraRemote_SDK.h"
#include "../../RemoteCli/app/CRSDK/IDeviceCallback.h"
#include "../../RemoteCli/app/CRSDK/CrDeviceProperty.h"
#include "../../RemoteCli/app/CRSDK/CrDefines.h"
#include "../../RemoteCli/app/CRSDK/CrError.h"
#include "../../RemoteCli/app/CRSDK/CrCommandData.h"
#include "../../RemoteCli/app/CRSDK/CrControlCode.h"
#include "../../RemoteCli/app/CRSDK/CrTypes.h"

namespace SDK = SCRSDK;
using namespace std::chrono_literals;

// ---------------------------------------------------------------------------
// Canon property ID constants (from EDSDK/Header/EDSDKTypes.h)
// These are what PhotoboothDashboard passes to getPropertyStrings()
// ---------------------------------------------------------------------------
static constexpr uint32_t CANON_PROP_ISO          = 0x00000402;
static constexpr uint32_t CANON_PROP_AV           = 0x00000405;
static constexpr uint32_t CANON_PROP_TV           = 0x00000406;
static constexpr uint32_t CANON_PROP_WB           = 0x00000106;
static constexpr uint32_t CANON_PROP_EV           = 0x00000407;
static constexpr uint32_t CANON_PROP_COLORTEMP    = 0x00000107;

// ---------------------------------------------------------------------------
// Internal implementation class
// ---------------------------------------------------------------------------
class SonyApp::SonyCameraController::Impl : public SDK::IDeviceCallback {
public:
    Impl() = default;
    ~Impl() { cleanup(); }

    // ---- State ----
    SDK::CrDeviceHandle               m_handle        = 0;
    SDK::ICrEnumCameraObjectInfo*     m_enumList      = nullptr;
    std::atomic<bool>                 m_connected     {false};
    std::atomic<bool>                 m_sdkInit       {false};
    std::atomic<bool>                 m_movieRecording{false};
    int                               m_connectedIndex = -1;
    std::string                       m_cameraModel;
    std::string                       m_savePath;
    std::string                       m_lastPhotoPath;

    SonyCameraState                   m_state;

    // ---- Properties cache ----
    mutable std::mutex                m_propMutex;
    struct PropInfo {
        SDK::CrDevicePropertyCode     code;
        CrInt64u                      current;
        bool                          writable = false;
        std::vector<CrInt64u>         valid;
    };
    std::map<SDK::CrDevicePropertyCode, PropInfo> m_props;

    // ---- Listeners ----
    std::mutex                        m_listenerMutex;
    std::vector<ICameraEventListener*> m_listeners;
    std::function<void(const std::string&)>      m_logCallback;
    std::function<void(const uint8_t*, size_t)>  m_lvCallback;

    // ---- Live view streaming thread ----
    std::thread                       m_lvThread;
    std::atomic<bool>                 m_lvStreaming   {false};
    std::vector<uint8_t>              m_lvBuffer;

    // ---- Property refresh debounce ----
    std::atomic<bool>                 m_propRefreshPending{false};
    std::chrono::steady_clock::time_point m_lastPropRefresh;

    // ---- Error ----
    mutable std::string               m_lastError;
    mutable uint32_t                  m_lastErrorCode = 0;

    // =========================================================================
    // Helpers
    // =========================================================================

    void cleanup()
    {
        if (m_lvStreaming) stopLiveViewStreaming();
        if (m_connected) doDisconnect();
        if (m_enumList) { m_enumList->Release(); m_enumList = nullptr; }
        if (m_sdkInit) {
            SDK::Release();
            m_sdkInit = false;
        }
    }

    void log(const std::string& msg)
    {
        if (m_logCallback) m_logCallback("[Sony] " + msg);
    }

    void setError(const std::string& msg, uint32_t code = 1)
    {
        m_lastError = msg;
        m_lastErrorCode = code;
        log("ERROR: " + msg);
    }

    void fireEvent(const CameraEvent& ev)
    {
        std::lock_guard<std::mutex> lk(m_listenerMutex);
        for (auto* l : m_listeners) {
            if (l) l->onCameraEvent(ev);
        }
    }

    void fireSimpleEvent(CameraEventType type, const std::string& msg = "")
    {
        CameraEvent ev;
        ev.type    = type;
        ev.message = msg;
        fireEvent(ev);
    }

    // =========================================================================
    // SDK Helpers
    // =========================================================================

    static std::string wcharToStr(const CrChar* ws)
    {
        if (!ws) return "";
#if defined(_UNICODE) || defined(UNICODE)
        const wchar_t* wp = (const wchar_t*)ws;
        if (!wp) return "";
        int sz = WideCharToMultiByte(CP_UTF8, 0, wp, -1, nullptr, 0, nullptr, nullptr);
        if (sz <= 0) return "";
        std::string s(sz - 1, '\0');
        WideCharToMultiByte(CP_UTF8, 0, wp, -1, &s[0], sz, nullptr, nullptr);
        return s;
#else
        return std::string((const char*)ws);
#endif
    }

    // =========================================================================
    // Property System
    // =========================================================================

    void refreshAllProperties()
    {
        if (!m_connected || !m_handle) return;

        SDK::CrDeviceProperty* propList = nullptr;
        CrInt32 nProp = 0;

        auto status = SDK::GetDeviceProperties(m_handle, &propList, &nProp);
        if (CR_FAILED(status) || !propList || nProp <= 0) {
            if (propList) SDK::ReleaseDeviceProperties(m_handle, propList);
            return;
        }

        std::lock_guard<std::mutex> lk(m_propMutex);
        for (int i = 0; i < nProp; i++) {
            auto& p = propList[i];
            auto  code = (SDK::CrDevicePropertyCode)p.GetCode();

            PropInfo info;
            info.code     = code;
            info.current  = p.GetCurrentValue();
            info.writable = p.IsSetEnableCurrentValue() == 1;

            CrInt32u rawSz = p.GetValueSize();
            if (rawSz > 0 && p.GetValues()) {
                const CrInt8u* raw = p.GetValues();
                bool is16 = (code == SDK::CrDeviceProperty_FNumber         ||
                             code == SDK::CrDeviceProperty_WhiteBalance     ||
                             code == SDK::CrDeviceProperty_FocusMode        ||
                             code == SDK::CrDeviceProperty_StillImageStoreDestination ||
                             code == SDK::CrDeviceProperty_ExposureProgramMode);
                size_t elemSz = is16 ? sizeof(CrInt16u) : sizeof(CrInt32u);
                int cnt = (int)(rawSz / elemSz);
                info.valid.resize(cnt);
                for (int j = 0; j < cnt; j++) {
                    info.valid[j] = is16
                        ? ((const CrInt16u*)raw)[j]
                        : ((const CrInt32u*)raw)[j];
                }
            }

            m_props[code] = std::move(info);
        }

        SDK::ReleaseDeviceProperties(m_handle, propList);
        updateStateFromProps();
    }

    void refreshSelectProperties(CrInt32u num, CrInt32u* codes)
    {
        if (!m_connected || !m_handle) return;
        SDK::CrDeviceProperty* propList = nullptr;
        CrInt32 nProp = 0;
        auto status = SDK::GetSelectDeviceProperties(m_handle, num, codes, &propList, &nProp);
        if (CR_FAILED(status) || !propList) {
            if (propList) SDK::ReleaseDeviceProperties(m_handle, propList);
            return;
        }

        std::lock_guard<std::mutex> lk(m_propMutex);
        for (int i = 0; i < nProp; i++) {
            auto& p    = propList[i];
            auto  code = (SDK::CrDevicePropertyCode)p.GetCode();
            auto  it   = m_props.find(code);
            if (it != m_props.end()) {
                it->second.current  = p.GetCurrentValue();
                it->second.writable = p.IsSetEnableCurrentValue() == 1;
            } else {
                // Property wasn't cached on connect (e.g. Colortemp is only
                // reported by the camera when WB = Color Temperature mode).
                // Insert it now so subsequent state reads pick it up.
                PropInfo info;
                info.current  = p.GetCurrentValue();
                info.writable = p.IsSetEnableCurrentValue() == 1;
                int cnt = (int)p.GetValueSize();
                bool is16 = (code == SDK::CrDeviceProperty_WhiteBalance);
                size_t elemSz = is16 ? sizeof(CrInt16u) : sizeof(CrInt32u);
                const uint8_t* raw = static_cast<const uint8_t*>(p.GetValues());
                if (raw && cnt > 0) {
                    for (int j = 0; j < cnt / (int)elemSz; ++j)
                        info.valid.push_back(is16
                            ? ((const CrInt16u*)raw)[j]
                            : ((const CrInt32u*)raw)[j]);
                }
                m_props[code] = std::move(info);
            }
        }

        SDK::ReleaseDeviceProperties(m_handle, propList);
        updateStateFromProps();
    }

    void updateStateFromProps()
    {
        // ISO: lower 24 bits = ISO value, 0x00FFFFFF = Auto
        {
            auto it = m_props.find(SDK::CrDeviceProperty_IsoSensitivity);
            if (it != m_props.end()) {
                CrInt32u raw = (CrInt32u)it->second.current;
                CrInt32u isoVal = raw & 0x00FFFFFF;
                m_state.setIso(isoVal == 0x00FFFFFF ? 0 : (int)isoVal);
            }
        }
        // FNumber: * 100
        {
            auto it = m_props.find(SDK::CrDeviceProperty_FNumber);
            if (it != m_props.end()) m_state.setAv((int)(CrInt16u)it->second.current);
        }
        // Shutter speed: Sony packed (num<<16)|den
        {
            auto it = m_props.find(SDK::CrDeviceProperty_ShutterSpeed);
            if (it != m_props.end()) m_state.setTv((int)(CrInt32u)it->second.current);
        }
        // White balance (Sony code → canon code)
        {
            auto it = m_props.find(SDK::CrDeviceProperty_WhiteBalance);
            if (it != m_props.end()) {
                CrInt16u sv = (CrInt16u)it->second.current;
                m_state.setWb((int)sonyWbToCanon(sv));
            }
        }
        // Exposure compensation
        {
            auto it = m_props.find(SDK::CrDeviceProperty_ExposureBiasCompensation);
            if (it != m_props.end()) m_state.setEv((int)(CrInt32u)it->second.current);
        }
        // Battery
        {
            auto it = m_props.find(SDK::CrDeviceProperty_BatteryRemain);
            if (it != m_props.end()) m_state.setBattery((int)it->second.current);
        }
        // Color temperature
        {
            auto it = m_props.find(SDK::CrDeviceProperty_Colortemp);
            if (it != m_props.end()) m_state.setColorTemp((int)it->second.current);
        }
    }

    // ---- Canon ↔ Sony property mapping ----

    // Map a Canon EdsPropertyID to a Sony CrDevicePropertyCode
    static SDK::CrDevicePropertyCode canonPropToSony(uint32_t canonId)
    {
        switch (canonId) {
            case CANON_PROP_ISO:       return SDK::CrDeviceProperty_IsoSensitivity;
            case CANON_PROP_AV:        return SDK::CrDeviceProperty_FNumber;
            case CANON_PROP_TV:        return SDK::CrDeviceProperty_ShutterSpeed;
            case CANON_PROP_WB:        return SDK::CrDeviceProperty_WhiteBalance;
            case CANON_PROP_EV:        return SDK::CrDeviceProperty_ExposureBiasCompensation;
            case CANON_PROP_COLORTEMP: return SDK::CrDeviceProperty_Colortemp;
            default:                   return SDK::CrDeviceProperty_Undefined;
        }
    }

    // Sony White Balance code → Canon WB code
    static int sonyWbToCanon(CrInt16u sonyWb)
    {
        switch (sonyWb) {
            case 0x0001: return 0;   // Auto
            case 0x0002: return 1;   // Daylight
            case 0x0003: return 2;   // Shade / Shadow
            case 0x0004: return 3;   // Cloudy
            case 0x0005: return 4;   // Tungsten/Incandescent
            case 0x0006: return 5;   // Fluorescent
            case 0x0007: return 6;   // Flash
            case 0x001F: return 8;   // Custom WB 1
            case 0x0010: return 9;   // Color Temperature
            case 0x000B: return 10;  // Underwater (no Canon equivalent)
            default:     return 0;
        }
    }

    // Canon WB code → Sony WB code
    static CrInt16u canonWbToSony(int canonWb)
    {
        switch (canonWb) {
            case 0:  return 0x0001;  // Auto
            case 1:  return 0x0002;  // Daylight
            case 2:  return 0x0003;  // Shade
            case 3:  return 0x0004;  // Cloudy
            case 4:  return 0x0005;  // Tungsten
            case 5:  return 0x0006;  // Fluorescent
            case 6:  return 0x0007;  // Flash
            case 8:  return 0x001F;  // Custom WB 1
            case 9:  return 0x0010;  // Color Temperature
            default: return 0x0001;
        }
    }

    // ---- ISO formatting ----
    static std::string formatIso(CrInt32u raw)
    {
        CrInt32u isoVal = raw & 0x00FFFFFF;
        if (isoVal == 0x00FFFFFF) return "Auto";
        CrInt32u mode = (raw >> 24) & 0x0F;
        if (mode == 1) return "MFNR " + std::to_string(isoVal);
        return std::to_string(isoVal);
    }

    // ---- FNumber (aperture) formatting ----
    static std::string formatFNumber(CrInt16u raw)
    {
        if (raw == 0xFFFD) return "Iris Close";
        if (raw == 0xFFFE || raw == 0xFFFF) return "--";
        char buf[24];
        snprintf(buf, sizeof(buf), "f/%.1f", raw / 100.0f);
        return buf;
    }

    // ---- Shutter speed formatting ----
    static std::string formatShutterSpeed(CrInt32u raw)
    {
        if (raw == 0x00000000) return "BULB";
        if (raw == 0xFFFFFFFF) return "N/A";
        CrInt16u num = (CrInt16u)((raw >> 16) & 0xFFFF);
        CrInt16u den = (CrInt16u)(raw & 0xFFFF);
        char buf[32];
        if (den == 0) {
            snprintf(buf, sizeof(buf), "%d\"", num);
            return buf;
        }
        if (num == 1) {
            snprintf(buf, sizeof(buf), "1/%d", den);
            return buf;
        }
        if (num % den == 0) {
            snprintf(buf, sizeof(buf), "%d\"", num / den);
            return buf;
        }
        snprintf(buf, sizeof(buf), "%.1f\"", (double)num / den);
        return buf;
    }

    // ---- White balance label ----
    // Covers all known Sony CrWhiteBalanceSetting values (see CrDefines.h)
    static std::string formatWb(CrInt16u raw)
    {
        switch (raw) {
            case 0x0000: return "Tự động";            // Auto (some bodies)
            case 0x0001: return "Tự động";            // Auto
            case 0x0002: return "Ánh sáng ban ngày";   // Daylight
            case 0x0003: return "Bóng râm";            // Shade
            case 0x0004: return "Có mây";              // Cloudy
            case 0x0005: return "Đèn dây tóc";         // Tungsten/Incandescent
            case 0x0006: return "Đèn huỳnh quang";     // Fluorescent
            case 0x0007: return "Đèn Flash";           // Flash
            case 0x000B: return "Dưới nước";           // Underwater
            case 0x0010: return "Nhiệt độ màu";        // Color Temperature
            case 0x0011: return "Tùy chỉnh";           // Custom (color filter)
            case 0x0012: return "Tự động (ưu tiên ấm)"; // Auto WB – Ambience (warm)
            case 0x0013: return "Tự động (ưu tiên trắng)"; // Auto WB – White priority
            case 0x0014: return "Tự động (ưu tiên tự nhiên)"; // Auto WB – Natural
            case 0x0022: return "Đèn huỳnh quang ấm";  // Fluorescent Warm White
            case 0x0023: return "Đèn huỳnh quang lạnh"; // Fluorescent Cool White
            case 0x0024: return "Đèn huỳnh quang ban ngày"; // Fluorescent Daylight
            case 0x0030: return "CT (tùy chỉnh)";      // Color Temperature – custom range
            case 0x001F: return "Tùy chỉnh 1";         // Custom WB 1
            case 0x0020: return "Tùy chỉnh 2";         // Custom WB 2
            case 0x0021: return "Tùy chỉnh 3";         // Custom WB 3
            case 0x0100: return "Đèn huỳnh quang TL84"; // TL84 fluorescent
            case 0x0101: return "Đèn huỳnh quang CWF";  // Cool White fluorescent
            case 0x0102: return "Đèn huỳnh quang D50";  // D50 fluorescent
            case 0x0103: return "Đèn huỳnh quang D65";  // D65 fluorescent
            default: {
                char buf[24];
                snprintf(buf, sizeof(buf), "WB 0x%04X", raw);
                return buf;
            }
        }
    }

    // ---- Exposure compensation label ----
    static std::string formatEv(CrInt32u raw)
    {
        // Sony EV: signed value in 1/3-stop units (3 = +1/3, 8 = +1, -8 = -1)
        // This matches Canon encoding
        auto sv = (int32_t)raw;
        if (sv == 0) return "0";
        char buf[24];
        int thirds = std::abs(sv);
        int stops  = thirds / 8;
        int rem    = thirds % 8;
        const char* sign = sv > 0 ? "+" : "-";
        if (rem == 0)       snprintf(buf, sizeof(buf), "%s%d", sign, stops);
        else if (rem == 3)  snprintf(buf, sizeof(buf), "%s%d 1/3", sign, stops);
        else if (rem == 5)  snprintf(buf, sizeof(buf), "%s%d 2/3", sign, stops);
        else                snprintf(buf, sizeof(buf), "%s%d (%d)", sign, stops, rem);
        return buf;
    }

    // ---- Query Sony camera for a property list ----
    // Returns human-readable list + current value string
    bool getPropertyStringsInternal(uint32_t canonPropId,
                                    std::vector<std::string>& outList,
                                    std::string& outCurrent)
    {
        auto sonyCode = canonPropToSony(canonPropId);
        if (sonyCode == SDK::CrDeviceProperty_Undefined) {
            setError("Unknown Canon property ID: " + std::to_string(canonPropId));
            return false;
        }

        std::lock_guard<std::mutex> lk(m_propMutex);
        auto it = m_props.find(sonyCode);
        if (it == m_props.end()) {
            setError("Property not in cache for code: " + std::to_string(sonyCode));
            return false;
        }

        const PropInfo& info = it->second;
        outList.clear();

        switch (sonyCode) {
        case SDK::CrDeviceProperty_IsoSensitivity:
            outCurrent = formatIso((CrInt32u)info.current);
            for (auto v : info.valid) outList.push_back(formatIso((CrInt32u)v));
            break;

        case SDK::CrDeviceProperty_FNumber:
            outCurrent = formatFNumber((CrInt16u)info.current);
            for (auto v : info.valid) outList.push_back(formatFNumber((CrInt16u)v));
            break;

        case SDK::CrDeviceProperty_ShutterSpeed:
            outCurrent = formatShutterSpeed((CrInt32u)info.current);
            for (auto v : info.valid) outList.push_back(formatShutterSpeed((CrInt32u)v));
            break;

        case SDK::CrDeviceProperty_WhiteBalance:
            outCurrent = formatWb((CrInt16u)info.current);
            for (auto v : info.valid) outList.push_back(formatWb((CrInt16u)v));
            break;

        case SDK::CrDeviceProperty_ExposureBiasCompensation:
            outCurrent = formatEv((CrInt32u)info.current);
            for (auto v : info.valid) outList.push_back(formatEv((CrInt32u)v));
            break;

        case SDK::CrDeviceProperty_Colortemp:
            outCurrent = std::to_string(info.current);
            for (auto v : info.valid) outList.push_back(std::to_string(v));
            break;

        default:
            outCurrent = std::to_string(info.current);
            for (auto v : info.valid) outList.push_back(std::to_string(v));
            break;
        }

        return !outList.empty();
    }

    // ---- Set a property by Sony code ----
    bool setSonyProperty(SDK::CrDevicePropertyCode code, CrInt64u value, bool is16 = false)
    {
        if (!m_connected || !m_handle) {
            setError("Camera not connected");
            return false;
        }

        SDK::CrDeviceProperty prop;
        prop.SetCode(code);
        prop.SetCurrentValue(value);
        prop.SetValueType(is16 ? SDK::CrDataType_UInt16Array : SDK::CrDataType_UInt32Array);

        auto err = SDK::SetDeviceProperty(m_handle, &prop);
        if (CR_FAILED(err)) {
            std::ostringstream ss;
            ss << "SetDeviceProperty 0x" << std::hex << (int)code
               << " = 0x" << value << " failed: 0x" << err;
            setError(ss.str(), (uint32_t)err);
            return false;
        }

        {
            std::ostringstream ss;
            ss << "SetDeviceProperty OK: code=0x" << std::hex << (int)code
               << " value=0x" << value;
            log(ss.str());
        }

        // Refresh this single property so m_props stays current
        CrInt32u c = (CrInt32u)code;
        refreshSelectProperties(1, &c);

        // Fire PropertyChanged so CameraEventBridge (Qt side) refreshes
        // isoList / shutterSpeedList / apertureList and emits currentXxxChanged
        fireSimpleEvent(CameraEventType::PropertyChanged, "Property set");
        return true;
    }

    // ---- Parse shutter speed string → Sony packed value ----
    static CrInt32u parseShutterSpeed(const std::string& s)
    {
        std::string str = s;
        // Strip trailing quote/inch characters
        while (!str.empty() && (str.back() == '"' || str.back() == '\'' || str.back() == 's'))
            str.pop_back();

        if (str == "BULB" || str == "bulb") return 0x00000000;

        // "1/XXX" format → sub-second
        auto slashPos = str.find('/');
        if (slashPos != std::string::npos) {
            int num = std::stoi(str.substr(0, slashPos));
            int den = std::stoi(str.substr(slashPos + 1));
            return (CrInt32u)((num << 16) | den);
        }

        // Decimal seconds → e.g., "2.5" seconds
        auto dotPos = str.find('.');
        if (dotPos != std::string::npos) {
            double secs = std::stod(str);
            int num = (int)(secs * 10);
            int den_scaled = 10;
            // Simplify
            return (CrInt32u)((num << 16) | den_scaled);
        }

        // Whole seconds → e.g., "2"
        int secs = std::stoi(str);
        return (CrInt32u)(secs << 16);   // den = 0 means whole seconds
    }

    // ---- Parse aperture string → Sony FNumber value ----
    static CrInt16u parseAperture(const std::string& s)
    {
        std::string str = s;
        // Strip "f/" prefix
        if (str.size() > 2 && (str[0] == 'f' || str[0] == 'F') && str[1] == '/')
            str = str.substr(2);
        try {
            double fstop = std::stod(str);
            return (CrInt16u)(int)(fstop * 100.0 + 0.5);
        } catch (...) {
            return 0;
        }
    }

    // ---- Connection ----

    bool doConnect(int index)
    {
        if (!m_enumList || index < 0) return false;

        const SDK::ICrCameraObjectInfo* cam = m_enumList->GetCameraObjectInfo(index);
        if (!cam) { setError("Null camera info at index " + std::to_string(index)); return false; }

        log("Connecting to camera " + std::to_string(index) + "...");

        auto err = SDK::Connect(const_cast<SDK::ICrCameraObjectInfo*>(cam),
                                this, &m_handle,
                                SDK::CrSdkControlMode_Remote,
                                SDK::CrReconnecting_ON);
        if (CR_FAILED(err)) {
            std::ostringstream ss;
            ss << "Connect failed: 0x" << std::hex << err;
            setError(ss.str(), (uint32_t)err);
            return false;
        }

        m_connected = true;
        m_connectedIndex = index;
        log("Connected OK.");

        // Enable live view
        SDK::SetDeviceSetting(m_handle, SDK::Setting_Key_EnableLiveView,
                              (CrInt32u)SDK::CrDeviceSetting_Enable);

        // Enable PostView — delivers captured JPEG to OnCompleteDownload
        SDK::SetDeviceSetting(m_handle, SDK::Setting_Key_EnablePostView,
                              (CrInt32u)SDK::CrDeviceSetting_Enable);
        SDK::SetDeviceSetting(m_handle, SDK::Setting_Key_PostViewTransferringType,
                              (CrInt32u)SDK::CrPostViewTransferring_Legacy);

        // Load all properties
        refreshAllProperties();

        // Set save path
        if (!m_savePath.empty()) applySavePath();
        else {
#ifdef _WIN32
            wchar_t picDir[MAX_PATH] = {};
            if (SUCCEEDED(SHGetFolderPathW(nullptr, 0x0027, nullptr, 0, picDir))) {
                int sz = WideCharToMultiByte(CP_UTF8, 0, picDir, -1, nullptr, 0, nullptr, nullptr);
                if (sz > 0) {
                    std::string utf8(sz - 1, '\0');
                    WideCharToMultiByte(CP_UTF8, 0, picDir, -1, &utf8[0], sz, nullptr, nullptr);
                    m_savePath = utf8;
                    applySavePath();
                }
            }
#endif
        }

        // Get model name
        const CrChar* model = cam->GetModel();
        m_cameraModel = wcharToStr(model);

        return true;
    }

    void doDisconnect()
    {
        if (!m_connected) return;
        log("Disconnecting...");
        if (m_lvStreaming) stopLiveViewStreaming();
        SDK::Disconnect(m_handle);
        SDK::ReleaseDevice(m_handle);
        m_handle = 0;
        m_connected = false;
        m_movieRecording = false;
        { std::lock_guard<std::mutex> lk(m_propMutex); m_props.clear(); }
        log("Disconnected.");
    }

    bool applySavePath()
    {
        if (!m_connected || !m_handle || m_savePath.empty()) return false;

        auto fsp = std::filesystem::u8path(m_savePath);
        std::wstring wpath = fsp.wstring();
        while (!wpath.empty() && (wpath.back() == L'\\' || wpath.back() == L'/'))
            wpath.pop_back();

        std::wstring emptyPrefix;
        auto err = SDK::SetSaveInfo(m_handle,
                                    (CrChar*)wpath.c_str(),
                                    (CrChar*)emptyPrefix.c_str(),
                                    -1);
        if (CR_FAILED(err)) {
            std::ostringstream ss;
            ss << "SetSaveInfo failed: 0x" << std::hex << (uint32_t)err;
            setError(ss.str(), (uint32_t)err);
            return false;
        }
        log("Save path: " + m_savePath);
        return true;
    }

    // ---- Capture ----

    bool capture(bool forceAF = false)
    {
        if (!m_connected) { setError("Not connected"); return false; }

        bool useAF = forceAF;
        if (!forceAF) {
            // Auto-detect: if focus mode != MF use AF+Release
            std::lock_guard<std::mutex> lk(m_propMutex);
            auto it = m_props.find(SDK::CrDeviceProperty_FocusMode);
            if (it != m_props.end())
                useAF = ((CrInt16u)it->second.current != 1); // 1 = MF
            else
                useAF = true;
        }

        log(useAF ? "Capture: AF+Release..." : "Capture: Release (MF)...");
        SDK::CrCommandId cmd = useAF ? SDK::CrCommandId_S1andRelease : SDK::CrCommandId_Release;

        auto err = SDK::SendCommand(m_handle, cmd, SDK::CrCommandParam_Down);
        if (CR_FAILED(err)) {
            std::ostringstream ss;
            ss << "Capture Down rejected: 0x" << std::hex << (uint32_t)err;
            setError(ss.str(), (uint32_t)err);
            return false;
        }
        std::this_thread::sleep_for(useAF ? 800ms : 100ms);

        SDK::SendCommand(m_handle, cmd, SDK::CrCommandParam_Up);
        log("Capture Up sent.");
        return true;
    }

    // ---- Live View ----

    bool getLiveViewJpeg(std::vector<uint8_t>& out)
    {
        if (!m_connected || !m_handle) return false;

        SDK::CrImageInfo inf;
        auto err = SDK::GetLiveViewImageInfo(m_handle, &inf);
        if (CR_FAILED(err)) return false;

        CrInt32u bufSz = inf.GetBufferSize();
        if (bufSz < 1) return false;

        if (m_lvBuffer.size() < bufSz) m_lvBuffer.resize(bufSz);

        SDK::CrImageDataBlock imgData;
        imgData.SetSize(bufSz);
        imgData.SetData(m_lvBuffer.data());

        err = SDK::GetLiveViewImage(m_handle, &imgData);
        if (CR_FAILED(err)) return false;

        CrInt32u imgSz = imgData.GetImageSize();
        if (imgSz == 0) return false;

        const CrInt8u* imgPtr = imgData.GetImageData();
        out.assign(imgPtr, imgPtr + imgSz);
        return true;
    }

    void stopLiveViewStreaming()
    {
        m_lvStreaming = false;
        if (m_lvThread.joinable()) m_lvThread.join();
    }

    void startLiveViewStreamingThread()
    {
        if (m_lvStreaming) return;
        m_lvStreaming = true;
        m_lvThread = std::thread([this]() {
            log("Live view streaming thread started (adaptive ~25 fps).");
            std::vector<uint8_t> jpegBuf;
            using clock = std::chrono::steady_clock;
            // Target 25 fps (40ms/frame). More sustainable than 30fps on weak CPUs.
            // Deadline-based: sleep until the NEXT deadline rather than fixed post-sleep.
            // If fetch takes longer than 40ms the next tick fires immediately (no buildup).
            constexpr auto kFrameInterval = std::chrono::milliseconds(40);
            auto nextFrame = clock::now() + kFrameInterval;
            while (m_lvStreaming.load() && m_connected.load()) {
                if (getLiveViewJpeg(jpegBuf) && !jpegBuf.empty()) {
                    if (m_lvCallback) {
                        m_lvCallback(jpegBuf.data(), jpegBuf.size());
                    }
                }
                auto now = clock::now();
                if (nextFrame > now)
                    std::this_thread::sleep_until(nextFrame);
                else
                    nextFrame = now; // re-sync: we're running behind, skip catch-up burst
                nextFrame += kFrameInterval;
            }
            log("Live view streaming thread stopped.");
        });
    }

    // =========================================================================
    // IDeviceCallback implementation
    // =========================================================================

    void OnConnected(SDK::DeviceConnectionVersioin /*version*/) override
    {
        log("OnConnected callback received.");
        fireSimpleEvent(CameraEventType::Connected, "Camera connected");
    }

    void OnDisconnected(CrInt32u error) override
    {
        std::ostringstream ss;
        ss << "Camera disconnected (0x" << std::hex << error << ")";
        log(ss.str());
        m_connected = false;
        m_movieRecording = false;
        fireSimpleEvent(CameraEventType::Disconnected, ss.str());
    }

    void OnPropertyChanged() override
    {
        // Refresh cache FIRST so fetchCameraPropertyLists() reads fresh data when
        // CameraEventBridge handles PropertyChanged immediately after this call.
        refreshAllProperties();
        m_propRefreshPending = false;
        fireSimpleEvent(CameraEventType::PropertyChanged, "Properties changed");
    }

    void OnPropertyChangedCodes(CrInt32u num, CrInt32u* codes) override
    {
        // Refresh cache FIRST (selected props or all) before firing event
        if (num > 0 && codes) {
            refreshSelectProperties(num, codes);
        } else {
            refreshAllProperties();
        }
        m_propRefreshPending = false;
        fireSimpleEvent(CameraEventType::PropertyChanged, "Properties changed");
    }

    void OnLvPropertyChanged() override {}
    void OnLvPropertyChangedCodes(CrInt32u, CrInt32u*) override {}

    void OnCompleteDownload(CrChar* filename, CrInt32u type) override
    {
        std::string fn = wcharToStr(filename);
        log("OnCompleteDownload: " + fn + " type=" + std::to_string(type));

        if (type == SDK::CrDownloadSettingFileType_None) {
            // Skip RAW files
            std::string lower = fn;
            std::transform(lower.begin(), lower.end(), lower.begin(),
                           [](unsigned char c){ return (char)std::tolower(c); });
            bool isRaw = (lower.size() >= 4 &&
                         (lower.compare(lower.size()-4, 4, ".arw") == 0 ||
                          lower.compare(lower.size()-4, 4, ".raw") == 0));
            if (isRaw) {
                std::error_code ec;
                std::filesystem::remove(std::filesystem::u8path(fn), ec);
                log("RAW deleted: " + fn);
                return;
            }

            m_lastPhotoPath = fn;
            log("Photo saved: " + fn);

            // Fire CaptureCompleted event with filename
            CameraEvent ev;
            ev.type     = CameraEventType::CaptureCompleted;
            ev.message  = "Photo captured";
            ev.fileName = fn;
            fireEvent(ev);
        }
    }

    void OnWarning(CrInt32u warning) override
    {
        std::ostringstream ss;
        ss << "Warning: 0x" << std::hex << warning;
        log(ss.str());

        if (warning == SDK::CrNotify_Captured_Event) {
            // Exposure started / shutter fired
            fireSimpleEvent(CameraEventType::CaptureStarted, "Shutter fired");
        }
    }

    void OnWarningExt(CrInt32u warning, CrInt32 p1, CrInt32 p2, CrInt32 p3) override
    {
        (void)p2; (void)p3;
        if (warning == SDK::CrWarningExt_AFStatus) {
            const char* s = nullptr;
            switch (p1) {
                case SDK::CrWarningExt_AFStatusParam_Focused_AF_S:         s = "AF Focused"; break;
                case SDK::CrWarningExt_AFStatusParam_NotFocused_AF_S:      s = "AF Not Focused"; break;
                case SDK::CrWarningExt_AFStatusParam_TrackingSubject_AF_C: s = "AF Tracking"; break;
                default: break;
            }
            if (s) log(std::string("AF status: ") + s);
        }
    }

    void OnError(CrInt32u error) override
    {
        std::ostringstream ss;
        ss << "Camera error: 0x" << std::hex << error;
        setError(ss.str(), error);

        CameraEvent ev;
        ev.type    = CameraEventType::CaptureError;
        ev.message = ss.str();
        fireEvent(ev);
    }

    void OnNotifyContentsTransfer(CrInt32u notify, SDK::CrContentHandle, CrChar* filename) override
    {
        std::string fn = wcharToStr(filename);
        log("ContentsTransfer notify=0x" + std::to_string(notify) + " file=" + fn);
    }

    void OnNotifyRemoteTransferResult(CrInt32u notify, CrInt32u per, CrChar* filename) override
    {
        std::string fn = wcharToStr(filename);
        if (per == 100 || notify == SDK::CrNotify_RemoteTransfer_Result_OK) {
            m_lastPhotoPath = fn;
            log("RemoteTransfer OK: " + fn);

            CameraEvent ev;
            ev.type     = CameraEventType::CaptureCompleted;
            ev.fileName = fn;
            fireEvent(ev);
        }
    }

    void OnNotifyRemoteTransferResult(CrInt32u, CrInt32u, CrInt8u*, CrInt64u) override {}
    void OnNotifyRemoteTransferContentsListChanged(CrInt32u, CrInt32u, CrInt32u) override {}
    void OnNotifyFTPTransferResult(CrInt32u, CrInt32u, CrInt32u) override {}
    void OnReceivePlaybackTimeCode(CrInt32u) override {}
    void OnReceivePlaybackData(CrInt8u, CrInt32, CrInt8u*, CrInt64, CrInt64, CrInt32, CrInt32) override {}
    void OnNotifyRemoteFirmwareUpdateResult(CrInt32u, const void*) override {}
};

// ============================================================================
// SonyCameraState::getProperty — generic property query by Canon prop ID
// ============================================================================
uint32_t SonyApp::SonyCameraState::getProperty(uint32_t canonPropId) const
{
    switch (canonPropId) {
        case CANON_PROP_ISO:       return (uint32_t)m_iso;
        case CANON_PROP_AV:        return (uint32_t)m_av;
        case CANON_PROP_TV:        return (uint32_t)m_tv;
        case CANON_PROP_WB:        return (uint32_t)m_wb;
        case CANON_PROP_EV:        return (uint32_t)m_ev;
        case CANON_PROP_COLORTEMP: return (uint32_t)m_colorTemp;
        default:                   return 0;
    }
}

// ============================================================================
// SonyCameraController — singleton + forwarding to Impl
// ============================================================================
SonyApp::SonyCameraController& SonyApp::SonyCameraController::instance()
{
    static SonyCameraController inst;
    return inst;
}

SonyApp::SonyCameraController::SonyCameraController()
    : m_impl(std::make_unique<Impl>())
{
}

SonyApp::SonyCameraController::~SonyCameraController() = default;

// ---- Lifecycle ----

bool SonyApp::SonyCameraController::initialize()
{
    if (m_impl->m_sdkInit) return true;

    if (!SDK::Init(0)) {
        m_lastError = "Sony SDK Init() failed";
        m_lastErrorCode = 1;
        return false;
    }

    m_impl->m_sdkInit = true;
    m_impl->log("Sony Camera Remote SDK initialized.");
    return true;
}

void SonyApp::SonyCameraController::shutdown()
{
    m_impl->cleanup();
}

// ---- Discovery ----

bool SonyApp::SonyCameraController::findCameras(std::vector<SonyCameraInfo>& outCameras)
{
    outCameras.clear();
    if (!m_impl->m_sdkInit && !initialize()) return false;

    if (m_impl->m_enumList) {
        m_impl->m_enumList->Release();
        m_impl->m_enumList = nullptr;
    }

    auto err = SDK::EnumCameraObjects(&m_impl->m_enumList, 5);
    if (CR_FAILED(err) || !m_impl->m_enumList) {
        std::ostringstream ss;
        ss << "EnumCameraObjects failed: 0x" << std::hex << err;
        m_lastError = ss.str();
        return false;
    }

    int count = (int)m_impl->m_enumList->GetCount();
    for (int i = 0; i < count; i++) {
        const SDK::ICrCameraObjectInfo* cam = m_impl->m_enumList->GetCameraObjectInfo(i);
        if (!cam) continue;
        SonyCameraInfo info;
        info.index   = i;
        info.name    = Impl::wcharToStr(cam->GetModel());
        info.guid    = Impl::wcharToStr(cam->GetGuid());
        info.portName = "";
        outCameras.push_back(std::move(info));
    }

    m_impl->log("Found " + std::to_string(count) + " Sony camera(s).");
    return true;
}

int SonyApp::SonyCameraController::getCameraCount()
{
    if (!m_impl->m_enumList) return 0;
    return (int)m_impl->m_enumList->GetCount();
}

// ---- Connection ----

bool SonyApp::SonyCameraController::connectCamera(int index)
{
    if (!m_impl->m_sdkInit && !initialize()) return false;
    if (!m_impl->m_enumList) {
        // Auto-enumerate if not done
        std::vector<SonyCameraInfo> tmp;
        if (!findCameras(tmp) || tmp.empty()) {
            m_lastError = "No Sony cameras found";
            return false;
        }
    }
    return m_impl->doConnect(index);
}

bool SonyApp::SonyCameraController::disconnectCamera()
{
    m_impl->doDisconnect();
    return true;
}

bool SonyApp::SonyCameraController::isConnected() const
{
    return m_impl->m_connected.load();
}

// ---- Photo Capture ----

bool SonyApp::SonyCameraController::takePhoto()
{
    return m_impl->capture(false);  // auto-detect AF mode
}

bool SonyApp::SonyCameraController::takePhotoNoAF()
{
    // Force MF mode then capture
    m_impl->setSonyProperty(SDK::CrDeviceProperty_FocusMode, 1, true);  // MF = 1
    std::this_thread::sleep_for(std::chrono::milliseconds(50));
    return m_impl->capture(false);
}

bool SonyApp::SonyCameraController::takeBulbPhoto(int exposureMs)
{
    if (!m_impl->m_connected) return false;
    SDK::SendCommand(m_impl->m_handle, SDK::CrCommandId_Release, SDK::CrCommandParam_Down);
    std::this_thread::sleep_for(std::chrono::milliseconds(exposureMs));
    SDK::SendCommand(m_impl->m_handle, SDK::CrCommandId_Release, SDK::CrCommandParam_Up);
    return true;
}

std::string SonyApp::SonyCameraController::getLastPhotoPath() const
{
    return m_impl->m_lastPhotoPath;
}

// ---- Live View ----

bool SonyApp::SonyCameraController::startLiveView()
{
    // Live view is enabled at Connect time for Sony; no separate command needed
    if (!m_impl->m_connected) return false;
    m_impl->log("Live view ready (enabled at connection time).");
    return true;
}

bool SonyApp::SonyCameraController::stopLiveView()
{
    // Stop streaming if active
    if (m_impl->m_lvStreaming) m_impl->stopLiveViewStreaming();
    return true;
}

bool SonyApp::SonyCameraController::isLiveViewActive() const
{
    return m_impl->m_connected.load();  // LV is always active when connected on Sony
}

bool SonyApp::SonyCameraController::getLiveViewFrame(LiveViewFrame& outFrame)
{
    std::vector<uint8_t> jpeg;
    if (!m_impl->getLiveViewJpeg(jpeg)) return false;
    outFrame.jpegData = std::move(jpeg);
    return true;
}

bool SonyApp::SonyCameraController::startLiveViewStreaming()
{
    if (!m_impl->m_connected) return false;
    m_impl->startLiveViewStreamingThread();
    return true;
}

bool SonyApp::SonyCameraController::stopLiveViewStreaming()
{
    m_impl->stopLiveViewStreaming();
    return true;
}

// ---- Focus ----

bool SonyApp::SonyCameraController::driveLensNear()
{
    if (!m_impl->m_connected) return false;
    auto err = SDK::ExecuteControlCodeValue(m_impl->m_handle, SDK::CrControlCode_NearFar, (CrInt64u)-1);
    return !CR_FAILED(err);
}

bool SonyApp::SonyCameraController::driveLensFar()
{
    if (!m_impl->m_connected) return false;
    auto err = SDK::ExecuteControlCodeValue(m_impl->m_handle, SDK::CrControlCode_NearFar, 1);
    return !CR_FAILED(err);
}

bool SonyApp::SonyCameraController::startAutofocus()
{
    if (!m_impl->m_connected) return false;
    SDK::SendCommand(m_impl->m_handle, SDK::CrCommandId_S1andRelease, SDK::CrCommandParam_Down);
    return true;
}

bool SonyApp::SonyCameraController::stopAutofocus()
{
    if (!m_impl->m_connected) return false;
    SDK::SendCommand(m_impl->m_handle, SDK::CrCommandId_S1andRelease, SDK::CrCommandParam_Up);
    return true;
}

// ---- Camera Parameters ----

bool SonyApp::SonyCameraController::setISO(int iso)
{
    if (!m_impl->m_connected) return false;
    // iso == 0 → Auto (0x00FFFFFF), else use value directly
    CrInt32u sonyVal = (iso <= 0) ? 0x00FFFFFF : (CrInt32u)iso;
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_IsoSensitivity, sonyVal, false);
}

bool SonyApp::SonyCameraController::setShutterSpeed(const std::string& value)
{
    if (!m_impl->m_connected) return false;
    CrInt32u packed = Impl::parseShutterSpeed(value);
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_ShutterSpeed, packed, false);
}

bool SonyApp::SonyCameraController::setAperture(const std::string& value)
{
    if (!m_impl->m_connected) return false;
    CrInt16u fnum = Impl::parseAperture(value);
    if (fnum == 0) return false;
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_FNumber, fnum, true);
}

bool SonyApp::SonyCameraController::setWhiteBalance(int mode)
{
    if (!m_impl->m_connected) return false;
    // If mode is already a raw Sony CrInt16u value (a Sony-only code with no Canon
    // equivalent — e.g. 0x0012 Auto-warm, 0x0013 Auto-white, 0x0022 Fluorescent-warm,
    // 0x0100 TL84, etc.), pass it directly to avoid canonWbToSony() mapping it to Auto.
    static const int kCanonMapped[] = { 0,1,2,3,4,5,6,8,9 };
    bool isCanonCode = false;
    for (int c : kCanonMapped) { if (mode == c) { isCanonCode = true; break; } }

    CrInt16u sonyWb = isCanonCode ? Impl::canonWbToSony(mode) : (CrInt16u)mode;
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_WhiteBalance, sonyWb, true);
}

bool SonyApp::SonyCameraController::setColorTemperature(int kelvin)
{
    if (!m_impl->m_connected) return false;

    // Switch WB to Color Temp mode — after this the camera starts reporting
    // CrDeviceProperty_Colortemp, which may not have been in m_props before.
    m_impl->setSonyProperty(SDK::CrDeviceProperty_WhiteBalance, 0x0010, true);

    // Refresh WB + Colortemp together so Colortemp enters m_props cache
    // (refreshSelectProperties now inserts new entries, so this is safe).
    CrInt32u codes[2] = { (CrInt32u)SDK::CrDeviceProperty_WhiteBalance,
                          (CrInt32u)SDK::CrDeviceProperty_Colortemp };
    m_impl->refreshSelectProperties(2, codes);

    return m_impl->setSonyProperty(SDK::CrDeviceProperty_Colortemp, (CrInt32u)kelvin, false);
}

bool SonyApp::SonyCameraController::setMeteringMode(int mode)
{
    if (!m_impl->m_connected) return false;
    // Canon→Sony metering: 0=Multi, 1=Center, 2=Spot, 3=Center-weighted
    static const CrInt16u sonyMet[] = { 0x8001, 0x8002, 0x8004, 0x8003 };
    CrInt16u sv = (mode >= 0 && mode < 4) ? sonyMet[mode] : 0x8001;
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_MeteringMode, sv, true);
}

bool SonyApp::SonyCameraController::setImageQuality(int quality)
{
    if (!m_impl->m_connected) return false;
    // quality: 0=JPEG Fine, 1=RAW, 2=RAW+JPEG
    // Sony: CrFileType_Jpeg=0x0002, CrFileType_RAW=0x0003, CrFileType_RAW_J=0x0006
    static const CrInt16u sonyQuality[] = { 0x0002, 0x0003, 0x0006 };
    CrInt16u sv = (quality >= 0 && quality < 3) ? sonyQuality[quality] : 0x0002;
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_FileType, sv, true);
}

bool SonyApp::SonyCameraController::setDriveMode(int mode)
{
    if (!m_impl->m_connected) return false;
    // 0=Single, 1=Continuous, 2=Timer 10s, 3=Timer 2s
    static const CrInt32u sonyDrive[] = {
        SDK::CrDrive_Single,
        SDK::CrDrive_Continuous_Hi,
        SDK::CrDrive_Timer_10s,
        SDK::CrDrive_Timer_2s
    };
    CrInt32u sv = (mode >= 0 && mode < 4) ? sonyDrive[mode] : SDK::CrDrive_Single;
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_DriveMode, sv, false);
}

bool SonyApp::SonyCameraController::setExposureComp(int stopValue)
{
    if (!m_impl->m_connected) return false;
    // Sony EV encoding matches Canon (3 units = 1/3 stop, 8 = 1 stop)
    return m_impl->setSonyProperty(SDK::CrDeviceProperty_ExposureBiasCompensation,
                                   (CrInt32u)(int32_t)stopValue, false);
}

// ---- Property Strings ----

bool SonyApp::SonyCameraController::getPropertyStrings(uint32_t canonPropId,
                                                        std::vector<std::string>& outList,
                                                        std::string& outCurrent)
{
    return m_impl->getPropertyStringsInternal(canonPropId, outList, outCurrent);
}

bool SonyApp::SonyCameraController::setParameters(const CameraApp::CameraParameters& params)
{
    bool ok = true;
    ok &= setISO(params.iso);
    ok &= setShutterSpeed(params.shutterSpeed);
    ok &= setAperture(params.aperture);
    ok &= setWhiteBalance(params.whiteBalance);
    ok &= setColorTemperature(params.colorTemperature);
    ok &= setExposureComp(params.exposureComp);
    return ok;
}

bool SonyApp::SonyCameraController::getParameters(CameraApp::CameraParameters& params) const
{
    const auto* s = getState();
    if (!s) return false;
    params.iso          = s->iso();
    params.whiteBalance = s->whiteBalance();
    params.exposureComp = s->exposureComp();
    params.colorTemperature = s->getProperty(CANON_PROP_COLORTEMP);
    return true;
}

// ---- Image Management ----

void SonyApp::SonyCameraController::setSaveFolder(const std::string& folderPath)
{
    m_impl->m_savePath = folderPath;
    if (m_impl->m_connected) m_impl->applySavePath();
}

std::string SonyApp::SonyCameraController::getSaveFolder() const
{
    return m_impl->m_savePath;
}

// ---- State & Diagnostics ----

const SonyApp::SonyCameraState* SonyApp::SonyCameraController::getState() const
{
    if (!m_impl->m_connected) return nullptr;
    return &m_impl->m_state;
}

std::string SonyApp::SonyCameraController::getCameraModel() const
{
    return m_impl->m_cameraModel;
}

std::string SonyApp::SonyCameraController::getLastError() const
{
    return m_impl->m_lastError;
}

// ---- Callbacks ----

void SonyApp::SonyCameraController::addEventListener(ICameraEventListener* listener)
{
    std::lock_guard<std::mutex> lk(m_impl->m_listenerMutex);
    m_impl->m_listeners.push_back(listener);
}

void SonyApp::SonyCameraController::removeEventListener(ICameraEventListener* listener)
{
    std::lock_guard<std::mutex> lk(m_impl->m_listenerMutex);
    auto& v = m_impl->m_listeners;
    v.erase(std::remove(v.begin(), v.end(), listener), v.end());
}

void SonyApp::SonyCameraController::setLogCallback(std::function<void(const std::string&)> cb)
{
    m_impl->m_logCallback = std::move(cb);
}

void SonyApp::SonyCameraController::setLiveViewFrameCallback(std::function<void(const uint8_t*, size_t)> cb)
{
    m_impl->m_lvCallback = std::move(cb);
}
