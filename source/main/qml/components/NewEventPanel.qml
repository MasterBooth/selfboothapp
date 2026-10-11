import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import "../theme"

Item {
    id: root

    signal createRequested(string name, string location, string eventDate)
    signal closeRequested()

    function clearFields() {
        nameField.text = ""
        locationField.text = ""
        dateField.text = ""
    }

    Rectangle {
        anchors.fill: parent
        color: "#13151F"
        radius: 14
        border.color: "#1E2030"
        border.width: 1

        // Top accent bar
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 3
            radius: 14
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#4FA4F2" }
                GradientStop { position: 1.0; color: "#2D86DE" }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 0

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 42; height: 42; radius: 10
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0.0; color: "#4FA4F2" }
                        GradientStop { position: 1.0; color: "#2060B0" }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "✨"
                        font.pixelSize: 20
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: "Tạo Sự Kiện Mới"
                        color: Theme.text
                        font.pixelSize: 15
                        font.weight: Font.Bold
                    }
                    Text {
                        text: "Điền thông tin sự kiện bên dưới"
                        color: "#445577"
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    width: 26; height: 26; radius: 7
                    color: closeMouse.containsMouse ? "#1E2540" : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#445577"
                        font.pixelSize: 12
                    }
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.clearFields()
                            root.closeRequested()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1E2030"
                Layout.topMargin: 14
                Layout.bottomMargin: 14
            }

            // Form fields
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Tên Sự Kiện *"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#7080A0"
                    }

                    TextField {
                        id: nameField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "YEP, Tiệc Cưới,..."
                        font.pixelSize: 13
                        color: Theme.surface
                        placeholderTextColor: "#2D3A55"

                        background: Rectangle {
                            color: "#0D0D14"
                            radius: 7
                            border.color: parent.activeFocus ? "#4FA4F2" : "#1E2030"
                            border.width: parent.activeFocus ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }
                        leftPadding: 10
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Địa Điểm Tổ Chức"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#7080A0"
                    }

                    TextField {
                        id: locationField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "VP Hà Nội,..."
                        font.pixelSize: 13
                        color: Theme.surface
                        placeholderTextColor: "#2D3A55"

                        background: Rectangle {
                            color: "#0D0D14"
                            radius: 7
                            border.color: parent.activeFocus ? "#4FA4F2" : "#1E2030"
                            border.width: parent.activeFocus ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }
                        leftPadding: 10
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Text {
                        text: "Ngày Tổ Chức"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#7080A0"
                    }

                    TextField {
                        id: dateField
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        placeholderText: "YYYY-MM-DD (vd: 2026-06-15)"
                        font.pixelSize: 13
                        color: Theme.surface
                        placeholderTextColor: "#2D3A55"

                        background: Rectangle {
                            color: "#0D0D14"
                            radius: 7
                            border.color: parent.activeFocus ? "#4FA4F2" : "#1E2030"
                            border.width: parent.activeFocus ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 150 } }
                        }
                        leftPadding: 10
                    }
                }
            }

            InputPanel {
                id: vkPanel
                Layout.fillWidth: true
                Layout.topMargin: 8
                visible: Qt.inputMethod.visible
                active: Qt.inputMethod.visible
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1E2030"
                Layout.bottomMargin: 12
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                // Create button
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: 9
                    opacity: nameField.text.length > 0 ? 1.0 : 0.30
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: createMouse.containsMouse ? "#5BB8FF" : "#4FA4F2" }
                        GradientStop { position: 1.0; color: createMouse.containsMouse ? "#4FA4F2" : "#2D86DE" }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "✨"; font.pixelSize: 15 }
                        Text {
                            text: "Tạo Sự Kiện"
                            color: "#ffffff"
                            font.pixelSize: 13
                            font.weight: Font.Bold
                        }
                    }

                    MouseArea {
                        id: createMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: nameField.text.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            if (nameField.text.length === 0) return
                            var eventDate = dateField.text.length > 0
                                ? (function() { try { return new Date(dateField.text).toISOString() } catch(e) { return new Date().toISOString() } })()
                                : new Date().toISOString()
                            root.createRequested(nameField.text, locationField.text, eventDate)
                            root.clearFields()
                        }
                    }
                }

                // Cancel button
                Button {
                    text: "Huỷ"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36

                    background: Rectangle {
                        color: parent.hovered ? "#1A2030" : "transparent"
                        radius: 8
                        border.color: "#1E2030"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#445577"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                    }
                    onClicked: {
                        root.clearFields()
                        root.closeRequested()
                    }
                }
            }
        }
    }
}
