import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 980
    height: 680
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    title: "RX1 Print Tool"

    property string imagePath: ""

    FileDialog {
        id: imageDialog
        title: "Select image"
        nameFilters: ["Images (*.jpg *.jpeg *.png *.bmp)", "All files (*)"]
        onAccepted: root.imagePath = selectedFile
    }

    Connections {
        target: rx1Printer
        function onPrintFinished(success, message) {
            resultLabel.text = message
            resultLabel.palette.windowText = success ? "#176b3a" : "#9d1c20"
        }
    }

    palette.window: "#f5f6f8"
    palette.windowText: "#1f2328"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Label {
                text: "RX1 Print Tool"
                font.pixelSize: 26
                font.bold: true
                Layout.fillWidth: true
            }

            BusyIndicator {
                running: rx1Printer.busy
                visible: running
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
            }
        }

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            Rectangle {
                SplitView.preferredWidth: 560
                SplitView.minimumWidth: 430
                color: "#ffffff"
                border.color: "#d8dee4"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Choose Image"
                            onClicked: imageDialog.open()
                        }
                        Label {
                            text: rx1Printer.normalizeLocalPath(root.imagePath)
                            elide: Text.ElideMiddle
                            Layout.fillWidth: true
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#0f1115"
                        border.color: "#2d333b"
                        radius: 6

                        Image {
                            anchors.fill: parent
                            anchors.margins: 10
                            source: root.imagePath
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            visible: root.imagePath !== ""
                        }

                        Label {
                            anchors.centerIn: parent
                            text: "No image selected"
                            color: "#c9d1d9"
                            visible: root.imagePath === ""
                        }
                    }
                }
            }

            Rectangle {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 340
                color: "#ffffff"
                border.color: "#d8dee4"
                radius: 8

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Button {
                            text: "Scan"
                            enabled: !rx1Printer.busy
                            onClicked: {
                                rx1Printer.scanPrinters()
                                rx1Printer.scanSdkPorts()
                            }
                        }
                        Label {
                            text: rx1Printer.sdkLoaded ? "SDK loaded" : "SDK unavailable"
                            color: rx1Printer.sdkLoaded ? "#176b3a" : "#9d1c20"
                            Layout.fillWidth: true
                        }
                    }

                    Label { text: "Printer" }
                    ComboBox {
                        id: printerCombo
                        Layout.fillWidth: true
                        model: rx1Printer.printers
                        currentIndex: rx1Printer.printers.indexOf(rx1Printer.selectedPrinter)
                        onActivated: rx1Printer.selectedPrinter = currentText
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        rowSpacing: 10
                        columnSpacing: 12

                        Label { text: "Paper" }
                        ComboBox {
                            id: paperCombo
                            Layout.fillWidth: true
                            model: ["4x6", "6x8"]
                            currentIndex: 0
                        }

                        Label { text: "Che do cat" }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ButtonGroup { id: cutModeGroup }

                            Button {
                                id: noCutButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                text: "Khong cat"
                                checkable: true
                                checked: true
                                ButtonGroup.group: cutModeGroup
                                contentItem: Text {
                                    text: noCutButton.text
                                    color: noCutButton.checked ? "#ffffff" : "#1f2328"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.bold: noCutButton.checked
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: noCutButton.checked ? "#176b3a" : "#f6f8fa"
                                    border.color: noCutButton.checked ? "#176b3a" : "#d0d7de"
                                }
                            }

                            Button {
                                id: cutButton
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                text: "Cat 2 inch"
                                checkable: true
                                ButtonGroup.group: cutModeGroup
                                contentItem: Text {
                                    text: cutButton.text
                                    color: cutButton.checked ? "#ffffff" : "#1f2328"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.bold: cutButton.checked
                                }
                                background: Rectangle {
                                    radius: 6
                                    color: cutButton.checked ? "#176b3a" : "#f6f8fa"
                                    border.color: cutButton.checked ? "#176b3a" : "#d0d7de"
                                }
                            }
                        }

                        Label { text: "Copies" }
                        SpinBox {
                            id: copiesSpin
                            from: 1
                            to: 10
                            value: 1
                            editable: true
                            Layout.fillWidth: true
                        }

                        Label { text: "DPI" }
                        ComboBox {
                            id: dpiCombo
                            Layout.fillWidth: true
                            model: [300, 600]
                            currentIndex: 0
                        }

                        Label { text: "Orientation" }
                        ComboBox {
                            id: orientationCombo
                            Layout.fillWidth: true
                            textRole: "label"
                            valueRole: "value"
                            model: [
                                { "label": "Auto", "value": 0 },
                                { "label": "Landscape", "value": 1 },
                                { "label": "Portrait", "value": 2 }
                            ]
                            currentIndex: 0
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        text: "Print Image"
                        enabled: !rx1Printer.busy && root.imagePath !== "" && printerCombo.currentText !== ""
                        onClicked: rx1Printer.printImage(
                            root.imagePath,
                            printerCombo.currentText,
                            paperCombo.currentText,
                            cutButton.checked,
                            copiesSpin.value,
                            dpiCombo.currentValue,
                            orientationCombo.currentValue
                        )
                    }

                    Label {
                        id: resultLabel
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: rx1Printer.sdkPort === ""
                              ? rx1Printer.sdkStatus
                              : rx1Printer.sdkPort + " - " + rx1Printer.sdkStatus
                    }

                    TextArea {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        readOnly: true
                        text: rx1Printer.logText
                        wrapMode: TextArea.Wrap
                        font.family: "Consolas"
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        rx1Printer.scanPrinters()
        rx1Printer.scanSdkPorts()
    }
}
