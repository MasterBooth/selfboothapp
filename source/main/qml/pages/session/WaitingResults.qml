import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import "../../theme"
import "../../components"

// Trang chờ sau khi bấm In: hiển thị ảnh đã in và mã QR.
Item {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // ── Inputs (set bởi BoothSession) ─────────────────────────
    property var    photos: []
    property string collagePath: ""
    property string displayPath: ""   // ảnh hiển thị (strip no-cut); fallback collagePath
    property string _displaySource: displayPath !== "" ? displayPath : collagePath
    property int    eventId: -1
    property var    eventData: null
    property string sessionId: ""
    property string hwid: ""

    signal finished()   // "Chụp Lượt Mới" hoặc hết giờ đếm ngược

    property bool _paymentEnabled: eventManager.getAppSetting("payment_enabled", "false") === "true"
    property int  resultCountdownTime: parseInt(eventManager.getAppSetting("waiting_results_countdown", "30")) || 30
    property string backgroundImagePath: {
        var s = eventManager.getAppSetting("waiting_results_bg_image", "")
        return s !== "" ? s : "qrc:/assets/5.png"
    }

    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    property color _ink: "#3C241B"
    property color _muted: "#7A5F52"
    property color _paper: "#FFF8EC"
    property color _panel: "#FFFAF1"
    property color _copper: "#B8783F"
    property color _copperDark: "#6B3E22"
    property color _line: "#E5D4C3"

    readonly property int _gridGap: portrait ? 6 : 5
    readonly property int _gridPad: portrait ? 10 : 10
    readonly property int _gridBaseW: Math.floor(Math.min(width - (portrait ? 180 : 170), portrait ? 520 : 520))
    readonly property int _gridCell: Math.floor((_gridBaseW - _gridGap * 3) / 4)
    readonly property int _gridInner: _gridCell * 4 + _gridGap * 3
    readonly property int _gridPanelW: _gridInner + _gridPad * 2
    readonly property int _gridPanelH: _gridInner + _gridPad * 2
    readonly property int _qrCardW: Math.floor(Math.min(width - (portrait ? 120 : 160), portrait ? 600 : 390))
    readonly property int _qrCardH: portrait ? 580 : 300
    readonly property int _qrSide: portrait ? 400 : 184
    readonly property int _bottomH: portrait ? 110 : 104

    // QR mở thẳng album web của lượt chụp (xem ảnh → chọn frame → ghép → in).
    // Link có token ngẫu nhiên do server cấp (s3Uploader.requestGalleryLink), nên phải
    // chờ mạng; mất mạng thì thử lại định kỳ. Dùng chung provider image://qr/.
    property string galleryLink: sessionId !== "" ? s3Uploader.cachedGalleryLink(sessionId) : ""
    property bool   _galleryLinkFailed: false
    property string qrImageUrl: galleryLink !== "" ? ("image://qr/" + encodeURIComponent(galleryLink)) : ""

    function _requestGalleryLink() {
        if (root.sessionId === "" || root.galleryLink !== "") return
        s3Uploader.requestGalleryLink(root.sessionId)
    }

    onSessionIdChanged: {
        root.galleryLink = root.sessionId !== "" ? s3Uploader.cachedGalleryLink(root.sessionId) : ""
        root._galleryLinkFailed = false
        root._requestGalleryLink()
    }

    Connections {
        target: s3Uploader
        function onGalleryLinkReady(sid, url) {
            if (sid !== root.sessionId) return
            root.galleryLink = url
            root._galleryLinkFailed = false
        }
        function onGalleryLinkFailed(sid, message) {
            if (sid !== root.sessionId) return
            root._galleryLinkFailed = true
            console.warn("[WaitingResults] Gallery link failed:", message)
        }
    }

    // Chưa có link (mất mạng / server bận): thử lại mỗi 5 giây khi màn đang hiển thị.
    Timer {
        interval: 5000
        repeat: true
        running: root._isActiveScreen && root.sessionId !== "" && root.galleryLink === ""
        onTriggered: root._requestGalleryLink()
    }

    // ── Video quá trình chụp (video_<sessionId>.mp4) ───────────────────────────
    // Nguồn kép: hỏi thẳng backend khi mở màn (video đã encode xong từ trước),
    // và nghe processVideoReady (encode xong khi đang ở màn này).
    property bool   _videoEnabled: eventManager.getAppSetting("video_enabled", "true") === "true"
    property string videoPath: ""
    readonly property bool _showVideo: _videoEnabled && videoPath !== ""

    // WaitingResults chỉ hiển thị QR xem ảnh của toàn session chụp.
    // QR web ghép/chỉnh sửa ảnh không hiển thị ở màn này.
    property bool frameSelectionEnabled: eventManager.getAppSetting("frame_selection_enabled", "true") === "true"
    property string editorBaseUrl: eventManager.getAppSetting("selfbooth_editor_base_url", "https://boothme-vn.vercel.app")
    property string editorUrl: {
        var base = editorBaseUrl
        while (base.length > 0 && base.charAt(base.length - 1) === "/")
            base = base.slice(0, -1)
        if (hwid !== "" && sessionId !== "" && eventId > 0 && base !== "")
            return base + "/selfbooth/" + hwid + "/" + eventId + "/" + sessionId
        return ""
    }
    property string editorQrUrl: editorUrl !== "" ? ("image://qr/" + encodeURIComponent(editorUrl)) : ""
    readonly property bool _dualQr: false

    property var _gridSources: []

    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "frame_selection_enabled")
                root.frameSelectionEnabled = (value === "true")
            if (key === "selfbooth_editor_base_url")
                root.editorBaseUrl = value
            if (key === "video_enabled")
                root._videoEnabled = (value === "true")
        }
        function onProcessVideoReady(sid, videoUrl) {
            if (sid === root.sessionId && videoUrl && videoUrl !== "")
                root.videoPath = videoUrl
        }
    }

    function toUrl(p) {
        if (!p || p === "") return ""
        if (p.startsWith("file:") || p.startsWith("qrc:") || p.startsWith("http")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    function _photoPath(item) {
        if (!item) return ""
        if (typeof item === "string") return item
        if (item.path !== undefined) return item.path
        if (item.filePath !== undefined) return item.filePath
        if (item.displayPath !== undefined) return item.displayPath
        if (item.url !== undefined) return item.url
        return ""
    }

    function _pushUnique(list, value) {
        if (!value || value === "") return
        for (var i = 0; i < list.length; i++) {
            if (list[i] === value) return
        }
        list.push(value)
    }

    function _refreshGridSources() {
        var source = []
        var raw = root.photos || []
        for (var i = 0; i < raw.length; i++)
            root._pushUnique(source, root._photoPath(raw[i]))
        root._pushUnique(source, root._displaySource)
        root._pushUnique(source, root.collagePath)

        for (var j = source.length - 1; j > 0; j--) {
            var k = Math.floor(Math.random() * (j + 1))
            var tmp = source[j]
            source[j] = source[k]
            source[k] = tmp
        }

        if (source.length === 0) {
            root._gridSources = []
            return
        }

        var picked = []
        for (var n = 0; n < 16; n++)
            picked.push(source[n % source.length])
        root._gridSources = picked
    }

    function _gridSource(index) {
        if (!root._gridSources || root._gridSources.length === 0) return ""
        return root._gridSources[index % root._gridSources.length]
    }

    function _startCountdownIfNeeded() {
        if (root._paymentEnabled && !countdownTimer.running)
            countdownTimer.start()
    }

    onPhotosChanged: _refreshGridSources()
    onDisplayPathChanged: _refreshGridSources()
    onCollagePathChanged: _refreshGridSources()

    Component.onCompleted: {
        root._requestGalleryLink()
        root._refreshGridSources()
        root._startCountdownIfNeeded()
        // Trả "" khi chưa encode xong → chờ signal processVideoReady ở trên.
        if (root._videoEnabled && root.eventId > 0 && root.sessionId !== "")
            root.videoPath = eventManager.getSessionVideoPath(root.eventId, root.sessionId)
    }

    // ── Background ─────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#F8F0E7"
    }
    BackgroundMedia {
        anchors.fill: parent
        visible: root.backgroundImagePath !== ""
        sourcePath: root.backgroundImagePath
    }
    Rectangle {
        anchors.fill: parent
        color: "#FFF7EB"
        opacity: 0.50
    }

    // ── Đếm ngược (chế độ thanh toán) ─────────────────────────
    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: root.portrait ? 18 : 40
        anchors.topMargin: root.portrait ? 14 : 24
        width: root.portrait ? 78 : 90
        height: root.portrait ? 48 : 54
        radius: height / 2
        visible: root._paymentEnabled
        color: "#FFF8EA"
        border.color: root._line
        border.width: 1
        z: 20

        Text {
            anchors.centerIn: parent
            text: root.resultCountdownTime + "s"
            color: root._copperDark
            font.pixelSize: root.portrait ? 24 : 28
            font.bold: true
        }
    }

    Column {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.portrait ? 38 : 30
        spacing: root.portrait ? 10 : 8
        z: 5

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 74, root.portrait ? 560 : 900)
            text: "Ảnh đã sẵn sàng"
            color: root._copperDark
            font.pixelSize: root.portrait ? 23 : 23
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 64, root.portrait ? 560 : 920)
            text: "Quét QR để tải ảnh"
            color: root._ink
            font.pixelSize: root.portrait ? 54 : 58
            font.bold: true
            lineHeight: 0.94
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            style: Text.Outline
            styleColor: "#24FFFFFF"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 82, root.portrait ? 540 : 760)
            text: "Mở camera điện thoại, quét mã và tải toàn bộ ảnh trong lượt chụp này."
            color: root._muted
            font.pixelSize: root.portrait ? 20 : 21
            lineHeight: 1.12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width - 82, 720)
            visible: root._showVideo
            text: "Video hậu trường sẽ nằm trong album sau khi xử lý xong."
            color: root._copperDark
            font.pixelSize: root.portrait ? 16 : 18
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    GridLayout {
        id: resultGrid
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: header.bottom
        anchors.bottom: bottomBar.top
        anchors.leftMargin: root.portrait ? 28 : 64
        anchors.rightMargin: root.portrait ? 28 : 64
        anchors.topMargin: root.portrait ? 18 : 22
        anchors.bottomMargin: root.portrait ? 14 : 18
        columns: root.portrait ? 1 : 2
        rowSpacing: root.portrait ? 26 : 0
        columnSpacing: root.portrait ? 0 : 64
        z: 2

        Rectangle {
            id: photoGridCard
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: root._gridPanelW
            Layout.preferredHeight: root._gridPanelH
            radius: root.portrait ? 26 : 28
            color: "#FFFDF7"
            border.color: "#FFFFFF"
            border.width: 1
            clip: true

            Item {
                id: photoGrid
                width: root._gridInner
                height: root._gridInner
                anchors.centerIn: parent
                visible: root._gridSources.length > 0

                Repeater {
                    model: root._gridSources.length > 0 ? 16 : 0
                    delegate: Rectangle {
                        readonly property int col: index % 4
                        readonly property int row: Math.floor(index / 4)
                        x: col * (root._gridCell + root._gridGap)
                        y: row * (root._gridCell + root._gridGap)
                        width: root._gridCell
                        height: root._gridCell
                        radius: root.portrait ? 8 : 10
                        color: "#F2E7DC"
                        border.color: "#FFFFFF"
                        border.width: 1
                        clip: true
                        antialiasing: true

                        Image {
                            anchors.fill: parent
                            source: root.toUrl(root._gridSource(index))
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            smooth: true
                            sourceSize: Qt.size(720, 720)
                        }
                    }
                }
            }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 80, 320)
                height: 112
                radius: 24
                visible: root._gridSources.length === 0
                color: root._paper
                border.color: root._line

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 36
                    text: "Ảnh đang được chuẩn bị"
                    color: root._muted
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            id: qrCard
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            Layout.preferredWidth: root._qrCardW
            Layout.preferredHeight: root._qrCardH
            radius: root.portrait ? 28 : 30
            color: root._panel
            border.color: root._line
            border.width: 1
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: root.portrait ? 6 : 7
                color: root._copper
                opacity: 0.72
            }

            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 18
                anchors.topMargin: 18
                width: root.portrait ? 36 : 40
                height: width
                radius: width / 2
                color: root._paper
                border.color: root._line

                Text {
                    anchors.centerIn: parent
                    text: "QR"
                    color: root._copperDark
                    font.pixelSize: root.portrait ? 13 : 14
                    font.bold: true
                }
            }

            Column {
                anchors.fill: parent
                anchors.margins: root.portrait ? 26 : 22
                spacing: root.portrait ? 16 : 12

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: root._qrSide
                    height: width
                    radius: root.portrait ? 18 : 20
                    color: "#FFFFFF"
                    border.color: "#EADCCC"
                    border.width: 1

                    Image {
                        id: qrImage
                        anchors.fill: parent
                        anchors.margins: root.portrait ? 18 : 16
                        source: root.qrImageUrl
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        cache: false
                        smooth: false
                        sourceSize: root.portrait ? Qt.size(960, 960) : Qt.size(640, 640)
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: qrImage.status === Image.Loading || (root.qrImageUrl === "" && !root._galleryLinkFailed)
                        visible: running
                    }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 28
                        visible: root.qrImageUrl === "" && root._galleryLinkFailed
                        text: "Đang kết nối mạng để tạo mã QR…"
                        color: root._muted
                        font.pixelSize: root.portrait ? 14 : 15
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "Album của bạn"
                    color: root._ink
                    font.pixelSize: root.portrait ? 28 : 24
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    text: "Quét mã để mở album: tải ảnh, chọn frame và ghép ảnh ngay trên điện thoại."
                    color: root._muted
                    font.pixelSize: root.portrait ? 17 : 15
                    lineHeight: 1.12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    Item {
        id: bottomBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root._bottomH
        z: 30

        Button {
            id: newRoundBtn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: root.portrait ? 300 : 340
            height: root.portrait ? 62 : 68
            text: "Chụp lượt mới"

            background: Rectangle {
                radius: height / 2
                color: newRoundBtn.down ? "#9F2444" : (newRoundBtn.hovered ? "#D94B70" : "#C8325A")
                border.color: "#FFE1EA"
                border.width: 1
            }
            contentItem: Text {
                text: newRoundBtn.text
                color: "#FFFFFF"
                font.pixelSize: root.portrait ? 20 : 21
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.finished()
        }
    }

    // ── Đếm ngược tự chuyển lượt mới (thanh toán) ──────────────
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.resultCountdownTime--
            if (root.resultCountdownTime <= 0) {
                stop()
                root.finished()
            }
        }
    }
}
