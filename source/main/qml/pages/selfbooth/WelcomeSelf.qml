import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../../theme"

Item {
    id: root

    signal tapToStart()
    signal settingsClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0

    // Background image from settings
    property string bgImage:      eventManager.getAppSetting("selfbooth_bg_welcome", "")

    // Editable text content (live from settings)
    property string titleText:    eventManager.getAppSetting("welcome_title",    "SELF BOOTH")
    property string subtitleText: eventManager.getAppSetting("welcome_subtitle", "Chụp ảnh tự do · Lưu kỷ niệm")
    property string tapIcon:      eventManager.getAppSetting("welcome_tap_icon", "👆")
    property string tapText:      eventManager.getAppSetting("welcome_tap_text", "CHẠM ĐỂ BẮT ĐẦU")

    // Live-reload when any setting changes
    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if      (key === "selfbooth_bg_welcome") root.bgImage      = value
            else if (key === "welcome_title")        root.titleText    = value
            else if (key === "welcome_subtitle")     root.subtitleText = value
            else if (key === "welcome_tap_icon")     root.tapIcon      = value
            else if (key === "welcome_tap_text")     root.tapText      = value
        }
    }

    // ── Background layer ──────────────────────────────────────────────────────
    // Fallback dark gradient (shown when no custom image is set)
    Rectangle {
        anchors.fill: parent
        visible: root.bgImage === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#1a0a2e" }
            GradientStop { position: 1.0; color: "#0D0D14" }
        }
    }

    // Custom background image (fills screen, hidden when not set)
    Image {
        anchors.fill: parent
        source: root.bgImage !== "" ? "file:///" + root.bgImage : ""
        fillMode: Image.PreserveAspectCrop
        visible: root.bgImage !== ""
    }

    // Animated floating circles (semi-transparent, visible on both bg types)
    Repeater {
        model: 14
        delegate: Rectangle {
            property real sz: 50 + index * 18
            width: sz; height: sz; radius: sz / 2
            color: Qt.rgba(0.55, 0.15, 0.9, root.bgImage !== "" ? 0.04 : 0.07)
            x: (index % 5) * (root.width / 5) + Math.sin(index * 1.3) * 60
            y: (index % 3) * (root.height / 3) + Math.cos(index * 0.8) * 50

            NumberAnimation on x {
                from: x; to: x + (index % 2 === 0 ? 100 : -100)
                duration: 7000 + index * 900
                loops: Animation.Infinite; easing.type: Easing.InOutSine
            }
            NumberAnimation on y {
                from: y; to: y + (index % 2 === 0 ? -70 : 70)
                duration: 8500 + index * 700
                loops: Animation.Infinite; easing.type: Easing.InOutSine
            }
        }
    }

    // ── Settings button (top-left) ────────────────────────────────────────────
    Rectangle {
        id: settingsBtn
        width: 56; height: 56; radius: 28
        x: 28; y: 28
        z: 10
        opacity: root._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: settingsBtnArea.containsMouse ? Qt.rgba(0.22, 0.24, 0.33, 0.9) : Qt.rgba(0.15, 0.16, 0.23, 0.8)
        border.color: "#5a4080"
        border.width: 1

        Behavior on color { ColorAnimation { duration: 150 } }

        Image {
            anchors.centerIn: parent
            width: 32
            height: 32
            source: "qrc:/assets/icons/settings_button.png"
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
        }

        MouseArea {
            id: settingsBtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.settingsClicked()
        }
    }

    // ── Main content ──────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 44

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Text {
                text: root.titleText
                font.pixelSize: 90
                font.bold: true
                color: "white"
                style: Text.Outline
                styleColor: "#5a0090"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: root.subtitleText
                font.pixelSize: 22
                color: "#bb88ee"
                font.italic: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        Item { height: 24; Layout.fillWidth: true }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Text {
                text: root.tapIcon
                font.pixelSize: 56
                Layout.alignment: Qt.AlignHCenter

                SequentialAnimation on opacity {
                    running: true; loops: Animation.Infinite
                    NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                text: root.tapText
                color: "white"
                font.bold: true
                font.pixelSize: 36
                font.letterSpacing: 5
                Layout.alignment: Qt.AlignHCenter

                SequentialAnimation on opacity {
                    running: true; loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }
        }
    }

    // ── Tap to start (background area) ───────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.tapToStart()
    }
}
