import QtQuick
import QtQuick.Controls
import "../theme"

/**
 * Canon Camera Live View Component
 *
 * Displays live view frames from Canon camera via EDSDK image provider.
 * Uses pull-based rendering — QML timer requests new frames from C++ image provider.
 */
Rectangle {
    id: root
    color: "#000000"
    border.color: "#3a3d45"
    border.width: 1
    radius: 8

    property bool isActive: cameraController.isLiveViewActive
    property int renderFps: 30

    // === LIVE VIEW IMAGE ===
    Image {
        id: liveImage
        anchors.fill: parent
        anchors.margins: 2
        fillMode: Image.PreserveAspectFit
        cache: false
        asynchronous: false

        property int frameVersion: 0

        function updateFrame() {
            if (!root.isActive) return
            frameVersion++
            liveImage.source = "image://live/frame_" + frameVersion
        }
    }

    // === PUSH MODEL — update only when C++ signals a new frame ===
    // Qt.callLater() coalescing: if several frameReady signals arrive before
    // one event-loop pass executes, only ONE update fires — always the latest frame.
    Connections {
        target: cameraController
        property bool pendingUpdate: false
        function onFrameReady() {
            if (!root.isActive || pendingUpdate) return
            pendingUpdate = true
            Qt.callLater(function() {
                pendingUpdate = false
                liveImage.updateFrame()
            })
        }
    }

    // === STATUS OVERLAY — shown when not streaming ===
    Rectangle {
        visible: !root.isActive
        anchors.fill: parent
        color: "#1a1d23"
        radius: 6

        Column {
            anchors.centerIn: parent
            spacing: 15

            Text {
                text: "📷"
                font.pixelSize: 48
                opacity: 0.3
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: cameraController.isConnected ? "Starting live view..." : "Camera not connected"
                color: "#808080"
                font.pixelSize: 16
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // === FPS STATS OVERLAY ===
    Rectangle {
        visible: root.isActive
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: statsText.width + 20
        height: statsText.height + 10
        color: "#CC000000"
        radius: 5

        Text {
            id: statsText
            anchors.centerIn: parent
            color: "#00FF00"
            font.family: "Monospace"
            font.pixelSize: 12
            text: root.renderFps + " FPS | Canon EDSDK"
        }
    }
}
