#pragma once
/*=============================================================================
 * NikonService.h — Nikon Control Service Layer lifecycle + camera detection
 *
 * Rules (mirror SonyService):
 *   initSDK() / shutdownSDK() — called from the main thread (DualSDKController).
 *   detectCameras()           — safe from a worker thread AFTER initSDK() == true.
 *=============================================================================*/

#include "CameraDescriptor.h"
#include "API/NikonCameraController.h"   // NikonApp (resolved via NIKONAPP_ROOT)
#include <vector>
#include <QDebug>

class NikonService {
public:
    static NikonService& instance() {
        static NikonService s;
        return s;
    }

    // ----- MAIN THREAD — SDK lifecycle -----
    bool initSDK() {
        if (m_sdkInit) return true;
        m_sdkInit = NikonApp::NikonCameraController::instance().initialize();
        if (m_sdkInit)
            qWarning() << "[NikonService] Control Service Layer initialized OK";
        else
            qCritical() << "[NikonService] Control Service Layer init FAILED:"
                        << QString::fromStdString(
                               NikonApp::NikonCameraController::instance().getLastError());
        return m_sdkInit;
    }

    void shutdownSDK() {
        if (!m_sdkInit) return;
        NikonApp::NikonCameraController::instance().shutdown();
        m_sdkInit = false;
        qDebug() << "[NikonService] Control Service Layer shut down";
    }

    bool isSDKInitialized() const { return m_sdkInit; }

    // ----- WORKER THREAD — enumeration (SDK must already be initialized) -----
    bool detectCameras(std::vector<CameraDescriptor>& out) {
        if (!m_sdkInit) {
            qWarning() << "[NikonService] detectCameras() called before initSDK()";
            return false;
        }
        std::vector<NikonApp::NikonCameraInfo> raw;
        bool ok = NikonApp::NikonCameraController::instance().findCameras(raw);
        out.clear();
        for (int i = 0; i < static_cast<int>(raw.size()); ++i) {
            out.push_back({
                CameraDescriptor::Brand::Nikon,
                raw[i].name,
                raw[i].portName,
                i
            });
        }
        qDebug() << "[NikonService] Detected" << (int)out.size() << "camera(s)";
        return ok;
    }

private:
    NikonService() = default;
    bool m_sdkInit = false;
};
