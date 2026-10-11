import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Item {
    id: root

    property int eventId: -1
    property var eventData: ({})

    signal launchClicked(int eventId)
    signal settingsClicked(int eventId)
    signal renameRequested(int eventId)
    signal deleteRequested(int eventId)
    signal closeRequested()

    visible: eventId !== -1

    // Stats sống — refresh khi đổi event, định kỳ khi visible, và khi printCount đổi.
    // Không ghi đè eventData (do parent quản lý) — chỉ giữ riêng 3 con số để hiển thị.
    property int statsTotalPhotos: 0
    property int statsPrintCount: 0
    property int statsPendingFiles: 0

    function refreshStats() {
        if (eventId <= 0) {
            statsTotalPhotos = 0
            statsPrintCount = 0
            statsPendingFiles = 0
            return
        }
        var d = eventManager.getEventDetails(eventId)
        statsTotalPhotos  = (d.totalPhotos  !== undefined) ? d.totalPhotos  : 0
        statsPrintCount   = (d.printCount   !== undefined) ? d.printCount   : 0
        statsPendingFiles = (d.pendingFiles !== undefined) ? d.pendingFiles : 0
    }

    onEventIdChanged: refreshStats()
    onVisibleChanged: if (visible) refreshStats()

    Timer {
        id: statsRefreshTimer
        interval: 5000
        running: root.visible && root.eventId > 0
        repeat: true
        onTriggered: root.refreshStats()
    }

    Connections {
        target: eventManager
        function onPrintCountChanged(eid) {
            if (eid === root.eventId) root.refreshStats()
        }
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
                        text: "📷"
                        font.pixelSize: 20
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    Text {
                        text: root.eventData.name || "Sự kiện"
                        color: Theme.text
                        font.pixelSize: 15
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    RowLayout {
                        spacing: 5
                        Rectangle {
                            width: 7; height: 7; radius: 4
                            color: "#10b981"
                        }
                        Text {
                            text: "Sẵn sàng khởi chạy"
                            color: "#10b981"
                            font.pixelSize: 10
                        }
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
                        onClicked: root.closeRequested()
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

            // Location & Date
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: (root.eventData.location != null && root.eventData.location !== "") ||
                         (root.eventData.eventDate != null && root.eventData.eventDate !== "")

                RowLayout {
                    spacing: 8
                    visible: root.eventData.location != null && root.eventData.location !== ""
                    Text { text: "📍"; font.pixelSize: 12 }
                    Text {
                        text: root.eventData.location || ""
                        color: "#7080A0"
                        font.pixelSize: 11
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }

                RowLayout {
                    spacing: 8
                    visible: root.eventData.eventDate != null && root.eventData.eventDate !== ""
                    Text { text: "📅"; font.pixelSize: 12 }
                    Text {
                        text: {
                            if (!root.eventData.eventDate) return ""
                            try {
                                return new Date(root.eventData.eventDate).toLocaleDateString("vi-VN")
                            } catch(e) { return root.eventData.eventDate }
                        }
                        color: "#7080A0"
                        font.pixelSize: 11
                        Layout.fillWidth: true
                    }
                }
            }

            Text {
                text: "THỐNG KÊ"
                color: "#2D4070"
                font.pixelSize: 10
                font.weight: Font.Bold
                font.letterSpacing: 1.5
                Layout.topMargin: 10
                Layout.bottomMargin: 6
            }

            // Stats grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                rowSpacing: 7
                columnSpacing: 7

                // Photos taken
                Rectangle {
                    Layout.fillWidth: true
                    height: 66
                    radius: 9
                    color: "#0F1A2A"
                    border.color: "#1A3050"
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: root.statsTotalPhotos.toString()
                            color: "#4FA4F2"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "📸 Ảnh đã chụp"
                            color: "#445577"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Prints
                Rectangle {
                    Layout.fillWidth: true
                    height: 66
                    radius: 9
                    color: "#0A1F18"
                    border.color: "#0D3020"
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: root.statsPrintCount.toString()
                            color: "#10b981"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "🖨️ Ảnh đã in"
                            color: "#445577"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Capture mode
                Rectangle {
                    Layout.fillWidth: true
                    height: 66
                    radius: 9
                    color: "#0F1A2A"
                    border.color: "#1A3050"
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: {
                                var m = root.eventData.captureMode || "photo"
                                if (m === "photo") return "📷"
                                if (m === "video") return "🎥"
                                if (m === "boomerang") return "🔄"
                                return "📷"
                            }
                            font.pixelSize: 20
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: {
                                var m = root.eventData.captureMode || "photo"
                                if (m === "photo") return "Chụp ảnh"
                                if (m === "video") return "Quay video"
                                if (m === "boomerang") return "Boomerang"
                                return "Chụp ảnh"
                            }
                            color: "#445577"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                // Pending upload
                Rectangle {
                    Layout.fillWidth: true
                    height: 66
                    radius: 9
                    color: "#130F1F"
                    border.color: "#251540"
                    border.width: 1

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            text: root.statsPendingFiles.toString()
                            color: "#8B5CF6"
                            font.pixelSize: 24
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "☁️ Chờ upload"
                            color: "#445577"
                            font.pixelSize: 10
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: "#1E2030"
                Layout.bottomMargin: 12
            }

            // Action buttons
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7

                    Button {
                        text: "⚙  Cài đặt"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        background: Rectangle {
                            color: parent.hovered ? "#1A2540" : "#111827"
                            radius: 8
                            border.color: "#1E4080"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#4FA4F2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                        }
                        onClicked: root.settingsClicked(root.eventId)
                    }

                    Button {
                        text: "✏  Đổi tên"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 36

                        background: Rectangle {
                            color: parent.hovered ? "#1A2540" : "#111827"
                            radius: 8
                            border.color: "#1E4080"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#4FA4F2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                        }
                        onClicked: root.renameRequested(root.eventId)
                    }
                }

                Button {
                    text: "🗑  Xoá sự kiện"
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36

                    background: Rectangle {
                        color: parent.hovered ? "#2A1010" : "#1A0A0A"
                        radius: 8
                        border.color: parent.hovered ? "#5A1A1A" : "#2A1515"
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.hovered ? "#E05555" : "#6A3333"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    onClicked: root.deleteRequested(root.eventId)
                }
            }
        }
    }

    property real panelOpacity: eventId !== -1 ? 1.0 : 0.0
    Behavior on panelOpacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
    opacity: panelOpacity
}
