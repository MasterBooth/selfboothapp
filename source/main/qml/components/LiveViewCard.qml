// Hallmark - component: live view preview card - genre: editorial - theme: Studio soft
import QtQuick
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    Layout.fillWidth: true
    Layout.fillHeight: true
    color: Theme.settingsCard
    radius: Theme.settingsRadiusLarge
    border.color: Theme.settingsBorder
    border.width: 1

    property bool isLive: cameraController.isLiveViewActive
    property var eventData: null

    Component.onCompleted: cameraController.addLiveViewViewer()
    Component.onDestruction: cameraController.removeLiveViewViewer()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Live view preview"
                    color: Theme.settingsText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.isLive ? "Đang nhận hình trực tiếp" : "Chờ kết nối máy ảnh"
                    color: Theme.settingsTextMuted
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.max(86, fpsLabel.implicitWidth + 22)
                Layout.preferredHeight: 34
                radius: 17
                color: root.isLive ? Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.10)
                                   : Theme.settingsSurface
                border.color: root.isLive ? Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.38)
                                          : Theme.settingsBorder
                border.width: 1

                Text {
                    id: fpsLabel
                    anchors.centerIn: parent
                    text: root.isLive ? (cameraController.liveViewFps + " FPS") : "Offline"
                    color: root.isLive ? Theme.settingsSuccess : Theme.settingsTextMuted
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        Rectangle {
            id: viewport
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 430
            color: "#11100F"
            radius: 18
            border.color: root.isLive ? Theme.settingsCopper : Theme.settingsBorder
            border.width: root.isLive ? 2 : 1
            clip: true

            LiveViewPanel {
                anchors.fill: parent
                isActive: root.isLive
                eventData: root.eventData
                fillMode: Image.PreserveAspectCrop
                imageMargins: 0
                panelRadius: 18
                panelBorderWidth: 0
            }
        }
    }
}
