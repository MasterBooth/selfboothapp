import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Bảng chi tiết một máy: thông tin · mã OTP · giấy phép · ký (cấp / gia hạn) · thao tác · lịch sử.
ScrollView {
    id: d
    required property var app
    property var machine: null

    readonly property bool isLicensed: !!machine && machine.state === "licensed"
    readonly property bool isRevoked: !!machine && machine.state === "revoked"
    // OTP: ưu tiên mã vừa sinh trong phiên (có ngay), không thì mã đang mở trên máy chủ.
    readonly property var otp: {
        if (!machine) return null
        if (app.lastOtp && app.lastOtp.hwid === machine.hwid)
            return { code: app.lastOtp.otp, expires: app.lastOtp.expires, attempts: 0 }
        if (machine.otp) return { code: machine.otp, expires: machine.otp_expires_at, attempts: machine.otp_attempts || 0 }
        return null
    }

    // ── Trạng thái biểu mẫu ký ──────────────────────────────────────────────
    property string _formHwid: ""
    property string tier: "premium"
    property int months: 12
    property int grace: 30
    property bool withOtp: false
    readonly property var tiers: ["premium", "studio", "event", "event_studio", "studio_selfbooth", "trial"]
    readonly property var monthChoices: [1, 3, 6, 12, 24, 0]
    readonly property var graceChoices: [0, 7, 15, 30, 60]

    function resetForm() {
        _formHwid = machine ? machine.hwid : ""
        tier = machine && machine.device_tier ? machine.device_tier : "premium"
        months = 12
        grace = 30
        withOtp = false
        serialField.text = app.newSerial()
    }
    onMachineChanged: if (machine && machine.hwid !== _formHwid) resetForm()

    readonly property string previewNotAfter: isLicensed
        ? app.renewedNotAfter(machine ? machine.not_after : "", months)
        : app.renewedNotAfter("", months)

    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        width: d.availableWidth
        spacing: 0

        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: Tk.sXl
            Layout.maximumWidth: 760
            spacing: Tk.sLg

            // ── Đầu ─────────────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Tk.sXs
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tk.sSm
                    Text {
                        Layout.fillWidth: true
                        text: d.machine ? (d.machine.studio_name || "Chưa gắn studio") : ""
                        color: Tk.ink
                        font.family: Tk.display
                        font.pixelSize: Tk.text2xl
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    StatusPill { machineState: d.machine ? d.machine.state : "pending" }
                }
                Text {
                    Layout.fillWidth: true
                    text: d.machine ? [d.machine.owner_email || "Chưa có email chủ",
                                       d.machine.device_name || "",
                                       d.machine.app_version ? "v" + d.machine.app_version : ""]
                                      .filter(function(x) { return x !== "" }).join("  ·  ") : ""
                    color: Tk.muted
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                    elide: Text.ElideRight
                }
            }

            // ── Thông tin máy ───────────────────────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Tk.sLg
                rowSpacing: Tk.sSm

                Fact {
                    label: "Mã máy"
                    value: d.machine ? d.machine.hwid : ""
                    mono: true
                    copyable: true
                }
                Fact { label: "Lần cuối kết nối"; value: d.machine ? Tk.dateTime(d.machine.last_seen_at) : "" }
                Fact { label: "Gửi yêu cầu"; value: d.machine ? Tk.dateTime(d.machine.request_updated_at) : "" }
                Fact {
                    label: "Hạn giấy phép"
                    value: !d.machine || !d.machine.serial ? "Chưa cấp"
                         : d.isRevoked ? "Đã thu hồi " + Tk.dateTime(d.machine.revoked_at)
                         : !d.machine.not_after ? "Vĩnh viễn"
                         : Tk.date(d.machine.not_after) + " (" + Tk.relative(d.machine.not_after) + ")"
                    tone: d.isLicensed && d.machine.not_after && Tk.daysLeft(d.machine.not_after) <= 14 ? "warn" : ""
                }
            }

            // ── Mã OTP ──────────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: d.otp !== null
                implicitHeight: otpCol.implicitHeight + Tk.sLg * 2
                radius: Tk.radiusLg
                color: Tk.ink

                RowLayout {
                    id: otpCol
                    anchors.fill: parent
                    anchors.margins: Tk.sLg
                    spacing: Tk.sLg
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Tk.s2xs
                        Text {
                            text: "Mã kích hoạt — đọc cho khách nhập trên máy"
                            color: Tk.sideMuted
                            font.family: Tk.body
                            font.pixelSize: Tk.textXs
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: d.otp ? d.otp.code.split("").join(" ") : ""
                            color: Tk.paper
                            font.family: Tk.mono
                            font.pixelSize: Tk.textOtp
                            font.weight: Font.Medium
                        }
                        Text {
                            Layout.fillWidth: true
                            text: d.otp ? "Dùng 1 lần · hết hạn " + Tk.dateTime(d.otp.expires) + " (" + Tk.relative(d.otp.expires) + ")"
                                          + " · đã nhập sai " + d.otp.attempts + "/5" : ""
                            color: Tk.sideInk
                            font.family: Tk.body
                            font.pixelSize: Tk.textXs
                            wrapMode: Text.WordWrap
                        }
                    }
                    Btn {
                        text: "Sao chép"
                        variant: "secondary"
                        onDark: true
                        onClicked: d.app.copy(d.otp.code, "Đã chép mã " + d.otp.code)
                    }
                }
            }

            // ── Giấy phép hiện tại ──────────────────────────────────────────
            Panel {
                visible: !!d.machine && !!d.machine.serial
                title: d.isRevoked ? "Giấy phép đã thu hồi" : "Giấy phép hiện tại"
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Tk.sLg
                    rowSpacing: Tk.sSm
                    Fact { label: "Số hiệu"; value: d.machine ? (d.machine.serial || "") : ""; mono: true; copyable: true }
                    Fact { label: "Hạng"; value: d.machine ? Tk.tierLabel(d.machine.device_tier) : "" }
                    Fact { label: "Ký lúc"; value: d.machine ? Tk.dateTime(d.machine.issued_at) : "" }
                    Fact { label: "Người duyệt"; value: d.machine ? (d.machine.approver || "—") : "" }
                }
            }

            // ── Ký giấy phép (cấp mới / gia hạn) ────────────────────────────
            Panel {
                title: d.isLicensed ? "Gia hạn hoặc đổi hạng" : d.isRevoked ? "Cấp lại giấy phép" : "Cấp giấy phép"
                subtitle: d.isLicensed
                          ? "Máy tự nhận bản mới khi có mạng. Hạ hạng cũng được — bản ký sau luôn thắng."
                          : "Ký tại máy này rồi sinh mã OTP 4 số cho khách nhập trên app booth."

                ChoiceRow {
                    label: "Hạng thiết bị"
                    Repeater {
                        model: d.tiers
                        Chip {
                            required property string modelData
                            text: Tk.tierLabel(modelData)
                            selected: d.tier === modelData
                            onClicked: d.tier = modelData
                        }
                    }
                }

                ChoiceRow {
                    label: d.isLicensed ? "Cộng thêm" : "Thời hạn"
                    Repeater {
                        model: d.monthChoices
                        Chip {
                            required property int modelData
                            text: modelData === 0 ? "Vĩnh viễn" : modelData + " tháng"
                            selected: d.months === modelData
                            onClicked: d.months = modelData
                        }
                    }
                }

                ChoiceRow {
                    label: "Ân hạn khi hết hạn (máy offline vẫn chạy thêm)"
                    Repeater {
                        model: d.graceChoices
                        Chip {
                            required property int modelData
                            text: modelData === 0 ? "Không" : modelData + " ngày"
                            selected: d.grace === modelData
                            onClicked: d.grace = modelData
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tk.sMd
                    Field {
                        id: serialField
                        Layout.fillWidth: true
                        label: "Số hiệu giấy phép"
                        mono: true
                    }
                    Field {
                        id: approverField
                        Layout.fillWidth: true
                        label: "Người duyệt"
                        placeholderText: "Tên bạn"
                        text: d.app.approver
                        onTextEdited: d.app.approver = approverField.text
                    }
                }

                // Hạn sẽ ký — đọc trước khi bấm.
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: summary.implicitHeight + Tk.sSm * 2
                    radius: Tk.radiusSm
                    color: d.months === 0 ? Tk.errorSoft : Tk.paper2
                    Text {
                        id: summary
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: Tk.sMd }
                        wrapMode: Text.WordWrap
                        color: d.months === 0 ? Tk.error : Tk.muted
                        font.family: Tk.body
                        font.pixelSize: Tk.textSm
                        text: d.months === 0
                              ? "Giấy phép vĩnh viễn: máy không bao giờ hết hạn, chỉ chặn được bằng thu hồi."
                              : "Hạng " + Tk.tierLabel(d.tier) + " · hạn đến " + Tk.date(d.previewNotAfter)
                                + (d.isLicensed ? " (cộng dồn từ hạn hiện tại)" : "")
                                + " · ân hạn " + d.grace + " ngày"
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Tk.sMd
                    Chip {
                        visible: d.isLicensed
                        text: d.withOtp ? "✓ Kèm mã OTP mới" : "Kèm mã OTP mới"
                        selected: d.withOtp
                        onClicked: d.withOtp = !d.withOtp
                    }
                    Item { Layout.fillWidth: true }
                    Btn {
                        text: d.isLicensed ? "Ký và gia hạn" : "Ký và sinh mã OTP"
                        loading: d.app.busy
                        enabled: serialField.text.trim() !== ""
                        onClicked: {
                            if (d.isLicensed)
                                d.app.renew(d.machine, d.tier, d.months, d.grace, serialField.text, d.withOtp)
                            else
                                d.app.issueNew(d.machine, d.tier, d.months, d.grace, serialField.text)
                            serialField.text = d.app.newSerial()
                        }
                    }
                }
            }

            // ── Thao tác khác ───────────────────────────────────────────────
            Panel {
                visible: d.isLicensed || d.isRevoked
                title: "Thao tác khác"
                Flow {
                    Layout.fillWidth: true
                    spacing: Tk.sSm
                    Btn {
                        visible: d.isLicensed
                        variant: "secondary"
                        text: "Cấp lại mã OTP"
                        onClicked: d.app.reissueOtp(d.machine)
                    }
                    Btn {
                        visible: d.isLicensed
                        variant: "secondary"
                        text: "Chuyển sang máy khác…"
                        enabled: d.app.pendingMachines.length > 0
                        onClicked: d.app.openTransfer(d.machine)
                    }
                    Btn {
                        visible: d.isLicensed
                        variant: "danger"
                        text: "Thu hồi…"
                        onClicked: d.app.openRevoke(d.machine)
                    }
                    Btn {
                        visible: d.isRevoked
                        variant: "danger"
                        text: "Xoá khỏi danh sách…"
                        onClicked: d.app.openRemove(d.machine)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: d.isLicensed && d.app.pendingMachines.length === 0
                    text: "Chuyển máy cần có ít nhất một máy mới đang chờ duyệt."
                    color: Tk.neutral
                    font.family: Tk.body
                    font.pixelSize: Tk.textXs
                }
            }

            // ── Lịch sử ─────────────────────────────────────────────────────
            Panel {
                title: "Lịch sử giấy phép"
                Text {
                    visible: d.app.historyState !== "ready"
                    text: d.app.historyState === "loading" ? "Đang tải…"
                        : d.app.historyState === "unavailable" ? "Máy chủ chưa hỗ trợ xem lịch sử."
                        : "Không tải được lịch sử."
                    color: Tk.neutral
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                }
                Text {
                    visible: d.app.historyState === "ready" && d.app.history.licenses.length === 0
                    text: "Chưa cấp giấy phép nào cho máy này."
                    color: Tk.neutral
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                }
                Repeater {
                    model: d.app.historyState === "ready" ? d.app.history.licenses : []
                    HistoryRow {
                        required property var modelData
                        primary: modelData.serial
                        secondary: Tk.tierLabel(modelData.device_tier) + " · hạn " + Tk.date(modelData.not_after)
                                   + " · ký " + Tk.dateTime(modelData.issued_at)
                                   + (modelData.approver ? " · " + modelData.approver : "")
                        badge: modelData.status === "active" ? "Đang dùng"
                             : modelData.status === "revoked" ? "Thu hồi" : "Đã thay"
                        badgeTone: modelData.status === "active" ? "ok" : modelData.status === "revoked" ? "bad" : ""
                    }
                }
                Text {
                    visible: d.app.historyState === "ready" && d.app.history.otps.length > 0
                    Layout.topMargin: Tk.sSm
                    text: "Mã OTP đã sinh"
                    color: Tk.muted
                    font.family: Tk.body
                    font.pixelSize: Tk.textXs
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: d.app.historyState === "ready" ? d.app.history.otps : []
                    HistoryRow {
                        required property var modelData
                        primary: modelData.code
                        secondary: "Tạo " + Tk.dateTime(modelData.created_at)
                                   + (modelData.used_at ? " · dùng " + Tk.dateTime(modelData.used_at) : "")
                                   + " · sai " + modelData.attempts + "/5"
                        badge: modelData.status === "used" ? "Đã dùng" : modelData.status === "locked" ? "Bị khoá"
                             : modelData.status === "active" ? "Đang mở" : "Đã huỷ"
                        badgeTone: modelData.status === "used" ? "ok" : modelData.status === "locked" ? "bad" : ""
                    }
                }
            }
        }
    }

    // ── Thành phần nội bộ ───────────────────────────────────────────────────
    component Fact: ColumnLayout {
        id: fact
        property string label: ""
        property string value: ""
        property bool mono: false
        property bool copyable: false
        property string tone: ""
        // Hai cột bằng nhau, căn đỉnh — dòng có nút "Sao chép" cao hơn không kéo lệch cột kia.
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        spacing: 2
        Text {
            text: fact.label
            color: Tk.neutral
            font.family: Tk.body
            font.pixelSize: Tk.textXs
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Tk.sXs
            Text {
                Layout.fillWidth: !fact.copyable
                Layout.preferredHeight: 32
                verticalAlignment: Text.AlignVCenter
                text: fact.value
                color: fact.tone === "warn" ? Tk.error : Tk.ink
                font.family: fact.mono ? Tk.mono : Tk.body
                font.pixelSize: Tk.textSm
                font.weight: fact.mono ? Font.Medium : Font.Normal
                elide: Text.ElideRight
            }
            Btn {
                visible: fact.copyable && fact.value !== ""
                variant: "quiet"
                text: "Sao chép"
                onClicked: d.app.copy(fact.value, "Đã chép " + fact.value)
            }
            Item { Layout.fillWidth: fact.copyable }
        }
    }

    component Panel: Rectangle {
        id: panel
        property string title: ""
        property string subtitle: ""
        default property alias content: body.data
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + Tk.sLg * 2
        radius: Tk.radiusLg
        color: Tk.surface
        border.width: 1
        border.color: Tk.paper3
        ColumnLayout {
            id: body
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tk.sLg }
            spacing: Tk.sMd
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: panel.title
                    color: Tk.ink
                    font.family: Tk.display
                    font.pixelSize: Tk.textLg
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    visible: panel.subtitle !== ""
                    text: panel.subtitle
                    color: Tk.neutral
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component ChoiceRow: ColumnLayout {
        id: choice
        property string label: ""
        default property alias chips: flow.data
        Layout.fillWidth: true
        spacing: Tk.sXs
        Text {
            text: choice.label
            color: Tk.muted
            font.family: Tk.body
            font.pixelSize: Tk.textXs
            font.weight: Font.DemiBold
        }
        Flow {
            id: flow
            Layout.fillWidth: true
            spacing: Tk.sXs
        }
    }

    component HistoryRow: RowLayout {
        id: hr
        property string primary: ""
        property string secondary: ""
        property string badge: ""
        property string badgeTone: ""
        Layout.fillWidth: true
        spacing: Tk.sMd
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text {
                text: hr.primary
                color: Tk.ink
                font.family: Tk.mono
                font.pixelSize: Tk.textSm
            }
            Text {
                Layout.fillWidth: true
                text: hr.secondary
                color: Tk.neutral
                font.family: Tk.body
                font.pixelSize: Tk.textXs
                elide: Text.ElideRight
            }
        }
        Text {
            text: hr.badge
            color: hr.badgeTone === "ok" ? Tk.success : hr.badgeTone === "bad" ? Tk.error : Tk.neutral
            font.family: Tk.body
            font.pixelSize: Tk.textXs
            font.weight: Font.DemiBold
        }
    }
}
