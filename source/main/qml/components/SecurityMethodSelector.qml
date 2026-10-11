import QtQuick
import QtQuick.Layouts
import "../theme"

// Bộ 3 nút chọn phương thức bảo mật dùng chung cho mọi cửa xác thực
// (mở ứng dụng, vào Cài đặt, thoát session về trang quản lý sự kiện).
GridLayout {
    id: root

    property string method: "pin"      // "qr" | "pin" | "both"
    signal picked(string method)

    columns: width >= 900 ? 3 : 1
    columnSpacing: 12
    rowSpacing: 12

    component MethodCard: Rectangle {
        id: card
        property string value: ""
        property string icon: ""
        property string label: ""
        property string hint: ""
        readonly property bool selected: root.method === value

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.preferredHeight: 108
        radius: Theme.settingsRadiusSmall
        color: selected ? Theme.settingsCopperSoft : Theme.settingsCard
        border.color: selected ? Theme.settingsCopper : Theme.settingsBorder
        border.width: selected ? 2 : 1
        Behavior on color { ColorAnimation { duration: 120 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text { text: card.icon; font.pixelSize: 20 }
                Text {
                    Layout.fillWidth: true
                    text: card.label
                    color: Theme.settingsText
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                // Chấm tròn báo lựa chọn đang áp dụng
                Rectangle {
                    Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10
                    color: card.selected ? Theme.settingsCopper : "transparent"
                    border.color: card.selected ? Theme.settingsCopper : Theme.settingsBorder
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        visible: card.selected
                        text: "✓"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: card.hint
                color: Theme.settingsTextMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (!card.selected) root.picked(card.value)
        }
    }

    MethodCard {
        value: "qr"
        icon: "📱"
        label: "Dùng mã QR bảo mật"
        hint: "Mọi dialog xác thực chỉ hiện mã QR — quét bằng điện thoại để mở."
    }
    MethodCard {
        value: "pin"
        icon: "🔑"
        label: "Dùng mật khẩu bảo mật"
        hint: "Mọi dialog xác thực yêu cầu nhập mã PIN quản trị."
    }
    MethodCard {
        value: "both"
        icon: "🔐"
        label: "Dùng cả hai"
        hint: "Mặc định hiện mã QR; nút “Nhập mật khẩu” ở góc dialog để chuyển sang PIN."
    }
}
