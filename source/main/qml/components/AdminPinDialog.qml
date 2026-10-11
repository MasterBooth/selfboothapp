// Hallmark · component: admin passcode dialog · genre: editorial · theme: Studio · keypad: iOS-inspired
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Popup {
    id: root

    signal accepted()
    signal rejected()

    property string subtitle: "Yêu cầu xác thực để vào Cài đặt"
    property bool forcePin: false

    property string _method: "pin"
    property bool   _qrEnabled: false
    property bool   _pinEnabled: true
    property bool   _pinFallback: false

    property string _input: ""
    property bool   _wrong: false
    property bool   _qrMode: false
    property real   _shakeX: 0

    readonly property bool _pinAvailable: root._pinEnabled || root._pinFallback
    readonly property real _hostWidth: parent ? parent.width : 608
    readonly property real _hostHeight: parent ? parent.height : 1080
    readonly property bool _portrait: root._hostHeight >= root._hostWidth
    readonly property real _outerMargin: root._portrait ? 18 : 34
    readonly property real _panelWidth: Math.max(340, Math.min(root._portrait ? 520 : 500,
                                                              root._hostWidth - root._outerMargin * 2))

    function _enterQrMode() {
        root._qrMode = true
        root._input = ""
        qrLoginManager.start(machineAuth.hwid, "security")
    }

    function _leaveQrMode() {
        root._qrMode = false
        qrLoginManager.cancel()
    }

    function _statusText() {
        if (root._wrong) return "Mã bảo mật không đúng. Vui lòng thử lại."
        if (root._qrMode) {
            if (qrLoginManager.status === "waiting") return "Quét mã QR để mở khóa quyền quản trị."
            if (qrLoginManager.status === "approved") return "Đã xác nhận. Đang mở khóa..."
            if (qrLoginManager.status === "expired") return "Mã QR đã hết hạn. Hãy tạo mã mới."
            if (qrLoginManager.status === "error")
                return qrLoginManager.errorText !== "" ? qrLoginManager.errorText : "Không tạo được mã QR."
        }
        return root.subtitle
    }

    modal: true
    closePolicy: Popup.NoAutoClose
    parent: Overlay.overlay
    x: (parent ? (parent.width - width) / 2 : 0) + root._shakeX
    y: parent ? Math.max(root._outerMargin, (parent.height - height) / 2) : 0
    width: root._panelWidth
    height: Math.min(contentCol.implicitHeight, root._hostHeight - root._outerMargin * 2)
    padding: 0
    clip: true

    Overlay.modal: Rectangle {
        color: Qt.rgba(42 / 255, 33 / 255, 28 / 255, 0.48)
    }

    onOpened: {
        root._input = ""
        root._wrong = false
        root._pinFallback = false
        root._method = "pin"
        root._qrEnabled = false
        root._pinEnabled = true
        root._qrMode = false
    }

    onClosed: qrLoginManager.cancel()

    Connections {
        target: qrLoginManager
        enabled: root._qrEnabled
        function onApproved(email, name, role, purpose) {
            if (purpose !== "security" || !root.opened) return
            eventManager.recordQrScan(email, name, role)
            root.close()
            root.accepted()
        }
    }

    background: Rectangle {
        radius: 28
        color: Theme.settingsSurface
        border.color: root._wrong ? Theme.settingsDanger : Theme.settingsBorder
        border.width: root._wrong ? 2 : 1
        clip: true
    }

    SequentialAnimation {
        id: shakeAnim
        PropertyAnimation { target: root; property: "_shakeX"; to: -9; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to:  9; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to: -5; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to:  5; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to:  0; duration: 42 }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: 170; easing.type: Easing.OutQuad }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 110; easing.type: Easing.OutQuad }
    }

    contentItem: ColumnLayout {
        id: contentCol
        width: root.width
        spacing: 0

        ColumnLayout {
            visible: root._qrMode
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 24
            Layout.bottomMargin: 24
            spacing: 18

            Text {
                Layout.fillWidth: true
                text: "Quét QR từ tài khoản quản trị"
                color: Theme.settingsText
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 18
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(300, root.width - 88)
                Layout.preferredHeight: width
                radius: 24
                color: Theme.settingsCard
                border.color: Theme.settingsBorder
                border.width: 1

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 14
                    radius: 18
                    color: "#FFFFFF"
                    border.color: "#EFE2D8"
                    border.width: 1
                }

                Image {
                    anchors.centerIn: parent
                    width: parent.width - 58
                    height: width
                    fillMode: Image.PreserveAspectFit
                    smooth: false
                    visible: qrLoginManager.qrData !== "" && qrLoginManager.status === "waiting"
                    source: qrLoginManager.qrData !== ""
                            ? "image://qr/" + encodeURIComponent(qrLoginManager.qrData) : ""
                }

                BusyIndicator {
                    anchors.centerIn: parent
                    running: root._qrMode && qrLoginManager.status === "waiting" && qrLoginManager.qrData === ""
                    visible: running
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 56
                    visible: qrLoginManager.status === "expired" || qrLoginManager.status === "error"
                    text: qrLoginManager.status === "expired" ? "Mã đã hết hạn"
                          : (qrLoginManager.errorText !== "" ? qrLoginManager.errorText : "Không tạo được mã")
                    color: Theme.settingsText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                PrimaryButton {
                    visible: qrLoginManager.status === "expired" || qrLoginManager.status === "error"
                    Layout.fillWidth: true
                    text: "Tạo mã mới"
                    enabled: true
                    onClicked: qrLoginManager.start(machineAuth.hwid, "security")
                }

                SecondaryButton {
                    visible: !root._pinEnabled && qrLoginManager.status === "error"
                    Layout.fillWidth: true
                    text: "Nhập PIN dự phòng"
                    onClicked: { root._pinFallback = true; root._leaveQrMode() }
                }
            }
        }

        ColumnLayout {
            visible: !root._qrMode && root._pinAvailable
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 24
            Layout.bottomMargin: 24
            spacing: 0

            Item {
                id: keypadStage
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(420, root.width - 56)
                Layout.preferredHeight: pinDots.height + 18 + iosPinPad.implicitHeight

                Row {
                    id: pinDots
                    Layout.alignment: Qt.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    spacing: 18

                    Repeater {
                        model: 6
                        Rectangle {
                            required property int index

                            width: 14
                            height: 14
                            radius: 7
                            color: index < root._input.length
                                   ? (root._wrong ? Theme.settingsDanger : Theme.settingsText)
                                   : "transparent"
                            border.width: 1.5
                            border.color: index < root._input.length
                                          ? "transparent"
                                          : (root._wrong ? Theme.settingsDanger : "#BFCBD0")
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                        }
                    }
                }

                PinPad {
                    id: iosPinPad
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: pinDots.bottom
                    anchors.topMargin: 18
                    height: implicitHeight
                    iosStyle: true
                    showLetters: true
                    keyDiameter: root._portrait ? 86 : 78
                    keySpacing: root._portrait ? 14 : 12
                    keyFill: "transparent"
                    keyFillDown: Qt.rgba(201 / 255, 111 / 255, 74 / 255, 0.12)
                    keyBorder: root._wrong ? Theme.settingsDanger : "#C9E8EE"
                    keyText: Theme.settingsText
                    accent: Theme.settingsCopper
                    submitEnabled: root._input.length > 0
                    backspaceEnabled: root._input.length > 0
                    onDigit: function(d) { root._append(d) }
                    onBackspace: root._backspace()
                    onSubmit: root._trySubmit()
                }
            }

        }
    }

    component CapsuleButton: Rectangle {
        id: button
        signal clicked()
        property string text: ""
        readonly property int implicitWidth: label.implicitWidth + 34

        radius: 999
        color: press.pressed ? "#F2DED4" : (press.containsMouse ? Theme.settingsCopperSoft : Theme.settingsCard)
        border.color: press.containsMouse || press.pressed ? Theme.settingsCopper : Theme.settingsBorder
        border.width: 1

        Text {
            id: label
            anchors.centerIn: parent
            text: button.text
            color: Theme.settingsCopperDark
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component PrimaryButton: Rectangle {
        id: button
        signal clicked()
        property string text: ""
        property bool enabled: true

        Layout.preferredHeight: 56
        radius: 18
        opacity: enabled ? 1.0 : 0.46
        color: enabled
               ? (press.pressed ? Theme.settingsCopperDark
                                 : (press.containsMouse ? Qt.darker(Theme.settingsCopper, 1.06) : Theme.settingsCopper))
               : "#D9CBC2"
        scale: press.pressed && enabled ? 0.992 : 1.0

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

        Text {
            anchors.centerIn: parent
            width: parent.width - 28
            text: button.text
            color: "#FFF7EF"
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 16
            font.weight: Font.DemiBold
            fontSizeMode: Text.Fit
            minimumPixelSize: 11
        }

        MouseArea {
            id: press
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component SecondaryButton: Rectangle {
        id: button
        signal clicked()
        property string text: ""
        property bool danger: false

        Layout.preferredHeight: 50
        radius: 16
        color: press.pressed
               ? (danger ? "#F4D4D0" : "#F2DED4")
               : (press.containsMouse ? (danger ? "#FFF1ED" : Theme.settingsCopperSoft) : Theme.settingsCard)
        border.color: press.containsMouse ? (danger ? Theme.settingsDanger : Theme.settingsCopper) : Theme.settingsBorder
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            width: parent.width - 18
            text: button.text
            color: button.danger ? Theme.settingsDanger : Theme.settingsCopperDark
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 14
            font.weight: Font.DemiBold
            fontSizeMode: Text.Fit
            minimumPixelSize: 10
        }

        MouseArea {
            id: press
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    function _append(d) {
        if (root._input.length >= 6) return
        root._input += d
        root._wrong = false
        if (root._input.length >= 6)
            root._trySubmit()
    }

    function _backspace() {
        root._input = root._input.slice(0, -1)
    }

    function _trySubmit() {
        if (eventManager.verifySecurityPin(root._input)) {
            root.close()
            root.accepted()
        } else {
            root._wrong = true
            root._input = ""
            shakeAnim.start()
        }
    }
}
