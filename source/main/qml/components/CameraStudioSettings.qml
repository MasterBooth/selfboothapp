// Hallmark - component: camera settings workbench - genre: editorial - theme: Studio soft
// states (StudioSegmented): default · hover · focus · pressed · disabled · selected
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import "../theme"

Item {
    id: root

    property var eventData: null
    property var toast: null

    signal switchCameraRequested(string brand)

    function notify(message) {
        if (root.toast && root.toast.show)
            root.toast.show(message)
    }

    function lanUrl() {
        var ip = eventManager.getLocalIpAddress()
        return ip !== "" ? ("http://" + ip + ":5514") : ""
    }

    readonly property bool isHotFolder: cameraController.captureSource === "hotfolder"
    readonly property bool isFujiHotFolder: root.isHotFolder && cameraController.hotFolderKind === "fuji"

    function sourceIndex() {
        return root.isHotFolder ? 4
             : cameraController.cameraType === "Sony" ? 1
             : cameraController.cameraType === "Nikon" ? 2
             : cameraController.cameraType === "Fuji" ? 3 : 0
    }

    function hotFolderStatusText() {
        switch (cameraController.hotFolderState) {
        case "watching":         return "Đang theo dõi"
        case "folder_unset":     return "Chưa chọn thư mục"
        case "folder_missing":   return "Không thấy thư mục"
        case "fuji_starting":    return "Đang mở HotFolder"
        case "fuji_stopped":     return "HotFolder đã tắt"
        case "fuji_exe_missing": return "Không mở được HotFolder"
        default:                 return "Chưa theo dõi"
        }
    }

    function hotFolderStatusColor() {
        var state = cameraController.hotFolderState
        return state === "watching" ? Theme.settingsSuccess
             : (state === "fuji_starting" || state === "folder_unset") ? Theme.settingsWarning
             : Theme.settingsDanger
    }

    function hotFolderHint() {
        switch (cameraController.hotFolderState) {
        case "watching":         return "Ảnh JPG mới được chuyển vào phiên đang chụp."
        case "folder_unset":     return "Chọn thư mục phần mềm chụp đang lưu ảnh."
        case "folder_missing":   return "Kiểm tra ổ đĩa hoặc chọn lại thư mục."
        case "fuji_starting":    return "Chờ biểu tượng HotFolder hiện ở khay hệ thống."
        case "fuji_stopped":     return "Bấm Mở lại để tiếp tục nhận ảnh."
        case "fuji_exe_missing": return "Thiếu tools\\fuji_hotfolder\\HotFolder.exe."
        default:                 return ""
        }
    }

    function cameraLabel() {
        if (root.isHotFolder)
            return cameraController.cameraModel
        return cameraController.cameraType === "Sony" ? "Sony CRSDK"
             : cameraController.cameraType === "Nikon" ? "Nikon MAID"
             : cameraController.cameraType === "Fuji" ? "Fujifilm X SDK"
             : "Canon EDSDK"
    }

    Component.onCompleted: {
        eventManager.setAppSetting("lan_pickup_enabled", "true")
        eventManager.setAppSetting("lan_pickup_pin", "")
    }

    ScrollView {
        id: cameraScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true
        background: Item {}

        ColumnLayout {
            width: cameraScroll.availableWidth
            spacing: 14

            Item { Layout.preferredHeight: 2 }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                spacing: 4

                Text {
                    text: "Máy ảnh"
                    color: Theme.settingsText
                    font.family: "Georgia"
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }

                Text {
                    text: root.isHotFolder
                          ? (cameraController.isConnected ? "Đang nhận ảnh qua " + root.cameraLabel()
                                                          : root.cameraLabel() + " · " + root.hotFolderStatusText())
                          : cameraController.isConnected
                          ? "Đã kết nối " + root.cameraLabel()
                          : "Chọn nguồn, kết nối máy ảnh và kiểm tra live view."
                    color: Theme.settingsTextMuted
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
            }

            StatusCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.preferredHeight: 92
            }

            LiveViewCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
                Layout.preferredHeight: Math.max(540, Math.min(760, cameraScroll.availableWidth * 1.02))
                eventData: root.eventData
            }

            StudioCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                SectionHeader {
                    title: "Kết nối"
                    subtitle: root.isHotFolder
                              ? (cameraController.hotFolderPath !== "" ? cameraController.hotFolderPath : root.cameraLabel())
                              : (cameraController.cameraModel !== "" ? cameraController.cameraModel : "Chưa nhận model máy ảnh")
                    statusText: root.isHotFolder ? root.hotFolderStatusText()
                              : cameraController.isConnecting ? "Đang kết nối"
                              : (cameraController.isConnected ? "Sẵn sàng" : "Chưa kết nối")
                    statusColor: root.isHotFolder ? root.hotFolderStatusColor()
                               : cameraController.isConnected ? Theme.settingsSuccess
                               : (cameraController.isConnecting ? Theme.settingsWarning : Theme.settingsDanger)
                }

                SettingRow {
                    title: "Nguồn máy ảnh"
                    detail: root.isHotFolder ? "Nhận ảnh từ thư mục; SDK đã ngắt để không giành máy."
                                             : "Chọn SDK đúng hãng đang cắm."

                    StudioComboBox {
                        id: cameraTypeCombo
                        Layout.preferredWidth: 260
                        model: ListModel {
                            ListElement { text: "Canon Camera (EDSDK)"; brand: "Canon" }
                            ListElement { text: "Sony Camera (CRSDK)"; brand: "Sony" }
                            ListElement { text: "Nikon Camera (MAID)"; brand: "Nikon" }
                            ListElement { text: "Fujifilm Camera (X SDK)"; brand: "Fuji" }
                            ListElement { text: "Hot Folder"; brand: "HotFolder" }
                        }
                        currentIndex: root.sourceIndex()
                        onActivated: {
                            var brand = model.get(currentIndex).brand
                            if (brand === "HotFolder") {
                                cameraController.setCaptureSource("hotfolder")
                            } else {
                                cameraController.switchCameraType(brand)
                                root.switchCameraRequested(brand)
                            }
                            // Chọn tay làm mất binding → gắn lại để theo đúng trạng thái C++.
                            currentIndex = Qt.binding(function() { return root.sourceIndex() })
                        }
                    }
                }

                // ── Hot Folder: kiểu + thư mục ───────────────────────────────
                ColumnLayout {
                    visible: root.isHotFolder
                    Layout.fillWidth: true
                    spacing: 12

                    SettingRow {
                        title: "Kiểu hot folder"
                        detail: root.isFujiHotFolder ? "Mở FUJIFILM HotFolder, nhận ảnh khi bấm remote."
                                                     : "Thư mục phần mềm chụp đang lưu ảnh."

                        StudioSegmented {
                            options: [
                                { text: "Thư mục ảnh", value: "folder" },
                                { text: "Fujifilm", value: "fuji" }
                            ]
                            value: cameraController.hotFolderKind
                            onPicked: (picked) => cameraController.setHotFolderKind(picked)
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 68
                        radius: 18
                        color: Theme.settingsSurface
                        border.color: Theme.settingsBorder
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Text {
                                text: cameraController.hotFolderPath !== ""
                                      ? cameraController.hotFolderPath
                                      : (root.isFujiHotFolder ? "Đang đọc thư mục của HotFolder" : "Chưa chọn thư mục")
                                color: cameraController.hotFolderPath !== "" ? Theme.settingsText : Theme.settingsTextMuted
                                font.family: "Consolas"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                elide: Text.ElideMiddle
                            }

                            SecondaryButton {
                                text: root.isFujiHotFolder ? "Mở lại" : "Chọn thư mục"
                                enabled: !root.isFujiHotFolder
                                         || cameraController.hotFolderState === "fuji_stopped"
                                         || cameraController.hotFolderState === "fuji_exe_missing"
                                Layout.preferredWidth: 132
                                onClicked: {
                                    if (root.isFujiHotFolder)
                                        cameraController.relaunchFujiHotFolder()
                                    else
                                        hotFolderDialog.open()
                                }
                            }
                        }
                    }

                    RowLayout {
                        visible: root.hotFolderHint() !== ""
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            Layout.preferredWidth: 8
                            Layout.preferredHeight: 8
                            radius: 4
                            color: root.hotFolderStatusColor()
                        }

                        Text {
                            text: root.hotFolderHint()
                            color: Theme.settingsTextMuted
                            font.pixelSize: 12
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Platform.FolderDialog {
                        id: hotFolderDialog
                        title: "Chọn thư mục hot folder"
                        folder: cameraController.hotFolderPath !== ""
                                ? "file:///" + cameraController.hotFolderPath.replace(/\\/g, "/") : ""
                        onAccepted: {
                            cameraController.setHotFolderFolder(folder.toString())
                            root.notify("Đã lưu thư mục hot folder")
                        }
                    }
                }

                SettingRow {
                    title: "Nguồn Live View"
                    detail: root.isHotFolder ? "Hot Folder dùng HDMI / Webcam cho live view."
                                             : "Dùng HDMI khi lấy hình qua webcam hoặc capture card."

                    StudioComboBox {
                        id: liveViewSourceCombo
                        Layout.preferredWidth: 220
                        enabled: !root.isHotFolder
                        model: ListModel {
                            ListElement { text: "SDK Camera"; value: "sdk" }
                            ListElement { text: "HDMI / Webcam"; value: "webcam" }
                        }
                        currentIndex: cameraController.useWebcamLiveView ? 1 : 0
                        onActivated: {
                            cameraController.setUseWebcamLiveView(currentIndex === 1)
                            currentIndex = Qt.binding(function() { return cameraController.useWebcamLiveView ? 1 : 0 })
                        }
                    }
                }

                RowLayout {
                    visible: cameraController.useWebcamLiveView
                    Layout.fillWidth: true
                    spacing: 10

                    SecondaryButton {
                        text: "Quét webcam"
                        Layout.preferredWidth: 128
                        onClicked: {
                            var list = cameraController.scanWebcams()
                            webcamCombo.model = list.length > 0 ? list : ["Không tìm thấy webcam"]
                        }
                    }

                    ComboBox {
                        id: webcamCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        model: cameraController.webcamList && cameraController.webcamList.length > 0
                               ? cameraController.webcamList : ["Nhấn quét webcam"]
                        onActivated: {
                            if (model[currentIndex] !== "Nhấn quét webcam"
                                    && model[currentIndex] !== "Không tìm thấy webcam")
                                cameraController.startWebcamLiveView(currentIndex)
                        }
                        background: Rectangle {
                            color: Theme.settingsSurface
                            radius: 14
                            border.color: webcamCombo.activeFocus ? Theme.settingsCopper : Theme.settingsBorder
                            border.width: webcamCombo.activeFocus ? 2 : 1
                        }
                        contentItem: Text {
                            text: webcamCombo.displayText
                            color: Theme.settingsText
                            leftPadding: 14
                            rightPadding: 28
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    PrimaryButton {
                        text: root.isHotFolder
                              ? (cameraController.isConnected ? "Theo dõi lại" : "Bắt đầu theo dõi")
                              : cameraController.isConnecting
                              ? "Đang kết nối"
                              : (cameraController.isConnected ? "Kết nối lại" : "Kết nối")
                        enabled: !cameraController.isConnecting
                        Layout.fillWidth: true
                        onClicked: cameraController.connectAsync()
                    }
                }
            }

            StudioCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                SectionHeader {
                    title: "Hiệu suất live view"
                    subtitle: "Giữ preview mượt, ảnh chụp gốc không bị giảm chất lượng."
                    statusText: cameraController.isLiveViewActive ? (cameraController.liveViewFps + " FPS") : "Offline"
                    statusColor: cameraController.isLiveViewActive ? Theme.settingsSuccess : Theme.settingsTextMuted
                }

                SettingRow {
                    title: "Độ phân giải"
                    detail: "Native ưu tiên nét; 960p/640p nhẹ hơn cho máy yếu."

                    StudioComboBox {
                        id: cameraLiveQualityCombo
                        Layout.preferredWidth: 220
                        textRole: "text"
                        model: ListModel {
                            ListElement { text: "Native"; value: "0" }
                            ListElement { text: "Mượt 640p"; value: "640" }
                            ListElement { text: "Cân bằng 960p"; value: "960" }
                            ListElement { text: "Cao 1280p"; value: "1280" }
                        }
                        Component.onCompleted: {
                            var saved = eventManager.getAppSetting("live_view_max_width", "0")
                            for (var i = 0; i < model.count; ++i)
                                if (model.get(i).value === saved) currentIndex = i
                        }
                        onActivated: {
                            var value = model.get(currentIndex).value
                            eventManager.setAppSetting("live_view_max_width", value)
                            cameraController.setMaxLiveViewWidth(parseInt(value))
                            root.notify("Đã lưu độ phân giải Live View")
                        }
                    }
                }

                SettingRow {
                    title: "Giới hạn FPS"
                    detail: "Giảm FPS khi máy tính nóng hoặc preview giật."

                    StudioComboBox {
                        id: cameraLiveFpsCombo
                        Layout.preferredWidth: 220
                        model: ListModel {
                            ListElement { text: "Tối đa 30 FPS"; value: "30" }
                            ListElement { text: "Cân bằng 20 FPS"; value: "20" }
                            ListElement { text: "Tiết kiệm 15 FPS"; value: "15" }
                            ListElement { text: "Tối thiểu 10 FPS"; value: "10" }
                        }
                        Component.onCompleted: {
                            var saved = eventManager.getAppSetting("live_view_target_fps", "30")
                            for (var i = 0; i < model.count; ++i)
                                if (model.get(i).value === saved) currentIndex = i
                        }
                        onActivated: {
                            var value = model.get(currentIndex).value
                            eventManager.setAppSetting("live_view_target_fps", value)
                            cameraController.setTargetLiveViewFps(parseInt(value))
                            root.notify("Đã lưu giới hạn FPS")
                        }
                    }
                }

                SettingRow {
                    title: "Lật ngang"
                    detail: "Bật khi muốn live view giống gương soi."

                    StudioSwitch {
                        id: mirrorSwitch
                        checked: cameraController.mirrorMode
                        Component.onCompleted: {
                            var saved = eventManager.getAppSetting("mirror_mode", "true")
                            cameraController.setMirrorMode(saved === "true")
                        }
                        onToggled: {
                            cameraController.setMirrorMode(checked)
                            eventManager.setAppSetting("mirror_mode", checked ? "true" : "false")
                        }
                    }
                }

                SettingRow {
                    title: "Live view nền"
                    detail: "Hiển thị live view ở màn chờ."

                    StudioSwitch {
                        id: liveViewBgSwitch
                        checked: eventManager.getAppSetting("landing_liveview_enabled", "true") === "true"
                        onToggled: eventManager.setAppSetting("landing_liveview_enabled",
                                                              checked ? "true" : "false")
                    }
                }

                ColumnLayout {
                    visible: cameraController.cameraType === "Fuji" && !root.isHotFolder
                    Layout.fillWidth: true
                    spacing: 10

                    ThinRule {}

                    SettingRow {
                        title: "Fuji frame size"
                        detail: "Native giữ nguyên frame SDK trả về."

                        StudioComboBox {
                            id: fujiLiveViewSizeCombo
                            Layout.preferredWidth: 220
                            model: ListModel {
                                ListElement { text: "Native"; value: "auto" }
                                ListElement { text: "L - SDK 1280"; value: "L" }
                                ListElement { text: "M - SDK 800"; value: "M" }
                                ListElement { text: "S - SDK 640"; value: "S" }
                            }
                            Component.onCompleted: {
                                var saved = eventManager.getAppSetting("fuji_live_view_size", "auto")
                                for (var i = 0; i < model.count; ++i)
                                    if (model.get(i).value === saved) currentIndex = i
                            }
                            onActivated: {
                                var value = model.get(currentIndex).value
                                var quality = eventManager.getAppSetting("fuji_live_view_quality", "fine")
                                eventManager.setAppSetting("fuji_live_view_size", value)
                                cameraController.setFujiLiveViewOptions(value, quality)
                                root.notify("Đã lưu kích thước Live View Fuji")
                            }
                        }
                    }

                    SettingRow {
                        title: "Fuji quality"
                        detail: "Fine nét hơn; Basic nhẹ hơn."

                        StudioComboBox {
                            id: fujiLiveViewQualityCombo
                            Layout.preferredWidth: 220
                            model: ListModel {
                                ListElement { text: "Fine"; value: "fine" }
                                ListElement { text: "Normal"; value: "normal" }
                                ListElement { text: "Basic"; value: "basic" }
                            }
                            Component.onCompleted: {
                                var saved = eventManager.getAppSetting("fuji_live_view_quality", "fine")
                                for (var i = 0; i < model.count; ++i)
                                    if (model.get(i).value === saved) currentIndex = i
                            }
                            onActivated: {
                                var value = model.get(currentIndex).value
                                var size = eventManager.getAppSetting("fuji_live_view_size", "auto")
                                eventManager.setAppSetting("fuji_live_view_quality", value)
                                cameraController.setFujiLiveViewOptions(size, value)
                                root.notify("Đã lưu chất lượng Live View Fuji")
                            }
                        }
                    }
                }
            }

            StudioCard {
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                SectionHeader {
                    title: "Nhận ảnh qua LAN"
                    subtitle: "Luôn bật. Máy khác trong cùng mạng mở địa chỉ này để lấy ảnh gốc."
                    statusText: root.lanUrl() !== "" ? "Sẵn sàng" : "Chưa có IP"
                    statusColor: root.lanUrl() !== "" ? Theme.settingsSuccess : Theme.settingsWarning
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 68
                    radius: 18
                    color: Theme.settingsSurface
                    border.color: Theme.settingsBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 10

                        Text {
                            text: root.lanUrl() !== "" ? root.lanUrl() : "Không tìm thấy IP LAN"
                            color: root.lanUrl() !== "" ? Theme.settingsText : Theme.settingsWarning
                            font.family: "Consolas"
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        SecondaryButton {
                            text: "Sao chép"
                            enabled: root.lanUrl() !== ""
                            Layout.preferredWidth: 112
                            onClicked: {
                                lanClip.text = root.lanUrl()
                                lanClip.selectAll()
                                lanClip.copy()
                                root.notify("Đã sao chép địa chỉ LAN")
                            }
                        }
                    }
                }

                TextEdit { id: lanClip; visible: false }
            }

            ExposureCard {
                // ISO / khẩu / tốc độ cần phiên SDK — Hot Folder chỉnh trên máy.
                visible: !root.isHotFolder
                Layout.fillWidth: true
                Layout.leftMargin: 16
                Layout.rightMargin: 16
            }

            Item { Layout.preferredHeight: 18 }
        }
    }

    component StudioCard: Rectangle {
        id: card
        default property alias content: contentColumn.data
        Layout.fillWidth: true
        implicitHeight: contentColumn.implicitHeight + 28
        color: Theme.settingsCard
        radius: Theme.settingsRadiusLarge
        border.color: Theme.settingsBorder
        border.width: 1

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12
        }
    }

    component SectionHeader: RowLayout {
        id: sectionHeader

        property string title: ""
        property string subtitle: ""
        property string statusText: ""
        property color statusColor: Theme.settingsTextMuted

        Layout.fillWidth: true
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: sectionHeader.title
                color: Theme.settingsText
                font.pixelSize: 17
                font.weight: Font.DemiBold
            }

            Text {
                text: sectionHeader.subtitle
                color: Theme.settingsTextMuted
                font.pixelSize: 12
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: Math.max(92, statusTextItem.implicitWidth + 24)
            Layout.preferredHeight: 34
            radius: 17
            color: Qt.rgba(sectionHeader.statusColor.r, sectionHeader.statusColor.g, sectionHeader.statusColor.b, 0.10)
            border.color: Qt.rgba(sectionHeader.statusColor.r, sectionHeader.statusColor.g, sectionHeader.statusColor.b, 0.32)
            border.width: 1

            Text {
                id: statusTextItem
                anchors.centerIn: parent
                text: sectionHeader.statusText
                color: sectionHeader.statusColor
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }
        }
    }

    component SettingRow: RowLayout {
        id: settingRow
        property string title: ""
        property string detail: ""
        default property alias control: controlSlot.data

        Layout.fillWidth: true
        spacing: 12

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: settingRow.title
                color: Theme.settingsText
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }

            Text {
                text: settingRow.detail
                color: Theme.settingsTextMuted
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        Item {
            id: controlSlot
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: children.length > 0 ? children[0].implicitWidth : 220
            Layout.preferredHeight: children.length > 0 ? children[0].implicitHeight : 46
        }
    }

    component ThinRule: Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.settingsBorder
    }

    component StudioComboBox: ComboBox {
        id: combo
        implicitWidth: 220
        implicitHeight: 46
        textRole: "text"

        background: Rectangle {
            color: Theme.settingsSurface
            radius: 14
            border.color: combo.activeFocus ? Theme.settingsCopper : Theme.settingsBorder
            border.width: combo.activeFocus ? 2 : 1
        }

        contentItem: Text {
            text: combo.displayText
            color: Theme.settingsText
            leftPadding: 14
            rightPadding: 32
            verticalAlignment: Text.AlignVCenter
            font.pixelSize: 14
            elide: Text.ElideRight
        }

        delegate: ItemDelegate {
            id: comboOption
            required property int index

            width: combo.width
            height: 44
            highlighted: combo.highlightedIndex === comboOption.index
            contentItem: Text {
                text: combo.textAt(comboOption.index)
                color: Theme.settingsText
                font.pixelSize: 14
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: comboOption.highlighted ? Theme.settingsCopperSoft : Theme.settingsSurface
            }
        }
    }

    component PrimaryButton: Button {
        id: primaryButton
        implicitHeight: 48

        background: Rectangle {
            radius: 18
            color: !primaryButton.enabled ? Theme.settingsBorder
                 : primaryButton.down ? Theme.settingsCopperDark
                 : primaryButton.hovered ? Qt.darker(Theme.settingsCopper, 1.06)
                 : Theme.settingsCopper
        }

        contentItem: Text {
            text: primaryButton.text
            color: primaryButton.enabled ? "#FFFFFF" : Theme.settingsTextMuted
            font.pixelSize: 14
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    component SecondaryButton: Button {
        id: secondaryButton
        implicitHeight: 44

        background: Rectangle {
            radius: 16
            color: !secondaryButton.enabled ? Theme.settingsSurface
                 : secondaryButton.down ? "#F2DED4"
                 : secondaryButton.hovered ? Theme.settingsCopperSoft
                 : Theme.settingsSurface
            border.color: secondaryButton.enabled ? Theme.settingsBorder : Qt.rgba(Theme.settingsBorder.r, Theme.settingsBorder.g, Theme.settingsBorder.b, 0.45)
            border.width: 1
        }

        contentItem: Text {
            text: secondaryButton.text
            color: secondaryButton.enabled ? Theme.settingsCopperDark : Theme.settingsTextMuted
            font.pixelSize: 13
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
    }

    // Chọn 1 trong vài lựa chọn ngắn (vd "Thư mục ảnh | Fujifilm").
    component StudioSegmented: Rectangle {
        id: segmented

        property var options: []      // [{ text, value }]
        property string value: ""
        signal picked(string choice)

        implicitWidth: 260
        implicitHeight: 46
        radius: 23
        color: Theme.settingsSurface
        border.color: Theme.settingsBorder
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.margins: 4
            spacing: 4

            Repeater {
                model: segmented.options

                delegate: Button {
                    id: segment
                    required property var modelData
                    readonly property bool selected: segmented.value === segment.modelData.value

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    focusPolicy: Qt.StrongFocus
                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: segment.selected
                    onClicked: {
                        if (!segment.selected)
                            segmented.picked(segment.modelData.value)
                    }

                    background: Rectangle {
                        radius: 19
                        color: !segment.enabled ? "transparent"
                             : segment.selected ? Theme.settingsCopper
                             : segment.down ? Theme.settingsCopperSoft
                             : segment.hovered ? Theme.settingsCopperSoft
                             : "transparent"
                        border.color: segment.visualFocus ? Theme.settingsCopperDark : "transparent"
                        border.width: segment.visualFocus ? 2 : 0
                    }

                    contentItem: Text {
                        text: segment.modelData.text
                        color: !segment.enabled ? Theme.settingsTextMuted
                             : segment.selected ? Theme.settingsCard
                             : Theme.settingsCopperDark
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    component StudioSwitch: Switch {
        id: studioSwitch
        implicitWidth: 68
        implicitHeight: 34

        indicator: Rectangle {
            implicitWidth: 56
            implicitHeight: 30
            x: studioSwitch.leftPadding
            y: parent.height / 2 - height / 2
            radius: 15
            color: studioSwitch.checked ? Theme.settingsCopper : Theme.settingsBorder

            Rectangle {
                width: 24
                height: 24
                radius: 12
                x: studioSwitch.checked ? parent.width - width - 3 : 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.settingsCard

                Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
        }

        contentItem: Text {
            text: studioSwitch.checked ? "Bật" : "Tắt"
            color: Theme.settingsText
            font.pixelSize: 12
            font.weight: Font.DemiBold
            verticalAlignment: Text.AlignVCenter
            leftPadding: studioSwitch.indicator.width + studioSwitch.spacing
        }
    }
}
