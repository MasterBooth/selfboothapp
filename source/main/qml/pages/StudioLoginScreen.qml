// Hallmark - pre-emit critique: P5 H4 E4 S4 R5 V4
// Hallmark - genre: editorial - macrostructure: Workbench - design-system: design.md - designed-as-app
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Đăng nhập / đăng ký studio (email + mật khẩu) — bắt buộc lần chạy đầu của bản PTB.
// Thành công: máy được gắn vào studio, nhận token riêng -> phát proceed().
// Không đặt anchors ở root: màn này luôn được StackView.push (StackView tự gán kích thước).
Item {
    id: screen

    signal proceed()
    property bool _proceeded: false
    // 0 = Đăng nhập, 1 = Đăng ký
    property int mode: 0

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
    readonly property color fieldHover: "#F9F1EA"
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

    function _checkProceed() {
        if (!_proceeded && screen.studio.loggedIn) {
            _proceeded = true
            screen.proceed()
        }
    }

    function _submit() {
        errorText.text = ""
        if (screen.studio.busy) return
        var email = emailField.text.trim()
        var pw = passwordField.text
        if (email === "" || pw === "") { errorText.text = "Nhập email và mật khẩu"; return }
        if (mode === 0) {
            screen.studio.login(email, pw)
            return
        }
        if (studioField.text.trim() === "") { errorText.text = "Nhập tên studio"; return }
        if (pw.length < 8) { errorText.text = "Mật khẩu tối thiểu 8 ký tự"; return }
        if (pw !== confirmField.text) { errorText.text = "Mật khẩu nhập lại không khớp"; return }
        screen.studio.registerStudio(studioField.text.trim(), email, pw)
    }

    function _switchMode(nextMode) {
        if (screen.studio.busy) return
        screen.mode = nextMode
        errorText.text = ""
    }

    Component.onCompleted: _checkProceed()

    Connections {
        target: screen.studio
        function onSignedIn() { screen._checkProceed() }
        function onAuthFailed(message) { errorText.text = message }
    }

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

                ColumnLayout {
                    id: shellLayout
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: screen.shellPad
                    spacing: screen.compact ? 20 : 28

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 14
                        visible: screen.compact

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 14
                            color: screen.ink

                            Text {
                                anchors.centerIn: parent
                                text: "S"
                                color: screen.paper
                                font.family: screen.displayFace
                                font.pixelSize: 24
                                font.weight: Font.DemiBold
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: "Selfbooth Studio"
                                color: screen.ink
                                elide: Text.ElideRight
                                font.family: screen.displayFace
                                font.pixelSize: 24
                                font.weight: Font.DemiBold
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Gắn máy với tài khoản quản trị"
                                color: screen.muted
                                elide: Text.ElideRight
                                font.family: screen.bodyFace
                                font.pixelSize: 14
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: screen.compact ? 0 : 32

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
                                    text: "Selfbooth Studio"
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
                                    text: "Máy này sẽ được liên kết với studio, đồng bộ phiên chụp và doanh thu về tài khoản quản trị."
                                    color: screen.muted
                                    wrapMode: Text.WordWrap
                                    font.family: screen.bodyFace
                                    font.pixelSize: 17
                                    lineHeight: 1.35
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    InfoLine { title: "1. Liên kết máy"; body: "Mỗi thiết bị dùng mã máy riêng." }
                                    InfoLine { title: "2. Đồng bộ dữ liệu"; body: "Ảnh, phiên chụp và thanh toán đi cùng studio." }
                                    InfoLine { title: "3. Quản trị tập trung"; body: "Đăng nhập một lần trước khi vận hành booth." }
                                }

                                Item { Layout.fillHeight: true }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    radius: 14
                                    color: screen.accentSoft

                                    Text {
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.margins: 14
                                        text: "Mã máy: " + screen.machine.hwid
                                        color: screen.accentDark
                                        elide: Text.ElideMiddle
                                        font.family: screen.bodyFace
                                        font.pixelSize: 13
                                        font.weight: Font.DemiBold
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            id: formColumn
                            Layout.fillWidth: true
                            Layout.maximumWidth: screen.compact ? 520 : 552
                            spacing: 16

                            Text {
                                Layout.fillWidth: true
                                text: screen.mode === 0 ? "Đăng nhập studio" : "Tạo studio mới"
                                color: screen.ink
                                wrapMode: Text.WordWrap
                                font.family: screen.displayFace
                                font.pixelSize: screen.compact ? 32 : 40
                                font.weight: Font.DemiBold
                                lineHeight: 1.02
                            }

                            Text {
                                Layout.fillWidth: true
                                text: screen.mode === 0
                                      ? "Dùng email và mật khẩu studio để mở khóa thiết bị này."
                                      : "Tạo studio rồi gắn ngay máy này vào tài khoản vừa đăng ký."
                                color: screen.muted
                                wrapMode: Text.WordWrap
                                font.family: screen.bodyFace
                                font.pixelSize: 16
                                lineHeight: 1.35
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 56
                                radius: 18
                                color: screen.paper2
                                border.color: screen.rule
                                border.width: 1

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 4
                                    spacing: 4

                                    Repeater {
                                        model: ["Đăng nhập", "Đăng ký"]
                                        delegate: Rectangle {
                                            id: tab
                                            required property int index
                                            required property string modelData
                                            readonly property bool selected: screen.mode === index

                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            radius: 14
                                            color: selected ? screen.ink
                                                            : (tabMouse.containsMouse && !screen.studio.busy ? screen.surface : "transparent")
                                            opacity: screen.studio.busy ? 0.62 : 1.0

                                            Behavior on color { ColorAnimation { duration: 120 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: tab.modelData
                                                color: tab.selected ? screen.paper : screen.ink
                                                font.family: screen.bodyFace
                                                font.pixelSize: 15
                                                font.weight: Font.DemiBold
                                                fontSizeMode: Text.Fit
                                                minimumPixelSize: 11
                                            }

                                            MouseArea {
                                                id: tabMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                enabled: !screen.studio.busy
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: screen._switchMode(tab.index)
                                            }
                                        }
                                    }
                                }
                            }

                            Field {
                                id: studioField
                                visible: screen.mode === 1
                                label: "Tên studio"
                                placeholderText: "Selfbooth Nguyễn Huệ"
                            }

                            Field {
                                id: emailField
                                label: "Email quản trị"
                                placeholderText: "studio@example.com"
                                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoAutoUppercase
                            }

                            Field {
                                id: passwordField
                                label: "Mật khẩu"
                                placeholderText: "Tối thiểu 8 ký tự"
                                echoMode: TextInput.Password
                            }

                            Field {
                                id: confirmField
                                visible: screen.mode === 1
                                label: "Nhập lại mật khẩu"
                                placeholderText: "Nhập lại mật khẩu"
                                echoMode: TextInput.Password
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
                                color: screen.studio.busy ? screen.muted
                                      : (submitMouse.pressed ? screen.accentDark
                                      : (submitMouse.containsMouse ? Qt.darker(screen.accent, 1.08) : screen.accent))
                                opacity: screen.studio.busy ? 0.78 : 1.0
                                scale: submitMouse.pressed ? 0.992 : 1.0

                                Behavior on color { ColorAnimation { duration: 120 } }
                                Behavior on scale { NumberAnimation { duration: 90 } }

                                Text {
                                    anchors.centerIn: parent
                                    width: parent.width - 32
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    elide: Text.ElideRight
                                    text: screen.studio.busy ? "Đang xử lý..."
                                                             : (screen.mode === 0 ? "Đăng nhập studio" : "Tạo studio")
                                    color: screen.accentInk
                                    font.family: screen.bodyFace
                                    font.pixelSize: 17
                                    font.weight: Font.DemiBold
                                    fontSizeMode: Text.Fit
                                    minimumPixelSize: 12
                                }

                                MouseArea {
                                    id: submitMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: !screen.studio.busy
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: screen._submit()
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                visible: screen.compact
                                text: "Mã máy: " + screen.machine.hwid
                                color: screen.muted
                                elide: Text.ElideMiddle
                                horizontalAlignment: Text.AlignHCenter
                                font.family: screen.bodyFace
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
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

    component Field: ColumnLayout {
        id: fieldRoot
        property alias text: fieldInput.text
        property string label: ""
        property string placeholderText: ""
        property int echoMode: TextInput.Normal
        property int inputMethodHints: Qt.ImhNone

        Layout.fillWidth: true
        spacing: 7

        Text {
            Layout.fillWidth: true
            text: fieldRoot.label
            color: screen.ink
            font.family: screen.bodyFace
            font.pixelSize: 13
            font.weight: Font.DemiBold
        }

        TextField {
            id: fieldInput
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            enabled: !screen.studio.busy
            echoMode: fieldRoot.echoMode
            inputMethodHints: fieldRoot.inputMethodHints
            placeholderText: fieldRoot.placeholderText
            font.family: screen.bodyFace
            font.pixelSize: 16
            color: screen.ink
            placeholderTextColor: screen.muted
            selectedTextColor: screen.surface
            selectionColor: screen.accent
            leftPadding: 16
            rightPadding: 16
            verticalAlignment: TextInput.AlignVCenter

            background: Rectangle {
                radius: 16
                color: !fieldInput.enabled ? screen.paper2
                      : (fieldInput.activeFocus ? screen.card
                      : (fieldInput.hovered ? screen.fieldHover : screen.card))
                border.width: 1
                border.color: fieldInput.activeFocus ? screen.accent
                            : (fieldInput.hovered ? screen.accentSoft : screen.rule)

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 4
                    radius: 2
                    visible: fieldInput.activeFocus
                    color: screen.accent
                }
            }

            Keys.onReturnPressed: screen._submit()
            Keys.onEnterPressed: screen._submit()
        }
    }
}
