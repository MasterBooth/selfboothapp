#include "FujiSdkLibrary.h"
#include "Logger.h"

static const char* TAG = "SdkLib";

FujiSdkLibrary::~FujiSdkLibrary() { unload(); }

template <typename T>
bool FujiSdkLibrary::resolve(T& fn, const char* name) {
    fn = reinterpret_cast<T>(::GetProcAddress(m_module, name));
    if (!fn) {
        Logger::instance().error(TAG, "missing export: %s", name);
        return false;
    }
    return true;
}

template <typename T>
void FujiSdkLibrary::resolveOpt(T& fn, const char* name) {
    fn = reinterpret_cast<T>(::GetProcAddress(m_module, name));
    if (!fn)
        Logger::instance().warn(TAG, "optional export absent: %s (control disabled)", name);
}

bool FujiSdkLibrary::load(const std::wstring& dllPath) {
    if (m_module) return true;

    // SetDllDirectory so the loader also finds the sibling transport/model DLLs
    // (FTLPTP.dll / FTLPTPIP.dll / FF00xxAPI.dll) that XAPI.dll depends on at
    // runtime. Only meaningful when dllPath carries a directory; for a bare
    // "XAPI.dll" the default search (exe dir + cwd) already covers the siblings,
    // and setting a bogus directory would BREAK that search.
    auto sep = dllPath.find_last_of(L"\\/");
    if (sep != std::wstring::npos)
        ::SetDllDirectoryW(dllPath.substr(0, sep).c_str());

    m_module = ::LoadLibraryW(dllPath.c_str());
    if (!m_module) {
        Logger::instance().error(TAG, "LoadLibrary failed (err=%lu)", ::GetLastError());
        return false;
    }

    bool ok = true;
    ok &= resolve(Init,               "XSDK_Init");
    ok &= resolve(Exit,               "XSDK_Exit");
    ok &= resolve(Detect,             "XSDK_Detect");
    ok &= resolve(Append,             "XSDK_Append");
    ok &= resolve(OpenEx,             "XSDK_OpenEx");
    ok &= resolve(Close,              "XSDK_Close");
    ok &= resolve(PowerOFF,           "XSDK_PowerOFF");
    ok &= resolve(GetErrorNumber,     "XSDK_GetErrorNumber");
    ok &= resolve(GetVersionString,   "XSDK_GetVersionString");
    ok &= resolve(GetErrorDetails,    "XSDK_GetErrorDetails");
    ok &= resolve(GetDeviceInfo,      "XSDK_GetDeviceInfo");
    ok &= resolve(GetFirmwareVersion, "XSDK_GetFirmwareVersion");
    ok &= resolve(GetLensInfo,        "XSDK_GetLensInfo");
    ok &= resolve(CapPriorityMode,    "XSDK_CapPriorityMode");
    ok &= resolve(SetPriorityMode,    "XSDK_SetPriorityMode");
    ok &= resolve(GetPriorityMode,    "XSDK_GetPriorityMode");
    ok &= resolve(CapReleaseEx,       "XSDK_CapReleaseEx");
    ok &= resolve(ReleaseEx,          "XSDK_ReleaseEx");
    ok &= resolve(Release,            "XSDK_Release");
    ok &= resolve(GetReleaseStatus,   "XSDK_GetReleaseStatus");
    ok &= resolve(GetBufferCapacity,  "XSDK_GetBufferCapacity");
    ok &= resolve(ReadImageInfo,      "XSDK_ReadImageInfo");
    ok &= resolve(ReadPreview,        "XSDK_ReadPreview");
    ok &= resolve(ReadImage,          "XSDK_ReadImage");
    ok &= resolve(DeleteImage,        "XSDK_DeleteImage");
    ok &= resolve(SetMediaRecord,     "XSDK_SetMediaRecord");
    ok &= resolve(GetMediaRecord,     "XSDK_GetMediaRecord");
    ok &= resolve(SetSensitivity,     "XSDK_SetSensitivity");
    ok &= resolve(GetSensitivity,     "XSDK_GetSensitivity");
    ok &= resolve(SetProp,            "XSDK_SetProp");
    ok &= resolve(GetProp,            "XSDK_GetProp");
    ok &= resolve(CapProp,            "XSDK_CapProp");

    // Extended exposure controls: optional so a body lacking one still opens.
    resolveOpt(CapSensitivity,  "XSDK_CapSensitivity");
    resolveOpt(CapShutterSpeed, "XSDK_CapShutterSpeed");
    resolveOpt(SetShutterSpeed, "XSDK_SetShutterSpeed");
    resolveOpt(GetShutterSpeed, "XSDK_GetShutterSpeed");
    resolveOpt(CapAperture,     "XSDK_CapAperture");
    resolveOpt(SetAperture,     "XSDK_SetAperture");
    resolveOpt(GetAperture,     "XSDK_GetAperture");
    resolveOpt(CapExposureBias, "XSDK_CapExposureBias");
    resolveOpt(SetExposureBias, "XSDK_SetExposureBias");
    resolveOpt(GetExposureBias, "XSDK_GetExposureBias");

    if (!ok) {
        Logger::instance().error(TAG, "SDK version/exports mismatch; unloading");
        unload();
        return false;
    }

    // NOTE: do NOT call any XSDK_* function here. The SDK is not usable until
    // XSDK_Init runs (CameraManager::initialize); calling e.g.
    // XSDK_GetVersionString before Init dereferences uninitialised SDK globals
    // and access-violates inside XAPI.dll. Version logging happens post-Init.
    Logger::instance().info(TAG, "XAPI.dll loaded and all exports resolved");
    return true;
}

void FujiSdkLibrary::unload() {
    if (m_module) {
        ::FreeLibrary(m_module);
        m_module = nullptr;
    }
}
