import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils/Money.js" as Money
import "../../theme"
import "../../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // ── Inputs ────────────────────────────────────────────────────────────────
    property int totalPrice: 0   // số tiền cần thanh toán
    property string bgOverride: ""

    // ── Signals ───────────────────────────────────────────────────────────────
    signal paymentComplete(int received)   // đủ tiền
    signal closeClicked()

    // ── Internal state (bind lên billAcceptor) ────────────────────────────────
    property bool _sessionActive: false  // true chỉ SAU KHI startSession() đã được gọi
    property int  received:  billAcceptor.receivedAmount
    property int  remaining: Math.max(0, root.totalPrice - root.received)
    // isDone bị guard bởi _sessionActive: tránh stale receivedAmount từ session trước
    // kích hoạt doneTimer ngay khi component vừa tạo (trước khi startSession reset về 0)
    property bool isDone:    _sessionActive && root.received >= root.totalPrice && root.totalPrice > 0

    // ── Theme ─────────────────────────────────────────────────────────────────
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    // Accent theme hồng/vàng đồng bộ với app
    readonly property color cashPink:     "#ad436d"
    readonly property color cashPinkDark: "#6d2942"
    readonly property color cashGold:     "#f0c040"
    readonly property color cashGoldDark: "#a98b2e"
    property string backgroundImagePath: {
        if (root.bgOverride !== "") return root.bgOverride
        var s = eventManager.getAppSetting("cash_payment_bg_image", "")
        if (s !== "") return s
        if (eventManager.getAppSetting("global_background_enabled", "false") === "true") {
            var g = eventManager.getAppSetting("global_background_image", "")
            if (g !== "") return g
        }
        return "qrc:/assets/bg/payment_cash.png"
    }
    color: "transparent"
    gradient: backgroundImagePath === "" ? cashBackgroundGradient : null

    Gradient {
        id: cashBackgroundGradient
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
        GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
        z: -1
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────
    Component.onCompleted: {
        if (root.totalPrice <= 0) {
            showError("Giá chưa được cấu hình. Vào Cài Đặt → Thanh Toán để thiết lập giá.")
            return
        }
        if (!billAcceptor.connected) {
            showError("Máy đọc tiền chưa kết nối. Vào Cài Đặt để kết nối COM port.")
            return
        }
        // startSession() reset receivedAmount về 0 TRƯỚC khi _sessionActive = true,
        // đảm bảo binding isDone không thể evaluate true từ số tiền của session cũ.
        billAcceptor.startSession(root.totalPrice)
        _sessionActive = true
    }
    Component.onDestruction: {
        billAcceptor.stopSession()
    }

    // Theo dõi khi đủ tiền
    onIsDoneChanged: {
        if (root.isDone) doneTimer.start()
    }

    // Chờ 1.2s sau khi đủ tiền rồi emit signal
    Timer {
        id: doneTimer
        interval: 1200
        onTriggered: root.paymentComplete(root.received)
    }

    // ── Connections: bill event + connection state từ backend ────────────────
    Connections {
        target: billAcceptor

        function onBillAccepted(denomination, totalReceived) {
            billFlash.restart()
        }

        function onErrorOccurred(message) {
            // Reconnect errors are shown in the banner, not the error text
            if (!billAcceptor.reconnecting)
                showError(message)
        }

        function onConnectedChanged() {
            if (!billAcceptor.connected && !root.isDone) {
                // Device disconnected mid-session — backend will auto-reconnect
                showError("")          // clear any previous error
                errorText.visible = false
                reconnectBanner.visible = true
            } else if (billAcceptor.connected) {
                reconnectBanner.visible = false
                errorText.visible = false
            }
        }

        function onRunningChanged() {
            // Session was resumed by backend after reconnect
            if (billAcceptor.running && reconnectBanner.visible)
                reconnectBanner.visible = false
        }
    }

    function showError(msg) {
        errorText.text    = msg
        errorText.visible = msg.length > 0
    }

    // ── Top bar ───────────────────────────────────────────────────────────────
    Item {
        id: topBar
        width: parent.width; height: 100
        anchors.top: parent.top
        z: 10

        Text {
            anchors.centerIn: parent
            text: root.isDone ? "✅  Thanh Toán Thành Công!" : "💵  Thanh Toán Tiền Mặt"
            color: root.isDone ? "#4ade80" : "#ffffff"
            font.pixelSize: 38; font.weight: Font.Bold
            style: Text.Outline; styleColor: "#55000000"
            Behavior on color { ColorAnimation { duration: 300 } }
        }
    }

    // ── Main content ──────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width * 0.62, 820)
        spacing: 0

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }

        // ── 3 cards: cần / đã nhận / còn lại ─────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 22

            // Cần thanh toán
            Rectangle {
                Layout.fillWidth: true; height: 138; radius: 20
                color: "#ffffff"
                border.color: Qt.rgba(0.68, 0.26, 0.43, 0.45); border.width: 1

                ColumnLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: "Cần thanh toán"
                        color: root.cashPinkDark; font.pixelSize: 15; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: Money.vnd(root.totalPrice)
                        color: root.cashPink; font.pixelSize: 30; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Đã nhận
            Rectangle {
                id: receivedCard
                Layout.fillWidth: true; height: 138; radius: 20
                color: root.isDone ? "#eafaf0" : "#fffdf4"
                border.color: root.isDone ? "#22c55e"
                            : (root.received > 0 ? root.cashGold : "#e6d9a8")
                border.width: root.isDone ? 2 : 1
                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                // Flash khi nhận tiền
                SequentialAnimation {
                    id: billFlash
                    NumberAnimation { target: receivedCard; property: "border.width"; to: 3; duration: 80 }
                    NumberAnimation { target: receivedCard; property: "border.width"; to: 1; duration: 300 }
                }

                ColumnLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: "Đã nhận"
                        color: root.isDone ? "#16a34a" : root.cashGoldDark; font.pixelSize: 15; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        text: Money.vnd(root.received)
                        color: root.isDone ? "#16a34a" : (root.received > 0 ? "#c79a1e" : root.cashPinkDark)
                        font.pixelSize: 30; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }

            // Còn lại
            Rectangle {
                Layout.fillWidth: true; height: 138; radius: 20
                color: root.isDone ? "#eafaf0" : "#fdeef4"
                border.color: root.isDone ? "#22c55e"
                            : (root.remaining > 0 ? root.cashPink : "#e6c2d2")
                border.width: 1
                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                ColumnLayout {
                    anchors.centerIn: parent; spacing: 8
                    Text {
                        text: root.isDone ? "Tiền thừa" : "Còn lại"
                        color: root.isDone ? "#16a34a" : root.cashPinkDark; font.pixelSize: 15; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        text: {
                            if (root.isDone) {
                                var change = root.received - root.totalPrice
                                return (change > 0 ? "+ " : "") + Money.vnd(change)
                            }
                            return Money.vnd(root.remaining)
                        }
                        color: root.isDone ? "#16a34a" : (root.remaining > 0 ? root.cashPink : root.cashPinkDark)
                        font.pixelSize: 30; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                }
            }
        }

        Item { height: 32 }

        // ── Progress bar ──────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true; height: 18; radius: 9
            color: Qt.rgba(1, 1, 1, 0.20)
            border.color: Qt.rgba(1, 1, 1, 0.25); border.width: 1
            visible: root.totalPrice > 0

            Rectangle {
                width: root.totalPrice > 0
                       ? Math.min(1.0, root.received / root.totalPrice) * parent.width
                       : 0
                height: parent.height; radius: parent.radius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.isDone ? "#22c55e" : root.cashPink }
                    GradientStop { position: 1.0; color: root.isDone ? "#4ade80" : root.cashGold }
                }
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            }
        }

        Item { height: 28 }

        // ── Banner kết nối lại (hiện khi mất kết nối mid-session) ─────────────
        Rectangle {
            id: reconnectBanner
            Layout.fillWidth: true
            height: 64; radius: 16
            visible: false
            color: "#fff7e6"
            border.color: root.cashGold; border.width: 1

            RowLayout {
                anchors.centerIn: parent
                spacing: 14

                // Spinner dots
                Row {
                    spacing: 6
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: root.cashGoldDark
                            SequentialAnimation on opacity {
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.2; duration: 400 }
                                NumberAnimation { to: 1.0; duration: 400 }
                            }
                            Component.onCompleted: { opacity = index === 0 ? 1.0 : (index === 1 ? 0.6 : 0.2) }
                        }
                    }
                }

                Text {
                    text: "Mất kết nối máy đọc tiền — đang kết nối lại, vui lòng chờ..."
                    color: root.cashGoldDark; font.pixelSize: 14; font.bold: true
                }
            }
        }

        // ── Hướng dẫn ─────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: instructCol.implicitHeight + 36
            radius: 16
            color: "#ffffff"
            border.color: Qt.rgba(0.68, 0.26, 0.43, 0.35); border.width: 1
            visible: !root.isDone && !reconnectBanner.visible

            ColumnLayout {
                id: instructCol
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
                spacing: 12

                RowLayout {
                    spacing: 10
                    Text { text: "💡"; font.pixelSize: 20 }
                    Text {
                        text: "Hướng dẫn"
                        color: root.cashPink; font.pixelSize: 16; font.bold: true
                    }
                }
                Text {
                    text: "Đưa tiền vào máy đọc. Máy sẽ tự động nhận và đếm số tiền."
                    color: root.cashPinkDark; font.pixelSize: 14
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }

                // Danh sách mệnh giá hỗ trợ — chip vàng champagne
                Flow {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: ["10.000 ₫", "20.000 ₫", "50.000 ₫", "100.000 ₫", "200.000 ₫", "500.000 ₫"]
                        Rectangle {
                            width: denomTxt.implicitWidth + 22; height: 30; radius: 15
                            color: "#fff4d8"
                            border.color: root.cashGold; border.width: 1
                            Text {
                                id: denomTxt
                                anchors.centerIn: parent
                                text: modelData
                                color: root.cashGoldDark; font.pixelSize: 13; font.bold: true
                            }
                        }
                    }
                }
            }
        }

        // ── Thông báo lỗi (nếu có) ───────────────────────────────────────────
        Text {
            id: errorText
            Layout.fillWidth: true
            text: ""
            color: "#ef4444"
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            visible: false
            horizontalAlignment: Text.AlignHCenter
        }

        // ── Màn hình done ─────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 84; radius: 18
            visible: root.isDone
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#eafaf0" }
                GradientStop { position: 1.0; color: "#dcf5e6" }
            }
            border.color: "#22c55e"; border.width: 2

            Text {
                anchors.centerIn: parent
                text: "✅  Đang xử lý, vui lòng chờ..."
                color: "#16a34a"; font.pixelSize: 20; font.bold: true
            }
        }

        // ── Nút huỷ ──────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            visible: !root.isDone

            Item { Layout.fillWidth: true }

            Rectangle {
                width: 200; height: 54; radius: 14
                color: cancelCashMa.pressed ? "#f3d3e0"
                     : cancelCashMa.containsMouse ? "#fbe6ee" : "#ffffff"
                border.color: root.cashPink; border.width: 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "Huỷ"
                    color: root.cashPink; font.pixelSize: 16; font.bold: true
                }
                MouseArea {
                    id: cancelCashMa
                    anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        billAcceptor.stopSession()
                        root.closeClicked()
                    }
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }
    }
}
