#pragma once

/*=============================================================================
 * MainWindow.h - Win32 GUI Window with GDI+ Live View rendering
 *
 * Layout:
 * ┌──────────────────────────────────────────────────────────────┐
 * │  [Connect ▼]  Camera: EOS R5  Battery: 100%  Shots: 1234    │
 * ├────────────────────────────────────┬─────────────────────────┤
 * │                                    │  ── Capture ──          │
 * │                                    │  [Take Picture]         │
 * │                                    │  [Take (No AF)]         │
 * │        LIVE VIEW                   │                         │
 * │        (960 x 640)                 │  ── Live View ──        │
 * │                                    │  [Start LV] [Stop LV]  │
 * │                                    │                         │
 * │                                    │  ── Focus ──            │
 * │                                    │  [Near] [Far]           │
 * │                                    │  [AF On] [AF Off]       │
 * │                                    │                         │
 * │                                    │  ── Settings ──         │
 * │                                    │  ISO:    [ComboBox]     │
 * │                                    │  Av:     [ComboBox]     │
 * │                                    │  Tv:     [ComboBox]     │
 * │                                    │  WB:     [ComboBox]     │
 * ├────────────────────────────────────┴─────────────────────────┤
 * │  Status: Ready                                               │
 * └──────────────────────────────────────────────────────────────┘
 *============================================================================*/

#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <windows.h>
#include <commctrl.h>
#include <objidl.h>
#include <gdiplus.h>

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "gdiplus.lib")

#include <string>
#include <vector>
#include <mutex>
#include <functional>

namespace CameraApp {

// ---------------------------------------------------------------------------
// Control IDs
// ---------------------------------------------------------------------------
enum ControlID {
    ID_BTN_CONNECT = 1001,
    ID_BTN_DISCONNECT,
    ID_BTN_TAKE_PICTURE,
    ID_BTN_TAKE_NOAF,
    ID_BTN_START_LV,
    ID_BTN_STOP_LV,
    ID_BTN_FOCUS_NEAR,
    ID_BTN_FOCUS_FAR,
    ID_BTN_AF_ON,
    ID_BTN_AF_OFF,
    ID_BTN_ZOOM_FIT,
    ID_BTN_ZOOM_5X,
    ID_COMBO_CAMERA,
    ID_COMBO_ISO,
    ID_COMBO_AV,
    ID_COMBO_TV,
    ID_COMBO_WB,
    ID_COMBO_QUALITY,
    ID_COMBO_METERING,
    ID_COMBO_COLORTEMP,
    ID_EDIT_KELVIN,
    ID_BUTTON_APPLY_KELVIN,
    ID_STATIC_STATUS,
    ID_STATIC_CAMERA_INFO,
    ID_STATIC_LV_PANEL,
    ID_TIMER_KEEPALIVE = 2001,
};

// Custom window messages
#define WM_APP_LV_FRAME      (WM_APP + 1)
#define WM_APP_STATUS_UPDATE  (WM_APP + 2)
#define WM_APP_PROP_CHANGED   (WM_APP + 3)
#define WM_APP_CONNECTED      (WM_APP + 4)
#define WM_APP_DISCONNECTED   (WM_APP + 5)
#define WM_APP_FILE_SAVED     (WM_APP + 6)

// ---------------------------------------------------------------------------
// MainWindow
// ---------------------------------------------------------------------------
class MainWindow {
public:
    // UI action callbacks
    struct Actions {
        std::function<void()>               onConnect;
        std::function<void()>               onDisconnect;
        std::function<void()>               onTakePicture;
        std::function<void()>               onTakePictureNoAF;
        std::function<void()>               onStartLiveView;
        std::function<void()>               onStopLiveView;
        std::function<void()>               onFocusNear;
        std::function<void()>               onFocusFar;
        std::function<void()>               onAFOn;
        std::function<void()>               onAFOff;
        std::function<void()>               onZoomFit;
        std::function<void()>               onZoom5x;
        std::function<void(EdsUInt32 kelvin)> onColorTemperatureChanged;
        std::function<void(int comboId, int selectedIndex, EdsInt32 value)> onPropertySelected;
    };

    // Dimensions
    static constexpr int WINDOW_W       = 1280;
    static constexpr int WINDOW_H       = 820;
    static constexpr int LV_WIDTH       = 960;
    static constexpr int LV_HEIGHT      = 640;
    static constexpr int PANEL_WIDTH    = 280;
    static constexpr int TOOLBAR_H      = 40;
    static constexpr int STATUSBAR_H    = 28;
    static constexpr int BTN_W          = 120;
    static constexpr int BTN_H          = 30;
    static constexpr int COMBO_W        = 160;
    static constexpr int COMBO_H        = 24;
    static constexpr int LABEL_W        = 55;

    MainWindow() = default;
    ~MainWindow() { destroy(); }

    // -----------------------------------------------------------------------
    // Create and show window
    // -----------------------------------------------------------------------
    bool create(HINSTANCE hInstance, const std::string& title = "Canon Camera Control") {
        m_hInstance = hInstance;

        // Init GDI+
        Gdiplus::GdiplusStartupInput gdiplusInput;
        Gdiplus::GdiplusStartup(&m_gdiplusToken, &gdiplusInput, NULL);

        // Init common controls
        INITCOMMONCONTROLSEX icc = { sizeof(icc), ICC_WIN95_CLASSES };
        InitCommonControlsEx(&icc);

        // Register window class
        WNDCLASSEXA wc = {};
        wc.cbSize        = sizeof(wc);
        wc.style         = CS_HREDRAW | CS_VREDRAW;
        wc.lpfnWndProc   = windowProc;
        wc.hInstance     = hInstance;
        wc.hCursor       = LoadCursor(NULL, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
        wc.lpszClassName = "CameraAppMainWindow";
        wc.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
        RegisterClassExA(&wc);

        // Calculate window rect for desired client area
        RECT rc = { 0, 0, WINDOW_W, WINDOW_H };
        AdjustWindowRectEx(&rc, WS_OVERLAPPEDWINDOW, FALSE, 0);

        m_hwnd = CreateWindowExA(
            0, "CameraAppMainWindow", title.c_str(),
            WS_OVERLAPPEDWINDOW & ~WS_THICKFRAME & ~WS_MAXIMIZEBOX,
            CW_USEDEFAULT, CW_USEDEFAULT,
            rc.right - rc.left, rc.bottom - rc.top,
            NULL, NULL, hInstance, this);

        if (!m_hwnd) return false;

        createControls();

        ShowWindow(m_hwnd, SW_SHOW);
        UpdateWindow(m_hwnd);

        // Keep-alive timer (every 60 seconds)
        SetTimer(m_hwnd, ID_TIMER_KEEPALIVE, 60000, NULL);

        return true;
    }

    // -----------------------------------------------------------------------
    // Message loop
    // -----------------------------------------------------------------------
    int run() {
        MSG msg;
        while (GetMessage(&msg, NULL, 0, 0)) {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        return static_cast<int>(msg.wParam);
    }

    void destroy() {
        if (m_hwnd) {
            KillTimer(m_hwnd, ID_TIMER_KEEPALIVE);
            DestroyWindow(m_hwnd);
            m_hwnd = nullptr;
        }
        if (m_gdiplusToken) {
            Gdiplus::GdiplusShutdown(m_gdiplusToken);
            m_gdiplusToken = 0;
        }
    }

    HWND handle() const { return m_hwnd; }
    Actions& actions() { return m_actions; }

    // -----------------------------------------------------------------------
    // Update Live View frame with double-buffering (prevents flickering)
    //
    // Algorithm:
    // 1. Write new frame data to back buffer
    // 2. Increment sequence number
    // 3. Trigger repaint
    // 4. During render, front buffer is swapped only if new frame exists
    //
    // This prevents the UI from flickering between old/new/empty buffers
    // because only one buffer is read while the other is being updated.
    // -----------------------------------------------------------------------
    // -----------------------------------------------------------------------
    // Update Live View frame with pre-decoded BITMAP (streaming thread did JPEG decode)
    // This is MUCH faster than decoding in paint routine!
    // -----------------------------------------------------------------------
    void updateLiveViewFrame(HBITMAP bitmap, int width, int height) {
        static uint64_t frameCount = 0;
        frameCount++;

        {
            std::lock_guard<std::mutex> lock(m_lvMutex);
            // Replace old back bitmap with new decoded bitmap
            if (m_lvBitmapBack) {
                DeleteObject(m_lvBitmapBack);  // Clean up old bitmap
            }
            m_lvBitmapBack = bitmap;
            m_lvBitmapWidth = width;
            m_lvBitmapHeight = height;
            // Signal new frame ready
            m_lvFrameSeq++;
        }

        // Diagnostic logging (first 10 frames + every 200th)
        if (frameCount <= 10 || frameCount % 200 == 0) {
            ErrorHandler::dbg("MainWindow::updateLiveViewFrame",
                "frame#=" + std::to_string(frameCount) +
                " bitmap=" + std::to_string((uintptr_t)bitmap) +
                " size=" + std::to_string(width) + "x" + std::to_string(height) +
                " seq=" + std::to_string(m_lvFrameSeq));
        }

        // Trigger ASYNC repaint (not UpdateWindow! Let Windows schedule naturally)
        InvalidateRect(m_lvPanel, NULL, FALSE);
    }

    // Backward compatibility wrapper (for old jpeg callback)
    void updateLiveViewFrame(const uint8_t* jpegData, size_t dataSize) {
        // Legacy method - decode happens in streaming thread now, so this is rarely called
        // But keep it for compatibility
        if (jpegData && dataSize > 0) {
            HBITMAP bitmap = nullptr;
            int width = 0, height = 0;
            // Would need to decode here, but better to decode in streaming thread
            // For now just ignore legacy calls
        }
    }

    // -----------------------------------------------------------------------
    // Update status text (thread-safe)
    // -----------------------------------------------------------------------
    void setStatus(const std::string& text) {
        std::lock_guard<std::mutex> lock(m_statusMutex);
        m_pendingStatus = text;
        PostMessage(m_hwnd, WM_APP_STATUS_UPDATE, 0, 0);
    }

    // -----------------------------------------------------------------------
    // Update camera info bar
    // -----------------------------------------------------------------------
    void setCameraInfo(const std::string& text) {
        if (m_lblCameraInfo) {
            SetWindowTextA(m_lblCameraInfo, text.c_str());
        }
    }

    // -----------------------------------------------------------------------
    // Populate camera combo box
    // -----------------------------------------------------------------------
    void setCameraList(const std::vector<std::string>& names) {
        SendMessage(m_cmbCamera, CB_RESETCONTENT, 0, 0);
        for (auto& name : names) {
            SendMessageA(m_cmbCamera, CB_ADDSTRING, 0, (LPARAM)name.c_str());
        }
        if (!names.empty()) {
            SendMessage(m_cmbCamera, CB_SETCURSEL, 0, 0);
        }
    }

    int selectedCameraIndex() const {
        return (int)SendMessage(m_cmbCamera, CB_GETCURSEL, 0, 0);
    }

    // -----------------------------------------------------------------------
    // Populate a property combo box
    // -----------------------------------------------------------------------
    void setPropertyComboItems(int comboId,
                               const std::vector<std::pair<EdsInt32, std::string>>& items,
                               EdsInt32 currentValue) {
        HWND combo = getComboByID(comboId);
        if (!combo) return;

        SendMessage(combo, CB_RESETCONTENT, 0, 0);

        int selectIdx = 0;
        for (size_t i = 0; i < items.size(); ++i) {
            SendMessageA(combo, CB_ADDSTRING, 0, (LPARAM)items[i].second.c_str());
            SendMessage(combo, CB_SETITEMDATA, i, (LPARAM)items[i].first);
            if (items[i].first == currentValue) {
                selectIdx = static_cast<int>(i);
            }
        }
        SendMessage(combo, CB_SETCURSEL, selectIdx, 0);
    }

    // -----------------------------------------------------------------------
    // Set connection UI state
    // -----------------------------------------------------------------------
    void setConnectedState(bool connected) {
        EnableWindow(m_btnConnect, !connected);
        EnableWindow(m_btnDisconnect, connected);
        EnableWindow(m_btnTakePicture, connected);
        EnableWindow(m_btnTakeNoAF, connected);
        EnableWindow(m_btnStartLV, connected);
        EnableWindow(m_btnStopLV, connected);
        EnableWindow(m_btnFocusNear, connected);
        EnableWindow(m_btnFocusFar, connected);
        EnableWindow(m_btnAFOn, connected);
        EnableWindow(m_btnAFOff, connected);
        EnableWindow(m_btnZoomFit, connected);
        EnableWindow(m_btnZoom5x, connected);
        for (auto combo : { m_cmbISO, m_cmbAv, m_cmbTv, m_cmbWB, m_cmbQuality, m_cmbMetering }) {
            EnableWindow(combo, connected);
        }
    }

    // -----------------------------------------------------------------------
    // Notify file saved (thread-safe)
    // -----------------------------------------------------------------------
    void notifyFileSaved(const std::string& fileName) {
        std::lock_guard<std::mutex> lock(m_statusMutex);
        m_pendingStatus = "Saved: " + fileName;
        PostMessage(m_hwnd, WM_APP_FILE_SAVED, 0, 0);
    }

    // -----------------------------------------------------------------------
    // Getter methods
    // -----------------------------------------------------------------------
    HWND getComboByID(int id) const {
        switch (id) {
        case ID_COMBO_ISO:      return m_cmbISO;
        case ID_COMBO_AV:       return m_cmbAv;
        case ID_COMBO_TV:       return m_cmbTv;
        case ID_COMBO_WB:       return m_cmbWB;
        case ID_COMBO_QUALITY:  return m_cmbQuality;
        case ID_COMBO_METERING: return m_cmbMetering;
        case ID_COMBO_COLORTEMP: return m_cmbColorTemp;
        default: return nullptr;
        }
    }

    HWND getKelvinEdit() const { return m_editKelvin; }
    HWND getApplyKelvinButton() const { return m_btnApplyKelvin; }

private:
    // -----------------------------------------------------------------------
    // Create all child controls
    // -----------------------------------------------------------------------
    void createControls() {
        HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
        int x, y;

        // ===== TOP TOOLBAR =====
        x = 10; y = 8;

        // Camera selector combo
        createLabel("Camera:", x, y + 3, 50, 20);
        x += 55;
        m_cmbCamera = createCombo(ID_COMBO_CAMERA, x, y, 200, 200);
        x += 210;

        m_btnConnect = createButton("Connect", ID_BTN_CONNECT, x, y, 80, BTN_H);
        x += 85;
        m_btnDisconnect = createButton("Disconnect", ID_BTN_DISCONNECT, x, y, 90, BTN_H);
        x += 100;

        // Camera info label (fills rest of toolbar)
        m_lblCameraInfo = createLabel("No camera connected", x, y + 5, 450, 20);

        // ===== LIVE VIEW PANEL (left) =====
        int lvX = 10, lvY = TOOLBAR_H + 5;
        m_lvPanel = CreateWindowExA(
            WS_EX_CLIENTEDGE, "STATIC", "",
            WS_CHILD | WS_VISIBLE | SS_OWNERDRAW,
            lvX, lvY, LV_WIDTH, LV_HEIGHT,
            m_hwnd, (HMENU)ID_STATIC_LV_PANEL, m_hInstance, NULL);

        // ===== RIGHT PANEL =====
        int panelX = LV_WIDTH + 25;
        y = TOOLBAR_H + 10;

        // -- Capture section --
        createSectionLabel("CAPTURE", panelX, y);
        y += 22;
        m_btnTakePicture = createButton("Take Picture", ID_BTN_TAKE_PICTURE, panelX, y, BTN_W, BTN_H);
        m_btnTakeNoAF = createButton("Take (No AF)", ID_BTN_TAKE_NOAF, panelX + BTN_W + 8, y, BTN_W, BTN_H);
        y += BTN_H + 15;

        // -- Live View section --
        createSectionLabel("LIVE VIEW", panelX, y);
        y += 22;
        m_btnStartLV = createButton("Start LV", ID_BTN_START_LV, panelX, y, BTN_W, BTN_H);
        m_btnStopLV = createButton("Stop LV", ID_BTN_STOP_LV, panelX + BTN_W + 8, y, BTN_W, BTN_H);
        y += BTN_H + 6;
        m_btnZoomFit = createButton("Zoom Fit", ID_BTN_ZOOM_FIT, panelX, y, BTN_W, BTN_H);
        m_btnZoom5x = createButton("Zoom 5x", ID_BTN_ZOOM_5X, panelX + BTN_W + 8, y, BTN_W, BTN_H);
        y += BTN_H + 15;

        // -- Focus section --
        createSectionLabel("FOCUS", panelX, y);
        y += 22;
        m_btnFocusNear = createButton("<< Near", ID_BTN_FOCUS_NEAR, panelX, y, BTN_W, BTN_H);
        m_btnFocusFar = createButton("Far >>", ID_BTN_FOCUS_FAR, panelX + BTN_W + 8, y, BTN_W, BTN_H);
        y += BTN_H + 6;
        m_btnAFOn = createButton("AF On", ID_BTN_AF_ON, panelX, y, BTN_W, BTN_H);
        m_btnAFOff = createButton("AF Off", ID_BTN_AF_OFF, panelX + BTN_W + 8, y, BTN_W, BTN_H);
        y += BTN_H + 15;

        // -- Settings section --
        createSectionLabel("SETTINGS", panelX, y);
        y += 24;

        auto addPropRow = [&](const char* label, int comboId, HWND& outCombo) {
            createLabel(label, panelX, y + 3, LABEL_W, 20);
            outCombo = createCombo(comboId, panelX + LABEL_W + 5, y, COMBO_W, 300);
            y += COMBO_H + 6;
        };

        addPropRow("ISO:", ID_COMBO_ISO, m_cmbISO);
        addPropRow("Av:", ID_COMBO_AV, m_cmbAv);
        addPropRow("Tv:", ID_COMBO_TV, m_cmbTv);
        addPropRow("WB:", ID_COMBO_WB, m_cmbWB);
        addPropRow("Quality:", ID_COMBO_QUALITY, m_cmbQuality);
        addPropRow("Meter:", ID_COMBO_METERING, m_cmbMetering);

        // Color Temperature section
        y += 35;
        CreateWindowA("STATIC", "Color Temp (K):", WS_CHILD | WS_VISIBLE,
            panelX, y, LABEL_W, 20, m_hwnd, (HMENU)0, m_hInstance, NULL);
        m_cmbColorTemp = createCombo(ID_COMBO_COLORTEMP, panelX + LABEL_W + 5, y, COMBO_W, 150);

        y += 25;
        CreateWindowA("STATIC", "Custom Kelvin:", WS_CHILD | WS_VISIBLE,
            panelX, y, LABEL_W, 20, m_hwnd, (HMENU)0, m_hInstance, NULL);
        m_editKelvin = CreateWindowA("EDIT", "5200", WS_CHILD | WS_VISIBLE | WS_BORDER | ES_NUMBER,
            panelX + LABEL_W + 5, y, 60, 20, m_hwnd, (HMENU)ID_EDIT_KELVIN, m_hInstance, NULL);
        m_btnApplyKelvin = CreateWindowA("BUTTON", "Apply", WS_CHILD | WS_VISIBLE,
            panelX + LABEL_W + 70, y, 50, 20, m_hwnd, (HMENU)ID_BUTTON_APPLY_KELVIN, m_hInstance, NULL);

        // ===== STATUS BAR =====
        m_lblStatus = CreateWindowExA(
            WS_EX_CLIENTEDGE, "STATIC", " Ready",
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            0, WINDOW_H - STATUSBAR_H, WINDOW_W, STATUSBAR_H,
            m_hwnd, (HMENU)ID_STATIC_STATUS, m_hInstance, NULL);
        SendMessage(m_lblStatus, WM_SETFONT, (WPARAM)hFont, TRUE);

        // Set initial state (disconnected)
        setConnectedState(false);
        EnableWindow(m_btnDisconnect, FALSE);
    }

    // -----------------------------------------------------------------------
    // Helper: create button
    // -----------------------------------------------------------------------
    HWND createButton(const char* text, int id, int x, int y, int w, int h) {
        HWND btn = CreateWindowExA(0, "BUTTON", text,
            WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
            x, y, w, h, m_hwnd, (HMENU)(INT_PTR)id, m_hInstance, NULL);
        SendMessage(btn, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE);
        return btn;
    }

    // -----------------------------------------------------------------------
    // Helper: create combo box
    // -----------------------------------------------------------------------
    HWND createCombo(int id, int x, int y, int w, int dropH) {
        HWND combo = CreateWindowExA(0, "COMBOBOX", "",
            WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_VSCROLL,
            x, y, w, dropH, m_hwnd, (HMENU)(INT_PTR)id, m_hInstance, NULL);
        SendMessage(combo, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE);
        return combo;
    }

    // -----------------------------------------------------------------------
    // Helper: create label
    // -----------------------------------------------------------------------
    HWND createLabel(const char* text, int x, int y, int w, int h) {
        HWND lbl = CreateWindowExA(0, "STATIC", text,
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            x, y, w, h, m_hwnd, NULL, m_hInstance, NULL);
        SendMessage(lbl, WM_SETFONT, (WPARAM)GetStockObject(DEFAULT_GUI_FONT), TRUE);
        return lbl;
    }

    // -----------------------------------------------------------------------
    // Helper: create section header label
    // -----------------------------------------------------------------------
    void createSectionLabel(const char* text, int x, int y) {
        HWND lbl = CreateWindowExA(0, "STATIC", text,
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            x, y, 250, 18, m_hwnd, NULL, m_hInstance, NULL);
        // Bold font
        HFONT boldFont = CreateFontA(14, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, 0, 0, "Segoe UI");
        SendMessage(lbl, WM_SETFONT, (WPARAM)boldFont, TRUE);
    }

    // -----------------------------------------------------------------------
    // Render Live View JPEG frame using GDI+
    // -----------------------------------------------------------------------
    // -----------------------------------------------------------------------
    // Render pre-decoded bitmap using fast BitBlt (NOT GDI+!)
    // Bitmap already decoded in streaming thread, so this is ultra-fast
    // WM_ERASEBKGND disabled, so no black flicker between frames
    // -----------------------------------------------------------------------
    void renderLiveViewFrame(HDC hdc) {
        static uint64_t renderCount = 0;
        renderCount++;

        HBITMAP bitmapToRender = nullptr;
        int bitmapWidth = 0, bitmapHeight = 0;
        uint64_t seqBefore, renderedBefore;

        // **SWAP BUFFERS only if new frame arrived**
        {
            std::lock_guard<std::mutex> lock(m_lvMutex);
            seqBefore = m_lvFrameSeq;
            renderedBefore = m_lvRenderedSeq;

            if (m_lvFrameSeq > m_lvRenderedSeq) {
                // Swap bitmap pointers (O(1))
                std::swap(m_lvBitmapFront, m_lvBitmapBack);
                bitmapWidth = m_lvBitmapWidth;
                bitmapHeight = m_lvBitmapHeight;
                m_lvRenderedSeq = m_lvFrameSeq;
            }

            bitmapToRender = m_lvBitmapFront;
        }

        // Diagnostic logging
        if (renderCount <= 20 || renderCount % 100 == 0) {
            ErrorHandler::dbg("MainWindow::renderLiveViewFrame",
                "render#=" + std::to_string(renderCount) +
                " bitmap=" + std::to_string((uintptr_t)bitmapToRender) +
                " seq=" + std::to_string(seqBefore) +
                " rendered=" + std::to_string(renderedBefore) +
                " swapped=" + std::string(seqBefore > renderedBefore ? "Y" : "N"));
        }

        RECT rc;
        GetClientRect(m_lvPanel, &rc);
        int panelW = rc.right - rc.left;
        int panelH = rc.bottom - rc.top;

        // Check if we have a valid bitmap to display
        if (!bitmapToRender || bitmapWidth == 0 || bitmapHeight == 0) {
            // Placeholder (only at startup)
            if (renderCount <= 5) {
                ErrorHandler::log(LogLevel::Warning,
                    "[RenderFlicker] render#=" + std::to_string(renderCount) +
                    " - NO BITMAP available!");
            }
            // **WM_ERASEBKGND is disabled, so we don't get black clearing here**
            return;
        }

        // **FAST RENDERING using BitBlt (NOT GDI+ Graphics::DrawImage!)**
        // Create memory DC compatible with screen DC
        HDC hdcMem = CreateCompatibleDC(hdc);
        if (!hdcMem) return;

        // Select bitmap into memory DC
        HBITMAP hOldBitmap = (HBITMAP)SelectObject(hdcMem, bitmapToRender);

        // Calculate scaled dimensions (fit to panel with aspect ratio)
        float scaleX = (float)panelW / bitmapWidth;
        float scaleY = (float)panelH / bitmapHeight;
        float scale = (scaleX < scaleY) ? scaleX : scaleY;

        int drawW = (int)(bitmapWidth * scale);
        int drawH = (int)(bitmapHeight * scale);
        int drawX = (panelW - drawW) / 2;
        int drawY = (panelH - drawH) / 2;

        // **Ultra-fast BitBlt rendering**
        // StretchDIBits is even faster for scaling, but BitBlt is simpler
        StretchBlt(hdc, drawX, drawY, drawW, drawH,
                   hdcMem, 0, 0, bitmapWidth, bitmapHeight,
                   SRCCOPY);

        // Restore and cleanup
        SelectObject(hdcMem, hOldBitmap);
        DeleteDC(hdcMem);

        // Done! Very fast, no flicker, no black clearing between frames
    }

    // -----------------------------------------------------------------------
    // Window procedure
    // -----------------------------------------------------------------------
    static LRESULT CALLBACK windowProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
        MainWindow* self = nullptr;

        if (msg == WM_CREATE) {
            auto cs = reinterpret_cast<CREATESTRUCTA*>(lParam);
            self = static_cast<MainWindow*>(cs->lpCreateParams);
            SetWindowLongPtr(hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(self));
        } else {
            self = reinterpret_cast<MainWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
        }

        if (!self) return DefWindowProcA(hwnd, msg, wParam, lParam);

        switch (msg) {
        case WM_COMMAND: {
            int id = LOWORD(wParam);
            int code = HIWORD(wParam);

            // Combo box selection changed
            if (code == CBN_SELCHANGE) {
                HWND combo = (HWND)lParam;
                int sel = (int)SendMessage(combo, CB_GETCURSEL, 0, 0);
                if (sel >= 0 && self->m_actions.onPropertySelected) {
                    EdsInt32 val = (EdsInt32)SendMessage(combo, CB_GETITEMDATA, sel, 0);
                    self->m_actions.onPropertySelected(id, sel, val);
                }
                return 0;
            }

            // Buttons
            switch (id) {
            case ID_BTN_CONNECT:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Connect");
                if (self->m_actions.onConnect) self->m_actions.onConnect();
                break;
            case ID_BTN_DISCONNECT:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Disconnect");
                if (self->m_actions.onDisconnect) self->m_actions.onDisconnect();
                break;
            case ID_BTN_TAKE_PICTURE:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Take Picture");
                if (self->m_actions.onTakePicture) self->m_actions.onTakePicture();
                break;
            case ID_BTN_TAKE_NOAF:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Take Picture No AF");
                if (self->m_actions.onTakePictureNoAF) self->m_actions.onTakePictureNoAF();
                break;
            case ID_BTN_START_LV:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Start LV");
                if (self->m_actions.onStartLiveView) self->m_actions.onStartLiveView();
                break;
            case ID_BTN_STOP_LV:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Stop LV");
                if (self->m_actions.onStopLiveView) self->m_actions.onStopLiveView();
                break;
            case ID_BTN_FOCUS_NEAR:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Focus Near");
                if (self->m_actions.onFocusNear) self->m_actions.onFocusNear();
                break;
            case ID_BTN_FOCUS_FAR:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Focus Far");
                if (self->m_actions.onFocusFar) self->m_actions.onFocusFar();
                break;
            case ID_BTN_AF_ON:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: AF On");
                if (self->m_actions.onAFOn) self->m_actions.onAFOn();
                break;
            case ID_BTN_AF_OFF:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: AF Off");
                if (self->m_actions.onAFOff) self->m_actions.onAFOff();
                break;
            case ID_BTN_ZOOM_FIT:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Zoom Fit");
                if (self->m_actions.onZoomFit) self->m_actions.onZoomFit();
                break;
            case ID_BTN_ZOOM_5X:
                ErrorHandler::dbg("MainWindow::WM_COMMAND", "Action từ người dùng: Zoom 5x");
                if (self->m_actions.onZoom5x) self->m_actions.onZoom5x();
                break;

            case ID_BUTTON_APPLY_KELVIN: {
                char buf[32] = {};
                GetWindowTextA(self->m_editKelvin, buf, sizeof(buf));
                EdsUInt32 kelvin = std::stoul(buf);
                ErrorHandler::dbg("MainWindow::WM_COMMAND",
                    "Action từ người dùng: Apply Color Temperature " + std::string(buf) + "K");
                if (self->m_actions.onColorTemperatureChanged) {
                    self->m_actions.onColorTemperatureChanged(kelvin);
                }
                break;
            }

            case ID_COMBO_COLORTEMP:
                if (HIWORD(wParam) == CBN_SELCHANGE) {
                    int sel = (int)SendMessage((HWND)lParam, CB_GETCURSEL, 0, 0);
                    if (sel >= 0) {
                        EdsUInt32 kelvin = (EdsUInt32)SendMessage((HWND)lParam, CB_GETITEMDATA, sel, 0);
                        if (self->m_actions.onColorTemperatureChanged) {
                            self->m_actions.onColorTemperatureChanged(kelvin);
                        }
                    }
                }
                break;
            }
            return 0;
        }

        case WM_ERASEBKGND: {
            // **CRITICAL FIX**: Disable background erasing for Live View panel
            // Windows normally clears background (BLACK) before WM_DRAWITEM
            // This causes visible black flicker between frames
            // Since we decode JPEG in streaming thread, rendering is fast enough
            // that we don't need Windows to clear the background
            auto* dis = reinterpret_cast<DRAWITEMSTRUCT*>(lParam);
            if (dis && dis->CtlID == ID_STATIC_LV_PANEL) {
                return 1;  // Return 1 = "I handled erasing" (but we didn't, so no black clearing!)
            }
            // For other controls, let Windows do its thing
            return DefWindowProcA(hwnd, msg, wParam, lParam);
        }

        case WM_DRAWITEM: {
            auto* dis = reinterpret_cast<DRAWITEMSTRUCT*>(lParam);
            if (dis->CtlID == ID_STATIC_LV_PANEL) {
                self->renderLiveViewFrame(dis->hDC);
                return TRUE;
            }
            break;
        }

        case WM_APP_LV_FRAME: {
            // **NEW STRATEGY**: Just invalidate, don't force synchronous update
            // Streaming thread decodes JPEG → bitmap in real-time
            // So Windows can schedule WM_DRAWITEM naturally
            // No need for UpdateWindow() - that was causing redundant repaints
            // and amplifying the flicker!
            InvalidateRect(self->m_lvPanel, NULL, FALSE);
            // Let Windows handle painting naturally (no UpdateWindow!)
            return 0;
        }

        case WM_APP_STATUS_UPDATE:
        case WM_APP_FILE_SAVED: {
            std::string status;
            {
                std::lock_guard<std::mutex> lock(self->m_statusMutex);
                status = self->m_pendingStatus;
            }
            SetWindowTextA(self->m_lblStatus, (" " + status).c_str());
            return 0;
        }

        case WM_TIMER:
            if (wParam == ID_TIMER_KEEPALIVE) {
                // Keep-alive handled by facade
            }
            return 0;

        case WM_CLOSE:
            PostQuitMessage(0);
            return 0;

        case WM_DESTROY:
            return 0;
        }

        return DefWindowProcA(hwnd, msg, wParam, lParam);
    }

    // -----------------------------------------------------------------------
    // Members
    // -----------------------------------------------------------------------
    HINSTANCE   m_hInstance = nullptr;
    HWND        m_hwnd = nullptr;
    ULONG_PTR   m_gdiplusToken = 0;
    Actions     m_actions;

    // Controls
    HWND m_btnConnect = nullptr, m_btnDisconnect = nullptr;
    HWND m_btnTakePicture = nullptr, m_btnTakeNoAF = nullptr;
    HWND m_btnStartLV = nullptr, m_btnStopLV = nullptr;
    HWND m_btnFocusNear = nullptr, m_btnFocusFar = nullptr;
    HWND m_btnAFOn = nullptr, m_btnAFOff = nullptr;
    HWND m_btnZoomFit = nullptr, m_btnZoom5x = nullptr;
    HWND m_cmbCamera = nullptr;
    HWND m_cmbISO = nullptr, m_cmbAv = nullptr, m_cmbTv = nullptr;
    HWND m_cmbWB = nullptr, m_cmbQuality = nullptr, m_cmbMetering = nullptr;
    HWND m_cmbColorTemp = nullptr;
    HWND m_editKelvin = nullptr, m_btnApplyKelvin = nullptr;
    HWND m_lblCameraInfo = nullptr, m_lblStatus = nullptr;
    HWND m_lvPanel = nullptr;

    // Live View BITMAP double-buffering (pre-decoded, ultra-fast rendering)
    // Streaming thread decodes JPEG → HBITMAP, writes to m_lvBitmapBack
    // UI thread renders via BitBlt (not GDI+, much faster!)
    // WM_ERASEBKGND disabled, no black flicker
    std::mutex              m_lvMutex;
    HBITMAP                 m_lvBitmapFront = nullptr;      // UI renders from this via BitBlt
    HBITMAP                 m_lvBitmapBack = nullptr;       // Streaming thread decodes/writes
    int                     m_lvBitmapWidth = 0;            // Bitmap pixel dimensions
    int                     m_lvBitmapHeight = 0;
    uint64_t                m_lvFrameSeq = 0;               // Sequence counter (track updates)
    uint64_t                m_lvRenderedSeq = 0;            // Track what was rendered

    // Status text buffer
    std::mutex   m_statusMutex;
    std::string  m_pendingStatus;
};

} // namespace CameraApp
