// Hallmark - component: employee/admin login dialog - genre: editorial - theme: Studio
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Popup {
    id: root

    signal loggedIn()

    property string _error: ""
    property bool _wrong: false
    property var _employees: []
    property int _selIndex: 0
    property real _shakeX: 0
    readonly property bool _adminSelected: _selIndex <= 0

    property string _method: "pin"
    property bool _qrEnabled: false
    property bool _pinEnabled: true
    property bool _pinFallback: false
    property bool _qrMode: false
    readonly property bool _pinAvailable: root._pinEnabled || root._pinFallback

    readonly property real _hostWidth: Overlay.overlay ? Overlay.overlay.width : 608
    readonly property real _hostHeight: Overlay.overlay ? Overlay.overlay.height : 1080
    readonly property bool _portrait: root._hostHeight >= root._hostWidth
    readonly property real _outerMargin: root._portrait ? 18 : 34
    readonly property real _panelWidth: Math.max(320, Math.min(root._portrait ? 560 : 680,
                                                              root._hostWidth - root._outerMargin * 2))

    function _enterQrMode() {
        root._qrMode = true
        pinInput.text = ""
        qrLoginManager.start(machineAuth.hwid, "login")
    }

    function _leaveQrMode() {
        root._qrMode = false
        qrLoginManager.cancel()
    }

    function _selectedName() {
        if (root._selIndex <= 0) return "root"
        var emp = root._employees[root._selIndex - 1]
        return emp ? emp.full_name : "root"
    }

    function _selectedPrefix() {
        if (root._selIndex <= 0) return "ROOT"
        var emp = root._employees[root._selIndex - 1]
        return emp ? emp.prefix : "NV"
    }

    function _initials() {
        if (root._adminSelected) return "AD"
        var name = root._selectedName().trim()
        if (name === "") return "NV"
        var parts = name.split(/\s+/)
        if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase()
        return String(parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase()
    }

    function _titleText() {
        if (root._qrMode) return "Đăng nhập bằng mã QR"
        return root._adminSelected ? "Đăng nhập quản trị" : "Đăng nhập nhân viên"
    }

    function _statusText() {
        if (root._wrong) return root._error
        if (root._qrMode) {
            if (qrLoginManager.status === "waiting") return "Quét mã QR từ cổng quản trị để tiếp tục vận hành studio."
            if (qrLoginManager.status === "approved") return "Đã xác nhận. Đang đăng nhập..."
            if (qrLoginManager.status === "expired") return "Mã QR đã hết hạn. Hãy tạo mã mới."
            if (qrLoginManager.status === "error")
                return qrLoginManager.errorText !== "" ? qrLoginManager.errorText : "Không tạo được mã QR."
        }
        return "Chọn tài khoản và nhập mật khẩu để tiếp tục vận hành studio."
    }

    function reload() {
        root._employees = eventManager.getEmployees()
        root._selIndex = 0
    }

    parent: Overlay.overlay
    modal: true
    closePolicy: Popup.NoAutoClose
    padding: 0
    width: root._panelWidth
    height: Math.min(contentCol.implicitHeight, root._hostHeight - root._outerMargin * 2)
    x: Math.max(root._outerMargin, ((root._hostWidth - width) / 2) + root._shakeX)
    y: Math.max(root._outerMargin, (root._hostHeight - height) / 2)
    clip: true

    onOpened: {
        reload()
        root._error = ""
        root._wrong = false
        root._pinFallback = false
        root._method = eventManager.securityMethod()
        root._qrEnabled = root._method !== "pin"
        root._pinEnabled = root._method !== "qr"
        pinInput.text = ""
        if (root._qrEnabled) root._enterQrMode()
        else                 root._qrMode = false
        if (machineAuth.hwid) qrLoginManager.fetchStudioInfo(machineAuth.hwid)
    }

    onClosed: qrLoginManager.cancel()

    Connections {
        target: qrLoginManager
        function onStudioInfoChanged() {
            if (!root.opened) return
            var si = qrLoginManager.studioInfo
            if (si && si.loaded === true) {
                var prev = root._selIndex
                eventManager.syncCloudStaffAccounts(si.staff || [])
                root.reload()
                if (prev > 0 && prev <= root._employees.length) root._selIndex = prev
            }
        }
    }

    Connections {
        target: qrLoginManager
        function onApproved(email, name, role, purpose) {
            if (purpose !== "login" || !root.opened) return
            var err = eventManager.qrLogin(email, name, role)
            if (err === "") {
                root.close()
                root.loggedIn()
            } else {
                root._error = err
                root._wrong = true
            }
        }
    }

    function _append(d) {
        if (pinInput.text.length >= 12) return
        pinInput.text += d
        root._wrong = false
    }

    function _backspace() {
        pinInput.text = pinInput.text.slice(0, -1)
    }

    Overlay.modal: Rectangle {
        color: Qt.rgba(42 / 255, 33 / 255, 28 / 255, 0.36)
    }

    background: Rectangle {
        radius: Theme.settingsRadiusLarge + 2
        color: Theme.settingsSurface
        border.color: root._wrong ? Theme.settingsDanger : Theme.settingsBorder
        border.width: root._wrong ? 2 : 1
        clip: true

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 5
            color: root._wrong ? Theme.settingsDanger : Theme.settingsCopper
        }
    }

    SequentialAnimation {
        id: shakeAnim
        PropertyAnimation { target: root; property: "_shakeX"; to: -9; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to:  9; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to: -5; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to:  5; duration: 42 }
        PropertyAnimation { target: root; property: "_shakeX"; to:  0; duration: 42 }
        ScriptAction { script: root._wrong = false }
    }

    enter: Transition {
        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 150; easing.type: Easing.OutQuad }
        NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: 170; easing.type: Easing.OutQuad }
    }

    exit: Transition {
        NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 110 }
    }

    contentItem: ColumnLayout {
        id: contentCol
        width: root.width
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 154
            color: Theme.settingsSurface

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                anchors.topMargin: 28
                anchors.bottomMargin: 24
                spacing: 16

                Rectangle {
                    Layout.preferredWidth: 58
                    Layout.preferredHeight: 58
                    radius: 18
                    color: root._wrong ? "#FFF1ED" : Theme.settingsCopperSoft
                    border.color: root._wrong ? Theme.settingsDanger : "#EAC6B5"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: root._initials()
                        color: root._wrong ? Theme.settingsDanger : Theme.settingsCopperDark
                        font.pixelSize: 22
                        font.weight: Font.Black
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        text: root._titleText()
                        color: Theme.settingsText
                        elide: Text.ElideRight
                        font.family: "Georgia"
                        font.pixelSize: root._portrait ? 30 : 32
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 42
                        text: root._statusText()
                        color: root._wrong ? Theme.settingsDanger : Theme.settingsTextMuted
                        wrapMode: Text.WordWrap
                        maximumLineCount: 2
                        font.pixelSize: 14
                        lineHeight: 1.25
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                }

                CapsuleButton {
                    visible: root._qrEnabled && root._pinAvailable
                    Layout.preferredWidth: Math.max(92, implicitWidth)
                    Layout.preferredHeight: 42
                    text: root._qrMode ? "PIN" : "QR"
                    onClicked: root._qrMode ? root._leaveQrMode() : root._enterQrMode()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.settingsBorder
        }

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
                text: "Quét QR từ cổng quản trị"
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

            Text {
                Layout.fillWidth: true
                text: qrLoginManager.status === "waiting" ? "Đang chờ xác nhận trên thiết bị quản trị..."
                      : qrLoginManager.status === "approved" ? "Đã xác nhận. Đang đăng nhập..."
                      : qrLoginManager.status === "expired" ? "Mã đã hết hạn, hãy tạo mã mới."
                      : ""
                color: qrLoginManager.status === "expired" ? Theme.settingsWarning : Theme.settingsTextMuted
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                PrimaryButton {
                    visible: qrLoginManager.status === "expired" || qrLoginManager.status === "error"
                    Layout.fillWidth: true
                    text: "Tạo mã mới"
                    onClicked: qrLoginManager.start(machineAuth.hwid, "login")
                }

                SecondaryButton {
                    visible: !root._pinEnabled && qrLoginManager.status === "error"
                    Layout.fillWidth: true
                    text: "Nhập mật khẩu dự phòng"
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
            Layout.bottomMargin: 22
            spacing: 16

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: "Tài khoản"
                    color: Theme.settingsText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                ComboBox {
                    id: accountCombo
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56
                    model: {
                        var arr = ["Admin (root)"]
                        for (var i = 0; i < root._employees.length; i++)
                            arr.push(root._employees[i].full_name + "  -  " + root._employees[i].prefix)
                        return arr
                    }
                    currentIndex: root._selIndex
                    onActivated: function(idx) {
                        root._selIndex = idx
                        pinInput.forceActiveFocus()
                    }

                    contentItem: Text {
                        leftPadding: 18
                        rightPadding: 42
                        text: accountCombo.displayText
                        color: Theme.settingsText
                        font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    indicator: Text {
                        x: accountCombo.width - width - 16
                        y: (accountCombo.height - height) / 2
                        text: "⌄"
                        color: Theme.settingsTextMuted
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }

                    background: Rectangle {
                        color: Theme.settingsCard
                        radius: 18
                        border.color: accountCombo.activeFocus ? Theme.settingsCopper : Theme.settingsBorder
                        border.width: accountCombo.activeFocus ? 2 : 1
                    }

                    delegate: ItemDelegate {
                        id: accountOption

                        required property var modelData
                        required property int index

                        width: accountCombo.width
                        height: 48
                        highlighted: accountCombo.highlightedIndex === accountOption.index
                        contentItem: Text {
                            text: accountOption.modelData
                            color: Theme.settingsText
                            font.pixelSize: 14
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: accountOption.highlighted ? Theme.settingsCopperSoft : Theme.settingsSurface
                        }
                    }

                    popup: Popup {
                        y: accountCombo.height + 6
                        width: accountCombo.width
                        implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
                        padding: 6
                        background: Rectangle {
                            color: Theme.settingsSurface
                            radius: 18
                            border.color: Theme.settingsBorder
                            border.width: 1
                        }
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: accountCombo.popup.visible ? accountCombo.delegateModel : null
                            currentIndex: accountCombo.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator { }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: "Mật khẩu"
                        color: Theme.settingsText
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Text {
                        text: root._selectedPrefix()
                        color: root._wrong ? Theme.settingsDanger : Theme.settingsTextMuted
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                TextField {
                    id: pinInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    readOnly: true
                    echoMode: TextInput.Password
                    maximumLength: 12
                    placeholderText: "Nhập mật khẩu bằng bàn phím số"
                    color: Theme.settingsText
                    selectedTextColor: "#FFFFFF"
                    selectionColor: Theme.settingsCopper
                    font.pixelSize: 21
                    font.letterSpacing: 4
                    leftPadding: 16
                    rightPadding: 16
                    horizontalAlignment: Text.AlignHCenter

                    background: Rectangle {
                        color: root._wrong ? "#FFF1ED" : Theme.settingsCard
                        radius: 20
                        border.color: root._wrong ? Theme.settingsDanger
                                      : (pinInput.text.length > 0 ? Theme.settingsCopper : Theme.settingsBorder)
                        border.width: (root._wrong || pinInput.text.length > 0) ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                }
            }

            PinPad {
                Layout.fillWidth: true
                minKeyHeight: root._portrait ? 66 : 60
                keySpacing: 10
                keyRadius: 18
                submitEnabled: pinInput.text.length > 0
                backspaceEnabled: pinInput.text.length > 0
                accent: Theme.settingsCopper
                onDigit: function(d) { root._append(d) }
                onBackspace: root._backspace()
                onSubmit: root._trySubmit()
            }

            PrimaryButton {
                Layout.fillWidth: true
                text: "Đăng nhập"
                enabled: pinInput.text.length > 0
                onClicked: root._trySubmit()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.bottomMargin: 26
            Layout.preferredHeight: footerText.implicitHeight + 22
            radius: 18
            color: Theme.settingsCanvas
            border.color: Theme.settingsBorder
            border.width: 1

            Text {
                id: footerText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                text: root._adminSelected
                      ? "Admin có toàn quyền quản lý voucher, mã, doanh thu và cấu hình hệ thống."
                      : "Nhân viên chỉ thao tác trong phạm vi được cấp quyền."
                color: Theme.settingsTextMuted
                wrapMode: Text.WordWrap
                font.pixelSize: 12
                lineHeight: 1.25
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

        Layout.preferredHeight: 50
        radius: 16
        color: press.pressed ? "#F2DED4"
                             : (press.containsMouse ? Theme.settingsCopperSoft : Theme.settingsCard)
        border.color: press.containsMouse ? Theme.settingsCopper : Theme.settingsBorder
        border.width: 1

        Text {
            anchors.centerIn: parent
            width: parent.width - 18
            text: button.text
            color: Theme.settingsCopperDark
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

    function _trySubmit() {
        var err = eventManager.employeeLogin(root._selectedName(), pinInput.text)
        if (err === "") {
            root.close()
            root.loggedIn()
        } else {
            root._error = err
            root._wrong = true
            pinInput.text = ""
            shakeAnim.start()
        }
    }
}
