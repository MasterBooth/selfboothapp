import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.VirtualKeyboard
import "../theme"

Dialog {
    id: root
    title: "Tạo sự kiện mới"
    modal: true
    anchors.centerIn: Overlay.overlay
    width: 500


    background: Rectangle {
        color: "#1f2229"
        radius: 12
        border.color: "#3a3d45"
        border.width: 2
    }

    header: Rectangle {
        height: 60
        color: "#1a1d23"
        radius: 12

        Text {
            anchors.centerIn: parent
            text: "Create New Event"
            font.pixelSize: 18
            font.weight: Font.Medium
            color: "#ffffff"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        // Event Name
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Tên Sự Kiện *"
                font.pixelSize: 13
                color: Theme.textMuted
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "YEP, Tiệc Cưới,..."
                font.pixelSize: 14
                color: "#ffffff"
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    color: "#15171c"
                    radius: 8
                    border.color: parent.activeFocus ? "#8b5a2b" : "#3a3d45"
                    border.width: 1
                }
            }
        }

        // Location
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Địa Điểm Tổ Chức"
                font.pixelSize: 13
                color: Theme.textMuted
            }

            TextField {
                id: locationField
                Layout.fillWidth: true
                placeholderText: "VP Hà Nội,..."
                font.pixelSize: 14
                color: "#ffffff"
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    color: "#15171c"
                    radius: 8
                    border.color: parent.activeFocus ? "#8b5a2b" : "#3a3d45"
                    border.width: 1
                }
            }
        }

        // Event Date
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "Ngày Tổ Chức"
                font.pixelSize: 13
                color: Theme.textMuted
            }

            TextField {
                id: dateField
                Layout.fillWidth: true
                placeholderText: "YYYY-MM-DD (e.g., 2026-02-14)"
                font.pixelSize: 14
                color: "#ffffff"
                placeholderTextColor: Theme.textMuted
                background: Rectangle {
                    color: "#15171c"
                    radius: 8
                    border.color: parent.activeFocus ? "#8b5a2b" : "#3a3d45"
                    border.width: 1
                }
            }
        }

        // Virtual Keyboard — hiện khi bất kỳ TextField nào được focus
        InputPanel {
            id: vkPanel
            Layout.fillWidth: true
            visible: Qt.inputMethod.visible
            active: Qt.inputMethod.visible
        }

        Item { Layout.fillHeight: true }

        // Buttons
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Item { Layout.fillWidth: true }

            Button {
                text: "Huỷ"
                font.pixelSize: 14
                Layout.preferredWidth: 100
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.hovered ? "#2a2d35" : "#1f2229"
                    radius: 8
                    border.color: "#3a3d45"
                    border.width: 1
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textMuted
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font: parent.font
                }

                onClicked: {
                    nameField.text = ""
                    locationField.text = ""
                    dateField.text = ""
                    root.close()
                }
            }

            Button {
                text: "Tạo Sự Kiện"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.preferredWidth: 140
                Layout.preferredHeight: 40

                background: Rectangle {
                    color: parent.hovered ? "#a67c52" : "#8b5a2b"
                    radius: 8
                }

                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font: parent.font
                }

                onClicked: {
                    if (nameField.text.length > 0) {
                        // Create event with ISO date format
                        let eventDate = dateField.text || new Date().toISOString()
                        if (!dateField.text) {
                            // If no date provided, use current date in ISO format
                            eventDate = new Date().toISOString()
                        } else {
                            // Try to parse the date and convert to ISO
                            try {
                                eventDate = new Date(dateField.text).toISOString()
                            } catch (e) {
                                eventDate = new Date().toISOString()
                            }
                        }

                        eventManager.createEvent(
                            nameField.text,
                            locationField.text,
                            eventDate
                        )

                        // Clear fields
                        nameField.text = ""
                        locationField.text = ""
                        dateField.text = ""
                        root.close()
                    }
                }
            }
        }
    }
}
