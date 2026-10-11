import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.VirtualKeyboard
import "pages"
import "pages/selfbooth"
import "pages/session"
import "components"
import "theme"

ApplicationWindow {
    id: root
    visible: true
    width: 1600
    height: 900
    minimumWidth: 1024
    minimumHeight: 600
    title: "SelfBooth VN"
    color: Theme.bg

    // Nguồn màu thật nằm ở Theme singleton; các property dưới là binding
    // tương thích ngược cho code cũ tham chiếu Window.window.appBgColor.
    property color  appBgColor:   Theme.bg
    property color  appTextColor: Theme.text
    property color  appSurfaceColor: Theme.surface
    property color  appFieldColor: Theme.field
    property color  appBorderColor: Theme.border

    // ── Ẩn nút điều khiển (⚙ / ✕) trên màn hình khách ────────────────────────
    // Dùng OPACITY chứ không phải visible: QML không lọc input theo alpha, nên
    // nút opacity 0 vẫn bấm được ở đúng vị trí cũ — đó chính là "tàng hình".
    // Nguồn: app setting "chrome_hide_mode" = off | dim | ghost.
    property real appChromeOpacity: 1.0
    property bool appChromeGhost:   false

    function _applyChromeHideMode(mode) {
        root.appChromeGhost   = (mode === "ghost")
        root.appChromeOpacity = (mode === "ghost") ? 0.0
                              : (mode === "dim")   ? 0.25
                                                   : 1.0
    }

    function _mixThemeColor(base, ink, amount) {
        return Qt.rgba(base.r + (ink.r - base.r) * amount,
                       base.g + (ink.g - base.g) * amount,
                       base.b + (ink.b - base.b) * amount,
                       1.0)
    }

    function _isDarkThemeColor(bg) {
        return (bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114) < 0.55
    }

    function _contrastThemeText(bg) {
        return root._isDarkThemeColor(bg) ? "#FFFFFF" : "#1F2430"
    }

    function applyThemeColors(bg, text, surface, field, border) {
        var nextBg = bg || root.appBgColor
        var nextText = root._contrastThemeText(nextBg)
        var nextSurface = root._mixThemeColor(nextBg, nextText, 0.07)
        var nextField = root._mixThemeColor(nextBg, nextText, 0.18)
        var nextBorder = root._mixThemeColor(nextBg, nextText, 0.28)
        Theme.bg = nextBg
        Theme.text = nextText
        Theme.surface = nextSurface
        Theme.field = nextField
        Theme.border = nextBorder
        eventManager.setAppSetting("app_bg_color", nextBg.toString())
        eventManager.setAppSetting("app_text_color", nextText.toString())
        eventManager.setAppSetting("app_surface_color", nextSurface.toString())
        eventManager.setAppSetting("app_field_color", nextField.toString())
        eventManager.setAppSetting("app_border_color", nextBorder.toString())
    }

    // Nền landing page (dùng chung setting với bản photobooth).
    property string landingBgImage: ""
    // Alias cho các trang session dùng chung (PhotoComposition/FilterScreen tham chiếu).
    property string dashboardBgImage: ""

    // ── Startup ───────────────────────────────────────────────────────────────
    Component.onCompleted: {
        // BRAND cố định: theme lấy mặc định từ Theme singleton, KHÔNG đọc từ DB.

        root.landingBgImage = eventManager.getGlobalLandingBackground()

        root._applyChromeHideMode(eventManager.getAppSetting("chrome_hide_mode", "off"))

        root.x = Math.max(0, (Screen.width  - root.width)  / 2)
        root.y = Math.max(0, (Screen.height - root.height) / 2)

        if (eventManager.getAppSetting("fullscreen_on_startup", "false") === "true")
            root.showFullScreen()

        var lvMaxW = parseInt(eventManager.getAppSetting("live_view_max_width",  "0"))
        var lvFps  = parseInt(eventManager.getAppSetting("live_view_target_fps", "30"))
        var fujiLvSize = eventManager.getAppSetting("fuji_live_view_size", "auto")
        var fujiLvQuality = eventManager.getAppSetting("fuji_live_view_quality", "fine")
        cameraController.setMaxLiveViewWidth(lvMaxW)
        cameraController.setTargetLiveViewFps(lvFps)
        cameraController.setFujiLiveViewOptions(fujiLvSize, fujiLvQuality)

        // Nạp cấu hình máy in toàn cục (eventId -1 = slot config chung, không sự kiện).
        printerConfig.loadFromDatabase(-1)

        if (eventManager.getAppSetting("app_open_security_enabled", "false") === "true")
            Qt.callLater(function() { appOpenPinDialog.open() })
    }

    // ── Orientation: "landscape" = 1920×1080, "portrait" = 1080×1920 ──────────
    property string _orientation: eventManager.getAppSetting("selfbooth_orientation", "landscape")

    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "selfbooth_orientation") root._orientation = value
            if (key === "chrome_hide_mode") root._applyChromeHideMode(value)
            if (key === "global_background_enabled" ||
                key === "global_background_image" ||
                key === "landing_background")
                root.landingBgImage = eventManager.getGlobalLandingBackground()
        }
    }

    property real _canvasW: root._orientation === "portrait" ? 1080 : 1920
    property real _canvasH: root._orientation === "portrait" ? 1920 : 1080

    // Alias tương thích cho các trang dùng chung với bản photobooth.
    readonly property bool isPortrait: root._orientation === "portrait"
    readonly property real _designW: root._canvasW
    readonly property real _designH: root._canvasH

    // ── Content scale — letterbox so canvas fits inside window ───────────────
    property real _contentScale: Math.min(root.width / root._canvasW, root.height / root._canvasH)

    Rectangle { anchors.fill: parent; color: root.appBgColor; z: -1 }

    StackView {
        id: stackView
        width:  root._canvasW
        height: root._canvasH
        transformOrigin: Item.TopLeft
        scale: root._contentScale
        x: Math.round((root.width  - root._canvasW * root._contentScale) / 2)
        y: Math.round((root.height - root._canvasH * root._contentScale) / 2)
        initialItem: landingComponent
    }

    // ── Landing page (giống photobooth) → luồng selfbooth ─────────────────────
    Component {
        id: landingComponent
        LandingPage {
            backgroundImage: root.landingBgImage
            onStartClicked: {
                if (!machineAuth.hasCapability("selfbooth")) {
                    root.showUpgradeNotice()
                    return
                }
                stackView.push(welcomeSelfComponent)
            }
            onSettingsClicked: root._openSettingSelfSecure(-1)
        }
    }

    // ── Selfbooth flow ────────────────────────────────────────────────────────
    property var _welcomeRef: null

    Component {
        id: welcomeSelfComponent
        WelcomeSelf {
            onSettingsClicked: root._openSettingSelfSecure(-1)
            onTapToStart: {
                if (!machineAuth.hasCapability("selfbooth")) {
                    root.showUpgradeNotice()
                    return
                }
                // Chế độ phút → chọn gói thời gian; chế độ đếm ngược → vào thẳng
                // (thanh toán giá phiên nếu bật).
                if (eventManager.getAppSetting("selfbooth_minute_mode", "true") === "true") {
                    stackView.push(optionTimeComponent)
                    return
                }
                var price = parseInt(eventManager.getAppSetting("selfbooth_price_session", "0")) || 0
                root._prepareSelfSession(0, price)
                var paymentOn = eventManager.getAppSetting("selfbooth_payment_enabled", "false") === "true"
                if (paymentOn && price > 0)
                    root._proceedSelfPayment()
                else
                    root._startSelfCapture()
            }
            Component.onCompleted: root._welcomeRef = this
        }
    }

    Component {
        id: settingSelfComponent
        SettingSelf {
            onBackClicked: stackView.pop()
            // Mở trang cài đặt photobooth (bản copy PtbSettings) tại tab chỉ định.
            onOpenPtbSettings: function(tab) { root._openPtbSettings(tab) }
        }
    }

    // ── Cài đặt photobooth (copy nguyên trang SettingsPage, eventId -1 = global) ─
    function _pushSettingSelf(selectedTab) {
        if (selectedTab >= 0)
            stackView.push(settingSelfComponent, { "selectedTab": selectedTab })
        else
            stackView.push(settingSelfComponent)
    }

    function _openSettingSelfSecure(selectedTab) {
        if (eventManager.getAppSetting("security_enabled", "false") === "true") {
            settingsPinDialog._pendingAction = "settingSelf"
            settingsPinDialog._pendingTab = selectedTab
            settingsPinDialog.open()
        } else {
            root._pushSettingSelf(selectedTab)
        }
    }

    function _pushPtbSettings(tab) {
        stackView.push(ptbSettingsComponent, {
            "eventData": eventManager.getEventDetails(-1),
            "currentTab": tab
        })
    }

    function _openPtbSettings(tab) {
        root._pushPtbSettings(tab)
    }

    Component {
        id: ptbSettingsComponent
        PtbSettings {
            onBackClicked: stackView.pop()
            // Standalone selfbooth không có luồng launch event — bỏ qua.
            onLaunchClicked: stackView.pop()
        }
    }

    function showUpgradeNotice() { console.log("Upgrade notice suppressed") }

    UpgradeNoticePopup {
        id: entitlementNotice
        onOpenUpgrade: root._openSettingSelfSecure(5)
    }

    AdminPinDialog {
        id: appOpenPinDialog
        parent: Overlay.overlay
        forcePin: true
        subtitle: "Nhập PIN bảo mật để mở BOOTHME"
    }

    AdminPinDialog {
        id: settingsPinDialog
        parent: Overlay.overlay
        forcePin: true
        subtitle: "Nhập PIN bảo mật để vào Cài đặt"
        property string _pendingAction: ""
        property int _pendingTab: -1
        onAccepted: {
            if (_pendingAction === "settingSelf")
                root._pushSettingSelf(_pendingTab)
            _pendingAction = ""
            _pendingTab = -1
        }
        onRejected: {
            _pendingAction = ""
            _pendingTab = -1
        }
    }

    // ── Thanh toán trước khi chụp (tham khảo luồng minute-mode BoothSession) ──
    property int    _selfMinutes: 0
    property int    _selfOriginalPrice: 0
    property int    _selfTotalPrice: 0
    property string _selfSessionId: ""
    property string _selfSessionPath: ""
    property string _selfVoucherCode: ""
    property string _selfVoucherType: ""
    property int    _selfVoucherValue: 0

    function _selfPriceForMinutes(minutes) {
        var times = [
            parseInt(eventManager.getAppSetting("selfbooth_time1", "5")) || 5,
            parseInt(eventManager.getAppSetting("selfbooth_time2", "10")) || 10,
            parseInt(eventManager.getAppSetting("selfbooth_time3", "15")) || 15
        ]
        var prices = [
            parseInt(eventManager.getAppSetting("selfbooth_price1", "0")) || 0,
            parseInt(eventManager.getAppSetting("selfbooth_price2", "0")) || 0,
            parseInt(eventManager.getAppSetting("selfbooth_price3", "0")) || 0
        ]
        var idx = times.indexOf(minutes)
        return idx >= 0 ? prices[idx] : 0
    }

    function _prepareSelfSession(minutes, price) {
        root._selfMinutes = minutes
        root._selfOriginalPrice = Math.max(0, price)
        root._selfTotalPrice = root._selfOriginalPrice
        root._selfVoucherCode = ""
        root._selfVoucherType = ""
        root._selfVoucherValue = 0

        root._selfSessionId = "selfbooth_" + Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")
        var base = eventManager.getAppSetting("sbcut_save_dir", "")
        if (base === "") base = eventManager.getSelfBoothBaseDir()
        root._selfSessionPath = base + "/" + root._selfSessionId
    }

    function _logSelfRevenue(paymentMethod, cashReceived, transferAmount,
                             changeAmount, voucherAmount) {
        var note = root._selfMinutes > 0 ? "Gói chụp " + root._selfMinutes + " phút"
                                         : "Phiên chụp đếm ngược"
        eventManager.logRevenue(-1, "SelfBooth", root._selfSessionId,
            0, root._selfOriginalPrice, cashReceived, transferAmount, changeAmount,
            paymentMethod, "", "selfbooth", note, voucherAmount)
    }

    // Dựng lại stack: về Welcome rồi vào chụp — không để trang thanh toán của
    // khách trước còn nằm dưới stack.
    function _startSelfCapture() {
        if (root._welcomeRef) stackView.pop(root._welcomeRef)
        else                  stackView.pop(null)
        if (eventManager.getAppSetting("selfbooth_minute_mode", "true") === "true") {
            stackView.push(lCaptureSelfComponent, {
                "selectedMinutes": root._selfMinutes,
                "sessionPath": root._selfSessionPath,
                "sessionId": root._selfSessionId
            })
        } else {
            // Chế độ đếm ngược: SelfBoothCapture tự đọc sbcut_photo_count/sbcut_countdown...
            cameraController.setSessionStoragePath(root._selfSessionPath)
            cameraController.setCurrentSessionId(root._selfSessionId)
            stackView.push(selfCaptureComponent, {
                "sessionPath": root._selfSessionPath,
                "sessionId": root._selfSessionId
            })
        }
    }

    function _completeSelfPayment(paymentMethod, cashReceived, transferAmount,
                                  changeAmount, voucherAmount) {
        root._logSelfRevenue(paymentMethod, cashReceived, transferAmount,
                             changeAmount, voucherAmount)
        if (root._selfVoucherCode !== "") {
            eventManager.redeemVoucher(root._selfVoucherCode, root._selfSessionId,
                                       voucherAmount)
        }
        root._selfVoucherCode = ""
        root._selfVoucherType = ""
        root._selfVoucherValue = 0
        root._startSelfCapture()
    }

    function _proceedSelfPayment() {
        if (root._selfTotalPrice <= 0) {
            root._completeSelfPayment("voucher", 0, 0, 0,
                                      Math.max(root._selfVoucherValue, root._selfOriginalPrice))
            return
        }
        stackView.push(selfPaymentMethodComponent)
    }

    Component {
        id: optionTimeComponent
        OptionTime {
            priceOptions: [
                parseInt(eventManager.getAppSetting("selfbooth_price1", "0")) || 0,
                parseInt(eventManager.getAppSetting("selfbooth_price2", "0")) || 0,
                parseInt(eventManager.getAppSetting("selfbooth_price3", "0")) || 0
            ]
            onBackClicked: stackView.pop()
            onTimeSelected: function(minutes) {
                var price = root._selfPriceForMinutes(minutes)
                root._prepareSelfSession(minutes, price)
                var paymentOn = eventManager.getAppSetting("selfbooth_payment_enabled", "false") === "true"
                if (paymentOn && price > 0)
                    root._proceedSelfPayment()
                else
                    root._startSelfCapture()
            }
        }
    }

    // Chọn phương thức thanh toán / voucher
    Component {
        id: selfPaymentMethodComponent
        PaymentMethodScreen {
            totalPrice: root._selfTotalPrice
            copies: 1
            isCut: false
            layoutPath: ""
            bgOverride: eventManager.getAppSetting("selfbooth_bg_payment", "")
            showVoucher: eventManager.getAppSetting("voucher_enabled", "false") === "true"
            showCash: eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
            showBankTransfer: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
            cashCodeEnabled: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"
            allowPrintVoucher: false

            onCloseClicked: stackView.pop()
            onCashSelected: stackView.push(selfCashPaymentComponent)
            onBankTransferSelected: stackView.push(selfBankPaymentComponent)

            onCashCodePaid: function(code, amount) {
                eventManager.redeemCashPaymentCode(code, root._selfSessionId, amount)
                root._completeSelfPayment(
                    "cash", amount, 0, Math.max(0, amount - root._selfTotalPrice),
                    root._selfVoucherValue)
            }

            onVoucherApplied: function(code, voucherType, voucherValue) {
                root._selfVoucherCode = code
                root._selfVoucherType = voucherType
                root._selfVoucherValue = voucherValue
                if (voucherType === "discount" || voucherType === "cash")
                    root._selfTotalPrice = Math.max(0, root._selfTotalPrice - voucherValue)

                if (root._selfTotalPrice <= 0) {
                    root._proceedSelfPayment()
                    return
                }
                var cashEnabled = eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
                var bankEnabled = eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
                if (!cashEnabled && bankEnabled)
                    stackView.push(selfBankPaymentComponent)
            }

            onVoucherPaid: function(code, amount) {
                root._selfVoucherCode = code
                root._selfVoucherValue = amount
                root._completeSelfPayment("voucher", 0, 0, 0, amount)
            }
        }
    }

    // Tiền mặt qua máy đọc tiền
    Component {
        id: selfCashPaymentComponent
        CashPaymentScreen {
            totalPrice: root._selfTotalPrice
            bgOverride: eventManager.getAppSetting("selfbooth_bg_payment", "")
            onCloseClicked: stackView.pop()
            onPaymentComplete: function(received) {
                root._completeSelfPayment(
                    "cash", received, 0, Math.max(0, received - root._selfTotalPrice),
                    root._selfVoucherValue)
            }
        }
    }

    // Chuyển khoản ngân hàng (QR SePay)
    Component {
        id: selfBankPaymentComponent
        PaymentScreen {
            eventId: -1
            eventData: null
            sessionId: root._selfSessionId
            printCopies: 1
            directTotalPrice: root._selfTotalPrice
            directCutMode: 0
            canGoBack: true
            bgOverride: eventManager.getAppSetting("selfbooth_bg_payment", "")
            paymentEnabledOverride: 1

            onCloseClicked: stackView.pop()
            onBackClicked: stackView.pop()
            onPaymentSuccess: {
                root._completeSelfPayment(
                    "transfer", 0, root._selfTotalPrice, 0, root._selfVoucherValue)
            }
            onPaymentSkipped: {
                // Thiếu cấu hình ngân hàng — không được tạo phiên đã trả tiền.
                console.warn("[SelfBoothVN] Bank payment skipped; returning")
                stackView.pop()
            }
        }
    }

    // ── Frame sau khi chụp: chọn frame → ghép ảnh → filter → in → QR ─────────
    property string _selfFrameSessionId: ""
    property var    _selfFramePhotos: []
    property string _selfSelectedFramePath: ""

    // Kết thúc chụp (cả 2 chế độ): có bật frame + có frame + có ảnh → chọn frame;
    // ngược lại → QR luôn (tham khảo BoothSession._finishSelfBoothCapture).
    function _finishSelfCapture(sid, photos) {
        root._selfFrameSessionId = sid
        root._selfFramePhotos = photos || []
        root._selfSelectedFramePath = ""

        var frameOn = eventManager.getAppSetting("selfbooth_frame_enabled", "false") === "true"
        if (!frameOn || root._selfFramePhotos.length === 0 ||
            eventManager.getSelfBoothLayouts().length === 0) {
            root._showSelfQr(sid)
            return
        }
        stackView.pop()   // gỡ trang chụp
        stackView.push(frameSelectionComponent)
    }

    // Về Welcome rồi hiện QR — "Khách tiếp theo" pop về Welcome sạch sẽ.
    function _showSelfQr(sid) {
        if (root._welcomeRef) stackView.pop(root._welcomeRef)
        else                  stackView.pop(null)
        stackView.push(qrcodeSelfComponent, { "sessionId": sid })
    }

    // Upload ảnh ghép lên R2 cùng prefix với ảnh chụp → gallery QR hiện đủ cả hai.
    function _uploadSelfCollage(path) {
        if (!path || path === "" || root._selfFrameSessionId === "") return
        var clean = path.toString()
        if (Qt.platform.os === "windows") clean = clean.replace(/^file:\/{2,3}/, "")
        else                              clean = clean.replace(/^file:\/\//, "")
        clean = decodeURIComponent(clean)
        var hwid = machineAuth.hwid
        if (hwid && hwid !== "")
            s3Uploader.uploadFileWithPath(clean, hwid + "/" + root._selfFrameSessionId + "/collage.jpg")
    }

    Component {
        id: lCaptureSelfComponent
        LCaptureSelf {
            onSessionDone: function(sid, photos) {
                root._finishSelfCapture(sid, photos)
            }
            onCameraFailed: {
                if (root._welcomeRef) stackView.pop(root._welcomeRef)
                else                  stackView.pop(null)
            }
            onCancelClicked: {
                if (root._welcomeRef) stackView.pop(root._welcomeRef)
                else                  stackView.pop(null)
            }
        }
    }

    // Chụp đếm ngược N ảnh (như photobooth) — tự đọc sbcut_photo_count/sbcut_countdown...
    Component {
        id: selfCaptureComponent
        SelfBoothCapture {
            onSessionDone: function(sid, photos) {
                root._finishSelfCapture(sid, photos)
            }
            onCameraFailed: {
                if (root._welcomeRef) stackView.pop(root._welcomeRef)
                else                  stackView.pop(null)
            }
            onCancelClicked: {
                if (root._welcomeRef) stackView.pop(root._welcomeRef)
                else                  stackView.pop(null)
            }
        }
    }

    // Chọn khung frame (nguồn frame selfbooth toàn máy)
    Component {
        id: frameSelectionComponent
        LayoutSelection {
            eventId: -1
            eventData: null
            layoutSource: "selfbooth"
            cutModeFilter: -1
            paymentModeOverride: 1
            countdownEnabled: false
            alwaysShowTitle: true
            titleText: "Chọn Khung Frame"

            onCloseClicked: root._showSelfQr(root._selfFrameSessionId)
            onBackClicked:  root._showSelfQr(root._selfFrameSessionId)
            onLayoutSelected: function(layoutPath, slotCount, printLabel, printPrice, isCut) {
                root._selfSelectedFramePath = layoutPath
                stackView.push(compositionComponent, {
                    "layoutPath": layoutPath,
                    "capturedPhotos": root._selfFramePhotos,
                    "sessionId": root._selfFrameSessionId
                })
            }
        }
    }

    // Ghép ảnh vào frame
    Component {
        id: compositionComponent
        PhotoCompositionScreen {
            eventId: -1
            selfBoothMode: true
            paymentModeOverride: 1
            photoReviewOverride: 0

            onCloseClicked: stackView.pop()
            onBackClicked:  stackView.pop()
            onSessionFinished: function(photos, collagePath, transforms) {
                var filterOn = eventManager.getAppSetting("selfbooth_filter_enabled", "false") === "true"
                // Bật filter là đủ để vào FilterScreen (nơi có nút in + QR),
                // không bắt buộc phải cài sẵn file LUT nào.
                if (filterOn) {
                    stackView.push(filterComponent, {
                        "collagePath": collagePath,
                        "layoutPath": root._selfSelectedFramePath,
                        "photos": photos,
                        "transforms": transforms,
                        "sessionId": root._selfFrameSessionId,
                        "eventId": -1,
                        "hwid": machineAuth.hwid
                    })
                } else {
                    root._uploadSelfCollage(collagePath)
                    root._showSelfQr(root._selfFrameSessionId)
                }
            }
        }
    }

    // Filter làm đẹp + in ảnh (dialog số bản/cắt nằm sẵn trong FilterScreen)
    Component {
        id: filterComponent
        FilterScreen {
            // eventData tổng hợp: FilterScreen đọc paperSize/autoCut/selectedLayout từ đây.
            eventData: ({
                "paperSize": eventManager.getAppSetting("selfbooth_paper_size", "6x4"),
                "autoCut": false,
                "selectedLayout": root._selfSelectedFramePath
            })
            onPrintRequested: function(finalPath, filteredStrip) {
                root._uploadSelfCollage(finalPath)
                root._showSelfQr(root._selfFrameSessionId)
            }
            onCloseClicked: {
                root._uploadSelfCollage(collagePath)
                root._showSelfQr(root._selfFrameSessionId)
            }
        }
    }

    Component {
        id: qrcodeSelfComponent
        QRCodeSelf {
            onBackClicked: {
                if (root._welcomeRef) stackView.pop(root._welcomeRef)
                else                  stackView.pop(null)
            }
            onNextSession: {
                if (root._welcomeRef) stackView.pop(root._welcomeRef)
                else                  stackView.pop(null)
            }
        }
    }

    // ── Apply camera defaults on reconnect ────────────────────────────────────
    Connections {
        target: cameraController
        function onIsConnectedChanged() {
            if (!cameraController.isConnected) return
            // Tôn trọng toggle "Điều khiển qua phần mềm": khi TẮT, không đẩy thông
            // số xuống máy ảnh — để máy ảnh dùng cài đặt trực tiếp trên thân máy.
            if (eventManager.getAppSetting("camera_control_enabled", "false") !== "true") return
            Qt.callLater(function() {
                cameraController.setIso(eventManager.getAppSetting("camera_iso", "200"))
                cameraController.setAperture(eventManager.getAppSetting("camera_aperture", "f/4.5"))
                cameraController.setShutterSpeed(eventManager.getAppSetting("camera_shutter", "1/160"))
                cameraController.setWhiteBalance(eventManager.getAppSetting("camera_wb", "Daylight"))
            })
        }
    }

    // ── Auth popup (same as main app) ─────────────────────────────────────────
    Popup {
        id: authPopup
        modal: true; closePolicy: Popup.NoAutoClose
        parent: Overlay.overlay; anchors.centerIn: parent
        width: 420; height: 260; visible: false

        background: Rectangle { color: "#FFFFFF"; radius: 10; border.color: "#D8E0EC"; border.width: 1 }

        contentItem: ColumnLayout {
            anchors.fill: parent; anchors.margins: 32; spacing: 20

            Text { text: "Xác thực máy"; color: "white"; font.pixelSize: 18; font.bold: true; Layout.alignment: Qt.AlignHCenter }

            CircularLoadingIndicator {
                Layout.alignment: Qt.AlignHCenter
                status: machineAuth.status; size: 52; strokeWidth: 4
                loadingColor: "#7c6af7"; successColor: "#4ade80"
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: {
                    var s = machineAuth.status
                    if (s === 0) return "Đang khởi động..."
                    if (s === 1) return "Đang xác thực máy..."
                    if (s === 2) return "Xác thực thành công!"
                    if (s === 3) return "Máy chưa được kích hoạt"
                    if (s === 4) return "Xác thực thất bại"
                    if (s === 5) return "Lỗi kết nối mạng"
                    return ""
                }
                color: machineAuth.status === 2 ? "#4ade80" : machineAuth.status >= 3 ? "#fb923c" : "#9ca3af"
                font.pixelSize: 14
            }

            Button {
                text: "Thử lại"; Layout.alignment: Qt.AlignHCenter
                visible: machineAuth.status === 4 || machineAuth.status === 5
                onClicked: machineAuth.retryAuthentication()
                background: Rectangle { color: parent.hovered ? "#f97316" : "#ea580c"; radius: 6 }
                contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
            }
        }

        Connections {
            target: machineAuth
            function onAuthenticationCompleted(success) {
                if (success) {
                    authPopup.close()
                    if (!machineAuth.hasCapability("selfbooth"))
                        Qt.callLater(root.showUpgradeNotice)
                }
                else         authPopup.open()
            }
        }
    }

    // ── Global Virtual Keyboard ───────────────────────────────────────────────
    InputPanel {
        id: globalInputPanel
        parent: Overlay.overlay
        z: 9999
        readonly property bool portraitKeyboardHost: parent && parent.width < 760
        width: portraitKeyboardHost ? parent.width : Math.min(parent.width * 0.78, 960)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        visible: Qt.inputMethod.visible
        active:  Qt.inputMethod.visible
    }
}
