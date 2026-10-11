#pragma once

/*=============================================================================
 * CameraManager.h - Camera discovery and enumeration
 *
 * Layer: Camera
 * Purpose: Discovers connected Canon cameras via EDSDK and returns
 *          a list of CameraInfo objects for the application to select from.
 *============================================================================*/

#include "../Core/Types.h"
#include "../Core/ErrorHandler.h"
#include "../Core/EDSDKContext.h"

#include <vector>

namespace CameraApp {

class CameraManager {
public:
    // -----------------------------------------------------------------------
    // Enumerate all connected cameras
    // Returns a list of CameraInfo with camera references.
    // Caller must eventually EdsRelease each ref when done.
    // -----------------------------------------------------------------------
    Result enumerate(std::vector<CameraInfo>& outCameras) {
        outCameras.clear();

        // Ensure SDK is initialized
        auto result = EDSDKContext::instance().initialize();
        if (!result.ok()) return result;

        // Get camera list
        EdsCameraListRef cameraList = nullptr;
        EdsError err = EdsGetCameraList(&cameraList);
        if (err != EDS_ERR_OK) {
            return ErrorHandler::check(err, "EdsGetCameraList");
        }

        // Count cameras
        EdsUInt32 count = 0;
        err = EdsGetChildCount(cameraList, &count);
        if (err != EDS_ERR_OK) {
            EdsRelease(cameraList);
            return ErrorHandler::check(err, "EdsGetChildCount(cameraList)");
        }

        if (count == 0) {
            ErrorHandler::log(LogLevel::Warning, "No cameras detected");
            EdsRelease(cameraList);
            return Result::Ok();
        }

        // Enumerate each camera
        for (EdsUInt32 i = 0; i < count; ++i) {
            EdsCameraRef cameraRef = nullptr;
            err = EdsGetChildAtIndex(cameraList, i, &cameraRef);
            if (err != EDS_ERR_OK) continue;

            EdsDeviceInfo deviceInfo;
            err = EdsGetDeviceInfo(cameraRef, &deviceInfo);
            if (err != EDS_ERR_OK) {
                EdsRelease(cameraRef);
                continue;
            }

            CameraInfo info;
            info.name          = deviceInfo.szDeviceDescription;
            info.portName      = deviceInfo.szPortName;
            info.deviceSubType = deviceInfo.deviceSubType;
            info.ref           = cameraRef;  // Caller owns this reference

            outCameras.push_back(std::move(info));
        }

        EdsRelease(cameraList);

        ErrorHandler::log(LogLevel::Info,
            "Found " + std::to_string(outCameras.size()) + " camera(s)");
        return Result::Ok();
    }

    // -----------------------------------------------------------------------
    // Release all camera references in a vector
    // -----------------------------------------------------------------------
    static void releaseAll(std::vector<CameraInfo>& cameras) {
        for (auto& cam : cameras) {
            if (cam.ref) {
                EdsRelease(cam.ref);
                cam.ref = nullptr;
            }
        }
        cameras.clear();
    }
};

} // namespace CameraApp
