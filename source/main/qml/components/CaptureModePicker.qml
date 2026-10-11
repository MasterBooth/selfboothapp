import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Row {
    id: root
    spacing: 16

    property string selectedMode: "photo"
    signal modeSelected(string mode)

    // Photo mode
    Rectangle {
        width: 100
        height: 100
        color: selectedMode === "photo" ? "#1e7eea" : "#1f2229"
        radius: 12
        border.color: selectedMode === "photo" ? "#1e7eea" : (photoMouse.containsMouse ? "#4a4d55" : "#3a3d45")
        border.width: 2

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "📷"
                font.pixelSize: 36
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Photo"
                font.pixelSize: 13
                color: selectedMode === "photo" ? "#ffffff" : Theme.textMuted
                font.weight: selectedMode === "photo" ? Font.Medium : Font.Normal
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            id: photoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.modeSelected("photo")
        }

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // Video mode
    Rectangle {
        width: 100
        height: 100
        color: selectedMode === "video" ? "#1e7eea" : "#1f2229"
        radius: 12
        border.color: selectedMode === "video" ? "#1e7eea" : (videoMouse.containsMouse ? "#4a4d55" : "#3a3d45")
        border.width: 2

        Column {
            anchors.centerIn: parent
            spacing: 8

            Text {
                text: "🎥"
                font.pixelSize: 36
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "Video"
                font.pixelSize: 13
                color: selectedMode === "video" ? "#ffffff" : Theme.textMuted
                font.weight: selectedMode === "video" ? Font.Medium : Font.Normal
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        MouseArea {
            id: videoMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.modeSelected("video")
        }

        Behavior on color { ColorAnimation { duration: 150 } }
        Behavior on border.color { ColorAnimation { duration: 150 } }
    }
}
