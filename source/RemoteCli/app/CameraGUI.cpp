#include "CameraGUI.h"
#include "imgui.h"
#include <windows.h>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <algorithm>
#include <cstring>
#include <cstdio>
#include <thread>

static void EarlyLog2(const char* msg)
{
    FILE* f = nullptr;
    wchar_t exePath[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    wchar_t* sl = wcsrchr(exePath, L'\\');
    if (sl) wcscpy_s(sl + 1, MAX_PATH - (sl - exePath + 1), L"startup.log");
    if (_wfopen_s(&f, exePath, L"a") == 0 && f) {
        fprintf(f, "%s\n", msg);
        fclose(f);
    }
}

CameraGUI::CameraGUI()
    : m_ctrl(nullptr)
    , m_pd3dDevice(nullptr)
    , m_pd3dContext(nullptr)
    , m_lv_texture(nullptr)
    , m_lv_srv(nullptr)
    , m_lv_width(0)
    , m_lv_height(0)
    , m_lv_enabled(true)
    , m_selected_camera(0)
    , m_save_path_dirty(false)
    , m_log_scroll_bottom(true)
    , m_win_w(1280)
    , m_win_h(800)
    , m_last_lv_decode(std::chrono::steady_clock::now())
    , m_last_prop_ui_refresh(std::chrono::steady_clock::now())
{
    EarlyLog2("CameraGUI::ctor start");
    memset(m_save_path, 0, sizeof(m_save_path));
    EarlyLog2("CameraGUI::ctor done");
}

CameraGUI::~CameraGUI()
{
    Shutdown();
}

void CameraGUI::SetD3DDevice(ID3D11Device* device, ID3D11DeviceContext* context)
{
    m_pd3dDevice = device;
    m_pd3dContext = context;
}

void CameraGUI::Initialize()
{
    EarlyLog2("CameraGUI::Initialize start");

    EarlyLog2("Creating CameraController...");
    m_ctrl = new CameraController();
    EarlyLog2("CameraController created");

    EarlyLog2("Calling m_ctrl->Initialize...");
    m_ctrl->Initialize();
    EarlyLog2("m_ctrl->Initialize done");

    // Setup property UIs we want to show
    EarlyLog2("Pushing property UIs...");
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_FNumber,                    "Aperture",    -1, {}, {} });
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_ShutterSpeed,               "Shutter Spd", -1, {}, {} });
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_IsoSensitivity,             "ISO",         -1, {}, {} });
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_WhiteBalance,               "White Bal",   -1, {}, {} });
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_FocusMode,                  "Focus Mode",  -1, {}, {} });
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_DriveMode,                  "Drive Mode",  -1, {}, {} });
    m_prop_uis.push_back({ SCRSDK::CrDeviceProperty_StillImageStoreDestination, "Save Dest",   -1, {}, {} });
    EarlyLog2("Property UIs pushed");

    EarlyLog2("Adding log message...");
    AddLog("GUI initialized.");
    EarlyLog2("CameraGUI::Initialize done");
}

void CameraGUI::Shutdown()
{
    if (m_ctrl) {
        m_ctrl->Shutdown();
        delete m_ctrl;
        m_ctrl = nullptr;
    }
    if (m_lv_srv)     { m_lv_srv->Release();     m_lv_srv = nullptr; }
    if (m_lv_texture) { m_lv_texture->Release(); m_lv_texture = nullptr; }
}

bool CameraGUI::IsConnected() const
{
    return m_ctrl && m_ctrl->IsConnected();
}

void CameraGUI::Update()
{
    if (!m_ctrl) return;

    // Deferred property refresh (max 2Hz, no USB round-trip on SDK callbacks)
    m_ctrl->TickUpdate();

    // Drain logs from controller
    if (m_ctrl->HasNewLog()) {
        auto entries = m_ctrl->DrainLog();
        for (auto& e : entries) AddLog(e);
    }

    auto now = std::chrono::steady_clock::now();

    // PropUI refresh throttle: max 2x per second
    if (m_ctrl->IsConnected()) {
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                      now - m_last_prop_ui_refresh).count();
        if (ms >= 500) {
            m_last_prop_ui_refresh = now;
            RefreshPropUI();
        }
    }

    // Live view throttle: max 30fps (33ms)
    if (m_ctrl->IsConnected() && m_lv_enabled && m_pd3dDevice && m_pd3dContext) {
        auto lv_ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                         now - m_last_lv_decode).count();
        if (lv_ms >= 33) {
            m_last_lv_decode = now;
            if (m_ctrl->GetLiveViewJpeg(m_lv_jpeg))
                UpdateLiveViewTexture(m_lv_jpeg);
        }
    }
}

void CameraGUI::Render()
{
    ImVec2 display = ImGui::GetIO().DisplaySize;
    m_win_w = display.x;
    m_win_h = display.y;

    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::SetNextWindowSize(display);

    ImGuiWindowFlags flags = ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoTitleBar |
                             ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoBringToFrontOnFocus;

    ImGui::Begin("##main", nullptr, flags);

    // === Top: Connection Panel ===
    RenderConnectionPanel();
    ImGui::Separator();

    // === Middle: Live View (left) + Controls (right) ===
    float lv_panel_w = m_win_w * 0.60f;
    float ctrl_panel_w = m_win_w * 0.38f;

    ImGui::BeginChild("##lv_area", ImVec2(lv_panel_w, m_win_h * 0.58f), false);
    RenderLiveViewPanel();
    ImGui::EndChild();

    ImGui::SameLine();

    ImGui::BeginChild("##ctrl_area", ImVec2(ctrl_panel_w, m_win_h * 0.58f), false);
    RenderShootingPanel();
    ImGui::Separator();
    RenderSettingsPanel();
    ImGui::Separator();
    RenderFocusPanel();
    ImGui::Separator();
    RenderStatusPanel();
    ImGui::EndChild();

    ImGui::Separator();

    // === Bottom: Log Panel ===
    RenderLogPanel();

    ImGui::End();
}

// ---- Connection Panel ----

void CameraGUI::RenderConnectionPanel()
{
    if (!m_ctrl) return;

    bool connected = m_ctrl->IsConnected();

    ImGui::Text("SONY CAMERA REMOTE CONTROL");
    ImGui::SameLine(0, 30);

    if (connected)
        ImGui::TextColored(ImVec4(0.1f, 0.9f, 0.1f, 1), "● CONNECTED");
    else
        ImGui::TextColored(ImVec4(0.9f, 0.2f, 0.2f, 1), "● DISCONNECTED");

    ImGui::Spacing();

    // Row 1: Enumerate + camera selector
    if (ImGui::Button("Scan Cameras", ImVec2(110, 0))) {
        m_ctrl->Enumerate(2);
        m_selected_camera = 0;
        AddLog("Scan complete.");
    }
    ImGui::SameLine();

    int count = m_ctrl->GetCameraCount();
    if (count > 0) {
        const auto& names = m_ctrl->GetCameraNames();
        ImGui::SetNextItemWidth(300);
        // Build c-str list
        std::vector<const char*> items;
        for (auto& n : names) items.push_back(n.c_str());
        ImGui::Combo("##cam_sel", &m_selected_camera, items.data(), (int)items.size());
    } else {
        ImGui::TextDisabled("(no cameras found)");
    }

    ImGui::SameLine();

    if (!connected) {
        if (ImGui::Button("Connect", ImVec2(90, 0)) && count > 0)
            m_ctrl->Connect(m_selected_camera);
    } else {
        if (ImGui::Button("Disconnect", ImVec2(90, 0)))
            m_ctrl->Disconnect();
    }

    // Row 2: Save path
    ImGui::Text("Save Path:");
    ImGui::SameLine();
    ImGui::SetNextItemWidth(400);
    if (ImGui::InputText("##savepath", m_save_path, sizeof(m_save_path)))
        m_save_path_dirty = true;
    ImGui::SameLine();
    if (ImGui::Button("Apply##savepath", ImVec2(60, 0)) && m_save_path_dirty && connected) {
        m_ctrl->SetSavePath(std::string(m_save_path));
        m_save_path_dirty = false;
    }

    // Sync save path from controller
    if (connected && !m_ctrl->GetSavePath().empty()) {
        const std::string& sp = m_ctrl->GetSavePath();
        if (std::string(m_save_path) != sp) {
            strncpy_s(m_save_path, sp.c_str(), sizeof(m_save_path) - 1);
        }
    }
}

// ---- Live View Panel ----

void CameraGUI::RenderLiveViewPanel()
{
    ImVec2 avail = ImGui::GetContentRegionAvail();

    ImGui::Checkbox("Live View", &m_lv_enabled);
    ImGui::SameLine();
    if (m_lv_srv && m_lv_width > 0 && m_lv_height > 0) {
        char dim_buf[32];
        snprintf(dim_buf, sizeof(dim_buf), "%dx%d", m_lv_width, m_lv_height);
        ImGui::TextDisabled(dim_buf);
    }

    if (m_lv_srv && m_lv_enabled) {
        float lv_w = avail.x;
        float lv_h = avail.y - 30;
        float aspect = (float)m_lv_width / (float)m_lv_height;
        if (m_lv_height > 0) {
            float fit_h = lv_w / aspect;
            if (fit_h > lv_h) {
                lv_w = lv_h * aspect;
            } else {
                lv_h = fit_h;
            }
        }
        ImGui::Image((ImTextureID)(void*)m_lv_srv, ImVec2(lv_w, lv_h));
    } else {
        ImGui::BeginChild("##lv_placeholder", avail, true);
        ImVec2 center = ImGui::GetContentRegionAvail();
        float tx = center.x * 0.5f - 60;
        float ty = center.y * 0.5f - 8;
        ImGui::SetCursorPos(ImVec2(tx, ty));
        ImGui::TextDisabled("[ Live View Off ]");
        ImGui::EndChild();
    }
}

// ---- Shooting Panel ----

void CameraGUI::RenderShootingPanel()
{
    if (!m_ctrl) return;
    bool connected = m_ctrl->IsConnected();

    ImGui::Text("Shooting");
    ImGui::Spacing();

    ImGui::BeginDisabled(!connected);

    if (ImGui::Button("Capture", ImVec2(120, 36)))
        m_ctrl->Capture();
    ImGui::SameLine();
    if (ImGui::Button("AF + Shoot", ImVec2(120, 36)))
        m_ctrl->AFShoot();

    bool movie_rec = m_ctrl->IsMovieRecording();
    if (movie_rec)
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.1f, 0.1f, 1.0f));
    if (ImGui::Button(movie_rec ? "■ Stop REC" : "● Movie REC", ImVec2(120, 36)))
        m_ctrl->MovieRecToggle();
    if (movie_rec)
        ImGui::PopStyleColor();

    ImGui::Spacing();

    // Download photos from camera memory card
    bool downloading = m_ctrl->IsDownloading();
    ImGui::BeginDisabled(downloading);
    if (ImGui::Button(downloading ? "Downloading..." : "Download from Camera",
                      ImVec2(248, 32))) {
        std::thread([this]() { m_ctrl->DownloadRecentPhotos(5); }).detach();
    }
    ImGui::EndDisabled();
    if (downloading)
        ImGui::TextColored(ImVec4(1, 0.8f, 0.2f, 1), "Transferring... do not disconnect");

    ImGui::EndDisabled();
}

// ---- Settings Panel ----

void CameraGUI::RenderSettingsPanel()
{
    if (!m_ctrl) return;
    bool connected = m_ctrl->IsConnected();

    ImGui::Text("Settings");
    ImGui::Spacing();

    ImGui::BeginDisabled(!connected);

    for (auto& pui : m_prop_uis) {
        if (pui.display_items.empty()) {
            // show read-only current if available
            CameraController::PropInfo info;
            if (m_ctrl->GetPropInfo(pui.code, info)) {
                std::string val = m_ctrl->FormatPropertyValue(pui.code, info.current_value);
                char buf[128];
                snprintf(buf, sizeof(buf), "%s: %s", pui.label, val.c_str());
                ImGui::TextDisabled(buf);
            }
            continue;
        }

        // Build const char* list
        std::vector<const char*> items;
        for (auto& s : pui.display_items) items.push_back(s.c_str());

        char combo_id[64];
        snprintf(combo_id, sizeof(combo_id), "##prop_%X", (unsigned)pui.code);

        ImGui::SetNextItemWidth(160);
        int prev = pui.selected_index;
        if (ImGui::Combo(combo_id, &pui.selected_index, items.data(), (int)items.size())) {
            if (pui.selected_index != prev && pui.selected_index >= 0 &&
                pui.selected_index < (int)pui.raw_values.size()) {
                m_ctrl->SetProperty(pui.code, pui.raw_values[pui.selected_index]);
            }
        }
        ImGui::SameLine();
        ImGui::Text("%s", pui.label);
    }

    ImGui::EndDisabled();
}

// ---- Focus Panel ----

void CameraGUI::RenderFocusPanel()
{
    if (!m_ctrl) return;
    bool connected = m_ctrl->IsConnected();
    bool is_mf = connected && m_ctrl->IsManualFocus();

    ImGui::Text("Focus");
    ImGui::Spacing();

    ImGui::BeginDisabled(!connected);

    // Toggle AF<->MF
    const char* tog = is_mf ? "Switch to AF" : "Switch to MF";
    if (ImGui::Button(tog, ImVec2(140, 0)))
        m_ctrl->ToggleFocusMode();
    ImGui::SameLine();
    ImGui::TextColored(is_mf ? ImVec4(1.0f, 0.7f, 0.2f, 1.0f)
                              : ImVec4(0.4f, 0.9f, 0.4f, 1.0f),
                       is_mf ? "MF" : "AF");

    // MF-only buttons; greyed out in AF mode
    ImGui::BeginDisabled(!is_mf);
    if (ImGui::Button("MF Near", ImVec2(90, 0))) m_ctrl->SetFocusNear();
    ImGui::SameLine();
    if (ImGui::Button("MF Far",  ImVec2(90, 0))) m_ctrl->SetFocusFar();
    ImGui::SameLine();
    if (ImGui::Button("Cancel",  ImVec2(90, 0))) m_ctrl->CancelFocus();
    ImGui::EndDisabled();

    if (!is_mf)
        ImGui::TextDisabled("(MF Near/Far only available in MF mode)");

    ImGui::EndDisabled();
}

// ---- Status Panel ----

void CameraGUI::RenderStatusPanel()
{
    if (!m_ctrl) return;

    ImGui::Text("Status");
    ImGui::Spacing();

    if (m_ctrl->IsConnected()) {
        int batt = m_ctrl->GetBatteryRemain();
        ImGui::Text("Battery:  %d%%", batt);

        std::string focus_status = m_ctrl->GetFocusStatus();
        ImGui::Text("Focus:    %s", focus_status.c_str());

        ImGui::Text("Movie:    %s", m_ctrl->IsMovieRecording() ? "RECORDING" : "Standby");

        // Show current values for each property
        for (auto& pui : m_prop_uis) {
            CameraController::PropInfo info;
            if (m_ctrl->GetPropInfo(pui.code, info)) {
                std::string val = m_ctrl->FormatPropertyValue(pui.code, info.current_value);
                ImGui::Text("%-12s %s", pui.label, val.c_str());
            }
        }
    } else {
        ImGui::TextDisabled("Not connected.");
    }
}

// ---- Log Panel ----

void CameraGUI::RenderLogPanel()
{
    float log_h = m_win_h * 0.20f;
    ImGui::BeginChild("##log_panel", ImVec2(-1, log_h), true, ImGuiWindowFlags_HorizontalScrollbar);

    ImGui::Text("Log:");
    ImGui::SameLine();
    if (ImGui::SmallButton("Clear"))
        m_log_lines.clear();

    ImGui::Separator();

    for (const auto& line : m_log_lines)
        ImGui::TextUnformatted(line.c_str());

    if (m_log_scroll_bottom) {
        ImGui::SetScrollHereY(1.0f);
        m_log_scroll_bottom = false;
    }

    ImGui::EndChild();
}

// ---- Helpers ----

void CameraGUI::AddLog(const std::string& msg)
{
    m_log_lines.push_back(msg);
    if (m_log_lines.size() > 300)
        m_log_lines.erase(m_log_lines.begin());
    m_log_scroll_bottom = true;
}

void CameraGUI::UpdateLiveViewTexture(const std::vector<uint8_t>& jpeg)
{
    if (!m_pd3dDevice || !m_pd3dContext || jpeg.empty()) return;

    // Decode JPEG with OpenCV
    std::vector<uint8_t> buf(jpeg.begin(), jpeg.end());
    cv::Mat img = cv::imdecode(buf, cv::IMREAD_COLOR);
    if (img.empty()) return;

    cv::Mat rgba;
    cv::cvtColor(img, rgba, cv::COLOR_BGR2RGBA);

    int w = rgba.cols;
    int h = rgba.rows;

    // Recreate texture if size changed
    if (w != m_lv_width || h != m_lv_height) {
        if (m_lv_srv)     { m_lv_srv->Release();     m_lv_srv = nullptr; }
        if (m_lv_texture) { m_lv_texture->Release(); m_lv_texture = nullptr; }

        D3D11_TEXTURE2D_DESC desc = {};
        desc.Width              = w;
        desc.Height             = h;
        desc.MipLevels          = 1;
        desc.ArraySize          = 1;
        desc.Format             = DXGI_FORMAT_R8G8B8A8_UNORM;
        desc.SampleDesc.Count   = 1;
        desc.Usage              = D3D11_USAGE_DEFAULT;
        desc.BindFlags          = D3D11_BIND_SHADER_RESOURCE;

        D3D11_SUBRESOURCE_DATA init = {};
        init.pSysMem            = rgba.data;
        init.SysMemPitch        = w * 4;

        if (SUCCEEDED(m_pd3dDevice->CreateTexture2D(&desc, &init, &m_lv_texture))) {
            m_pd3dDevice->CreateShaderResourceView(m_lv_texture, nullptr, &m_lv_srv);
        }

        m_lv_width  = w;
        m_lv_height = h;
    } else if (m_lv_texture) {
        // Update existing texture
        m_pd3dContext->UpdateSubresource(m_lv_texture, 0, nullptr, rgba.data, w * 4, 0);
    }
}

void CameraGUI::RefreshPropUI()
{
    if (!m_ctrl) return;

    for (auto& pui : m_prop_uis) {
        CameraController::PropInfo info;
        if (!m_ctrl->GetPropInfo(pui.code, info)) continue;
        if (!info.writable || info.valid_values.empty()) continue;

        // Rebuild if valid_values changed
        if (pui.raw_values != info.valid_values) {
            pui.raw_values = info.valid_values;
            pui.display_items.clear();
            for (auto v : pui.raw_values)
                pui.display_items.push_back(m_ctrl->FormatPropertyValue(pui.code, v));
        }

        // Update selected index to match current
        pui.selected_index = -1;
        for (int i = 0; i < (int)pui.raw_values.size(); i++) {
            if (pui.raw_values[i] == info.current_value) {
                pui.selected_index = i;
                break;
            }
        }
        if (pui.selected_index < 0 && !pui.raw_values.empty())
            pui.selected_index = 0;
    }
}
