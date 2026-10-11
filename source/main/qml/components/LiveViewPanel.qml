import QtQuick
import QtQuick.Layouts
import "../theme"

/**
 * LiveViewPanel — Pull-based live view renderer
 *
 * Displays Canon camera frames from the LiveViewImageProvider registered as "live".
 * Uses a pull timer that requests image://live/frame_N every 33ms when active.
 * Mirror mode is applied in C++ (CameraController) before the image reaches the provider.
 */
Rectangle {
    id: root
    color: "transparent"
    border.color: "#3a3d45"
    border.width: root.panelBorderWidth
    radius: root.panelRadius
    clip: true   // cắt phần frame tràn ra ngoài khi dùng PreserveAspectCrop

    // External API — set by parent (LiveViewCard, CaptureScreen, etc.)
    property bool isActive: false
    // true chỉ khi panel này thuộc màn hình ĐANG hiển thị trên StackView. Khi màn bị
    // đẩy xuống (vẫn còn sống trong StackView), parent set false để NGỪNG tiêu thụ
    // frame — tránh requestImage đồng bộ vô ích mỗi frame trên GUI thread.
    property bool consuming: true
    property var eventData: null
    property string errorMessage: ""
    // Cách lấp đầy khung. Mặc định PreserveAspectCrop để fill kín màn hình
    // (giữ tỉ lệ, cắt phần thừa, không méo). Parent có thể override nếu cần.
    property int fillMode: Image.PreserveAspectCrop
    property int renderFps: 30
    property int imageMargins: 2
    property int panelRadius: 8
    property int panelBorderWidth: 1
    property double _lastRenderMs: 0
    property bool _renderQueued: false

    function _scheduleFrame() {
        if (_renderQueued || !root.isActive || !root.consuming) return
        _renderQueued = true
        Qt.callLater(function() {
            _renderQueued = false
            var fps = Math.max(1, root.renderFps)
            var minInterval = 1000 / fps
            var now = Date.now()
            if (root._lastRenderMs > 0 && (now - root._lastRenderMs) < (minInterval - 1))
                return
            root._lastRenderMs = now
            liveImage.updateFrame()
        })
    }

    // === LIVE VIEW IMAGE ===
    // asynchronous:false is intentional: the provider returns a pre-decoded QImage
    // (decoded on the EDSDK streaming thread before this call), so requestImage()
    // completes in microseconds — no render-thread stall.
    // Using asynchronous:true here would queue async loads that get canceled when
    // new frames arrive faster than Qt can decode them, producing ghost frames.
    Image {
        id: liveImage
        anchors.fill: parent
        anchors.margins: root.imageMargins
        fillMode: root.fillMode
        cache: false
        asynchronous: false

        property int frameVersion: 0

        function updateFrame() {
            if (!root.isActive) return
            frameVersion++
            source = "image://live/frame_" + frameVersion
        }
    }

    // === PUSH MODEL — update only when C++ has a new frame ===
    // frameReady fires once per JPEG received from the camera (on the streaming
    // thread, posted via QueuedConnection to the main thread).
    //
    // Problem without coalescing: if the main thread is briefly busy, multiple
    // frameReady signals queue up.  When the main thread catches up it processes
    // all of them in one burst — requestImage() is called N times in rapid
    // succession, showing N stale frames before going idle, creating jitter.
    //
    // Fix: Qt.callLater() defers the actual update to the next event-loop pass.
    // If several frameReady signals arrive before that pass executes, the flag
    // prevents duplicate calls — only ONE update happens per event-loop turn,
    // always showing the LATEST frame in the provider.
    Connections {
        target: cameraController
        // Ngừng hẳn khi panel không hiển thị / không phải màn hiện tại → không có
        // requestImage thừa từ màn bị che (StackView giữ item sống).
        enabled: root.isActive && root.consuming

        function onFrameReady() {
            root._scheduleFrame()
        }
    }

    // === INACTIVE OVERLAY ===
    Rectangle {
        visible: !root.isActive
        anchors.fill: parent
        color: "transparent"
        radius: Math.max(0, root.panelRadius - 2)

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 15

            Text {
                text: "📷"
                font.pixelSize: 48
                opacity: 0.3
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Tắt live view"
                color: "#808080"
                font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // === ERROR OVERLAY ===
    Rectangle {
        visible: root.errorMessage !== ""
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        width: msgText.width + 40
        height: 30
        color: "#CCFF0000"
        radius: 15

        Text {
            id: msgText
            anchors.centerIn: parent
            text: root.errorMessage
            color: "white"
            font.bold: true
        }
    }
}
