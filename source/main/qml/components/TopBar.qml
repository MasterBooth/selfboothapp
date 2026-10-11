import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../theme"

Rectangle {
    id: root
    height: 80
    color: "transparent"

    property bool hasSelection: false
    readonly property color surfaceColor: Window.window ? Window.window.appSurfaceColor : "#121212"
    readonly property color fieldColor: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    readonly property color borderColor: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    readonly property color textColor: "#000000"
    readonly property color mutedTextColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65)

    signal launchClicked()
    signal settingsClicked()
    signal renameClicked()
    signal deleteClicked()
    signal duplicateClicked()
    signal searchTextChanged(string text)
    signal logoutClicked()
    signal quitClicked()

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Qt.rgba(root.borderColor.r, root.borderColor.g, root.borderColor.b, 0.55)
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.topMargin: 10
        anchors.bottomMargin: 10
        spacing: 10

        Image {
            source: "qrc:/logo.png"
            fillMode: Image.PreserveAspectFit
            Layout.preferredWidth: 120
            Layout.preferredHeight: 50
            Layout.alignment: Qt.AlignVCenter
        }

        // Các nút hành động (Đổi Tên / Xóa / Nhân bản / Cài Đặt / Khởi Chạy) đã
        // chuyển vào dialog thông tin sự kiện (mở khi click card) — không còn hiển
        // thị luôn ở thanh trên.

        Item { Layout.fillWidth: true }

        RowLayout {
            spacing: 10

            Rectangle {
                Layout.preferredHeight: 46
                Layout.preferredWidth: quitRow.implicitWidth + 28
                radius: 23
                color: quitMouse.pressed ? Theme.surface
                     : quitMouse.containsMouse ? Theme.surface : "transparent"
                border.color: quitMouse.containsMouse ? "#4FA4F2" : root.borderColor
                border.width: 2
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: quitRow
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        source: "qrc:/assets/icons/quit_app.png"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Text {
                        text: "Thoát phần mềm"
                        color: root.textColor
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: quitMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.quitClicked()
                }
            }

            Rectangle {
                visible: eventManager.getAppSetting("login_required", "true") === "true"
                Layout.preferredHeight: 46
                Layout.preferredWidth: logoutRow.implicitWidth + 28
                radius: 23
                color: logoutMouse.pressed ? Theme.surface
                     : logoutMouse.containsMouse ? Theme.surface : "transparent"
                border.color: logoutMouse.containsMouse ? "#e0604a" : root.borderColor
                border.width: 2
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    id: logoutRow
                    anchors.centerIn: parent
                    spacing: 8
                    Image {
                        source: "qrc:/assets/icons/logout_account.png"
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        mipmap: true
                    }
                    Text {
                        text: eventManager.isLoggedIn
                              ? (eventManager.isAdmin ? "Admin" : eventManager.currentEmployeeName)
                              : "—"
                        color: root.textColor
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                    Rectangle { width: 1; height: 20; color: root.borderColor }
                    Text {
                        text: "Đăng xuất"
                        color: "#D94A3A"
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }
                }

                MouseArea {
                    id: logoutMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.logoutClicked()
                }
            }
        }
    }

    component ActionButton: Rectangle {
        id: action
        property string label: ""
        property color baseColor: "#4FA4F2"
        property color hoverColor: "#5BB8FF"
        property color pressColor: "#2D86DE"
        property bool enabledVisual: true
        signal clicked()

        Layout.preferredHeight: 44
        Layout.preferredWidth: Math.max(90, buttonLabel.implicitWidth + 34)
        radius: 8
        opacity: enabledVisual ? 1.0 : 0.30
        color: actionMouse.pressed ? pressColor
             : actionMouse.containsMouse ? hoverColor : baseColor
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: buttonLabel
            anchors.centerIn: parent
            text: action.label
            color: "#000000"
            font.pixelSize: 18
            font.weight: Font.Bold
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: action.enabledVisual ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: action.clicked()
        }
    }
}
