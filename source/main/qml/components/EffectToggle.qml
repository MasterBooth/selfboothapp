import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    height: 44
    color: toggleSwitch.checked ? "#1a1d23" : "transparent"
    radius: 6
    border.color: toggleSwitch.checked ? "#1e7eea" : "#2a2d35"
    border.width: 1

    property string effectName: ""
    property string effectKey: ""
    property int eventId: -1

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 12

        Text {
            text: root.effectName
            color: toggleSwitch.checked ? "#ffffff" : Theme.textMuted
            font.pixelSize: 13
            Layout.fillWidth: true

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        Switch {
            id: toggleSwitch
            checked: false

            onCheckedChanged: {
                if (root.eventId !== -1) {
                    eventManager.updateEffect(root.eventId, root.effectKey, checked)
                }
            }

            indicator: Rectangle {
                width: 44
                height: 24
                radius: 12
                color: parent.checked ? "#1e7eea" : "#3a3d45"

                Rectangle {
                    x: parent.parent.checked ? parent.width - width - 3 : 3
                    y: 3
                    width: 18
                    height: 18
                    radius: 9
                    color: "#ffffff"

                    Behavior on x {
                        NumberAnimation { duration: 150 }
                    }
                }

                Behavior on color {
                    ColorAnimation { duration: 150 }
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggleSwitch.checked = !toggleSwitch.checked
        z: -1
    }
}
