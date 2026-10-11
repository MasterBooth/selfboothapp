import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"

FocusScope {
    id: root
    property string title: ""
    property string description: ""
    property string iconName: "settings"
    property bool locked: false
    property color accent: Theme.settingsCopper
    signal clicked()

    implicitWidth: 320
    implicitHeight: 104
    activeFocusOnTab: true
    Keys.onReturnPressed: root.clicked()
    Keys.onEnterPressed: root.clicked()
    Accessible.role: Accessible.Button
    Accessible.name: root.title

    MultiEffect {
        source: card
        anchors.fill: card
        shadowEnabled: true
        shadowColor: "#220F0804"
        shadowBlur: 0.35
        shadowVerticalOffset: 3
        opacity: mouse.pressed ? 0.55 : 1
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Theme.settingsRadiusMedium
        color: mouse.pressed ? Theme.settingsCopperSoft
                             : (mouse.containsMouse || root.activeFocus ? "#FFF8F3" : Theme.settingsCard)
        border.width: root.activeFocus ? 2 : 1
        border.color: root.activeFocus || mouse.containsMouse ? root.accent : Theme.settingsBorder
        scale: mouse.pressed ? 0.985 : 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }
        Behavior on scale { NumberAnimation { duration: 90 } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 52
                Layout.preferredHeight: 52
                radius: 14
                color: Theme.settingsCopperSoft
                SettingsIcon { anchors.centerIn: parent; width: 27; height: 27; name: root.iconName; color: root.accent }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: root.title
                        color: Theme.settingsText
                        font.pixelSize: 16
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text { visible: root.locked; text: "LOCK"; color: Theme.settingsWarning; font.pixelSize: 9; font.bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.description
                    color: Theme.settingsTextMuted
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
            }

            Text { text: "›"; color: root.accent; font.pixelSize: 25; font.weight: Font.Light }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.forceActiveFocus(); root.clicked() }
        }
    }
}
