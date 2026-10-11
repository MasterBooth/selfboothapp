#pragma once

#include <string>
#include <vector>
#include <map>
#include <mutex>
#include <atomic>
#include <chrono>
#include <condition_variable>
#include "CameraRemote_SDK.h"
#include "IDeviceCallback.h"
#include "CrDeviceProperty.h"
#include "CrCommandData.h"
#include "CrDefines.h"

class CameraController : public SCRSDK::IDeviceCallback
{
public:
    struct PropInfo {
        SCRSDK::CrDevicePropertyCode code;
        CrInt64u current_value;
        bool writable;
        std::vector<CrInt64u> valid_values;
    };

    CameraController();
    ~CameraController();

    // Lifecycle
    bool Initialize();
    void Shutdown();

    // Enumeration & connection
    bool Enumerate(int timeout_sec = 3);
    bool Connect(int index);
    bool Disconnect();
    bool IsConnected() const { return m_connected.load(); }

    int GetCameraCount() const { return (int)m_camera_names.size(); }
    const std::vector<std::string>& GetCameraNames() const { return m_camera_names; }

    // Shooting
    bool Capture();
    bool AFShoot();
    bool MovieRecToggle();
    bool IsMovieRecording() const { return m_movie_recording.load(); }
    bool SetFocusNear();
    bool SetFocusFar();
    bool CancelFocus();

    // Focus mode helpers
    bool IsManualFocus() const;            // true if FocusMode == MF
    bool ToggleFocusMode();                // toggle AF-S <-> MF

    // Properties
    void LoadAllProperties();
    bool SetProperty(SCRSDK::CrDevicePropertyCode code, CrInt64u value);
    bool GetPropInfo(SCRSDK::CrDevicePropertyCode code, PropInfo& out) const;

    // Save path (UTF-8 path)
    bool SetSavePath(const std::string& utf8_path);
    const std::string& GetSavePath() const { return m_save_path; }

    // Download recent photos from camera memory card to PC.
    // Switches connection to RemoteTransfer mode, downloads, then back to Remote.
    // Runs synchronously (blocks); recommend calling from UI thread with progress feedback.
    bool DownloadRecentPhotos(int max_photos = 5);
    bool IsDownloading() const { return m_downloading.load(); }

    // Live view — returns JPEG bytes; false = no new frame
    bool GetLiveViewJpeg(std::vector<uint8_t>& jpeg_out);

    // Called every frame from GUI — handles deferred property refresh
    void TickUpdate();

    // Log
    std::vector<std::string> DrainLog();
    bool HasNewLog() const { return m_has_new_log.load(); }

    // Status
    int GetBatteryRemain() const { return m_battery_remain.load(); }
    std::string GetFocusStatus() const;
    std::string FormatPropertyValue(SCRSDK::CrDevicePropertyCode code, CrInt64u value) const;

    // IDeviceCallback
    void OnConnected(SCRSDK::DeviceConnectionVersioin version) override;
    void OnDisconnected(CrInt32u error) override;
    void OnPropertyChanged() override;
    void OnPropertyChangedCodes(CrInt32u num, CrInt32u* codes) override;
    void OnLvPropertyChanged() override;
    void OnLvPropertyChangedCodes(CrInt32u num, CrInt32u* codes) override;
    void OnCompleteDownload(CrChar* filename, CrInt32u type) override;
    void OnWarning(CrInt32u warning) override;
    void OnWarningExt(CrInt32u warning, CrInt32 p1, CrInt32 p2, CrInt32 p3) override;
    void OnError(CrInt32u error) override;
    void OnNotifyContentsTransfer(CrInt32u n, SCRSDK::CrContentHandle h, CrChar* f) override;
    void OnNotifyFTPTransferResult(CrInt32u, CrInt32u, CrInt32u) override {}
    void OnNotifyRemoteTransferResult(CrInt32u notify, CrInt32u per, CrChar* filename) override;
    void OnNotifyRemoteTransferResult(CrInt32u, CrInt32u, CrInt8u*, CrInt64u) override {}
    void OnNotifyRemoteTransferContentsListChanged(CrInt32u notify, CrInt32u slotNumber, CrInt32u addSize) override;
    void OnReceivePlaybackTimeCode(CrInt32u) override {}
    void OnReceivePlaybackData(CrInt8u, CrInt32, CrInt8u*, CrInt64, CrInt64, CrInt32, CrInt32) override {}
    void OnNotifyRemoteFirmwareUpdateResult(CrInt32u, const void*) override {}

private:
    void Log(const std::string& msg);
    void CaptureLog(const std::string& msg);
    void RefreshProperties(CrInt32u num = 0, CrInt32u* codes = nullptr);
    std::string WCharToStr(const CrChar* ws) const;

    SCRSDK::CrDeviceHandle m_handle;
    std::atomic<bool> m_connected;
    std::atomic<bool> m_movie_recording;

    SCRSDK::ICrEnumCameraObjectInfo* m_enum_list;
    std::vector<std::string> m_camera_names;
    int m_connected_index;  // index into m_enum_list used to connect (for reconnect during download)

    mutable std::mutex m_prop_mutex;
    std::map<SCRSDK::CrDevicePropertyCode, PropInfo> m_props;
    std::atomic<int> m_battery_remain;

    std::string m_save_path;

    std::vector<uint8_t> m_lv_buffer;

    std::mutex m_log_mutex;
    std::vector<std::string> m_log_entries;
    std::atomic<bool> m_has_new_log;

    // File log
    std::mutex m_file_log_mutex;
    FILE* m_log_file;
    FILE* m_capture_log_file;

    // Property refresh debounce
    std::atomic<bool> m_prop_refresh_pending;
    std::chrono::steady_clock::time_point m_last_prop_refresh;

    // Download state (RemoteTransfer mode)
    std::atomic<bool> m_downloading;
    std::mutex m_download_mutex;
    std::condition_variable m_download_cv;
    int m_download_notify;       // last notify value from OnNotifyRemoteTransferResult
    std::string m_download_file; // last downloaded filename
};
