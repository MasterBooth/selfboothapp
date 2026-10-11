import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../components"

// Trang "Chọn dịch vụ" — đứng trước CutModeScreen khi bật Selfbooth (sbcut_enabled).
// Chỉ có 2 lựa chọn: Photobooth (→ CutModeScreen) và Selfbooth (→ luồng Selfbooth).
Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // Chọn Photobooth → vào CutModeScreen (chọn loại in + chụp).
    signal photoboothChosen()
    // Chọn Selfbooth → nhánh tự chụp (như cũ).
    signal selfBoothChosen()
    // ⚙ Cài đặt — đây là màn home. (Gallery xem ảnh đã chuyển vào Cài đặt → tab Thư viện ảnh.)
    signal settingsClicked()
    signal closeClicked()

    // Hiện nút ⚙ (vào Cài đặt) ở chế độ thanh toán — khi không có Dashboard.
    property bool paymentMode: false
    // Ẩn nút X khi flow đã có nút Quay lại riêng.
    property bool showCloseButton: true

    readonly property bool selfBoothAllowed: machineAuth.hasCapability("selfbooth")

    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0

    property string backgroundImagePath: {
        var s = eventManager.getAppSetting("selectservice_bg_image", "")
        return s !== "" ? s : "qrc:/assets/bg/select_service.png"
    }
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
            GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
        }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    // ── Top bar ──────────────────────────────────────────────────────────────
    Item {
        id: topBar
        width: parent.width
        height: 100
        anchors.top: parent.top
        z: 10

        // ⚙ Cài đặt — cạnh nút X, chỉ hiện ở chế độ thanh toán
        Button {
            id: ssSettingsBtn
            visible: root.paymentMode
            anchors.right: ssCloseBtn.left
            anchors.rightMargin: 16
            anchors.verticalCenter: ssCloseBtn.verticalCenter
            width: 60; height: 60
            z: 16
            opacity: root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }

            background: Rectangle {
                color: parent.hovered ? "#1e7eea" : Theme.field
                radius: 30
                border.color: parent.hovered ? "#1e7eea" : Theme.border
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

        Button {
            id: ssCloseBtn
            visible: root.showCloseButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 40
            width: 60; height: 60
            opacity: ssCloseGuard.holding ? 0.65 : root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }
            background: Rectangle {
                color: parent.hovered ? "#ff4757" : Theme.field
                radius: 30
                border.color: parent.hovered ? "#ff4757" : Theme.border
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

        // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
        // Khi không ở chế độ tàng hình, guard tắt và ✕ bấm một chạm như cũ.
        HoldToActivate {
            id: ssCloseGuard
            anchors.fill: ssCloseBtn
            onActivated: root.closeClicked()
        }
    }

    // ── Center content ────────────────────────────────────────────────────────
    Item {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Vuốt ngang để xem & chọn (các ô to nên có thể tràn màn → cho cuộn ngang).
        Flickable {
            id: modeFlick
            anchors.centerIn: parent
            width: parent.width
            height: root.portrait ? 740 : 840
            // Lề trái khớp với nút "Xem Ảnh" (góc trên-trái).
            readonly property int leftPad: 140
            contentWidth: Math.max(width, modeRow.width + leftPad * 2)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: false

            Row {
                id: modeRow
                height: parent.height
                spacing: root.portrait ? 80 : 120
                x: modeFlick.leftPad

                // ── Photobooth ───────────────────────────────────────────────
                Column {
                    spacing: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: root.portrait ? 600 : 740
                        height: root.portrait ? 740 : 840

                        Image {
                            id: photoboothThumb
                            anchors.fill: parent
                            source: {
                                var s = eventManager.getAppSetting("selectservice_thumb_photobooth", "")
                                return s !== "" ? root._resolveImg(s) : "qrc:/assets/bg/thumb_photobooth.png"
                            }
                            fillMode: Image.PreserveAspectFit
                            visible: source !== ""
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.field
                            border.color: "#1e7eea"
                            border.width: 3
                            visible: photoboothThumb.source === ""

                            Column {
                                anchors.centerIn: parent
                                spacing: 20
                                Text { text: "📷"; font.pixelSize: 80; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: "Photobooth"; color: "#ffffff"; font.pixelSize: 28; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.photoboothChosen()
                        }
                    }
                }

                // ── Selfbooth ────────────────────────────────────────────────
                Column {
                    spacing: 24
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: root.portrait ? 600 : 740
                        height: root.portrait ? 740 : 840

                        Image {
                            id: selfBoothThumb
                            anchors.fill: parent
                            source: {
                                var s = eventManager.getAppSetting("sbcut_thumbnail", "")
                                return s !== "" ? root._resolveImg(s) : "qrc:/assets/bg/thumb_selfbooth.png"
                            }
                            fillMode: Image.PreserveAspectFit
                            visible: source !== ""
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.field
                            border.color: "#9c27b0"
                            border.width: 3
                            visible: selfBoothThumb.source === ""

                            Column {
                                anchors.centerIn: parent
                                spacing: 20
                                Text { text: "🤳"; font.pixelSize: 80; anchors.horizontalCenter: parent.horizontalCenter }
                                Text { text: "Selfbooth" + (root.selfBoothAllowed ? "" : "  🔒"); color: "#ffffff"; font.pixelSize: 28; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.selfBoothAllowed) {
                                    if (Window.window && Window.window.showUpgradeNotice)
                                        Window.window.showUpgradeNotice()
                                    return
                                }
                                root.selfBoothChosen()
                            }
                        }
                    }
                }
            }
        }
    }
}
