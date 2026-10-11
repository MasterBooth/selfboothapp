import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    signal loginSuccess()   // Emitted after successful login or register

    // ── Helpers ──────────────────────────────────────────────────────────────

    // 0 = Đăng Nhập, 1 = Đăng Ký
    property int activeTab: 0

    function clearFields() {
        loginInput.text    = ""
        loginPin.clear()
        regName.text       = ""
        regPhone.text      = ""
        regPin.clear()
        errorMsg.text      = ""
    }

    // ── Background ───────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: "#0f1117"

        // Subtle gradient overlay
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#1a1d23" }
                GradientStop { position: 1.0; color: "#0d0f14" }
            }
        }
    }

    // ── Centre card ──────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.centerIn: parent
        width:  520
        height: cardColumn.implicitHeight + 56
        radius: 18
        color:  "#1e2130"
        border.color: "#2e3347"
        border.width: 1

        // Drop shadow
        layer.enabled: true
        layer.effect: null   // No QtGraphicalEffects needed

        ColumnLayout {
            id: cardColumn
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: 28
            spacing: 20

            // ── Logo / Title ─────────────────────────────────────────────
            Column {
                Layout.alignment: Qt.AlignHCenter
                spacing: 6
                topPadding: 8

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📷"
                    font.pixelSize: 48
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Photobooth"
                    color: "#ffffff"
                    font.pixelSize: 28
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Đăng nhập để tiếp tục"
                    color: Theme.textMuted
                    font.pixelSize: 14
                }
            }

            // ── Tab bar ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: 44
                radius: 10
                color: "#151820"

                Row {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 0

                    Repeater {
                        model: ["Đăng Nhập", "Đăng Ký"]
                        delegate: Rectangle {
                            width:  parent.width / 2
                            height: parent.height
                            radius: 8
                            color:  root.activeTab === index ? "#1e7eea" : "transparent"

                            Behavior on color { ColorAnimation { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: root.activeTab === index ? "#ffffff" : Theme.textMuted
                                font.pixelSize: 14
                                font.bold: root.activeTab === index
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    root.activeTab = index
                                    root.clearFields()
                                }
                            }
                        }
                    }
                }
            }

            // ── Error message ─────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                height: errorMsg.text !== "" ? errorMsg.implicitHeight + 14 : 0
                visible: errorMsg.text !== ""
                radius: 8
                color: "#3d1515"
                border.color: "#ef4444"
                border.width: 1

                Text {
                    id: errorMsg
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    anchors.margins: 10
                    wrapMode: Text.WordWrap
                    color: "#fca5a5"
                    font.pixelSize: 13
                }
            }

            // ─────────────────────────────────────────────────────────────
            // LOGIN form
            // ─────────────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: root.activeTab === 0

                Text { text: "Tên hoặc Số điện thoại"; color: Theme.textMuted; font.pixelSize: 13 }
                Rectangle {
                    Layout.fillWidth: true; height: 48; radius: 10
                    color: "#252838"; border.color: loginInput.activeFocus ? "#1e7eea" : "#2e3347"; border.width: 1
                    TextInput {
                        id: loginInput
                        anchors { fill: parent; margins: 14 }
                        color: "#ffffff"; font.pixelSize: 15
                        verticalAlignment: TextInput.AlignVCenter
                        Keys.onReturnPressed: doLogin()
                        Keys.onEnterPressed:  doLogin()
                    }
                    Text {
                        anchors { fill: parent; margins: 14 }
                        text: "Nhập tên hoặc số điện thoại"
                        color: Theme.textMuted; font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        visible: loginInput.text === "" && !loginInput.activeFocus
                    }
                }

                Text { text: "Mật khẩu (6 chữ số)"; color: Theme.textMuted; font.pixelSize: 13 }
                PinInput { id: loginPin; Layout.fillWidth: true }

                Button {
                    Layout.fillWidth: true
                    height: 50
                    text: "Đăng Nhập"
                    background: Rectangle {
                        color: parent.hovered ? "#2b8eff" : "#1e7eea"
                        radius: 10
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"
                        font.pixelSize: 16; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: doLogin()
                }
            }

            // ─────────────────────────────────────────────────────────────
            // REGISTER form
            // ─────────────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: root.activeTab === 1

                Text { text: "Họ và Tên"; color: Theme.textMuted; font.pixelSize: 13 }
                Rectangle {
                    Layout.fillWidth: true; height: 48; radius: 10
                    color: "#252838"; border.color: regName.activeFocus ? "#1e7eea" : "#2e3347"; border.width: 1
                    TextInput {
                        id: regName
                        anchors { fill: parent; margins: 14 }
                        color: "#ffffff"; font.pixelSize: 15
                        verticalAlignment: TextInput.AlignVCenter
                    }
                    Text {
                        anchors { fill: parent; margins: 14 }
                        text: "Nguyễn Văn A"; color: Theme.textMuted; font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        visible: regName.text === "" && !regName.activeFocus
                    }
                }

                Text { text: "Số điện thoại"; color: Theme.textMuted; font.pixelSize: 13 }
                Rectangle {
                    Layout.fillWidth: true; height: 48; radius: 10
                    color: "#252838"; border.color: regPhone.activeFocus ? "#1e7eea" : "#2e3347"; border.width: 1
                    TextInput {
                        id: regPhone
                        anchors { fill: parent; margins: 14 }
                        color: "#ffffff"; font.pixelSize: 15
                        inputMethodHints: Qt.ImhDigitsOnly
                        validator: RegularExpressionValidator { regularExpression: /^[0-9]{0,10}$/ }
                        verticalAlignment: TextInput.AlignVCenter
                    }
                    Text {
                        anchors { fill: parent; margins: 14 }
                        text: "0912345678"; color: Theme.textMuted; font.pixelSize: 15
                        verticalAlignment: Text.AlignVCenter
                        visible: regPhone.text === "" && !regPhone.activeFocus
                    }
                }

                Text { text: "Mật khẩu (6 chữ số)"; color: Theme.textMuted; font.pixelSize: 13 }
                PinInput { id: regPin; Layout.fillWidth: true }

                Button {
                    Layout.fillWidth: true
                    height: 50
                    text: "Đăng Ký"
                    background: Rectangle {
                        color: parent.hovered ? "#7c6ded" : "#6c5ce7"
                        radius: 10
                    }
                    contentItem: Text {
                        text: parent.text; color: "white"
                        font.pixelSize: 16; font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment:   Text.AlignVCenter
                    }
                    onClicked: doRegister()
                }
            }

            // ── Bottom spacer ─────────────────────────────────────────────
            Item { height: 4 }
        }
    }

    // ── Action handlers ──────────────────────────────────────────────────────

    function doLogin() {
        errorMsg.text = ""
        var result = userAuth.loginUser(loginInput.text.trim(), loginPin.pin)
        if (result === "") {
            root.loginSuccess()
        } else {
            errorMsg.text = result
            loginPin.clear()
        }
    }

    function doRegister() {
        errorMsg.text = ""
        var result = userAuth.registerUser(regName.text.trim(), regPhone.text.trim(), regPin.pin)
        if (result === "") {
            root.loginSuccess()
        } else {
            errorMsg.text = result
            regPin.clear()
        }
    }

    // ── PinInput component — 6 individual digit boxes ────────────────────────
    component PinInput: Item {
        id: pinRoot
        height: 60
        property string pin: ""

        function clear() { pin = ""; hiddenInput.text = "" }

        onVisibleChanged: if (visible) hiddenInput.forceActiveFocus()

        // Hidden TextInput that captures keyboard input
        TextInput {
            id: hiddenInput
            focus: true
            opacity: 0
            width: 1; height: 1
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 6
            validator: RegularExpressionValidator { regularExpression: /^[0-9]{0,6}$/ }
            onTextChanged: {
                // Strip non-digits and cap at 6
                var filtered = text.replace(/[^0-9]/g, "").substring(0, 6)
                if (filtered !== text) { text = filtered; return }
                pinRoot.pin = filtered
            }
            Keys.onReturnPressed: {
                // Bubble enter up to parent form actions
                if (pinRoot.parent && typeof pinRoot.parent.parent !== "undefined") {
                    var form = pinRoot.parent
                    if (form.visible) {
                        if (root.activeTab === 0) root.doLogin()
                        else root.doRegister()
                    }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Repeater {
                id: pinRepeater
                property int currentIndex: 0
                model: 6
                delegate: Rectangle {
                    width: 44; height: 54
                    radius: 8
                    color:  "#252838"
                    border.color: {
                        if (hiddenInput.activeFocus && index === pinRoot.pin.length) return "#1e7eea"
                        if (index < pinRoot.pin.length) return "#1e7eea"
                        return "#2e3347"
                    }
                    border.width: (hiddenInput.activeFocus && index === pinRoot.pin.length) ? 2 : 1

                    Text {
                        anchors.centerIn: parent
                        text: index < pinRoot.pin.length ? "●" : ""
                        color: "#ffffff"
                        font.pixelSize: 22
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: hiddenInput.forceActiveFocus()
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: hiddenInput.forceActiveFocus()
        }
    }
}
