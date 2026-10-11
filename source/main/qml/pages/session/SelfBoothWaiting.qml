import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Trang chờ kiểu ModeSelection cho chế độ Selfbooth (tự chụp, miễn phí).
// Bấm vào giữa → bắt đầu chụp; ⚙ → BoothSession đẩy trang cài đặt sidebar; X → quay về CutModeScreen.
Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    signal startCapture()
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    signal settingsClicked()

    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property string backgroundImagePath: eventManager.getAppSetting("sbcut_bg_waiting", "")
    property string startText: eventManager.getAppSetting("sbcut_start_text", "Chạm để bắt đầu chụp")
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    // Cập nhật live khi đổi trong trang cài đặt.
    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "sbcut_bg_waiting")  root.backgroundImagePath = value
            else if (key === "sbcut_start_text") root.startText = value
        }
    }

    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    color: "transparent"

    // ── Nền: gradient fallback + ảnh tuỳ chọn ────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
            GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
        }
    }

    Image {
        anchors.fill: parent
        source: root._resolveImg(root.backgroundImagePath)
        fillMode: Image.PreserveAspectCrop
        visible: root.backgroundImagePath !== ""
    }

    // ── Bấm vào giữa → bắt đầu chụp ──────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        onClicked: root.startCapture()
        z: 1
    }

    // ── Chữ gợi ý ở giữa (ẩn nếu xóa rỗng) ───────────────────────────────────
    Text {
        id: centerPrompt
        anchors.centerIn: parent
        text: root.startText
        visible: text !== ""
        color: "#ffffff"
        font.pixelSize: 72
        font.weight: Font.Bold
        z: 2

        SequentialAnimation on opacity {
            running: root._isActiveScreen && centerPrompt.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.6; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.6; duration: 1500; easing.type: Easing.InOutQuad }
        }
    }

    // ── Top bar: ⚙ + X ───────────────────────────────────────────────────────
    Item {
        id: topBar
        width: parent.width
        height: 100
        anchors.top: parent.top
        z: 10

        // Nút X (góc trên-phải) → về CutModeScreen
        Button {
            id: closeBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 40
            width: 60; height: 60
            opacity: sbwCloseGuard.holding ? 0.65 : root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }
            background: Rectangle {
                color: parent.hovered ? "#ff4757" : "#2a2d35"
                radius: 30
                border.color: parent.hovered ? "#ff4757" : "#454850"
                border.width: 2
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: "✕"; color: "white"
                font.pixelSize: 28; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.closeClicked()
        }

        // Nút ⚙ (cạnh trái nút X) → mở trang cài đặt
        Button {
            id: settingsBtn
            anchors.right: closeBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: closeBtn.verticalCenter
            width: 60; height: 60
            opacity: root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }
            background: Rectangle {
                color: parent.hovered ? "#1e7eea" : "#2a2d35"
                radius: 30
                border.color: parent.hovered ? "#1e7eea" : "#454850"
                border.width: 2
                opacity: parent.hovered ? 1.0 : 0.85
            }
            contentItem: Image {
                source: "qrc:/assets/icons/settings_button.png"
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
            onClicked: root.settingsClicked()
        }

        // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
        HoldToActivate {
            id: sbwCloseGuard
            anchors.fill: closeBtn
            onActivated: root.closeClicked()
        }
    }
}
