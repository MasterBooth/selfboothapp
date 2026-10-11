pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Kích hoạt máy bằng mã OTP 4 số do quản trị viên cấp — hiện sau khi đăng nhập
// studio nếu máy chưa có chữ ký (giấy phép) hợp lệ.
// Nhập đúng mã: máy tải giấy phép đã ký, tự xác minh chữ ký + mã máy rồi lưu lại;
// từ đó chạy được kể cả khi mất mạng / máy chủ lỗi -> phát proceed().
// Không đặt anchors ở root: màn này luôn được StackView.push (StackView tự gán kích thước).
Item {
    id: screen

    signal proceed()
    property bool _proceeded: false

    readonly property bool compact: width < 880
    readonly property int pagePad: compact ? 22 : 56
    readonly property int shellPad: compact ? 22 : 34
    readonly property string displayFace: "Georgia"
    readonly property string bodyFace: "Segoe UI"
    readonly property color paper: Theme.settingsCanvas
    readonly property color paper2: "#EFE5DC"
    readonly property color paperTop: "#FDF6EC"
    readonly property color surface: Theme.settingsSurface
    readonly property color card: Theme.settingsCard
    readonly property color rule: Theme.settingsBorder
    readonly property color ink: Theme.settingsText
    readonly property color muted: Theme.settingsTextMuted
    readonly property color accent: Theme.settingsCopper
    readonly property color accentDark: Theme.settingsCopperDark
    readonly property color accentSoft: Theme.settingsCopperSoft
    readonly property color accentInk: "#FFF7EF"
    readonly property color danger: Theme.settingsDanger
    readonly property color dangerSoft: "#FFF1ED"
    readonly property var studio: studioAccount
    readonly property var machine: machineAuth
    readonly property var client: activation
    readonly property var license: licenseManager

    function _checkProceed() {
        if (!_proceeded && screen.license.valid) {
            _proceeded = true
            screen.proceed()
        }
    }

    function _submit() {
        errorText.text = ""
        if (screen.client.busy) return
        var code = otpField.text.trim()
        if (!/^[0-9]{4}$/.test(code)) { errorText.text = "Nhập đủ 4 chữ số"; return }
        screen.client.redeemOtp(code)
    }

    function _recheck() {
        errorText.text = ""
        screen.client.requestActivation()
        screen.client.syncStatus()
    }

    function _copyHwid() {
        hwidCopy.text = screen.machine.hwid
        hwidCopy.selectAll()
        hwidCopy.copy()
        copiedTimer.restart()
    }

    Component.onCompleted: {
        _checkProceed()
        if (_proceeded) return
        // Báo máy chủ để máy hiện trong mục "Chờ duyệt" của app admin; đồng thời
        // nhận ngay giấy phép nếu admin đã gia hạn cho máy từ trước.
        screen.client.requestActivation()
        screen.client.syncStatus()
        otpField.forceActiveFocus()
    }

    Connections {
        target: screen.license
        function onLicenseChanged() { screen._checkProceed() }
    }

    Connections {
        target: screen.client
        function onFailed(reason) {
            errorText.text = reason
            otpField.text = ""
            otpField.forceActiveFocus()
        }
    }

    // Dùng để sao chép mã máy vào clipboard.
    TextEdit { id: hwidCopy; visible: false }
    Timer { id: copiedTimer; interval: 1600 }

    Rectangle {
        anchors.fill: parent
        color: screen.paper
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(parent.height * 0.42, 360)
        gradient: Gradient {
            GradientStop { position: 0.0; color: screen.paperTop }
            GradientStop { position: 1.0; color: screen.paper }
        }
    }

    Rectangle {
        width: parent.width * 0.34
        height: parent.height
        anchors.right: parent.right
        color: screen.accentSoft
        opacity: screen.compact ? 0.22 : 0.34
    }

    Rectangle {
        width: 1
        height: parent.height
        anchors.right: parent.right
        anchors.rightMargin: screen.compact ? 26 : 92
        color: screen.rule
        opacity: 0.65
    }

    Flickable {
        id: pageFlick
        anchors.fill: parent
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        contentWidth: width
        contentHeight: stage.height

        Item {
            id: stage
            width: pageFlick.width
            height: Math.max(pageFlick.height, shell.implicitHeight + screen.pagePad * 2)

            Rectangle {
                id: shell
                anchors.centerIn: parent
                width: Math.min(parent.width - screen.pagePad * 2, screen.compact ? 560 : 1040)
                implicitHeight: shellLayout.implicitHeight + screen.shellPad * 2
                radius: screen.compact ? 22 : 30
                color: screen.surface
                border.color: screen.rule
                border.width: 1

                RowLayout {
                    id: shellLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: screen.shellPad
                    spacing: screen.compact ? 0 : 32

                    // ── Cột thông tin ────────────────────────────────────────
                    Rectangle {
                        Layout.preferredWidth: 392
                        Layout.fillHeight: true
                        Layout.minimumHeight: infoColumn.implicitHeight + 48
                        visible: !screen.compact
                        radius: 24
                        color: screen.paper
                        border.color: screen.rule
                        border.width: 1

                        ColumnLayout {
                            id: infoColumn
                            anchors.fill: parent
                            anchors.margins: 24
                            spacing: 20

                            Rectangle {
                                Layout.preferredWidth: 58
                                Layout.preferredHeight: 58
                                radius: 18
                                color: screen.ink

                                Text {
                                    anchors.centerIn: parent
                                    text: "S"
                                    color: screen.paper
                                    font.family: screen.displayFace
                                    font.pixelSize: 32
                                    font.weight: Font.DemiBold
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Kích hoạt máy"
                                color: screen.ink
                                wrapMode: Text.WordWrap
                                font.family: screen.displayFace
                                font.pixelSize: 38
                                font.weight: Font.DemiBold
                                lineHeight: 0.95
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                color: screen.rule
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Mỗi máy cần chữ ký kích hoạt do quản trị viên cấp. Kích hoạt một lần, máy lưu chữ ký và chạy được cả khi mất mạng."
                                color: screen.muted
                                wrapMode: Text.WordWrap
                                font.family: screen.bodyFace
                                font.pixelSize: 17
                                lineHeight: 1.35
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                InfoLine { title: "1. Gửi mã máy"; body: "Đọc hoặc gửi mã máy bên dưới cho quản trị viên." }
                                InfoLine { title: "2. Nhận mã kích hoạt"; body: "Quản trị viên cấp mã 4 số, dùng một lần trong 24 giờ." }
                                InfoLine { title: "3. Nhập mã"; body: "Máy lưu chữ ký và vào thẳng booth." }
                            }

                            Item { Layout.fillHeight: true }

                            HwidChip { Layout.fillWidth: true }
                        }
                    }

                    // ── Cột nhập mã ──────────────────────────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.maximumWidth: screen.compact ? 520 : 552
                        spacing: 16

                        Text {
                            Layout.fillWidth: true
                            text: "Nhập mã kích hoạt"
                            color: screen.ink
                            wrapMode: Text.WordWrap
                            font.family: screen.displayFace
                            font.pixelSize: screen.compact ? 32 : 40
                            font.weight: Font.DemiBold
                            lineHeight: 1.02
                        }

                        Text {
                            Layout.fillWidth: true
                            text: screen.license.revoked
                                  ? "Giấy phép của máy đã bị thu hồi. Liên hệ quản trị viên để được cấp lại mã 4 số."
                                  : "Máy chưa có chữ ký kích hoạt. Liên hệ quản trị viên để nhận mã 4 số."
                            color: screen.muted
                            wrapMode: Text.WordWrap
                            font.family: screen.bodyFace
                            font.pixelSize: 16
                            lineHeight: 1.35
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            radius: 16
                            color: screen.paper2
                            border.color: screen.rule
                            border.width: 1

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 16
                                text: "Studio: " + (screen.studio.studioName || "—")
                                      + (screen.studio.email ? "  ·  " + screen.studio.email : "")
                                color: screen.ink
                                elide: Text.ElideRight
                                font.family: screen.bodyFace
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }

                        HwidChip { Layout.fillWidth: true; visible: screen.compact }

                        Text {
                            Layout.fillWidth: true
                            text: "Mã kích hoạt (4 số)"
                            color: screen.ink
                            font.family: screen.bodyFace
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }

                        TextField {
                            id: otpField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 84
                            enabled: !screen.client.busy
                            maximumLength: 4
                            validator: RegularExpressionValidator { regularExpression: /[0-9]{0,4}/ }
                            inputMethodHints: Qt.ImhDigitsOnly
                            horizontalAlignment: TextInput.AlignHCenter
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: "• • • •"
                            font.family: screen.displayFace
                            font.pixelSize: 44
                            font.letterSpacing: 22
                            font.weight: Font.DemiBold
                            color: screen.ink
                            placeholderTextColor: screen.muted
                            selectedTextColor: screen.surface
                            selectionColor: screen.accent

                            background: Rectangle {
                                radius: 18
                                color: !otpField.enabled ? screen.paper2 : screen.card
                                border.width: otpField.activeFocus ? 2 : 1
                                border.color: otpField.activeFocus ? screen.accent : screen.rule
                            }

                            onTextChanged: {
                                if (text.length > 0) errorText.text = ""
                                if (text.length === 4) screen._submit()
                            }
                            Keys.onReturnPressed: screen._submit()
                            Keys.onEnterPressed: screen._submit()
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: errorText.text !== "" ? Math.max(46, errorText.implicitHeight + 22) : 0
                            visible: errorText.text !== ""
                            radius: 14
                            color: screen.dangerSoft
                            border.color: screen.danger
                            border.width: 1

                            Text {
                                id: errorText
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: 14
                                text: ""
                                color: screen.danger
                                wrapMode: Text.WordWrap
                                font.family: screen.bodyFace
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }

                        Rectangle {
                            id: submitButton
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            radius: 18
                            color: screen.client.busy ? screen.muted
                                  : (submitMouse.pressed ? screen.accentDark
                                  : (submitMouse.containsMouse ? Qt.darker(screen.accent, 1.08) : screen.accent))
                            opacity: screen.client.busy ? 0.78 : 1.0
                            scale: submitMouse.pressed ? 0.992 : 1.0

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on scale { NumberAnimation { duration: 90 } }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 32
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                                text: screen.client.busy ? "Đang kích hoạt..." : "Kích hoạt máy"
                                color: screen.accentInk
                                font.family: screen.bodyFace
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }

                            MouseArea {
                                id: submitMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !screen.client.busy
                                cursorShape: Qt.PointingHandCursor
                                onClicked: screen._submit()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            GhostButton {
                                Layout.fillWidth: true
                                label: "Kiểm tra lại"
                                onClicked: screen._recheck()
                            }

                            GhostButton {
                                Layout.fillWidth: true
                                label: "Đăng xuất studio"
                                onClicked: screen.studio.logout()
                            }
                        }
                    }
                }
            }
        }
    }

    component HwidChip: Rectangle {
        Layout.preferredHeight: 48
        radius: 14
        color: screen.accentSoft

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 8
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: "Mã máy: " + screen.machine.hwid
                color: screen.accentDark
                elide: Text.ElideMiddle
                font.family: screen.bodyFace
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Rectangle {
                Layout.preferredWidth: copyLabel.implicitWidth + 20
                Layout.preferredHeight: 32
                radius: 10
                color: copyMouse.containsMouse ? screen.surface : "transparent"
                border.color: screen.accentDark
                border.width: 1

                Text {
                    id: copyLabel
                    anchors.centerIn: parent
                    text: copiedTimer.running ? "Đã chép" : "Sao chép"
                    color: screen.accentDark
                    font.family: screen.bodyFace
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: screen._copyHwid()
                }
            }
        }
    }

    component GhostButton: Rectangle {
        id: ghost
        property string label: ""
        signal clicked()

        Layout.preferredHeight: 48
        radius: 16
        color: ghostMouse.containsMouse && ghost.enabled ? screen.paper2 : "transparent"
        border.color: screen.rule
        border.width: 1
        enabled: !screen.client.busy
        opacity: enabled ? 1.0 : 0.6

        Text {
            anchors.centerIn: parent
            text: ghost.label
            color: screen.ink
            font.family: screen.bodyFace
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: ghostMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: ghost.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: ghost.clicked()
        }
    }

    component InfoLine: RowLayout {
        id: infoLine
        property string title: ""
        property string body: ""

        Layout.fillWidth: true
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 9
            Layout.preferredHeight: 9
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 7
            radius: 4
            color: screen.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: infoLine.title
                color: screen.ink
                font.family: screen.bodyFace
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                Layout.fillWidth: true
                text: infoLine.body
                color: screen.muted
                wrapMode: Text.WordWrap
                font.family: screen.bodyFace
                font.pixelSize: 13
                lineHeight: 1.25
            }
        }
    }
}
