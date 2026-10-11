import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait
    
    // Properties
    property string sessionId: ""
    property int eventId: -1
    property string hwid: ""
    property string uploadedUrl: ""
    
    // Signals
    signal nextSessionClicked()
    signal backClicked()
    // X = thoát lượt → BoothSession đưa về CutModeScreen (lượt mới).
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    
    // Derived theme background — direct expression so QML tracks appBgColor changes
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    property string backgroundImagePath: eventManager.getAppSetting("global_background_enabled", "false") === "true"
                                         ? eventManager.getAppSetting("global_background_image", "") : ""

    // Background
    color: "transparent"
    gradient: backgroundImagePath === "" ? qrBackgroundGradient : null

    Gradient {
        id: qrBackgroundGradient
        GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.05) }
        GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
    }

    Image {
        anchors.fill: parent
        source: root.backgroundImagePath === "" ? ""
                : (root.backgroundImagePath.startsWith("file:")
                   ? root.backgroundImagePath
                   : "file:///" + root.backgroundImagePath.replace(/\\/g, "/"))
        fillMode: Image.PreserveAspectCrop
        visible: root.backgroundImagePath !== ""
        z: -1
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 60
        spacing: 40
        
        // Header
        Text {
            text: "Nhận Ảnh Của Bạn"
            color: root._themeText
            font.pixelSize: 48
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }
        
        // Subtitle
        Text {
            text: "Quét mã QR bằng điện thoại để tải ảnh về máy"
            color: root._themeMutedText
            font.pixelSize: 20
            Layout.alignment: Qt.AlignHCenter
            wrapMode: Text.WordWrap
        }
        
        Item { Layout.fillHeight: true }
        
        // QR Code Container
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 450
            Layout.preferredHeight: 450
            color: "white"
            radius: 20
            
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 25
                spacing: 0
                
                // QR Code Image
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "white"
                    
                    // QR luôn hiển thị ngay khi có sessionId — không cần chờ upload xong
                    // Khi có mạng và upload xong, URL đó sẽ có ảnh để xem
                    property string qrDataUrl: (root.sessionId && root.hwid)
                        ? s3Uploader.buildSessionUrl(root.hwid, root.eventId, root.sessionId)
                        : ""

                    Image {
                        id: qrImage
                        anchors.fill: parent
                        anchors.margins: 10
                        source: parent.qrDataUrl !== ""
                                ? ("image://qr/" + encodeURIComponent(parent.qrDataUrl))
                                : ""
                        fillMode: Image.PreserveAspectFit
                        smooth: false
                        cache: false

                        onStatusChanged: {
                            if (status === Image.Error)
                                console.error("QRScreen: Failed to generate QR code for", parent.qrDataUrl)
                            else if (status === Image.Ready)
                                console.log("QRScreen: QR code ready for", parent.qrDataUrl)
                        }
                    }

                    BusyIndicator {
                        anchors.centerIn: parent
                        running: qrImage.status === Image.Loading
                        visible: running
                    }

                    // Placeholder khi chưa có sessionId
                    Column {
                        anchors.centerIn: parent
                        spacing: 10
                        visible: parent.qrDataUrl === "" && qrImage.status !== Image.Loading

                        Text {
                            text: "⏳"
                            font.pixelSize: 48
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Text {
                            text: "Đang tạo mã QR..."
                            color: "#666"
                            font.pixelSize: 16
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    // Banner thông báo ảnh đang upload (hiển thị khi chưa có mạng)
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 36
                        color: "#e67e22"
                        radius: 8
                        visible: root.sessionId !== "" && root.uploadedUrl === ""

                        Text {
                            anchors.centerIn: parent
                            text: "Ảnh đang chờ tải lên — quét để xem khi có mạng"
                            color: "white"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }
                }
            }
        }
        
        // URL Display — hiển thị khi có sessionId
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 600
            Layout.preferredHeight: 50
            color: root._themeField
            radius: 10
            border.color: root._themeBorder
            border.width: 1
            visible: root.sessionId !== "" && root.hwid !== ""

            Text {
                anchors.centerIn: parent
                text: s3Uploader.buildSessionUrl(root.hwid, root.eventId, root.sessionId)
                color: root.uploadedUrl !== "" ? "#1e7eea" : "#888"
                font.pixelSize: 14
                elide: Text.ElideMiddle
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        Item { Layout.fillHeight: true }
        
        // Button Row
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            spacing: 30
            
            Item { Layout.fillWidth: true }
            
            // Back Button (Secondary)
            Button {
                Layout.preferredHeight: 80
                Layout.preferredWidth: 250
                
                background: Rectangle {
                    color: parent.hovered ? Theme.border : root._themeField
                    radius: 40
                    border.color: root._themeBorder
                    border.width: 2
                }
                
                contentItem: Text {
                    text: "← Quay Lại"
                    color: "#1e7eea"
                    font.pixelSize: 20
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                onClicked: root.backClicked()
            }
            
            // Next Session Button (Primary)
            Button {
                id: nextSessionBtn
                Layout.preferredHeight: 80
                Layout.preferredWidth: 350

                background: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: nextSessionBtn.hovered ? "#2ecc71" : "#27ae60" }
                        GradientStop { position: 1.0; color: nextSessionBtn.hovered ? "#27ae60" : "#229954" }
                    }
                    radius: 40
                    
                    // Pulse animation
                    SequentialAnimation on scale {
                        running: true
                        loops: Animation.Infinite
                        NumberAnimation { from: 1; to: 1.05; duration: 1000; easing.type: Easing.InOutQuad }
                        NumberAnimation { from: 1.05; to: 1; duration: 1000; easing.type: Easing.InOutQuad }
                    }
                }
                
                contentItem: RowLayout {
                    spacing: 15
                    
                    Text {
                        text: "📸"
                        font.pixelSize: 32
                        Layout.alignment: Qt.AlignVCenter
                    }
                    
                    Text {
                        text: "Chụp Lượt Mới"
                        color: "white"
                        font.pixelSize: 24
                        font.bold: true
                        Layout.alignment: Qt.AlignVCenter
                    }
                }
                
                onClicked: root.nextSessionClicked()
            }
            
            Item { Layout.fillWidth: true }
        }
        
        Item { Layout.preferredHeight: 20 }
    }

    // ── Nút X tròn — bấm → về CutModeScreen (lượt mới). ──
    Rectangle {
        id: qrCloseBtn
        anchors.right: parent.right
        anchors.top:   parent.top
        anchors.rightMargin: 20
        anchors.topMargin:   16
        width: 52; height: 52; radius: 26
        opacity: qrCloseGuard.holding ? 0.65 : root._chromeOpacity
        Behavior on opacity { NumberAnimation { duration: 180 } }
        color: closeQrArea.containsMouse ? "#c0392b" : "#e74c3c"
        border.color: "white"; border.width: 2
        z: 50
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: "✕"
            color: "white"; font.pixelSize: 22; font.bold: true
        }
        MouseArea {
            id: closeQrArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeClicked()
        }
    }

    // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
    HoldToActivate {
        id: qrCloseGuard
        anchors.fill: qrCloseBtn
        z: 51
        onActivated: root.closeClicked()
    }
}
