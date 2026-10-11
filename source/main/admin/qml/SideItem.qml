import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Mục điều hướng trên sidebar: vạch nhấn bên trái khi đang chọn + số đếm.
AbstractButton {
    id: s
    property bool current: false
    property int count: -1               // -1 = không hiện số
    property bool attention: false       // số đếm cần chú ý (máy chờ duyệt)
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 40
    Layout.fillWidth: true

    background: Rectangle {
        radius: Tk.radiusSm
        color: s.current ? Tk.sideActive : s.hovered ? Qt.lighter(Tk.side, 1.25) : "transparent"
        Rectangle {
            visible: s.current
            width: 3; radius: 2
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 10; bottomMargin: 10 }
            color: Tk.accentSoft
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -2
            radius: parent.radius + 2
            color: "transparent"; border.width: 2; border.color: Tk.accentSoft
            visible: s.visualFocus
        }
    }

    contentItem: RowLayout {
        spacing: Tk.sXs
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Tk.sSm
            text: s.text
            color: s.current ? Tk.sideInk : Tk.sideMuted
            font.family: Tk.body
            font.pixelSize: Tk.textSm
            font.weight: s.current ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }
        Rectangle {
            visible: s.count >= 0
            Layout.rightMargin: Tk.sXs
            implicitWidth: Math.max(24, n.implicitWidth + 12)
            implicitHeight: 20
            radius: 10
            color: s.attention && s.count > 0 ? Tk.accentSoft : "transparent"
            border.width: s.attention && s.count > 0 ? 0 : 1
            border.color: Tk.sideMuted
            Text {
                id: n
                anchors.centerIn: parent
                text: s.count
                color: s.attention && s.count > 0 ? Tk.accent : Tk.sideMuted
                font.family: Tk.body
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }
}
