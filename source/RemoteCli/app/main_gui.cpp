#include <windows.h>
#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>
#include "imgui.h"
#include "imgui_impl_win32.h"
#include "imgui_impl_dx11.h"
#include "CameraGUI.h"
#include "CameraRemote_SDK.h"

using Microsoft::WRL::ComPtr;

// Forward declare message handler
extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);

// Global state
static ComPtr<ID3D11Device> g_pd3dDevice;
static ComPtr<ID3D11DeviceContext> g_pd3dDeviceContext;
static ComPtr<IDXGISwapChain> g_pSwapChain;
static ComPtr<ID3D11RenderTargetView> g_mainRenderTargetView;
static CameraGUI* g_camera_gui = nullptr;

LRESULT WINAPI WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam)
{
    if (ImGui_ImplWin32_WndProcHandler(hWnd, msg, wParam, lParam))
        return true;

    switch (msg)
    {
    case WM_SIZE:
        if (g_pd3dDevice != nullptr && wParam != SIZE_MINIMIZED)
        {
            UINT width = (UINT)LOWORD(lParam);
            UINT height = (UINT)HIWORD(lParam);

            g_mainRenderTargetView.Reset();
            g_pSwapChain->ResizeBuffers(0, width, height, DXGI_FORMAT_UNKNOWN, 0);

            ID3D11Texture2D* pBackBuffer = nullptr;
            g_pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));
            if (pBackBuffer)
            {
                g_pd3dDevice->CreateRenderTargetView(pBackBuffer, nullptr, g_mainRenderTargetView.GetAddressOf());
                pBackBuffer->Release();
            }
        }
        return 0;
    case WM_SYSCOMMAND:
        if ((wParam & 0xfff0) == SC_KEYMENU)
            return 0;
        break;
    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }
    return DefWindowProc(hWnd, msg, wParam, lParam);
}

bool CreateDeviceD3D(HWND hWnd)
{
    DXGI_SWAP_CHAIN_DESC sd;
    ZeroMemory(&sd, sizeof(sd));
    sd.BufferCount = 2;
    sd.BufferDesc.Width = 0;
    sd.BufferDesc.Height = 0;
    sd.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    sd.BufferDesc.RefreshRate.Numerator = 60;
    sd.BufferDesc.RefreshRate.Denominator = 1;
    sd.Flags = DXGI_SWAP_CHAIN_FLAG_ALLOW_MODE_SWITCH;
    sd.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    sd.OutputWindow = hWnd;
    sd.SampleDesc.Count = 1;
    sd.SampleDesc.Quality = 0;
    sd.Windowed = TRUE;
    sd.SwapEffect = DXGI_SWAP_EFFECT_DISCARD;

    UINT createDeviceFlags = 0;
#ifdef _DEBUG
    createDeviceFlags |= D3D11_CREATE_DEVICE_DEBUG;
#endif

    D3D_FEATURE_LEVEL featureLevel;
    const D3D_FEATURE_LEVEL featureLevelArray[2] = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_0,
    };

    HRESULT res = D3D11CreateDeviceAndSwapChain(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        createDeviceFlags,
        featureLevelArray,
        2,
        D3D11_SDK_VERSION,
        &sd,
        g_pSwapChain.GetAddressOf(),
        g_pd3dDevice.GetAddressOf(),
        &featureLevel,
        g_pd3dDeviceContext.GetAddressOf()
    );

    if (res == DXGI_ERROR_UNSUPPORTED)
    {
        res = D3D11CreateDeviceAndSwapChain(
            nullptr,
            D3D_DRIVER_TYPE_WARP,
            nullptr,
            createDeviceFlags,
            featureLevelArray,
            2,
            D3D11_SDK_VERSION,
            &sd,
            g_pSwapChain.GetAddressOf(),
            g_pd3dDevice.GetAddressOf(),
            &featureLevel,
            g_pd3dDeviceContext.GetAddressOf()
        );
    }

    if (res != S_OK)
        return false;

    ID3D11Texture2D* pBackBuffer = nullptr;
    g_pSwapChain->GetBuffer(0, IID_PPV_ARGS(&pBackBuffer));
    if (pBackBuffer)
    {
        g_pd3dDevice->CreateRenderTargetView(pBackBuffer, nullptr, g_mainRenderTargetView.GetAddressOf());
        pBackBuffer->Release();
    }

    return true;
}

void CleanupDeviceD3D()
{
    g_mainRenderTargetView.Reset();
    g_pSwapChain.Reset();
    g_pd3dDeviceContext.Reset();
    g_pd3dDevice.Reset();
}

void RenderFrame()
{
    ImGui::SetCurrentContext(ImGui::GetCurrentContext());

    // Start ImGui frame
    ImGui_ImplDX11_NewFrame();
    ImGui_ImplWin32_NewFrame();
    ImGui::NewFrame();

    // Update camera state
    if (g_camera_gui)
    {
        g_camera_gui->Update();
        g_camera_gui->Render();
    }

    // Rendering
    ImGui::Render();

    const float clear_color_with_alpha[4] = { 0.45f, 0.55f, 0.60f, 1.00f };
    g_pd3dDeviceContext->OMSetRenderTargets(1, g_mainRenderTargetView.GetAddressOf(), nullptr);
    g_pd3dDeviceContext->ClearRenderTargetView(g_mainRenderTargetView.Get(), clear_color_with_alpha);
    ImGui_ImplDX11_RenderDrawData(ImGui::GetDrawData());

    g_pSwapChain->Present(1, 0); // Present with vsync
}

static void EarlyLog(const char* msg)
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

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    EarlyLog("WinMain start");

    // Initialize CRSDK
    EarlyLog("Calling SCRSDK::Init...");
    if (!SCRSDK::Init())
    {
        EarlyLog("SCRSDK::Init FAILED");
        MessageBoxA(nullptr, "Failed to initialize Camera Remote SDK", "Error", MB_OK | MB_ICONERROR);
        return 1;
    }
    EarlyLog("SCRSDK::Init OK");

    // Create window
    const wchar_t* window_class = L"ImGui Example";
    WNDCLASSEXW wc = {
        sizeof(wc), CS_CLASSDC, WndProc, 0L, 0L,
        GetModuleHandle(nullptr), nullptr, nullptr, nullptr, nullptr,
        window_class, nullptr
    };
    RegisterClassExW(&wc);

    HWND hwnd = CreateWindowW(
        window_class,
        L"Sony Camera Remote Control",
        WS_OVERLAPPEDWINDOW,
        100, 100, 1280, 800,
        nullptr, nullptr,
        wc.hInstance,
        nullptr
    );

    EarlyLog("Window created");

    // Create D3D11 device
    EarlyLog("Calling CreateDeviceD3D...");
    if (!CreateDeviceD3D(hwnd))
    {
        EarlyLog("CreateDeviceD3D FAILED");
        CleanupDeviceD3D();
        DestroyWindow(hwnd);
        UnregisterClassW(wc.lpszClassName, wc.hInstance);
        SCRSDK::Release();
        MessageBoxA(nullptr, "Failed to create DirectX 11 device", "Error", MB_OK | MB_ICONERROR);
        return 1;
    }
    EarlyLog("D3D11 OK");

    // Show window
    ShowWindow(hwnd, SW_SHOWDEFAULT);
    UpdateWindow(hwnd);

    // Setup ImGui
    EarlyLog("Init ImGui...");
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;

    ImGui::StyleColorsDark();

    ImGui_ImplWin32_Init(hwnd);
    ImGui_ImplDX11_Init(g_pd3dDevice.Get(), g_pd3dDeviceContext.Get());

    // Create CameraGUI
    EarlyLog("Create CameraGUI...");
    g_camera_gui = new CameraGUI();
    g_camera_gui->SetD3DDevice(g_pd3dDevice.Get(), g_pd3dDeviceContext.Get());
    g_camera_gui->Initialize();
    EarlyLog("CameraGUI initialized — entering message loop");

    // Main loop
    MSG msg;
    ZeroMemory(&msg, sizeof(msg));
    bool done = false;

    while (!done)
    {
        if (PeekMessageW(&msg, nullptr, 0U, 0U, PM_REMOVE))
        {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
            if (msg.message == WM_QUIT)
                done = true;
        }
        else
        {
            RenderFrame();
        }
    }

    // Cleanup
    g_camera_gui->Shutdown();
    delete g_camera_gui;
    g_camera_gui = nullptr;

    ImGui_ImplDX11_Shutdown();
    ImGui_ImplWin32_Shutdown();
    ImGui::DestroyContext();

    CleanupDeviceD3D();
    DestroyWindow(hwnd);
    UnregisterClassW(wc.lpszClassName, wc.hInstance);

    SCRSDK::Release();

    return 0;
}
