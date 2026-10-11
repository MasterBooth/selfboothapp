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

    property int  totalPrice:  0
    property int  printCopies: 1
    property bool isCut:       false
    property string bgOverride: ""

    signal voucherApplied(string code, string voucherType, int voucherValue)
    // Voucher loại "cash" hợp lệ = đã thanh toán đủ (thay tiền mặt).
    signal voucherPaid(string code, int amount)
    signal skipped()

    property color _bg: Window.window ? Window.window.appBgColor : "#000000"
    property string backgroundImagePath: root.bgOverride !== ""
                                         ? root.bgOverride
                                         : eventManager.getAppSetting("voucher_bg_image", "")
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root._bg, 1.06) }
            GradientStop { position: 1.0; color: Qt.darker(root._bg,  1.40) }
        }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    // ── State ──────────────────────────────────────────────────────────────
    property string _inputRaw:    ""    // 4 chữ số của mã (không tiền tố)
    property string _resultType:  ""
    property int    _resultValue: 0
    property string _errorMsg:    ""
    property bool   _applied:     false

    readonly property int _checkLen: 4    // luôn nhập 4 chữ số
    readonly property int _maxLen:   4

    // ── Dynamic sizing — numpad 3 cột, rộng ~56 % màn hình, tối đa 940 px ─────
    property real _layoutW:  Math.min(root.width * 0.56, 940)
    property real _kbGap:    10
    property real _keyW:     Math.floor((_layoutW - 2 * _kbGap) / 3)
    property real _keyH:     Math.floor(_keyW * 0.62)
    property real _slotW:    Math.max(36, Math.floor(_layoutW * 0.053))
    property real _slotH:    Math.floor(_slotW * 1.44)
    property real _slotFont: Math.max(14, Math.round(_slotW * 0.52))

    // Mã chỉ 4 số, không tiền tố → dùng thẳng chuỗi số đã nhập.
    function _fmt(raw) { return raw }

    function _add(ch) {
        if (root._applied || root._inputRaw.length >= root._maxLen) return
        // Bàn phím tối giản: chỉ nhận chữ số 0–9.
        if (!/^[0-9]$/.test(ch)) return
        root._inputRaw  += ch
        root._errorMsg   = ""
        root._resultType = ""
        // Tự kiểm tra khi đủ số ký tự cần thiết.
        if (root._inputRaw.length >= root._checkLen) _check()
    }

    function _del() {
        if (root._applied || root._inputRaw.length === 0) return
        root._inputRaw   = root._inputRaw.slice(0, -1)
        root._errorMsg   = ""
        root._resultType = ""
    }

    function _check() {
        if (root._inputRaw.length === 0) return
        // Voucher "cash" hợp lệ khi giá trị <= số tiền cần trả (trừ thẳng khi áp dụng).
        var res = eventManager.validateVoucher(_fmt(root._inputRaw), root.totalPrice)
        if (res.valid) {
            root._resultType  = res.type
            root._resultValue = res.value
            root._errorMsg    = ""
        } else {
            root._resultType  = ""
            root._resultValue = 0
            root._errorMsg    = res.error   // "Sai mã voucher" nếu không khớp / không tồn tại
        }
    }

    function _apply() {
        if (!root._resultType || root._applied) return
        root._applied = true
        var code = _fmt(root._inputRaw)
        if (root._resultType === "cash" || root._resultType === "discount") {
            // Voucher tiền/giảm giá: trừ thẳng giá trị. Phủ đủ → thanh toán xong;
            // còn lại → áp dụng rồi tiếp tục thanh toán phần còn lại.
            if (root._resultValue >= root.totalPrice)
                root.voucherPaid(code, root.totalPrice)
            else
                root.voucherApplied(code, root._resultType, root._resultValue)
        } else { // "print"
            root.voucherApplied(code, root._resultType, root._resultValue)
        }
    }

    Timer {
        id: blink; interval: 520; repeat: true
        running: !root._applied
        property bool on: true
        onTriggered: on = !on
    }

    // ── Inline: single character slot ──────────────────────────────────────
    component Slot: Rectangle {
        property int ci: 0
        width: root._slotW; height: root._slotH; radius: 8
        readonly property bool filled: ci < root._inputRaw.length
        readonly property bool active: ci === root._inputRaw.length && !root._applied

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
            font.pixelSize: root._slotFont; font.bold: true
            color: filled ? "#ffffff" : "transparent"
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2; height: Math.round(root._slotH * 0.55); radius: 1; color: "#4FA4F2"
            visible: parent.active && blink.on
        }
    }

    // ── Inline: keyboard key ───────────────────────────────────────────────
    component Key: Rectangle {
        id: k
        property string ch:    ""
        property bool isNum:   false
        property bool isDel:   false
        property bool isClear: false
        signal tap()

        width: root._keyW; height: root._keyH; radius: 10

        color: ma.pressed
             ? (isDel||isClear ? "#7a1a1a" : (isNum ? "#1a3a6e" : "#1e3270"))
             : ma.containsMouse
             ? (isDel||isClear ? "#4a1515" : (isNum ? "#121e38" : "#141e44"))
             : isDel||isClear ? "#120e0e" : (isNum ? "#0e1420" : "#0e1220")

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
            font.pixelSize: k.isDel    ? Math.round(root._keyW * 0.30)
                          : k.isClear  ? Math.round(root._keyW * 0.15)
                          : Math.round(root._keyW * 0.25)
            font.bold: true
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root._applied
            onClicked: k.tap()
        }
    }

    // ── HEADER ─────────────────────────────────────────────────────────────
    Rectangle {
        id: hdr
        width: parent.width; height: 68
        color: Qt.darker(root._bg, 1.50)

        Text {
            anchors.centerIn: parent
            text: "Nhập Mã Voucher"
            color: "#ffffff"; font.pixelSize: 26; font.bold: true
        }

        RowLayout {
            anchors.right: skipRect.left; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text { text: "Số tờ: " + root.printCopies; color: Theme.textMuted; font.pixelSize: 14 }
            Rectangle { width: 1; height: 18; color: Theme.border }
            Text {
                text: Money.vnd(root.totalPrice)
                color: "#f0c040"; font.pixelSize: 16; font.bold: true
            }
        }

        Rectangle {
            id: skipRect
            anchors.right: parent.right; anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 130; height: 42; radius: 21
            color: skipMa.containsMouse ? "#2e3240" : "#20232e"
            border.color: "#353848"; border.width: 1
            Behavior on color { ColorAnimation { duration: 130 } }
            Text { anchors.centerIn: parent; text: "Bỏ qua ›"; color: Theme.textMuted; font.pixelSize: 14; font.bold: true }
            MouseArea { id: skipMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.skipped() }
        }
    }

    // ── CENTERED CONTENT ───────────────────────────────────────────────────
    Item {
        anchors { top: hdr.bottom; bottom: parent.bottom; left: parent.left; right: parent.right }

        ColumnLayout {
            anchors.centerIn: parent
            width: root._layoutW
            spacing: 14

            // ── Code display: 4 ô số (không tiền tố) ──────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: root._slotH + 36; radius: 18
                color: "#0b0e14"
                border.width: 2
                border.color: root._resultType !== "" ? "#3d9e52"
                            : root._errorMsg   !== "" ? "#c84040"
                            : root._inputRaw.length > 0 ? "#1e3a68" : "#181c28"
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Slot { ci: 0 }
                    Slot { ci: 1 }
                    Slot { ci: 2 }
                    Slot { ci: 3 }
                }
            }

            // ── Status bar ──────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 50; radius: 12
                color: root._resultType !== "" ? "#0c1f10"
                     : root._errorMsg   !== "" ? "#1f0c0c"
                     : "#0e1018"
                border.width: root._resultType !== "" || root._errorMsg !== "" ? 1 : 0
                border.color: root._resultType !== "" ? "#3d9e52" : "#c84040"
                Behavior on color        { ColorAnimation { duration: 200 } }
                Behavior on border.color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    font.pixelSize: 15; font.bold: true

                    text: root._applied       ? "✓  Đã áp dụng thành công"
                        : (root._resultType === "cash" || root._resultType === "discount")
                          ? (root._resultValue >= root.totalPrice
                             ? "✓  Voucher trừ " + Money.vnd(root._resultValue) + " — Đã đủ, miễn phí phần còn lại"
                             : "✓  Voucher trừ " + Money.vnd(root._resultValue) + " — Còn lại: " + Money.vnd(root.totalPrice - root._resultValue))
                        : root._resultType === "print"
                          ? "✓  Tặng thêm +" + root._resultValue + " tờ — Tổng in: " + (root.printCopies + root._resultValue) + " tờ"
                        : root._errorMsg !== ""
                          ? "✕  " + root._errorMsg
                        : root._inputRaw.length === 0
                          ? "Nhập 4 số của mã voucher"
                          : "Đang nhập mã..."

                    color: root._applied             ? "#4FA4F2"
                         : root._resultType !== ""   ? "#6ee37a"
                         : root._errorMsg   !== ""   ? "#ef8080"
                         : "#404868"
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }

            // ── Bàn phím số tối giản — 3 cột (1–9, 0, ⌫, Xóa) ─────────────────
            Grid {
                Layout.alignment: Qt.AlignHCenter
                columns: 3
                spacing: root._kbGap

                // Hàng 1–3: 1–9
                Key { ch:"1"; isNum: true; onTap: root._add(ch) }
                Key { ch:"2"; isNum: true; onTap: root._add(ch) }
                Key { ch:"3"; isNum: true; onTap: root._add(ch) }
                Key { ch:"4"; isNum: true; onTap: root._add(ch) }
                Key { ch:"5"; isNum: true; onTap: root._add(ch) }
                Key { ch:"6"; isNum: true; onTap: root._add(ch) }
                Key { ch:"7"; isNum: true; onTap: root._add(ch) }
                Key { ch:"8"; isNum: true; onTap: root._add(ch) }
                Key { ch:"9"; isNum: true; onTap: root._add(ch) }

                // Hàng 4: ⌫ + 0 + Xóa tất cả
                Key { ch:"⌫";  isDel:   true; onTap: root._del() }
                Key { ch:"0"; isNum: true; onTap: root._add(ch) }
                Key { ch:"Xóa\ntất cả"; isClear: true; onTap: { root._inputRaw = ""; root._errorMsg = ""; root._resultType = "" } }
            }

            // ── Apply button ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true; height: 58; radius: 12
                enabled: root._resultType !== "" && !root._applied
                opacity: enabled ? 1.0 : 0.22
                Behavior on opacity { NumberAnimation { duration: 220 } }

                color: appMa.pressed ? "#1e6b26" : (appMa.containsMouse ? "#236030" : "#1a5424")
                border.color: "#3a9a50"; border.width: 1
                Behavior on color { ColorAnimation { duration: 100 } }

                scale: appMa.pressed ? 0.97 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }

                Text {
                    anchors.centerIn: parent
                    text: root._applied ? "✓  Đã áp dụng" : "Áp dụng Voucher  →"
                    color: "#ffffff"; font.pixelSize: 18; font.bold: true
                }
                MouseArea {
                    id: appMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: root._resultType !== "" && !root._applied ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root._apply()
                }
            }
        }
    }
}
