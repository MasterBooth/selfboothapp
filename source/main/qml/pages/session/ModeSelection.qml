import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "ExposureHelper.js" as Exposure
import "../../utils/Money.js" as Money
import "../../theme"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // Property to hold background image path (can be set from parent)
    property string backgroundImage: ""

    // Effective background: use the externally-provided image when set; otherwise
    // always fall back to the default page background image. The static image is
    // given priority over the live-view background at ModeSelection, so chonggoi
    // shows even when the event has liveViewBackground enabled.
    readonly property string _effectiveBackground:
        backgroundImage !== "" ? backgroundImage : "qrc:/assets/chonggoi.png"

    // Derived theme background (falls back to original dark color if window not ready)
    property color _themeBg: {
        var win = Window.window
        return win ? win.appBgColor : "#000000"
    }
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)

    // Background - uses theme color (default) - only if no image/live view
    color: (_effectiveBackground !== "" || useLiveViewBackground) ? "transparent" : _themeBg

    Gradient {
        id: bgGradient
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
        GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
    }

    gradient: (_effectiveBackground !== "" || useLiveViewBackground) ? null : bgGradient

    // Property for Live View Background
    property bool useLiveViewBackground: false

    // Live View Background - Inline full-screen (no card styling)
    LiveViewPanel {
        id: liveViewBg
        anchors.fill: parent
        visible: root.useLiveViewBackground && (root._effectiveBackground === "")
        isActive: cameraController.isLiveViewActive
        consuming: root._lvViewerHeld && liveViewBg.visible
        fillMode: Image.PreserveAspectCrop
        imageMargins: 0
        panelRadius: 0
        panelBorderWidth: 0

    }

    // Custom Background Image - MUST BE FIRST CHILD to render behind everything
    BackgroundMedia {
        id: customBackground
        anchors.fill: parent
        sourcePath: root._effectiveBackground
        visible: root._effectiveBackground !== ""
    }

    signal modeSelected(string mode)
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    signal backClicked()
    signal galleryClicked()
    signal cameraSettingsClicked()
    signal settingsClicked()
    // Khách chọn gói chụp (thay cho "chạm màn hình bắt đầu").
    signal packageSelected(int minutes, int price, int prints)

    // ── Danh sách gói chụp ────────────────────────────────────────────────────
    // Đọc từ Cài Đặt → Thanh toán: pkgN_minutes / pkgN_price; gói 1–3 luôn hiện,
    // gói 4 chỉ hiện khi pkg4_enabled. Thumbnail đặt ở Cài Đặt → Hình nền (pkgN_thumbnail).
    property var _packages: []
    property int selectedPackageIndex: -1
    function _continueSelectedPackage() {
        if (selectedPackageIndex < 0 || selectedPackageIndex >= _packages.length)
            return
        var pkg = _packages[selectedPackageIndex]
        root.packageSelected(pkg.minutes, pkg.price, pkg.prints)
    }

    function _reloadPackages() {
        var defMin = [5, 10, 15, 20]
        var list = []
        for (var i = 1; i <= 4; i++) {
            if (i === 4 && eventManager.getAppSetting("pkg4_enabled", "false") !== "true")
                continue
            var mins  = parseInt(eventManager.getAppSetting("pkg" + i + "_minutes", "" + defMin[i - 1])) || defMin[i - 1]
            var price = parseInt(eventManager.getAppSetting("pkg" + i + "_price", "0")) || 0
            var prints = parseInt(eventManager.getAppSetting("pkg" + i + "_prints", "1")) || 1
            var thumb = eventManager.getAppSetting("pkg" + i + "_thumbnail", "")
            list.push({ "minutes": mins, "price": price, "prints": prints, "thumbnail": thumb })
        }
        root._packages = list
        if (root.selectedPackageIndex >= list.length)
            root.selectedPackageIndex = -1
    }

    // Hiện nút ⚙ (vào Cài đặt) ở chế độ thanh toán — khi không có Dashboard.
    property bool paymentMode: false

    // ── Live view decode gating ───────────────────────────────────────────────
    // Chỉ đăng ký "viewer" khi màn hình đang hiển thị VÀ dùng live view làm nền.
    // Nhờ vậy decode thread chỉ chạy khi thực sự có người xem.
    property bool _lvViewerHeld: false
    function _syncLiveViewViewer() {
        var want = root.useLiveViewBackground && root._effectiveBackground === ""
                && (StackView.status === StackView.Active
                 || StackView.status === StackView.Activating)
        if (want && !_lvViewerHeld) {
            cameraController.addLiveViewViewer()
            _lvViewerHeld = true
        } else if (!want && _lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            _lvViewerHeld = false
        }
    }
    StackView.onStatusChanged:        _syncLiveViewViewer()
    onUseLiveViewBackgroundChanged:   _syncLiveViewViewer()
    Component.onCompleted: { _syncLiveViewViewer(); _reloadPackages() }
    // Cập nhật lại danh sách gói khi admin đổi cài đặt (không cần khởi động lại).
    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key.indexOf("pkg") === 0) root._reloadPackages()
        }
    }
    Component.onDestruction: {
        if (_lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            _lvViewerHeld = false
        }
    }

    // Pending ISO value when warning dialog is shown
    property string _pendingIsoValue: ""

    // ---------------------------------------------------------
    // PACKAGE CHOOSER — chọn gói chụp (thay "chạm màn hình bắt đầu")
    // ---------------------------------------------------------
    Row {
        id: packageRow
        z: 2
        anchors.centerIn: parent
        spacing: 48

        Repeater {
            model: root._packages

            delegate: Item {
                id: pkgItem
                required property int index
                required property var modelData
                readonly property bool hasThumb: modelData.thumbnail && modelData.thumbnail !== ""
                readonly property bool selected: root.selectedPackageIndex === pkgItem.index
                // Thumbnail: chỉ hiện ảnh (không viền/nền). Card mặc định: kích thước cố định.
                width:  hasThumb ? Math.min(pkgThumb.implicitWidth, 360) : 260
                height: hasThumb ? Math.min(pkgThumb.implicitHeight, 460) : 320

                // ── Có thumbnail → chỉ hiển thị ảnh trong suốt làm nút ──
                Image {
                    id: pkgThumb
                    visible: pkgItem.hasThumb
                    anchors.fill: parent
                    source: pkgItem.hasThumb
                            ? (modelData.thumbnail.indexOf("file:") === 0 || modelData.thumbnail.indexOf("qrc:") === 0
                               ? modelData.thumbnail : "file:///" + modelData.thumbnail)
                            : ""
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    scale: pkgArea.pressed ? 0.96 : (pkgItem.selected ? 1.06 : (pkgArea.containsMouse ? 1.03 : 1.0))
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }
                }

                // ── Không có thumbnail → card mặc định (số phút + giá) ──
                Rectangle {
                    visible: pkgItem.hasThumb && pkgItem.selected
                    anchors.fill: parent
                    anchors.margins: -10
                    radius: 24
                    color: "transparent"
                    border.color: "#ad436d"
                    border.width: 5
                    z: 2
                }

                Rectangle {
                    id: pkgCard
                    visible: !pkgItem.hasThumb
                    anchors.fill: parent
                    radius: 22
                    readonly property color baseColor: pkgItem.index === 0 ? "#1e6eea"
                                                     : pkgItem.index === 1 ? "#7c3aed"
                                                     : pkgItem.index === 2 ? "#059669" : "#d97706"
                    color: pkgArea.pressed ? Qt.darker(baseColor, 1.3)
                         : pkgArea.containsMouse ? Qt.lighter(baseColor, 1.15) : baseColor
                    border.color: pkgItem.selected ? "#ad436d" : Qt.lighter(baseColor, 1.6); border.width: pkgItem.selected ? 5 : 2
                    scale: pkgArea.pressed ? 0.97 : (pkgItem.selected ? 1.06 : (pkgArea.containsMouse ? 1.03 : 1.0))
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: pkgItem.modelData.minutes
                            color: "white"; font.pixelSize: 92; font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "phút"
                            color: Qt.rgba(1,1,1,0.85); font.pixelSize: 24; font.bold: true
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: pkgItem.modelData.price > 0
                            text: Money.vnd(pkgItem.modelData.price)
                            color: "#fef08a"; font.pixelSize: 22; font.bold: true
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 130; height: 40; radius: 20; color: Qt.rgba(0,0,0,0.25)
                            Text { anchors.centerIn: parent; text: "Chọn"; color: "white"; font.pixelSize: 16; font.bold: true }
                        }
                    }
                }

                MouseArea {
                    id: pkgArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedPackageIndex = pkgItem.index
                }
            }
        }
    }

    // ---------------------------------------------------------
    // TOP BAR
    // ---------------------------------------------------------
    Item {
        id: topBar
        width: parent.width
        height: 100
        anchors.top: parent.top
        z: 10
        
        // Settings Button — nằm cạnh nút X (góc trên-phải), chỉ hiện ở chế độ thanh toán
        Button {
            id: settingsBtn
            visible: root.paymentMode
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.rightMargin: 40
            width: 60
            height: 60
            z: 16
            opacity: root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }

            background: Rectangle {
                color: parent.hovered ? "#1e7eea" : root._themeField
                radius: 30
                border.color: parent.hovered ? "#1e7eea" : Theme.border
                border.width: 2
                opacity: parent.hovered ? 1.0 : 0.85
            }
            contentItem: Image {
                source: "qrc:/assets/icons/settings_button.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
            onClicked: root.settingsClicked()
        }

        // View Gallery Button (Top Left) — màu hồng pastel, không icon
        Button {
            visible: false   // Ẩn nút Xem Ảnh tại ModeSelection
            width: 150
            height: 60
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.topMargin: 40
            anchors.leftMargin: 40
            z: 15

            background: Rectangle {
                color: parent.hovered ? "#f4abc8" : "#f7c5da"
                radius: 12
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            contentItem: Text {
                text: "Xem Ảnh"
                font.pixelSize: 18
                font.weight: Font.Bold
                color: "#8a3a5a"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            scale: hovered ? 1.05 : 1.0
            
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            onClicked: {
                console.log("ModeSelection: Gallery button clicked")
                root.galleryClicked()
            }
        }
        
    }
    
    // ---------------------------------------------------------
    Item {
        id: modeBackPill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: modeBackMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "‹"
                color: "#7A4B2A"
                opacity: modeBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back"
                color: "#7A4B2A"
                opacity: modeBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: modeBackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backClicked()
        }
    }

    Item {
        id: modeNextPill
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100
        opacity: root.selectedPackageIndex >= 0 ? 1.0 : 0.35
        Behavior on opacity { NumberAnimation { duration: 200 } }

        scale: modeNextMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "›"
                color: "#ad436d"
                opacity: modeNextMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Next"
                color: "#ad436d"
                opacity: modeNextMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: modeNextMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.selectedPackageIndex >= 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root._continueSelectedPackage()
        }
    }

    // FOOTER - PROMPT
    // ---------------------------------------------------------
    Item {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 150
        
        Text {
            id: promptText
            anchors.centerIn: parent
            text: "Tận Hưởng Khoảnh Khắc Của Bạn"
            color: root._themeMutedText
            font.pixelSize: 14
            font.letterSpacing: 4
            font.weight: Font.Bold
            
            // Subtle breathing animation
            SequentialAnimation {
                running: true
                loops: Animation.Infinite
                NumberAnimation { target: promptText; property: "opacity"; from: 0.4; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { target: promptText; property: "opacity"; from: 1.0; to: 0.4; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
    }
    
    // ---------------------------------------------------------
    // LEFT SIDE - EXPOSURE CONTROLS (below gallery button)
    // ---------------------------------------------------------
    Column {
        id: exposureControls
        anchors.left: parent.left
        anchors.top: topBar.bottom
        anchors.leftMargin: 40
        anchors.topMargin: 20
        spacing: 8
        z: 15
        // Ẩn hẳn cụm chỉnh máy ảnh (ô thông số + nút +/− + WB) tại ModeSelection.
        visible: false

        // Current exposure values strip — click to open camera settings
        Rectangle {
            width: 60
            height: 52
            radius: 8
            color: camStripMa.containsMouse ? "#CC252930" : "#CC1a1d23"
            border.color: camStripMa.containsMouse ? "#4FA4F2" : root._themeBorder
            border.width: camStripMa.containsMouse ? 2 : 1
            Behavior on color        { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: cameraController.shutterSpeed || "—"
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "F" + (cameraController.aperture || "—")
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ISO" + (cameraController.iso || "—")
                    color: Theme.textMuted
                    font.pixelSize: 10
                }
            }

            MouseArea {
                id: camStripMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cameraSettingsClicked()
            }
        }

        // Separator
        Rectangle { width: 60; height: 1; color: root._themeBorder; opacity: 0.5 }

        // Helper to apply exposure change result
        function applyChange(result, direction) {
            if (!result) {
                console.log("Exposure: Already at limit")
                root.showToast("Đã đạt giới hạn")
                return
            }
            console.log("Exposure: Changing", result.param, "to", result.value)
            if (result.param === "shutter") {
                cameraController.shutterSpeed = result.value
            } else if (result.param === "aperture") {
                cameraController.aperture = result.value
            } else if (result.param === "iso") {
                cameraController.iso = result.value
            }
            // Show feedback toast
            var paramName = result.param === "shutter" ? "Tốc độ"
                          : result.param === "aperture" ? "Khẩu độ"
                          : "ISO"
            root.showToast((direction === "up" ? "Tăng sáng" : "Giảm sáng") + "  ·  " + paramName + ": " + result.value)
        }

        Button {
            width: 60; height: 60
            z: 15
            background: Rectangle {
                color: parent.pressed ? "#1565c0" : (parent.hovered ? Theme.field : root._themeField)
                radius: 12
                opacity: 0.85
            }
            contentItem: Text {
                text: "+"
                color: "white"
                font.pixelSize: 28
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            scale: hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            onClicked: {
                var result = Exposure.increaseExposure(
                    cameraController.shutterSpeed,
                    cameraController.aperture,
                    cameraController.iso,
                    cameraController.shutterSpeedList,
                    cameraController.apertureList,
                    cameraController.isoList
                )
                // Check ISO warning threshold
                if (result && result.param === "iso" && parseInt(result.value) > 3200) {
                    root._pendingIsoValue = result.value
                    isoWarningPopup.open()
                } else {
                    exposureControls.applyChange(result, "up")
                }
            }
        }

        Button {
            width: 60; height: 60
            z: 15
            background: Rectangle {
                color: parent.pressed ? "#1565c0" : (parent.hovered ? Theme.field : root._themeField)
                radius: 12
                opacity: 0.85
            }
            contentItem: Text {
                text: "−"
                color: "white"
                font.pixelSize: 28
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            scale: hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
            onClicked: {
                var result = Exposure.decreaseExposure(
                    cameraController.shutterSpeed,
                    cameraController.aperture,
                    cameraController.iso,
                    cameraController.shutterSpeedList,
                    cameraController.apertureList,
                    cameraController.isoList
                )
                exposureControls.applyChange(result, "down")
            }
        }

        // Separator
        Rectangle { width: 60; height: 1; color: root._themeBorder; opacity: 0.5 }

        // White Balance Selector Button
        Item {
            id: wbButton
            width: 60; height: 60
            z: 15

            Rectangle {
                anchors.fill: parent
                color: wbBtnArea.pressed ? "#1565c0" : (wbBtnArea.containsMouse ? Theme.field : root._themeField)
                radius: 12
                opacity: 0.85
            }

            Column {
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "WB"
                    color: "#ffffff"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                Rectangle {
                    width: 32; height: 7; radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: root.wbSwatch(cameraController.whiteBalance)
                    border.color: "#ffffff40"; border.width: 1
                }
            }

            MouseArea {
                id: wbBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: wbPopup.open()
            }

            scale: wbBtnArea.containsMouse ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }
    }

    // ---------------------------------------------------------
    // WHITE BALANCE HELPER + POPUP
    // ---------------------------------------------------------
    function wbSwatch(name) {
        if (!name) return Theme.border
        var n = name.toLowerCase()
        if (n.indexOf("auto")         >= 0) return Theme.border
        if (n.indexOf("daylight")     >= 0 || n.indexOf("sunny") >= 0) return "#f5c842"
        if (n.indexOf("shade")        >= 0) return "#8ab4f0"
        if (n.indexOf("cloud")        >= 0) return "#a8c8f0"
        if (n.indexOf("incandescent") >= 0 || n.indexOf("tungsten") >= 0) return "#ff8c42"
        if (n.indexOf("fluorescent")  >= 0) return "#a0e8a0"
        if (n.indexOf("flash")        >= 0) return Theme.surface
        if (n.indexOf("kelvin")       >= 0) return "#ffd080"
        return Theme.border
    }

    Popup {
        id: wbPopup
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        parent: Overlay.overlay
        x: {
            var pt = wbButton.mapToItem(null, wbButton.width + 12, 0)
            return pt.x
        }
        y: {
            var pt = wbButton.mapToItem(null, 0, -8)
            return pt.y
        }
        width: 220
        padding: 10

        background: Rectangle {
            color: root._themeSurface
            radius: 12
            border.color: root._themeBorder
            border.width: 1
        }

        Column {
            width: parent.width
            spacing: 2

            Text {
                text: "White Balance"
                color: root._themeMutedText
                font.pixelSize: 11
                font.weight: Font.Bold
                leftPadding: 6
                bottomPadding: 4
            }

            Repeater {
                model: cameraController.whiteBalanceList

                Item {
                    width: wbPopup.width - wbPopup.padding * 2
                    height: 38

                    property bool isActive: cameraController.whiteBalance === modelData

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color: wbItemArea.containsMouse ? Theme.field : (isActive ? "#1c2535" : "transparent")

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            spacing: 10

                            Rectangle {
                                width: 20; height: 20; radius: 5
                                color: root.wbSwatch(modelData)
                                border.color: "#ffffff30"; border.width: 1
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: modelData
                                color: isActive ? "#ffffff" : root._themeText
                                font.pixelSize: 13
                                font.weight: isActive ? Font.Bold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            text: "✓"
                            color: "#1e7eea"
                            font.pixelSize: 13
                            font.bold: true
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            visible: isActive
                        }

                        MouseArea {
                            id: wbItemArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                cameraController.whiteBalance = modelData
                                root.showToast("White Balance: " + modelData)
                                wbPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // ISO WARNING POPUP
    // ---------------------------------------------------------
    Popup {
        id: isoWarningPopup
        modal: true
        closePolicy: Popup.NoAutoClose
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 480
        height: 280
        padding: 0

        background: Rectangle {
            color: "#1e2028"
            radius: 18
            border.color: "#ff6b35"
            border.width: 2

            // Glow ring
            Rectangle {
                anchors.fill: parent
                radius: 22
                color: "transparent"
                border.color: "#ff6b3540"
                border.width: 6
                anchors.margins: -4
            }
        }

        // Entrance animation
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutQuad }
            NumberAnimation { property: "scale"; from: 0.85; to: 1.0; duration: 220; easing.type: Easing.OutBack }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 150; easing.type: Easing.InQuad }
        }

        Column {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 20

            // Warning icon + title
            Row {
                spacing: 14
                anchors.horizontalCenter: parent.horizontalCenter

                Text {
                    text: "⚠️"
                    font.pixelSize: 32
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: "Cảnh báo ISO cao"
                    color: "#ff8c42"
                    font.pixelSize: 22
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Message
            Text {
                text: "ISO " + root._pendingIsoValue + " vượt mức an toàn 3200.\nẢnh có thể bị nhiễu hạt (noise) nhiều."
                color: Theme.text
                font.pixelSize: 15
                lineHeight: 1.5
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
                wrapMode: Text.WordWrap
                width: parent.width
            }

            // Buttons row
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16

                // Keep 3200 button
                Rectangle {
                    width: 180; height: 48
                    radius: 12
                    color: keepMa.containsMouse ? root._themeField : root._themeSurface
                    border.color: root._themeBorder
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "Giữ ISO 3200"
                        color: root._themeText
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: keepMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Set ISO to 3200
                            cameraController.iso = "3200"
                            root.showToast("ISO giữ nguyên: 3200")
                            root._pendingIsoValue = ""
                            isoWarningPopup.close()
                        }
                    }
                }

                // Allow / OK button
                Rectangle {
                    width: 180; height: 48
                    radius: 12
                    color: allowMa.containsMouse ? "#e05a20" : "#c94d10"
                    border.color: "#ff6b35"
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        anchors.centerIn: parent
                        text: "OK – Tăng ISO " + root._pendingIsoValue
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: allowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Allow ISO beyond 3200
                            cameraController.iso = root._pendingIsoValue
                            root.showToast("ISO: " + root._pendingIsoValue)
                            root._pendingIsoValue = ""
                            isoWarningPopup.close()
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------
    // TOAST NOTIFICATION
    // ---------------------------------------------------------
    function showToast(message) {
        toastText.text = message
        toastBg.opacity = 1.0
        toastHideTimer.restart()
    }

    Rectangle {
        id: toastBg
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 30
        anchors.bottomMargin: 180
        width: toastText.implicitWidth + 32
        height: 40
        radius: 20
        color: "#DD1a1d23"
        opacity: 0
        z: 20

        Behavior on opacity {
            NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
        }

        Text {
            id: toastText
            anchors.centerIn: parent
            color: "white"
            font.pixelSize: 14
            font.weight: Font.Medium
        }
    }

    Timer {
        id: toastHideTimer
        interval: 1500
        onTriggered: toastBg.opacity = 0
    }
}
