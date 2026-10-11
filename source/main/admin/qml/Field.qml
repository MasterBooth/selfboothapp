import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ô nhập có nhãn phía trên. Lỗi hiện ngay dưới ô, cùng màu với viền.
ColumnLayout {
    id: f
    property alias text: input.text
    property alias input: input
    property string label: ""
    property string hint: ""
    property string error: ""
    property alias placeholderText: input.placeholderText
    property alias echoMode: input.echoMode
    property bool mono: false
    signal accepted()
    signal textEdited()

    spacing: Tk.s2xs

    Text {
        text: f.label
        visible: f.label !== ""
        color: Tk.muted
        font.family: Tk.body
        font.pixelSize: Tk.textXs
        font.weight: Font.DemiBold
    }

    TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: Tk.control
        leftPadding: Tk.sSm
        rightPadding: Tk.sSm
        color: Tk.ink
        placeholderTextColor: Tk.neutral
        selectionColor: Tk.accent
        selectedTextColor: Tk.accentInk
        font.family: f.mono ? Tk.mono : Tk.body
        font.pixelSize: Tk.textSm
        selectByMouse: true
        onAccepted: f.accepted()
        onTextEdited: f.textEdited()
        background: Rectangle {
            radius: Tk.radiusSm
            color: input.enabled ? Tk.surface : Tk.paper2
            border.width: input.activeFocus || f.error !== "" ? 2 : 1
            border.color: f.error !== "" ? Tk.error
                        : input.activeFocus ? Tk.focus
                        : input.hovered ? Tk.ruleStrong : Tk.rule
        }
    }

    Text {
        Layout.fillWidth: true
        visible: text !== ""
        text: f.error !== "" ? f.error : f.hint
        color: f.error !== "" ? Tk.error : Tk.neutral
        font.family: Tk.body
        font.pixelSize: Tk.textXs
        wrapMode: Text.WordWrap
    }
}
