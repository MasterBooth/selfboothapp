// Hallmark - component: camera status card - genre: editorial - theme: Studio soft
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    Layout.fillWidth: true
    color: Theme.settingsCard
    radius: Theme.settingsRadiusLarge
    border.color: cameraController.isConnected ? Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.38)
                                                : Qt.rgba(Theme.settingsDanger.r, Theme.settingsDanger.g, Theme.settingsDanger.b, 0.36)
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        Rectangle {
            Layout.preferredWidth: 58
            Layout.preferredHeight: 58
            radius: 18
            color: cameraController.isConnected ? Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.10)
                                                : Qt.rgba(Theme.settingsDanger.r, Theme.settingsDanger.g, Theme.settingsDanger.b, 0.10)
            border.color: cameraController.isConnected ? Theme.settingsSuccess : Theme.settingsDanger
            border.width: 1

            Rectangle {
                width: 14
                height: 14
                radius: 7
                anchors.centerIn: parent
                color: cameraController.isConnected ? Theme.settingsSuccess : Theme.settingsDanger

                SequentialAnimation on opacity {
                    running: cameraController.isConnected
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.45; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { from: 0.45; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: cameraController.captureSource === "hotfolder"
                      ? (cameraController.isConnected ? "Hot Folder đang nhận ảnh" : "Hot Folder chưa sẵn sàng")
                      : (cameraController.isConnected ? "Máy ảnh sẵn sàng" : "Máy ảnh mất kết nối")
                color: cameraController.isConnected ? Theme.settingsSuccess : Theme.settingsDanger
                font.pixelSize: 18
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: cameraController.cameraModel !== "" ? cameraController.cameraModel : "Chưa nhận thông tin thiết bị"
                color: Theme.settingsTextMuted
                font.pixelSize: 12
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Button {
            id: connectButton
            text: cameraController.isConnecting ? "Đang kết nối"
                  : (cameraController.captureSource === "hotfolder" ? "Theo dõi lại" : "Kết nối")
            visible: !cameraController.isConnected
            enabled: !cameraController.isConnecting
            Layout.preferredWidth: 132
            Layout.preferredHeight: 44
            onClicked: cameraController.connectAsync()

            background: Rectangle {
                radius: 16
                color: !connectButton.enabled ? Theme.settingsBorder
                     : connectButton.down ? Theme.settingsCopperDark
                     : connectButton.hovered ? Qt.darker(Theme.settingsCopper, 1.06)
                     : Theme.settingsCopper
            }

            contentItem: Text {
                text: connectButton.text
                color: connectButton.enabled ? "#FFFFFF" : Theme.settingsTextMuted
                font.pixelSize: 13
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }
}
