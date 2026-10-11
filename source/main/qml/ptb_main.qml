import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.VirtualKeyboard
import "components"
import "pages"
import "theme"

ApplicationWindow {
    id: root
    visible: true
    width: 1600
    height: 900
    minimumWidth: 1024
    minimumHeight: 600
    title: "Photobooth"
    color: Theme.bg

    // Nguồn màu thật nằm ở Theme singleton; các property dưới là binding
    // tương thích ngược cho code cũ tham chiếu Window.window.appBgColor.
    property color  appBgColor:        Theme.bg
    property color  appTextColor:      Theme.text
    property color  appSurfaceColor:   Theme.surface
    property color  appFieldColor:     Theme.field
    property color  appBorderColor:    Theme.border

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

    property string dashboardBgImage:  ""
    // BRAND cố định cho màn ADMIN. "" = nền tối brand.
    readonly property string brandAdminBg: "qrc:/assets/1.png"
    property string landingBgImage:    ""
    property bool globalBackgroundEnabled: false
    property string globalBackgroundImage: ""

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
        console.log("Theme applied:", nextBg.toString(), nextText.toString(), nextSurface.toString(), nextField.toString(), nextBorder.toString())
    }

    function setDashboardBackground(imagePath) {
        root.dashboardBgImage = imagePath
        eventManager.setAppSetting("dashboard_bg_image", imagePath)
        console.log("Dashboard BG image set:", imagePath)
    }

    property string screenAspectRatio: "16:9"
    // Ép cứng màn hình dọc (1080×1920) — không đọc setting screen_orientation.
    property string screenOrientation: "portrait"
    readonly property bool isPortrait: screenOrientation === "portrait"

    function ratioDesignSize(ratio) {
        if (ratio === "16:9")  return { w: 1920, h: 1080 }
        if (ratio === "4:3")   return { w: 1920, h: 1440 }
        if (ratio === "3:2")   return { w: 1920, h: 1280 }
        if (ratio === "21:9")  return { w: 1920, h:  823 }
        if (ratio === "auto")  return { w: root.width, h: root.height }
        var parts = ratio.split(":")
        if (parts.length === 2) {
            var rw = parseFloat(parts[0])
            var rh = parseFloat(parts[1])
            if (rw > 0 && rh > 0) return { w: 1920, h: Math.round(1920 * rh / rw) }
        }
        return { w: 1920, h: 1080 }
    }

    property int  _designW: isPortrait ? 1080 : ratioDesignSize(screenAspectRatio).w
    property int  _designH: isPortrait ? 1920 : ratioDesignSize(screenAspectRatio).h
    property real _contentScale: Math.min(root.width  / Math.max(1, _designW),
                                          root.height / Math.max(1, _designH))

    function applyAspectRatio(ratio) {
        screenAspectRatio = ratio
        if (root.isPortrait)
            return
        if (root.visibility !== Window.FullScreen) {
            var sz = ratioDesignSize(ratio)
            if (ratio !== "auto") {
                root.width  = Math.round(900 * sz.w / sz.h)
                root.height = 900
            }
            root.x = Math.max(0, (Screen.width  - root.width)  / 2)
            root.y = Math.max(0, (Screen.height - root.height) / 2)
        }
        console.log("Ratio:", ratio,
                    "| Design:", _designW + "×" + _designH,
                    "| Scale:", _contentScale.toFixed(4))
    }

    function applyOrientation(orientation) {
        screenOrientation = "portrait"
        if (root.visibility !== Window.FullScreen) {
            if (root.isPortrait) {
                root.width = Math.round(900 * 1080 / 1920)
                root.height = 900
            } else {
                root.applyAspectRatio(screenAspectRatio)
            }
            root.x = Math.max(0, (Screen.width  - root.width)  / 2)
            root.y = Math.max(0, (Screen.height - root.height) / 2)
        }
        console.log("Orientation:", screenOrientation,
                    "| Design:", _designW + "×" + _designH,
                    "| Scale:", _contentScale.toFixed(4))
    }

    Component.onCompleted: {
        // BRAND cố định: theme lấy mặc định từ Theme singleton, KHÔNG đọc từ DB.

        root.dashboardBgImage = eventManager.getAppSetting("dashboard_bg_image", "")
        root.landingBgImage = eventManager.getGlobalLandingBackground()
        root.globalBackgroundEnabled =
            eventManager.getAppSetting("global_background_enabled", "false") === "true"
        root.globalBackgroundImage =
            eventManager.getAppSetting("global_background_image", "")

        root._applyChromeHideMode(eventManager.getAppSetting("chrome_hide_mode", "off"))

        root.screenAspectRatio = eventManager.getAppSetting("screen_aspect_ratio", "16:9")
        root.applyOrientation("portrait")

        root.x = Math.max(0, (Screen.width  - root.width)  / 2)
        root.y = Math.max(0, (Screen.height - root.height) / 2)

        // Luôn mở full màn hình khi khởi động, bỏ qua setting.
        console.log("Fullscreen on startup: always enabled")
        root.showFullScreen()

        var lvMaxW  = parseInt(eventManager.getAppSetting("live_view_max_width",  "0"))
        var lvFps   = parseInt(eventManager.getAppSetting("live_view_target_fps", "30"))
        var fujiLvSize = eventManager.getAppSetting("fuji_live_view_size", "auto")
        var fujiLvQuality = eventManager.getAppSetting("fuji_live_view_quality", "fine")
        cameraController.setMaxLiveViewWidth(lvMaxW)
        cameraController.setTargetLiveViewFps(lvFps)
        cameraController.setFujiLiveViewOptions(fujiLvSize, fujiLvQuality)
        console.log("Live view settings loaded — maxWidth:", lvMaxW, "targetFps:", lvFps)

        // Cổng đăng nhập studio (email + mật khẩu, bắt buộc lần chạy đầu): máy chưa gắn
        // studio thì hiện StudioLoginScreen trước; đăng nhập xong mới vào luồng booth.
        if (!studioAccount.loggedIn) {
            Qt.callLater(function() { stackView.push(studioLoginComponent) })
            return
        }
        // Cổng giấy phép: chưa có chữ ký hợp lệ thì nhập OTP do admin cấp.
        if (!licenseManager.valid) {
            Qt.callLater(root._pushActivation)
            return
        }
        root._startBoothFlow()
    }

    // Chuẩn hóa chế độ vận hành đã lưu theo hạng thiết bị hiện tại (xem main.qml).
    // mode1↔event, mode2/3↔studio. Chế độ không hợp lệ → đổi sang chế độ hợp lệ đầu tiên.
    function _normalizeOperationModeForTier() {
        if (buildFixedOperationMode === "mode2" || buildFixedOperationMode === "mode3")
            return
        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        if (mode === "modebao") return
        var needCap = (mode === "mode2" || mode === "mode3") ? "studio" : "event"
        if (machineAuth.hasCapability(needCap)) return

        var target = ""
        if (machineAuth.hasCapability("event")) target = "mode1"
        else if (machineAuth.hasCapability("studio")) target = "mode2"
        if (target === "" || target === mode) return

        eventManager.setAppSetting("app_operation_mode", target)
        eventManager.setAppSetting("payment_enabled",
                                   (target === "mode2" || target === "mode3") ? "true" : "false")
        console.log("Operation mode normalized for tier:", mode, "→", target)
    }

    // Luồng vào booth sau đăng nhập studio/giấy phép.
    function _ensureStudioEvents() {
        eventManager.getOrCreateStudioEvent("studio2")
        eventManager.getOrCreateStudioEvent("booth")
        eventManager.eventModel.refresh()
    }

    function _modeForEventData(eventData) {
        var name = ((eventData && eventData.name) ? eventData.name : "").trim().toLowerCase()
        if (name === "studio2") return "mode2"
        if (name === "booth") return "mode3"
        return ""
    }

    function _modeForEventId(eventId) {
        return root._modeForEventData(eventManager.getEventDetails(eventId))
    }

    function _applyOperationModeForEvent(eventData) {
        if (buildFixedOperationMode === "mode2" || buildFixedOperationMode === "mode3") {
            eventManager.setAppSetting("app_operation_mode", buildFixedOperationMode)
            eventManager.setAppSetting("payment_enabled", "true")
            eventManager.setAppSetting("multi_event_enabled", "false")
            return true
        }
        var eventMode = root._modeForEventData(eventData)
        if (eventMode === "") return true
        if (!machineAuth.canUseOperationMode(eventMode)) {
            root.showUpgradeNotice()
            return false
        }
        eventManager.setAppSetting("app_operation_mode", eventMode)
        eventManager.setAppSetting("payment_enabled", "true")
        eventManager.setAppSetting("multi_event_enabled", "false")
        return true
    }

    function _showDashboardAfterLogin() {
        root._ensureStudioEvents()
        eventManager.setActiveEventId(-1)
        stackView.replace(dashboardComponent)
    }

    function _showLandingAfterLogin() {
        eventManager.setActiveEventId(-1)
        stackView.replace(landingComponent)
    }

    function _showWaitingAfterLogin() {
        eventManager.setActiveEventId(-1)
        root._launchBoothosEvent()
    }

    function _ensureCurrentOperationModeAllowed() {
        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        if (!machineAuth.canUseOperationMode(mode)) {
            root.showUpgradeNotice()
            return false
        }
        return true
    }

    function _resolveBoothosEventId() {
        if (!root._ensureCurrentOperationModeAllowed())
            return -1
        eventManager.eventModel.refresh()

        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        var eventId = -1
        if (mode === "mode2" || mode === "mode3") {
            var studioName = mode === "mode3" ? "booth" : "studio2"
            eventId = eventManager.getOrCreateStudioEvent(studioName)
            eventManager.setAppSetting("payment_enabled", "true")
            eventManager.setAppSetting("multi_event_enabled", "false")
        } else {
            eventId = eventManager.getOrCreateBoothosEvent()
            eventManager.setAppSetting("payment_enabled", "false")
        }

        if (eventId <= 0) {
            console.error("Main: Failed to get/create launch event for mode", mode)
            return -1
        }
        root.selectedEventId = eventId
        root.selectedEventData = eventManager.getEventDetails(eventId)
        eventManager.setAppSetting("last_event_id", String(eventId))
        printerConfig.loadFromDatabase(eventId)
        return eventId
    }

    function _launchBoothosEvent() {
        var boothosId = root._resolveBoothosEventId()
        if (boothosId <= 0)
            return
        root._launchEvent(boothosId)
    }

    function _openBoothosSettings(initialTab) {
        var boothosId = root._resolveBoothosEventId()
        if (boothosId <= 0)
            return
        root._openSettingsSecure(boothosId, initialTab)
    }

    function _launchEvent(eventId) {
        if (root._boothSessionActive || stackView.busy) {
            console.warn("Main: BoothSession launch ignored; session already active or navigation busy")
            return
        }

        var eventData = eventManager.getEventDetails(eventId)
        if (!root._applyOperationModeForEvent(eventData))
            return
        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        if (!machineAuth.canUseOperationMode(mode)) {
            root.showUpgradeNotice()
            return
        }
        root.selectedEventId = eventId
        root.selectedEventData = eventData
        eventManager.setActiveEventId(eventId)
        eventManager.setAppSetting("last_event_id", String(eventId))
        printerConfig.loadFromDatabase(eventId)
        root._boothSessionActive = true
        var item = stackView.push("pages/BoothSession.qml", {
            "eventId": eventId,
            "eventData": root.selectedEventData
        })
        if (item && item.exitSession) {
            item.exitSession.connect(function() {
                root._boothSessionActive = false
                eventManager.setActiveEventId(-1)
                stackView.pop()
                // Giấy phép mất hiệu lực giữa phiên (thu hồi / hết hạn): không cắt
                // ngang khách đang chụp, chặn ngay khi phiên kết thúc.
                if (!licenseManager.valid) Qt.callLater(root._returnToActivation)
            })
        } else if (item) {
            root._boothSessionActive = false
            console.error("Main: BoothSession loaded but exitSession signal missing")
        } else {
            root._boothSessionActive = false
            console.error("Main: Failed to load BoothSession.qml")
        }
    }

    function _startBoothFlow() {
        root._normalizeUnifiedSecurityLock()
        if (eventManager.getAppSetting("app_open_security_enabled", "false") === "true") {
            appOpenPinDialog.open()
            return
        }
        root._continueBoothFlowAfterSecurity()
    }

    function _normalizeUnifiedSecurityLock() {
        var appLock = eventManager.getAppSetting("app_open_security_enabled", "false") === "true"
        var settingsLock = eventManager.getAppSetting("security_enabled", "false") === "true"
        var legacyLoginLock = eventManager.getAppSetting("login_required", "true") === "true"
        if (!appLock && !settingsLock && legacyLoginLock)
            eventManager.setAppSetting("login_required", "false")
    }

    function _continueBoothFlowAfterSecurity() {
        if (eventManager.getAppSetting("app_operation_mode", "mode1") === "modebao") {
            stackView.push(welcomePaperComponent)
            return
        }

        eventManager.restoreEmployeeSession()
        // Tải studio-info để đồng bộ nhân viên cloud → account local (xem Connections
        // onStudioInfoChanged bên dưới). Cần cả khi tắt đăng nhập (không mở dialog).
        if (machineAuth.hwid) qrLoginManager.fetchStudioInfo(machineAuth.hwid)
        // login_required bật (mặc định) → bắt đăng nhập NV/admin.
        // Tắt → tự đăng nhập thẳng quyền admin, không cần dialog.
        var loginRequired = eventManager.getAppSetting("login_required", "true") === "true"
        if (loginRequired) {
            if (eventManager.currentEmployeeId === 0)
                Qt.callLater(function() { employeeLoginDialog.open() })
            else
                Qt.callLater(root._showWaitingAfterLogin)
        } else {
            eventManager.enterAdminWithoutPassword()
            // Không cần đăng nhập: áp dụng routing theo chế độ nhiều/một sự kiện.
            Qt.callLater(root._showWaitingAfterLogin)
        }
    }

    Connections {
        target: eventManager

        function onAppSettingChanged(key, value) {
            if (key === "chrome_hide_mode")
                root._applyChromeHideMode(value)
            if (key === "global_background_enabled" ||
                key === "global_background_image" ||
                key === "dashboard_bg_image") {
                root.globalBackgroundEnabled =
                    eventManager.getAppSetting("global_background_enabled", "false") === "true"
                root.globalBackgroundImage =
                    eventManager.getAppSetting("global_background_image", "")
                root.dashboardBgImage =
                    eventManager.getAppSetting("dashboard_bg_image", "")
            }
            if (key === "global_background_enabled" ||
                key === "global_background_image" ||
                key === "landing_background") {
                root.landingBgImage = eventManager.getGlobalLandingBackground()
            }
        }
    }

    // Mỗi khi studio-info về từ máy chủ → đồng bộ nhân viên cloud thành account
    // local (idempotent). Nhờ đó combobox đăng nhập và tab Tài khoản đều thấy họ.
    Connections {
        target: qrLoginManager
        function onStudioInfoChanged() {
            var si = qrLoginManager.studioInfo
            if (si && si.loaded === true)
                eventManager.syncCloudStaffAccounts(si.staff || [])
        }
    }

    // Đọc trực tiếp mỗi lần để thay đổi trong Settings có hiệu lực ngay.
    function _multiEventEnabled() {
        // Chế độ 3 mặc định một sự kiện studio (default off) nhưng người dùng có
        // thể bật chọn nhiều sự kiện; các chế độ khác mặc định bật.
        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        if (mode === "mode1") return true
        var def = (mode === "mode3") ? "false" : "true"
        return eventManager.getAppSetting("multi_event_enabled", def) === "true"
    }

    // Sự kiện id có còn tồn tại trong model không (out-of-range → getEventId trả -1).
    function _eventExists(id) {
        if (id <= 0) return false
        for (var i = 0; ; i++) {
            var e = eventManager.eventModel.getEventId(i)
            if (e <= 0) break
            if (e === id) return true
        }
        return false
    }

    // Chọn sự kiện để vào booth ở chế độ một sự kiện:
    // ưu tiên event vừa dùng → event đầu danh sách → tự tạo (cho MỌI chế độ),
    // bảo đảm không bao giờ rơi vào trạng thái "chưa chọn sự kiện".
    function _resolveLaunchEventId() {
        // Chế độ 2/3 luôn dùng (hoặc tạo) sự kiện studio riêng: studio2 / studio3.
        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        if (mode === "mode2" || mode === "mode3") {
            var sName = mode === "mode3" ? "booth" : "studio2"
            var studioId = eventManager.getOrCreateStudioEvent(sName)
            if (studioId > 0) return studioId
        }
        var lastId = parseInt(eventManager.getAppSetting("last_event_id", "-1")) || -1
        if (root._eventExists(lastId)) return lastId
        var firstId = eventManager.eventModel.getEventId(0)
        if (firstId > 0) return firstId
        console.log("Main: no event → auto-create studio event")
        eventManager.createEvent("Studio", "", new Date().toISOString())
        eventManager.eventModel.refresh()
        return eventManager.eventModel.getEventId(0)
    }

    // Khởi chạy booth bằng event vừa dùng trong chế độ một sự kiện.
    // Tự tạo sự kiện nếu chưa có (mọi chế độ) thay vì đẩy về dashboard rỗng.
    function _launchStudioEvent() {
        root._launchBoothosEvent()
    }

    // Lúc boot: nhiều sự kiện thì vào dashboard; một sự kiện thì vào thẳng booth.
    function _maybeAutoLaunchSingleEvent() {
        root._launchBoothosEvent()
    }

    property int selectedEventId: -1
    property var selectedEventData: ({})
    property bool _boothSessionActive: false

    // ── Nền BRAND cố định (window-level). Trang admin để transparent để lộ nền này. ──
    Rectangle { anchors.fill: parent; color: root.appBgColor; z: -3 }
    Image {
        anchors.fill: parent
        source: root.brandAdminBg
        visible: root.brandAdminBg !== ""
        fillMode: Image.PreserveAspectCrop
        z: -2
    }
    Rectangle {
        anchors.fill: parent
        visible: root.brandAdminBg !== ""
        z: -1
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#80000000" }
            GradientStop { position: 1.0; color: "#B3000000" }
        }
    }

    StackView {
        id: stackView

        width:  root._designW
        height: root._designH

        transformOrigin: Item.TopLeft
        scale: root._contentScale

        x: Math.round((root.width  - root._designW * root._contentScale) / 2)
        y: Math.round((root.height - root._designH * root._contentScale) / 2)

        initialItem: landingComponent
    }

    Component {
        id: studioLoginComponent
        StudioLoginScreen {
            onProceed: {
                stackView.pop(null, StackView.Immediate)
                if (!licenseManager.valid) {
                    root._pushActivation()
                    return
                }
                root._startBoothFlow()
            }
        }
    }

    // Kích hoạt máy bằng OTP 4 số (sau đăng nhập studio, khi chưa có chữ ký).
    property bool _activationActive: false

    Component {
        id: activationComponent
        ActivationScreen {
            onProceed: {
                root._activationActive = false
                stackView.pop(null, StackView.Immediate)
                root._startBoothFlow()
            }
        }
    }

    function _pushActivation() {
        if (root._activationActive) return
        root._activationActive = true
        stackView.push(activationComponent)
    }

    // Giấy phép bị thu hồi / hết hạn khi đang chạy → về màn kích hoạt.
    function _returnToActivation() {
        if (root._activationActive || !studioAccount.loggedIn || licenseManager.valid) return
        root._resetNavigationState()
        stackView.clear()
        stackView.push(landingComponent, StackView.Immediate)
        root._activationActive = true
        stackView.push(activationComponent, StackView.Immediate)
    }

    Connections {
        target: licenseManager
        function onLicenseChanged() {
            if (licenseManager.valid || root._boothSessionActive) return
            Qt.callLater(root._returnToActivation)
        }
    }

    // Phiên studio hết hiệu lực (đăng xuất / token bị thu hồi) -> quay về màn đăng nhập.
    function _returnToStudioLogin() {
        root._resetNavigationState()
        stackView.clear()
        stackView.push(landingComponent,      StackView.Immediate)
        stackView.push(studioLoginComponent,  StackView.Immediate)
    }

    Connections {
        target: studioAccount
        function onSignedOut() { Qt.callLater(root._returnToStudioLogin) }
    }

    // Dọn mọi cờ điều hướng ở root. Bắt buộc gọi trước stackView.clear(): clear() hủy
    // SettingsPage/BoothSession mà KHÔNG phát backClicked/exitSession, nên các cờ chống
    // double-click sẽ kẹt true vĩnh viễn và chặn mọi lần mở Cài đặt / vào session sau này.
    function _resetNavigationState() {
        root._settingsOpening    = false
        root._boothSessionActive = false
        root._activationActive   = false
        eventManager.setActiveEventId(-1)
    }

    Component {
        id: welcomePaperComponent
        WelcomePaper {
            onStartRequested: stackView.push(paperSessionComponent)
            onSettingsRequested: {
                adminPinDialog._pendingEventId = -1
                adminPinDialog._pendingInitialTab = 0
                adminPinDialog.open()
            }
            onAdminRequested: {
                adminPinDialog._pendingEventId = -1
                adminPinDialog._pendingInitialTab = 12
                adminPinDialog.open()
            }
        }
    }

    Component {
        id: paperSessionComponent
        PaperSession {
            onExitSession: stackView.pop()
        }
    }

    Component {
        id: landingComponent
        LandingPage {
            backgroundImage: root.landingBgImage
            showSettingsButton: true
            onStartClicked: {
                root._launchBoothosEvent()
            }
            // ⚙ Cài đặt: dùng cài đặt cấp app (eventId = -1), tự hỏi PIN nếu bật bảo mật.
            onSettingsClicked: root._openBoothosSettings()
        }
    }

    Component {
        id: dashboardComponent

        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    color: root.appBgColor

                    EventListPanel {
                        id: eventListPanel
                        anchors.fill: parent
                        backgroundImagePath: root.brandAdminBg
                        onLogoutRequested: {
                            eventManager.employeeLogout()
                            employeeLoginDialog.open()
                        }
                        onQuitRequested: Qt.quit()
                        onEventSelected: function(eventId) {
                            root.selectedEventId = eventId
                            root.selectedEventData = eventManager.getEventDetails(eventId)
                            root._applyOperationModeForEvent(root.selectedEventData)
                        }

                        onSettingsClicked: function(eventId) {
                            root._openSettingsSecure(eventId)
                        }

                        onLaunchEventClicked: function(eventId) {
                            root._launchEvent(eventId)
                        }
                    }
                }
            }
        }
    }

    AdminPinDialog {
        id: appOpenPinDialog
        parent: Overlay.overlay
        forcePin: true
        subtitle: "Nhập PIN bảo mật để mở BOOTHME"
        onAccepted: root._continueBoothFlowAfterSecurity()
    }

    AdminPinDialog {
        id: adminPinDialog
        parent: Overlay.overlay
        forcePin: true
        property int _pendingEventId: -1
        property int _pendingInitialTab: -1
        onAccepted: {
            var eventId = adminPinDialog._pendingEventId
            var initialTab = adminPinDialog._pendingInitialTab
            adminPinDialog._pendingEventId = -1
            adminPinDialog._pendingInitialTab = -1
            root._openSettings(eventId, initialTab)
        }
        onRejected: {
            adminPinDialog._pendingEventId = -1
            adminPinDialog._pendingInitialTab = -1
        }
    }

    // ── Employee Login Dialog (bắt buộc khi mở app, nhớ phiên) ─────────────────
    EmployeeLoginDialog {
        id: employeeLoginDialog
        parent: Overlay.overlay
        onLoggedIn: {
            console.log("Đăng nhập:", eventManager.currentEmployeeName,
                        "| admin:", eventManager.isAdmin)
            Qt.callLater(root._showWaitingAfterLogin)
        }
    }

    // Chặn mở SettingsPage trùng lặp: trang này nặng nên có độ trễ hiển thị; nếu người
    // dùng bấm ⚙ nhiều lần trong lúc chờ, các click dồn lại sẽ đẩy nhiều instance chồng
    // lên stack (gây "bung"). Cờ giữ tới khi rời Settings; kèm guard stackView.busy.
    property bool _settingsOpening: false

    function _openSettings(eventId, initialTab) {
        if (root._settingsOpening || stackView.busy)
            return
        root._settingsOpening = true
        // Mọi getAppSetting/setAppSetting trong SettingsPage sẽ thao tác trên cài
        // đặt riêng của sự kiện này (trừ các key cấp máy).
        if (!root._applyOperationModeForEvent(eventManager.getEventDetails(eventId))) {
            root._settingsOpening = false
            return
        }
        eventManager.setActiveEventId(eventId)
        printerConfig.loadFromDatabase(eventId)
        var item = stackView.push("pages/SettingsPage.qml", {
            "eventData": eventManager.getEventDetails(eventId),
            "currentTab": (initialTab !== undefined) ? initialTab : -1
        })
        if (!item) { root._settingsOpening = false; console.error("Failed to load SettingsPage.qml"); return }
        if (item.backClicked)
            item.backClicked.connect(function() {
                root._settingsOpening = false
                eventManager.setActiveEventId(-1)
                stackView.pop()
            })
        if (item.eventDataUpdated)
            item.eventDataUpdated.connect(function(eid) {
                if (root.selectedEventId === eid)
                    root.selectedEventData = eventManager.getEventDetails(eid)
            })
        if (item.launchClicked)
            item.launchClicked.connect(function() {
                // Bảo mật: gỡ SettingsPage khỏi stack TRƯỚC khi mở session.
                // Nhờ vậy bấm X tại ModeSelection sẽ về Dashboard, không rớt lại
                // vào Settings (vốn vẫn còn sống dưới stack) mà bỏ qua PIN.
                root._settingsOpening = false
                stackView.pop()
                // activeEventId vẫn là sự kiện vừa cấu hình → session áp dụng đúng
                // cài đặt riêng của nó.
                root._launchEvent(root.selectedEventId)
            })
    }

    // Mở Settings có kiểm tra bảo mật (dùng cho Dashboard và nút ⚙ ở ModeSelection).
    function _openSettingsSecure(eventId, initialTab) {
        root.selectedEventId = eventId
        root.selectedEventData = eventManager.getEventDetails(eventId)
        var secOn = eventManager.getAppSetting("security_enabled", "false") === "true"
        if (secOn) {
            adminPinDialog._pendingEventId = eventId
            adminPinDialog._pendingInitialTab = (initialTab !== undefined) ? initialTab : -1
            adminPinDialog.open()
        } else {
            root._openSettings(eventId, initialTab)
        }
    }

    function showUpgradeNotice() { console.log("Upgrade notice suppressed") }

    UpgradeNoticePopup {
        id: entitlementNotice
        onOpenUpgrade: root._openSettings(-1, -1)
    }

    Popup {
        id: authPopup
        modal: true
        closePolicy: Popup.NoAutoClose
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 450
        height: 280
        visible: false

        background: Rectangle {
            color: "#FFFFFF"
            radius: 8
            border.color: "#E0E0E0"
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20
            anchors.verticalCenter: parent.verticalCenter

            Text {
                text: "Xác thực máy"
                color: "#333333"
                font.pixelSize: 18
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Item {
                width: parent.width
                height: 100
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: 15
                    width: parent.width

                    CircularLoadingIndicator {
                        id: authIndicator
                        anchors.horizontalCenter: parent.horizontalCenter
                        status: machineAuth.status
                        size: 60
                        strokeWidth: 4
                        loadingColor: "#333333"
                        successColor: "#4CAF50"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            switch (machineAuth.status) {
                                case 0:  return "Đang khởi động..."
                                case 1:  return "Đang xác thực máy..."
                                case 2:  return "Xác thực thành công!"
                                case 3:  return "Máy chưa được kích hoạt"
                                case 4:  return "Xác thực thất bại"
                                case 5:  return "Lỗi kết nối mạng"
                                default: return "Trạng thái không xác định"
                            }
                        }
                        color: {
                            if (machineAuth.status === 2) return "#4CAF50"
                            if (machineAuth.status === 3 || machineAuth.status === 4 || machineAuth.status === 5)
                                return "#FF9800"
                            return "#333333"
                        }
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Text {
                text: machineAuth.statusMessage
                color: "#555555"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                visible: machineAuth.statusMessage !== ""
            }

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: visible ? 40 : 0
                color: "#F0F2F5"
                radius: 4
                border.color: "#E0E0E0"
                visible: (machineAuth.status === 3 || machineAuth.status === 4) && machineAuth.hwid !== ""

                Row {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 10

                    Text {
                        text: "ID:"
                        color: "#888888"
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: machineAuth.hwid
                        color: "#4CAF50"
                        font.pixelSize: 11
                        font.family: "Courier"
                        verticalAlignment: Text.AlignVCenter
                        Layout.fillWidth: true
                    }
                }
            }

            Button {
                text: "Thử lại"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 150
                height: 40
                visible: machineAuth.status === 5 || machineAuth.status === 4
                enabled: machineAuth.status !== 1
                background: Rectangle {
                    color: parent.hovered ? "#FF9800" : "#FFA500"
                    radius: 4
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                }
                onClicked: {
                    machineAuth.retryAuthentication()
                }
            }
        }

        Connections {
            target: machineAuth
            function onAuthenticationCompleted(success) {
                console.log("Authentication completed:", success)
                if (success) {
                    authPopup.close()
                    root._normalizeOperationModeForTier()
                    if (!machineAuth.hasCapability("event") && !machineAuth.hasCapability("studio"))
                        Qt.callLater(root.showUpgradeNotice)
                } else if (licenseManager.valid) {
                    // Thiếu / mất giấy phép do màn ActivationScreen xử lý, không
                    // mở popup xác thực cũ đè lên.
                    authPopup.open()
                }
            }
        }
    }

    Connections {
        target: eventManager
        function onEventCreated(eventId) {
            console.log("Event created:", eventId)
        }
        function onError(message) {
            console.error("Error:", message)
        }
        // Màn hình dọc ép cứng: không còn phản ứng với screen_orientation.
    }

    Connections {
        target: cameraController
        function onIsConnectedChanged() {
            if (!cameraController.isConnected) return
            // Tôn trọng toggle "Điều khiển qua phần mềm": khi TẮT, không đẩy thông
            // số xuống máy ảnh — để máy ảnh dùng cài đặt trực tiếp trên thân máy.
            if (eventManager.getAppSetting("camera_control_enabled", "false") !== "true") return
            var iso   = eventManager.getAppSetting("camera_iso",      "200")
            var ap    = eventManager.getAppSetting("camera_aperture",  "f/4.5")
            var sh    = eventManager.getAppSetting("camera_shutter",   "1/160")
            var wb    = eventManager.getAppSetting("camera_wb",        "Daylight")
            Qt.callLater(function() {
                cameraController.setIso(iso)
                cameraController.setAperture(ap)
                cameraController.setShutterSpeed(sh)
                cameraController.setWhiteBalance(wb)
            })
        }
    }

    InputPanel {
        id: globalInputPanel
        parent: Overlay.overlay
        z: 9999
        readonly property bool portraitKeyboardHost: parent && parent.width < 760
        width: portraitKeyboardHost ? parent.width : Math.min(parent.width * 0.78, 960)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        visible: Qt.inputMethod.visible
        active: Qt.inputMethod.visible
    }
}
