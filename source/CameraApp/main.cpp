/*=============================================================================
 * main.cpp - Demo application using the CameraApp framework
 *
 * Purpose: Demonstrates how to use CameraFacade to:
 *          1. Discover and connect to a camera
 *          2. Read/set camera properties
 *          3. Take photos with auto-download
 *          4. Stream Live View frames
 *          5. Handle errors and disconnection
 *
 * Build: Link against EDSDK.lib
 *============================================================================*/

#include "Interface/CameraFacade.h"

#include <iostream>
#include <string>
#include <thread>
#include <chrono>
#include <atomic>

using namespace CameraApp;

// ===========================================================================
// Example ICameraCallback implementation for console output
// ===========================================================================
class ConsoleCameraHandler : public ICameraCallback {
public:
    void onCameraConnected(const std::string& name) override {
        std::cout << "[CONNECTED] " << name << std::endl;
    }

    void onCameraDisconnected() override {
        std::cout << "[DISCONNECTED]" << std::endl;
    }

    void onPropertyChanged(EdsPropertyID propId, EdsUInt32 value) override {
        std::cout << "[PROPERTY] ID=0x" << std::hex << propId
                  << " Value=0x" << value << std::dec << std::endl;
    }

    void onPropertyDescChanged(EdsPropertyID propId,
                                const PropertyDescriptor& desc) override {
        std::cout << "[PROP_DESC] ID=0x" << std::hex << propId
                  << " (" << std::dec << desc.values.size()
                  << " valid values)" << std::endl;
    }

    void onDownloadProgress(const std::string& fileName,
                            EdsUInt32 percent) override {
        std::cout << "\r[DOWNLOAD] " << fileName
                  << " " << percent << "%" << std::flush;
    }

    void onFileDownloaded(const DownloadedFile& file) override {
        std::cout << "\n[SAVED] " << file.fileName << std::endl;
    }

    void onCaptureError(EdsError error, const std::string& message) override {
        std::cout << "[CAPTURE ERROR] " << message << std::endl;
    }

    void onLiveViewFrame(const uint8_t* jpegData, size_t dataSize,
                          const LiveViewFrame& metadata) override {
        frameCount++;
        if (frameCount % 30 == 0) {
            std::cout << "[LV] Frame #" << frameCount
                      << " (" << dataSize << " bytes)"
                      << " Zoom=" << metadata.zoom << std::endl;
        }
    }

    void onLiveViewStateChanged(bool active) override {
        std::cout << "[LIVEVIEW] " << (active ? "Started" : "Stopped")
                  << std::endl;
    }

    void onError(const std::string& message) override {
        std::cout << "[ERROR] " << message << std::endl;
    }

    void onStatusMessage(const std::string& message) override {
        std::cout << "[STATUS] " << message << std::endl;
    }

    int frameCount = 0;
};

// ===========================================================================
// Helper: print menu
// ===========================================================================
void printMenu() {
    std::cout << "\n===== Camera Control =====\n"
              << "  1. Take Picture (with AF)\n"
              << "  2. Take Picture (no AF)\n"
              << "  3. Start Live View\n"
              << "  4. Stop Live View\n"
              << "  5. Start LV Streaming\n"
              << "  6. Stop LV Streaming\n"
              << "  7. Focus Near\n"
              << "  8. Focus Far\n"
              << "  9. Show Camera Info\n"
              << " 10. Set ISO\n"
              << " 11. Set Aperture\n"
              << " 12. Set Shutter Speed\n"
              << "  0. Disconnect & Exit\n"
              << "==========================\n"
              << "> ";
}

// ===========================================================================
// Helper: display valid values and let user choose
// ===========================================================================
bool selectPropertyValue(CameraFacade& facade, EdsPropertyID propId,
                          const std::string& label) {
    PropertyDescriptor desc;
    auto result = facade.getPropertyDescriptor(propId, desc);
    if (!result.ok() || desc.isEmpty()) {
        std::cout << "Cannot get valid values for " << label << std::endl;
        return false;
    }

    std::cout << "Available " << label << " values:" << std::endl;
    for (size_t i = 0; i < desc.values.size(); ++i) {
        std::cout << "  [" << i << "] 0x" << std::hex
                  << desc.values[i] << std::dec << std::endl;
    }
    std::cout << "Select index: ";

    int idx;
    std::cin >> idx;
    if (idx < 0 || idx >= static_cast<int>(desc.values.size())) {
        std::cout << "Invalid selection." << std::endl;
        return false;
    }

    result = facade.setProperty(propId, static_cast<EdsUInt32>(desc.values[idx]));
    if (result.ok()) {
        std::cout << label << " set successfully." << std::endl;
    } else {
        std::cout << "Failed to set " << label << ": " << result.message << std::endl;
    }
    return result.ok();
}

// ===========================================================================
// Main
// ===========================================================================
int main() {
    // Setup
    CameraFacade facade;
    ConsoleCameraHandler handler;

    facade.setCallback(&handler);
    facade.setLogCallback([](LogLevel level, const std::string& msg) {
        const char* prefix[] = { "DBG", "INF", "WRN", "ERR" };
        std::cout << "[" << prefix[static_cast<int>(level)] << "] "
                  << msg << std::endl;
    });

    // Initialize SDK
    auto result = facade.initialize();
    if (!result.ok()) {
        std::cerr << "Failed to initialize SDK: " << result.message << std::endl;
        return 1;
    }

    // Discover cameras
    std::vector<CameraInfo> cameras;
    result = facade.enumerateCameras(cameras);
    if (!result.ok() || cameras.empty()) {
        std::cout << "No cameras found. Please connect a Canon camera and retry."
                  << std::endl;
        facade.shutdown();
        return 1;
    }

    // Display camera list
    std::cout << "\nDetected cameras:" << std::endl;
    for (size_t i = 0; i < cameras.size(); ++i) {
        std::cout << "  [" << i << "] " << cameras[i].name
                  << " (" << cameras[i].portName << ")" << std::endl;
    }

    // Select camera bypass
    int camIdx = 0;
    std::cout << "Auto-selecting camera [0]" << std::endl;

    // Connect
    facade.setSaveDirectory("./captured/");
    result = facade.connect(cameras[camIdx], SaveTarget::Host);
    if (!result.ok()) {
        std::cerr << "Failed to connect: " << result.message << std::endl;
        CameraManager::releaseAll(cameras);
        facade.shutdown();
        return 1;
    }

    // Automated Test Loop
    std::cout << "\n--- AUTOMATED TEST SEQUENCE STARTED ---\n";
    std::cout << "1. Checking connection..." << std::endl;
    std::this_thread::sleep_for(std::chrono::seconds(1));

    std::cout << "\n2. Starting Live View..." << std::endl;
    facade.startLiveView();
    facade.startLiveViewStreaming();
    std::this_thread::sleep_for(std::chrono::seconds(4));

    std::cout << "\n3. Taking Picture..." << std::endl;
    facade.takePicture();
    
    // Wait for download to complete
    std::this_thread::sleep_for(std::chrono::seconds(5));

    std::cout << "\n4. Stopping Live View..." << std::endl;
    facade.stopLiveViewStreaming();
    facade.stopLiveView();
    std::this_thread::sleep_for(std::chrono::seconds(1));

    std::cout << "\n5. Disconnecting..." << std::endl;
    std::cout << "--- AUTOMATED TEST SEQUENCE FINISHED ---\n";

    // Cleanup
    facade.disconnect();
    CameraManager::releaseAll(cameras);
    facade.shutdown();

    std::cout << "Goodbye!" << std::endl;
    return 0;
}
