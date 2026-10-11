// Hallmark - component: camera exposure settings - genre: editorial - theme: Studio soft
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    Layout.fillWidth: true
    color: Theme.settingsCard
    radius: Theme.settingsRadiusLarge
    border.color: Theme.settingsBorder
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + 28

    property bool controlEnabled: eventManager.getAppSetting("camera_control_enabled", "false") === "true"

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 14

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Thông số máy ảnh"
                    color: Theme.settingsText
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.controlEnabled ? "Điều khiển trực tiếp từ phần mềm" : "Đang dùng thông số cài trên máy ảnh"
                    color: root.controlEnabled ? Theme.settingsSuccess : Theme.settingsTextMuted
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            Button {
                id: refreshButton
                text: "Làm mới"
                Layout.preferredWidth: 92
                Layout.preferredHeight: 40
                onClicked: cameraController.getAllCameraProperties()

                background: Rectangle {
                    radius: 14
                    color: refreshButton.down ? "#F2DED4" : (refreshButton.hovered ? Theme.settingsCopperSoft : Theme.settingsSurface)
                    border.color: Theme.settingsBorder
                    border.width: 1
                }

                contentItem: Text {
                    text: refreshButton.text
                    color: Theme.settingsCopperDark
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }
            }

            StudioToggle {
                checked: root.controlEnabled
                onToggled: {
                    root.controlEnabled = checked
                    eventManager.setAppSetting("camera_control_enabled", checked ? "true" : "false")
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: root.width >= 720 ? 3 : 2
            columnSpacing: 12
            rowSpacing: 12
            enabled: root.controlEnabled
            opacity: root.controlEnabled ? 1.0 : 0.48

            CameraSettingSlider {
                label: "ISO"
                model: cameraController.isoList
                currentValue: cameraController.iso
                Layout.fillWidth: true
                onValueSelected: (val) => { cameraController.iso = val; eventManager.setAppSetting("camera_iso", val) }
            }

            CameraSettingSlider {
                label: "Khẩu độ"
                model: cameraController.apertureList
                currentValue: cameraController.aperture
                Layout.fillWidth: true
                onValueSelected: (val) => { cameraController.aperture = val; eventManager.setAppSetting("camera_aperture", val) }
            }

            CameraSettingSlider {
                label: "Tốc độ"
                model: cameraController.shutterSpeedList
                currentValue: cameraController.shutterSpeed
                Layout.fillWidth: true
                onValueSelected: (val) => { cameraController.shutterSpeed = val; eventManager.setAppSetting("camera_shutter", val) }
            }

            CameraSettingSlider {
                label: "Cân bằng trắng"
                model: cameraController.whiteBalanceList
                currentValue: cameraController.whiteBalance
                Layout.fillWidth: true
                onValueSelected: (val) => { cameraController.whiteBalance = val; eventManager.setAppSetting("camera_wb", val) }
            }

            CameraSettingSlider {
                label: "Nhiệt độ màu"
                model: cameraController.colorTemperatureList
                currentValue: cameraController.colorTemperature
                visible: cameraController.colorTemperatureList && cameraController.colorTemperatureList.length > 0
                Layout.fillWidth: true
                onValueSelected: (val) => cameraController.colorTemperature = val
            }

            CameraSettingSlider {
                label: "Bù sáng"
                model: cameraController.exposureCompensationList
                currentValue: cameraController.exposureCompensation
                Layout.fillWidth: true
                onValueSelected: (val) => cameraController.exposureCompensation = val
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Theme.settingsBorder
            opacity: root.controlEnabled ? 1.0 : 0.48
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: root.controlEnabled
            opacity: root.controlEnabled ? 1.0 : 0.48

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                Text {
                    text: "Lấy nét"
                    color: Theme.settingsText
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }

                Text {
                    text: cameraController.afEnabled ? "Tự động (AF)" : "Thủ công (MF)"
                    color: cameraController.afEnabled ? Theme.settingsSuccess : Theme.settingsWarning
                    font.pixelSize: 12
                }
            }

            StudioToggle {
                checked: cameraController.afEnabled
                onToggled: cameraController.afEnabled = checked
            }

            ComboBox {
                id: imageQualityCombo
                Layout.preferredWidth: 156
                Layout.preferredHeight: 42
                model: ["JPEG Fine", "JPEG Normal", "RAW", "RAW+JPEG"]

                background: Rectangle {
                    color: Theme.settingsSurface
                    radius: 14
                    border.color: imageQualityCombo.activeFocus ? Theme.settingsCopper : Theme.settingsBorder
                    border.width: imageQualityCombo.activeFocus ? 2 : 1
                }

                contentItem: Text {
                    text: imageQualityCombo.displayText
                    color: Theme.settingsText
                    leftPadding: 12
                    rightPadding: 28
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }
        }
    }

    component StudioToggle: Switch {
        id: toggle
        implicitWidth: 62
        implicitHeight: 32

        indicator: Rectangle {
            implicitWidth: 52
            implicitHeight: 28
            x: toggle.leftPadding
            y: parent.height / 2 - height / 2
            radius: 14
            color: toggle.checked ? Theme.settingsCopper : Theme.settingsBorder

            Rectangle {
                width: 22
                height: 22
                radius: 11
                anchors.verticalCenter: parent.verticalCenter
                x: toggle.checked ? parent.width - width - 3 : 3
                color: Theme.settingsCard
                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }

        contentItem: Item {}
    }
}
