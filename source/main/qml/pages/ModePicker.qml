import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"

Rectangle {
    id: root

    signal photoboothSelected()
    signal selfBoothSelected()
    readonly property string operationMode: eventManager.getAppSetting("app_operation_mode", "mode1")
    readonly property bool photoboothAllowed: machineAuth.canUseOperationMode(operationMode)
    readonly property bool selfBoothAllowed: machineAuth.hasCapability("selfbooth")

    color: "#0D0D14"

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: "#150a22" }
        GradientStop { position: 1.0; color: "#0D0D14" }
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 56

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Text {
                        text: "VIETBOOTH EVENT" + (root.photoboothAllowed ? "" : "  🔒")
                font.pixelSize: 64
                font.bold: true
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Chọn chế độ sử dụng"
                font.pixelSize: 22
                color: Theme.textMuted
                Layout.alignment: Qt.AlignHCenter
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 60

            // ── Photobooth ────────────────────────────────────────────────
            Rectangle {
                width: 320; height: 240
                radius: 20
                color: "transparent"
                border.width: pbArea.containsMouse ? 3 : 0
                border.color: "#2a7fff"
                scale: pbArea.containsPress ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }

                Image {
                    anchors.fill: parent
                    source: "qrc:/assets/bg/mode_photobooth.png"
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: pbMask
                    }
                }
                Item {
                    id: pbMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: 20 }
                }

                // Phụ đề
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    radius: 14
                    color: "#aa000000"
                    width: pbSub.implicitWidth + 24
                    height: pbSub.implicitHeight + 12
                    Text { id: pbSub; anchors.centerIn: parent; text: "Chụp ảnh sự kiện"; color: "white"; font.pixelSize: 14 }
                }

                // Khóa khi không có quyền
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    visible: !root.photoboothAllowed
                    color: "#99000000"
                    Text { anchors.centerIn: parent; text: "🔒"; font.pixelSize: 56 }
                }

                MouseArea {
                    id: pbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.photoboothSelected()
                }
            }

            // ── Self Booth ────────────────────────────────────────────────
            Rectangle {
                width: 320; height: 240
                radius: 20
                color: "transparent"
                border.width: sbArea.containsMouse ? 3 : 0
                border.color: "#c040c0"
                scale: sbArea.containsPress ? 0.98 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }

                Image {
                    anchors.fill: parent
                    source: "qrc:/assets/bg/mode_selfbooth.png"
                    fillMode: Image.PreserveAspectCrop
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: sbMask
                    }
                }
                Item {
                    id: sbMask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false
                    Rectangle { anchors.fill: parent; radius: 20 }
                }

                // Phụ đề
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    radius: 14
                    color: "#aa000000"
                    width: sbSub.implicitWidth + 24
                    height: sbSub.implicitHeight + 12
                    Text { id: sbSub; anchors.centerIn: parent; text: "Tự chụp theo thời gian"; color: "white"; font.pixelSize: 14 }
                }

                // Khóa khi không có quyền
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    visible: !root.selfBoothAllowed
                    color: "#99000000"
                    Text { anchors.centerIn: parent; text: "🔒"; font.pixelSize: 56 }
                }

                MouseArea {
                    id: sbArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selfBoothSelected()
                }
            }
        }
    }

    Text {
        text: "Powered by PhotoboothDashboard"
        color: Qt.rgba(1, 1, 1, 0.25)
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        font.pixelSize: 12
    }
}
