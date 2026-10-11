import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    color: "transparent"
    Layout.fillWidth: true
    implicitHeight: headerRect.height + (contentLoader.visible ? contentLoader.height + 24 : 0)

    property string title: ""
    property Component content: null
    property bool expanded: true

    // Header
    Rectangle {
        id: headerRect
        width: parent.width
        height: 50
        color: "transparent"
        border.color: "#2a2d35"
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12

            Text {
                text: root.title
                color: Theme.text
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }

            Text {
                text: root.expanded ? "▼" : "▶"
                color: Theme.textMuted
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded
        }

        Behavior on border.color { ColorAnimation { duration: 150 } }
    }

    // Content
    Loader {
        id: contentLoader
        anchors.top: headerRect.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 16
        anchors.topMargin: 12
        sourceComponent: root.content
        visible: root.expanded
        active: root.expanded

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }

        opacity: root.expanded ? 1.0 : 0.0
    }
}
