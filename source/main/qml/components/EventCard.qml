import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../theme"

Rectangle {
    id: root
    width: 284
    height: 284
    color: "transparent"
    radius: 14
    border.color: selected ? "#4FA4F2" : (mouseArea.containsMouse ? Theme.border : borderColor)
    border.width: selected ? 2 : 1

    readonly property color surfaceColor: Window.window ? Window.window.appSurfaceColor : "#121212"
    readonly property color fieldColor: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    readonly property color borderColor: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    readonly property color textColor: "#000000"
    readonly property color mutedTextColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65)

    property string eventName: "Untitled Event"
    property string updatedTime: "Just now"
    property string thumbnailPath: ""
    property string selectedLayout: ""
    property string badgeText: ""
    property bool selected: false

    signal clicked()

    Behavior on border.color { ColorAnimation { duration: 150 } }
    Behavior on border.width  { NumberAnimation  { duration: 150 } }

    // Selection indicator
    Rectangle {
        visible: root.selected
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        width: 22
        height: 22
        radius: 11
        color: "#4FA4F2"

        Text {
            anchors.centerIn: parent
            text: "✓"
            color: "#ffffff"
            font.pixelSize: 12
            font.weight: Font.Bold
        }
    }

    Rectangle {
        visible: root.badgeText !== ""
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 10
        width: badgeLabel.implicitWidth + 18
        height: 28
        radius: 8
        color: "#4FA4F2"
        border.color: "#2D86DE"
        border.width: 1
        z: 2

        Text {
            id: badgeLabel
            anchors.centerIn: parent
            text: root.badgeText
            color: "#ffffff"
            font.pixelSize: 13
            font.weight: Font.Bold
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        // Thumbnail area
        Rectangle {
            width: parent.width
            height: parent.height - 50
            color: "transparent"
            radius: 8
            border.color: root.borderColor
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "📷"
                font.pixelSize: 56
                opacity: 0.15
                visible: layoutImage.status !== Image.Ready
            }

            Image {
                id: layoutImage
                anchors.fill: parent
                anchors.margins: 4
                source: root.selectedLayout
                fillMode: Image.PreserveAspectFit
                visible: status === Image.Ready
                cache: true
            }

            Item {
                anchors.fill: parent
                visible: mouseArea.containsMouse

                Button {
                    anchors.centerIn: parent
                    text: "⚙ Cấu Hình"
                    width: 150
                    height: 42

                    background: Rectangle {
                        color: parent.hovered ? "#4FA4F2" : "transparent"
                        radius: 17
                        border.color: parent.hovered ? "#4FA4F2" : Theme.border
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }

                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? "#ffffff" : root.textColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 16
                        font.weight: Font.Medium
                    }

                    onClicked: root.clicked()
                }
            }
        }

        // Event info
        Column {
            width: parent.width
            spacing: 3

            Text {
                text: root.eventName
                font.pixelSize: 21
                font.weight: Font.Medium
                color: root.textColor
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: root.updatedTime
                font.pixelSize: 16
                color: root.mutedTextColor
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
