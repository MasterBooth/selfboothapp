/*=============================================================================
 * main_gui.cpp - Win32 GUI entry point for Canon Camera Control App
 *
 * Wires together:
 *   MainWindow  (Win32 UI)
 *   CameraFacade (camera engine)
 *   UIHandler   (event bridge)
 *
 * Images are saved to CameraApp/image/ folder.
 *============================================================================*/

#ifndef NOMINMAX
#define NOMINMAX
#endif

#include "Interface/CameraFacade.h"
#include "UI/MainWindow.h"
#include "UI/UIHandler.h"
#include "UI/PropertyLabels.h"

#include <windows.h>
#include <string>
#include <vector>
#include <thread>
#include <shlobj.h>    // SHCreateDirectoryExA
#include <iostream>
#include <cstdio>

using namespace CameraApp;

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------
static CameraFacade       g_facade;
static std::vector<CameraInfo> g_cameras;

// ---------------------------------------------------------------------------
// Get path to image/ folder next to executable
// ---------------------------------------------------------------------------
static std::string getImageFolder() {
    char exePath[MAX_PATH];
    GetModuleFileNameA(NULL, exePath, MAX_PATH);
    std::string path(exePath);
    size_t pos = path.find_last_of("\\/");
    if (pos != std::string::npos) {
        path = path.substr(0, pos + 1);
    }
    path += "image";
    // Create directory if needed
    SHCreateDirectoryExA(NULL, path.c_str(), NULL);
    return path;
}

// ---------------------------------------------------------------------------
// Refresh camera list in combo box
// ---------------------------------------------------------------------------
static void refreshCameraList(MainWindow& window) {
    CameraManager::releaseAll(g_cameras);

    auto result = g_facade.enumerateCameras(g_cameras);
    if (!result.ok() || g_cameras.empty()) {
        window.setCameraList({});
        window.setStatus("No cameras found. Connect a camera and restart.");
        return;
    }

    std::vector<std::string> names;
    for (auto& cam : g_cameras) {
        names.push_back(cam.name + " (" + cam.portName + ")");
    }
    window.setCameraList(names);
    window.setStatus("Found " + std::to_string(g_cameras.size()) + " camera(s). Select and click Connect.");
}

// ---------------------------------------------------------------------------
// WinMain
// ---------------------------------------------------------------------------
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE, LPSTR, int) {
    // Allocate console so we can see real-time terminal logs
    AllocConsole();
    FILE* fp;
    freopen_s(&fp, "CONOUT$", "w", stdout);
    freopen_s(&fp, "CONOUT$", "w", stderr);

    // Create main window
    MainWindow window;
    if (!window.create(hInstance, "Canon Camera Control")) {
        MessageBoxA(NULL, "Failed to create window", "Error", MB_OK | MB_ICONERROR);
        return 1;
    }

    // Initialize SDK
    auto result = g_facade.initialize();
    if (!result.ok()) {
        MessageBoxA(NULL, ("SDK init failed: " + result.message).c_str(),
                    "Error", MB_OK | MB_ICONERROR);
        return 1;
    }

    // Set image save folder
    std::string imageFolder = getImageFolder();
    g_facade.setSaveDirectory(imageFolder + "/");

    // Create UI handler (bridges events → window)
    UIHandler uiHandler(window, g_facade);
    g_facade.setCallback(&uiHandler);

    // Set up log callback → status bar
    g_facade.setLogCallback([&window](LogLevel level, const std::string& msg) {
        if (level >= LogLevel::Info) {
            window.setStatus(msg);
        }
    });

    // Discover cameras
    refreshCameraList(window);

    // -----------------------------------------------------------------------
    // Wire up button actions
    // -----------------------------------------------------------------------
    auto& actions = window.actions();

    actions.onConnect = [&]() {
        int idx = window.selectedCameraIndex();
        if (idx < 0 || idx >= (int)g_cameras.size()) {
            window.setStatus("No camera selected");
            return;
        }

        window.setStatus("Connecting...");

        // Connect on background thread
        std::thread([&, idx]() {
            ComThreadGuard comGuard;
            auto r = g_facade.connect(g_cameras[idx], SaveTarget::Host);
            if (!r.ok()) {
                window.setStatus("Connect failed: " + r.message);
            }
        }).detach();
    };

    actions.onDisconnect = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.stopLiveViewStreaming();
            g_facade.stopLiveView();
            g_facade.disconnect();
        }).detach();
    };

    actions.onTakePicture = [&]() {
        window.setStatus("Taking picture...");
        std::thread([&]() {
            ComThreadGuard comGuard;
            auto r = g_facade.takePicture();
            if (!r.ok()) window.setStatus("Take picture failed: " + r.message);
        }).detach();
    };

    actions.onTakePictureNoAF = [&]() {
        window.setStatus("Taking picture (no AF)...");
        std::thread([&]() {
            ComThreadGuard comGuard;
            auto r = g_facade.takePictureNoAF();
            if (!r.ok()) window.setStatus("Take picture failed: " + r.message);
        }).detach();
    };

    actions.onStartLiveView = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            auto r = g_facade.startLiveView();
            if (r.ok()) {
                g_facade.startLiveViewStreaming();
                window.setStatus("Live View streaming...");
            } else {
                window.setStatus("Start LV failed: " + r.message);
            }
        }).detach();
    };

    actions.onStopLiveView = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.stopLiveViewStreaming();
            g_facade.stopLiveView();
        }).detach();
    };

    actions.onFocusNear = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.driveLens(FocusDrive::Near2);
        }).detach();
    };

    actions.onFocusFar = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.driveLens(FocusDrive::Far2);
        }).detach();
    };

    actions.onAFOn = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.liveViewAFStart();
        }).detach();
    };

    actions.onAFOff = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.liveViewAFStop();
        }).detach();
    };

    actions.onZoomFit = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.setLiveViewZoom(kEdsEvfZoom_Fit);
        }).detach();
    };

    actions.onZoom5x = [&]() {
        std::thread([&]() {
            ComThreadGuard comGuard;
            g_facade.setLiveViewZoom(kEdsEvfZoom_x5);
        }).detach();
    };

    actions.onPropertySelected = [&](int comboId, int, EdsInt32 value) {
        EdsPropertyID propId = 0;
        switch (comboId) {
        case ID_COMBO_ISO:      propId = kEdsPropID_ISOSpeed; break;
        case ID_COMBO_AV:       propId = kEdsPropID_Av; break;
        case ID_COMBO_TV:       propId = kEdsPropID_Tv; break;
        case ID_COMBO_WB:       propId = kEdsPropID_WhiteBalance; break;
        case ID_COMBO_QUALITY:  propId = kEdsPropID_ImageQuality; break;
        case ID_COMBO_METERING: propId = kEdsPropID_MeteringMode; break;
        default: return;
        }

        std::thread([&, propId, value]() {
            ComThreadGuard comGuard;
            g_facade.setProperty(propId, static_cast<EdsUInt32>(value));
        }).detach();
    };

    // -----------------------------------------------------------------------
    // Run message loop
    // -----------------------------------------------------------------------
    int exitCode = window.run();

    // -----------------------------------------------------------------------
    // Cleanup
    // -----------------------------------------------------------------------
    g_facade.shutdown();
    CameraManager::releaseAll(g_cameras);

    return exitCode;
}
