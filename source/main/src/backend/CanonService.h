#pragma once
/*=============================================================================
 * CanonService.h — Canon EDSDK lifecycle + camera detection
 *
 * Rules:
 *   initSDK() / shutdownSDK() — MUST be called on the main thread.
 *   detectCameras()           — safe to call from a worker thread
 *                               AFTER initSDK() has returned true.
 *
 * Does NOT open camera sessions (that is the CanonSDKAdapter's job).
 *=============================================================================*/

#include "CameraDescriptor.h"
#include "API/CameraController.h"   // CameraApp (resolved via CAMERAAPP_ROOT)
#include <vector>
#include <QDebug>

class CanonService {
public:
    static CanonService& instance() {
        static CanonService s;
        return s;
    }

    // -----------------------------------------------------------------------
    // MAIN THREAD — SDK lifecycle
    // -----------------------------------------------------------------------

    // Initialize Canon EDSDK.  Must be called from the main thread.
    bool initSDK() {
        if (m_sdkInit) return true;
        m_sdkInit = CameraApp::CameraController::instance().initialize();
        if (m_sdkInit)
            qWarning() << "[CanonService] EDSDK initialized OK";
        else
            qCritical() << "[CanonService] EDSDK initialization FAILED";
        return m_sdkInit;
    }

    // Terminate EDSDK.  Must be called from the main thread.
    void shutdownSDK() {
        if (!m_sdkInit) return;
        CameraApp::CameraController::instance().shutdown();
        m_sdkInit = false;
        qDebug() << "[CanonService] EDSDK shut down";
    }

    bool isSDKInitialized() const { return m_sdkInit; }

    // -----------------------------------------------------------------------
    // WORKER THREAD — camera enumeration (SDK must already be initialized)
    // -----------------------------------------------------------------------

    // Enumerate connected Canon cameras.
    // Returns true even if the list is empty (= no cameras connected).
    // Returns false if SDK is not initialized.
    bool detectCameras(std::vector<CameraDescriptor>& out) {
        if (!m_sdkInit) {
            qWarning() << "[CanonService] detectCameras() called before initSDK()";
            return false;
        }

        std::vector<CameraApp::CameraInfo> raw;
        bool ok = CameraApp::CameraController::instance().findCameras(raw);
        out.clear();
        for (int i = 0; i < static_cast<int>(raw.size()); ++i) {
            out.push_back({
                CameraDescriptor::Brand::Canon,
                raw[i].name,
                raw[i].portName,
                i
            });
        }
        qDebug() << "[CanonService] Detected" << (int)out.size() << "camera(s)";
        return ok;
    }

private:
    CanonService() = default;
    bool m_sdkInit = false;
};
