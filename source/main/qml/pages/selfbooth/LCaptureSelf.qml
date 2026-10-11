import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../components"
import "../../theme"

Item {
    id: root

    // Set by parent before pushing this page
    property int selectedMinutes: 5
    property string sessionPath: ""
    property string sessionId:   ""

    signal sessionDone(string sessionId, var photos)
    signal cancelClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0

    // ── Internal state ────────────────────────────────────────────────────────
    property int    photoCount:  0
    property bool   _cancelled:  false
    property var    capturedPhotos: []

    // Countdown in seconds (initialized when page becomes active)
    property int remainingSeconds: selectedMinutes * 60

    // True while we're in the "saving last photos" phase
    property bool isSaving: false

    // Background image (loaded from settings, live-reloads on change)
    property string captureBg: eventManager.getAppSetting("selfbooth_bg_capture", "")

    // Chế độ chụp test: không cần máy ảnh, bấm nút tạo ảnh mockup (grab màn hình
    // giả lập) để kiểm thử toàn bộ luồng upload + QR.
    readonly property bool testMode: eventManager.getAppSetting("selfbooth_test_mode", "false") === "true"

    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "selfbooth_bg_capture") root.captureBg = value
        }
    }

    // ── Session initialisation ────────────────────────────────────────────────
    Component.onCompleted: {
        if (root.sessionId === "") {
            var now   = new Date()
            var stamp = Qt.formatDateTime(now, "yyyyMMdd_HHmmss")
            root.sessionId = "selfbooth_" + stamp
        }
        if (root.sessionPath === "") {
            var baseDir = eventManager.getAppSetting("sbcut_save_dir", "")
            if (baseDir === "") baseDir = eventManager.getSelfBoothBaseDir()
            root.sessionPath = baseDir + "/" + root.sessionId
        }

        cameraController.setSessionStoragePath(root.sessionPath)
        cameraController.setCurrentSessionId(root.sessionId)
        cameraController.setRemoteShutterMode(true)

        // Register as live view viewer so the decode thread stays active
        cameraController.addLiveViewViewer()

        // Chế độ test: chuẩn bị sẵn thư mục phiên để lưu ảnh mockup.
        if (root.testMode)
            eventManager.ensureDir(root.sessionPath)

        // Start session timer
        remainingSeconds = selectedMinutes * 60
        sessionTimer.start()

        console.log("[LCaptureSelf] Session started:", sessionId, "| path:", sessionPath, "| time:", selectedMinutes, "min", root.testMode ? "| TEST MODE" : "")
    }

    Component.onDestruction: {
        sessionTimer.stop()
        reconnectTimer.stop()
        cameraController.setRemoteShutterMode(false)
        cameraController.removeLiveViewViewer()
    }

    // ── Session countdown timer ───────────────────────────────────────────────
    Timer {
        id: sessionTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.isSaving) return
            root.remainingSeconds--
            if (root.remainingSeconds <= 0) {
                stop()
                root.beginSaving()
            }
        }
    }

    // ── Saving-phase delay: give camera time to write last photos ─────────────
    Timer {
        id: savingTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (root._cancelled) return
            console.log("[LCaptureSelf] Saving done — total photos:", root.photoCount)
            root.sessionDone(root.sessionId, root.capturedPhotos)
        }
    }

    function beginSaving() {
        if (root._cancelled) return
        root.isSaving = true
        savingPopup.open()
        savingTimer.start()
    }

    // ── Helper: extract filename from path ────────────────────────────────────
    function basename(filePath) {
        return filePath.replace(/\\/g, "/").split("/").pop()
    }

    function cleanPath(p) {
        var s = p.toString()
        if (Qt.platform.os === "windows")
            s = s.replace(/^file:\/{2,3}/, "")
        else
            s = s.replace(/^file:\/\//, "")
        return decodeURIComponent(s)
    }

    // ── Ghi nhận 1 ảnh (từ camera hoặc mockup test) + upload S3 ──────────────
    function _registerPhoto(cleanFilePath) {
        root.photoCount++
        photoFlash.restart()

        // Upload to S3 on worker thread (s3Uploader has its own QThread)
        var photos = root.capturedPhotos.slice()
        photos.push(cleanFilePath)
        root.capturedPhotos = photos
        var fname = root.basename(cleanFilePath)
        var hwid  = machineAuth.hwid
        if (hwid && hwid !== "" && fname && fname !== "") {
            var s3Key = hwid + "/" + root.sessionId + "/" + fname
            s3Uploader.uploadFileWithPath(cleanFilePath, s3Key)
            console.log("[LCaptureSelf] Queued upload:", s3Key)
        }

        console.log("[LCaptureSelf] Photo", root.photoCount, "->", cleanFilePath)
    }

    // ── Listen for photos captured via remote shutter ─────────────────────────
    Connections {
        target: cameraController
        function onImageCaptured(path) {
            if (!root._cancelled)
                root._registerPhoto(root.cleanPath(path))
        }
    }

    // ── Chụp test: grab khung mock → lưu file jpg vào thư mục phiên ──────────
    property bool _testCapturing: false
    function _takeTestPhoto() {
        if (root._cancelled || root.isSaving || root._testCapturing) return
        root._testCapturing = true
        var idx = root.photoCount + 1
        var fname = "test_" + (idx < 10 ? "0" + idx : idx) + ".jpg"
        var dest = root.sessionPath + "/" + fname
        mockFrame.grabToImage(function(result) {
            root._testCapturing = false
            if (result.saveToFile(dest)) {
                root._registerPhoto(dest)
            } else {
                console.warn("[LCaptureSelf] TEST: cannot save mock photo:", dest)
            }
        })
    }

    // ── Formatted countdown helpers ───────────────────────────────────────────
    function pad2(n) { return n < 10 ? "0" + n : n.toString() }
    function formatTime(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return pad2(m) + ":" + pad2(s)
    }
    property string countdownText: formatTime(remainingSeconds)

    // ── UI ────────────────────────────────────────────────────────────────────
    // Full-screen solid black base
    Rectangle {
        anchors.fill: parent
        color: "#000000"
    }

    // Optional background image (behind live view, only visible when live view inactive)
    Image {
        anchors.fill: parent
        source: root.captureBg !== "" ? "file:///" + root.captureBg : ""
        fillMode: Image.PreserveAspectCrop
        visible: root.captureBg !== "" && !cameraController.isLiveViewActive
    }

    // ── Full-screen live view (inlined for true fill — no border/radius/margins)
    // Uses push model: update only when C++ signals a new frame is ready.
    Item {
        id: liveViewContainer
        anchors.fill: parent

        Image {
            id: liveImage
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            cache: false
            asynchronous: false

            property int frameVersion: 0

            function updateFrame() {
                if (!cameraController.isLiveViewActive) return
                frameVersion++
                source = "image://live/frame_" + frameVersion
            }
        }

        // Inactive overlay
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            visible: !cameraController.isLiveViewActive && !root.testMode

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16
                Text { text: "📷"; font.pixelSize: 64; Layout.alignment: Qt.AlignHCenter; opacity: 0.4 }
                Text {
                    text: "Live view chưa hoạt động"
                    color: Theme.textMuted; font.pixelSize: 18
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }

    // ── Khung mock cho chế độ chụp test (thay live view, được grab thành ảnh) ─
    Rectangle {
        id: mockFrame
        anchors.fill: parent
        visible: root.testMode
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#2a1a4e" }
            GradientStop { position: 0.55; color: "#14275e" }
            GradientStop { position: 1.0; color: "#0b0d16" }
        }

        // Đồng hồ chạy để mỗi ảnh mockup một khác
        Timer {
            id: mockClock
            interval: 1000; repeat: true; running: root.testMode
            onTriggered: mockTimeText.text = Qt.formatDateTime(new Date(), "HH:mm:ss  dd/MM/yyyy")
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18

            Text { text: "🧪"; font.pixelSize: 110; Layout.alignment: Qt.AlignHCenter }
            Text {
                text: "ẢNH TEST — MOCKUP"
                color: "#ffffff"; font.pixelSize: 56; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                id: mockTimeText
                text: Qt.formatDateTime(new Date(), "HH:mm:ss  dd/MM/yyyy")
                color: "#8ab4f8"; font.pixelSize: 34; font.family: "Courier New"
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: root.sessionId + "  ·  ảnh #" + (root.photoCount + 1)
                color: Qt.rgba(1,1,1,0.6); font.pixelSize: 22
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Frame pump — one update per event-loop turn to avoid jitter
    Connections {
        target: cameraController
        property bool pendingUpdate: false
        function onFrameReady() {
            if (pendingUpdate) return
            pendingUpdate = true
            Qt.callLater(function() {
                pendingUpdate = false
                liveImage.updateFrame()
            })
        }
    }

    // ── Top-left: always-visible exit button ──────────────────────────────────
    Rectangle {
        id: cancelButton
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 24
        anchors.leftMargin: 24
        width: 56
        height: 56
        radius: 28
        z: 30
        opacity: lcCancelGuard.holding ? 0.65 : root._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: cancelArea.containsMouse ? "#c0392b" : "#e74c3c"
        border.color: "white"
        border.width: 2

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"
            font.pixelSize: 24
            font.bold: true
        }

        MouseArea {
            id: cancelArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root._cancelled) return
                root._cancelled = true
                sessionTimer.stop()
                savingTimer.stop()
                reconnectTimer.stop()
                cameraFailedDialog.close()
                savingPopup.close()
                root.cancelClicked()
            }
        }
    }

    // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới huỷ lượt chụp.
    HoldToActivate {
        id: lcCancelGuard
        anchors.fill: cancelButton
        z: 31
        onActivated: {
            if (root._cancelled) return
            root._cancelled = true
            sessionTimer.stop()
            savingTimer.stop()
            reconnectTimer.stop()
            cameraFailedDialog.close()
            savingPopup.close()
            root.cancelClicked()
        }
    }

    // ── Countdown badge, placed beside the exit button ────────────────────────
    Rectangle {
        id: countdownBadge
        anchors.top: parent.top
        anchors.left: cancelButton.right
        anchors.topMargin: 24
        anchors.leftMargin: 12
        width: countdownCol.implicitWidth + 32
        height: countdownCol.implicitHeight + 20
        radius: 14
        z: 25
        color: remainingSeconds <= 60 ? Qt.rgba(0.8, 0.1, 0.1, 0.85)
             : remainingSeconds <= 180 ? Qt.rgba(0.8, 0.5, 0.0, 0.85)
             : Qt.rgba(0.0, 0.0, 0.0, 0.72)

        Behavior on color { ColorAnimation { duration: 400 } }

        ColumnLayout {
            id: countdownCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: root.countdownText
                color: "white"
                font.pixelSize: 38; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: "Thời gian còn lại"
                color: Qt.rgba(1,1,1,0.75); font.pixelSize: 11
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Pulse animation when time is almost up
        SequentialAnimation on opacity {
            running: remainingSeconds <= 10 && !root.isSaving
            loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 400 }
            NumberAnimation { to: 1.0; duration: 400 }
        }
        opacity: 1.0
    }

    // ── Top-right: photo counter ──────────────────────────────────────────────
    Rectangle {
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 24; anchors.rightMargin: 24
        width: photoCountRow.implicitWidth + 28
        height: 52; radius: 12
        color: Qt.rgba(0,0,0,0.72)

        Row {
            id: photoCountRow
            anchors.centerIn: parent
            spacing: 8

            Text { text: "📷"; font.pixelSize: 22; verticalAlignment: Text.AlignVCenter }
            Text {
                text: root.photoCount
                color: "white"; font.pixelSize: 26; font.bold: true
                verticalAlignment: Text.AlignVCenter
            }
            Text {
                text: "ảnh"
                color: Qt.rgba(1,1,1,0.6); font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter; topPadding: 4
            }
        }
    }

    // ── Photo capture flash effect ────────────────────────────────────────────
    Rectangle {
        id: photoFlashRect
        anchors.fill: parent
        color: "white"; opacity: 0; z: 10

        SequentialAnimation {
            id: photoFlash
            NumberAnimation { target: photoFlashRect; property: "opacity"; to: 0.6; duration: 60 }
            NumberAnimation { target: photoFlashRect; property: "opacity"; to: 0.0; duration: 220 }
        }
    }

    // ── Camera reconnect state ────────────────────────────────────────────────
    property int  _reconnectAttempts: 0
    property bool _reconnecting:      false
    readonly property int _maxReconnectAttempts: 5

    signal cameraFailed()   // emitted when all retries exhausted

    // Watch for disconnection while session is running
    Connections {
        id: cameraWatcher
        target: cameraController
        function onIsConnectedChanged() {
            if (root._cancelled || root.testMode) return
            if (cameraController.isConnected) {
                // Reconnected — cancel pending retry, reset counter, resume session timer
                reconnectTimer.stop()
                root._reconnecting      = false
                root._reconnectAttempts = 0
                cameraController.setRemoteShutterMode(true)
                if (!root.isSaving) sessionTimer.start()
                console.log("[LCaptureSelf] Camera reconnected — session resumed")
            } else {
                // Just disconnected — start retry sequence
                if (!root.isSaving && !root._reconnecting) {
                    sessionTimer.stop()
                    root._reconnecting      = true
                    root._reconnectAttempts = 0
                    reconnectTimer.restart()
                    console.log("[LCaptureSelf] Camera disconnected — starting reconnect sequence")
                }
            }
        }
    }

    // Fires every 3 s to attempt reconnection
    Timer {
        id: reconnectTimer
        interval: 3000
        repeat: false
        onTriggered: {
            if (!root._reconnecting || root._cancelled) return
            root._reconnectAttempts++
            console.log("[LCaptureSelf] Reconnect attempt", root._reconnectAttempts, "/", root._maxReconnectAttempts)
            cameraController.connectAsync()

            if (root._reconnectAttempts < root._maxReconnectAttempts) {
                // Wait for onIsConnectedChanged; if not fired in 3 s, fire next attempt
                reconnectTimer.restart()
            } else {
                // All attempts exhausted
                root._reconnecting = false
                cameraFailedDialog.open()
                console.warn("[LCaptureSelf] All reconnect attempts failed")
            }
        }
    }

    // ── Camera disconnected overlay ───────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.85)
        visible: !cameraController.isConnected && !root.isSaving && !root.testMode
        z: 20

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20

            Text { text: "📷"; font.pixelSize: 64; Layout.alignment: Qt.AlignHCenter; opacity: 0.5 }

            Text {
                text: "Máy ảnh ngắt kết nối"
                color: "white"; font.pixelSize: 28; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: root._reconnectAttempts > 0
                      ? ("Đang thử kết nối lại... (" + root._reconnectAttempts + "/" + root._maxReconnectAttempts + ")")
                      : "Đang chờ kết nối lại..."
                color: Theme.textMuted; font.pixelSize: 16
                Layout.alignment: Qt.AlignHCenter
            }

            // Attempt dots
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 10
                Repeater {
                    model: root._maxReconnectAttempts
                    Rectangle {
                        width: 14; height: 14; radius: 7
                        color: index < root._reconnectAttempts ? "#f87171"
                             : index === root._reconnectAttempts && root._reconnecting ? "#facc15"
                             : "#374151"
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 48; Layout.preferredHeight: 48
                running: root._reconnecting
            }
        }
    }

    // ── Camera failed dialog ──────────────────────────────────────────────────
    Popup {
        id: cameraFailedDialog
        modal: true
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: Overlay.overlay
        width: 500; height: 300

        background: Rectangle {
            color: "#1e1520"; radius: 16
            border.color: "#7f1d1d"; border.width: 2
        }

        contentItem: ColumnLayout {
            anchors.fill: parent; anchors.margins: 32
            spacing: 20

            Text {
                text: "⚠  Không thể kết nối máy ảnh"
                color: "#fca5a5"; font.pixelSize: 20; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Đã thử kết nối " + root._maxReconnectAttempts + " lần nhưng không thành công.\nVui lòng liên hệ nhân viên kiểm tra lại máy ảnh."
                color: Theme.textMuted; font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                lineHeight: 1.5; wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 220; height: 48; radius: 24
                color: confirmArea.containsMouse ? "#991b1b" : "#7f1d1d"
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "Về trang chào mừng"
                    color: "white"; font.pixelSize: 15; font.bold: true
                }

                MouseArea {
                    id: confirmArea
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        cameraFailedDialog.close()
                        root.cameraFailed()
                    }
                }
            }
        }
    }

    // ── Bottom instruction bar ────────────────────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: root.testMode ? 110 : 20
        width: instrText.implicitWidth + 40; height: 44; radius: 22
        color: Qt.rgba(0,0,0,0.65)
        visible: !root.isSaving

        Text {
            id: instrText
            anchors.centerIn: parent
            text: root.testMode ? "Chế độ TEST — bấm nút bên dưới để chụp ảnh mockup"
                                : "Bấm remote để chụp ảnh"
            color: Qt.rgba(1,1,1,0.85); font.pixelSize: 15
        }
    }

    // ── Nút chụp test (chỉ hiện ở chế độ test) ────────────────────────────────
    Rectangle {
        anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
        width: 280; height: 68; radius: 34
        z: 25
        visible: root.testMode && !root.isSaving
        color: testShotMa.pressed ? "#b45309"
             : testShotMa.containsMouse ? "#d97706" : "#f59e0b"
        border.color: "#ffffff"; border.width: 2
        Behavior on color { ColorAnimation { duration: 100 } }
        scale: testShotMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 80 } }

        Row {
            anchors.centerIn: parent
            spacing: 10
            Text { text: "📸"; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "CHỤP TEST"
                color: "#1a1200"; font.pixelSize: 22; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: testShotMa
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root._takeTestPhoto()
        }
    }

    // ── Saving popup ──────────────────────────────────────────────────────────
    Popup {
        id: savingPopup
        modal: true
        closePolicy: Popup.NoAutoClose
        anchors.centerIn: Overlay.overlay
        width: 460; height: 260
        visible: false

        background: Rectangle {
            color: "#1e2030"; radius: 16
            border.color: "#4a4d70"; border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 20

            Text {
                text: "Đang lưu ảnh..."
                color: "white"; font.pixelSize: 22; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 52; Layout.preferredHeight: 52
                running: savingPopup.visible
            }

            Text {
                text: "Vui lòng chờ trong giây lát\nĐang lưu " + root.photoCount + " ảnh vào thư mục phiên"
                color: Theme.textMuted; font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
                lineHeight: 1.4
            }
        }
    }
}
