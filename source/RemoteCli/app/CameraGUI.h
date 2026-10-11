#pragma once

#include <vector>
#include <string>
#include <chrono>
#include <d3d11.h>
#include "CameraController.h"

class CameraGUI
{
public:
    CameraGUI();
    ~CameraGUI();

    void SetD3DDevice(ID3D11Device* device, ID3D11DeviceContext* context);
    void Initialize();
    void Update();
    void Render();
    void Shutdown();

    bool IsConnected() const;

private:
    // Controller
    CameraController* m_ctrl;

    // D3D11
    ID3D11Device*           m_pd3dDevice;
    ID3D11DeviceContext*    m_pd3dContext;

    // Live view texture
    ID3D11Texture2D*            m_lv_texture;
    ID3D11ShaderResourceView*   m_lv_srv;
    int                         m_lv_width;
    int                         m_lv_height;

    // Live view jpeg decode buffer
    std::vector<uint8_t>    m_lv_jpeg;
    bool                    m_lv_enabled;

    // Connection UI state
    int     m_selected_camera;
    char    m_save_path[512];
    bool    m_save_path_dirty;

    // Property UI state
    struct PropUI {
        SCRSDK::CrDevicePropertyCode code;
        const char* label;
        int selected_index;                    // index in valid_values[]
        std::vector<std::string> display_items; // formatted valid values
        std::vector<CrInt64u>    raw_values;    // same-order raw values
    };
    std::vector<PropUI> m_prop_uis;

    // Log
    std::vector<std::string> m_log_lines;
    bool m_log_scroll_bottom;

    // Window dims
    float m_win_w;
    float m_win_h;

    // Throttle timers (steady_clock)
    std::chrono::steady_clock::time_point m_last_lv_decode;
    std::chrono::steady_clock::time_point m_last_prop_ui_refresh;

    // UI panels
    void RenderConnectionPanel();
    void RenderLiveViewPanel();
    void RenderShootingPanel();
    void RenderSettingsPanel();
    void RenderStatusPanel();
    void RenderFocusPanel();
    void RenderLogPanel();

    // Helpers
    void UpdateLiveViewTexture(const std::vector<uint8_t>& jpeg);
    void RefreshPropUI();
    void AddLog(const std::string& msg);
};
