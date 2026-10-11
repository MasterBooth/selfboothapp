#pragma once
/*=============================================================================
 * FujiService.h - FUJIFILM X SDK lifecycle + camera detection
 *=============================================================================*/

#include "CameraDescriptor.h"
#include "API/FujiCameraController.h"
#include <vector>
#include <QDebug>

class FujiService {
public:
    static FujiService& instance() {
        static FujiService s;
        return s;
    }

    bool initSDK() {
        if (m_sdkInit) return true;
        m_sdkInit = FujiApp::FujiCameraController::instance().initialize();
        if (m_sdkInit)
            qWarning() << "[FujiService] FUJIFILM X SDK initialized OK";
        else
            qCritical() << "[FujiService] FUJIFILM X SDK init FAILED:"
                        << QString::fromStdString(
                               FujiApp::FujiCameraController::instance().getLastError());
        return m_sdkInit;
    }

    void shutdownSDK() {
        if (!m_sdkInit) return;
        FujiApp::FujiCameraController::instance().shutdown();
        m_sdkInit = false;
        qDebug() << "[FujiService] FUJIFILM X SDK shut down";
    }

    bool isSDKInitialized() const { return m_sdkInit; }

    bool detectCameras(std::vector<CameraDescriptor>& out) {
        if (!m_sdkInit) {
            qWarning() << "[FujiService] detectCameras() called before initSDK()";
            return false;
        }

        std::vector<FujiApp::FujiCameraInfo> raw;
        bool ok = FujiApp::FujiCameraController::instance().findCameras(raw);
        out.clear();
        for (int i = 0; i < static_cast<int>(raw.size()); ++i) {
            out.push_back({
                CameraDescriptor::Brand::Fuji,
                raw[i].name,
                raw[i].portName,
                i
            });
        }
        qDebug() << "[FujiService] Detected" << (int)out.size() << "camera(s)";
        return ok;
    }

private:
    FujiService() = default;
    bool m_sdkInit = false;
};
