import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../theme"
import "../components"

Rectangle {
    id: landingPage
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // Signal to notify parent to switch screen
    signal startClicked()
    // Mở Cài đặt (parent xử lý PIN admin theo security_enabled).
    signal settingsClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    property bool showSettingsButton: false

    // Property to hold background image path
    property string backgroundImage: ""

    // Effective background: dùng ảnh do parent truyền (landing_background) nếu có;
    // nếu không thì phủ ảnh brand mặc định để KHÔNG lộ nền window-level bị gradient
    // làm mờ phía sau (customBackground là ảnh đục, phủ kín, che sạch lớp mờ đó).
    readonly property string _effectiveBackground:
        backgroundImage !== "" ? backgroundImage : "qrc:/assets/1.png"

    // Derived theme background — direct expression so QML tracks appBgColor changes
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    // Màu chữ/trang trí nằm trực tiếp trên nền: dùng ảnh nền → trắng; nếu không → theo theme (tối trên nền sáng).
    property color _onBgText: "white"
    // Trong suốt để lộ nền BRAND (window-level). Ảnh nền riêng (nếu có) vẫn phủ lên.
    color: "transparent"

    // ── Live view làm nền ────────────────────────────────────────────────────
    // Bật/tắt theo app setting machine-global; mặc định BẬT để giữ máy ảnh được
    // "tiêu thụ" live view → giữ kết nối. (getAppSetting không reactive — đọc 1
    // lần khi tạo; LandingPage được StackView tạo lại nên luôn lấy giá trị mới.)
    property bool liveViewBgEnabled: eventManager.getAppSetting("landing_liveview_enabled", "true") === "true"
    // Có đang giữ một live-view viewer hay không (để gate giải mã frame).
    property bool _lvViewerHeld: false

    // Đăng ký/huỷ viewer theo trạng thái hiển thị của trang trên StackView.
    function _syncLiveViewViewer() {
        var want = landingPage.liveViewBgEnabled
                && (StackView.status === StackView.Active
                 || StackView.status === StackView.Activating)
        if (want && !landingPage._lvViewerHeld) {
            cameraController.addLiveViewViewer()
            landingPage._lvViewerHeld = true
        } else if (!want && landingPage._lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            landingPage._lvViewerHeld = false
        }
    }

    StackView.onStatusChanged: _syncLiveViewViewer()
    onLiveViewBgEnabledChanged: _syncLiveViewViewer()
    Component.onCompleted: _syncLiveViewViewer()
    Component.onDestruction: {
        if (landingPage._lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            landingPage._lvViewerHeld = false
        }
    }

    // Custom Background Image - MUST BE FIRST CHILD
    BackgroundMedia {
        id: customBackground
        anchors.fill: parent
        sourcePath: landingPage._effectiveBackground
        visible: landingPage._effectiveBackground !== ""
    }

    // Live view nền — nằm DƯỚI nội dung (chữ) và TRÊN ảnh nền tĩnh. Hiện khi bật
    // toggle và máy ảnh đang live; mất kết nối → tự lộ lại ảnh nền tĩnh bên dưới.
    LiveViewPanel {
        anchors.fill: parent
        // Ảnh nền tĩnh (nếu được set) được ưu tiên: khi có backgroundImage thì ẩn
        // live view để không phủ/làm mờ ảnh nền. Viewer vẫn được giữ (xem
        // _syncLiveViewViewer) nên kết nối camera không bị ngắt.
        visible: landingPage.liveViewBgEnabled && cameraController.isLiveViewActive
                 && landingPage.backgroundImage === ""
        isActive: cameraController.isLiveViewActive
        consuming: landingPage._lvViewerHeld && visible
        fillMode: Image.PreserveAspectCrop
        imageMargins: 0
        panelRadius: 0
        panelBorderWidth: 0
    }

    // 3. Main Content
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 40

        // Title Area
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 10
            

            Text {
                text: ""
                font.pixelSize: 100
                font.bold: true
                font.family: "Raleway" // Or system font
                color: "#7A4B2A"
                style: landingPage.backgroundImage !== "" ? Text.Outline : Text.Normal
                styleColor: "#2c3e50"
                Layout.alignment: Qt.AlignHCenter
            }
            
            Text {
                text: ""
                font.pixelSize: 24
                color: "#7A4B2A"
                Layout.alignment: Qt.AlignHCenter
                font.italic: true
            }
        }

        // Space
        Item { height: 20; Layout.fillWidth: true }

        // "Chạm để bắt đầu" indicator — nhấp nháy, không còn là nút bấm
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            Text {
                text: ""
                font.pixelSize: 52
                Layout.alignment: Qt.AlignHCenter

                SequentialAnimation on opacity {
                    running: true; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                text: eventManager.getAppSetting("landing_touch_text", " ")
                color: "#7A4B2A"
                font.bold: true
                font.pixelSize: 55
                font.letterSpacing: 4
                Layout.alignment: Qt.AlignHCenter

                SequentialAnimation on opacity {
                    running: true; loops: Animation.Infinite
                    NumberAnimation { to: 0.4; duration: 900; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
                }
            }
        }
    }
    
    // Bottom decorator
    Text {
        text: "Powered by BOOTHME"
        color: landingPage.backgroundImage !== "" ? Qt.rgba(1,1,1,0.5) : Qt.rgba(landingPage._themeText.r, landingPage._themeText.g, landingPage._themeText.b, 0.45)
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        font.pixelSize: 12
    }

    // Bấm bất kỳ đâu trên màn hình để bắt đầu
    MouseArea {
        anchors.fill: parent
        onClicked: landingPage.startClicked()
    }

    // ⚙ Cài đặt — đặt SAU MouseArea full-screen để nằm trên & tự bắt sự kiện,
    // không kích hoạt startClicked().
    Rectangle {
        id: settingsButton
        // Ẩn icon ⚙ ở Landing cho mọi chế độ (1/2/3): cài đặt mở từ Dashboard
        // (chế độ 1) hoặc từ màn chọn chế độ / booth (chế độ 2/3).
        visible: landingPage.showSettingsButton
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 20
        anchors.rightMargin: 20
        width: 56; height: 56; radius: 28
        opacity: landingPage._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: settingsMA.containsMouse ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.14)
        border.color: Qt.rgba(1, 1, 1, 0.45)
        border.width: 1
        z: 100
        Behavior on color { ColorAnimation { duration: 120 } }

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
            id: settingsMA
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: landingPage.settingsClicked()
        }
    }
}
