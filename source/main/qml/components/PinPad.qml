import QtQuick
import QtQuick.Layouts
import "../theme"

// Bàn phím số nhúng cho PIN/mật khẩu số.
Item {
    id: pad

    signal digit(string d)
    signal backspace()
    signal submit()

    property bool submitEnabled: true
    property bool backspaceEnabled: true

    property color accent: Theme.settingsCopper
    property color keyFill: Theme.settingsCard
    property color keyFillDown: Theme.settingsCopperSoft
    property color keyBorder: Theme.settingsBorder
    property color keyText: Theme.settingsText
    property real keyRadius: Theme.settingsRadiusMedium
    property real keySpacing: 10
    property real minKeyHeight: 62
    property bool iosStyle: false
    property bool showLetters: false
    property real keyDiameter: 92

    implicitWidth: iosStyle ? 440 : 420
    implicitHeight: grid.rows * (iosStyle ? keyDiameter : minKeyHeight) + (grid.rows - 1) * keySpacing

    function _lettersForDigit(d) {
        if (d === "2") return "ABC"
        if (d === "3") return "DEF"
        if (d === "4") return "GHI"
        if (d === "5") return "JKL"
        if (d === "6") return "MNO"
        if (d === "7") return "PQRS"
        if (d === "8") return "TUV"
        if (d === "9") return "WXYZ"
        return ""
    }

    component PinKey: FocusScope {
        id: key
        property string label: ""
        property string subLabel: ""
        property string accessibleName: label
        property color fill: pad.keyFill
        property color fillDown: pad.keyFillDown
        property color borderColor: pad.keyBorder
        property color labelColor: pad.keyText
        property real labelSize: 25
        property bool keyEnabled: true
        property bool primary: false
        property bool danger: false
        signal activated()

        Layout.fillWidth: true
        Layout.fillHeight: true
        activeFocusOnTab: keyEnabled
        enabled: keyEnabled
        opacity: keyEnabled ? 1.0 : 0.42
        scale: ma.pressed && keyEnabled ? 0.985 : 1.0
        Accessible.role: Accessible.Button
        Accessible.name: accessibleName
        Keys.onReturnPressed: if (keyEnabled) key.activated()
        Keys.onEnterPressed: if (keyEnabled) key.activated()
        Keys.onSpacePressed: if (keyEnabled) key.activated()

        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
        Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        Rectangle {
            anchors.centerIn: parent
            width: pad.iosStyle ? Math.min(parent.width, parent.height) : parent.width
            height: pad.iosStyle ? width : parent.height
            radius: pad.iosStyle ? width / 2 : pad.keyRadius
            color: {
                if (!keyEnabled) return Theme.settingsCanvas
                if (key.primary)
                    return ma.pressed ? Theme.settingsCopperDark
                                      : (ma.containsMouse || key.activeFocus ? Qt.lighter(pad.accent, 1.06) : pad.accent)
                if (key.danger)
                    return ma.pressed ? "#F4D4D0"
                                      : (ma.containsMouse || key.activeFocus ? "#FBE6E1" : "#FFF8F5")
                return ma.pressed ? fillDown
                                  : (ma.containsMouse || key.activeFocus ? "#FFF8F3" : fill)
            }
            border.width: key.activeFocus ? 2 : 1
            border.color: {
                if (!keyEnabled) return Theme.settingsBorder
                if (key.primary) return pad.accent
                if (key.danger) return ma.containsMouse || key.activeFocus ? Theme.settingsDanger : "#F1CDC5"
                return ma.containsMouse || key.activeFocus ? pad.accent : borderColor
            }
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Column {
                anchors.centerIn: parent
                spacing: pad.iosStyle ? 2 : 0

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: key.label
                    color: {
                        if (key.primary) return "#FFFFFF"
                        if (key.danger) return Theme.settingsDanger
                        return key.labelColor
                    }
                    font.pixelSize: key.labelSize
                    font.weight: pad.iosStyle ? Font.Light : Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Text {
                    visible: pad.showLetters && key.subLabel !== ""
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: key.subLabel
                    color: key.labelColor
                    opacity: 0.72
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 2.4
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            enabled: key.keyEnabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                key.forceActiveFocus()
                key.activated()
            }
        }
    }

    GridLayout {
        id: grid
        anchors.fill: parent
        columns: 3
        rows: 4
        rowSpacing: pad.keySpacing
        columnSpacing: pad.keySpacing

        Repeater {
            model: 9
            PinKey {
                property string digitText: String(index + 1)
                label: digitText
                subLabel: pad._lettersForDigit(digitText)
                labelSize: pad.iosStyle ? 35 : 25
                accessibleName: "So " + digitText
                onActivated: pad.digit(digitText)
            }
        }

        PinKey {
            label: "⌫"
            accessibleName: "Xoa mot so"
            labelSize: 23
            danger: true
            keyEnabled: pad.backspaceEnabled
            onActivated: pad.backspace()
        }

        PinKey {
            label: "0"
            labelSize: pad.iosStyle ? 35 : 25
            accessibleName: "So 0"
            onActivated: pad.digit("0")
        }

        PinKey {
            label: "✓"
            accessibleName: "Xac nhan"
            labelSize: 24
            primary: true
            keyEnabled: pad.submitEnabled
            onActivated: pad.submit()
        }
    }
}
