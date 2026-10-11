// PropertyManager.h -- typed access to camera properties.
//
// Two families exist in the SDK:
//   1. Dedicated exports: XSDK_SetSensitivity / XSDK_GetShutterSpeed / ...
//   2. Model-dependent interface: XSDK_{Cap,Set,Get}Prop(handle, API_CODE, param, ...)
//      used for film simulation, focus mode, image quality, live-view knobs, etc.
//
// Enumerable properties follow a two-pass "Cap" pattern (see cap_exposure_bias
// in the Python sample): call once with a count pointer and a NULL value buffer
// to learn N, allocate an N-long array, call again to fill it.
//
// Every method takes the shared SDK lock and null-checks both the handle and the
// resolved entry point, so calling an unsupported control fails cleanly (returns
// false / empty) instead of dereferencing a null function pointer.
#pragma once

#include "CameraContext.h"
#include <vector>

class PropertyManager {
public:
    explicit PropertyManager(CameraContext* ctx) : m_ctx(ctx) {}

    // --- ISO / sensitivity (dedicated export) ---
    bool setIso(long iso);
    bool getIso(long& iso);
    std::vector<long> capIso();          // allowed ISO values (incl. AUTO codes)

    // --- Shutter speed (dedicated export; bulb flag reported separately) ---
    bool setShutterSpeed(long code, long bulb = 0);
    bool getShutterSpeed(long& code, long& bulb);
    std::vector<long> capShutterSpeed();

    // --- Aperture, F-number * 100 (dedicated export) ---
    bool setAperture(long fnumberX100);
    bool getAperture(long& fnumberX100);
    std::vector<long> capAperture();     // enumerated at current zoom position

    // --- Exposure bias, 1/3 EV steps encoded x/... (dedicated export) ---
    bool setExposureBias(long code);
    bool getExposureBias(long& code);
    std::vector<long> capExposureBias();

    // --- Film Simulation (model-dependent SetProp/GetProp) ---
    bool setFilmSimulation(long sim);    // SDK_FILMSIMULATION_*
    bool getFilmSimulation(long& sim);

    // --- Image Quality (model-dependent) ---
    std::vector<long> capImageQuality();
    bool setImageQuality(long q);        // SDK_IMAGEQUALITY_*
    bool getImageQuality(long& q);

    // --- Image Size (model-dependent) ---
    std::vector<long> capImageSize();
    bool setImageSize(long size);        // SDK_IMAGESIZE_*
    bool getImageSize(long& size);

    // --- White balance mode (model-dependent) ---
    bool setWhiteBalance(long wb);       // SDK_WB_*
    bool getWhiteBalance(long& wb);

private:
    CameraContext* m_ctx;
    // Generic model-dependent enumerator (API_CODE_Cap*): returns allowed values.
    std::vector<long> capProp(long apiCapCode);
};
