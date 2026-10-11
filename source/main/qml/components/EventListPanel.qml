import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "../theme"

Item {
    id: root

    property string backgroundImagePath: ""
    property color  fallbackBgColor:     Window.window ? Window.window.appBgColor : "#000000"
    readonly property color surfaceColor: Window.window ? Window.window.appSurfaceColor : "#121212"
    readonly property color fieldColor: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    readonly property color borderColor: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    readonly property color textColor: "#000000"
    readonly property color mutedTextColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.65)

    signal eventSelected(int eventId)
    signal settingsClicked(int eventId)
    signal launchEventClicked(int eventId)
    signal logoutRequested()
    signal quitRequested()

    property int selectedEventId: -1
    property var selectedEventData: ({})
    property bool multiEventEnabled: true
    property bool hasAnyEvent: false
    readonly property bool allowNewEvent: true

    function isSystemStudioEventData(eventData) {
        var name = ((eventData && eventData.name) ? eventData.name : "").trim().toLowerCase()
        return name === "studio2" || name === "studio3"
    }

    function systemStudioBadge(eventData) {
        var name = ((eventData && eventData.name) ? eventData.name : "").trim().toLowerCase()
        if (name === "studio2") return "Chế độ 2"
        if (name === "studio3") return "Chế độ 3"
        return ""
    }

    function selectedIsSystemStudioEvent() {
        return root.isSystemStudioEventData(root.selectedEventData)
    }

    function resolveMultiEventEnabled() {
        return eventManager.getAppSetting("app_operation_mode", "mode1") === "mode1"
                || eventManager.getAppSetting("multi_event_enabled", "true") === "true"
    }

    function refreshEventAvailability() {
        eventManager.eventModel.refresh()
        root.hasAnyEvent = eventManager.eventModel.getEventId(0) > 0
    }

    Component.onCompleted: {
        root.multiEventEnabled = root.resolveMultiEventEnabled()
        root.refreshEventAvailability()
    }

    Connections {
        target: eventManager

        function onAppSettingChanged(key, value) {
            if (key === "multi_event_enabled" || key === "app_operation_mode")
                root.multiEventEnabled = root.resolveMultiEventEnabled()
        }

        function onEventCreated(eventId) {
            root.hasAnyEvent = true
        }

        function onEventDeleted(eventId) {
            root.refreshEventAvailability()
        }
    }

    // Background
    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        color: root.fallbackBgColor
        z: 0
    }

    BackgroundMedia {
        id: bgImage
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
        z: 1
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        z: 2

        TopBar {
            id: topBar
            Layout.fillWidth: true
            Layout.preferredHeight: 80
            hasSelection: root.selectedEventId !== -1

            onSettingsClicked: root.settingsClicked(root.selectedEventId)
            onLogoutClicked: root.logoutRequested()
            onQuitClicked: root.quitRequested()
            onLaunchClicked: {
                if (root.selectedEventId !== -1) root.launchEventClicked(root.selectedEventId)
            }
            onRenameClicked: {
                if (root.selectedEventId !== -1 && !root.selectedIsSystemStudioEvent())
                    renameDialog.open()
            }
            onDeleteClicked: {
                if (root.selectedEventId !== -1 && !root.selectedIsSystemStudioEvent())
                    deleteConfirmDialog.open()
            }
            onDuplicateClicked: {
                if (root.selectedEventId !== -1)
                    eventManager.duplicateEvent(root.selectedEventId)
            }
        }

        // (Đã bỏ thanh tìm/lọc sự kiện theo yêu cầu.)

        // Content row: grid + side panel
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Event grid
            ScrollView {
                id: eventScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: availableWidth
                background: Item {}

                Item {
                    width: eventScroll.availableWidth
                    height: eventGrid.implicitHeight + 40

                    Grid {
                        id: eventGrid
                        x: 20
                        y: 20
                        width: Math.max(284, parent.width - 40)
                        columns: Math.max(1, Math.floor((width + 20) / 304))
                        columnSpacing: 20
                        rowSpacing: 20

                        Rectangle {
                            visible: root.allowNewEvent
                            width: 284
                            height: 284
                            radius: 14
                            color: "transparent"
                            border.color: addEventMouse.containsMouse ? "#4FA4F2" : Theme.border
                            border.width: addEventMouse.containsMouse ? 2 : 1

                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            Column {
                                anchors.centerIn: parent
                                spacing: 14

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 78
                                    height: 78
                                    radius: 39
                                    color: addEventMouse.containsMouse ? "#4FA4F2" : "transparent"
                                    border.color: "#4FA4F2"
                                    border.width: 2

                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "+"
                                        color: root.textColor
                                        font.pixelSize: 56
                                        font.weight: Font.Light
                                    }
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "Tạo sự kiện mới"
                                    color: root.textColor
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                }
                            }

                            MouseArea {
                                id: addEventMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: createEventDialog.open()
                            }
                        }

                        Repeater {
                            model: eventManager.eventModel

                            delegate: EventCard {
                                required property var model

                                width: 284
                                height: 284
                                eventName: model.name
                                updatedTime: "7 ngày trước"
                                thumbnailPath: model.thumbnailPath || ""
                                selectedLayout: model.selectedLayout || ""
                                badgeText: root.systemStudioBadge(model)
                                selected: model.eventId === root.selectedEventId

                                onClicked: {
                                    root.selectedEventId = model.eventId
                                    root.selectedEventData = eventManager.getEventDetails(model.eventId)
                                    root.eventSelected(model.eventId)
                                    // Click sự kiện → mở dialog thông tin + hành động.
                                    eventDetailDialog.eventId = model.eventId
                                    eventDetailDialog.eventData = root.selectedEventData
                                    eventDetailDialog.systemEvent = root.isSystemStudioEventData(root.selectedEventData)
                                    eventDetailDialog.badgeText = root.systemStudioBadge(root.selectedEventData)
                                    eventDetailDialog.open()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: createEventDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width: 560
        height: 320
        padding: 0
        Overlay.modal: Rectangle { color: "transparent" }

        property string errorMessage: ""

        onAboutToShow: {
            errorMessage = ""
            createEventNameField.text = ""
            Qt.callLater(function() { createEventNameField.forceActiveFocus() })
        }

        background: Rectangle {
            color: "transparent"
            radius: 14
            border.color: root.borderColor
            border.width: 1
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14

            Text {
                text: "Tạo sự kiện mới"
                color: root.textColor
                font.pixelSize: 30
                font.weight: Font.Bold
            }

            Text {
                text: "Nhập tên sự kiện để bắt đầu cấu hình."
                color: root.mutedTextColor
                font.pixelSize: 19
            }

            TextField {
                id: createEventNameField
                Layout.fillWidth: true
                Layout.preferredHeight: 56
                placeholderText: "Tên sự kiện"
                color: root.textColor
                placeholderTextColor: root.mutedTextColor
                font.pixelSize: 22
                leftPadding: 14

                background: Rectangle {
                    color: "transparent"
                    radius: 8
                    border.color: parent.activeFocus ? "#4FA4F2" : root.borderColor
                    border.width: parent.activeFocus ? 2 : 1
                }

                Keys.onReturnPressed: root.createEventFromDialog()
                Keys.onEnterPressed: root.createEventFromDialog()
            }

            Text {
                visible: createEventDialog.errorMessage !== ""
                text: createEventDialog.errorMessage
                color: "#ef8070"
                font.pixelSize: 16
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                Button {
                    text: "Huỷ"
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 46
                    font.pixelSize: 18
                    onClicked: createEventDialog.close()
                }

                Button {
                    text: "Tạo sự kiện"
                    enabled: createEventNameField.text.trim().length > 0
                    Layout.preferredWidth: 170
                    Layout.preferredHeight: 46

                    background: Rectangle {
                        color: parent.enabled
                               ? (parent.hovered ? "#5BB8FF" : "#4FA4F2")
                               : Theme.field
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "#000000" : root.mutedTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 18
                        font.weight: Font.Bold
                    }

                    onClicked: root.createEventFromDialog()
                }
            }
        }
    }

    // Dialog thông tin + hành động sự kiện (mở khi click vào card).
    EventDetailDialog {
        id: eventDetailDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay

        onLaunchClicked: function(id) { root.launchEventClicked(id) }
        onSettingsClicked: function(id) { root.settingsClicked(id) }
        onRenameRequested: function(id) {
            if (!root.selectedIsSystemStudioEvent())
                renameDialog.open()
        }
        onDeleteRequested: function(id) {
            if (!root.selectedIsSystemStudioEvent())
                deleteConfirmDialog.open()
        }
        onDuplicateRequested: function(id) {
            if (id > 0)
                eventManager.duplicateEvent(id)
        }
    }

    function createEventFromDialog() {
        var name = createEventNameField.text.trim()
        if (name.length === 0)
            return

        if (eventManager.createEvent(name, "", new Date().toISOString())) {
            // Event thường mới tạo luôn quay về mode1 để không bị "ăn theo" mode2/3
            // đang dùng trước đó của app.
            eventManager.setAppSetting("app_operation_mode", "mode1")
            eventManager.setAppSetting("payment_enabled", "false")
            eventManager.setAppSetting("multi_event_enabled", "true")
            root.multiEventEnabled = true
            createEventDialog.close()
        } else {
            createEventDialog.errorMessage = "Không thể tạo sự kiện. Vui lòng thử lại."
        }
    }

    // Rename Dialog
    Dialog {
        id: renameDialog
        modal: true
        anchors.centerIn: parent
        width: 420
        height: 200

        onAboutToShow: {
            var d = eventManager.getEventDetails(root.selectedEventId)
            renameField.text = d.name || ""
            renameField.selectAll()
            renameField.forceActiveFocus()
        }

        background: Rectangle {
            color: root.surfaceColor
            radius: 12
            border.color: root.borderColor
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Text {
                text: "Tên Sự Kiện"
                color: root.mutedTextColor
                font.pixelSize: 13
                font.weight: Font.Medium
            }

            TextField {
                id: renameField
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                font.pixelSize: 14
                color: root.textColor
                placeholderText: "Nhập Tên Sự Kiện..."
                placeholderTextColor: root.mutedTextColor

                background: Rectangle {
                    color: root.fieldColor
                    radius: 6
                    border.color: parent.activeFocus ? "#4FA4F2" : root.borderColor
                    border.width: parent.activeFocus ? 2 : 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }
                leftPadding: 10

                Keys.onReturnPressed: {
                    if (root.selectedIsSystemStudioEvent())
                        return
                    if (renameField.text.length > 0) {
                        eventManager.updateEventName(root.selectedEventId, renameField.text)
                        renameDialog.close()
                    }
                }
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Huỷ"
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: 80

                    background: Rectangle {
                        color: parent.hovered ? root.fieldColor : "transparent"
                        radius: 6
                        border.color: root.borderColor
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.mutedTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                    }
                    onClicked: renameDialog.close()
                }

                Button {
                    text: "Lưu"
                    enabled: renameField.text.length > 0
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: 80

                    background: Rectangle {
                        color: parent.enabled ? (parent.hovered ? "#5BB8FF" : "#4FA4F2") : Theme.field
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: parent.enabled ? "#ffffff" : Theme.textMuted
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    onClicked: {
                        if (root.selectedIsSystemStudioEvent())
                            return
                        if (renameField.text.length > 0) {
                            eventManager.updateEventName(root.selectedEventId, renameField.text)
                            renameDialog.close()
                        }
                    }
                }
            }
        }
    }

    // Delete Confirmation Dialog
    Dialog {
        id: deleteConfirmDialog
        modal: true
        anchors.centerIn: parent
        width: 440
        height: 190

        property string eventName: ""

        onAboutToShow: {
            var d = eventManager.getEventDetails(root.selectedEventId)
            eventName = d.name || "Sự kiện này"
        }

        background: Rectangle {
            color: root.surfaceColor
            radius: 12
            border.color: "#3A1515"
            border.width: 1
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            RowLayout {
                spacing: 12
                Text { text: "⚠️"; font.pixelSize: 28 }
                Text {
                    text: "Xoá \"" + deleteConfirmDialog.eventName + "\"?"
                    color: root.textColor
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            Text {
                text: "Hành động này không thể hoàn tác."
                color: root.mutedTextColor
                font.pixelSize: 12
                Layout.fillWidth: true
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Button {
                    text: "Huỷ"
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: 80

                    background: Rectangle {
                        color: parent.hovered ? root.fieldColor : "transparent"
                        radius: 6
                        border.color: root.borderColor
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.mutedTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                    }
                    onClicked: deleteConfirmDialog.close()
                }

                Button {
                    text: "Xoá"
                    Layout.preferredHeight: 38
                    Layout.preferredWidth: 80

                    background: Rectangle {
                        color: parent.hovered ? "#C04040" : "#A03030"
                        radius: 6
                        Behavior on color { ColorAnimation { duration: 120 } }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "#ffffff"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 13
                        font.weight: Font.Medium
                    }
                    onClicked: {
                        if (root.selectedIsSystemStudioEvent()) {
                            deleteConfirmDialog.close()
                            return
                        }
                        eventManager.deleteEvent(root.selectedEventId)
                        root.selectedEventId = -1
                        root.selectedEventData = {}
                        deleteConfirmDialog.close()
                    }
                }
            }
        }
    }
}
