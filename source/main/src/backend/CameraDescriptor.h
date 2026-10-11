#pragma once
/*=============================================================================
 * CameraDescriptor.h — Unified camera identity (brand-agnostic)
 *
 * Produced by CanonService / SonyService / NikonService / FujiService during detection.
 * Consumed by DualSDKController for selection and connection.
 *=============================================================================*/

#include <string>

struct CameraDescriptor {
    enum class Brand { Unknown, Canon, Sony, Nikon, Fuji };

    Brand       brand    = Brand::Unknown;
    std::string name;       // Display name, e.g. "Canon EOS R5"
    std::string portName;   // USB port or IP address
    int         index = -1; // Index within the brand's own detected list

    bool isValid() const { return brand != Brand::Unknown && index >= 0; }

    std::string brandName() const {
        switch (brand) {
        case Brand::Canon: return "Canon";
        case Brand::Sony:  return "Sony";
        case Brand::Nikon: return "Nikon";
        case Brand::Fuji:  return "Fuji";
        default:           return "Unknown";
        }
    }
};
