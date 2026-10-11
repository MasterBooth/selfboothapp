import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    color: "#0f1115"
    
    FileDialog {
        id: layoutUploadDialog
        title: "Chọn các mẫu chụp"
        nameFilters: ["PNG Images (*.png)"]
        fileMode: FileDialog.OpenFile
        onAccepted: {
            if (root.eventId > 0) {
                 eventManager.uploadLayout(root.eventId, selectedFile)
            }
        }
    }

    property int eventId: -1
    property var eventData: ({})
    

    ListModel { id: layoutModel }
    
    function refreshLayouts() {
        if (root.eventId > 0) {
            layoutModel.clear()
            var layouts = eventManager.getLayouts(root.eventId)
            for(var i=0; i<layouts.length; i++) {
                layoutModel.append(layouts[i])
            }
        }
    }
    
    onEventIdChanged: refreshLayouts()
    
    Connections {
        target: eventManager
        function onLayoutUploaded(id) {
            if (id === root.eventId) refreshLayouts()
        }
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: parent.width
            spacing: 0

            // Empty state
            Rectangle {
                visible: root.eventId === -1
                Layout.fillWidth: true
                Layout.preferredHeight: 600
                color: "transparent"

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 16

                    Text {
                        text: "📋"
                        font.pixelSize: 64
                        opacity: 0.3
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Vui lòng chọn sự kiện để cấu hình"
                        font.pixelSize: 16
                        color: Theme.textMuted
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            // Config content (when event selected)
            ColumnLayout {
                visible: root.eventId !== -1
                Layout.fillWidth: true
                spacing: 0

                // Panel Header
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 70
                    color: "transparent"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        ColumnLayout {
                            spacing: 4
                            Layout.fillWidth: true
                            
                            Text {
                                text: root.eventData.name || "Sự kiện"
                                color: "#ffffff"
                                font.pixelSize: 20
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            
                            Text {
                                text: "Chuẩn bị bắt đầu"
                                color: "#10b981" // Green
                                font.pixelSize: 12
                            }
                        }
                    }

                    // Divider
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: "#2a2d35"
                    }
                }

                // Capture Section
                ConfigSection {
                    Layout.fillWidth: true
                    title: "Chụp Ảnh"

                    content: ColumnLayout {
                        spacing: 20

                        // Capture Mode Label
                        Text {
                            text: "Chế Độ Chụp"
                            color: Theme.textMuted
                            font.pixelSize: 13
                            font.weight: Font.Medium
                        }

                        // Capture Mode Picker
                        CaptureModePicker {
                            id: captureModePicker
                            selectedMode: root.eventData.captureMode || "photo"
                            onModeSelected: function(mode) {
                                eventManager.updateCaptureMode(root.eventId, mode)
                            }
                        }
                    }
                }

                // Statistics Section - Thống Kê
                ConfigSection {
                    id: statsSection
                    Layout.fillWidth: true
                    title: "Thống Kê"

                    property int printCount: 0
                    property int cutPrintCount: 0
                    property int noCutPrintCount: 0

                    function updatePrintCount() {
                        var eid = root.eventId
                        if (eid > 0) {
                            printCount     = eventManager.getEventPrintCount(eid)
                            cutPrintCount   = eventManager.getEventCutPrintCount(eid)
                            noCutPrintCount = eventManager.getEventNoCutPrintCount(eid)
                        } else {
                            printCount = cutPrintCount = noCutPrintCount = 0
                        }
                    }

                    Component.onCompleted: updatePrintCount()

                    Connections {
                        target: root
                        function onEventIdChanged() { statsSection.updatePrintCount() }
                    }

                    Connections {
                        target: eventManager
                        function onPrintCountChanged(eventId) {
                            if (eventId === root.eventId) statsSection.updatePrintCount()
                        }
                    }

                    content: ColumnLayout {
                        spacing: 12

                        // ── Tổng ảnh đã in ──────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                width: 36; height: 36; radius: 8
                                color: "#162a44"
                                Text { anchors.centerIn: parent; text: "🖨"; font.pixelSize: 18 }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Tổng Ảnh Đã In"; color: "#8a8d95"; font.pixelSize: 11 }
                                Text {
                                    text: statsSection.printCount.toString()
                                    color: "#ffffff"
                                    font.pixelSize: 24
                                    font.weight: Font.Bold
                                }
                            }
                        }

                        // ── Divider ──────────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true
                            height: 1
                            color: "#2a2d35"
                        }

                        // ── Ảnh cắt + Ảnh nguyên tờ (cạnh nhau) ────────────
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // Ảnh cắt
                            Rectangle {
                                Layout.fillWidth: true
                                height: 56
                                radius: 6
                                color: "#12263a"
                                border.color: "#1e4a6e"
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: statsSection.cutPrintCount.toString()
                                        color: "#4a9ede"
                                        font.pixelSize: 20
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: "✂ Ảnh Cắt"
                                        color: "#6a9dbf"
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }

                            // Ảnh nguyên tờ
                            Rectangle {
                                Layout.fillWidth: true
                                height: 56
                                radius: 6
                                color: "#1a2e1a"
                                border.color: "#2d6a2d"
                                border.width: 1

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 2

                                    Text {
                                        text: statsSection.noCutPrintCount.toString()
                                        color: "#4caf50"
                                        font.pixelSize: 20
                                        font.weight: Font.Bold
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                    Text {
                                        text: "▣ Ảnh Nguyên"
                                        color: "#5a9d5a"
                                        font.pixelSize: 10
                                        Layout.alignment: Qt.AlignHCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // Bottom spacing
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                }
            }
        }
    }
}
