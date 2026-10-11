import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Camera Controls Component
// Uses cameraController (string-based API, supports both Sony and Canon)
ColumnLayout {
    id: root
    spacing: 24

    // cameraController is a global context property (CameraController*)
    // It exposes isoList/shutterSpeedList/apertureList/whiteBalanceList as QStringList
    // and current values (iso/shutterSpeed/aperture/whiteBalance) as QString
    
    // ISO Control
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: " Cài đặt ISO"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: cameraController ? (cameraController.iso || "--") : "--"
                color: "#1e7eea"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        ComboBox {
            id: isoCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            model: cameraController ? cameraController.isoList : []
            currentIndex: cameraController ? cameraController.isoList.indexOf(cameraController.iso) : -1

            delegate: ItemDelegate {
                width: isoCombo.width
                contentItem: Text {
                    text: modelData
                    color: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: isoCombo.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#1e7eea" : (parent.hovered ? "#2a2d35" : "#1f2229")
                }
            }

            contentItem: Text {
                leftPadding: 12
                text: isoCombo.currentIndex >= 0 && isoCombo.model.length > 0
                      ? isoCombo.model[isoCombo.currentIndex]
                      : (cameraController ? cameraController.iso : "--")
                color: "#ffffff"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: isoCombo.pressed ? "#1f2229" : (isoCombo.hovered ? "#2a2d35" : "#1f2229")
                border.color: isoCombo.activeFocus ? "#1e7eea" : "#3a3d45"
                border.width: 1
                radius: 6
            }

            onActivated: function(index) {
                if (cameraController && index >= 0 && index < model.length) {
                    cameraController.setIso(model[index])
                }
            }
        }
    }
    
    // Aperture Control
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Cài đặt khẩu độ"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: cameraController ? (cameraController.aperture || "f/--") : "f/--"
                color: "#1e7eea"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        ComboBox {
            id: apertureCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            model: cameraController ? cameraController.apertureList : []
            currentIndex: cameraController ? cameraController.apertureList.indexOf(cameraController.aperture) : -1

            delegate: ItemDelegate {
                width: apertureCombo.width
                contentItem: Text {
                    text: modelData
                    color: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: apertureCombo.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#1e7eea" : (parent.hovered ? "#2a2d35" : "#1f2229")
                }
            }

            contentItem: Text {
                leftPadding: 12
                text: apertureCombo.currentIndex >= 0 && apertureCombo.model.length > 0
                      ? apertureCombo.model[apertureCombo.currentIndex]
                      : (cameraController ? cameraController.aperture : "f/--")
                color: "#ffffff"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: apertureCombo.pressed ? "#1f2229" : (apertureCombo.hovered ? "#2a2d35" : "#1f2229")
                border.color: apertureCombo.activeFocus ? "#1e7eea" : "#3a3d45"
                border.width: 1
                radius: 6
            }

            onActivated: function(index) {
                if (cameraController && index >= 0 && index < model.length) {
                    cameraController.setAperture(model[index])
                }
            }
        }
    }
    
    // Shutter Speed Control
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Cài đặt tốc độ chụp"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: cameraController ? (cameraController.shutterSpeed || "--") : "--"
                color: "#1e7eea"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        ComboBox {
            id: shutterSpeedCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            model: cameraController ? cameraController.shutterSpeedList : []
            currentIndex: cameraController ? cameraController.shutterSpeedList.indexOf(cameraController.shutterSpeed) : -1

            delegate: ItemDelegate {
                width: shutterSpeedCombo.width
                contentItem: Text {
                    text: modelData
                    color: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: shutterSpeedCombo.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#1e7eea" : (parent.hovered ? "#2a2d35" : "#1f2229")
                }
            }

            contentItem: Text {
                leftPadding: 12
                text: shutterSpeedCombo.currentIndex >= 0 && shutterSpeedCombo.model.length > 0
                      ? shutterSpeedCombo.model[shutterSpeedCombo.currentIndex]
                      : (cameraController ? cameraController.shutterSpeed : "--")
                color: "#ffffff"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: shutterSpeedCombo.pressed ? "#1f2229" : (shutterSpeedCombo.hovered ? "#2a2d35" : "#1f2229")
                border.color: shutterSpeedCombo.activeFocus ? "#1e7eea" : "#3a3d45"
                border.width: 1
                radius: 6
            }

            onActivated: function(index) {
                if (cameraController && index >= 0 && index < model.length) {
                    cameraController.setShutterSpeed(model[index])
                }
            }
        }
    }
    
    // White Balance Control
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Cân bằng sáng"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: cameraController ? (cameraController.whiteBalance || "Auto") : "Auto"
                color: "#1e7eea"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        ComboBox {
            id: whiteBalanceCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            model: cameraController ? cameraController.whiteBalanceList : []
            currentIndex: cameraController ? cameraController.whiteBalanceList.indexOf(cameraController.whiteBalance) : -1

            delegate: ItemDelegate {
                width: whiteBalanceCombo.width
                contentItem: Text {
                    text: modelData
                    color: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: whiteBalanceCombo.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#1e7eea" : (parent.hovered ? "#2a2d35" : "#1f2229")
                }
            }

            contentItem: Text {
                leftPadding: 12
                text: whiteBalanceCombo.currentIndex >= 0 && whiteBalanceCombo.model.length > 0
                      ? whiteBalanceCombo.model[whiteBalanceCombo.currentIndex]
                      : (cameraController ? cameraController.whiteBalance : "Auto")
                color: "#ffffff"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: whiteBalanceCombo.pressed ? "#1f2229" : (whiteBalanceCombo.hovered ? "#2a2d35" : "#1f2229")
                border.color: whiteBalanceCombo.activeFocus ? "#1e7eea" : "#3a3d45"
                border.width: 1
                radius: 6
            }

            onActivated: function(index) {
                if (cameraController && index >= 0 && index < model.length) {
                    cameraController.setWhiteBalance(model[index])
                }
            }
        }
    }

    // Color Temperature (Kelvin) Control
    // Chọn nhiệt độ màu thủ công. Canon/Sony tự chuyển WB sang chế độ
    // "Nhiệt độ màu" khi đặt giá trị Kelvin.
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Nhiệt độ màu (Kelvin)"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: cameraController && cameraController.colorTemperature
                      ? cameraController.colorTemperature + "K" : "--"
                color: "#1e7eea"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        ComboBox {
            id: kelvinCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            model: cameraController ? cameraController.colorTemperatureList : []
            currentIndex: cameraController
                ? cameraController.colorTemperatureList.indexOf(cameraController.colorTemperature)
                : -1

            delegate: ItemDelegate {
                width: kelvinCombo.width
                contentItem: Text {
                    text: modelData + "K"
                    color: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: kelvinCombo.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#1e7eea" : (parent.hovered ? "#2a2d35" : "#1f2229")
                }
            }

            contentItem: Text {
                leftPadding: 12
                text: kelvinCombo.currentIndex >= 0 && kelvinCombo.model.length > 0
                      ? kelvinCombo.model[kelvinCombo.currentIndex] + "K"
                      : (cameraController && cameraController.colorTemperature
                         ? cameraController.colorTemperature + "K" : "--")
                color: "#ffffff"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: kelvinCombo.pressed ? "#1f2229" : (kelvinCombo.hovered ? "#2a2d35" : "#1f2229")
                border.color: kelvinCombo.activeFocus ? "#1e7eea" : "#3a3d45"
                border.width: 1
                radius: 6
            }

            onActivated: function(index) {
                if (cameraController && index >= 0 && index < model.length) {
                    cameraController.setColorTemperature(model[index])
                }
            }
        }
    }

    // Image Quality Control (JPEG only — RAW/CRAW filtered out)
    ColumnLayout {
        spacing: 8
        Layout.fillWidth: true

        // Filtered list: only JPEG options (no RAW, CRAW, HEIF, RAW+JPEG combos)
        // RAW/CRAW have byte 2 (bits 23-16) = 0x64 or 0x63
        // Pure JPEG values have byte 2 in range 0x00–0x10 (size codes)
        property var jpegQualityModel: {
            if (!root.camera || !root.camera.imageQualityValues) return []
            var filtered = []
            var all = root.camera.imageQualityValues
            for (var i = 0; i < all.length; i++) {
                var v = all[i].value
                var byte2 = (v >> 16) & 0xFF
                // Skip RAW (0x64), CRAW (0x63), RAW variants, HEIF (0x80+)
                if (byte2 >= 0x63) continue
                // Only include known JPEG quality values
                var label = getImageQualityDisplayValue(v)
                if (label !== "Unknown") {
                    filtered.push({ value: v, label: label })
                }
            }
            return filtered
        }

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Chất lượng ảnh"
                color: "#ffffff"
                font.pixelSize: 14
                font.weight: Font.Medium
                Layout.fillWidth: true
            }
            Text {
                text: root.camera ? getImageQualityDisplayValue(root.camera.imageQuality) : "--"
                color: "#1e7eea"
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }

        ComboBox {
            id: imageQualityCombo
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            model: parent.jpegQualityModel
            currentIndex: {
                if (!root.camera) return -1
                var cur = root.camera.imageQuality
                var m = parent.jpegQualityModel
                for (var i = 0; i < m.length; i++) {
                    if (m[i].value === cur) return i
                }
                return 0
            }

            delegate: ItemDelegate {
                width: imageQualityCombo.width
                contentItem: Text {
                    text: modelData.label
                    color: "#ffffff"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                }
                highlighted: imageQualityCombo.highlightedIndex === index
                background: Rectangle {
                    color: highlighted ? "#1e7eea" : (parent.hovered ? "#2a2d35" : "#1f2229")
                }
            }

            contentItem: Text {
                leftPadding: 12
                text: imageQualityCombo.currentIndex >= 0 && imageQualityCombo.model.length > 0
                      ? imageQualityCombo.model[imageQualityCombo.currentIndex].label
                      : "--"
                color: "#ffffff"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                color: imageQualityCombo.pressed ? "#1f2229" : (imageQualityCombo.hovered ? "#2a2d35" : "#1f2229")
                border.color: imageQualityCombo.activeFocus ? "#1e7eea" : "#3a3d45"
                border.width: 1
                radius: 6
            }

            onActivated: function(index) {
                if (root.camera && index >= 0 && index < model.length) {
                    root.camera.setImageQuality(model[index].value)
                }
            }
        }
    }
    
    // Image Quality section removed for Sony compatibility
    // (Sony does not expose JPEG quality variants in the same Canon-coded way)

    // Refresh button — forces a property list reload from camera
    // Useful after reconnecting or when lists appear empty
    Button {
        Layout.fillWidth: true
        Layout.preferredHeight: 36
        text: "↺  Làm mới thông số"
        font.pixelSize: 12
        visible: cameraController && cameraController.isConnected

        background: Rectangle {
            color: parent.pressed ? "#1565c0" : (parent.hovered ? "#2a3a55" : "#1e293b")
            radius: 6
            border.color: "#3a5070"
            border.width: 1
        }
        contentItem: Text {
            text: parent.text
            color: "#8ab4d8"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: {
            if (cameraController) cameraController.fetchCameraPropertyLists()
        }
    }

    // Helper functions — kept for backward compat but no longer used by combos
    function getISODisplayValue(value) {
        if (!value) return "--"
        var isoMap = {
            0x00000040: "50",
            0x00000048: "100",
            0x0000004b: "125",
            0x0000004d: "160",
            0x00000050: "200",
            0x00000053: "250",
            0x00000055: "320",
            0x00000058: "400",
            0x0000005b: "500",
            0x0000005d: "640",
            0x00000060: "800",
            0x00000063: "1000",
            0x00000065: "1250",
            0x00000068: "1600",
            0x0000006b: "2000",
            0x0000006d: "2500",
            0x00000070: "3200",
            0x00000073: "4000",
            0x00000075: "5000",
            0x00000078: "6400",
            0x0000007b: "8000",
            0x0000007d: "10000",
            0x00000080: "12800",
            0x00000083: "16000",
            0x00000085: "20000",
            0x00000088: "25600"
        }
        return isoMap[value] || value.toString()
    }
    
    function getApertureDisplayValue(value) {
        if (!value) return "f/--"
        var apertureMap = {
            0x0d: "f/1.2",
            0x10: "f/1.4",
            0x13: "f/1.8",
            0x14: "f/2.0",
            0x15: "f/2.2",
            0x18: "f/2.8",
            0x1b: "f/3.5",
            0x1c: "f/4.0",
            0x1d: "f/4.5",
            0x20: "f/5.6",
            0x23: "f/7.1",
            0x24: "f/8.0",
            0x25: "f/9.0",
            0x28: "f/11",
            0x2b: "f/14",
            0x2c: "f/16",
            0x2d: "f/18",
            0x30: "f/22",
            0x33: "f/28",
            0x34: "f/32"
        }
        return apertureMap[value] || "f/" + (value / 10.0).toFixed(1)
    }
    
    function getShutterSpeedDisplayValue(value) {
        if (!value) return "--"
        var shutterMap = {
            0x0c: "Bulb",
            0x10: "30\"",
            0x13: "25\"",
            0x14: "20\"",
            0x15: "20\"",
            0x18: "15\"",
            0x1b: "13\"",
            0x1c: "10\"",
            0x1d: "10\"",
            0x20: "8\"",
            0x23: "6\"",
            0x24: "6\"",
            0x25: "5\"",
            0x28: "4\"",
            0x2b: "3\"2",
            0x2c: "3\"",
            0x2d: "2\"5",
            0x30: "2\"",
            0x33: "1\"6",
            0x34: "1\"5",
            0x35: "1\"3",
            0x38: "1\"",
            0x3b: "0\"8",
            0x3c: "0\"7",
            0x3d: "0\"6",
            0x40: "0\"5",
            0x43: "0\"4",
            0x44: "0\"3",
            0x45: "0\"3",
            0x48: "1/4",
            0x4b: "1/5",
            0x4c: "1/6",
            0x4d: "1/6",
            0x50: "1/8",
            0x53: "1/10",
            0x54: "1/10",
            0x55: "1/13",
            0x58: "1/15",
            0x5b: "1/20",
            0x5c: "1/20",
            0x5d: "1/25",
            0x60: "1/30",
            0x63: "1/40",
            0x64: "1/45",
            0x65: "1/50",
            0x68: "1/60",
            0x6b: "1/80",
            0x6c: "1/90",
            0x6d: "1/100",
            0x70: "1/125",
            0x73: "1/160",
            0x74: "1/180",
            0x75: "1/200",
            0x78: "1/250",
            0x7b: "1/320",
            0x7c: "1/350",
            0x7d: "1/400",
            0x80: "1/500",
            0x83: "1/640",
            0x84: "1/750",
            0x85: "1/800",
            0x88: "1/1000",
            0x8b: "1/1250",
            0x8c: "1/1500",
            0x8d: "1/1600",
            0x90: "1/2000",
            0x93: "1/2500",
            0x94: "1/3000",
            0x95: "1/3200",
            0x98: "1/4000",
            0x9b: "1/5000",
            0x9c: "1/6000",
            0x9d: "1/6400",
            0xa0: "1/8000"
        }
        return shutterMap[value] || "1/" + value
    }
    
    function getWhiteBalanceDisplayValue(value) {
        var wbMap = {
            0: "Auto",
            1: "Daylight",
            2: "Cloudy",
            3: "Tungsten",
            4: "Fluorescent",
            5: "Flash",
            6: "Manual",
            8: "Shade",
            9: "Color Temp"
        }
        return wbMap[value] || "Custom"
    }
    
}

