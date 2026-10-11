#pragma once
/*=============================================================================
 * CameraBackend.h — Camera SDK selection
 *
 * Build options (CMake -D flag):
 *
 *   USE_DUAL_SDK=ON   (recommended)
 *     Both Canon EDSDK and Sony Camera Remote SDK are compiled in.
 *     On initialize(), two threads run in parallel — one per SDK.
 *     Whichever detects a connected camera is activated (Canon preferred).
 *
 *   USE_SONY_SDK=ON
 *     Sony-only at compile time (legacy, single SDK).
 *
 *   (default / USE_SONY_SDK=OFF)
 *     Canon EDSDK only at compile time (single SDK).
 *
 * Usage in CameraController.cpp:
 *   ICameraSDK& cam = CameraBackend::camera();
 *   cam.initialize();   // triggers parallel detection in dual-SDK mode
 *=============================================================================*/

#include <cstdint>
#include "ICameraSDK.h"

#if defined(USE_DUAL_SDK)
    #include "DualSDKController.h"
    namespace CameraBackend {
        inline ICameraSDK& camera() { return DualSDKController::instance(); }
    }
#elif defined(USE_SONY_SDK)
    #include "SonySDKAdapter.h"
    namespace CameraBackend {
        inline ICameraSDK& camera() { return SonySDKAdapter::instance(); }
    }
#else
    // Default: Canon EDSDK
    #include "CanonSDKAdapter.h"
    namespace CameraBackend {
        inline ICameraSDK& camera() { return CanonSDKAdapter::instance(); }
    }
#endif

// ---------------------------------------------------------------------------
// Common aliases & Canon EdsPropertyID constants (accepted by all adapters)
// ---------------------------------------------------------------------------
namespace CameraBackend {
    using CameraInfo = ICameraSDK::CameraInfo;

    constexpr uint32_t PropWB        = 0x00000106;   // kEdsPropID_WhiteBalance
    constexpr uint32_t PropColorTemp = 0x00000107;   // kEdsPropID_ColorTemperature
    constexpr uint32_t PropISO       = 0x00000402;   // kEdsPropID_ISOSpeed
    constexpr uint32_t PropAv        = 0x00000405;   // kEdsPropID_Av
    constexpr uint32_t PropTv        = 0x00000406;   // kEdsPropID_Tv
    constexpr uint32_t PropEV        = 0x00000407;   // kEdsPropID_ExposureCompensation
}
