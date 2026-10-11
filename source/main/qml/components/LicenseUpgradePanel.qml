import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    signal notify(string message)

    // ── Palette có thể cấu hình ──────────────────────────────────────────────
    // Mặc định tone tối (Theme.*) cho trang tối (SettingSelf). SettingsPage truyền
    // palette sáng để chữ/card đọc được trên nền sáng chữ đen.
    property color panelText:    Theme.text
    property color panelMuted:   Theme.textMuted
    property color panelSurface: Theme.surface
    property color panelBorder:  Theme.border
    property color accentGreen:  "#4ade80"
    property color accentAmber:  "#f0c040"
    // Nền cho popup QR — cần đặc (không trong suốt) kể cả khi card để trong suốt.
    property color popupSurface: Theme.surface

    property var _intent: null
    property string _payStatus: ""
    property int buyYears: 1
    readonly property string currentTier: machineAuth.deviceTier || ""
    readonly property bool hasPaidTier: currentTier !== "" && currentTier !== "trial"

    function fmtVnd(value) {
        return Number(value || 0).toLocaleString(Qt.locale("vi_VN"), "f", 0) + "đ"
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            Text { text: "Thông tin & nâng cấp"; color: root.panelText; font.pixelSize: 24; font.bold: true }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 116
                color: root.panelSurface; radius: 12; border.color: root.panelBorder; border.width: 1
                RowLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 24
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: "HWID"; color: root.panelMuted; font.pixelSize: 12 }
                        Text { text: machineAuth.hwid || "—"; color: root.panelText; font.pixelSize: 15; font.family: "Courier"; elide: Text.ElideMiddle; Layout.fillWidth: true }
                    }
                    ColumnLayout {
                        Text { text: "Hạng thiết bị"; color: root.panelMuted; font.pixelSize: 12 }
                        Text { text: root.currentTier || "Chưa được cấp"; color: root.currentTier ? root.accentGreen : root.accentAmber; font.pixelSize: 17; font.bold: true }
                    }
                    ColumnLayout {
                        Text { text: "Hạn license"; color: root.panelMuted; font.pixelSize: 12 }
                        Text { text: machineAuth.licenseEnd || "Không giới hạn"; color: root.panelText; font.pixelSize: 17; font.bold: true }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Các gói dịch vụ"; color: root.panelText; font.pixelSize: 19; font.bold: true }
                Item { Layout.fillWidth: true }
                Button { text: "−"; enabled: root.buyYears > 1; onClicked: root.buyYears-- }
                Text { text: root.buyYears + " năm"; color: root.panelText; font.pixelSize: 14; font.bold: true }
                Button { text: "+"; enabled: root.buyYears < 10; onClicked: root.buyYears++ }
            }

            Repeater {
                model: licenseStore.plans
                delegate: Rectangle {
                    id: planCard
                    Layout.fillWidth: true; Layout.preferredHeight: 126
                    color: root.panelSurface; radius: 12
                    border.width: isCurrent ? 2 : 1
                    border.color: isCurrent ? root.accentGreen : root.panelBorder
                    property bool isCurrent: root.currentTier === String(modelData.device_tier || "")
                    property var caps: modelData.capabilities || ({})

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 16
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 5
                            Text { text: modelData.name || modelData.code; color: root.panelText; font.pixelSize: 17; font.bold: true }
                            Text { text: modelData.description || ""; color: root.panelMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Text {
                                text: (caps.event ? "Event  " : "") + (caps.studio ? "Studio  " : "") + (caps.selfbooth ? "Self-booth" : "")
                                color: root.accentGreen; font.pixelSize: 12; font.bold: true
                            }
                        }
                        ColumnLayout {
                            Layout.preferredWidth: 190; spacing: 8
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: modelData.is_contact ? "Liên hệ báo giá"
                                      : root.fmtVnd(licenseStore.totalForYears(modelData.price_per_year, root.buyYears))
                                color: modelData.is_contact ? root.accentAmber : root.panelText
                                font.pixelSize: 14; font.bold: true
                            }
                            Button {
                                id: planBtn
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                text: planCard.isCurrent ? "Đang sử dụng" : (modelData.is_contact ? "Liên hệ" : (root.hasPaidTier ? "Đổi gói" : "Mua"))
                                enabled: !licenseStore.busy && !planCard.isCurrent
                                // Đang sử dụng → nền vàng/amber; còn lại (Mua/Đổi gói/Liên hệ) → nền xanh lá.
                                background: Rectangle {
                                    radius: 8
                                    color: planCard.isCurrent
                                           ? root.accentAmber
                                           : (planBtn.down ? Qt.darker(root.accentGreen, 1.15)
                                              : (planBtn.hovered ? Qt.lighter(root.accentGreen, 1.1) : root.accentGreen))
                                    opacity: planCard.isCurrent ? 1.0 : (planBtn.enabled ? 1.0 : 0.45)
                                    Behavior on color { ColorAnimation { duration: 130 } }
                                }
                                contentItem: Text {
                                    text: planBtn.text
                                    color: "#ffffff"
                                    font.pixelSize: 14
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }
                                onClicked: {
                                    if (modelData.is_contact) {
                                        root.notify("Premium mở toàn bộ chế độ. Liên hệ 0395458706 hoặc boothstudio2026@gmail.com để kích hoạt.")
                                        return
                                    }
                                    licenseStore.createIntent(machineAuth.hwid, modelData.code,
                                                              root.hasPaidTier ? 1 : root.buyYears,
                                                              root.hasPaidTier ? "switch" : "new")
                                }
                            }
                        }
                    }
                }
            }

            Text {
                visible: licenseStore.plans.length === 0
                text: licenseStore.busy ? "Đang tải danh sách gói..." : "Không tải được danh sách gói."
                color: root.panelMuted; font.pixelSize: 14
            }
            Item { Layout.preferredHeight: 20 }
        }
    }

    Component.onCompleted: {
        licenseStore.fetchPlans()
        machineAuth.retryAuthentication()
    }

    Connections {
        target: licenseStore
        function onIntentCreated(intent) {
            root._intent = intent; root._payStatus = "pending"; qrPopup.open(); payPoll.start()
        }
        function onIntentStatus(code, status) {
            if (!root._intent || code !== root._intent.code) return
            root._payStatus = status
            if (status === "paid") {
                payPoll.stop(); qrPopup.close()
                root.notify("Thanh toán thành công. Đang cập nhật hạng thiết bị...")
                machineAuth.retryAuthentication()
            }
        }
        function onSwitchApplied() {
            root.notify("Đã đổi gói thành công.")
            machineAuth.retryAuthentication()
        }
        function onErrorOccurred(message) { root.notify("Lỗi: " + message) }
    }

    Timer {
        id: payPoll; interval: 4000; repeat: true
        onTriggered: if (root._intent) licenseStore.checkIntent(machineAuth.hwid, root._intent.code)
    }

    Popup {
        id: qrPopup
        parent: Overlay.overlay; anchors.centerIn: Overlay.overlay; modal: true
        closePolicy: Popup.CloseOnEscape; width: 430; height: 570
        onClosed: payPoll.stop()
        background: Rectangle { color: root.popupSurface; radius: 12; border.color: root.panelBorder }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24; spacing: 12
            Text { text: "Thanh toán nâng cấp"; color: root.panelText; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Image {
                Layout.alignment: Qt.AlignHCenter; Layout.preferredWidth: 270; Layout.preferredHeight: 270
                source: root._intent ? root._intent.qr_url : ""; fillMode: Image.PreserveAspectFit
            }
            Text { text: root._intent ? root.fmtVnd(root._intent.amount) : ""; color: root.accentGreen; font.pixelSize: 20; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text { text: "Nội dung: " + (root._intent ? root._intent.content : ""); color: root.accentAmber; font.pixelSize: 14; font.bold: true; Layout.alignment: Qt.AlignHCenter }
            Text { text: root._payStatus === "paid" ? "Đã thanh toán ✓" : "Đang chờ thanh toán..."; color: root.panelMuted; Layout.alignment: Qt.AlignHCenter }
            Button { text: "Đóng"; Layout.alignment: Qt.AlignHCenter; onClicked: qrPopup.close() }
        }
    }
}
