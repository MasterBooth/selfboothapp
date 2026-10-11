#ifndef CAMERAEVENTBRIDGE_H
#define CAMERAEVENTBRIDGE_H

#include "API/CameraController.h"
#include <QImage>
#include <memory>

/**
 * @brief Bridge between CameraApp::CameraController events and Qt signals
 *
 * Converts CameraApp::ICameraEventListener events to Qt signals for QML compatibility
 * This allows PhotoboothDashboard to use the new unified camera API while
 * maintaining the same Qt signal interface for the UI.
 */
// Forward declaration — full type needed only in .cpp
class CameraController;

class CameraEventBridge : public CameraApp::ICameraEventListener {
public:
    explicit CameraEventBridge(CameraController* owner);
    ~CameraEventBridge() override = default;

    /**
     * Main event handler from CameraApp::CameraController
     * Routes all camera events to appropriate Qt signals
     */
    void onCameraEvent(const CameraApp::CameraEvent& event) override;

private:
    CameraController* m_owner;

    // Helper methods for event processing
    void handleConnected(const CameraApp::CameraEvent& event);
    void handleDisconnected(const CameraApp::CameraEvent& event);
    void handleCaptureStarted(const CameraApp::CameraEvent& event);
    void handleCaptureCompleted(const CameraApp::CameraEvent& event);
    void handleCaptureError(const CameraApp::CameraEvent& event);
    void handleLiveViewStarted(const CameraApp::CameraEvent& event);
    void handleLiveViewStopped(const CameraApp::CameraEvent& event);
    void handleLiveViewFrameReceived(const CameraApp::CameraEvent& event);
    void handlePropertyChanged(const CameraApp::CameraEvent& event);
    void handleDownloadProgress(const CameraApp::CameraEvent& event);
};

#endif // CAMERAEVENTBRIDGE_H
