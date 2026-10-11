import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils/Money.js" as Money
import "../../theme"
import "../../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // ── Inputs ────────────────────────────────────────────────────────────────
    property int    totalPrice: 0
    property int    copies: 1
    property bool   isCut: false
    property string layoutPath: ""
    property string bgOverride: ""

    // Hiển thị nút nào (luồng chính: theo settings; gallery: tắt voucher inline)
    property bool   showVoucher: true
    property bool   showCash: true
    property bool   showBankTransfer: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
    property bool   cashCodeEnabled: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"
    property bool   allowPrintVoucher: true

    // ── Output signals ────────────────────────────────────────────────────────
    signal cashSelected()
    signal cashCodePaid(string code, int amount)
    signal bankTransferSelected()
    // Voucher giảm giá / tặng in (vẫn còn tiền phải trả) → host cập nhật giá rồi
    // ở lại trang để khách chọn tiền mặt / QR (hoặc tự sang QR khi tắt tiền mặt).
    signal voucherApplied(string code, string voucherType, int voucherValue)
    // Voucher "cash" khớp đúng hoặc giảm về 0 = đã thanh toán đủ → bỏ qua thanh toán.
    signal voucherPaid(string code, int amount)
    signal closeClicked()

    // ── Lifecycle: re-online bill acceptor ──────────────────────────────────────
    Component.onCompleted: {
        if (!billAcceptor.connected) {
            var savedPort = eventManager.getAppSetting("bill_acceptor_port", "")
            if (savedPort !== "")
                billAcceptor.openPort(savedPort)
        }
        // Mã giờ chỉ 4 số, không tiền tố → không cần dựng danh sách tiền tố.
    }

    Connections {
        target: billAcceptor
        function onConnectedChanged() {
            if (billAcceptor.connected)
                reconnectingBanner.visible = false
        }
    }

    // ── Voucher state ───────────────────────────────────────────────────────────
    property bool   _voucherMode: false   // panel nhập voucher đang mở
    property bool   _voucherDone: false   // đã áp dụng (giảm giá / tặng in)
    property string _inputRaw:    ""      // 4 chữ số của mã (không tiền tố)
    property string _resultType:  ""
    property int    _resultValue: 0
    property string _errorMsg:    ""
    property bool   _cashCodeMode: false
    property bool   _cashHandoffMode: false
    property string _cashInputRaw: ""
    property string _cashErrorMsg: ""

    readonly property int _checkLen: 4    // luôn nhập 4 chữ số
    readonly property int _maxLen:   4

    function _startCashCodePayment() {
        if (!root.cashCodeEnabled) return
        root._voucherMode = false
        root._cashHandoffMode = false
        root._cashInputRaw = ""
        root._cashErrorMsg = ""
        root._cashCodeMode = true
    }

    function _startCashHandoff() {
        root._startCashCodePayment()
    }

    function _goBack() {
        if (root._cashCodeMode) {
            root._cashCodeMode = false
            root._cashInputRaw = ""
            root._cashErrorMsg = ""
            return
        }
        if (root._cashHandoffMode || root._voucherMode) {
            root._cashHandoffMode = false
            root._voucherMode = false
            return
        }
        root.closeClicked()
    }

    function _cashAdd(ch) {
        if (!/^[0-9]$/.test(ch) || root._cashInputRaw.length >= 4) return
        root._cashInputRaw += ch
        root._cashErrorMsg = ""
        if (root._cashInputRaw.length === 4)
            root._checkCashCode()
    }

    function _cashDel() {
        if (root._cashInputRaw.length === 0) return
        root._cashInputRaw = root._cashInputRaw.slice(0, -1)
        root._cashErrorMsg = ""
    }

    function _checkCashCode() {
        var code = root._fmtCash(root._cashInputRaw)
        var res = eventManager.validateCashPaymentCode(code, root.totalPrice)
        if (res.valid) {
            root.cashCodePaid(res.code, root.totalPrice)
        } else {
            root._cashErrorMsg = res.error || "Sai mã thanh toán tiền mặt"
            root._cashInputRaw = ""
        }
    }

    // ── Numpad sizing — nhỏ gọn để vừa cùng các nút trên 1 màn hình ─────────────
    property real _kbW:      Math.min(root.width * 0.30, 360)
    property real _kbGap:    10
    property real _keyW:     Math.floor((_kbW - 2 * _kbGap) / 3)
    property real _keyH:     Math.floor(_keyW * 0.50)
    property real _slotW:    Math.max(34, Math.floor(_kbW * 0.16))
    property real _slotH:    Math.floor(_slotW * 1.30)
    property real _slotFont: Math.max(14, Math.round(_slotW * 0.50))

    // Mã chỉ 4 số, không tiền tố → dùng thẳng chuỗi số đã nhập.
    function _fmt(raw) { return raw }
    function _fmtCash(raw) { return raw }

    function _add(ch) {
        if (root._voucherDone || root._inputRaw.length >= root._maxLen) return
        if (!/^[0-9]$/.test(ch)) return    // bàn phím tối giản: chỉ chữ số
        root._inputRaw  += ch
        root._errorMsg   = ""
        root._resultType = ""
        if (root._inputRaw.length >= root._checkLen) _check()
    }

    function _del() {
        if (root._voucherDone || root._inputRaw.length === 0) return
        root._inputRaw   = root._inputRaw.slice(0, -1)
        root._errorMsg   = ""
        root._resultType = ""
    }

    function _check() {
        if (root._inputRaw.length === 0) return
        var res = eventManager.validateVoucher(_fmt(root._inputRaw), root.totalPrice)
        if (res.valid) {
            if (res.type === "print" && !root.allowPrintVoucher) {
                root._resultType  = ""
                root._resultValue = 0
                root._errorMsg    = "Voucher tặng lượt in không áp dụng cho Selfbooth"
                return
            }
            root._resultType  = res.type
            root._resultValue = res.value
            root._errorMsg    = ""
        } else {
            root._resultType  = ""
            root._resultValue = 0
            root._errorMsg    = res.error
        }
    }

    function _apply() {
        if (!root._resultType || root._voucherDone) return
        var code = _fmt(root._inputRaw)
        if (root._resultType === "cash" || root._resultType === "discount") {
            // Voucher tiền/giảm giá: trừ thẳng giá trị vào số tiền cần trả.
            if (root._resultValue >= root.totalPrice) {
                // Phủ đủ → đã thanh toán xong.
                root._voucherDone = true
                root.voucherPaid(code, root.totalPrice)
            } else {
                // Còn lại → host cập nhật giá, ở lại trang chọn cách trả phần còn lại.
                root._voucherDone = true
                root._voucherMode = false
                root.voucherApplied(code, root._resultType, root._resultValue)
            }
        } else { // "print"
            root._voucherDone = true
            root._voucherMode = false
            root.voucherApplied(code, "print", root._resultValue)
        }
    }

    Timer {
        id: blink; interval: 520; repeat: true
        running: (root._voucherMode && !root._voucherDone) || root._cashCodeMode
        property bool on: true
        onTriggered: on = !on
    }

    // ── Theme ─────────────────────────────────────────────────────────────────
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    property string backgroundImagePath: {
        if (root.bgOverride !== "") return root.bgOverride
        var s = eventManager.getAppSetting("payment_method_bg_image", "")
        return s !== "" ? s : "qrc:/assets/thanhtoan.png"
    }
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
            GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
        }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    // ── Inline: ô số voucher ────────────────────────────────────────────────────
    component Slot: Rectangle {
        property int ci: 0
        width: root._slotW; height: root._slotH; radius: 8
        readonly property bool filled: ci < root._inputRaw.length
        readonly property bool active: ci === root._inputRaw.length && !root._voucherDone

        color:        filled ? "#131d2e" : "#0d1018"
        border.width: active ? 2 : 1
        border.color: active                  ? "#4FA4F2"
                    : root._resultType !== "" ? "#3d9e52"
                    : root._errorMsg   !== "" ? "#c84040"
                    : filled                  ? "#1e3050"
                    : "#1e2230"
        Behavior on border.color { ColorAnimation { duration: 160 } }
        Behavior on color        { ColorAnimation { duration: 160 } }

        Text {
            anchors.centerIn: parent
            text: ci < root._inputRaw.length ? root._inputRaw[ci] : ""
            font.pixelSize: root._slotFont; font.bold: true; font.family: "Courier New"
            color: root._resultType !== "" ? "#6ee37a"
                 : root._errorMsg   !== "" ? "#ef8080"
                 : Theme.surface
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2; height: Math.round(root._slotH * 0.55); radius: 1; color: "#4FA4F2"
            visible: parent.active && blink.on
        }
    }

    // ── Inline: phím numpad ─────────────────────────────────────────────────────
    component Key: Rectangle {
        id: k
        property string ch:    ""
        property bool isNum:   false
        property bool isDel:   false
        property bool isClear: false
        signal tap()

        width: root._keyW; height: root._keyH; radius: 10

        color: ma.pressed
             ? (isDel||isClear ? "#7a1a1a" : "#1a3a6e")
             : ma.containsMouse
             ? (isDel||isClear ? "#4a1515" : "#121e38")
             : isDel||isClear ? "#120e0e" : "#0e1420"

        border.color: ma.containsMouse
                    ? (isDel||isClear ? "#e07070" : "#4FA4F2")
                    : (isDel||isClear ? "#2e1a1a" : "#1a2038")
        border.width: ma.containsMouse ? 2 : 1

        Behavior on color        { ColorAnimation { duration: 60 } }
        Behavior on border.color { ColorAnimation { duration: 60 } }

        scale: ma.pressed ? 0.88 : 1.0
        Behavior on scale { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }

        Text {
            anchors.centerIn: parent
            text: k.ch
            color: k.isDel||k.isClear ? "#e07070" : (k.isNum ? "#82c4f8" : Theme.surface)
            font.pixelSize: k.isDel    ? Math.round(root._keyW * 0.34)
                          : k.isClear  ? Math.round(root._keyW * 0.17)
                          : Math.round(root._keyW * 0.30)
            font.bold: true
            font.family: (k.isDel || k.isClear) ? "" : "Courier New"
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root._cashCodeMode || !root._voucherDone
            onClicked: k.tap()
        }
    }

    // ── Top bar ───────────────────────────────────────────────────────────────
    Item {
        id: topBar
        width: parent.width
        height: 90
        anchors.top: parent.top
        z: 10

        Text {
            anchors.centerIn: parent
            text: root._cashCodeMode    ? ""
                : ""
            color: "#ffffff"
            font.pixelSize: 34
            font.weight: Font.Bold
        }
    }

    // ── Main content ──────────────────────────────────────────────────────────
    ColumnLayout {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width * 0.86, 1100)
        spacing: 0

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }

        // Tổng tiền cần thanh toán
        Rectangle {
            Layout.fillWidth: true
            height: 84
            radius: 16
            color: Theme.field
            border.color: "#f0c040"
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 0

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: root._voucherDone ? "Còn lại sau voucher" : "Tổng thanh toán"
                        color: Theme.textMuted
                        font.pixelSize: 15
                    }
                    Text {
                        text: root.copies + (root.isCut ? " ảnh cắt" : " ảnh in")
                        color: "#6a8aaa"
                        font.pixelSize: 13
                    }
                }

                Text {
                    text: Money.vnd(root.totalPrice)
                    color: "#f0c040"
                    font.pixelSize: 32
                    font.bold: true
                }
            }
        }

        Item { height: 22 }

        Text {
            text: root._cashCodeMode    ? "Nhập mã tiền mặt"
                : root._voucherMode     ? "Nhập mã voucher"
                : "Vui lòng chọn phương thức thanh toán"
            color: Theme.textMuted
            font.pixelSize: 17
            Layout.alignment: Qt.AlignHCenter
        }

        Item { height: 20 }

        // ── Các nút chọn phương thức (Voucher / Tiền mặt / Chuyển khoản) ───────
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 24
            visible: true

            // Voucher
            Rectangle {
                id: voucherBtn
                visible: root.showVoucher
                Layout.fillWidth: true
                height: 150
                radius: 18
                color: root._voucherMode ? "#1a0d2e"
                     : voucherMa.containsMouse ? "#1a0d2e" : "#12191f"
                border.color: (root._voucherMode || voucherMa.containsMouse) ? "#9d4edd" : Theme.border
                border.width: (root._voucherMode || voucherMa.containsMouse) ? 2 : 1
                opacity: root._voucherDone ? 0.55 : 1.0

                scale: voucherMa.pressed ? 0.97 : 1.0
                Behavior on color        { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }
                Behavior on scale        { NumberAnimation { duration: 100 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "🎟️"; font.pixelSize: 40; Layout.alignment: Qt.AlignHCenter }
                    Text {
                        text: root._voucherDone ? "Đã áp dụng" : "Voucher"
                        color: "#ffffff"; font.pixelSize: 21; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: root._voucherDone ? "✓" : "Nhập mã giảm giá"
                        color: root._voucherDone ? "#6ee37a" : Theme.textMuted
                        font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: voucherMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: root._voucherDone ? Qt.ArrowCursor : Qt.PointingHandCursor
                    enabled: !root._voucherDone
                    onClicked: {
                        root._cashCodeMode = false
                        root._cashHandoffMode = false
                        root._voucherMode = !root._voucherMode
                    }
                }
            }

            // Tiền mặt
            Rectangle {
                id: cashBtn
                visible: root.showCash
                Layout.fillWidth: true
                height: 150
                radius: 18
                color: root._cashCodeMode ? "#0d2a18"
                     : cashMa.pressed ? "#0d2a18"
                     : cashMa.containsMouse ? "#0d2a18" : "#12191f"
                border.color: (root._cashCodeMode || cashMa.containsMouse) ? "#22c55e" : Theme.border
                border.width: (root._cashCodeMode || cashMa.containsMouse) ? 2 : 1

                scale: cashMa.pressed ? 0.97 : 1.0
                Behavior on color        { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }
                Behavior on scale        { NumberAnimation { duration: 100 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "💵"; font.pixelSize: 40; Layout.alignment: Qt.AlignHCenter }
                    Text {
                        text: "Tiền Mặt"
                        color: "#ffffff"; font.pixelSize: 21; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Thanh toán trực tiếp"
                        color: Theme.textMuted; font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Badge trạng thái máy đọc tiền
                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    width: statusBadgeTxt.implicitWidth + 16
                    height: 24; radius: 12
                    color: billAcceptor.connected ? "#0d2a18" : "#2a1a0a"
                    border.color: billAcceptor.connected ? "#22c55e" : "#c06020"
                    border.width: 1

                    Text {
                        id: statusBadgeTxt
                        anchors.centerIn: parent
                        text: billAcceptor.connected ? "✓ Đã kết nối" : "✗ Chưa kết nối"
                        color: billAcceptor.connected ? "#4ade80" : "#fb923c"
                        font.pixelSize: 11; font.bold: true
                    }
                }

                MouseArea {
                    id: cashMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: (billAcceptor.connected || root.cashCodeEnabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: {
                        if (root.cashCodeEnabled)
                            root._startCashCodePayment()
                        else if (billAcceptor.connected)
                            root.cashSelected()
                    }
                }
            }

            // Chuyển khoản ngân hàng (QR)
            Rectangle {
                id: bankBtn
                visible: root.showBankTransfer
                Layout.fillWidth: true
                height: 150
                radius: 18
                color: bankMa.pressed ? "#0d1a3a"
                     : bankMa.containsMouse ? "#0d1a3a" : "#12191f"
                border.color: bankMa.containsMouse ? "#4FA4F2" : Theme.border
                border.width: bankMa.containsMouse ? 2 : 1

                scale: bankMa.pressed ? 0.97 : 1.0
                Behavior on color        { ColorAnimation { duration: 130 } }
                Behavior on border.color { ColorAnimation { duration: 130 } }
                Behavior on scale        { NumberAnimation { duration: 100 } }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "📱"; font.pixelSize: 40; Layout.alignment: Qt.AlignHCenter }
                    Text {
                        text: "Chuyển Khoản"
                        color: "#ffffff"; font.pixelSize: 21; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                    Text {
                        text: "Quét mã QR ngân hàng"
                        color: Theme.textMuted; font.pixelSize: 13
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                MouseArea {
                    id: bankMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.bankTransferSelected()
                }
            }
        }

        // ── Panel nhập voucher (hiện khi bấm nút Voucher) ──────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: root._voucherMode ? 18 : 0
            spacing: 12
            visible: root._voucherMode
            opacity: root._voucherMode ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 160 } }

            // Ô hiển thị mã: 4 ô số (không tiền tố)
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: root._kbW + 40; height: root._slotH + 24; radius: 14
                color: "#0b0e14"
                border.width: 2
                border.color: root._resultType !== "" ? "#3d9e52"
                            : root._errorMsg   !== "" ? "#c84040"
                            : root._inputRaw.length > 0 ? "#1e3a68" : "#181c28"
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Slot { ci: 0 }
                    Slot { ci: 1 }
                    Slot { ci: 2 }
                    Slot { ci: 3 }
                }
            }

            // Thanh trạng thái
            Text {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: 14; font.bold: true
                text: (root._resultType === "cash" || root._resultType === "discount")
                        ? (root._resultValue >= root.totalPrice
                           ? "✓  Voucher trừ " + Money.vnd(root._resultValue) + " — Đã đủ, miễn phí phần còn lại"
                           : "✓  Voucher trừ " + Money.vnd(root._resultValue) + " — Còn lại: " + Money.vnd(root.totalPrice - root._resultValue))
                    : root._resultType === "print"
                        ? "✓  Tặng thêm +" + root._resultValue + " tờ"
                    : root._errorMsg !== ""
                        ? "✕  " + root._errorMsg
                    : root._inputRaw.length === 0
                        ? "Nhập 4 số của mã voucher"
                        : "Đang nhập mã..."
                color: root._resultType !== ""   ? "#6ee37a"
                     : root._errorMsg   !== ""   ? "#ef8080"
                     : Theme.textMuted
            }

            // Numpad + nút áp dụng
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 20

                Grid {
                    columns: 3
                    spacing: root._kbGap
                    Key { ch:"1"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"2"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"3"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"4"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"5"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"6"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"7"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"8"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"9"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"⌫";  isDel:   true; onTap: root._del() }
                    Key { ch:"0"; isNum: true; onTap: root._add(ch) }
                    Key { ch:"Xóa"; isClear: true; onTap: { root._inputRaw = ""; root._errorMsg = ""; root._resultType = "" } }
                }

                // Nút áp dụng
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: root._keyH * 4 + root._kbGap * 3
                    radius: 14
                    enabled: root._resultType !== "" && !root._voucherDone
                    opacity: enabled ? 1.0 : 0.25
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    color: appMa.pressed ? "#1e6b26" : (appMa.containsMouse ? "#236030" : "#1a5424")
                    border.color: "#3a9a50"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 100 } }
                    scale: appMa.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - 16
                        text: "Áp dụng\nVoucher →"
                        horizontalAlignment: Text.AlignHCenter
                        color: "#ffffff"; font.pixelSize: 18; font.bold: true
                    }
                    MouseArea {
                        id: appMa; anchors.fill: parent; hoverEnabled: true
                        cursorShape: (root._resultType !== "" && !root._voucherDone) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root._apply()
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: root._cashHandoffMode ? 18 : 0
            spacing: 14
            visible: root._cashHandoffMode

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(root.width * 0.54, 680)
                Layout.preferredHeight: 250
                radius: 24
                color: "#111a13"
                border.color: "#22c55e"
                border.width: 2

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 28
                    spacing: 14

                    Text {
                        text: "💵"
                        font.pixelSize: 48
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Vui lòng đưa số tiền cần thanh toán cho nhân viên tại quầy"
                        color: "#ffffff"
                        font.pixelSize: 24
                        font.bold: true
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Text {
                        text: Money.vnd(root.totalPrice)
                        color: "#f0c040"
                        font.pixelSize: 42
                        font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }

                    Text {
                        text: "Sau khi đã đưa tiền, bấm xác nhận để nhập mã tiền mặt do nhân viên cấp."
                        color: "#9aa4b8"
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }
                }
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 300
                Layout.preferredHeight: 58
                radius: 14
                color: cashGivenMa.pressed ? "#15803d" : (cashGivenMa.containsMouse ? "#166534" : "#14532d")
                border.color: "#4ade80"
                border.width: 1
                scale: cashGivenMa.pressed ? 0.97 : 1.0
                Behavior on color { ColorAnimation { duration: 120 } }
                Behavior on scale { NumberAnimation { duration: 90 } }

                Text {
                    anchors.centerIn: parent
                    text: "Xác nhận đã đưa tiền"
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                }

                MouseArea {
                    id: cashGivenMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._startCashCodePayment()
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: root._cashCodeMode ? 18 : 0
            spacing: 14
            visible: root._cashCodeMode

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: root._kbW + 40
                height: root._slotH + 24
                radius: 14
                color: "#0b0e14"
                border.width: 2
                border.color: root._cashErrorMsg !== "" ? "#c84040"
                            : root._cashInputRaw.length > 0 ? "#1f7a43" : "#181c28"
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: 4
                        Rectangle {
                            width: root._slotW
                            height: root._slotH
                            radius: 8
                            readonly property bool active: index === root._cashInputRaw.length && root._cashCodeMode
                            color: index < root._cashInputRaw.length ? "#13251a" : "#0d1018"
                            border.width: active ? 2 : 1
                            border.color: active ? "#22c55e"
                                          : root._cashErrorMsg !== "" ? "#c84040"
                                          : index < root._cashInputRaw.length ? "#22c55e" : "#1e2230"
                            Text {
                                anchors.centerIn: parent
                                text: index < root._cashInputRaw.length ? root._cashInputRaw[index] : ""
                                color: Theme.text
                                font.pixelSize: root._slotFont
                                font.bold: true
                                font.family: "Courier New"
                            }
                            Rectangle {
                                anchors.centerIn: parent
                                width: 2
                                height: Math.round(root._slotH * 0.55)
                                radius: 1
                                color: "#22c55e"
                                visible: parent.active && blink.on
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Đưa " + Money.vnd(root.totalPrice) + " cho nhân viên, sau đó nhập 4 số của mã tiền mặt"
                color: Theme.textMuted
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root._cashErrorMsg !== "" ? root._cashErrorMsg : "Mã tiền mặt được tạo trong Cài đặt → Voucher"
                color: root._cashErrorMsg !== "" ? "#ef8080" : Theme.textMuted
                font.pixelSize: 13
                font.bold: root._cashErrorMsg !== ""
            }

            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                spacing: root._kbGap
                Key { ch:"1"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"2"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"3"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"4"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"5"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"6"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"7"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"8"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"9"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"<-"; isDel: true; onTap: root._cashDel() }
                Key { ch:"0"; isNum: true; onTap: root._cashAdd(ch) }
                Key { ch:"Xóa"; isClear: true; onTap: { root._cashInputRaw = ""; root._cashErrorMsg = "" } }
            }
        }

        Item { height: 20 }

        // ── Nút huỷ / quay lại ────────────────────────────────────────────────
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 200; height: 50; radius: 10
            color: cancelMethodMa.pressed ? "#263244"
                 : cancelMethodMa.containsMouse ? "#1e2a3d" : "#151b26"
            border.color: "#4FA4F2"; border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "Huỷ"
                color: Theme.text; font.pixelSize: 16; font.bold: true
                visible: false
            }
            Text {
                anchors.centerIn: parent
                text: "Quay lại"
                color: Theme.text; font.pixelSize: 16; font.bold: true
            }
            MouseArea {
                id: cancelMethodMa
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._goBack()
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 1 }
    }

    // ── Banner trạng thái đầu đọc tiền ──────────────────────────────────────
    Rectangle {
        id: reconnectingBanner
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        width: bannerRow.implicitWidth + 36
        height: 42; radius: 21
        visible: root.showCash && !billAcceptor.connected && !root.cashCodeEnabled
        color: billAcceptor.reconnecting ? "#1a1200" : "#2a1a08"
        border.color: billAcceptor.reconnecting ? "#c08000" : "#c06020"
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 250 } }
        Behavior on border.color { ColorAnimation { duration: 250 } }

        Row {
            id: bannerRow
            anchors.centerIn: parent
            spacing: 8

            Row {
                spacing: 4
                visible: billAcceptor.reconnecting
                Repeater {
                    model: 3
                    Rectangle {
                        width: 6; height: 6; radius: 3
                        color: "#f0c040"
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.2; duration: 350 }
                            NumberAnimation { to: 1.0; duration: 350 }
                        }
                        Component.onCompleted: opacity = index === 0 ? 1.0 : (index === 1 ? 0.6 : 0.2)
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: billAcceptor.reconnecting
                      ? "Đang kết nối lại máy đọc tiền..."
                      : "⚠  Máy đọc tiền chưa kết nối — vào Cài Đặt để cấu hình"
                color: billAcceptor.reconnecting ? "#f0c040" : "#fb923c"
                font.pixelSize: 13
                Behavior on color { ColorAnimation { duration: 250 } }
            }
        }
    }
}
