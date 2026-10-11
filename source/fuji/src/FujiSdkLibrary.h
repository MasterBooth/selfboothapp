// FujiSdkLibrary.h -- owns the XAPI.dll module and all resolved entry points.
//
// One instance per process. XSDK_Init/XSDK_Exit are global (not per-handle), so
// this class also brackets the global SDK session.
#pragma once

#include "XsdkApi.h"
#include <string>

class FujiSdkLibrary {
public:
    FujiSdkLibrary() = default;
    ~FujiSdkLibrary();

    // Loads XAPI.dll from `dllPath` and resolves every required export.
    // Returns false and logs if the DLL is missing or an export is absent
    // (which usually means an SDK-version mismatch).
    bool load(const std::wstring& dllPath);
    void unload();
    bool loaded() const { return m_module != nullptr; }

    HMODULE module() const { return m_module; }

    // Resolved entry points (public for the thin FujiCamera wrapper).
    PFN_XSDK_Init              Init              = nullptr;
    PFN_XSDK_Exit              Exit              = nullptr;
    PFN_XSDK_Detect            Detect            = nullptr;
    PFN_XSDK_Append            Append            = nullptr;
    PFN_XSDK_OpenEx            OpenEx            = nullptr;
    PFN_XSDK_Close             Close             = nullptr;
    PFN_XSDK_PowerOFF          PowerOFF          = nullptr;
    PFN_XSDK_GetErrorNumber    GetErrorNumber    = nullptr;
    PFN_XSDK_GetVersionString  GetVersionString  = nullptr;
    PFN_XSDK_GetErrorDetails   GetErrorDetails   = nullptr;
    PFN_XSDK_GetDeviceInfo     GetDeviceInfo     = nullptr;
    PFN_XSDK_GetFirmwareVersion GetFirmwareVersion = nullptr;
    PFN_XSDK_GetLensInfo       GetLensInfo       = nullptr;
    PFN_XSDK_CapPriorityMode   CapPriorityMode   = nullptr;
    PFN_XSDK_SetPriorityMode   SetPriorityMode   = nullptr;
    PFN_XSDK_GetPriorityMode   GetPriorityMode   = nullptr;
    PFN_XSDK_CapReleaseEx      CapReleaseEx      = nullptr;
    PFN_XSDK_ReleaseEx         ReleaseEx         = nullptr;
    PFN_XSDK_Release           Release           = nullptr;
    PFN_XSDK_GetReleaseStatus  GetReleaseStatus  = nullptr;
    PFN_XSDK_GetBufferCapacity GetBufferCapacity = nullptr;
    PFN_XSDK_ReadImageInfo     ReadImageInfo     = nullptr;
    PFN_XSDK_ReadPreview       ReadPreview       = nullptr;
    PFN_XSDK_ReadImage         ReadImage         = nullptr;
    PFN_XSDK_DeleteImage       DeleteImage       = nullptr;
    PFN_XSDK_SetMediaRecord    SetMediaRecord    = nullptr;
    PFN_XSDK_GetMediaRecord    GetMediaRecord    = nullptr;

    // Dedicated exposure/ISO exports. Cap* enumerate the values the body accepts.
    PFN_XSDK_CapSensitivity    CapSensitivity    = nullptr;
    PFN_XSDK_SetSensitivity    SetSensitivity    = nullptr;
    PFN_XSDK_GetSensitivity    GetSensitivity    = nullptr;
    PFN_XSDK_CapShutterSpeed   CapShutterSpeed   = nullptr;
    PFN_XSDK_SetShutterSpeed   SetShutterSpeed   = nullptr;
    PFN_XSDK_GetShutterSpeed   GetShutterSpeed   = nullptr;
    PFN_XSDK_CapAperture       CapAperture       = nullptr;
    PFN_XSDK_SetAperture       SetAperture       = nullptr;
    PFN_XSDK_GetAperture       GetAperture       = nullptr;
    PFN_XSDK_CapExposureBias   CapExposureBias   = nullptr;
    PFN_XSDK_SetExposureBias   SetExposureBias   = nullptr;
    PFN_XSDK_GetExposureBias   GetExposureBias   = nullptr;

    // Model-dependent interface (film simulation, WB, image quality, live view).
    PFN_XSDK_SetProp           SetProp           = nullptr;
    PFN_XSDK_GetProp           GetProp           = nullptr;
    PFN_XSDK_CapProp           CapProp           = nullptr;

private:
    HMODULE m_module = nullptr;
    // resolve(): required export -- failure aborts load().
    template <typename T> bool resolve(T& fn, const char* name);
    // resolveOpt(): optional export -- absence is logged but does not fail load,
    // so the engine still runs on older bodies that lack a given control.
    template <typename T> void resolveOpt(T& fn, const char* name);
};
