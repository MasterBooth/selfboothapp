import QtQuick
import QtQuick.Controls
import "session"
import "selfbooth"
import "../components"
import "../theme"

Item {
    id: root

    // Public Properties
    property int eventId: -1
    property var eventData: null
    property string sessionId: ""  // Track current session ID for S3 upload
    property int pendingRetakeIndex: -1  // Index cá»§a áº£nh vá»«a Ä‘Æ°á»£c retake (-1 = khÃ´ng cÃ³)
    property int pendingSlotCount: 1    // Slot count saved from layout selection
    property var _pendingPhotos: []     // Photos held while FilterScreen is shown
    property var _pendingTransforms: [] // Transforms held while FilterScreen is shown
    property var allCapturedPhotos: [] // ALL photos captured this session (for S3 individual upload)
    property var _retakeDiscardedPhotos: []
    property string _videoRequestedSessionId: ""
    property var _deferredIndividualPhotos: []
    property int _deferredIndividualEventId: -1
    property string _deferredIndividualSessionId: ""
    property bool _deferredIndividualFilterRunning: false

    // â”€â”€ Payment flow state (lÆ°u xuyÃªn suá»‘t cÃ¡c bÆ°á»›c khi payment báº­t) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    property bool   _paymentEnabled: false        // Ä‘á»c 1 láº§n khi session báº¯t Ä‘áº§u
    property string _operationMode: "mode1"
    property bool   _selectedCutMode: false       // BÆ°á»›c 1: CutModeScreen
    property string _selectedCategory: ""         // BÆ°á»›c 1 (cháº¿ Ä‘á»™ nhÃ³m): CutModeScreen
    property int    _selectedCategoryPrice: -1    // Giá nhóm frame khi bật pricing_by_category_enabled
    property string _selectedLayoutPath: ""       // BÆ°á»›c 2: LayoutSelection
    property int    _selectedLayoutSlots: 3       // BÆ°á»›c 2: LayoutSelection
    property int    _selectedPrintCopies: 2       // BÆ°á»›c 3: PrintQuantityScreen
    property int    _selectedTotalPrice: 0        // BÆ°á»›c 3: tá»•ng tiá»n (Ä‘á»ƒ truyá»n vÃ o PaymentMethodScreen)
    property int    _selectedOriginalTotalPrice: 0
    property var    _capturedPhotosAwaitingLayout: []
    // GÃ³i chá»¥p Ä‘Ã£ chá»n (phÃºt) â†’ giá»›i háº¡n thá»i gian phiÃªn chá»¥p trong CaptureScreen.
    property int    _selectedPackageMinutes: 0
    // true = Ä‘ang trong luá»“ng gÃ³i chá»¥p (chá»¥p trÆ°á»›c â†’ chá»n frame â†’ ghÃ©p â†’ in 1 báº£n).
    property bool   _packageFlow: false

    // Ma goi chup tra truoc (prepaid package code): bat toggle -> bo qua han Waiting,
    // vao thang EnterCode lam man dau. _prepaidCode: "" = khong dung ma goi.
    // Doc ngay khi khoi tao de StackView.initialItem chon dung man.
    property bool   _prepaidPackageEnabled: eventManager.getAppSetting("prepaid_package_enabled", "false") === "true"
    property string _prepaidCode:           ""

    // Mode3: ma goi 4 so cua studio kiem tra qua API selfboothvn (cloudSync.redeemCode).
    // Chan xac nhan ma nhieu lan -> mo trung CaptureScreen / ghi trung doanh thu.
    property bool   _mode3CodeStarting:     false

    //â”€â”€ Voucher state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    property bool   _voucherEnabled: false        // Ä‘á»c tá»« settings
    property string _voucherCode:    ""           // "" = khÃ´ng cÃ³ voucher
    property string _voucherType:    ""           // "discount" | "print"
    property int    _voucherValue:   0

    // â”€â”€ Selfbooth (sbcut) â€” lÆ°u session camera chÃ­nh Ä‘á»ƒ khÃ´i phá»¥c sau sub-flow â”€
    // cameraController.setSessionStoragePath/setCurrentSessionId lÃ  GLOBAL nÃªn
    // nhÃ¡nh selfbooth Ä‘á»•i táº¡m, pháº£i khÃ´i phá»¥c láº¡i á»Ÿ má»i lá»‘i thoÃ¡t.
    property string _mainSessionPath: ""
    property string _mainSessionId:   ""

    // â”€â”€ Selfbooth minute-mode payment state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    property int    _selfMinutes: 0
    property int    _selfOriginalPrice: 0
    property int    _selfTotalPrice: 0
    property string _selfSessionId: ""
    property string _selfSessionPath: ""
    property string _selfVoucherCode: ""
    property string _selfVoucherType: ""
    property int    _selfVoucherValue: 0
    property string _selfFrameSessionId: ""
    property var    _selfFramePhotos: []
    property string _selfSelectedFramePath: ""
    property int    _selfSelectedFrameSlots: 0

    property var _modeSelectionRef: null

    signal exitSession()

    // KhÃ´i phá»¥c path/id cá»§a session chÃ­nh cho camera (idempotent).
    function _restoreMainCameraSession() {
        if (_mainSessionPath !== "") cameraController.setSessionStoragePath(_mainSessionPath)
        if (_mainSessionId   !== "") cameraController.setCurrentSessionId(_mainSessionId)
    }

    // Ãp dá»¥ng lÆ°u trá»¯ theo PHIÃŠN: áº£nh gá»‘c má»—i phiÃªn vÃ o folder con Originals/<sessionId>/.
    // (áº¢nh ghÃ©p Final/<sessionId>/ do EventManager tá»± tÃ¡ch theo sessionId truyá»n vÃ o.)
    function _applySessionStorage(sid) {
        root._mainSessionId   = sid
        root._mainSessionPath = (root.eventData && root.eventData.rawPath)
                                ? (root.eventData.rawPath + "/" + sid) : ""
        if (root._mainSessionPath !== "")
            cameraController.setSessionStoragePath(root._mainSessionPath)
        cameraController.setCurrentSessionId(sid)
    }

    function _clearVoucherState() {
        root._voucherCode  = ""
        root._voucherType  = ""
        root._voucherValue = 0
    }

    function _voucherRevenueNote(extra) {
        if (root._voucherCode !== "")
            return "Voucher code: " + root._voucherCode
        return extra || ""
    }

    function _selfPriceForMinutes(minutes) {
        var times = [
            parseInt(eventManager.getAppSetting("sbcut_time1", "5")) || 5,
            parseInt(eventManager.getAppSetting("sbcut_time2", "10")) || 10,
            parseInt(eventManager.getAppSetting("sbcut_time3", "15")) || 15
        ]
        var prices = [
            parseInt(eventManager.getAppSetting("sbcut_price1", "0")) || 0,
            parseInt(eventManager.getAppSetting("sbcut_price2", "0")) || 0,
            parseInt(eventManager.getAppSetting("sbcut_price3", "0")) || 0
        ]
        var idx = times.indexOf(minutes)
        return idx >= 0 ? prices[idx] : 0
    }

    function _prepareSelfMinuteSession(minutes, price) {
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

    function _logSelfMinuteRevenue(paymentMethod, cashReceived, transferAmount,
                                   changeAmount, voucherAmount) {
        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
        var noteSelf = "GÃ³i chá»¥p " + root._selfMinutes + " phÃºt"
        var noteMain = "Chá»¥p selfbooth - gÃ³i " + root._selfMinutes + " phÃºt"
        eventManager.logRevenue(root.eventId, evName, root._selfSessionId,
            0, root._selfOriginalPrice, cashReceived, transferAmount, changeAmount,
            paymentMethod, "", "selfbooth", noteSelf, voucherAmount)
        eventManager.logRevenue(root.eventId, evName, root._selfSessionId,
            0, root._selfOriginalPrice, cashReceived, transferAmount, changeAmount,
            paymentMethod, "", "session", noteMain, voucherAmount)
    }

    function _startSelfMinuteCapture() {
        // Rebuild the Selfbooth stack so "KhÃ¡ch tiáº¿p theo" returns to its waiting page,
        // never to a payment screen from the previous customer.
        sessionStack.pop(null)
        sessionStack.push(selfBoothWaitingComponent)
        sessionStack.push(selfBoothMinuteCaptureComponent, {
            selectedMinutes: root._selfMinutes,
            sessionPath: root._selfSessionPath,
            sessionId: root._selfSessionId
        })
    }

    function _completeSelfMinutePayment(paymentMethod, cashReceived, transferAmount,
                                        changeAmount, voucherAmount) {
        root._logSelfMinuteRevenue(paymentMethod, cashReceived, transferAmount,
                                   changeAmount, voucherAmount)
        if (root._selfVoucherCode !== "") {
            eventManager.redeemVoucher(root._selfVoucherCode, root._selfSessionId,
                                       voucherAmount)
        }
        root._selfVoucherCode = ""
        root._selfVoucherType = ""
        root._selfVoucherValue = 0
        root._startSelfMinuteCapture()
    }

    function _proceedSelfMinutePayment() {
        if (root._selfTotalPrice <= 0) {
            root._completeSelfMinutePayment("voucher", 0, 0, 0,
                                            Math.max(root._selfVoucherValue, root._selfOriginalPrice))
            return
        }
        // Selfbooth always shows the method screen first, even when bank transfer
        // is the only enabled option, so customers can explicitly choose/cancel.
        sessionStack.push(selfBoothPaymentMethodComponent)
    }

    function _selfFrameEnabled() {
        return eventManager.getAppSetting("sbcut_frame_enabled", "false") === "true"
    }

    function _showSelfBoothQr(sessionId) {
        if (sessionStack.busy) return
        sessionStack.pop(null)
        sessionStack.push(selfBoothWaitingComponent)
        sessionStack.push(selfBoothQrComponent, { sessionId: sessionId })
    }

    function _finishSelfBoothCapture(sessionId, photos) {
        root._selfFrameSessionId = sessionId
        root._selfFramePhotos = photos || []
        root._selfSelectedFramePath = ""
        root._selfSelectedFrameSlots = 0

        if (!root._selfFrameEnabled()
                || root._selfFramePhotos.length === 0
                || eventManager.getSelfBoothLayouts().length === 0) {
            root._showSelfBoothQr(sessionId)
            return
        }

        if (sessionStack.busy) return
        sessionStack.pop()
        sessionStack.push(selfBoothFrameSelectionComponent)
    }

    function _uploadSelfBoothCollage(path) {
        if (!path || path === "" || root._selfFrameSessionId === "") return
        var clean = path.toString()
        if (Qt.platform.os === "windows")
            clean = clean.replace(/^file:\/{2,3}/, "")
        else
            clean = clean.replace(/^file:\/\//, "")
        clean = decodeURIComponent(clean)
        var hwid = machineAuth.hwid
        if (hwid && hwid !== "")
            s3Uploader.uploadFileWithPath(
                clean, hwid + "/" + root._selfFrameSessionId + "/collage.jpg")
    }

    // -------------------------------------------------------------------------
    // Navigation Helpers
    // -------------------------------------------------------------------------

    // Level-based navigation:
    // Level 0: Dashboard (exitSession)
    // Level 1: ModeSelection (initial item in sessionStack)
    // Level 2+: Session screens (LayoutSelection, CaptureScreen, etc.)

    // Ãp cháº¿ Ä‘á»™ chá»¥p theo toggle "chá»¥p theo máº«u" cá»§a nhÃ³m Ä‘Ã£ chá»n.
    // Báº­t theo máº«u â†’ shootingMode = 2 (template).
    // Táº¯t â†’ manual (mode 1) máº·c Ä‘á»‹nh 6 áº£nh.
    // Cáº­p nháº­t DB + reload eventData Ä‘á»ƒ CaptureScreen Ä‘á»c Ä‘Ãºng.
    function _applyCategoryShootingMode(cat) {
        if (!root.eventData || root.eventId <= 0) return
        var tpl = eventManager.getAppSetting("cate_template_" + cat, "false") === "true"
        var mode = tpl ? 2 : 1
        var currentManualCount = parseInt(root.eventData.manualPhotoCount) || 0
        var cnt  = currentManualCount > 0 ? currentManualCount : 6
        if (eventManager.updateShootingMode(root.eventId, mode, cnt))
            root.eventData = eventManager.getEventDetails(root.eventId)
    }

    function _usePostCaptureFrameSelectionFlow() {
        var shootingMode = root.eventData ? root.eventData.shootingMode : 1
        return !root._paymentEnabled && root._operationMode === "mode1" && shootingMode === 1
    }

    function _isStudioPaymentMode() {
        return root._operationMode === "mode2" || root._operationMode === "mode3"
    }

    function _usesPrepaidCodeFlow() {
        return root._operationMode === "mode1" && root._prepaidPackageEnabled
    }

    function _requestExitSession() {
        var secOn = eventManager.getAppSetting("security_enabled", "false") === "true"
        if (secOn)
            exitPinDialog.open()
        else
            root.exitSession()
    }

    // Toggle "Chá»n khung sau khi chá»¥p" (CÃ i Ä‘áº·t chung). Máº·c Ä‘á»‹nh Báº¬T.
    // Táº®T â†’ chá»¥p xong bá» qua chá»n frame/ghÃ©p/filter/in, sang tháº³ng WaitingResults (QR).
    function _frameSelectionEnabled() {
        return eventManager.getAppSetting("frame_selection_enabled", "true") === "true"
    }

    function _shouldBypassCompositionToWaitingResults() {
        // Mode3: khong dung frame -> chup xong sang thang WaitingResults.
        if (root._operationMode === "mode3")
            return true
        return !root._isStudioPaymentMode() && !root._frameSelectionEnabled()
    }

    function _captureCountFollowsFrame() {
        return eventManager.getAppSetting("capture_count_follow_frame", "true") === "true"
    }

    function _manualCapturePhotoCount(captureConfig) {
        var cfg = captureConfig || root.eventData
        var manualCount = cfg ? (parseInt(cfg.manualPhotoCount) || 0) : 0
        return Math.max(1, manualCount > 0 ? manualCount : 6)
    }

    function _selectedFrameSlotCount(explicitSlotCount, captureConfig) {
        var count = parseInt(explicitSlotCount) || 0
        if (count <= 0)
            return 0

        var cfg = captureConfig || root.eventData
        var layoutPath = cfg && cfg.selectedLayout ? cfg.selectedLayout : root._selectedLayoutPath
        if (!layoutPath)
            return 0

        return count
    }

    function _effectiveCapturePhotoCount(explicitSlotCount) {
        if (root._captureCountFollowsFrame()) {
            var frameCount = root._selectedFrameSlotCount(explicitSlotCount, root.eventData)
            if (frameCount > 0)
                return Math.max(1, frameCount)
        }
        return root._manualCapturePhotoCount(root.eventData)
    }

    function _defaultCapturePhotoCount() {
        return root._effectiveCapturePhotoCount(0)
    }

    function _captureScreenFollowsFrame(explicitSlotCount) {
        return root._captureCountFollowsFrame()
               && root._selectedFrameSlotCount(explicitSlotCount, root.eventData) > 0
    }

    function _pushCaptureScreen(selectedSlotCount) {
        if (sessionStack.busy) return
        var effectiveTotal = root._effectiveCapturePhotoCount(selectedSlotCount)
        sessionStack.push(captureScreenComponent, {
            "totalPhotos": Math.max(1, effectiveTotal),
            "followFramePhotoCount": root._captureScreenFollowsFrame(selectedSlotCount),
            "sessionPath": root._mainSessionPath,
            "sessionId":   root.sessionId,
            "operationMode": root._operationMode
        })
    }

    function _beginFrameSelectionAfterCapture(photos) {
        root._capturedPhotosAwaitingLayout = photos ? photos.slice() : []
        if (sessionStack.busy) return
        sessionStack.push(layoutSelectionComponent)
    }

    // Quay vá» ModeSelection (dÃ¹ng cho cÃ¡c trang Level 2+)
    function navigateToModeSelection() {
        console.log("BoothSession: Navigating back to operation start")
        root._clearVoucherState()
        root._selectedOriginalTotalPrice = 0
        root._capturedPhotosAwaitingLayout = []
        root._packageFlow = false
        root._selectedPackageMinutes = 0
        root._prepaidCode = ""
        root._mode3CodeStarting = false
        if (root._isStudioPaymentMode())
            root._resetToOperationStartScreen()
        else if (root._usesPrepaidCodeFlow())
            root._resetToEnterCode()
        else
            root._resetToModeSelection()
    }

    function _showModeSelectionFromWaiting() {
        if (sessionStack.busy) return
        var item = sessionStack.push(modeSelectionComponent)
        if (item)
            root._modeSelectionRef = item
    }

    function _pushOperationStartScreen() {
        if (sessionStack.busy) return false
        if (root._operationMode === "mode2") {
            sessionStack.push(cutModeScreenComponent)
            return true
        }
        if (root._operationMode === "mode3")
            return !!sessionStack.push(enterCodeComponent)
        if (root._usesPrepaidCodeFlow())
            return !!sessionStack.push(enterCodeComponent)
        root._showModeSelectionFromWaiting()
        return true
    }

    // Quay ve EnterCode (dung cho luong ma tra truoc: chup lai luot moi = nhap ma moi).
    function navigateToEnterCode() {
        console.log("BoothSession: Navigating back to EnterCode (prepaid flow)")
        root._clearVoucherState()
        root._selectedOriginalTotalPrice = 0
        root._capturedPhotosAwaitingLayout = []
        root._packageFlow = false
        root._selectedPackageMinutes = 0
        root._prepaidCode = ""
        root._resetToEnterCode()
    }

    // Reset stack ve [Waiting, EnterCode]: pop het ve Waiting (initial item) roi push EnterCode.
    function _resetToEnterCode() {
        if (sessionStack.busy) return false
        sessionStack.pop(null)
        return !!sessionStack.push(enterCodeComponent)
    }

    // Luot moi: mode1 co the ve EnterCode/ModeSelection; mode2/3 ve dung man dau cua flow thanh toan.
    function _returnForNextSession() {
        root.navigateToModeSelection()
    }

    // Ma goi chup hop le -> ghi doanh thu (gia goi, prepaid_code), redeem 1 lan, vao chup.
    function _startPrepaidPackage(code, value, minutes, prints, packageName) {
        root._prepaidCode                = code
        root._packageFlow                = true
        root._selectedPackageMinutes     = Math.max(0, minutes)
        root._selectedTotalPrice         = Math.max(0, value)
        root._selectedOriginalTotalPrice = Math.max(0, value)
        root._selectedPrintCopies        = Math.max(1, prints)

        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
        var note = "Prepaid package: " + code + (packageName !== "" ? " (" + packageName + ")" : "")
        eventManager.logRevenue(root.eventId, evName, root.sessionId,
            root._selectedPrintCopies, root._selectedOriginalTotalPrice,
            0, 0, 0, "prepaid_code", "", "session", note, 0)
        eventManager.redeemPackageCode(code, root.sessionId, value)
        root._pushPrepaidCaptureScreen()
    }

    // Luong ma tra truoc: day thang CaptureScreen len tren EnterCode (KHONG qua
    // ModeSelection). Stack = [Waiting, EnterCode, CaptureScreen] -> X ve EnterCode.
    function _pushPrepaidCaptureScreen() {
        if (sessionStack.busy) return
        sessionStack.push(captureScreenComponent, {
            "forceManualPostFlow": true,
            "sessionTimeLimit":    root._selectedPackageMinutes * 60,
            "totalPhotos":         Math.max(1, root._effectiveCapturePhotoCount(0)),
            "followFramePhotoCount": root._captureScreenFollowsFrame(0),
            "sessionPath":         root._mainSessionPath,
            "sessionId":           root.sessionId,
            "operationMode":       root._operationMode
        })
    }

    // Mode3: server (hoac cache ma dung lai khi mat mang) da nhan ma -> ghi doanh thu =
    // gia ma, gan luot dung ma vao phien, roi vao chup tu do toi het gio.
    // Stack = [Waiting, EnterCode, CaptureScreen] -> X ve EnterCode.
    // result = {code, use_id, minutes, price_vnd, kind, source}
    function _startMode3CodeSession(result) {
        if (sessionStack.busy || root._mode3CodeStarting) return
        var current = sessionStack.currentItem
        if (!current || current.cloudCodeMode === undefined) return
        var code = result.code
        var minutes = result.minutes
        var price = Math.max(0, result.price_vnd || 0)
        if (!(minutes > 0)) {
            console.warn("Session: Mode3 code has no capture minutes ->", code)
            return
        }
        root._mode3CodeStarting      = true
        root._prepaidCode            = code
        root._selectedPackageMinutes = minutes
        if (result.use_id)
            eventManager.setSessionCodeUse(root.sessionId, result.use_id)

        var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
        eventManager.logRevenue(root.eventId, evName, root.sessionId,
            0, price, 0, 0, 0, "prepaid_code", "", "session",
            "Ma goi " + code + " (" + result.kind + ", " + minutes + " phut, " + result.source + ")", 0)

        sessionStack.push(captureScreenComponent, {
            "freeCaptureUntilTimeout": true,
            "forceManualPostFlow":     true,
            "sessionTimeLimit":        minutes * 60,
            "totalPhotos":             1,
            "followFramePhotoCount":   false,
            "sessionPath":             root._mainSessionPath,
            "sessionId":               root.sessionId,
            "operationMode":           root._operationMode
        })
    }

    // Tao session moi cho luot ke tiep (sessionId + folder Originals/<sid>).
    function _startNewMainSession() {
        if (root.eventId <= 0) return
        root.sessionId = sessionManager.createSession(root.eventId, machineAuth.hwid)
        root._applySessionStorage(root.sessionId)
        root.allCapturedPhotos = []
        root._retakeDiscardedPhotos = []
        console.log("Session: New session ID ->", root.sessionId)
    }

    function _resetToModeSelection() {
        if (sessionStack.busy) return false
        if (root._modeSelectionRef) {
            sessionStack.pop(root._modeSelectionRef)
            return true
        }
        sessionStack.pop(null)
        var item = sessionStack.push(modeSelectionComponent)
        if (item)
            root._modeSelectionRef = item
        return !!item
    }

    function _resetToOperationStartScreen() {
        if (sessionStack.busy) return false
        root._modeSelectionRef = null
        sessionStack.pop(null)
        if (root._operationMode === "mode2") {
            sessionStack.push(cutModeScreenComponent)
            return true
        }
        // Mode3: het phien -> ve man cho (Waiting la initial item).
        if (root._operationMode === "mode3")
            return true
        if (root._usesPrepaidCodeFlow())
            return !!sessionStack.push(enterCodeComponent)
        var item = sessionStack.push(modeSelectionComponent)
        if (item)
            root._modeSelectionRef = item
        return !!item
    }

    function _pushPaidStudioCaptureScreen() {
        if (sessionStack.busy) return
        var selectedSlotCount = root._packageFlow ? 0 : root._selectedLayoutSlots
        root._modeSelectionRef = null
        sessionStack.pop(null, StackView.Immediate)
        sessionStack.push(captureScreenComponent, {
            "forceManualPostFlow": true,
            "sessionTimeLimit":    root._selectedPackageMinutes * 60,
            "totalPhotos":         Math.max(1, root._effectiveCapturePhotoCount(selectedSlotCount)),
            "followFramePhotoCount": root._captureScreenFollowsFrame(selectedSlotCount),
            "sessionPath":         root._mainSessionPath,
            "sessionId":           root.sessionId,
            "operationMode":       root._operationMode,
            "showCloseButton":     false
        }, StackView.Immediate)
    }

    // VÃ o CaptureScreen cho luá»“ng GÃ“I CHá»¤P: chá»¥p trÆ°á»›c (forceManualPostFlow) rá»“i chá»n
    // frame sau; giá»›i háº¡n thá»i gian = sá»‘ phÃºt gÃ³i Ã— 60. Sá»‘ báº£n in = theo gÃ³i (Ä‘Ã£ set
    // á»Ÿ onPackageSelected), in miá»…n phÃ­.
    function _pushPackageCaptureScreen() {
        if (root._isStudioPaymentMode()) {
            root._pushPaidStudioCaptureScreen()
            return
        }
        if (!root._resetToModeSelection())
            return
        sessionStack.push(captureScreenComponent, {
            "forceManualPostFlow": true,
            "sessionTimeLimit":    root._selectedPackageMinutes * 60,
            "totalPhotos":         Math.max(1, root._effectiveCapturePhotoCount(0)),
            "followFramePhotoCount": root._captureScreenFollowsFrame(0),
            "sessionPath":         root._mainSessionPath,
            "sessionId":           root.sessionId,
            "operationMode":       root._operationMode
        })
    }

    // Chuyá»ƒn sang mÃ n hÃ¬nh thanh toÃ¡n sau khi Ä‘Ã£ xá»­ lÃ½ voucher
    function _proceedToPayment() {
        if (root._selectedTotalPrice <= 0) {
            // Miá»…n phÃ­ (gÃ³i giÃ¡ 0 hoáº·c voucher giáº£m vá» 0) â†’ bá» qua payment.
            if (root._voucherCode !== "") {
                eventManager.redeemVoucher(root._voucherCode, root.sessionId)
                root._clearVoucherState()
            }
            root._pushPackageCaptureScreen()
            return
        }
        var cashEnabled = eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
        var bankEnabled = eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
        // Hiá»‡n trang phÆ°Æ¡ng thá»©c (cÃ³ nháº­p voucher) khi báº­t tiá»n máº·t HOáº¶C voucher.
        // Chá»‰ QR thuáº§n (táº¯t cáº£ hai) â†’ vÃ o tháº³ng trang QR.
        if (cashEnabled || root._voucherEnabled || !bankEnabled) {
            sessionStack.push(paymentMethodScreenComponent)
        } else {
            sessionStack.push(prePaymentScreenComponent)
        }
    }
    
    // Nạp sẵn thumbnail cho FilterScreen (Mode 3). Phải nằm Ở ĐÂY chứ không nằm trong
    // màn nào: nó giữ tham chiếu tới các pixmap đã nạp, màn bị pop là cache mất theo.
    Mode3ThumbPreloader {
        id: mode3ThumbPreloader
    }

    // Session Stack View
    StackView {
        id: sessionStack
        anchors.fill: parent
        initialItem: waitingComponent
        
        pushEnter: Transition {
            PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        pushExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 200 }
        }
        popEnter: Transition {
            PropertyAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        popExit: Transition {
            PropertyAnimation { property: "opacity"; from: 1; to: 0; duration: 200 }
        }
    }
    
    // Config & Warmup on Session Start
    Component.onCompleted: {
        // 0. Read payment & voucher flags once
        root._paymentEnabled  = eventManager.getAppSetting("payment_enabled",  "false") === "true"
        root._voucherEnabled  = eventManager.getAppSetting("voucher_enabled",  "false") === "true"
        root._operationMode   = eventManager.getAppSetting("app_operation_mode", root._paymentEnabled ? "mode2" : "mode1")

        // 1. Táº¡o phiÃªn trÆ°á»›c Ä‘á»ƒ cÃ³ sessionId â†’ lÆ°u trá»¯ áº£nh theo folder con cá»§a phiÃªn.
        if (root.eventId > 0) {
            var hwid = machineAuth.hwid
            root.sessionId = sessionManager.createSession(root.eventId, hwid)
            root._applySessionStorage(root.sessionId)  // Originals/<sessionId>/ + sync camera
            console.log("Session: Created session ID ->", root.sessionId, "| storage ->", root._mainSessionPath)
            console.log("Session: Event ID:", root.eventId, "| HWID:", hwid)
        }

        // Note: Live View runs as a persistent service started in main.cpp
        // No need to start/stop here
        console.log("Session: Live View service should be active")
    }
    
    // -------------------------------------------------------------------------
    // Components
    // -------------------------------------------------------------------------
    
    // 0. Waiting Screen
    Component {
        id: waitingComponent
        Waiting {
            backgroundImage: eventManager.getAppSetting("waiting_bg_image", "")
            onContinueClicked: {
                // mode2/3 vao thang flow thanh toan; chi mode1 moi dung EnterCode/goi chup.
                root._pushOperationStartScreen()
            }
            onBackClicked: {
                root._requestExitSession()
            }
        }
    }
    // 0.5 Nhap ma goi chup tra truoc (chi dung khi prepaid_package_enabled bat)
    Component {
        id: enterCodeComponent
        EnterCode {
            cloudCodeMode: root._operationMode === "mode3"
            sessionId: root.sessionId
            // EnterCode nam tren Waiting -> Back = quay lai Waiting.
            onBackClicked: { if (!sessionStack.busy) sessionStack.pop() }
            onCloudCodeAccepted: function(result) {
                console.log("Session: Mode3 code accepted ->", result.code, "| phut", result.minutes,
                            "| gia", result.price_vnd, "| nguon", result.source)
                root._startMode3CodeSession(result)
            }
            onCodeAccepted: function(code, value, minutes, prints, packageName) {
                console.log("Session: Prepaid package code accepted ->", code,
                            "| gia", value, "| phut", minutes, "| ban in", prints)
                root._startPrepaidPackage(code, value, minutes, prints, packageName)
            }
        }
    }
    // 1. Mode Selection Screen
    Component {
        id: modeSelectionComponent
        ModeSelection {
            backgroundImage: {
                var win = root.Window.window
                if (win && win.globalBackgroundEnabled)
                    return win.globalBackgroundImage
                return root.eventData && root.eventData.modeSelectionBackground
                        ? root.eventData.modeSelectionBackground : ""
            }
            useLiveViewBackground: root.eventData ? !!root.eventData.liveViewBackground : false
            // NÃºt âš™ vÃ o CÃ i Ä‘áº·t chá»‰ hiá»‡n á»Ÿ cháº¿ Ä‘á»™ thanh toÃ¡n (mode2/mode3).
            paymentMode: root._paymentEnabled
            Component.onCompleted: root._modeSelectionRef = this
            Component.onDestruction: {
                if (root._modeSelectionRef === this)
                    root._modeSelectionRef = null
            }
            
            // Báº¥m Back táº¡i ModeSelection (Level 1) = quay láº¡i trang Waiting Ä‘ang
            // náº±m ngay dÆ°á»›i trong stack ([Waiting, ModeSelection]). pop() giá»¯ Ä‘Ãºng
            // instance Waiting cÅ©, khÃ´ng táº¡o báº£n má»›i, khÃ´ng vá» tháº³ng Dashboard.
            onBackClicked: { if (!sessionStack.busy) sessionStack.pop() }
            // Báº¥m X táº¡i ModeSelection (Level 1) = thoÃ¡t session vá» Dashboard.
            // Khi báº£o máº­t báº­t, yÃªu cáº§u nháº­p PIN admin trÆ°á»›c khi cho thoÃ¡t â€”
            // khÃ¡ch khÃ´ng thá»ƒ tá»± Ã½ káº¿t thÃºc session.
            onCloseClicked: {
                var secOn = eventManager.getAppSetting("security_enabled", "false") === "true"
                if (secOn) {
                    exitPinDialog.open()
                } else {
                    root.exitSession()
                }
            }
            // KhÃ¡ch chá»n gÃ³i chá»¥p â†’ lÆ°u thá»i lÆ°á»£ng + giÃ¡ + sá»‘ báº£n in, sang thanh toÃ¡n.
            onPackageSelected: function(minutes, price, prints) {
                console.log("Session: Package selected ->", minutes, "phÃºt | giÃ¡", price, "| báº£n in", prints)
                root._packageFlow                = true
                root._selectedPackageMinutes     = minutes
                root._selectedTotalPrice         = price
                root._selectedOriginalTotalPrice = price
                root._selectedPrintCopies        = Math.max(1, prints)
                root._proceedToPayment()
            }
            onModeSelected: function(mode) {
                console.log("Session: Mode selected -> " + mode)
                if (root._paymentEnabled) {
                    if (root._operationMode === "mode3") {
                        root._selectedCategory = ""
                        sessionStack.push(layoutSelectionComponent)
                        return
                    }
                    // Payment flow: BÆ°á»›c 1 â†’ Chá»n kiá»ƒu chá»¥p
                    sessionStack.push(cutModeScreenComponent)
                } else {
                    // Mode1 flow: capture first, choose frame after.
                    if (root._usePostCaptureFrameSelectionFlow()) {
                        root._capturedPhotosAwaitingLayout = []
                        root._pushCaptureScreen()
                    } else {
                        sessionStack.push(layoutSelectionComponent)
                    }
                }
            }
            onGalleryClicked: {
                console.log("Session: Gallery clicked")
                // Khi báº­t báº£o máº­t, yÃªu cáº§u nháº­p PIN admin trÆ°á»›c khi xem áº£nh â€”
                // trÃ¡nh khÃ¡ch tá»± xem/in áº£nh cá»§a phiÃªn khÃ¡c.
                var secOn = eventManager.getAppSetting("security_enabled", "false") === "true"
                if (secOn) galleryPinDialog.open()
                else       sessionStack.push(galleryScreenComponent)
            }
            onCameraSettingsClicked: {
                var win = Window.window
                if (win) win._openSettings(root.eventId, 0)
            }
            // NÃºt âš™: má»Ÿ lÆ°á»›i CÃ i Ä‘áº·t (cÃ³ PIN náº¿u báº­t báº£o máº­t).
            onSettingsClicked: {
                var win = Window.window
                if (win) win._openSettingsSecure(root.eventId)
            }
        }
    }

    // 2. Layout Selection Screen
    Component {
        id: layoutSelectionComponent
        LayoutSelection {
            eventId: root.eventId
            eventData: root.eventData
            property bool _catMode: eventManager.getAppSetting("frame_category_enabled", "false") === "true"
            categoryPickerMode: root._operationMode === "mode3"
            // Lá»c theo loáº¡i in (cut/nocut) khi payment báº­t â€” ká»ƒ cáº£ cháº¿ Ä‘á»™ nhÃ³m,
            // vÃ¬ giá» khÃ¡ch chá»n cut/nocut trÆ°á»›c rá»“i má»›i chá»n nhÃ³m.
            cutModeFilter: root._operationMode === "mode3" ? -1 : (root._paymentEnabled ? (root._selectedCutMode ? 1 : 0) : -1)
            categoryFilter: root._operationMode === "mode3" ? "" : (_catMode ? root._selectedCategory : "")
            // áº¨n nÃºt Quay láº¡i khi vÃ o tá»« luá»“ng sau-chá»¥p (Ä‘Ã£ chá»¥p áº£nh trÆ°á»›c rá»“i má»›i chá»n frame).
            showBackButton: root._capturedPhotosAwaitingLayout.length === 0 && root._operationMode !== "mode3"
            showCloseButton: root._operationMode === "mode3"
            // Level 2: Báº¥m X â†’ quay vá» ModeSelection (Level 1), KHÃ”NG thoÃ¡t Dashboard
            onCloseClicked: {
                if (root._operationMode === "mode3" && root._capturedPhotosAwaitingLayout.length === 0)
                    root._requestExitSession()
                else
                    root.navigateToModeSelection()
            }
            // Quay láº¡i bÆ°á»›c trÆ°á»›c (CutModeScreen khi báº­t thanh toÃ¡n, ngÆ°á»£c láº¡i ModeSelection)
            onBackClicked: {
                if (root._operationMode === "mode3" && root._capturedPhotosAwaitingLayout.length === 0)
                    root._requestExitSession()
                else if (!sessionStack.busy)
                    sessionStack.pop()
            }
            onLayoutSelected: function(layoutPath, slotCount, printLabel, printPrice, isCut) {
                if (sessionStack.busy) return
                console.log("Session: Layout selected ->", layoutPath, "| Slots:", slotCount)
                if (root._operationMode === "mode3" && printLabel !== "") {
                    root._selectedCategory = printLabel
                    root._applyCategoryShootingMode(printLabel)
                    // Nạp sẵn thumbnail cho FilterScreen ngay từ bây giờ. Từ đây tới lúc
                    // mở màn filter còn cả bước chụp ảnh + ghép ảnh, thừa thời gian giải mã.
                    mode3ThumbPreloader.warm(root.eventId, printLabel)
                }

                // Update event with selected layout
                eventManager.updateEventLayout(root.eventId, layoutPath)
                root.eventData = eventManager.getEventDetails(root.eventId)

                root.pendingSlotCount = slotCount
                root._selectedLayoutPath = layoutPath
                root._selectedLayoutSlots = slotCount
                root._selectedCutMode = !!isCut
                root._selectedCategoryPrice = (printLabel !== "" && eventManager.getAppSetting("pricing_by_category_enabled", "false") === "true")
                    ? Math.max(0, parseInt(printPrice, 10) || 0)
                    : -1

                if (root._capturedPhotosAwaitingLayout.length > 0) {
                    // ÄÃ£ chá»¥p áº£nh trÆ°á»›c (luá»“ng gÃ³i / mode1): chá»n frame xong â†’ sang ghÃ©p áº£nh.
                    // Æ¯u tiÃªn trÆ°á»›c nhÃ¡nh thanh toÃ¡n vÃ¬ luá»“ng gÃ³i cÅ©ng báº­t _paymentEnabled.
                    sessionStack.push(photoCompositionScreenComponent, {
                        "eventId":           root.eventId,
                        "eventData":         root.eventData,
                        "layoutPath":        layoutPath,
                        "capturedPhotos":    root._capturedPhotosAwaitingLayout,
                        "sessionId":         root.sessionId,
                        "newPhotoIndex":     root.pendingRetakeIndex,
                        "preAssignedPhotos": root._capturedPhotosAwaitingLayout
                    })
                    root.pendingRetakeIndex = -1
                } else if (root._paymentEnabled) {
                    // Payment flow cÅ© (khÃ´ng dÃ¹ng gÃ³i): BÆ°á»›c 3 â†’ Chá»n sá»‘ lÆ°á»£ng áº£nh in
                    sessionStack.push(printQuantityScreenComponent)
                } else {
                    root._pushCaptureScreen(slotCount)
                }
            }
        }
    }

    // 1.5 Cut Mode Screen (payment flow only â€“ BÆ°á»›c 1)
    Component {
        id: cutModeScreenComponent
        CutModeScreen {
            eventId: root.eventId
            paymentMode: root._paymentEnabled
            showBackButton: root._operationMode !== "mode2"
            filterCategoriesBySelectedCut: eventManager.getAppSetting("frame_category_enabled", "false") === "true"
            onCloseClicked: {
                if (root._operationMode === "mode2")
                    root._requestExitSession()
                else
                    root.navigateToModeSelection()
            }
            // Quay láº¡i bÆ°á»›c trÆ°á»›c (ModeSelection)
            onBackClicked: {
                if (root._operationMode === "mode2")
                    root._requestExitSession()
                else if (!sessionStack.busy)
                    sessionStack.pop()
            }
            // Selfbooth: nhÃ¡nh Ä‘á»™c láº­p, miá»…n phÃ­ â€” sang trang chá».
            onCutModeChosen: function(isCut) {
                console.log("Session: Cut mode chosen ->", isCut)
                root._selectedCutMode = isCut
                // BÆ°á»›c 2: chá»n layout Ä‘Ã£ Ä‘Æ°á»£c filter
                sessionStack.push(layoutSelectionComponent)
            }
            onCategoryChosen: function(cat) {
                console.log("Session: Category chosen ->", cat)
                root._selectedCategory = cat
                root._applyCategoryShootingMode(cat)
                // BÆ°á»›c 2: chá»n layout Ä‘Ã£ Ä‘Æ°á»£c lá»c theo nhÃ³m
                sessionStack.push(layoutSelectionComponent)
            }
            // Cháº¿ Ä‘á»™ nhÃ³m má»›i: Ä‘Ã£ chá»n cáº£ loáº¡i in (cut/nocut) láº«n nhÃ³m.
            onCategoryFlowChosen: function(cat, isCut) {
                console.log("Session: Category flow chosen ->", cat, "| cut ->", isCut)
                root._selectedCutMode = isCut
                root._selectedCategory = cat
                root._applyCategoryShootingMode(cat)
                // BÆ°á»›c 2: chá»n layout Ä‘Ã£ lá»c theo nhÃ³m + loáº¡i in
                sessionStack.push(layoutSelectionComponent)
            }
        }
    }

    // 1.6 Selfbooth â€“ Trang chá» (nhÃ¡nh Ä‘á»™c láº­p, miá»…n phÃ­)
    Component {
        id: selfBoothWaitingComponent
        SelfBoothWaiting {
            // X â†’ vá» CutModeScreen. Báº­t báº£o máº­t thÃ¬ yÃªu cáº§u PIN admin trÆ°á»›c.
            onCloseClicked: {
                if (eventManager.getAppSetting("sbcut_security_enabled", "false") === "true") {
                    sbcutExitPinDialog.open()
                } else {
                    root._restoreMainCameraSession()
                    if (!sessionStack.busy) sessionStack.pop()
                }
            }
            // âš™ â†’ má»Ÿ trang cÃ i Ä‘áº·t sidebar.
            onSettingsClicked: { if (!sessionStack.busy) sessionStack.push(selfBoothSettingsComponent) }
            // Báº¥m giá»¯a â†’ táº¡o session selfbooth Ä‘á»™c láº­p, Ä‘á»•i táº¡m path camera, sang chá»¥p.
            onStartCapture: {
                if (sessionStack.busy) return
                if (eventManager.getAppSetting("sbcut_minute_mode", "false") === "true") {
                    sessionStack.push(selfBoothOptionTimeComponent)
                    return
                }
                var base = eventManager.getAppSetting("sbcut_save_dir", "")
                if (base === "") base = eventManager.getSelfBoothBaseDir()
                var sid   = "selfbooth_" + Qt.formatDateTime(new Date(), "yyyyMMdd_HHmmss")
                var spath = base + "/" + sid
                cameraController.setSessionStoragePath(spath)
                cameraController.setCurrentSessionId(sid)
                sessionStack.push(selfBoothCaptureComponent, { sessionPath: spath, sessionId: sid })
            }
        }
    }

    // 1.65 Selfbooth â€“ Trang cÃ i Ä‘áº·t (sidebar)
    Component {
        id: selfBoothSettingsComponent
        SelfBoothSettings {
            onBackClicked: { if (!sessionStack.busy) sessionStack.pop() }
        }
    }

    // 1.66 Selfbooth â€“ chá»n gÃ³i phÃºt
    Component {
        id: selfBoothOptionTimeComponent
        OptionTime {
            timeOptions: [
                parseInt(eventManager.getAppSetting("sbcut_time1", "5")) || 5,
                parseInt(eventManager.getAppSetting("sbcut_time2", "10")) || 10,
                parseInt(eventManager.getAppSetting("sbcut_time3", "15")) || 15
            ]
            priceOptions: [
                parseInt(eventManager.getAppSetting("sbcut_price1", "0")) || 0,
                parseInt(eventManager.getAppSetting("sbcut_price2", "0")) || 0,
                parseInt(eventManager.getAppSetting("sbcut_price3", "0")) || 0
            ]
            onBackClicked: { if (!sessionStack.busy) sessionStack.pop() }
            onTimeSelected: function(minutes) {
                if (sessionStack.busy) return
                var price = root._selfPriceForMinutes(minutes)
                root._prepareSelfMinuteSession(minutes, price)
                var paymentOn = eventManager.getAppSetting("sbcut_payment_enabled", "false") === "true"
                if (paymentOn && price > 0)
                    root._proceedSelfMinutePayment()
                else
                    root._startSelfMinuteCapture()
            }
        }
    }

    // 1.67 Selfbooth â€“ phiÃªn chá»¥p theo phÃºt, thá»¥ Ä‘á»™ng qua dÃ¢y remote
    Component {
        id: selfBoothMinuteCaptureComponent
        LCaptureSelf {
            onSessionDone: function(sid, photos) {
                root._finishSelfBoothCapture(sid, photos)
            }
            onCameraFailed: {
                root._restoreMainCameraSession()
                if (!sessionStack.busy) sessionStack.pop()
            }
            onCancelClicked: {
                root._restoreMainCameraSession()
                if (!sessionStack.busy) sessionStack.pop()
            }
        }
    }

    // 1.7 Selfbooth â€“ MÃ n chá»¥p tá»± Ä‘áº¿m ngÆ°á»£c
    Component {
        id: selfBoothCaptureComponent
        SelfBoothCapture {
            onSessionDone: function(sid, photos) {
                root._finishSelfBoothCapture(sid, photos)
            }
            onCameraFailed: {
                root._restoreMainCameraSession()
                if (!sessionStack.busy) sessionStack.pop()
            }
            // X â†’ huá»· chá»¥p, khÃ´i phá»¥c session camera chÃ­nh & quay vá» trang chá» Selfbooth.
            onCancelClicked: {
                root._restoreMainCameraSession()
                if (!sessionStack.busy) sessionStack.pop()
            }
        }
    }

    // 1.75 Selfbooth - chá»n frame sau khi chá»¥p
    Component {
        id: selfBoothFrameSelectionComponent
        LayoutSelection {
            eventId: root.eventId
            eventData: root.eventData
            layoutSource: "selfbooth"
            cutModeFilter: -1
            paymentModeOverride: 1
            countdownEnabled: false
            alwaysShowTitle: true
            titleText: "Chá»n Khung Frame"

            onCloseClicked: root._showSelfBoothQr(root._selfFrameSessionId)
            onBackClicked: root._showSelfBoothQr(root._selfFrameSessionId)
            onLayoutSelected: function(layoutPath, slotCount, printLabel, printPrice, isCut) {
                if (sessionStack.busy) return
                root._selfSelectedFramePath = layoutPath
                root._selfSelectedFrameSlots = slotCount
                sessionStack.push(selfBoothFrameCompositionComponent, {
                    layoutPath: layoutPath,
                    capturedPhotos: root._selfFramePhotos,
                    sessionId: root._selfFrameSessionId
                })
            }
        }
    }

    // 1.76 Selfbooth - gÃ¡n áº£nh vÃ o cÃ¡c slot cá»§a frame
    Component {
        id: selfBoothFrameCompositionComponent
        PhotoCompositionScreen {
            eventId: root.eventId
            eventData: root.eventData
            selfBoothMode: true
            paymentModeOverride: 1
            photoReviewOverride: 0

            onCloseClicked: {
                if (!sessionStack.busy) sessionStack.pop()
            }
            onSessionFinished: function(photos, collagePath, transforms) {
                root._uploadSelfBoothCollage(collagePath)
                root._showSelfBoothQr(root._selfFrameSessionId)
            }
        }
    }

    // 1.8 Selfbooth â€“ MÃ n QR (tÃ¡i dÃ¹ng QRCodeSelf, ná»n riÃªng sbcut_bg_result)
    Component {
        id: selfBoothQrComponent
        QRCodeSelf {
            bgOverride: eventManager.getAppSetting("sbcut_bg_result", "")
            // "â† Quay láº¡i": thoÃ¡t háº³n Selfbooth vá» ModeSelection chÃ­nh.
            onBackClicked: {
                root._restoreMainCameraSession()
                root.navigateToModeSelection()
            }
            // "KhÃ¡ch tiáº¿p theo" = chá»¥p lÆ°á»£t má»›i â†’ vá» trang chá» Selfbooth (modeselection
            // cá»§a Selfbooth náº±m ngay dÆ°á»›i QR trong stack), KHÃ”NG vá» CutModeScreen.
            onNextSession: {
                if (!sessionStack.busy) sessionStack.pop()
            }
        }
    }

    // 1.9 Selfbooth minute-mode â€“ chá»n phÆ°Æ¡ng thá»©c / voucher
    Component {
        id: selfBoothPaymentMethodComponent
        PaymentMethodScreen {
            totalPrice: root._selfTotalPrice
            copies: 1
            isCut: false
            layoutPath: ""
            bgOverride: eventManager.getAppSetting("sbcut_bg_payment", "")
            showVoucher: root._voucherEnabled
            showCash: eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
            showBankTransfer: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
            cashCodeEnabled: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"
            allowPrintVoucher: false

            onCloseClicked: { if (!sessionStack.busy) sessionStack.pop() }
            onCashSelected: sessionStack.push(selfBoothCashPaymentComponent)
            onBankTransferSelected: sessionStack.push(selfBoothBankPaymentComponent)

            onCashCodePaid: function(code, amount) {
                eventManager.redeemCashPaymentCode(code, root._selfSessionId, amount)
                root._completeSelfMinutePayment(
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
                    root._proceedSelfMinutePayment()
                    return
                }
                var cashEnabled = eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
                var bankEnabled = eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
                if (!cashEnabled && bankEnabled)
                    sessionStack.push(selfBoothBankPaymentComponent)
            }

            onVoucherPaid: function(code, amount) {
                root._selfVoucherCode = code
                root._selfVoucherValue = amount
                root._completeSelfMinutePayment("voucher", 0, 0, 0, amount)
            }
        }
    }

    // 1.91 Selfbooth minute-mode â€“ tiá»n máº·t
    Component {
        id: selfBoothCashPaymentComponent
        CashPaymentScreen {
            totalPrice: root._selfTotalPrice
            bgOverride: eventManager.getAppSetting("sbcut_bg_payment", "")
            onCloseClicked: { if (!sessionStack.busy) sessionStack.pop() }
            onPaymentComplete: function(received) {
                root._completeSelfMinutePayment(
                    "cash", received, 0, Math.max(0, received - root._selfTotalPrice),
                    root._selfVoucherValue)
            }
        }
    }

    // 1.92 Selfbooth minute-mode â€“ chuyá»ƒn khoáº£n ngÃ¢n hÃ ng
    Component {
        id: selfBoothBankPaymentComponent
        PaymentScreen {
            eventId: root.eventId
            eventData: root.eventData
            sessionId: root._selfSessionId
            printCopies: 1
            directTotalPrice: root._selfTotalPrice
            directCutMode: 0
            canGoBack: true
            bgOverride: eventManager.getAppSetting("sbcut_bg_payment", "")
            paymentEnabledOverride: 1

            onCloseClicked: { if (!sessionStack.busy) sessionStack.pop() }
            onPaymentSuccess: {
                root._completeSelfMinutePayment(
                    "transfer", 0, root._selfTotalPrice, 0, root._selfVoucherValue)
            }
            onPaymentSkipped: {
                // Configuration errors must not create a paid session or revenue.
                console.warn("[SelfBooth] Bank payment skipped; returning to package selection")
                if (!sessionStack.busy) sessionStack.pop()
            }
        }
    }

    // 2.5 Print Quantity Screen (payment flow only â€“ BÆ°á»›c 3)
    Component {
        id: printQuantityScreenComponent
        PrintQuantityScreen {
            layoutPath: root._selectedLayoutPath
            slotCount:  root._selectedLayoutSlots
            isCut:      root._selectedCutMode
            categoryPrice: root._selectedCategoryPrice
            onCloseClicked: root.navigateToModeSelection()
            // Quay láº¡i bÆ°á»›c trÆ°á»›c (LayoutSelection)
            onBackClicked: { if (!sessionStack.busy) sessionStack.pop() }
            onContinueClicked: function(copies, total) {
                console.log("Session: Print copies chosen ->", copies, "total ->", total)
                root._selectedPrintCopies = copies
                root._selectedTotalPrice  = total
                root._selectedOriginalTotalPrice = total
                // Voucher giá» nháº­p ngay táº¡i trang phÆ°Æ¡ng thá»©c thanh toÃ¡n.
                root._proceedToPayment()
            }
        }
    }

    // 2.55 Payment Method Screen (payment flow â€“ BÆ°á»›c 4)
    // Voucher Ä‘Æ°á»£c nháº­p ngay táº¡i trang nÃ y (khÃ´ng cÃ²n trang voucher riÃªng).
    Component {
        id: paymentMethodScreenComponent
        PaymentMethodScreen {
            totalPrice: root._selectedTotalPrice
            copies:     root._selectedPrintCopies
            isCut:      root._selectedCutMode
            layoutPath: root._selectedLayoutPath
            showVoucher: root._voucherEnabled
            showCash:    eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
            showBankTransfer: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
            cashCodeEnabled: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"

            onCloseClicked: { if (!sessionStack.busy) sessionStack.pop() }

            onCashSelected: {
                // BÆ°á»›c 5a: Thanh toÃ¡n tiá»n máº·t qua mÃ¡y Ä‘á»c
                sessionStack.push(cashPaymentScreenComponent)
            }

            onBankTransferSelected: {
                // BÆ°á»›c 5b: Thanh toÃ¡n QR
                sessionStack.push(prePaymentScreenComponent)
            }

            onCashCodePaid: function(code, amount) {
                console.log("Session: Cash code payment complete ->", code, amount)
                var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                eventManager.logRevenue(root.eventId, evName, root.sessionId,
                    root._selectedPrintCopies, root._selectedOriginalTotalPrice,
                    amount, 0, 0, "cash", "", "session",
                    root._voucherRevenueNote("Cash code: " + code + "; cash: " + amount),
                    root._voucherValue)
                eventManager.redeemCashPaymentCode(code, root.sessionId, amount)
                if (root._voucherCode !== "") {
                    eventManager.redeemVoucher(root._voucherCode, root.sessionId)
                    root._clearVoucherState()
                }
                root._pushPackageCaptureScreen()
            }

            // Voucher giáº£m giÃ¡ / táº·ng in: cáº­p nháº­t giÃ¡. Náº¿u cÃ²n tiá»n vÃ  táº¯t tiá»n máº·t
            // thÃ¬ tá»± sang QR; náº¿u báº­t tiá»n máº·t thÃ¬ á»Ÿ láº¡i Ä‘á»ƒ khÃ¡ch chá»n cÃ¡ch tráº£.
            onVoucherApplied: function(code, voucherType, voucherValue) {
                console.log("Session: Voucher applied ->", code, voucherType, voucherValue)
                root._voucherCode  = code
                root._voucherType  = voucherType
                root._voucherValue = voucherValue
                if (voucherType === "discount" || voucherType === "cash")
                    root._selectedTotalPrice = Math.max(0, root._selectedTotalPrice - voucherValue)
                else if (voucherType === "print")
                    root._selectedPrintCopies += voucherValue

                if (root._selectedTotalPrice <= 0) {
                    // ÄÃ£ miá»…n phÃ­ hoÃ n toÃ n â†’ bá» qua thanh toÃ¡n.
                    root._proceedToPayment()
                    return
                }
                var cashEnabled = eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
                var bankEnabled = eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
                if (!cashEnabled && bankEnabled) {
                    // Chá»‰ QR â†’ Ã¡p xong tá»± sang trang QR vá»›i giÃ¡ Ä‘Ã£ giáº£m.
                    sessionStack.push(prePaymentScreenComponent)
                }
                // CÃ²n láº¡i: báº­t tiá»n máº·t â†’ á»Ÿ láº¡i trang, khÃ¡ch chá»n tiá»n máº·t / QR.
            }

            // Voucher "cash" há»£p lá»‡ = Ä‘Ã£ thanh toÃ¡n Ä‘á»§ â†’ ghi doanh thu, redeem, bá» qua thanh toÃ¡n.
            onVoucherPaid: function(code, amount) {
                console.log("Session: Voucher paid ->", code, amount)
                var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                eventManager.logRevenue(root.eventId, evName, root.sessionId,
                    root._selectedPrintCopies, root._selectedOriginalTotalPrice,
                    0, 0, 0, "voucher", "", "session",
                    "Voucher code: " + code, amount)
                eventManager.redeemVoucher(code, root.sessionId, amount)
                root._clearVoucherState()
                root._pushPackageCaptureScreen()
            }
        }
    }

    // 2.56 Cash Payment Screen (payment flow only â€“ BÆ°á»›c 5a)
    Component {
        id: cashPaymentScreenComponent
        CashPaymentScreen {
            totalPrice: root._selectedTotalPrice

            onCloseClicked: root.navigateToModeSelection()

            onPaymentComplete: function(received) {
                console.log("Session: Cash payment complete, received:", received)
                var evName = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                var change = Math.max(0, received - root._selectedTotalPrice)
                eventManager.logRevenue(root.eventId, evName, root.sessionId,
                    root._selectedPrintCopies, root._selectedOriginalTotalPrice,
                    received, 0, change, "cash", "", "session",
                    root._voucherRevenueNote(""), root._voucherValue)
                if (root._voucherCode !== "") {
                    eventManager.redeemVoucher(root._voucherCode, root.sessionId)
                    root._clearVoucherState()
                }
                root._pushPackageCaptureScreen()
            }
        }
    }

    // 2.6 Pre-Capture Payment Screen (payment flow only â€“ BÆ°á»›c 5b)
    Component {
        id: prePaymentScreenComponent
        PaymentScreen {
            eventId:          root.eventId
            eventData:        root.eventData
            sessionId:        root.sessionId
            printCopies:      root._selectedPrintCopies
            // DÃ¹ng Tá»”NG tiá»n cá»‘ Ä‘á»‹nh Ä‘Ã£ tÃ­nh á»Ÿ mÃ n chá»n sá»‘ lÆ°á»£ng (giÃ¡ cá»‘ Ä‘á»‹nh
            // cáº£ cá»¥m), khÃ´ng Ä‘á»ƒ PaymentScreen tá»± nhÃ¢n Ä‘Æ¡n giÃ¡ Ã— sá»‘ báº£n.
            directTotalPrice: root._selectedTotalPrice
            directCutMode:    root._selectedCutMode ? 1 : 0
            // CÃ³ trang chá»n phÆ°Æ¡ng thá»©c (PaymentMethodScreen) á»Ÿ bÆ°á»›c trÆ°á»›c khi báº­t
            // tiá»n máº·t â†’ cho phÃ©p quay láº¡i Ä‘á»ƒ Ä‘á»•i phÆ°Æ¡ng thá»©c.
            canGoBack:        eventManager.getAppSetting("cash_payment_enabled", "false") === "true" || root._voucherEnabled

            onCloseClicked: sessionStack.pop()   // Há»§y â†’ vá» trang trÆ°á»›c (chá»n sá»‘ lÆ°á»£ng / layout)
            onBackClicked:  sessionStack.pop()   // vá» PaymentMethodScreen

            onPaymentSuccess: {
                console.log("Session: Pre-capture payment success â†’ go to CaptureScreen")
                var evName2 = (root.eventData && root.eventData.name) ? root.eventData.name : ""
                eventManager.logRevenue(root.eventId, evName2, root.sessionId,
                    root._selectedPrintCopies, root._selectedOriginalTotalPrice,
                    0, root._selectedTotalPrice, 0, "transfer", "", "session",
                    root._voucherRevenueNote(""), root._voucherValue)
                if (root._voucherCode !== "") {
                    eventManager.redeemVoucher(root._voucherCode, root.sessionId)
                    root._clearVoucherState()
                }
                root._pushPackageCaptureScreen()
            }

            onPaymentSkipped: {
                console.log("Session: Pre-capture payment skipped â†’ go to CaptureScreen")
                root._pushPackageCaptureScreen()
            }
        }
    }

    // LÆ°u args Ä‘á»ƒ onPreviewReady dÃ¹ng
    property var _pendingFilterCollagePath: ""
    // true = preview dÃ¹ng cho FilterScreen (push má»›i); false = dÃ¹ng Ä‘á»ƒ cáº­p nháº­t mÃ n hÃ¬nh hiá»‡n táº¡i
    property bool _previewForFilter: false
    // true = onPreviewReady sáº½ cáº­p nháº­t collagePath cá»§a FilterScreen Ä‘ang hiá»ƒn thá»‹ (cut mode)
    property bool _previewUpdateFilter: false

    // Connections duy nháº¥t cho eventManager signals trong BoothSession
    Connections {
        target: eventManager

        function onPreviewReady(previewPath) {
            if (root._previewForFilter) {
                // Legacy path: push FilterScreen sau khi async xong (khÃ´ng cÃ²n dÃ¹ng cho filter flow)
                root._previewForFilter = false
                var photos2     = root._pendingPhotos
                var collagePath2 = root._pendingFilterCollagePath
                var transforms2  = root._pendingTransforms
                var layoutPath2  = (root.eventData && root.eventData.selectedLayout) ? root.eventData.selectedLayout : ""
                var displayPath2 = (previewPath && previewPath !== "") ? previewPath : collagePath2
                sessionStack.push(filterScreenComponent, {
                    "collagePath": displayPath2,
                    "layoutPath":  layoutPath2,
                    "eventId":     root.eventId,
                    "eventData":   root.eventData,
                    "photos":      photos2,
                    "transforms":  transforms2,
                    "sessionId":   root.sessionId
                })
            } else if (root._previewUpdateFilter) {
                // Cut mode: raw strip Ä‘Ã£ xong â€” cáº­p nháº­t collagePath cá»§a FilterScreen Ä‘ang hiá»ƒn thá»‹
                root._previewUpdateFilter = false
                var filterScreen = sessionStack.currentItem
                if (filterScreen && filterScreen._previewLoading !== undefined) {
                    if (previewPath && previewPath !== "") {
                        filterScreen.collagePath = previewPath
                        console.log("[BoothSession] FilterScreen collagePath updated to raw strip:", previewPath)
                    } else {
                        console.warn("[BoothSession] processCollageNoCutAsync tra ve rong — giu collagePath cu")
                    }
                    // Luôn mở khoá: nếu không, nút "In Ảnh" bị disable vĩnh viễn.
                    filterScreen._previewLoading = false
                }
            } else {
                // Result flow (autoCut): cáº­p nháº­t displayPath trÃªn ResultScreen Ä‘ang hiá»ƒn thá»‹
                if (previewPath && previewPath !== "") {
                    var current = sessionStack.currentItem
                    if (current && typeof current.updateDisplayPath === "function")
                        current.updateDisplayPath(previewPath)
                }
            }
        }
    }

    Connections {
        target: filterManager
        function onPhotosFilterComplete(success) {
            console.log("[BoothSession] photosFilterComplete:", success)
            root.triggerDeferredIndividualSave()
        }
    }

    // [ASYNC] Queue collage upload lÃªn S3. CHá»ˆ phÃ¡t signal queued sang
    // S3UploadThread (Ä‘á»c file + HTTP PUT Ä‘á»u cháº¡y trÃªn worker thread cá»§a
    // S3Uploader) â†’ KHÃ”NG block UI dÃ¹ upload cháº­m. á»ž Ä‘Ã¢y chá»‰ lÃ  vÃ i thao tÃ¡c
    // string + 1 emit, an toÃ n gá»i trÃªn main/QML thread.
    function uploadCollageToS3(path) {
        if (root.sessionId === "" || !path || path === "") return
        var hwid = machineAuth.hwid
        var clean = path.toString().replace(/^(file:\/{3})|(file:)/, "")
        if (Qt.platform.os === "windows") clean = clean.replace(/^(file:\/\/\/)/, "")
        clean = decodeURIComponent(clean)
        var rawPath = (root.eventData && root.eventData.rawPath) ? root.eventData.rawPath : ""
        s3Uploader.setCurrentEventRawPath(rawPath)
        s3Uploader.uploadCollage(clean, hwid, root.eventId, root.sessionId)
    }

    function _saveIndividualPhotosForCurrentSession(photosToUpload) {
        if (!photosToUpload || photosToUpload.length === 0) return
        if (root.eventId > 0 && root.sessionId !== "") {
            eventManager.saveSessionPhotosAsync(root.eventId, photosToUpload, root.sessionId)
        }
    }

    function triggerDeferredIndividualSave() {
        if (!root._deferredIndividualPhotos || root._deferredIndividualPhotos.length === 0) {
            root._deferredIndividualFilterRunning = false
            return
        }

        var photosToUpload = root._deferredIndividualPhotos.slice()
        var eventId = root._deferredIndividualEventId
        var sessionId = root._deferredIndividualSessionId
        root._deferredIndividualPhotos = []
        root._deferredIndividualEventId = -1
        root._deferredIndividualSessionId = ""
        root._deferredIndividualFilterRunning = false
        if (eventId > 0 && sessionId !== "") {
            eventManager.saveSessionPhotosAsync(eventId, photosToUpload, sessionId)
        }
    }

    function handleSessionCompletion(photos, collagePath, transforms) {
        console.log("=== [BoothSession] handleSessionCompletion ===")
        console.log("[BoothSession] photos.length:", photos ? photos.length : 0)
        console.log("[BoothSession] collagePath:", collagePath)
        console.log("[BoothSession] transforms.length:", transforms ? transforms.length : 0)
        root._capturedPhotosAwaitingLayout = []
        root.createProcessVideoOnce(photos)

        // Route/settings first: when requested, individual photos wait until
        // FilterScreen finalizes the selected LUT.
        var filterEnabled = eventManager.getAppSetting("filter_enabled", "false") === "true"
        var hasFilters = filterManager.getFilters().length > 0
        var applyFilterAll = eventManager.getAppSetting("filter_apply_all_photos", "false") === "true"
        var deferIndividual = filterEnabled && hasFilters && applyFilterAll
        console.log("[BoothSession] filterEnabled:", filterEnabled,
                    "| hasFilters:", hasFilters,
                    "| applyFilterAll:", applyFilterAll,
                    "| deferIndividual:", deferIndividual)

        // [ASYNC] Flip + DB save + S3 individual photos â€” cháº¡y background, khÃ´ng block
        // Upload final selected photos plus shots discarded by retake. Composition
        // still uses only `photos`; discarded shots are kept for the customer gallery.
        var photosToUpload = photos ? photos.slice() : []
        var discardedForUpload = root._retakeDiscardedPhotos ? root._retakeDiscardedPhotos.slice() : []
        if (discardedForUpload.length > 0)
            photosToUpload = photosToUpload.concat(discardedForUpload)
        if (deferIndividual) {
            root._deferredIndividualPhotos = photosToUpload ? photosToUpload.slice() : []
            root._deferredIndividualEventId = root.eventId
            root._deferredIndividualSessionId = root.sessionId
        } else {
            root._saveIndividualPhotosForCurrentSession(photosToUpload)
        }
        root._retakeDiscardedPhotos = []

        // Collage upload bá»‹ HOÃƒN: náº¿u Ä‘i qua FilterScreen, báº£n gá»‘c (chÆ°a filter)
        // sáº½ lá»‡ch vá»›i báº£n in/hiá»ƒn thá»‹. Upload diá»…n ra á»Ÿ nhÃ¡nh khÃ´ng-filter bÃªn dÆ°á»›i,
        // hoáº·c trong onFilterComplete (upload Ä‘Ãºng báº£n Ä‘Ã£ filter). Xem uploadCollageToS3().

        // Route: FilterScreen hoáº·c ResultScreen
        // Chỉ cần bật filter là vào FilterScreen, KHÔNG bắt buộc phải có file LUT:
        // màn này còn giữ QR overlay bản in + hộp thoại in + điều hướng WaitingResults.
        if (filterEnabled) {
            root._pendingPhotos          = photos
            root._pendingTransforms      = transforms || []
            root._pendingFilterCollagePath = collagePath
            root._previewForFilter       = false

            var autoCut   = root.eventData && root.eventData.autoCut
            var layoutPath = (root.eventData && root.eventData.selectedLayout) ? root.eventData.selectedLayout : ""
            console.log("[BoothSession] â†’ push FilterScreen | autoCut:", autoCut, "| layoutPath:", layoutPath)

            if (autoCut) {
                console.log("[BoothSession] Cut mode: push FilterScreen vá»›i _previewLoading=true, cháº¡y processCollageNoCutAsync")
                root._previewUpdateFilter = true
                sessionStack.push(filterScreenComponent, {
                    "collagePath":    collagePath,
                    "layoutPath":     layoutPath,
                    "eventId":        root.eventId,
                    "eventData":      root.eventData,
                    "photos":         photos,
                    "transforms":     transforms,
                    "sessionId":      root.sessionId,
                    "selectedCategory": root._selectedCategory,
                    "_previewLoading": true
                })
                eventManager.processCollageNoCutAsync(
                    root.eventId, photos, transforms || [], root.sessionId)
            } else {
                console.log("[BoothSession] Non-cut mode: push FilterScreen vá»›i collagePath:", collagePath)
                root._previewUpdateFilter = false
                sessionStack.push(filterScreenComponent, {
                    "collagePath": collagePath,
                    "layoutPath":  layoutPath,
                    "eventId":     root.eventId,
                    "eventData":   root.eventData,
                    "photos":      photos,
                    "transforms":  transforms,
                    "sessionId":   root.sessionId,
                    "selectedCategory": root._selectedCategory
                })
            }
            console.log("=== [BoothSession] FilterScreen Ä‘Ã£ Ä‘Æ°á»£c push lÃªn stack ===")
        } else {
            console.log("[BoothSession] â†’ KhÃ´ng qua FilterScreen, push ResultScreen trá»±c tiáº¿p")
            root.uploadCollageToS3(collagePath)
            root.pushToResultScreen(photos, collagePath, transforms)
        }
    }

    // displayHint: filtered no-cut strip from FilterScreen (file:/// URL).
    // When provided, skip processCollageNoCutAsync so the filtered strip is not
    // replaced by an unfiltered one on the ResultScreen.
    function pushToResultScreen(photos, collagePath, transforms, displayHint) {
        var hwid = machineAuth.hwid
        var autoCut = root.eventData && root.eventData.autoCut
        var hasFilteredStrip = displayHint && displayHint !== ""

        // If a filtered strip is provided, use it as the initial displayPath so
        // ResultScreen immediately shows the correct filtered preview.
        var initialDisplayPath = hasFilteredStrip ? displayHint : collagePath
        console.log("[BoothSession] pushToResultScreen: collagePath=" + collagePath + " | displayHint=" + displayHint + " | autoCut=" + autoCut)

        sessionStack.push(resultScreenComponent, {
            "photos":            photos,
            "collagePath":       collagePath,
            "displayPath":       initialDisplayPath,
            "eventId":           root.eventId,
            "eventData":         root.eventData,
            "sessionId":         root.sessionId,
            "hwid":              hwid,
            // Luá»“ng gÃ³i: in miá»…n phÃ­, sá»‘ báº£n theo gÃ³i, khÃ´ng há»i sá»‘ lÆ°á»£ng.
            "prePaymentDone":    true,
            // PHẢI khớp điều kiện ghép ảnh ở EventManager
            // (cutMode_compose = event.autoCut && printerConfig.cutMode).
            // Hard-code false khiến canvas 2 strip bị in ra mà không cắt.
            "prePaymentCutMode": autoCut && printerConfig.cutMode,
            "prePaymentCopies":  Math.max(1, root._selectedPrintCopies)
        })

        // [ASYNC] Generate no-cut preview strip only when autoCut is on AND no
        // filtered strip was supplied.  If the user applied a filter, displayHint
        // already holds the correct filtered strip â€” regenerating from raw photos
        // would overwrite it with an unfiltered one.
        if (autoCut && !hasFilteredStrip) {
            root._pendingPhotos     = photos
            root._pendingTransforms = transforms || []
            root._pendingFilterCollagePath = collagePath
            root._previewForFilter  = false
            eventManager.processCollageNoCutAsync(
                root.eventId, photos, transforms || [], root.sessionId)
        }
    }

    // Sau khi báº¥m "In áº¢nh" á»Ÿ FilterScreen â†’ trang chá» WaitingResults (QR + ảnh).
    // QR trá» tá»›i URL session (gom anh chup va anh ghep.
    function pushToWaitingResults(photos, collagePath, displayHint) {
        var hwid = machineAuth.hwid
        var initialDisplayPath = (displayHint && displayHint !== "") ? displayHint : collagePath
        sessionStack.push(waitingResultsComponent, {
            "photos":      photos,
            "collagePath": collagePath,
            "displayPath": initialDisplayPath,
            "eventId":     root.eventId,
            "eventData":   root.eventData,
            "sessionId":   root.sessionId,
            "hwid":        hwid
        })
    }

    function updateWaitingResultsFinalImage(finalPath) {
        if (!finalPath || finalPath === "") return
        var item = sessionStack.currentItem
        if (!item || item.collagePath === undefined || item.displayPath === undefined) return
        item.collagePath = finalPath
        item.displayPath = finalPath
    }

    function createProcessVideoOnce(photos) {
        if (!photos || photos.length === 0) return
        if (!root.sessionId || root.sessionId === "") return
        if (root._videoRequestedSessionId === root.sessionId) return
        root._videoRequestedSessionId = root.sessionId
        console.log("[BoothSession] Creating process video for session:", root.sessionId)
        var slotCaptureIndices = root.resolveSlotCaptureIndices(photos)
        console.log("[BoothSession] Process video slot->capture map:", slotCaptureIndices)
        eventManager.createVideoFromSessionQml(root.eventId, root.sessionId, photos, 1920, slotCaptureIndices)
    }

    function normalizePhotoPathForCompare(path) {
        var p = String(path || "")
        if (p.startsWith("file:///")) p = p.substring(8)
        else if (p.startsWith("file://")) p = p.substring(7)
        p = decodeURIComponent(p).replace(/\\/g, "/")
        if (Qt.platform.os === "windows" && p.startsWith("/") && p.indexOf(":") === 2)
            p = p.substring(1)
        return p.toLowerCase()
    }

    function resolveSlotCaptureIndices(slotPhotos) {
        var map = []
        var captured = root.allCapturedPhotos || []
        for (var i = 0; i < slotPhotos.length; i++) {
            var wanted = root.normalizePhotoPathForCompare(slotPhotos[i])
            var found = -1
            for (var j = 0; j < captured.length; j++) {
                if (root.normalizePhotoPathForCompare(captured[j]) === wanted) {
                    found = j
                    break
                }
            }
            map.push(found >= 0 ? found : i)
        }
        return map
    }

    // Chá»¥p xong khi Táº®T "Chá»n khung": bá» qua chá»n frame/ghÃ©p/filter/in, Ä‘i tháº³ng
    // WaitingResults. Anh roi duoc upload qua _saveIndividualPhotosForCurrentSession.
    function pushToWaitingResultsDirect(photos, collagePath) {
        root.allCapturedPhotos = photos
        root._capturedPhotosAwaitingLayout = []
        // Mode3 (chup tu do, khong dem nguoc) khong quay doan truoc moi anh -> khong tao video.
        if (root._operationMode !== "mode3")
            root.createProcessVideoOnce(photos)
        var photosToUpload = photos ? photos.slice() : []
        var discardedForUpload = root._retakeDiscardedPhotos ? root._retakeDiscardedPhotos.slice() : []
        if (discardedForUpload.length > 0)
            photosToUpload = photosToUpload.concat(discardedForUpload)
        root._saveIndividualPhotosForCurrentSession(photosToUpload)
        root._retakeDiscardedPhotos = []
        var finalCollage = (collagePath && collagePath !== "") ? collagePath : ""
        if (finalCollage !== "") root.uploadCollageToS3(finalCollage)
        var first = finalCollage !== "" ? finalCollage : ((photos && photos.length > 0) ? photos[0] : "")
        var hwid = machineAuth.hwid
        sessionStack.push(waitingResultsComponent, {
            "photos":      photos,
            "collagePath": finalCollage,
            "displayPath": first,
            "eventId":     root.eventId,
            "eventData":   root.eventData,
            "sessionId":   root.sessionId,
            "hwid":        hwid
        })
    }

    // Káº¿t ná»‘i previewReady Ä‘Ã£ Ä‘Æ°á»£c gá»™p vÃ o Connections phÃ­a trÃªn.

    // 3. Capture Screen
    Component {
        id: captureScreenComponent
        CaptureScreen {
            eventId: root.eventId
            eventData: root.eventData
            operationMode: root._operationMode
            forceManualPostFlow: root._usePostCaptureFrameSelectionFlow() || root._packageFlow || root._shouldBypassCompositionToWaitingResults()
            // Level 2: Báº¥m X â†’ quay vá» ModeSelection (Level 1), KHÃ”NG thoÃ¡t Dashboard
            onCloseClicked: {
                // Luong ma tra truoc: X -> ve EnterCode (pop CaptureScreen). Con lai -> ModeSelection.
                if (root._operationMode === "mode3" && root._prepaidCode !== "") {
                    // Mode3: X -> ve EnterCode voi session moi, khong giu anh/phien cu.
                    if (sessionStack.busy) return
                    root._startNewMainSession()
                    root._prepaidCode = ""
                    root._selectedPackageMinutes = 0
                    root._mode3CodeStarting = false
                    sessionStack.pop()
                } else if (root._prepaidCode !== "") {
                    if (!sessionStack.busy) sessionStack.pop()
                } else {
                    root.navigateToModeSelection()
                }
            }
            onSessionFinished: function(photos, collagePath) {
                root.allCapturedPhotos = photos  // Save ALL captured photos
                if (root._shouldBypassCompositionToWaitingResults()) {
                    console.log("Session: frame selection OFF â†’ WaitingResults (QR only)")
                    root.pushToWaitingResultsDirect(photos, collagePath)
                    return
                }
                root.handleSessionCompletion(photos, collagePath, [])
            }
            onManualCaptureFinished: function(photos) {
                root.allCapturedPhotos = photos  // Save ALL captured photos before composition
                if (root._shouldBypassCompositionToWaitingResults()) {
                    console.log("Session: frame selection OFF â†’ WaitingResults (QR only)")
                    root.pushToWaitingResultsDirect(photos)
                    return
                }
                if (root._usePostCaptureFrameSelectionFlow() || root._packageFlow) {
                    console.log("Session: Capture finished. Opening frame selection with", photos.length, "photos")
                    root._beginFrameSelectionAfterCapture(photos)
                    return
                }
                var isTemplate = root.eventData && root.eventData.shootingMode === 2
                console.log("Session: Capture finished (" + (isTemplate ? "Template" : "Manual") + "). Going to Composition Screen with", photos.length, "photos")
                var props = {
                    "eventId":            root.eventId,
                    "eventData":          root.eventData,
                    "layoutPath":         (root.eventData && root.eventData.selectedLayout) ? root.eventData.selectedLayout : "",
                    "capturedPhotos":     photos,
                    "sessionId":          root.sessionId,
                    "newPhotoIndex":      root.pendingRetakeIndex,  // -1 = khÃ´ng cÃ³, >=0 = áº£nh vá»«a retake
                    // Template mode: pre-assign photos to slots in captured order
                    "preAssignedPhotos":  isTemplate ? photos : []
                }
                root.pendingRetakeIndex = -1  // reset sau khi dÃ¹ng
                sessionStack.push(photoCompositionScreenComponent, props)
            }
            onRetakeDiscardedPhoto: function(photoPath) {
                if (!photoPath || photoPath === "") return
                var list = root._retakeDiscardedPhotos ? root._retakeDiscardedPhotos.slice() : []
                if (list.indexOf(photoPath) < 0) list.push(photoPath)
                root._retakeDiscardedPhotos = list
                console.log("[BoothSession] Retake discarded photo kept for gallery:", photoPath)
            }
            onPhotoReady: function(photoPath, photoIndex) {
                if (!photoPath || photoPath === "" || root.eventId <= 0 || !root.sessionId)
                    return
                eventManager.enqueueCaptureAsset(root.eventId, photoPath, root.sessionId, photoIndex)
            }
        }
    }

    // 3.5 Photo Composition Screen
    Component {
        id: photoCompositionScreenComponent
        PhotoCompositionScreen {
            eventId: root.eventId
            // Level 2: Báº¥m X â†’ quay vá» ModeSelection (Level 1), KHÃ”NG thoÃ¡t Dashboard
            onCloseClicked: root.navigateToModeSelection()
            // Quay láº¡i CaptureScreen (pop 1 bÆ°á»›c, giá»¯ nguyÃªn session state)
            // Return to the previous screen in the stack.
            onBackClicked: {
                console.log("BoothSession: Composition back -> returning to previous step")
                sessionStack.pop()
            }
            // Chá»¥p láº¡i 1 áº£nh cá»¥ thá»ƒ: pop vá» CaptureScreen vÃ  trigger retake
            onRetakeRequested: function(photoIndex) {
                console.log("BoothSession: Retake requested for photo index", photoIndex)
                root.pendingRetakeIndex = photoIndex
                sessionStack.pop()
                Qt.callLater(function() {
                    if (root._capturedPhotosAwaitingLayout.length > 0
                            && sessionStack.currentItem
                            && sessionStack.currentItem.selectedLayoutPath !== undefined) {
                        sessionStack.pop()
                    }
                    Qt.callLater(function() {
                        var captureScreen = sessionStack.currentItem
                        if (captureScreen && photoIndex >= 0
                                && typeof captureScreen.retakePhoto === "function") {
                            console.log("BoothSession: Triggering retakePhoto(", photoIndex, ") on CaptureScreen")
                            captureScreen.retakePhoto(photoIndex)
                        } else {
                            console.warn("BoothSession: Could not trigger retake - screen:",
                                         captureScreen, "index:", photoIndex)
                        }
                    })
                })
            }
            onSessionFinished: function(photos, collagePath, transforms) {
                root.handleSessionCompletion(photos, collagePath, transforms)
            }
        }
    }
    // 3.6 Filter Screen (shown between Composition and Result when filter_enabled)
    Component {
        id: filterScreenComponent
        FilterScreen {
            hwid: machineAuth.hwid
            sessionId: root.sessionId
            // In miá»…n phÃ­, sá»‘ báº£n = theo gÃ³i: nÃºt "In áº¢nh" in tháº³ng (khÃ´ng há»i sá»‘ lÆ°á»£ng).
            prePaymentDone:    true
            prePaymentCopies:  Math.max(1, root._selectedPrintCopies)
            // PHẢI khớp điều kiện ghép ảnh ở EventManager
            // (cutMode_compose = event.autoCut && printerConfig.cutMode).
            prePaymentCutMode: !!(root.eventData && root.eventData.autoCut) && printerConfig.cutMode
            onCloseClicked: {
                root.triggerDeferredIndividualSave()
                if (!sessionStack.busy) sessionStack.pop()
            }
            onFrameSelected: function(framePath) {
                console.log("[BoothSession] FilterScreen frame selected:", framePath)
                if (eventManager.updateEventLayout(root.eventId, framePath))
                    root.eventData = eventManager.getEventDetails(root.eventId)
                root._previewUpdateFilter = true
                eventManager.processCollageNoCutAsync(
                    root.eventId, root._pendingPhotos, root._pendingTransforms || [], root.sessionId)
            }
            // Báº¥m "In áº¢nh": in cháº¡y ná»n á»Ÿ FilterScreen, Ä‘iá»u hÆ°á»›ng ngay sang WaitingResults (QR).
            onPrintRequested: function(finalPath, filteredStrip) {
                console.log("[BoothSession] FilterScreen In áº¢nh â†’ WaitingResults: finalPath=" + finalPath + " | strip=" + filteredStrip)
                // Upload báº£n ngÆ°á»i dÃ¹ng chá»‘t (Ä‘Ã£ filter/frame) lÃªn S3 Ä‘á»ƒ QR trá» tá»›i.
                root.uploadCollageToS3(finalPath)
                if (root._deferredIndividualPhotos && root._deferredIndividualPhotos.length > 0) {
                    if (selectedFilterId && selectedFilterId !== "") {
                        root._deferredIndividualFilterRunning = true
                        filterManager.applyFilterToPhotosAsync(root._deferredIndividualPhotos,
                                                               selectedFilterId)
                    } else {
                        root.triggerDeferredIndividualSave()
                    }
                }
                root.pushToWaitingResults(root._pendingPhotos, finalPath, filteredStrip)
            }
            onFinalPrintImageReady: function(finalPath) {
                console.log("[BoothSession] QR overlay final image ready â†’ update WaitingResults/S3:", finalPath)
                root.uploadCollageToS3(finalPath)
                root.updateWaitingResultsFinalImage(finalPath)
            }
        }
    }

    // 4. Result Screen
    Component {
        id: resultScreenComponent
        ResultScreen {
            onFinished: {
                // Restart session for next guest
                // Note: Live View continues running, no need to restart
                // Generate a new session ID so next session gets its own S3 path and QR code
                if (root.eventId > 0) {
                    var hwid = machineAuth.hwid
                    root.sessionId = sessionManager.createSession(root.eventId, hwid)
                    root._applySessionStorage(root.sessionId)  // Originals/<sessionId>/ + sync camera
                    console.log("Session: New session ID for next guest ->", root.sessionId)
                }
                root._returnForNextSession()
            }
            onBackClicked: {
                console.log("Session: Back from Result Screen")
                sessionStack.pop()
            }
            onQrCodeClicked: {
                console.log("Session: QR Code clicked from ResultScreen")
                var hwid = machineAuth.hwid
                sessionStack.push(qrScreenComponent, {
                    "sessionId": sessionId,  // DÃ¹ng sessionId cá»§a ResultScreen, khÃ´ng dÃ¹ng root.sessionId
                    "eventId": root.eventId,
                    "hwid": hwid,
                    "uploadedUrl": uploadedUrl  // From ResultScreen
                })
            }
        }
    }

    // 4b. Waiting Results â€” trang chá» sau khi báº¥m "In áº¢nh": QR + ảnh.
    Component {
        id: waitingResultsComponent
        WaitingResults {
            // "Chá»¥p LÆ°á»£t Má»›i" (hoáº·c háº¿t giá») â†’ táº¡o session má»›i + vá» ModeSelection chá»n gÃ³i.
            onFinished: {
                if (root.eventId > 0) {
                    var hwid = machineAuth.hwid
                    root.sessionId = sessionManager.createSession(root.eventId, hwid)
                    root._applySessionStorage(root.sessionId)  // Originals/<sessionId>/ + sync camera
                    console.log("Session: New session ID for next guest ->", root.sessionId)
                }
                root._returnForNextSession()
            }
        }
    }

    // 5. Gallery Screen
    Component {
        id: galleryScreenComponent
        GalleryScreen {
            eventId:   root.eventId
            eventData: root.eventData
            hwid:      machineAuth.hwid

            onBackClicked: {
                console.log("Session: Back from Gallery")
                sessionStack.pop()
            }
        }
    }
    
    // 6. QR Screen
    Component {
        id: qrScreenComponent
        QRScreen {
            onBackClicked: {
                console.log("Session: Back from QR Screen")
                sessionStack.pop()
            }
            
            onNextSessionClicked: {
                console.log("Session: Start next session from QR Screen")
                // Generate new session ID before returning to mode selection
                if (root.eventId > 0) {
                    var hwid = machineAuth.hwid
                    root.sessionId = sessionManager.createSession(root.eventId, hwid)
                    root._applySessionStorage(root.sessionId)  // Originals/<sessionId>/ + sync camera
                    console.log("Session: New session ID for next guest (from QR Screen) ->", root.sessionId)
                }
                root._returnForNextSession()
            }
        }
    }

    // â”€â”€ PIN xÃ¡c thá»±c khi thoÃ¡t session tá»« ModeSelection (báº£o máº­t báº­t) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    // Nháº­p Ä‘Ãºng PIN admin má»›i cho thoÃ¡t vá» Dashboard. CÃ¡c nÃºt X khÃ¡c (Level 2+)
    // chá»‰ quay vá» ModeSelection nÃªn khÃ´ng cáº§n PIN.
    AdminPinDialog {
        id: exitPinDialog
        parent: Overlay.overlay
        subtitle: "Yêu cầu xác thực để thoát sự kiện"
        onAccepted: root.exitSession()
    }

    // â”€â”€ PIN xÃ¡c thá»±c khi vÃ o Gallery (báº£o máº­t báº­t) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
    AdminPinDialog {
        id: galleryPinDialog
        parent: Overlay.overlay
        subtitle: "Yêu cầu xác thực để xem ảnh"
        onAccepted: sessionStack.push(galleryScreenComponent)
    }

    // â”€â”€ PIN xÃ¡c thá»±c khi thoÃ¡t trang chá» Selfbooth (báº£o máº­t Selfbooth báº­t) â”€â”€â”€â”€â”€
    AdminPinDialog {
        id: sbcutExitPinDialog
        parent: Overlay.overlay
        subtitle: "Yêu cầu xác thực để thoát Selfbooth"
        onAccepted: {
            root._restoreMainCameraSession()
            if (!sessionStack.busy) sessionStack.pop()
        }
    }
}


