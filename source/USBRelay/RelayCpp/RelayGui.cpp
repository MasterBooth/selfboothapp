// RelayGui.cpp
// UI Win32 thuan (khong phu thuoc Qt/.NET) de dieu khien USB Relay.
// Build x86 (DLL hang la 32-bit). Xem build.bat.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <string>
#include <vector>

#include "RelayCore.h"

using namespace RelayCore;

// --- Control IDs ---
#define IDC_COMBO       1001
#define IDC_FIND        1002
#define IDC_CONNECT     1003
#define IDC_DISCONNECT  1004
#define IDC_STATUS      1005
#define IDC_ALLON       1006
#define IDC_ALLOFF      1007
#define IDC_READ        1008
#define IDC_BITS        1009
#define IDC_CH_BASE     1100   // kenh i => IDC_CH_BASE + i (i = 1..8)

static const int CH_COUNT = 8;

// --- Trang thai toan cuc ---
static HWND  g_hCombo = nullptr;
static HWND  g_hStatus = nullptr;
static HWND  g_hBits = nullptr;
static HWND  g_hChBtn[CH_COUNT] = { nullptr };
static int   g_handle = 0;            // 0 = chua ket noi
static std::string g_serial;

// Dat font GUI mac dinh cho moi control con.
static BOOL CALLBACK SetFontProc(HWND hChild, LPARAM lParam)
{
    SendMessage(hChild, WM_SETFONT, (WPARAM)lParam, TRUE);
    return TRUE;
}

static void SetStatus(const std::string& msg)
{
    SetWindowTextA(g_hStatus, msg.c_str());
}

// Bat/tat (enable) cac nut thao tac khi co/khong ket noi.
static void EnableControls(bool connected)
{
    for (int i = 0; i < CH_COUNT; ++i)
        EnableWindow(g_hChBtn[i], connected);
    EnableWindow(GetDlgItem(GetParent(g_hChBtn[0]), IDC_ALLON), connected);
    EnableWindow(GetDlgItem(GetParent(g_hChBtn[0]), IDC_ALLOFF), connected);
    EnableWindow(GetDlgItem(GetParent(g_hChBtn[0]), IDC_READ), connected);
    EnableWindow(GetDlgItem(GetParent(g_hChBtn[0]), IDC_DISCONNECT), connected);
    EnableWindow(GetDlgItem(GetParent(g_hChBtn[0]), IDC_CONNECT), !connected);
}

// Doc trang thai phan cung va cap nhat caption tung nut kenh + dong bits.
static void RefreshChannelStates()
{
    unsigned int status = 0;
    if (g_handle == 0 || !Core_GetStatus(g_handle, status))
    {
        SetWindowTextA(g_hBits, "Trang thai: (khong doc duoc)");
        return;
    }

    for (int i = 0; i < CH_COUNT; ++i)
    {
        int on = (status >> i) & 0x1;
        char cap[32];
        wsprintfA(cap, "Kenh %d: %s", i + 1, on ? "BAT" : "TAT");
        SetWindowTextA(g_hChBtn[i], cap);
    }

    std::string bits = "Bits: ";
    for (int i = 0; i < CH_COUNT; ++i)
        bits += ('0' + ((status >> i) & 0x1));
    SetWindowTextA(g_hBits, bits.c_str());
}

static void RefreshDevices(HWND hwnd)
{
    SendMessageA(g_hCombo, CB_RESETCONTENT, 0, 0);
    std::vector<std::string> serials = Core_ListSerials();
    for (const auto& s : serials)
        SendMessageA(g_hCombo, CB_ADDSTRING, 0, (LPARAM)s.c_str());

    if (!serials.empty())
    {
        SendMessageA(g_hCombo, CB_SETCURSEL, 0, 0);
        SetStatus("Tim thay " + std::to_string(serials.size()) + " thiet bi. Chon va bam Ket noi.");
    }
    else
    {
        SetStatus("Khong tim thay thiet bi. Kiem tra cap USB roi bam Tim.");
    }
}

static void DoConnect(HWND hwnd)
{
    int sel = (int)SendMessageA(g_hCombo, CB_GETCURSEL, 0, 0);
    if (sel == CB_ERR)
    {
        MessageBoxA(hwnd, "Hay chon mot thiet bi trong danh sach.", "Thong bao", MB_ICONINFORMATION);
        return;
    }

    char buf[128] = { 0 };
    SendMessageA(g_hCombo, CB_GETLBTEXT, sel, (LPARAM)buf);

    if (g_handle != 0)
        Core_Close(g_handle);

    g_handle = Core_Open(buf);
    if (g_handle == 0)
    {
        SetStatus("Loi: khong mo duoc thiet bi.");
        EnableControls(false);
        return;
    }

    g_serial = buf;
    SetStatus("Da ket noi: " + g_serial);
    EnableControls(true);
    RefreshChannelStates();
}

static void DoDisconnect()
{
    if (g_handle != 0)
    {
        Core_Close(g_handle);
        g_handle = 0;
    }
    g_serial.clear();
    for (int i = 0; i < CH_COUNT; ++i)
    {
        char cap[32];
        wsprintfA(cap, "Kenh %d", i + 1);
        SetWindowTextA(g_hChBtn[i], cap);
    }
    SetWindowTextA(g_hBits, "Bits: --------");
    SetStatus("Da ngat ket noi.");
    EnableControls(false);
}

static void ToggleChannel(int channel)
{
    if (g_handle == 0) return;

    unsigned int status = 0;
    Core_GetStatus(g_handle, status);
    bool currentlyOn = ((status >> (channel - 1)) & 0x1) != 0;

    if (!Core_SetOne(g_handle, channel, !currentlyOn))
        SetStatus("Loi thao tac kenh " + std::to_string(channel));
    RefreshChannelStates();
}

static void CreateControls(HWND hwnd)
{
    // Hang 1: thiet bi + nut Tim
    CreateWindowA("STATIC", "Thiet bi:", WS_CHILD | WS_VISIBLE,
        15, 18, 60, 20, hwnd, nullptr, nullptr, nullptr);
    g_hCombo = CreateWindowA("COMBOBOX", "",
        WS_CHILD | WS_VISIBLE | CBS_DROPDOWNLIST | WS_VSCROLL,
        80, 15, 230, 200, hwnd, (HMENU)IDC_COMBO, nullptr, nullptr);
    CreateWindowA("BUTTON", "Tim", WS_CHILD | WS_VISIBLE,
        320, 14, 80, 26, hwnd, (HMENU)IDC_FIND, nullptr, nullptr);

    // Hang 2: Ket noi / Ngat
    CreateWindowA("BUTTON", "Ket noi", WS_CHILD | WS_VISIBLE,
        80, 50, 110, 28, hwnd, (HMENU)IDC_CONNECT, nullptr, nullptr);
    CreateWindowA("BUTTON", "Ngat ket noi", WS_CHILD | WS_VISIBLE,
        200, 50, 110, 28, hwnd, (HMENU)IDC_DISCONNECT, nullptr, nullptr);

    // Hang 3: trang thai
    g_hStatus = CreateWindowA("STATIC", "Chua ket noi.", WS_CHILD | WS_VISIBLE,
        15, 88, 390, 20, hwnd, (HMENU)IDC_STATUS, nullptr, nullptr);

    // Cac nut kenh: 2 hang x 4 cot
    for (int i = 0; i < CH_COUNT; ++i)
    {
        int col = i % 4;
        int row = i / 4;
        int x = 15 + col * 98;
        int y = 120 + row * 44;
        char cap[16];
        wsprintfA(cap, "Kenh %d", i + 1);
        g_hChBtn[i] = CreateWindowA("BUTTON", cap, WS_CHILD | WS_VISIBLE,
            x, y, 92, 38, hwnd, (HMENU)(IDC_CH_BASE + i + 1), nullptr, nullptr);
    }

    // Hang: Bat tat ca / Tat tat ca / Doc trang thai
    CreateWindowA("BUTTON", "Bat tat ca", WS_CHILD | WS_VISIBLE,
        15, 218, 120, 30, hwnd, (HMENU)IDC_ALLON, nullptr, nullptr);
    CreateWindowA("BUTTON", "Tat tat ca", WS_CHILD | WS_VISIBLE,
        145, 218, 120, 30, hwnd, (HMENU)IDC_ALLOFF, nullptr, nullptr);
    CreateWindowA("BUTTON", "Doc trang thai", WS_CHILD | WS_VISIBLE,
        275, 218, 130, 30, hwnd, (HMENU)IDC_READ, nullptr, nullptr);

    // Dong bits
    g_hBits = CreateWindowA("STATIC", "Bits: --------", WS_CHILD | WS_VISIBLE,
        15, 258, 390, 20, hwnd, (HMENU)IDC_BITS, nullptr, nullptr);

    // Font dep cho toan bo control
    HFONT hFont = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
    EnumChildWindows(hwnd, SetFontProc, (LPARAM)hFont);

    EnableControls(false);
}

static LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    switch (msg)
    {
    case WM_CREATE:
        CreateControls(hwnd);
        if (!Core_Init())
            MessageBoxA(hwnd, "Khong khoi tao duoc thu vien USB Relay.", "Loi", MB_ICONERROR);
        else
            RefreshDevices(hwnd);
        return 0;

    case WM_COMMAND:
    {
        int id = LOWORD(wParam);
        if (id == IDC_FIND)            RefreshDevices(hwnd);
        else if (id == IDC_CONNECT)    DoConnect(hwnd);
        else if (id == IDC_DISCONNECT) DoDisconnect();
        else if (id == IDC_READ)       RefreshChannelStates();
        else if (id == IDC_ALLON)    { if (g_handle) { Core_SetAll(g_handle, true);  RefreshChannelStates(); } }
        else if (id == IDC_ALLOFF)   { if (g_handle) { Core_SetAll(g_handle, false); RefreshChannelStates(); } }
        else if (id > IDC_CH_BASE && id <= IDC_CH_BASE + CH_COUNT)
            ToggleChannel(id - IDC_CH_BASE);
        return 0;
    }

    case WM_DESTROY:
        if (g_handle != 0)
            Core_Close(g_handle);
        Core_Exit();
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hwnd, msg, wParam, lParam);
}

int WINAPI WinMain(HINSTANCE hInst, HINSTANCE, LPSTR, int nCmdShow)
{
    const char* CLS = "RelayGuiWindow";

    WNDCLASSA wc = { 0 };
    wc.lpfnWndProc = WndProc;
    wc.hInstance = hInst;
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_BTNFACE + 1);
    wc.lpszClassName = CLS;
    wc.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
    RegisterClassA(&wc);

    HWND hwnd = CreateWindowA(CLS, "USB Relay Control",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX,
        CW_USEDEFAULT, CW_USEDEFAULT, 440, 330,
        nullptr, nullptr, hInst, nullptr);
    if (!hwnd)
        return 1;

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }
    return (int)msg.wParam;
}
