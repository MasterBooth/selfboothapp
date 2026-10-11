import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import Qt.labs.platform as Platform
import "../../utils/Money.js" as Money
import "../../theme"

// Trang cài đặt Selfbooth dạng sidebar (dễ mở rộng). Mọi key dùng namespace sbcut_*.
Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    color: "#15171e"

    signal backClicked()

    property int selectedTab: 0
    readonly property var navItems: [
        { icon: "📷", label: "Cài Đặt Chụp" },
        { icon: "🖼", label: "Giao Diện" },
        { icon: "📁", label: "Chung & Lưu Trữ" },
        { icon: "🔒", label: "Bảo Mật" }
    ]

    // ── State đọc từ settings (cập nhật khi đổi) ─────────────────────────────
    property int    photoCount:     parseInt(eventManager.getAppSetting("sbcut_photo_count", "4")) || 4
    property int    countdown:      parseInt(eventManager.getAppSetting("sbcut_countdown", "3")) || 3
    property int    reviewSeconds:  parseInt(eventManager.getAppSetting("sbcut_review_seconds", "10")) || 10
    property bool   useNoAf:        eventManager.getAppSetting("sbcut_capture_noaf", "false") === "true"
    property bool   useRemote:      eventManager.getAppSetting("sbcut_use_remote", "false") === "true"
    property bool   minuteMode:     eventManager.getAppSetting("sbcut_minute_mode", "false") === "true"
    property int    minute1:        parseInt(eventManager.getAppSetting("sbcut_time1", "5")) || 5
    property int    minute2:        parseInt(eventManager.getAppSetting("sbcut_time2", "10")) || 10
    property int    minute3:        parseInt(eventManager.getAppSetting("sbcut_time3", "15")) || 15
    property int    price1:         parseInt(eventManager.getAppSetting("sbcut_price1", "0")) || 0
    property int    price2:         parseInt(eventManager.getAppSetting("sbcut_price2", "0")) || 0
    property int    price3:         parseInt(eventManager.getAppSetting("sbcut_price3", "0")) || 0
    property bool   paymentEnabled: eventManager.getAppSetting("sbcut_payment_enabled", "false") === "true"
    property string bgWaiting:      eventManager.getAppSetting("sbcut_bg_waiting", "")
    property string bgResult:       eventManager.getAppSetting("sbcut_bg_result", "")
    property string bgPayment:      eventManager.getAppSetting("sbcut_bg_payment", "")
    property string startText:      eventManager.getAppSetting("sbcut_start_text", "Chạm để bắt đầu chụp")
    property string saveDir:        eventManager.getAppSetting("sbcut_save_dir", "")
    property bool   securityOn:     eventManager.getAppSetting("sbcut_security_enabled", "false") === "true"
    property bool   frameEnabled:   eventManager.getAppSetting("sbcut_frame_enabled", "false") === "true"

    readonly property string defaultSaveDir: eventManager.getSelfBoothBaseDir()
    property int selfRevenueTotal: 0

    ListModel { id: selfRevenueModel }
    ListModel { id: selfFrameModel }

    function _setMinute(index, value) {
        if (index === 0) root.minute1 = value
        else if (index === 1) root.minute2 = value
        else root.minute3 = value
        eventManager.setAppSetting("sbcut_time" + (index + 1), value.toString())
    }

    function _setPrice(index, value) {
        if (index === 0) root.price1 = value
        else if (index === 1) root.price2 = value
        else root.price3 = value
        eventManager.setAppSetting("sbcut_price" + (index + 1), value.toString())
    }

    function reloadSelfRevenue() {
        var recs = eventManager.getRevenueRecords("time", eventManager.isAdmin ? -1 : -2)
        selfRevenueModel.clear()
        root.selfRevenueTotal = 0
        for (var i = 0; i < recs.length; i++) {
            var r = recs[i]
            if ((r.source || "session") !== "selfbooth") continue
            var received = r.received_amount || 0
            root.selfRevenueTotal += received
            var dt = new Date(r.recorded_at)
            selfRevenueModel.append({
                recordedAt: isNaN(dt.getTime()) ? r.recorded_at
                                                : Qt.formatDateTime(dt, "dd/MM/yyyy HH:mm:ss"),
                amount: received,
                paymentMethod: r.payment_method || "",
                note: r.note || ""
            })
        }
    }

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

    function _normPath(raw) {
        var p = raw
        if (Qt.platform.os === "windows") p = p.replace(/^file:\/{2,3}/, "")
        else p = p.replace(/^file:\/\//, "")
        return decodeURIComponent(p)
    }
    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    // ── File / Folder dialogs ────────────────────────────────────────────────
    Platform.FileDialog {
        id: bgWaitingDialog
        title: "Chọn hình nền trang chờ (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var p = root._normPath(currentFile ? currentFile.toString() : file.toString())
            eventManager.setAppSetting("sbcut_bg_waiting", p); root.bgWaiting = p
        }
    }
    Platform.FileDialog {
        id: bgResultDialog
        title: "Chọn hình nền trang kết quả/QR (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var p = root._normPath(currentFile ? currentFile.toString() : file.toString())
            eventManager.setAppSetting("sbcut_bg_result", p); root.bgResult = p
        }
    }
    Platform.FileDialog {
        id: bgPaymentDialog
        title: "Chọn hình nền trang thanh toán Selfbooth (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var p = root._normPath(currentFile ? currentFile.toString() : file.toString())
            eventManager.setAppSetting("sbcut_bg_payment", p); root.bgPayment = p
        }
    }
    Platform.FolderDialog {
        id: saveDirDialog
        title: "Chọn thư mục lưu ảnh Selfbooth"
        onAccepted: {
            var p = root._normPath(folder.toString())
            eventManager.setAppSetting("sbcut_save_dir", p); root.saveDir = p
        }
    }
    Platform.FileDialog {
        id: selfFrameUploadDialog
        title: "Chọn các khung frame Selfbooth (PNG trong suốt)"
        nameFilters: ["PNG Images (*.png)"]
        fileMode: Platform.FileDialog.OpenFiles
        onAccepted: {
            var files = currentFiles
            for (var i = 0; i < files.length; i++)
                eventManager.uploadSelfBoothLayout(files[i])
        }
    }

    Connections {
        target: eventManager
        function onLayoutUploaded(eventId) {
            if (eventId === -2) root.reloadSelfFrames()
        }
    }

    // ── Component tái dùng ────────────────────────────────────────────────────
    component FieldLabel: Text {
        color: "#ffffff"; font.pixelSize: 16; font.weight: Font.Medium
    }
    component FieldHint: Text {
        color: "#888888"; font.pixelSize: 12; wrapMode: Text.WordWrap
    }

    // ── Layout: sidebar + content ─────────────────────────────────────────────
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sidebar ──────────────────────────────────────────────────────────
        Rectangle {
            id: sidebar
            Layout.preferredWidth: 260
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
                        Text { text: "Cài Đặt Selfbooth"; color: "white"; font.pixelSize: 16; font.bold: true; Layout.fillWidth: true }
                    }
                }

                Repeater {
                    model: root.navItems
                    delegate: Rectangle {
                        required property int index
                        required property var modelData
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
                            }
                        }
                        MouseArea {
                            id: navArea; anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor; onClicked: root.selectedTab = index
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ── Content ──────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#15171e"

            // ───────── Tab 0: Cài đặt chụp ─────────
            ScrollView {
                anchors.fill: parent; anchors.margins: 28
                visible: root.selectedTab === 0
                contentWidth: availableWidth; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 28

                    Text { text: "Cài Đặt Chụp"; color: "white"; font.pixelSize: 24; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Chụp theo phút" }
                            FieldHint {
                                text: "Chọn gói thời gian, chụp không giới hạn ảnh bằng dây remote và tự sang QR khi hết giờ."
                                Layout.fillWidth: true
                            }
                        }
                        Switch {
                            checked: root.minuteMode
                            onToggled: {
                                root.minuteMode = checked
                                eventManager.setAppSetting("sbcut_minute_mode", checked ? "true" : "false")
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.minuteMode
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Số ảnh chụp" }
                            FieldHint { text: "Số ảnh tự động chụp mỗi lượt Selfbooth"; Layout.fillWidth: true }
                        }
                        SpinBox {
                            from: 1; to: 20; value: root.photoCount
                            onValueModified: { root.photoCount = value; eventManager.setAppSetting("sbcut_photo_count", value.toString()) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.minuteMode
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Đếm ngược mỗi ảnh (giây)" }
                            FieldHint { text: "Thời gian giữ trước mỗi lần chụp"; Layout.fillWidth: true }
                        }
                        SpinBox {
                            from: 0; to: 15; value: root.countdown
                            onValueModified: { root.countdown = value; eventManager.setAppSetting("sbcut_countdown", value.toString()) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.minuteMode
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Thời gian xem lại (giây)" }
                            FieldHint { text: "Sau khi chụp đủ, chờ bấy nhiêu giây để xem/chụp lại rồi tự sang QR"; Layout.fillWidth: true }
                        }
                        SpinBox {
                            from: 1; to: 60; value: root.reviewSeconds
                            onValueModified: { root.reviewSeconds = value; eventManager.setAppSetting("sbcut_review_seconds", value.toString()) }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.minuteMode
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Chụp nhanh (No-AF)" }
                            FieldHint { text: "Bỏ lấy nét để giảm thời gian đứng hình giữa các ảnh"; Layout.fillWidth: true }
                        }
                        Switch {
                            checked: root.useNoAf
                            onToggled: { root.useNoAf = checked; eventManager.setAppSetting("sbcut_capture_noaf", checked ? "true" : "false") }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: !root.minuteMode
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Dùng dây bấm remote" }
                            FieldHint {
                                text: "Tự bấm dây remote để chụp từng ảnh; app không tự bấm. Dùng khi cắm dây bấm mềm vào máy."
                                Layout.fillWidth: true
                            }
                        }
                        Switch {
                            checked: root.useRemote
                            onToggled: {
                                root.useRemote = checked
                                eventManager.setAppSetting("sbcut_use_remote", checked ? "true" : "false")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.minuteMode
                        spacing: 16

                        FieldLabel { text: "Gói thời gian và giá" }
                        FieldHint {
                            text: "Ba lựa chọn này sẽ xuất hiện ở màn hình vòng tròn. Giá 0 đồng sẽ bỏ qua thanh toán."
                            Layout.fillWidth: true
                        }

                        Repeater {
                            model: [
                                { minutes: root.minute1, price: root.price1 },
                                { minutes: root.minute2, price: root.price2 },
                                { minutes: root.minute3, price: root.price3 }
                            ]
                            delegate: RowLayout {
                                required property int index
                                required property var modelData
                                Layout.fillWidth: true
                                spacing: 16

                                Text {
                                    text: "Gói " + (index + 1)
                                    color: "#ffffff"; font.pixelSize: 14; font.bold: true
                                    Layout.preferredWidth: 80
                                }
                                Text { text: "Phút"; color: Theme.textMuted; font.pixelSize: 13 }
                                SpinBox {
                                    from: 1; to: 999; value: modelData.minutes
                                    editable: true
                                    onValueModified: root._setMinute(index, value)
                                }
                                Text { text: "Giá (VND)"; color: Theme.textMuted; font.pixelSize: 13 }
                                SpinBox {
                                    Layout.fillWidth: true
                                    from: 0; to: 100000000; stepSize: 1000
                                    value: modelData.price; editable: true
                                    onValueModified: root._setPrice(index, value)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 2
                                FieldLabel { text: "Bật thanh toán gói phút" }
                                FieldHint {
                                    text: "Dùng chung tài khoản ngân hàng, máy nhận tiền và kho voucher của luồng chính."
                                    Layout.fillWidth: true
                                }
                            }
                            Switch {
                                checked: root.paymentEnabled
                                onToggled: {
                                    root.paymentEnabled = checked
                                    eventManager.setAppSetting("sbcut_payment_enabled", checked ? "true" : "false")
                                }
                            }
                        }
                    }
                }
            }

            // ───────── Tab 1: Giao diện ─────────
            ScrollView {
                anchors.fill: parent; anchors.margins: 28
                visible: root.selectedTab === 1
                contentWidth: availableWidth; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 28

                    Text { text: "Giao Diện"; color: "white"; font.pixelSize: 24; font.bold: true }

                    // Text "chạm để bắt đầu"
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        FieldLabel { text: "Chữ trên trang chờ" }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            TextField {
                                id: startTextField
                                Layout.fillWidth: true
                                text: root.startText
                                placeholderText: "Để trống nếu không muốn hiển thị chữ"
                                color: "#ffffff"
                                background: Rectangle { color: "#1f2229"; radius: 6; border.color: "#3a3d45" }
                                onEditingFinished: { root.startText = text; eventManager.setAppSetting("sbcut_start_text", text) }
                            }
                            Button {
                                text: "Xóa text"
                                background: Rectangle { color: parent.hovered ? "#d32f2f" : "#c62828"; radius: 6 }
                                contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 13; leftPadding: 14; rightPadding: 14; topPadding: 8; bottomPadding: 8 }
                                onClicked: { root.startText = ""; startTextField.text = ""; eventManager.setAppSetting("sbcut_start_text", "") }
                            }
                        }
                    }

                    // Nền trang chờ
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        FieldLabel { text: "Hình nền trang chờ" }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 220
                            color: "#1f2229"; radius: 8; border.color: "#3a3d45"
                            Image {
                                anchors.fill: parent; anchors.margins: 8
                                source: root._resolveImg(root.bgWaiting)
                                fillMode: Image.PreserveAspectFit; visible: source !== ""
                            }
                            Text { anchors.centerIn: parent; text: "Chưa có hình nền"; color: Theme.textMuted; font.pixelSize: 13; visible: root.bgWaiting === "" }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Button {
                                text: "📁 Tải hình"; Layout.fillWidth: true
                                background: Rectangle { color: parent.hovered ? "#1e7eea" : "#1976d2"; radius: 6 }
                                contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; topPadding: 10; bottomPadding: 10 }
                                onClicked: bgWaitingDialog.open()
                            }
                            Button {
                                text: "🗑️ Xóa"; Layout.preferredWidth: 120; enabled: root.bgWaiting !== ""
                                background: Rectangle { color: parent.enabled ? (parent.hovered ? "#d32f2f" : "#c62828") : "#2a2d35"; radius: 6 }
                                contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : "#666"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; topPadding: 10; bottomPadding: 10 }
                                onClicked: { root.bgWaiting = ""; eventManager.setAppSetting("sbcut_bg_waiting", "") }
                            }
                        }
                    }

                    // Nền trang kết quả/QR
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        FieldLabel { text: "Hình nền trang kết quả (QR)" }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 220
                            color: "#1f2229"; radius: 8; border.color: "#3a3d45"
                            Image {
                                anchors.fill: parent; anchors.margins: 8
                                source: root._resolveImg(root.bgResult)
                                fillMode: Image.PreserveAspectFit; visible: source !== ""
                            }
                            Text { anchors.centerIn: parent; text: "Chưa có hình nền"; color: Theme.textMuted; font.pixelSize: 13; visible: root.bgResult === "" }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Button {
                                text: "📁 Tải hình"; Layout.fillWidth: true
                                background: Rectangle { color: parent.hovered ? "#1e7eea" : "#1976d2"; radius: 6 }
                                contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; topPadding: 10; bottomPadding: 10 }
                                onClicked: bgResultDialog.open()
                            }
                            Button {
                                text: "🗑️ Xóa"; Layout.preferredWidth: 120; enabled: root.bgResult !== ""
                                background: Rectangle { color: parent.enabled ? (parent.hovered ? "#d32f2f" : "#c62828") : "#2a2d35"; radius: 6 }
                                contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : "#666"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; topPadding: 10; bottomPadding: 10 }
                                onClicked: { root.bgResult = ""; eventManager.setAppSetting("sbcut_bg_result", "") }
                            }
                        }
                    }

                    // Nền trang thanh toán Selfbooth
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        FieldLabel { text: "Hình nền trang thanh toán Selfbooth" }
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 220
                            color: "#1f2229"; radius: 8; border.color: "#3a3d45"
                            Image {
                                anchors.fill: parent; anchors.margins: 8
                                source: root._resolveImg(root.bgPayment)
                                fillMode: Image.PreserveAspectFit; visible: source !== ""
                            }
                            Text {
                                anchors.centerIn: parent; text: "Dùng nền thanh toán mặc định"
                                color: Theme.textMuted; font.pixelSize: 13; visible: root.bgPayment === ""
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Button {
                                text: "📁 Tải hình"; Layout.fillWidth: true
                                onClicked: bgPaymentDialog.open()
                            }
                            Button {
                                text: "🗑️ Xóa"; Layout.preferredWidth: 120; enabled: root.bgPayment !== ""
                                onClicked: {
                                    root.bgPayment = ""
                                    eventManager.setAppSetting("sbcut_bg_payment", "")
                                }
                            }
                        }
                    }
                }
            }

            // ───────── Tab 2: Chung & Lưu trữ ─────────
            ScrollView {
                anchors.fill: parent; anchors.margins: 28
                visible: root.selectedTab === 2
                contentWidth: availableWidth; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 28

                    Text { text: "Chung & Lưu Trữ"; color: "white"; font.pixelSize: 24; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            FieldLabel { text: "Ghép frame sau khi chụp" }
                            FieldHint {
                                text: "Tắt: chụp xong sang QR như hiện tại. Bật: chọn frame, chọn ảnh cho từng slot rồi mới sang QR."
                                Layout.fillWidth: true
                            }
                        }
                        Switch {
                            checked: root.frameEnabled
                            onToggled: {
                                root.frameEnabled = checked
                                eventManager.setAppSetting("sbcut_frame_enabled",
                                                           checked ? "true" : "false")
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        visible: root.frameEnabled
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 3
                                FieldLabel { text: "Kho khung frame Selfbooth" }
                                FieldHint {
                                    text: "Có thể tải nhiều PNG cùng lúc. Vùng trong suốt của PNG được nhận diện thành các slot ảnh."
                                    Layout.fillWidth: true
                                }
                            }
                            Button {
                                text: "＋ Tải frame"
                                onClicked: selfFrameUploadDialog.open()
                            }
                            Button {
                                text: "Làm mới"
                                onClicked: root.reloadSelfFrames()
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 240
                            color: "#101218"
                            radius: 10
                            border.color: "#343743"
                            clip: true

                            ListView {
                                anchors.fill: parent
                                anchors.margins: 14
                                orientation: ListView.Horizontal
                                spacing: 18
                                model: selfFrameModel
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                delegate: Rectangle {
                                    required property string fileName
                                    required property string path
                                    required property int slotCount
                                    width: 180
                                    height: 210
                                    radius: 8
                                    color: "#1f2229"
                                    border.color: "#3a3d45"

                                    Image {
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        anchors.bottomMargin: 42
                                        source: path
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        sourceSize: Qt.size(320, 320)
                                    }
                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: deleteFrameButton.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 10
                                        text: fileName + " · " + slotCount + " slot"
                                        color: Theme.border
                                        font.pixelSize: 11
                                        elide: Text.ElideMiddle
                                    }
                                    Button {
                                        id: deleteFrameButton
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 6
                                        width: 34; height: 34
                                        text: "✕"
                                        onClicked: {
                                            eventManager.deleteSelfBoothLayout(path)
                                            root.reloadSelfFrames()
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: selfFrameModel.count === 0
                                text: "Chưa có frame Selfbooth"
                                color: Theme.textMuted
                                font.pixelSize: 14
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 1; color: "#343743"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        FieldLabel { text: "Thư mục lưu ảnh Selfbooth" }
                        FieldHint { text: "Ảnh selfbooth lưu riêng, không ảnh hưởng thư mục sự kiện chính."; Layout.fillWidth: true }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 56
                            color: "#1f2229"; radius: 6; border.color: "#3a3d45"
                            Text {
                                anchors.fill: parent; anchors.margins: 14
                                text: root.saveDir !== "" ? root.saveDir : (root.defaultSaveDir + "  (mặc định)")
                                color: Theme.textMuted; font.pixelSize: 13
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideMiddle
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Button {
                                text: "📁 Chọn thư mục"; Layout.fillWidth: true
                                background: Rectangle { color: parent.hovered ? "#1e7eea" : "#1976d2"; radius: 6 }
                                contentItem: Text { text: parent.text; color: "#ffffff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; topPadding: 10; bottomPadding: 10 }
                                onClicked: saveDirDialog.open()
                            }
                            Button {
                                text: "Mặc định"; Layout.preferredWidth: 140; enabled: root.saveDir !== ""
                                background: Rectangle { color: parent.enabled ? (parent.hovered ? "#3a4455" : "#2a2d35") : "#22242c"; radius: 6 }
                                contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : "#666"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; topPadding: 10; bottomPadding: 10 }
                                onClicked: { root.saveDir = ""; eventManager.setAppSetting("sbcut_save_dir", "") }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; height: 1; color: "#343743"
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            FieldLabel { text: "Doanh thu Selfbooth" }
                            FieldHint {
                                text: "Chỉ hiển thị các bản ghi source=selfbooth."
                                Layout.fillWidth: true
                            }
                        }
                        Button {
                            text: "Làm mới"
                            onClicked: root.reloadSelfRevenue()
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 72
                        color: "#1f2229"; radius: 8; border.color: "#3a3d45"
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 16
                            Text { text: "Tổng doanh thu"; color: Theme.textMuted; font.pixelSize: 14 }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: Money.vnd(root.selfRevenueTotal)
                                color: "#4ade80"; font.pixelSize: 24; font.bold: true
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 8
                        Repeater {
                            model: selfRevenueModel
                            delegate: Rectangle {
                                required property string recordedAt
                                required property int amount
                                required property string paymentMethod
                                required property string note
                                Layout.fillWidth: true; Layout.preferredHeight: 68
                                color: "#1f2229"; radius: 6
                                RowLayout {
                                    anchors.fill: parent; anchors.margins: 12; spacing: 12
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 2
                                        Text { text: note; color: "#ffffff"; font.pixelSize: 13 }
                                        Text {
                                            text: recordedAt + " • " + paymentMethod
                                            color: "#888888"; font.pixelSize: 11
                                        }
                                    }
                                    Text {
                                        text: Money.vnd(amount)
                                        color: "#4ade80"; font.pixelSize: 15; font.bold: true
                                    }
                                }
                            }
                        }
                        Text {
                            visible: selfRevenueModel.count === 0
                            text: "Chưa có giao dịch Selfbooth."
                            color: Theme.textMuted; font.pixelSize: 13
                        }
                    }
                }
            }

            // ───────── Tab 3: Bảo mật ─────────
            ScrollView {
                anchors.fill: parent; anchors.margins: 28
                visible: root.selectedTab === 3
                contentWidth: availableWidth; clip: true

                ColumnLayout {
                    width: parent.width; spacing: 28

                    Text { text: "Bảo Mật"; color: "white"; font.pixelSize: 24; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            FieldLabel { text: "Yêu cầu PIN khi thoát" }
                            FieldHint { text: "Khi bật, bấm X tại trang chờ phải nhập PIN admin mới quay lại được."; Layout.fillWidth: true }
                        }
                        Switch {
                            checked: root.securityOn
                            onToggled: { root.securityOn = checked; eventManager.setAppSetting("sbcut_security_enabled", checked ? "true" : "false") }
                        }
                    }
                }
            }
        }
    }

    // Bàn phím ảo cho TextField (kiosk)
    InputPanel {
        id: inputPanel
        z: 99
        y: active ? parent.height - height : parent.height
        anchors.left: parent.left
        anchors.right: parent.right
        Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    }

    Component.onCompleted: {
        reloadSelfRevenue()
        reloadSelfFrames()
    }
}
