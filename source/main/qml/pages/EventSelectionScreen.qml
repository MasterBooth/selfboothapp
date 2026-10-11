import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    color: "#0D0D14"

    signal eventSelected(int eventId)
    signal closeClicked()

    // Header
    Rectangle {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 80
        color: "#0A0A0F"

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: "#1E2030"
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 32
            anchors.rightMargin: 24
            spacing: 16

            Text {
                text: "Chọn sự kiện"
                color: "#ffffff"
                font.pixelSize: 26
                font.weight: Font.Bold
                Layout.fillWidth: true
            }

            // Close / back button
            Rectangle {
                width: 44
                height: 44
                radius: 22
                color: closeMa.containsMouse ? "#2a2d35" : "transparent"
                border.color: "#3a3d45"
                border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "#ffffff"
                    font.pixelSize: 18
                }

                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeClicked()
                }
            }
        }
    }

    // Subtitle
    Text {
        id: subtitle
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.leftMargin: 32
        text: "Chọn một sự kiện để bắt đầu phiên chụp"
        color: Theme.textMuted
        font.pixelSize: 14
    }

    // Event grid
    GridView {
        id: grid
        anchors.top: subtitle.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.topMargin: 16
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        anchors.bottomMargin: 24

        clip: true
        cellWidth: 304
        cellHeight: 320

        model: eventManager.eventModel

        delegate: Item {
            width: grid.cellWidth
            height: grid.cellHeight

            Rectangle {
                anchors.fill: parent
                anchors.margins: 10
                color: cardMa.containsMouse ? "#1a1d26" : "#13151F"
                radius: 14
                border.color: cardMa.containsMouse ? "#1e7eea" : "#1E2030"
                border.width: cardMa.containsMouse ? 2 : 1

                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    // Layout thumbnail
                    Rectangle {
                        width: parent.width
                        height: parent.height - 54
                        color: "#0D0D14"
                        radius: 8
                        border.color: "#1E2030"
                        border.width: 1

                        Text {
                            anchors.centerIn: parent
                            text: "📷"
                            font.pixelSize: 48
                            opacity: 0.15
                            visible: layoutImg.status !== Image.Ready
                        }

                        Image {
                            id: layoutImg
                            anchors.fill: parent
                            anchors.margins: 4
                            source: model.selectedLayout || ""
                            fillMode: Image.PreserveAspectFit
                            visible: status === Image.Ready
                            cache: true
                        }
                    }

                    // Event name
                    Text {
                        text: model.name || "Sự kiện"
                        color: "#ffffff"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                        width: parent.width
                    }

                    // Select button (hiện khi hover)
                    Rectangle {
                        width: parent.width
                        height: 28
                        radius: 6
                        color: cardMa.containsMouse ? "#1e7eea" : "#1f2229"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "Chọn"
                            color: "#ffffff"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.eventSelected(model.eventId)
                }
            }
        }

        // Empty state
        Text {
            anchors.centerIn: parent
            visible: grid.count === 0
            text: "Chưa có sự kiện nào\nVui lòng tạo sự kiện trong phần quản lý"
            color: Theme.textMuted
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
