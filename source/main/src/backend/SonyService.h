#pragma once
/*=============================================================================
 * SonyService.h — Sony Camera Remote SDK lifecycle + camera detection
 *
 * Rules:
 *   initSDK() / shutdownSDK() — MUST be called on the main thread.
 *   detectCameras()           — safe to call from a worker thread
 *                               AFTER initSDK() has returned true.
 *=============================================================================*/

#include "CameraDescriptor.h"
#include "API/SonyCameraController.h"   // SonyApp (resolved via SONYAPP_ROOT)
#include <vector>
#include <QDebug>

class SonyService {
public:
    static SonyService& instance() {
        static SonyService s;
        return s;
    }

    // -----------------------------------------------------------------------
    // MAIN THREAD — SDK lifecycle
    // -----------------------------------------------------------------------

    bool initSDK() {
        if (m_sdkInit) return true;
        m_sdkInit = SonyApp::SonyCameraController::instance().initialize();
        if (m_sdkInit)
            qWarning() << "[SonyService] Camera Remote SDK initialized OK";
        else
            qCritical() << "[SonyService] Camera Remote SDK initialization FAILED";
        return m_sdkInit;
    }

    void shutdownSDK() {
        if (!m_sdkInit) return;
        SonyApp::SonyCameraController::instance().shutdown();
        m_sdkInit = false;
        qDebug() << "[SonyService] Camera Remote SDK shut down";
    }

    bool isSDKInitialized() const { return m_sdkInit; }

    // -----------------------------------------------------------------------
    // WORKER THREAD — camera enumeration (SDK must already be initialized)
    // -----------------------------------------------------------------------

    bool detectCameras(std::vector<CameraDescriptor>& out) {
        if (!m_sdkInit) {
            qWarning() << "[SonyService] detectCameras() called before initSDK()";
            return false;
        }

        std::vector<SonyApp::SonyCameraInfo> raw;
        bool ok = SonyApp::SonyCameraController::instance().findCameras(raw);
        out.clear();
        for (int i = 0; i < static_cast<int>(raw.size()); ++i) {
            out.push_back({
                CameraDescriptor::Brand::Sony,
                raw[i].name,
                raw[i].portName,
                i
            });
        }
        qDebug() << "[SonyService] Detected" << (int)out.size() << "camera(s)";
        return ok;
    }

private:
    SonyService() = default;
    bool m_sdkInit = false;
};
