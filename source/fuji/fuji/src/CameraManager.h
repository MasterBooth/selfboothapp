// CameraManager.h -- owns the global SDK session and camera enumeration.
//
// Responsibilities:
//   * Load XAPI.dll (FujiSdkLibrary)
//   * XSDK_Init / XSDK_Exit  (global, once per process)
//   * XSDK_Detect over USB (and optionally Wi-Fi)
//   * XSDK_OpenEx -> hand a ready FujiCamera (as ICamera) to the app
//
// In the multi-vendor design this becomes the place that decides WHICH concrete
// ICamera to build (FujiCamera / CanonCamera / ...). Here we implement Fuji.
#pragma once

#include "FujiSdkLibrary.h"
#include "ICamera.h"
#include <memory>
#include <string>
#include <vector>

class CameraManager {
public:
    CameraManager() = default;
    ~CameraManager();

    // dllPath: full path to XAPI.dll. Calls XSDK_Init on success.
    bool initialize(const std::wstring& dllPath);
    void shutdown();

    // Returns model strings for every camera the SDK can see right now.
    std::vector<std::string> detect(long iface = XSDK_DSC_IF_USB);

    // Opens ENUM index `index` (as in "ENUM:0"). Returns nullptr on failure.
    std::unique_ptr<ICamera> open(int index = 0);

    FujiSdkLibrary& lib() { return m_lib; }

private:
    FujiSdkLibrary m_lib;
    bool           m_initialized = false;
};
