#include "CameraController.h"
#include <windows.h>
#include <shlobj.h>
#include <sstream>
#include <iomanip>
#include <thread>
#include <chrono>
#include <filesystem>

namespace SDK = SCRSDK;
using namespace std::chrono_literals;

CameraController::CameraController()
    : m_handle(0)
    , m_connected(false)
    , m_movie_recording(false)
    , m_enum_list(nullptr)
    , m_connected_index(-1)
    , m_battery_remain(0)
    , m_has_new_log(false)
    , m_log_file(nullptr)
    , m_capture_log_file(nullptr)
    , m_prop_refresh_pending(false)
    , m_last_prop_refresh(std::chrono::steady_clock::now())
    , m_downloading(false)
    , m_download_notify(0)
{
}

CameraController::~CameraController()
{
    Shutdown();
}

bool CameraController::Initialize()
{
    // Open log file next to the exe
    wchar_t exePath[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    wchar_t* slash = wcsrchr(exePath, L'\\');
    if (slash) wcscpy_s(slash + 1, MAX_PATH - (slash - exePath + 1), L"RemoteCliGUI.log");
    // Open in append mode; previous runs are preserved
    errno_t err = _wfopen_s(&m_log_file, exePath, L"a");
    if (err != 0) {
        m_log_file = nullptr;
        return false;
    }

    // Open capture log file
    if (slash) wcscpy_s(slash + 1, MAX_PATH - (slash - exePath + 1), L"RemoteCliGUI_Capture.log");
    errno_t cap_err = _wfopen_s(&m_capture_log_file, exePath, L"a");
    if (cap_err != 0) {
        m_capture_log_file = nullptr;
    }

    Log("=== RemoteCliGUI session start ===");
    CaptureLog("=== Capture log start ===");
    return true;
}

void CameraController::Shutdown()
{
    if (m_connected) Disconnect();
    if (m_enum_list) { m_enum_list->Release(); m_enum_list = nullptr; }
    m_camera_names.clear();

    Log("=== RemoteCliGUI session end ===");
    CaptureLog("=== Capture log end ===");
    std::lock_guard<std::mutex> lk(m_file_log_mutex);
    if (m_log_file) { fclose(m_log_file); m_log_file = nullptr; }
    if (m_capture_log_file) { fclose(m_capture_log_file); m_capture_log_file = nullptr; }
}

// ---- Per-frame update (called from GUI render thread) ----

void CameraController::TickUpdate()
{
    if (!m_connected) return;

    // Property refresh: max 2 times per second to avoid USB saturation
    if (m_prop_refresh_pending.load()) {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                           now - m_last_prop_refresh).count();
        if (elapsed >= 500) {
            m_prop_refresh_pending = false;
            m_last_prop_refresh = now;
            RefreshProperties();
        }
    }
}

// ---- Enumeration & Connection ----

bool CameraController::Enumerate(int timeout_sec)
{
    if (m_enum_list) { m_enum_list->Release(); m_enum_list = nullptr; }
    m_camera_names.clear();

    Log("Enumerating cameras (" + std::to_string(timeout_sec) + "s)...");

    auto err = SDK::EnumCameraObjects(&m_enum_list, (CrInt8u)timeout_sec);
    if (CR_FAILED(err) || !m_enum_list) {
        Log("Enumeration failed.");
        return false;
    }

    int count = (int)m_enum_list->GetCount();
    for (int i = 0; i < count; i++) {
        const SDK::ICrCameraObjectInfo* cam = m_enum_list->GetCameraObjectInfo(i);
        if (!cam) continue;
        std::string model = WCharToStr(cam->GetModel());
        std::string id    = WCharToStr(cam->GetGuid());
        m_camera_names.push_back(model + " (" + id + ")");
    }

    Log("Found " + std::to_string(count) + " camera(s).");
    return count > 0;
}

bool CameraController::Connect(int index)
{
    if (!m_enum_list || index < 0 || index >= (int)m_camera_names.size()) {
        Log("Connect failed: invalid index.");
        return false;
    }

    const SDK::ICrCameraObjectInfo* cam = m_enum_list->GetCameraObjectInfo(index);
    if (!cam) {
        Log("Connect failed: null camera info.");
        return false;
    }

    Log("Connecting to " + m_camera_names[index] + "...");

    auto err = SDK::Connect(const_cast<SDK::ICrCameraObjectInfo*>(cam),
                            this,
                            &m_handle,
                            SDK::CrSdkControlMode_Remote,
                            SDK::CrReconnecting_ON);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "Connect failed: 0x" << std::hex << err;
        Log(ss.str());
        return false;
    }

    m_connected = true;
    m_connected_index = index;
    Log("Connected successfully.");

    // Enable live view
    auto lv_err = SDK::SetDeviceSetting(m_handle, SDK::Setting_Key_EnableLiveView,
                          (CrInt32u)SDK::CrDeviceSetting_Enable);
    Log(CR_FAILED(lv_err) ? "EnableLiveView: FAILED" : "EnableLiveView: OK");

    // Enable PostView transfer (this is the mechanism that downloads captured images to PC)
    // Legacy mode: SDK saves to disk and calls OnCompleteDownload with the file path
    auto pv_err = SDK::SetDeviceSetting(m_handle, SDK::Setting_Key_EnablePostView,
                          (CrInt32u)SDK::CrDeviceSetting_Enable);
    Log(CR_FAILED(pv_err) ? "EnablePostView: FAILED" : "EnablePostView: OK");

    auto pvt_err = SDK::SetDeviceSetting(m_handle, SDK::Setting_Key_PostViewTransferringType,
                          (CrInt32u)SDK::CrPostViewTransferring_Legacy);
    Log(CR_FAILED(pvt_err) ? "PostViewTransferringType Legacy: FAILED" : "PostViewTransferringType Legacy: OK");

    // Load initial properties first so we know what's writable
    LoadAllProperties();

    // Do not override destination — let SDK handle it with PostView transfer in Legacy mode
    // (Some cameras don't support HostPC mode and PostView only triggers with default settings)
    Log("StillImageStoreDestination: using camera default (PostView Legacy mode will transfer images).");

    // Try to set file type to JPEG so capture produces .JPG (downloadable later)
    {
        SDK::CrDeviceProperty ft;
        ft.SetCode(SDK::CrDeviceProperty_FileType);
        ft.SetCurrentValue((CrInt64u)SDK::CrFileType_Jpeg);
        ft.SetValueType(SDK::CrDataType_UInt16Array);
        auto fterr = SDK::SetDeviceProperty(m_handle, &ft);
        Log(CR_FAILED(fterr) ? "FileType: JPEG set FAILED (camera may already be set, or controlled by physical dial)"
                              : "FileType: JPEG OK");
    }

    // Set default save path → user's Pictures folder
    if (m_save_path.empty()) {
        wchar_t picDir[MAX_PATH] = {};
        // SHGetFolderPathW for CSIDL_MYPICTURES = 0x27
        if (SUCCEEDED(SHGetFolderPathW(nullptr, 0x0027 /*CSIDL_MYPICTURES*/, nullptr, 0, picDir))) {
            int sz = WideCharToMultiByte(CP_UTF8, 0, picDir, -1, nullptr, 0, nullptr, nullptr);
            if (sz > 0) {
                std::string utf8(sz - 1, '\0');
                WideCharToMultiByte(CP_UTF8, 0, picDir, -1, &utf8[0], sz, nullptr, nullptr);
                SetSavePath(utf8);
            }
        } else {
            // Fallback: current working directory
            auto cwd = std::filesystem::current_path().string();
            SetSavePath(cwd);
        }
    } else {
        SetSavePath(m_save_path);
    }

    return true;
}

bool CameraController::Disconnect()
{
    if (!m_connected) return true;
    Log("Disconnecting...");
    auto err = SDK::Disconnect(m_handle);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "Disconnect failed: 0x" << std::hex << err;
        Log(ss.str());
    }
    SDK::ReleaseDevice(m_handle);
    m_handle = 0;
    m_connected = false;
    m_movie_recording = false;
    {
        std::lock_guard<std::mutex> lock(m_prop_mutex);
        m_props.clear();
    }
    Log("Disconnected.");
    return true;
}

// ---- Shooting ----

bool CameraController::Capture()
{
    if (!m_connected) { Log("Capture: not connected."); return false; }

    // Detect focus mode: if AF-* (not MF), use S1andRelease (AF then shutter).
    bool use_af = true;
    bool is_continuous = false;
    {
        std::lock_guard<std::mutex> lock(m_prop_mutex);
        auto it = m_props.find(SDK::CrDeviceProperty_FocusMode);
        if (it != m_props.end()) {
            CrInt16u fm = (CrInt16u)it->second.current_value;
            if (fm == 1) use_af = false; // MF
        }
        auto dit = m_props.find(SDK::CrDeviceProperty_DriveMode);
        if (dit != m_props.end()) {
            CrInt32u dm = (CrInt32u)dit->second.current_value;
            // Any value with high byte 0x00010xxx is continuous-family
            if ((dm & 0xFFFF0000) == 0x00010000) is_continuous = true;
        }
    }

    if (is_continuous) {
        Log("Capture: drive mode is Continuous — switching to Single for reliable single shot...");
        SDK::CrDeviceProperty p;
        p.SetCode(SDK::CrDeviceProperty_DriveMode);
        p.SetCurrentValue((CrInt64u)SDK::CrDrive_Single);
        p.SetValueType(SDK::CrDataType_UInt32Array);
        auto perr = SDK::SetDeviceProperty(m_handle, &p);
        if (CR_FAILED(perr)) {
            std::ostringstream ss;
            ss << "DriveMode->Single failed 0x" << std::hex << perr
               << " (camera may force continuous via physical dial)";
            Log(ss.str());
        } else {
            Log("DriveMode set to Single.");
            std::this_thread::sleep_for(150ms); // let camera apply
        }
    }

    Log(use_af ? "Capture: AF + shutter down..." : "Capture: shutter down (MF)...");
    CaptureLog(use_af ? "CAPTURE START - S1andRelease down" : "CAPTURE START - Release down (MF)");

    SDK::CrCommandId cmd = use_af ? SDK::CrCommandId_S1andRelease : SDK::CrCommandId_Release;

    auto err = SDK::SendCommand(m_handle, cmd, SDK::CrCommandParam_Down);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "Capture Down rejected: 0x" << std::hex << (uint32_t)err;
        Log(ss.str());
        CaptureLog(ss.str());
        return false;
    }
    // Hold long enough: AF lock + camera registers a frame in continuous mode
    std::this_thread::sleep_for(use_af ? 800ms : 100ms);

    Log("Capture: shutter up.");
    CaptureLog("CAPTURE SHUTTER UP");
    err = SDK::SendCommand(m_handle, cmd, SDK::CrCommandParam_Up);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "Capture Up rejected: 0x" << std::hex << (uint32_t)err;
        Log(ss.str());
        CaptureLog(ss.str());
    }
    return true;
}

bool CameraController::AFShoot()
{
    if (!m_connected) { Log("AF+Shoot: not connected."); return false; }
    Log("AF+Shoot: S1+Release down...");
    auto err = SDK::SendCommand(m_handle, SDK::CrCommandId_S1andRelease, SDK::CrCommandParam_Down);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "AF+Shoot Down rejected: 0x" << std::hex << (uint32_t)err;
        Log(ss.str());
        return false;
    }
    std::this_thread::sleep_for(100ms);
    Log("AF+Shoot: release up.");
    SDK::SendCommand(m_handle, SDK::CrCommandId_S1andRelease, SDK::CrCommandParam_Up);
    return true;
}

bool CameraController::MovieRecToggle()
{
    if (!m_connected) { Log("MovieRec: not connected."); return false; }
    if (!m_movie_recording) {
        Log("Movie recording: START.");
        SDK::SendCommand(m_handle, SDK::CrCommandId_MovieRecord, SDK::CrCommandParam_Down);
        std::this_thread::sleep_for(35ms);
        SDK::SendCommand(m_handle, SDK::CrCommandId_MovieRecord, SDK::CrCommandParam_Up);
        m_movie_recording = true;
    } else {
        Log("Movie recording: STOP.");
        SDK::SendCommand(m_handle, SDK::CrCommandId_MovieRecord, SDK::CrCommandParam_Down);
        std::this_thread::sleep_for(35ms);
        SDK::SendCommand(m_handle, SDK::CrCommandId_MovieRecord, SDK::CrCommandParam_Up);
        m_movie_recording = false;
    }
    return true;
}

bool CameraController::SetFocusNear()
{
    if (!m_connected) return false;
    Log("Focus: step Near.");
    // Negative step value drives toward Near (closer)
    auto err = SDK::ExecuteControlCodeValue(m_handle, SDK::CrControlCode_NearFar, (CrInt64u)-1);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "FocusNear failed: 0x" << std::hex << err;
        Log(ss.str());
    }
    return !CR_FAILED(err);
}

bool CameraController::SetFocusFar()
{
    if (!m_connected) return false;
    Log("Focus: step Far.");
    // Positive step value drives toward Far (farther)
    auto err = SDK::ExecuteControlCodeValue(m_handle, SDK::CrControlCode_NearFar, 1);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "FocusFar failed: 0x" << std::hex << err;
        Log(ss.str());
    }
    return !CR_FAILED(err);
}

bool CameraController::CancelFocus()
{
    if (!m_connected) { Log("CancelFocus: not connected."); return false; }
    Log("Focus: cancel.");
    SDK::SendCommand(m_handle, SDK::CrCommandId_CancelFocusPosition, SDK::CrCommandParam_Down);
    std::this_thread::sleep_for(10ms);
    SDK::SendCommand(m_handle, SDK::CrCommandId_CancelFocusPosition, SDK::CrCommandParam_Up);
    return true;
}

bool CameraController::IsManualFocus() const
{
    std::lock_guard<std::mutex> lock(m_prop_mutex);
    auto it = m_props.find(SDK::CrDeviceProperty_FocusMode);
    if (it == m_props.end()) return false;
    return (CrInt16u)it->second.current_value == 1; // MF == 1
}

bool CameraController::ToggleFocusMode()
{
    if (!m_connected) { Log("ToggleFocusMode: not connected."); return false; }
    bool to_mf = !IsManualFocus();
    CrInt16u target = to_mf ? 1 /*MF*/ : 2 /*AF-S*/;
    Log(to_mf ? "Focus mode: switching to MF..." : "Focus mode: switching to AF-S...");
    return SetProperty(SDK::CrDeviceProperty_FocusMode, (CrInt64u)target);
}

// ---- Properties ----

void CameraController::LoadAllProperties()
{
    RefreshProperties();
}

void CameraController::RefreshProperties(CrInt32u num, CrInt32u* codes)
{
    if (!m_connected || !m_handle) return;

    SDK::CrDeviceProperty* prop_list = nullptr;
    CrInt32 nprop = 0;

    SDK::CrError status;
    if (num == 0)
        status = SDK::GetDeviceProperties(m_handle, &prop_list, &nprop);
    else
        status = SDK::GetSelectDeviceProperties(m_handle, num, codes, &prop_list, &nprop);

    if (CR_FAILED(status) || !prop_list || nprop <= 0) {
        if (prop_list) SDK::ReleaseDeviceProperties(m_handle, prop_list);
        return;
    }

    std::lock_guard<std::mutex> lock(m_prop_mutex);

    for (int i = 0; i < nprop; i++) {
        auto& prop = prop_list[i];
        auto code = (SDK::CrDevicePropertyCode)prop.GetCode();

        PropInfo info;
        info.code = code;
        info.current_value = prop.GetCurrentValue();
        info.writable = prop.IsSetEnableCurrentValue() == 1;

        CrInt32u raw_size = prop.GetValueSize();
        if (raw_size > 0 && prop.GetValues()) {
            const CrInt8u* raw = prop.GetValues();
            // Properties that use CrInt16u element size
            bool is16 = (code == SDK::CrDeviceProperty_FNumber         ||
                         code == SDK::CrDeviceProperty_WhiteBalance     ||
                         code == SDK::CrDeviceProperty_FocusMode        ||
                         code == SDK::CrDeviceProperty_StillImageStoreDestination ||
                         code == SDK::CrDeviceProperty_ExposureProgramMode);
            size_t elem_size = is16 ? sizeof(CrInt16u) : sizeof(CrInt32u);
            int count = (int)(raw_size / elem_size);
            info.valid_values.resize(count);
            for (int j = 0; j < count; j++) {
                info.valid_values[j] = is16
                    ? ((const CrInt16u*)raw)[j]
                    : ((const CrInt32u*)raw)[j];
            }
        }

        m_props[code] = std::move(info);

        if (code == SDK::CrDeviceProperty_BatteryRemain)
            m_battery_remain.store((int)prop.GetCurrentValue());
    }

    SDK::ReleaseDeviceProperties(m_handle, prop_list);
}

bool CameraController::SetProperty(SDK::CrDevicePropertyCode code, CrInt64u value)
{
    if (!m_connected) { Log("SetProperty: not connected."); return false; }

    SDK::CrDeviceProperty prop;
    prop.SetCode(code);
    prop.SetCurrentValue(value);

    // Properties that use CrInt16u (must match RefreshProperties logic)
    bool is16 = (code == SDK::CrDeviceProperty_FNumber         ||
                 code == SDK::CrDeviceProperty_WhiteBalance     ||
                 code == SDK::CrDeviceProperty_FocusMode        ||
                 code == SDK::CrDeviceProperty_StillImageStoreDestination ||
                 code == SDK::CrDeviceProperty_ExposureProgramMode);
    prop.SetValueType(is16 ? SDK::CrDataType_UInt16Array : SDK::CrDataType_UInt32Array);

    auto err = SDK::SetDeviceProperty(m_handle, &prop);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "SetProperty code=0x" << std::hex << (int)code
           << " value=0x" << std::hex << value << " failed: 0x" << err;
        Log(ss.str());
        return false;
    }

    std::string val_str = FormatPropertyValue(code, value);
    Log("Set property " + val_str);

    // Refresh this property
    CrInt32u c = (CrInt32u)code;
    RefreshProperties(1, &c);
    return true;
}

bool CameraController::GetPropInfo(SDK::CrDevicePropertyCode code, PropInfo& out) const
{
    std::lock_guard<std::mutex> lock(m_prop_mutex);
    auto it = m_props.find(code);
    if (it == m_props.end()) return false;
    out = it->second;
    return true;
}

// ---- Save path ----

bool CameraController::SetSavePath(const std::string& utf8_path)
{
    if (!m_connected) { m_save_path = utf8_path; return false; }

    // Convert UTF-8 to wstring, strip trailing backslash (SDK doesn't want it)
    std::filesystem::path fsp = std::filesystem::u8path(utf8_path);
    std::wstring wpath = fsp.wstring();
    while (!wpath.empty() && (wpath.back() == L'\\' || wpath.back() == L'/'))
        wpath.pop_back();

    // no = -1 (ImageSaveAutoStartNo): SDK assigns filenames automatically
    // prefix = L"" : let camera/SDK decide filename prefix
    std::wstring empty_prefix;
    auto err = SDK::SetSaveInfo(m_handle,
                                (CrChar*)wpath.c_str(),
                                (CrChar*)empty_prefix.c_str(),
                                -1);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "SetSaveInfo failed: 0x" << std::hex << (uint32_t)err;
        Log(ss.str());
        return false;
    }
    m_save_path = utf8_path;
    Log("Save path set: " + utf8_path);
    return true;
}

// ---- Live view ----

bool CameraController::GetLiveViewJpeg(std::vector<uint8_t>& jpeg_out)
{
    if (!m_connected || !m_handle) return false;

    SDK::CrImageInfo inf;
    auto err = SDK::GetLiveViewImageInfo(m_handle, &inf);
    if (CR_FAILED(err)) return false;

    CrInt32u bufSize = inf.GetBufferSize();
    if (bufSize < 1) return false;

    if (m_lv_buffer.size() < bufSize)
        m_lv_buffer.resize(bufSize);

    SDK::CrImageDataBlock image_data;
    image_data.SetSize(bufSize);
    image_data.SetData(m_lv_buffer.data());

    err = SDK::GetLiveViewImage(m_handle, &image_data);
    if (CR_FAILED(err)) return false;

    CrInt32u img_size = image_data.GetImageSize();
    if (img_size == 0) return false;

    const CrInt8u* img_ptr = image_data.GetImageData();
    jpeg_out.assign(img_ptr, img_ptr + img_size);
    return true;
}

// ---- Formatting ----

std::string CameraController::FormatPropertyValue(SDK::CrDevicePropertyCode code, CrInt64u value) const
{
    char buf[128] = {};
    switch (code) {
    case SDK::CrDeviceProperty_FNumber: {
        CrInt16u v = (CrInt16u)value;
        if (v == 0xFFFD) return "Iris Close";
        if (v == 0xFFFE) return "--";
        if (v == 0xFFFF) return "N/A";
        snprintf(buf, sizeof(buf), "F%.1f", v / 100.0f);
        return buf;
    }
    case SDK::CrDeviceProperty_ShutterSpeed: {
        CrInt32u v = (CrInt32u)value;
        if (v == 0x00000000) return "BULB";
        if (v == 0xFFFFFFFF) return "N/A";
        CrInt16u num = (CrInt16u)((v >> 16) & 0xFFFF);
        CrInt16u den = (CrInt16u)(v & 0xFFFF);
        if (den == 0) { snprintf(buf, sizeof(buf), "%d\"", num); return buf; }
        if (num == 1) { snprintf(buf, sizeof(buf), "1/%d", den); return buf; }
        if (num % den == 0) { snprintf(buf, sizeof(buf), "%d\"", num / den); return buf; }
        snprintf(buf, sizeof(buf), "%d.%d\"", num / den, num % den);
        return buf;
    }
    case SDK::CrDeviceProperty_IsoSensitivity: {
        CrInt32u v = (CrInt32u)value;
        CrInt32u iso_val = v & 0x00FFFFFF;
        if (iso_val == 0xFFFFFF) return "ISO Auto";
        CrInt32u mode = (v >> 24) & 0x0F;
        if (mode == 1) snprintf(buf, sizeof(buf), "MFNR %u", iso_val);
        else snprintf(buf, sizeof(buf), "ISO %u", iso_val);
        return buf;
    }
    case SDK::CrDeviceProperty_WhiteBalance: {
        CrInt16u v = (CrInt16u)value;
        switch (v) {
        case 0x0001: return "Auto WB";
        case 0x0002: return "Daylight";
        case 0x0003: return "Shadow";
        case 0x0004: return "Cloudy";
        case 0x0005: return "Incandescent";
        case 0x0006: return "Fluorescent";
        case 0x0007: return "Flash";
        case 0x000B: return "Underwater";
        case 0x0010: return "Color Temp";
        case 0x001F: return "Custom WB 1";
        case 0x0020: return "Custom WB 2";
        case 0x0021: return "Custom WB 3";
        default: snprintf(buf, sizeof(buf), "WB 0x%04X", v); return buf;
        }
    }
    case SDK::CrDeviceProperty_FocusMode: {
        CrInt16u v = (CrInt16u)value;
        switch (v) {
        case 1: return "MF";
        case 2: return "AF-S";
        case 3: return "AF-A";
        case 4: return "AF-C";
        case 5: return "DMF";
        case 6: return "PF";
        default: snprintf(buf, sizeof(buf), "Focus 0x%04X", v); return buf;
        }
    }
    case SDK::CrDeviceProperty_DriveMode: {
        CrInt32u v = (CrInt32u)value;
        switch (v) {
        case SDK::CrDrive_Single:                return "Single";
        case SDK::CrDrive_Continuous_Hi:         return "Continuous Hi";
        case SDK::CrDrive_Continuous_Hi_Plus:    return "Continuous Hi+";
        case SDK::CrDrive_Continuous_Hi_Live:    return "Continuous Hi (Live)";
        case SDK::CrDrive_Continuous_Lo:         return "Continuous Lo";
        case SDK::CrDrive_Continuous:            return "Continuous";
        case SDK::CrDrive_Continuous_SpeedPriority: return "Continuous Speed Priority";
        case SDK::CrDrive_Continuous_Mid:        return "Continuous Mid";
        case SDK::CrDrive_Continuous_Mid_Live:   return "Continuous Mid (Live)";
        case SDK::CrDrive_Continuous_Lo_Live:    return "Continuous Lo (Live)";
        case SDK::CrDrive_Timer_2s:              return "Self Timer 2s";
        case SDK::CrDrive_Timer_5s:              return "Self Timer 5s";
        case SDK::CrDrive_Timer_10s:             return "Self Timer 10s";
        default: snprintf(buf, sizeof(buf), "Drive 0x%X", v); return buf;
        }
    }
    case SDK::CrDeviceProperty_StillImageStoreDestination: {
        CrInt16u v = (CrInt16u)value;
        switch (v) {
        case SDK::CrStillImageStoreDestination_HostPC:             return "PC Only";
        case SDK::CrStillImageStoreDestination_MemoryCard:         return "Memory Card";
        case SDK::CrStillImageStoreDestination_HostPCAndMemoryCard:return "PC + Card";
        default: snprintf(buf, sizeof(buf), "Dest 0x%04X", v); return buf;
        }
    }
    case SDK::CrDeviceProperty_BatteryRemain:
        snprintf(buf, sizeof(buf), "%u%%", (unsigned)value);
        return buf;
    default:
        snprintf(buf, sizeof(buf), "0x%llX", (unsigned long long)value);
        return buf;
    }
}

std::string CameraController::GetFocusStatus() const
{
    PropInfo info;
    if (GetPropInfo(SDK::CrDeviceProperty_FocusIndication, info)) {
        CrInt16u v = (CrInt16u)info.current_value;
        switch (v) {
        case 0x0001: return "AF Unlocked";
        case 0x0002: return "AF Focused";
        case 0x0003: return "AF Not Focus";
        case 0x0004: return "Tracking";
        default: return "AF --";
        }
    }
    return "--";
}

// ---- Log ----

void CameraController::Log(const std::string& msg)
{
    // Timestamp with milliseconds
    auto now    = std::chrono::system_clock::now();
    auto ms     = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    auto t      = std::chrono::system_clock::to_time_t(now);
    std::tm tm_info;
#if defined(_WIN32)
    localtime_s(&tm_info, &t);
#else
    localtime_r(&t, &tm_info);
#endif
    char ts[24];
    snprintf(ts, sizeof(ts), "%02d:%02d:%02d.%03d",
             tm_info.tm_hour, tm_info.tm_min, tm_info.tm_sec, (int)ms.count());

    std::string entry = std::string("[") + ts + "] " + msg;

    // Write to GUI log (ring buffer, capped at 300 lines)
    {
        std::lock_guard<std::mutex> lock(m_log_mutex);
        m_log_entries.push_back(entry);
        if (m_log_entries.size() > 300)
            m_log_entries.erase(m_log_entries.begin());
        m_has_new_log = true;
    }

    // Write to file log (separate mutex so file I/O never blocks GUI log readers)
    {
        std::lock_guard<std::mutex> lk(m_file_log_mutex);
        if (m_log_file) {
            fprintf(m_log_file, "%s\n", entry.c_str());
            fflush(m_log_file); // flush immediately so log is readable even if app crashes
        }
    }
}

std::vector<std::string> CameraController::DrainLog()
{
    std::lock_guard<std::mutex> lock(m_log_mutex);
    m_has_new_log = false;
    return std::move(m_log_entries);
}

void CameraController::CaptureLog(const std::string& msg)
{
    auto now    = std::chrono::system_clock::now();
    auto ms     = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;
    auto t      = std::chrono::system_clock::to_time_t(now);
    std::tm tm_info;
#if defined(_WIN32)
    localtime_s(&tm_info, &t);
#else
    localtime_r(&t, &tm_info);
#endif
    char ts[24];
    snprintf(ts, sizeof(ts), "%02d:%02d:%02d.%03d",
             tm_info.tm_hour, tm_info.tm_min, tm_info.tm_sec, (int)ms.count());

    std::string entry = std::string("[") + ts + "] " + msg;

    std::lock_guard<std::mutex> lk(m_file_log_mutex);
    if (m_capture_log_file) {
        fprintf(m_capture_log_file, "%s\n", entry.c_str());
        fflush(m_capture_log_file);
    }
}

// ---- Utility ----

std::string CameraController::WCharToStr(const CrChar* ws) const
{
    if (!ws) return "";
#if defined(_UNICODE) || defined(UNICODE)
    const wchar_t* wp = (const wchar_t*)ws;
    if (!wp) return "";
    int size = WideCharToMultiByte(CP_UTF8, 0, wp, -1, nullptr, 0, nullptr, nullptr);
    if (size <= 0) return "";
    std::string s(size - 1, '\0');
    WideCharToMultiByte(CP_UTF8, 0, wp, -1, &s[0], size, nullptr, nullptr);
    return s;
#else
    return std::string((const char*)ws);
#endif
}

// ---- IDeviceCallback ----

void CameraController::OnConnected(SDK::DeviceConnectionVersioin version)
{
    Log("OnConnected callback.");
}

void CameraController::OnDisconnected(CrInt32u error)
{
    std::ostringstream ss;
    ss << "Camera disconnected (code=0x" << std::hex << error << ").";
    Log(ss.str());
    m_connected = false;
    m_movie_recording = false;
}

void CameraController::OnPropertyChanged()
{
    // Mark pending — actual USB refresh will happen on next Update() call (max 2/sec)
    m_prop_refresh_pending = true;
}

void CameraController::OnPropertyChangedCodes(CrInt32u num, CrInt32u* codes)
{
    m_prop_refresh_pending = true;
}

void CameraController::OnLvPropertyChanged() {}

void CameraController::OnLvPropertyChangedCodes(CrInt32u, CrInt32u*) {}

void CameraController::OnCompleteDownload(CrChar* filename, CrInt32u type)
{
    std::string fn = WCharToStr(filename);
    CaptureLog("OnCompleteDownload called - filename: " + fn + " type: " + std::to_string(type));
    switch (type) {
    case SDK::CrDownloadSettingFileType_None: {
        // Skip RAW (.ARW) files: delete them so only JPEG remains.
        std::string lower = fn;
        std::transform(lower.begin(), lower.end(), lower.begin(),
                       [](unsigned char c){ return (char)std::tolower(c); });
        if (lower.size() >= 4 && lower.compare(lower.size()-4, 4, ".arw") == 0) {
            std::error_code ec;
            std::filesystem::remove(std::filesystem::u8path(fn), ec);
            if (ec) {
                Log("RAW deleted (failed): " + fn + " err=" + ec.message());
            } else {
                Log("RAW skipped (deleted): " + fn);
                CaptureLog("RAW deleted: " + fn);
            }
        } else {
            Log("Photo saved: " + fn);
            CaptureLog("DOWNLOAD COMPLETE - Photo saved: " + fn);
        }
        break;
    }
    case SDK::CrDownloadSettingFileType_Setup:
        Log("Camera settings file downloaded: " + fn);
        CaptureLog("DOWNLOAD COMPLETE - Settings file: " + fn);
        break;
    default:
        Log("Download complete (type=" + std::to_string(type) + "): " + fn);
        CaptureLog("DOWNLOAD COMPLETE - Type " + std::to_string(type) + ": " + fn);
        break;
    }
}

void CameraController::OnWarning(CrInt32u warning)
{
    const char* name = nullptr;
    switch (warning) {
    case SDK::CrWarning_Unknown:                       name = "Unknown"; break;
    case SDK::CrWarning_File_StorageFull:              name = "StorageFull"; break;
    case SDK::CrWarning_SetFileName_Failed:            name = "SetFileName_Failed"; break;
    case SDK::CrWarning_GetImage_Failed:               name = "GetImage_Failed"; break;
    case SDK::CrWarning_NetworkErrorOccurred:          name = "NetworkError"; break;
    case SDK::CrNotify_Captured_Event:                 name = "ExposureStarted"; break;
    case SDK::CrWarning_Frame_NotUpdated:              name = "Frame_NotUpdated"; break;
    case SDK::CrNotify_All_Download_Complete:          name = "AllDownloadComplete"; break;
    case SDK::CrWarning_Connect_Already:               name = "AlreadyConnected"; break;
    case SDK::CrWarning_MovieRecordingOperation_Result_Invalid: name = "MovieRec_Invalid"; break;
    case SDK::CrWarning_MovieRecordingOperation_Result_OK:      name = "MovieRec_OK"; break;
    case SDK::CrWarning_MovieRecordingOperation_Result_NG:      name = "MovieRec_NG"; break;
    case SDK::CrWarning_FocusPosition_Result_Invalid:  name = "FocusPos_Invalid"; break;
    case SDK::CrWarning_FocusPosition_Result_OK:       name = "FocusPos_OK"; break;
    case SDK::CrWarning_FocusPosition_Result_NG:       name = "FocusPos_NG"; break;
    case SDK::CrWarning_CautionDisplay:                name = "CautionDisplay"; break;
    default: break;
    }
    std::ostringstream ss;
    if (name)
        ss << "Warning [" << name << "] 0x" << std::hex << warning;
    else
        ss << "Warning: 0x" << std::hex << warning;
    Log(ss.str());
}

void CameraController::OnWarningExt(CrInt32u warning, CrInt32 p1, CrInt32 p2, CrInt32 p3)
{
    if (warning == SDK::CrWarningExt_AFStatus) {
        const char* s = nullptr;
        switch (p1) {
        case SDK::CrWarningExt_AFStatusParam_Unlocked:             s = "AF Unlocked"; break;
        case SDK::CrWarningExt_AFStatusParam_Focused_AF_S:         s = "AF Focused (S)"; break;
        case SDK::CrWarningExt_AFStatusParam_NotFocused_AF_S:      s = "AF Not Focused (S)"; break;
        case SDK::CrWarningExt_AFStatusParam_TrackingSubject_AF_C: s = "AF Tracking (C)"; break;
        case SDK::CrWarningExt_AFStatusParam_Focused_AF_C:         s = "AF Focused (C)"; break;
        case SDK::CrWarningExt_AFStatusParam_NotFocused_AF_C:      s = "AF Not Focused (C)"; break;
        default: break;
        }
        if (s) Log(std::string("AF: ") + s);
        else {
            std::ostringstream ss;
            ss << "AF status p1=0x" << std::hex << p1;
            Log(ss.str());
        }
    } else if (warning == SDK::CrWarningExt_OperationResults) {
        const char* s = nullptr;
        switch (p1) {
        case SDK::CrWarningExt_OperationResultsParam_OK:                  s = "Operation OK"; break;
        case SDK::CrWarningExt_OperationResultsParam_NG:                  s = "Operation NG"; break;
        case SDK::CrWarningExt_OperationResultsParam_CameraStatusError:   s = "CameraStatusError"; break;
        case SDK::CrWarningExt_OperationResultsParam_ExecuteCanceled:     s = "Canceled"; break;
        default: break;
        }
        std::ostringstream ss;
        ss << "OperationResult: " << (s ? s : "?")
           << " (p1=0x" << std::hex << p1 << ")";
        Log(ss.str());
    } else if (warning == SDK::CrWarningExt_OperationInvalid) {
        std::ostringstream ss;
        ss << "OperationInvalid (camera busy / wrong state) p1=0x" << std::hex << p1;
        Log(ss.str());
    } else {
        std::ostringstream ss;
        ss << "WarningExt 0x" << std::hex << warning
           << " p1=0x" << p1 << " p2=0x" << p2 << " p3=0x" << p3;
        Log(ss.str());
    }
}

void CameraController::OnError(CrInt32u error)
{
    std::ostringstream ss;
    ss << "Error: 0x" << std::hex << error;
    Log(ss.str());
}

void CameraController::OnNotifyContentsTransfer(CrInt32u notify, SDK::CrContentHandle, CrChar* filename)
{
    std::string fn = WCharToStr(filename);
    {
        std::lock_guard<std::mutex> lk(m_download_mutex);
        m_download_notify = (int)notify;
        if (!fn.empty()) m_download_file = fn;
    }
    std::ostringstream ss;
    ss << "Transfer notify=0x" << std::hex << notify << " file=" << fn;
    Log(ss.str());
    CaptureLog(ss.str());
    m_download_cv.notify_all();
}

void CameraController::OnNotifyRemoteTransferResult(CrInt32u notify, CrInt32u per, CrChar* filename)
{
    std::string fn = WCharToStr(filename);
    {
        std::lock_guard<std::mutex> lk(m_download_mutex);
        m_download_notify = (int)notify;
        if (!fn.empty()) m_download_file = fn;
    }
    if (per == 100 || notify == SDK::CrNotify_RemoteTransfer_Result_OK) {
        std::ostringstream ss;
        ss << "RemoteTransfer OK: " << fn;
        Log(ss.str());
        CaptureLog(ss.str());
        m_download_cv.notify_all();
    } else if (notify == SDK::CrNotify_RemoteTransfer_Result_NG ||
               notify == SDK::CrNotify_RemoteTransfer_Result_DeviceBusy) {
        std::ostringstream ss;
        ss << "RemoteTransfer FAILED notify=0x" << std::hex << notify;
        Log(ss.str());
        CaptureLog(ss.str());
        m_download_cv.notify_all();
    }
}

void CameraController::OnNotifyRemoteTransferContentsListChanged(CrInt32u notify, CrInt32u slotNumber, CrInt32u addSize)
{
    std::ostringstream ss;
    ss << "ContentsList changed: slot=" << slotNumber << " added=" << addSize;
    Log(ss.str());
    CaptureLog(ss.str());
}

bool CameraController::DownloadRecentPhotos(int max_photos)
{
    if (m_downloading.load()) {
        Log("Download: already in progress.");
        return false;
    }
    if (!m_enum_list || m_connected_index < 0) {
        Log("Download: no camera selected. Connect first.");
        return false;
    }

    m_downloading = true;
    Log("=== Download: starting (will switch to ContentsTransfer mode) ===");
    CaptureLog("=== Download starting ===");

    // 1. Disconnect from Remote mode
    bool was_connected = m_connected.load();
    int saved_index = m_connected_index;
    if (was_connected) {
        Log("Download: disconnecting Remote mode...");
        SDK::Disconnect(m_handle);
        SDK::ReleaseDevice(m_handle);
        m_handle = 0;
        m_connected = false;
        m_movie_recording = false;
        {
            std::lock_guard<std::mutex> lock(m_prop_mutex);
            m_props.clear();
        }
    }

    // Small delay so SDK releases USB
    std::this_thread::sleep_for(800ms);

    // 2. Reconnect in ContentsTransfer mode (MTP-style file access)
    const SDK::ICrCameraObjectInfo* cam = m_enum_list->GetCameraObjectInfo(saved_index);
    if (!cam) {
        Log("Download: failed to get camera info.");
        m_downloading = false;
        return false;
    }

    Log("Download: connecting in ContentsTransfer mode...");
    SDK::CrDeviceHandle xfer_handle = 0;
    auto err = SDK::Connect(const_cast<SDK::ICrCameraObjectInfo*>(cam),
                            this, &xfer_handle,
                            SDK::CrSdkControlMode_ContentsTransfer,
                            SDK::CrReconnecting_ON);
    if (CR_FAILED(err)) {
        std::ostringstream ss;
        ss << "Download: ContentsTransfer connect failed 0x" << std::hex << err;
        Log(ss.str());
        CaptureLog(ss.str());
        std::this_thread::sleep_for(500ms);
        Connect(saved_index);
        m_downloading = false;
        return false;
    }

    Log("Download: ContentsTransfer connected, waiting for camera ready...");
    std::this_thread::sleep_for(2000ms);

    // 3. Get folder list from camera (DCIM/...)
    int downloaded = 0;
    SDK::CrMtpFolderInfo* folders = nullptr;
    CrInt32u numFolders = 0;
    err = SDK::GetDateFolderList(xfer_handle, &folders, &numFolders);
    if (CR_FAILED(err) || !folders || numFolders == 0) {
        std::ostringstream ss;
        ss << "Download: GetDateFolderList failed 0x" << std::hex << err
           << " folders=" << numFolders;
        Log(ss.str());
        CaptureLog(ss.str());
    } else {
        std::ostringstream ss;
        ss << "Download: found " << numFolders << " folder(s).";
        Log(ss.str());

        // Prepare save path (UTF-8 → wide)
        std::filesystem::path fsp = std::filesystem::u8path(m_save_path);
        std::wstring wpath = fsp.wstring();

        // Iterate folders newest-last (camera usually returns oldest-first).
        // Walk from last to first so we download newest photos first.
        for (int fi = (int)numFolders - 1; fi >= 0 && downloaded < max_photos; fi--) {
            SDK::CrMtpFolderInfo& folder = folders[fi];

            SDK::CrContentHandle* handles = nullptr;
            CrInt32u numHandles = 0;
            auto herr = SDK::GetContentsHandleList(xfer_handle, folder.handle,
                            &handles, &numHandles);
            if (CR_FAILED(herr) || !handles || numHandles == 0) {
                continue;
            }

            std::ostringstream ss2;
            ss2 << "Download: folder has " << numHandles << " file(s).";
            Log(ss2.str());

            // Download newest in this folder first; only JPEG files
            for (int hi = (int)numHandles - 1; hi >= 0 && downloaded < max_photos; hi--) {
                SDK::CrMtpContentsInfo info;
                auto derr = SDK::GetContentsDetailInfo(xfer_handle, handles[hi], &info);
                if (CR_FAILED(derr)) continue;

                std::string fname = WCharToStr(info.fileName);

                // Filter: only .JPG / .JPEG (skip .ARW, .HIF, etc.)
                std::string lower = fname;
                std::transform(lower.begin(), lower.end(), lower.begin(),
                               [](unsigned char c){ return (char)std::tolower(c); });
                if (lower.size() < 4 ||
                    (lower.compare(lower.size()-4, 4, ".jpg") != 0 &&
                     (lower.size() < 5 || lower.compare(lower.size()-5, 5, ".jpeg") != 0))) {
                    continue;
                }

                {
                    std::lock_guard<std::mutex> lk(m_download_mutex);
                    m_download_notify = 0;
                    m_download_file.clear();
                }

                Log("Download: pulling " + fname + "...");
                CaptureLog("Download: pulling " + fname);

                auto perr = SDK::PullContentsFile(xfer_handle, handles[hi],
                                SDK::CrPropertyStillImageTransSize_Original,
                                (CrChar*)wpath.c_str(),
                                info.fileName);
                if (CR_FAILED(perr)) {
                    std::ostringstream ss3;
                    ss3 << "Download: PullContentsFile failed 0x" << std::hex << perr;
                    Log(ss3.str());
                    CaptureLog(ss3.str());
                    continue;
                }

                // Wait for OnNotifyContentsTransfer with non-empty filename (transfer complete)
                std::unique_lock<std::mutex> ulk(m_download_mutex);
                bool ok = m_download_cv.wait_for(ulk, std::chrono::seconds(60),
                    [this]() { return !m_download_file.empty(); });
                if (ok) {
                    downloaded++;
                    Log("Download: saved -> " + m_download_file);
                    CaptureLog("Download saved: " + m_download_file);
                } else {
                    Log("Download: timeout waiting for transfer of " + fname);
                    CaptureLog("Download: timeout for " + fname);
                }
            }
            SDK::ReleaseContentsHandleList(xfer_handle, handles);
        }
        SDK::ReleaseDateFolderList(xfer_handle, folders);
    }

    // 4. Disconnect ContentsTransfer
    Log("Download: disconnecting ContentsTransfer...");
    SDK::Disconnect(xfer_handle);
    SDK::ReleaseDevice(xfer_handle);

    // 5. Reconnect in Remote mode
    std::this_thread::sleep_for(800ms);
    Log("Download: reconnecting Remote mode...");
    Connect(saved_index);

    std::ostringstream summary;
    summary << "=== Download finished: " << downloaded << " file(s) saved ===";
    Log(summary.str());
    CaptureLog(summary.str());
    m_downloading = false;
    return downloaded > 0;
}
