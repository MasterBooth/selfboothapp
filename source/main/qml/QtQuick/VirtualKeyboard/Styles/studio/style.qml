// Hallmark - component: virtual keyboard - genre: editorial - theme: Studio
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Styles

KeyboardStyle {
    id: kbStyle

    readonly property color canvas: "#F7F1EC"
    readonly property color surface: "#FFFCF9"
    readonly property color keySurface: "#FFFFFF"
    readonly property color keySurfaceDown: "#FBE8DD"
    readonly property color functionSurface: "#F2E7DE"
    readonly property color functionSurfaceDown: "#EBD9CE"
    readonly property color accent: "#C96F4A"
    readonly property color accentDown: "#A95435"
    readonly property color accentSoft: "#FBE8DD"
    readonly property color border: "#E8DDD5"
    readonly property color borderStrong: "#D7C5B9"
    readonly property color ink: "#2A211C"
    readonly property color muted: "#766A62"
    readonly property color danger: "#C94F4F"

    keyboardDesignWidth: 960
    keyboardDesignHeight: 332
    keyboardRelativeLeftMargin: 0.016
    keyboardRelativeRightMargin: 0.016
    keyboardRelativeTopMargin: 0.045
    keyboardRelativeBottomMargin: 0.045
    alternateKeysListItemWidth: 64 * scaleHint
    alternateKeysListItemHeight: 54 * scaleHint
    alternateKeysListTopMargin: 8 * scaleHint
    alternateKeysListBottomMargin: 8 * scaleHint
    alternateKeysListLeftMargin: 8 * scaleHint
    alternateKeysListRightMargin: 8 * scaleHint
    characterPreviewMargin: 8 * scaleHint
    selectionListHeight: 40 * scaleHint
    languagePopupListEnabled: true

    function specialLabel(control, fallback) {
        if (!control)
            return fallback
        if (control.displayText && control.displayText.length > 0)
            return control.displayText
        if (control.keyType === QtVirtualKeyboard.KeyType.SpaceKey)
            return "Space"
        if (control.keyType === QtVirtualKeyboard.KeyType.BackspaceKey)
            return "Back"
        if (control.keyType === QtVirtualKeyboard.KeyType.EnterKey)
            return "Enter"
        if (control.keyType === QtVirtualKeyboard.KeyType.ShiftKey)
            return control.uppercased ? "SHIFT" : "Shift"
        if (control.keyType === QtVirtualKeyboard.KeyType.HideKeyboardKey)
            return "Hide"
        if (control.keyType === QtVirtualKeyboard.KeyType.ChangeLanguageKey)
            return "Lang"
        if (control.keyType === QtVirtualKeyboard.KeyType.InputModeKey)
            return "ABC"
        if (control.keyType === QtVirtualKeyboard.KeyType.HandwritingModeKey)
            return "Write"
        return fallback
    }

    keyboardBackground: Rectangle {
        color: kbStyle.canvas

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(1, 1 * kbStyle.scaleHint)
            color: kbStyle.border
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.max(10, 14 * kbStyle.scaleHint)
            color: "#FFFFFF"
            opacity: 0.34
        }
    }

    keyPanel: KeyPanel {
        id: letterPanel
        implicitWidth: 58 * kbStyle.scaleHint
        implicitHeight: 54 * kbStyle.scaleHint

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(3, 5 * kbStyle.scaleHint)
            radius: Math.max(8, 12 * kbStyle.scaleHint)
            color: !letterPanel.control || letterPanel.control.enabled
                   ? (letterPanel.control && letterPanel.control.pressed ? kbStyle.keySurfaceDown : kbStyle.keySurface)
                   : "#EEE5DE"
            border.width: 1
            border.color: letterPanel.control && letterPanel.control.pressed ? kbStyle.accent : kbStyle.border

            Behavior on color { ColorAnimation { duration: 90 } }
            Behavior on border.color { ColorAnimation { duration: 90 } }
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 12 * kbStyle.scaleHint
            text: letterPanel.control ? letterPanel.control.displayText : ""
            color: letterPanel.control && letterPanel.control.enabled ? kbStyle.ink : kbStyle.muted
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            font.family: "Segoe UI"
            font.pixelSize: Math.max(17, 25 * kbStyle.scaleHint)
            font.weight: Font.Medium
            fontSizeMode: Text.Fit
            minimumPixelSize: 11
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: 12 * kbStyle.scaleHint
            anchors.topMargin: 7 * kbStyle.scaleHint
            visible: letterPanel.control && letterPanel.control.smallTextVisible && letterPanel.control.smallText.length > 0
            text: letterPanel.control ? letterPanel.control.smallText : ""
            color: kbStyle.muted
            font.family: "Segoe UI"
            font.pixelSize: Math.max(9, 12 * kbStyle.scaleHint)
            font.weight: Font.DemiBold
        }
    }

    backspaceKeyPanel: KeyPanel {
        id: backPanel
        implicitWidth: 86 * kbStyle.scaleHint
        implicitHeight: 54 * kbStyle.scaleHint

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(3, 5 * kbStyle.scaleHint)
            radius: Math.max(8, 12 * kbStyle.scaleHint)
            color: backPanel.control && backPanel.control.pressed ? "#FFE1DA" : "#FFF3EE"
            border.width: 1
            border.color: backPanel.control && backPanel.control.pressed ? kbStyle.danger : "#F0C8BA"
        }

        Text {
            anchors.centerIn: parent
            text: kbStyle.specialLabel(backPanel.control, "Back")
            color: kbStyle.danger
            font.family: "Segoe UI"
            font.pixelSize: Math.max(14, 19 * kbStyle.scaleHint)
            font.weight: Font.DemiBold
        }
    }

    enterKeyPanel: KeyPanel {
        id: enterPanel
        implicitWidth: 86 * kbStyle.scaleHint
        implicitHeight: 54 * kbStyle.scaleHint

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(3, 5 * kbStyle.scaleHint)
            radius: Math.max(8, 12 * kbStyle.scaleHint)
            color: !enterPanel.control || enterPanel.control.enabled
                   ? (enterPanel.control && enterPanel.control.pressed ? kbStyle.accentDown : kbStyle.accent)
                   : "#D9CBC2"
            border.width: 1
            border.color: enterPanel.control && enterPanel.control.pressed ? kbStyle.accentDown : kbStyle.accent
        }

        Text {
            anchors.centerIn: parent
            text: kbStyle.specialLabel(enterPanel.control, "Enter")
            color: "#FFF7EF"
            font.family: "Segoe UI"
            font.pixelSize: Math.max(14, 19 * kbStyle.scaleHint)
            font.weight: Font.DemiBold
        }
    }

    shiftKeyPanel: KeyPanel {
        id: shiftPanel
        implicitWidth: 86 * kbStyle.scaleHint
        implicitHeight: 54 * kbStyle.scaleHint

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(3, 5 * kbStyle.scaleHint)
            radius: Math.max(8, 12 * kbStyle.scaleHint)
            color: shiftPanel.control && (shiftPanel.control.pressed || shiftPanel.control.uppercased)
                   ? kbStyle.accentSoft : kbStyle.functionSurface
            border.width: 1
            border.color: shiftPanel.control && shiftPanel.control.uppercased ? kbStyle.accent : kbStyle.borderStrong
        }

        Text {
            anchors.centerIn: parent
            text: kbStyle.specialLabel(shiftPanel.control, "Shift")
            color: kbStyle.ink
            font.family: "Segoe UI"
            font.pixelSize: Math.max(13, 18 * kbStyle.scaleHint)
            font.weight: Font.DemiBold
        }
    }

    spaceKeyPanel: KeyPanel {
        id: spacePanel
        implicitWidth: 260 * kbStyle.scaleHint
        implicitHeight: 54 * kbStyle.scaleHint

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(3, 5 * kbStyle.scaleHint)
            radius: Math.max(8, 12 * kbStyle.scaleHint)
            color: spacePanel.control && spacePanel.control.pressed ? kbStyle.keySurfaceDown : kbStyle.keySurface
            border.width: 1
            border.color: kbStyle.border
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 24 * kbStyle.scaleHint
            text: "Space"
            color: kbStyle.muted
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            font.family: "Segoe UI"
            font.pixelSize: Math.max(14, 19 * kbStyle.scaleHint)
            font.weight: Font.Medium
            fontSizeMode: Text.Fit
            minimumPixelSize: 10
        }
    }

    symbolKeyPanel: KeyPanel {
        id: symbolPanel
        implicitWidth: 86 * kbStyle.scaleHint
        implicitHeight: 54 * kbStyle.scaleHint

        Rectangle {
            anchors.fill: parent
            anchors.margins: Math.max(3, 5 * kbStyle.scaleHint)
            radius: Math.max(8, 12 * kbStyle.scaleHint)
            color: symbolPanel.control && symbolPanel.control.pressed ? kbStyle.functionSurfaceDown : kbStyle.functionSurface
            border.width: 1
            border.color: kbStyle.borderStrong
        }

        Text {
            anchors.centerIn: parent
            text: symbolPanel.control ? symbolPanel.control.displayText : "&123"
            color: kbStyle.ink
            font.family: "Segoe UI"
            font.pixelSize: Math.max(14, 19 * kbStyle.scaleHint)
            font.weight: Font.DemiBold
        }
    }

    languageKeyPanel: symbolKeyPanel
    hideKeyPanel: symbolKeyPanel
    modeKeyPanel: symbolKeyPanel
    handwritingKeyPanel: symbolKeyPanel

    characterPreviewDelegate: Rectangle {
        property string text: ""
        width: 58 * kbStyle.scaleHint
        height: 64 * kbStyle.scaleHint
        radius: 16 * kbStyle.scaleHint
        color: kbStyle.surface
        border.color: kbStyle.accent
        border.width: 1

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: kbStyle.ink
            font.family: "Segoe UI"
            font.pixelSize: 30 * kbStyle.scaleHint
            font.weight: Font.DemiBold
        }
    }

    alternateKeysListBackground: Rectangle {
        color: kbStyle.surface
        radius: 16 * kbStyle.scaleHint
        border.color: kbStyle.border
        border.width: 1
    }

    alternateKeysListDelegate: SelectionListItem {
        Rectangle {
            anchors.fill: parent
            anchors.margins: 4 * kbStyle.scaleHint
            radius: 12 * kbStyle.scaleHint
            color: ListView.isCurrentItem ? kbStyle.accentSoft : kbStyle.keySurface
            border.color: ListView.isCurrentItem ? kbStyle.accent : kbStyle.border
            border.width: 1
        }

        Text {
            anchors.centerIn: parent
            text: display
            color: kbStyle.ink
            font.family: "Segoe UI"
            font.pixelSize: 23 * kbStyle.scaleHint
            font.weight: Font.Medium
        }
    }

    selectionListBackground: Rectangle {
        color: kbStyle.surface
        border.color: kbStyle.border
        border.width: 1
    }

    selectionListDelegate: SelectionListItem {
        width: Math.max(80 * kbStyle.scaleHint, parent ? parent.width : 80)

        Text {
            anchors.centerIn: parent
            width: parent.width - 20 * kbStyle.scaleHint
            text: display
            color: kbStyle.ink
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.family: "Segoe UI"
            font.pixelSize: 15 * kbStyle.scaleHint
            font.weight: Font.Medium
        }
    }

    navigationHighlight: Rectangle {
        radius: 13 * kbStyle.scaleHint
        color: "transparent"
        border.width: Math.max(2, 2 * kbStyle.scaleHint)
        border.color: kbStyle.accent
    }
}

