import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Engine tự đếm ngược + chụp N ảnh cho chế độ Selfbooth, có hàng thumbnail xem lại + chụp lại.
// Hoàn toàn độc lập: KHÔNG đọc/ghi eventData, KHÔNG tạo session DB, KHÔNG ghép collage.
Item {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080

    // ── Props set bởi parent trước khi push ──────────────────────────────────
    property string sessionPath: ""
    property string sessionId: ""

    // ── Thông số chụp (đọc 1 lần từ settings — không đụng luồng chính) ────────
    property int totalPhotos: Math.max(1, parseInt(eventManager.getAppSetting("sbcut_photo_count", "4")) || 4)
    property int countdownDuration: Math.max(0, parseInt(eventManager.getAppSetting("sbcut_countdown", "3")) || 3)
    property int reviewSeconds: Math.max(1, parseInt(eventManager.getAppSetting("sbcut_review_seconds", "10")) || 10)
    property bool useNoAf: eventManager.getAppSetting("sbcut_capture_noaf", "false") === "true"
    property bool useRemote: eventManager.getAppSetting("sbcut_use_remote", "false") === "true"

    // ── Trạng thái nội bộ ────────────────────────────────────────────────────
    property int  currentPhotoIndex: 0
    property int  countdownValue: 0
    property bool isCountingDown: false
    property int  capturingIndex: -1
    property var  _downloadQueue: []
    property int  capturedCount: 0
    property bool isRetaking: false
    property int  retakeIndex: -1
    property int  lastRetakenIndex: -1
    property bool reviewActive: false
    property int  reviewRemaining: 0
    property bool _finished: false
    property bool waitingForRemote: false

    signal sessionDone(string sessionId, var photos)
    signal cameraFailed()
    signal cancelClicked()   // bấm X → huỷ tiến trình chụp, quay về trang trước

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0

    ListModel { id: sessionPhotos }

    // -------------------------------------------------------------------------
    // Vòng đời
    // -------------------------------------------------------------------------
    Component.onCompleted: {
        if (sessionPath !== "") cameraController.setSessionStoragePath(sessionPath)
        if (sessionId !== "")   cameraController.setCurrentSessionId(sessionId)
        cameraController.setRemoteShutterMode(root.useRemote)
        cameraController.addLiveViewViewer()
        // Bật relay đã chọn (đồng bộ với CaptureScreen). No-op nếu tính năng tắt / chưa kết nối.
        relayController.activateSelected()
        sessionPhotos.clear()
        for (var i = 0; i < root.totalPhotos; i++)
            sessionPhotos.append({ "path": "", "captured": false, "realPath": "" })
        startCountdownForCurrent()
        console.log("[SelfBoothCapture] start | photos:", totalPhotos, "| countdown:", countdownDuration, "| review:", reviewSeconds, "| noAf:", useNoAf, "| remote:", useRemote)
    }

    Component.onDestruction: {
        countdownTimer.stop(); nextShotTimer.stop(); reconnectTimer.stop()
        reviewTimer.stop(); captureRetryTimer.stop()
        root.waitingForRemote = false
        cameraController.setRemoteShutterMode(false)
        cameraController.removeLiveViewViewer()
        // Tắt relay khi rời màn chụp Selfbooth (chụp xong / lỗi máy / thoát).
        relayController.deactivateSelected()
    }

    // -------------------------------------------------------------------------
    // Logic chụp
    // -------------------------------------------------------------------------
    function startCountdownForCurrent() {
        if (root.currentPhotoIndex >= root.totalPhotos) return
        root.countdownValue = root.countdownDuration
        root.isCountingDown = true
        if (root.countdownValue <= 0)
            Qt.callLater(root.triggerCapture)
        else
            countdownTimer.restart()
    }

    function triggerCapture() {
        if (root.currentPhotoIndex >= root.totalPhotos) return
        root.isCountingDown = false
        root.capturingIndex = root.currentPhotoIndex
        if (root.useRemote) {
            root.waitingForRemote = true
            console.warn("[SelfBoothCapture] countdown ended in remote mode; waiting for physical shutter | photo:", root.capturingIndex + 1)
            return
        }
        photoFlash.restart()
        console.log("[SelfBoothCapture] countdown ended; sending app capture command | photo:", root.capturingIndex + 1, "| noAf:", root.useNoAf)
        var ok = root.useNoAf ? cameraController.takePictureNoAF()
                              : cameraController.takePicture()
        if (!ok) {
            console.warn("[SelfBoothCapture] takePicture failed for index", root.capturingIndex)
            captureRetryTimer.restart()
        }
    }

    // Chụp lại đúng 1 slot (từ previewOverlay).
    function retakePhoto(index) {
        if (index < 0 || index >= sessionPhotos.count) return
        countdownTimer.stop(); nextShotTimer.stop(); reviewTimer.stop()
        captureRetryTimer.stop()
        root.reviewActive = false

        if (sessionPhotos.get(index).captured) root.capturedCount--
        sessionPhotos.setProperty(index, "path", "")
        sessionPhotos.setProperty(index, "realPath", "")
        sessionPhotos.setProperty(index, "captured", false)

        root.isRetaking = true
        root.retakeIndex = index
        root.currentPhotoIndex = index
        startCountdownForCurrent()
    }

    function _maybeStartReview() {
        if (root._finished || root.reviewActive || root.isRetaking) return
        if (root.capturedCount < root.totalPhotos) return
        root.reviewActive = true
        root.reviewRemaining = root.reviewSeconds
        reviewTimer.restart()
    }

    function _pauseReview() {
        reviewTimer.stop()
        root.reviewActive = false
    }

    function _finishSession() {
        if (root._finished) return
        root._finished = true
        countdownTimer.stop(); nextShotTimer.stop(); reviewTimer.stop()

        // Upload S3 các ảnh cuối cùng (sau khi đã xem/chụp lại) + gom path trả về.
        var out = []
        var hwid = machineAuth.hwid
        for (var i = 0; i < sessionPhotos.count; i++) {
            var rp = sessionPhotos.get(i).realPath
            if (!rp || rp === "") continue
            out.push(rp)
            var clean = root.cleanPath(rp)
            var fname = root.basename(clean)
            if (hwid && hwid !== "" && fname && fname !== "")
                s3Uploader.uploadFileWithPath(clean, hwid + "/" + root.sessionId + "/" + fname)
        }
        console.log("[SelfBoothCapture] done — uploaded", out.length, "photos")
        root.sessionDone(root.sessionId, out)
    }

    function cleanPath(p) {
        var s = p.toString()
        if (Qt.platform.os === "windows") s = s.replace(/^file:\/{2,3}/, "")
        else s = s.replace(/^file:\/\//, "")
        return decodeURIComponent(s)
    }
    function basename(filePath) {
        return filePath.replace(/\\/g, "/").split("/").pop()
    }

    // ── Timers ───────────────────────────────────────────────────────────────
    Timer {
        id: countdownTimer
        interval: 1000; repeat: true
        onTriggered: {
            root.countdownValue--
            if (root.countdownValue <= 0) { stop(); root.triggerCapture() }
        }
    }

    Timer {
        id: nextShotTimer
        interval: 600; repeat: false
        onTriggered: { root.currentPhotoIndex++; root.startCountdownForCurrent() }
    }

    Timer {
        id: captureRetryTimer
        interval: 800; repeat: false
        property int attempts: 0
        onTriggered: {
            if (root.useRemote) return
            if (root.capturingIndex < 0) return
            attempts++
            if (attempts > 3) { attempts = 0; root.cameraFailed(); return }
            var ok = cameraController.takePictureNoAF()
            if (!ok) restart()
        }
    }

    // Đếm ngược xem lại → tự sang QR.
    Timer {
        id: reviewTimer
        interval: 1000; repeat: true
        onTriggered: {
            root.reviewRemaining--
            if (root.reviewRemaining <= 0) { stop(); root._finishSession() }
        }
    }

    Timer {
        id: retakeHighlightTimer
        interval: 4000; repeat: false
        onTriggered: root.lastRetakenIndex = -1
    }

    // ── Tín hiệu camera ──────────────────────────────────────────────────────
    Connections {
        target: cameraController

        function onCaptureCompleted() {
            var targetIdx = root.capturingIndex
            if (targetIdx < 0) return
            if (root.useRemote && !root.waitingForRemote) return
            if (root.useRemote) {
                root.waitingForRemote = false
                photoFlash.restart()
            }
            captureRetryTimer.stop(); captureRetryTimer.attempts = 0

            if (!sessionPhotos.get(targetIdx).captured) {
                sessionPhotos.setProperty(targetIdx, "captured", true)
                root.capturedCount++
            }

            var q = root._downloadQueue.slice(); q.push(targetIdx); root._downloadQueue = q

            if (root.isRetaking) {
                // Chụp lại 1 slot → không advance; chờ file về (onImageCaptured).
                return
            }
            if (root.currentPhotoIndex < root.totalPhotos - 1) {
                nextShotTimer.start()
            } else {
                root.currentPhotoIndex++  // đã bấm hết
                root._maybeStartReview()
            }
        }

        function onImageCaptured(path) {
            if (root._downloadQueue.length === 0) {
                console.warn("[SelfBoothCapture] onImageCaptured but queue empty")
                return
            }
            var q = root._downloadQueue.slice(); var targetIdx = q.shift(); root._downloadQueue = q

            var clean = root.cleanPath(path)
            var url = "file:///" + clean.replace(/\\/g, "/")
            sessionPhotos.setProperty(targetIdx, "path", url)
            sessionPhotos.setProperty(targetIdx, "realPath", url)

            if (root.isRetaking && targetIdx === root.retakeIndex) {
                root.isRetaking = false
                root.retakeIndex = -1
                root.lastRetakenIndex = targetIdx
                retakeHighlightTimer.restart()
            }
            root._maybeStartReview()
        }
    }

    // -------------------------------------------------------------------------
    // UI
    // -------------------------------------------------------------------------
    Rectangle { anchors.fill: parent; color: "#000000" }

    // Live view toàn màn.
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

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            visible: !cameraController.isLiveViewActive
            ColumnLayout {
                anchors.centerIn: parent; spacing: 16
                Text { text: "📷"; font.pixelSize: 64; Layout.alignment: Qt.AlignHCenter; opacity: 0.4 }
                Text { text: "Live view chưa hoạt động"; color: Theme.textMuted; font.pixelSize: 18; Layout.alignment: Qt.AlignHCenter }
            }
        }
    }

    Connections {
        target: cameraController
        property bool pendingUpdate: false
        function onFrameReady() {
            if (pendingUpdate) return
            pendingUpdate = true
            Qt.callLater(function() { pendingUpdate = false; liveImage.updateFrame() })
        }
    }

    // ── Overlay đếm ngược chụp ───────────────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: root.isCountingDown && root.countdownValue > 0
        text: root.countdownValue
        color: "white"; font.pixelSize: 280; font.bold: true
        style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.6)
        z: 5
    }

    // ── Nút X: huỷ tiến trình chụp → quay về trang trước (góc trên-phải) ──────
    Rectangle {
        id: cancelBtn
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 24; anchors.rightMargin: 24
        width: 52; height: 52; radius: 26
        z: 9
        opacity: cancelGuard.holding ? 0.65 : root._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: cancelArea.containsMouse ? "#c0392b" : "#e74c3c"
        border.color: "white"; border.width: 2
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"; font.pixelSize: 22; font.bold: true
        }

        MouseArea {
            id: cancelArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Dừng mọi tiến trình đang chạy rồi báo parent quay về trang trước.
                countdownTimer.stop(); nextShotTimer.stop(); reviewTimer.stop()
                captureRetryTimer.stop(); reconnectTimer.stop()
                root._finished = true   // chặn các callback chụp/đếm còn lại
                root.cancelClicked()
            }
        }
    }

    // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới huỷ lượt chụp.
    HoldToActivate {
        id: cancelGuard
        anchors.fill: cancelBtn
        z: 10
        onActivated: {
            countdownTimer.stop(); nextShotTimer.stop(); reviewTimer.stop()
            captureRetryTimer.stop(); reconnectTimer.stop()
            root._finished = true
            root.cancelClicked()
        }
    }

    // ── Badge số ảnh + đếm ngược review (góc trên-phải) ──────────────────────
    Rectangle {
        id: countBadge
        anchors.top: parent.top; anchors.right: cancelBtn.left
        anchors.topMargin: 24; anchors.rightMargin: 12
        width: badgeCol.implicitWidth + 28
        height: badgeCol.implicitHeight + 18
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.72)
        z: 6
        ColumnLayout {
            id: badgeCol
            anchors.centerIn: parent
            spacing: 2
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "📷 " + Math.min(root.capturedCount, root.totalPhotos) + " / " + root.totalPhotos
                color: "white"; font.pixelSize: 22; font.bold: true
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: root.reviewActive
                text: "Sang QR sau " + root.reviewRemaining + "s"
                color: "#facc15"; font.pixelSize: 13
            }
        }
    }

    // ── Hiệu ứng flash ───────────────────────────────────────────────────────
    Rectangle {
        id: photoFlashRect
        anchors.fill: parent; color: "white"; opacity: 0; z: 10
        SequentialAnimation {
            id: photoFlash
            NumberAnimation { target: photoFlashRect; property: "opacity"; to: 0.6; duration: 60 }
            NumberAnimation { target: photoFlashRect; property: "opacity"; to: 0.0; duration: 220 }
        }
    }

    // ── Hàng thumbnail dưới live view ────────────────────────────────────────
    Rectangle {
        id: bottomBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: 160
        z: 8
        color: "#CC1a1d23"

        ListView {
            anchors.fill: parent
            anchors.margins: 20
            orientation: ListView.Horizontal
            spacing: 15
            clip: true
            model: sessionPhotos

            delegate: Rectangle {
                required property int index
                required property var model
                width: 160; height: 120
                color: "#000000"
                radius: 4
                anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                border.color: {
                    if (index === root.lastRetakenIndex) return "#4caf50"
                    if (index === root.currentPhotoIndex && root.isCountingDown) return "#1e7eea"
                    return "#3a3d45"
                }
                border.width: (index === root.lastRetakenIndex
                               || (index === root.currentPhotoIndex && root.isCountingDown)) ? 4 : 2

                Image {
                    anchors.fill: parent; anchors.margins: 2
                    source: model.path
                    fillMode: Image.PreserveAspectFit
                    visible: model.captured
                    cache: false; asynchronous: true
                    sourceSize: Qt.size(156, 116)
                }
                Text {
                    visible: !model.captured
                    anchors.centerIn: parent
                    text: (index + 1)
                    color: "#3a3d45"; font.pixelSize: 36; font.bold: true
                }

                // Chỉ cho xem/chụp lại sau khi đã chụp đủ (giai đoạn review),
                // tránh phá vị trí khi đang trong chuỗi chụp.
                property bool _tappable: model.captured && root.capturedCount >= root.totalPhotos && !root.isRetaking
                MouseArea {
                    anchors.fill: parent
                    enabled: parent._tappable
                    cursorShape: parent._tappable ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        root._pauseReview()
                        previewOverlay.previewSource = model.path
                        previewOverlay.previewTargetIndex = index
                        previewOverlay.visible = true
                    }
                }
            }
        }
    }

    // ── Xem ảnh to + Chụp lại ────────────────────────────────────────────────
    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        color: "#EE000000"
        visible: false
        z: 90

        property string previewSource: ""
        property int    previewTargetIndex: -1

        MouseArea { anchors.fill: parent; onClicked: {} }

        Text {
            anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 30
            text: "Ảnh " + (previewOverlay.previewTargetIndex + 1)
            color: "white"; font.pixelSize: 22; font.bold: true
            style: Text.Outline; styleColor: "#00000088"
        }

        Image {
            anchors {
                left: parent.left; leftMargin: 60
                right: rightPanel.left; rightMargin: 20
                top: parent.top; topMargin: 60
                bottom: parent.bottom; bottomMargin: 60
            }
            source: previewOverlay.previewSource
            fillMode: Image.PreserveAspectFit
            cache: false; asynchronous: true
            sourceSize: Qt.size(1200, 900)
        }

        ColumnLayout {
            id: rightPanel
            anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom
            anchors.margins: 30
            width: 180; spacing: 16

            Item { Layout.fillHeight: true }

            Button {
                Layout.fillWidth: true; Layout.preferredHeight: 64
                background: Rectangle { color: parent.hovered ? "#3a4455" : "#242a38"; radius: 12; border.color: "#4a5570"; border.width: 1 }
                contentItem: ColumnLayout {
                    spacing: 4
                    Text { Layout.alignment: Qt.AlignHCenter; text: "←"; color: "white"; font.pixelSize: 22; font.bold: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Quay Lại"; color: "white"; font.pixelSize: 15; font.bold: true }
                }
                onClicked: {
                    previewOverlay.previewSource = ""
                    previewOverlay.visible = false
                    root._maybeStartReview()   // tiếp tục đếm ngược review
                }
            }

            Button {
                id: retakeBtn
                Layout.fillWidth: true; Layout.preferredHeight: 64
                background: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0; color: retakeBtn.hovered ? "#e04040" : "#c62828" }
                        GradientStop { position: 1; color: retakeBtn.hovered ? "#b03030" : "#8b1a1a" }
                    }
                    radius: 12
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    Text { Layout.alignment: Qt.AlignHCenter; text: "📷"; font.pixelSize: 22 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Chụp Lại"; color: "white"; font.pixelSize: 15; font.bold: true }
                }
                onClicked: {
                    var targetIdx = previewOverlay.previewTargetIndex
                    previewOverlay.previewSource = ""
                    previewOverlay.visible = false
                    root.retakePhoto(targetIdx)
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // ── Trạng thái kết nối lại camera ────────────────────────────────────────
    property int  _reconnectAttempts: 0
    property bool _reconnecting: false
    readonly property int _maxReconnectAttempts: 5

    Connections {
        target: cameraController
        function onIsConnectedChanged() {
            if (cameraController.isConnected) {
                reconnectTimer.stop()
                root._reconnecting = false
                root._reconnectAttempts = 0
                cameraController.setRemoteShutterMode(root.useRemote)
                if (!root._finished && !root.reviewActive && root.capturedCount < root.totalPhotos)
                    root.startCountdownForCurrent()
                console.log("[SelfBoothCapture] camera reconnected")
            } else {
                if (!root._finished && !root._reconnecting) {
                    countdownTimer.stop(); nextShotTimer.stop()
                    root._reconnecting = true
                    root._reconnectAttempts = 0
                    reconnectTimer.restart()
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: 3000; repeat: false
        onTriggered: {
            if (!root._reconnecting) return
            root._reconnectAttempts++
            cameraController.connectAsync()
            if (root._reconnectAttempts < root._maxReconnectAttempts) reconnectTimer.restart()
            else { root._reconnecting = false; cameraFailedDialog.open() }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.85)
        visible: !cameraController.isConnected && !root._finished
        z: 20
        ColumnLayout {
            anchors.centerIn: parent; spacing: 20
            Text { text: "📷"; font.pixelSize: 64; Layout.alignment: Qt.AlignHCenter; opacity: 0.5 }
            Text { text: "Máy ảnh ngắt kết nối"; color: "white"; font.pixelSize: 28; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text {
                text: root._reconnectAttempts > 0
                      ? ("Đang thử kết nối lại... (" + root._reconnectAttempts + "/" + root._maxReconnectAttempts + ")")
                      : "Đang chờ kết nối lại..."
                color: Theme.textMuted; font.pixelSize: 16; Layout.alignment: Qt.AlignHCenter
            }
            BusyIndicator { Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 48; Layout.preferredHeight: 48; running: root._reconnecting }
        }
    }

    Popup {
        id: cameraFailedDialog
        modal: true; closePolicy: Popup.NoAutoClose
        anchors.centerIn: Overlay.overlay
        width: 500; height: 280
        background: Rectangle { color: "#1e1520"; radius: 16; border.color: "#7f1d1d"; border.width: 2 }
        contentItem: ColumnLayout {
            anchors.fill: parent; anchors.margins: 32; spacing: 20
            Text { text: "⚠  Không thể kết nối máy ảnh"; color: "#fca5a5"; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text {
                text: "Đã thử kết nối " + root._maxReconnectAttempts + " lần nhưng không thành công."
                color: Theme.textMuted; font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter; Layout.alignment: Qt.AlignHCenter
                wrapMode: Text.WordWrap; Layout.fillWidth: true
            }
            Item { Layout.fillHeight: true }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 200; height: 48; radius: 24
                color: failArea.containsMouse ? "#991b1b" : "#7f1d1d"
                Text { anchors.centerIn: parent; text: "Quay lại"; color: "white"; font.pixelSize: 15; font.bold: true }
                MouseArea {
                    id: failArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { cameraFailedDialog.close(); root.cameraFailed() }
                }
            }
        }
    }

    // ── Hướng dẫn dưới cùng (trên hàng thumbnail) ────────────────────────────
    Rectangle {
        anchors.bottom: bottomBar.top; anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 16
        width: instrText.implicitWidth + 40; height: 44; radius: 22
        color: Qt.rgba(0, 0, 0, 0.65)
        z: 8
        visible: !root.reviewActive
        Text {
            id: instrText
            anchors.centerIn: parent
            text: root.useRemote
                  ? (root.waitingForRemote
                     ? ("Bấm dây remote để chụp ảnh " + (root.capturingIndex + 1))
                     : "Chuẩn bị — bấm dây remote khi có hướng dẫn")
                  : "Tạo dáng — máy sẽ tự chụp"
            color: Qt.rgba(1, 1, 1, 0.85); font.pixelSize: 15
        }
    }
}
