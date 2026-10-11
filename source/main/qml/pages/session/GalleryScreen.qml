import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../utils/Money.js" as Money
import "../../theme"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // ─────────────────────────────────────────────────────────────────────────
    // Public API
    // ─────────────────────────────────────────────────────────────────────────
    property int    eventId:  -1
    property var    eventData: null
    property string hwid:     ""       // needed for QR URL construction
    // Hiện nút X (về CutModeScreen) — chỉ bật khi dùng trong phiên chụp (BoothSession),
    // KHÔNG bật khi nhúng trong SettingsPage.
    property bool   showCloseButton: false

    signal backClicked()
    signal closeClicked()
    signal printRequested(string photoPath)   // caller may override print logic

    // ─────────────────────────────────────────────────────────────────────────
    // Theme (follows ApplicationWindow appBgColor)
    // ─────────────────────────────────────────────────────────────────────────
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    property string backgroundImagePath: eventManager.getAppSetting("global_background_enabled", "false") === "true"
                                         ? eventManager.getAppSetting("global_background_image", "") : ""
    color: backgroundImagePath === "" ? root._themeBg : "transparent"

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
        z: -1
    }

    function toUrl(path) {
        if (!path || path === "") return ""
        if (path.startsWith("file:")) return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    // ── Trạng thái thanh toán Gallery (giữ giữa voucher → thanh toán → in) ──────
    property int    _galleryCopies:      1
    property int    _galleryTotal:       0
    property int    _galleryOriginalTotal: 0
    property bool   _galleryCutMode:     false
    property bool   _galleryPayOn:       false
    property string _galleryVoucherCode: ""   // mã voucher đã áp (trừ một phần) chờ redeem khi thanh toán
    property string _galleryVoucherType: ""
    property int    _galleryVoucherValue: 0

    function _clearGalleryVoucherState() {
        root._galleryVoucherCode = ""
        root._galleryVoucherType = ""
        root._galleryVoucherValue = 0
    }

    function _galleryVoucherRevenueNote(extra) {
        if (root._galleryVoucherCode !== "")
            return "Voucher code: " + root._galleryVoucherCode
        return extra || ""
    }

    // Định tuyến thanh toán cho luồng in từ Gallery (gọi sau khi qua/ bỏ qua voucher).
    function _startGalleryPayment() {
        var total       = root._galleryTotal
        var cashEnabled = eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
        var bankEnabled = eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
        var voucherOn   = eventManager.getAppSetting("voucher_enabled", "false") === "true"
        var vaOn        = eventManager.getAppSetting("payment_va_enabled",  "false") === "true"
        var vaNo        = eventManager.getAppSetting("payment_va_account_no", "")
        var accNo       = (vaOn && vaNo !== "") ? vaNo
                                                : eventManager.getAppSetting("payment_account_no", "")
        var bankId      = eventManager.getAppSetting("payment_bank_id",   "")
        var spKey       = eventManager.getAppSetting("payment_sepay_key", "")
        var bankOk      = bankEnabled && accNo !== "" && bankId !== "" && spKey !== ""

        if (root._galleryPayOn && total > 0 && (cashEnabled || bankOk)) {
            galleryPaymentOverlay.copies     = root._galleryCopies
            galleryPaymentOverlay.totalPrice = total
            galleryPaymentOverlay.isCutMode  = root._galleryCutMode

            if (voucherOn || cashEnabled) {
                galleryPaymentMethodOverlay.open()
            } else {
                galleryPaymentOverlay.cameFromMethod = false
                galleryPaymentOverlay.open()
            }
        } else {
            // Không có thanh toán nào được cấu hình → in thẳng
            root.requestPrint(root._pendingPrintPath)
        }
    }

    // Chuẩn hóa về path local sạch (bỏ prefix file://, URL-decode) —
    // bắt buộc cho printerManager.autoFindAndPrint / tryPrintOnePrinterSilent
    // vì các hàm này dùng QFile::exists()/QImage() trực tiếp, không toLocalFile().
    function cleanLocalPath(p) {
        if (!p || p === "") return ""
        var s = p.toString().replace(/^(file:\/{3})|(file:)/, "")
        if (Qt.platform.os === "windows") s = s.replace(/^(file:\/\/\/)/, "")
        return decodeURIComponent(s)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Internal state
    // ─────────────────────────────────────────────────────────────────────────
    property bool   isLoading:     false
    property var    allPhotos:     []       // raw from DB — all types
    property var    selectedPhoto: null     // currently focused photo object
    property bool   isPrinting:    false
    property string printMessage:  ""
    property string photoFilter:   "all"   // "all" | "collage" | "original"

    // Print options state
    property int    printCopies:   1        // số bản in người dùng chọn (1–5)
    property bool   printCutMode:  false    // trạng thái cắt người dùng chọn
    property string _pendingPrintPath: ""   // đường dẫn ảnh cần in (set trước khi mở dialog)
    property bool   _autoScanActive: false  // đang trong quá trình auto-scan tìm máy in

    // Computed filtered list — reactive on allPhotos + photoFilter
    property var filteredPhotos: {
        if (photoFilter === "collage")
            return allPhotos.filter(function(p) { return p.type === "collage" })
        if (photoFilter === "original")
            return allPhotos.filter(function(p) { return p.type === "original" })
        return allPhotos
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Init
    // ─────────────────────────────────────────────────────────────────────────
    Component.onCompleted: loadPhotos()

    function loadPhotos() {
        isLoading = true
        loadTimer.restart()
    }

    // Defer the DB call by one frame so isLoading=true renders before the
    // synchronous C++ call blocks the main thread.
    Timer {
        id: loadTimer
        interval: 16
        onTriggered: {
            allPhotos = eventManager.getEventPhotos(root.eventId)
            isLoading = false
            console.log("GalleryScreen: Loaded", allPhotos.length, "photos for event", root.eventId)
        }
    }

    function buildQrUrl(sessionId) {
        if (!sessionId || !root.hwid || root.eventId < 0) return ""
        var link = s3Uploader.buildSessionUrl(root.hwid, root.eventId, sessionId)
        return "image://qr/" + encodeURIComponent(link)
    }

    function buildPhotoUrl(sessionId) {
        if (!sessionId || !root.hwid || root.eventId < 0) return ""
        return s3Uploader.buildSessionUrl(root.hwid, root.eventId, sessionId)
    }

    // Trước khi gửi lệnh in, cho chọn máy in. Dialog chọn xong sẽ gọi doprint().
    function requestPrint(photoPath) {
        root._pendingPrintPath = photoPath
        printerPickDialog.openFor(photoPath)
    }

    function doprint(photoPath) {
        console.log("GalleryScreen: Print with options →", photoPath,
                    "copies:", root.printCopies, "cut:", root.printCutMode)
        root.isPrinting = true
        root.printMessage = ""
        eventManager.printPhotoFromGalleryWithOptions(
            root.eventId, photoPath,
            root.printCopies, root.printCutMode
        )
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Print feedback + auto-scan khi máy in không phản hồi
    // ─────────────────────────────────────────────────────────────────────────
    Connections {
        target: printerManager

        function onPrintFinished(success, message) {
            if (!success && !root._autoScanActive) {
                // Lần in đầu thất bại → kích auto-scan, không hiện lỗi ngay
                root._autoScanActive = true
                printerManager.autoFindAndPrint(
                    root._pendingPrintPath,
                    root.printCopies,
                    root.printCutMode,
                    300)
                return
            }

            // Kết quả cuối (sau auto-scan hoặc in thành công ngay lần đầu)
            root.isPrinting = false
            root._autoScanActive = false
            autoScanPopupCloseTimer.start()

            root.printMessage = success ? "✅ " + message : "❌ " + message

            if (success && root.eventId > 0) {
                var actualPhotoCount = eventManager.getLastGalleryPrintPhotoCount()
                if (actualPhotoCount > 0) {
                    var wasCut = eventManager.getLastGalleryPrintCutMode()
                    eventManager.incrementPrintCount(root.eventId, actualPhotoCount, wasCut)
                }
            }
            printMsgTimer.restart()
        }

        function onErrorOccurred(error) {
            root.isPrinting = false
            root._autoScanActive = false
            galleryAutoScanPopup.visible = false
            root.printMessage = "❌ " + error
            printMsgTimer.restart()
        }

        function onAutoPrintScanStarted() {
            galleryAutoScanPopup.visible = true
            galleryAutoScanStatus.text = "Đang quét máy in..."
        }

        function onAutoPrintScanProgress(message) {
            galleryAutoScanStatus.text = message
        }

        function onAutoPrintScanFinished(success, printerName) {
            if (success) {
                galleryAutoScanStatus.text = "Đang in ảnh..."
                // Lưu máy in vào database để dùng lâu dài
                printerConfig.saveGlobal()
            } else {
                galleryAutoScanPopup.visible = false
            }
        }
    }

    Timer { id: printMsgTimer; interval: 3500; onTriggered: root.printMessage = "" }

    Timer {
        id: autoScanPopupCloseTimer
        interval: 1500
        repeat: false
        onTriggered: galleryAutoScanPopup.visible = false
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Background
    // ─────────────────────────────────────────────────────────────────────────
    // Color set above

    // =========================================================================
    // GRID VIEW  (always rendered beneath the detail overlay)
    // =========================================================================
    ColumnLayout {
        id: gridLayout
        anchors.fill: parent
        anchors.margins: 30
        spacing: 20

        // ── Header ────────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14

            // Row 1: Back / Title / Reload / Count
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                spacing: 20

                // Back button
                Button {
                    id: backBtn
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 56
                    background: Rectangle {
                        color: backBtn.hovered ? "#FFFFFF" : "#FFFFFF"
                        radius: 14
                        border.color: Theme.border; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: RowLayout {
                        spacing: 6
                        Text { text: "←"; color: "white"; font.pixelSize: 22 }
                        Text { text: "Quay Lại"; color: "white"; font.pixelSize: 15; font.bold: true }
                    }
                    onClicked: root.backClicked()
                }

                // Title
                Text {
                    text: "Thư Viện Ảnh"
                    color: "#000000"
                    font.pixelSize: 38
                    font.weight: Font.Bold
                    Layout.fillWidth: true
                }

                // Reload button
                Button {
                    id: reloadBtn
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56
                    background: Rectangle {
                        color: reloadBtn.hovered ? "#FFFFFF" : "#FFFFFF"
                        radius: 12
                        border.color: Theme.border; border.width: 1
                    }
                    contentItem: Text { text: "🔄"; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    onClicked: root.loadPhotos()
                }

                // Count badge
                Rectangle {
                    Layout.preferredWidth: 140
                    Layout.preferredHeight: 56
                    color: Theme.field
                    radius: 14
                    border.color: Theme.border; border.width: 1
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "🖼️"; font.pixelSize: 20 }
                        Text {
                            text: root.filteredPhotos.length + " / " + root.allPhotos.length + " ảnh"
                            color: Theme.textMuted; font.pixelSize: 14; font.bold: true
                        }
                    }
                }
            } // Row 1

            // Row 2: Filter tabs
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                spacing: 12

                Repeater {
                    model: [
                        { label: "Tất Cả",    icon: "📋", key: "all" },
                        { label: "Collage",   icon: "🖼️", key: "collage" },
                        { label: "Ảnh Lẻ",   icon: "📸", key: "original" }
                    ]

                    delegate: Button {
                        property bool isActive: root.photoFilter === modelData.key

                        Layout.preferredHeight: 46
                        Layout.preferredWidth: {
                            // count per type for badge
                            if (modelData.key === "all")      return 140
                            if (modelData.key === "collage")  return 140
                            return 140
                        }

                        background: Rectangle {
                            color:  isActive ? "#1e7eea" : (parent.hovered ? "#FFFFFF" : Theme.field)
                            radius: 12
                            border.color: isActive ? "#1e7eea" : Theme.border
                            border.width: isActive ? 0 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        contentItem: RowLayout {
                            spacing: 6
                            anchors.centerIn: parent
                            Text { text: modelData.icon; font.pixelSize: 15 }
                            Text {
                                text: modelData.label + " (" + {
                                    "all":      root.allPhotos.length,
                                    "collage":  root.allPhotos.filter(function(p){ return p.type==="collage" }).length,
                                    "original": root.allPhotos.filter(function(p){ return p.type==="original" }).length
                                }[modelData.key] + ")"
                                color: "white"
                                font.pixelSize: 14; font.bold: isActive
                            }
                        }

                        onClicked: root.photoFilter = modelData.key
                    }
                }

                // Spacer so tabs stay left-aligned
                Item { Layout.fillWidth: true }
            } // Row 2 filter tabs
        } // ColumnLayout header

        // ── Content area ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Loading
            Column {
                anchors.centerIn: parent
                spacing: 18
                visible: root.isLoading
                BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: root.isLoading }
                Text { text: "Đang tải ảnh..."; color: Theme.textMuted; font.pixelSize: 18 }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 18
                visible: !root.isLoading && root.filteredPhotos.length === 0
                Text { text: "🖼️"; font.pixelSize: 80; anchors.horizontalCenter: parent.horizontalCenter; opacity: 0.35 }
                Text { text: "Chưa có ảnh nào"; color: "#000000"; font.pixelSize: 26; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: "Hãy chụp ảnh đầu tiên của bạn!"; color: Theme.textMuted; font.pixelSize: 17; anchors.horizontalCenter: parent.horizontalCenter }
            }

            // Grid
            GridView {
                id: photoGrid
                anchors.fill: parent
                visible: !root.isLoading && root.filteredPhotos.length > 0
                cellWidth: 270; cellHeight: 270
                clip: true

                model: root.filteredPhotos

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 6; radius: 3; color: parent.pressed ? "#999" : "#444"; opacity: parent.active ? 1 : 0.5 }
                }

                delegate: Item {
                    width: photoGrid.cellWidth
                    height: photoGrid.cellHeight

                    // Is this card the selected one?
                    property bool isSelected: root.selectedPhoto !== null && root.selectedPhoto.id === modelData.id

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        anchors.margins: 12
                        color: Theme.field
                        radius: 16
                        clip: true

                        // Border: selected = glow amber, hover = blue, default = subtle
                        border.color: isSelected
                            ? "#f59e0b"
                            : (cardMouse.containsMouse ? "#1e7eea" : Theme.field)
                        border.width: isSelected ? 3 : (cardMouse.containsMouse ? 2 : 1)

                        scale: cardMouse.containsMouse && !isSelected ? 1.04 : 1.0
                        Behavior on scale       { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation  { duration: 120 } }
                        Behavior on border.width { NumberAnimation { duration: 120 } }

                        // Thumbnail
                        Image {
                            id: thumbImg
                            anchors.fill: parent
                            source: toUrl(modelData.filePath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            // Decode at thumbnail size — Qt uses libjpeg's built-in
                            // downscaling, loading ~16× less data than full-res.
                            sourceSize.width:  270
                            sourceSize.height: 270

                            BusyIndicator {
                                anchors.centerIn: parent
                                running: thumbImg.status === Image.Loading
                                visible: running
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "❌"
                                font.pixelSize: 44
                                visible: thumbImg.status === Image.Error
                                opacity: 0.5
                            }
                        }

                        // Bottom info strip
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left:   parent.left
                            anchors.right:  parent.right
                            height: 38
                            gradient: Gradient {
                                GradientStop { position: 0; color: "transparent" }
                                GradientStop { position: 1; color: "#cc000000" }
                            }
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4
                                Text { text: "🕐"; font.pixelSize: 12; opacity: 0.7 }
                                Text {
                                    text: {
                                        var d = new Date(modelData.createdAt)
                                        return Qt.formatDateTime(d, "dd/MM HH:mm")
                                    }
                                    color: Theme.textMuted; font.pixelSize: 12
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                // QR available indicator
                                Rectangle {
                                    width: 20; height: 20; radius: 4
                                    color: (modelData.sessionId && modelData.sessionId !== "") ? "#22c55e" : Theme.textMuted
                                    Text { text: "Q"; anchors.centerIn: parent; color: "white"; font.pixelSize: 10; font.bold: true }
                                }
                            }
                        }

                        // Selected glow ring
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            radius: parent.radius
                            border.color: "#f59e0b"
                            border.width: isSelected ? 3 : 0
                            opacity: 0.6
                            Behavior on border.width { NumberAnimation { duration: 150 } }
                        }

                        // Press ripple
                        Rectangle {
                            anchors.fill: parent
                            color: "#1e7eea"
                            opacity: cardMouse.pressed ? 0.18 : 0
                            radius: parent.radius
                            Behavior on opacity { NumberAnimation { duration: 80 } }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selectedPhoto = modelData
                            }
                        }
                    }
                }
            } // GridView
        } // Content Item
    } // ColumnLayout (grid)

    // =========================================================================
    // DETAIL OVERLAY  – slides in / fades when a photo is selected
    // =========================================================================
    Rectangle {
        id: detailOverlay
        anchors.fill: parent
        visible: opacity > 0
        opacity: root.selectedPhoto !== null ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        // Dark glass background
        color: "#e9101318"

        // ── Computed session photos (all photos sharing the same sessionId) ──
        property var sessionPhotos: {
            if (!root.selectedPhoto || !root.allPhotos) return []
            var sid = root.selectedPhoto.sessionId
            if (!sid || sid === "") return []
            return root.allPhotos.filter(function(p) { return p.sessionId === sid })
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── Header bar ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 62
                color: Qt.rgba(0, 0, 0, 0.65)

                RowLayout {
                    anchors { fill: parent; leftMargin: 24; rightMargin: 16 }
                    spacing: 16

                    // Back to list
                    Rectangle {
                        id: detailBackBtn
                        width: detailBackBtnRow.implicitWidth + 28; height: 40; radius: 10
                        color: detailBackBtnMA.containsMouse ? Theme.border : Theme.field
                        border.color: Theme.border; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        RowLayout {
                            id: detailBackBtnRow
                            anchors.centerIn: parent; spacing: 8
                            Text { text: "←"; color: Theme.textMuted; font.pixelSize: 16; font.bold: true }
                            Text { text: "Danh Sách Ảnh"; color: Theme.textMuted; font.pixelSize: 14 }
                        }
                        MouseArea {
                            id: detailBackBtnMA
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedPhoto = null
                        }
                    }

                    // Title — shows photo type + timestamp
                    Text {
                        Layout.fillWidth: true
                        text: root.selectedPhoto
                              ? (root.selectedPhoto.type === "collage" ? "🖼️  Ảnh Collage" : "📷  Ảnh Gốc")
                                + "  •  "
                                + Qt.formatDateTime(new Date(root.selectedPhoto.createdAt), "dd/MM/yyyy  HH:mm:ss")
                              : ""
                        color: Theme.textMuted; font.pixelSize: 15; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                    }

                    // Close ✕
                    Button {
                        Layout.preferredWidth:  60
                        Layout.preferredHeight: 60
                        Layout.alignment: Qt.AlignRight
                        background: Rectangle {
                            color: parent.hovered ? "#ff4757" : "#2b3040"
                            radius: 30
                            border.color: parent.hovered ? "#ff4757" : "#5a6070"; border.width: 2
                        }
                        contentItem: Text {
                            text: "✕"
                            color: "white"
                            font.pixelSize: 26; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment:   Text.AlignVCenter
                        }
                        onClicked: root.selectedPhoto = null
                    }
                }
            }

            // ── Main content area ────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 20
                spacing: 20

                // ── LEFT: Large photo + print bar ────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 14

                    // Photo frame
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#0a0b0f"; radius: 16
                        border.color: "#f59e0b"; border.width: 2
                        clip: true

                        Image {
                            id: detailImg
                            anchors.fill: parent; anchors.margins: 3
                            source: root.selectedPhoto ? toUrl(root.selectedPhoto.filePath) : ""
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            // cache:false — ảnh xem chi tiết gallery có path khác nhau
                            // mỗi lần chọn. cache:true sẽ giữ từng ảnh ~6.5MB trong
                            // QQuickPixmapCache → phình RAM khi xem nhiều ảnh.
                            cache: false
                            // Cap decode size — 1280 đủ nét cho khung xem, giảm ~56%
                            // RAM/ảnh so với 1920 (6.5MB → 2.9MB).
                            sourceSize.width:  1280
                            sourceSize.height: 1280
                            BusyIndicator {
                                anchors.centerIn: parent
                                running: detailImg.status === Image.Loading
                                visible: running
                            }
                        }

                        // Type badge (top-left)
                        Rectangle {
                            anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 12
                            width: typeBadgeRow.implicitWidth + 18; height: 30
                            color: root.selectedPhoto && root.selectedPhoto.type === "collage" ? "#7c3aed" : "#1e7eea"
                            radius: 8
                            RowLayout {
                                id: typeBadgeRow; anchors.centerIn: parent; spacing: 6
                                Text { text: root.selectedPhoto && root.selectedPhoto.type === "collage" ? "🖼️" : "📷"; font.pixelSize: 12 }
                                Text {
                                    text: root.selectedPhoto && root.selectedPhoto.type === "collage" ? "Collage" : "Original"
                                    color: "white"; font.pixelSize: 12; font.bold: true
                                }
                            }
                        }

                        // Timestamp badge (top-right)
                        Rectangle {
                            anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 12
                            width: tsRow.implicitWidth + 18; height: 30; color: "#cc000000"; radius: 8
                            RowLayout {
                                id: tsRow; anchors.centerIn: parent; spacing: 6
                                Text { text: "🕐"; font.pixelSize: 12 }
                                Text {
                                    text: root.selectedPhoto
                                          ? Qt.formatDateTime(new Date(root.selectedPhoto.createdAt), "dd/MM/yyyy  HH:mm:ss")
                                          : ""
                                    color: Theme.textMuted; font.pixelSize: 12
                                }
                            }
                        }
                    }

                    // ── Print Bar ───────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14

                        // Status message
                        Rectangle {
                            Layout.fillWidth: true; height: 52
                            visible: root.printMessage !== ""
                            color: root.printMessage.startsWith("✅") ? "#163a20" : "#3a1616"
                            radius: 12
                            border.color: root.printMessage.startsWith("✅") ? "#22c55e" : "#ef4444"
                            border.width: 1
                            Text {
                                anchors.centerIn: parent; text: root.printMessage
                                color: "white"; font.pixelSize: 15; font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                        Item { Layout.fillWidth: true; visible: root.printMessage === "" }

                        // ── Nút In Ảnh Này → mở dialog ──────────────────────────
                        Rectangle {
                            id: printBtnRect
                            width: 220; height: 52; radius: 14
                            enabled: root.selectedPhoto !== null && !root.isPrinting
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: printBtnRect.enabled ? (printBtnMA2.containsMouse ? "#4ade80" : "#22c55e") : "#444"
                                }
                                GradientStop {
                                    position: 1
                                    color: printBtnRect.enabled ? (printBtnMA2.containsMouse ? "#22c55e" : "#16a34a") : "#333"
                                }
                            }
                            RowLayout {
                                anchors.centerIn: parent; spacing: 10
                                BusyIndicator {
                                    Layout.preferredWidth: 26; Layout.preferredHeight: 26
                                    running: root.isPrinting; visible: root.isPrinting
                                }
                                Text {
                                    text: root.isPrinting ? "Đang in..." : "🖨️  In Ảnh Này"
                                    color: "white"; font.pixelSize: 18; font.bold: true
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                            MouseArea {
                                id: printBtnMA2
                                anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: printBtnRect.enabled
                                onClicked: {
                                    if (root.selectedPhoto) {
                                        root._pendingPrintPath = cleanLocalPath(root.selectedPhoto.filePath)
                                        galleryPrintDialog.openDialog()
                                    }
                                }
                            }
                        }
                    } // Print bar RowLayout
                } // LEFT ColumnLayout

                // ── RIGHT: QR + session photos ───────────────────────────────
                ColumnLayout {
                    Layout.preferredWidth: 370
                    Layout.fillHeight: true
                    spacing: 16

                    // QR section header
                    Text {
                        text: "📱 Mã QR Nhận Ảnh"
                        color: "white"; font.pixelSize: 16; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    // QR Code box
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 250; height: 250; radius: 16; color: "white"

                        // No sessionId → placeholder
                        Column {
                            anchors.centerIn: parent; spacing: 10
                            visible: !root.selectedPhoto || !root.selectedPhoto.sessionId || root.selectedPhoto.sessionId === ""
                            Text { text: "⏳"; font.pixelSize: 44; anchors.horizontalCenter: parent.horizontalCenter }
                            Text {
                                text: "QR chưa có\n(ảnh chưa upload)"
                                color: "#888"; font.pixelSize: 13
                                horizontalAlignment: Text.AlignHCenter
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }

                        Image {
                            id: qrImg
                            anchors.fill: parent; anchors.margins: 12
                            visible: root.selectedPhoto && root.selectedPhoto.sessionId && root.selectedPhoto.sessionId !== ""
                            source: visible ? root.buildQrUrl(root.selectedPhoto.sessionId) : ""
                            fillMode: Image.PreserveAspectFit; smooth: false; cache: false; asynchronous: true
                            BusyIndicator { anchors.centerIn: parent; running: qrImg.status === Image.Loading; visible: running }
                            Text {
                                anchors.centerIn: parent; text: "❌ Không tải được QR"
                                color: "#888"; font.pixelSize: 12
                                visible: qrImg.status === Image.Error
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }

                    // URL link
                    Rectangle {
                        Layout.fillWidth: true; height: 38; radius: 10
                        color: Theme.surface; border.color: Theme.border; border.width: 1
                        visible: root.selectedPhoto && root.selectedPhoto.sessionId && root.selectedPhoto.sessionId !== ""
                        Text {
                            anchors.centerIn: parent; width: parent.width - 20
                            text: root.selectedPhoto ? root.buildPhotoUrl(root.selectedPhoto.sessionId) : ""
                            color: "#1e7eea"; font.pixelSize: 11
                            elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // ── Session photos separator ─────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true; spacing: 8
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#2e3340" }
                        Text { text: "Ảnh cùng phiên"; color: Theme.textMuted; font.pixelSize: 12 }
                        Rectangle { Layout.fillWidth: true; height: 1; color: "#2e3340" }
                    }

                    // ── Session photos ListView (scrollable) ─────────────────
                    ListView {
                        id: sessionStrip
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        model: detailOverlay.sessionPhotos
                        spacing: 8

                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        delegate: Rectangle {
                            id: sessionThumbItem
                            width: sessionStrip.width; height: 80
                            radius: 10
                            color: modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "")
                                   ? "#1e3a5f" : "#1a1e28"
                            border.color: modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "")
                                          ? "#1e7eea" : Theme.field
                            border.width: modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "") ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            clip: true

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 8; spacing: 10

                                // Thumbnail image
                                Rectangle {
                                    width: 64; height: 64; radius: 8; color: "#0a0b0f"; clip: true
                                    Image {
                                        anchors.fill: parent
                                        source: toUrl(modelData.filePath)
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true; cache: true
                                        sourceSize.width:  64
                                        sourceSize.height: 64
                                    }
                                }

                                // Info
                                ColumnLayout {
                                    Layout.fillWidth: true; Layout.fillHeight: true; spacing: 4
                                    Text {
                                        text: modelData.type === "collage"
                                              ? "🖼️  Collage"
                                              : "📷  Ảnh gốc #" + (index + 1)
                                        color: modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "")
                                               ? "#4fc3f7" : Theme.border
                                        font.pixelSize: 13; font.bold: true
                                        elide: Text.ElideRight
                                    }
                                    Text {
                                        text: Qt.formatDateTime(new Date(modelData.createdAt), "HH:mm:ss")
                                        color: Theme.textMuted; font.pixelSize: 11
                                    }
                                }

                                // Selected indicator
                                Rectangle {
                                    width: 6; height: 40; radius: 3
                                    color: modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "")
                                           ? "#1e7eea" : "transparent"
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: root.selectedPhoto = modelData
                                onEntered: sessionThumbItem.color = modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "")
                                           ? "#1e3a5f" : "#22273a"
                                onExited: sessionThumbItem.color = modelData.filePath === (root.selectedPhoto ? root.selectedPhoto.filePath : "")
                                          ? "#1e3a5f" : "#1a1e28"
                            }
                        }
                    } // sessionStrip ListView
                } // RIGHT ColumnLayout
            } // RowLayout (main content)
        } // ColumnLayout (root of overlay)
    } // detailOverlay

    // =========================================================================
    // Auto-scan popup — hiện khi máy in mặc định không phản hồi / offline
    // =========================================================================
    Rectangle {
        id: galleryAutoScanPopup
        anchors.fill: parent
        color: "#BB000000"
        visible: false
        z: 4000

        MouseArea { anchors.fill: parent }

        Rectangle {
            anchors.centerIn: parent
            width: 500
            height: 280
            color: Theme.field
            radius: 20
            border.color: Theme.textMuted
            border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 22

                // Spinner quay
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 54; height: 54; radius: 27
                    color: "transparent"
                    border.color: "#1e7eea"; border.width: 4
                    RotationAnimator on rotation {
                        running: galleryAutoScanPopup.visible
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }

                Text {
                    text: "Vui lòng chờ"
                    color: "#ffffff"
                    font.pixelSize: 26
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    id: galleryAutoScanStatus
                    text: "Đang kiểm tra máy in..."
                    color: Theme.textMuted
                    font.pixelSize: 15
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // =========================================================================
    // Back button from detail (escape key / swipe down)
    // =========================================================================
    Keys.onEscapePressed: {
        if (root.selectedPhoto !== null) {
            root.selectedPhoto = null
        } else {
            root.backClicked()
        }
    }

    // =========================================================================
    // Print Dialog
    // =========================================================================
    Rectangle {
        id: galleryPrintDialog
        anchors.fill: parent
        visible: false
        color: "#BB000000"
        z: 2000

        property bool  dlgCut:    false

        // ── Payment settings (đọc 1 lần khi mở dialog) ──────────────────────
        property bool paymentEnabled: false

        // ── Lựa chọn in cố định theo chế độ cắt (đồng bộ với Cài đặt) ────────
        // Mỗi phần tử: { qty: số ảnh, price: giá cố định } — giống PrintQuantityScreen.
        property var printOptions: []
        property int selIndex: 0

        // Số ảnh & giá của lựa chọn đang chọn
        property int selPhotos: (printOptions.length > 0 && selIndex < printOptions.length)
                                ? printOptions[selIndex].qty : (dlgCut ? 2 : 1)
        property int selPrice:  (printOptions.length > 0 && selIndex < printOptions.length)
                                ? printOptions[selIndex].price : 0

        // Số bản in thực tế gửi máy (cắt: 2 ảnh = 1 bản)
        property int printBans: dlgCut ? Math.round(selPhotos / 2) : selPhotos
        // Tổng tiền = giá cố định của lựa chọn
        property int totalPrice: selPrice

        // Đọc danh sách lựa chọn in theo chế độ cắt hiện tại (mô phỏng
        // PrintQuantityScreen: 4 lựa chọn mặc định + lựa chọn 5 nếu được bật).
        function loadOptions() {
            var defJson = dlgCut
                ? '[{"qty":2,"price":0},{"qty":4,"price":0},{"qty":6,"price":0},{"qty":8,"price":0},{"qty":10,"price":0}]'
                : '[{"qty":1,"price":0},{"qty":2,"price":0},{"qty":3,"price":0},{"qty":4,"price":0},{"qty":5,"price":0}]'
            var optKey = dlgCut ? "print_options_cut"  : "print_options_nocut"
            var en5Key = dlgCut ? "print_option4_cut_enabled" : "print_option4_nocut_enabled"
            var arr = []
            try { arr = JSON.parse(eventManager.getAppSetting(optKey, defJson)) }
            catch (e) { arr = JSON.parse(defJson) }
            if (!Array.isArray(arr) || arr.length === 0) arr = JSON.parse(defJson)
            // Pad đủ 5 phần tử bằng mặc định — tránh setting cũ thiếu phần tử
            var defArr = JSON.parse(defJson)
            while (arr.length < 5)
                arr.push(arr.length < defArr.length ? defArr[arr.length] : { qty: 1, price: 0 })
            var opts = arr.slice(0, 4)
            if (eventManager.getAppSetting(en5Key, "false") === "true" && arr.length >= 5)
                opts.push(arr[4])
            printOptions = opts.map(function(o) {
                return { qty: parseInt(o.qty, 10) || 0, price: parseInt(o.price, 10) || 0 }
            })
            selIndex = 0
        }

        function openDialog() {
            paymentEnabled = eventManager.getAppSetting("payment_enabled", "false") === "true"
            dlgCut    = !!(root.eventData && root.eventData.autoCut)
            loadOptions()
            visible   = true
        }
        function closeDialog() {
            visible = false
        }

        MouseArea { anchors.fill: parent; onClicked: galleryPrintDialog.closeDialog() }

        // ── Dialog box ───────────────────────────────────────────────────────
        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: dlgCol.implicitHeight + 60
            color: Theme.field
            radius: 20
            border.color: "#2a3040"
            border.width: 2

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: dlgCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 30 }
                spacing: 16

                // ── Header ───────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "🖨️  Lựa Chọn In"
                        color: "white"; font.pixelSize: 24; font.bold: true
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: closeDlgMA.containsMouse ? Theme.border : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; color: Theme.textMuted; font.pixelSize: 16 }
                        MouseArea {
                            id: closeDlgMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: galleryPrintDialog.closeDialog()
                        }
                    }
                }

                // ── Preview ảnh ──────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; height: 140
                    color: "#000000"; radius: 10
                    border.color: "#2a3040"; border.width: 1
                    Image {
                        anchors.fill: parent; anchors.margins: 6
                        source: toUrl(root._pendingPrintPath)
                        fillMode: Image.PreserveAspectFit; cache: false
                    }
                }

                // ── Chế độ cắt ──────────────────────────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8

                    Text { text: "Chế độ cắt"; color: Theme.textMuted; font.pixelSize: 13; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10

                        // Không cắt
                        Rectangle {
                            Layout.fillWidth: true; height: 52; radius: 10
                            color: !galleryPrintDialog.dlgCut ? "#0d2a18" : "#151c28"
                            border.color: !galleryPrintDialog.dlgCut ? "#22c55e" : "#252d3a"
                            border.width: !galleryPrintDialog.dlgCut ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter; spacing: 6
                                    Text { text: "▣"; color: !galleryPrintDialog.dlgCut ? "#22c55e" : "#4a6070"; font.pixelSize: 14 }
                                    Text {
                                        text: "Không cắt"
                                        color: !galleryPrintDialog.dlgCut ? "#22c55e" : Theme.textMuted
                                        font.pixelSize: 13; font.bold: true
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { galleryPrintDialog.dlgCut = false; galleryPrintDialog.loadOptions() }
                            }
                        }

                        // Cắt ảnh
                        Rectangle {
                            Layout.fillWidth: true; height: 52; radius: 10
                            color: galleryPrintDialog.dlgCut ? "#2a1800" : "#151c28"
                            border.color: galleryPrintDialog.dlgCut ? "#f59e0b" : "#252d3a"
                            border.width: galleryPrintDialog.dlgCut ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                RowLayout {
                                    Layout.alignment: Qt.AlignHCenter; spacing: 6
                                    Text { text: "✂"; color: galleryPrintDialog.dlgCut ? "#f59e0b" : "#4a6070"; font.pixelSize: 13 }
                                    Text {
                                        text: "Cắt ảnh"
                                        color: galleryPrintDialog.dlgCut ? "#f59e0b" : Theme.textMuted
                                        font.pixelSize: 13; font.bold: true
                                    }
                                }
                            }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: { galleryPrintDialog.dlgCut = true; galleryPrintDialog.loadOptions() }
                            }
                        }
                    }
                }

                // ── Chọn số lượng (lựa chọn cố định, đồng bộ Cài đặt) ─────────
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8

                    Text { text: "Số lượng ảnh in"; color: Theme.textMuted; font.pixelSize: 13; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true; spacing: 10

                        Repeater {
                            model: galleryPrintDialog.printOptions

                            delegate: Rectangle {
                                required property int index
                                required property var modelData
                                property bool sel: index === galleryPrintDialog.selIndex

                                Layout.fillWidth: true
                                height: 72; radius: 10
                                color: sel ? "#0d2238" : "#12151e"
                                border.color: sel ? "#4FA4F2" : Theme.border
                                border.width: sel ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 120 } }

                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 3
                                    Text {
                                        text: modelData.qty + " ảnh"
                                        color: sel ? "#ffffff" : Theme.textMuted
                                        font.pixelSize: 16; font.bold: true
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        visible: galleryPrintDialog.paymentEnabled
                                        text: modelData.price > 0
                                              ? Money.vnd(modelData.price)
                                              : "Miễn phí"
                                        color: sel ? "#4ade80" : "#5a7a5a"
                                        font.pixelSize: 12
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: galleryPrintDialog.selIndex = index
                                }
                            }
                        }
                    }
                }

                // ── Hiển thị giá tiền ─────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; height: 70; radius: 12
                    visible: galleryPrintDialog.paymentEnabled
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#0d1a0d" }
                        GradientStop { position: 1.0; color: "#1a0d00" }
                    }
                    border.color: galleryPrintDialog.totalPrice > 0 ? "#2d6a2d" : Theme.border
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 0

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text {
                                text: galleryPrintDialog.selPhotos + " ảnh · " + galleryPrintDialog.printBans + " bản"
                                color: "#6a8a6a"; font.pixelSize: 12
                            }
                            Text {
                                text: "💳  Thanh toán bắt buộc"
                                color: "#f59e0b"; font.pixelSize: 11
                                visible: galleryPrintDialog.paymentEnabled && galleryPrintDialog.totalPrice > 0
                            }
                        }

                        Text {
                            text: galleryPrintDialog.totalPrice > 0
                                  ? Money.vnd(galleryPrintDialog.totalPrice)
                                  : Money.vnd(0)
                            color: galleryPrintDialog.totalPrice > 0 ? "#4ade80" : "#4a6060"
                            font.pixelSize: 28; font.bold: true
                            Behavior on text { }
                        }
                    }
                }

                // Spacer nhỏ
                Item { height: 4 }

                // ── Nút hành động ────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; spacing: 12

                    // Huỷ
                    Rectangle {
                        Layout.preferredWidth: 120; Layout.preferredHeight: 52; radius: 12
                        color: cancelMA.pressed ? "#7a1a1a"
                             : cancelMA.containsMouse ? "#5a1515" : "#3a1010"
                        border.color: "#6a2020"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent; text: "Huỷ"
                            color: "white"; font.pixelSize: 16; font.bold: true
                        }
                        MouseArea {
                            id: cancelMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: galleryPrintDialog.closeDialog()
                        }
                    }

                    // In Ảnh / Thanh toán
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 12
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop {
                                position: 0.0
                                color: printConfirmMA.pressed ? "#1a60b0"
                                     : printConfirmMA.containsMouse ? "#5BB8FF" : "#4FA4F2"
                            }
                            GradientStop {
                                position: 1.0
                                color: printConfirmMA.pressed ? "#1040a0"
                                     : printConfirmMA.containsMouse ? "#4FA4F2" : "#2D86DE"
                            }
                        }

                        // Glow khi hover
                        Rectangle {
                            anchors.fill: parent; anchors.margins: -3; radius: parent.radius + 3
                            color: "transparent"
                            border.color: Qt.rgba(0.31, 0.64, 0.95, printConfirmMA.containsMouse ? 0.4 : 0.0)
                            border.width: 3
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }

                        RowLayout {
                            anchors.centerIn: parent; spacing: 10
                            Text {
                                text: galleryPrintDialog.paymentEnabled && galleryPrintDialog.totalPrice > 0
                                      ? "💳" : "🖨️"
                                font.pixelSize: 18
                            }
                            Text {
                                text: galleryPrintDialog.paymentEnabled && galleryPrintDialog.totalPrice > 0
                                      ? "Thanh Toán & In"
                                      : "In Ảnh"
                                color: "white"; font.pixelSize: 16; font.bold: true
                            }
                        }

                        MouseArea {
                            id: printConfirmMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var cutMode = galleryPrintDialog.dlgCut
                                var bans    = galleryPrintDialog.printBans   // số bản gửi máy in
                                root.printCopies  = bans
                                root.printCutMode = cutMode
                                galleryPrintDialog.closeDialog()

                                var payOn = galleryPrintDialog.paymentEnabled
                                var total = galleryPrintDialog.totalPrice

                                // Lưu lại để các bước sau dùng
                                root._galleryCopies    = bans
                                root._galleryTotal     = total
                                root._galleryOriginalTotal = total
                                root._galleryCutMode   = cutMode
                                root._galleryPayOn     = payOn

                                // Nếu voucher bật và có thanh toán → hiện màn nhập voucher trước
                                root._clearGalleryVoucherState()
                                root._startGalleryPayment()
                            }
                        }
                    }
                }

                Item { height: 2 }
            }
        }
    } // galleryPrintDialog

    // =========================================================================
    // Voucher Overlay — nhập voucher trước khi thanh toán (in từ Gallery)
    // =========================================================================
    Rectangle {
        id: galleryVoucherOverlay
        anchors.fill: parent
        visible: false
        color: "#F0000000"
        z: 2900

        function open() { visible = true }
        function close() { visible = false }

        MouseArea { anchors.fill: parent }

        Loader {
            anchors.fill: parent
            active: galleryVoucherOverlay.visible

            sourceComponent: Component {
                VoucherScreen {
                    anchors.fill: parent
                    totalPrice:  root._galleryTotal
                    printCopies: root._galleryCopies
                    isCut:       root._galleryCutMode

                    // Voucher phủ đủ số tiền → coi như đã thanh toán → in luôn
                    onVoucherPaid: function(code, amount) {
                        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                        var sid    = root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                        eventManager.logRevenue(root.eventId, evName, sid,
                            root._galleryCopies, root._galleryOriginalTotal, 0, 0, 0, "voucher", "", "reprint",
                            "Voucher code: " + code, amount)
                        eventManager.redeemVoucher(code, sid, amount)
                        root._clearGalleryVoucherState()
                        galleryVoucherOverlay.close()
                        root.requestPrint(root._pendingPrintPath)
                    }

                    // Voucher tiền/giảm giá trừ một phần → cập nhật giá rồi thanh toán phần còn lại.
                    onVoucherApplied: function(code, voucherType, voucherValue) {
                        root._galleryVoucherCode = code
                        root._galleryVoucherType = voucherType
                        root._galleryVoucherValue = voucherValue
                        if (voucherType === "cash" || voucherType === "discount")
                            root._galleryTotal = Math.max(0, root._galleryTotal - voucherValue)
                        else if (voucherType === "print")
                            root._galleryCopies += voucherValue
                        galleryVoucherOverlay.close()
                        root._startGalleryPayment()
                    }

                    // Bỏ qua voucher → tiếp tục luồng thanh toán bình thường
                    onSkipped: {
                        root._clearGalleryVoucherState()
                        galleryVoucherOverlay.close()
                        root._startGalleryPayment()
                    }
                }
            }
        }
    } // galleryVoucherOverlay

    // =========================================================================
    // Cash Payment Overlay — thanh toán tiền mặt qua máy đọc
    // =========================================================================
    Rectangle {
        id: galleryCashOverlay
        anchors.fill: parent
        visible: false
        color: "#F0000000"
        z: 2800

        function open() { visible = true }
        function close() { visible = false }

        MouseArea { anchors.fill: parent }

        Loader {
            anchors.fill: parent
            active: galleryCashOverlay.visible

            sourceComponent: Component {
                CashPaymentScreen {
                    anchors.fill: parent
                    totalPrice: galleryPaymentOverlay.totalPrice

                    onCloseClicked: galleryCashOverlay.close()

                    onPaymentComplete: function(received) {
                        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                        var sid    = root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                        var total  = galleryPaymentOverlay.totalPrice
                        var change = Math.max(0, received - total)
                        eventManager.logRevenue(root.eventId, evName, sid,
                            galleryPaymentOverlay.copies, root._galleryOriginalTotal,
                            received, 0, change, "cash", "", "reprint",
                            root._galleryVoucherRevenueNote(""), root._galleryVoucherValue)
                        if (root._galleryVoucherCode !== "") {
                            eventManager.redeemVoucher(root._galleryVoucherCode, sid)
                            root._clearGalleryVoucherState()
                        }
                        galleryCashOverlay.close()
                        root.requestPrint(root._pendingPrintPath)
                    }
                }
            }
        }
    } // galleryCashOverlay

    // =========================================================================
    // Payment Method Overlay — chọn tiền mặt hoặc chuyển khoản
    // =========================================================================
    Rectangle {
        id: galleryPaymentMethodOverlay
        anchors.fill: parent
        visible: false
        color: "#F0000000"
        z: 2500

        function open() { visible = true }
        function close() { visible = false }

        MouseArea { anchors.fill: parent }

        Loader {
            anchors.fill: parent
            active: galleryPaymentMethodOverlay.visible

            sourceComponent: Component {
                PaymentMethodScreen {
                    anchors.fill: parent
                    totalPrice: galleryPaymentOverlay.totalPrice
                    copies:     galleryPaymentOverlay.copies
                    isCut:      galleryPaymentOverlay.isCutMode
                    // Gallery dùng voucher overlay riêng trước đó → ẩn voucher inline.
                    showVoucher: eventManager.getAppSetting("voucher_enabled", "false") === "true"
                    showCash:    eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
                    showBankTransfer: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
                    cashCodeEnabled: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"

                    onCloseClicked: galleryPaymentMethodOverlay.close()

                    onCashSelected: {
                        galleryPaymentMethodOverlay.close()
                        galleryCashOverlay.open()
                    }

                    onBankTransferSelected: {
                        galleryPaymentMethodOverlay.close()
                        galleryPaymentOverlay.cameFromMethod = true
                        galleryPaymentOverlay.open()
                    }

                    onCashCodePaid: function(code, amount) {
                        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                        var sid    = root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                        eventManager.logRevenue(root.eventId, evName, sid,
                            galleryPaymentOverlay.copies, root._galleryOriginalTotal,
                            amount, 0, 0, "cash", "", "reprint",
                            root._galleryVoucherRevenueNote("Cash code: " + code + "; cash: " + amount),
                            root._galleryVoucherValue)
                        eventManager.redeemCashPaymentCode(code, sid, amount)
                        if (root._galleryVoucherCode !== "") {
                            eventManager.redeemVoucher(root._galleryVoucherCode, sid)
                            root._clearGalleryVoucherState()
                        }
                        galleryPaymentMethodOverlay.close()
                        root.requestPrint(root._pendingPrintPath)
                    }

                    onVoucherApplied: function(code, voucherType, voucherValue) {
                        root._galleryVoucherCode = code
                        root._galleryVoucherType = voucherType
                        root._galleryVoucherValue = voucherValue
                        if (voucherType === "cash" || voucherType === "discount")
                            root._galleryTotal = Math.max(0, root._galleryTotal - voucherValue)
                        else if (voucherType === "print")
                            root._galleryCopies += voucherValue

                        galleryPaymentOverlay.copies     = root._galleryCopies
                        galleryPaymentOverlay.totalPrice = root._galleryTotal
                        galleryPaymentOverlay.isCutMode  = root._galleryCutMode

                        if (root._galleryTotal <= 0) {
                            var sid = root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                            eventManager.redeemVoucher(root._galleryVoucherCode, sid)
                            root._clearGalleryVoucherState()
                            galleryPaymentMethodOverlay.close()
                            root.requestPrint(root._pendingPrintPath)
                        }
                    }

                    onVoucherPaid: function(code, amount) {
                        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                        var sid    = root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                        eventManager.logRevenue(root.eventId, evName, sid,
                            root._galleryCopies, root._galleryOriginalTotal, 0, 0, 0, "voucher", "", "reprint",
                            "Voucher code: " + code, amount)
                        eventManager.redeemVoucher(code, sid, amount)
                        root._clearGalleryVoucherState()
                        galleryPaymentMethodOverlay.close()
                        root.requestPrint(root._pendingPrintPath)
                    }
                }
            }
        }
    } // galleryPaymentMethodOverlay

    // =========================================================================
    // Payment Overlay — hiện toàn màn hình, nhúng PaymentScreen
    // =========================================================================
    Rectangle {
        id: galleryPaymentOverlay
        anchors.fill: parent
        visible: false
        color: "#F0000000"
        z: 3000

        // Thông tin truyền vào PaymentScreen
        property int    unitPrice:  0
        property int    copies:     1
        property int    totalPrice: 0
        property bool   isCutMode:  false
        // true khi mở từ trang chọn phương thức → cho phép nút "Quay lại"
        property bool   cameFromMethod: false

        function open() {
            visible = true
        }
        function close() {
            visible = false
        }

        // Chặn click xuyên
        MouseArea { anchors.fill: parent }

        // ── PaymentScreen inline ─────────────────────────────────────────────
        Loader {
            id: paymentLoader
            anchors.fill: parent
            active: galleryPaymentOverlay.visible

            sourceComponent: Component {
                PaymentScreen {
                    anchors.fill: parent

                    eventId:     root.eventId
                    eventData:   root.eventData
                    slotCount:   1
                    sessionId:   root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                    printCopies: galleryPaymentOverlay.copies
                    // Tổng tiền cố định → QR thu đúng, không nhân số bản
                    directTotalPrice: galleryPaymentOverlay.totalPrice
                    directCutMode: galleryPaymentOverlay.isCutMode ? 1 : 0
                    canGoBack: galleryPaymentOverlay.cameFromMethod

                    onBackClicked: {
                        // Quay về trang chọn phương thức thanh toán
                        galleryPaymentOverlay.close()
                        galleryPaymentMethodOverlay.open()
                    }

                    onPaymentSuccess: {
                        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                        var sid    = root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : ""
                        var total  = galleryPaymentOverlay.totalPrice
                        eventManager.logRevenue(root.eventId, evName, sid,
                            galleryPaymentOverlay.copies, root._galleryOriginalTotal,
                            0, total, 0, "transfer", "", "reprint",
                            root._galleryVoucherRevenueNote(""), root._galleryVoucherValue)
                        if (root._galleryVoucherCode !== "") {
                            eventManager.redeemVoucher(root._galleryVoucherCode, sid)
                            root._clearGalleryVoucherState()
                        }
                        galleryPaymentOverlay.close()
                        root.requestPrint(root._pendingPrintPath)
                    }

                    onPaymentSkipped: {
                        // Payment disabled hoặc giá = 0 → in thẳng
                        if (root._galleryVoucherCode !== "") {
                            eventManager.redeemVoucher(root._galleryVoucherCode,
                                root.selectedPhoto ? (root.selectedPhoto.sessionId || "") : "")
                            root._clearGalleryVoucherState()
                        }
                        galleryPaymentOverlay.close()
                        root.requestPrint(root._pendingPrintPath)
                    }

                    onCloseClicked: {
                        galleryPaymentOverlay.close()
                    }
                }
            }
        }
    } // galleryPaymentOverlay

    // =========================================================================
    // Printer Pick Dialog — chọn máy in trước khi gửi lệnh in
    // =========================================================================
    Rectangle {
        id: printerPickDialog
        anchors.fill: parent
        visible: false
        color: "#BB000000"
        z: 3500

        property var  printers: []
        property string selPrinter: ""
        // Khi switch máy in xong (async) thì mới gửi in
        property bool _printAfterSwitch: false

        function openFor(path) {
            root._pendingPrintPath = path
            selPrinter = printerConfig.selectedPrinter || ""
            // Fallback: hiện ngay máy hiện tại; refresh để cập nhật danh sách đầy đủ
            printers = selPrinter !== "" ? [selPrinter] : []
            printerManager.refreshPrinterListAsync()
            visible = true
        }
        function closeDialog() { visible = false }

        // Thực hiện in: nếu đổi máy → switch async rồi in trong onPrinterSwitchFinished
        function confirmPrint() {
            if (selPrinter !== "" && selPrinter !== printerConfig.selectedPrinter) {
                _printAfterSwitch = true
                printerManager.switchPrinterAsync(selPrinter)
            } else {
                closeDialog()
                root.doprint(root._pendingPrintPath)
            }
        }

        Connections {
            target: printerManager
            function onPrinterListReady(list) {
                if (!printerPickDialog.visible) return
                printerPickDialog.printers = (list && list.length > 0)
                    ? list
                    : (printerPickDialog.selPrinter !== "" ? [printerPickDialog.selPrinter] : [])
            }
            function onPrinterSwitchFinished(success, message) {
                if (!printerPickDialog._printAfterSwitch) return
                printerPickDialog._printAfterSwitch = false
                printerPickDialog.closeDialog()
                // Dù switch thất bại vẫn in bằng máy hiện tại (an toàn, không kẹt luồng)
                root.doprint(root._pendingPrintPath)
            }
        }

        MouseArea { anchors.fill: parent; onClicked: printerPickDialog.closeDialog() }

        Rectangle {
            anchors.centerIn: parent
            width: 520
            height: pickCol.implicitHeight + 60
            color: Theme.field
            radius: 20
            border.color: "#2a3040"
            border.width: 2

            MouseArea { anchors.fill: parent }

            ColumnLayout {
                id: pickCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 30 }
                spacing: 16

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "🖨️  Chọn Máy In"
                        color: "white"; font.pixelSize: 24; font.bold: true
                        Layout.fillWidth: true
                    }
                    Rectangle {
                        width: 32; height: 32; radius: 16
                        color: closePickMA.containsMouse ? Theme.border : "transparent"
                        Text { anchors.centerIn: parent; text: "✕"; color: Theme.textMuted; font.pixelSize: 16 }
                        MouseArea {
                            id: closePickMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: printerPickDialog.closeDialog()
                        }
                    }
                }

                // Danh sách máy in
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8

                    Repeater {
                        model: printerPickDialog.printers
                        delegate: Rectangle {
                            required property int index
                            required property var modelData
                            property bool sel: modelData === printerPickDialog.selPrinter

                            Layout.fillWidth: true
                            height: 56; radius: 10
                            color: sel ? "#0d2238" : "#12151e"
                            border.color: sel ? "#4FA4F2" : Theme.border
                            border.width: sel ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 14; spacing: 12
                                Text {
                                    text: "🖨"
                                    color: sel ? "#4FA4F2" : Theme.textMuted
                                    font.pixelSize: 18
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData
                                    color: sel ? "#ffffff" : Theme.textMuted
                                    font.pixelSize: 15; font.bold: sel
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: sel
                                    text: "✓"; color: "#4ade80"
                                    font.pixelSize: 16; font.bold: true
                                }
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: printerPickDialog.selPrinter = modelData
                            }
                        }
                    }

                    Text {
                        visible: printerPickDialog.printers.length === 0
                        text: "Đang tìm máy in..."
                        color: Theme.textMuted; font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Nút hành động
                RowLayout {
                    Layout.fillWidth: true; spacing: 12

                    Rectangle {
                        Layout.preferredWidth: 120; Layout.preferredHeight: 52; radius: 12
                        color: cancelPickMA.pressed ? "#7a1a1a"
                             : cancelPickMA.containsMouse ? "#5a1515" : "#3a1010"
                        border.color: "#6a2020"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent; text: "Huỷ"
                            color: "white"; font.pixelSize: 16; font.bold: true
                        }
                        MouseArea {
                            id: cancelPickMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: printerPickDialog.closeDialog()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 52; radius: 12
                        opacity: printerPickDialog.selPrinter !== "" ? 1.0 : 0.4
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: printPickMA.pressed ? "#1a60b0" : (printPickMA.containsMouse ? "#5BB8FF" : "#4FA4F2") }
                            GradientStop { position: 1.0; color: printPickMA.pressed ? "#1040a0" : (printPickMA.containsMouse ? "#4FA4F2" : "#2D86DE") }
                        }
                        RowLayout {
                            anchors.centerIn: parent; spacing: 10
                            Text { text: "🖨️"; font.pixelSize: 18 }
                            Text { text: "In"; color: "white"; font.pixelSize: 16; font.bold: true }
                        }
                        MouseArea {
                            id: printPickMA; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: printerPickDialog.selPrinter !== ""
                            onClicked: printerPickDialog.confirmPrint()
                        }
                    }
                }
            }
        }
    } // printerPickDialog

    // ── Nút X tròn — bấm → về CutModeScreen. Chỉ hiện khi dùng trong phiên chụp. ──
    Rectangle {
        anchors.right: parent.right
        anchors.top:   parent.top
        anchors.rightMargin: 20
        anchors.topMargin:   16
        width: 52; height: 52; radius: 26
        visible: root.showCloseButton && root.selectedPhoto === null
        color: closeGalleryArea.containsMouse ? "#c0392b" : "#e74c3c"
        border.color: "white"; border.width: 2
        z: 50
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"; font.pixelSize: 22; font.bold: true
        }
        MouseArea {
            id: closeGalleryArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }
}
