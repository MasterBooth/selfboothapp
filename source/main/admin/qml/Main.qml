// Hallmark · genre: editorial · macrostructure: Workbench (app, sidebar) · design-system: design.md · designed-as-app
// Hallmark · pre-emit critique: P4 H5 E4 S5 R5 V4
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore

// BOOTHME Admin — cấp giấy phép máy booth.
// Luồng: máy booth đăng nhập studio → hiện ở "Chờ duyệt" → admin ký + cấp → Worker sinh
// OTP 4 số → admin đọc mã cho khách → khách nhập trên máy → máy lưu chữ ký, chạy offline.
ApplicationWindow {
    id: win
    width: 1320; height: 840
    minimumWidth: 1060; minimumHeight: 660
    visible: true
    title: "BOOTHME Admin — Giấy phép máy"
    color: Tk.paper

    // ── State ────────────────────────────────────────────────────────────────
    property var machines: []
    property string view: "pending"           // pending | licensed | revoked | all | key | server
    property string search: ""
    property string selectedHwid: ""
    property var lastOtp: null                // { hwid, otp, expires } — mã vừa sinh trong phiên
    property var history: ({ licenses: [], otps: [] })
    property string historyState: "idle"      // idle | loading | ready | unavailable | error
    property string approver: ""
    property string lastSync: ""
    property string lastError: ""
    property bool _refreshing: false
    readonly property bool busy: api.busy

    readonly property var selected: {
        for (let i = 0; i < machines.length; i++)
            if (machines[i].hwid === selectedHwid) return machines[i]
        return null
    }
    readonly property var visibleMachines: {
        const q = search.trim().toLowerCase()
        return machines.filter(function(m) {
            if (view !== "all" && m.state !== view) return false
            if (q === "") return true
            return [m.hwid, m.studio_name, m.owner_email, m.serial, m.device_name]
                .some(function(x) { return x && String(x).toLowerCase().indexOf(q) >= 0 })
        })
    }
    readonly property var pendingMachines: machines.filter(function(m) { return m.state === "pending" })
    function countOf(state) {
        let n = 0
        for (let i = 0; i < machines.length; i++) if (state === "all" || machines[i].state === state) n++
        return n
    }

    Settings {
        category: "admin-ui"
        property alias approver: win.approver
        property alias view: win.view
    }

    // ── Thao tác ─────────────────────────────────────────────────────────────
    function newSerial() { return "LM-" + Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss") }

    // Hạn mới: cộng dồn từ max(hôm nay, hạn hiện tại). 0 tháng = vô thời hạn ("").
    function renewedNotAfter(currentIso, months) {
        if (months <= 0) return ""
        let base = new Date()
        if (currentIso) {
            const cur = new Date(currentIso)
            if (!isNaN(cur.getTime()) && cur > base) base = cur
        }
        base.setMonth(base.getMonth() + months)
        return base.toISOString().replace(/\.\d{3}Z$/, "Z")
    }

    function refresh() {
        if (!signer.unlocked) return
        _refreshing = true
        api.fetchMachines()
    }
    function select(hwid) {
        selectedHwid = hwid
        loadHistory()
    }
    function loadHistory() {
        if (selectedHwid === "") { historyState = "idle"; return }
        historyState = "loading"
        api.fetchHistory(selectedHwid)
    }
    function notify(msg, isError) { snack.show(msg, !!isError) }
    function copy(text, msg) { api.copyText(text); notify(msg || "Đã chép") }

    function issueNew(m, tier, months, grace, serial) {
        const blob = signer.signLicense(m.hwid, m.owner_email || "", m.studio_name || "",
                                        tier, serial.trim(), months, grace)
        if (!blob) { notify("Không ký được: " + signer.lastError(), true); return }
        api.issue(blob, approver, true)
    }
    function renew(m, tier, months, grace, serial, withOtp) {
        const blob = signer.signLicenseUntil(m.hwid, m.owner_email || "", m.studio_name || "",
                                             tier, serial.trim(), renewedNotAfter(m.not_after, months), grace)
        if (!blob) { notify("Không ký được: " + signer.lastError(), true); return }
        api.issue(blob, approver, withOtp)
    }
    function reissueOtp(m) { api.reissueOtp(m.hwid) }
    function openRevoke(m) { sheet.openFor("revoke", m) }
    function openTransfer(m) { sheet.openFor("transfer", m) }
    function openRemove(m) { sheet.openFor("remove", m) }

    Connections {
        target: api
        function onMachinesReady(list) {
            win.machines = list
            win.lastSync = new Date().toISOString()
            win.lastError = ""
            win._refreshing = false
            if (win.selectedHwid !== "" && win.selected === null) win.selectedHwid = ""
        }
        function onIssued(serial, hwid, otp, expiresAt) {
            if (otp) {
                win.lastOtp = { hwid: hwid, otp: otp, expires: expiresAt }
                win.notify("Đã cấp " + serial + " · mã kích hoạt " + otp)
            } else {
                win.notify("Đã ký " + serial + " · máy tự nhận khi có mạng")
            }
            // Chuyển máy: đi theo máy mới để admin đọc OTP ngay.
            win.selectedHwid = hwid
            if (win.view !== "all" && win.view !== "licensed") win.view = "licensed"
            win.refresh()
            win.loadHistory()
        }
        function onOtpReady(hwid, otp, expiresAt) {
            win.lastOtp = { hwid: hwid, otp: otp, expires: expiresAt }
            win.notify("Đã cấp lại mã kích hoạt " + otp)
            win.refresh()
            win.loadHistory()
        }
        function onRevoked(serial, hwid) {
            win.notify("Đã thu hồi " + serial + " · máy bị khoá khi có mạng")
            if (win.lastOtp && win.lastOtp.hwid === hwid) win.lastOtp = null
            win.refresh()
            win.loadHistory()
        }
        function onRemoved(hwid) {
            win.notify("Đã xoá " + hwid + " khỏi danh sách")
            win.selectedHwid = ""
            win.refresh()
        }
        function onHistoryReady(hwid, data) {
            if (hwid !== win.selectedHwid) return
            win.history = { licenses: data.licenses || [], otps: data.otps || [] }
            win.historyState = "ready"
        }
        function onHistoryFailed(hwid, notSupported) {
            if (hwid !== win.selectedHwid) return
            win.historyState = notSupported ? "unavailable" : "error"
        }
        function onFailed(msg) {
            if (win._refreshing) { win.lastError = msg; win._refreshing = false }
            win.notify(msg, true)
        }
    }

    // Danh sách chờ duyệt tự làm mới — khách vừa đăng nhập là thấy.
    Timer {
        interval: 60000
        repeat: true
        running: signer.unlocked
        onTriggered: if (!api.busy) win.refresh()
    }

    Connections {
        target: signer
        function onStateChanged() { if (signer.unlocked) win.refresh() }
    }
    Component.onCompleted: if (signer.unlocked) refresh()

    component GroupLabel: Text {
        Layout.leftMargin: Tk.sSm
        Layout.bottomMargin: Tk.s2xs
        color: Tk.sideMuted
        font.family: Tk.body
        font.pixelSize: 11
        font.weight: Font.DemiBold
    }

    // ── Bố cục ───────────────────────────────────────────────────────────────
    // Mọi lớp (giao diện chính, hộp xác nhận, màn khoá) nằm trong một Item gốc.
    Rectangle {
    id: rootView
    anchors.fill: parent
    color: Tk.paper

    RowLayout {
        anchors.fill: parent
        spacing: 0
        visible: signer.unlocked

        // Sidebar
        Rectangle {
            Layout.preferredWidth: 252
            Layout.fillHeight: true
            color: Tk.side

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Tk.sMd
                spacing: Tk.s2xs

                ColumnLayout {
                    Layout.leftMargin: Tk.sSm
                    Layout.topMargin: Tk.sSm
                    Layout.bottomMargin: Tk.sLg
                    spacing: 0
                    Text {
                        text: "Selfbooth"
                        color: Tk.sideInk
                        font.family: Tk.display
                        font.pixelSize: Tk.textXl
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: "Giấy phép máy"
                        color: Tk.sideMuted
                        font.family: Tk.body
                        font.pixelSize: Tk.textXs
                    }
                }

                GroupLabel { text: "Máy" }
                SideItem { text: "Chờ duyệt"; count: win.countOf("pending"); attention: true
                           current: win.view === "pending"; onClicked: win.view = "pending" }
                SideItem { text: "Đã kích hoạt"; count: win.countOf("licensed")
                           current: win.view === "licensed"; onClicked: win.view = "licensed" }
                SideItem { text: "Đã thu hồi"; count: win.countOf("revoked")
                           current: win.view === "revoked"; onClicked: win.view = "revoked" }
                SideItem { text: "Tất cả máy"; count: win.countOf("all")
                           current: win.view === "all"; onClicked: win.view = "all" }

                GroupLabel { text: "Hệ thống"; Layout.topMargin: Tk.sLg }
                SideItem { text: "Khoá ký"; current: win.view === "key"; onClicked: win.view = "key" }
                SideItem { text: "Máy chủ"; current: win.view === "server"; onClicked: win.view = "server" }

                Item { Layout.fillHeight: true }

                // Khoá + kết nối
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: foot.implicitHeight + Tk.sMd * 2
                    radius: Tk.radiusMd
                    color: Tk.sideActive
                    ColumnLayout {
                        id: foot
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tk.sMd }
                        spacing: Tk.sXs
                        RowLayout {
                            spacing: Tk.sXs
                            Rectangle {
                                implicitWidth: 8; implicitHeight: 8; radius: 4
                                color: win.lastError !== "" ? Tk.errorSoft : win.lastSync ? Tk.successSoft : Tk.sideMuted
                            }
                            Text {
                                Layout.fillWidth: true
                                text: api.baseUrl ? api.baseUrl.replace(/^https?:\/\//, "") : "Chưa cấu hình máy chủ"
                                color: Tk.sideInk
                                font.family: Tk.body
                                font.pixelSize: Tk.textXs
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            text: "Khoá " + signer.keyId + " · đang mở"
                            color: Tk.sideMuted
                            font.family: Tk.mono
                            font.pixelSize: 11
                        }
                        Btn {
                            Layout.fillWidth: true
                            Layout.topMargin: Tk.s2xs
                            variant: "secondary"
                            onDark: true
                            text: "Khoá sổ"
                            onClicked: signer.lock()
                        }
                    }
                }
            }
        }

        // Nội dung
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            MachinesPage {
                anchors.fill: parent
                visible: ["pending", "licensed", "revoked", "all"].indexOf(win.view) >= 0
                app: win
            }
            KeyPage {
                anchors.fill: parent
                visible: win.view === "key"
                app: win
            }
            ServerPage {
                anchors.fill: parent
                visible: win.view === "server"
                app: win
            }

            // Snackbar — chỉ cho kết quả không tự hiện trên màn hình và cho lỗi.
            Rectangle {
                id: snack
                property bool isError: false
                property string message: ""
                function show(m, err) { message = m; isError = err; hideTimer.restart() }
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Tk.sLg
                width: Math.min(snackText.implicitWidth + Tk.sLg * 2 + closeBtn.width, parent.width - Tk.sXl * 2)
                height: Math.max(Tk.control, snackText.implicitHeight + Tk.sSm * 2)
                radius: Tk.radiusPill
                color: isError ? Tk.error : Tk.ink
                opacity: message !== "" ? 1 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: Tk.durMicro } }
                Timer { id: hideTimer; interval: snack.isError ? 7000 : 3500; onTriggered: snack.message = "" }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Tk.sLg
                    anchors.rightMargin: Tk.sXs
                    Text {
                        id: snackText
                        Layout.fillWidth: true
                        text: snack.message
                        color: Tk.accentInk
                        font.family: Tk.body
                        font.pixelSize: Tk.textSm
                        wrapMode: Text.WordWrap
                    }
                    Btn {
                        id: closeBtn
                        variant: "quiet"
                        onDark: true
                        text: "Đóng"
                        onClicked: snack.message = ""
                    }
                }
            }
        }
    }


    // ── Hộp xác nhận: thu hồi · chuyển máy · xoá ─────────────────────────────
    // Lớp phủ tự vẽ (không dùng Popup): nằm trong cây QML nên chụp/kiểm thử được.
    Rectangle {
        id: sheet
        property string kind: ""
        property var machine: null
        property int targetIndex: -1
        function openFor(k, m) {
            machine = m; targetIndex = -1; reason.text = ""
            kind = k
        }
        function close() { kind = "" }
        anchors.fill: parent
        z: 50
        visible: kind !== "" && signer.unlocked
        color: Qt.rgba(0.13, 0.07, 0.02, 0.45)   // ink 45% — lớp mờ, không phải màu mới
        MouseArea { anchors.fill: parent; onClicked: sheet.close() }
        Shortcut { sequence: "Escape"; enabled: sheet.visible; onActivated: sheet.close() }

        readonly property string titleText: kind === "revoke" ? "Thu hồi giấy phép"
                                          : kind === "transfer" ? "Chuyển sang máy khác" : "Xoá khỏi danh sách"

        Rectangle {
          anchors.centerIn: parent
          width: Math.min(520, parent.width - Tk.sXl * 2)
          height: card.implicitHeight + Tk.sLg * 2
          radius: Tk.radiusLg
          color: Tk.surface
          border.width: 1
          border.color: Tk.rule
          MouseArea { anchors.fill: parent }   // chặn click xuyên xuống lớp mờ
          ColumnLayout {
            id: card
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tk.sLg }
            spacing: Tk.sMd
            Text {
                text: sheet.titleText
                color: Tk.ink
                font.family: Tk.display
                font.pixelSize: Tk.textXl
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Tk.muted
                font.family: Tk.body
                font.pixelSize: Tk.textSm
                lineHeight: 1.3
                text: !sheet.machine ? ""
                    : sheet.kind === "revoke"
                      ? "Ký phiếu thu hồi " + sheet.machine.serial + " của " + (sheet.machine.studio_name || sheet.machine.hwid)
                        + ". Máy bị khoá ở lần kết nối mạng tiếp theo; đang chụp dở thì khoá sau khi xong phiên. Không hoàn tác được — muốn dùng lại phải cấp giấy phép mới."
                    : sheet.kind === "transfer"
                      ? "Máy cũ (" + sheet.machine.hwid + ") bị thu hồi. Máy mới nhận cùng hạng " + Tk.tierLabel(sheet.machine.device_tier)
                        + ", cùng hạn " + Tk.date(sheet.machine.not_after) + " và một mã OTP mới."
                      : "Xoá " + sheet.machine.hwid + " cùng giấy phép cũ, OTP và yêu cầu. Phiếu thu hồi vẫn được giữ. Nếu máy báo danh lại sẽ hiện ở Chờ duyệt."
            }

            Field {
                id: reason
                Layout.fillWidth: true
                visible: sheet.kind === "revoke"
                label: "Lý do (lưu trong phiếu thu hồi)"
                placeholderText: "Ví dụ: hết hợp đồng, máy bị mất"
            }

            // Chọn máy mới
            ColumnLayout {
                Layout.fillWidth: true
                visible: sheet.kind === "transfer"
                spacing: Tk.s2xs
                Text {
                    text: "Máy mới (đang chờ duyệt)"
                    color: Tk.muted
                    font.family: Tk.body
                    font.pixelSize: Tk.textXs
                    font.weight: Font.DemiBold
                }
                Repeater {
                    model: sheet.kind === "transfer" ? win.pendingMachines : []
                    AbstractButton {
                        id: pick
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 56
                        hoverEnabled: true
                        onClicked: sheet.targetIndex = index
                        background: Rectangle {
                            radius: Tk.radiusSm
                            color: sheet.targetIndex === pick.index ? Tk.accentSoft : pick.hovered ? Tk.paper2 : "transparent"
                            border.width: 1
                            border.color: sheet.targetIndex === pick.index ? Tk.accent : Tk.paper3
                        }
                        contentItem: Item {
                          ColumnLayout {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                Layout.leftMargin: Tk.sMd
                                text: pick.modelData.studio_name || "Chưa gắn studio"
                                color: Tk.ink
                                font.family: Tk.body
                                font.pixelSize: Tk.textSm
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.leftMargin: Tk.sMd
                                text: pick.modelData.hwid + "  ·  " + (pick.modelData.owner_email || "")
                                color: Tk.neutral
                                font.family: Tk.mono
                                font.pixelSize: Tk.textXs
                            }
                          }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Tk.sXs
                spacing: Tk.sSm
                Item { Layout.fillWidth: true }
                Btn { variant: "secondary"; text: "Huỷ"; onClicked: sheet.close() }
                Btn {
                    variant: sheet.kind === "transfer" ? "primary" : "danger"
                    text: sheet.kind === "revoke" ? "Ký và thu hồi"
                        : sheet.kind === "transfer" ? "Ký và chuyển" : "Xoá máy"
                    enabled: sheet.kind !== "transfer" || sheet.targetIndex >= 0
                    onClicked: {
                        const m = sheet.machine
                        if (sheet.kind === "revoke") {
                            const rev = signer.signRevocation(m.hwid, m.serial, reason.text)
                            if (!rev) { win.notify("Không ký được: " + signer.lastError(), true); return }
                            api.revoke(rev)
                        } else if (sheet.kind === "transfer") {
                            const t = win.pendingMachines[sheet.targetIndex]
                            const rev = signer.signRevocation(m.hwid, m.serial, "chuyển sang " + t.hwid)
                            const lic = signer.signLicenseUntil(t.hwid, t.owner_email || m.owner_email || "",
                                                                t.studio_name || m.studio_name || "",
                                                                m.device_tier, win.newSerial(), m.not_after || "", 30)
                            if (!rev || !lic) { win.notify("Không ký được: " + signer.lastError(), true); return }
                            api.transfer(rev, lic, win.approver)
                        } else {
                            api.removeMachine(m.hwid)
                        }
                        sheet.close()
                    }
                }
            }
        }
    }
    }

    // ── Màn mở khoá sổ ───────────────────────────────────────────────────────
    // Chưa mở khoá thì không thấy gì khác. Khoá ký chỉ nằm trong RAM sau bước này.
    Rectangle {
        anchors.fill: parent
        visible: !signer.unlocked
        color: Tk.paper
        z: 100

        property bool working: false

        function submit() {
            keyErr.text = ""
            working = true
            // Argon2 mất ~1 giây và chạy đồng bộ: nhường một khung hình để nút kịp đổi chữ.
            Qt.callLater(function() {
                const ok = signer.hasKeyFile ? signer.unlock(passField.text)
                                             : signer.createKey(kidField.text, passField.text)
                working = false
                if (!ok) {
                    keyErr.text = signer.hasKeyFile ? "Sai mật khẩu hoặc tệp khoá đã bị sửa."
                                                    : "Không tạo được khoá. Mật khẩu cần tối thiểu 12 ký tự."
                    passField.input.selectAll()
                    passField.input.forceActiveFocus()
                } else {
                    passField.text = ""
                }
            })
        }
        id: lockScreen

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * 0.38
            color: Tk.side
            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Tk.sXl
                spacing: Tk.sXs
                Text {
                    text: "Selfbooth"
                    color: Tk.sideInk
                    font.family: Tk.display
                    font.pixelSize: 56
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: "Công cụ cấp giấy phép máy booth. Chỉ cài trên máy quản trị, không đưa cho khách."
                    color: Tk.sideMuted
                    font.family: Tk.body
                    font.pixelSize: Tk.textSm
                    wrapMode: Text.WordWrap
                }
            }
        }

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            x: parent.width * 0.38 + (parent.width * 0.62 - width) / 2
            width: Math.min(400, parent.width * 0.62 - Tk.sXl * 2)
            spacing: Tk.sMd

            Text {
                text: signer.hasKeyFile ? "Mở khoá sổ ký" : "Tạo khoá ký"
                color: Tk.ink
                font.family: Tk.display
                font.pixelSize: Tk.text2xl
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                text: signer.hasKeyFile
                      ? "Nhập mật khẩu sổ ký. Khoá chỉ nằm trong bộ nhớ khi app đang mở và bị xoá khi bấm Khoá sổ."
                      : "Máy này sẽ giữ khoá ký duy nhất của hệ thống. Sao lưu tệp khoá và ghi nhớ mật khẩu — mất khoá là không gia hạn được máy nào."
                color: Tk.muted
                font.family: Tk.body
                font.pixelSize: Tk.textSm
                wrapMode: Text.WordWrap
                lineHeight: 1.3
            }
            Field {
                id: kidField
                Layout.fillWidth: true
                visible: !signer.hasKeyFile
                label: "Mã khoá (kid)"
                text: "lm-2026-01"
                mono: true
            }
            Field {
                id: passField
                Layout.fillWidth: true
                label: "Mật khẩu"
                placeholderText: signer.hasKeyFile ? "" : "Tối thiểu 12 ký tự"
                echoMode: TextInput.Password
                error: keyErr.text
                onAccepted: lockScreen.submit()
                Component.onCompleted: input.forceActiveFocus()
            }
            Text { id: keyErr; visible: false }
            Btn {
                Layout.fillWidth: true
                text: signer.hasKeyFile ? "Mở khoá" : "Tạo khoá"
                loading: lockScreen.working
                enabled: passField.text !== ""
                onClicked: lockScreen.submit()
            }
            Text {
                Layout.fillWidth: true
                text: signer.keyFilePath
                color: Tk.neutral
                font.family: Tk.mono
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
            }
        }
    }
    }
}
