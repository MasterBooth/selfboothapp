#include "CameraManager.h"
#include "FujiCamera.h"
#include "Logger.h"
#include <cstring>

static const char* TAG = "CameraMgr";

CameraManager::~CameraManager() { shutdown(); }

bool CameraManager::initialize(const std::wstring& dllPath) {
    if (!m_lib.load(dllPath)) return false;

    // The official Windows LiveView/ZoomPos samples initialize with NULL after
    // LoadLibrary. Passing the HINSTANCE also works for basic tethered capture
    // on some samples, but X-T5 model-dependent CapProp/SetProp can fault with
    // that state on SDK 1.15, so match the LiveView sample.
    if (m_lib.Init(nullptr) != XSDK_COMPLETE) {
        Logger::instance().error(TAG, "XSDK_Init failed");
        return false;
    }
    m_initialized = true;

    // Now that the SDK is initialised, it is safe to query the version.
    char ver[256] = {0};
    if (m_lib.GetVersionString && m_lib.GetVersionString(ver) == XSDK_COMPLETE)
        Logger::instance().info(TAG, "SDK initialized (XAPI version %s)", ver);
    else
        Logger::instance().info(TAG, "SDK initialized");
    return true;
}

void CameraManager::shutdown() {
    if (m_initialized) {
        m_lib.Exit();
        m_initialized = false;
        Logger::instance().info(TAG, "SDK shut down");
    }
    m_lib.unload();
}

std::vector<std::string> CameraManager::detect(long iface) {
    std::vector<std::string> out;
    if (!m_initialized) return out;

    long count = 0;
    // First form: NULL name buffers -> the SDK just reports the count.
    if (m_lib.Detect(iface, nullptr, nullptr, &count) != XSDK_COMPLETE) {
        Logger::instance().error(TAG, "XSDK_Detect failed");
        return out;
    }
    Logger::instance().info(TAG, "detected %ld camera(s)", count);

    // Second form: XSDK_Append gives model + serial per camera.
    if (count > 0 && m_lib.Append) {
        std::vector<XSDK_CameraList> list(count);
        long n = count;
        if (m_lib.Append(iface, nullptr, nullptr, &n, list.data()) == XSDK_COMPLETE) {
            for (long i = 0; i < n; ++i)
                if (list[i].bValid)
                    out.emplace_back(list[i].strProduct);
        }
    }
    if (out.empty())
        for (long i = 0; i < count; ++i) out.emplace_back("FUJIFILM (index " + std::to_string(i) + ")");
    return out;
}

std::unique_ptr<ICamera> CameraManager::open(int index) {
    if (!m_initialized) return nullptr;

    char device[32];
    std::snprintf(device, sizeof(device), "ENUM:%d", index);

    XSDK_HANDLE handle = nullptr;
    long cameraMode = 0;
    if (m_lib.OpenEx(device, &handle, &cameraMode, nullptr) != XSDK_COMPLETE) {
        Logger::instance().error(TAG, "XSDK_OpenEx(%s) failed", device);
        return nullptr;
    }

    // Confirm the body supports tethered shooting; if not, back out cleanly.
    if (!(cameraMode & XSDK_DSC_MODE_TETHER)) {
        Logger::instance().error(TAG, "camera opened but tether mode unsupported");
        m_lib.Close(handle);
        return nullptr;
    }

    // Pull identity for the UI / logs.
    CameraInfo info;
    XSDK_DeviceInformation di{};
    if (m_lib.GetDeviceInfo(handle, &di) == XSDK_COMPLETE) {
        info.model     = di.strProduct;
        info.serial    = di.strSerialNo;
        info.framework = di.strFramework;
    }
    char fw[256] = {0};
    if (m_lib.GetFirmwareVersion(handle, fw) == XSDK_COMPLETE) info.firmware = fw;
    XSDK_LensInformation li{};
    if (m_lib.GetLensInfo(handle, &li) == XSDK_COMPLETE) info.lens = li.strProductName;

    auto cam = std::make_unique<FujiCamera>(&m_lib, handle, info);
    if (!cam->open()) return nullptr;
    return cam;
}
