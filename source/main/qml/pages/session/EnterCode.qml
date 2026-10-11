import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "../../utils/Money.js" as Money
import "../../components"

// Nhập mã gói chụp trả trước (type='package_code'). Mã 4 số do web/portal tạo.
// Nền trắng; ô mã + bàn phím gọn đặt giữa màn hình. Hai nút Back/Next ở góc dưới
// đồng bộ với các trang khác. Nhập đủ 4 số → tự kiểm tra mã; Next mới bắt đầu dùng mã.
Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080

    property string backgroundImage: ""
    // true = mã gói của studio trên API selfboothvn (mode3): đủ 4 số sẽ check online,
    // mã chỉ được DÙNG (redeem) khi bấm Next -> mã 1 lần không bị mất khi khách gõ.
    property bool cloudCodeMode: false
    // Phiên sẽ dùng mã (gửi kèm redeem để server ghi lượt dùng theo phiên).
    property string sessionId: ""
    property bool _checking: false
    property bool _redeeming: false

    // Ưu tiên hình nền truyền vào; nếu không thì lấy từ cài đặt; cuối cùng ảnh mặc định 3.png.
    readonly property string _effectiveBackground: {
        if (backgroundImage !== "") return backgroundImage
        var s = eventManager.getAppSetting("enter_code_bg_image", "")
        return s !== "" ? s : "qrc:/assets/3.png"
    }

    // code = mã đã nhập; value = giá gói (ghi doanh thu); minutes = thời gian chụp;
    // prints = số bản in; packageName = tên gói (cho ghi chú doanh thu).
    signal codeAccepted(string code, int value, int minutes, int prints, string packageName)
    // cloudCodeMode: kết quả redeem {code, use_id, minutes, price_vnd, kind, source}.
    signal cloudCodeAccepted(var result)
    signal backClicked()

    Connections {
        target: root.cloudCodeMode ? cloudSync : null
        function onCodeCheckFinished(result) {
            if (result.code !== root._checkingCode || result.code !== root._inputRaw) return
            root._checking = false
            if (result.ok) {
                root._valid      = true
                root._pkgMinutes = result.minutes
                root._pkgValue   = result.price_vnd
                root._pkgPrints  = 1
                // Mã của lịch đặt trên web: chào khách theo tên + giờ hẹn.
                root._pkgName    = result.booking_customer
                                   ? "Xin chào " + result.booking_customer + " · lịch " + result.booking_time
                                   : "Mã " + result.code
                root._errorMsg   = ""
                root._checkedCode = result.code
                return
            }
            root._valid       = false
            root._pkgValue    = 0
            root._pkgMinutes  = 0
            root._pkgPrints   = 1
            root._pkgName     = ""
            root._checkedCode = ""
            root._errorMsg    = result.message || "Mã không hợp lệ"
        }

        function onCodeRedeemFinished(result) {
            if (!root._redeeming) return
            root._redeeming = false
            if (result.ok) {
                root._pkgMinutes = result.minutes
                root._pkgValue   = result.price_vnd
                root.cloudCodeAccepted(result)
                return
            }
            // Sai / đã dùng / hết hạn / mất mạng: mở khóa để khách nhập mã khác.
            root._accepted = false
            root._valid    = false
            root._checking = false
            root._inputRaw = ""
            root._errorMsg = result.message || "Không kiểm tra được mã"
        }
    }

    color: "#ffffff" 

    function resolveImageSource(path) {
        if (!path || path === "")
            return ""
        if (path.indexOf("file:") === 0 || path.indexOf("qrc:") === 0 || path.indexOf("http") === 0)
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root._effectiveBackground
        visible: root._effectiveBackground !== ""
    }

    // ── State ──────────────────────────────────────────────────────────────
    property string _inputRaw:   ""     // 4 chữ số của mã
    property bool   _valid:      false  // true = mã hợp lệ → cho bấm Next
    property int    _pkgValue:   0
    property int    _pkgMinutes: 0
    property int    _pkgPrints:  1
    property string _pkgName:    ""
    property string _errorMsg:   ""
    property bool   _accepted:   false  // đã bấm Next, khóa nhập
    property string _checkingCode: ""
    property string _checkedCode:  ""
    property bool   _localPackageCode: false

    readonly property int _checkLen: 4
    readonly property int _maxLen:   4

    // ── Kích thước responsive: màn dọc cần vùng nhập lớn, dễ bấm và nằm giữa.
    readonly property bool _portrait: root.height > root.width
    property real _kbW:    Math.min(root.width - 48, Math.max(300, _portrait ? Math.min(root.width * 0.72, 640)
                                                                             : Math.min(root.width * 0.30, 460)))
    property real _gap:    _portrait ? 16 : 12
    property real _keyW:   Math.floor((_kbW - 2 * _gap) / 3)
    property real _keyH:   Math.floor(_keyW * (_portrait ? 0.64 : 0.56))
    property real _slotW:  Math.floor(_keyW * (_portrait ? 0.72 : 0.78))
    property real _slotH:  Math.floor(_slotW * (_portrait ? 1.18 : 1.28))
    property real _slotFont: Math.max(20, Math.round(_slotW * 0.6))
    property real _titleFont: _portrait ? Math.max(44, Math.min(root.width * 0.075, 64)) : 40
    property real _hintFont:  _portrait ? Math.max(22, Math.min(root.width * 0.04, 32)) : 20

    function _add(ch) {
        if (root._accepted || root._inputRaw.length >= root._maxLen) return
        if (!/^[0-9]$/.test(ch)) return
        root._inputRaw += ch
        root._errorMsg  = ""
        root._valid     = false
        root._localPackageCode = false
        root._checkedCode = ""
        if (root._inputRaw.length >= root._checkLen) _check()
    }

    function _del() {
        if (root._accepted || root._inputRaw.length === 0) return
        root._inputRaw = root._inputRaw.slice(0, -1)
        root._errorMsg  = ""
        root._valid     = false
        root._checking  = false
        root._checkingCode = ""
        root._checkedCode  = ""
        root._localPackageCode = false
    }

    function _clear() {
        if (root._accepted) return
        root._inputRaw = ""
        root._errorMsg = ""
        root._valid    = false
        root._checking = false
        root._checkingCode = ""
        root._checkedCode  = ""
        root._localPackageCode = false
    }

    // Xóa sạch trạng thái (kể cả khóa _accepted). Gọi mỗi khi trang được kích hoạt
    // lại — vd bấm X ở CaptureScreen quay về đây: mã cũ đã redeem nên phải nhập mã mới.
    function _reset() {
        root._inputRaw   = ""
        root._valid      = false
        root._pkgValue   = 0
        root._pkgMinutes = 0
        root._pkgPrints  = 1
        root._pkgName    = ""
        root._errorMsg   = ""
        root._accepted   = false
        root._checking   = false
        root._redeeming  = false
        root._checkingCode = ""
        root._checkedCode  = ""
        root._localPackageCode = false
    }

    StackView.onActivated: root._reset()

    function _check() {
        if (root._inputRaw.length === 0) return
        if (root.cloudCodeMode) {
            root._valid       = false
            root._checkedCode = ""
            root._localPackageCode = false
            root._pkgValue    = 0
            root._pkgMinutes  = 0
            root._pkgPrints   = 1
            root._pkgName     = ""
            if (!/^[0-9]{4}$/.test(root._inputRaw)) {
                root._checking = false
                root._checkingCode = ""
                root._errorMsg = "Mã gồm đúng 4 chữ số"
                return
            }
            var localRes = eventManager.validateLocalPackageCode(root._inputRaw)
            if (localRes.valid) {
                root._valid       = true
                root._localPackageCode = true
                root._checkedCode = root._inputRaw
                root._pkgValue    = localRes.value
                root._pkgMinutes  = localRes.package_minutes
                root._pkgPrints   = Math.max(1, localRes.package_prints)
                root._pkgName     = localRes.package_name
                root._checking    = false
                root._checkingCode = ""
                root._errorMsg    = ""
                return
            }
            root._checking = true
            root._checkingCode = root._inputRaw
            root._errorMsg = ""
            cloudSync.checkCode(root._inputRaw)
            return
        }
        var res = eventManager.validatePackageCode(root._inputRaw)
        if (res.valid) {
            root._valid      = true
            root._pkgValue   = res.value
            root._pkgMinutes = res.package_minutes
            root._pkgPrints  = Math.max(1, res.package_prints)
            root._pkgName    = res.package_name
            root._errorMsg   = ""
        } else {
            root._valid    = false
            root._pkgValue = 0
            root._errorMsg = res.error
        }
    }

    function _accept() {
        if (!root._valid || root._accepted || root._checking) return
        root._accepted = true
        if (root.cloudCodeMode) {
            if (root._localPackageCode) {
                var localUse = eventManager.redeemLocalPackageCode(root._inputRaw, root.sessionId, root._pkgValue)
                if (!localUse.ok) {
                    root._accepted = false
                    root._valid = false
                    root._localPackageCode = false
                    root._errorMsg = localUse.error || "Mã gói chụp này đã được sử dụng"
                    return
                }
                root.cloudCodeAccepted({
                    "ok": true,
                    "code": localUse.code || root._inputRaw,
                    "use_id": localUse.use_id || "",
                    "minutes": localUse.minutes || root._pkgMinutes,
                    "price_vnd": localUse.price_vnd || root._pkgValue,
                    "kind": localUse.kind || "local",
                    "source": localUse.source || "local"
                })
                return
            }
            root._redeeming = true
            root._errorMsg = ""
            cloudSync.redeemCode(root._inputRaw, root.sessionId)
            return
        }
        root.codeAccepted(root._inputRaw, root._pkgValue, root._pkgMinutes,
                          root._pkgPrints, root._pkgName)
    }

    Timer {
        id: blink; interval: 520; repeat: true
        running: !root._accepted
        property bool on: true
        onTriggered: on = !on
    }

    // ── Inline: một ô số ────────────────────────────────────────────────────
    component Slot: Rectangle {
        property int ci: 0
        width: root._slotW; height: root._slotH; radius: 12
        readonly property bool filled: ci < root._inputRaw.length
        readonly property bool active: ci === root._inputRaw.length && !root._accepted

        // Ô nền tối trên nền trắng → chữ số màu sáng, nổi bật rõ.
        color: "#2b3040"
        border.width: 2
        border.color: active       ? "#ad436d"
                    : root._valid  ? "#3d9e52"
                    : root._errorMsg !== "" ? "#c84040"
                    : "#d2d6e0"
        Behavior on border.color { ColorAnimation { duration: 160 } }

        Text {
            anchors.centerIn: parent
            text: ci < root._inputRaw.length ? root._inputRaw[ci] : ""
            font.pixelSize: root._slotFont; font.bold: true; font.family: "Courier New"
            color: "#ffffff"
        }

        Rectangle {
            anchors.centerIn: parent
            width: 2; height: Math.round(root._slotH * 0.5); radius: 1; color: "#ad436d"
            visible: parent.active && blink.on
        }
    }

    // ── Inline: phím ─────────────────────────────────────────────────────────
    component Key: Rectangle {
        id: k
        property string ch:    ""
        property bool isNum:   false
        property bool isDel:   false
        property bool isClear: false
        signal tap()

        width: root._keyW; height: root._keyH; radius: 12

        color: ma.pressed     ? (isDel||isClear ? "#f0d6d6" : "#e2e6ee")
             : ma.containsMouse ? (isDel||isClear ? "#faeaea" : "#eef1f6")
             : "#f6f7fa"
        border.color: ma.containsMouse ? (isDel||isClear ? "#d98a8a" : "#ad436d") : "#dcdfe7"
        border.width: 1
        Behavior on color { ColorAnimation { duration: 60 } }

        scale: ma.pressed ? 0.9 : 1.0
        Behavior on scale { NumberAnimation { duration: 75; easing.type: Easing.OutQuad } }

        Text {
            anchors.centerIn: parent
            text: k.ch
            color: k.isDel||k.isClear ? "#c0392b" : "#333a4a"
            font.pixelSize: k.isDel   ? Math.round(root._keyW * 0.34)
                          : k.isClear ? Math.round(root._keyW * 0.17)
                          : Math.round(root._keyW * 0.30)
            font.bold: true
            font.family: (k.isDel || k.isClear) ? "" : "Courier New"
            horizontalAlignment: Text.AlignHCenter
        }

        MouseArea {
            id: ma; anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !root._accepted
            onClicked: k.tap()
        }
    }

    // ── Nội dung giữa màn hình ───────────────────────────────────────────────
    Column {
        anchors.centerIn: parent
        width: Math.min(root.width - 32, root._kbW + 80)
        spacing: root._portrait ? 26 : 22

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Nhập mã gói chụp"
            color: "#2b3040"
            font.pixelSize: root._titleFont; font.bold: true; font.family: "Raleway"
        }

        // 4 ô số, đặt giữa
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: root._portrait ? 16 : 12
            Slot { ci: 0 }
            Slot { ci: 1 }
            Slot { ci: 2 }
            Slot { ci: 3 }
        }

        // Dòng trạng thái: thông tin gói / lỗi / gợi ý
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(root.width - 32, root._kbW + 120)
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            font.pixelSize: root._hintFont; font.bold: true
            text: root._redeeming
                  ? "Đang xác nhận mã..."
                : root._checking
                  ? "Đang kiểm tra mã..."
                : root.cloudCodeMode && root._valid
                  ? "✓  Mã hợp lệ · " + root._pkgMinutes + " phút · " + Money.vnd(root._pkgValue) + " · bấm Next để chụp"
                : root._valid
                  ? "✓  " + (root._pkgName !== "" ? root._pkgName + " — " : "")
                    + root._pkgMinutes + " phút · " + root._pkgPrints + " tờ · "
                    + Money.vnd(root._pkgValue)
                : root._errorMsg !== ""
                  ? "×  " + root._errorMsg
                : root._inputRaw.length === 0
                  ? "Nhập 4 số của mã gói chụp"
                  : "Đang nhập mã..."
            color: root._valid           ? "#2e7d32"
                 : root._errorMsg !== ""  ? "#c0392b"
                 : root._checking || root._redeeming ? "#7A4B2A"
                 : "#8a8f9c"
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // Bàn phím số gọn — 3 cột (1–9, ⌫, 0, Xóa)
        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 3
            spacing: root._gap

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
            Key { ch:"Xóa"; isClear: true; onTap: root._clear() }
        }
    }

    // ── Nút Back (góc dưới trái) — đồng bộ các trang khác ─────────────────────
    Item {
        id: backPill
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: backMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "‹"; color: "#7A4B2A"
                opacity: backMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back"; color: "#7A4B2A"
                opacity: backMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.backClicked()
        }
    }

    // ── Nút Next (góc dưới phải) — chỉ bật khi mã hợp lệ ──────────────────────
    Item {
        id: nextPill
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        enabled: root._valid && !root._accepted && !root._checking && !root._redeeming
        opacity: enabled ? 1.0 : 0.3
        Behavior on opacity { NumberAnimation { duration: 200 } }

        scale: nextMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "›"; color: "#ad436d"
                opacity: nextMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Next"; color: "#ad436d"
                opacity: nextMouse.containsMouse ? 1.0 : 0.9
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: nextMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: root._valid && !root._accepted && !root._checking && !root._redeeming
            cursorShape: Qt.PointingHandCursor
            onClicked: root._accept()
        }
    }
}
