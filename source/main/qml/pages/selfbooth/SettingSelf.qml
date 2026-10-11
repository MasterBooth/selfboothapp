import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import Qt.labs.platform as Platform
import "../../components"
import "../../theme"
import "../../utils/Money.js" as Money

Rectangle {
    id: root

    signal backClicked()
    // Mở trang cài đặt photobooth (bản copy PtbSettings) tại tab tương ứng —
    // máy in / thanh toán / bộ lọc / voucher / doanh thu dùng nguyên UI của ptb.
    signal openPtbSettings(int tab)

    color: "#15171e"

    // ── Sidebar nav items (mục có ptbTab → mở PtbSettings thay vì tab nội bộ) ─
    property int selectedTab: 0
    readonly property var navItems: [
        { icon: "⚙",  label: "Cài Đặt Chung"    },
        { icon: "🔌", label: "Kết Nối Máy Ảnh"  },
        { icon: "⏱",  label: "Gói Chụp & Thanh Toán" },
        { icon: "📁",  label: "Thư Mục Lưu"      },
        { icon: "🖼",  label: "Hình Ảnh Giao Diện" },
        { icon: "ℹ",  label: "Thông Tin & Nâng Cấp" },
        { icon: "🧩", label: "Frame & Filter"       },
        { icon: "🖨",  label: "Máy In",                    ptbTab: 3  },
        { icon: "💳", label: "Thanh Toán & Đầu Đọc Tiền",  ptbTab: 13 },
        { icon: "🎨", label: "Bộ Lọc Màu",                ptbTab: 8  },
        { icon: "🎟",  label: "Voucher",                   ptbTab: 9  },
        { icon: "📊",  label: "Doanh Thu",                 ptbTab: 10 }
    ]

    function showInfoMessage(message) {
        infoMessage.text = message
        infoMessageDialog.open()
    }

    Dialog {
        id: infoMessageDialog
        anchors.centerIn: Overlay.overlay
        modal: true
        standardButtons: Dialog.Ok
        title: "Thông báo"
        contentItem: Text {
            id: infoMessage
            color: Theme.text
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            width: 420
        }
    }

    // ── Background image paths ────────────────────────────────────────────────
    property string bgWelcome: eventManager.getAppSetting("selfbooth_bg_welcome", "")
    property string bgOption:  eventManager.getAppSetting("selfbooth_bg_option",  "")
    property string bgCapture: eventManager.getAppSetting("selfbooth_bg_capture", "")
    property string bgQr:      eventManager.getAppSetting("selfbooth_bg_qr",      "")
    property string bgPayment: eventManager.getAppSetting("selfbooth_bg_payment", "")

    // ── File dialogs ──────────────────────────────────────────────────────────
    Platform.FileDialog {
        id: welcomeBgDialog; title: "Chọn hình nền trang Welcome"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]; fileMode: Platform.FileDialog.OpenFile
        onAccepted: { var p = _normPath(currentFile ? currentFile.toString() : file.toString()); eventManager.setAppSetting("selfbooth_bg_welcome", p); root.bgWelcome = p }
    }
    Platform.FileDialog {
        id: optionBgDialog; title: "Chọn hình nền trang Chọn Thời Gian"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]; fileMode: Platform.FileDialog.OpenFile
        onAccepted: { var p = _normPath(currentFile ? currentFile.toString() : file.toString()); eventManager.setAppSetting("selfbooth_bg_option", p); root.bgOption = p }
    }
    Platform.FileDialog {
        id: captureBgDialog; title: "Chọn hình nền trang Chụp Ảnh"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]; fileMode: Platform.FileDialog.OpenFile
        onAccepted: { var p = _normPath(currentFile ? currentFile.toString() : file.toString()); eventManager.setAppSetting("selfbooth_bg_capture", p); root.bgCapture = p }
    }
    Platform.FileDialog {
        id: qrBgDialog; title: "Chọn hình nền trang QR Code"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]; fileMode: Platform.FileDialog.OpenFile
        onAccepted: { var p = _normPath(currentFile ? currentFile.toString() : file.toString()); eventManager.setAppSetting("selfbooth_bg_qr", p); root.bgQr = p }
    }
    Platform.FileDialog {
        id: paymentBgDialog; title: "Chọn hình nền trang Thanh Toán"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]; fileMode: Platform.FileDialog.OpenFile
        onAccepted: { var p = _normPath(currentFile ? currentFile.toString() : file.toString()); eventManager.setAppSetting("selfbooth_bg_payment", p); root.bgPayment = p }
    }

    function _normPath(raw) {
        var p = raw
        if (Qt.platform.os === "windows") p = p.replace(/^file:\/{2,3}/, "")
        else p = p.replace(/^file:\/\//, "")
        return decodeURIComponent(p)
    }

    // ── Frame Selfbooth (kho frame toàn máy) ──────────────────────────────────
    ListModel { id: selfFrameModel }

    function reloadSelfFrames() {
        var layouts = eventManager.getSelfBoothLayouts()
        selfFrameModel.clear()
        for (var i = 0; i < layouts.length; i++) {
            var item = layouts[i]
            selfFrameModel.append({
                fileName: item.fileName || "",
                path: item.path || "",
                slotCount: item.metadata && item.metadata.slot_count
                           ? item.metadata.slot_count : 0
            })
        }
    }

    Connections {
        target: eventManager
        function onLayoutUploaded(eid) {
            if (eid === -2) root.reloadSelfFrames()
        }
    }

    Platform.FileDialog {
        id: frameUploadDialog
        title: "Chọn frame PNG (có thể chọn nhiều file)"
        nameFilters: ["PNG Files (*.png)"]
        fileMode: Platform.FileDialog.OpenFiles
        onAccepted: {
            var list = currentFiles ? currentFiles : files
            for (var i = 0; i < list.length; i++)
                eventManager.uploadSelfBoothLayout(root._normPath(list[i].toString()))
            root.reloadSelfFrames()
        }
    }

    // (Voucher / doanh thu / máy in / thanh toán dùng nguyên UI photobooth —
    //  mở qua signal openPtbSettings, xem navItems có ptbTab.)

    // ── FolderListModel for session subdirectories (Tab 2) ────────────────────
    FolderListModel {
        id: sessionDirModel
        showDirs:     true
        showFiles:    false
        sortField:    FolderListModel.Name
        sortReversed: true
        folder:       root.selectedTab === 3 ? "file:///" + eventManager.getSelfBoothBaseDir() : ""
    }

    // ── FolderListModel for photos inside selected session ────────────────────
    FolderListModel {
        id: photoGridModel
        showDirs:    false
        showFiles:   true
        nameFilters: ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG", "*.png", "*.PNG"]
        sortField:   FolderListModel.Name
        folder:      ""
    }

    // ── Layout: sidebar + content ─────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Left sidebar ──────────────────────────────────────────────────────
        Rectangle {
            id: sidebar
            Layout.preferredWidth: 240
            Layout.fillHeight: true
            color: "#1a1c28"

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true; height: 64
                    color: "#1e2030"; border.color: "#2a2d3e"; border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 12; spacing: 10

                        Rectangle {
                            width: 36; height: 36; radius: 18
                            color: backBtnArea.containsMouse ? "#2a2d3e" : "transparent"
                            border.color: "#3a3d55"; border.width: 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text { anchors.centerIn: parent; text: "←"; color: "#aaa"; font.pixelSize: 18 }
                            MouseArea {
                                id: backBtnArea; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: root.backClicked()
                            }
                        }

                        Text { text: "Self Booth"; color: "white"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                    }
                }

                Repeater {
                    model: root.navItems
                    delegate: Rectangle {
                        Layout.fillWidth: true; height: 52
                        color: root.selectedTab === index ? "#252740" : (navArea.containsMouse ? "#1f2235" : "transparent")
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Rectangle {
                            width: 3; height: parent.height; anchors.left: parent.left
                            color: "#7c6af7"; visible: root.selectedTab === index; radius: 2
                        }

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 20; anchors.rightMargin: 16; spacing: 12
                            Text { text: modelData.icon; font.pixelSize: 18; verticalAlignment: Text.AlignVCenter }
                            Text {
                                text: modelData.label
                                color: root.selectedTab === index ? "white" : Theme.textMuted
                                font.pixelSize: 13; font.bold: root.selectedTab === index
                                Layout.fillWidth: true; verticalAlignment: Text.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                        }

                        MouseArea {
                            id: navArea; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.ptbTab !== undefined)
                                    root.openPtbSettings(modelData.ptbTab)
                                else
                                    root.selectedTab = index
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true; height: 56
                    color: "#1e2030"; border.color: "#2a2d3e"; border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10
                        Rectangle { width: 10; height: 10; radius: 5; color: cameraController.isLiveViewActive ? "#4ade80" : Theme.textMuted }
                        Text {
                            text: cameraController.isConnected
                                  ? (cameraController.isLiveViewActive ? "Live view đang chạy" : "Máy ảnh đã kết nối")
                                  : "Chưa kết nối máy ảnh"
                            color: Theme.textMuted; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        // ── Right content area ────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#15171e"

            // ════════════════════════════════════════════════════════════════
            // Tab 0: General Settings
            // ════════════════════════════════════════════════════════════════
            ScrollView {
                anchors.fill: parent; anchors.margins: 24
                visible: root.selectedTab === 0
                contentWidth: parent.width - 48; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 20

                    Text { text: "Cài Đặt Chung"; color: "white"; font.pixelSize: 22; font.bold: true; topPadding: 4 }

                    // ── Fullscreen + Orientation ──────────────────────────────
                    ConfigSection {
                        title: "Hiển Thị"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 0

                            // Fullscreen toggle
                            Rectangle {
                                Layout.fillWidth: true; height: 56
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent; spacing: 12
                                    Text { text: "⛶"; font.pixelSize: 20; verticalAlignment: Text.AlignVCenter }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: "Toàn màn hình"; color: "white"; font.pixelSize: 14; font.bold: true }
                                        Text { text: "Hiệu lực ngay, lưu cho lần khởi động sau"; color: Theme.textMuted; font.pixelSize: 11 }
                                    }
                                    Switch {
                                        id: fullscreenSwitch
                                        checked: Window.window ? Window.window.visibility === Window.FullScreen : false
                                        indicator: Rectangle {
                                            implicitWidth: 48; implicitHeight: 26
                                            x: fullscreenSwitch.leftPadding; y: parent.height / 2 - height / 2
                                            radius: 13; color: fullscreenSwitch.checked ? "#1e7eea" : "#3a3d45"
                                            Rectangle {
                                                x: fullscreenSwitch.checked ? parent.width - width - 2 : 2
                                                width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                                Behavior on x { NumberAnimation { duration: 200 } }
                                            }
                                        }
                                        contentItem: Text {
                                            text: fullscreenSwitch.checked ? "Bật" : "Tắt"
                                            color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                            leftPadding: fullscreenSwitch.indicator.width + fullscreenSwitch.spacing
                                        }
                                        onToggled: {
                                            if (checked) Window.window.showFullScreen()
                                            else         Window.window.showNormal()
                                            eventManager.setAppSetting("fullscreen_on_startup", checked ? "true" : "false")
                                        }
                                    }
                                }
                            }

                            // Divider
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2a2d3e" }

                            // Orientation picker
                            Rectangle {
                                Layout.fillWidth: true; height: 64
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent; spacing: 12
                                    Text { text: "⟳"; font.pixelSize: 20; verticalAlignment: Text.AlignVCenter; color: Theme.textMuted }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: "Tỉ lệ màn hình"; color: "white"; font.pixelSize: 14; font.bold: true }
                                        Text { text: "Áp dụng ngay — khớp với hướng màn hình thực tế"; color: Theme.textMuted; font.pixelSize: 11 }
                                    }
                                    // Landscape button
                                    Rectangle {
                                        property bool sel: eventManager.getAppSetting("selfbooth_orientation", "landscape") === "landscape"
                                        id: landscapeBtn
                                        width: 130; height: 40; radius: 8
                                        color: sel ? "#1e7eea" : "#1f2229"
                                        border.color: sel ? "#1e7eea" : "#3a3d45"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 1
                                            Text { text: "⬜ Ngang"; color: landscapeBtn.sel ? "#fff" : Theme.textMuted; font.pixelSize: 13; font.bold: landscapeBtn.sel; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: "1920 × 1080"; color: landscapeBtn.sel ? "#bce0ff" : "#4a4d55"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                eventManager.setAppSetting("selfbooth_orientation", "landscape")
                                                landscapeBtn.sel = true
                                                portraitBtn.sel  = false
                                            }
                                        }
                                    }
                                    // Portrait button
                                    Rectangle {
                                        property bool sel: eventManager.getAppSetting("selfbooth_orientation", "landscape") === "portrait"
                                        id: portraitBtn
                                        width: 130; height: 40; radius: 8
                                        color: sel ? "#1e7eea" : "#1f2229"
                                        border.color: sel ? "#1e7eea" : "#3a3d45"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 1
                                            Text { text: "⬜ Dọc"; color: portraitBtn.sel ? "#fff" : Theme.textMuted; font.pixelSize: 13; font.bold: portraitBtn.sel; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: "1080 × 1920"; color: portraitBtn.sel ? "#bce0ff" : "#4a4d55"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                eventManager.setAppSetting("selfbooth_orientation", "portrait")
                                                portraitBtn.sel  = true
                                                landscapeBtn.sel = false
                                            }
                                        }
                                    }
                                }
                            }

                            // Divider
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2a2d3e" }

                            // Chế độ chụp test (mockup, không cần máy ảnh)
                            Rectangle {
                                Layout.fillWidth: true; height: 56
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent; spacing: 12
                                    Text { text: "🧪"; font.pixelSize: 20; verticalAlignment: Text.AlignVCenter }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: "Chụp Test (Mockup)"; color: "white"; font.pixelSize: 14; font.bold: true }
                                        Text { text: "Hiện nút chụp ảnh mockup ở màn chụp — test luồng không cần máy ảnh"; color: Theme.textMuted; font.pixelSize: 11 }
                                    }
                                    Switch {
                                        id: testModeSwitch
                                        checked: eventManager.getAppSetting("selfbooth_test_mode", "false") === "true"
                                        indicator: Rectangle {
                                            implicitWidth: 48; implicitHeight: 26
                                            x: testModeSwitch.leftPadding; y: parent.height / 2 - height / 2
                                            radius: 13; color: testModeSwitch.checked ? "#f59e0b" : "#3a3d45"
                                            Rectangle {
                                                x: testModeSwitch.checked ? parent.width - width - 2 : 2
                                                width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                                Behavior on x { NumberAnimation { duration: 200 } }
                                            }
                                        }
                                        contentItem: Text {
                                            text: testModeSwitch.checked ? "Bật" : "Tắt"
                                            color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                            leftPadding: testModeSwitch.indicator.width + testModeSwitch.spacing
                                        }
                                        onToggled: eventManager.setAppSetting("selfbooth_test_mode", checked ? "true" : "false")
                                    }
                                }
                            }
                        }
                    }

                    // ── Welcome page text content ─────────────────────────────
                    ConfigSection {
                        title: "Nội Dung Trang Welcome"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 14

                            // Helper to build a labelled text field row
                            Repeater {
                                model: [
                                    { key: "welcome_title",    label: "Tiêu đề lớn",     def: "SELF BOOTH",            hint: "VD: SELF BOOTH" },
                                    { key: "welcome_subtitle", label: "Phụ đề",           def: "Chụp ảnh tự do · Lưu kỷ niệm", hint: "Dòng chữ nhỏ bên dưới tiêu đề" },
                                    { key: "welcome_tap_icon", label: "Biểu tượng chạm",  def: "👆",                    hint: "Emoji / ký tự hiển thị phía trên nút chạm" },
                                    { key: "welcome_tap_text", label: "Chữ nút chạm",     def: "CHẠM ĐỂ BẮT ĐẦU",     hint: "Văn bản kêu gọi chạm màn hình" }
                                ]
                                delegate: ColumnLayout {
                                    Layout.fillWidth: true; spacing: 6

                                    Text { text: modelData.label; color: Theme.textMuted; font.pixelSize: 12 }

                                    Rectangle {
                                        Layout.fillWidth: true; height: 44
                                        color: "#1f2229"; radius: 6
                                        border.color: wTextField.activeFocus ? "#7c6af7" : "#3a3d45"; border.width: 1

                                        TextInput {
                                            id: wTextField
                                            anchors.fill: parent; anchors.margins: 12
                                            text: eventManager.getAppSetting(modelData.key, modelData.def)
                                            color: "#fff"; font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                            clip: true
                                            onEditingFinished: eventManager.setAppSetting(modelData.key, text)
                                            // also save on focus lost
                                            onActiveFocusChanged: if (!activeFocus) eventManager.setAppSetting(modelData.key, text)
                                        }
                                    }

                                    Text { text: modelData.hint; color: "#4a4d55"; font.pixelSize: 11; font.italic: true }
                                }
                            }
                        }
                    }

                    Item { height: 32 }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // Tab 1: Camera Connection + Parameters (merged)
            // ════════════════════════════════════════════════════════════════
            ScrollView {
                anchors.fill: parent; anchors.margins: 24
                visible: root.selectedTab === 1
                contentWidth: parent.width - 48; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 20

                    Text { text: "Kết Nối Máy Ảnh"; color: "white"; font.pixelSize: 22; font.bold: true; topPadding: 4 }

                    StatusCard { Layout.fillWidth: true; Layout.preferredHeight: 96 }

                    ConfigSection {
                        title: "Nguồn Máy Ảnh"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 16

                            RowLayout {
                                spacing: 12; Layout.fillWidth: true
                                Text { text: "Loại máy ảnh:"; color: "#fff"; font.pixelSize: 14; Layout.preferredWidth: 160 }
                                ComboBox {
                                    id: cameraTypeCombo
                                    Layout.fillWidth: true; Layout.preferredHeight: 44
                                    enabled: !cameraController.isConnecting
                                    model: ["Canon Camera (EDSDK)", "Sony Camera (CRSDK)", "Nikon Camera (MAID)", "Fujifilm Camera (X SDK)"]
                                    currentIndex: cameraController.cameraType === "Sony" ? 1
                                                : cameraController.cameraType === "Nikon" ? 2
                                                : cameraController.cameraType === "Fuji" ? 3 : 0
                                    onActivated: cameraController.switchCameraType(currentIndex === 1 ? "Sony" : currentIndex === 2 ? "Nikon" : currentIndex === 3 ? "Fuji" : "Canon")
                                    background: Rectangle { color: "#1f2229"; border.color: "#3a3d45"; border.width: 1; radius: 4 }
                                    contentItem: Text { leftPadding: 12; text: cameraTypeCombo.displayText; color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
                                    delegate: ItemDelegate {
                                        width: cameraTypeCombo.width
                                        contentItem: Text { text: modelData; color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
                                        highlighted: cameraTypeCombo.highlightedIndex === index
                                        background: Rectangle { color: highlighted ? "#1e7eea" : "#1f2229" }
                                    }
                                }
                                Button {
                                    text: cameraController.isConnected ? "Kết nối lại" : "Kết nối"
                                    Layout.preferredWidth: 120; Layout.preferredHeight: 44
                                    enabled: !cameraController.isConnecting
                                    onClicked: cameraController.connectAsync()
                                    background: Rectangle { color: !parent.enabled ? "#334155" : parent.hovered ? "#2a8bff" : "#1e7eea"; radius: 4 }
                                    contentItem: Text { text: parent.text; color: "#fff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }

                            RowLayout {
                                spacing: 12; Layout.fillWidth: true; visible: cameraController.cameraModel !== ""
                                Text { text: "Model:"; color: "#fff"; font.pixelSize: 14; Layout.preferredWidth: 160 }
                                Text { text: cameraController.cameraModel; color: "#4ade80"; font.pixelSize: 13 }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 48
                                color: "#15171c"; border.color: "#2a2d35"; border.width: 1; radius: 4
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 10
                                    Rectangle { width: 10; height: 10; radius: 5; color: cameraController.isLiveViewActive ? "#4ade80" : Theme.textMuted }
                                    Text { text: cameraController.isLiveViewActive ? "Live view đang chạy" : "Live view chưa hoạt động"; color: Theme.textMuted; font.pixelSize: 13 }
                                    Item { Layout.fillWidth: true }
                                    Text { text: cameraController.liveViewFps + " FPS"; color: Theme.textMuted; font.pixelSize: 13; visible: cameraController.isLiveViewActive }
                                }
                            }

                            RowLayout {
                                spacing: 12; Layout.fillWidth: true
                                Text { text: "Lật ngang (Mirror):"; color: "#fff"; font.pixelSize: 14; Layout.preferredWidth: 160 }
                                Switch {
                                    id: mirrorSwitch
                                    checked: cameraController.mirrorMode
                                    Component.onCompleted: {
                                        var saved = eventManager.getAppSetting("mirror_mode", "true")
                                        cameraController.setMirrorMode(saved === "true")
                                    }
                                    indicator: Rectangle {
                                        implicitWidth: 48; implicitHeight: 26
                                        x: mirrorSwitch.leftPadding; y: parent.height / 2 - height / 2
                                        radius: 13; color: mirrorSwitch.checked ? "#1e7eea" : "#3a3d45"
                                        Rectangle {
                                            x: mirrorSwitch.checked ? parent.width - width - 2 : 2
                                            width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                    contentItem: Text { text: mirrorSwitch.checked ? "On" : "Off"; color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter; leftPadding: mirrorSwitch.indicator.width + mirrorSwitch.spacing }
                                    onToggled: { cameraController.setMirrorMode(checked); eventManager.setAppSetting("mirror_mode", checked ? "true" : "false") }
                                }
                            }
                        }
                    }

                    // Live view — tall preview
                    LiveViewCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 480
                        eventData: null
                    }

                    // Camera parameters as a single horizontal row below the preview
                    ConfigSection {
                        title: "Thông Số Máy Ảnh"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 12

                            RowLayout {
                                spacing: 16; Layout.fillWidth: true

                                CameraSettingSlider {
                                    label: "ISO"; model: cameraController.isoList; currentValue: cameraController.iso
                                    Layout.fillWidth: true
                                    onValueSelected: function(val) { cameraController.iso = val; eventManager.setAppSetting("camera_iso", val) }
                                }
                                CameraSettingSlider {
                                    label: "Khẩu độ (F)"; model: cameraController.apertureList; currentValue: cameraController.aperture
                                    Layout.fillWidth: true
                                    onValueSelected: function(val) { cameraController.aperture = val; eventManager.setAppSetting("camera_aperture", val) }
                                }
                                CameraSettingSlider {
                                    label: "Tốc độ chụp"; model: cameraController.shutterSpeedList; currentValue: cameraController.shutterSpeed
                                    Layout.fillWidth: true
                                    onValueSelected: function(val) { cameraController.shutterSpeed = val; eventManager.setAppSetting("camera_shutter", val) }
                                }
                                CameraSettingSlider {
                                    label: "Cân bằng trắng"; model: cameraController.whiteBalanceList; currentValue: cameraController.whiteBalance
                                    Layout.fillWidth: true
                                    onValueSelected: function(val) { cameraController.whiteBalance = val; eventManager.setAppSetting("camera_wb", val) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }
                                Button {
                                    text: "↻  Làm mới thông số"
                                    onClicked: cameraController.getAllCameraProperties()
                                    background: Rectangle { color: parent.hovered ? "#2a2d35" : "#1f2229"; radius: 6; border.color: "#3a3d45"; border.width: 1 }
                                    contentItem: Text { text: parent.text; color: "#aaa"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                }
                            }
                        }
                    }

                    Item { height: 32 }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // Tab 2: Shooting Time
            // ════════════════════════════════════════════════════════════════
            ScrollView {
                anchors.fill: parent; anchors.margins: 24
                visible: root.selectedTab === 2
                contentWidth: parent.width - 48; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 20

                    Text { text: "Gói Chụp & Thanh Toán"; color: "white"; font.pixelSize: 22; font.bold: true; topPadding: 4 }

                    // ── Chế độ chụp: theo phút hoặc đếm ngược N ảnh ───────────
                    ConfigSection {
                        title: "Chế Độ Chụp"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            id: modeCol
                            spacing: 16
                            property bool minuteMode: eventManager.getAppSetting("selfbooth_minute_mode", "true") === "true"

                            RowLayout {
                                spacing: 16; Layout.fillWidth: true

                                Rectangle {
                                    Layout.fillWidth: true; height: 64; radius: 8
                                    color: modeCol.minuteMode ? "#1e7eea" : "#1f2229"
                                    border.color: modeCol.minuteMode ? "#1e7eea" : "#3a3d45"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 2
                                        Text { text: "⏱ Theo phút"; color: modeCol.minuteMode ? "#fff" : Theme.textMuted; font.pixelSize: 14; font.bold: modeCol.minuteMode; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "Chọn gói phút, bấm remote chụp tự do"; color: modeCol.minuteMode ? "#bce0ff" : "#4a4d55"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { modeCol.minuteMode = true; eventManager.setAppSetting("selfbooth_minute_mode", "true") }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; height: 64; radius: 8
                                    color: !modeCol.minuteMode ? "#1e7eea" : "#1f2229"
                                    border.color: !modeCol.minuteMode ? "#1e7eea" : "#3a3d45"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 2
                                        Text { text: "⏲ Đếm ngược N ảnh"; color: !modeCol.minuteMode ? "#fff" : Theme.textMuted; font.pixelSize: 14; font.bold: !modeCol.minuteMode; Layout.alignment: Qt.AlignHCenter }
                                        Text { text: "Tự chụp N ảnh với đếm ngược như photobooth"; color: !modeCol.minuteMode ? "#bce0ff" : "#4a4d55"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: { modeCol.minuteMode = false; eventManager.setAppSetting("selfbooth_minute_mode", "false") }
                                    }
                                }
                            }

                            // Cài đặt riêng cho chế độ đếm ngược
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 16
                                visible: !modeCol.minuteMode

                                RowLayout {
                                    spacing: 16; Layout.fillWidth: true
                                    Repeater {
                                        model: [
                                            { key: "sbcut_photo_count",    label: "Số ảnh / phiên",     def: "4",  unit: "ảnh"  },
                                            { key: "sbcut_countdown",      label: "Đếm ngược mỗi ảnh",  def: "3",  unit: "giây" },
                                            { key: "sbcut_review_seconds", label: "Xem lại sau chụp",   def: "10", unit: "giây" },
                                            { key: "selfbooth_price_session", label: "Giá / phiên",     def: "0",  unit: "đ"    }
                                        ]
                                        delegate: ColumnLayout {
                                            Layout.fillWidth: true; spacing: 6
                                            Text { text: modelData.label; color: "#fff"; font.pixelSize: 13 }
                                            Rectangle {
                                                Layout.fillWidth: true; height: 44; color: "#1f2229"
                                                border.color: cntField.activeFocus ? "#1e7eea" : "#3a3d45"; border.width: 1; radius: 6
                                                RowLayout {
                                                    anchors.fill: parent; anchors.margins: 8; spacing: 4
                                                    TextInput {
                                                        id: cntField; Layout.fillWidth: true
                                                        text: eventManager.getAppSetting(modelData.key, modelData.def)
                                                        color: "#fff"; font.pixelSize: 18; font.bold: true
                                                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                                        inputMethodHints: Qt.ImhDigitsOnly
                                                        validator: IntValidator { bottom: 0; top: 100000000 }
                                                        onEditingFinished: {
                                                            var v = parseInt(text)
                                                            if (!isNaN(v) && v >= 0) eventManager.setAppSetting(modelData.key, v.toString())
                                                        }
                                                    }
                                                    Text { text: modelData.unit; color: Theme.textMuted; font.pixelSize: 12 }
                                                }
                                            }
                                        }
                                    }
                                }

                                RowLayout {
                                    spacing: 24; Layout.fillWidth: true
                                    Repeater {
                                        model: [
                                            { key: "sbcut_capture_noaf", label: "Chụp không lấy nét (No-AF)", def: "false" },
                                            { key: "sbcut_use_remote",   label: "Chờ remote thay vì tự chụp", def: "false" }
                                        ]
                                        delegate: RowLayout {
                                            spacing: 8
                                            Switch {
                                                id: capToggle
                                                checked: eventManager.getAppSetting(modelData.key, modelData.def) === "true"
                                                indicator: Rectangle {
                                                    implicitWidth: 48; implicitHeight: 26
                                                    x: capToggle.leftPadding; y: parent.height / 2 - height / 2
                                                    radius: 13; color: capToggle.checked ? "#1e7eea" : "#3a3d45"
                                                    Rectangle {
                                                        x: capToggle.checked ? parent.width - width - 2 : 2
                                                        width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                                        Behavior on x { NumberAnimation { duration: 200 } }
                                                    }
                                                }
                                                contentItem: Text {
                                                    text: modelData.label
                                                    color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                                    leftPadding: capToggle.indicator.width + capToggle.spacing
                                                }
                                                onToggled: eventManager.setAppSetting(modelData.key, checked ? "true" : "false")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ConfigSection {
                        title: "Lựa Chọn Thời Gian (Phút)"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 16
                            Text {
                                text: "Cài đặt 3 lựa chọn thời gian hiển thị trên màn hình chọn:"
                                color: Theme.textMuted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 16; Layout.fillWidth: true
                                Repeater {
                                    model: [
                                        { key: "selfbooth_time1", label: "Lựa chọn 1", def: "5"  },
                                        { key: "selfbooth_time2", label: "Lựa chọn 2", def: "10" },
                                        { key: "selfbooth_time3", label: "Lựa chọn 3", def: "15" }
                                    ]
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Text { text: modelData.label; color: "#fff"; font.pixelSize: 13 }
                                        Rectangle {
                                            Layout.fillWidth: true; height: 44; color: "#1f2229"
                                            border.color: timeField.activeFocus ? "#1e7eea" : "#3a3d45"; border.width: 1; radius: 6
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 4
                                                TextInput {
                                                    id: timeField; Layout.fillWidth: true
                                                    text: eventManager.getAppSetting(modelData.key, modelData.def)
                                                    color: "#fff"; font.pixelSize: 18; font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                                    inputMethodHints: Qt.ImhDigitsOnly
                                                    validator: IntValidator { bottom: 1; top: 999 }
                                                    onEditingFinished: {
                                                        var v = parseInt(text)
                                                        if (!isNaN(v) && v >= 1) eventManager.setAppSetting(modelData.key, v.toString())
                                                    }
                                                }
                                                Text { text: "phút"; color: Theme.textMuted; font.pixelSize: 12 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Giá tiền từng gói ─────────────────────────────────────
                    ConfigSection {
                        title: "Giá Tiền Từng Gói (VNĐ)"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 16
                            Text {
                                text: "Giá 0 = miễn phí (bỏ qua thanh toán cho gói đó):"
                                color: Theme.textMuted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                            }
                            RowLayout {
                                spacing: 16; Layout.fillWidth: true
                                Repeater {
                                    model: [
                                        { key: "selfbooth_price1", label: "Giá gói 1", def: "0" },
                                        { key: "selfbooth_price2", label: "Giá gói 2", def: "0" },
                                        { key: "selfbooth_price3", label: "Giá gói 3", def: "0" }
                                    ]
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true; spacing: 6
                                        Text { text: modelData.label; color: "#fff"; font.pixelSize: 13 }
                                        Rectangle {
                                            Layout.fillWidth: true; height: 44; color: "#1f2229"
                                            border.color: priceField.activeFocus ? "#1e7eea" : "#3a3d45"; border.width: 1; radius: 6
                                            RowLayout {
                                                anchors.fill: parent; anchors.margins: 8; spacing: 4
                                                TextInput {
                                                    id: priceField; Layout.fillWidth: true
                                                    text: eventManager.getAppSetting(modelData.key, modelData.def)
                                                    color: "#fff"; font.pixelSize: 18; font.bold: true
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                                    inputMethodHints: Qt.ImhDigitsOnly
                                                    validator: IntValidator { bottom: 0; top: 100000000 }
                                                    onEditingFinished: {
                                                        var v = parseInt(text)
                                                        if (!isNaN(v) && v >= 0) eventManager.setAppSetting(modelData.key, v.toString())
                                                    }
                                                }
                                                Text { text: "đ"; color: Theme.textMuted; font.pixelSize: 12 }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Thanh toán trước khi chụp ─────────────────────────────
                    ConfigSection {
                        title: "Thanh Toán Trước Khi Chụp"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            spacing: 0

                            Repeater {
                                model: [
                                    { key: "selfbooth_payment_enabled",  icon: "💰", label: "Bật thanh toán trước khi chụp",
                                      hint: "Khách phải thanh toán gói (nếu giá > 0) trước khi vào màn chụp", def: "false" }
                                ]
                                delegate: ColumnLayout {
                                    Layout.fillWidth: true; spacing: 0

                                    Rectangle {
                                        Layout.fillWidth: true; height: 56
                                        color: "transparent"
                                        RowLayout {
                                            anchors.fill: parent; spacing: 12
                                            Text { text: modelData.icon; font.pixelSize: 20; verticalAlignment: Text.AlignVCenter }
                                            ColumnLayout {
                                                Layout.fillWidth: true; spacing: 2
                                                Text { text: modelData.label; color: "white"; font.pixelSize: 14; font.bold: true }
                                                Text { text: modelData.hint; color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                            }
                                            Switch {
                                                id: payToggle
                                                checked: eventManager.getAppSetting(modelData.key, modelData.def) === "true"
                                                indicator: Rectangle {
                                                    implicitWidth: 48; implicitHeight: 26
                                                    x: payToggle.leftPadding; y: parent.height / 2 - height / 2
                                                    radius: 13; color: payToggle.checked ? "#1e7eea" : "#3a3d45"
                                                    Rectangle {
                                                        x: payToggle.checked ? parent.width - width - 2 : 2
                                                        width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                                        Behavior on x { NumberAnimation { duration: 200 } }
                                                    }
                                                }
                                                contentItem: Text {
                                                    text: payToggle.checked ? "Bật" : "Tắt"
                                                    color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                                    leftPadding: payToggle.indicator.width + payToggle.spacing
                                                }
                                                onToggled: eventManager.setAppSetting(modelData.key, checked ? "true" : "false")
                                            }
                                        }
                                    }

                                    Rectangle { Layout.fillWidth: true; height: 1; color: "#2a2d3e" }
                                }
                            }

                            Text {
                                text: "Phương thức thanh toán (voucher / tiền mặt / mã tiền mặt / chuyển khoản QR), cấu hình ngân hàng SePay và đầu đọc tiền được quản lý trong mục \"💳 Thanh Toán & Đầu Đọc Tiền\" ở thanh bên (dùng nguyên trang cài đặt của Photobooth)."
                                color: "#4a4d55"; font.pixelSize: 12; font.italic: true
                                wrapMode: Text.WordWrap; Layout.fillWidth: true
                                topPadding: 10
                            }
                        }
                    }

                    Item { height: 32 }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // Tab 3: Session Storage Browser
            // ════════════════════════════════════════════════════════════════
            Item {
                anchors.fill: parent
                visible: root.selectedTab === 3

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 24; spacing: 16

                    // Header row
                    RowLayout {
                        Layout.fillWidth: true; spacing: 16

                        Text { text: "Thư Mục Lưu"; color: "white"; font.pixelSize: 22; font.bold: true }

                        Item { Layout.fillWidth: true }

                        Text { text: "Xem:"; color: Theme.textMuted; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }

                        ComboBox {
                            id: limitCombo
                            Layout.preferredWidth: 180; Layout.preferredHeight: 36
                            model: ["5 session gần nhất", "10 session gần nhất", "15 session gần nhất", "Tất cả session"]
                            currentIndex: 0
                            background: Rectangle { color: "#1f2229"; border.color: "#3a3d45"; border.width: 1; radius: 6 }
                            contentItem: Text { leftPadding: 10; text: limitCombo.displayText; color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
                            delegate: ItemDelegate {
                                width: limitCombo.width
                                contentItem: Text { text: modelData; color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
                                highlighted: limitCombo.highlightedIndex === index
                                background: Rectangle { color: highlighted ? "#1e7eea" : "#1f2229" }
                            }
                        }

                        Button {
                            text: "↻ Làm mới"; Layout.preferredHeight: 36
                            onClicked: sessionDirModel.folder = "file:///" + eventManager.getSelfBoothBaseDir()
                            background: Rectangle { color: parent.hovered ? "#2a2d35" : "#1f2229"; radius: 6; border.color: "#3a3d45"; border.width: 1 }
                            contentItem: Text { text: parent.text; color: "#aaa"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        }
                    }

                    // Base dir info bar
                    Rectangle {
                        Layout.fillWidth: true; height: 36
                        color: "#1a1d23"; radius: 6; border.color: "#2a2d35"; border.width: 1
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 10; spacing: 8
                            Text { text: "📂"; font.pixelSize: 14 }
                            Text {
                                text: eventManager.getSelfBoothBaseDir()
                                color: "#60a5fa"; font.pixelSize: 12; elide: Text.ElideMiddle; Layout.fillWidth: true
                            }
                        }
                    }

                    // Main split: session list left | photo grid right
                    RowLayout {
                        Layout.fillWidth: true; Layout.fillHeight: true; spacing: 16

                        // ── Session list ────────────────────────────────────
                        Rectangle {
                            Layout.preferredWidth: 260; Layout.fillHeight: true
                            color: "#1a1c28"; radius: 8; border.color: "#2a2d3e"; border.width: 1; clip: true

                            ColumnLayout {
                                anchors.fill: parent; spacing: 0

                                Rectangle {
                                    Layout.fillWidth: true; height: 36; color: "#1e2030"
                                    border.color: "#2a2d3e"; border.width: 1
                                    Text { anchors.centerIn: parent; text: "Danh sách session (" + sessionListView.count + ")"; color: Theme.textMuted; font.pixelSize: 12; font.bold: true }
                                }

                                ListView {
                                    id: sessionListView
                                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                                    currentIndex: -1

                                    // Filter sessionDirModel by limit
                                    model: {
                                        var limits = [5, 10, 15, 0]
                                        var lim = limits[limitCombo.currentIndex]
                                        var total = sessionDirModel.count
                                        return lim > 0 ? Math.min(lim, total) : total
                                    }

                                    delegate: Rectangle {
                                        required property int index
                                        width: sessionListView.width; height: 50
                                        color: sessionListView.currentIndex === index ? "#252740" : (sessArea.containsMouse ? "#1f2235" : "transparent")
                                        Behavior on color { ColorAnimation { duration: 100 } }

                                        Rectangle {
                                            width: 3; height: parent.height; anchors.left: parent.left
                                            color: "#7c6af7"; visible: sessionListView.currentIndex === index; radius: 2
                                        }

                                        Text {
                                            anchors.fill: parent
                                            anchors.leftMargin: 14; anchors.rightMargin: 10
                                            text: sessionDirModel.get(index, "fileName") || ""
                                            color: sessionListView.currentIndex === index ? "white" : Theme.textMuted
                                            font.pixelSize: 12; font.bold: sessionListView.currentIndex === index
                                            elide: Text.ElideRight; verticalAlignment: Text.AlignVCenter
                                        }

                                        MouseArea {
                                            id: sessArea; anchors.fill: parent; hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                sessionListView.currentIndex = index
                                                var fp = sessionDirModel.get(index, "filePath") || ""
                                                photoGridModel.folder = fp !== "" ? "file:///" + fp : ""
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Chưa có session nào"; color: "#4a4d55"; font.pixelSize: 13
                                        visible: sessionListView.count === 0
                                    }
                                }
                            }
                        }

                        // ── Photo + QR panel ────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            color: "#1a1c28"; radius: 8; border.color: "#2a2d3e"; border.width: 1; clip: true

                            ColumnLayout {
                                anchors.fill: parent; spacing: 0

                                // Panel header: session name + QR thumbnail
                                Rectangle {
                                    Layout.fillWidth: true; height: 60
                                    color: "#1e2030"; border.color: "#2a2d3e"; border.width: 1

                                    RowLayout {
                                        anchors.fill: parent; anchors.margins: 12; spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true; spacing: 2
                                            Text {
                                                text: sessionListView.currentIndex >= 0
                                                      ? (sessionDirModel.get(sessionListView.currentIndex, "fileName") || "")
                                                      : "← Chọn session để xem ảnh"
                                                color: "white"; font.pixelSize: 13; font.bold: true
                                                elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                            Text {
                                                text: photoGridModel.count + " ảnh"
                                                color: Theme.textMuted; font.pixelSize: 11
                                                visible: sessionListView.currentIndex >= 0
                                            }
                                        }

                                        // QR code thumbnail for this session
                                        Rectangle {
                                            width: 44; height: 44; radius: 6
                                            color: "#0d1929"; border.color: "#1e3a8a"; border.width: 1
                                            visible: sessionListView.currentIndex >= 0

                                            Image {
                                                anchors.fill: parent; anchors.margins: 3
                                                source: {
                                                    if (sessionListView.currentIndex < 0) return ""
                                                    var sname = sessionDirModel.get(sessionListView.currentIndex, "fileName") || ""
                                                    var hw = machineAuth.hwid
                                                    if (!hw || hw === "" || sname === "") return ""
                                                    var url = "https://boothos-client.vercel.app/selfbooth/" + hw + "/" + sname
                                                    return "https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=" + encodeURIComponent(url)
                                                }
                                                fillMode: Image.PreserveAspectFit; smooth: false; cache: false
                                            }

                                            ToolTip.visible: qrThumbArea.containsMouse
                                            ToolTip.text: "QR code session này"
                                            MouseArea { id: qrThumbArea; anchors.fill: parent; hoverEnabled: true }
                                        }
                                    }
                                }

                                // Photo grid
                                ScrollView {
                                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true

                                    GridView {
                                        id: photoGrid
                                        anchors.fill: parent; anchors.margins: 10
                                        cellWidth: 160; cellHeight: 130; clip: true
                                        model: photoGridModel

                                        delegate: Rectangle {
                                            width: 152; height: 122
                                            color: "#12141c"; radius: 6
                                            border.color: "#2a2d3e"; border.width: 1; clip: true

                                            Image {
                                                anchors.fill: parent; anchors.margins: 2
                                                source: "file:///" + filePath
                                                fillMode: Image.PreserveAspectCrop
                                                smooth: true; asynchronous: true
                                            }

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                anchors.left: parent.left; anchors.right: parent.right
                                                height: 20; color: "#aa000000"; radius: 4
                                                Text {
                                                    anchors.fill: parent; leftPadding: 4; rightPadding: 4
                                                    text: fileName
                                                    color: "#ccc"; font.pixelSize: 9
                                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                                    elide: Text.ElideLeft
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: sessionListView.currentIndex < 0 ? "← Chọn session để xem ảnh" : "Session này chưa có ảnh"
                                            color: "#4a4d55"; font.pixelSize: 14
                                            visible: photoGrid.count === 0
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ════════════════════════════════════════════════════════════════
            // Tab 4: Background Images
            // ════════════════════════════════════════════════════════════════
            ScrollView {
                anchors.fill: parent; anchors.margins: 24
                visible: root.selectedTab === 4
                contentWidth: parent.width - 48; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 20

                    Text { text: "Hình Ảnh Giao Diện"; color: "white"; font.pixelSize: 22; font.bold: true; topPadding: 4 }

                    Text {
                        text: "Chọn hình nền cho các trang của Self Booth. Các chi tiết giao diện sẽ hiển thị trong suốt để không che nền."
                        color: Theme.textMuted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    BgImageCard {
                        Layout.fillWidth: true; label: "Trang Chào Mừng (Welcome)"; imagePath: root.bgWelcome
                        onBrowse: welcomeBgDialog.open()
                        onClear: { eventManager.setAppSetting("selfbooth_bg_welcome", ""); root.bgWelcome = "" }
                    }
                    BgImageCard {
                        Layout.fillWidth: true; label: "Trang Chọn Thời Gian"; imagePath: root.bgOption
                        onBrowse: optionBgDialog.open()
                        onClear: { eventManager.setAppSetting("selfbooth_bg_option", ""); root.bgOption = "" }
                    }
                    BgImageCard {
                        Layout.fillWidth: true; label: "Trang Chụp Ảnh (Capture)"; imagePath: root.bgCapture
                        onBrowse: captureBgDialog.open()
                        onClear: { eventManager.setAppSetting("selfbooth_bg_capture", ""); root.bgCapture = "" }
                    }
                    BgImageCard {
                        Layout.fillWidth: true; label: "Trang QR Code"; imagePath: root.bgQr
                        onBrowse: qrBgDialog.open()
                        onClear: { eventManager.setAppSetting("selfbooth_bg_qr", ""); root.bgQr = "" }
                    }
                    BgImageCard {
                        Layout.fillWidth: true; label: "Trang Thanh Toán"; imagePath: root.bgPayment
                        onBrowse: paymentBgDialog.open()
                        onClear: { eventManager.setAppSetting("selfbooth_bg_payment", ""); root.bgPayment = "" }
                    }

                    Item { height: 32 }
                }
            }

            // Không còn bán gói trong app — hiển thị thông tin studio thay thế.
            StudioInfoPanel {
                anchors.fill: parent
                anchors.margins: 24
                visible: root.selectedTab === 5
                onNotify: function(message) { root.showInfoMessage(message) }
            }

            // ════════════════════════════════════════════════════════════════
            // Tab 6: Frame & Filter
            // ════════════════════════════════════════════════════════════════
            ScrollView {
                anchors.fill: parent; anchors.margins: 24
                visible: root.selectedTab === 6
                contentWidth: parent.width - 48; clip: true
                onVisibleChanged: if (visible) root.reloadSelfFrames()

                ColumnLayout {
                    width: parent.width; spacing: 20

                    Text { text: "Frame & Filter"; color: "white"; font.pixelSize: 22; font.bold: true; topPadding: 4 }

                    ConfigSection {
                        title: "Ghép Frame Sau Khi Chụp"; expanded: true; Layout.fillWidth: true
                        content: ColumnLayout {
                            id: frameCol
                            spacing: 16
                            property bool frameOn: eventManager.getAppSetting("selfbooth_frame_enabled", "false") === "true"

                            RowLayout {
                                Layout.fillWidth: true; spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    Text { text: "Chọn frame sau khi chụp"; color: "white"; font.pixelSize: 14; font.bold: true }
                                    Text {
                                        text: "Tắt: chụp xong hiện 2 QR — xem ảnh + ghép ảnh online (boothme-vn). Bật: khách chọn frame → ghép ảnh → (filter) → in → QR xem ảnh."
                                        color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    }
                                }
                                Switch {
                                    id: frameSwitch
                                    checked: frameCol.frameOn
                                    indicator: Rectangle {
                                        implicitWidth: 48; implicitHeight: 26
                                        x: frameSwitch.leftPadding; y: parent.height / 2 - height / 2
                                        radius: 13; color: frameSwitch.checked ? "#1e7eea" : "#3a3d45"
                                        Rectangle {
                                            x: frameSwitch.checked ? parent.width - width - 2 : 2
                                            width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 200 } }
                                        }
                                    }
                                    contentItem: Text {
                                        text: frameSwitch.checked ? "Bật" : "Tắt"
                                        color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                        leftPadding: frameSwitch.indicator.width + frameSwitch.spacing
                                    }
                                    onToggled: {
                                        frameCol.frameOn = checked
                                        eventManager.setAppSetting("selfbooth_frame_enabled", checked ? "true" : "false")
                                    }
                                }
                            }

                            // Kho frame (chỉ hiện khi bật)
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 12
                                visible: frameCol.frameOn

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 10
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: "Kho khung frame"; color: "white"; font.pixelSize: 14; font.bold: true }
                                        Text {
                                            text: "Tải PNG có vùng trong suốt — vùng trong suốt được nhận diện thành slot ảnh."
                                            color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                        }
                                    }
                                    Button {
                                        text: "＋ Tải frame"
                                        Layout.preferredHeight: 40
                                        background: Rectangle { color: parent.hovered ? "#2a8bff" : "#1e7eea"; radius: 6 }
                                        contentItem: Text { text: parent.text; color: "#fff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: frameUploadDialog.open()
                                    }
                                    Button {
                                        text: "↻ Làm mới"
                                        Layout.preferredHeight: 40
                                        background: Rectangle { color: parent.hovered ? "#3a4455" : "#2a2d35"; radius: 6 }
                                        contentItem: Text { text: parent.text; color: "#fff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: root.reloadSelfFrames()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true; Layout.preferredHeight: 240
                                    color: "#101218"; radius: 10; border.color: "#2a2d3e"; clip: true

                                    ListView {
                                        anchors.fill: parent; anchors.margins: 14
                                        orientation: ListView.Horizontal; spacing: 18
                                        model: selfFrameModel; clip: true
                                        boundsBehavior: Flickable.StopAtBounds

                                        delegate: Rectangle {
                                            required property string fileName
                                            required property string path
                                            required property int slotCount
                                            width: 180; height: 210; radius: 8
                                            color: "#1f2229"; border.color: "#3a3d45"

                                            Image {
                                                anchors.fill: parent; anchors.margins: 10; anchors.bottomMargin: 42
                                                source: path
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                sourceSize: Qt.size(320, 320)
                                            }
                                            Text {
                                                anchors.left: parent.left; anchors.right: delFrameBtn.left
                                                anchors.bottom: parent.bottom; anchors.margins: 10
                                                text: fileName + " · " + slotCount + " slot"
                                                color: Theme.textMuted; font.pixelSize: 11; elide: Text.ElideMiddle
                                            }
                                            Rectangle {
                                                id: delFrameBtn
                                                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 6
                                                width: 34; height: 34; radius: 6
                                                color: delFrameMa.containsMouse ? "#3a2020" : "#2a1515"
                                                border.color: "#5a3030"; border.width: 1
                                                Text { anchors.centerIn: parent; text: "✕"; color: "#f87171"; font.pixelSize: 14 }
                                                MouseArea {
                                                    id: delFrameMa; anchors.fill: parent; hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        eventManager.deleteSelfBoothLayout(path)
                                                        root.reloadSelfFrames()
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: selfFrameModel.count === 0
                                        text: "Chưa có frame — bấm ＋ Tải frame"
                                        color: Theme.textMuted; font.pixelSize: 14
                                    }
                                }
                            }
                        }
                    }

                    ConfigSection {
                        title: "Filter Làm Đẹp"; expanded: true; Layout.fillWidth: true
                        content: RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                Text { text: "Trang chọn filter sau khi ghép ảnh"; color: "white"; font.pixelSize: 14; font.bold: true }
                                Text {
                                    text: "Cần có file filter LUT (dùng chung kho filter với app Photobooth). Hiện có: "
                                          + filterManager.getFilters().length + " filter."
                                    color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true
                                }
                            }
                            Switch {
                                id: filterSwitch
                                checked: eventManager.getAppSetting("selfbooth_filter_enabled", "false") === "true"
                                indicator: Rectangle {
                                    implicitWidth: 48; implicitHeight: 26
                                    x: filterSwitch.leftPadding; y: parent.height / 2 - height / 2
                                    radius: 13; color: filterSwitch.checked ? "#1e7eea" : "#3a3d45"
                                    Rectangle {
                                        x: filterSwitch.checked ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#fff"; anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }
                                contentItem: Text {
                                    text: filterSwitch.checked ? "Bật" : "Tắt"
                                    color: "#fff"; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter
                                    leftPadding: filterSwitch.indicator.width + filterSwitch.spacing
                                }
                                onToggled: eventManager.setAppSetting("selfbooth_filter_enabled", checked ? "true" : "false")
                            }
                        }
                    }

                    Item { height: 32 }
                }
            }

        }
    }

    // ── Inline component: BgImageCard ─────────────────────────────────────────
    component BgImageCard: Rectangle {
        property string label: ""
        property string imagePath: ""
        signal browse()
        signal clear()

        height: 130; color: "#1e2030"; border.color: "#2a2d3e"; border.width: 1; radius: 10

        RowLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 16

            Rectangle {
                width: 140; height: 98; color: "#12141c"; radius: 6
                border.color: "#2a2d3e"; border.width: 1; clip: true

                Image {
                    anchors.fill: parent
                    source: imagePath !== "" ? "file:///" + imagePath : ""
                    fillMode: Image.PreserveAspectCrop; visible: imagePath !== ""
                }
                Text {
                    anchors.centerIn: parent; text: "Chưa có hình\nnền"
                    color: "#4a4d55"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter
                    visible: imagePath === ""; lineHeight: 1.4
                }
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 10

                Text { text: label; color: "white"; font.pixelSize: 14; font.bold: true }
                Text {
                    text: imagePath !== "" ? imagePath : "Chưa chọn hình nền"
                    color: imagePath !== "" ? "#4ade80" : Theme.textMuted
                    font.pixelSize: 12; elide: Text.ElideLeft; Layout.fillWidth: true
                }
                RowLayout {
                    spacing: 10
                    Rectangle {
                        width: 110; height: 34; radius: 6
                        color: browseArea.containsMouse ? "#2a8bff" : "#1e7eea"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "Chọn ảnh"; color: "white"; font.pixelSize: 13 }
                        MouseArea { id: browseArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: browse() }
                    }
                    Rectangle {
                        width: 72; height: 34; radius: 6
                        color: clearArea.containsMouse ? "#3a2020" : "#2a1515"
                        border.color: "#5a3030"; border.width: 1; visible: imagePath !== ""
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text { anchors.centerIn: parent; text: "Xoá"; color: "#f87171"; font.pixelSize: 13 }
                        MouseArea { id: clearArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: clear() }
                    }
                }
            }
        }
    }
}
