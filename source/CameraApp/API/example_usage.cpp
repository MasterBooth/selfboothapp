/*=============================================================================
 * example_usage.cpp - Simple example of using CameraController
 *
 * This example demonstrates the clean API for:
 * 1. Camera discovery
 * 2. Connection
 * 3. Setting parameters
 * 4. Taking photos
 * 5. Live view
 *
 * Compile with:
 *   cl /I. /I.. example_usage.cpp CameraController.cpp ../Interface/CameraFacade.cpp ...
 *=============================================================================*/

#include "CameraController.h"
#include <iostream>
#include <thread>
#include <chrono>

using namespace CameraApp;

// ============================================================================
// EXAMPLE 1: Simple Photo App
// ============================================================================

void example_simple_photo_app() {
    std::cout << "\n=== Example 1: Simple Photo App ===\n\n";

    auto& camera = CameraController::instance();

    // Initialize SDK
    if (!camera.initialize()) {
        std::cerr << "Failed to initialize SDK\n";
        return;
    }

    // Find cameras
    std::vector<CameraInfo> cameras;
    if (!camera.findCameras(cameras) || cameras.empty()) {
        std::cerr << "No cameras found\n";
        camera.shutdown();
        return;
    }

    std::cout << "Found " << cameras.size() << " camera(s)\n";
    for (size_t i = 0; i < cameras.size(); ++i) {
        std::cout << "  [" << i << "] " << cameras[i].name
                 << " (" << cameras[i].portName << ")\n";
    }

    // Connect to first camera
    std::cout << "\nConnecting to camera 0...\n";
    if (!camera.connectCamera(0)) {
        std::cerr << "Failed to connect: " << camera.getLastError() << "\n";
        camera.shutdown();
        return;
    }

    std::cout << "Connected to " << camera.getCameraModel() << "\n";

    // Configure camera
    std::cout << "\nSetting camera parameters...\n";
    camera.setSaveFolder("./photos/");
    camera.setISO(400);
    camera.setWhiteBalance(1);  // Daylight
    camera.setAutoDownload(true);

    // Take photos
    std::cout << "\nTaking 3 photos...\n";
    for (int i = 0; i < 3; ++i) {
        std::cout << "  Photo " << (i + 1) << "...";
        if (camera.takePhoto()) {
            std::cout << " OK - " << camera.getLastPhotoPath() << "\n";
        } else {
            std::cerr << " FAILED: " << camera.getLastError() << "\n";
        }
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }

    // Cleanup
    std::cout << "\nDisconnecting...\n";
    camera.disconnectCamera();
    camera.shutdown();

    std::cout << "\nDone!\n";
}

// ============================================================================
// EXAMPLE 2: Live View with Focus Control
// ============================================================================

void example_live_view() {
    std::cout << "\n=== Example 2: Live View with Focus Control ===\n\n";

    auto& camera = CameraController::instance();

    camera.initialize();

    std::vector<CameraInfo> cameras;
    if (!camera.findCameras(cameras) || cameras.empty()) {
        std::cerr << "No cameras found\n";
        return;
    }

    if (!camera.connectCamera(0)) {
        std::cerr << "Failed to connect\n";
        return;
    }

    // Start live view
    std::cout << "Starting live view...\n";
    if (!camera.startLiveView()) {
        std::cerr << "Failed to start live view: " << camera.getLastError() << "\n";
        camera.disconnectCamera();
        return;
    }

    std::cout << "Live view active. Press focus buttons...\n";
    std::cout << "  'n' = focus near\n";
    std::cout << "  'f' = focus far\n";
    std::cout << "  'a' = autofocus\n";
    std::cout << "  '5' = zoom 5x\n";
    std::cout << "  'q' = quit\n\n";

    // Simulate some focus operations
    if (camera.startLiveViewStreaming()) {
        std::cout << "Live view streaming started...\n";

        std::this_thread::sleep_for(std::chrono::seconds(2));

        // Drive lens near
        std::cout << "Focusing near...\n";
        if (!camera.driveLensNear()) {
            std::cerr << "Focus failed: " << camera.getLastError() << "\n";
        }

        std::this_thread::sleep_for(std::chrono::seconds(1));

        // Zoom 5x
        std::cout << "Zooming 5x...\n";
        if (!camera.setLiveViewZoom5x()) {
            std::cerr << "Zoom failed: " << camera.getLastError() << "\n";
        }

        std::this_thread::sleep_for(std::chrono::seconds(2));

        // Zoom fit
        std::cout << "Zooming to fit...\n";
        if (!camera.setLiveViewZoomFit()) {
            std::cerr << "Zoom failed: " << camera.getLastError() << "\n";
        }

        std::this_thread::sleep_for(std::chrono::seconds(2));

        // Stop streaming
        camera.stopLiveViewStreaming();
    }

    // Stop live view
    std::cout << "Stopping live view...\n";
    camera.stopLiveView();

    camera.disconnectCamera();
    camera.shutdown();

    std::cout << "Done!\n";
}

// ============================================================================
// EXAMPLE 3: Event-Driven Architecture
// ============================================================================

class MyEventListener : public ICameraEventListener {
public:
    void onCameraEvent(const CameraEvent& event) override {
        switch (event.type) {
        case CameraEventType::Connected:
            std::cout << "[EVENT] Camera connected: " << event.message << "\n";
            break;
        case CameraEventType::Disconnected:
            std::cout << "[EVENT] Camera disconnected\n";
            break;
        case CameraEventType::CaptureStarted:
            std::cout << "[EVENT] Capture started\n";
            break;
        case CameraEventType::CaptureCompleted:
            std::cout << "[EVENT] Capture completed: " << event.fileName << "\n";
            break;
        case CameraEventType::CaptureError:
            std::cout << "[EVENT] Capture error: " << event.message << "\n";
            break;
        case CameraEventType::LiveViewStarted:
            std::cout << "[EVENT] Live view started\n";
            break;
        case CameraEventType::LiveViewStopped:
            std::cout << "[EVENT] Live view stopped\n";
            break;
        case CameraEventType::LiveViewFrameReceived:
            // std::cout << "[EVENT] Live view frame received\n";
            break;  // Too verbose
        case CameraEventType::PropertyChanged:
            std::cout << "[EVENT] Property changed: 0x" << std::hex
                     << event.propertyId << " = " << std::dec
                     << event.propertyValue << "\n";
            break;
        case CameraEventType::DownloadProgress:
            std::cout << "[EVENT] Download progress: " << event.fileName
                     << " " << event.downloadPercent << "%\n";
            break;
        }
    }
};

void example_event_driven() {
    std::cout << "\n=== Example 3: Event-Driven Architecture ===\n\n";

    auto& camera = CameraController::instance();

    // Setup event listener
    MyEventListener listener;
    camera.addEventListener(&listener);

    // Setup logging
    camera.setLogCallback([](const std::string& msg) {
        std::cout << "[LOG] " << msg << "\n";
    });

    camera.initialize();

    std::vector<CameraInfo> cameras;
    if (!camera.findCameras(cameras) || cameras.empty()) {
        std::cerr << "No cameras found\n";
        return;
    }

    if (!camera.connectCamera(0)) {
        std::cerr << "Failed to connect\n";
        return;
    }

    // All operations now emit events that are handled by listener
    std::cout << "\nTaking photo with events...\n";
    camera.setISO(800);
    camera.takePhoto();

    // Wait for capture to complete
    std::this_thread::sleep_for(std::chrono::seconds(3));

    camera.disconnectCamera();
    camera.removeEventListener(&listener);
    camera.shutdown();

    std::cout << "\nDone!\n";
}

// ============================================================================
// EXAMPLE 4: Batch Parameter Setting
// ============================================================================

void example_batch_parameters() {
    std::cout << "\n=== Example 4: Batch Parameter Setting ===\n\n";

    auto& camera = CameraController::instance();

    camera.initialize();

    std::vector<CameraInfo> cameras;
    if (!camera.findCameras(cameras) || cameras.empty()) {
        std::cerr << "No cameras found\n";
        return;
    }

    if (!camera.connectCamera(0)) {
        std::cerr << "Failed to connect\n";
        return;
    }

    // Create parameter set
    CameraParameters params;
    params.iso = 400;
    params.shutterSpeed = "1/500";
    params.aperture = "f/5.6";
    params.whiteBalance = 1;           // Daylight
    params.meteringMode = 0;           // Evaluative
    params.imageQuality = 0;           // JPEG
    params.driveMode = 0;              // Single shot
    params.colorTemperature = 5200;    // Daylight

    std::cout << "Setting parameters batch...\n";
    if (camera.setParameters(params)) {
        std::cout << "Parameters set successfully\n";
    } else {
        std::cerr << "Failed to set parameters: " << camera.getLastError() << "\n";
    }

    // Read parameters back
    CameraParameters readParams;
    if (camera.getParameters(readParams)) {
        std::cout << "Current ISO: " << readParams.iso << "\n";
    }

    camera.disconnectCamera();
    camera.shutdown();

    std::cout << "Done!\n";
}

// ============================================================================
// MAIN - Select which example to run
// ============================================================================

int main(int argc, char* argv[]) {
    std::cout << "Camera Controller API Examples\n";
    std::cout << "==============================\n";

    if (argc > 1) {
        std::string example = argv[1];

        if (example == "1") {
            example_simple_photo_app();
        } else if (example == "2") {
            example_live_view();
        } else if (example == "3") {
            example_event_driven();
        } else if (example == "4") {
            example_batch_parameters();
        } else {
            std::cout << "Usage: example_usage.exe [1|2|3|4]\n";
            std::cout << "  1 = Simple photo app\n";
            std::cout << "  2 = Live view with focus control\n";
            std::cout << "  3 = Event-driven architecture\n";
            std::cout << "  4 = Batch parameter setting\n";
        }
    } else {
        // Run example 1 by default
        example_simple_photo_app();
    }

    return 0;
}
