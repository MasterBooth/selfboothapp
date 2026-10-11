#pragma once

#include "XsdkApi.h"

enum class MediaRecordMode {
    CameraDefault,
    RawJpeg,
    Jpeg,
    Raw,
    Off,
};

struct RuntimeConfig {
    bool autoConnectOnStart = true;
    bool autoStartLiveView = true;
    bool restorePcPriorityOnLiveStop = true;
    MediaRecordMode mediaRecordMode = MediaRecordMode::CameraDefault;
};

inline RuntimeConfig& runtimeConfig() {
    static RuntimeConfig config;
    return config;
}

inline const char* mediaRecordModeName(MediaRecordMode mode) {
    switch (mode) {
        case MediaRecordMode::CameraDefault: return "camera";
        case MediaRecordMode::RawJpeg:       return "rawjpeg";
        case MediaRecordMode::Jpeg:          return "jpeg";
        case MediaRecordMode::Raw:           return "raw";
        case MediaRecordMode::Off:           return "off";
    }
    return "camera";
}

inline bool mediaRecordSdkValue(MediaRecordMode mode, long& value) {
    switch (mode) {
        case MediaRecordMode::RawJpeg:
            value = XSDK_MEDIAREC_RAWJPEG;
            return true;
        case MediaRecordMode::Jpeg:
            value = XSDK_MEDIAREC_JPEG;
            return true;
        case MediaRecordMode::Raw:
            value = XSDK_MEDIAREC_RAW;
            return true;
        case MediaRecordMode::Off:
            value = XSDK_MEDIAREC_OFF;
            return true;
        case MediaRecordMode::CameraDefault:
            return false;
    }
    return false;
}
