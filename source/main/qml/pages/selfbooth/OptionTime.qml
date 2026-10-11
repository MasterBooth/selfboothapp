import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils/Money.js" as Money
import "../../theme"

Item {
    id: root

    signal timeSelected(int minutes)
    signal backClicked()

    // Hosts can override these lists for a separate flow such as cut-mode Selfbooth.
    property var timeOptions: [
        parseInt(eventManager.getAppSetting("selfbooth_time1", "5"))  || 5,
        parseInt(eventManager.getAppSetting("selfbooth_time2", "10")) || 10,
        parseInt(eventManager.getAppSetting("selfbooth_time3", "15")) || 15
    ]
    property var priceOptions: [0, 0, 0]

    // Background image from settings
    readonly property string bgImage: eventManager.getAppSetting("selfbooth_bg_option", "")

    // Portrait mode: cards stack vertically instead of horizontally
    property bool isPortrait: eventManager.getAppSetting("selfbooth_orientation", "landscape") === "portrait"
    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "selfbooth_orientation") root.isPortrait = (value === "portrait")
        }
    }

    // ── Background layer ──────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.bgImage === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#1a0a2e" }
            GradientStop { position: 1.0; color: "#0D0D14" }
        }
    }

    Image {
        anchors.fill: parent
        source: root.bgImage !== "" ? "file:///" + root.bgImage : ""
        fillMode: Image.PreserveAspectCrop
        visible: root.bgImage !== ""
    }

    // Background particles
    Repeater {
        model: 10
        delegate: Rectangle {
            property real sz: 60 + index * 20
            width: sz; height: sz; radius: sz / 2
            color: Qt.rgba(0.55, 0.15, 0.9, root.bgImage !== "" ? 0.04 : 0.06)
            x: (index % 4) * (root.width / 4) + 40
            y: (index % 3) * (root.height / 3) + 30

            NumberAnimation on x {
                from: x; to: x + (index % 2 === 0 ? 90 : -90)
                duration: 7000 + index * 800
                loops: Animation.Infinite; easing.type: Easing.InOutSine
            }
        }
    }

    // ── Back button ───────────────────────────────────────────────────────────
    Rectangle {
        width: 110; height: 44; radius: 8
        x: 28; y: 28; z: 10
        color: backArea.containsMouse ? Qt.rgba(0.22, 0.24, 0.27, 0.9) : Qt.rgba(0.15, 0.16, 0.23, 0.8)
        border.color: "#4a4d55"; border.width: 1
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: "← Quay lại"
            color: Theme.textMuted; font.pixelSize: 14
        }
        MouseArea {
            id: backArea; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backClicked()
        }
    }

    // ── Main content ──────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 56

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12

            Text {
                text: "Chọn Thời Gian Chụp"
                font.pixelSize: 52; font.bold: true; color: "white"
                style: root.bgImage !== "" ? Text.Outline : Text.Normal
                styleColor: "#1a0a2e"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Bạn muốn chụp trong bao lâu?"
                font.pixelSize: 20; color: "#bb88ee"; font.italic: true
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Cards: side-by-side (landscape) or stacked (portrait)
        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: root.isPortrait ? 1 : 3
            rows:    root.isPortrait ? 3 : 1
            spacing: root.isPortrait ? 28 : 48

            Repeater {
                model: root.timeOptions

                delegate: Rectangle {
                    id: packageCard
                    required property int index
                    required property var modelData
                    width:  root.isPortrait ? 480 : 240
                    height: root.isPortrait ? 200 : 280
                    radius: 20
                    color: btnArea.containsPress ? Qt.darker(btnColor, 1.3)
                         : btnArea.containsMouse ? Qt.lighter(btnColor, 1.2) : btnColor
                    border.color: Qt.lighter(btnColor, 1.6); border.width: 2

                    readonly property color btnColor: index === 0 ? "#1e6eea"
                                                    : index === 1 ? "#7c3aed"
                                                    : "#059669"
                    readonly property int packagePrice: index < root.priceOptions.length
                                                        ? parseInt(root.priceOptions[index]) || 0 : 0

                    layer.enabled: root.bgImage !== ""
                    Behavior on color { ColorAnimation { duration: 150 } }

                    // Portrait: horizontal layout (number left, label+button right)
                    // Landscape: vertical layout (number on top)
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 20
                        visible: root.isPortrait

                        Text {
                            text: modelData
                            font.pixelSize: 80; font.bold: true; color: "white"
                        }
                        ColumnLayout {
                            spacing: 8
                            Text { text: "phút"; font.pixelSize: 20; color: Qt.rgba(1,1,1,0.8); font.bold: true }
                            Text {
                                visible: packageCard.packagePrice > 0
                                text: Money.vnd(packageCard.packagePrice)
                                color: "#fef08a"; font.pixelSize: 16; font.bold: true
                            }
                            Rectangle {
                                width: 110; height: 34; radius: 17; color: Qt.rgba(0,0,0,0.25)
                                Text { anchors.centerIn: parent; text: "Chọn"; color: "white"; font.pixelSize: 14; font.bold: true }
                            }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16
                        visible: !root.isPortrait

                        Text {
                            text: modelData
                            font.pixelSize: 88; font.bold: true; color: "white"
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            text: "phút"
                            font.pixelSize: 22; color: Qt.rgba(1,1,1,0.8); font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {
                            visible: packageCard.packagePrice > 0
                            text: Money.vnd(packageCard.packagePrice)
                            color: "#fef08a"; font.pixelSize: 18; font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: 120; height: 36; radius: 18; color: Qt.rgba(0,0,0,0.25)
                            Text { anchors.centerIn: parent; text: "Chọn"; color: "white"; font.pixelSize: 14; font.bold: true }
                        }
                    }

                    MouseArea {
                        id: btnArea; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.timeSelected(modelData)
                    }
                }
            }
        }
    }
}
