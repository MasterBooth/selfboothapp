import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.VirtualKeyboard
import "components"
import "pages"
import "pages/selfbooth"
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

    // ── Theme / color state ───────────────────────────────────────────────────
    // Nguồn màu thật nằm ở Theme singleton; các property dưới đây là binding
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

    // Path to dashboard background image (empty = use solid appBgColor)
    property string dashboardBgImage:  ""
    // BRAND cố định cho màn ADMIN (Dashboard + Cài đặt). "" = nền tối brand.
    readonly property string brandAdminBg: "qrc:/assets/1.png"

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

    // Apply colors immediately to window + persist to settings
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

    // Set dashboard background image path and persist
    function setDashboardBackground(imagePath) {
        root.dashboardBgImage = imagePath
        eventManager.setAppSetting("dashboard_bg_image", imagePath)
        console.log("Dashboard BG image set:", imagePath)
    }

    // ── Aspect ratio + content scaling ───────────────────────────────────────
    property string screenAspectRatio: "16:9"
    property string screenOrientation: "landscape"
    readonly property bool isPortrait: screenOrientation === "portrait"

    // Return the logical "design" dimensions for a given ratio string.
    // All content is authored at this size; a uniform scale is applied to fit
    // the actual window / screen, producing letterbox bars when needed.
    // Custom ratios are stored as "W:H" strings (e.g. "16:10", "5:4").
    function ratioDesignSize(ratio) {
        if (ratio === "16:9")  return { w: 1920, h: 1080 }
        if (ratio === "4:3")   return { w: 1920, h: 1440 }
        if (ratio === "3:2")   return { w: 1920, h: 1280 }
        if (ratio === "21:9")  return { w: 1920, h:  823 }
        if (ratio === "auto")  return { w: root.width, h: root.height }  // scale = 1.0, no bars
        // Custom "W:H"
        var parts = ratio.split(":")
        if (parts.length === 2) {
            var rw = parseFloat(parts[0])
            var rh = parseFloat(parts[1])
            if (rw > 0 && rh > 0) return { w: 1920, h: Math.round(1920 * rh / rw) }
        }
        return { w: 1920, h: 1080 }
    }

    // Logical design dimensions (reactive — updates when ratio or window size changes)
    property int  _designW: isPortrait ? 1080 : ratioDesignSize(screenAspectRatio).w
    property int  _designH: isPortrait ? 1920 : ratioDesignSize(screenAspectRatio).h

    // Uniform scale so design content letterboxes into the actual window.
    // In fullscreen on a matching screen this will be exactly 1.0.
    property real _contentScale: Math.min(root.width  / Math.max(1, _designW),
                                          root.height / Math.max(1, _designH))

    // Apply or update ratio — works in BOTH windowed and fullscreen mode.
    function applyAspectRatio(ratio) {
        screenAspectRatio = ratio           // triggers _designW/_designH/_contentScale bindings
        if (root.isPortrait)
            return
        if (root.visibility !== Window.FullScreen) {
            // Windowed: also resize the window to match the ratio at 900 px height
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
        screenOrientation = orientation === "portrait" ? "portrait" : "landscape"
        if (eventManager.getAppSetting("screen_orientation", "landscape") !== screenOrientation)
            eventManager.setAppSetting("screen_orientation", screenOrientation)
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

    // Center window on screen and apply fullscreen / aspect ratio if enabled
    Component.onCompleted: {
        // BRAND cố định: theme lấy mặc định từ Theme singleton, KHÔNG đọc từ DB.

        // Restore saved dashboard background image
        root.dashboardBgImage = eventManager.getAppSetting("dashboard_bg_image", "")

        root.screenOrientation = eventManager.getAppSetting("screen_orientation", "landscape")

        root._applyChromeHideMode(eventManager.getAppSetting("chrome_hide_mode", "off"))

        // Apply aspect ratio first (sets window dimensions)
        var ratio = eventManager.getAppSetting("screen_aspect_ratio", "16:9")
        if (root.isPortrait)
            root.applyOrientation(root.screenOrientation)
        else
            root.applyAspectRatio(ratio)

        // Center
        root.x = Math.max(0, (Screen.width  - root.width)  / 2)
        root.y = Math.max(0, (Screen.height - root.height) / 2)

        // Check if fullscreen on startup is enabled
        var fullscreenEnabled = eventManager.getAppSetting("fullscreen_on_startup", "false")
        if (fullscreenEnabled === "true") {
            console.log("Fullscreen on startup: enabled")
            root.showFullScreen()
        } else {
            console.log("Fullscreen on startup: disabled")
        }

        // Sync live-view performance settings from DB → CameraController.
        // The decode thread reads from cached atomics; this call updates them
        // with the values the user last saved in SettingsPage.
        var lvMaxW  = parseInt(eventManager.getAppSetting("live_view_max_width",  "0"))
        var lvFps   = parseInt(eventManager.getAppSetting("live_view_target_fps", "30"))
        var fujiLvSize = eventManager.getAppSetting("fuji_live_view_size", "auto")
        var fujiLvQuality = eventManager.getAppSetting("fuji_live_view_quality", "fine")
        cameraController.setMaxLiveViewWidth(lvMaxW)
        cameraController.setTargetLiveViewFps(lvFps)
        cameraController.setFujiLiveViewOptions(fujiLvSize, fujiLvQuality)
        console.log("Live view settings loaded — maxWidth:", lvMaxW, "targetFps:", lvFps)

        // Đồng bộ mirror mode (lật ngang live view) NGAY ở đây, thay vì chỉ khi
        // người dùng mở SettingsPage — trước đây đây là chỗ duy nhất từng đọc lại
        // "mirror_mode" từ DB, nên live view luôn khởi động ở giá trị mặc định
        // C++ (m_mirrorMode) cho tới khi người dùng vào Cài đặt. Mặc định "true"
        // để lần chạy đầu tiên (chưa từng lưu) cũng mirror ngay.
        var mirrorEnabled = eventManager.getAppSetting("mirror_mode", "true") === "true"
        cameraController.setMirrorMode(mirrorEnabled)

        // Đăng ký thiết bị phải chạy ở MỌI nhánh, kể cả chế độ Báo (return sớm
        // bên dưới) — nên khởi động bộ đếm trước khi rẽ nhánh.
        machineAuthFallbackTimer.start()

        // Khôi phục phiên đăng nhập nhân viên; nếu chưa đăng nhập → mở dialog
        // bắt buộc sau khi cửa sổ sẵn sàng.
        root._startAfterAppSecurity()
    }

    function _normalizeUnifiedSecurityLock() {
        var appLock = eventManager.getAppSetting("app_open_security_enabled", "false") === "true"
        var settingsLock = eventManager.getAppSetting("security_enabled", "false") === "true"
        var legacyLoginLock = eventManager.getAppSetting("login_required", "true") === "true"
        if (!appLock && !settingsLock && legacyLoginLock)
            eventManager.setAppSetting("login_required", "false")
    }

    function _startAfterAppSecurity() {
        root._normalizeUnifiedSecurityLock()
        if (eventManager.getAppSetting("app_open_security_enabled", "false") === "true") {
            appOpenPinDialog.open()
            return
        }
        root._continueStartupAfterSecurity()
    }

    function _continueStartupAfterSecurity() {
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
                Qt.callLater(root._showDashboardAfterLogin)
        } else {
            eventManager.enterAdminWithoutPassword()
            // Không cần đăng nhập + chỉ có đúng 1 sự kiện → vào thẳng khởi chạy.
            Qt.callLater(root._showDashboardAfterLogin)
        }
    }

    // main.cpp luôn gọi machineAuth->authenticate() khi nạp QML. Máy chỉ gắn
    // studio sau khi đăng nhập StudioAccount và nhận machine token riêng.
    //
    // Đặt trễ hơn bộ đếm 500 ms bên main.cpp rồi mới kiểm status: nếu bên kia
    // đã xác thực thì status khác 0 và ở đây bỏ qua, tránh gọi trùng.
    Timer {
        id: machineAuthFallbackTimer
        interval: 1500
        repeat: false
        onTriggered: {
            if (machineAuth.status === 0) {
                console.log("[main] Máy chưa được xác thực sau khởi động — gọi bù authenticate()")
                machineAuth.authenticate()
            }
        }
    }

    // Tự khởi chạy session nếu chỉ có duy nhất 1 sự kiện (dùng khi tắt đăng nhập).
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

    function _launchEvent(eventId) {
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
        var item = stackView.push("pages/BoothSession.qml", {
            "eventId": eventId,
            "eventData": root.selectedEventData
        })
        if (item && item.exitSession) {
            item.exitSession.connect(function() {
                eventManager.setActiveEventId(-1)
                stackView.pop()
            })
        } else if (item) {
            console.error("Main: BoothSession loaded but exitSession signal missing")
        } else {
            console.error("Main: Failed to load BoothSession.qml")
        }
    }

    function _maybeAutoLaunchSingleEvent() {
        root._showDashboardAfterLogin()
    }

    property int selectedEventId: -1
    property var selectedEventData: ({})

    // ── Letterbox background ─────────────────────────────────────────────────
    // Fills any bars left by the letterbox (visible on non-matching screens).
    // ── Nền BRAND cố định (window-level). Trang admin để transparent để lộ nền này. ──
    Rectangle { anchors.fill: parent; color: root.appBgColor; z: -3 }
    Image {
        anchors.fill: parent
        source: root.brandAdminBg
        visible: root.brandAdminBg !== ""
        fillMode: Image.PreserveAspectCrop
        z: -2
    }

    // ── Scaled content container ─────────────────────────────────────────────
    // The StackView operates in "design coordinates" (_designW × _designH).
    // A uniform scale + centering offset letterboxes it into whatever screen
    // or window size is actually available — no layout code needs to change.
    StackView {
        id: stackView

        // Design (logical) dimensions
        width:  root._designW
        height: root._designH

        // Scale uniformly from the top-left corner
        transformOrigin: Item.TopLeft
        scale: root._contentScale

        // Center horizontally + vertically (letterbox offset)
        x: Math.round((root.width  - root._designW * root._contentScale) / 2)
        y: Math.round((root.height - root._designH * root._contentScale) / 2)

        initialItem: modePickerComponent
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

    // ── Mode picker (startup screen) ─────────────────────────────────────────
    Component {
        id: paperSessionComponent
        PaperSession {
            onExitSession: stackView.pop()
        }
    }

    Component {
        id: modePickerComponent
        ModePicker {
            onPhotoboothSelected: {
                stackView.push(landingComponent)
            }
            onSelfBoothSelected:  {
                // Khóa SELF BOOTH theo hạng thiết bị: chỉ tier có cap 'selfbooth'.
                if (!machineAuth.hasCapability("selfbooth")) {
                    root.showUpgradeNotice()
                    return
                }
                root._welcomeSelfRef = stackView.push(welcomeSelfComponent)
            }
        }
    }

    // Reference to the WelcomeSelf item so LCaptureSelf can pop back to it
    property var _welcomeSelfRef: null

    Component {
        id: landingComponent
        LandingPage {
            backgroundImage: eventManager.getGlobalLandingBackground()
            onStartClicked: {
                // Chế độ thanh toán (mode2/mode3): bỏ qua Dashboard, tự dùng sự kiện
                // "studio" rồi vào thẳng ModeSelection. X tại ModeSelection sẽ về Landing.
                var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
                if (!machineAuth.canUseOperationMode(mode)) {
                    root.showUpgradeNotice()
                    return
                }
                root._showDashboardAfterLogin()
            }
        }
    }

    // ── Self Booth components ────────────────────────────────────────────────
    Component {
        id: welcomeSelfComponent
        WelcomeSelf {
            onSettingsClicked: stackView.push(settingSelfComponent)
            onTapToStart:      stackView.push(optionTimeComponent)
        }
    }

    Component {
        id: settingSelfComponent
        SettingSelf {
            onBackClicked: stackView.pop()
        }
    }

    Component {
        id: optionTimeComponent
        OptionTime {
            onBackClicked: stackView.pop()
            onTimeSelected: function(minutes) {
                stackView.push(lCaptureSelfComponent, { "selectedMinutes": minutes })
            }
        }
    }

    Component {
        id: lCaptureSelfComponent
        LCaptureSelf {
            onSessionDone: function(sid, photos) {
                stackView.push(qrcodeSelfComponent, { "sessionId": sid })
            }
            onCameraFailed: {
                if (root._welcomeSelfRef)
                    stackView.pop(root._welcomeSelfRef)
                else
                    stackView.pop(null)
            }
            onCancelClicked: {
                if (root._welcomeSelfRef)
                    stackView.pop(root._welcomeSelfRef)
                else
                    stackView.pop(null)
            }
        }
    }

    Component {
        id: qrcodeSelfComponent
        QRCodeSelf {
            onBackClicked: {
                if (root._welcomeSelfRef)
                    stackView.pop(root._welcomeSelfRef)
                else
                    stackView.pop(null)
            }
            onNextSession: {
                if (root._welcomeSelfRef)
                    stackView.pop(root._welcomeSelfRef)
                else
                    stackView.pop(null)
            }
        }
    }

    // Dashboard Page Component
    Component {
        id: dashboardComponent

        Item {
            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Full-width Event List Panel
                Item {
                    Layout.fillHeight: true
                    Layout.fillWidth: true

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

                        // Settings click from TopBar or detail dialog
                        onSettingsClicked: function(eventId) {
                            root._openSettingsSecure(eventId)
                        }

                        // Launch from detail dialog
                        onLaunchEventClicked: function(eventId) {
                            root._launchEvent(eventId)
                        }
                    }
                }
            }
        }
    }

    // New Event Dialog (Global)
    NewEventDialog {
        id: newEventDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
    }

    // ── Admin PIN Dialog ──────────────────────────────────────────────────────
    AdminPinDialog {
        id: appOpenPinDialog
        parent: Overlay.overlay
        forcePin: true
        subtitle: "Nhập PIN bảo mật để mở BOOTHME"
        onAccepted: root._continueStartupAfterSecurity()
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
        onLoggedIn: console.log("Đăng nhập:", eventManager.currentEmployeeName,
                                "| admin:", eventManager.isAdmin)
    }

    // Mở Settings — dùng chung cho cả 2 luồng (có/không bảo mật)
    Connections {
        target: employeeLoginDialog
        function onLoggedIn() {
            Qt.callLater(root._showDashboardAfterLogin)
        }
    }

    // Chặn mở SettingsPage trùng lặp: trang nặng nên có độ trễ hiển thị; bấm ⚙ nhiều
    // lần trong lúc chờ sẽ đẩy nhiều instance chồng lên stack (gây "bung"). Cờ giữ tới
    // khi rời Settings; kèm guard stackView.busy.
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
                var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
                if (!machineAuth.canUseOperationMode(mode)) {
                    root.showUpgradeNotice()
                    return   // Settings vẫn mở → giữ cờ, không cho mở trùng.
                }
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
    // Bật security_enabled → hỏi PIN admin; ngược lại mở thẳng.
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

    // Chế độ thanh toán: tự dùng/tạo sự kiện "studio" rồi vào thẳng BoothSession
    // (push trên LandingPage để bấm X/exitSession sẽ pop về Landing).
    function _enterPaymentMode() {
        var mode = eventManager.getAppSetting("app_operation_mode", "mode2")
        if (!machineAuth.canUseOperationMode(mode)) {
            root.showUpgradeNotice()
            return
        }
        // Chế độ 2 → sự kiện "studio2"; chế độ 3 → "studio3" (tự tạo nếu chưa có).
        var studioName = mode === "mode3" ? "booth"
                       : (mode === "mode2" ? "studio2" : "")
        var sid = eventManager.getOrCreateStudioEvent(studioName)
        if (sid <= 0) {
            console.error("Main: Failed to get/create studio event")
            return
        }
        root.selectedEventId = sid
        root.selectedEventData = eventManager.getEventDetails(sid)
        eventManager.setActiveEventId(sid)
        printerConfig.loadFromDatabase(sid)
        var s = stackView.push("pages/BoothSession.qml", {
            "eventId":   sid,
            "eventData": root.selectedEventData
        })
        if (s && s.exitSession)
            s.exitSession.connect(function() {
                eventManager.setActiveEventId(-1)
                stackView.pop()
            })
        else if (s)
            console.error("Main: BoothSession loaded but exitSession signal missing")
        else
            console.error("Main: Failed to load BoothSession.qml")
    }

    // Thông báo cần nâng cấp gói (khi chế độ/tính năng không thuộc hạng thiết bị).
    function showUpgradeNotice() {
        console.log("Upgrade notice suppressed")
    }

    function _showUpgradeNotice() { showUpgradeNotice() }

    UpgradeNoticePopup {
        id: entitlementNotice
        onOpenUpgrade: root._openSettings(-1, -1)
    }

    // Chuẩn hóa chế độ vận hành đã lưu theo hạng thiết bị hiện tại.
    // Nếu chế độ đang lưu cần cap mà máy không có (mode1↔event, mode2/3↔studio),
    // tự đổi sang chế độ hợp lệ đầu tiên: ưu tiên mode1 (event), rồi mode2 (studio).
    // Không có cả hai (fail-open / tier lạ) → giữ nguyên.
    function _normalizeOperationModeForTier() {
        if (buildFixedOperationMode === "mode2" || buildFixedOperationMode === "mode3")
            return
        var mode = eventManager.getAppSetting("app_operation_mode", "mode1")
        if (mode === "modebao") return   // chế độ Báo không thuộc khóa tier
        var needCap = (mode === "mode2" || mode === "mode3") ? "studio" : "event"
        if (machineAuth.hasCapability(needCap)) return   // chế độ hiện tại hợp lệ

        var target = ""
        if (machineAuth.hasCapability("event")) target = "mode1"
        else if (machineAuth.hasCapability("studio")) target = "mode2"
        if (target === "" || target === mode) return     // không có lựa chọn hợp lệ

        eventManager.setAppSetting("app_operation_mode", target)
        eventManager.setAppSetting("payment_enabled",
                                   (target === "mode2" || target === "mode3") ? "true" : "false")
        console.log("Operation mode normalized for tier:", mode, "→", target)
    }

    // ── Popup thông báo nâng cấp gói ───────────────────────────────────────────
    Popup {
        id: upgradeNoticePopup
        modal: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: 460
        padding: 28

        background: Rectangle {
            color: Theme.surface
            radius: 12
            border.color: Theme.border
            border.width: 1
        }

        Column {
            anchors.fill: parent
            spacing: 22

            Text {
                text: "Thông báo"
                color: Theme.text
                font.pixelSize: 18
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                width: parent.width
                text: "Gói dịch vụ chưa được nâng cấp, vui lòng vào mục Thông tin để nâng cấp."
                color: Theme.text
                font.pixelSize: 15
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }

            Button {
                text: "Đã hiểu"
                anchors.horizontalCenter: parent.horizontalCenter
                width: 160
                height: 42
                background: Rectangle {
                    color: parent.hovered ? "#2a7fff" : "#1e6eea"
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 14
                    font.bold: true
                }
                onClicked: upgradeNoticePopup.close()
            }
        }
    }

    // ============= Authentication Popup =============
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

            // Header
            Text {
                text: "Xác thực máy"
                color: "#333333"
                font.pixelSize: 18
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Status Indicator
            Item {
                width: parent.width
                height: 100
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: 15
                    width: parent.width

                    // Circular loading indicator
                    CircularLoadingIndicator {
                        id: authIndicator
                        anchors.horizontalCenter: parent.horizontalCenter
                        status: machineAuth.status
                        size: 60
                        strokeWidth: 4
                        loadingColor: "#333333"
                        successColor: "#4CAF50"
                    }

                    // Status text
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: {
                            switch (machineAuth.status) {
                                case 0:  // NotChecked
                                    return "Đang khởi động..."
                                case 1:  // Checking
                                    return "Đang xác thực máy..."
                                case 2:  // Authenticated
                                    return "Xác thực thành công!"
                                case 3:  // Pending
                                    return "Máy chưa được kích hoạt"
                                case 4:  // Failed
                                    return "Xác thực thất bại"
                                case 5:  // NetworkError
                                    return "Lỗi kết nối mạng"
                                default:
                                    return "Trạng thái không xác định"
                            }
                        }
                        color: {
                            if (machineAuth.status === 2) return "#4CAF50"  // Green
                            if (machineAuth.status === 3 || machineAuth.status === 4 || machineAuth.status === 5)
                                return "#FF9800"  // Orange
                            return "#333333"
                        }
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            // Status Message
            Text {
                text: machineAuth.statusMessage
                color: "#555555"
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                wrapMode: Text.WordWrap
                visible: machineAuth.statusMessage !== ""
            }

            // HWID Display (for pending/failed states)
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

            // Retry Button
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
                    // Có capabilities theo hạng thiết bị → chuẩn hóa chế độ đã lưu.
                    root._normalizeOperationModeForTier()
                    if (!machineAuth.hasCapability("event") &&
                        !machineAuth.hasCapability("studio") &&
                        !machineAuth.hasCapability("selfbooth"))
                        Qt.callLater(root.showUpgradeNotice)
                } else {
                    authPopup.open()
                }
            }
        }
    }

    // Connect to backend signals
    Connections {
        target: eventManager
        function onEventCreated(eventId) {
            console.log("Event created:", eventId)
        }
        function onError(message) {
            console.error("Error:", message)
        }
        function onAppSettingChanged(key, value) {
            if (key === "screen_orientation")
                root.applyOrientation(value)
            else if (key === "chrome_hide_mode")
                root._applyChromeHideMode(value)
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

    // Apply camera defaults when camera connects
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

    // ── Global Virtual Keyboard ───────────────────────────────────────────────
    // Phải dùng parent: Overlay.overlay để nằm TRONG cùng layer với modal Popup.
    // Nếu để ở root level, Overlay sẽ render trên và block touch events tới bàn phím.
    // z: 9999 đảm bảo InputPanel nằm trên mọi Popup/Dialog trong Overlay.
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
