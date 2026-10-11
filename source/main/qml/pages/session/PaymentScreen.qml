import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../utils/Money.js" as Money
import "../../theme"
import "../../components"

Item {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // ── Public properties ────────────────────────────────────────────────────
    property int    eventId:   -1
    property var    eventData: null
    property int    slotCount: 1        // number of photo slots (from layout)
    property string sessionId: ""
    property int    printCopies: 1      // number of print copies chosen by user
    property string bgOverride: ""
    // -1 = use global payment_enabled; 0/1 = explicit host override.
    property int paymentEnabledOverride: -1

    signal closeClicked()
    signal backClicked()                // quay về trang chọn phương thức thanh toán
    signal paymentSuccess()             // emitted when payment verified
    signal paymentSkipped()             // emitted when payment is disabled / price = 0

    // Chỉ hiện nút "Quay lại" khi có trang chọn phương thức để quay về
    // (bật tiền mặt → có PaymentMethodScreen ở bước trước).
    property bool canGoBack: false

    // ── Public: print option (set by BoothSession from LayoutSelection) ──────
    property string printLabel:   "1 bản"  // label chosen in LayoutSelection
    property int    directPrice:  -1       // -1 = auto-resolve; >=0 = đơn giá 1 bản, sẽ × printCopies
    property int    directTotalPrice: -1   // -1 = bỏ qua; >=0 = TỔNG tiền cố định, dùng thẳng (không × copies)
    property int    directCutMode: -1      // -1 = auto-resolve from eventData; 0=false, 1=true

    // ── Internal state ───────────────────────────────────────────────────────
    property string paymentRef: ""      // e.g. "SEVQRsession123"
    property bool   paid: false
    property bool   checking: false
    property int    pricePerCopy: 0     // giá 1 bản (từ cài đặt)
    property int    price: 0            // tổng tiền = pricePerCopy × printCopies
    property bool   isCut: false        // resolved from eventData + printerConfig
    property string bankId: ""
    property string accountNo: ""
    property string accountName: ""
    property string sePayKey: ""
    property string paymentProvider: "sepay"
    property string payosReturnUrl: ""
    property string payosCancelUrl: ""
    property string payosPaymentId: ""
    property string payosQrData: ""
    property string paymentError: ""

    // ── Resolve settings on load ─────────────────────────────────────────────
    Component.onCompleted: {
        paymentProvider = eventManager.getAppSetting("payment_provider", "sepay")
        if (paymentProvider !== "payos") paymentProvider = "sepay"
        bankId      = eventManager.getAppSetting("payment_bank_id",      "")
        accountNo   = eventManager.getAppSetting("payment_account_no",   "")
        accountName = eventManager.getAppSetting("payment_account_name", "")
        sePayKey    = eventManager.getAppSetting("payment_sepay_key",    "")
        payosReturnUrl = eventManager.getAppSetting("payment_payos_return_url", "https://payos.vn")
        payosCancelUrl = eventManager.getAppSetting("payment_payos_cancel_url", "https://payos.vn")

        // Tài khoản ảo (VA): khi bật và đã nhập số VA → dùng số VA cho QR +
        // hiển thị + validation. VA chung mã NH (bankId) và API Key (sePayKey).
        var vaOn = eventManager.getAppSetting("payment_va_enabled", "false") === "true"
        var vaNo = eventManager.getAppSetting("payment_va_account_no", "")
        if (vaOn && vaNo !== "") {
            accountNo = vaNo
            console.log("[PAYMENT] Dùng tài khoản ảo (VA):", vaNo)
        }

        // Determine cut mode: prefer directCutMode if provided
        if (root.directCutMode >= 0) {
            isCut = root.directCutMode > 0
        } else {
            isCut = (root.eventData && root.eventData.autoCut) && printerConfig.cutMode
        }

        // Tổng tiền:
        // - Ưu tiên directTotalPrice (TỔNG cố định đã tính sẵn ở màn chọn số lượng /
        //   Gallery) → dùng THẲNG, không nhân số bản. Tránh lỗi nhân đôi/×10 khi
        //   giá cài là giá-cố-định-cả-cụm chứ không phải đơn giá/bản.
        // - Ngược lại: tổng = đơn giá/bản × số bản (luồng cũ).
        if (root.directTotalPrice >= 0)
            price = root.directTotalPrice
        else
            price = pricePerCopy * Math.max(1, root.printCopies)

        // Resolve price per copy (chỉ để HIỂN THỊ "Giá 1 bản"):
        // - directPrice >= 0  → đơn giá truyền thẳng.
        // - directTotalPrice >= 0 → suy ra từ TỔNG / số bản, để hiển thị khớp với
        //   số tiền thực thu (tránh hiển thị giá cài đặt cũ, vd 700.000).
        // - Ngược lại → lấy theo cài đặt (price_cut/price_nocut).
        if (root.directPrice >= 0) {
            pricePerCopy = root.directPrice
        } else if (root.directTotalPrice >= 0) {
            pricePerCopy = Math.round(root.directTotalPrice / Math.max(1, root.printCopies))
        } else {
            pricePerCopy = resolveUnitPrice(isCut)
        }

        // Generate payment reference: SEVQR + 6 ký tự suffix ngắn từ sessionId
        // Dùng phần hex cuối của sessionId (hoặc random nếu rỗng)
        var sid = root.sessionId !== "" ? root.sessionId : ""
        var suffix
        if (sid !== "") {
            // sessionId dạng: session_20260416_230533_38F5 → lấy 6 ký tự cuối (bỏ dấu _)
            var clean = sid.replace(/_/g, "")
            suffix = clean.slice(-6).toUpperCase()
        } else {
            suffix = ("" + Math.floor(100000 + Math.random() * 900000))
        }
        paymentRef = paymentProvider === "payos" ? ("B" + suffix) : ("SEVQR" + suffix)

        // If payment not configured or price = 0, skip immediately
        var enabled = root.paymentEnabledOverride >= 0
                      ? root.paymentEnabledOverride > 0
                      : eventManager.getAppSetting("payment_enabled", "false") === "true"

        console.log("[PAYMENT] ========================================")
        console.log("[PAYMENT] Session ID  :", root.sessionId)
        console.log("[PAYMENT] Payment Ref :", paymentRef)
        console.log("[PAYMENT] Price/bản  :", pricePerCopy, "VND")
        console.log("[PAYMENT] Print copies:", root.printCopies)
        console.log("[PAYMENT] Total price :", price, "VND")
        console.log("[PAYMENT] Cut mode    :", isCut)
        console.log("[PAYMENT] Enabled     :", enabled)
        console.log("[PAYMENT] Provider    :", paymentProvider)
        console.log("[PAYMENT] Bank ID     :", bankId)
        console.log("[PAYMENT] Account No  :", accountNo !== "" ? accountNo : "(empty)")
        console.log("[PAYMENT] SePay key   :", sePayKey !== "" ? "(set)" : "(empty - NOT configured)")
        console.log("[PAYMENT] ========================================")

        var missingConfig = paymentProvider === "payos"
            ? (eventManager.getAppSetting("payment_payos_client_id", "") === ""
               || eventManager.getAppSetting("payment_payos_api_key", "") === ""
               || eventManager.getAppSetting("payment_payos_checksum_key", "") === "")
            : (accountNo === "" || bankId === "" || sePayKey === "")

        if (!enabled || price <= 0 || missingConfig) {
            var reason = []
            if (!enabled)         reason.push("payment_enabled=false")
            if (price <= 0)       reason.push("price=0")
            if (paymentProvider === "payos") {
                if (eventManager.getAppSetting("payment_payos_client_id", "") === "") reason.push("payos_client_id empty")
                if (eventManager.getAppSetting("payment_payos_api_key", "") === "") reason.push("payos_api_key empty")
                if (eventManager.getAppSetting("payment_payos_checksum_key", "") === "") reason.push("payos_checksum_key empty")
            } else {
                if (accountNo === "") reason.push("account_no empty")
                if (bankId === "")    reason.push("bank_id empty")
                if (sePayKey === "")  reason.push("sepay_key empty")
            }
            console.log("[PAYMENT] SKIPPING payment. Reason:", reason.join(", "))
            Qt.callLater(function() { root.paymentSkipped() })
            return
        }

        if (paymentProvider === "payos") {
            root._createPayosPayment()
        } else {
            console.log("[PAYMENT] Starting SePay poll every 3s...")
            pollTimer.start()
        }
    }

    Component.onDestruction: {
        pollTimer.stop()
    }

    function _confirmPaid() {
        root.paid = true
        pollTimer.stop()
        successAnim.start()
    }

    function _createPayosPayment() {
        root.checking = true
        root.paymentError = ""
        var res = eventManager.createPayosPayment(root.price, root.paymentRef,
                                                  root.payosReturnUrl, root.payosCancelUrl)
        root.checking = false
        if (!res || !res.ok) {
            root.paymentError = (res && (res.error || res.desc)) ? (res.error || res.desc)
                                                                  : "Không thể tạo thanh toán payOS"
            console.warn("[PAYMENT] payOS create failed:", root.paymentError)
            Qt.callLater(function() { root.paymentSkipped() })
            return
        }
        root.payosPaymentId = res.paymentLinkId !== "" ? res.paymentLinkId : res.orderCode
        root.payosQrData = res.qrCode || ""
        console.log("[PAYMENT] payOS created:", root.payosPaymentId, "| status:", res.status)
        pollTimer.start()
    }

    // ── Helper: resolve unit price (1 bản) theo cut mode ────────────────────
    function resolveUnitPrice(cut) {
        var key = cut ? "price_cut" : "price_nocut"
        var val = parseInt(eventManager.getAppSetting(key, "0"), 10)
        return isNaN(val) ? 0 : val
    }

    // ── VietQR URL ────────────────────────────────────────────────────────────
    property string qrUrl: (accountNo !== "" && bankId !== "")
        ? ("https://img.vietqr.io/image/" + bankId + "-" + accountNo + "-qr_only.png"
           + "?amount=" + price
           + "&addInfo=" + encodeURIComponent(paymentRef)
           + (accountName !== "" ? ("&accountName=" + encodeURIComponent(accountName)) : ""))
        : ""
    property string qrImageSource: paymentProvider === "payos"
        ? (payosQrData !== "" ? ("image://qr/" + encodeURIComponent(payosQrData)) : "")
        : qrUrl

    // ── SePay polling ─────────────────────────────────────────────────────────
    Timer {
        id: pollTimer
        interval: 3000
        repeat: true
        triggeredOnStart: false
        onTriggered: {
            if (root.paid || root.checking) return
            root.checking = true
            if (root.paymentProvider === "payos")
                payosRequest.sendRequest()
            else
                sePayRequest.sendRequest()
        }
    }

    // SePay HTTP GET via XMLHttpRequest
    QtObject {
        id: sePayRequest
        property int pollCount: 0
        function sendRequest() {
            pollCount++
            console.log("[PAYMENT] Poll #" + pollCount + " | ref:", root.paymentRef, "| expected:", root.price, "VND")
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "https://my.sepay.vn/userapi/transactions/list?limit=20", true)
            xhr.setRequestHeader("Authorization", "Bearer " + root.sePayKey)
            xhr.setRequestHeader("Content-Type", "application/json")
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                root.checking = false
                if (xhr.status === 200) {
                    try {
                        var resp = JSON.parse(xhr.responseText)
                        var txns = resp.transactions || resp.data || []
                        console.log("[PAYMENT] SePay returned", txns.length, "transactions")
                        var matched = false
                        for (var i = 0; i < txns.length; i++) {
                            var t = txns[i]
                            var content = (t.transaction_content || t.content || "").toString()
                            var amount  = parseInt(t.amount_in || t.amount || "0", 10)
                            var hasRef  = content.toUpperCase().indexOf(root.paymentRef.toUpperCase()) >= 0
                            console.log("[PAYMENT]   txn["+i+"] amount:", amount,
                                        "| content:", content,
                                        "| hasRef:", hasRef,
                                        "| amountOK:", amount >= root.price)
                            if (hasRef && amount >= root.price) {
                                console.log("[PAYMENT] ✅ MATCH FOUND! Payment confirmed.")
                                root._confirmPaid()
                                matched = true
                                return
                            }
                        }
                        if (!matched) {
                            console.log("[PAYMENT] No match yet. Waiting for ref '"
                                + root.paymentRef + "' with amount >= " + root.price)
                        }
                    } catch (e) {
                        console.warn("[PAYMENT] JSON parse error:", e)
                    }
                } else {
                    console.warn("[PAYMENT] SePay API error HTTP", xhr.status, "-", xhr.responseText.substring(0, 200))
                }
            }
            xhr.send()
        }
    }

    QtObject {
        id: payosRequest
        property int pollCount: 0
        function sendRequest() {
            pollCount++
            console.log("[PAYMENT] payOS poll #" + pollCount + " | id:", root.payosPaymentId)
            var res = eventManager.getPayosPaymentStatus(root.payosPaymentId)
            root.checking = false
            if (!res || !res.ok) {
                root.paymentError = (res && (res.error || res.desc)) ? (res.error || res.desc)
                                                                      : "Không thể kiểm tra payOS"
                console.warn("[PAYMENT] payOS status failed:", root.paymentError)
                return
            }
            var st = (res.status || "").toUpperCase()
            console.log("[PAYMENT] payOS status:", st, "| paid:", res.amountPaid, "| remain:", res.amountRemaining)
            if (st === "PAID" || st === "SUCCEEDED" || st === "SUCCESS") {
                root._confirmPaid()
            } else if (st === "CANCELLED" || st === "EXPIRED") {
                root.paymentError = "Giao dịch payOS đã " + st
                pollTimer.stop()
            }
        }
    }

    // ── Success animation before emitting signal ──────────────────────────────
    SequentialAnimation {
        id: successAnim
        NumberAnimation { target: successOverlay; property: "opacity"; from: 0; to: 1; duration: 300 }
        PauseAnimation  { duration: 1500 }
        ScriptAction    { script: root.paymentSuccess() }
    }

    // ── Theme ─────────────────────────────────────────────────────────────────
    property color bg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    property string backgroundImagePath: {
        if (root.bgOverride !== "") return root.bgOverride
        var s = eventManager.getAppSetting("payment_bg_image", "")
        return s !== "" ? s : "qrc:/assets/bg/payment_qr.png"
    }
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
        z: 0
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundImagePath !== "" ? "transparent" : root.bg
        z: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 0
            spacing: 0

            // Header bar
            Rectangle {
                Layout.fillWidth: true
                height: 64
                color: root._themeSurface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 16

                    // Nút Quay lại / Hủy — LUÔN hiện (trừ khi đã thanh toán xong).
                    // Có trang chọn phương thức → "Quay lại" (backClicked);
                    // không có → "Hủy" (closeClicked, về màn trước đó).
                    Rectangle {
                        visible: !root.paid
                        Layout.preferredWidth: 116
                        Layout.preferredHeight: 40
                        radius: 20
                        color: backMA.pressed ? root._themeBorder : (backMA.containsMouse ? root._themeSurface : root._themeField)
                        border.color: root._themeBorder
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 8
                            Text { text: root.canGoBack ? "‹" : "✕"; color: "#1e7eea"; font.pixelSize: root.canGoBack ? 22 : 16; font.bold: true }
                            Text { text: root.canGoBack ? "Quay lại" : "Hủy"; color: "#1e7eea"; font.pixelSize: 14; font.bold: true }
                        }

                        MouseArea {
                            id: backMA
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.canGoBack) root.backClicked()
                                else                root.closeClicked()
                            }
                        }
                    }

                    Text {
                        text: "Thanh Toán"
                        color: root._themeText
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                    }

                    // Status indicator
                    Rectangle {
                        width: 120; height: 32; radius: 16
                        color: root.paid ? "#1a3a1a" : (root.checking ? "#1a2a3a" : "#2a2030")
                        border.color: root.paid ? "#4caf50" : (root.checking ? "#1e7eea" : "#8a4a9a")
                        border.width: 1
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            BusyIndicator {
                                running: root.checking && !root.paid
                                visible: root.checking && !root.paid
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }
                            Text {
                                text: root.paid ? "✓ Đã thanh toán" : (root.checking ? "Đang kiểm tra" : "Chờ thanh toán")
                                color: root.paid ? "#4caf50" : (root.checking ? "#1e7eea" : "#c080e0")
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }
                    }
                }
            }

            // Main content
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: root.portrait ? 24 : 40
                    spacing: root.portrait ? 24 : 40

                    // Left: QR + amount
                    ColumnLayout {
                        Layout.preferredWidth: parent.width * (root.portrait ? 0.48 : 0.45)
                        Layout.fillHeight: true
                        spacing: 20

                        Text {
                            text: "Quét mã QR để thanh toán"
                            color: Theme.textMuted
                            font.pixelSize: 16
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        // QR code image
                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            width: root.portrait ? 240 : 280; height: width
                            color: "#ffffff"
                            radius: 12

                            Image {
                                id: qrImage
                                anchors.fill: parent
                                anchors.margins: 10
                                source: root.qrImageSource
                                fillMode: Image.PreserveAspectFit
                                // Tải nền (không treo UI) + cache + giới hạn kích thước giải mã
                                // → QR hiện nhanh hơn nhiều so với tải full-res, không cache.
                                asynchronous: true
                                cache: true
                                sourceSize.width: 300
                                sourceSize.height: 300
                                onStatusChanged: {
                                    if (status === Image.Error) {
                                        console.warn("PaymentScreen: Failed to load QR image from", root.qrImageSource)
                                    }
                                }
                            }

                            BusyIndicator {
                                anchors.centerIn: parent
                                running: qrImage.status === Image.Loading
                                visible: running
                            }
                        }

                        // Amount display
                        Rectangle {
                            Layout.fillWidth: true
                            height: 64
                            color: root._themeSurface
                            radius: 10
                            border.color: root._themeBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "Số tiền"
                                    color: Theme.textMuted
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    text: Money.vnd(root.price)
                                    color: "#f0c040"
                                    font.pixelSize: 24
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }

                        // Account info
                        Rectangle {
                            Layout.fillWidth: true
                            color: root._themeSurface
                            radius: 8
                            border.color: root._themeBorder
                            border.width: 1
                            height: bankCol.implicitHeight + 24
                            visible: root.paymentProvider === "sepay"

                            ColumnLayout {
                                id: bankCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                                spacing: 6

                                RowLayout {
                                    spacing: 8
                                    Text { text: "Ngân hàng:"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 100 }
                                    Text { text: root.bankId; color: "#1F2430"; font.pixelSize: 13; font.bold: true }
                                }
                                RowLayout {
                                    spacing: 8
                                    Text { text: "Số TK:"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 100 }
                                    Text { text: root.accountNo; color: "#1F2430"; font.pixelSize: 13 }
                                }
                                RowLayout {
                                    spacing: 8
                                    Text { text: "Chủ TK:"; color: Theme.textMuted; font.pixelSize: 12; Layout.preferredWidth: 100 }
                                    Text { text: root.accountName; color: "#1F2430"; font.pixelSize: 13 }
                                }
                            }
                        }
                    }

                    // Right: instructions + transfer content
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 20

                        Text {
                            text: root.paymentProvider === "payos" ? "Mã đơn hàng" : "Nội dung chuyển khoản"
                            color: Theme.textMuted
                            font.pixelSize: 16
                            font.bold: true
                        }

                        // Transfer content box
                        Rectangle {
                            Layout.fillWidth: true
                            height: 72
                            color: Theme.surface
                            radius: 10
                            border.color: "#86EFAC"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 4
                                Text {
                                    text: root.paymentProvider === "payos" ? "payOS đang theo dõi đơn hàng:" : "Nhập chính xác nội dung sau:"
                                    color: "#4caf50"
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: root.paymentRef
                                    color: "#ffffff"
                                    font.pixelSize: 22
                                    font.bold: true
                                    font.family: "Courier New"
                                }
                            }
                        }

                        // Instructions
                        Rectangle {
                            Layout.fillWidth: true
                            color: Theme.surface
                            radius: 8
                            border.color: "#BFD7FF"
                            border.width: 1
                            height: instrCol.implicitHeight + 24

                            ColumnLayout {
                                id: instrCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                                spacing: 8

                                Text { text: "Hướng dẫn"; color: "#7090d0"; font.pixelSize: 13; font.bold: true }

                                Repeater {
                                    model: [
                                        root.paymentProvider === "payos" ? "1. Mở app ngân hàng và quét mã QR" : "1. Mở app ngân hàng và chọn Chuyển khoản",
                                        root.paymentProvider === "payos" ? "2. Kiểm tra số tiền trên màn hình xác nhận" : "2. Quét mã QR hoặc nhập số tài khoản",
                                        root.paymentProvider === "payos" ? "3. Xác nhận thanh toán" : "3. Nhập số tiền chính xác",
                                        root.paymentProvider === "payos" ? "4. Chờ hệ thống payOS xác nhận" : "4. Nhập nội dung: " + root.paymentRef,
                                        root.paymentProvider === "payos" ? "5. Không tắt màn hình này trước khi thành công" : "5. Xác nhận chuyển khoản"
                                    ]
                                    delegate: Text {
                                        text: modelData
                                        color: Theme.textMuted
                                        font.pixelSize: 12
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        // Polling status
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            BusyIndicator {
                                running: !root.paid
                                Layout.preferredWidth: 20
                                Layout.preferredHeight: 20
                            }
                            Text {
                                text: root.paid ? "Thanh toán thành công!" : "Đang chờ xác nhận thanh toán..."
                                color: root.paid ? "#4caf50" : Theme.textMuted
                                font.pixelSize: 13
                            }
                        }
                    }
                }
            }
        }

        // Success overlay
        Rectangle {
            id: successOverlay
            anchors.fill: parent
            color: "#e0000000"
            opacity: 0
            radius: 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 100; height: 100; radius: 50
                    color: "#1a3a1a"
                    border.color: "#4caf50"; border.width: 3
                    Text {
                        anchors.centerIn: parent
                        text: "✓"
                        color: "#4caf50"
                        font.pixelSize: 56
                        font.bold: true
                    }
                }

                Text {
                    text: "Thanh toán thành công!"
                    color: "#4caf50"
                    font.pixelSize: 28
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: "Đang chuyển sang chụp ảnh..."
                    color: Theme.textMuted
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }
    }
}
