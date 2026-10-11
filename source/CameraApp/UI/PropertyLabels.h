#pragma once

/*=============================================================================
 * PropertyLabels.h - Human-readable labels for EDSDK property values
 *
 * Purpose: Maps EDSDK numeric property values to display strings
 *          for ISO, Aperture, Shutter Speed, White Balance, etc.
 *============================================================================*/

#include "EDSDK.h"
#include "EDSDKTypes.h"
#include <string>
#include <map>

namespace CameraApp {

// ---------------------------------------------------------------------------
// ISO labels
// ---------------------------------------------------------------------------
inline const std::map<EdsInt32, std::string>& isoLabels() {
    static const std::map<EdsInt32, std::string> m = {
        {0x00, "Auto"}, {0x28, "6"}, {0x30, "12"}, {0x38, "25"},
        {0x40, "50"}, {0x48, "100"}, {0x4B, "125"}, {0x4D, "160"},
        {0x50, "200"}, {0x53, "250"}, {0x55, "320"}, {0x58, "400"},
        {0x5B, "500"}, {0x5D, "640"}, {0x60, "800"}, {0x63, "1000"},
        {0x65, "1250"}, {0x68, "1600"}, {0x6B, "2000"}, {0x6D, "2500"},
        {0x70, "3200"}, {0x73, "4000"}, {0x75, "5000"}, {0x78, "6400"},
        {0x7B, "8000"}, {0x7D, "10000"}, {0x80, "12800"}, {0x83, "16000"},
        {0x85, "20000"}, {0x88, "25600"}, {0x8B, "32000"}, {0x8D, "40000"},
        {0x90, "51200"}, {0x98, "102400"}, {0xA0, "204800"},
        {0xA8, "409600"}, {0xB0, "819200"},
    };
    return m;
}

// ---------------------------------------------------------------------------
// Aperture (Av) labels
// ---------------------------------------------------------------------------
inline const std::map<EdsInt32, std::string>& avLabels() {
    static const std::map<EdsInt32, std::string> m = {
        {0x08, "f/1.0"}, {0x0B, "f/1.1"}, {0x0D, "f/1.2"}, {0x10, "f/1.4"},
        {0x13, "f/1.6"}, {0x15, "f/1.8"}, {0x18, "f/2.0"}, {0x1B, "f/2.2"},
        {0x1D, "f/2.5"}, {0x20, "f/2.8"}, {0x23, "f/3.2"}, {0x25, "f/3.5"},
        {0x28, "f/4.0"}, {0x2B, "f/4.5"}, {0x2D, "f/5.0"}, {0x30, "f/5.6"},
        {0x33, "f/6.3"}, {0x35, "f/7.1"}, {0x38, "f/8.0"}, {0x3B, "f/9.0"},
        {0x3D, "f/10"}, {0x40, "f/11"}, {0x43, "f/13"}, {0x45, "f/14"},
        {0x48, "f/16"}, {0x4B, "f/18"}, {0x4D, "f/20"}, {0x50, "f/22"},
        {0x53, "f/25"}, {0x55, "f/29"}, {0x58, "f/32"}, {0x5B, "f/36"},
        {0x5D, "f/40"}, {0x60, "f/45"}, {0x63, "f/51"}, {0x65, "f/57"},
        {0x68, "f/64"}, {0x6B, "f/72"}, {0x6D, "f/81"}, {0x70, "f/91"},
    };
    return m;
}

// ---------------------------------------------------------------------------
// Shutter speed (Tv) labels
// ---------------------------------------------------------------------------
inline const std::map<EdsInt32, std::string>& tvLabels() {
    static const std::map<EdsInt32, std::string> m = {
        {0x0C, "Bulb"}, {0x10, "30\""}, {0x13, "25\""}, {0x14, "20\""},
        {0x15, "20\""}, {0x18, "15\""}, {0x1B, "13\""}, {0x1C, "10\""},
        {0x1D, "10\""}, {0x20, "8\""}, {0x23, "6\""}, {0x24, "6\""},
        {0x25, "5\""}, {0x28, "4\""}, {0x2B, "3.2\""}, {0x2C, "3\""},
        {0x2D, "2.5\""}, {0x30, "2\""}, {0x33, "1.6\""}, {0x34, "1.5\""},
        {0x35, "1.3\""}, {0x38, "1\""}, {0x3B, "0.8\""}, {0x3C, "0.7\""},
        {0x3D, "0.6\""}, {0x40, "0.5\""}, {0x43, "0.4\""}, {0x44, "0.3\""},
        {0x45, "0.3\""}, {0x48, "1/4"}, {0x4B, "1/5"}, {0x4C, "1/6"},
        {0x4D, "1/6"}, {0x50, "1/8"}, {0x53, "1/10"}, {0x54, "1/10"},
        {0x55, "1/13"}, {0x58, "1/15"}, {0x5B, "1/20"}, {0x5C, "1/20"},
        {0x5D, "1/25"}, {0x60, "1/30"}, {0x63, "1/40"}, {0x64, "1/45"},
        {0x65, "1/50"}, {0x68, "1/60"}, {0x6B, "1/80"}, {0x6C, "1/90"},
        {0x6D, "1/100"}, {0x70, "1/125"}, {0x73, "1/160"}, {0x74, "1/180"},
        {0x75, "1/200"}, {0x78, "1/250"}, {0x7B, "1/320"}, {0x7C, "1/350"},
        {0x7D, "1/400"}, {0x80, "1/500"}, {0x83, "1/640"}, {0x84, "1/750"},
        {0x85, "1/800"}, {0x88, "1/1000"}, {0x8B, "1/1250"}, {0x8C, "1/1500"},
        {0x8D, "1/1600"}, {0x90, "1/2000"}, {0x93, "1/2500"}, {0x94, "1/3000"},
        {0x95, "1/3200"}, {0x98, "1/4000"}, {0x9B, "1/5000"}, {0x9C, "1/6000"},
        {0x9D, "1/6400"}, {0xA0, "1/8000"}, {0xA3, "1/10000"},
        {0xA5, "1/12800"}, {0xA8, "1/16000"},
    };
    return m;
}

// ---------------------------------------------------------------------------
// White Balance labels
// ---------------------------------------------------------------------------
inline const std::map<EdsInt32, std::string>& wbLabels() {
    static const std::map<EdsInt32, std::string> m = {
        {0, "Auto"}, {1, "Daylight"}, {2, "Cloudy"}, {3, "Tungsten"},
        {4, "Fluorescent"}, {5, "Flash"}, {6, "Manual"}, {8, "Shade"},
        {9, "Color Temp"}, {10, "Custom PC-1"}, {11, "Custom PC-2"},
        {12, "Custom PC-3"}, {15, "Custom PC-4"}, {16, "Custom PC-5"},
        {23, "Auto (White)"},
    };
    return m;
}

// ---------------------------------------------------------------------------
// Metering mode labels
// ---------------------------------------------------------------------------
inline const std::map<EdsInt32, std::string>& meteringLabels() {
    static const std::map<EdsInt32, std::string> m = {
        {1, "Spot"}, {3, "Evaluative"}, {4, "Partial"}, {5, "Center-weighted"},
    };
    return m;
}

// ---------------------------------------------------------------------------
// Image quality labels (simplified)
// ---------------------------------------------------------------------------
inline const std::map<EdsInt32, std::string>& qualityLabels() {
    static const std::map<EdsInt32, std::string> m = {
        {0x0010FF0F, "Large Fine JPEG"},
        {0x0110FF0F, "Large Normal JPEG"},
        {0x0510FF0F, "Large Super Fine JPEG"},
        {0x0020FF0F, "Middle Fine JPEG"},
        {0x0120FF0F, "Middle Normal JPEG"},
        {0x0030FF0F, "Small Fine JPEG"},
        {0x0130FF0F, "Small Normal JPEG"},
        {0x0064FF0F, "RAW"},
        {0x00640010, "RAW + Large Fine"},
        {0x00640110, "RAW + Large Normal"},
        {0x00640510, "RAW + Large SF"},
        {0x0264FF0F, "CRAW"},
        {0x02640010, "CRAW + Large Fine"},
        {0x02640110, "CRAW + Large Normal"},
        {0x02640510, "CRAW + Large SF"},
    };
    return m;
}

// ---------------------------------------------------------------------------
// Generic lookup helper
// ---------------------------------------------------------------------------
inline std::string labelForValue(const std::map<EdsInt32, std::string>& table,
                                  EdsInt32 value) {
    auto it = table.find(value);
    if (it != table.end()) return it->second;

    char buf[32];
    snprintf(buf, sizeof(buf), "0x%X", (unsigned)value);
    return buf;
}

} // namespace CameraApp
