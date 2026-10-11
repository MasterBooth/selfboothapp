// Hallmark - component: startup splash - genre: editorial - theme: Studio soft (Warm Luxury tokens)
// layout: khung dọc 1080×1920 căn giữa màn, giống ptb_main.qml — splash → app không nhảy bố cục
// motion: logo hiện dần 420ms · thanh tiến trình chạy bằng transform (scale X) · mờ dần khi đóng
import QtQuick
import QtQuick.Window
import "../theme"

Window {
    id: splash

    property real progress: 0
    property string statusText: "Đang khởi động…"

    readonly property real clampedProgress: Math.max(0, Math.min(1, splash.progress))
    // Cùng khung thiết kế với app chính (ptb_main.qml: 1080×1920, thu phóng vừa màn).
    readonly property int designW: 1080
    readonly property int designH: 1920
    readonly property real canvasScale: Math.min(splash.width / designW, splash.height / designH)

    visible: true
    visibility: Window.FullScreen
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    color: Theme.settingsCanvas

    function finish() {
        closeFade.start()
    }

    // Màn ngang: khung dọc nằm giữa, hai bên là nền kem trơn.
    Rectangle {
        anchors.fill: parent
        color: Theme.settingsCanvas
    }

    Item {
        id: canvas
        width: splash.designW
        height: splash.designH
        scale: splash.canvasScale
        transformOrigin: Item.TopLeft
        x: Math.round((splash.width - splash.designW * splash.canvasScale) / 2)
        y: Math.round((splash.height - splash.designH * splash.canvasScale) / 2)

        Rectangle {
            anchors.fill: parent
            // Trắng như nền vuông của log.png (RGB, không trong suốt) → logo không lộ thành ô.
            color: Theme.settingsCard
            border.color: Theme.settingsBorder
            border.width: splash.width > splash.designW * splash.canvasScale + 2 ? 2 : 0
        }

        Image {
            id: logo
            anchors.horizontalCenter: parent.horizontalCenter
            y: 560
            width: 600
            height: 600
            source: "qrc:/assets/log.png"
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            mipmap: true
            smooth: true
            opacity: 0

            NumberAnimation on opacity {
                from: 0
                to: 1
                duration: 420
                easing.type: Easing.OutCubic
            }
        }

        // Khối tiến trình: chữ trạng thái + phần trăm trên, đường kẻ mảnh dưới.
        Item {
            id: progressBlock
            anchors.horizontalCenter: parent.horizontalCenter
            y: 1440
            width: 720
            height: 96

            Text {
                id: statusLabel
                anchors.left: parent.left
                anchors.right: percentLabel.left
                anchors.rightMargin: 24
                anchors.bottom: track.top
                anchors.bottomMargin: 24
                text: splash.statusText
                color: Theme.settingsText
                font.pixelSize: 32
                font.weight: Font.Medium
                elide: Text.ElideRight
            }

            Text {
                id: percentLabel
                anchors.right: parent.right
                anchors.baseline: statusLabel.baseline
                text: Math.round(splash.clampedProgress * 100) + "%"
                color: Theme.settingsCopperDark
                font.pixelSize: 32
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }

            Rectangle {
                id: track
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 6
                color: Theme.settingsBorder

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: parent.width
                    color: Theme.settingsCopper
                    transform: Scale {
                        origin.x: 0
                        xScale: splash.clampedProgress
                        Behavior on xScale {
                            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }
        }
    }

    NumberAnimation {
        id: closeFade
        target: canvas
        property: "opacity"
        to: 0
        duration: 220
        easing.type: Easing.InCubic
        onFinished: splash.close()
    }
}
