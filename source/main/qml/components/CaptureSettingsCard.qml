import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    width: 600
    // Chiều cao theo nội dung → ScrollView của tab cuộn được khi nội dung dài
    implicitHeight: mainCol.implicitHeight + 48
    color: "transparent"
    radius: 12
    border.color: "#3a3e45"
    border.width: 1

    property var eventData: null
    property bool _paymentEnabled: eventManager.getAppSetting("payment_enabled", "false") === "true"
    // Chế độ chụp theo mẫu (template). Set tay trong onToggled để đảm bảo UI refresh
    // vì field con của eventData không reactive.
    property bool _templateMode: root.eventData ? (root.eventData.shootingMode === 2) : false
    onEventDataChanged: _templateMode = root.eventData ? (root.eventData.shootingMode === 2) : false

    // Ở chế độ 2/3, "Hướng dẫn Pose" và "Xem lại ảnh" bị ẩn cho tới khi mở khóa
    // bằng toggle "Nâng cao" + nhập mật khẩu (1010).
    property bool _advancedUnlocked: false

    // Chụp bằng dây remote — khi bật, ẩn các nhóm cài đặt chụp khác.
    property bool _remoteOn: eventManager.getAppSetting("remote_shutter_enabled", "false") === "true"
    property bool _followFrameCount: eventManager.getAppSetting("capture_count_follow_frame", "true") === "true"
    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "remote_shutter_enabled") root._remoteOn = (value === "true")
            else if (key === "capture_count_follow_frame") root._followFrameCount = (value === "true")
        }
    }

    // halfSteps: 0=0s, 1=0.5s, 2=1s, 3=1.5s, ...
    function saveInterShotDelay(halfSteps) {
        if (!root.eventData) return
        var ms = halfSteps * 500
        if (eventManager.updateCaptureTimings(
            root.eventData.id,
            firstShotCountdownSpinBox.value,
            firstShotCountdownSpinBox.value,
            ms
        )) {
            root.eventData.shotInterval = ms
        }
    }

    // Component for reusable section styling
    component SectionLabel: Text {
        color: "#000000"
        font.pixelSize: 15
        font.weight: Font.Medium
        // Nhãn dài (vd "Thời gian đếm ngược ảnh đầu tiên") tự xuống dòng trong bề
        // rộng cho phép thay vì tràn đè lên ô +/- bên cạnh.
        wrapMode: Text.WordWrap
        verticalAlignment: Text.AlignVCenter
    }

    component SettingDescription: Text {
        color: "#888888"
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }

    // GroupBox tái sử dụng: khung có viền + tiêu đề, nội dung khai báo trực tiếp
    // bên trong sẽ được đưa vào layout con (innerCol).
    component GroupCard: Rectangle {
        id: groupCard
        default property alias content: innerCol.data
        property string title: ""
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        // Nền card mờ nhạt + viền nhạt → mỗi nhóm là một khối rõ ràng, không bị dính nhau.
        color: "#f6f7f9"
        radius: 12
        border.color: "#d8dce3"
        border.width: 1
        implicitHeight: groupWrap.implicitHeight + 48

        ColumnLayout {
            id: groupWrap
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 18

            Text {
                text: groupCard.title
                color: "#000000"
                font.pixelSize: 17
                font.bold: true
                visible: groupCard.title !== ""
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#d8dce3"
                visible: groupCard.title !== ""
            }

            ColumnLayout {
                id: innerCol
                Layout.fillWidth: true
                spacing: 22
            }
        }
    }

    ColumnLayout {
        id: mainCol
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        // HEADER
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Cài Đặt Chụp"
                color: "#000000"
                font.pixelSize: 24
                font.bold: true
            }
        }

        // Các nhóm cài đặt xếp dọc (1 cột) cho bố cục gọn, dễ đọc.
        GridLayout {
            Layout.fillWidth: true
            columns: 1
            columnSpacing: 28
            rowSpacing: 32

        // ══════════════════════════════════════════════════════════════
        // NHÓM 0 — CHỤP BẰNG REMOTE
        // ══════════════════════════════════════════════════════════════
        GroupCard {
            title: "Chụp bằng remote"
            Layout.columnSpan: parent.columns

            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Chụp bằng dây remote" }
                    SettingDescription {
                        text: "Bật: khách tự bấm nút remote gắn máy ảnh để chụp; live view full màn hình, chỉ hiện thời gian gói + số ảnh đã chụp. Khi bật sẽ ẩn các cài đặt chụp khác."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: remoteSwitch
                    checked: root._remoteOn

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: remoteSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: remoteSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: remoteSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: remoteSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: remoteSwitch.indicator.width + remoteSwitch.spacing
                    }

                    onToggled: {
                        eventManager.setAppSetting("remote_shutter_enabled", checked ? "true" : "false")
                        root._remoteOn = checked
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // NHÓM 1 — CHẾ ĐỘ & SỐ LƯỢNG
        // ══════════════════════════════════════════════════════════════
        GroupCard {
            title: "Chế độ & Số lượng"
            // Ẩn cả nhóm: đã bỏ "Chụp theo mẫu (Template)" và "Số ảnh chụp".
            // App luôn chụp Manual, không giới hạn số ảnh (khách bấm "Xong" để dừng).
            visible: !root._remoteOn

            // CHỤP THEO MẪU (TEMPLATE)
            // Khi bật chọn frame theo nhóm: ẩn toggle chung (mỗi nhóm tự có toggle riêng).
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: false

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Chụp theo mẫu (khung)" }
                    SettingDescription {
                        text: "Live view hiển thị khung hình đã chọn, chia theo từng slot và chụp đúng số ảnh khung yêu cầu."
                        Layout.fillWidth: true
                    }
                }

                // Custom Switch (đồng bộ style với poseGuideSwitch)
                Switch {
                    id: templateModeSwitch
                    checked: root._templateMode

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: templateModeSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: templateModeSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: templateModeSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: templateModeSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: templateModeSwitch.indicator.width + templateModeSwitch.spacing
                    }

                    onToggled: {
                        if (root.eventData) {
                            // Bật → template (mode 2). Tắt → manual (mode 1) với mặc định 6 ảnh.
                            var newMode = checked ? 2 : 1
                            var cnt = checked ? (root.eventData.manualPhotoCount ? root.eventData.manualPhotoCount : 0)
                                              : 6
                            if (eventManager.updateShootingMode(root.eventData.id, newMode, cnt)) {
                                root.eventData.shootingMode = newMode
                                root.eventData.manualPhotoCount = cnt
                                root._templateMode = checked
                            }
                        }
                    }
                }
            }

            // FOLLOW FRAME PHOTO COUNT
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SectionLabel { text: "Theo số ảnh của frame" }
                    SettingDescription {
                        text: "Bật: số ảnh chụp lấy theo số slot của frame đã chọn. Tắt: dùng số ảnh cài đặt bên dưới."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: followFrameCountSwitch
                    checked: root._followFrameCount

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: followFrameCountSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: followFrameCountSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: followFrameCountSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: followFrameCountSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: followFrameCountSwitch.indicator.width + followFrameCountSwitch.spacing
                    }

                    onToggled: {
                        eventManager.setAppSetting("capture_count_follow_frame", checked ? "true" : "false")
                        root._followFrameCount = checked
                    }
                }
            }

            // MANUAL PHOTO COUNT
            RowLayout {
                id: manualPhotoCountRow
                Layout.fillWidth: true
                spacing: 24
                visible: true
                enabled: !root._followFrameCount
                opacity: enabled ? 1.0 : 0.45

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    SectionLabel { text: "Số ảnh chụp" }
                    SettingDescription {
                        text: "Số ảnh chụp trong 1 lượt."
                    }
                }

                SpinBox {
                    from: 1
                    to: 50
                    value: (root.eventData && root.eventData.manualPhotoCount) ? root.eventData.manualPhotoCount : 6
                    editable: manualPhotoCountRow.enabled
                    enabled: manualPhotoCountRow.enabled
                    Layout.preferredWidth: 120

                    onValueModified: {
                        if (!root.eventData) return
                        if (eventManager.updateShootingMode(root.eventData.id, 1, value)) {
                            root.eventData.shootingMode = 1
                            root.eventData.manualPhotoCount = value
                        }
                    }
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // NHÓM 2 — THỜI GIAN ĐẾM NGƯỢC
        // ══════════════════════════════════════════════════════════════
        GroupCard {
            title: "Thời gian đếm ngược"
            visible: !root._remoteOn

            // COUNTDOWN (áp dụng cho ảnh đầu tiên và các ảnh tiếp theo)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian đếm ngược ảnh"
                        Layout.preferredWidth: 200
                    }

                    // Custom Input Field Look
                    SpinBox {
                        id: firstShotCountdownSpinBox
                        from: 0
                        to: 30
                        value: root.eventData ? (root.eventData.firstShotCountdown || 3) : 3
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        // Customizing SpinBox Style
                        contentItem: TextInput {
                            text: firstShotCountdownSpinBox.textFromValue(firstShotCountdownSpinBox.value, firstShotCountdownSpinBox.locale)
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !firstShotCountdownSpinBox.editable
                            validator: firstShotCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: firstShotCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        // Logic Update — áp dụng cùng một giá trị cho ảnh đầu và ảnh sau
                        onValueModified: {
                            if (root.eventData) {
                                if (eventManager.updateCaptureTimings(
                                    root.eventData.id,
                                    value,
                                    value,
                                    shotIntervalSpinBox.value * 500
                                )) {
                                    root.eventData.firstShotCountdown = value
                                    root.eventData.nextShotCountdown = value
                                }
                            }
                        }
                    }

                    Text {
                        text: "seconds"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Đếm ngược trước khi chụp mỗi ảnh (áp dụng cho ảnh đầu tiên và các ảnh tiếp theo)."
                    Layout.leftMargin: 220 // Align with input
                }
            }

            // INTER-SHOT DELAY
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian nghỉ giữa các ảnh"
                        Layout.preferredWidth: 200
                    }

                    RowLayout {
                        Layout.preferredWidth: 200
                        Layout.fillHeight: true
                        spacing: 0

                        Button {
                            text: "−"
                            font.pixelSize: 20
                            Layout.preferredWidth: 45
                            Layout.fillHeight: true
                            background: Rectangle {
                                color: "transparent"
                                radius: 6
                                border.color: "#3a3d45"
                                border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text; color: "#000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: parent.font
                            }
                            onClicked: {
                                var newVal = Math.max(shotIntervalSpinBox.from, shotIntervalSpinBox.value - 1)
                                shotIntervalSpinBox.value = newVal
                                root.saveInterShotDelay(newVal)
                            }
                        }

                        SpinBox {
                            id: shotIntervalSpinBox
                            from: 0
                            to: 60          // 0–30s in 0.5s steps
                            stepSize: 1
                            // value = half-steps: 0→0s, 1→0.5s, 2→1s, 4→2s, ...
                            value: root.eventData ? Math.round(root.eventData.shotInterval / 500) : 4

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            textFromValue: function(v) {
                                return (v / 2.0).toFixed(v % 2 === 0 ? 0 : 1)
                            }

                            background: Rectangle {
                                color: "transparent"
                                border.color: "#3a3d45"
                                border.width: 1
                            }
                            contentItem: Text {
                                text: shotIntervalSpinBox.textFromValue(shotIntervalSpinBox.value)
                                font.pixelSize: 16
                                color: "#000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            up.indicator: Item {}
                            down.indicator: Item {}
                        }

                        Button {
                            text: "+"
                            font.pixelSize: 20
                            Layout.preferredWidth: 45
                            Layout.fillHeight: true
                            background: Rectangle {
                                color: "transparent"
                                radius: 6
                                border.color: "#3a3d45"
                                border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text; color: "#000000"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font: parent.font
                            }
                            onClicked: {
                                var newVal = Math.min(shotIntervalSpinBox.to, shotIntervalSpinBox.value + 1)
                                shotIntervalSpinBox.value = newVal
                                root.saveInterShotDelay(newVal)
                            }
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Khoảng dừng sau khi chụp xong 1 ảnh, trước khi bắt đầu đếm ngược cho ảnh tiếp theo."
                    Layout.leftMargin: 220
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // NHÓM 3 — THỜI GIAN LUỒNG (THANH TOÁN) — chỉ hiện khi bật thanh toán
        // ══════════════════════════════════════════════════════════════
        GroupCard {
            title: "Thời gian luồng"
            visible: !root._remoteOn

            // CAPTURE SESSION COUNTDOWN
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian phiên chụp"
                        Layout.preferredWidth: 200
                    }

                    SpinBox {
                        id: captureSessionCountdownSpinBox
                        from: 30
                        to: 600
                        stepSize: 10
                        value: parseInt(eventManager.getAppSetting("capture_session_countdown", "120")) || 120
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        contentItem: TextInput {
                            text: captureSessionCountdownSpinBox.value
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !captureSessionCountdownSpinBox.editable
                            validator: captureSessionCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: captureSessionCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        onValueModified: {
                            eventManager.setAppSetting("capture_session_countdown", value.toString())
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Thời gian tối đa cho 1 phiên chụp. Hết giờ sẽ tự động chuyển sang bước tiếp theo."
                    Layout.leftMargin: 220
                }
            }

            // LAYOUT SELECTION COUNTDOWN
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian chọn khung hình"
                        Layout.preferredWidth: 200
                    }

                    SpinBox {
                        id: layoutCountdownSpinBox
                        from: 10
                        to: 300
                        stepSize: 5
                        value: parseInt(eventManager.getAppSetting("layout_selection_countdown", "60")) || 60
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        contentItem: TextInput {
                            text: layoutCountdownSpinBox.value
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !layoutCountdownSpinBox.editable
                            validator: layoutCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: layoutCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        onValueModified: {
                            eventManager.setAppSetting("layout_selection_countdown", value.toString())
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Thời gian đếm ngược để chọn khung hình. Hết giờ sẽ tự động chọn khung hình đầu tiên."
                    Layout.leftMargin: 220
                }
            }

            // PHOTO COMPOSITION (TRANG GHÉP ẢNH) COUNTDOWN
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian trang ghép ảnh"
                        Layout.preferredWidth: 200
                    }

                    SpinBox {
                        id: compositionCountdownSpinBox
                        from: 10
                        to: 600
                        stepSize: 10
                        value: parseInt(eventManager.getAppSetting("photo_composition_countdown", "240")) || 240
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        contentItem: TextInput {
                            text: compositionCountdownSpinBox.value
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !compositionCountdownSpinBox.editable
                            validator: compositionCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: compositionCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        onValueModified: {
                            eventManager.setAppSetting("photo_composition_countdown", value.toString())
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Thời gian chọn & ghép ảnh vào khung. Hết giờ sẽ tự động điền ảnh còn thiếu và chuyển sang bước tiếp theo."
                    Layout.leftMargin: 220
                }
            }

            // FILTER SCREEN (TRANG CHỌN FILTER) COUNTDOWN
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian trang chọn filter"
                        Layout.preferredWidth: 200
                    }

                    SpinBox {
                        id: filterCountdownSpinBox
                        from: 10
                        to: 600
                        stepSize: 10
                        value: parseInt(eventManager.getAppSetting("filter_screen_countdown", "240")) || 240
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        contentItem: TextInput {
                            text: filterCountdownSpinBox.value
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !filterCountdownSpinBox.editable
                            validator: filterCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: filterCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        onValueModified: {
                            eventManager.setAppSetting("filter_screen_countdown", value.toString())
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Thời gian chọn bộ lọc màu. Hết giờ sẽ tự động in với bộ lọc đang chọn và chuyển sang trang chờ in."
                    Layout.leftMargin: 220
                }
            }

            // RESULT SCREEN COUNTDOWN — ẩn theo yêu cầu (không cần thiết)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                visible: false

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian trang kết quả"
                        Layout.preferredWidth: 200
                    }

                    SpinBox {
                        id: resultCountdownSpinBox
                        from: 10
                        to: 300
                        stepSize: 5
                        value: parseInt(eventManager.getAppSetting("result_screen_countdown", "30")) || 30
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        contentItem: TextInput {
                            text: resultCountdownSpinBox.value
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !resultCountdownSpinBox.editable
                            validator: resultCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: resultCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        onValueModified: {
                            eventManager.setAppSetting("result_screen_countdown", value.toString())
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Thời gian đếm ngược tại trang kết quả. Hết giờ sẽ tự động bắt đầu lượt chụp mới."
                    Layout.leftMargin: 220
                }
            }

            // WAITING RESULTS (TRANG CHỜ IN ẢNH) COUNTDOWN
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 45
                    spacing: 20

                    SectionLabel {
                        text: "Thời gian trang chờ in ảnh"
                        Layout.preferredWidth: 200
                    }

                    SpinBox {
                        id: waitingCountdownSpinBox
                        from: 10
                        to: 300
                        stepSize: 5
                        value: parseInt(eventManager.getAppSetting("waiting_results_countdown", "30")) || 30
                        editable: true

                        Layout.preferredWidth: 200
                        Layout.fillHeight: true

                        contentItem: TextInput {
                            text: waitingCountdownSpinBox.value
                            font.pixelSize: 16
                            color: "#000000"
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !waitingCountdownSpinBox.editable
                            validator: waitingCountdownSpinBox.validator
                            inputMethodHints: Qt.ImhFormattedNumbersOnly
                        }

                        background: Rectangle {
                            color: "transparent"
                            border.color: waitingCountdownSpinBox.activeFocus ? "#1e7eea" : "#3a3d45"
                            border.width: 1
                            radius: 6
                        }

                        onValueModified: {
                            eventManager.setAppSetting("waiting_results_countdown", value.toString())
                        }
                    }

                    Text {
                        text: "giây"
                        color: "#888"
                        font.pixelSize: 14
                    }
                }

                SettingDescription {
                    text: "Thời gian đếm ngược tại trang chờ in ảnh (ảnh in + video + QR). Hết giờ sẽ tự động bắt đầu lượt chụp mới."
                    Layout.leftMargin: 220
                }
            }
        }

        // ══════════════════════════════════════════════════════════════
        // NHÓM 4 — TRẢI NGHIỆM CHỤP
        // ══════════════════════════════════════════════════════════════
        GroupCard {
            title: "Trải nghiệm chụp"
            visible: !root._remoteOn

            // NÂNG CAO — chỉ ở chế độ 2/3. Bật → nhập mật khẩu để hiện
            // "Hướng dẫn Pose" và "Xem lại ảnh".
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: root._paymentEnabled

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Nâng cao" }
                    SettingDescription {
                        text: "Mở khóa các tùy chọn nâng cao (Hướng dẫn Pose, Xem lại ảnh). Yêu cầu nhập mật khẩu."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: advancedSwitch
                    // Trạng thái điều khiển thủ công (qua dialog), không bind trực tiếp
                    // để tránh xung đột khi gán checked trong onToggled.
                    checked: false

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: advancedSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: advancedSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: advancedSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: advancedSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: advancedSwitch.indicator.width + advancedSwitch.spacing
                    }

                    onToggled: {
                        if (checked) {
                            // Chưa mở khóa → yêu cầu mật khẩu. Giữ trạng thái off
                            // cho tới khi nhập đúng (dialog sẽ bật lại nếu đúng).
                            advancedSwitch.checked = false
                            advancedPassDialog.open()
                        } else {
                            root._advancedUnlocked = false
                        }
                    }
                }
            }

            // POSE GUIDE — ẩn khi bật chụp theo mẫu (frame overlay đã thay thế);
            // ở chế độ 2/3 chỉ hiện sau khi mở khóa "Nâng cao".
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: !root._templateMode && (!root._paymentEnabled || root._advancedUnlocked)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Hướng dẫn Pose" }
                    SettingDescription {
                        text: "Hiển thị overlay vùng tối trên live view để hướng dẫn căn chỉnh dáng theo layout."
                        Layout.fillWidth: true
                    }
                }

                // Custom Switch
                Switch {
                    id: poseGuideSwitch
                    checked: root.eventData ? (root.eventData.poseGuide || false) : false

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: poseGuideSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: poseGuideSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: poseGuideSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: poseGuideSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: poseGuideSwitch.indicator.width + poseGuideSwitch.spacing
                    }

                    onToggled: {
                        if (root.eventData) {
                            eventManager.updateEventBool(root.eventData.id, "poseGuide", checked)
                            root.eventData.poseGuide = checked
                        }
                    }
                }
            }

            // XEM LẠI ẢNH — chỉ hiện ở chế độ 2/3 sau khi mở khóa "Nâng cao"
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: root._paymentEnabled && root._advancedUnlocked

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Xem lại ảnh" }
                    SettingDescription {
                        text: "Bật: trang ghép ảnh có panel xem trước và dải ảnh ngang phía dưới.\nTắt: chọn ảnh trực tiếp từ lưới 2 hàng bên trái (không có xem trước)."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: photoReviewSwitch
                    checked: eventManager.getAppSetting("photo_review_enabled", "false") === "true"

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: photoReviewSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: photoReviewSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: photoReviewSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: photoReviewSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: photoReviewSwitch.indicator.width + photoReviewSwitch.spacing
                    }

                    onToggled: {
                        eventManager.setAppSetting("photo_review_enabled", checked ? "true" : "false")
                    }
                }
            }

            // LẬT ẢNH SAU KHI CHỤP (gộp từ tab vào nhóm trải nghiệm)
            RowLayout {
                Layout.fillWidth: true
                spacing: 24

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Lật ảnh sau khi chụp" }
                    SettingDescription {
                        text: "Lật ngang ảnh thành phẩm để khớp với hình ảnh khách nhìn trên Live View."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: flipPhotoSwitch
                    checked: eventManager.getAppSetting("flip_photo_enabled", "false") === "true"

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: flipPhotoSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: flipPhotoSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: flipPhotoSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: flipPhotoSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: flipPhotoSwitch.indicator.width + flipPhotoSwitch.spacing
                    }

                    onToggled: {
                        eventManager.setAppSetting("flip_photo_enabled", checked ? "true" : "false")
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Chụp ảnh test" }
                    SettingDescription {
                        text: "Bật: hết thời gian đếm ngược sẽ tạo ảnh ảo để kiểm tra toàn bộ luồng mà không cần kết nối máy ảnh."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: mockCaptureSwitch
                    checked: eventManager.getAppSetting("mock_capture_enabled", "false") === "true"

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: mockCaptureSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: mockCaptureSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: mockCaptureSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: mockCaptureSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: mockCaptureSwitch.indicator.width + mockCaptureSwitch.spacing
                    }

                    onToggled: {
                        eventManager.setAppSetting("mock_capture_enabled", checked ? "true" : "false")
                    }
                }
            }

            // KHONG CHUP LAI - setting thuc te duoc CaptureScreen doc qua key no_retake_enabled.
            RowLayout {
                Layout.fillWidth: true
                spacing: 24
                visible: true

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    SectionLabel { text: "Không chụp lại" }
                    SettingDescription {
                        text: "Bật: trang chụp hiển thị live view ở giữa khung trắng, bên trái là số ảnh, bên phải là đếm ngược. Không xem lại/chụp lại; chụp đủ ảnh sẽ tự chuyển bước tiếp theo."
                        Layout.fillWidth: true
                    }
                }

                Switch {
                    id: noRetakeSwitch
                    checked: eventManager.getAppSetting("no_retake_enabled", "false") === "true"

                    indicator: Rectangle {
                        implicitWidth: 48; implicitHeight: 26
                        x: noRetakeSwitch.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 13
                        color: noRetakeSwitch.checked ? "#1e7eea" : "#3a3d45"
                        border.color: color

                        Rectangle {
                            x: noRetakeSwitch.checked ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    contentItem: Text {
                        text: noRetakeSwitch.checked ? "On" : "Off"
                        color: "#000000"; font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: noRetakeSwitch.indicator.width + noRetakeSwitch.spacing
                    }

                    onToggled: {
                        eventManager.setAppSetting("no_retake_enabled", checked ? "true" : "false")
                    }
                }
            }
        }

        }
        // /Lưới các nhóm

        Item { Layout.fillHeight: true } // Spacer
    }

    // ── Dialog nhập mật khẩu mở khóa "Nâng cao" ──────────────────────────────
    Dialog {
        id: advancedPassDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        modal: true
        width: 360
        padding: 24
        closePolicy: Popup.CloseOnEscape

        background: Rectangle { color: "#ffffff"; radius: 12; border.color: "#d8dce3"; border.width: 1 }
        header: Item { height: 0 }
        footer: Item { height: 0 }

        // Mở khóa thành công thì onClosed không revert; ngược lại tắt lại toggle.
        onOpened: { advPassField.text = ""; advPassError.visible = false; advPassField.forceActiveFocus() }
        onClosed: { if (!root._advancedUnlocked) advancedSwitch.checked = false }

        function _submit() {
            if (advPassField.text === "1010") {
                root._advancedUnlocked = true
                advancedSwitch.checked = true
                advancedPassDialog.close()
            } else {
                advPassError.visible = true
                advPassField.text = ""
                advPassField.forceActiveFocus()
            }
        }

        contentItem: ColumnLayout {
            spacing: 16

            Text {
                text: "Nhập mật khẩu nâng cao"
                color: "#000000"; font.pixelSize: 16; font.bold: true
                Layout.fillWidth: true
            }

            TextField {
                id: advPassField
                Layout.fillWidth: true
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhDigitsOnly
                placeholderText: "Mật khẩu"
                font.pixelSize: 16
                color: "#000000"
                onAccepted: advancedPassDialog._submit()
            }

            Text {
                id: advPassError
                text: "Mật khẩu không đúng"
                color: "#d33a3a"; font.pixelSize: 12
                visible: false
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Item { Layout.fillWidth: true }
                Button {
                    text: "Hủy"
                    onClicked: advancedPassDialog.close()
                }
                Button {
                    text: "Mở khóa"
                    onClicked: advancedPassDialog._submit()
                }
            }
        }
    }
}
