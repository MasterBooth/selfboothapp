import QtQuick
import QtQuick.Controls

// Lựa chọn dạng chip (một trong nhiều) — dùng cho hạng thiết bị và thời hạn.
AbstractButton {
    id: c
    property bool selected: false
    checkable: false
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    implicitHeight: 36
    implicitWidth: t.implicitWidth + Tk.sMd * 2

    contentItem: Text {
        id: t
        text: c.text
        color: c.selected ? Tk.accentInk : Tk.ink
        opacity: c.enabled ? 1 : 0.45
        font.family: Tk.body
        font.pixelSize: Tk.textSm
        font.weight: c.selected ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        maximumLineCount: 1
    }
    background: Rectangle {
        radius: Tk.radiusPill
        color: c.selected ? Tk.accent : c.down ? Tk.paper3 : c.hovered ? Tk.paper2 : Tk.surface
        border.width: c.selected ? 0 : 1
        border.color: Tk.rule
        Behavior on color { ColorAnimation { duration: Tk.durMicro } }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"; border.width: 2; border.color: Tk.focus
            visible: c.visualFocus
        }
    }
}
