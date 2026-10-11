import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

/*
 * Tab "Thông tin" — thay thế LicenseUpgradePanel (đã ẩn giá gói & mua gói trong app).
 * Hiển thị: thông tin máy (HWID/hạng/hạn license), chủ studio + email + danh sách
 * nhân viên (từ worker qua qrLoginManager.fetchStudioInfo), lượt đăng nhập QR gần
 * nhất và khối liên hệ hỗ trợ.
 */
Item {
    id: root

    signal notify(string message)

    // ── Palette có thể cấu hình (giữ tương thích chỗ nhúng LicenseUpgradePanel cũ) ──
    property color panelText:    Theme.text
    property color panelMuted:   Theme.textMuted
    property color panelSurface: Theme.surface
    property color panelBorder:  Theme.border
    property color accentGreen:  "#4ade80"
    property color accentAmber:  "#f0c040"
    property color popupSurface: Theme.surface

    readonly property string currentTier: machineAuth.deviceTier || ""
    readonly property var _studio: qrLoginManager.studioInfo
    readonly property bool _studioLoaded: _studio && _studio.loaded === true
    readonly property string _studioError: qrLoginManager.studioInfoError || ""
    readonly property var _staffList: (_studioLoaded && _studio.staff) ? _studio.staff : []

    // Lượt đăng nhập QR gần nhất (đọc lại mỗi lần mở tab)
    property string lastQrEmail: ""
    property string lastQrName: ""
    property string lastQrRole: ""
    property string lastQrAt: ""

    function _fmtIso(iso) {
        if (!iso) return ""
        var d = new Date(iso)
        if (isNaN(d.getTime())) return iso
        return Qt.formatDateTime(d, "HH:mm dd/MM/yyyy")
    }

    function _studioTitle() {
        if (qrLoginManager.studioInfoLoading) return "Đang tải..."
        if (root._studioError !== "") return root._studioError
        if (root._studioLoaded) return root._studio.owner_name || root._studio.brand || "Chưa cập nhật"
        return "Chưa có dữ liệu từ máy chủ"
    }

    function refreshStudioInfo() {
        if (machineAuth.hwid)
            qrLoginManager.fetchStudioInfo(machineAuth.hwid)
        lastQrEmail = eventManager.getAppSetting("last_qr_login_email", "")
        lastQrName  = eventManager.getAppSetting("last_qr_login_name", "")
        lastQrRole  = eventManager.getAppSetting("last_qr_login_role", "")
        lastQrAt    = eventManager.getAppSetting("last_qr_login_at", "")
    }

    Component.onCompleted: refreshStudioInfo()

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 16

            Text { text: "Thông tin"; color: root.panelText; font.pixelSize: 24; font.bold: true }

            // ── Thông tin máy ────────────────────────────────────────────────
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

            // ── Studio: chủ, email, nhân viên ────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Studio"; color: root.panelText; font.pixelSize: 19; font.bold: true; Layout.fillWidth: true }
                Button {
                    text: qrLoginManager.studioInfoLoading ? "Đang tải..." : "Làm mới"
                    enabled: !qrLoginManager.studioInfoLoading
                    onClicked: root.refreshStudioInfo()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: studioCol.implicitHeight + 36
                color: root.panelSurface; radius: 12; border.color: root.panelBorder; border.width: 1

                ColumnLayout {
                    id: studioCol
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true; spacing: 24
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: "Chủ studio"; color: root.panelMuted; font.pixelSize: 12 }
                            Text {
                                text: root._studioTitle()
                                color: root.panelText; font.pixelSize: 16; font.bold: true
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: "Email studio"; color: root.panelMuted; font.pixelSize: 12 }
                            Text {
                                text: (root._studioLoaded && root._studio.owner_email)
                                      ? root._studio.owner_email
                                      : "—"
                                color: root.panelText; font.pixelSize: 15
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.panelBorder; opacity: 0.6 }

                    Text {
                        visible: root._studioError === ""
                        text: "Nhân viên được studio thêm (" + root._staffList.length + ")"
                        color: root.panelMuted; font.pixelSize: 12
                    }

                    Repeater {
                        model: root._staffList
                        delegate: RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            Rectangle {
                                Layout.preferredWidth: 8; Layout.preferredHeight: 8; radius: 4
                                color: root.accentGreen
                            }
                            Text {
                                text: (modelData.staff_name ? modelData.staff_name + "  —  " : "") + modelData.staff_email
                                color: root.panelText; font.pixelSize: 14
                                elide: Text.ElideRight; Layout.fillWidth: true
                            }
                        }
                    }

                    Text {
                        visible: root._studioLoaded && root._studioError === "" && root._staffList.length === 0
                        text: "Chưa có nhân viên nào. Thêm nhân viên trong Cổng khách hàng → Cài đặt."
                        color: root.panelMuted; font.pixelSize: 13
                    }
                }
            }

            // ── Đăng nhập QR gần nhất ────────────────────────────────────────
            Text { text: "Đăng nhập QR gần nhất"; color: root.panelText; font.pixelSize: 19; font.bold: true }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 92
                color: root.panelSurface; radius: 12; border.color: root.panelBorder; border.width: 1
                RowLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 24
                    visible: root.lastQrEmail !== ""
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Tài khoản"; color: root.panelMuted; font.pixelSize: 12 }
                        Text {
                            text: (root.lastQrName ? root.lastQrName + "  —  " : "") + root.lastQrEmail
                            color: root.panelText; font.pixelSize: 15; font.bold: true
                            elide: Text.ElideRight; Layout.fillWidth: true
                        }
                    }
                    ColumnLayout {
                        spacing: 3
                        Text { text: "Vai trò"; color: root.panelMuted; font.pixelSize: 12 }
                        Text {
                            text: root.lastQrRole === "owner" ? "Chủ studio" : "Nhân viên"
                            color: root.lastQrRole === "owner" ? root.accentAmber : root.accentGreen
                            font.pixelSize: 15; font.bold: true
                        }
                    }
                    ColumnLayout {
                        spacing: 3
                        Text { text: "Thời gian"; color: root.panelMuted; font.pixelSize: 12 }
                        Text { text: root._fmtIso(root.lastQrAt); color: root.panelText; font.pixelSize: 15 }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.lastQrEmail === ""
                    text: "Chưa có lượt đăng nhập QR nào trên máy này."
                    color: root.panelMuted; font.pixelSize: 14
                }
            }

            // ── Hỗ trợ ───────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 92
                color: root.panelSurface; radius: 12; border.color: root.panelBorder; border.width: 1
                RowLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 24
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { text: "Hỗ trợ BOOTHME"; color: root.panelMuted; font.pixelSize: 12 }
                        Text { text: "Hotline 0395458706  ·  boothstudio2026@gmail.com"; color: root.panelText; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                    }
                    Text {
                        text: machineAuth.statusMessage || ""
                        color: root.panelMuted; font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            Item { Layout.preferredHeight: 20 }
        }
    }
}
