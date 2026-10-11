import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Dialogs 1.3
import "../theme"

Page {
    id: root
    title: "Máy In(DNP RX1)"
    background: Rectangle { color: "#1e1e1e" }
    
    // Default image if none provided
    property string imageSource: ""

    header: ToolBar {
        background: Rectangle { color: "#333" }
        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            
            ToolButton {
                text: "Back"
                onClicked: root.StackView.view.pop()
            }
            
            Label {
                text: "Cài đặt máy in"
                color: "white"
                font.pointSize: 16
                Layout.alignment: Qt.AlignCenter
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // Status Section
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: "#2d2d2d"
            radius: 5
            border.color: printerManager.serverStatus.includes("Ready") ? "green" : "red"
            border.width: 2

            RowLayout {
                anchors.fill: parent
                anchors.margins: 15
                
                Label {
                    text: "Trạng Thái:"
                    color: "#aaa"
                    font.bold: true
                }
                Label {
                    text: printerManager.serverStatus
                    color: "white"
                    font.pointSize: 14
                    Layout.fillWidth: true
                }
                Button {
                    text: "Làm Mới"
                    onClicked: printerManager.checkStatus()
                }
            }
        }

        // Preview Section
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#000"
            border.color: "#444"
            
            Image {
                id: preview
                anchors.fill: parent
                anchors.margins: 2
                source: root.imageSource
                fillMode: Image.PreserveAspectFit
                
                Text {
                    anchors.centerIn: parent
                    text: "Không có ảnh chọn"
                    color: "#555"
                    visible: !parent.source
                }
            }
            
            DropArea {
                anchors.fill: parent
                onDropped: {
                    if (drop.hasUrls) {
                        root.imageSource = drop.urls[0]
                    }
                }
            }
        }

        Button {
            text: "Chọn Ảnh"
            Layout.alignment: Qt.AlignHCenter
            onClicked: fileDialog.open()
        }

        // Controls
        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: 10
            columnSpacing: 20

            Label { text: "Kích thước in:"; color: "white" }
            ComboBox {
                id: sizeSelector
                model: ["4x6 ", "6x8 "]
                Layout.fillWidth: true
            }

            Label { text: "Số bản in:"; color: "white" }
            SpinBox {
                id: copySelector
                from: 1; to: 10
                value: 1
                editable: true
                Layout.fillWidth: true
            }

            Label { text: "Chế độ cắt:"; color: "white" }
            CheckBox {
                text: "Không cắt"
                checked: false
                onCheckedChanged: printerManager.setCutterMode(checked ? 1 : 0)
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    leftPadding: parent.indicator.width + parent.spacing
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        // Actions
        Button {
            text: "In Ngay"
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            font.bold: true
            palette.button: "#4CAF50"
            palette.buttonText: "white"
            enabled: root.imageSource != ""
            
            onClicked: {
                var size = sizeSelector.currentIndex === 0 ? "4x6" : "6x8"
                printerManager.printImage(root.imageSource, copySelector.value, size)
            }
        }
    }

    FileDialog {
        id: fileDialog
        title: "Vui lòng chọn ảnh"
        folder: shortcuts.pictures
        nameFilters: ["Image files (*.jpg *.png)"]
        onAccepted: {
            root.imageSource = fileDialog.fileUrl
        }
    }

    Connections {
        target: printerManager
        function onPrintFinished(success, message) {
            console.log("In Thành Công: " + message)
            // Optional: Show popup
        }
    }
}
