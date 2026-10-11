import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Dialog {
    id: root

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent
    width: 640
    height: 620
    padding: 0

    // ── Properties ────────────────────────────────────────────────────────────
    property int   eventId:   -1
    property var   eventData: ({})
    property bool  systemEvent: false
    property string badgeText: ""

    // ── Signals ───────────────────────────────────────────────────────────────
    signal launchClicked(int eventId)
    signal settingsClicked(int eventId)
    signal duplicateRequested(int eventId)
    signal renameRequested(int eventId)
    signal deleteRequested(int eventId)

    // Chuẩn hoá đường dẫn ảnh layout (tham khảo _resolveImg ở LayoutSelection.qml).
    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    // Làm mờ nền phía sau cho cảm giác premium (frosted scrim).
    Overlay.modal: Rectangle { color: "#66101418" }

    // ── Styling — thẻ sáng frosted ──────────────────────────────────────────────
    background: Rectangle {
        color: "#FFFFFF"
        radius: 20
        border.color: "#E2E6EC"
        border.width: 1

        // Bóng đổ mềm (nhiều lớp viền mờ).
        Rectangle {
            anchors.fill: parent
            anchors.margins: -6
            radius: parent.radius + 6
            z: -1
            color: "transparent"
            border.color: "#14000000"
            border.width: 6
        }

        // Thanh gradient accent ở đỉnh.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 4
            radius: 20
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#4FA4F2" }
                GradientStop { position: 1.0; color: "#2D86DE" }
            }
        }
    }

    // Bỏ header/footer mặc định của Dialog.
    header: Item { height: 0 }
    footer: Item { height: 0 }

    // ── Content ───────────────────────────────────────────────────────────────
    contentItem: Item {
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 0

            // ── Top row: icon + tên + trạng thái + nút đóng ───────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Monogram: chữ cái đầu của tên sự kiện (thay cho icon).
                Rectangle {
                    width: 56; height: 56; radius: 14
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#4FA4F2" }
                        GradientStop { position: 1.0; color: "#2D86DE" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: (root.eventData.name || "S").trim().charAt(0).toUpperCase()
                        color: "#ffffff"
                        font.pixelSize: 28
                        font.weight: Font.Bold
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        text: root.eventData.name || "Sự kiện"
                        color: "#1F2430"
                        font.pixelSize: 28
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 7
                        Rectangle { width: 9; height: 9; radius: 4.5; color: "#10b981" }
                        Text {
                            text: "Sẵn sàng khởi chạy"
                            color: "#10b981"
                            font.pixelSize: 15
                            font.weight: Font.Medium
                        }
                    }
                }

                Rectangle {
                    width: 34; height: 34; radius: 10
                    color: closeBtnMouse.containsMouse ? "#EEF1F5" : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#6B7280"
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#ECEFF3"
                Layout.topMargin: 20
                Layout.bottomMargin: 20
            }

            // ── Xem trước khung (layout) ──────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 14
                color: "#F7F8FA"
                border.color: "#ECEFF3"
                border.width: 1

                Image {
                    id: layoutPreview
                    anchors.fill: parent
                    anchors.margins: 16
                    source: root._resolveImg(root.eventData.selectedLayout)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    cache: true
                    asynchronous: true
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: layoutPreview.status !== Image.Ready
                    text: "Chưa chọn khung hình"
                    color: "#9AA3AF"
                    font.pixelSize: 18
                    font.weight: Font.Medium
                }
            }

            // ── Khu nút hành động — chữ to rõ, không icon ─────────────────
            // Hàng 3 nút phụ (Cài đặt / Đổi tên / Xóa) + nút chính Khởi Chạy lớn.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: 24
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ActionTile {
                        label: "Cài đặt"
                        baseColor: "#4FA4F2"
                        hoverColor: "#73B9F5"
                        onClicked: { root.close(); root.settingsClicked(root.eventId) }
                    }
                    ActionTile {
                        label: "Nhân bản"
                        baseColor: "#8B5CF6"
                        hoverColor: "#A78BFA"
                        onClicked: { root.close(); root.duplicateRequested(root.eventId) }
                    }
                    ActionTile {
                        label: "Đổi tên"
                        visible: !root.systemEvent
                        baseColor: "#F59E0B"
                        hoverColor: "#FBB72A"
                        onClicked: { root.close(); root.renameRequested(root.eventId) }
                    }
                    ActionTile {
                        label: "Xóa"
                        visible: !root.systemEvent
                        baseColor: "#EF4444"
                        hoverColor: "#F66"
                        onClicked: { root.close(); root.deleteRequested(root.eventId) }
                    }
                }

                // Khởi chạy — nút chính, lớn, full-width
                ActionTile {
                    Layout.fillWidth: true
                    label: "Khởi Chạy"
                    baseColor: "#10B981"
                    hoverColor: "#34D399"
                    hero: true
                    onClicked: { root.close(); root.launchClicked(root.eventId) }
                }
            }
        }
    }

    // Tile hành động: nền màu đặc theo chức năng, chỉ chữ (không icon), chữ trắng to.
    // hero=true → cao hơn, chữ lớn hơn, viền glow + nhịp đập để làm hành động chính nổi bật.
    component ActionTile: Rectangle {
        id: tile
        property string label: ""
        property color baseColor: "#4FA4F2"
        property color hoverColor: "#73B9F5"
        property bool hero: false
        signal clicked()

        Layout.fillWidth: true
        Layout.preferredHeight: hero ? 66 : 58
        radius: 14
        color: tileMouse.pressed ? Qt.darker(baseColor, 1.12)
             : tileMouse.containsMouse ? hoverColor : baseColor
        Behavior on color { ColorAnimation { duration: 130 } }

        scale: tileMouse.pressed ? 0.97 : 1.0
        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

        // Viền glow cho hero
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            radius: parent.radius + 4
            color: "transparent"
            visible: tile.hero
            border.color: Qt.rgba(0.06, 0.72, 0.51, tileMouse.containsMouse ? 0.45 : 0.22)
            border.width: 3
            Behavior on border.color { ColorAnimation { duration: 200 } }
        }

        Text {
            anchors.centerIn: parent
            text: tile.label
            color: "#ffffff"
            font.pixelSize: tile.hero ? 23 : 19
            font.weight: Font.Bold
        }

        MouseArea {
            id: tileMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        // Nhịp đập nhẹ cho hero khi không hover.
        SequentialAnimation on scale {
            running: tile.hero && root.visible && !tileMouse.containsMouse && !tileMouse.pressed
            loops: Animation.Infinite
            NumberAnimation { to: 1.02; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0;  duration: 900; easing.type: Easing.InOutSine }
        }
    }

    // Enter / exit animation
    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 200 }
        NumberAnimation { property: "scale";  from: 0.92; to: 1.0; duration: 200; easing.type: Easing.OutQuad }
    }
    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 160 }
        NumberAnimation { property: "scale";  from: 1.0; to: 0.94; duration: 160; easing.type: Easing.InQuad }
    }
}
