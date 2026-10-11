import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../theme"
import "../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080

    signal adminRequested()
    signal settingsRequested()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    signal startRequested()

    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property string backgroundImagePath: eventManager.getAppSetting("paper_welcome_bg_image", "")

    gradient: Gradient {
        GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
        GradientStop { position: 1.0; color: Qt.darker(root._themeBg, 1.28) }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.startRequested()
    }

    Rectangle {
        id: settingsButton
        width: 64
        height: 64
        radius: 12
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 28
        opacity: root._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: settingsMouse.pressed ? Theme.surface : (settingsMouse.containsMouse ? Theme.surface : root._themeField)
        border.color: settingsMouse.containsMouse ? "#4FA4F2" : root._themeBorder
        border.width: 1

        Image {
            anchors.centerIn: parent
            width: 34
            height: 34
            source: "qrc:/assets/icons/settings_button.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        MouseArea {
            id: settingsMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsRequested()
        }
    }

    MouseArea {
        id: hiddenAdminArea
        width: 120
        height: 120
        anchors.left: parent.left
        anchors.top: parent.top
        pressAndHoldInterval: 1500

        onPressAndHold: root.adminRequested()
    }
}
