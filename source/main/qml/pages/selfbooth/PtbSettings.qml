import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.platform as Platform
import QtQuick.VirtualKeyboard
import QtMultimedia
import "../session"
import "../../components"
import "../../js/CameraHelpers.js" as CameraHelpers
import "../../utils/Money.js" as Money
import "../../theme"

Rectangle {
    id: root
    // Derived theme colors — direct expression so QML tracks dependency changes
    property color themeBgColor:      Window.window ? Window.window.appBgColor      : "#000000"
    property color themeTextColor:    Theme.settingsText
    property color themeSurfaceColor: Theme.settingsSurface
    property color themeFieldColor:   Theme.settingsCard
    property color themeBorderColor:  Theme.settingsBorder
    property string adminBackgroundImage: Window.window && Window.window.brandAdminBg ? Window.window.brandAdminBg : ""
    property var _backgroundMediaFilters: ["Background Media (*.png *.jpg *.jpeg *.mp4)", "Image Files (*.png *.jpg *.jpeg)", "MP4 Video (*.mp4)"]

    function mutedText(alpha) {
        return Qt.rgba(root.themeTextColor.r, root.themeTextColor.g, root.themeTextColor.b, alpha)
    }

    function mixColors(base, ink, amount) {
        return Qt.rgba(base.r + (ink.r - base.r) * amount,
                       base.g + (ink.g - base.g) * amount,
                       base.b + (ink.b - base.b) * amount,
                       1.0)
    }

    function isDarkColor(bg) {
        return (bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114) < 0.55
    }

    function contrastTextFor(bg) {
        return root.isDarkColor(bg) ? "#FFFFFF" : "#1F2430"
    }

    function resolveImageSource(path) {
        if (!path) return ""
        if (path.indexOf("http") === 0 || path.indexOf("file:") === 0 || path.indexOf("qrc:") === 0)
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    // Trong suốt để các khối cài đặt lộ nền BRAND riêng của Settings.
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        visible: root.adminBackgroundImage === ""
        color: root.themeBgColor
        z: -10
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.adminBackgroundImage
        visible: root.adminBackgroundImage !== ""
        z: -9
    }

    signal backClicked()
    signal eventDataUpdated(int eventId)
    signal launchClicked()

    // -1 = chế độ menu (lưới ô cài đặt + dải thống kê); >= 0 = đang xem chi tiết một mục
    property int currentTab: -1
    // Tiêu đề trang con bên trong Cài đặt chung; rỗng = màn tổng quan.
    property string generalSectionTitle: ""
    property string settingsSearchText: ""
    property var eventData: null

    // ── Thống kê sự kiện (hiển thị ở dải trên cùng của menu) ───────────────────
    property int  statPhotos:  0
    property int  statPrints:  0
    property int  statFrames:  0
    property real statRevenue: 0

    function refreshStats() {
        var id = (root.eventData && root.eventData.id) ? root.eventData.id : -1
        if (id <= 0) {
            statPhotos = 0; statPrints = 0; statFrames = 0; statRevenue = 0
            return
        }
        var d = eventManager.getEventDetails(id)
        statPhotos = (d.totalPhotos !== undefined) ? d.totalPhotos : 0
        statPrints = (d.printCount  !== undefined) ? d.printCount  : 0

        var layouts = eventManager.getLayouts(id)
        statFrames = layouts ? layouts.length : 0

        // Doanh thu thực nhận của riêng sự kiện này (lọc theo event_id).
        var recs = eventManager.getRevenueRecords("time", eventManager.isAdmin ? -1 : -2)
        var rev = 0
        for (var i = 0; i < recs.length; i++) {
            if ((recs[i].event_id || 0) === id) rev += (recs[i].received_amount || 0)
        }
        statRevenue = rev
    }

    onCurrentTabChanged: {
        if (currentTab >= 0 && !root._isSettingsTabVisible(currentTab)) {
            currentTab = -1
            generalSectionTitle = ""
        } else {
            if (currentTab === -1) refreshStats()
            if (currentTab !== 0) generalSectionTitle = ""
        }
    }

    Timer {
        id: statsRefreshTimer
        interval: 5000
        repeat: true
        running: root.currentTab === -1
        onTriggered: root.refreshStats()
    }

    Connections {
        target: eventManager
        function onPrintCountChanged(eid) {
            var id = (root.eventData && root.eventData.id) ? root.eventData.id : -1
            if (eid === id) root.refreshStats()
        }
    }

    property string _voucherExportContent: ""
    property url _exportFolder: Platform.StandardPaths.writableLocation(Platform.StandardPaths.DocumentsLocation)
    property int _bgRefreshCount: 0
    property int _catRefreshCount: 0
    property int _framesRefreshCount: 0
    property string pendingCategoryScroll: ""
    property int categoryScrollRequest: 0
    property var _comPorts: []
    property string _operationMode: eventManager.getAppSetting("app_operation_mode", eventManager.getAppSetting("payment_enabled", "false") === "true" ? "mode2" : "mode1")
    property bool _paymentEnabledSetting: eventManager.getAppSetting("payment_enabled", "false") === "true"
    property var _hiddenSettingsTabIds: {
        var tabs = ["sharing", "frames", "filters", "ai", "gallery", "voucher", "payment"]
        if (buildFixedOperationMode === "mode2" || buildFixedOperationMode === "mode3")
            tabs.push("mode")
        return tabs
    }

    function _sanitizeFileToken(s) {
        return (s || "").replace(/[\\\/:*?"<>|]/g, "").replace(/\s+/g, "-").replace(/-+/g, "-")
    }

    function buildExportName(prefix, statusToken, ext) {
        var who = eventManager.isAdmin ? "admin"
                : ("NV-" + (eventManager.currentEmployeeName || "NV"))
        var ts = Qt.formatDateTime(new Date(), "yyyyMMdd_HHmm")
        return root._sanitizeFileToken(prefix) + "_" + root._sanitizeFileToken(statusToken) + "_"
             + ts + "_" + root._sanitizeFileToken(who) + "." + (ext || "txt")
    }

    function exportVoucherTxt(content, prefix, statusToken) {
        root._voucherExportContent = content
        var name = root.buildExportName(prefix, statusToken, "txt")
        voucherSaveDialog.folder = root._exportFolder
        voucherSaveDialog.currentFile = root._exportFolder + "/" + name
        voucherSaveDialog.open()
    }

    function _applyStudioModeDefaults() {
        eventManager.setAppSetting("qr_code_enabled", "true")
        eventManager.setAppSetting("payment_enabled", "true")
        eventManager.setAppSetting("bank_transfer_enabled", "true")
        eventManager.setAppSetting("cash_payment_enabled", "true")
        eventManager.setAppSetting("cash_payment_code_enabled", "true")
        eventManager.setAppSetting("voucher_enabled", "true")
        eventManager.setAppSetting("filter_enabled", "true")
        eventManager.setAppSetting("sticker_enabled", "true")
        eventManager.setAppSetting("no_retake_enabled", "false")
        eventManager.setAppSetting("flip_photo_enabled", "true")
        eventManager.setAppSetting("photo_review_enabled", "false")
    }

    function _setOperationMode(mode, fromUser) {
        if (fromUser === undefined) fromUser = true
        var normalizedMode = mode === "modebao" ? "modebao"
                           : (mode === "mode3" ? "mode3" : (mode === "mode2" ? "mode2" : "mode1"))
        // Khóa chế độ theo gói: Chế độ 1 cần 'event'; Chế độ 2/3 cần 'studio'.
        if (fromUser) {
            if (normalizedMode === "mode1" && !machineAuth.hasCapability("event")) {
                autoSavedToast.show("Gói dịch vụ chưa được mua hoặc chưa được cập nhật. Vui lòng vào Cài đặt > Thông tin để nâng cấp.")
                return false
            }
            if ((normalizedMode === "mode2" || normalizedMode === "mode3") && !machineAuth.hasCapability("studio")) {
                autoSavedToast.show("Gói dịch vụ chưa được mua hoặc chưa được cập nhật. Vui lòng vào Cài đặt > Thông tin để nâng cấp.")
                return false
            }
        }
        root._operationMode = normalizedMode
        root._paymentEnabledSetting = normalizedMode === "mode2" || normalizedMode === "mode3"
        eventManager.setAppSetting("app_operation_mode", normalizedMode)
        eventManager.setAppSetting("payment_enabled", root._paymentEnabledSetting ? "true" : "false")
        if (fromUser && (normalizedMode === "mode2" || normalizedMode === "mode3")) {
            root._applyStudioModeDefaults()
            root._paymentEnabledSetting = true
        }
        // Chế độ 2/3 luôn dùng một sự kiện studio riêng (studio2/studio3) →
        // tắt chọn nhiều sự kiện và ẩn nút bật/tắt.
        if (normalizedMode === "mode1")
            eventManager.setAppSetting("multi_event_enabled", "true")
        else if (normalizedMode === "mode2" || normalizedMode === "mode3")
            eventManager.setAppSetting("multi_event_enabled", "false")
        return true
    }

    // ── Khóa tab cho nhân viên (admin tick tab nào → NV phải nhập pass) ────────
    // Danh sách index tab bị khóa, lưu ở app_settings "staff_locked_tabs" (JSON).
    property var _lockedTabs: {
        try { return JSON.parse(eventManager.getAppSetting("staff_locked_tabs", "[]")) }
        catch (e) { return [] }
    }
    function _isTabLocked(idx) {
        // Admin (root) luôn vào được; chỉ khóa với nhân viên thường.
        if (eventManager.isAdmin) return false
        for (var i = 0; i < _lockedTabs.length; i++)
            if (_lockedTabs[i] === idx) return true
        return false
    }
    // Đổi tab có kiểm tra khóa — gọi từ sidebar.
    function _isSettingsTabVisible(idx) {
        if (idx < 0 || idx >= sidebarModel.count) return false
        var tabId = sidebarModel.get(idx).tabId
        return root._hiddenSettingsTabIds.indexOf(tabId) < 0
    }

    function _visibleTabIndexes(indexes) {
        var result = []
        for (var i = 0; i < indexes.length; ++i) {
            if (root._isSettingsTabVisible(indexes[i]))
                result.push(indexes[i])
        }
        return result
    }

    function _openVisibleTab(idx) {
        if (!root._isSettingsTabVisible(idx)) {
            root.currentTab = -1
            root.generalSectionTitle = ""
            return false
        }
        root.currentTab = idx
        return true
    }

    function _requestTab(idx) {
        if (!root._isSettingsTabVisible(idx)) {
            root.currentTab = -1
            root.generalSectionTitle = ""
            return
        }
        if (_isTabLocked(idx)) {
            staffLockDialog.pendingTab = idx
            staffLockDialog.open()
        } else {
            root._openVisibleTab(idx)
        }
    }

    function _settingsMatches(idx) {
        if (idx < 0 || idx >= sidebarModel.count) return false
        if (!root._isSettingsTabVisible(idx)) return false
        var q = (root.settingsSearchText || "").trim().toLowerCase()
        if (q === "") return true
        var item = sidebarModel.get(idx)
        var haystack = (item.name + " " + item.desc + " " + item.keywords).toLowerCase()
        return haystack.indexOf(q) >= 0
    }

    function _groupHasMatches(groupName) {
        for (var i = 0; i < sidebarModel.count; ++i) {
            var item = sidebarModel.get(i)
            if (item.group === groupName && root._settingsMatches(i)) return true
        }
        return false
    }

    Component.onCompleted: {
        root._setOperationMode(root._operationMode, false)

        var ports = billAcceptor.availablePorts()
        _comPorts = ports.length > 0 ? ports : ["(Không tìm thấy cổng COM)"]

        // Luôn mở vào màn hình menu (currentTab === -1) — không lộ nội dung tab
        // bị khóa; nhân viên phải nhập pass khi bấm vào ô khóa.
        root.refreshStats()
    }


    ListModel { id: layoutModel }

    // Layout Reprocess Progress Dialog
    Popup {
        id: reprocessDialog
        modal: true
        Overlay.modal: Rectangle { color: "transparent" }
        anchors.centerIn: parent
        width: 420
        height: 200
        closePolicy: Popup.NoAutoClose

        property int current: 0
        property int total: 1
        property string currentFile: ""

        background: Rectangle {
            color: root.themeSurfaceColor
            border.color: root.themeBorderColor
            border.width: 1
            radius: 12
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Text {
                text: "Đang chuẩn hóa layouts..."
                color: root.themeTextColor
                font.pixelSize: 16
                font.weight: Font.Bold
                Layout.alignment: Qt.AlignHCenter
            }

            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                running: reprocessDialog.visible
            }

            ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: reprocessDialog.total
                value: reprocessDialog.current

                background: Rectangle {
                    implicitHeight: 8
                    color: root.themeFieldColor
                    radius: 4
                }

                contentItem: Item {
                    implicitHeight: 8

                    Rectangle {
                        width: reprocessDialog.total > 0
                            ? parent.width * (reprocessDialog.current / reprocessDialog.total)
                            : 0
                        height: parent.height
                        radius: 4
                        color: "#6c5ce7"

                        Behavior on width {
                            NumberAnimation { duration: 200 }
                        }
                    }
                }
            }

            Text {
                text: reprocessDialog.current + " / " + reprocessDialog.total + " layouts"
                color: root.mutedText(0.65)
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // Tiến trình thao tác khung theo lô (tải lên / xoá / đổi tên).
    FrameProgressDialog {
        id: frameProgress
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        surfaceColor: root.themeSurfaceColor
        textColor:    root.themeTextColor
        mutedColor:   root.mutedText(0.65)
        borderColor:  root.themeBorderColor
        trackColor:   root.themeFieldColor
        onDismissedToBackground: autoSavedToast.show("Đang xử lý khung hình ở nền...")
    }

    Connections {
        target: eventManager

        // ── Thao tác khung theo lô ───────────────────────────────────────────
        // Cả lô chỉ phát layoutUploaded MỘT lần ở cuối, nên danh sách chỉ nạp lại
        // 1 lần thay vì N+1 lần như khi gọi bản đơn trong vòng lặp.
        function onFrameTaskStarted(op, total) {
            root._frameBusy = true
            frameProgress.begin(op, total)
        }
        function onFrameTaskProgress(current, total, fileName) {
            frameProgress.update(current, total, fileName)
        }
        function onFrameTaskFinished(op, ok, failed, errors) {
            root._frameBusy = false
            root._categoryAssignRunning = false
            frameProgress.finish(ok, failed, errors)
        }
        // Khóa app-setting "frame_image_*" do QML sinh nên C++ không tự dọn được.
        function onFrameDeleted(layoutPath) {
            root.clearFrameImage(layoutPath)
        }
        function onFrameRenamed(oldPath, newPath) {
            root.migrateFrameImage(oldPath, newPath)
        }
    }

    Connections {
        target: eventManager

        // Refresh eventData whenever any setting is saved to DB,
        // so navigating away and back always shows the latest values.
        function onEventUpdated(eventId) {
            if (root.eventData && root.eventData.id === eventId) {
                root.eventData = eventManager.getEventDetails(eventId)
                root.eventDataUpdated(eventId)
            }
        }

        function onLayoutReprocessStarted(totalLayouts) {
            console.log("[SettingsPage] *** REPROCESS STARTED signal received ***")
            console.log("[SettingsPage] Total layouts:", totalLayouts)
            reprocessDialog.total = totalLayouts
            reprocessDialog.current = 0
            reprocessDialog.open()
            console.log("[SettingsPage] Dialog opened")
        }

        function onLayoutReprocessProgress(current, total, fileName) {
            console.log("[SettingsPage] Progress:", current, "/", total, "-", fileName)
            reprocessDialog.current = current
            reprocessDialog.total = total
            reprocessDialog.currentFile = fileName
        }

        function onLayoutReprocessFinished(layoutsProcessed) {
            console.log("[SettingsPage] *** REPROCESS FINISHED signal received ***")
            console.log("[SettingsPage] Layouts processed:", layoutsProcessed)
            reprocessDialog.close()
            refreshLayouts()
        }
    }

    Platform.FileDialog {
        id: layoutUploadDialog
        title: "Select Layout Templates (PNG)"
        nameFilters: ["PNG Images (*.png)"]
        fileMode: Platform.FileDialog.OpenFiles
        onAccepted: {
            var files = currentFiles

            if (root._operationMode === "modebao") {
                // Khung giấy vẫn dùng bản đơn (thư mục data/PaperLayouts riêng).
                for (var p = 0; p < files.length; p++)
                    eventManager.uploadPaperLayout(files[p])
            } else if (root.eventData && root.eventData.id > 0) {
                // Một lời gọi cho cả lô: xử lý tuần tự ở nền, có dialog tiến trình,
                // và chỉ nạp lại danh sách 1 lần khi xong.
                eventManager.uploadLayoutsBatch(root.eventData.id, root._toPathList(files), "")
            } else {
                console.warn("No active event selected for layout upload")
            }
        }
    }

    // Tải frame lên trực tiếp cho một nhóm (category): dùng đúng cơ chế uploadLayout
    // (gồm scale/normalise), sau khi xử lý xong sẽ tự gán tiền tố nhóm.
    Platform.FileDialog {
        id: categoryUploadDialog
        title: "Chọn khung hình cho nhóm (PNG)"
        nameFilters: ["PNG Images (*.png)"]
        fileMode: Platform.FileDialog.OpenFiles
        property string targetCategory: ""
        onAccepted: {
            if (!(root.eventData && root.eventData.id > 0)) {
                console.warn("No active event selected for category layout upload")
                return
            }
            root.pendingCategoryScroll = categoryUploadDialog.targetCategory
            eventManager.uploadLayoutsBatch(root.eventData.id,
                                            root._toPathList(currentFiles),
                                            categoryUploadDialog.targetCategory)
        }
    }

    Platform.FileDialog {
        id: landingBackgroundDialog
        title: "Chọn hình nền trang đầu / Landing (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            if (eventManager.setGlobalLandingBackground(path)) {
                refreshBackgrounds()
                autoSavedToast.show("Đã cập nhật hình nền trang đầu")
            } else {
                autoSavedToast.showError("Không thể lưu hình nền trang đầu")
            }
        }
    }

    Platform.FileDialog {
        id: globalBackgroundDialog
        title: "Chọn hình nền chung cho toàn bộ phần mềm"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)

            var imageSaved = eventManager.setAppSetting("global_background_image", path)
            var enabledSaved = imageSaved &&
                    eventManager.setAppSetting("global_background_enabled", "true")
            if (enabledSaved) {
                refreshBackgrounds()
                autoSavedToast.show("Đã bật hình nền chung cho toàn bộ phần mềm")
            } else {
                autoSavedToast.showError("Không thể lưu hình nền chung")
            }
        }
    }

    Platform.FileDialog {
        id: waitingPageBackgroundDialog
        title: "Chọn hình nền màn hình chờ (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("waiting_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: enterCodeBackgroundDialog
        title: "Chọn hình nền trang nhập mã (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("enter_code_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: captureBackgroundDialog
        title: "Chọn hình nền màn chụp ảnh (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("capture_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: waitingResultsBackgroundDialog
        title: "Chọn hình nền trang chờ kết quả (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("waiting_results_bg_image", path)
            refreshBackgrounds()
        }
    }
    Platform.FileDialog {
        id: dashboardBackgroundDialog
        title: "Select Dashboard Background (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()

            // Clean the file:/// prefix
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)

            console.log("Uploading dashboard background:", path)
            var mainWin = root.Window.window
            if (mainWin && typeof mainWin.setDashboardBackground === "function") {
                mainWin.setDashboardBackground(path)
            } else {
                eventManager.setAppSetting("dashboard_bg_image", path)
            }
        }
    }

    // ── Payment screen background file dialogs ───────────────────────────────

    Platform.FileDialog {
        id: cutModeThumbnailCutDialog
        title: "Chọn thumbnail ảnh cắt (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("cutmode_thumbnail_cut", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: cutModeThumbnailNoCutDialog
        title: "Chọn thumbnail ảnh không cắt (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("cutmode_thumbnail_nocut", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: cutModeBackgroundDialog
        title: "Chọn hình nền trang chọn loại ảnh (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("cutmode_bg_image", path)
            refreshBackgrounds()
        }
    }

    // Hình nền trang Chọn dịch vụ (SelectServiceScreen)
    Platform.FileDialog {
        id: selectServiceBgDialog
        title: "Chọn hình nền trang chọn dịch vụ (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("selectservice_bg_image", path)
            refreshBackgrounds()
        }
    }

    // Thumbnail Selfbooth (trang Chọn dịch vụ; dùng lại key sbcut_thumbnail)
    Platform.FileDialog {
        id: sbcutThumbnailDialog
        title: "Chọn thumbnail Selfbooth (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("sbcut_thumbnail", path)
            refreshBackgrounds()
        }
    }

    // Thumbnail cho từng nhóm (category) khung hình
    Platform.FileDialog {
        id: categoryThumbnailDialog
        title: "Chon frame mac dinh cho nhom (PNG)"
        nameFilters: ["PNG Images (*.png)"]
        fileMode: Platform.FileDialog.OpenFile
        property string targetCategory: ""
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            if (targetCategory.length > 0 && root.eventData && root.eventData.id > 0) {
                root._pendingCategoryThumbnailTarget = targetCategory
                root.pendingCategoryScroll = targetCategory
                eventManager.uploadLayoutToCategory(root.eventData.id, path, targetCategory)
            }
        }
    }

    // Ảnh hiển thị riêng cho nhóm tại CutModeScreen (độc lập thumbnail dùng cho slot/mode3)
    Platform.FileDialog {
        id: categoryDisplayImageDialog
        title: "Chọn ảnh hiển thị cho nhóm (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        property string targetCategory: ""
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            if (targetCategory.length > 0) {
                eventManager.setAppSetting("cate_image_" + targetCategory, path)
                root._catRefreshCount++
            }
        }
    }

    Platform.FileDialog {
        id: frameDisplayImageDialog
        title: "Chon anh hien thi cho frame (PNG/JPG)"
        nameFilters: ["Image Files (*.png *.jpg *.jpeg)"]
        fileMode: Platform.FileDialog.OpenFile
        property string targetFramePath: ""
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            if (targetFramePath.length > 0) {
                eventManager.setAppSetting(root.frameImageKey(targetFramePath), path)
                root._framesRefreshCount++
            }
        }
    }

    Platform.FileDialog {
        id: layoutSelectionBackgroundDialog
        title: "Chọn hình nền trang chọn khung hình (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("layout_selection_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: layoutCategoryBackgroundDialog
        title: "Chọn hình nền trang chọn nhóm khung hình (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("layout_category_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: printQuantityBackgroundDialog
        title: "Chọn hình nền trang chọn số lượng ảnh (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("print_quantity_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: waitingBackgroundDialog
        title: "Chọn hình nền trang chờ kết quả (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("waiting_results_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: paymentMethodBackgroundDialog
        title: "Chọn hình nền trang chọn phương thức thanh toán (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("payment_method_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: cashPaymentBackgroundDialog
        title: "Chọn hình nền trang thanh toán tiền mặt (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("cash_payment_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: paymentBackgroundDialog
        title: "Chọn hình nền trang thanh toán QR (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("payment_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: photoCompositionBackgroundDialog
        title: "Chọn hình nền trang ghép ảnh (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("photo_composition_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: resultBackgroundDialog
        title: "Chọn hình nền trang kết quả (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("result_bg_image", path)
            refreshBackgrounds()
        }
    }

    Platform.FileDialog {
        id: filterScreenBackgroundDialog
        title: "Chọn hình nền trang chọn bộ lọc (PNG/JPG/MP4)"
        nameFilters: root._backgroundMediaFilters
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = currentFile ? currentFile.toString() : file.toString()
            if (Qt.platform.os === "windows") {
                path = path.replace(/^(file:\/{3})|(file:)/, "")
            } else {
                path = path.replace(/^(file:\/\/)/, "")
            }
            path = decodeURIComponent(path)
            eventManager.setAppSetting("filter_screen_bg_image", path)
            refreshBackgrounds()
        }
    }

    // ── Filter file dialogs (Platform — works without QApplication) ──────────

    // Holds which filter id is being acted on by thumbnail/replace dialogs
    property string _filterDialogTargetId: ""

    function cleanFilePath(raw) {
        var p = raw.toString()
        if (Qt.platform.os === "windows")
            p = p.replace(/^(file:\/{3})|(file:)/, "")
        else
            p = p.replace(/^(file:\/\/)/, "")
        return decodeURIComponent(p)
    }

    Platform.FileDialog {
        id: cubeUploadDialog
        title: "Chọn file bộ lọc màu (.cube)"
        nameFilters: ["Cube LUT Files (*.cube *.CUBE)"]
        fileMode: Platform.FileDialog.OpenFiles
        onAccepted: {
            var paths = []
            for (var i = 0; i < currentFiles.length; i++)
                paths.push(root.cleanFilePath(currentFiles[i].toString()))
            if (paths.length > 0)
                filterManager.importFilters(paths)
        }
    }

    Platform.FileDialog {
        id: stickerUploadDialog
        title: "Chọn file sticker (PNG trong suốt)"
        nameFilters: ["PNG Images (*.png)"]
        fileMode: Platform.FileDialog.OpenFiles
        onAccepted: {
            var paths = []
            for (var i = 0; i < currentFiles.length; i++)
                paths.push(root.cleanFilePath(currentFiles[i].toString()))
            if (paths.length > 0)
                stickerManager.importStickers(paths)
        }
    }

    Platform.FileDialog {
        id: filterThumbnailDialog
        title: "Chọn ảnh thumbnail"
        nameFilters: ["Image Files (*.jpg *.jpeg *.png *.bmp *.webp)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = root.cleanFilePath(currentFile.toString())
            filterManager.setFilterThumbnail(root._filterDialogTargetId, path)
        }
    }

    Platform.FileDialog {
        id: filterReplaceDialog
        title: "Thay thế file .cube"
        nameFilters: ["Cube LUT Files (*.cube *.CUBE)"]
        fileMode: Platform.FileDialog.OpenFile
        onAccepted: {
            var path = root.cleanFilePath(currentFile.toString())
            filterManager.replaceFilterFile(root._filterDialogTargetId, path)
        }
    }

    Platform.FileDialog {
        id: voucherSaveDialog
        title: "Lưu file voucher TXT"
        nameFilters: ["Text files (*.txt)"]
        fileMode: Platform.FileDialog.SaveFile
        defaultSuffix: "txt"
        onAccepted: {
            var path = file ? file.toString() : (currentFile ? currentFile.toString() : "")
            if (path !== "") {
                var ok = eventManager.writeTextFile(path, root._voucherExportContent)
                autoSavedToast.show(ok ? "Đã lưu file voucher" : "Lưu file thất bại")
            }
        }
    }

    function refreshBackgrounds() {
        root._bgRefreshCount++
        if (root.eventData && root.eventData.id > 0) {
            root.eventData = eventManager.getEventDetails(root.eventData.id)
            root.eventDataUpdated(root.eventData.id)
        }
    }

    // ── Ẩn nút điều khiển (⚙ / ✕) trên màn hình khách ────────────────────────
    // off = hiện bình thường · dim = mờ 25% · ghost = tàng hình (vẫn bấm được,
    // nhưng nút ✕ phải giữ 1 giây — xem components/HoldToActivate.qml).
    property string _chromeHideMode: eventManager.getAppSetting("chrome_hide_mode", "off")

    function _setChromeHideMode(mode) {
        root._chromeHideMode = mode
        eventManager.setAppSetting("chrome_hide_mode", mode)
        // Root window nghe appSettingChanged và cập nhật appChromeOpacity ngay,
        // nên mọi màn hình đổi tức thì, không cần khởi động lại.
        autoSavedToast.show(mode === "off"   ? "Đã hiện lại nút điều khiển"
                          : mode === "dim"   ? "Nút điều khiển: mờ 25%"
                                             : "Nút điều khiển: tàng hình (giữ 1 giây để thoát)")
    }

    property bool _layoutsLoading: false
    // Chỉ vá metadata khung thiếu 1 lần cho mỗi sự kiện trong 1 phiên mở Cài đặt.
    property int _layoutRepairDoneForEvent: -1
    // true trong lúc một lô khung (tải/xoá/đổi tên) đang chạy — dùng để khoá nút,
    // tránh người dùng bấm chồng lô mới lên lô chưa xong.
    property bool _frameBusy: false

    // currentFiles của FileDialog là list<url>; đổi sang mảng chuỗi để truyền
    // vào tham số QStringList của C++.
    function _toPathList(files) {
        var out = []
        for (var i = 0; i < files.length; i++)
            out.push(files[i].toString())
        return out
    }

    // Sự kiện đang được hiển thị trong layoutModel (-1 = chưa nạp, -2 = khung giấy).
    property int _loadedLayoutEventId: -1

    function refreshLayouts() {
        if (root._operationMode === "modebao") {
            root._layoutsLoading = false
            if (root._loadedLayoutEventId !== -2) {
                layoutModel.clear()          // đổi nguồn dữ liệu → dọn sạch
                root._loadedLayoutEventId = -2
            }
            root._syncLayoutModel(eventManager.getPaperLayouts())
        } else if (root.eventData && root.eventData.id > 0) {
            root._layoutsLoading = true
            // CHỈ clear khi đổi sang sự kiện khác. Nạp lại cùng một sự kiện thì
            // giữ nguyên model để _syncLayoutModel diff — không huỷ delegate,
            // không decode lại ảnh của những khung không đổi.
            if (root._loadedLayoutEventId !== root.eventData.id) {
                layoutModel.clear()
                root._loadedLayoutEventId = root.eventData.id
            }
            eventManager.requestLayouts(root.eventData.id)
            // Khung cũ bị ghi sai tên file .json sẽ không hiện — phân tích lại ở nền,
            // xong sẽ tự phát layoutUploaded để nạp lại danh sách.
            if (root._layoutRepairDoneForEvent !== root.eventData.id) {
                root._layoutRepairDoneForEvent = root.eventData.id
                eventManager.repairMissingLayoutMetadata(root.eventData.id)
            }
        }
    }

    onEventDataChanged: refreshLayouts()
    onVisibleChanged: if(visible) refreshLayouts()

    // ── Quản lý nhóm (category) khung hình ────────────────────────────────────
    // Lưu danh sách nhóm vào app setting "frame_categories", phân tách bằng "|".
    function getCategoryList() {
        var dummy = root._catRefreshCount  // ép re-eval khi danh sách đổi
        var raw = eventManager.getAppSetting("frame_categories", "")
        var out = []
        var parts = raw.split("|")
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim()
            if (t.length > 0) out.push(t)
        }
        return out
    }

    function saveCategoryList(list) {
        eventManager.setAppSetting("frame_categories", list.join("|"))
        root._catRefreshCount++
    }

    function addCategory() {
        var list = getCategoryList()
        var n = list.length + 1
        var name = "Category " + n
        while (list.indexOf(name) >= 0) { n++; name = "Category " + n }
        list.push(name)
        saveCategoryList(list)
    }

    function renameCategory(oldName, newName) {
        newName = (newName || "").trim()
        if (newName.length === 0 || newName === oldName) return
        var list = getCategoryList()
        if (list.indexOf(newName) >= 0) {
            autoSavedToast.showError("Tên nhóm đã tồn tại")
            return
        }
        var idx = list.indexOf(oldName)
        if (idx < 0) return
        list[idx] = newName
        // Chuyển thumbnail sang key mới
        var thumb = eventManager.getAppSetting("cate_thumb_" + oldName, "")
        if (thumb.length > 0) {
            eventManager.setAppSetting("cate_thumb_" + newName, thumb)
            eventManager.setAppSetting("cate_thumb_" + oldName, "")
        }
        // Chuyển ảnh hiển thị sang key mới
        var dispImg = eventManager.getAppSetting("cate_image_" + oldName, "")
        if (dispImg.length > 0) {
            eventManager.setAppSetting("cate_image_" + newName, dispImg)
            eventManager.setAppSetting("cate_image_" + oldName, "")
        }
        // Chuyển giá nhóm sang key mới
        var catPrice = eventManager.getAppSetting("cate_price_" + oldName, "")
        if (catPrice.length > 0) {
            eventManager.setAppSetting("cate_price_" + newName, catPrice)
            eventManager.setAppSetting("cate_price_" + oldName, "")
        }
        // Đổi tiền tố các frame thuộc nhóm cũ → nhóm mới.
        // Gom thành MỘT lô: trước đây mỗi renameLayout phát layoutUploaded riêng
        // nên nhóm 30 khung phải nạp lại danh sách 31 lần.
        saveCategoryList(list)
        if (root.eventData && root.eventData.id > 0) {
            var jobs = []
            for (var i = 0; i < layoutModel.count; i++) {
                var fn = layoutModel.get(i).fileName
                if (categoryOf(fn) === oldName) {
                    var base = fn.replace(/\.png$/i, "")
                    var sub = base.indexOf("__") > 0 ? base.substring(base.indexOf("__") + 2) : base
                    jobs.push({ "from": layoutModel.get(i).path, "to": newName + "__" + sub })
                }
            }
            if (jobs.length > 0) {
                // frameRenamed sẽ lo migrateFrameImage; layoutUploaded cuối lô lo refresh.
                eventManager.renameLayoutsBatch(root.eventData.id, jobs)
                return
            }
        }
        refreshLayouts()
    }

    function deleteCategory(name) {
        var list = getCategoryList()
        var idx = list.indexOf(name)
        if (idx < 0) return
        list.splice(idx, 1)
        eventManager.setAppSetting("cate_thumb_" + name, "")
        eventManager.setAppSetting("cate_image_" + name, "")
        eventManager.setAppSetting("cate_price_" + name, "")
        saveCategoryList(list)
    }

    // Tách tên nhóm từ tên file "Category__name.png" → "Category" (không có → "Khác")
    function categoryOf(fileName) {
        var base = (fileName || "").replace(/\.png$/i, "")
        var idx = base.indexOf("__")
        return idx > 0 ? base.substring(0, idx) : "Khác"
    }

    // Trả về danh sách frame {fileName, path, metadata} thuộc một nhóm (dùng cho lưới con).
    function normalizedFramePath(path) {
        var p = (path || "").toString().replace(/\?t=\d+$/, "")
        if (Qt.platform.os === "windows")
            p = p.replace(/^(file:\/{3})|(file:)/, "")
        else
            p = p.replace(/^(file:\/\/)/, "")
        p = decodeURIComponent(p).replace(/\\/g, "/")
        return p.toLowerCase()
    }

    function frameImageKey(path) {
        return "frame_image_" + encodeURIComponent(normalizedFramePath(path))
    }

    function frameImagePath(path) {
        var d = root._framesRefreshCount
        return path ? eventManager.getAppSetting(frameImageKey(path), "") : ""
    }

    function frameDisplayPath(path) {
        var img = frameImagePath(path)
        return img !== "" ? img : path
    }

    function frameImageSourceUrl(path) {
        if (!path || path === "") return ""
        var p = path.toString()
        if (p.indexOf("qrc:/") === 0 || p.indexOf("file:/") === 0
                || p.indexOf("http://") === 0 || p.indexOf("https://") === 0)
            return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    function frameSiblingPath(path, newName) {
        var p = (path || "").toString().replace(/\?t=\d+$/, "")
        var prefix = ""
        if (p.indexOf("file:///") === 0) {
            prefix = "file:///"
            p = p.substring(8)
        } else if (p.indexOf("file:") === 0) {
            p = p.replace(/^file:/, "")
        }
        p = decodeURIComponent(p).replace(/\\/g, "/")
        var slash = p.lastIndexOf("/")
        var dir = slash >= 0 ? p.substring(0, slash + 1) : ""
        var base = newName
        if (!base.match(/\.png$/i)) base += ".png"
        return prefix + dir + base
    }

    function clearFrameImage(path) {
        if (!path) return
        // Không ghi khi vốn đã rỗng — xoá lô khung không có ảnh riêng (và khung
        // giấy) sẽ tạo hàng loạt bản ghi cài đặt rỗng vô nghĩa.
        if (frameImagePath(path) === "") return
        eventManager.setAppSetting(frameImageKey(path), "")
        root._framesRefreshCount++
    }

    function migrateFrameImage(oldPath, newPath) {
        var img = frameImagePath(oldPath)
        if (img === "") return
        eventManager.setAppSetting(frameImageKey(newPath), img)
        eventManager.setAppSetting(frameImageKey(oldPath), "")
        root._framesRefreshCount++
    }

    // Chỉ mục nhóm → danh sách khung, dựng MỘT lần mỗi khi model đổi.
    // Trước đây mỗi nhóm tự quét lại toàn bộ layoutModel ở binding catFrames
    // (O(nhóm × khung) cho mỗi lần _framesRefreshCount đổi).
    property var _framesByCategory: ({})

    function _rebuildCategoryIndex() {
        var m = {}
        for (var i = 0; i < layoutModel.count; i++) {
            var it = layoutModel.get(i)
            var c = categoryOf(it.fileName)
            if (m[c] === undefined) m[c] = []
            m[c].push({ "fileName": it.fileName, "path": it.path, "metadata": it.metadata })
        }
        root._framesByCategory = m
        root._framesRefreshCount++
    }

    function framesInCategory(category) {
        var d = root._framesRefreshCount   // ép re-eval khi danh sách đổi
        var out = root._framesByCategory[category]
        return out !== undefined ? out : []
    }

    // Gán frame vào một nhóm: rename file thành "Category__name.png"
    function assignFrameCategory(path, fileName, category) {
        if (!root.eventData || root.eventData.id <= 0) return
        var base = fileName.replace(/\.png$/i, "")
        var sub = base.indexOf("__") > 0 ? base.substring(base.indexOf("__") + 2) : base
        var newName = (category === "Khác") ? sub : (category + "__" + sub)
        // Dùng đường lô (dù chỉ 1 khung) để đi chung luồng frameRenamed + refresh cuối lô.
        eventManager.renameLayoutsBatch(root.eventData.id, [{ "from": path, "to": newName }])
    }

    // Hàng đợi gán nhóm sau khi upload xong (vì uploadLayout xử lý bất đồng bộ).
    // Khóa = base name gốc (lowercase, không .png) -> category cần gán.
    property var _pendingCategoryUploads: ({})
    property string _pendingCategoryThumbnailTarget: ""
    // Chặn _processPendingCategoryAssign tự gọi lại chính nó qua chuỗi
    // renameLayoutsBatch → layoutUploaded → refreshLayouts → onLayoutsReady.
    property bool _categoryAssignRunning: false

    // Tìm tên file đích chưa trùng trong thư mục Layouts (auto thêm _1, _2...).
    // Trả về tên KHÔNG có ".png" (renameLayout tự thêm đuôi).
    function _uniqueCategoryName(category, sub) {
        var existing = {}
        for (var i = 0; i < layoutModel.count; i++)
            existing[layoutModel.get(i).fileName.toLowerCase()] = true
        var prefix = (category === "Khác") ? "" : (category + "__")
        var candidate = prefix + sub + ".png"
        var n = 1
        while (existing[candidate.toLowerCase()]) {
            candidate = prefix + sub + "_" + n + ".png"
            n++
        }
        return candidate.replace(/\.png$/i, "")
    }

    Connections {
        target: eventManager
        function onLayoutUploaded(id) {
            if (root._operationMode === "modebao" && id === -1) refreshLayouts()
            else if (root.eventData && id === root.eventData.id) refreshLayouts()
        }
        function onLayoutFailed(eventId, fileName, reason) {
            root._layoutsLoading = false
            autoSavedToast.show("Không xử lý được khung \"" + fileName + "\" — " + reason)
        }
        function onLayoutReady(eventId, layout) {
            if (!root.eventData || root.eventData.id !== eventId || !layout || !layout.path) return

            var replaced = false
            for (var i = 0; i < layoutModel.count; i++) {
                if (layoutModel.get(i).path === layout.path) {
                    layoutModel.set(i, layout)
                    replaced = true
                    break
                }
            }
            if (!replaced)
                layoutModel.append(layout)

            root._layoutsLoading = false
            root._rebuildCategoryIndex()
            if (root._pendingCategoryThumbnailTarget !== ""
                    && root.categoryOf(layout.fileName) === root._pendingCategoryThumbnailTarget) {
                var thumbCategory = root._pendingCategoryThumbnailTarget
                root._pendingCategoryThumbnailTarget = ""
                eventManager.setAppSetting("cate_thumb_" + thumbCategory, layout.path)
                root._catRefreshCount++
                autoSavedToast.show("Da dat frame mac dinh cho nhom \"" + thumbCategory + "\"")
            }
            if (root.pendingCategoryScroll !== "")
                root.categoryScrollRequest++
        }
        function onLayoutsReady(eventId, layouts) {
            if (!root.eventData || root.eventData.id !== eventId) return
            root._layoutsLoading = false
            root._syncLayoutModel(layouts)
            var didRenameCategoryUploads = root._processPendingCategoryAssign()
            if (root.pendingCategoryScroll !== "" && !didRenameCategoryUploads)
                root.categoryScrollRequest++
        }
    }

    // Cập nhật layoutModel bằng DIFF thay vì clear() + append lại toàn bộ.
    //
    // clear() huỷ mọi delegate của GridView, khiến tất cả Image phải decode lại —
    // kể cả những khung không hề thay đổi. Đó chính là hiện tượng "load lại" sau
    // mỗi lần thêm/sửa/xoá. Với diff, chỉ phần tử thực sự khác mới bị chạm tới.
    function _syncLayoutModel(layouts) {
        var incoming = {}
        for (var j = 0; j < layouts.length; j++) incoming[layouts[j].path] = true

        // 1) gỡ khung không còn tồn tại (duyệt ngược để chỉ số không lệch)
        for (var k = layoutModel.count - 1; k >= 0; k--)
            if (incoming[layoutModel.get(k).path] !== true) layoutModel.remove(k)

        // 2) đưa về đúng thứ tự nguồn; path trùng thì set() tại chỗ nên
        //    Image.source giữ nguyên giá trị → không có lượt decode mới.
        for (var m = 0; m < layouts.length; m++) {
            var it = layouts[m]
            if (m < layoutModel.count && layoutModel.get(m).path === it.path) {
                layoutModel.set(m, it)
                continue
            }
            var found = -1
            for (var n = m; n < layoutModel.count; n++) {
                if (layoutModel.get(n).path === it.path) { found = n; break }
            }
            if (found >= 0) { layoutModel.move(found, m, 1); layoutModel.set(m, it) }
            else            layoutModel.insert(m, it)
        }

        root._rebuildCategoryIndex()
    }

    // Gán nhóm cho các frame vừa upload qua nút "+ Frame" của nhóm.
    // Chạy sau khi layoutModel đã cập nhật: tìm frame chưa có tiền tố (category "Khác")
    // có base name khớp hàng đợi rồi rename sang "Nhóm__<tên>.png" (auto hậu tố số nếu trùng).
    function _processPendingCategoryAssign() {
        var pend = root._pendingCategoryUploads
        if (!pend || Object.keys(pend).length === 0) return false
        // Lô rename dưới đây lại phát layoutUploaded → refreshLayouts → onLayoutsReady
        // → gọi lại chính hàm này. Cờ chặn tái nhập cắt vòng phản hồi đó.
        if (root._categoryAssignRunning) return false

        var jobs = []
        var remaining = Object.assign({}, pend)

        for (var i = 0; i < layoutModel.count; i++) {
            var item = layoutModel.get(i)
            if (categoryOf(item.fileName) !== "Khác") continue
            var base = item.fileName.replace(/\.png$/i, "").toLowerCase()
            if (remaining[base] === undefined) continue

            var category = remaining[base]
            if (category && category !== "Khác") {
                var sub = item.fileName.replace(/\.png$/i, "")
                jobs.push({ "from": item.path, "to": _uniqueCategoryName(category, sub) })
            }
            delete remaining[base]
        }

        root._pendingCategoryUploads = remaining
        if (jobs.length === 0) return false

        // Một lô cho toàn bộ khung vừa tải, thay vì N lần rename + N lần nạp lại.
        root._categoryAssignRunning = true
        eventManager.renameLayoutsBatch(root.eventData.id, jobs)
        return true
    }

    ListModel {
        id: sidebarModel
        // Không đổi thứ tự index 0–12: initialTab và staff_locked_tabs đang dùng index số.
        // Các mục mới phải nối ở cuối danh sách để giữ tương thích dữ liệu cũ.
        ListElement { tabId: "general";  group: "operation"; iconName: "settings"; name: "Cài đặt chung";  desc: "Nội dung, màn hình, lưu trữ và media"; keywords: "chung hệ thống màn hình thư mục video"; accent: "#C96F4A" }
        ListElement { tabId: "camera";   group: "operation"; iconName: "camera";   name: "Máy ảnh";          desc: "Kết nối, Live View và nguồn hình ảnh"; keywords: "camera live view fps iso"; accent: "#B85F40" }
        ListElement { tabId: "capture";  group: "operation"; iconName: "capture";  name: "Cài đặt chụp";     desc: "Đếm giờ, số kiểu và chế độ chụp"; keywords: "chụp đếm giờ lật ảnh"; accent: "#B85F40" }
        ListElement { tabId: "printer";  group: "operation"; iconName: "printer";  name: "Máy in";           desc: "Máy in, khổ giấy, kiểu in và tự cắt"; keywords: "printer giấy dpi cắt"; accent: "#2E8B65" }
        ListElement { tabId: "sharing";  group: "experience"; iconName: "share";    name: "Chia sẻ";          desc: "QR, email, đám mây và mạng xã hội"; keywords: "qr email cloud upload"; accent: "#2E8B65" }
        ListElement { tabId: "frames";   group: "experience"; iconName: "frames";   name: "Khung frame";      desc: "Quản lý layout và khung ảnh sự kiện"; keywords: "frame layout mẫu"; accent: "#8B5F8E" }
        ListElement { tabId: "account";  group: "admin"; iconName: "account";  name: "Tài khoản";         desc: "Nhân viên, phân quyền và bảo mật"; keywords: "nhân viên mật khẩu pin khóa"; accent: "#8B5F8E" }
        ListElement { tabId: "background"; group: "experience"; iconName: "image"; name: "Hình nền";        desc: "Màn hình chào và màn chọn chế độ"; keywords: "background ảnh nền"; accent: "#C58A33" }
        ListElement { tabId: "filters";  group: "experience"; iconName: "palette";  name: "Bộ lọc màu";      desc: "Filter, sticker và chỉnh sửa ảnh"; keywords: "filter sticker màu"; accent: "#C58A33" }
        ListElement { tabId: "voucher";  group: "admin"; iconName: "ticket";   name: "Voucher";           desc: "Mã giảm giá, ca làm và khuyến mãi"; keywords: "mã giảm giá hết hạn"; accent: "#C58A33" }
        ListElement { tabId: "revenue";  group: "admin"; iconName: "revenue";  name: "Doanh thu";         desc: "Báo cáo và lịch sử giao dịch"; keywords: "tiền báo cáo giao dịch"; accent: "#B8782F" }
        ListElement { tabId: "info";     group: "admin"; iconName: "info";     name: "Thông tin";         desc: "Mã máy, bản quyền và phiên bản"; keywords: "hwid license phiên bản"; accent: "#766A62" }
        ListElement { tabId: "mode";     group: "operation"; iconName: "mode";     name: "Chế độ";            desc: "Miễn phí, thanh toán và vận hành"; keywords: "mode chế độ payment"; accent: "#766A62" }
        ListElement { tabId: "payment";  group: "admin"; iconName: "revenue"; name: "Thanh toán";          desc: "Ngân hàng, giá in, voucher và đầu đọc tiền"; keywords: "thanh toán ngân hàng sepay giá tiền voucher tiền mặt com"; accent: "#2E8B65" }
        ListElement { tabId: "gallery";  group: "experience"; iconName: "image"; name: "Thư viện ảnh";       desc: "Xem lại và in ảnh đã chụp của sự kiện"; keywords: "gallery thư viện ảnh xem in lại photo"; accent: "#8B5F8E" }
        // Index 15 — thêm CUỐI cùng để không xê dịch index các tab đã hard-code (info=11, payment=13, gallery=14).
        ListElement { tabId: "captures"; group: "admin"; iconName: "revenue"; name: "Lượt chụp";        desc: "Báo cáo trạng thái từng lượt chụp và xử lý sự cố"; keywords: "lượt chụp capture lỗi hoàn tiền xử lý attempt sự cố"; accent: "#C0564B" }
        // Index 16 — Tính năng AI (chưa phát hành → bấm vào hiện popup "coming soon").
        ListElement { tabId: "ai"; group: "experience"; iconName: "palette"; name: "Tính năng AI"; desc: "Mịn da làm đẹp, vline, thay thế background, ghép ảnh"; keywords: "ai mịn da làm đẹp vline background nền ghép ảnh beautify"; accent: "#8B5F8E" }
    }

    Component {
        id: warmCategoryDelegate
        SettingsCategoryCard {
            required property int modelData
            property int tabIndex: modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.preferredHeight: 104
            visible: root._settingsMatches(tabIndex)
            title: sidebarModel.get(tabIndex).name
            description: sidebarModel.get(tabIndex).desc
            iconName: sidebarModel.get(tabIndex).iconName
            accent: sidebarModel.get(tabIndex).accent
            locked: root._isTabLocked(tabIndex)
            onClicked: {
                // Tính năng AI chưa phát hành → hiện popup "coming soon" thay vì mở tab.
                if (sidebarModel.get(tabIndex).tabId === "ai")
                    comingSoonPopup.open()
                else
                    root._requestTab(tabIndex)
            }
        }
    }

    // ── Popup "Tính năng AI — đang cập nhật / coming soon" ────────────────────
    Popup {
        id: comingSoonPopup
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        modal: true
        Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
        width: 440
        padding: 28
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.settingsCard
            radius: Theme.settingsRadiusLarge
            border.color: Theme.settingsBorder
            border.width: 1
        }

        contentItem: ColumnLayout {
            spacing: 14

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 76; height: 76; radius: 38
                color: Theme.settingsCopperSoft
                Text { anchors.centerIn: parent; text: "✨"; font.pixelSize: 38 }
            }

            Text {
                text: "Tính năng AI đang cập nhật"
                color: Theme.settingsText; font.pixelSize: 19; font.bold: true
                horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true
            }

            Text {
                text: "Mịn da làm đẹp, vline, thay thế background, ghép ảnh — dự kiến sẽ được phát hành trong thời gian sắp tới."
                color: Theme.settingsTextMuted; font.pixelSize: 14
                wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }

            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: csTxt.implicitWidth + 28
                Layout.preferredHeight: 30
                radius: 15
                color: Qt.rgba(Theme.settingsCopper.r, Theme.settingsCopper.g, Theme.settingsCopper.b, 0.12)
                Text { id: csTxt; anchors.centerIn: parent; text: "Coming soon"; color: Theme.settingsCopper; font.pixelSize: 13; font.bold: true }
            }

            Button {
                Layout.fillWidth: true
                Layout.topMargin: 6
                implicitHeight: 44
                text: "Đã hiểu"
                background: Rectangle { radius: Theme.settingsRadiusSmall; color: parent.hovered ? Theme.settingsCopperDark : Theme.settingsCopper }
                contentItem: Text { text: parent.text; color: "#FFFFFF"; font.pixelSize: 15; font.weight: Font.Bold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                onClicked: comingSoonPopup.close()
            }
        }
    }

    // ── Xác nhận đăng xuất tài khoản studio ─────────────────────────────────
    Dialog {
        id: googleLogoutDialog
        parent: Overlay.overlay
        anchors.centerIn: Overlay.overlay
        modal: true
        width: 460
        height: 210
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        header: Item { height: 0 }
        footer: Item { height: 0 }
        background: Rectangle { color: "#FFFFFF"; radius: 14; border.color: "#E2E6EC"; border.width: 1 }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Text {
                text: "Đăng xuất tài khoản?"
                color: "#1F2430"
                font.pixelSize: 22
                font.weight: Font.Bold
            }
            Text {
                Layout.fillWidth: true
                text: (studioAccount.loggedIn && studioAccount.email && studioAccount.email.length > 0)
                      ? ("Tài khoản: " + studioAccount.email)
                      : "Bạn sẽ cần đăng nhập lại để dùng các tính năng tài khoản."
                color: "#6B7280"
                font.pixelSize: 15
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignRight
                spacing: 10

                Rectangle {
                    Layout.preferredWidth: 110; Layout.preferredHeight: 44
                    radius: 10
                    color: cancelLogoutMouse.containsMouse ? "#EEF1F5" : "transparent"
                    border.color: "#DCE1E8"; border.width: 1
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Text { anchors.centerIn: parent; text: "Huỷ"; color: "#333333"; font.pixelSize: 15; font.weight: Font.Medium }
                    MouseArea {
                        id: cancelLogoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: googleLogoutDialog.close()
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 150; Layout.preferredHeight: 44
                    radius: 10
                    color: confirmLogoutMouse.pressed ? "#C0392B"
                         : confirmLogoutMouse.containsMouse ? "#F66" : "#EF4444"
                    Behavior on color { ColorAnimation { duration: 130 } }
                    Text { anchors.centerIn: parent; text: "Đăng xuất"; color: "#ffffff"; font.pixelSize: 15; font.weight: Font.Bold }
                    MouseArea {
                        id: confirmLogoutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            studioAccount.logout()
                            googleLogoutDialog.close()
                            autoSavedToast.show("Đã đăng xuất tài khoản")
                        }
                    }
                }
            }
        }
    }

    // ============================================
    // TAB COMPONENTS (Lazy-loaded)
    // ============================================

    // ── Chế Độ: chọn 1 trong 3 chế độ vận hành ──────────────────────────
    Component {
        id: operationModeTabComponent
        Item {
            ScrollView {
                anchors.fill: parent
                contentWidth: parent.width
                clip: true

                ColumnLayout {
                    width: parent.width - 80
                    spacing: 32

                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Cho phép thanh toán"
                        description: "Bật luồng thanh toán cho các chế độ Studio có thu phí."
                        checked: root._paymentEnabledSetting
                        accent: Theme.settingsCopper
                        onToggled: function(next) {
                            root._paymentEnabledSetting = next
                            eventManager.setAppSetting("payment_enabled", next ? "true" : "false")
                            autoSavedToast.show(next ? "Đã bật thanh toán" : "Đã tắt thanh toán")
                        }
                    }

                    // Gắn mã QR album lên ảnh in — thuộc hành vi chế độ/in, đặt ở đây
                    // (đã chuyển từ tab Chia sẻ sang để đúng ngữ cảnh).
                    SettingsToggleRow {
                        Layout.fillWidth: true
                        title: "Gắn mã QR lên ảnh"
                        description: "Tự động gắn mã QR album lên ảnh trước khi in."
                        visible: false
                        checked: eventManager.getAppSetting("qr_code_enabled", "false") === "true"
                        accent: Theme.settingsCopper
                        onToggled: function(next) {
                            eventManager.setAppSetting("qr_code_enabled", next ? "true" : "false")
                            autoSavedToast.show(next ? "Đã bật mã QR trên ảnh" : "Đã tắt mã QR trên ảnh")
                        }
                    }

                    // ── Operation Mode Settings section ──────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        Text { text: "Chế Độ Vận Hành"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Text {
                            text: "Chọn một trong ba chế độ vận hành cho ứng dụng."
                            color: root.mutedText(0.65); font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                id: operationMode1Card
                                Layout.fillWidth: true
                                height: 110
                                radius: 8
                                border.width: 1

                                property bool selected: root._operationMode === "mode1"
                                property bool allowed: machineAuth.hasCapability("event")

                                color: "transparent"
                                opacity: allowed ? 1.0 : 0.45
                                border.color: selected ? "#1e7eea" : "#2d5a8c"
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    Rectangle {
                                        implicitWidth: 48; implicitHeight: 26; radius: 13
                                        color: (operationMode1Card.selected && operationMode1Card.allowed) ? "#1e7eea" : "#2d5a8c"
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Rectangle {
                                            x: (operationMode1Card.selected && operationMode1Card.allowed) ? parent.width - width - 2 : 2
                                            width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 200 } }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text { text: "Chế độ 1 - Tắt thanh toán" + (operationMode1Card.allowed ? "" : "  🔒"); color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                        Text {
                                            text: "Khi bật, app chạy không yêu cầu thanh toán. Nút Bật Thanh Toán sẽ tắt và ẩn khỏi cài đặt chung."
                                            color: root.mutedText(0.65); font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: operationMode1Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: operationMode1Card.allowed ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (root._setOperationMode("mode1"))
                                            autoSavedToast.show("Đã bật: Chế độ 1 - Tắt thanh toán")
                                    }
                                }
                            }

                            Rectangle {
                                id: operationMode2Card
                                Layout.fillWidth: true
                                height: 110
                                radius: 8
                                border.width: 1

                                property bool selected: root._operationMode === "mode2"
                                property bool allowed: machineAuth.hasCapability("studio")

                                color: "transparent"
                                opacity: allowed ? 1.0 : 0.45
                                border.color: selected ? "#1e7eea" : "#2d5a8c"
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    Rectangle {
                                        implicitWidth: 48; implicitHeight: 26; radius: 13
                                        color: (operationMode2Card.selected && operationMode2Card.allowed) ? "#1e7eea" : "#2d5a8c"
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Rectangle {
                                            x: (operationMode2Card.selected && operationMode2Card.allowed) ? parent.width - width - 2 : 2
                                            width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 200 } }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text { text: "Chế độ 2 - Bật thanh toán" + (operationMode2Card.allowed ? "" : "  🔒"); color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                        Text {
                                            text: "Khi bật, app yêu cầu thanh toán và nút Bật Thanh Toán sẽ hiển thị lại trong cài đặt."
                                            color: root.mutedText(0.65); font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: operationMode2Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: operationMode2Card.allowed ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!machineAuth.hasCapability("studio")) {
                                            autoSavedToast.show("Gói dịch vụ chưa được mua hoặc chưa được cập nhật. Vui lòng vào Cài đặt > Thông tin để nâng cấp.")
                                            return
                                        }
                                        modeRestartConfirmDialog.openFor("mode2", "Chế độ 2 - Bật thanh toán")
                                    }
                                }
                            }

                            Rectangle {
                                id: operationMode3Card
                                Layout.fillWidth: true
                                height: 110
                                radius: 8
                                border.width: 1

                                property bool selected: root._operationMode === "mode3"
                                property bool allowed: machineAuth.hasCapability("studio")

                                color: "transparent"
                                opacity: allowed ? 1.0 : 0.45
                                border.color: selected ? "#1e7eea" : "#2d5a8c"
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    Rectangle {
                                        implicitWidth: 48; implicitHeight: 26; radius: 13
                                        color: (operationMode3Card.selected && operationMode3Card.allowed) ? "#1e7eea" : "#2d5a8c"
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Rectangle {
                                            x: (operationMode3Card.selected && operationMode3Card.allowed) ? parent.width - width - 2 : 2
                                            width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 200 } }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text { text: "Chế độ 3 - Thanh toán + nhóm frame" + (operationMode3Card.allowed ? "" : "  🔒"); color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                        Text {
                                            text: "Bật thanh toán, ẩn CutModeScreen và cho khách chọn nhóm frame trực tiếp trong LayoutSelection."
                                            color: root.mutedText(0.65); font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: operationMode3Mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: operationMode3Card.allowed ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    onClicked: {
                                        if (!machineAuth.hasCapability("studio")) {
                                            autoSavedToast.show("Gói dịch vụ chưa được mua hoặc chưa được cập nhật. Vui lòng vào Cài đặt > Thông tin để nâng cấp.")
                                            return
                                        }
                                        modeRestartConfirmDialog.openFor("mode3", "Chế độ 3 - Thanh toán + nhóm frame")
                                    }
                                }
                            }

                            Rectangle {
                                id: operationModeBaoCard
                                Layout.fillWidth: true
                                visible: false
                                height: visible ? 110 : 0
                                radius: 8
                                border.width: 1

                                property bool selected: root._operationMode === "modebao"

                                color: operationModeBaoMouse.containsMouse
                                       ? (selected ? "#26000000" : Theme.field)
                                       : Theme.surface
                                border.color: selected ? "#1e7eea" : "#2d5a8c"
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 16

                                    Rectangle {
                                        implicitWidth: 48; implicitHeight: 26; radius: 13
                                        color: operationModeBaoCard.selected ? "#1e7eea" : "#2d5a8c"
                                        Behavior on color { ColorAnimation { duration: 200 } }
                                        Rectangle {
                                            x: operationModeBaoCard.selected ? parent.width - width - 2 : 2
                                            width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                            anchors.verticalCenter: parent.verticalCenter
                                            Behavior on x { NumberAnimation { duration: 200 } }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text { text: "Chế độ Báo - Photobooth Báo"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                        Text {
                                            text: "Bật chế độ Photobooth Báo (đang cập nhật). Ứng dụng sẽ khởi động lại."
                                            color: root.mutedText(0.65); font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: operationModeBaoMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: paperModeConfirmDialog.open()
                                }
                            }
                        }

                        Dialog {
                            id: paperModeConfirmDialog
                            modal: true
                            Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                            anchors.centerIn: Overlay.overlay
                            width: 460
                            padding: 20
                            title: "Chuyển sang Photobooth Báo?"
                            standardButtons: Dialog.Ok | Dialog.Cancel
                            contentItem: Text {
                                text: "Chuyển sang chế độ Photobooth Báo? Ứng dụng sẽ khởi động lại."
                                color: root.themeTextColor; font.pixelSize: 15
                                wrapMode: Text.WordWrap
                            }
                            onAccepted: {
                                eventManager.setAppSetting("app_operation_mode", "modebao")
                                eventManager.setAppSetting("payment_enabled", "false")
                                eventManager.restartApp()
                            }
                        }

                        // Bật mode2/mode3 → cần khởi động lại để áp dụng luồng thanh toán.
                        Dialog {
                            id: modeRestartConfirmDialog
                            property string pendingMode: ""
                            property string pendingLabel: ""
                            function openFor(mode, label) {
                                modeRestartConfirmDialog.pendingMode = mode
                                modeRestartConfirmDialog.pendingLabel = label
                                modeRestartConfirmDialog.open()
                            }
                            modal: true
                            Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                            anchors.centerIn: Overlay.overlay
                            width: 460
                            padding: 20
                            title: "Cần khởi động lại"
                            standardButtons: Dialog.Ok | Dialog.Cancel
                            contentItem: Text {
                                text: "Bật " + modeRestartConfirmDialog.pendingLabel +
                                      "?\nỨng dụng sẽ khởi động lại để áp dụng chế độ thanh toán."
                                color: root.themeTextColor; font.pixelSize: 15
                                wrapMode: Text.WordWrap
                            }
                            onAccepted: {
                                if (root._setOperationMode(modeRestartConfirmDialog.pendingMode))
                                    eventManager.restartApp()
                            }
                        }
                    }

                    // ── Chọn nhiều sự kiện ─────────────────────────────────────
                    // Chế độ 2/3 luôn dùng một sự kiện studio riêng → ẩn & disable nút này.
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: root._operationMode !== "mode2" && root._operationMode !== "mode3"
                        enabled: visible

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                        Text {
                            text: "Chọn nhiều sự kiện"
                            color: root.themeTextColor
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }

                        Text {
                            text: root._operationMode === "mode1"
                                  ? "Chế độ 1 luôn mở dashboard để chọn và quản lý nhiều sự kiện."
                                  : "Bật để mở dashboard và quản lý nhiều sự kiện. Tắt để dùng một sự kiện studio và vào thẳng booth."
                            color: root.mutedText(0.65)
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            color: "transparent"
                            radius: 8
                            border.color: multiEventSwitch.checked ? "#1e7eea" : "#2d5a8c"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        text: "Cho phép chọn và tạo nhiều sự kiện"
                                        color: root.themeTextColor
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: root._operationMode === "mode1"
                                              ? "Luôn bật ở chế độ 1"
                                              : (multiEventSwitch.checked ? "Đang bật" : "Đang tắt")
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 13
                                    }
                                }

                                Switch {
                                    id: multiEventSwitch
                                    enabled: root._operationMode !== "mode1"
                                    checked: root._operationMode === "mode1"
                                             || eventManager.getAppSetting("multi_event_enabled", "true") === "true"
                                    onToggled: {
                                        if (root._operationMode === "mode1") {
                                            checked = true
                                            eventManager.setAppSetting("multi_event_enabled", "true")
                                            return
                                        }
                                        var value = checked ? "true" : "false"
                                        if (eventManager.setAppSetting("multi_event_enabled", value)) {
                                            autoSavedToast.show(checked
                                                ? "Đã bật: Chọn nhiều sự kiện"
                                                : "Đã tắt: Chế độ một sự kiện studio")
                                        } else {
                                            checked = !checked
                                            autoSavedToast.showError("Không thể lưu cài đặt chọn nhiều sự kiện")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Selfbooth (tự chụp) — chỉ ở mode2/mode3 ──────────────────────
                    ColumnLayout {
                        id: sbcutSection
                        spacing: 12
                        Layout.fillWidth: true
                        visible: root._operationMode === "mode2" || root._operationMode === "mode3"

                        property bool sbOn: eventManager.getAppSetting("sbcut_enabled", "false") === "true"
                        // Selfbooth chỉ dùng được khi gói có capability 'selfbooth'.
                        property bool sbAllowed: machineAuth.hasCapability("selfbooth")

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                        Text {
                            text: "Selfbooth (tự chụp)"
                            color: "#1e7eea"
                            font.pixelSize: 18
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Thêm ô 'Selfbooth' tại trang chọn loại ảnh: khách tự chụp miễn phí, không qua thanh toán."
                            color: root.mutedText(0.65)
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Toggle bật/tắt
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            color: "transparent"
                            radius: 8
                            opacity: sbcutSection.sbAllowed ? 1.0 : 0.45
                            border.color: (sbcutSection.sbOn && sbcutSection.sbAllowed) ? "#1e7eea" : "#2d5a8c"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                Text {
                                    text: "Bật Selfbooth" + (sbcutSection.sbAllowed ? "" : "  🔒")
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }

                                Rectangle {
                                    width: 48; height: 26; radius: 13
                                    color: (sbcutSection.sbOn && sbcutSection.sbAllowed) ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 150 } }

                                    Rectangle {
                                        width: 20; height: 20; radius: 10
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: (sbcutSection.sbOn && sbcutSection.sbAllowed) ? parent.width - width - 3 : 3
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: sbcutSection.sbAllowed ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            if (!machineAuth.hasCapability("selfbooth")) {
                                                autoSavedToast.show("Gói dịch vụ chưa được mua hoặc chưa được cập nhật. Vui lòng vào Cài đặt > Thông tin để nâng cấp.")
                                                return
                                            }
                                            sbcutSection.sbOn = !sbcutSection.sbOn
                                            eventManager.setAppSetting("sbcut_enabled", sbcutSection.sbOn ? "true" : "false")
                                        }
                                    }
                                }
                            }
                        }

                        // Thumbnail Selfbooth (chỉ hiện khi đã bật)
                        ColumnLayout {
                            spacing: 12
                            Layout.fillWidth: true
                            visible: sbcutSection.sbOn

                            Text {
                                text: "Thumbnail Selfbooth"
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 260
                                color: "transparent"
                                radius: 8
                                border.color: "#2d5a8c"
                                border.width: 1

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 12

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "transparent"
                                        radius: 4
                                        border.color: "#2d5a8c"

                                        Image {
                                            id: sbcutThumbPreview
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: {
                                                var dummy = root._bgRefreshCount
                                                var p = eventManager.getAppSetting("sbcut_thumbnail", "")
                                                if (!p) return ""
                                                if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
                                                return "file:///" + p.replace(/\\/g, "/")
                                            }
                                            fillMode: Image.PreserveAspectFit
                                            visible: source !== ""
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "Chưa có thumbnail"
                                            color: root.mutedText(0.65)
                                            font.pixelSize: 14
                                            visible: sbcutThumbPreview.source === ""
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        Button {
                                            text: "📁 Tải thumbnail"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 40
                                            background: Rectangle { color: parent.hovered ? "#1e7eea" : "#1976d2"; radius: 6 }
                                            contentItem: Text { text: parent.text; color: root.themeTextColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14; font.weight: Font.Medium }
                                            onClicked: sbcutThumbnailDialog.open()
                                        }

                                        Button {
                                            text: "🗑️ Xoá"
                                            Layout.preferredWidth: 100
                                            Layout.preferredHeight: 40
                                            enabled: sbcutThumbPreview.source !== ""
                                            background: Rectangle { color: parent.enabled ? (parent.hovered ? "#d32f2f" : "#c62828") : Theme.field; radius: 6 }
                                            contentItem: Text { text: parent.text; color: parent.enabled ? "#ffffff" : root.mutedText(0.65); horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14 }
                                            onClicked: {
                                                eventManager.setAppSetting("sbcut_thumbnail", "")
                                                refreshBackgrounds()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── USB Relay control (đèn phòng chụp) ────────────────────────
                    ColumnLayout {
                        id: relaySection
                        spacing: 12
                        Layout.fillWidth: true

                        readonly property bool controllerAvailable: typeof relayController !== "undefined" && relayController !== null
                        readonly property var controller: controllerAvailable ? relayController : null

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                        Text { text: "Điều khiển Relay (đèn phòng chụp)"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                        Text {
                            text: "Bật để điều khiển đèn/thiết bị qua USB Relay: tự bật khi vào trang chụp, tự tắt khi rời trang chụp."
                            color: root.mutedText(0.65); font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        // Toggle bật/tắt tính năng
                        Rectangle {
                            Layout.fillWidth: true
                            height: 76
                            radius: 8; color: "transparent"; border.color: "#2d5a8c"; border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "Bật điều khiển Relay"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                    Text {
                                        text: relaySection.controller && relaySection.controller.connected
                                              ? ("Đã kết nối: " + relaySection.controller.currentSerial)
                                              : "Chưa kết nối"
                                        color: relaySection.controller && relaySection.controller.connected ? "#4ade80" : root.mutedText(0.65)
                                        font.pixelSize: 13
                                    }
                                }

                                Switch {
                                    id: relayEnableSwitch
                                    enabled: relaySection.controllerAvailable
                                    checked: relaySection.controller ? relaySection.controller.enabled : false
                                    onToggled: {
                                        if (relaySection.controller)
                                            relaySection.controller.setEnabled(checked)
                                    }
                                }
                            }
                        }

                        // Chọn thiết bị + danh sách kênh (chỉ hiện khi đã bật)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: relaySection.controller && relaySection.controller.enabled

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Text { text: "Thiết bị:"; color: root.mutedText(0.65); font.pixelSize: 14 }

                                ComboBox {
                                    id: relayDeviceCombo
                                    Layout.preferredWidth: 240
                                    height: 40
                                    model: relaySection.controller ? relaySection.controller.devices : []
                                    onActivated: {
                                        if (relaySection.controller)
                                            relaySection.controller.selectDevice(currentText)
                                    }
                                    Component.onCompleted: {
                                        if (relaySection.controller) {
                                            var i = relaySection.controller.devices.indexOf(relaySection.controller.currentSerial)
                                            if (i >= 0) currentIndex = i
                                        }
                                    }
                                }

                                Button {
                                    text: "Tìm lại"
                                    enabled: relaySection.controllerAvailable
                                    onClicked: {
                                        if (relaySection.controller)
                                            relaySection.controller.scanAndConnect()
                                    }
                                }

                                Item { Layout.fillWidth: true }
                            }

                            Text {
                                visible: relaySection.controller && relaySection.controller.channelCount > 0
                                text: "Chọn kênh dùng khi chụp và đổi tên thiết bị (vd: Đèn phòng 1):"
                                color: root.mutedText(0.65); font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Repeater {
                                model: relaySection.controller ? relaySection.controller.channelCount : 0
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    height: 58
                                    radius: 8; color: "transparent"; border.color: "#2d5a8c"; border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        CheckBox {
                                            checked: relaySection.controller ? relaySection.controller.isChannelActive(index + 1) : false
                                            onToggled: {
                                                if (relaySection.controller)
                                                    relaySection.controller.setChannelActive(index + 1, checked)
                                            }
                                        }

                                        Text {
                                            text: "Kênh " + (index + 1)
                                            color: root.mutedText(0.65); font.pixelSize: 14
                                            Layout.preferredWidth: 64
                                        }

                                        TextField {
                                            id: relayNameField
                                            Layout.fillWidth: true
                                            height: 40
                                            text: relaySection.controller ? relaySection.controller.channelName(index + 1) : ("Relay " + (index + 1))
                                            placeholderText: "Tên thiết bị (vd: Đèn phòng " + (index + 1) + ")"
                                            color: root.themeTextColor
                                            font.pixelSize: 15
                                            leftPadding: 12
                                            background: Rectangle {
                                                color: "transparent"; radius: 6
                                                border.color: relayNameField.activeFocus ? "#4FA4F2" : Theme.border
                                                border.width: relayNameField.activeFocus ? 2 : 1
                                            }
                                            onEditingFinished: {
                                                if (relaySection.controller) {
                                                    relaySection.controller.setChannelName(index + 1, text)
                                                    autoSavedToast.show("Đã lưu tên kênh " + (index + 1))
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: relaySection.controller && relaySection.controller.enabled && relaySection.controller.channelCount === 0 && !relaySection.controller.scanning
                                text: "Chưa phát hiện thiết bị relay. Cắm thiết bị rồi bấm \"Tìm lại\"."
                                color: "#f0a000"; font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }

                        // Thông báo kết quả quét
                        Connections {
                            target: relaySection.controller
                            function onScanFinished(ok, message) {
                                if (ok) autoSavedToast.show("Đã kết nối relay: " + message)
                                else    autoSavedToast.show("Relay: " + message)
                            }
                        }

                        // Popup "đang tìm và kết nối"
                        Popup {
                            id: relayScanPopup
                            parent: Overlay.overlay
                            anchors.centerIn: Overlay.overlay
                            modal: true
                            Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                            closePolicy: Popup.NoAutoClose
                            visible: relaySection.controller && relaySection.controller.scanning
                            width: 340; height: 150
                            background: Rectangle { color: "transparent"; radius: 12; border.color: "#2d5a8c"; border.width: 1 }
                            contentItem: ColumnLayout {
                                spacing: 16
                                BusyIndicator { Layout.alignment: Qt.AlignHCenter; running: relayScanPopup.visible }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Đang tìm và kết nối relay..."
                                    color: root.themeTextColor; font.pixelSize: 15
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Thư viện ảnh: xem lại & in ảnh đã chụp (chuyển từ SelectServiceScreen/CutModeScreen) ──
    Component {
        id: galleryTabComponent
        Item {
            GalleryScreen {
                width: parent.width
                height: parent.height
                // Cùng nguồn dữ liệu sự kiện như màn booth (eventId của sự kiện đang mở).
                eventId:   root.eventData ? root.eventData.id : -1
                eventData: root.eventData
                hwid:      machineAuth.hwid
                // Trong Cài đặt: "Quay Lại" trở về lưới danh mục thay vì pop stack.
                onBackClicked: root.currentTab = -1
            }
        }
    }

    // ── Thông tin máy: HWID + thời hạn sử dụng (license) ─────────────────
    Component {
        id: infoTabComponent
        Item {
            id: infoRoot
            property var _intent: null
            property string _payStatus: ""
            function fmtVnd(n) { return Number(n || 0).toLocaleString(Qt.locale("vi_VN"), "f", 0) }

            // Không còn hiển thị giá gói/mua gói trong app — thay bằng thông tin
            // studio (chủ, email, nhân viên) + lượt đăng nhập QR gần nhất.
            StudioInfoPanel {
                anchors.fill: parent
                z: 2
                // Tone sáng đồng bộ với SettingsPage (nền sáng, chữ đen).
                panelText:    root.themeTextColor
                panelMuted:   root.mutedText(0.6)
                panelSurface: "transparent"
                panelBorder:  "#E2E6EC"
                popupSurface: "#FFFFFF"
                accentGreen:  "#16A34A"
                accentAmber:  "#D97706"
                onNotify: function(message) { autoSavedToast.show(message) }
            }

            ScrollView {
                anchors.fill: parent
                visible: false
                contentWidth: parent.width
                clip: true

                ColumnLayout {
                    width: parent.width - 80
                    spacing: 24

                    Text {
                        text: "Thông tin máy"
                        color: root.themeTextColor
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    // ── HWID ──────────────────────────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        color: "transparent"
                        radius: 8
                        border.color: "#2d5a8c"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Rectangle {
                                width: 56; height: 56; radius: 8; color: "transparent"
                                Text { anchors.centerIn: parent; text: "🆔"; font.pixelSize: 28 }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text { text: "HWID (Mã định danh máy)"; color: root.mutedText(0.65); font.pixelSize: 14 }
                                Text {
                                    text: (machineAuth.hwid && machineAuth.hwid.length > 0)
                                          ? machineAuth.hwid : "Chưa xác định"
                                    color: root.themeTextColor
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                    font.family: "Consolas"
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 96
                                Layout.preferredHeight: 40
                                radius: 6
                                color: copyHwidMouse.pressed ? "#1668c7"
                                       : (copyHwidMouse.containsMouse ? "#2a8bff" : "#1e7eea")
                                border.color: "#2d5a8c"; border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: copyHwidMouse._copied ? "Đã chép ✓" : "Sao chép"
                                    color: "#ffffff"; font.pixelSize: 14
                                }
                                MouseArea {
                                    id: copyHwidMouse
                                    property bool _copied: false
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        hwidClip.text = machineAuth.hwid
                                        hwidClip.selectAll()
                                        hwidClip.copy()
                                        _copied = true
                                        copyResetTimer.restart()
                                    }
                                }
                                Timer {
                                    id: copyResetTimer
                                    interval: 1500
                                    onTriggered: copyHwidMouse._copied = false
                                }
                            }
                        }
                    }

                    // ── Thời hạn sử dụng (license) ────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 110
                        color: "transparent"
                        radius: 8
                        border.color: "#2d5a8c"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Rectangle {
                                width: 56; height: 56; radius: 8; color: "transparent"
                                Text { anchors.centerIn: parent; text: "⏳"; font.pixelSize: 28 }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text { text: "Thời hạn sử dụng (License)"; color: root.mutedText(0.65); font.pixelSize: 14 }
                                Text {
                                    text: (machineAuth.licenseEnd && machineAuth.licenseEnd.length > 0)
                                          ? machineAuth.licenseEnd : "Không giới hạn"
                                    color: "#2ecc71"
                                    font.pixelSize: 22
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }

                    // ── Gói dịch vụ & nâng cấp (mỗi gói 1 ô, xếp ngang) ────────
                    Rectangle {
                        id: plansBox
                        property int buyYears: 1
                        Layout.fillWidth: true
                        Layout.preferredHeight: plansCol.implicitHeight + 40
                        color: Theme.settingsSurface
                        radius: Theme.settingsRadiusMedium
                        border.color: Theme.settingsBorder
                        border.width: 1

                        ColumnLayout {
                            id: plansCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Gói dịch vụ"; color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    Layout.preferredWidth: badgeTxt.implicitWidth + 24
                                    Layout.preferredHeight: 28
                                    radius: 14
                                    color: machineAuth.plan === "trial"
                                           ? Qt.rgba(Theme.settingsWarning.r, Theme.settingsWarning.g, Theme.settingsWarning.b, 0.14)
                                           : Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.14)
                                    border.color: machineAuth.plan === "trial" ? Theme.settingsWarning : Theme.settingsSuccess
                                    border.width: 1
                                    Text {
                                        id: badgeTxt
                                        anchors.centerIn: parent
                                        text: machineAuth.plan === "trial" ? "Đang dùng thử"
                                              : (machineAuth.plan && machineAuth.plan.length > 0 ? ("Gói: " + machineAuth.plan) : "Chưa có gói")
                                        color: machineAuth.plan === "trial" ? Theme.settingsWarning : Theme.settingsSuccess
                                        font.pixelSize: 13; font.weight: Font.Bold
                                    }
                                }
                            }

                            // Chọn thời hạn mua (mặc định 1 năm, +/- ; mua dài càng rẻ)
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text { text: "Thời hạn mua:"; color: root.mutedText(0.65); font.pixelSize: 14 }
                                Rectangle {
                                    width: 34; height: 34; radius: Theme.settingsRadiusSmall; color: minusMouse.containsMouse ? Theme.settingsCopperSoft : "transparent"
                                    border.color: minusMouse.containsMouse ? Theme.settingsCopper : Theme.settingsBorder; border.width: 1
                                    Text { anchors.centerIn: parent; text: "−"; color: root.themeTextColor; font.pixelSize: 20 }
                                    MouseArea { id: minusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: plansBox.buyYears = Math.max(1, plansBox.buyYears - 1) }
                                }
                                Text { text: plansBox.buyYears + " năm"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Bold
                                       horizontalAlignment: Text.AlignHCenter; Layout.preferredWidth: 64 }
                                Rectangle {
                                    width: 34; height: 34; radius: Theme.settingsRadiusSmall; color: plusMouse.containsMouse ? Theme.settingsCopperSoft : "transparent"
                                    border.color: plusMouse.containsMouse ? Theme.settingsCopper : Theme.settingsBorder; border.width: 1
                                    Text { anchors.centerIn: parent; text: "+"; color: root.themeTextColor; font.pixelSize: 20 }
                                    MouseArea { id: plusMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: plansBox.buyYears = Math.min(10, plansBox.buyYears + 1) }
                                }
                                Text { text: "Mua càng dài càng rẻ"; color: Theme.settingsTextMuted; font.pixelSize: 13; Layout.leftMargin: 6 }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "Hạn: " + ((machineAuth.licenseEnd && machineAuth.licenseEnd.length > 0) ? machineAuth.licenseEnd : "—")
                                    color: root.mutedText(0.65); font.pixelSize: 13
                                }
                            }

                            // Mỗi gói 1 ô, xếp thành một hàng ngang
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 14

                                Repeater {
                                    model: licenseStore.plans
                                    delegate: Rectangle {
                                        id: planCard
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        Layout.preferredHeight: 286
                                        radius: Theme.settingsRadiusMedium
                                        color: planCard.isCurrent ? Theme.settingsCopperSoft : Theme.settingsCard
                                        border.color: planCard.isCurrent ? Theme.settingsCopper : Theme.settingsBorder
                                        border.width: planCard.isCurrent ? 2 : 1

                                        property bool isCurrent: machineAuth.plan === modelData.code
                                        property bool hasPaid: machineAuth.plan && machineAuth.plan.length > 0 && machineAuth.plan !== "trial"
                                        property var caps: modelData.capabilities || ({})

                                        ColumnLayout {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 8

                                            // Tên gói + nhãn "Đang dùng"
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 8
                                                Text {
                                                    text: modelData.name; color: root.themeTextColor
                                                    font.pixelSize: 17; font.weight: Font.Bold
                                                    Layout.fillWidth: true; elide: Text.ElideRight
                                                }
                                                Rectangle {
                                                    visible: planCard.isCurrent
                                                    Layout.preferredWidth: curTxt.implicitWidth + 16
                                                    Layout.preferredHeight: 22
                                                    radius: 11
                                                    color: Theme.settingsCopper
                                                    Text { id: curTxt; anchors.centerIn: parent; text: "Đang dùng"; color: "#FFFFFF"; font.pixelSize: 10; font.bold: true }
                                                }
                                            }

                                            Text {
                                                text: modelData.description || ""
                                                color: root.mutedText(0.65); font.pixelSize: 13
                                                wrapMode: Text.WordWrap; Layout.fillWidth: true
                                                Layout.preferredHeight: 40
                                            }

                                            // Chế độ mở (capability chips)
                                            Flow {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Repeater {
                                                    model: [
                                                        { on: planCard.caps.event === true,     t: "Chế độ 1" },
                                                        { on: planCard.caps.studio === true,    t: "Chế độ 2,3" },
                                                        { on: planCard.caps.selfbooth === true, t: "Self-booth" },
                                                    ]
                                                    delegate: Rectangle {
                                                        visible: modelData.on
                                                        width: chip.implicitWidth + 16; height: 22; radius: 11
                                                        color: Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.12)
                                                        Text { id: chip; anchors.centerIn: parent; text: modelData.t; color: Theme.settingsSuccess; font.pixelSize: 10; font.bold: true }
                                                    }
                                                }
                                            }

                                            Item { Layout.fillHeight: true }

                                            // Giá
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 4
                                                Text {
                                                    text: infoRoot.fmtVnd(modelData.price_per_year)
                                                    color: root.themeTextColor; font.pixelSize: 22; font.weight: Font.Bold
                                                }
                                                Text {
                                                    text: "đ/năm"; color: root.mutedText(0.65); font.pixelSize: 13
                                                    Layout.alignment: Qt.AlignBottom; bottomPadding: 3
                                                }
                                            }
                                            Text {
                                                visible: !planCard.hasPaid || planCard.isCurrent
                                                text: "Tổng " + plansBox.buyYears + " năm: " + infoRoot.fmtVnd(licenseStore.totalForYears(modelData.price_per_year, plansBox.buyYears)) + "đ"
                                                color: Theme.settingsSuccess; font.pixelSize: 12; font.weight: Font.Medium
                                            }
                                            Text {
                                                visible: planCard.hasPaid && !planCard.isCurrent
                                                text: "Đổi gói: chỉ bù phí tính năng nhận thêm"
                                                color: Theme.settingsWarning; font.pixelSize: 11
                                                wrapMode: Text.WordWrap; Layout.fillWidth: true
                                            }

                                            // Nút mua / đổi gói / đang dùng
                                            Rectangle {
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 42
                                                radius: Theme.settingsRadiusSmall
                                                color: planCard.isCurrent ? "transparent"
                                                       : (cardBuyMouse.containsMouse ? Theme.settingsCopperDark : Theme.settingsCopper)
                                                border.color: planCard.isCurrent ? Theme.settingsBorder : Theme.settingsCopper
                                                border.width: 1
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: planCard.isCurrent ? "Đang dùng"
                                                          : (planCard.hasPaid ? "Đổi gói" : "Mua")
                                                    color: planCard.isCurrent ? root.mutedText(0.65) : "#FFFFFF"
                                                    font.pixelSize: 15; font.weight: Font.Bold
                                                }
                                                MouseArea {
                                                    id: cardBuyMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    enabled: !licenseStore.busy && !planCard.isCurrent
                                                    onClicked: {
                                                        if (modelData.is_contact) {
                                                            autoSavedToast.show("Gói doanh nghiệp: liên hệ sales 0395458706.")
                                                            return
                                                        }
                                                        if (planCard.hasPaid)
                                                            licenseStore.createIntent(machineAuth.hwid, modelData.code, 1, "switch")
                                                        else
                                                            licenseStore.createIntent(machineAuth.hwid, modelData.code, plansBox.buyYears, "new")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: licenseStore.plans.length === 0
                                text: licenseStore.busy ? "Đang tải danh sách gói..." : "Chưa tải được gói. Kiểm tra kết nối mạng."
                                color: root.mutedText(0.65); font.pixelSize: 14
                            }
                        }

                        Component.onCompleted: licenseStore.fetchPlans()
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 132
                        color: "transparent"
                        radius: 8
                        border.color: "#2d5a8c"
                        border.width: 1
                        visible: false

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 16

                            Rectangle {
                                width: 56; height: 56; radius: 8; color: "transparent"
                                Text { anchors.centerIn: parent; text: "G"; font.pixelSize: 28; font.bold: true; color: "#8ab4f8" }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Text { text: "Đăng nhập cũ"; color: root.mutedText(0.65); font.pixelSize: 14 }
                                Text {
                                    text: "Không sử dụng"
                                    color: root.themeTextColor
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                                Text {
                                    text: "Luồng đăng nhập cũ đã tắt"
                                    color: "#8fa0b8"
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 148
                                Layout.preferredHeight: 42
                                radius: 6
                                color: googleLogoutMouse.containsMouse ? "#7a1f1f" : "#2a1b1b"
                                border.color: "#6a3030"
                                border.width: 1
                                visible: false
                                Text {
                                    anchors.centerIn: parent
                                    text: "Đăng xuất"
                                    color: "#ffb4b4"
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                }
                                MouseArea {
                                    id: googleLogoutMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        autoSavedToast.show("Luồng đăng nhập cũ đã tắt")
                                    }
                                }
                            }
                        }
                    }

                    // ── Trạng thái xác thực ───────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        text: "Trạng thái: " + (machineAuth.statusMessage || "")
                        color: root.mutedText(0.65)
                        font.pixelSize: 14
                        wrapMode: Text.WordWrap
                    }

                    // ── Giới thiệu phần mềm & liên hệ hỗ trợ ──────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: introCol.implicitHeight + 40
                        color: "transparent"
                        radius: 8
                        border.color: "#2d5a8c"
                        border.width: 1

                        ColumnLayout {
                            id: introCol
                            anchors.fill: parent
                            anchors.margins: 20
                            spacing: 10

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Rectangle {
                                    width: 56; height: 56; radius: 8; color: "transparent"
                                    Text { anchors.centerIn: parent; text: "📸"; font.pixelSize: 28 }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "BOOTHME"; color: root.themeTextColor; font.pixelSize: 22; font.weight: Font.Bold }
                                    Text { text: "Phần mềm photobooth chuyên nghiệp"; color: root.mutedText(0.65); font.pixelSize: 14 }
                                }
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: "transparent" }

                            Text {
                                Layout.fillWidth: true
                                text: "Giải pháp photobooth chuyên nghiệp, ổn định và dễ sử dụng cho mọi sự kiện."
                                color: root.mutedText(0.65)
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                            }

                            Text {
                                Layout.fillWidth: true
                                text: "Mọi thắc mắc cần hỗ trợ vui lòng liên hệ:"
                                color: root.themeTextColor
                                font.pixelSize: 14
                                font.weight: Font.Medium
                                wrapMode: Text.WordWrap
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "✉️"; font.pixelSize: 15 }
                                Text {
                                    text: "boothstudio2026@gmail.com"
                                    color: "#1e7eea"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Qt.openUrlExternally("mailto:boothstudio2026@gmail.com")
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Text { text: "📞"; font.pixelSize: 15 }
                                Text {
                                    text: "Hotline: 0395458706"
                                    color: "#2ecc71"
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                }
                            }
                        }
                    }

                    // TextEdit ẩn dùng cho thao tác sao chép vào clipboard
                    TextEdit { id: hwidClip; visible: false }
                }
            }

            // ── Thanh toán SePay: nhận intent + poll trạng thái ──────────────
            Connections {
                target: null
                function onIntentCreated(intent) {
                    infoRoot._intent = intent
                    infoRoot._payStatus = "pending"
                    qrPopup.open()
                    payPollTimer.start()
                }
                function onIntentStatus(code, status) {
                    if (!infoRoot._intent || code !== infoRoot._intent.code) return
                    infoRoot._payStatus = status
                    if (status === "paid") {
                        payPollTimer.stop()
                        qrPopup.close()
                        autoSavedToast.show("Thanh toán thành công! Đang kích hoạt license...")
                        machineAuth.retryAuthentication()
                    }
                }
                function onErrorOccurred(msg) { autoSavedToast.show("Lỗi: " + msg) }
                function onSwitchApplied() {
                    autoSavedToast.show("Đã đổi gói thành công!")
                    machineAuth.retryAuthentication()
                }
            }

            Timer {
                id: payPollTimer
                interval: 4000
                repeat: true
                running: false
                onTriggered: if (infoRoot._intent) licenseStore.checkIntent(machineAuth.hwid, infoRoot._intent.code)
            }

            Popup {
                id: qrPopup
                parent: Overlay.overlay
                anchors.centerIn: Overlay.overlay
                modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                closePolicy: Popup.CloseOnEscape
                width: 420
                height: qrCol.implicitHeight + 48
                onClosed: payPollTimer.stop()
                background: Rectangle { color: "transparent"; radius: 14; border.color: "#2d5a8c"; border.width: 1 }

                ColumnLayout {
                    id: qrCol
                    anchors.centerIn: parent
                    width: parent.width - 48
                    spacing: 14

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Quét QR để thanh toán"
                        color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 240; height: 240; radius: 10; color: "transparent"
                        Image {
                            anchors.centerIn: parent
                            width: 220; height: 220
                            fillMode: Image.PreserveAspectFit
                            source: infoRoot._intent ? infoRoot._intent.qr_url : ""
                            cache: false
                        }
                    }

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: infoRoot._intent ? (infoRoot.fmtVnd(infoRoot._intent.amount) + " đ") : ""
                        color: "#2ecc71"; font.pixelSize: 22; font.weight: Font.Bold
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: infoCol.implicitHeight + 20
                        color: "transparent"; radius: 8
                        ColumnLayout {
                            id: infoCol
                            anchors.fill: parent; anchors.margins: 10; spacing: 3
                            Text { text: "Ngân hàng: " + (infoRoot._intent ? infoRoot._intent.bank : ""); color: root.mutedText(0.65); font.pixelSize: 13 }
                            Text { text: "Số TK: " + (infoRoot._intent ? infoRoot._intent.account : ""); color: root.mutedText(0.65); font.pixelSize: 13 }
                            Text { text: "Chủ TK: " + (infoRoot._intent ? infoRoot._intent.holder : ""); color: root.mutedText(0.65); font.pixelSize: 13 }
                            Text {
                                text: "Nội dung CK: " + (infoRoot._intent ? infoRoot._intent.content : "")
                                color: "#f0c040"; font.pixelSize: 14; font.weight: Font.Bold
                                wrapMode: Text.WrapAnywhere; Layout.fillWidth: true
                            }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: infoRoot._payStatus === "paid" ? "Đã thanh toán ✓" : "Đang chờ thanh toán... (tự động kích hoạt sau khi nhận tiền)"
                        color: infoRoot._payStatus === "paid" ? "#2ecc71" : "#8fa0b8"
                        font.pixelSize: 13; wrapMode: Text.WordWrap
                    }

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 120; height: 40; radius: 6
                        color: closePayMouse.containsMouse ? Theme.border : Theme.field
                        border.color: "#2d5a8c"; border.width: 1
                        Text { anchors.centerIn: parent; text: "Đóng"; color: root.themeTextColor; font.pixelSize: 15 }
                        MouseArea {
                            id: closePayMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { payPollTimer.stop(); qrPopup.close() }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: generalTabComponent
        Item {
            id: generalTabRoot
            // Chiều cao bàn phím quy về design coordinates (chia cho scale)
            property real _vkHeight: {
                if (!Qt.inputMethod.visible) return 0
                var scale = Window.window ? Window.window._contentScale : 1.0
                if (scale <= 0) scale = 1.0
                return Qt.inputMethod.keyboardRectangle.height / scale
            }

            Component.onDestruction: root.generalSectionTitle = ""

            // Màn tổng quan ngắn thay cho trang cài đặt dài liên tục.
            ScrollView {
                anchors.fill: parent
                anchors.margins: 28
                visible: root.generalSectionTitle === ""
                contentWidth: availableWidth
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                ColumnLayout {
                    width: parent.width
                    spacing: 22

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 112
                        radius: 18
                        color: Theme.settingsCard
                        border.color: Theme.settingsBorder
                        RowLayout {
                            anchors.fill: parent; anchors.margins: 20; spacing: 16
                            Rectangle { Layout.preferredWidth: 58; Layout.preferredHeight: 58; radius: 17; color: Theme.settingsCopperSoft
                                SettingsIcon { anchors.centerIn: parent; width: 28; height: 28; name: "capture"; color: Theme.settingsCopper }
                            }
                            ColumnLayout { Layout.fillWidth: true; spacing: 4
                                Text { text: "Sự kiện đang cấu hình"; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                                Text { Layout.fillWidth: true; text: root.eventData && root.eventData.name ? root.eventData.name : "Chưa chọn sự kiện"; color: Theme.settingsText; font.pixelSize: 20; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { text: "Các mục có nhãn Sự kiện chỉ áp dụng cho sự kiện này."; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                            }
                            Rectangle { Layout.preferredWidth: 126; Layout.preferredHeight: 34; radius: 10; color: Theme.settingsCopperSoft
                                Text { anchors.centerIn: parent; text: "SỰ KIỆN"; color: Theme.settingsCopper; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.1 }
                            }
                        }
                    }

                    Text { text: "Chọn nhóm cần thiết lập"; color: Theme.settingsText; font.pixelSize: 19; font.weight: Font.DemiBold }
                    Text { text: "Mỗi nhóm chỉ hiển thị những tuỳ chọn liên quan, giúp thao tác nhanh và tránh nhầm lẫn."; color: Theme.settingsTextMuted; font.pixelSize: 13 }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 1380 ? 4 : (width >= 760 ? 2 : 1)
                        columnSpacing: 16; rowSpacing: 16

                        Repeater {
                            model: [
                                { title: "Nội dung hiển thị", desc: "Văn bản Landing, màn chụp và thông điệp sự kiện", icon: "text", section: "Nội dung hiển thị", badge: "Hệ thống + Sự kiện" },
                                { title: "Màn hình & bố cục", desc: "Hướng màn hình, tỷ lệ và chế độ Photobooth Báo", icon: "monitor", section: "Màn hình & bố cục", badge: "Hệ thống" },
                                { title: "Lưu trữ", desc: "Thư mục ảnh RAW và ảnh đã xử lý", icon: "folder", section: "Lưu trữ", badge: "Sự kiện" },
                                { title: "Media đầu ra", desc: "Tạo video sau phiên và chọn độ phân giải", icon: "video", section: "Media đầu ra", badge: "Hệ thống" }
                            ]
                            delegate: SettingsCategoryCard {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; Layout.preferredHeight: 138
                                title: modelData.title; description: modelData.desc; iconName: modelData.icon; accent: Theme.settingsCopper
                                onClicked: root.generalSectionTitle = modelData.section
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 78; radius: 14
                        color: "#FFF8F3"; border.color: Theme.settingsBorder
                        RowLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                            SettingsIcon { width: 22; height: 22; name: "info"; color: Theme.settingsCopper }
                            Text { Layout.fillWidth: true; text: "Live View, bảo mật, lưu trữ và media đã được chuyển về đúng danh mục chuyên trách."; color: Theme.settingsTextMuted; font.pixelSize: 13; wrapMode: Text.WordWrap }
                        }
                    }
                }
            }

            ScrollView {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent._vkHeight
                visible: root.generalSectionTitle !== ""
                contentWidth: parent.width
                clip: true
                background: Item {}

                Behavior on anchors.bottomMargin {
                    NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    width: parent.width - 80
                    spacing: 32

                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // thông tin sự kiện đã nằm ở màn tổng quan

                        Text { text: "Cấu hình cho sự kiện hiện tại"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 100
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 20

                                Rectangle {
                                    width: 60; height: 60
                                    radius: 8
                                    color: "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "📅"
                                        font.pixelSize: 32
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: root.eventData ? (root.eventData.name || "Untitled Event") : "No Event Selected"
                                        color: root.themeTextColor
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        text: root.eventData ? ("Created: " + (root.eventData.created || "Just now")) : "-"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 14
                                    }

                                    Text {
                                        text: "Location: Local Storage"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 13
                                    }
                                }
                            }
                        }
                    }

                    // ── Live View Quality Setting ────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Máy ảnh

                        Text { text: "Hiệu suât Live View"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 210
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 0

                                // ── Độ phân giải ──────────────────────────────────────
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 20

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Độ phân giải Live View"
                                            color: root.themeTextColor
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }

                                        Text {
                                            text: "Giảm độ phân giải giúp Live View mượt hơn trên máy tính yếu."
                                            color: root.mutedText(0.65)
                                            font.pixelSize: 13
                                        }
                                    }

                                    ComboBox {
                                        id: liveViewQualityCombo
                                        Layout.preferredWidth: 220
                                        height: 40

                                        property string currentSetting: eventManager.getAppSetting("live_view_max_width", "0")

                                        model: ListModel {
                                            ListElement { text: "Theo máy ảnh / Native"; value: "0" }
                                            ListElement { text: "Hiệu năng mượt (640p)"; value: "640" }
                                            ListElement { text: "Cân bằng (960p)"; value: "960" }
                                            ListElement { text: "Chất lượng cao (1280p)"; value: "1280" }
                                        }

                                        textRole: "text"
                                        valueRole: "value"

                                        Component.onCompleted: {
                                            for (var i = 0; i < model.count; i++) {
                                                if (model.get(i).value === currentSetting) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }

                                        onActivated: {
                                            var val = model.get(currentIndex).value
                                            eventManager.setAppSetting("live_view_max_width", val)
                                            cameraController.setMaxLiveViewWidth(parseInt(val))
                                            autoSavedToast.show("Đã lưu độ phân giải Live View")
                                        }

                                        background: Rectangle {
                                            color: "transparent"; radius: 6
                                            border.color: "#2d5a8c"; border.width: 1
                                        }
                                        contentItem: Text {
                                            text: liveViewQualityCombo.displayText
                                            color: root.themeTextColor; font.pixelSize: 15
                                            verticalAlignment: Text.AlignVCenter; leftPadding: 16
                                        }
                                        popup: Popup {
                                            y: liveViewQualityCombo.height + 4
                                            width: liveViewQualityCombo.width
                                            implicitHeight: contentItem.implicitHeight; padding: 1
                                            contentItem: ListView {
                                                clip: true; implicitHeight: contentHeight
                                                model: liveViewQualityCombo.popup.visible ? liveViewQualityCombo.delegateModel : null
                                                currentIndex: liveViewQualityCombo.highlightedIndex
                                                boundsBehavior: Flickable.StopAtBounds
                                            }
                                            background: Rectangle { color: "transparent"; border.color: "#2d5a8c"; radius: 6 }
                                        }
                                    }
                                }

                                // ── Divider ───────────────────────────────────────────
                                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                                // ── Giới hạn FPS ──────────────────────────────────────
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 20

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        Text {
                                            text: "Giới hạn FPS Live View"
                                            color: root.themeTextColor
                                            font.pixelSize: 16
                                            font.weight: Font.Medium
                                        }

                                        Text {
                                            text: "Giảm FPS để tiết kiệm CPU trên máy yếu. Không ảnh hưởng chất lượng ảnh chụp."
                                            color: root.mutedText(0.65)
                                            font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }

                                    ComboBox {
                                        id: liveViewFpsCombo
                                        Layout.preferredWidth: 220
                                        height: 40

                                        property string currentSetting: eventManager.getAppSetting("live_view_target_fps", "30")

                                        model: ListModel {
                                            ListElement { text: "Tối đa (30 FPS)"; value: "30" }
                                            ListElement { text: "Cân bằng (20 FPS)"; value: "20" }
                                            ListElement { text: "Tiết kiệm (15 FPS)"; value: "15" }
                                            ListElement { text: "Tối thiểu (10 FPS)"; value: "10" }
                                        }

                                        textRole: "text"
                                        valueRole: "value"

                                        Component.onCompleted: {
                                            for (var i = 0; i < model.count; i++) {
                                                if (model.get(i).value === currentSetting) {
                                                    currentIndex = i
                                                    break
                                                }
                                            }
                                        }

                                        onActivated: {
                                            var val = model.get(currentIndex).value
                                            eventManager.setAppSetting("live_view_target_fps", val)
                                            cameraController.setTargetLiveViewFps(parseInt(val))
                                            autoSavedToast.show("Đã lưu giới hạn FPS Live View")
                                        }

                                        background: Rectangle {
                                            color: "transparent"; radius: 6
                                            border.color: "#2d5a8c"; border.width: 1
                                        }
                                        contentItem: Text {
                                            text: liveViewFpsCombo.displayText
                                            color: root.themeTextColor; font.pixelSize: 15
                                            verticalAlignment: Text.AlignVCenter; leftPadding: 16
                                        }
                                        popup: Popup {
                                            y: liveViewFpsCombo.height + 4
                                            width: liveViewFpsCombo.width
                                            implicitHeight: contentItem.implicitHeight; padding: 1
                                            contentItem: ListView {
                                                clip: true; implicitHeight: contentHeight
                                                model: liveViewFpsCombo.popup.visible ? liveViewFpsCombo.delegateModel : null
                                                currentIndex: liveViewFpsCombo.highlightedIndex
                                                boundsBehavior: Flickable.StopAtBounds
                                            }
                                            background: Rectangle { color: "transparent"; border.color: "#2d5a8c"; radius: 6 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Bộ Lọc Màu toggle ────────────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Bộ lọc màu

                        Text { text: "Bộ Lọc Màu"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Rectangle {
                            id: filterEnabledCard
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool filterOn: eventManager.getAppSetting("filter_enabled", "false") === "true"

                            color: "transparent"
                            border.color: filterOn ? "#1e7eea" : "#2d5a8c"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48
                                    implicitHeight: 26
                                    radius: 13
                                    color: filterEnabledCard.filterOn ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Rectangle {
                                        x: filterEnabledCard.filterOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "Bật Bộ Lọc Màu"
                                        color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Khi bật, màn hình chọn bộ lọc sẽ xuất hiện sau khi ghép ảnh."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: filterEnabledMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    filterEnabledCard.filterOn = !filterEnabledCard.filterOn
                                    eventManager.setAppSetting("filter_enabled", filterEnabledCard.filterOn ? "true" : "false")
                                    autoSavedToast.show(filterEnabledCard.filterOn ? "Đã bật: Bộ lọc màu" : "Đã tắt: Bộ lọc màu")
                                }
                            }
                        }

                        // ── Toggle: Sticker (chỉ tác dụng khi Bộ lọc màu cũng bật) ──
                        Rectangle {
                            id: stickerEnabledCard
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool stickerOn: eventManager.getAppSetting("sticker_enabled", "false") === "true"

                            color: "transparent"
                            border.color: stickerOn ? "#1e7eea" : "#2d5a8c"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                    color: stickerEnabledCard.stickerOn ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        x: stickerEnabledCard.stickerOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "Bật Sticker"
                                        color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Khi bật (cùng Bộ lọc màu), trang chọn bộ lọc có thêm cụm sticker để dán lên ảnh trước khi in. Quản lý thư viện sticker ở tab Bộ lọc màu."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: stickerEnabledMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    stickerEnabledCard.stickerOn = !stickerEnabledCard.stickerOn
                                    eventManager.setAppSetting("sticker_enabled", stickerEnabledCard.stickerOn ? "true" : "false")
                                    autoSavedToast.show(stickerEnabledCard.stickerOn ? "Đã bật: Sticker" : "Đã tắt: Sticker")
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        Rectangle {
                            id: filterApplyAllPhotosCard
                            visible: false // chuyển sang tab Bộ lọc màu
                            Layout.fillWidth: true
                            height: 92
                            radius: 8
                            border.width: 1

                            property bool applyAllOn: eventManager.getAppSetting("filter_apply_all_photos", "false") === "true"

                            color: "transparent"
                            border.color: applyAllOn ? "#1e7eea" : "#2d5a8c"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                    color: filterApplyAllPhotosCard.applyAllOn ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        x: filterApplyAllPhotosCard.applyAllOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "Áp dụng bộ lọc cho ảnh lẻ"
                                        color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Khi bật, bộ lọc đã chọn sẽ áp dụng cho cả ảnh chụp riêng trong gallery/QR và video, không chỉ ảnh ghép. Chỉ có tác dụng khi đã bật Bộ Lọc Màu."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: filterApplyAllPhotosMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    filterApplyAllPhotosCard.applyAllOn = !filterApplyAllPhotosCard.applyAllOn
                                    eventManager.setAppSetting("filter_apply_all_photos",
                                                               filterApplyAllPhotosCard.applyAllOn ? "true" : "false")
                                    autoSavedToast.show(filterApplyAllPhotosCard.applyAllOn
                                                        ? "Đã bật: áp dụng filter cho ảnh lẻ"
                                                        : "Đã tắt: áp dụng filter cho ảnh lẻ")
                                }
                            }
                        }
                    }

                    // ── Toggle: Lật ảnh sau khi chụp ────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Cài đặt chụp

                        Text { text: "Lật Ảnh"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Rectangle {
                            id: flipPhotoEnabledCard
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool flipOn: eventManager.getAppSetting("flip_photo_enabled", "false") === "true"

                            color: "transparent"
                            border.color: flipOn ? "#1e7eea" : "#2d5a8c"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48
                                    implicitHeight: 26
                                    radius: 13
                                    color: flipPhotoEnabledCard.flipOn ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Rectangle {
                                        x: flipPhotoEnabledCard.flipOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "Bật Lật Ảnh Sau Khi Chụp"
                                        color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Khi bật, trang ghép ảnh sẽ có nút lật gương tất cả ảnh đã chụp."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: flipPhotoEnabledMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    flipPhotoEnabledCard.flipOn = !flipPhotoEnabledCard.flipOn
                                    eventManager.setAppSetting("flip_photo_enabled", flipPhotoEnabledCard.flipOn ? "true" : "false")
                                    autoSavedToast.show(flipPhotoEnabledCard.flipOn ? "Đã bật: Lật ảnh sau khi chụp" : "Đã tắt: Lật ảnh sau khi chụp")
                                }
                            }
                        }
                    }

                    // ── QR Code Settings section ─────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Chia sẻ

                        Text { text: "Mã QR Code"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Rectangle {
                            id: qrContainer
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool qrEnabled: eventManager.getAppSetting("qr_code_enabled", "false") === "true"

                            color: "transparent"
                            border.color: qrEnabled ? "#1e7eea" : "#2d5a8c"

                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                // Visual-only toggle indicator — click được xử lý bởi MouseArea bên dưới
                                Rectangle {
                                    implicitWidth: 48
                                    implicitHeight: 26
                                    radius: 13
                                    color: qrContainer.qrEnabled ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }

                                    Rectangle {
                                        x: qrContainer.qrEnabled ? parent.width - width - 2 : 2
                                        width: 22
                                        height: 22
                                        radius: 11
                                        color: "transparent"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: "Gán Mã QR Lên Ảnh"
                                        color: root.themeTextColor
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Tự động gán mã QR lên ảnh trước khi in."
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            // MouseArea phủ toàn bộ container — vùng click bằng toàn bộ button
                            MouseArea {
                                id: qrContainerMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    qrContainer.qrEnabled = !qrContainer.qrEnabled
                                    eventManager.setAppSetting("qr_code_enabled", qrContainer.qrEnabled ? "true" : "false")
                                    autoSavedToast.show(qrContainer.qrEnabled ? "Đã bật: Mã QR Code" : "Đã tắt: Mã QR Code")
                                }
                            }
                        }
                    }

                    // ── Security Settings section ────────────────────────────────────
                    ColumnLayout {
                        id: securitySection
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Tài khoản

                        Text { text: "Bảo Mật"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        // Toggle bật/tắt yêu cầu đăng nhập khi mở app
                        Rectangle {
                            id: loginRequiredCard
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool loginOn: eventManager.getAppSetting("login_required", "true") === "true"

                            color: "transparent"
                            border.color: loginOn ? "#1e7eea" : "#2d5a8c"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                    color: loginRequiredCard.loginOn ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        x: loginRequiredCard.loginOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: "Yêu Cầu Đăng Nhập Khi Mở App"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                    Text {
                                        text: "Bật: mở app phải đăng nhập nhân viên hoặc admin. Tắt: vào thẳng quyền admin, không cần đăng nhập."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    }
                                }
                            }
                            MouseArea {
                                id: loginRequiredMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    loginRequiredCard.loginOn = !loginRequiredCard.loginOn
                                    eventManager.setAppSetting("login_required", loginRequiredCard.loginOn ? "true" : "false")
                                    autoSavedToast.show(loginRequiredCard.loginOn ? "Đã bật: Yêu cầu đăng nhập" : "Đã tắt: Yêu cầu đăng nhập")
                                }
                            }
                        }

                        // Toggle bật/tắt bảo mật
                        Rectangle {
                            id: securityEnabledCard
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool securityOn: eventManager.getAppSetting("security_enabled", "false") === "true"

                            color: "transparent"
                            border.color: securityOn ? "#f0a020" : Theme.border
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                    color: securityEnabledCard.securityOn ? "#f0a020" : Theme.border
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        x: securityEnabledCard.securityOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: "Bật Bảo Mật Cài Đặt"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                    Text {
                                        text: "Yêu cầu nhập mật khẩu Admin để truy cập trang Cài đặt."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    }
                                }
                            }
                            MouseArea {
                                id: securityEnabledMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    securityEnabledCard.securityOn = !securityEnabledCard.securityOn
                                    eventManager.setAppSetting("security_enabled", securityEnabledCard.securityOn ? "true" : "false")
                                    autoSavedToast.show(securityEnabledCard.securityOn ? "Đã bật: Bảo mật cài đặt" : "Đã tắt: Bảo mật cài đặt")
                                }
                            }
                        }

                        // Quản lý mật khẩu (chỉ hiện khi bảo mật bật)
                        Rectangle {
                            Layout.fillWidth: true
                            radius: 8
                            color: "transparent"
                            border.color: "#2d5a8c"
                            border.width: 1
                            height: pinManageCol.implicitHeight + 32
                            visible: securityEnabledCard.securityOn

                            ColumnLayout {
                                id: pinManageCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
                                spacing: 16

                                Text { text: "🔑 Quản lý mật khẩu"; color: "#f0a020"; font.pixelSize: 15; font.weight: Font.Bold }

                                // Hiển thị mật khẩu hiện tại (masked)
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Text { text: "Mật khẩu hiện tại:"; color: root.mutedText(0.65); font.pixelSize: 14 }
                                    TextField {
                                        id: currentPinField
                                        Layout.fillWidth: true
                                        height: 44
                                        placeholderText: "Nhập mật khẩu hiện tại..."
                                        echoMode: TextInput.Password
                                        inputMethodHints: Qt.ImhDigitsOnly
                                        maximumLength: 6
                                        color: root.themeTextColor
                                        font.pixelSize: 16
                                        background: Rectangle {
                                            color: "transparent"
                                            radius: 8
                                            border.color: currentPinField.activeFocus ? "#4FA4F2" : Theme.border
                                            border.width: 1
                                        }
                                        leftPadding: 12
                                    }
                                }

                                // Input mật khẩu mới
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Text { text: "Đặt mật khẩu mới (4–6 chữ số):"; color: root.mutedText(0.65); font.pixelSize: 14 }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12

                                        TextField {
                                            id: newPinField
                                            Layout.fillWidth: true
                                            height: 44
                                            placeholderText: "Nhập mật khẩu mới..."
                                            echoMode: TextInput.Password
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            maximumLength: 6
                                            color: root.themeTextColor
                                            font.pixelSize: 16
                                            background: Rectangle {
                                                color: "transparent"
                                                radius: 8
                                                border.color: newPinField.activeFocus ? "#4FA4F2" : Theme.border
                                                border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                            }
                                            leftPadding: 12
                                        }

                                        TextField {
                                            id: confirmPinField
                                            Layout.fillWidth: true
                                            height: 44
                                            placeholderText: "Xác nhận mật khẩu..."
                                            echoMode: TextInput.Password
                                            inputMethodHints: Qt.ImhDigitsOnly
                                            maximumLength: 6
                                            color: root.themeTextColor
                                            font.pixelSize: 16
                                            background: Rectangle {
                                                color: "transparent"
                                                radius: 8
                                                border.color: confirmPinField.activeFocus
                                                              ? (newPinField.text !== "" && confirmPinField.text !== "" && newPinField.text !== confirmPinField.text ? "#ff4422" : "#4FA4F2")
                                                              : Theme.border
                                                border.width: 1
                                                Behavior on border.color { ColorAnimation { duration: 150 } }
                                            }
                                            leftPadding: 12
                                        }

                                        // Nút Lưu
                                        Rectangle {
                                            width: 100; height: 44; radius: 8
                                            color: savePinMa.pressed ? "#1565c0"
                                                 : (savePinMa.containsMouse ? "#1a6fd0" : "#1e7eea")
                                            Behavior on color { ColorAnimation { duration: 100 } }
                                            enabled: newPinField.text.length >= 4
                                                  && newPinField.text === confirmPinField.text

                                            opacity: enabled ? 1.0 : 0.4

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Lưu"
                                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                                            }
                                            MouseArea {
                                                id: savePinMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: parent.enabled
                                                onClicked: {
                                                    var error = eventManager.setSecurityPin(currentPinField.text, newPinField.text)
                                                    if (error !== "") {
                                                        autoSavedToast.show(error)
                                                        return
                                                    }
                                                    currentPinField.text = ""
                                                    newPinField.text = ""
                                                    confirmPinField.text = ""
                                                    autoSavedToast.show("Mật khẩu đã được cập nhật!")
                                                }
                                            }
                                        }

                                        // Nút Reset về 0000
                                        Rectangle {
                                            width: 110; height: 44; radius: 8
                                            color: resetPinMa.pressed ? "#8b1a0a"
                                                 : (resetPinMa.containsMouse ? "#aa2010" : "#882010")
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Reset 0000"
                                                color: root.themeTextColor; font.pixelSize: 14; font.bold: true
                                            }
                                            MouseArea {
                                                id: resetPinMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    var error = eventManager.setSecurityPin(currentPinField.text, "0000")
                                                    if (error !== "") {
                                                        autoSavedToast.show(error)
                                                        return
                                                    }
                                                    currentPinField.text = ""
                                                    newPinField.text = ""
                                                    confirmPinField.text = ""
                                                    autoSavedToast.show("Mật khẩu đã reset về 0000")
                                                }
                                            }
                                        }
                                    }

                                    // Thông báo lỗi confirm không khớp
                                    Text {
                                        visible: newPinField.text !== "" && confirmPinField.text !== ""
                                              && newPinField.text !== confirmPinField.text
                                        text: "⚠ Mật khẩu xác nhận không khớp"
                                        color: "#ff6644"; font.pixelSize: 13
                                    }

                                }
                            }
                        }
                    }

                    // ── Payment Settings section ─────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Chế độ

                        Text { text: "Thanh Toán"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        Rectangle {
                            id: paymentEnabledCard
                            Layout.fillWidth: true
                            visible: root._operationMode !== "mode1"
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool paymentEnabled: root._paymentEnabledSetting

                            color: "transparent"
                            border.color: paymentEnabled ? "#1e7eea" : "#2d5a8c"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                    color: paymentEnabledCard.paymentEnabled ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        x: paymentEnabledCard.paymentEnabled ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text {
                                        text: "Bật Thanh Toán (QR Seepay)"
                                        color: root.themeTextColor
                                        font.pixelSize: 15
                                        font.weight: Font.Medium
                                    }
                                    Text {
                                        text: "Yêu cầu người dùng quét mã thanh toán VietQR (tích hợp Seepay) trước khi cho phép in. Mã QR bắt buộc chứa nội dung có định dạng 'SEVQR...'."
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: paymentEnabledMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root._paymentEnabledSetting) {
                                        root._setOperationMode("mode1")
                                    } else {
                                        root._setOperationMode("mode2")
                                    }
                                    autoSavedToast.show(root._paymentEnabledSetting ? "Đã bật: Thanh Toán" : "Đã tắt: Thanh Toán")
                                }
                            }
                        }
                    }

                    // ── Voucher Settings section ──────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: false // chuyển sang tab Voucher

                        Text { text: "Voucher"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        // Toggle bật/tắt voucher
                        Rectangle {
                            id: voucherEnabledCard
                            Layout.fillWidth: true
                            height: 80; radius: 8; border.width: 1

                            property bool voucherEnabled: eventManager.getAppSetting("voucher_enabled", "false") === "true"

                            color: "transparent"
                            border.color: voucherEnabled ? "#4caf50" : Theme.border
                            Behavior on color        { ColorAnimation { duration: 150 } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent; anchors.margins: 20; spacing: 16
                                Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: voucherEnabledCard.voucherEnabled ? "#4caf50" : Theme.border
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Rectangle {
                                        width: 18; height: 18; radius: 9
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: voucherEnabledCard.voucherEnabled ? 22 : 4
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                        color: "transparent"
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 4
                                    Text { text: "Bật Voucher"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                    Text { text: "Hiện màn hình nhập mã giảm giá / thêm lượt in trước khi thanh toán"; color: root.mutedText(0.65); font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                }
                            }

                            MouseArea {
                                id: voucherEnabledMouse; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    voucherEnabledCard.voucherEnabled = !voucherEnabledCard.voucherEnabled
                                    eventManager.setAppSetting("voucher_enabled", voucherEnabledCard.voucherEnabled ? "true" : "false")
                                    autoSavedToast.show(voucherEnabledCard.voucherEnabled ? "Đã bật: Voucher" : "Đã tắt: Voucher")
                                }
                            }
                        }

                        // Ngày hết hạn toàn cục
                        Rectangle {
                            Layout.fillWidth: true
                            height: expiryCol.implicitHeight + 32; radius: 8
                            color: "transparent"; border.color: "#2d5a8c"; border.width: 1

                            ColumnLayout {
                                id: expiryCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                                spacing: 8

                                Text { text: "Ngày hết hạn voucher (để trống = không hết hạn)"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text { text: "Áp dụng cho tất cả voucher. Định dạng: YYYY-MM-DD (ví dụ: 2026-12-31)"; color: root.mutedText(0.65); font.pixelSize: 11; wrapMode: Text.WordWrap; Layout.fillWidth: true }

                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    TextField {
                                        id: expiryField
                                        Layout.fillWidth: true; height: 44
                                        text: eventManager.getAppSetting("voucher_expiry_date", "")
                                        placeholderText: "YYYY-MM-DD"
                                        color: root.themeTextColor; font.pixelSize: 15; leftPadding: 12
                                        background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#4caf50" : Theme.border; radius: 6; height: 40 }
                                        onEditingFinished: {
                                            eventManager.setAppSetting("voucher_expiry_date", text.trim())
                                            autoSavedToast.show("Đã lưu ngày hết hạn voucher")
                                        }
                                    }
                                    Rectangle {
                                        width: 80; height: 44; radius: 6
                                        color: "transparent"
                                        border.color: "#5a3535"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 150 } }
                                        Text { anchors.centerIn: parent; text: "Xóa"; color: "#ef9a9a"; font.pixelSize: 14; font.bold: true }
                                        MouseArea {
                                            id: clearExpiryMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                expiryField.text = ""
                                                eventManager.setAppSetting("voucher_expiry_date", "")
                                                autoSavedToast.show("Đã xóa ngày hết hạn")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Custom Text section ──────────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: root.generalSectionTitle === "Nội dung hiển thị"

                        RowLayout { Layout.fillWidth: true; spacing: 10
                            Text { text: "Tuỳ chỉnh văn bản"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                            Rectangle { Layout.preferredWidth: 126; Layout.preferredHeight: 26; radius: 8; color: Theme.settingsCopperSoft
                                Text { anchors.centerIn: parent; text: "TOÀN HỆ THỐNG"; color: Theme.settingsCopper; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8 }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // Landing page touch text
                        Rectangle {
                            Layout.fillWidth: true
                            height: landingTextCol.implicitHeight + 32
                            radius: 8
                            color: "transparent"
                            border.color: "#2d5a8c"
                            border.width: 1

                            ColumnLayout {
                                id: landingTextCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                                spacing: 8

                                Text {
                                    text: "Văn bản màn hình chờ (Landing Page)"
                                    color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                }
                                Text {
                                    text: "Dòng chữ hiển thị khi chờ khách chạm màn hình để bắt đầu."
                                    color: root.mutedText(0.65); font.pixelSize: 13; wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    TextField {
                                        id: landingTextField
                                        Layout.fillWidth: true
                                        height: 44
                                        text: eventManager.getAppSetting("landing_touch_text", "CHẠM ĐỂ BẮT ĐẦU")
                                        placeholderText: "CHẠM ĐỂ BẮT ĐẦU"
                                        color: root.themeTextColor
                                        font.pixelSize: 15
                                        leftPadding: 12

                                        background: Rectangle {
                                            color: "transparent"
                                            radius: 8
                                            border.color: parent.activeFocus ? "#4FA4F2" : Theme.border
                                            border.width: parent.activeFocus ? 2 : 1
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    Rectangle {
                                        width: 80; height: 44; radius: 8
                                        color: landingSaveMa.containsMouse ? "#1a6fd0" : "#1e7eea"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: "Lưu"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Bold }
                                        MouseArea {
                                            id: landingSaveMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var val = landingTextField.text.trim()
                                                if (val === "") val = "CHẠM ĐỂ BẮT ĐẦU"
                                                eventManager.setAppSetting("landing_touch_text", val)
                                                autoSavedToast.show("Đã lưu văn bản Landing Page")
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Mode selection touch text
                        Rectangle {
                            Layout.fillWidth: true
                            height: modeTextCol.implicitHeight + 32
                            radius: 8
                            color: "transparent"
                            border.color: "#2d5a8c"
                            border.width: 1

                            ColumnLayout {
                                id: modeTextCol
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                                spacing: 8

                                Text {
                                    text: "Văn bản màn hình chụp (Mode Selection)"
                                    color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                }
                                Text {
                                    text: "Dòng chữ lớn hiển thị giữa màn hình khi khách chuẩn bị chụp."
                                    color: root.mutedText(0.65); font.pixelSize: 13; wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    TextField {
                                        id: modeTextField
                                        Layout.fillWidth: true
                                        height: 44
                                        text: eventManager.getAppSetting("mode_touch_text", "Chạm để chụp ảnh")
                                        placeholderText: "Chạm để chụp ảnh"
                                        color: root.themeTextColor
                                        font.pixelSize: 15
                                        leftPadding: 12

                                        background: Rectangle {
                                            color: "transparent"
                                            radius: 8
                                            border.color: parent.activeFocus ? "#4FA4F2" : Theme.border
                                            border.width: parent.activeFocus ? 2 : 1
                                            Behavior on border.color { ColorAnimation { duration: 150 } }
                                        }
                                    }

                                    Rectangle {
                                        width: 80; height: 44; radius: 8
                                        color: modeSaveMa.containsMouse ? "#1a6fd0" : "#1e7eea"
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: "Lưu"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Bold }
                                        MouseArea {
                                            id: modeSaveMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var val = modeTextField.text.trim()
                                                if (val === "") val = "Chạm để chụp ảnh"
                                                eventManager.setAppSetting("mode_touch_text", val)
                                                autoSavedToast.show("Đã lưu văn bản Mode Selection")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Video Settings section ────────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: root.generalSectionTitle === "Media đầu ra"

                        RowLayout { Layout.fillWidth: true; spacing: 10
                            Text { text: "Tạo video"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                            Rectangle { Layout.preferredWidth: 126; Layout.preferredHeight: 26; radius: 8; color: Theme.settingsCopperSoft
                                Text { anchors.centerIn: parent; text: "TOÀN HỆ THỐNG"; color: Theme.settingsCopper; font.pixelSize: 9; font.bold: true }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        // Toggle bật/tắt video
                        Rectangle {
                            id: videoEnabledCard
                            Layout.fillWidth: true
                            height: 80
                            radius: 8
                            border.width: 1

                            property bool videoOn: eventManager.getAppSetting("video_enabled", "true") === "true"

                            color: "transparent"
                            border.color: videoOn ? "#1e7eea" : "#2d5a8c"
                            Behavior on color { ColorAnimation { duration: 150 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Rectangle {
                                    implicitWidth: 48; implicitHeight: 26; radius: 13
                                    color: videoEnabledCard.videoOn ? "#1e7eea" : "#2d5a8c"
                                    Behavior on color { ColorAnimation { duration: 200 } }
                                    Rectangle {
                                        x: videoEnabledCard.videoOn ? parent.width - width - 2 : 2
                                        width: 22; height: 22; radius: 11; color: "#FFFFFF"
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 200 } }
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { text: "Tạo Video Sau Mỗi Phiên"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                    Text {
                                        text: "Tự động tạo video MP4 từ ảnh sau mỗi lần chụp."
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                                    }
                                }
                            }
                            MouseArea {
                                id: videoEnabledMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    videoEnabledCard.videoOn = !videoEnabledCard.videoOn
                                    eventManager.setAppSetting("video_enabled", videoEnabledCard.videoOn ? "true" : "false")
                                    autoSavedToast.show(videoEnabledCard.videoOn ? "Đã bật: Tạo Video" : "Đã tắt: Tạo Video")
                                }
                            }
                        }

                        // Chọn độ phân giải video (chỉ hiện khi bật)
                        Rectangle {
                            Layout.fillWidth: true
                            height: videoResContent.implicitHeight + 32
                            radius: 8
                            color: "transparent"
                            border.color: "#2d5a8c"; border.width: 1
                            visible: videoEnabledCard.videoOn
                            opacity: videoEnabledCard.videoOn ? 1.0 : 0.4
                            Behavior on opacity { NumberAnimation { duration: 150 } }

                            property string currentRes: eventManager.getAppSetting("video_resolution", "1920")

                            id: videoResCard

                            ColumnLayout {
                                id: videoResContent
                                anchors { left: parent.left; right: parent.right; top: parent.top }
                                anchors.margins: 16
                                spacing: 12

                                Text { text: "Độ Phân Giải Video (cạnh dài tối đa)"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                                Text {
                                    text: "Tối thiểu Full HD (1080p). Độ phân giải cao hơn = file nặng hơn."
                                    color: root.mutedText(0.65); font.pixelSize: 13
                                    wrapMode: Text.WordWrap; Layout.fillWidth: true
                                }

                                RowLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Repeater {
                                        model: [
                                            { label: "1080p\nFull HD",  value: "1920" },
                                            { label: "1440p\n2K",       value: "2560" },
                                            { label: "2160p\n4K",       value: "3840" }
                                        ]
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            height: 64
                                            radius: 8
                                            property bool isSelected: videoResCard.currentRes === modelData.value
                                            color: "transparent"
                                            border.color: isSelected ? "#1e7eea" : "#2d5a8c"
                                            border.width: isSelected ? 2 : 1
                                            Behavior on border.color { ColorAnimation { duration: 150 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.label
                                                color: isSelected ? Theme.settingsCopper : Theme.settingsText
                                                font.pixelSize: 13
                                                font.weight: isSelected ? Font.Bold : Font.Normal
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                            MouseArea {
                                                id: resMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    videoResCard.currentRes = modelData.value
                                                    eventManager.setAppSetting("video_resolution", modelData.value)
                                                    autoSavedToast.show("Độ phân giải video: " + modelData.label.replace("\n", " "))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ── Aspect Ratio section ───────────────────────────────────────────
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: root.generalSectionTitle === "Màn hình & bố cục" && root._operationMode === "modebao"

                        Text {
                            text: "Màn hình chế độ Báo"
                            color: root.themeTextColor
                            font.pixelSize: 20
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Chọn hướng hiển thị cho trang chào mừng, chọn khung và luồng chụp Báo."
                            color: root.mutedText(0.65)
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            id: paperOrientationCard
                            Layout.fillWidth: true
                            height: paperOrientationContent.implicitHeight + 32
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            property string currentOrientation: eventManager.getAppSetting("screen_orientation", "landscape")

                            function applyOrientation(orientation) {
                                currentOrientation = orientation === "portrait" ? "portrait" : "landscape"
                                var mainWin = root.Window.window
                                if (mainWin && typeof mainWin.applyOrientation === "function")
                                    mainWin.applyOrientation(currentOrientation)
                                else
                                    eventManager.setAppSetting("screen_orientation", currentOrientation)
                                autoSavedToast.show(currentOrientation === "portrait" ? "Chế độ Báo: màn hình dọc" : "Chế độ Báo: màn hình ngang")
                            }

                            RowLayout {
                                id: paperOrientationContent
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 16
                                spacing: 14

                                Rectangle {
                                    id: paperLandscapeBtn
                                    property bool selected: paperOrientationCard.currentOrientation === "landscape"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 84
                                    radius: 10
                                    color: "transparent"
                                    border.color: selected ? "#1e7eea" : "#2d5a8c"
                                    border.width: selected ? 2 : 1

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "▭ Ngang"
                                            color: paperLandscapeBtn.selected ? Theme.settingsCopper : Theme.settingsTextMuted
                                            font.pixelSize: 18
                                            font.bold: paperLandscapeBtn.selected
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: "1920 × 1080"
                                            color: paperLandscapeBtn.selected ? "#bce0ff" : root.mutedText(0.65)
                                            font.pixelSize: 13
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: paperOrientationCard.applyOrientation("landscape")
                                    }
                                }

                                Rectangle {
                                    id: paperPortraitBtn
                                    property bool selected: paperOrientationCard.currentOrientation === "portrait"
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 84
                                    radius: 10
                                    color: "transparent"
                                    border.color: selected ? "#1e7eea" : "#2d5a8c"
                                    border.width: selected ? 2 : 1

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        spacing: 4
                                        Text {
                                            text: "▯ Dọc"
                                            color: paperPortraitBtn.selected ? Theme.settingsCopper : Theme.settingsTextMuted
                                            font.pixelSize: 18
                                            font.bold: paperPortraitBtn.selected
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                        Text {
                                            text: "1080 × 1920"
                                            color: paperPortraitBtn.selected ? "#bce0ff" : root.mutedText(0.65)
                                            font.pixelSize: 13
                                            Layout.alignment: Qt.AlignHCenter
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: paperOrientationCard.applyOrientation("portrait")
                                    }
                                }
                            }
                        }
                    }
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        visible: root.generalSectionTitle === "Màn hình & bố cục"

                        // ── Ẩn nút điều khiển (⚙ / ✕) trên màn hình khách ──────────
                        Text { text: "Nút Điều Khiển"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }

                        SettingsToggleRow {
                            Layout.fillWidth: true
                            title: "Ẩn nút ⚙ và ✕ trên màn hình khách"
                            description: "Nút vẫn nằm nguyên vị trí cũ và vẫn bấm được — chỉ không còn nổi bật với khách."
                            checked: root._chromeHideMode !== "off"
                            accent: Theme.settingsCopper
                            onToggled: function(next) {
                                root._setChromeHideMode(next ? "dim" : "off")
                            }
                        }

                        // Mức ẩn — chỉ hiện khi đã bật
                        Rectangle {
                            Layout.fillWidth: true
                            visible: root._chromeHideMode !== "off"
                            height: chromeLevelRow.implicitHeight + 32
                            color: "transparent"
                            radius: 8
                            border.color: Theme.settingsBorder; border.width: 1

                            RowLayout {
                                id: chromeLevelRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 16
                                spacing: 14

                                Repeater {
                                    model: [
                                        { key: "dim",   label: "Mờ",        hint: "Còn thấy lờ mờ (25%). Bấm một chạm như thường." },
                                        { key: "ghost", label: "Tàng hình", hint: "Không thấy gì. Nút ✕ phải GIỮ 1 giây mới thoát." }
                                    ]
                                    delegate: Rectangle {
                                        id: chromeLevelCard
                                        required property var modelData
                                        readonly property bool selected: root._chromeHideMode === modelData.key
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 84
                                        radius: 10
                                        color: "transparent"
                                        border.color: selected ? Theme.settingsCopper : Theme.settingsBorder
                                        border.width: selected ? 2 : 1

                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            width: parent.width - 24
                                            spacing: 4
                                            Text {
                                                text: chromeLevelCard.modelData.label
                                                color: chromeLevelCard.selected ? Theme.settingsCopper : Theme.settingsTextMuted
                                                font.pixelSize: 18
                                                font.bold: chromeLevelCard.selected
                                                Layout.alignment: Qt.AlignHCenter
                                            }
                                            Text {
                                                text: chromeLevelCard.modelData.hint
                                                color: root.mutedText(0.65)
                                                font.pixelSize: 12
                                                wrapMode: Text.WordWrap
                                                horizontalAlignment: Text.AlignHCenter
                                                Layout.fillWidth: true
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root._setChromeHideMode(chromeLevelCard.modelData.key)
                                        }
                                    }
                                }
                            }
                        }

                        Text { text: "Tỷ Lệ Màn Hình"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                        Text {
                            text: "Áp dụng khi chạy cửa sổ. Fullscreen tự động dùng tỷ lệ màn hình thực tế."
                            color: root.mutedText(0.65); font.pixelSize: 13
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            id: aspectRatioCard
                            Layout.fillWidth: true
                            height: aspectRatioContent.implicitHeight + 32
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"; border.width: 1

                            // ── Internal state ──────────────────────────────────
                            property string currentRatio: eventManager.getAppSetting("screen_aspect_ratio", "auto")
                            property string currentOrientation: eventManager.getAppSetting("screen_orientation", "landscape")
                            readonly property bool isPortrait: currentOrientation === "portrait"

                            // True when the current saved ratio is NOT one of the presets
                            readonly property bool isCustomActive: !["auto","16:9","16:10","4:3","3:2","21:9"].includes(currentRatio)

                            // Helper: apply a ratio key to window + persist
                            function applyRatio(key) {
                                if (isPortrait)
                                    return
                                eventManager.setAppSetting("screen_aspect_ratio", key)
                                currentRatio = key
                                var mainWin = root.Window.window
                                if (mainWin && typeof mainWin.applyAspectRatio === "function")
                                    mainWin.applyAspectRatio(key)
                                console.log("Aspect ratio →", key)
                            }

                            function applyOrientation(orientation) {
                                currentOrientation = orientation === "portrait" ? "portrait" : "landscape"
                                var mainWin = root.Window.window
                                if (mainWin && typeof mainWin.applyOrientation === "function")
                                    mainWin.applyOrientation(currentOrientation)
                                else
                                    eventManager.setAppSetting("screen_orientation", currentOrientation)
                                console.log("Screen orientation ->", currentOrientation)
                            }

                            ColumnLayout {
                                id: aspectRatioContent
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                                spacing: 12

                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text { text: "Hướng màn hình"; color: root.themeTextColor; font.pixelSize: 15; font.bold: true }
                                        Text {
                                            text: "Dọc dùng canvas cố định 1080 × 1920; Ngang dùng các tỉ lệ bên dưới."
                                            color: root.mutedText(0.65); font.pixelSize: 11
                                            wrapMode: Text.WordWrap
                                            Layout.fillWidth: true
                                        }
                                    }

                                    Rectangle {
                                        id: landscapeOrientationBtn
                                        property bool sel: aspectRatioCard.currentOrientation === "landscape"
                                        width: 130; height: 44; radius: 8
                                        color: sel ? "#1e7eea" : "transparent"
                                        border.color: sel ? "#1e7eea" : "#2d5a8c"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 1
                                            Text { text: "⬜ Ngang"; color: landscapeOrientationBtn.sel ? "#fff" : root.mutedText(0.65); font.pixelSize: 14; font.bold: landscapeOrientationBtn.sel; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: "1920 × 1080"; color: landscapeOrientationBtn.sel ? "#bce0ff" : Theme.border; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: aspectRatioCard.applyOrientation("landscape")
                                        }
                                    }

                                    Rectangle {
                                        id: portraitOrientationBtn
                                        property bool sel: aspectRatioCard.currentOrientation === "portrait"
                                        width: 130; height: 44; radius: 8
                                        color: sel ? "#1e7eea" : "transparent"
                                        border.color: sel ? "#1e7eea" : "#2d5a8c"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 120 } }
                                        ColumnLayout {
                                            anchors.centerIn: parent; spacing: 1
                                            Text { text: "⬜ Dọc"; color: portraitOrientationBtn.sel ? "#fff" : root.mutedText(0.65); font.pixelSize: 14; font.bold: portraitOrientationBtn.sel; Layout.alignment: Qt.AlignHCenter }
                                            Text { text: "1080 × 1920"; color: portraitOrientationBtn.sel ? "#bce0ff" : Theme.border; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                                        }
                                        MouseArea {
                                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                            onClicked: aspectRatioCard.applyOrientation("portrait")
                                        }
                                    }
                                }

                                Text {
                                    visible: aspectRatioCard.isPortrait
                                    text: "Đang dùng màn hình dọc: các preset tỉ lệ bên dưới chỉ áp dụng cho màn hình ngang."
                                    color: "#f0c040"; font.pixelSize: 13
                                    wrapMode: Text.WordWrap
                                    Layout.fillWidth: true
                                }

                                // ── Preset buttons row ───────────────────────────
                                RowLayout {
                                    spacing: 12
                                    Layout.fillWidth: true
                                    enabled: !aspectRatioCard.isPortrait
                                    opacity: aspectRatioCard.isPortrait ? 0.45 : 1.0

                                    Repeater {
                                        model: [
                                            { label: "Auto",  key: "auto",  wr: 16, hr: 10 },
                                            { label: "16:9",  key: "16:9",  wr: 16, hr: 9  },
                                            { label: "16:10", key: "16:10", wr: 16, hr: 10 },
                                            { label: "4:3",   key: "4:3",   wr: 4,  hr: 3  },
                                            { label: "3:2",   key: "3:2",   wr: 3,  hr: 2  },
                                            { label: "21:9",  key: "21:9",  wr: 21, hr: 9  }
                                        ]

                                        delegate: Item {
                                            property bool isActive: aspectRatioCard.currentRatio === modelData.key

                                            Layout.preferredWidth: 110
                                            Layout.preferredHeight: 96

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 10
                                                color: "transparent"
                                                border.color: isActive ? "#1e7eea" : (ratioMouse.containsMouse ? Theme.border : Theme.field)
                                                border.width: isActive ? 2 : 1
                                                Behavior on color        { ColorAnimation { duration: 120 } }
                                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                                ColumnLayout {
                                                    anchors.centerIn: parent
                                                    spacing: 8

                                                    Item {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        Layout.preferredWidth: 60
                                                        Layout.preferredHeight: 36

                                                        Rectangle {
                                                            anchors.centerIn: parent
                                                            property real scaleW: 60 / modelData.wr
                                                            property real scaleH: 36 / modelData.hr
                                                            property real s: Math.min(scaleW, scaleH)
                                                            width:  modelData.wr * s
                                                            height: modelData.hr * s
                                                            radius: 3
                                                            color: isActive ? "#1e7eea" : "#2d5a8c"
                                                            Rectangle {
                                                                anchors.fill: parent; anchors.margins: 2
                                                                radius: 2
                                                                color: isActive ? "#2a5088" : "#14000000"
                                                            }
                                                            Text {
                                                                anchors.centerIn: parent
                                                                text: "✓"; color: root.themeTextColor
                                                                font.pixelSize: 13; font.bold: true
                                                                visible: isActive
                                                            }
                                                        }
                                                    }

                                                    Text {
                                                        Layout.alignment: Qt.AlignHCenter
                                                        text: modelData.label
                                                        color: isActive ? "#1e7eea" : root.mutedText(0.65)
                                                        font.pixelSize: 14; font.bold: isActive
                                                    }
                                                }

                                                MouseArea {
                                                    id: ratioMouse
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: aspectRatioCard.applyRatio(modelData.key)
                                                }
                                            }
                                        }
                                    } // Repeater presets

                                    // ── "Tùy Chỉnh" button ───────────────────────
                                    Item {
                                        property bool isActive: aspectRatioCard.isCustomActive
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 96

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: 10
                                            color: "transparent"
                                            border.color: parent.isActive ? "#1e7eea" : (customRatioMA.containsMouse ? Theme.border : Theme.field)
                                            border.width: parent.isActive ? 2 : 1
                                            Behavior on color        { ColorAnimation { duration: 120 } }
                                            Behavior on border.color { ColorAnimation { duration: 120 } }

                                            ColumnLayout {
                                                anchors.centerIn: parent
                                                spacing: 8

                                                // Preview: two overlapping rectangles suggesting a custom frame
                                                Item {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: 60
                                                    Layout.preferredHeight: 36
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: "⚙"
                                                        font.pixelSize: 24
                                                        color: parent.parent.parent.isActive ? "#1e7eea" : "#2d5a8c"
                                                    }
                                                }
                                                Text {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: aspectRatioCard.isCustomActive
                                                          ? aspectRatioCard.currentRatio
                                                          : "Tùy Chỉnh"
                                                    color: parent.parent.parent.isActive ? "#1e7eea" : root.mutedText(0.65)
                                                    font.pixelSize: 13
                                                    font.bold: parent.parent.parent.isActive
                                                }
                                            }

                                            MouseArea {
                                                id: customRatioMA
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                // Toggle input row visibility
                                                onClicked: customInputRow.visible = !customInputRow.visible
                                            }
                                        }
                                    } // Custom button

                                    Item { Layout.fillWidth: true }
                                } // RowLayout buttons

                                // ── Custom ratio input row ───────────────────────
                                // Shown when the user clicks "Tùy Chỉnh" or when a
                                // custom ratio is already active.
                                Rectangle {
                                    id: customInputRow
                                    Layout.fillWidth: true
                                    height: customInputInner.implicitHeight + 24
                                    visible: aspectRatioCard.isCustomActive && !aspectRatioCard.isPortrait
                                    color: "transparent"
                                    radius: 8
                                    border.color: "#2a3a50"; border.width: 1

                                    RowLayout {
                                        id: customInputInner
                                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
                                        spacing: 10

                                        Text { text: "Tỉ lệ tùy chỉnh:"; color: root.mutedText(0.65); font.pixelSize: 14 }

                                        // W field
                                        Rectangle {
                                            width: 80; height: 38; radius: 6
                                            color: "transparent"
                                            border.color: customWField.activeFocus ? "#1e7eea" : Theme.border
                                            border.width: customWField.activeFocus ? 2 : 1
                                            TextInput {
                                                id: customWField
                                                anchors.fill: parent; anchors.margins: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: root.themeTextColor; font.pixelSize: 15
                                                inputMethodHints: Qt.ImhDigitsOnly
                                                validator: IntValidator { bottom: 1; top: 9999 }
                                                // Pre-fill from current custom ratio
                                                text: {
                                                    if (!aspectRatioCard.isCustomActive) return ""
                                                    var p = aspectRatioCard.currentRatio.split(":")
                                                    return p.length === 2 ? p[0] : ""
                                                }
                                                onActiveFocusChanged: if (activeFocus) selectAll()
                                            }
                                        }

                                        Text { text: ":"; color: root.mutedText(0.65); font.pixelSize: 20; font.bold: true }

                                        // H field
                                        Rectangle {
                                            width: 80; height: 38; radius: 6
                                            color: "transparent"
                                            border.color: customHField.activeFocus ? "#1e7eea" : Theme.border
                                            border.width: customHField.activeFocus ? 2 : 1
                                            TextInput {
                                                id: customHField
                                                anchors.fill: parent; anchors.margins: 8
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: root.themeTextColor; font.pixelSize: 15
                                                inputMethodHints: Qt.ImhDigitsOnly
                                                validator: IntValidator { bottom: 1; top: 9999 }
                                                text: {
                                                    if (!aspectRatioCard.isCustomActive) return ""
                                                    var p = aspectRatioCard.currentRatio.split(":")
                                                    return p.length === 2 ? p[1] : ""
                                                }
                                                onActiveFocusChanged: if (activeFocus) selectAll()
                                            }
                                        }

                                        // Info: computed resolution preview
                                        Text {
                                            id: ratioPreviewText
                                            property int rw: parseInt(customWField.text) || 0
                                            property int rh: parseInt(customHField.text) || 0
                                            text: (rw > 0 && rh > 0)
                                                  ? "→ thiết kế 1920 × " + Math.round(1920 * rh / rw) + " px"
                                                  : "nhập chiều rộng : chiều cao"
                                            color: (rw > 0 && rh > 0) ? "#4fc3f7" : root.mutedText(0.65)
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                        }

                                        // Apply button
                                        Rectangle {
                                            id: applyCustomBtn
                                            width: 100; height: 38; radius: 8
                                            property bool canApply: (parseInt(customWField.text) > 0) && (parseInt(customHField.text) > 0)
                                            color: canApply ? (applyBtnMA.containsMouse ? "#2a8fff" : "#1e7eea") : "transparent"
                                            Behavior on color { ColorAnimation { duration: 100 } }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Áp dụng"
                                                color: applyCustomBtn.canApply ? "white" : root.mutedText(0.65)
                                                font.pixelSize: 14; font.bold: true
                                            }

                                            MouseArea {
                                                id: applyBtnMA
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: applyCustomBtn.canApply ? Qt.PointingHandCursor : Qt.ArrowCursor
                                                enabled: applyCustomBtn.canApply
                                                onClicked: {
                                                    var rw = parseInt(customWField.text)
                                                    var rh = parseInt(customHField.text)
                                                    if (rw > 0 && rh > 0) {
                                                        var key = rw + ":" + rh
                                                        aspectRatioCard.applyRatio(key)
                                                        customInputRow.visible = false
                                                    }
                                                }
                                            }
                                        }

                                        // Cancel button
                                        Rectangle {
                                            width: 80; height: 38; radius: 8
                                            color: "transparent"
                                            border.color: "#2d5a8c"; border.width: 1
                                            Text {
                                                anchors.centerIn: parent
                                                text: "Hủy"; color: root.mutedText(0.65)
                                                font.pixelSize: 14
                                            }
                                            MouseArea {
                                                id: cancelBtnMA
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: customInputRow.visible = false
                                            }
                                        }
                                    }
                                } // customInputRow

                                // ── Screen info readout ──────────────────────────
                                // Shows actual screen resolution + computed scale so
                                // the user knows what letterboxing will look like.
                                Text {
                                    property var mainWin: root.Window.window
                                    text: {
                                        if (!mainWin) return ""
                                        var sw = Screen.width; var sh = Screen.height
                                        var dw = mainWin._designW || 1920; var dh = mainWin._designH || 1080
                                        var sc = mainWin._contentScale || 1.0
                                        var pct = Math.round(sc * 100)
                                        return "Màn hình: " + sw + "×" + sh +
                                               "  |  Thiết kế: " + dw + "×" + dh +
                                               "  |  Tỉ lệ hiển thị: " + pct + "%"
                                               + (sc < 0.999 ? "  (có letterbox)" : "  (khít màn hình)")
                                    }
                                    color: "#5a8080"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                            } // ColumnLayout inside card
                        } // Card rect
                    } // Aspect ratio section

                    ColumnLayout {
                        spacing: 16
                        Layout.fillWidth: true
                        visible: root.generalSectionTitle === "Lưu trữ"

                        RowLayout { Layout.fillWidth: true; spacing: 10
                            Text { text: "Thư mục lưu"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                            Rectangle { Layout.preferredWidth: 88; Layout.preferredHeight: 26; radius: 8; color: "#F4EAF5"
                                Text { anchors.centerIn: parent; text: "SỰ KIỆN"; color: "#8B5F8E"; font.pixelSize: 9; font.bold: true }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "Ảnh Raw"; color: root.mutedText(0.65); font.pixelSize: 14 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                TextField {
                                    id: rawPathField
                                    text: root.eventData ? root.eventData.rawPath : ""
                                    Layout.fillWidth: true
                                    color: root.themeTextColor
                                    background: Rectangle { color: "transparent"; border.color: "#2d5a8c"; radius: 6; height: 40 }
                                    font.pixelSize: 14
                                    leftPadding: 12
                                    readOnly: true
                                }

                                Button {
                                    text: "Truy Cập..."
                                    background: Rectangle { color: "transparent"; radius: 6 }
                                    contentItem: Text { text: parent.text; color: root.themeTextColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    Layout.preferredHeight: 40
                                    onClicked: rawFolderDialog.open()
                                }
                            }

                            Platform.FolderDialog {
                                id: rawFolderDialog
                                title: "Chọn Thư Mục Ảnh Raw"
                                folder: rawPathField.text ? "file:///" + rawPathField.text : ""
                                onAccepted: {
                                    var path = folder.toString()
                                    if (Qt.platform.os === "windows") {
                                        path = path.replace(/^(file:\/{3})|(file:)/, "")
                                    } else {
                                        path = path.replace(/^(file:\/\/)/, "")
                                    }
                                    path = decodeURIComponent(path)

                                    if (root.eventData) {
                                        if (eventManager.updateEventPath(root.eventData.id, "rawPath", path)) {
                                            rawPathField.text = path
                                            var newData = root.eventData
                                            newData.rawPath = path
                                            root.eventData = newData
                                        }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "Ảnh Đã Xử Lý"; color: root.mutedText(0.65); font.pixelSize: 14 }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                TextField {
                                    id: finalPathField
                                    text: root.eventData ? root.eventData.finalPath : ""
                                    Layout.fillWidth: true
                                    color: root.themeTextColor
                                    background: Rectangle { color: "transparent"; border.color: "#2d5a8c"; radius: 6; height: 40 }
                                    font.pixelSize: 14
                                    leftPadding: 12
                                    readOnly: true
                                }

                                Button {
                                    text: "Truy Cập..."
                                    background: Rectangle { color: "transparent"; radius: 6 }
                                    contentItem: Text { text: parent.text; color: root.themeTextColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    Layout.preferredHeight: 40
                                    onClicked: finalFolderDialog.open()
                                }
                            }

                            Platform.FolderDialog {
                                id: finalFolderDialog
                                title: "Select Final Photos Folder"
                                currentFolder: finalPathField.text ? "file:///" + finalPathField.text : ""
                                onAccepted: {
                                    var path = selectedFolder.toString()
                                    if (Qt.platform.os === "windows") {
                                         path = path.replace(/^(file:\/{3})|(file:)/, "")
                                    } else {
                                         path = path.replace(/^(file:\/\/)/, "")
                                    }
                                    path = decodeURIComponent(path)

                                    if (root.eventData) {
                                        if (eventManager.updateEventPath(root.eventData.id, "finalPath", path)) {
                                            finalPathField.text = path
                                            var newData = root.eventData
                                            newData.finalPath = path
                                            root.eventData = newData
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        spacing: 16
                        Layout.fillWidth: true
                        visible: root.generalSectionTitle === "Nội dung hiển thị"

                        RowLayout { Layout.fillWidth: true; spacing: 10
                            Text { text: "Thông điệp sự kiện"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                            Rectangle { Layout.preferredWidth: 88; Layout.preferredHeight: 26; radius: 8; color: "#F4EAF5"
                                Text { anchors.centerIn: parent; text: "SỰ KIỆN"; color: "#8B5F8E"; font.pixelSize: 9; font.bold: true }
                            }
                            Item { Layout.fillWidth: true }
                        }

                        ColumnLayout {
                            spacing: 8
                            Layout.fillWidth: true
                            Text { text: "Thông điệp màn hình bắt đầu"; color: root.mutedText(0.65); font.pixelSize: 14 }

                            TextField {
                                id: startMsgField
                                text: root.eventData ? (root.eventData.startScreenMessage || "Tap screen to start") : "Tap screen to start"
                                Layout.fillWidth: true
                                color: root.themeTextColor
                                placeholderText: "Enter prompt message..."
                                placeholderTextColor: root.mutedText(0.65)
                                background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                                font.pixelSize: 15
                                leftPadding: 12

                                onEditingFinished: {
                                     if (root.eventData) {
                                        eventManager.updateEventPath(root.eventData.id, "startScreenMessage", text)
                                        autoSavedToast.show("Đã lưu tin nhắn màn hình")
                                     }
                                }
                            }

                            Text {
                                text: "This message appears when the booth is waiting for a guest."
                                color: root.mutedText(0.65)
                                font.pixelSize: 11
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; Layout.preferredHeight: 40 }
                }
            }
        }
    }

    Component {
        id: cameraTabComponent
        Item {
            ScrollView {
                anchors.fill: parent
                contentWidth: parent.width
                clip: true
                background: Item {}

                // Main Container for Cards
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 20

                    // ── NHÓM 1: Trạng thái kết nối (trên cùng) ──
                    StatusCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                    }

                    // ── NHÓM 2: Hiệu suất Live View (trái) + Chọn nguồn kết nối (phải) ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 20

                    ConfigSection {
                        title: "Hiệu suất Live View"
                        expanded: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        content: ColumnLayout {
                            spacing: 12
                            RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                ColumnLayout { Layout.fillWidth: true; spacing: 3
                                    Text { text: "Độ phân giải Live View"; color: Theme.settingsText; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Text { text: "Giảm độ phân giải để Live View mượt hơn trên máy yếu."; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                                }
                                ComboBox {
                                    id: cameraLiveQualityCombo
                                    Layout.preferredWidth: 250; Layout.preferredHeight: 44
                                    textRole: "text"; valueRole: "value"
                                    model: ListModel {
                                        ListElement { text: "Theo máy ảnh · Native"; value: "0" }
                                        ListElement { text: "Mượt · 640p"; value: "640" }
                                        ListElement { text: "Cân bằng · 960p"; value: "960" }
                                        ListElement { text: "Chất lượng cao · 1280p"; value: "1280" }
                                    }
                                    Component.onCompleted: {
                                        var saved = eventManager.getAppSetting("live_view_max_width", "0")
                                        for (var i = 0; i < model.count; ++i) if (model.get(i).value === saved) currentIndex = i
                                    }
                                    onActivated: {
                                        var value = model.get(currentIndex).value
                                        eventManager.setAppSetting("live_view_max_width", value)
                                        cameraController.setMaxLiveViewWidth(parseInt(value))
                                        autoSavedToast.show("Đã lưu độ phân giải Live View")
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.settingsBorder }
                            RowLayout {
                                Layout.fillWidth: true; spacing: 16
                                ColumnLayout { Layout.fillWidth: true; spacing: 3
                                    Text { text: "Giới hạn FPS"; color: Theme.settingsText; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Text { text: "Giảm FPS để tiết kiệm CPU; không ảnh hưởng ảnh chụp."; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                                }
                                ComboBox {
                                    id: cameraLiveFpsCombo
                                    Layout.preferredWidth: 250; Layout.preferredHeight: 44
                                    textRole: "text"; valueRole: "value"
                                    model: ListModel {
                                        ListElement { text: "Tối đa · 30 FPS"; value: "30" }
                                        ListElement { text: "Cân bằng · 20 FPS"; value: "20" }
                                        ListElement { text: "Tiết kiệm · 15 FPS"; value: "15" }
                                        ListElement { text: "Tối thiểu · 10 FPS"; value: "10" }
                                    }
                                    Component.onCompleted: {
                                        var saved = eventManager.getAppSetting("live_view_target_fps", "30")
                                        for (var i = 0; i < model.count; ++i) if (model.get(i).value === saved) currentIndex = i
                                    }
                                    onActivated: {
                                        var value = model.get(currentIndex).value
                                        eventManager.setAppSetting("live_view_target_fps", value)
                                        cameraController.setTargetLiveViewFps(parseInt(value))
                                        autoSavedToast.show("Đã lưu giới hạn FPS")
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.settingsBorder; visible: cameraController.cameraType === "Fuji" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                visible: cameraController.cameraType === "Fuji"

                                Text {
                                    text: "Fujifilm Live View"
                                    color: Theme.settingsText
                                    font.pixelSize: 15
                                    font.weight: Font.DemiBold
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Text { text: "Kích thước Live View Fuji"; color: Theme.settingsText; font.pixelSize: 14; font.weight: Font.Medium }
                                        Text { text: "Native giữ nguyên kích thước frame máy ảnh trả về, không ép size SDK."; color: Theme.settingsTextMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                                    }
                                    ComboBox {
                                        id: fujiLiveViewSizeCombo
                                        Layout.preferredWidth: 250; Layout.preferredHeight: 44
                                        textRole: "text"; valueRole: "value"
                                        model: ListModel {
                                            ListElement { text: "Theo máy ảnh / Native"; value: "auto" }
                                            ListElement { text: "L · SDK 1280"; value: "L" }
                                            ListElement { text: "M · SDK 800"; value: "M" }
                                            ListElement { text: "S · SDK 640"; value: "S" }
                                        }
                                        Component.onCompleted: {
                                            var saved = eventManager.getAppSetting("fuji_live_view_size", "auto")
                                            for (var i = 0; i < model.count; ++i) if (model.get(i).value === saved) currentIndex = i
                                        }
                                        onActivated: {
                                            var value = model.get(currentIndex).value
                                            var quality = eventManager.getAppSetting("fuji_live_view_quality", "fine")
                                            eventManager.setAppSetting("fuji_live_view_size", value)
                                            cameraController.setFujiLiveViewOptions(value, quality)
                                            autoSavedToast.show("Đã lưu kích thước Live View Fuji")
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 16
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3
                                        Text { text: "Chất lượng Live View Fuji"; color: Theme.settingsText; font.pixelSize: 14; font.weight: Font.Medium }
                                        Text { text: "Fine ưu tiên nét hơn; Normal/Basic dùng khi cần giảm tải USB/CPU."; color: Theme.settingsTextMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                                    }
                                    ComboBox {
                                        id: fujiLiveViewQualityCombo
                                        Layout.preferredWidth: 250; Layout.preferredHeight: 44
                                        textRole: "text"; valueRole: "value"
                                        model: ListModel {
                                            ListElement { text: "Fine"; value: "fine" }
                                            ListElement { text: "Normal"; value: "normal" }
                                            ListElement { text: "Basic"; value: "basic" }
                                        }
                                        Component.onCompleted: {
                                            var saved = eventManager.getAppSetting("fuji_live_view_quality", "fine")
                                            for (var i = 0; i < model.count; ++i) if (model.get(i).value === saved) currentIndex = i
                                        }
                                        onActivated: {
                                            var value = model.get(currentIndex).value
                                            var size = eventManager.getAppSetting("fuji_live_view_size", "auto")
                                            eventManager.setAppSetting("fuji_live_view_quality", value)
                                            cameraController.setFujiLiveViewOptions(size, value)
                                            autoSavedToast.show("Đã lưu chất lượng Live View Fuji")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Chọn nguồn kết nối (cột phải của NHÓM 2)
                    ConfigSection {
                        title: "Chọn nguồn kết nối"
                        expanded: true
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop

                        content: ColumnLayout {
                            spacing: 16

                            // Camera Source — choose Canon (EDSDK) or Sony (CRSDK)
                            RowLayout {
                                spacing: 12
                                Layout.fillWidth: true

                                Text {
                                    text: "Camera Source:"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 150
                                }

                                ComboBox {
                                    id: cameraTypeCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    model: ["Canon Camera (EDSDK)", "Sony Camera (CRSDK)", "Nikon Camera (MAID)", "Fujifilm Camera (X SDK)"]

                                    // Keep selection in sync with the persisted setting.
                                    currentIndex: cameraController.cameraType === "Sony" ? 1
                                                : cameraController.cameraType === "Nikon" ? 2
                                                : cameraController.cameraType === "Fuji" ? 3 : 0

                                    onActivated: {
                                        var brand = currentIndex === 1 ? "Sony"
                                                  : currentIndex === 2 ? "Nikon"
                                                  : currentIndex === 3 ? "Fuji" : "Canon"
                                        cameraController.switchCameraType(brand)

                                        // Hiện popup và chạy kết nối trên background thread
                                        // (không chặn UI dù camera không cắm vào)
                                        cameraSwitchPopup.switchTo(brand)
                                    }

                                    background: Rectangle {
                                        color: "transparent"
                                        border.color: "#2d5a8c"
                                        border.width: 1
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        leftPadding: 12
                                        text: cameraTypeCombo.displayText
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    delegate: ItemDelegate {
                                        width: cameraTypeCombo.width
                                        contentItem: Text {
                                            text: modelData
                                            color: root.themeTextColor
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        highlighted: cameraTypeCombo.highlightedIndex === index
                                        background: Rectangle {
                                            color: highlighted ? "#1e7eea" : "transparent"
                                        }
                                    }
                                }

                                Button {
                                    text: cameraController.isConnecting
                                          ? "Connecting..."
                                          : (cameraController.isConnected ? "Reconnect" : "Connect")
                                    Layout.preferredWidth: 110
                                    Layout.preferredHeight: 44
                                    enabled: !cameraController.isConnecting
                                    onClicked: {
                                        cameraController.connectAsync()
                                    }
                                    background: Rectangle {
                                        color: !parent.enabled ? "#334155"
                                             : parent.hovered ? "#2a8bff" : "#1e7eea"
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            Text {
                                visible: cameraController.isConnecting
                                text: "Dang ket noi. Van co the doi Camera Source; he thong se tu ket noi lai bang nguon moi nhat."
                                color: "#fbbf24"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            // Camera model info row
                            RowLayout {
                                spacing: 12
                                Layout.fillWidth: true
                                visible: cameraController.cameraModel !== ""

                                Text {
                                    text: "Model:"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 150
                                }

                                Text {
                                    text: cameraController.cameraModel
                                    color: "#4ade80"
                                    font.pixelSize: 14
                                }
                            }

                            // Status Indicator
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                color: "transparent"
                                border.color: "transparent"
                                border.width: 1
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Rectangle {
                                        width: 10
                                        height: 10
                                        radius: 5
                                        color: cameraController.isLiveViewActive ? "#4ade80" : root.mutedText(0.65)
                                    }

                                    Text {
                                        text: cameraController.isLiveViewActive
                                            ? "Live view active (" + (cameraController.cameraType === "Sony" ? "Sony CRSDK" : cameraController.cameraType === "Nikon" ? "Nikon MAID" : cameraController.cameraType === "Fuji" ? "Fuji X SDK" : "Canon EDSDK") + ")"
                                            : "Live view inactive"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 14
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: cameraController.liveViewFps + " FPS"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 14
                                        visible: cameraController.isLiveViewActive
                                    }
                                }
                            }

                            // Info notice for Canon camera mode
                            Rectangle {
                                Layout.fillWidth: true
                                height: 50
                                color: "transparent"
                                border.color: "#1e7eea"
                                border.width: 1
                                radius: 4

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 12
                                    spacing: 10

                                    Text {
                                        text: "ℹ"
                                        color: "#60a5fa"
                                        font.pixelSize: 18
                                    }

                                    Text {
                                        text: cameraController.cameraType === "Sony"
                                            ? "Sony camera controlled via Camera Remote SDK. Connect via USB, then press Connect."
                                            : cameraController.cameraType === "Nikon"
                                            ? "Nikon camera controlled via MAID SDK. Connect via USB, then press Connect."
                                            : cameraController.cameraType === "Fuji"
                                            ? "Fujifilm camera controlled via X SDK. Connect via USB, then press Connect."
                                            : "Canon camera controlled via EDSDK. Connect via USB, then press Connect."
                                        color: "#93c5fd"
                                        font.pixelSize: 13
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            // ── Live View Source ──────────────────────────────
                            RowLayout {
                                spacing: 12
                                Layout.fillWidth: true

                                Text {
                                    text: "Nguồn Live View:"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 150
                                }

                                ComboBox {
                                    id: liveViewSourceCombo
                                    Layout.preferredWidth: 220
                                    Layout.preferredHeight: 44
                                    model: ["SDK Camera", "HDMI / Webcam"]
                                    currentIndex: cameraController.useWebcamLiveView ? 1 : 0

                                    onActivated: {
                                        var useWebcam = (currentIndex === 1)
                                        cameraController.setUseWebcamLiveView(useWebcam)
                                    }

                                    background: Rectangle {
                                        color: "transparent"
                                        border.color: "#2d5a8c"
                                        border.width: 1
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        leftPadding: 12
                                        text: liveViewSourceCombo.displayText
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    delegate: ItemDelegate {
                                        width: liveViewSourceCombo.width
                                        contentItem: Text {
                                            text: modelData
                                            color: root.themeTextColor
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        highlighted: liveViewSourceCombo.highlightedIndex === index
                                        background: Rectangle {
                                            color: highlighted ? "#1e7eea" : "transparent"
                                        }
                                    }
                                }

                                Text {
                                    text: "Chọn HDMI để dùng webcam/capture card thay vì SDK"
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }
                            }

                            // ── Chọn Webcam (chỉ hiện khi HDMI mode) ──────────
                            RowLayout {
                                visible: liveViewSourceCombo.currentIndex === 1
                                spacing: 12
                                Layout.fillWidth: true

                                Text {
                                    text: "Webcam:"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 150
                                }

                                Button {
                                    text: cameraController.webcamScanning ? "Đang quét..." : "Scan"
                                    enabled: !cameraController.webcamScanning
                                    Layout.preferredWidth: 80
                                    Layout.preferredHeight: 44
                                    onClicked: cameraController.scanWebcams()
                                    background: Rectangle {
                                        color: parent.hovered ? "#2a8bff" : "#1e7eea"
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                ComboBox {
                                    id: webcamCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    property bool scanned: false
                                    enabled: !cameraController.webcamScanning
                                    model: cameraController.webcamScanning ? ["Đang quét..."]
                                         : cameraController.webcamList.length > 0 ? cameraController.webcamList
                                         : [scanned ? "Không tìm thấy webcam" : "Nhấn Scan để tìm webcam"]
                                    // Danh sách chỉ gồm thiết bị đọc được → vị trí ≠ index thiết bị.
                                    currentIndex: {
                                        cameraController.webcamList
                                        return Math.max(0, cameraController.webcamListIndexOf(
                                                               cameraController.selectedWebcamIndex))
                                    }

                                    Connections {
                                        target: cameraController
                                        function onWebcamScanFinished(count) { webcamCombo.scanned = true }
                                    }

                                    onActivated: function(index) {
                                        var device = cameraController.webcamDeviceAt(index)
                                        if (device >= 0)
                                            cameraController.startWebcamLiveView(device)
                                    }

                                    background: Rectangle {
                                        color: "transparent"
                                        border.color: "#2d5a8c"
                                        border.width: 1
                                        radius: 4
                                    }
                                    contentItem: Text {
                                        leftPadding: 12
                                        text: webcamCombo.displayText
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                    delegate: ItemDelegate {
                                        width: webcamCombo.width
                                        contentItem: Text {
                                            text: modelData
                                            color: root.themeTextColor
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        highlighted: webcamCombo.highlightedIndex === index
                                        background: Rectangle {
                                            color: highlighted ? "#1e7eea" : "transparent"
                                        }
                                    }
                                }
                            }

                            // Mirror Mode Toggle
                            RowLayout {
                                spacing: 12
                                Layout.fillWidth: true

                                Text {
                                    text: "Lật ngang (Mirror):"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 150
                                }

                                Switch {
                                    id: mirrorSwitch
                                    checked: cameraController.mirrorMode

                                    Component.onCompleted: {
                                        var saved = eventManager.getAppSetting("mirror_mode", "true")
                                        var enabled = (saved === "true")
                                        cameraController.setMirrorMode(enabled)
                                    }

                                    indicator: Rectangle {
                                        implicitWidth: 48
                                        implicitHeight: 26
                                        x: mirrorSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 13
                                        color: mirrorSwitch.checked ? "#1e7eea" : "#2d5a8c"
                                        border.color: mirrorSwitch.checked ? "#1e7eea" : "#2d5a8c"

                                        Rectangle {
                                            x: mirrorSwitch.checked ? parent.width - width - 2 : 2
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Behavior on x {
                                                NumberAnimation { duration: 200 }
                                            }
                                        }
                                    }

                                    contentItem: Text {
                                        text: mirrorSwitch.checked ? "On" : "Off"
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: mirrorSwitch.indicator.width + mirrorSwitch.spacing
                                    }

                                    onToggled: {
                                        cameraController.setMirrorMode(checked)
                                        eventManager.setAppSetting("mirror_mode", checked ? "true" : "false")
                                    }
                                }

                                Text {
                                    text: "Live view và ảnh chụp sẽ được lật ngang"
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }
                            }

                            // Live View Background Toggle
                            RowLayout {
                                spacing: 12
                                Layout.fillWidth: true

                                Text {
                                    text: "Live View Background:"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    Layout.preferredWidth: 150
                                }

                                Switch {
                                    id: liveViewBgSwitch
                                    // Machine-global: live view nền dùng ở màn Landing (trước khi chọn
                                    // sự kiện) nên KHÔNG lưu per-event. Mặc định BẬT.
                                    checked: eventManager.getAppSetting("landing_liveview_enabled", "true") === "true"

                                    indicator: Rectangle {
                                        implicitWidth: 48
                                        implicitHeight: 26
                                        x: liveViewBgSwitch.leftPadding
                                        y: parent.height / 2 - height / 2
                                        radius: 13
                                        color: liveViewBgSwitch.checked ? "#1e7eea" : "#2d5a8c"
                                        border.color: liveViewBgSwitch.checked ? "#1e7eea" : "#2d5a8c"

                                        Rectangle {
                                            x: liveViewBgSwitch.checked ? parent.width - width - 2 : 2
                                            width: 22
                                            height: 22
                                            radius: 11
                                            color: "transparent"
                                            anchors.verticalCenter: parent.verticalCenter

                                            Behavior on x {
                                                NumberAnimation { duration: 200 }
                                            }
                                        }
                                    }

                                    contentItem: Text {
                                        text: liveViewBgSwitch.checked ? "On" : "Off"
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                        leftPadding: liveViewBgSwitch.indicator.width + liveViewBgSwitch.spacing
                                    }

                                    onToggled: {
                                        // Lưu machine-global (key nằm trong kMachineGlobalKeys của
                                        // EventManager) → toggle và LandingPage dùng chung một giá trị.
                                        eventManager.setAppSetting("landing_liveview_enabled",
                                                                   checked ? "true" : "false")
                                    }
                                }

                                Text {
                                    text: "Live view sẽ hiển thị làm nền ở màn hình chờ (Landing)"
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                    }

                    // ── NHÓM 3: Hàng điều khiển thông số máy ảnh (ngang) ──
                    ExposureCard {
                        Layout.fillWidth: true
                    }

                    // ── NHÓM 4: Xem trước Live View (16:9) — dưới cùng ──
                    LiveViewCard {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 480
                        eventData: root.eventData
                    }

                }
            }
        }
    }

    Component {
        id: captureTabComponent
        Item {
            ScrollView {
                id: captureScroll
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: Math.min(captureScroll.availableWidth, 1200)
                    spacing: 20

                    CaptureSettingsCard {
                        Layout.fillWidth: true
                        eventData: root.eventData
                    }
                }
            }
        }
    }

    Component {
        id: printerTabComponent
        Item {
            id: printerTabRoot
            // Use printerConfig from context property
            // (registered in main.cpp)
            property bool _switchingPrinter: false

            Component.onCompleted: {
                // Load danh sach may in async khi tab mo - khong block UI
                printerManager.refreshPrinterListAsync()
            }

            Connections {
                target: printerManager
                function onPrinterListReady(printers) {
                    var idx = printers.indexOf(printerConfig.selectedPrinter)
                    printerComboBox.model = printers
                    printerComboBox.currentIndex = idx >= 0 ? idx : 0
                    // In tự do dùng chung danh sách máy in nhưng chọn độc lập.
                    freePrintCombo.model = printers
                    var fp = eventManager.getAppSetting("free_print_printer", "")
                    var fpIdx = printers.indexOf(fp)
                    freePrintCombo.currentIndex = fpIdx
                }
                function onPrinterSwitchStarted() { printerTabRoot._switchingPrinter = true }
                function onPrinterSwitchFinished(success, message) {
                    printerTabRoot._switchingPrinter = false
                    autoSavedToast.show((success ? "✓ " : "⚠ ") + message)
                }
                function onReconnectStarted()  { printerTabRoot._switchingPrinter = true }
                function onReconnectFinished(success, port) {
                    printerTabRoot._switchingPrinter = false
                    autoSavedToast.show(success ? "✓ Đã kết nối lại qua " + port
                                                 : "✗ Không tìm thấy máy in")
                }
            }

            Connections {
                target: printerConfig
                // Lưu cấu hình máy in riêng cho sự kiện đang mở (event_id). Sự kiện
                // chưa tuỳ chỉnh sẽ fallback về cấu hình global khi nạp (PrinterConfig).
                function _evId() { return root.eventData ? root.eventData.id : -1 }
                function onSelectedPrinterChanged() { printerConfig.saveToDatabase(_evId()); autoSavedToast.show("Đã lưu: Máy in") }
                function onResolutionChanged()      { printerConfig.saveToDatabase(_evId()); autoSavedToast.show("Đã lưu: Độ phân giải") }
                function onPrintModeChanged()       { printerConfig.saveToDatabase(_evId()); autoSavedToast.show("Đã lưu: Chế độ in") }
                function onCutModeChanged()         { printerConfig.saveToDatabase(_evId()); autoSavedToast.show("Đã lưu: Chế độ cắt") }
                function onPrintCopiesChanged()     { printerConfig.saveToDatabase(_evId()); autoSavedToast.show("Đã lưu: Số bản in") }
            }

            ScrollView {
                anchors.fill: parent
                contentWidth: parent.width
                clip: true

                ColumnLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 20
                    width: parent.width - 40
                    spacing: 20

                    // ===== HEADER SECTION =====
                    ColumnLayout {
                        spacing: 6
                        Layout.fillWidth: true

                        Text {
                            text: "Cài đặt máy in"
                            color: root.themeTextColor
                            font.pixelSize: 32
                            font.weight: Font.Bold
                        }

                        Text {
                            text: "Kết nối: " + (printerConfig.selectedPrinter || "DNP DS-RX1")
                            color: root.mutedText(0.65)
                            font.pixelSize: 15
                        }
                    }

                    // Lưới các nhóm cài đặt máy in (2 cột, tự thu về 1 cột khi hẹp)
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width > 820 ? 2 : 1
                        columnSpacing: 20
                        rowSpacing: 20

                    // ╔════ NHÓM: KẾT NỐI & THIẾT BỊ ════╗
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        color: "transparent"
                        radius: 10
                        border.color: "#2d5a8c"
                        border.width: 1
                        implicitHeight: grpConnCol.implicitHeight + 40

                        ColumnLayout {
                            id: grpConnCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 18

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: "Kết nối & Thiết bị"; color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold }
                                Text { text: "Trạng thái, chọn máy in và thông tin thiết bị"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2d5a8c"; opacity: 0.5 }

                    // ===== CONNECTION STATUS CARD (Compact) =====
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 72
                        color: "transparent"
                        radius: 8
                        border.color: printerManager.isConnected ? "#4caf50" : "#ff6b6b"
                        border.width: 2

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 12

                            Rectangle {
                                width: 12
                                height: 12
                                radius: 6
                                color: printerManager.isConnected ? "#4caf50" : "#ff6b6b"

                                SequentialAnimation on color {
                                    running: printerManager.isConnected === false
                                    loops: Animation.Infinite

                                    ColorAnimation {
                                        from: "#ff6b6b"
                                        to: "#ff9999"
                                        duration: 600
                                    }
                                    ColorAnimation {
                                        from: "#ff9999"
                                        to: "#ff6b6b"
                                        duration: 600
                                    }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2

                                Text {
                                    text: printerManager.isConnected ? "✓ Đã kết nối" : "✗ Chưa kết nối"
                                    color: printerManager.isConnected ? "#4caf50" : "#ff6b6b"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }

                                Text {
                                    text: printerManager.status
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 13
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Button {
                                text: "🔄"
                                Layout.preferredHeight: 40
                                Layout.preferredWidth: 40

                                background: Rectangle {
                                    color: parent.hovered ? "#2a4a7a" : "#1e3a5a"
                                    radius: 6
                                    border.color: "#2d5a8c"
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: root.themeTextColor
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 18
                                }

                                onClicked: {
                                    printerManager.reconnect()
                                }
                            }
                        }
                    }

                    // ===== PRINTER SELECTION CARD =====
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: "Chọn máy in"
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "Chọn driver máy in"
                                color: root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: printerSelectLayout.implicitHeight + 32
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            RowLayout {
                                id: printerSelectLayout
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                spacing: 12

                                ComboBox {
                                    id: printerComboBox
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 44
                                    // Model khởi tạo rỗng — được điền từ onPrinterListReady
                                    model: []
                                    enabled: !printerTabRoot._switchingPrinter

                                    background: Rectangle {
                                        color: "transparent"
                                        border.color: "#2d5a8c"
                                        radius: 6
                                        opacity: printerComboBox.enabled ? 1.0 : 0.5
                                    }

                                    contentItem: Text {
                                        text: printerComboBox.count > 0
                                              ? printerComboBox.displayText
                                              : "Đang tải..."
                                        color: root.themeTextColor
                                        leftPadding: 12
                                        font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    onActivated: {
                                        // Dùng onActivated (user thực sự chọn) thay vì onCurrentTextChanged
                                        // để tránh trigger khi model được update từ signal
                                        var name = currentText
                                        if (name && name !== printerConfig.selectedPrinter) {
                                            printerManager.switchPrinterAsync(name)
                                        }
                                    }
                                }

                                Button {
                                    id: refreshPrinterBtn
                                    text: "🔄 Làm mới"
                                    Layout.preferredHeight: 44
                                    Layout.preferredWidth: 120

                                    // Lấy _switchingPrinter từ tổ tiên Item
                                    property bool _busy: false
                                    Connections {
                                        target: printerManager
                                        function onPrinterListReady() { refreshPrinterBtn._busy = false }
                                    }

                                    background: Rectangle {
                                        color: parent.hovered ? "#2a4a7a" : "#1e3a5a"
                                        radius: 6
                                        border.color: "#2d5a8c"
                                        opacity: refreshPrinterBtn._busy ? 0.5 : 1.0
                                    }

                                    contentItem: Text {
                                        text: refreshPrinterBtn._busy ? "..." : parent.text
                                        color: root.themeTextColor
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                    }

                                    onClicked: {
                                        if (!_busy) {
                                            _busy = true
                                            printerManager.refreshPrinterListAsync()
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ===== PRINTER INFORMATION CARD =====
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: "Thông tin máy in"
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "Thông số kỹ thuật và trạng thái"
                                color: root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: infoGrid.implicitHeight + 40
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            GridLayout {
                                id: infoGrid
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 20
                                columns: 2
                                columnSpacing: 40
                                rowSpacing: 16

                                Text { text: "Model:"; color: root.mutedText(0.65); font.pixelSize: 14; font.weight: Font.Medium }
                                Text { text: "DNP DS-RX1"; color: root.themeTextColor; font.pixelSize: 14; font.weight: Font.Medium }

                                Text { text: "Firmware:"; color: root.mutedText(0.65); font.pixelSize: 14; font.weight: Font.Medium }
                                Text { text: printerManager.getFirmwareVersion(); color: root.themeTextColor; font.pixelSize: 14 }

                                Text { text: "Serial Number:"; color: root.mutedText(0.65); font.pixelSize: 14; font.weight: Font.Medium }
                                Text { text: printerManager.getSerialNumber(); color: root.themeTextColor; font.pixelSize: 14 }

                                Text { text: "Connection Type:"; color: root.mutedText(0.65); font.pixelSize: 14; font.weight: Font.Medium }
                                Text { text: printerManager.isConnected ? "USB Connected" : "Disconnected"; color: printerManager.isConnected ? "#4caf50" : "#ff6b6b"; font.pixelSize: 14; font.weight: Font.Medium }
                            }
                        }
                    }

                        }
                    }
                    // ╚════ /NHÓM ════╝

                    // ╔════ NHÓM: CHẤT LƯỢNG IN ════╗
                    Rectangle {
                        Layout.fillWidth: true
                        color: "transparent"
                        radius: 10
                        border.color: "#2d5a8c"
                        border.width: 1
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: grpQualityCol.implicitHeight + 40

                        ColumnLayout {
                            id: grpQualityCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 18

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: "Chất lượng in"; color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold }
                                Text { text: "Độ phân giải và chế độ màu khi in"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2d5a8c"; opacity: 0.5 }

                    // ===== TECHNICAL SPECIFICATIONS CARD =====
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: "Cài đặt kỹ thuật"
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "CHẤT LƯỢNG IN VÀ ĐỘ PHÂN GIẢI"
                                color: root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: techCol.implicitHeight + 40
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            ColumnLayout {
                                id: techCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 20
                                spacing: 20

                                // Row 1: Resolution
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: "ĐỘ PHÂN GIẢI (DPI)"
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    ComboBox {
                                        id: resolutionComboBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        model: ["300dpi - Standard (591×1772 / 1181×1772 / 1772×1181)", "600dpi - High (1181×3543 / 2362×3543 / 3543×2362)"]
                                        currentIndex: {
                                            var res = printerConfig.resolution
                                            if (res === "300dpi") return 0
                                            if (res === "600dpi") return 1
                                            return 1
                                        }

                                        background: Rectangle {
                                            color: "transparent"
                                            border.color: "#2d5a8c"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: resolutionComboBox.displayText
                                            color: root.themeTextColor
                                            leftPadding: 12
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onCurrentTextChanged: {
                                            if (currentText) {
                                                // Extract DPI value
                                                var dpi = currentText.split("dpi")[0].trim() + "dpi"
                                                console.log("=========================================")
                                                console.log("[SettingsPage] DPI ComboBox text changed")
                                                console.log("[SettingsPage] Current text:", currentText)
                                                console.log("[SettingsPage] Extracted DPI:", dpi)
                                                console.log("[SettingsPage] Setting printerConfig.resolution to:", dpi)
                                                console.log("=========================================")
                                                printerConfig.resolution = dpi
                                            }
                                        }
                                    }

                                    Text {
                                        text: "Các khung hình sẽ được tự động điều chỉnh"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 11
                                    }
                                }

                                // Divider
                                Rectangle {
                                    height: 1
                                    Layout.fillWidth: true
                                    color: "transparent"
                                }

                                // Row 2: Print Mode
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Chế độ in"
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    ComboBox {
                                        id: printModeComboBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        model: ["Color - Full RGB Output", "Black & White - Grayscale"]
                                        currentIndex: model.indexOf(printerConfig.printMode) >= 0 ? model.indexOf(printerConfig.printMode) : 0

                                        background: Rectangle {
                                            color: "transparent"
                                            border.color: "#2d5a8c"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: printModeComboBox.displayText
                                            color: root.themeTextColor
                                            leftPadding: 12
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onCurrentTextChanged: {
                                            if (currentText) {
                                                var mode = currentText.indexOf("Color") === 0 ? "Color" : "BlackWhite"
                                                printerConfig.printMode = mode
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                        }
                    }
                    // ╚════ /NHÓM ════╝

                    // ╔════ NHÓM: GIẤY & ĐẦU RA ════╗
                    Rectangle {
                        Layout.fillWidth: true
                        color: "transparent"
                        radius: 10
                        border.color: "#2d5a8c"
                        border.width: 1
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: grpPaperCol.implicitHeight + 40

                        ColumnLayout {
                            id: grpPaperCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 18

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: "Giấy & Đầu ra"; color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold }
                                Text { text: "Khổ giấy, chế độ cắt và số bản in"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2d5a8c"; opacity: 0.5 }

                    // ===== COPY COUNTER CARD (with Stepper) =====
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: "Số bản in"
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "Điều chỉnh số bản in"
                                color: root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 80
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 20

                                // Minus Button
                                Button {
                                    text: "−"
                                    Layout.preferredHeight: 48
                                    Layout.preferredWidth: 48
                                    enabled: copiesSpinBox.value > 1

                                    background: Rectangle {
                                        color: parent.enabled ? (parent.hovered ? "#2a4a7a" : "#1e3a5a") : Theme.field
                                        radius: 8
                                        border.color: "#2d5a8c"
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.enabled ? "#ffffff" : root.mutedText(0.65)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 24
                                        font.weight: Font.Bold
                                    }

                                    onClicked: if (copiesSpinBox.value > 1) copiesSpinBox.value--
                                }

                                // Display Value
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 48
                                    color: "transparent"
                                    radius: 8
                                    border.color: "#2d5a8c"

                                    Text {
                                        anchors.centerIn: parent
                                        text: copiesSpinBox.value + " Copies"
                                        color: root.themeTextColor
                                        font.pixelSize: 18
                                        font.weight: Font.Bold
                                    }
                                }

                                // Plus Button
                                Button {
                                    text: "+"
                                    Layout.preferredHeight: 48
                                    Layout.preferredWidth: 48
                                    enabled: copiesSpinBox.value < 10

                                    background: Rectangle {
                                        color: parent.enabled ? (parent.hovered ? "#2a4a7a" : "#1e3a5a") : Theme.field
                                        radius: 8
                                        border.color: "#2d5a8c"
                                    }

                                    contentItem: Text {
                                        text: parent.text
                                        color: parent.enabled ? "#ffffff" : root.mutedText(0.65)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                        font.pixelSize: 24
                                        font.weight: Font.Bold
                                    }

                                    onClicked: if (copiesSpinBox.value < 10) copiesSpinBox.value++
                                }

                                SpinBox {
                                    id: copiesSpinBox
                                    from: 1
                                    to: 10
                                    value: printerConfig.printCopies
                                    visible: false

                                    onValueChanged: {
                                        printerConfig.printCopies = value
                                    }
                                }
                            }
                        }
                    }

                    // ===== PAPER SETTINGS CARD =====
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true

                        ColumnLayout {
                            spacing: 2
                            Layout.fillWidth: true

                            Text {
                                text: "Cấu hình giấy"
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "Chọn kích thước giấy"
                                color: root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: paperCol.implicitHeight + 40
                            color: "transparent"
                            radius: 8
                            border.color: "#2d5a8c"
                            border.width: 1

                            ColumnLayout {
                                id: paperCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.margins: 20
                                spacing: 20

                                // Paper Size
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Kích Thước"
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    ComboBox {
                                        id: paperSizeComboBox
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        model: ["6x4 inch (PC)", "6x8 inch (A5)", "5x7 inch (2L)", "5x3.5 inch (L)"]
                                        currentIndex: 0

                                        background: Rectangle {
                                            color: "transparent"
                                            border.color: "#2d5a8c"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: paperSizeComboBox.displayText
                                            color: root.themeTextColor
                                            leftPadding: 12
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // Divider
                                Rectangle {
                                    height: 1
                                    Layout.fillWidth: true
                                    color: "transparent"
                                }

                                // Cutting Mode Toggle
                                ColumnLayout {
                                    spacing: 8
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Chế độ cắt"
                                        color: root.themeTextColor
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 50
                                        color: "transparent"
                                        radius: 8
                                        border.color: cutModeCheck.checked ? "#1e7eea" : "#2d5a8c"
                                        border.width: 2

                                        RowLayout {
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 12

                                            CheckBox {
                                                id: cutModeCheck
                                                checked: printerConfig.cutMode

                                                indicator: Rectangle {
                                                    implicitWidth: 22
                                                    implicitHeight: 22
                                                    radius: 4
                                                    color: cutModeCheck.checked ? "#1e7eea" : "transparent"
                                                    border.color: cutModeCheck.checked ? "#1e7eea" : root.mutedText(0.65)
                                                    border.width: 2

                                                    Text {
                                                        visible: cutModeCheck.checked
                                                        text: "✓"
                                                        color: root.themeTextColor
                                                        anchors.centerIn: parent
                                                        font.pixelSize: 15
                                                        font.weight: Font.Bold
                                                    }
                                                }

                                                onCheckedChanged: {
                                                    printerConfig.cutMode = checked
                                                }
                                            }

                                            ColumnLayout {
                                                Layout.fillWidth: true
                                                spacing: 1

                                                Text {
                                                    text: cutModeCheck.checked ? "Chế độ cắt" : "Không cắt"
                                                    color: root.themeTextColor
                                                    font.pixelSize: 14
                                                    font.weight: Font.Medium
                                                }

                                                Text {
                                                    text: cutModeCheck.checked ? "Cắt đôi ảnh" : "In toàn bộ ảnh"
                                                    color: root.mutedText(0.65)
                                                    font.pixelSize: 11
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                        }
                    }
                    // ╚════ /NHÓM ════╝

                    // ╔════ NHÓM: HÀNH ĐỘNG ════╗
                    Rectangle {
                        Layout.fillWidth: true
                        color: "transparent"
                        radius: 10
                        border.color: "#2d5a8c"
                        border.width: 1
                        Layout.alignment: Qt.AlignTop
                        implicitHeight: grpActionCol.implicitHeight + 40

                        ColumnLayout {
                            id: grpActionCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 18

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: "Hành động"; color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold }
                                Text { text: "In thử và công cụ nâng cao"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2d5a8c"; opacity: 0.5 }

                    // ===== ACTION BUTTONS SECTION =====
                    ColumnLayout {
                        spacing: 12
                        Layout.fillWidth: true
                        Layout.topMargin: 12

                        // Auto-save indicator (thay thế nút "Lưu cài đặt")
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            color: "transparent"
                            radius: 8
                            border.color: "#2d6a2d"
                            border.width: 1

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                Text { text: "⚡"; font.pixelSize: 18 }
                                Text {
                                    text: "Cài đặt máy in được lưu tự động"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    font.bold: true
                                }
                            }
                        }

                        Button {
                            text: "🖨️ In test"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 50
                            enabled: printerManager.isConnected

                            background: Rectangle {
                                color: parent.enabled ? (parent.down ? "#166ac1" : (parent.hovered ? "#1e7eea" : "#1976d2")) : Theme.field
                                radius: 8
                            }

                            contentItem: Text {
                                text: parent.text
                                color: parent.enabled ? "white" : root.mutedText(0.65)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }

                            onClicked: {
                                var resolution = resolutionComboBox.currentText.split("-")[0].trim()
                                var copies = copiesSpinBox.value
                                var paperSize = paperSizeComboBox.currentText.split(" ")[0]
                                var cutMode = cutModeCheck.checked ? 0x00 : 0x01

                                console.log("In Test - Độ Phân Giải:", resolution, "Số bản in:", copies, "In:", paperSize, "Cut:", cutMode)
                                testPrintFeedback.open()
                            }
                        }

                        Button {
                            text: "⚙️ Công cụ nâng cao"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 44

                            background: Rectangle {
                                color: parent.hovered ? Theme.field : Theme.surface
                                radius: 8
                                border.color: "#2d5a8c"
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                color: root.themeTextColor
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }

                            onClicked: StackView.view.push("../PrintPage.qml")
                        }
                    }
                        }
                    }
                    // ╚════ /NHÓM ════╝

                    // ╔════ NHÓM: IN TỰ DO ════╗
                    Rectangle {
                        id: freePrintGroup
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        color: "transparent"
                        radius: 10
                        border.color: "#2d5a8c"
                        border.width: 1
                        implicitHeight: grpFreePrintCol.implicitHeight + 40

                        // Trạng thái xoay cục bộ (getAppSetting không reactive) — khởi tạo từ DB.
                        property string rotValue: eventManager.getAppSetting("free_print_rotation", "0")

                        ColumnLayout {
                            id: grpFreePrintCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 18

                            ColumnLayout {
                                spacing: 2
                                Layout.fillWidth: true
                                Text { text: "In tự do"; color: root.themeTextColor; font.pixelSize: 18; font.weight: Font.Bold }
                                Text { text: "In theo khổ driver máy in thường, luôn không cắt"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#2d5a8c"; opacity: 0.5 }

                            SettingsToggleRow {
                                id: freePrintToggle
                                Layout.fillWidth: true
                                title: "Bật in tự do"
                                description: "Gửi ảnh khung tới máy in đã chọn, để driver tự scale theo khổ, luôn không cắt. Tắt để in như hiện tại."
                                checked: eventManager.getAppSetting("free_print_enabled", "false") === "true"
                                accent: Theme.settingsCopper
                                onToggled: function(next) {
                                    eventManager.setAppSetting("free_print_enabled", next ? "true" : "false")
                                    autoSavedToast.show(next ? "Đã bật in tự do" : "Đã tắt in tự do")
                                }
                            }

                            // Cụm con: chỉ hiện khi bật in tự do
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 14
                                visible: freePrintToggle.checked

                                // ── Chọn máy in tự do ──
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "Máy in tự do"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.DemiBold }
                                    Text { text: "Độc lập với máy in chính ở trên"; color: root.mutedText(0.65); font.pixelSize: 12 }

                                    ComboBox {
                                        id: freePrintCombo
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 44
                                        model: []

                                        background: Rectangle {
                                            color: "transparent"
                                            border.color: "#2d5a8c"
                                            radius: 6
                                        }

                                        contentItem: Text {
                                            text: freePrintCombo.currentIndex >= 0 && freePrintCombo.count > 0
                                                  ? freePrintCombo.displayText
                                                  : (eventManager.getAppSetting("free_print_printer", "") || "Chọn máy in...")
                                            color: root.themeTextColor
                                            leftPadding: 12
                                            font.pixelSize: 14
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onActivated: {
                                            eventManager.setAppSetting("free_print_printer", currentText)
                                            autoSavedToast.show("Đã lưu: Máy in tự do")
                                        }
                                    }
                                }

                                // ── Chọn xoay ảnh (Giữ nguyên / Xoay 90°) ──
                                ColumnLayout {
                                    spacing: 6
                                    Layout.fillWidth: true
                                    Text { text: "Xoay ảnh"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.DemiBold }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Repeater {
                                            model: [ { "label": "Giữ nguyên", "val": "0" },
                                                     { "label": "Xoay 90°",  "val": "90" } ]
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                Layout.preferredHeight: 48
                                                radius: 8
                                                border.width: 1
                                                property bool _sel: freePrintGroup.rotValue === modelData.val
                                                color: _sel ? "#1e3a5a" : "transparent"
                                                border.color: _sel ? Theme.settingsCopper : "#2d5a8c"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.label
                                                    color: root.themeTextColor
                                                    font.pixelSize: 14
                                                    font.weight: parent._sel ? Font.DemiBold : Font.Normal
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        freePrintGroup.rotValue = modelData.val
                                                        eventManager.setAppSetting("free_print_rotation", modelData.val)
                                                        autoSavedToast.show("Đã lưu: Xoay ảnh in tự do")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // ╚════ /NHÓM ════╝
                    }
                    // /Lưới các nhóm

                    Item { Layout.fillHeight: true }
                }
            }

            // Success Feedback Popup
            Popup {
                id: saveSuccessFeedback
                x: (parent.width - width) / 2
                y: parent.height - 120
                width: 280
                height: 60
                modal: false
                closePolicy: Popup.CloseOnEscape

                background: Rectangle {
                    color: "#4caf50"
                    radius: 8
                    border.color: "#45a049"
                    border.width: 2
                }

                onOpened: feedbackTimer.start()

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "✓"
                        color: root.themeTextColor
                        font.pixelSize: 20
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "Lưu cài đặt thành công!"
                        color: root.themeTextColor
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }
                }

                Timer {
                    id: feedbackTimer
                    interval: 2500
                    onTriggered: saveSuccessFeedback.close()
                }
            }

            // Test Print Feedback Popup
            Popup {
                id: testPrintFeedback
                x: (parent.width - width) / 2
                y: parent.height - 120
                width: 280
                height: 60
                modal: false
                closePolicy: Popup.CloseOnEscape

                background: Rectangle {
                    color: "#1e7eea"
                    radius: 8
                    border.color: "#1976d2"
                    border.width: 2
                }

                onOpened: testTimer.start()

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "🖨️"
                        font.pixelSize: 18
                    }

                    Text {
                        text: "Gửi ảnh test tới máy in!"
                        color: root.themeTextColor
                        font.pixelSize: 14
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }
                }

                Timer {
                    id: testTimer
                    interval: 2500
                    onTriggered: testPrintFeedback.close()
                }
            }
        }
    }

    Component {
        id: sharingTabComponent
        Item {
            id: sharingRoot

            readonly property int  currentEventId: root.eventData ? root.eventData.id : -1
            readonly property string currentHwid:  machineAuth.hwid
            readonly property string eventUrl:     (currentEventId > 0 && currentHwid !== "")
                                                   ? s3Uploader.buildEventUrl(currentHwid, currentEventId)
                                                   : ""
            readonly property string qrApiUrl:     eventUrl !== ""
                                                   ? ("https://api.qrserver.com/v1/create-qr-code/?size=360x360&data="
                                                      + encodeURIComponent(eventUrl))
                                                   : ""

            // Upload stats — làm mới mỗi 5s và khi nhận signal từ S3Uploader
            property int  statTotal:   0
            property int  statPending: 0
            property bool statOnline:  true

            function refreshStats() {
                if (currentEventId <= 0) return
                var s = eventManager.getEventUploadStats(currentEventId)
                statTotal   = s.totalPhotos   || 0
                statPending = s.pendingFiles   || 0
                statOnline  = s.isOnline !== undefined ? s.isOnline : true
            }

            Timer {
                id: statsRefreshTimer
                interval: 5000
                repeat: true
                running: sharingRoot.currentEventId > 0
                onTriggered: sharingRoot.refreshStats()
            }

            // Cập nhật ngay khi có upload hoàn thành hoặc pending thay đổi
            Connections {
                target: s3Uploader
                // uploadFinished/pendingCountChanged: đọc lại số pending thực tế từ disk
                function onUploadFinished()      { sharingRoot.refreshStats() }
                function onPendingCountChanged() { sharingRoot.refreshStats() }
                // networkOnline/Offline: chỉ đổi cờ online, KHÔNG refreshStats ngay —
                // pending count sẽ cập nhật dần qua pendingCountChanged khi từng file upload xong
                function onNetworkOnline()  { sharingRoot.statOnline = true  }
                function onNetworkOffline() { sharingRoot.statOnline = false }
            }

            // Kết quả lưu mã QR xuống máy
            Connections {
                target: eventManager
                function onQrCodeSaved(success, path) {
                    saveQrBtn.saving = false
                    if (success)
                        autoSavedToast.show("✓ Đã lưu mã QR: " + path)
                    else
                        autoSavedToast.showError("Lưu mã QR thất bại — kiểm tra mạng/quyền ghi")
                }
            }

            // Load ngay khi component hiển thị
            Component.onCompleted: sharingRoot.refreshStats()
            onCurrentEventIdChanged: sharingRoot.refreshStats()

            ScrollView {
                anchors.fill: parent
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: parent.width
                    anchors.margins: 40
                    spacing: 28

                    // ── Title ──────────────────────────────────────────────
                    Text {
                        text: "Chia sẻ album sự kiện"
                        color: root.themeTextColor
                        font.pixelSize: 24
                        font.weight: Font.Bold
                        Layout.topMargin: 40
                        Layout.leftMargin: 40
                    }
                    Text {
                        text: "Khách hàng quét mã QR để xem toàn bộ ảnh của sự kiện này."
                        color: root.mutedText(0.65)
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.leftMargin: 40
                        Layout.rightMargin: 40
                    }

                    // ── No event selected ──────────────────────────────────
                    Text {
                        visible: sharingRoot.currentEventId <= 0
                        text: "⚠ Chưa chọn sự kiện nào."
                        color: "#f0a020"
                        font.pixelSize: 15
                        Layout.leftMargin: 40
                    }

                    // ── Upload Status Card ─────────────────────────────────
                    Rectangle {
                        visible: sharingRoot.currentEventId > 0
                        Layout.leftMargin: 40
                        Layout.rightMargin: 40
                        Layout.fillWidth: true
                        height: uploadStatusCol.implicitHeight + 32
                        radius: 12
                        color: "transparent"
                        border.width: 1
                        border.color: sharingRoot.statPending > 0
                                      ? (sharingRoot.statOnline ? "#f59e0b" : "#ef4444")
                                      : "#22543d"

                        Behavior on border.color { ColorAnimation { duration: 300 } }

                        ColumnLayout {
                            id: uploadStatusCol
                            anchors { left: parent.left; right: parent.right; top: parent.top }
                            anchors.margins: 16
                            spacing: 10

                            // Hàng trên: icon + tiêu đề + trạng thái mạng
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                Text {
                                    text: sharingRoot.statOnline ? "☁" : "✈"
                                    font.pixelSize: 18
                                    color: sharingRoot.statOnline ? "#60a5fa" : root.mutedText(0.65)
                                }
                                Text {
                                    text: "Trạng thái tải lên"
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    font.weight: Font.Medium
                                    Layout.fillWidth: true
                                }
                                Rectangle {
                                    width: onlineDot.implicitWidth + onlineLabel.implicitWidth + 16
                                    height: 22
                                    radius: 11
                                    color: sharingRoot.statOnline ? "#14532d" : "#450a0a"
                                    border.color: sharingRoot.statOnline ? "#16a34a" : "#dc2626"
                                    border.width: 1
                                    Behavior on color { ColorAnimation { duration: 300 } }
                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 5
                                        Rectangle {
                                            id: onlineDot
                                            width: 7; height: 7; radius: 4
                                            color: sharingRoot.statOnline ? "#4ade80" : "#f87171"
                                            Behavior on color { ColorAnimation { duration: 300 } }

                                            SequentialAnimation on opacity {
                                                running: !sharingRoot.statOnline && sharingRoot.statPending > 0
                                                loops: Animation.Infinite
                                                NumberAnimation { to: 0.3; duration: 700 }
                                                NumberAnimation { to: 1.0; duration: 700 }
                                            }
                                        }
                                        Text {
                                            id: onlineLabel
                                            text: sharingRoot.statOnline ? "Online" : "Offline"
                                            color: sharingRoot.statOnline ? "#4ade80" : "#f87171"
                                            font.pixelSize: 11
                                            Behavior on color { ColorAnimation { duration: 300 } }
                                        }
                                    }
                                }
                            }

                            // Thanh tiến độ
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // X/Y ảnh đã upload
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        property int uploaded: Math.max(0, sharingRoot.statTotal - sharingRoot.statPending)
                                        text: uploaded + "/" + sharingRoot.statTotal + " ảnh đã upload"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        visible: sharingRoot.statPending > 0
                                        text: sharingRoot.statPending + " chờ"
                                        color: sharingRoot.statOnline ? "#fbbf24" : "#f87171"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                    Text {
                                        visible: sharingRoot.statPending === 0 && sharingRoot.statTotal > 0
                                        text: "✓"
                                        color: "#4ade80"
                                        font.pixelSize: 14
                                        font.weight: Font.Bold
                                    }
                                }

                                // Progress bar
                                Rectangle {
                                    Layout.fillWidth: true
                                    height: 8
                                    radius: 4
                                    color: "#374151"

                                    Rectangle {
                                        id: uploadProgressFill
                                        property real ratio: {
                                            if (sharingRoot.statTotal <= 0) return 0.0
                                            var uploaded = Math.max(0, sharingRoot.statTotal - sharingRoot.statPending)
                                            return uploaded / sharingRoot.statTotal
                                        }
                                        width: parent.width * ratio
                                        height: parent.height
                                        radius: 4
                                        color: sharingRoot.statPending > 0
                                               ? (sharingRoot.statOnline ? "#f59e0b" : "#ef4444")
                                               : "#22c55e"
                                        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
                                        Behavior on color { ColorAnimation  { duration: 300 } }
                                    }
                                }

                                // Thông báo trạng thái
                                Text {
                                    visible: !sharingRoot.statOnline && sharingRoot.statPending > 0
                                    text: "Mất mạng — sẽ tự upload khi có kết nối trở lại."
                                    color: "#f87171"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                }
                                Text {
                                    visible: sharingRoot.statOnline && sharingRoot.statPending > 0
                                    text: "Đang upload..."
                                    color: "#fbbf24"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                }
                            }

                        }
                    }

                    // ── QR + URL card ──────────────────────────────────────
                    Rectangle {
                        visible: sharingRoot.eventUrl !== ""
                        Layout.leftMargin: 40
                        Layout.rightMargin: 40
                        Layout.fillWidth: true
                        height: qrCardLayout.implicitHeight + 48
                        radius: 16
                        color: "transparent"
                        border.color: "#2a2e35"
                        border.width: 1

                        ColumnLayout {
                            id: qrCardLayout
                            anchors { fill: parent; margins: 24 }
                            spacing: 20

                            // QR Code
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 200; height: 200
                                color: "transparent"
                                radius: 12

                                Image {
                                    id: eventQrImage
                                    anchors { fill: parent; margins: 10 }
                                    source: sharingRoot.qrApiUrl
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    cache: false
                                }

                                BusyIndicator {
                                    anchors.centerIn: parent
                                    running: eventQrImage.status === Image.Loading
                                    visible: running
                                }
                            }

                            // Event name
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.eventData ? root.eventData.name : ""
                                color: root.themeTextColor
                                font.pixelSize: 16
                                font.weight: Font.Medium
                            }

                            // URL display
                            Rectangle {
                                Layout.fillWidth: true
                                height: 44
                                radius: 8
                                color: "transparent"
                                border.color: "#2d5a8c"

                                Text {
                                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                                    verticalAlignment: Text.AlignVCenter
                                    text: sharingRoot.eventUrl
                                    color: "#1e7eea"
                                    font.pixelSize: 13
                                    font.family: "Courier New"
                                    elide: Text.ElideMiddle
                                }
                            }

                            // Hidden clipboard helper
                            TextEdit {
                                id: clipHelper
                                visible: false
                            }

                            // Copy button
                            Button {
                                id: copyBtn
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 44

                                property bool copied: false
                                text: copied ? "✓ Đã sao chép!" : "📋 Sao chép đường dẫn"

                                background: Rectangle {
                                    radius: 10
                                    color: copyBtn.copied ? "#1b7a3c"
                                         : copyBtn.pressed ? "#1565c0" : "#1e7eea"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: root.themeTextColor
                                    font.pixelSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    clipHelper.text = sharingRoot.eventUrl
                                    clipHelper.selectAll()
                                    clipHelper.copy()
                                    copyBtn.copied = true
                                    Qt.callLater(function() {
                                        resetTimer.start()
                                    })
                                }

                                Timer {
                                    id: resetTimer
                                    interval: 2000
                                    onTriggered: copyBtn.copied = false
                                }
                            }

                            // Print QR button
                            Button {
                                id: printQrBtn
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 44

                                enabled: printerManager.isConnected && sharingRoot.qrApiUrl !== ""

                                property bool printing: false
                                text: printing ? "⏳ Đang in..." : "🖨️ In mã QR"

                                background: Rectangle {
                                    radius: 10
                                    color: printQrBtn.enabled
                                           ? (printQrBtn.printing ? "#1b5e20"
                                              : (printQrBtn.pressed ? "#1b5e20" : (printQrBtn.hovered ? "#2e7d32" : "#388e3c")))
                                           : Theme.field
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled ? "white" : root.mutedText(0.65)
                                    font.pixelSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    printQrBtn.printing = true
                                    var eventName = root.eventData ? root.eventData.name : ""
                                    eventManager.printQrCode(sharingRoot.qrApiUrl, eventName)
                                    printQrResetTimer.start()
                                }

                                Timer {
                                    id: printQrResetTimer
                                    interval: 3000
                                    onTriggered: printQrBtn.printing = false
                                }

                                ToolTip.visible: !printerManager.isConnected && printQrBtn.hovered
                                ToolTip.text: "Máy in chưa kết nối"
                                ToolTip.delay: 400
                            }

                            // Save QR button
                            Button {
                                id: saveQrBtn
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 220
                                Layout.preferredHeight: 44

                                enabled: sharingRoot.qrApiUrl !== "" && !saving

                                property bool saving: false
                                text: saving ? "⏳ Đang lưu..." : "💾 Lưu mã QR"

                                background: Rectangle {
                                    radius: 10
                                    color: saveQrBtn.enabled
                                           ? (saveQrBtn.pressed ? "#6d28d9"
                                              : (saveQrBtn.hovered ? "#7c3aed" : "#8b5cf6"))
                                           : Theme.field
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }
                                contentItem: Text {
                                    text: parent.text
                                    color: parent.enabled || saveQrBtn.saving ? "white" : root.mutedText(0.65)
                                    font.pixelSize: 15
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    saveQrBtn.saving = true
                                    var eventName = root.eventData ? root.eventData.name : ""
                                    eventManager.saveQrCode(sharingRoot.qrApiUrl, eventName)
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true; Layout.minimumHeight: 20 }
                }
            }
        }
    }

    Component {
        id: templatesTabComponent
        Item {
            id: frameManagerItem

            property bool selectMode: false
            property string selectedCategory: ""
            property var selectedPaths: ({})
            property int selectedCount: 0
            property bool paperMode: root._operationMode === "modebao"
            property bool mode3FrameGroups: root._operationMode === "mode3"
            property bool categoryEnabled: !paperMode && (mode3FrameGroups || eventManager.getAppSetting("frame_category_enabled", "false") === "true")
            // mode2: hiển thị khung kiểu "hàng dưới" (như chế độ 1) ở LayoutSelection.
            property bool bottomStripEnabled: eventManager.getAppSetting("mode2_show_bottom_strip", "false") === "true"

            function toggleSelect(path) {
                var sp = Object.assign({}, selectedPaths)
                if (sp[path]) delete sp[path]
                else sp[path] = true
                selectedPaths = sp
                selectedCount = Object.keys(sp).length
            }

            function selectAll() {
                var sp = {}
                for (var i = 0; i < layoutModel.count; i++)
                    sp[layoutModel.get(i).path] = true
                selectedPaths = sp
                selectedCount = Object.keys(sp).length
            }

            function selectCategoryFrames(frames, category) {
                var sp = {}
                for (var i = 0; i < frames.length; i++)
                    sp[frames[i].path] = true
                selectedCategory = category
                selectedPaths = sp
                selectedCount = Object.keys(sp).length
            }

            function clearSelection() {
                selectedCategory = ""
                selectedPaths = {}
                selectedCount = 0
            }

            function scrollToCategory(category) {
                if (!category || !categoryRepeater) return
                for (var i = 0; i < categoryRepeater.count; i++) {
                    var item = categoryRepeater.itemAt(i)
                    if (item && item.catName === category) {
                        categoryScroll.contentItem.contentY = Math.max(0, Math.min(item.y, categoryScroll.contentItem.contentHeight - categoryScroll.height))
                        root.pendingCategoryScroll = ""
                        return
                    }
                }
            }

            Timer {
                id: categoryScrollRestoreTimer
                interval: 80
                repeat: false
                onTriggered: frameManagerItem.scrollToCategory(root.pendingCategoryScroll)
            }

            Connections {
                target: root
                function onCategoryScrollRequestChanged() {
                    if (frameManagerItem.categoryEnabled)
                        categoryScrollRestoreTimer.restart()
                }
            }

            // ── Rename Popup ────────────────────────────────────────────────
            Popup {
                id: renamePopup
                modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                parent: Overlay.overlay
                anchors.centerIn: Overlay.overlay
                width: 400
                height: 170
                padding: 24
                property string targetPath: ""

                onOpened: renameField.forceActiveFocus()

                background: Rectangle { color: Theme.settingsCard; radius: Theme.settingsRadiusMedium; border.color: Theme.settingsBorder; border.width: 1 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    Text { text: "Đổi tên khung hình"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }

                    TextField {
                        id: renameField
                        Layout.fillWidth: true
                        placeholderText: "Tên mới (không cần .png)..."
                        color: root.themeTextColor
                        background: Rectangle { color: Theme.settingsSurface; radius: 6; border.color: renameField.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                        Keys.onReturnPressed: renameOkBtn.clicked()
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Item { Layout.fillWidth: true }
                        PillButton {
                            text: "Hủy"
                            implicitWidth: 80
                            onClicked: renamePopup.close()
                        }
                        PillButton {
                            id: renameOkBtn
                            text: "Đổi tên"
                            filled: true
                            implicitWidth: 90
                            enabled: renameField.text.trim().length > 0
                            onClicked: {
                                var newName = renameField.text.trim()
                                if (newName.length > 0 && root.eventData) {
                                    // frameRenamed lo migrateFrameImage, layoutUploaded lo refresh.
                                    eventManager.renameLayoutsBatch(root.eventData.id,
                                        [{ "from": renamePopup.targetPath, "to": newName }])
                                }
                                renamePopup.close()
                            }
                        }
                    }
                }
            }

            // ── Delete Confirm Popup ────────────────────────────────────────
            Popup {
                id: deleteConfirmPopup
                modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                parent: Overlay.overlay
                anchors.centerIn: Overlay.overlay
                width: 360
                height: 160
                padding: 24
                property var pathsToDelete: []

                background: Rectangle { color: Theme.settingsCard; radius: Theme.settingsRadiusMedium; border.color: Theme.settingsBorder; border.width: 1 }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 16

                    Text {
                        text: deleteConfirmPopup.pathsToDelete.length > 1
                              ? "Xóa " + deleteConfirmPopup.pathsToDelete.length + " khung hình?"
                              : "Xóa khung hình này?"
                        color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold
                        wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    Text { text: "Hành động này không thể hoàn tác."; color: root.mutedText(0.65); font.pixelSize: 14 }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Item { Layout.fillWidth: true }
                        PillButton {
                            text: "Hủy"
                            implicitWidth: 80
                            onClicked: deleteConfirmPopup.close()
                        }
                        PillButton {
                            text: "Xóa"
                            filled: true
                            danger: true
                            implicitWidth: 80
                            onClicked: {
                                // Cả lô trong một lời gọi: xoá tuần tự ở nền, có tiến trình,
                                // và chỉ nạp lại danh sách 1 lần (trước đây là N+1 lần).
                                // eventId = -1 là quy ước "khung giấy" — trùng với tín hiệu
                                // layoutUploaded(-1) mà deletePaperLayout vẫn phát.
                                var paths = deleteConfirmPopup.pathsToDelete
                                var evId = frameManagerItem.paperMode
                                           ? -1
                                           : (root.eventData ? root.eventData.id : 0)
                                if (paths.length > 0 && evId !== 0)
                                    eventManager.deleteLayoutsBatch(evId, paths)
                                frameManagerItem.clearSelection()
                                frameManagerItem.selectMode = false
                                deleteConfirmPopup.close()
                            }
                        }
                    }
                }
            }

            // ══════════════════════════════════════════════════════════════
            // COMPONENT TÁI DÙNG (inline)
            // ══════════════════════════════════════════════════════════════

            // Nút bo tròn theo theme Cài đặt: outline (mặc định) hoặc filled (đồng).
            component PillButton: Button {
                property bool filled: false
                property bool danger: false
                implicitHeight: 32
                leftPadding: 14; rightPadding: 14
                background: Rectangle {
                    radius: Theme.settingsRadiusSmall
                    color: parent.filled
                           ? (parent.danger ? (parent.hovered ? Qt.darker(Theme.settingsDanger, 1.15) : Theme.settingsDanger)
                                            : (parent.hovered ? Theme.settingsCopperDark : Theme.settingsCopper))
                           : (parent.hovered ? Theme.settingsCopperSoft : "transparent")
                    border.width: parent.filled ? 0 : 1
                    border.color: parent.danger ? Theme.settingsDanger
                                  : (parent.hovered ? Theme.settingsCopper : Theme.settingsBorder)
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.filled ? "#FFFFFF"
                           : (parent.danger ? Theme.settingsDanger : Theme.settingsTextMuted)
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // Thẻ bật/tắt 80px (tiêu đề + mô tả + switch). Phát signal toggled().
            component ToggleCard: Rectangle {
                id: tcard
                property bool on: false
                property string title: ""
                property string subtitle: ""
                signal toggled()
                Layout.fillWidth: true
                height: 80
                radius: Theme.settingsRadiusMedium
                color: tcard.on ? Theme.settingsCopperSoft : Theme.settingsCard
                border.width: 1
                border.color: tcard.on ? Theme.settingsCopper : Theme.settingsBorder

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 16

                    Rectangle {
                        implicitWidth: 48; implicitHeight: 26; radius: 13
                        color: tcard.on ? Theme.settingsCopper : Theme.settingsBorder
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            x: tcard.on ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11; color: "#FFFFFF"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            text: tcard.title
                            color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                        Text {
                            text: tcard.subtitle
                            color: root.mutedText(0.65); font.pixelSize: 13
                            wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: tcard.toggled()
                }
            }

            // Thẻ 1 khung hình — dùng cho cả lưới nhóm và lưới tổng.
            component FrameCard: Item {
                id: fcard
                property string framePath: ""
                property string frameFile: ""
                property var frameMeta: null
                property bool selectModeOn: false
                property bool showCategoryTools: false

                property bool isActiveLayout: root.eventData && (root.eventData.selectedLayout === framePath)
                property bool isChecked: frameManagerItem.selectedPaths[framePath] === true
                property string frameImage: root.frameImagePath(framePath)
                property bool hasFrameImage: frameImage !== ""
                property string framePreviewPath: hasFrameImage ? frameImage : framePath

                function _doActivate() {
                    if (fcard.selectModeOn) {
                        frameManagerItem.toggleSelect(fcard.framePath)
                    } else if (root.eventData) {
                        if (eventManager.updateEventLayout(root.eventData.id, fcard.framePath))
                            root.eventData = eventManager.getEventDetails(root.eventData.id)
                    }
                }
                function _confirmDelete() {
                    deleteConfirmPopup.pathsToDelete = [fcard.framePath]
                    deleteConfirmPopup.open()
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.settingsRadiusMedium
                    color: Theme.settingsCard
                    border.color: fcard.isChecked ? Theme.settingsDanger
                                  : fcard.isActiveLayout ? Theme.settingsCopper
                                  : (cardHover.containsMouse ? Theme.settingsCopper : Theme.settingsBorder)
                    border.width: (fcard.isChecked || fcard.isActiveLayout) ? 2 : 1

                    // Vùng bấm chính (chừa đáy cho hàng nút).
                    MouseArea {
                        id: cardHover
                        anchors.fill: parent
                        anchors.bottomMargin: fcard.selectModeOn ? 0
                                              : (fcard.showCategoryTools ? 74 : 26)
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fcard._doActivate()
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 4

                        // Ô ảnh nền trắng + overlay số slot
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.settingsRadiusSmall
                            color: "#FFFFFF"
                            border.color: Theme.settingsBorder
                            border.width: 1
                            clip: true

                            Image {
                                id: frameImg
                                anchors.fill: parent
                                anchors.margins: 4
                                source: root.frameImageSourceUrl(fcard.framePreviewPath)
                                fillMode: Image.PreserveAspectFit
                                mipmap: true
                                asynchronous: true
                                cache: true
                                sourceSize.width: 320
                                sourceSize.height: 320
                            }

                            // Badge số thứ tự cho từng ô slot (1, 2, 3, 4…)
                            Repeater {
                                visible: !fcard.hasFrameImage
                                model: (fcard.frameMeta && fcard.frameMeta.slots) ? fcard.frameMeta.slots : []
                                delegate: Rectangle {
                                    property var slot: modelData
                                    property real cw: (fcard.frameMeta && fcard.frameMeta.width) ? fcard.frameMeta.width : 0
                                    property real ch: (fcard.frameMeta && fcard.frameMeta.height) ? fcard.frameMeta.height : 0
                                    property real s: (cw > 0 && ch > 0) ? Math.min(frameImg.width / cw, frameImg.height / ch) : 0
                                    property real offX: frameImg.x + (frameImg.width - cw * s) / 2
                                    property real offY: frameImg.y + (frameImg.height - ch * s) / 2
                                    visible: s > 0 && slot
                                    width: 18; height: 18; radius: 9
                                    color: Theme.settingsCopper
                                    x: offX + (slot.x + slot.width / 2) * s - width / 2
                                    y: offY + (slot.y + slot.height / 2) * s - height / 2
                                    Text {
                                        anchors.centerIn: parent
                                        text: index + 1
                                        color: "#FFFFFF"; font.pixelSize: 11; font.bold: true
                                    }
                                }
                            }
                        }

                        // (lưới tổng) tên file
                        Text {
                            visible: fcard.showCategoryTools
                            Layout.fillWidth: true
                            text: fcard.frameFile
                            color: fcard.isActiveLayout ? Theme.settingsCopper : root.mutedText(0.65)
                            font.pixelSize: 11; font.bold: fcard.isActiveLayout
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // (lưới tổng) số slot
                        Text {
                            visible: fcard.showCategoryTools
                            Layout.fillWidth: true
                            text: (fcard.frameMeta && fcard.frameMeta.slot_count) ? fcard.frameMeta.slot_count + " slots" : "..."
                            color: root.mutedText(0.65); font.pixelSize: 10
                            horizontalAlignment: Text.AlignHCenter
                        }

                        // (lưới tổng) nhãn nhóm + gán nhóm — chỉ khi bật chế độ nhóm
                        Rectangle {
                            Layout.fillWidth: true
                            height: 20; radius: 4
                            visible: fcard.showCategoryTools && frameManagerItem.categoryEnabled && !fcard.selectModeOn
                            color: "transparent"
                            border.color: catBadgeHover.containsMouse ? Theme.settingsCopper : Theme.settingsBorder
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                text: "🗂 " + root.categoryOf(fcard.frameFile)
                                color: Theme.settingsCopper; font.pixelSize: 10
                                elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
                            }
                            MouseArea {
                                id: catBadgeHover
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: assignCatMenu.open()
                            }
                            Menu {
                                id: assignCatMenu
                                MenuItem {
                                    text: "Khác (bỏ nhóm)"
                                    onTriggered: root.assignFrameCategory(fcard.framePath, fcard.frameFile, "Khác")
                                }
                                Repeater {
                                    model: { var d = root._catRefreshCount; return root.getCategoryList() }
                                    delegate: MenuItem {
                                        text: modelData
                                        onTriggered: root.assignFrameCategory(fcard.framePath, fcard.frameFile, modelData)
                                    }
                                }
                            }
                        }

                        // (lưới tổng) hàng nút Đổi tên / Xóa
                        RowLayout {
                            Layout.fillWidth: true
                            visible: fcard.showCategoryTools && !fcard.selectModeOn
                            spacing: 4

                            Rectangle {
                                Layout.fillWidth: true; height: 22; radius: 4
                                color: "transparent"
                                border.color: frameImageHover.containsMouse || fcard.hasFrameImage ? Theme.settingsCopper : Theme.settingsBorder
                                border.width: 1
                                Text { anchors.centerIn: parent; text: fcard.hasFrameImage ? "Anh *" : "+ Anh"; color: Theme.settingsCopper; font.pixelSize: 10 }
                                MouseArea {
                                    id: frameImageHover
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        frameDisplayImageDialog.targetFramePath = fcard.framePath
                                        if (fcard.hasFrameImage) frameImageMenu.open()
                                        else frameDisplayImageDialog.open()
                                    }
                                }
                                Menu {
                                    id: frameImageMenu
                                    MenuItem {
                                        text: "Doi anh"
                                        onTriggered: {
                                            frameDisplayImageDialog.targetFramePath = fcard.framePath
                                            frameDisplayImageDialog.open()
                                        }
                                    }
                                    MenuItem {
                                        text: "Bo anh rieng"
                                        onTriggered: root.clearFrameImage(fcard.framePath)
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 22; radius: 4
                                color: "transparent"
                                border.color: renameHover.containsMouse ? Theme.settingsCopper : Theme.settingsBorder
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "Đổi tên"; color: Theme.settingsCopper; font.pixelSize: 10 }
                                MouseArea {
                                    id: renameHover
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        renameField.text = fcard.frameFile.replace(/\.png$/i, "")
                                        renamePopup.targetPath = fcard.framePath
                                        renamePopup.open()
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; height: 22; radius: 4
                                color: "transparent"
                                border.color: deleteHover.containsMouse ? Theme.settingsDanger : Theme.settingsBorder
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "Xóa"; color: Theme.settingsDanger; font.pixelSize: 10 }
                                MouseArea {
                                    id: deleteHover
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: fcard._confirmDelete()
                                }
                            }
                        }

                        // (lưới nhóm) nút Xóa nhỏ
                        Rectangle {
                            Layout.fillWidth: true
                            visible: !fcard.showCategoryTools && !fcard.selectModeOn
                            height: 20; radius: 4
                            color: "transparent"
                            border.color: frameImageHoverSmall.containsMouse || fcard.hasFrameImage ? Theme.settingsCopper : Theme.settingsBorder
                            border.width: 1
                            Text { anchors.centerIn: parent; text: fcard.hasFrameImage ? "Anh *" : "+ Anh"; color: Theme.settingsCopper; font.pixelSize: 10 }
                            MouseArea {
                                id: frameImageHoverSmall
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    frameDisplayImageDialog.targetFramePath = fcard.framePath
                                    if (fcard.hasFrameImage) frameImageMenuSmall.open()
                                    else frameDisplayImageDialog.open()
                                }
                            }
                            Menu {
                                id: frameImageMenuSmall
                                MenuItem {
                                    text: "Doi anh"
                                    onTriggered: {
                                        frameDisplayImageDialog.targetFramePath = fcard.framePath
                                        frameDisplayImageDialog.open()
                                    }
                                }
                                MenuItem {
                                    text: "Bo anh rieng"
                                    onTriggered: root.clearFrameImage(fcard.framePath)
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            visible: !fcard.showCategoryTools && !fcard.selectModeOn
                            height: 20; radius: 4
                            color: "transparent"
                            border.color: delHoverSmall.containsMouse ? Theme.settingsDanger : Theme.settingsBorder
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "Xóa"; color: Theme.settingsDanger; font.pixelSize: 10 }
                            MouseArea {
                                id: delHoverSmall
                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: fcard._confirmDelete()
                            }
                        }
                    }

                    // Ô tick chọn (góc trái) khi ở chế độ chọn nhiều
                    Rectangle {
                        width: 22; height: 22; radius: 4
                        anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 6
                        visible: fcard.selectModeOn
                        color: fcard.isChecked ? Theme.settingsDanger : Theme.settingsCard
                        border.color: fcard.isChecked ? Theme.settingsDanger : Theme.settingsTextMuted
                        border.width: 2
                        Text { anchors.centerIn: parent; text: "✓"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 14; visible: fcard.isChecked }
                    }

                    // Badge "đang chọn làm layout" (góc phải)
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        color: Theme.settingsCopper
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 6
                        visible: fcard.isActiveLayout && !fcard.selectModeOn
                        Text { anchors.centerIn: parent; text: "✓"; color: "#FFFFFF"; font.bold: true }
                    }
                }
            }

            // ── Main layout ─────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 40
                spacing: 20

                Text { text: "Lựa chọn mẫu"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold }

                // ── Toggle: Chọn khung theo nhóm (category) ──────────────────
                ToggleCard {
                    visible: !frameManagerItem.mode3FrameGroups
                    on: frameManagerItem.categoryEnabled
                    title: "Chọn khung hình theo nhóm (category)"
                    subtitle: "Khi bật, trang chọn kiểu chụp sẽ hiển thị các nhóm khung hình (kèm thumbnail) thay vì Ảnh Cắt / Ảnh Không Cắt. Tắt → quay về chia theo cắt / không cắt như cũ."
                    onToggled: {
                        frameManagerItem.categoryEnabled = !frameManagerItem.categoryEnabled
                        eventManager.setAppSetting("frame_category_enabled", frameManagerItem.categoryEnabled ? "true" : "false")
                        autoSavedToast.show(frameManagerItem.categoryEnabled ? "Đã bật: Chọn theo nhóm" : "Đã tắt: Chọn theo nhóm")
                    }
                }

                // ── Toggle: Hiển thị frame hàng dưới (chỉ mode2) ─────────────
                ToggleCard {
                    visible: root._operationMode === "mode2"
                    on: frameManagerItem.bottomStripEnabled
                    title: "Hiển thị khung dạng hàng dưới (như chế độ 1)"
                    subtitle: "Khi bật, trang chọn khung sẽ hiển thị ảnh xem trước lớn kèm dải thumbnail hàng dưới giống chế độ 1, thay cho dạng carousel. Mặc định tắt."
                    onToggled: {
                        frameManagerItem.bottomStripEnabled = !frameManagerItem.bottomStripEnabled
                        eventManager.setAppSetting("mode2_show_bottom_strip", frameManagerItem.bottomStripEnabled ? "true" : "false")
                        autoSavedToast.show(frameManagerItem.bottomStripEnabled ? "Đã bật: Khung hàng dưới" : "Đã tắt: Khung hàng dưới")
                    }
                }

                // ── Quản lý danh sách nhóm (chỉ hiện khi bật) ────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: frameManagerItem.categoryEnabled
                    visible: frameManagerItem.categoryEnabled
                    color: Theme.settingsSurface
                    radius: Theme.settingsRadiusMedium
                    border.color: Theme.settingsBorder
                    border.width: 1

                    ColumnLayout {
                        id: categoryManagerCol
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: frameManagerItem.mode3FrameGroups ? "Nhóm khung hình (Chế độ 3)" : "Nhóm khung hình"
                                color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Bold; Layout.fillWidth: true
                            }
                            PillButton {
                                text: "+ Thêm nhóm"
                                filled: true
                                onClicked: root.addCategory()
                            }
                        }

                        ScrollView {
                            id: categoryScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                            ColumnLayout {
                                width: categoryScroll.availableWidth
                                spacing: 16

                                Repeater {
                                    id: categoryRepeater
                                    model: { var d = root._catRefreshCount; return root.getCategoryList() }
                                    delegate: ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        property string catName: modelData
                                        property var catFrames: { var d = root._framesRefreshCount; return root.framesInCategory(catName) }
                                        property bool categorySelectMode: frameManagerItem.selectMode && frameManagerItem.selectedCategory === catName

                                        // ── Hàng tiêu đề nhóm (thumbnail + tên + nút) ──
                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 10

                                            // Thumbnail preview (ô trắng)
                                            Rectangle {
                                                width: 64; height: 64; radius: Theme.settingsRadiusSmall
                                                color: "#FFFFFF"; border.color: Theme.settingsBorder; border.width: 1
                                                Image {
                                                    anchors.fill: parent; anchors.margins: 4
                                                    fillMode: Image.PreserveAspectFit
                                                    asynchronous: true
                                                    // Khớp với LayoutSelection/CutModeScreen: ưu tiên ảnh hiển thị
                                                    // (cate_image_), nếu chưa có thì dùng file thumbnail (cate_thumb_).
                                                    source: {
                                                        var d = root._catRefreshCount
                                                        var img = eventManager.getAppSetting("cate_image_" + catName, "")
                                                        var p = img !== "" ? img : eventManager.getAppSetting("cate_thumb_" + catName, "")
                                                        if (!p) return ""
                                                        if (p.startsWith("file:") || p.startsWith("http") || p.startsWith("qrc:")) return p
                                                        return "file:///" + p.replace(/\\/g, "/")
                                                    }
                                                }
                                                Text {
                                                    anchors.centerIn: parent; text: "🖼"; font.pixelSize: 22
                                                    visible: eventManager.getAppSetting("cate_image_" + catName, "") === ""
                                                             && eventManager.getAppSetting("cate_thumb_" + catName, "") === ""
                                                    color: root.mutedText(0.45)
                                                }
                                            }

                                            TextField {
                                                id: catNameField
                                                Layout.fillWidth: true
                                                text: catName
                                                color: root.themeTextColor
                                                background: Rectangle { color: Theme.settingsSurface; radius: 6; border.color: catNameField.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                                                onEditingFinished: if (text.trim() !== catName) root.renameCategory(catName, text.trim())
                                            }

                                            // Giá nhóm (₫/bản) — chỉ hiện khi bật "thanh toán theo giá khung frame".
                                            RowLayout {
                                                spacing: 4
                                                visible: { var d = root._catRefreshCount; return eventManager.getAppSetting("pricing_by_category_enabled", "false") === "true" }
                                                TextField {
                                                    id: catPriceField
                                                    Layout.preferredWidth: 110
                                                    text: { var d = root._catRefreshCount; return eventManager.getAppSetting("cate_price_" + catName, "0") }
                                                    color: root.themeTextColor
                                                    inputMethodHints: Qt.ImhDigitsOnly
                                                    horizontalAlignment: TextInput.AlignRight
                                                    background: Rectangle { color: Theme.settingsSurface; radius: 6; border.color: catPriceField.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                                                    onEditingFinished: {
                                                        var v = (parseInt(text.trim(), 10) || 0).toString()
                                                        eventManager.setAppSetting("cate_price_" + catName, v)
                                                        root._catRefreshCount++
                                                        autoSavedToast.show("Đã lưu giá nhóm \"" + catName + "\": " + v + "₫")
                                                    }
                                                }
                                                Text { text: "₫/bản"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                            }

                                            // Toggle: chụp theo mẫu khung cho riêng nhóm này
                                            Rectangle {
                                                id: tplToggle
                                                visible: !frameManagerItem.mode3FrameGroups
                                                property bool on: { var d = root._catRefreshCount; return eventManager.getAppSetting("cate_template_" + catName, "false") === "true" }
                                                implicitHeight: 32
                                                implicitWidth: tplRow.implicitWidth + 20
                                                radius: Theme.settingsRadiusSmall
                                                color: tplToggle.on ? Theme.settingsCopper : "transparent"
                                                border.color: tplToggle.on ? Theme.settingsCopper : Theme.settingsBorder
                                                border.width: 1
                                                Behavior on color { ColorAnimation { duration: 150 } }

                                                RowLayout {
                                                    id: tplRow
                                                    anchors.centerIn: parent
                                                    spacing: 6
                                                    Rectangle {
                                                        implicitWidth: 32; implicitHeight: 18; radius: 9
                                                        color: tplToggle.on ? "#ffffff" : Theme.settingsBorder
                                                        Rectangle {
                                                            x: tplToggle.on ? parent.width - width - 2 : 2
                                                            width: 14; height: 14; radius: 7
                                                            color: tplToggle.on ? Theme.settingsCopper : "#ffffff"
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            Behavior on x { NumberAnimation { duration: 150 } }
                                                        }
                                                    }
                                                    Text {
                                                        text: "Theo mẫu"
                                                        color: tplToggle.on ? "#ffffff" : root.mutedText(0.65)
                                                        font.pixelSize: 13
                                                    }
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: {
                                                        var nv = !tplToggle.on
                                                        eventManager.setAppSetting("cate_template_" + catName, nv ? "true" : "false")
                                                        root._catRefreshCount++
                                                        autoSavedToast.show(nv ? ("Nhóm \"" + catName + "\": chụp theo mẫu")
                                                                              : ("Nhóm \"" + catName + "\": chụp manual (6 ảnh)"))
                                                    }
                                                }
                                            }

                                            // Nút chính: thêm frame vào nhóm
                                            PillButton {
                                                text: "+ Frame"
                                                filled: true
                                                visible: !categorySelectMode
                                                enabled: !root._frameBusy
                                                onClicked: { categoryUploadDialog.targetCategory = catName; categoryUploadDialog.open() }
                                            }

                                            // Menu "⋯": gom các thao tác phụ
                                            PillButton {
                                                text: "⋯"
                                                implicitWidth: 40
                                                visible: !categorySelectMode
                                                onClicked: catMenu.open()
                                                Menu {
                                                    id: catMenu
                                                    MenuItem {
                                                        text: "Frame mặc định"
                                                        onTriggered: { categoryThumbnailDialog.targetCategory = catName; categoryThumbnailDialog.open() }
                                                    }
                                                    MenuItem {
                                                        text: { var d = root._catRefreshCount; return eventManager.getAppSetting("cate_image_" + catName, "") !== "" ? "Ảnh hiển thị ✓" : "Ảnh hiển thị" }
                                                        onTriggered: { categoryDisplayImageDialog.targetCategory = catName; categoryDisplayImageDialog.open() }
                                                    }
                                                    MenuItem {
                                                        text: "Chọn nhiều"
                                                        onTriggered: {
                                                            frameManagerItem.clearSelection()
                                                            frameManagerItem.selectedCategory = catName
                                                            frameManagerItem.selectMode = true
                                                        }
                                                    }
                                                    MenuSeparator {}
                                                    MenuItem {
                                                        text: "Xóa nhóm"
                                                        onTriggered: root.deleteCategory(catName)
                                                    }
                                                }
                                            }

                                            // Cụm nút khi đang chọn nhiều
                                            PillButton {
                                                text: "Chọn tất cả"
                                                visible: categorySelectMode
                                                onClicked: frameManagerItem.selectCategoryFrames(catFrames, catName)
                                            }
                                            PillButton {
                                                text: "Xóa (" + frameManagerItem.selectedCount + ")"
                                                filled: true; danger: true
                                                visible: categorySelectMode && frameManagerItem.selectedCount > 0
                                                onClicked: {
                                                    deleteConfirmPopup.pathsToDelete = Object.keys(frameManagerItem.selectedPaths)
                                                    deleteConfirmPopup.open()
                                                }
                                            }
                                            PillButton {
                                                text: "Hủy"
                                                danger: true
                                                implicitWidth: 70
                                                visible: categorySelectMode
                                                onClicked: {
                                                    frameManagerItem.selectMode = false
                                                    frameManagerItem.clearSelection()
                                                }
                                            }
                                        }

                                        // ── Lưới con: các frame thuộc nhóm này ──
                                        Rectangle {
                                            id: catFrameBox
                                            Layout.fillWidth: true
                                            // Số cột tính theo bề rộng khả dụng (ô tối thiểu ~170px), tối thiểu 1 cột
                                            property int _innerW: width - 16
                                            property int _cols: Math.max(1, Math.floor(_innerW / 170))
                                            property int _cellW: _cols > 0 ? Math.floor(_innerW / _cols) : 170
                                            property int _cellH: 210
                                            Layout.preferredHeight: catFrames.length > 0
                                                ? (Math.ceil(catFrames.length / _cols) * _cellH + 16)
                                                : 40
                                            color: "transparent"
                                            radius: Theme.settingsRadiusSmall
                                            border.color: Theme.settingsBorder

                                            Text {
                                                anchors.centerIn: parent
                                                visible: catFrames.length === 0
                                                text: "Chưa có frame. Bấm \"+ Frame\" để thêm."
                                                color: root.mutedText(0.65); font.pixelSize: 13
                                            }

                                            GridView {
                                                id: catGrid
                                                anchors.fill: parent
                                                anchors.margins: 8
                                                cellWidth: catFrameBox._cellW
                                                cellHeight: catFrameBox._cellH
                                                interactive: false
                                                clip: true
                                                visible: catFrames.length > 0
                                                model: catFrames

                                                delegate: FrameCard {
                                                    width: catGrid.cellWidth
                                                    height: catGrid.cellHeight
                                                    framePath: modelData.path
                                                    frameFile: modelData.fileName
                                                    frameMeta: modelData.metadata
                                                    selectModeOn: categorySelectMode
                                                    showCategoryTools: false
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    visible: root.getCategoryList().length === 0
                                    text: "Chưa có nhóm nào. Bấm \"+ Thêm nhóm\" để tạo."
                                    color: root.mutedText(0.65); font.pixelSize: 13
                                }
                            }
                        }
                    }
                }

                // Toolbar (ẩn khi bật chọn theo nhóm — đã có lưới con cho từng nhóm)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    visible: !frameManagerItem.categoryEnabled

                    Text {
                        text: frameManagerItem.selectMode
                              ? (frameManagerItem.selectedCount > 0 ? frameManagerItem.selectedCount + " đã chọn" : "Chọn khung hình")
                              : "Quản lý khung hình"
                        color: root.mutedText(0.65)
                        font.pixelSize: 15
                        Layout.fillWidth: true
                    }

                    PillButton {
                        text: "Chọn tất cả"
                        visible: frameManagerItem.selectMode
                        implicitWidth: 110
                        onClicked: frameManagerItem.selectAll()
                    }

                    PillButton {
                        text: "Xóa (" + frameManagerItem.selectedCount + ")"
                        filled: true; danger: true
                        visible: frameManagerItem.selectMode && frameManagerItem.selectedCount > 0
                        enabled: !root._frameBusy
                        onClicked: {
                            deleteConfirmPopup.pathsToDelete = Object.keys(frameManagerItem.selectedPaths)
                            deleteConfirmPopup.open()
                        }
                    }

                    PillButton {
                        text: frameManagerItem.selectMode ? "Hủy" : "Chọn"
                        danger: frameManagerItem.selectMode
                        implicitWidth: 70
                        onClicked: {
                            frameManagerItem.selectMode = !frameManagerItem.selectMode
                            if (!frameManagerItem.selectMode) frameManagerItem.clearSelection()
                        }
                    }

                    PillButton {
                        text: "+ Tải khung hình"
                        filled: true
                        visible: !frameManagerItem.selectMode
                        enabled: !root._frameBusy
                        onClicked: layoutUploadDialog.open()
                    }
                }

                // Grid (tất cả khung — ẩn khi bật chọn theo nhóm, dùng lưới con thay thế)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !frameManagerItem.categoryEnabled
                    color: "transparent"
                    radius: Theme.settingsRadiusMedium
                    border.color: Theme.settingsBorder
                    border.width: 1

                    GridView {
                        anchors.fill: parent
                        anchors.margins: 20
                        cellWidth: 190
                        cellHeight: 250
                        clip: true
                        model: layoutModel

                        delegate: FrameCard {
                            width: 190
                            height: 250
                            framePath: model.path
                            frameFile: model.fileName
                            frameMeta: model.metadata
                            selectModeOn: frameManagerItem.selectMode
                            showCategoryTools: true
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Không có khung hình, vui lòng tải lên"
                        color: root.mutedText(0.65)
                        visible: layoutModel.count === 0
                    }
                }
            }
        }
    }

    Component {
        id: backgroundsTabComponent
        Item {
            id: bgTabRoot
            property bool _paymentEnabled: eventManager.getAppSetting("payment_enabled", "false") === "true"
            // Bật "Chọn khung sau chụp" → luồng có các trang chọn khung/ghép/lọc/chờ
            // (không cần thanh toán) nên phần hình nền luồng chụp cũng cần hiện.
            property bool _frameSelectionEnabled: eventManager.getAppSetting("frame_selection_enabled", "true") === "true"
            property bool paperMode: root._operationMode === "modebao"
            // Chế độ 3 bỏ hẳn màn chọn cắt/không cắt (BoothSession._pushOperationStartScreen)
            // → ẩn thẻ nền + thumbnail tương ứng và đánh số lại các thẻ còn lại cho liền mạch.
            readonly property bool isMode3: root._operationMode === "mode3"
            property bool globalBgEnabled: {
                var refresh = root._bgRefreshCount
                return eventManager.getAppSetting("global_background_enabled", "false") === "true"
            }
            property string globalBgPath: {
                var refresh = root._bgRefreshCount
                return eventManager.getAppSetting("global_background_image", "")
            }

            // ── Thẻ hình nền gọn dùng chung trong lưới 2 cột ─────────────────────
            // keyName != "" → chế độ appSetting đơn giản (imgPath + Xoá tự xử lý).
            // keyName == "" → dùng customPath + signal clearRequested (thẻ đặc biệt).
            component BgCard: Rectangle {
                id: bc
                property int    cardIndex: -1     // >= 0 → hiện số thứ tự (badge); trang Landing là số 0
                property string title: ""
                property string caption: ""
                property string keyName: ""
                property string customPath: ""
                // Ảnh mặc định (qrc) hiển thị khi khách chưa tải ảnh riêng.
                property string defaultSource: ""
                property bool hasToggle: false
                property bool toggleChecked: false
                signal uploadRequested()
                signal clearRequested()
                signal toggledChanged(bool val)

                readonly property string _path: {
                    var d = root._bgRefreshCount
                    return keyName !== "" ? eventManager.getAppSetting(keyName, "") : customPath
                }
                readonly property string _previewSource: bc._path === "" ? bc.defaultSource : bc._path

                Layout.fillWidth: true
                Layout.preferredHeight: 256
                radius: 14
                color: "#16202e"
                border.color: (hasToggle && toggleChecked) ? "#1e7eea" : "#2d5a8c"
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Số thứ tự (index) — badge cho rõ vị trí trong luồng
                        Rectangle {
                            visible: bc.cardIndex >= 0
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignTop
                            radius: 8
                            color: "#1e7eea"
                            Text {
                                anchors.centerIn: parent
                                text: bc.cardIndex
                                color: "#ffffff"
                                font.pixelSize: 14; font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: bc.title
                                color: "#eaf2fb"
                                font.pixelSize: 15; font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: bc.caption
                                visible: bc.caption !== ""
                                color: "#93a7bd"
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }
                        }
                        Switch {
                            visible: bc.hasToggle
                            checked: bc.toggleChecked
                            // Giữ binding theo toggleChecked sau khi user bấm (tránh đứt
                            // binding khiến switch không phản ánh trạng thái thật).
                            onToggled: {
                                var v = checked
                                checked = Qt.binding(function() { return bc.toggleChecked })
                                bc.toggledChanged(v)
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 8
                        color: "#0e1620"
                        border.color: "#2d5a8c"
                        clip: true

                        BackgroundMedia {
                            anchors.fill: parent
                            anchors.margins: 2
                            sourcePath: bc._previewSource
                            imageFillMode: Image.PreserveAspectFit
                            videoFillMode: VideoOutput.PreserveAspectFit
                            visible: bc._previewSource !== ""
                        }
                        Text {
                            anchors.centerIn: parent
                            text: bc.defaultSource !== "" ? "Đang dùng ảnh mặc định" : "Chưa cài hình nền"
                            color: root.mutedText(0.55)
                            font.pixelSize: 12
                            visible: bc._path === ""
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Button {
                            text: "📁 Tải hình nền"
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            background: Rectangle { color: parent.hovered ? "#1e7eea" : "#1976d2"; radius: 6 }
                            contentItem: Text { text: parent.text; color: "#ffffff"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13; font.weight: Font.Medium }
                            onClicked: bc.uploadRequested()
                        }

                        Button {
                            text: "🗑️"
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 38
                            enabled: bc._path !== ""
                            background: Rectangle { color: parent.enabled ? (parent.hovered ? "#d32f2f" : "#c62828") : Theme.field; radius: 6 }
                            contentItem: Text { text: parent.text; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14 }
                            onClicked: {
                                if (bc.keyName !== "") { eventManager.setAppSetting(bc.keyName, ""); refreshBackgrounds() }
                                else bc.clearRequested()
                            }
                        }
                    }
                }
            }

            ScrollView {
                anchors.fill: parent
                contentWidth: parent.width
                clip: true

                ColumnLayout {
                    width: parent.width - 40
                    x: 20
                    spacing: 32

                    Text {
                        text: "Ảnh background"
                        color: root.themeTextColor
                        font.pixelSize: 24
                        font.weight: Font.Bold
                    }

                    Text {
                        text: "Tùy chỉnh hình nền cho các màn hình khác nhau trong trải nghiệm photobooth của bạn."
                        color: root.mutedText(0.65)
                        font.pixelSize: 15
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 74
                        visible: bgTabRoot.globalBgEnabled
                        radius: 14
                        color: "#FFF8ED"
                        border.color: "#E7C58B"
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 14
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Hình nền chung đang bật"; color: Theme.settingsText; font.pixelSize: 15; font.weight: Font.DemiBold }
                                Text { text: "Nền chung có thể ghi đè hình nền riêng của 5 màn bên dưới."; color: Theme.settingsTextMuted; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            }
                            Button {
                                text: "Tắt nền chung"
                                Layout.preferredWidth: 132; Layout.preferredHeight: 38
                                background: Rectangle { color: parent.hovered ? Theme.settingsCopperDark : Theme.settingsCopper; radius: 10 }
                                contentItem: Text { text: parent.text; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13; font.weight: Font.DemiBold }
                                onClicked: {
                                    eventManager.setAppSetting("global_background_enabled", "false")
                                    refreshBackgrounds()
                                    autoSavedToast.show("Đã tắt hình nền chung")
                                }
                            }
                        }
                    }

                    Text {
                        text: "Luồng hình nền đang dùng"
                        color: "#1e7eea"; font.pixelSize: 20; font.weight: Font.Bold
                    }
                    Text {
                        text: "Chỉ giữ các màn còn trong luồng hiện tại: Landing, Waiting, nhập mã, chụp ảnh và chờ kết quả."
                        color: root.mutedText(0.65); font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 920 ? 2 : 1
                        columnSpacing: 18
                        rowSpacing: 18

                        BgCard {
                            cardIndex: 1
                            title: "Index / Landing Page"
                            caption: "Màn chào đầu tiên khi máy sẵn sàng"
                            customPath: { var d = root._bgRefreshCount; return eventManager.getGlobalLandingBackground() }
                            defaultSource: "qrc:/assets/1.png"
                            onUploadRequested: landingBackgroundDialog.open()
                            onClearRequested: { eventManager.setGlobalLandingBackground(""); refreshBackgrounds() }
                        }
                        BgCard { cardIndex: 2; title: "Waiting";         caption: "Màn chạm để bắt đầu phiên"; keyName: "waiting_bg_image";         defaultSource: "qrc:/assets/2.png"; onUploadRequested: waitingPageBackgroundDialog.open() }
                        BgCard { cardIndex: 3; title: "Enter Code";      caption: "Màn nhập mã / voucher";     keyName: "enter_code_bg_image";     onUploadRequested: enterCodeBackgroundDialog.open() }
                        BgCard { cardIndex: 4; title: "Capture Screen";  caption: "Màn live view và đếm ngược"; keyName: "capture_bg_image";        defaultSource: "qrc:/assets/4.png"; onUploadRequested: captureBackgroundDialog.open() }
                        BgCard { cardIndex: 5; title: "Waiting Results"; caption: "Màn xử lý ảnh sau khi chụp"; keyName: "waiting_results_bg_image"; onUploadRequested: waitingResultsBackgroundDialog.open() }
                    }

                    // ═══════════════════════════════════════════════════════════
                    // HÌNH NỀN — bố cục lưới 2 cột, sắp theo luồng app
                    // ═══════════════════════════════════════════════════════════

                    // ── Nhóm: Hình nền chung ────────────────────────────────────
                    Text {
                        visible: false
                        text: "Hình nền chung"
                        color: "#1e7eea"; font.pixelSize: 20; font.weight: Font.Bold
                    }
                    GridLayout {
                        visible: false
                        Layout.fillWidth: true
                        columns: 3; columnSpacing: 18; rowSpacing: 18

                        BgCard {
                            title: "Hình nền chung"
                            caption: "Áp dụng cho mọi màn hình (ưu tiên hơn nền riêng)"
                            hasToggle: true
                            toggleChecked: bgTabRoot.globalBgEnabled
                            customPath: bgTabRoot.globalBgPath
                            onUploadRequested: globalBackgroundDialog.open()
                            onClearRequested: {
                                eventManager.setAppSetting("global_background_enabled", "false")
                                eventManager.setAppSetting("global_background_image", "")
                                refreshBackgrounds()
                                autoSavedToast.show("Đã xóa hình nền chung")
                            }
                            onToggledChanged: (val) => {
                                if (val === bgTabRoot.globalBgEnabled) return
                                if (val && bgTabRoot.globalBgPath === "") { globalBackgroundDialog.open(); return }
                                if (eventManager.setAppSetting("global_background_enabled", val ? "true" : "false")) {
                                    refreshBackgrounds()
                                    autoSavedToast.show(val ? "Đã bật hình nền chung" : "Đã tắt hình nền chung")
                                }
                            }
                        }

                    }

                    // ── Nhóm: Luồng chụp (theo thứ tự app) ──────────────────────
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: false

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                        Text {
                            text: "Luồng chụp (theo thứ tự sử dụng)"
                            color: "#1e7eea"; font.pixelSize: 20; font.weight: Font.Bold
                        }
                        Text {
                            text: "Các hình nền sau áp dụng cho luồng chụp (khi bật Chọn khung sau chụp hoặc Thanh toán)."
                            color: root.mutedText(0.65); font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3; columnSpacing: 18; rowSpacing: 18

                            // Trang Landing đứng trước cả Trang chờ trong luồng → đánh số 0.
                            BgCard {
                                cardIndex: 0
                                title: "Trang đầu (Landing)"
                                caption: "Trang chào khi khởi động máy"
                                customPath: { var d = root._bgRefreshCount; return eventManager.getGlobalLandingBackground() }
                                onUploadRequested: landingBackgroundDialog.open()
                                onClearRequested: { eventManager.setGlobalLandingBackground(""); refreshBackgrounds() }
                            }
                            BgCard { cardIndex: 1; title: "Trang chờ";              caption: "Trang chạm để bắt đầu phiên";      keyName: "waiting_bg_image";           onUploadRequested: waitingPageBackgroundDialog.open() }
                            BgCard { cardIndex: 2; title: "Chọn loại ảnh";          caption: "Trang chọn ảnh cắt / không cắt";   keyName: "cutmode_bg_image";           visible: !bgTabRoot.isMode3; defaultSource: "qrc:/assets/bg/cut_mode.png"; onUploadRequested: cutModeBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 2 : 3;  title: "Chọn khung hình";        caption: "Trang chọn layout khung hình";     keyName: "layout_selection_bg_image";  onUploadRequested: layoutSelectionBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 3 : 4;  title: "Chọn số lượng in";       caption: "Trang chọn số bản / số ảnh in";    keyName: "print_quantity_bg_image";    defaultSource: "qrc:/assets/bg/print_quantity.png"; onUploadRequested: printQuantityBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 4 : 5;  title: "Phương thức thanh toán"; caption: "Trang chọn cách thanh toán";       keyName: "payment_method_bg_image";    onUploadRequested: paymentMethodBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 5 : 6;  title: "Thanh toán tiền mặt";    caption: "Trang nhận tiền mặt qua máy đọc";  keyName: "cash_payment_bg_image";      onUploadRequested: cashPaymentBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 6 : 7;  title: "Thanh toán QR";          caption: "Trang quét QR / chuyển khoản";     keyName: "payment_bg_image";           onUploadRequested: paymentBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 7 : 8;  title: "Ghép ảnh";               caption: "Trang ghép & chỉnh ảnh vào khung"; keyName: "photo_composition_bg_image"; onUploadRequested: photoCompositionBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 8 : 9;  title: "Bộ lọc";                 caption: "Trang chọn bộ lọc màu";            keyName: "filter_screen_bg_image";     onUploadRequested: filterScreenBackgroundDialog.open() }
                            BgCard { cardIndex: bgTabRoot.isMode3 ? 9 : 10; title: "Kết quả";                caption: "Trang hiển thị ảnh & QR tải về";   keyName: "result_bg_image";            onUploadRequested: resultBackgroundDialog.open() }
                        }

                        // ── Số layout đại diện hiển thị trên màn chọn khung ─────────
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 96
                            radius: 14
                            color: "#16202e"
                            border.color: "#2d5a8c"
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        text: "Số layout đại diện trên màn chọn khung"
                                        color: "#eaf2fb"
                                        font.pixelSize: 15; font.bold: true
                                    }
                                    Text {
                                        text: "Số khung hiển thị cùng lúc khi bật thanh toán. Khung đang chọn luôn ở giữa."
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }

                                ComboBox {
                                    id: layoutPreviewCountCombo
                                    Layout.preferredWidth: 220
                                    Layout.preferredHeight: 40

                                    property string currentSetting: {
                                        var d = root._bgRefreshCount
                                        return eventManager.getAppSetting("layout_preview_count", "0")
                                    }

                                    model: ListModel {
                                        ListElement { text: "Tắt (mặc định)"; value: "0" }
                                        ListElement { text: "3 layout";  value: "3" }
                                        ListElement { text: "5 layout";  value: "5" }
                                        ListElement { text: "7 layout";  value: "7" }
                                        ListElement { text: "11 layout"; value: "11" }
                                        ListElement { text: "13 layout"; value: "13" }
                                        ListElement { text: "15 layout"; value: "15" }
                                    }

                                    textRole: "text"
                                    valueRole: "value"

                                    Component.onCompleted: {
                                        for (var i = 0; i < model.count; i++) {
                                            if (model.get(i).value === currentSetting) {
                                                currentIndex = i
                                                break
                                            }
                                        }
                                    }

                                    onActivated: {
                                        var val = model.get(currentIndex).value
                                        eventManager.setAppSetting("layout_preview_count", val)
                                        autoSavedToast.show("Đã lưu số layout hiển thị")
                                    }

                                    background: Rectangle {
                                        color: "#0e1620"; radius: 6
                                        border.color: "#2d5a8c"; border.width: 1
                                    }
                                    contentItem: Text {
                                        text: layoutPreviewCountCombo.displayText
                                        color: "#eaf2fb"; font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter; leftPadding: 14
                                    }
                                    popup: Popup {
                                        y: layoutPreviewCountCombo.height + 4
                                        width: layoutPreviewCountCombo.width
                                        implicitHeight: contentItem.implicitHeight; padding: 1
                                        contentItem: ListView {
                                            clip: true; implicitHeight: contentHeight
                                            model: layoutPreviewCountCombo.popup.visible ? layoutPreviewCountCombo.delegateModel : null
                                            currentIndex: layoutPreviewCountCombo.highlightedIndex
                                            boundsBehavior: Flickable.StopAtBounds
                                        }
                                        background: Rectangle { color: "#16202e"; border.color: "#2d5a8c"; radius: 6 }
                                    }
                                }
                            }
                        }
                    }

                    // ── Nhóm: Thumbnail kiểu cắt (chế độ 3 không hỏi cắt/không cắt) ──
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 16
                        visible: false

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

                        Text {
                            text: "Thumbnail kiểu cắt"
                            color: "#1e7eea"; font.pixelSize: 20; font.weight: Font.Bold
                        }

                        GridLayout {
                            Layout.fillWidth: true
                            columns: 3; columnSpacing: 18; rowSpacing: 18

                            BgCard { title: "Thumbnail ảnh cắt";       caption: "Ảnh minh hoạ kiểu ảnh cắt";        keyName: "cutmode_thumbnail_cut";          defaultSource: "qrc:/assets/bg/thumb_cut.png";        onUploadRequested: cutModeThumbnailCutDialog.open() }
                            BgCard { title: "Thumbnail ảnh không cắt"; caption: "Ảnh minh hoạ kiểu không cắt";      keyName: "cutmode_thumbnail_nocut";        defaultSource: "qrc:/assets/bg/thumb_nocut.png";      onUploadRequested: cutModeThumbnailNoCutDialog.open() }
                        }
                    }
                    // ── End payment screen backgrounds ───────────────────────────────────

                    // Tips Section
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: tipsCol.implicitHeight + 40
                        color: "#1c2a3f"
                        radius: 8
                        border.color: "#1e7eea"
                        border.width: 1

                        ColumnLayout {
                            id: tipsCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 8

                            Text {
                                text: "💡 Mẹo cho ảnh đẹp"
                                color: "#1e7eea"
                                font.pixelSize: 15
                                font.weight: Font.Bold
                            }

                            Text {
                                text: "• Dùng độ phân giải cao\n• Hỗ trợ ảnh: PNG, JPG, JPEG\n•"
                                color: root.mutedText(0.65)
                                font.pixelSize: 13
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                lineHeight: 1.4
                            }
                        }
                    }

                    Item { Layout.fillWidth: true; Layout.preferredHeight: 40 }
                }
            }
        }
    }

    Component {
        id: accountTabComponent
        Item {
            id: accountTabRoot
            property bool showSecrets: false
            // Yêu cầu đăng nhập bật → mới hiện quản lý nhân viên & bảo mật nhân viên
            property bool loginEnabled: eventManager.getAppSetting("login_required", "true") === "true"
            property bool appOpenSecurityEnabled: eventManager.getAppSetting("app_open_security_enabled", "false") === "true"
            property bool settingsSecurityEnabled: eventManager.getAppSetting("security_enabled", "false") === "true"
            readonly property bool lockEnabled: appOpenSecurityEnabled || settingsSecurityEnabled || loginEnabled
            // Luôn dùng bảo mật bằng mã; giữ property để migrate máy từng chọn QR/both về pin.
            property string securityMethod: eventManager.securityMethod()

            // Phân quyền nhân viên: danh mục quyền + bản đồ id → [key,...] dựng từ getEmployees().
            readonly property var permCatalog: eventManager.employeePermissionCatalog()
            property var empPermMap: ({})

            // ── Lựa chọn in đã cài (mỗi phần tử: { qty, price, discount }) ───────
            property var optionsCut:   []
            property var optionsNoCut: []
            property bool option4CutEnabled:   false
            property bool option4NoCutEnabled: false

            readonly property string _defCutJson:   '[{"qty":2,"price":0,"discount":0},{"qty":4,"price":0,"discount":0},{"qty":6,"price":0,"discount":0},{"qty":8,"price":0,"discount":0},{"qty":10,"price":0,"discount":0}]'
            readonly property string _defNoCutJson: '[{"qty":1,"price":0,"discount":0},{"qty":2,"price":0,"discount":0},{"qty":3,"price":0,"discount":0},{"qty":4,"price":0,"discount":0},{"qty":5,"price":0,"discount":0}]'

            function _loadOptions(key, defJson) {
                var arr = []
                try { arr = JSON.parse(eventManager.getAppSetting(key, defJson)) }
                catch (e) { arr = JSON.parse(defJson) }
                if (!Array.isArray(arr)) arr = JSON.parse(defJson)
                // Bảo đảm luôn có đủ 5 phần tử để chỉnh sửa (4 cố định + ô thứ 5 bật thêm)
                var defArr = JSON.parse(defJson)
                while (arr.length < 5)
                    arr.push(arr.length < defArr.length ? defArr[arr.length] : { qty: 1, price: 0, discount: 0 })
                return arr.slice(0, 5).map(function(o) {
                    return {
                        qty: parseInt(o.qty, 10) || 0,
                        price: parseInt(o.price, 10) || 0,
                        discount: parseInt(o.discount, 10) || 0
                    }
                })
            }

            // Cập nhật 1 trường của 1 lựa chọn rồi lưu xuống DB
            function _saveOption(isCut, index, field, value) {
                // Dựng lại mảng bằng object literal MỚI (mutation-proof) — tránh lưu nhầm 0đ.
                var src = isCut ? optionsCut : optionsNoCut
                var arr = []
                for (var i = 0; i < src.length; i++) {
                    var q = parseInt(src[i].qty, 10) || 0
                    var p = parseInt(src[i].price, 10) || 0
                    var d = parseInt(src[i].discount, 10) || 0
                    if (i === index) {
                        if (field === "qty") q = parseInt(value, 10) || 0
                        else if (field === "price") p = parseInt(value, 10) || 0
                        else d = parseInt(value, 10) || 0
                    }
                    arr.push({ qty: q, price: p, discount: d })
                }
                var key = isCut ? "print_options_cut" : "print_options_nocut"
                var ok = eventManager.setAppSetting(key, JSON.stringify(arr))
                // gán lại để trigger binding
                if (isCut) optionsCut = arr
                else       optionsNoCut = arr
                autoSavedToast.show(ok ? "Đã lưu Lựa Chọn In" : "Lưu thất bại — thử lại")
            }

            Component.onCompleted: {
                optionsCut         = _loadOptions("print_options_cut",   _defCutJson)
                optionsNoCut       = _loadOptions("print_options_nocut", _defNoCutJson)
                option4CutEnabled  = eventManager.getAppSetting("print_option4_cut_enabled",   "false") === "true"
                option4NoCutEnabled = eventManager.getAppSetting("print_option4_nocut_enabled", "false") === "true"
                if (accountTabRoot.securityMethod !== "pin") {
                    accountTabRoot.securityMethod = "pin"
                    eventManager.setSecurityMethod("pin")
                }
                // Làm mới staff cloud → sync (do handler onStudioInfoChanged ở root) → reload danh sách.
                if (machineAuth.hwid) qrLoginManager.fetchStudioInfo(machineAuth.hwid)
            }

            // Khi staff cloud vừa được đồng bộ (studio-info về), nạp lại danh sách nhân viên.
            Connections {
                target: qrLoginManager
                function onStudioInfoChanged() { employeeModel.reload() }
            }

            // ── Một dòng cài đặt lựa chọn in (số lượng + giá) ─────────────────────
            component PrintOptionRow: RowLayout {
                Layout.fillWidth: true
                spacing: 12

                property bool isCut: false
                property int  optIndex: 0
                property int  qty: 0
                property int  price: 0
                property int  discount: 0
                property bool isOption4: false
                property bool option4On: false

                // chỉ dòng thứ 5 mới có công tắc + cho phép tắt
                property bool rowEnabled: !isOption4 || option4On

                // Khe chứa công tắc lựa chọn thứ 5 — luôn chiếm chỗ cố định để các dòng thẳng hàng
                Item {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 24
                    Layout.alignment: Qt.AlignVCenter

                    // Công tắc bật/tắt, chỉ hiện ở dòng thứ 5
                    Switch {
                        id: option4Switch
                        anchors.centerIn: parent
                        visible: isOption4
                        checked: option4On
                        onToggled: {
                            var key = isCut ? "print_option4_cut_enabled" : "print_option4_nocut_enabled"
                            eventManager.setAppSetting(key, checked ? "true" : "false")
                            if (isCut) accountTabRoot.option4CutEnabled = checked
                            else       accountTabRoot.option4NoCutEnabled = checked
                            autoSavedToast.show(checked ? "Đã bật lựa chọn 5" : "Đã tắt lựa chọn 5")
                        }
                        indicator: Rectangle {
                            implicitWidth: 44; implicitHeight: 24; radius: 12
                            color: option4Switch.checked ? "#22c55e" : Theme.border
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Rectangle {
                                x: option4Switch.checked ? parent.width - width - 3 : 3
                                y: 3; width: 18; height: 18; radius: 9; color: "#FFFFFF"
                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Số lượng (ảnh in)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                    TextField {
                        Layout.fillWidth: true
                        enabled: rowEnabled
                        opacity: rowEnabled ? 1.0 : 0.4
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: qty.toString()
                        onEditingFinished: accountTabRoot._saveOption(isCut, optIndex, "qty", text)
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Giá tiền (₫)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                    TextField {
                        Layout.fillWidth: true
                        enabled: rowEnabled
                        opacity: rowEnabled ? 1.0 : 0.4
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: price.toString()
                        onEditingFinished: accountTabRoot._saveOption(isCut, optIndex, "price", text)
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: 1
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "Giảm giá (₫)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                    TextField {
                        Layout.fillWidth: true
                        enabled: rowEnabled
                        opacity: rowEnabled ? 1.0 : 0.4
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: discount.toString()
                        onEditingFinished: accountTabRoot._saveOption(isCut, optIndex, "discount", text)
                    }
                }
            }

            ScrollView {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentWidth: availableWidth
                contentHeight: accountScrollContent.implicitHeight
                clip: true
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                id: accountScrollContent
                width: parent.width - 80
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 24

                Item { height: 20 }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: pinCommonCol.implicitHeight + 34
                    radius: Theme.settingsRadiusLarge
                    color: Theme.settingsCard
                    border.color: Theme.settingsBorder
                    border.width: 1

                    ColumnLayout {
                        id: pinCommonCol
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 14

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 46
                                Layout.preferredHeight: 46
                                radius: 14
                                color: Theme.settingsCopperSoft
                                SettingsIcon { anchors.centerIn: parent; width: 22; height: 22; name: "account"; color: Theme.settingsCopper }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text { Layout.fillWidth: true; text: "Khóa mở app"; color: Theme.settingsText; font.pixelSize: 18; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: "Bật thì mở app và vào Cài đặt đều yêu cầu nhập mã. Tắt thì cả hai đều mở thẳng."; color: Theme.settingsTextMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                            }

                            Rectangle {
                                Layout.preferredWidth: statusLabel.implicitWidth + 22
                                Layout.preferredHeight: 30
                                radius: 15
                                color: accountTabRoot.lockEnabled
                                       ? Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.12)
                                       : Theme.settingsCanvas
                                border.color: accountTabRoot.lockEnabled
                                              ? Qt.rgba(Theme.settingsSuccess.r, Theme.settingsSuccess.g, Theme.settingsSuccess.b, 0.28)
                                              : Theme.settingsBorder
                                Text {
                                    id: statusLabel
                                    anchors.centerIn: parent
                                    text: accountTabRoot.lockEnabled ? "Đang bật" : "Đang tắt"
                                    color: accountTabRoot.lockEnabled ? Theme.settingsSuccess : Theme.settingsTextMuted
                                    font.pixelSize: 12
                                    font.weight: Font.DemiBold
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.settingsBorder }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Text { Layout.fillWidth: true; text: "Khóa mở app"; color: Theme.settingsText; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: "Dùng cùng mã cho màn mở app và trang Cài đặt"; color: Theme.settingsTextMuted; font.pixelSize: 11; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }

                            Switch {
                                checked: accountTabRoot.lockEnabled
                                onToggled: {
                                    var next = checked
                                    accountTabRoot.appOpenSecurityEnabled = next
                                    accountTabRoot.settingsSecurityEnabled = next
                                    accountTabRoot.loginEnabled = false
                                    eventManager.setAppSetting("app_open_security_enabled", next ? "true" : "false")
                                    eventManager.setAppSetting("security_enabled", next ? "true" : "false")
                                    eventManager.setAppSetting("login_required", "false")
                                    autoSavedToast.show(next ? "Đã bật khóa mở app" : "Đã tắt khóa mở app")
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.settingsBorder }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            TextField {
                                id: accountCurrentPinField; Layout.fillWidth: true; Layout.preferredHeight: 44
                                placeholderText: "Mật khẩu hiện tại"; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 6
                                color: Theme.settingsText; leftPadding: 12
                                background: Rectangle { color: Theme.settingsSurface; radius: 10; border.color: parent.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                            }
                            TextField {
                                id: accountNewPinField; Layout.fillWidth: true; Layout.preferredHeight: 44
                                placeholderText: "Mật khẩu mới"; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 6
                                color: Theme.settingsText; leftPadding: 12
                                background: Rectangle { color: Theme.settingsSurface; radius: 10; border.color: parent.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                            }
                            TextField {
                                id: accountConfirmPinField; Layout.fillWidth: true; Layout.preferredHeight: 44
                                placeholderText: "Xác nhận mật khẩu mới"; echoMode: TextInput.Password; inputMethodHints: Qt.ImhDigitsOnly; maximumLength: 6
                                color: Theme.settingsText; leftPadding: 12
                                background: Rectangle { color: Theme.settingsSurface; radius: 10; border.color: parent.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                            }
                            Button {
                                text: "Lưu"
                                enabled: accountCurrentPinField.text.trim().length > 0
                                         && accountNewPinField.text.trim().length > 0
                                         && accountConfirmPinField.text.trim().length > 0
                                Layout.preferredWidth: 110; Layout.preferredHeight: 44
                                background: Rectangle { color: parent.enabled ? Theme.settingsCopper : Theme.settingsBorder; radius: 10 }
                                contentItem: Text { text: parent.text; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.weight: Font.DemiBold }
                                onClicked: {
                                    var current = accountCurrentPinField.text.trim()
                                    var next = accountNewPinField.text.trim()
                                    var confirm = accountConfirmPinField.text.trim()
                                    if (!/^[0-9]{4,6}$/.test(current)) {
                                        autoSavedToast.show("Mật khẩu hiện tại phải gồm 4-6 chữ số")
                                        return
                                    }
                                    if (!/^[0-9]{4,6}$/.test(next)) {
                                        autoSavedToast.show("Mật khẩu mới phải gồm 4-6 chữ số")
                                        return
                                    }
                                    if (next !== confirm) {
                                        autoSavedToast.show("Mật khẩu xác nhận không khớp")
                                        return
                                    }
                                    var err = eventManager.setSecurityPin(current, next)
                                    if (err && err.length > 0) {
                                        autoSavedToast.show(err)
                                        return
                                    }
                                    accountCurrentPinField.text = ""; accountNewPinField.text = ""; accountConfirmPinField.text = ""
                                    autoSavedToast.show("Đã cập nhật mật khẩu bảo mật")
                                }
                            }
                        }
                        Text {
                            visible: accountNewPinField.text !== "" && accountConfirmPinField.text !== ""
                                     && accountNewPinField.text.trim() !== accountConfirmPinField.text.trim()
                            text: "Mật khẩu xác nhận không khớp"
                            color: Theme.settingsDanger; font.pixelSize: 12
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.settingsBorder }

                // ── Quản lý nhân viên ──────────────────────────────────────────
                Text { text: "Tài Khoản Nhân Viên"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold
                       visible: accountTabRoot.loginEnabled }

                Rectangle {
                    Layout.fillWidth: true
                    height: 62; radius: 8
                    visible: accountTabRoot.loginEnabled && eventManager.isAdmin
                    color: "transparent"; border.color: "#2d5a8c"; border.width: 1

                    RowLayout {
                        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 14 }
                        spacing: 12

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text { text: "Tài khoản Admin"; color: root.themeTextColor; font.pixelSize: 15; font.bold: true }
                            Text { text: "Đổi mật khẩu đăng nhập root/admin"; color: root.mutedText(0.65); font.pixelSize: 13 }
                        }

                        Rectangle {
                            Layout.preferredWidth: 170; height: 36; radius: 7
                            color: adminPwMa.containsMouse ? "#2a8bff" : "#1e7eea"
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "Đổi mật khẩu Admin"; color: "#ffffff"; font.pixelSize: 13 }
                            MouseArea {
                                id: adminPwMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: adminPwDialog.open()
                            }
                        }
                    }
                }

                ListModel { id: employeeModel
                    function reload() {
                        var list = eventManager.getEmployees()
                        clear()
                        var m = {}
                        for (var i = 0; i < list.length; i++) {
                            append({ id: list[i].id, full_name: list[i].full_name,
                                     prefix: list[i].prefix, created_at: list[i].created_at,
                                     source: list[i].source || "local",
                                     cloud_email: list[i].cloud_email || "" })
                            m[list[i].id] = list[i].permissions || []
                        }
                        accountTabRoot.empPermMap = m
                    }
                    Component.onCompleted: reload()
                }

                Text {
                    Layout.fillWidth: true
                    visible: accountTabRoot.loginEnabled && !eventManager.isAdmin
                    text: "Chỉ admin (đăng nhập root) mới quản lý được nhân viên. Bạn có thể đổi mật khẩu của chính mình bên dưới."
                    color: "#f0a040"; font.pixelSize: 14; wrapMode: Text.WordWrap
                }

                // Thêm nhân viên (chỉ admin)
                RowLayout {
                    Layout.fillWidth: true
                    visible: accountTabRoot.loginEnabled && eventManager.isAdmin
                    spacing: 10

                    TextField {
                        id: newEmpName
                        Layout.fillWidth: true
                        color: root.themeTextColor; leftPadding: 12
                        placeholderText: "Họ và tên nhân viên mới"
                        background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                    }
                    Rectangle {
                        Layout.preferredWidth: 150; height: 42; radius: 8
                        color: addEmpMa.pressed ? "#1565c0" : (addEmpMa.containsMouse ? "#1a6fd0" : "#1e7eea")
                        Behavior on color { ColorAnimation { duration: 100 } }
                        Text { anchors.centerIn: parent; text: "+ Thêm (mk 0000)"; color: "#fff"; font.pixelSize: 14; font.bold: true }
                        MouseArea {
                            id: addEmpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                var err = eventManager.createEmployee(newEmpName.text, "0000")
                                if (err === "") {
                                    newEmpName.text = ""
                                    employeeModel.reload()
                                    autoSavedToast.show("Đã thêm nhân viên (mật khẩu mặc định 0000)")
                                } else {
                                    autoSavedToast.show(err)
                                }
                            }
                        }
                    }
                }

                // Danh sách nhân viên
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: accountTabRoot.loginEnabled
                    spacing: 8

                    Repeater {
                        model: employeeModel
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            height: 52; radius: 8
                            color: "transparent"; border.color: "#2d5a8c"; border.width: 1

                            RowLayout {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 12 }
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true; spacing: 2
                                    RowLayout {
                                        spacing: 8
                                        Text { text: model.full_name; color: root.themeTextColor; font.pixelSize: 15; font.bold: true }
                                        // Badge nguồn cloud — nhân viên do studio thêm ở Cổng khách hàng.
                                        Rectangle {
                                            visible: model.source === "cloud"
                                            Layout.preferredWidth: cloudBadge.implicitWidth + 16; height: 20; radius: 10
                                            color: "#123a2a"; border.color: "#22c55e"; border.width: 1
                                            Text { id: cloudBadge; anchors.centerIn: parent; text: "Cloud"; color: "#6ee7a5"; font.pixelSize: 11; font.bold: true }
                                        }
                                    }
                                    Text {
                                        text: model.source === "cloud" && model.cloud_email
                                              ? model.cloud_email : "Nhân viên tạo mã (theo tên)"
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                }

                                // Phân quyền (chỉ admin)
                                Rectangle {
                                    Layout.preferredWidth: 110; height: 34; radius: 7
                                    visible: eventManager.isAdmin
                                    color: permMa.containsMouse ? "#3a6a45" : "transparent"
                                    border.color: "#3f7058"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "Phân quyền"; color: "#8fe0ad"; font.pixelSize: 13 }
                                    MouseArea {
                                        id: permMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { empPermDialog.empId = model.id; empPermDialog.empName = model.full_name; empPermDialog.open() }
                                    }
                                }

                                // Đổi mật khẩu
                                Rectangle {
                                    Layout.preferredWidth: 120; height: 34; radius: 7
                                    color: pwMa.containsMouse ? "#2a8bff" : "#1e7eea"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "Đổi mật khẩu"; color: "#ffffff"; font.pixelSize: 13 }
                                    MouseArea {
                                        id: pwMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: { empPwDialog.empId = model.id; empPwDialog.empName = model.full_name; empPwDialog.open() }
                                    }
                                }

                                // Xóa (chỉ admin) — ẩn với nhân viên cloud vì lần sync sau sẽ tạo lại.
                                Rectangle {
                                    Layout.preferredWidth: 70; height: 34; radius: 7
                                    visible: eventManager.isAdmin && model.source !== "cloud"
                                    color: delEmpMa.containsMouse ? "#8b2020" : "transparent"
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "Xóa"; color: "#ef9a9a"; font.pixelSize: 13 }
                                    MouseArea {
                                        id: delEmpMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            eventManager.deleteEmployee(model.id)
                                            employeeModel.reload()
                                            autoSavedToast.show("Đã xóa nhân viên")
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: employeeModel.count === 0
                        text: "Chưa có nhân viên nào. Thêm nhân viên để cấp dãy mã voucher riêng."
                        color: root.mutedText(0.65); font.pixelSize: 14
                    }
                }

                // Dialog đổi mật khẩu nhân viên
                Dialog {
                    id: empPwDialog
                    property int empId: -1
                    property string empName: ""
                    modal: true
                    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                    anchors.centerIn: Overlay.overlay
                    width: 420
                    padding: 20
                    title: "Đổi mật khẩu: " + empName
                    standardButtons: Dialog.Save | Dialog.Cancel
                    onOpened: empPwField.text = ""
                    contentItem: ColumnLayout {
                        spacing: 10
                        Text { text: "Mật khẩu mới (để trống = 0000)"; color: root.mutedText(0.65); font.pixelSize: 14 }
                        TextField {
                            id: empPwField
                            Layout.fillWidth: true
                            color: root.themeTextColor; leftPadding: 12
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        }
                    }
                    onAccepted: {
                        eventManager.setEmployeePassword(empPwDialog.empId, empPwField.text)
                        autoSavedToast.show("Đã đổi mật khẩu nhân viên")
                    }
                }

                // Dialog phân quyền nhân viên (chỉ admin)
                Dialog {
                    id: empPermDialog
                    property int empId: -1
                    property string empName: ""
                    modal: true
                    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                    anchors.centerIn: Overlay.overlay
                    width: 460
                    padding: 20
                    title: "Phân quyền: " + empName
                    standardButtons: Dialog.Save | Dialog.Cancel
                    // Reset trạng thái tick theo quyền hiện tại của nhân viên (delegate được
                    // tái sử dụng giữa các lần mở → phải gán lại imperatively, không dựa binding).
                    onOpened: {
                        var have = accountTabRoot.empPermMap[empPermDialog.empId] || []
                        for (var i = 0; i < contentItem.children.length; i++) {
                            var c = contentItem.children[i]
                            if (c && c.permKey !== undefined)
                                c.checked = have.indexOf(c.permKey) >= 0
                        }
                    }
                    contentItem: ColumnLayout {
                        spacing: 12
                        Text {
                            Layout.fillWidth: true
                            text: "Tick những chức năng nhân viên này được phép sử dụng."
                            color: root.mutedText(0.65); font.pixelSize: 14; wrapMode: Text.WordWrap
                        }
                        Repeater {
                            model: accountTabRoot.permCatalog
                            delegate: CheckBox {
                                Layout.fillWidth: true
                                text: modelData.label
                                property string permKey: modelData.key
                                contentItem: Text {
                                    text: modelData.label; color: root.themeTextColor; font.pixelSize: 14
                                    leftPadding: parent.indicator.width + 8; verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }
                    onAccepted: {
                        var keys = []
                        for (var i = 0; i < contentItem.children.length; i++) {
                            var c = contentItem.children[i]
                            if (c && c.permKey !== undefined && c.checked) keys.push(c.permKey)
                        }
                        eventManager.setEmployeePermissions(empPermDialog.empId, keys)
                        employeeModel.reload()
                        autoSavedToast.show("Đã cập nhật phân quyền nhân viên")
                    }
                }

                // ── Bảo mật nhân viên (chỉ admin thấy, và chỉ khi bật đăng nhập) ─
                Dialog {
                    id: adminPwDialog
                    modal: true
                    Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                    anchors.centerIn: Overlay.overlay
                    width: 440
                    padding: 20
                    title: "Đổi mật khẩu Admin"
                    standardButtons: Dialog.Save | Dialog.Cancel
                    onOpened: {
                        adminPwCurrentField.text = ""
                        adminPwField.text = ""
                        adminPwConfirmField.text = ""
                        adminPwCurrentField.forceActiveFocus()
                    }
                    contentItem: ColumnLayout {
                        spacing: 10
                        Text {
                            Layout.fillWidth: true
                            text: "Mật khẩu Admin dùng chung với mật khẩu bảo mật mở app và vào Cài đặt."
                            color: root.mutedText(0.65); font.pixelSize: 14; wrapMode: Text.WordWrap
                        }
                        TextField {
                            id: adminPwCurrentField
                            Layout.fillWidth: true
                            color: root.themeTextColor; leftPadding: 12
                            placeholderText: "Mật khẩu hiện tại"
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        }
                        TextField {
                            id: adminPwField
                            Layout.fillWidth: true
                            color: root.themeTextColor; leftPadding: 12
                            placeholderText: "Mật khẩu mới (4-6 chữ số)"
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        }
                        TextField {
                            id: adminPwConfirmField
                            Layout.fillWidth: true
                            color: root.themeTextColor; leftPadding: 12
                            placeholderText: "Xác nhận mật khẩu mới"
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhDigitsOnly
                            background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                            onAccepted: adminPwDialog.accept()
                        }
                    }
                    onAccepted: {
                        var pin = adminPwField.text.trim()
                        if (!/^[0-9]{4,6}$/.test(pin)) {
                            autoSavedToast.show("Mật khẩu Admin phải gồm 4-6 chữ số")
                            adminPwDialog.open()
                            return
                        }
                        if (pin !== adminPwConfirmField.text.trim()) {
                            autoSavedToast.show("Xác nhận mật khẩu Admin chưa khớp")
                            adminPwDialog.open()
                            return
                        }
                        var error = eventManager.setSecurityPin(adminPwCurrentField.text.trim(), pin)
                        if (error !== "") {
                            autoSavedToast.show(error)
                            adminPwDialog.open()
                            return
                        }
                        autoSavedToast.show("Đã đổi mật khẩu Admin")
                    }
                }

                Item { height: 12; visible: eventManager.isAdmin && accountTabRoot.loginEnabled }
                Rectangle { Layout.fillWidth: true; height: 1; color: "transparent"; visible: eventManager.isAdmin && accountTabRoot.loginEnabled }
                Item { height: 8; visible: eventManager.isAdmin && accountTabRoot.loginEnabled }

                Text {
                    visible: eventManager.isAdmin && accountTabRoot.loginEnabled
                    text: "Bảo Mật Nhân Viên"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold
                }
                Text {
                    visible: eventManager.isAdmin && accountTabRoot.loginEnabled
                    Layout.fillWidth: true
                    text: "Tick vào mục mà nhân viên cần nhập mật khẩu mới được vào. Mục không tick thì nhân viên vào tự do."
                    color: root.mutedText(0.65); font.pixelSize: 14; wrapMode: Text.WordWrap
                }

                // Mật khẩu khóa mục (mặc định 0000)
                RowLayout {
                    visible: eventManager.isAdmin && accountTabRoot.loginEnabled
                    Layout.fillWidth: true; spacing: 10
                    Text { text: "Mật khẩu mở khóa:"; color: root.mutedText(0.65); font.pixelSize: 15; Layout.preferredWidth: 150 }
                    TextField {
                        id: staffLockPinField
                        Layout.preferredWidth: 200
                        color: root.themeTextColor; leftPadding: 12
                        inputMethodHints: Qt.ImhDigitsOnly
                        text: eventManager.getAppSetting("staff_lock_pin", "0000")
                        background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        onEditingFinished: {
                            var v = text.trim()
                            if (v === "") v = "0000"
                            eventManager.setAppSetting("staff_lock_pin", v)
                            autoSavedToast.show("Đã lưu mật khẩu bảo mật")
                        }
                    }
                }

                // Danh sách tab + checkbox khóa
                ColumnLayout {
                    visible: eventManager.isAdmin && accountTabRoot.loginEnabled
                    Layout.fillWidth: true; spacing: 6

                    Repeater {
                        model: sidebarModel
                        delegate: Rectangle {
                            id: lockRow
                            Layout.fillWidth: true
                            height: 44; radius: 8
                            color: "transparent"; border.color: "#2d5a8c"; border.width: 1

                            property int tabIndex: index
                            property bool locked: {
                                var arr = root._lockedTabs
                                for (var i = 0; i < arr.length; i++) if (arr[i] === lockRow.tabIndex) return true
                                return false
                            }

                            RowLayout {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 14; rightMargin: 14 }
                                spacing: 12

                                SettingsIcon {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    name: model.iconName || "settings"
                                    color: root.themeTextColor
                                }
                                Text { text: model.name; color: root.themeTextColor; font.pixelSize: 15; Layout.fillWidth: true }
                                Text {
                                    text: lockRow.locked ? "🔒 Cần mật khẩu" : "Mở tự do"
                                    color: lockRow.locked ? "#f0a040" : "#6a6d78"; font.pixelSize: 13
                                }

                                // Checkbox khóa
                                Rectangle {
                                    width: 28; height: 28; radius: 6
                                    color: lockRow.locked ? "#1e7eea" : "#FFFFFF"
                                    border.color: lockRow.locked ? "#1e7eea" : "#2d5a8c"; border.width: 2
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "✓"; color: root.themeTextColor; font.pixelSize: 16; font.bold: true; visible: lockRow.locked }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var arr = root._lockedTabs.slice()
                                            var pos = arr.indexOf(lockRow.tabIndex)
                                            if (pos >= 0) arr.splice(pos, 1)
                                            else arr.push(lockRow.tabIndex)
                                            root._lockedTabs = arr
                                            eventManager.setAppSetting("staff_locked_tabs", JSON.stringify(arr))
                                            autoSavedToast.show("Đã cập nhật bảo mật mục")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item { height: 12; visible: accountTabRoot.loginEnabled }
                Rectangle { Layout.fillWidth: true; height: 1; color: "transparent"; visible: accountTabRoot.loginEnabled }
                Item { height: 8; visible: accountTabRoot.loginEnabled }

                Text { text: "Cấu Hình AWS"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Mã Truy cập "; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        id: accessKeyField
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: s3Uploader.getAccessKey()
                        echoMode: accountTabRoot.showSecrets ? TextInput.Normal : TextInput.Password
                        onEditingFinished: {
                            s3Uploader.saveCredentials(accessKeyField.text, secretKeyField.text)
                            autoSavedToast.show("AWS credentials đã lưu")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Mã Bí Mật"; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        id: secretKeyField
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: s3Uploader.getSecretKey()
                        echoMode: accountTabRoot.showSecrets ? TextInput.Normal : TextInput.Password
                        onEditingFinished: {
                            s3Uploader.saveCredentials(accessKeyField.text, secretKeyField.text)
                            autoSavedToast.show("AWS credentials đã lưu")
                        }
                    }
                }

                // Các control thanh toán cũ được giữ lại để tương thích binding,
                // nhưng không còn tham gia giao diện tab Tài khoản.
                ColumnLayout {
                    visible: false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 0

                Item { height: 20 }
                Text { text: "Cấu Hình Thanh Toán Seepay"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Mã Ngân Hàng (Bank ID / BIN)"; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: eventManager.getAppSetting("payment_bank_id", "")
                        onEditingFinished: {
                            eventManager.setAppSetting("payment_bank_id", text)
                            autoSavedToast.show("Đã lưu Mã Ngân Hàng")
                        }
                    }
                }
                
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Số Tài Khoản"; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: eventManager.getAppSetting("payment_account_no", "")
                        onEditingFinished: {
                            eventManager.setAppSetting("payment_account_no", text)
                            autoSavedToast.show("Đã lưu Số Tài Khoản")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "Chủ Tài Khoản"; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: eventManager.getAppSetting("payment_account_name", "")
                        onEditingFinished: {
                            eventManager.setAppSetting("payment_account_name", text)
                            autoSavedToast.show("Đã lưu Chủ Tài Khoản")
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text { text: "API Key Seepay"; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: eventManager.getAppSetting("payment_sepay_key", "")
                        echoMode: accountTabRoot.showSecrets ? TextInput.Normal : TextInput.Password
                        onEditingFinished: {
                            eventManager.setAppSetting("payment_sepay_key", text)
                            autoSavedToast.show("Đã lưu API Key Seepay")
                        }
                    }
                }

                // ── Toggle tài khoản ảo (VA) ──────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    height: 64; radius: 12
                    color: "transparent"
                    border.color: vaToggle.checked ? "#22c55e" : Theme.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text {
                                text: "Dùng tài khoản ảo (VA)"
                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                            }
                            Text {
                                text: vaToggle.checked
                                      ? "QR & chuyển khoản dùng số VA do SePay cấp"
                                      : "Dùng số tài khoản chính (mặc định)"
                                color: vaToggle.checked ? "#4ade80" : root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Switch {
                            id: vaToggle
                            checked: eventManager.getAppSetting("payment_va_enabled", "false") === "true"
                            onCheckedChanged: {
                                eventManager.setAppSetting("payment_va_enabled", checked ? "true" : "false")
                                autoSavedToast.show(checked ? "Đã bật tài khoản ảo (VA)" : "Đã tắt tài khoản ảo (VA)")
                            }

                            indicator: Rectangle {
                                implicitWidth: 52; implicitHeight: 28; radius: 14
                                color: vaToggle.checked ? "#22c55e" : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    x: vaToggle.checked ? parent.width - width - 4 : 4
                                    y: 4; width: 20; height: 20; radius: 10
                                    color: "transparent"
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }

                // ── Số tài khoản ảo (VA) — chỉ hiện khi bật VA ────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: vaToggle.checked
                    Text { text: "Số Tài Khoản Ảo (VA)"; color: root.mutedText(0.65); font.pixelSize: 15 }
                    TextField {
                        Layout.fillWidth: true
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; border.color: activeFocus ? "#1e7eea" : Theme.border; radius: 6; height: 40 }
                        leftPadding: 12
                        text: eventManager.getAppSetting("payment_va_account_no", "")
                        onEditingFinished: {
                            eventManager.setAppSetting("payment_va_account_no", text)
                            autoSavedToast.show("Đã lưu Số Tài Khoản Ảo (VA)")
                        }
                    }
                }

                Item { height: 20 }
                Text { text: "Cài Đặt Lựa Chọn In"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold }
                Text {
                    text: "Cài sẵn số lượng & giá tiền cho từng lựa chọn in. Trang chọn số lượng sẽ hiển thị đúng giá đã cài."
                    color: root.mutedText(0.65); font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true
                }

                // ── Nhóm Dạng Cắt ────────────────────────────────────────────
                Text { text: "✂ Dạng Cắt"; color: "#4caf50"; font.pixelSize: 16; font.bold: true }
                Repeater {
                    model: accountTabRoot.optionsCut.length
                    delegate: PrintOptionRow {
                        required property int index
                        isCut: true
                        optIndex: index
                        qty:   accountTabRoot.optionsCut[index].qty
                        price: accountTabRoot.optionsCut[index].price
                        discount: accountTabRoot.optionsCut[index].discount
                        isOption4: index === 4
                        option4On: accountTabRoot.option4CutEnabled
                    }
                }

                Item { height: 8 }

                // ── Nhóm Dạng Không Cắt ──────────────────────────────────────
                Text { text: "🖼 Dạng Không Cắt"; color: "#ff9800"; font.pixelSize: 16; font.bold: true }
                Repeater {
                    model: accountTabRoot.optionsNoCut.length
                    delegate: PrintOptionRow {
                        required property int index
                        isCut: false
                        optIndex: index
                        qty:   accountTabRoot.optionsNoCut[index].qty
                        price: accountTabRoot.optionsNoCut[index].price
                        discount: accountTabRoot.optionsNoCut[index].discount
                        isOption4: index === 4
                        option4On: accountTabRoot.option4NoCutEnabled
                    }
                }

                Item { height: 20 }

                // ── Toggle thanh toán tiền mặt ────────────────────────────────
                Text { text: "Phương Thức Thanh Toán"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold }

                Rectangle {
                    Layout.fillWidth: true
                    height: 64; radius: 12
                    color: "transparent"
                    border.color: bankTransferToggle.checked ? "#4FA4F2" : Theme.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text {
                                text: "Cho phép thanh toán chuyển khoản"
                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                            }
                            Text {
                                text: bankTransferToggle.checked
                                      ? "Hiển thị nút Chuyển Khoản / QR tại trang chọn phương thức"
                                      : "Ẩn nút Chuyển Khoản / QR, chỉ dùng phương thức còn bật"
                                color: bankTransferToggle.checked ? "#7fb8f0" : root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Switch {
                            id: bankTransferToggle
                            checked: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
                            onCheckedChanged: {
                                eventManager.setAppSetting("bank_transfer_enabled", checked ? "true" : "false")
                                if (!checked && eventManager.getAppSetting("cash_payment_enabled", "false") !== "true") {
                                    eventManager.setAppSetting("cash_payment_enabled", "true")
                                    Qt.callLater(function() { cashToggle.checked = true })
                                    autoSavedToast.show("Đã tắt chuyển khoản và bật tiền mặt")
                                } else {
                                    autoSavedToast.show(checked ? "Đã bật thanh toán chuyển khoản" : "Đã tắt thanh toán chuyển khoản")
                                }
                            }

                            indicator: Rectangle {
                                implicitWidth: 52; implicitHeight: 28; radius: 14
                                color: bankTransferToggle.checked ? "#4FA4F2" : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    x: bankTransferToggle.checked ? parent.width - width - 4 : 4
                                    y: 4; width: 20; height: 20; radius: 10
                                    color: "transparent"
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 64; radius: 12
                    color: "transparent"
                    border.color: cashToggle.checked ? "#22c55e" : Theme.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text {
                                text: "Cho phép thanh toán tiền mặt"
                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                            }
                            Text {
                                text: cashToggle.checked
                                      ? "Người dùng có thể chọn tiền mặt hoặc QR"
                                      : "Chỉ thanh toán qua QR (mặc định)"
                                color: cashToggle.checked ? "#4ade80" : root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Switch {
                            id: cashToggle
                            checked: eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
                            onCheckedChanged: {
                                eventManager.setAppSetting("cash_payment_enabled", checked ? "true" : "false")
                                if (!checked) {
                                    cashCodeToggle.checked = false
                                    eventManager.setAppSetting("cash_payment_code_enabled", "false")
                                    if (!bankTransferToggle.checked)
                                        bankTransferToggle.checked = true
                                }
                                autoSavedToast.show(checked ? "Đã bật thanh toán tiền mặt" : "Đã tắt thanh toán tiền mặt")
                            }

                            indicator: Rectangle {
                                implicitWidth: 52; implicitHeight: 28; radius: 14
                                color: cashToggle.checked ? "#22c55e" : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    x: cashToggle.checked ? parent.width - width - 4 : 4
                                    y: 4; width: 20; height: 20; radius: 10
                                    color: "transparent"
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 64; radius: 12
                    visible: cashToggle.checked
                    color: "transparent"
                    border.color: cashCodeToggle.checked ? "#22c55e" : Theme.border
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16; spacing: 14

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 3
                            Text {
                                text: "Bật thanh toán tiền mặt bằng mã"
                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                            }
                            Text {
                                text: cashCodeToggle.checked
                                      ? "Khách đưa tiền cho nhân viên rồi nhập mã 4 số trên màn hình"
                                      : "Dùng đầu đọc tiền mặt khi có kết nối"
                                color: cashCodeToggle.checked ? "#4ade80" : root.mutedText(0.65)
                                font.pixelSize: 13
                            }
                        }

                        Switch {
                            id: cashCodeToggle
                            checked: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"
                            onCheckedChanged: {
                                eventManager.setAppSetting("cash_payment_code_enabled", checked ? "true" : "false")
                                autoSavedToast.show(checked ? "Đã bật thanh toán bằng mã" : "Đã tắt thanh toán bằng mã")
                            }

                            indicator: Rectangle {
                                implicitWidth: 52; implicitHeight: 28; radius: 14
                                color: cashCodeToggle.checked ? "#22c55e" : Theme.border
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    x: cashCodeToggle.checked ? parent.width - width - 4 : 4
                                    y: 4; width: 20; height: 20; radius: 10
                                    color: "transparent"
                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                }
                            }
                        }
                    }
                }

                Item { height: 20 }
                Text { text: "Cấu Hình Máy Đọc Tiền"; color: root.themeTextColor; font.pixelSize: 24; font.weight: Font.Bold }

                // Status badge
                Rectangle {
                    Layout.fillWidth: true
                    height: 52; radius: 10
                    color: billAcceptor.connected ? "#123a6f" : "#1e7eea"
                    border.color: billAcceptor.connected ? "#22c55e" : "#2a8bff"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10
                        Rectangle {
                            width: 10; height: 10; radius: 5
                            color: billAcceptor.connected ? "#22c55e" : "#ffffff"
                            SequentialAnimation on opacity {
                                running: billAcceptor.connected
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.3; duration: 700 }
                                NumberAnimation { to: 1.0; duration: 700 }
                            }
                        }
                        Text {
                            text: billAcceptor.connected
                                  ? "Máy đọc tiền đang kết nối — " + billAcceptor.portName
                                  : "Máy đọc tiền chưa kết nối"
                            color: "#ffffff"
                            font.pixelSize: 15
                            Layout.fillWidth: true
                        }
                    }
                }

                // COM port selector + connect button
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    ComboBox {
                        id: comPortCombo
                        Layout.fillWidth: true
                        model: root._comPorts
                        currentIndex: {
                            var saved = eventManager.getAppSetting("bill_acceptor_port", "")
                            var idx = find(saved)
                            return idx >= 0 ? idx : 0
                        }
                        font.pixelSize: 15
                        background: Rectangle {
                            color: "transparent"; border.color: parent.activeFocus ? "#1e7eea" : Theme.border
                            radius: 6; height: 40
                        }
                        contentItem: Text {
                            text: parent.displayText; color: root.themeTextColor
                            verticalAlignment: Text.AlignVCenter; leftPadding: 12
                            font: parent.font
                        }
                    }

                    // Nút Làm mới danh sách COM
                    Button {
                        text: "🔄"
                        width: 44; height: 40
                        ToolTip.visible: hovered; ToolTip.text: "Làm mới danh sách cổng"
                        background: Rectangle {
                            color: parent.hovered ? "#2a8bff" : "#1e7eea"
                            radius: 6; border.color: "#2d5a8c"; border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text; color: root.themeTextColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 18
                        }
                        onClicked: {
                            var ports = billAcceptor.availablePorts()
                            root._comPorts = ports.length > 0 ? ports : ["(Không tìm thấy cổng COM)"]
                        }
                    }

                    // Kết nối / Ngắt kết nối
                    Button {
                        text: billAcceptor.connected ? "Ngắt kết nối" : "Kết nối"
                        width: 130; height: 40
                        background: Rectangle {
                            color: billAcceptor.connected
                                   ? (parent.hovered ? "#7a1a1a" : "#5a1515")
                                   : (parent.hovered ? "#1565c0" : "#0d47a1")
                            radius: 6
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        contentItem: Text {
                            text: parent.text; color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        onClicked: {
                            if (billAcceptor.connected) {
                                billAcceptor.closePort()
                                eventManager.setAppSetting("bill_acceptor_port", "")
                                autoSavedToast.show("Đã ngắt kết nối máy đọc tiền")
                            } else {
                                var port = comPortCombo.currentText
                                if (port === "(Không tìm thấy cổng COM)" || port === "") return
                                if (billAcceptor.openPort(port)) {
                                    eventManager.setAppSetting("bill_acceptor_port", port)
                                    autoSavedToast.show("Đã kết nối máy đọc tiền: " + port)
                                } else {
                                    autoSavedToast.show("Không thể kết nối cổng " + port)
                                }
                            }
                        }
                    }
                }

                // Bảng mệnh giá
                Text {
                    text: "Mệnh giá hỗ trợ: 10.000 ₫ · 20.000 ₫ · 50.000 ₫ · 100.000 ₫ · 200.000 ₫ · 500.000 ₫"
                    color: "#5a6070"; font.pixelSize: 13
                    Layout.fillWidth: true; wrapMode: Text.WordWrap
                }
                }

                RowLayout {
                    spacing: 20

                    Button {
                        text: accountTabRoot.showSecrets ? "Ẩn mã" : "Hiển thị mã"
                        background: Rectangle {
                            color: parent.hovered ? "#2a8bff" : "#1e7eea"
                            radius: 6
                            border.color: "#2d5a8c"
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 14
                        }
                        onClicked: {
                            if (accountTabRoot.showSecrets) {
                                accountTabRoot.showSecrets = false
                            } else {
                                authDialog.open()
                            }
                        }
                    }

                    // Auto-save indicator – thay thế nút "Lưu Cấu hình"
                    Rectangle {
                        height: 36
                        width: 160
                        radius: 6
                        color: "transparent"
                        border.color: "#2d6a2d"; border.width: 1

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "⚡"; font.pixelSize: 15 }
                            Text {
                                text: "Tự động lưu"
                                color: root.themeTextColor; font.pixelSize: 14; font.bold: true
                            }
                        }
                    }
                }

                Popup {
                    id: authDialog
                    // Chiều cao bàn phím quy về design coordinates (chia cho scale)
                    property real _vkH: {
                        if (!Qt.inputMethod.visible) return 0
                        var scale = Window.window ? Window.window._contentScale : 1.0
                        if (scale <= 0) scale = 1.0
                        return Qt.inputMethod.keyboardRectangle.height / scale
                    }
                    x: (parent.width - width) / 2
                    // Khi bàn phím hiện -> đẩy dialog lên trên bàn phím; nếu không thì căn giữa.
                    y: Math.max(16, Math.min((parent.height - height) / 2,
                                             parent.height - _vkH - height - 16))
                    Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                    width: 480
                    height: authContent.implicitHeight
                    modal: true
                    Overlay.modal: Rectangle { color: "#99060A12" }
                    focus: true
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
                    padding: 0

                    background: Rectangle {
                        radius: 24
                        clip: true
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop { position: 0.0; color: "#172033" }
                            GradientStop { position: 0.55; color: "#101622" }
                            GradientStop { position: 1.0; color: "#080b12" }
                        }
                        border.color: errorText.visible ? "#ff4422" : "#46658d"
                        border.width: 2

                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            height: 6
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "#1e7eea" }
                                GradientStop { position: 0.55; color: "#d6a84f" }
                                GradientStop { position: 1.0; color: "#ad436d" }
                            }
                        }
                    }

                    onOpened: {
                        passwordField.text = ""
                        errorText.visible = false
                        passwordField.forceActiveFocus()
                    }
                    onClosed: Qt.inputMethod.hide()

                    ColumnLayout {
                        id: authContent
                        anchors.fill: parent
                        anchors.margins: 34
                        spacing: 16

                        Rectangle {
                            Layout.preferredWidth: 72
                            Layout.preferredHeight: 72
                            Layout.alignment: Qt.AlignHCenter
                            radius: 24
                            color: "#122a4d"
                            border.color: "#4FA4F2"
                            border.width: 1
                            Text { anchors.centerIn: parent; text: "🔐"; font.pixelSize: 34 }
                        }

                        Text {
                            text: "Xác thực bảo mật"
                            color: "#ffffff"
                            font.bold: true
                            font.pixelSize: 24
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Text {
                            text: errorText.visible ? "Mã không chính xác, vui lòng thử lại." : "Nhập mã admin để hiển thị thông tin nhạy cảm."
                            color: errorText.visible ? "#ff7a5f" : "#a8b6cc"
                            font.pixelSize: 14
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                        }

                        TextField {
                            id: passwordField
                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            echoMode: TextInput.Password
                            inputMethodHints: Qt.ImhDigitsOnly
                            horizontalAlignment: Text.AlignHCenter
                            placeholderText: "Nhập mã admin"
                            color: "#ffffff"
                            font.pixelSize: 22
                            font.letterSpacing: 6
                            background: Rectangle {
                                color: "#090f18"
                                radius: 16
                                border.color: passwordField.activeFocus
                                              ? (errorText.visible ? "#ff4422" : "#d6a84f")
                                              : "#344258"
                                border.width: passwordField.activeFocus ? 2 : 1
                            }
                            onAccepted: {
                                if (passwordField.text === "1234") {
                                    accountTabRoot.showSecrets = true
                                    authDialog.close()
                                } else {
                                    errorText.visible = true
                                    passwordField.text = ""
                                }
                            }
                        }

                        Text {
                            id: errorText
                            text: ""
                            visible: false
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight
                            spacing: 10

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 54
                                radius: 17
                                color: authCancelMa.containsMouse ? "#2e1a1a" : "#111827"
                                border.color: "#aa3322"
                                border.width: 1
                                Text { anchors.centerIn: parent; text: "Hủy"; color: "#ff6644"; font.pixelSize: 16; font.bold: true }
                                MouseArea { id: authCancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: authDialog.close() }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 54
                                radius: 17
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: authOkMa.containsMouse ? "#2f8cf0" : "#1e7eea" }
                                    GradientStop { position: 1.0; color: authOkMa.containsMouse ? "#c14f78" : "#ad436d" }
                                }
                                Text { anchors.centerIn: parent; text: "Mở khóa"; color: "#ffffff"; font.pixelSize: 16; font.bold: true }
                                MouseArea {
                                    id: authOkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                    if (passwordField.text === "1234") {
                                        accountTabRoot.showSecrets = true
                                        authDialog.close()
                                    } else {
                                        errorText.visible = true
                                        passwordField.text = ""
                                    }
                                }
                                }
                            }
                        }
                    }
                }

                Popup {
                    id: savedPopup
                    x: (parent.width - width) / 2
                    y: parent.height - 100
                    width: 200
                    height: 50
                    modal: false
                    focus: false
                    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                    background: Rectangle {
                        color: "#00AA00"
                        radius: 25
                    }

                    onOpened: saveTimer.start()

                    Text {
                        anchors.centerIn: parent
                        text: "Đã Lưu Cài Đặt!"
                        color: root.themeTextColor
                        font.bold: true
                    }

                    Timer {
                        id: saveTimer
                        interval: 2000
                        onTriggered: savedPopup.close()
                    }
                }

                Item { height: 20 }
            } // ColumnLayout
            } // ScrollView

            // Virtual Keyboard được xử lý bởi globalInputPanel trong main.qml
        }
    }

    // ── Voucher Tab Component ────────────────────────────────────────────────
    // Payment settings are kept in their own tab so Account only contains access,
    // employee security and AWS credentials.
    Component {
        id: paymentTabComponent

        Item {
            id: paymentTabRoot
            property bool showSecrets: false
            readonly property color inputBlue: "#123A6F"
            readonly property color inputBlueFocus: "#4FA4F2"
            property var optionsCut: []
            property var optionsNoCut: []
            property bool option4CutEnabled: false
            property bool option4NoCutEnabled: false
            // Bật → tính tiền theo giá nhóm khung (category); ô giá theo số lượng bị khoá.
            property bool _pricingByCategory: false

            readonly property string _defCutJson: '[{"qty":2,"price":0,"discount":0},{"qty":4,"price":0,"discount":0},{"qty":6,"price":0,"discount":0},{"qty":8,"price":0,"discount":0},{"qty":10,"price":0,"discount":0}]'
            readonly property string _defNoCutJson: '[{"qty":1,"price":0,"discount":0},{"qty":2,"price":0,"discount":0},{"qty":3,"price":0,"discount":0},{"qty":4,"price":0,"discount":0},{"qty":5,"price":0,"discount":0}]'

            function _loadOptions(key, defJson) {
                var arr = []
                try { arr = JSON.parse(eventManager.getAppSetting(key, defJson)) }
                catch (e) { arr = JSON.parse(defJson) }
                if (!Array.isArray(arr)) arr = JSON.parse(defJson)
                var defArr = JSON.parse(defJson)
                while (arr.length < 5)
                    arr.push(arr.length < defArr.length ? defArr[arr.length] : { qty: 1, price: 0, discount: 0 })
                return arr.slice(0, 5).map(function(o) {
                    return {
                        qty: parseInt(o.qty, 10) || 0,
                        price: parseInt(o.price, 10) || 0,
                        discount: parseInt(o.discount, 10) || 0
                    }
                })
            }

            function _saveOption(isCut, index, field, value) {
                // Dựng lại mảng bằng object literal MỚI thay vì sửa tại chỗ
                // optionsCut[index][field] — với property var, optionsCut[i] có thể
                // trả về bản sao nên mutate tại chỗ không vào JSON.stringify → lưu nhầm 0đ.
                var src = isCut ? optionsCut : optionsNoCut
                var arr = []
                for (var i = 0; i < src.length; i++) {
                    var q = parseInt(src[i].qty, 10) || 0
                    var p = parseInt(src[i].price, 10) || 0
                    var d = parseInt(src[i].discount, 10) || 0
                    if (i === index) {
                        if (field === "qty") q = parseInt(value, 10) || 0
                        else if (field === "price") p = parseInt(value, 10) || 0
                        else d = parseInt(value, 10) || 0
                    }
                    arr.push({ qty: q, price: p, discount: d })
                }
                var ok = eventManager.setAppSetting(isCut ? "print_options_cut" : "print_options_nocut",
                                                    JSON.stringify(arr))
                if (isCut) optionsCut = arr
                else       optionsNoCut = arr
                autoSavedToast.show(ok ? "Đã lưu lựa chọn in" : "Lưu thất bại — thử lại")
            }

            Component.onCompleted: {
                optionsCut = _loadOptions("print_options_cut", _defCutJson)
                optionsNoCut = _loadOptions("print_options_nocut", _defNoCutJson)
                option4CutEnabled = eventManager.getAppSetting("print_option4_cut_enabled", "false") === "true"
                option4NoCutEnabled = eventManager.getAppSetting("print_option4_nocut_enabled", "false") === "true"
                _pricingByCategory = eventManager.getAppSetting("pricing_by_category_enabled", "false") === "true"
            }

            component PaymentGroup: Rectangle {
                default property alias contentData: groupBody.data
                implicitHeight: groupBody.implicitHeight + 32
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                color: "transparent"
                radius: 14
                border.color: root.themeBorderColor
                border.width: 1

                ColumnLayout {
                    id: groupBody
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                }
            }

            component PaymentToggleRow: Rectangle {
                id: toggleRow
                property string title: ""
                property string description: ""
                property bool checked: false
                property color accent: "#2E8B65"
                signal changedByUser(bool next)

                Layout.fillWidth: true
                implicitHeight: 72
                color: "transparent"
                radius: 10
                border.color: checked ? accent : root.themeBorderColor
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            text: toggleRow.title; color: root.themeTextColor
                            font.pixelSize: 14; font.weight: Font.DemiBold
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                        Text {
                            text: toggleRow.description; color: root.mutedText(0.65)
                            font.pixelSize: 11; Layout.fillWidth: true
                            wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
                        }
                    }
                    Switch {
                        id: rowSwitch
                        checked: toggleRow.checked
                        onToggled: {
                            toggleRow.checked = checked
                            toggleRow.changedByUser(checked)
                        }
                        indicator: Rectangle {
                            implicitWidth: 48; implicitHeight: 26; radius: 13
                            color: rowSwitch.checked ? toggleRow.accent : Theme.border
                            Rectangle {
                                x: rowSwitch.checked ? parent.width - width - 3 : 3
                                y: 3; width: 20; height: 20; radius: 10; color: "#FFFFFF"
                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
                            }
                        }
                    }
                }
            }

            component PaymentPrintOptionRow: RowLayout {
                property bool isCut: false
                property int optIndex: 0
                property int qty: 0
                property int price: 0
                property int discount: 0
                property bool isOption4: false
                property bool option4On: false
                property bool rowEnabled: !isOption4 || option4On
                // Khoá ô giá khi đang tính theo giá nhóm khung; giảm giá vẫn chỉnh được.
                property bool priceLocked: false
                Layout.fillWidth: true
                spacing: 8

                Item {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 24
                    Switch {
                        id: option4Switch
                        anchors.centerIn: parent
                        visible: isOption4
                        checked: option4On
                        onToggled: {
                            var key = isCut ? "print_option4_cut_enabled" : "print_option4_nocut_enabled"
                            eventManager.setAppSetting(key, checked ? "true" : "false")
                            if (isCut) paymentTabRoot.option4CutEnabled = checked
                            else paymentTabRoot.option4NoCutEnabled = checked
                            autoSavedToast.show(checked ? "Đã bật lựa chọn 5" : "Đã tắt lựa chọn 5")
                        }
                        indicator: Rectangle {
                            implicitWidth: 40; implicitHeight: 22; radius: 11
                            color: option4Switch.checked ? "#22c55e" : Theme.border
                            Rectangle {
                                x: option4Switch.checked ? parent.width - width - 3 : 3
                                y: 3; width: 16; height: 16; radius: 8; color: "#FFFFFF"
                                Behavior on x { NumberAnimation { duration: 140 } }
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: "Số lượng"; color: root.mutedText(0.65); font.pixelSize: 11 }
                    TextField {
                        Layout.fillWidth: true; enabled: rowEnabled; opacity: rowEnabled ? 1 : 0.4
                        text: qty.toString(); color: "#FFFFFF"
                        selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                        inputMethodHints: Qt.ImhDigitsOnly; leftPadding: 10
                        background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                        onEditingFinished: paymentTabRoot._saveOption(isCut, optIndex, "qty", text)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: "Giá tiền (₫)"; color: root.mutedText(0.65); font.pixelSize: 11 }
                    TextField {
                        Layout.fillWidth: true
                        enabled: rowEnabled && !priceLocked
                        opacity: (rowEnabled && !priceLocked) ? 1 : 0.4
                        text: price.toString(); color: "#FFFFFF"
                        selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                        inputMethodHints: Qt.ImhDigitsOnly; leftPadding: 10
                        background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                        onEditingFinished: paymentTabRoot._saveOption(isCut, optIndex, "price", text)
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    Text { text: "Giảm giá (₫)"; color: root.mutedText(0.65); font.pixelSize: 11 }
                    TextField {
                        Layout.fillWidth: true
                        enabled: rowEnabled
                        opacity: rowEnabled ? 1 : 0.4
                        text: discount.toString(); color: "#FFFFFF"
                        selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                        inputMethodHints: Qt.ImhDigitsOnly; leftPadding: 10
                        background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                        onEditingFinished: paymentTabRoot._saveOption(isCut, optIndex, "discount", text)
                    }
                }
            }

            ScrollView {
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                GridLayout {
                    width: parent.width - 32
                    anchors.horizontalCenter: parent.horizontalCenter
                    columns: width >= 1000 ? 2 : 1
                    columnSpacing: 16
                    rowSpacing: 16

                    PaymentGroup {
                        Text {
                            text: "Tài khoản ngân hàng / SePay"
                            color: root.themeTextColor; font.pixelSize: 19; font.weight: Font.DemiBold
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width >= 620 ? 2 : 1
                            columnSpacing: 12; rowSpacing: 10

                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 4
                                Text { text: "Mã ngân hàng (Bank ID / BIN)"; color: root.mutedText(0.65); font.pixelSize: 12 }
                                TextField {
                                    Layout.fillWidth: true; color: "#FFFFFF"; leftPadding: 10
                                    selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                                    text: eventManager.getAppSetting("payment_bank_id", "")
                                    background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                                    onEditingFinished: {
                                        eventManager.setAppSetting("payment_bank_id", text.trim())
                                        autoSavedToast.show("Đã lưu mã ngân hàng")
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 4
                                Text { text: "Số tài khoản"; color: root.mutedText(0.65); font.pixelSize: 12 }
                                TextField {
                                    Layout.fillWidth: true; color: "#FFFFFF"; leftPadding: 10
                                    selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                                    text: eventManager.getAppSetting("payment_account_no", "")
                                    background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                                    onEditingFinished: {
                                        eventManager.setAppSetting("payment_account_no", text.trim())
                                        autoSavedToast.show("Đã lưu số tài khoản")
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 4
                                Text { text: "Chủ tài khoản"; color: root.mutedText(0.65); font.pixelSize: 12 }
                                TextField {
                                    Layout.fillWidth: true; color: "#FFFFFF"; leftPadding: 10
                                    selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                                    text: eventManager.getAppSetting("payment_account_name", "")
                                    background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                                    onEditingFinished: {
                                        eventManager.setAppSetting("payment_account_name", text.trim())
                                        autoSavedToast.show("Đã lưu chủ tài khoản")
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 4
                                Text { text: "API Key SePay"; color: root.mutedText(0.65); font.pixelSize: 12 }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                    TextField {
                                        Layout.fillWidth: true; color: "#FFFFFF"; leftPadding: 10
                                        selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                                        text: eventManager.getAppSetting("payment_sepay_key", "")
                                        echoMode: paymentTabRoot.showSecrets ? TextInput.Normal : TextInput.Password
                                        background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                                        onEditingFinished: {
                                            eventManager.setAppSetting("payment_sepay_key", text)
                                            autoSavedToast.show("Đã lưu API Key SePay")
                                        }
                                    }
                                    Button {
                                        text: paymentTabRoot.showSecrets ? "Ẩn" : "Hiện"
                                        Layout.preferredWidth: 62
                                        background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: paymentTabRoot.inputBlueFocus }
                                        contentItem: Text { text: parent.text; color: "#FFFFFF"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                        onClicked: {
                                            if (paymentTabRoot.showSecrets) paymentTabRoot.showSecrets = false
                                            else paymentAuthDialog.open()
                                        }
                                    }
                                }
                            }
                        }
                        PaymentToggleRow {
                            id: paymentVaRow
                            title: "Dùng tài khoản ảo (VA)"
                            description: checked ? "QR dùng số VA do SePay cấp" : "Dùng số tài khoản chính"
                            checked: eventManager.getAppSetting("payment_va_enabled", "false") === "true"
                            onChangedByUser: function(next) {
                                eventManager.setAppSetting("payment_va_enabled", next ? "true" : "false")
                                autoSavedToast.show(next ? "Đã bật tài khoản ảo" : "Đã tắt tài khoản ảo")
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; visible: paymentVaRow.checked; spacing: 4
                            Text { text: "Số tài khoản ảo (VA)"; color: root.mutedText(0.65); font.pixelSize: 12 }
                            TextField {
                                Layout.fillWidth: true; color: "#FFFFFF"; leftPadding: 10
                                selectedTextColor: "#FFFFFF"; selectionColor: "#2A8BFF"
                                text: eventManager.getAppSetting("payment_va_account_no", "")
                                background: Rectangle { color: paymentTabRoot.inputBlue; radius: 7; border.color: parent.activeFocus ? paymentTabRoot.inputBlueFocus : "#285A91" }
                                onEditingFinished: {
                                    eventManager.setAppSetting("payment_va_account_no", text.trim())
                                    autoSavedToast.show("Đã lưu số tài khoản VA")
                                }
                            }
                        }
                    }

                    PaymentGroup {
                        Text {
                            text: "Giá theo số lượng ảnh in"
                            color: root.themeTextColor; font.pixelSize: 19; font.weight: Font.DemiBold
                        }
                        Text {
                            text: "Cài số lượng ảnh in, giá tiền và giảm giá cho trang chọn số lượng in. Khi bật giá khung frame, giá lấy từ nhóm frame và giảm giá vẫn áp dụng theo từng lựa chọn."
                            color: root.mutedText(0.65); font.pixelSize: 12
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                        PaymentToggleRow {
                            title: "Thanh toán theo giá khung frame"
                            description: checked ? "Tổng = giá nhóm khung × số bản in - giảm giá"
                                                 : "Tổng lấy theo giá cố định của số lượng ảnh in bên dưới"
                            accent: "#C58A33"
                            checked: paymentTabRoot._pricingByCategory
                            onChangedByUser: function(next) {
                                paymentTabRoot._pricingByCategory = next
                                eventManager.setAppSetting("pricing_by_category_enabled", next ? "true" : "false")
                                autoSavedToast.show(next ? "Đã bật: thanh toán theo giá khung frame"
                                                         : "Đã tắt: quay lại tính theo số lượng in")
                            }
                        }
                        Text {
                            visible: paymentTabRoot._pricingByCategory
                            text: "Giá frame được đặt trong tab Khung frame theo từng nhóm. Ô giá tiền bên dưới bị khóa; số lượng và giảm giá vẫn chỉnh được."
                            color: "#C58A33"; font.pixelSize: 12
                            Layout.fillWidth: true; wrapMode: Text.WordWrap
                        }
                        GridLayout {
                            Layout.fillWidth: true
                            columns: width >= 700 ? 2 : 1
                            columnSpacing: 16; rowSpacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 8
                                Text { text: "Ảnh cắt 5x15"; color: "#22c55e"; font.pixelSize: 14; font.bold: true }
                                Repeater {
                                    model: paymentTabRoot.optionsCut.length
                                    delegate: PaymentPrintOptionRow {
                                        required property int index
                                        isCut: true; optIndex: index
                                        qty: paymentTabRoot.optionsCut[index].qty
                                        price: paymentTabRoot.optionsCut[index].price
                                        discount: paymentTabRoot.optionsCut[index].discount
                                        isOption4: index === 4
                                        option4On: paymentTabRoot.option4CutEnabled
                                        priceLocked: paymentTabRoot._pricingByCategory
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; Layout.preferredWidth: 1; spacing: 8
                                Text { text: "Ảnh lớn 10x15"; color: "#f59e0b"; font.pixelSize: 14; font.bold: true }
                                Repeater {
                                    model: paymentTabRoot.optionsNoCut.length
                                    delegate: PaymentPrintOptionRow {
                                        required property int index
                                        isCut: false; optIndex: index
                                        qty: paymentTabRoot.optionsNoCut[index].qty
                                        price: paymentTabRoot.optionsNoCut[index].price
                                        discount: paymentTabRoot.optionsNoCut[index].discount
                                        isOption4: index === 4
                                        option4On: paymentTabRoot.option4NoCutEnabled
                                        priceLocked: paymentTabRoot._pricingByCategory
                                    }
                                }
                            }
                        }
                    }

                    PaymentGroup {
                        Text {
                            text: "Phương thức thanh toán"
                            color: root.themeTextColor; font.pixelSize: 19; font.weight: Font.DemiBold
                        }
                        PaymentToggleRow {
                            id: paymentBankTransferRow
                            title: "Thanh toán chuyển khoản / QR"
                            description: checked ? "Hiển thị chuyển khoản tại trang thanh toán" : "Đang tắt chuyển khoản"
                            accent: "#4FA4F2"
                            checked: eventManager.getAppSetting("bank_transfer_enabled", "true") === "true"
                            onChangedByUser: function(next) {
                                eventManager.setAppSetting("bank_transfer_enabled", next ? "true" : "false")
                                if (!next && !paymentCashRow.checked) {
                                    paymentCashRow.checked = true
                                    eventManager.setAppSetting("cash_payment_enabled", "true")
                                    autoSavedToast.show("Đã bật tiền mặt để luôn có phương thức thanh toán")
                                } else {
                                    autoSavedToast.show(next ? "Đã bật chuyển khoản" : "Đã tắt chuyển khoản")
                                }
                            }
                        }
                        PaymentToggleRow {
                            id: paymentCashRow
                            title: "Thanh toán tiền mặt"
                            description: checked ? "Cho phép khách chọn tiền mặt" : "Chỉ dùng chuyển khoản"
                            checked: eventManager.getAppSetting("cash_payment_enabled", "false") === "true"
                            onChangedByUser: function(next) {
                                eventManager.setAppSetting("cash_payment_enabled", next ? "true" : "false")
                                if (!next) {
                                    paymentCashCodeRow.checked = false
                                    eventManager.setAppSetting("cash_payment_code_enabled", "false")
                                    if (!paymentBankTransferRow.checked) {
                                        paymentBankTransferRow.checked = true
                                        eventManager.setAppSetting("bank_transfer_enabled", "true")
                                    }
                                }
                                autoSavedToast.show(next ? "Đã bật tiền mặt" : "Đã tắt tiền mặt")
                            }
                        }
                        PaymentToggleRow {
                            id: paymentCashCodeRow
                            visible: paymentCashRow.checked
                            title: "Mã thanh toán tiền mặt"
                            description: checked ? "Khách nhập mã 4 số do nhân viên cung cấp" : "Dùng đầu đọc tiền khi có kết nối"
                            checked: eventManager.getAppSetting("cash_payment_code_enabled", "false") === "true"
                            onChangedByUser: function(next) {
                                eventManager.setAppSetting("cash_payment_code_enabled", next ? "true" : "false")
                                autoSavedToast.show(next ? "Đã bật thanh toán bằng mã" : "Đã tắt thanh toán bằng mã")
                            }
                        }
                        PaymentToggleRow {
                            title: "Cho phép sử dụng Voucher"
                            description: checked ? "Khách có thể nhập voucher khi thanh toán" : "Voucher đang bị tắt"
                            accent: "#C58A33"
                            checked: eventManager.getAppSetting("voucher_enabled", "false") === "true"
                            onChangedByUser: function(next) {
                                eventManager.setAppSetting("voucher_enabled", next ? "true" : "false")
                                autoSavedToast.show(next ? "Đã bật Voucher" : "Đã tắt Voucher")
                            }
                        }
                    }

                    PaymentGroup {
                        Text {
                            text: "Đầu đọc tiền"
                            color: root.themeTextColor; font.pixelSize: 19; font.weight: Font.DemiBold
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 52
                            color: "transparent"
                            radius: 10
                            border.color: billAcceptor.connected ? "#22c55e" : root.themeBorderColor
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 12; spacing: 10
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: billAcceptor.connected ? "#22c55e" : root.mutedText(0.45)
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: billAcceptor.connected
                                          ? "Đang kết nối — " + billAcceptor.portName
                                          : "Chưa kết nối đầu đọc tiền"
                                    color: root.themeTextColor; font.pixelSize: 13
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            ComboBox {
                                id: paymentComPortCombo
                                Layout.fillWidth: true
                                model: root._comPorts
                                currentIndex: {
                                    var saved = eventManager.getAppSetting("bill_acceptor_port", "")
                                    var idx = find(saved)
                                    return idx >= 0 ? idx : 0
                                }
                                background: Rectangle { color: "transparent"; radius: 7; border.color: parent.activeFocus ? "#2E8B65" : root.themeBorderColor }
                                contentItem: Text {
                                    text: parent.displayText; color: root.themeTextColor
                                    verticalAlignment: Text.AlignVCenter; leftPadding: 10
                                }
                            }
                            Button {
                                text: "Làm mới"
                                background: Rectangle { color: "transparent"; radius: 7; border.color: "#2E8B65" }
                                contentItem: Text { text: parent.text; color: root.themeTextColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    var ports = billAcceptor.availablePorts()
                                    root._comPorts = ports.length > 0 ? ports : ["(Không tìm thấy cổng COM)"]
                                }
                            }
                            Button {
                                text: billAcceptor.connected ? "Ngắt kết nối" : "Kết nối"
                                background: Rectangle {
                                    color: "transparent"; radius: 7
                                    border.color: billAcceptor.connected ? "#ef4444" : "#2E8B65"
                                }
                                contentItem: Text { text: parent.text; color: root.themeTextColor; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                onClicked: {
                                    if (billAcceptor.connected) {
                                        billAcceptor.closePort()
                                        eventManager.setAppSetting("bill_acceptor_port", "")
                                        autoSavedToast.show("Đã ngắt kết nối đầu đọc tiền")
                                    } else {
                                        var port = paymentComPortCombo.currentText
                                        if (port === "" || port === "(Không tìm thấy cổng COM)") return
                                        if (billAcceptor.openPort(port)) {
                                            eventManager.setAppSetting("bill_acceptor_port", port)
                                            autoSavedToast.show("Đã kết nối đầu đọc tiền: " + port)
                                        } else {
                                            autoSavedToast.show("Không thể kết nối cổng " + port)
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Mệnh giá hỗ trợ: 10.000 ₫ · 20.000 ₫ · 50.000 ₫ · 100.000 ₫ · 200.000 ₫ · 500.000 ₫"
                            color: root.mutedText(0.65); font.pixelSize: 12; wrapMode: Text.WordWrap
                        }
                    }
                }
            }

            Popup {
                id: paymentAuthDialog
                parent: Overlay.overlay
                anchors.centerIn: Overlay.overlay
                width: 420
                height: paymentAuthContent.implicitHeight + 40
                modal: true; focus: true; padding: 20
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle {
                    color: root.themeSurfaceColor; radius: 16
                    border.color: paymentAuthError.visible ? "#ef4444" : root.themeBorderColor
                }
                onOpened: {
                    paymentAuthPin.text = ""
                    paymentAuthError.visible = false
                    paymentAuthPin.forceActiveFocus()
                }
                contentItem: ColumnLayout {
                    id: paymentAuthContent
                    spacing: 12
                    Text { text: "Xác thực bảo mật"; color: root.themeTextColor; font.pixelSize: 20; font.bold: true }
                    Text { text: "Nhập mã admin để hiển thị API Key SePay."; color: root.mutedText(0.65); font.pixelSize: 13 }
                    TextField {
                        id: paymentAuthPin
                        Layout.fillWidth: true; echoMode: TextInput.Password
                        inputMethodHints: Qt.ImhDigitsOnly; placeholderText: "Mã admin"
                        color: root.themeTextColor
                        background: Rectangle { color: "transparent"; radius: 8; border.color: parent.activeFocus ? "#2E8B65" : root.themeBorderColor }
                        onAccepted: paymentAuthConfirm.clicked()
                    }
                    Text { id: paymentAuthError; visible: false; text: "Mã không chính xác."; color: "#ef4444"; font.pixelSize: 12 }
                    RowLayout {
                        Layout.alignment: Qt.AlignRight
                        Button { text: "Hủy"; onClicked: paymentAuthDialog.close() }
                        Button {
                            id: paymentAuthConfirm
                            text: "Mở khóa"
                            onClicked: {
                                if (paymentAuthPin.text === "1234") {
                                    paymentTabRoot.showSecrets = true
                                    paymentAuthDialog.close()
                                } else {
                                    paymentAuthError.visible = true
                                    paymentAuthPin.text = ""
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: voucherTabComponent

        Item {
            id: voucherTabRoot
            property bool   voucherListOpen:   true
            property bool   voucherFeatureEnabled: eventManager.getAppSetting("voucher_enabled", "false") === "true"
            property string voucherFilter: "all"
            property string cashFilter: "all"
            property var selectedVoucherCodes: ({})
            property var selectedCashCodes: ({})
            property int selectedVoucherCount: 0
            property int selectedCashCount: 0
            property bool deleteBatchBusy: false
            property string deleteBatchKind: ""
            property int deleteBatchDone: 0
            property int deleteBatchTotal: 0

            // ── Preset đồng bộ từ web (ghi chú / giá gợi ý / thời gian hiệu lực) ──
            property var vNotes: []      // [{id, content}]
            property var vPrices: []     // [{id, value}]
            property var vDurations: []  // [{id, minutes}]
            function loadVoucherPresets() {
                var p = eventManager.getVoucherPresets()
                vNotes     = (p && p.notes)     ? p.notes     : []
                vPrices    = (p && p.prices)    ? p.prices    : []
                vDurations = (p && p.durations) ? p.durations : []
            }
            function fmtMinutes(m) {
                m = parseInt(m) || 0
                if (m % 1440 === 0) return (m / 1440) + " ngày"
                if (m % 60 === 0)   return (m / 60) + " giờ"
                return m + " phút"
            }

            // ── Đồng bộ danh sách (voucher + mã tiền mặt dùng chung 1 lần kéo cloud) ──
            property var cloudCodes: []
            property bool haveCloud: false
            function statusMatch(used, f) {
                if (f === "used")   return !!used
                if (f === "unused") return !used
                return true
            }
            function applyCodeLists() {
                var useCloud = eventManager.isAdmin && haveCloud
                voucherListModel.applyList(useCloud ? cloudCodes : eventManager.getVoucherList("all"), voucherFilter, useCloud)
                cashPaymentCodeListModel.applyList(useCloud ? cloudCodes : eventManager.getCashPaymentCodeList("all"), cashFilter, useCloud)
            }
            // Số đếm theo cloud khi có (đồng bộ với danh sách); ngược lại dùng local.
            function countFor(filter) {
                if (eventManager.isAdmin && haveCloud) {
                    var n = 0
                    for (var i = 0; i < cloudCodes.length; i++) {
                        var v = cloudCodes[i]
                        if ((v.type || "") === "cash_code") continue
                        if (statusMatch(v.used, filter)) n++
                    }
                    return n
                }
                return eventManager.getVoucherCount(filter)
            }
            function reloadCodes() {
                applyCodeLists()
                if (eventManager.isAdmin) eventManager.refreshCloudVouchers("all")
            }

            // Đóng/mở vùng tạo (tiết kiệm chỗ, ưu tiên xem danh sách).
            property bool voucherCreateOpen: true
            property bool cashCreateOpen: true

            Component.onCompleted: { loadVoucherPresets(); reloadCodes() }

            // Trạng thái voucher dựa trên đã dùng + khung giờ hiệu lực.
            // Trả { label, color, bg }.
            function voucherStatus(used, validFrom, validUntil) {
                if (used)
                    return { label: "Đã dùng", color: "#9a3412", bg: "#fed7aa", rowBg: "#ffedd5" }
                var now = new Date()
                function parseIso(s) {
                    if (!s || s === "") return null
                    var d = new Date(s.replace(" ", "T"))
                    return isNaN(d.getTime()) ? null : d
                }
                var vf = parseIso(validFrom)
                var vu = parseIso(validUntil)
                if (vf && now < vf)
                    return { label: "Chưa hiệu lực", color: "#1d4ed8", bg: "#bfdbfe", rowBg: "#dbeafe" }
                if (vu && now > vu)
                    return { label: "Hết hạn", color: "#b91c1c", bg: "#fecaca", rowBg: "#fee2e2" }
                return { label: "Chưa dùng", color: "#15803d", bg: "#bbf7d0", rowBg: "#dcfce7" }
            }

            function selectedMap(kind) {
                return kind === "cash" ? selectedCashCodes : selectedVoucherCodes
            }

            function isSelected(kind, code) {
                var m = selectedMap(kind)
                return m && m[code] !== undefined
            }

            function setSelected(kind, next) {
                var count = Object.keys(next).length
                if (kind === "cash") {
                    selectedCashCodes = next
                    selectedCashCount = count
                } else {
                    selectedVoucherCodes = next
                    selectedVoucherCount = count
                }
            }

            function toggleSelected(kind, code, used) {
                if (deleteBatchBusy) return
                var current = selectedMap(kind)
                var next = {}
                for (var k in current) next[k] = current[k]
                if (next[code] !== undefined) delete next[code]
                else next[code] = { "code": code, "used": !!used }
                setSelected(kind, next)
            }

            function clearSelected(kind) {
                setSelected(kind, {})
            }

            function selectAllCodes(kind, listModel) {
                if (deleteBatchBusy) return
                var next = {}
                for (var i = 0; i < listModel.count; i++) {
                    var row = listModel.get(i)
                    next[row.code] = { "code": row.code, "used": !!row.used }
                }
                setSelected(kind, next)
            }

            function selectedItems(kind) {
                var current = selectedMap(kind)
                var keys = Object.keys(current)
                var items = []
                for (var i = 0; i < keys.length; i++) {
                    var entry = current[keys[i]]
                    if (entry && entry.code !== undefined)
                        items.push({ "code": entry.code, "used": !!entry.used })
                    else
                        items.push({ "code": keys[i], "used": false })
                }
                return items
            }

            function deleteSelectedCodes(kind) {
                if (!eventManager.isAdmin) {
                    autoSavedToast.show("Chỉ admin được xóa mã")
                    return
                }
                if (deleteBatchBusy) return
                var items = selectedItems(kind)
                if (items.length === 0) return
                deleteBatchBusy = true
                deleteBatchKind = kind
                deleteBatchDone = 0
                deleteBatchTotal = items.length
                autoSavedToast.show("Đang xóa " + items.length + " mã...")
                eventManager.deleteVoucherBatch(kind, items)
            }

            function deleteOneCode(kind, code, used) {
                if (!eventManager.isAdmin || deleteBatchBusy) return
                deleteBatchBusy = true
                deleteBatchKind = kind
                deleteBatchDone = 0
                deleteBatchTotal = 1
                eventManager.deleteVoucherBatch(kind, [{ "code": code, "used": !!used }])
            }

            function batchDeleteResultMessage(kind, requested, deleted, skippedUsed, failed) {
                var label = kind === "cash" ? "mã tiền mặt" : "voucher"
                var parts = []
                if (deleted > 0) parts.push("Đã xóa " + deleted + " " + label)
                if (failed > 0) parts.push(failed + " mã lỗi")
                if (parts.length === 0) parts.push("Không có mã nào được xóa")
                return parts.join("; ")
            }

            function exportCodes(kind, filter) {
                var isCash = kind === "cash"
                var list = isCash ? eventManager.getCashPaymentCodeList(filter)
                                  : eventManager.getVoucherList(filter)
                var statusLabel = filter === "unused" ? "Chưa dùng"
                                : (filter === "used" ? "Đã dùng" : "Tất cả")
                // Định dạng thời gian hiệu lực: "YYYY-MM-DDTHH:mm" → "YYYY-MM-DD HH:mm".
                function fDate(s) { return s ? s.replace("T", " ").substring(0, 16) : "∞" }
                var lines = [isCash ? "# PhotoBooth Cash Payment Codes Export" : "# PhotoBooth Vouchers Export",
                             "# Filter: " + filter,
                             "# Date: " + Qt.formatDate(new Date(), "yyyy-MM-dd"),
                             "# Count: " + list.length,
                             // Mô tả cột để người đọc file hiểu giá tiền & thời gian hiệu lực.
                             "# Format: Mã | Giá tiền | Hiệu lực (từ -> đến) | Trạng thái", ""]
                for (var i = 0; i < list.length; i++) {
                    var v = list[i]
                    var price = Money.vnd(v.value)
                    var validity = fDate(v.valid_from) + " -> " + fDate(v.valid_until)
                    var state = v.used ? "Đã dùng" : "Chưa dùng"
                    lines.push(v.code + " | " + price + " | " + validity + " | " + state)
                }
                root.exportVoucherTxt(lines.join("\n"), isCash ? "MaTien" : "Voucher", statusLabel)
            }

            // ── Hidden models ────────────────────────────────────────────────
            ListModel { id: genResultList }
            ListModel { id: cashCodeResultList }
            ListModel {
                id: voucherListModel
                // Nạp voucher (bỏ cash_code) + lọc trạng thái theo voucherFilter (client-side).
                // fromCloud=true: mã lấy từ cloud nên coi như đã đồng bộ (badge không hiện "Chưa đồng bộ").
                function applyList(list, statusFilter, fromCloud) {
                    clear()
                    for (var i = 0; i < list.length; i++) {
                        var v = list[i]
                        if ((v.type || "") === "cash_code") continue
                        if (!voucherTabRoot.statusMatch(v.used, statusFilter)) continue
                        append({ code: v.code, type: v.type, value: v.value, used: !!v.used,
                                 used_at: v.used_at || "", created_at: v.created_at || "",
                                 valid_from: v.valid_from || "", valid_until: v.valid_until || "",
                                 paid_amount: v.paid_amount || 0, shift: v.shift || "",
                                 created_via: v.created_via || "desktop",
                                 // Mã tại máy được trộn vào danh sách cloud và mang sẵn synced=false
                                 // → giữ nguyên cờ của hàng, chỉ mặc định theo nguồn khi hàng không có.
                                 synced: (v.synced !== undefined) ? !!v.synced : !!fromCloud,
                                 note: v.note || "", created_by: v.created_by || "" })
                    }
                }
                function reload() { voucherTabRoot.reloadCodes() }
            }

            // Danh sách cloud về (poll realtime) → cache + áp cho cả 2 model; lỗi giữ local.
            Connections {
                target: eventManager
                function onCloudVouchersReady(data, ok) {
                    if (!ok) return
                    voucherTabRoot.haveCloud = true
                    voucherTabRoot.cloudCodes = data
                    voucherTabRoot.applyCodeLists()
                }
                function onVoucherBatchDeleteProgress(kind, done, total) {
                    if (kind !== voucherTabRoot.deleteBatchKind) return
                    voucherTabRoot.deleteBatchDone = done
                    voucherTabRoot.deleteBatchTotal = total
                }
                function onVoucherBatchDeleteFinished(kind, requested, deleted, skippedUsed, failed, message) {
                    if (kind !== voucherTabRoot.deleteBatchKind) return
                    voucherTabRoot.deleteBatchBusy = false
                    voucherTabRoot.deleteBatchDone = 0
                    voucherTabRoot.deleteBatchTotal = 0
                    voucherTabRoot.clearSelected(kind)
                    voucherListModel.reload()
                    cashPaymentCodeListModel.reload()
                    autoSavedToast.show(voucherTabRoot.batchDeleteResultMessage(kind, requested, deleted, skippedUsed, failed))
                }
            }

            // Poll realtime khi tab đang mở (admin): thấy mã web/máy khác tạo (cả voucher + tiền mặt).
            Timer {
                interval: 12000; repeat: true
                running: voucherTabRoot.visible && eventManager.isAdmin
                onTriggered: eventManager.refreshCloudVouchers("all")
            }
            ListModel {
                id: cashPaymentCodeListModel
                // Chỉ hiện cash_code + lọc trạng thái theo cashFilter (client-side).
                function applyList(list, statusFilter, fromCloud) {
                    clear()
                    for (var i = 0; i < list.length; i++) {
                        var v = list[i]
                        if ((v.type || "") !== "cash_code") continue
                        if (!voucherTabRoot.statusMatch(v.used, statusFilter)) continue
                        append({ code: v.code, type: v.type, value: v.value, used: !!v.used,
                                 used_at: v.used_at || "", created_at: v.created_at || "",
                                 valid_from: v.valid_from || "", valid_until: v.valid_until || "",
                                 paid_amount: v.paid_amount || 0, shift: v.shift || "",
                                 created_via: v.created_via || "desktop",
                                 // Mã tại máy được trộn vào danh sách cloud và mang sẵn synced=false
                                 // → giữ nguyên cờ của hàng, chỉ mặc định theo nguồn khi hàng không có.
                                 synced: (v.synced !== undefined) ? !!v.synced : !!fromCloud,
                                 note: v.note || "", created_by: v.created_by || "" })
                    }
                }
                function reload() { voucherTabRoot.reloadCodes() }
            }
            Item { id: voucherListFilter; property string currentFilter: "all" }

            // ── Ca làm việc (lưu chung toàn máy ở app_settings "voucher_shifts") ─
            ListModel {
                id: shiftModel
                readonly property string _defJson:
                    '[{"name":"Ca 1","start":"00:00","end":"00:00"},' +
                    '{"name":"Ca 2","start":"00:00","end":"00:00"},' +
                    '{"name":"Ca 3","start":"00:00","end":"00:00"}]'
                function persist() {
                    var arr = []
                    for (var i = 0; i < count; i++) {
                        var s = get(i)
                        arr.push({ name: s.name, start: s.start, end: s.end })
                    }
                    eventManager.setAppSetting("voucher_shifts", JSON.stringify(arr))
                }
                function reload() {
                    var arr
                    try { arr = JSON.parse(eventManager.getAppSetting("voucher_shifts", _defJson)) }
                    catch (e) { arr = JSON.parse(_defJson) }
                    if (!Array.isArray(arr) || arr.length === 0) arr = JSON.parse(_defJson)
                    clear()
                    for (var i = 0; i < arr.length; i++)
                        append({ name: arr[i].name || ("Ca " + (i + 1)),
                                 start: arr[i].start || "00:00", end: arr[i].end || "00:00" })
                }
                Component.onCompleted: reload()
            }

            // Dialog thêm / sửa ca (editIndex = -1 → thêm; >= 0 → sửa ca đó)
            Dialog {
                id: addShiftDialog
                property int editIndex: -1
                modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                anchors.centerIn: Overlay.overlay
                width: 420; padding: 20
                title: editIndex >= 0 ? "Sửa ca làm việc" : "Thêm ca làm việc"
                standardButtons: Dialog.Save | Dialog.Cancel
                contentItem: ColumnLayout {
                    spacing: 10
                    Text { text: "Tên ca"; color: root.mutedText(0.65); font.pixelSize: 14 }
                    TextField {
                        id: shiftNameField; Layout.fillWidth: true; color: "#FFFFFF"; leftPadding: 12
                        placeholderText: "VD: Ca tối"
                        background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#4FA4F2" : Theme.border; radius: 6; height: 40 }
                    }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 10
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: "Giờ bắt đầu (HH:mm)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            TextField {
                                id: shiftStartField; Layout.fillWidth: true; text: "00:00"; color: "#FFFFFF"; leftPadding: 10
                                inputMethodHints: Qt.ImhPreferNumbers
                                background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#4FA4F2" : Theme.border; radius: 6; height: 40 }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: "Giờ kết thúc (HH:mm)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                            TextField {
                                id: shiftEndField; Layout.fillWidth: true; text: "00:00"; color: "#FFFFFF"; leftPadding: 10
                                inputMethodHints: Qt.ImhPreferNumbers
                                background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#4FA4F2" : Theme.border; radius: 6; height: 40 }
                            }
                        }
                    }
                    // Nút xóa ca (chỉ khi đang sửa và còn > 1 ca)
                    Rectangle {
                        Layout.fillWidth: true; height: 36; radius: 7
                        visible: addShiftDialog.editIndex >= 0 && shiftModel.count > 1
                        color: delShiftMa.containsMouse ? "#8b2020" : "#2a1a1a"
                        border.color: "#aa3322"; border.width: 1
                        Text { anchors.centerIn: parent; text: "Xóa ca này"; color: "#ef9a9a"; font.pixelSize: 14 }
                        MouseArea {
                            id: delShiftMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                shiftModel.remove(addShiftDialog.editIndex)
                                shiftModel.persist()
                                if (shiftCombo.currentIndex >= shiftModel.count) shiftCombo.currentIndex = shiftModel.count - 1
                                addShiftDialog.close()
                                autoSavedToast.show("Đã xóa ca")
                            }
                        }
                    }
                }
                onAccepted: {
                    var nm = shiftNameField.text.trim()
                    var st = shiftStartField.text.trim() || "00:00"
                    var en = shiftEndField.text.trim() || "00:00"
                    if (editIndex >= 0) {
                        if (nm === "") nm = shiftModel.get(editIndex).name
                        shiftModel.set(editIndex, { name: nm, start: st, end: en })
                        autoSavedToast.show("Đã cập nhật ca: " + nm)
                    } else {
                        if (nm === "") nm = "Ca " + (shiftModel.count + 1)
                        shiftModel.append({ name: nm, start: st, end: en })
                        shiftCombo.currentIndex = shiftModel.count - 1
                        autoSavedToast.show("Đã thêm ca: " + nm)
                    }
                    shiftModel.persist()
                }
                // Mở ở chế độ thêm
                function openAdd() {
                    editIndex = -1
                    shiftNameField.text = ""; shiftStartField.text = "00:00"; shiftEndField.text = "00:00"
                    open()
                }
                // Mở ở chế độ sửa ca idx
                function openEdit(idx) {
                    if (idx < 0 || idx >= shiftModel.count) return
                    editIndex = idx
                    var s = shiftModel.get(idx)
                    shiftNameField.text = s.name; shiftStartField.text = s.start; shiftEndField.text = s.end
                    open()
                }
            }

            // Áp khung giờ của ca đang chọn vào Hiệu lực Từ/Đến (theo ngày hôm nay).
            // Ca qua đêm (giờ kết thúc <= giờ bắt đầu) → ngày kết thúc +1.
            function _applyShift(idx) {
                if (idx < 0 || idx >= shiftModel.count) return
                var s = shiftModel.get(idx)
                var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
                var st = (s.start && s.start.length === 5) ? s.start : "00:00"
                var en = (s.end   && s.end.length   === 5) ? s.end   : "00:00"
                genFromField.text = today + " " + st
                // Nếu giờ kết thúc <= bắt đầu thì coi là qua đêm → +1 ngày
                var endDay = today
                if (en <= st && !(en === "00:00" && st === "00:00")) {
                    var d = new Date(); d.setDate(d.getDate() + 1)
                    endDay = Qt.formatDate(d, "yyyy-MM-dd")
                }
                genUntilField.text = endDay + " " + en
            }

            // ── Bộ chọn ngày/giờ (lịch + con lăn) cho khung giờ hiệu lực ────────
            DateTimePicker {
                id: fromPicker
                title: "Hiệu lực từ"
                onAccepted: genFromField.text = displayText
            }
            DateTimePicker {
                id: untilPicker
                title: "Hiệu lực đến"
                onAccepted: genUntilField.text = displayText
            }

            // ── Main column ──────────────────────────────────────────────────
            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    // Cao theo nội dung → không bị tràn/đè khi panel hẹp.
                    Layout.preferredHeight: voucherTopCol.implicitHeight + 24
                    radius: 14; color: Theme.settingsCard; border.color: Theme.settingsBorder
                    // Xếp DỌC: toggle ở trên, ô "Ngày hết hạn" ở dưới — tránh chồng ngang.
                    ColumnLayout {
                        id: voucherTopCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 12

                        SettingsToggleRow {
                            Layout.fillWidth: true
                            title: "Sử dụng Voucher"
                            description: "Hiện màn nhập mã giảm giá hoặc thêm lượt in trước thanh toán."
                            checked: voucherTabRoot.voucherFeatureEnabled
                            onToggled: function(next) {
                                voucherTabRoot.voucherFeatureEnabled = next
                                eventManager.setAppSetting("voucher_enabled", next ? "true" : "false")
                                autoSavedToast.show(next ? "Đã bật Voucher" : "Đã tắt Voucher")
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: "Ngày hết hạn mặc định"; color: Theme.settingsText; font.pixelSize: 12; font.weight: Font.DemiBold }
                            TextField {
                                id: voucherExpiryField
                                Layout.fillWidth: true; Layout.preferredHeight: 42
                                text: eventManager.getAppSetting("voucher_expiry_date", "")
                                placeholderText: "YYYY-MM-DD · để trống nếu không hết hạn"
                                color: Theme.settingsText; leftPadding: 12
                                background: Rectangle { color: Theme.settingsSurface; radius: 10; border.color: parent.activeFocus ? Theme.settingsCopper : Theme.settingsBorder }
                                onEditingFinished: {
                                    eventManager.setAppSetting("voucher_expiry_date", text.trim())
                                    autoSavedToast.show("Đã lưu ngày hết hạn voucher")
                                }
                            }
                        }
                    }
                }

                // ── Stats bar ─────────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; spacing: 12

                    Repeater {
                        model: [
                            { label: "Tổng",      filter: "all",    color: "#4FA4F2" },
                            { label: "Chưa dùng", filter: "unused", color: "#4caf50" },
                            { label: "Đã dùng",   filter: "used",   color: root.mutedText(0.65) }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true; height: 60; radius: 10
                            color: "transparent"; border.color: modelData.color; border.width: 1
                            ColumnLayout {
                                anchors.centerIn: parent; spacing: 2
                                Text { text: voucherTabRoot.countFor(modelData.filter); color: modelData.color; font.pixelSize: 22; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                                Text { text: modelData.label; color: root.mutedText(0.65); font.pixelSize: 11; Layout.alignment: Qt.AlignHCenter }
                            }
                        }
                    }
                }

                // ── Phạm vi hiệu lực dùng chung cho voucher + mã tiền mặt ─────
                Rectangle {
                    Layout.fillWidth: true
                    height: validityCol.implicitHeight + 24
                    radius: 12; color: "transparent"
                    border.color: "#2d5a8c"; border.width: 1

                    ColumnLayout {
                        id: validityCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Hiệu lực mã"; color: root.themeTextColor; font.pixelSize: 15; font.bold: true }
                            Text { text: "áp dụng cho cả voucher và mã tiền mặt"; color: root.mutedText(0.65); font.pixelSize: 11 }
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            ColumnLayout {
                                Layout.preferredWidth: 280; spacing: 4
                                Text { text: "Ca làm việc"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                RowLayout {
                                    Layout.fillWidth: true; spacing: 8
                                ComboBox {
                                    id: shiftCombo
                                    Layout.fillWidth: true
                                    height: 38
                                    model: shiftModel
                                    textRole: "name"
                                    // Hiển thị tên ca + khung giờ
                                    displayText: {
                                        if (currentIndex < 0 || currentIndex >= shiftModel.count) return "— Chọn ca —"
                                        var s = shiftModel.get(currentIndex)
                                        return s.name + "  (" + s.start + " – " + s.end + ")"
                                    }
                                    onActivated: function(idx) { voucherTabRoot._applyShift(idx) }

                                    contentItem: Text {
                                        leftPadding: 12
                                        text: shiftCombo.displayText
                                        color: root.themeTextColor; font.pixelSize: 14
                                        verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                                    }
                                    background: Rectangle { color: "transparent"; radius: 6; border.color: "#2d5a8c"; border.width: 1 }
                                    delegate: ItemDelegate {
                                        width: shiftCombo.width
                                        contentItem: Text {
                                            text: model.name + "  (" + model.start + " – " + model.end + ")"
                                            color: root.themeTextColor; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter
                                        }
                                        background: Rectangle { color: highlighted ? "#2a3550" : Theme.field }
                                        highlighted: shiftCombo.highlightedIndex === index
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 44; Layout.preferredHeight: 38; radius: 8
                                    color: editShiftMa.containsMouse ? "#2a3550" : "#222530"
                                    border.color: "#2d5a8c"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "✎"; color: "#334155"; font.pixelSize: 17 }
                                    MouseArea {
                                        id: editShiftMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: addShiftDialog.openEdit(shiftCombo.currentIndex)
                                    }
                                }

                                Rectangle {
                                    Layout.preferredWidth: 44; Layout.preferredHeight: 38; radius: 8
                                    color: addShiftMa.pressed ? "#1565c0" : (addShiftMa.containsMouse ? "#1a6fd0" : "#1e7eea")
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: "+"; color: "#fff"; font.pixelSize: 22; font.bold: true }
                                    MouseArea {
                                        id: addShiftMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: addShiftDialog.openAdd()
                                    }
                                }
                            }
                        }

                            TextField { id: genFromField;  visible: false }
                            TextField { id: genUntilField; visible: false }

                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Hiệu lực từ"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 38; radius: 6
                                    color: "transparent"; border.color: fromMa.containsMouse ? "#4FA4F2" : Theme.border; border.width: 1
                                    Behavior on border.color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors { left: parent.left; right: fromIcon.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                                        text: genFromField.text !== "" ? genFromField.text : "Chọn ngày & giờ bắt đầu"
                                        color: genFromField.text !== "" ? root.themeTextColor : root.mutedText(0.65)
                                        font.pixelSize: 14; elide: Text.ElideRight
                                    }
                                    Text {
                                        id: fromIcon
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 10
                                        text: "🕒"; font.pixelSize: 15
                                    }
                                    MouseArea { id: fromMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: fromPicker.openWith(genFromField.text) }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Hiệu lực đến (để trống = không giới hạn)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                Rectangle {
                                    Layout.fillWidth: true; height: 38; radius: 6
                                    color: "transparent"; border.color: untilMa.containsMouse ? "#4FA4F2" : Theme.border; border.width: 1
                                    Behavior on border.color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.left: parent.left; anchors.right: clearUntil.left
                                        anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 10
                                        text: genUntilField.text !== "" ? genUntilField.text : "Chọn ngày & giờ kết thúc"
                                        color: genUntilField.text !== "" ? root.themeTextColor : root.mutedText(0.65)
                                        font.pixelSize: 14; elide: Text.ElideRight
                                    }
                                    Text {
                                        id: clearUntil
                                        z: 2
                                        anchors.right: untilIcon.left; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 6
                                        visible: genUntilField.text !== ""
                                        text: "✕"; color: "#ef9a9a"; font.pixelSize: 14
                                        MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor; onClicked: genUntilField.text = "" }
                                    }
                                    Text {
                                        id: untilIcon
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.rightMargin: 10
                                        text: "🕒"; font.pixelSize: 15
                                    }
                                    MouseArea { id: untilMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: untilPicker.openWith(genUntilField.text) }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                // ── Tạo voucher theo nhân viên ───────────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: genCol.implicitHeight + 28
                    radius: 12; color: "transparent"
                    border.color: "#4FA4F2"; border.width: 1

                    ColumnLayout {
                        id: genCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: (voucherTabRoot.voucherCreateOpen ? "▾  " : "▸  ") + "Voucher"
                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: voucherTabRoot.voucherCreateOpen = !voucherTabRoot.voucherCreateOpen }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: eventManager.isAdmin ? "Người tạo: Admin"
                                    : (eventManager.isLoggedIn ? ("Người tạo: " + eventManager.currentEmployeeName) : "Chưa đăng nhập")
                                color: "#7fb8f0"; font.pixelSize: 13; font.bold: true
                            }
                        }

                        // Vùng nội dung tạo voucher — ẩn/hiện theo nút mũi tên ở tiêu đề.
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 10
                            visible: voucherTabRoot.voucherCreateOpen

                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Số tiền (₫)"; color: "#1e7eea"; font.pixelSize: 13; font.bold: true }
                                TextField {
                                    id: genValueField; Layout.fillWidth: true; height: 38; text: "100000"
                                    inputMethodHints: Qt.ImhDigitsOnly; color: "#1e7eea"; font.pixelSize: 14; leftPadding: 10
                                    background: Rectangle { color: "transparent"; border.color: "#1e7eea"; radius: 6; height: 36 }
                                }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: 100; spacing: 4
                                Text { text: "Số lượng"; color: "#1e7eea"; font.pixelSize: 13; font.bold: true }
                                TextField {
                                    id: genCountField; Layout.fillWidth: true; height: 38; text: "1"
                                    inputMethodHints: Qt.ImhDigitsOnly; color: "#1e7eea"; font.pixelSize: 14; leftPadding: 10
                                    background: Rectangle { color: "transparent"; border.color: "#1e7eea"; radius: 6; height: 36 }
                                }
                            }
                        }

                        // ── Preset đồng bộ web: giá gợi ý · ghi chú (bắt buộc) · hiệu lực ──
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Giá gợi ý"; color: "#1e7eea"; font.pixelSize: 13; font.bold: true }
                                ComboBox {
                                    id: genPriceCombo
                                    Layout.fillWidth: true; height: 38
                                    model: {
                                        var arr = []
                                        for (var i = 0; i < voucherTabRoot.vPrices.length; i++)
                                            arr.push(Money.vnd(voucherTabRoot.vPrices[i].value))
                                        arr.push("Khác (nhập tay)…")
                                        return arr
                                    }
                                    onActivated: function(idx) {
                                        if (idx < voucherTabRoot.vPrices.length)
                                            genValueField.text = String(voucherTabRoot.vPrices[idx].value)
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Ghi chú (bắt buộc)"; color: "#1e7eea"; font.pixelSize: 13; font.bold: true }
                                ComboBox {
                                    id: genNoteCombo
                                    Layout.fillWidth: true; height: 38
                                    model: {
                                        var arr = ["— Chọn ghi chú —"]
                                        for (var i = 0; i < voucherTabRoot.vNotes.length; i++)
                                            arr.push(voucherTabRoot.vNotes[i].content)
                                        return arr
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Text { text: "Thời gian hiệu lực"; color: "#1e7eea"; font.pixelSize: 13; font.bold: true }
                            ComboBox {
                                id: genDurationCombo
                                Layout.fillWidth: true; height: 38
                                model: {
                                    var arr = ["Không giới hạn"]
                                    for (var i = 0; i < voucherTabRoot.vDurations.length; i++)
                                        arr.push(voucherTabRoot.fmtMinutes(voucherTabRoot.vDurations[i].minutes))
                                    arr.push("Thời điểm cụ thể…")
                                    return arr
                                }
                                onActivated: function(idx) {
                                    var customIdx = voucherTabRoot.vDurations.length + 1
                                    if (idx === 0) { genFromField.text = ""; genUntilField.text = "" }
                                    else if (idx === customIdx) { /* dùng ô chọn ngày giờ bên dưới */ }
                                    else {
                                        var mins = parseInt(voucherTabRoot.vDurations[idx - 1].minutes) || 0
                                        var now = new Date()
                                        var end = new Date(now.getTime() + mins * 60000)
                                        genFromField.text  = Qt.formatDateTime(now, "yyyy-MM-dd HH:mm")
                                        genUntilField.text = Qt.formatDateTime(end, "yyyy-MM-dd HH:mm")
                                    }
                                }
                            }
                        }

                        // Preview codes
                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 0; height: 0; radius: 8
                            color: "transparent"; border.color: "#2d5a8c"; border.width: 1
                            visible: false
                            ScrollView {
                                anchors.fill: parent; anchors.margins: 8; clip: true
                                Text {
                                    text: { var lines = []; for (var i = 0; i < genResultList.count; i++) lines.push(genResultList.get(i).code); return lines.join("\n") }
                                    color: "#4FA4F2"; font.pixelSize: 13; font.family: "Courier New"
                                }
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 140; height: 38; radius: 8
                                enabled: eventManager.isLoggedIn && genNoteCombo.currentIndex > 0
                                opacity: enabled ? 1.0 : 0.4
                                color: genMa.pressed ? "#1565c0" : (genMa.containsMouse ? "#2a5aaa" : "#1e3a6e")
                                border.color: "#4FA4F2"; border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: "Tạo Voucher"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: genMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: eventManager.isLoggedIn && genNoteCombo.currentIndex > 0
                                    onClicked: {
                                        var val   = parseInt(genValueField.text)  || 0
                                        var count = parseInt(genCountField.text) || 0
                                        if (val <= 0 || count <= 0) { autoSavedToast.show("Giá trị không hợp lệ"); return }
                                        // Ghi chú bắt buộc (đồng nhất với web).
                                        var note = genNoteCombo.currentIndex > 0
                                                   ? voucherTabRoot.vNotes[genNoteCombo.currentIndex - 1].content : ""
                                        if (!note) { autoSavedToast.show("Vui lòng chọn ghi chú"); return }
                                        // Chuẩn hóa khung giờ -> ISO (rỗng nếu để trống)
                                        function toIso(s) {
                                            s = s.trim(); if (!s) return ""
                                            var d = new Date(s.replace(" ", "T"))
                                            return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "yyyy-MM-ddTHH:mm:ss")
                                        }
                                        var vf = toIso(genFromField.text)
                                        var vu = toIso(genUntilField.text)
                                        var shiftName = (shiftCombo.currentIndex >= 0 && shiftCombo.currentIndex < shiftModel.count)
                                                        ? shiftModel.get(shiftCombo.currentIndex).name : ""
                                        var codes = eventManager.generateVouchers(val, count, vf, vu, shiftName, note)
                                        genResultList.clear()
                                        for (var i = 0; i < codes.length; i++) genResultList.append({ code: codes[i] })
                                        autoSavedToast.show("Đã tạo " + codes.length + " voucher")
                                        voucherListModel.reload()
                                    }
                                }
                            }
                            Rectangle {
                                width: 120; height: 38; radius: 8
                                color: dlMa.pressed ? "#2a7a2a" : (dlMa.containsMouse ? "#3a8a3a" : "#1a4a1a")
                                border.color: "#4caf50"; border.width: 1
                                enabled: genResultList.count > 0
                                opacity: genResultList.count > 0 ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: "Tải TXT ↓"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: dlMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var val = parseInt(genValueField.text) || 0
                                        var lines = [
                                            "# PhotoBooth Vouchers - Batch",
                                            "# Value: " + val,
                                            "# Hiệu lực: " + (genFromField.text || "—") + " -> " + (genUntilField.text || "không giới hạn"),
                                            "# Generated: " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"),
                                            "# Count: " + genResultList.count, ""
                                        ]
                                        for (var i = 0; i < genResultList.count; i++) lines.push(genResultList.get(i).code)
                                        root.exportVoucherTxt(lines.join("\n"), "Voucher", "Batch")
                                    }
                                }
                            }
                        }
                        } // hết vùng nội dung tạo voucher (collapsible)
                    }
                }

                // ── Tạo mã tiền mặt theo nhân viên ───────────────────────────
                Rectangle {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredHeight: cashCodeGenCol.implicitHeight + 32
                    radius: 12; color: "transparent"
                    border.color: "#22c55e"; border.width: 1

                    ColumnLayout {
                        id: cashCodeGenCol
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
                        spacing: 10

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: (voucherTabRoot.cashCreateOpen ? "▾  " : "▸  ") + "Tạo mã tiền mặt"
                                color: root.themeTextColor; font.pixelSize: 15; font.bold: true
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: voucherTabRoot.cashCreateOpen = !voucherTabRoot.cashCreateOpen }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: eventManager.isAdmin ? "Người tạo: Admin"
                                    : (eventManager.isLoggedIn ? ("Người tạo: " + eventManager.currentEmployeeName) : "Chưa đăng nhập")
                                color: "#9ae6b4"; font.pixelSize: 13; font.bold: true
                            }
                        }

                        // Vùng nội dung tạo mã tiền mặt — ẩn/hiện theo nút mũi tên ở tiêu đề.
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 10
                            visible: voucherTabRoot.cashCreateOpen

                        Text {
                            Layout.fillWidth: true
                            text: "Dùng tại trang nhập mã tiền mặt; hệ thống chỉ nhận khi số tiền khớp đơn."
                            color: root.mutedText(0.65); font.pixelSize: 11; wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Số tiền mã tiền mặt (₫)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                TextField {
                                    id: cashCodeValueField; Layout.fillWidth: true; height: 38; text: genValueField.text
                                    inputMethodHints: Qt.ImhDigitsOnly; color: root.themeTextColor; font.pixelSize: 14; leftPadding: 10
                                    background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#22c55e" : Theme.border; radius: 6; height: 36 }
                                }
                            }
                            ColumnLayout {
                                Layout.preferredWidth: 100; spacing: 4
                                Text { text: "Số lượng"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                TextField {
                                    id: cashCodeCountField; Layout.fillWidth: true; height: 38; text: "1"
                                    inputMethodHints: Qt.ImhDigitsOnly; color: root.themeTextColor; font.pixelSize: 14; leftPadding: 10
                                    background: Rectangle { color: "transparent"; border.color: parent.activeFocus ? "#22c55e" : Theme.border; radius: 6; height: 36 }
                                }
                            }
                        }

                        // ── Preset đồng bộ web: giá gợi ý · ghi chú (bắt buộc) ──
                        RowLayout {
                            Layout.fillWidth: true; spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Giá gợi ý"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                ComboBox {
                                    id: cashPriceCombo
                                    Layout.fillWidth: true; height: 38
                                    model: {
                                        var arr = []
                                        for (var i = 0; i < voucherTabRoot.vPrices.length; i++)
                                            arr.push(Money.vnd(voucherTabRoot.vPrices[i].value))
                                        arr.push("Khác (nhập tay)…")
                                        return arr
                                    }
                                    onActivated: function(idx) {
                                        if (idx < voucherTabRoot.vPrices.length)
                                            cashCodeValueField.text = String(voucherTabRoot.vPrices[idx].value)
                                    }
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 4
                                Text { text: "Ghi chú (bắt buộc)"; color: root.mutedText(0.65); font.pixelSize: 13 }
                                ComboBox {
                                    id: cashNoteCombo
                                    Layout.fillWidth: true; height: 38
                                    model: {
                                        var arr = ["— Chọn ghi chú —"]
                                        for (var i = 0; i < voucherTabRoot.vNotes.length; i++)
                                            arr.push(voucherTabRoot.vNotes[i].content)
                                        return arr
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 0; height: 0; radius: 8
                            color: "transparent"; border.color: "#2d5a8c"; border.width: 1
                            visible: false
                            ScrollView {
                                anchors.fill: parent; anchors.margins: 8; clip: true
                                Text {
                                    text: { var lines = []; for (var i = 0; i < cashCodeResultList.count; i++) lines.push(cashCodeResultList.get(i).code); return lines.join("\n") }
                                    color: "#22c55e"; font.pixelSize: 13; font.family: "Courier New"
                                }
                            }
                        }

                        RowLayout {
                            spacing: 10
                            Rectangle {
                                width: 160; height: 38; radius: 8
                                color: cashCodeGenMa.pressed ? "#15803d" : (cashCodeGenMa.containsMouse ? "#166534" : "#14532d")
                                border.color: "#4ade80"; border.width: 1
                                enabled: eventManager.isLoggedIn && cashNoteCombo.currentIndex > 0
                                opacity: enabled ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: "Tạo mã tiền mặt"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: cashCodeGenMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    enabled: eventManager.isLoggedIn && cashNoteCombo.currentIndex > 0
                                    onClicked: {
                                        var val   = parseInt(cashCodeValueField.text)  || 0
                                        var count = parseInt(cashCodeCountField.text) || 0
                                        if (val <= 0 || count <= 0) { autoSavedToast.show("Giá trị mã tiền mặt không hợp lệ"); return }
                                        // Ghi chú bắt buộc (đồng nhất với web).
                                        var note = cashNoteCombo.currentIndex > 0
                                                   ? voucherTabRoot.vNotes[cashNoteCombo.currentIndex - 1].content : ""
                                        if (!note) { autoSavedToast.show("Vui lòng chọn ghi chú"); return }
                                        function toIso(s) {
                                            s = s.trim(); if (!s) return ""
                                            var d = new Date(s.replace(" ", "T"))
                                            return isNaN(d.getTime()) ? "" : Qt.formatDateTime(d, "yyyy-MM-ddTHH:mm:ss")
                                        }
                                        var vf = toIso(genFromField.text)
                                        var vu = toIso(genUntilField.text)
                                        var shiftName = (shiftCombo.currentIndex >= 0 && shiftCombo.currentIndex < shiftModel.count)
                                                        ? shiftModel.get(shiftCombo.currentIndex).name : ""
                                        var codes = eventManager.generateCashPaymentCodes(val, count, vf, vu, shiftName, note)
                                        cashCodeResultList.clear()
                                        for (var i = 0; i < codes.length; i++) cashCodeResultList.append({ code: codes[i] })
                                        autoSavedToast.show("Đã tạo " + codes.length + " mã tiền mặt")
                                        cashPaymentCodeListModel.reload()
                                    }
                                }
                            }
                            Rectangle {
                                width: 120; height: 38; radius: 8
                                color: cashCodeDlMa.pressed ? "#2a7a2a" : (cashCodeDlMa.containsMouse ? "#3a8a3a" : "#1a4a1a")
                                border.color: "#4caf50"; border.width: 1
                                enabled: cashCodeResultList.count > 0
                                opacity: cashCodeResultList.count > 0 ? 1.0 : 0.4
                                Behavior on color { ColorAnimation { duration: 120 } }
                                Text { anchors.centerIn: parent; text: "Tải TXT ↓"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                                MouseArea {
                                    id: cashCodeDlMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var val = parseInt(cashCodeValueField.text) || 0
                                        var lines = [
                                            "# PhotoBooth Cash Payment Codes - Batch",
                                            "# Value: " + val,
                                            "# Hiệu lực: " + (genFromField.text || "—") + " -> " + (genUntilField.text || "không giới hạn"),
                                            "# Generated: " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm"),
                                            "# Count: " + cashCodeResultList.count, ""
                                        ]
                                        for (var i = 0; i < cashCodeResultList.count; i++) lines.push(cashCodeResultList.get(i).code)
                                        root.exportVoucherTxt(lines.join("\n"), "MaTien", "Batch")
                                    }
                                }
                            }
                        }
                        } // hết vùng nội dung tạo mã tiền mặt (collapsible)
                    }
                }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 240
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 12
                        color: "transparent"
                        border.color: "#4FA4F2"
                        border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Danh Sách Voucher"; color: "#1e7eea"; font.pixelSize: 15; font.bold: true }
                                Item { Layout.fillWidth: true }
                                Text { text: voucherListModel.count + " mã"; color: "#1e7eea"; font.pixelSize: 13; font.bold: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                radius: 6
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    Text { text: "Mã"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                    Text { text: "Giá trị"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 86 }
                                    Text { text: "Trạng thái"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 92 }
                                    Item { visible: eventManager.isAdmin; Layout.preferredWidth: visible ? 54 : 0 }
                                }
                            }

                            ListView {
                                id: voucherSideListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: voucherListModel
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                delegate: Rectangle {
                                    width: voucherSideListView.width
                                    height: 58
                                    radius: 7
                                    property var st: voucherTabRoot.voucherStatus(model.used, model.valid_from, model.valid_until)
                                    property bool checked: eventManager.isAdmin && voucherTabRoot.isSelected("voucher", model.code)
                                    color: checked ? "#bfdbfe" : st.rowBg
                                    border.color: checked ? "#1e7eea" : st.color
                                    border.width: checked ? 2 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Rectangle {
                                            visible: eventManager.isAdmin
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 4
                                            color: checked ? "#1e7eea" : "transparent"
                                            border.color: checked ? "#1e7eea" : "#64748b"
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: "✓"; visible: checked; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voucherTabRoot.toggleSelected("voucher", model.code, model.used) }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text { text: model.code; color: "#0f172a"; font.pixelSize: 13; font.family: "Courier New"; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                                // Nguồn tạo mã: Web (chủ studio) hay Máy (desktop). Mã từ máy chưa
                                                // đồng bộ lên cloud → chấm cam để admin biết cần kết nối mạng.
                                                Rectangle {
                                                    visible: model.created_via === "web"
                                                    color: "#dbeafe"; radius: 4
                                                    Layout.preferredHeight: 16; Layout.preferredWidth: webTag.width + 10
                                                    Text { id: webTag; anchors.centerIn: parent; text: "Web"; color: "#1e40af"; font.pixelSize: 9; font.bold: true }
                                                }
                                                Rectangle {
                                                    visible: model.created_via !== "web" && !model.synced
                                                    color: "#fff7ed"; radius: 4
                                                    Layout.preferredHeight: 16; Layout.preferredWidth: syncTag.width + 10
                                                    Text { id: syncTag; anchors.centerIn: parent; text: "Tại máy"; color: "#c2410c"; font.pixelSize: 9; font.bold: true }
                                                }
                                            }
                                            Text {
                                                text: {
                                                    function f(s) { return s ? s.replace("T", " ").substring(0, 16) : "∞" }
                                                    return (model.shift && model.shift !== "" ? model.shift + " · " : "") + f(model.valid_from) + " → " + f(model.valid_until)
                                                }
                                                color: "#334155"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                            Text {
                                                visible: model.note && model.note !== ""
                                                text: "✎ " + model.note
                                                color: "#475569"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            text: Money.vnd(model.value)
                                            color: "#0f172a"
                                            font.pixelSize: 12
                                            font.bold: true
                                            Layout.preferredWidth: 86
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 92
                                            height: 22
                                            radius: 11
                                            color: st.bg
                                            border.color: st.color
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: st.label; color: st.color; font.pixelSize: 10; font.bold: true }
                                        }

                                        Rectangle {
                                            visible: eventManager.isAdmin
                                            Layout.preferredWidth: visible ? 46 : 0
                                            height: 26
                                            radius: 6
                                            color: voucherDelOneMa.containsMouse ? "#dc2626" : "#ef4444"
                                            Text { anchors.centerIn: parent; text: "Xóa"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                                            MouseArea {
                                                id: voucherDelOneMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !voucherTabRoot.deleteBatchBusy
                                                onClicked: {
                                                    voucherTabRoot.deleteOneCode("voucher", model.code, model.used)
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: voucherListModel.count === 0
                                    text: "Chưa có voucher nào"
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 15
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: [{ label: "Tất cả", val: "all" }, { label: "Chưa dùng", val: "unused" }, { label: "Đã dùng", val: "used" }]
                                    delegate: Rectangle {
                                        Layout.preferredWidth: 74
                                        height: 30
                                        radius: 8
                                        property bool sel: voucherTabRoot.voucherFilter === modelData.val
                                        color: sel ? "#1e7eea" : "transparent"
                                        border.color: sel ? "#1e7eea" : "#2d5a8c"
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: modelData.label; color: parent.sel ? "#ffffff" : "#1e7eea"; font.pixelSize: 10; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                voucherTabRoot.voucherFilter = modelData.val
                                                voucherTabRoot.clearSelected("voucher")
                                                voucherListModel.reload()
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    visible: eventManager.isAdmin
                                    Layout.preferredWidth: visible ? 76 : 0
                                    height: 30
                                    radius: 8
                                    color: "#0ea5e9"
                                    Text { anchors.centerIn: parent; text: "Chọn tất"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voucherTabRoot.selectAllCodes("voucher", voucherListModel) }
                                }
                                Rectangle {
                                    visible: eventManager.isAdmin
                                    Layout.preferredWidth: visible ? 88 : 0
                                    height: 30
                                    radius: 8
                                    enabled: voucherTabRoot.selectedVoucherCount > 0 && !voucherTabRoot.deleteBatchBusy
                                    opacity: enabled ? 1.0 : 0.45
                                    color: "#ef4444"
                                    Text { anchors.centerIn: parent; text: "Xóa (" + voucherTabRoot.selectedVoucherCount + ")"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: parent.enabled; onClicked: voucherTabRoot.deleteSelectedCodes("voucher") }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 74
                                    height: 30
                                    radius: 8
                                    color: "#16a34a"
                                    Text { anchors.centerIn: parent; text: "TXT"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voucherTabRoot.exportCodes("voucher", voucherTabRoot.voucherFilter) }
                                }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                        radius: 12
                        color: "transparent"
                        border.color: "#22c55e"
                        border.width: 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Danh Sách Mã Tiền Mặt"; color: "#16a34a"; font.pixelSize: 15; font.bold: true }
                                Item { Layout.fillWidth: true }
                                Text { text: cashPaymentCodeListModel.count + " mã"; color: "#16a34a"; font.pixelSize: 13; font.bold: true }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 26
                                radius: 6
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8
                                    Text { text: "Mã"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.fillWidth: true }
                                    Text { text: "Số tiền"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 86 }
                                    Text { text: "Trạng thái"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 92 }
                                    Item { visible: eventManager.isAdmin; Layout.preferredWidth: visible ? 54 : 0 }
                                }
                            }

                            ListView {
                                id: cashSideListView
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: cashPaymentCodeListModel
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                                delegate: Rectangle {
                                    width: cashSideListView.width
                                    height: 58
                                    radius: 7
                                    property var st: voucherTabRoot.voucherStatus(model.used, model.valid_from, model.valid_until)
                                    property bool checked: eventManager.isAdmin && voucherTabRoot.isSelected("cash", model.code)
                                    color: checked ? "#bbf7d0" : st.rowBg
                                    border.color: checked ? "#16a34a" : st.color
                                    border.width: checked ? 2 : 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 8

                                        Rectangle {
                                            visible: eventManager.isAdmin
                                            Layout.preferredWidth: 22
                                            Layout.preferredHeight: 22
                                            radius: 4
                                            color: checked ? "#16a34a" : "transparent"
                                            border.color: checked ? "#16a34a" : "#64748b"
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: "✓"; visible: checked; color: "#ffffff"; font.pixelSize: 13; font.bold: true }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voucherTabRoot.toggleSelected("cash", model.code, model.used) }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6
                                                Text { text: model.code; color: "#0f172a"; font.pixelSize: 13; font.family: "Courier New"; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                                                // Nguồn tạo mã: Web (chủ studio) hay Máy (desktop). Mã từ máy chưa
                                                // đồng bộ lên cloud → chấm cam để admin biết cần kết nối mạng.
                                                Rectangle {
                                                    visible: model.created_via === "web"
                                                    color: "#dbeafe"; radius: 4
                                                    Layout.preferredHeight: 16; Layout.preferredWidth: webTag.width + 10
                                                    Text { id: webTag; anchors.centerIn: parent; text: "Web"; color: "#1e40af"; font.pixelSize: 9; font.bold: true }
                                                }
                                                Rectangle {
                                                    visible: model.created_via !== "web" && !model.synced
                                                    color: "#fff7ed"; radius: 4
                                                    Layout.preferredHeight: 16; Layout.preferredWidth: syncTag.width + 10
                                                    Text { id: syncTag; anchors.centerIn: parent; text: "Tại máy"; color: "#c2410c"; font.pixelSize: 9; font.bold: true }
                                                }
                                            }
                                            Text {
                                                text: {
                                                    function f(s) { return s ? s.replace("T", " ").substring(0, 16) : "∞" }
                                                    return (model.shift && model.shift !== "" ? model.shift + " · " : "") + f(model.valid_from) + " → " + f(model.valid_until)
                                                }
                                                color: "#334155"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                            Text {
                                                visible: model.note && model.note !== ""
                                                text: "✎ " + model.note
                                                color: "#475569"; font.pixelSize: 10; elide: Text.ElideRight; Layout.fillWidth: true
                                            }
                                        }

                                        Text {
                                            text: Money.vnd(model.value)
                                            color: "#0f172a"
                                            font.pixelSize: 12
                                            font.bold: true
                                            Layout.preferredWidth: 86
                                            horizontalAlignment: Text.AlignRight
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 92
                                            height: 22
                                            radius: 11
                                            color: st.bg
                                            border.color: st.color
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: st.label; color: st.color; font.pixelSize: 10; font.bold: true }
                                        }

                                        Rectangle {
                                            visible: eventManager.isAdmin
                                            Layout.preferredWidth: visible ? 46 : 0
                                            height: 26
                                            radius: 6
                                            color: cashDelOneMa.containsMouse ? "#dc2626" : "#ef4444"
                                            Text { anchors.centerIn: parent; text: "Xóa"; color: "#ffffff"; font.pixelSize: 11; font.bold: true }
                                            MouseArea {
                                                id: cashDelOneMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                enabled: !voucherTabRoot.deleteBatchBusy
                                                onClicked: {
                                                    voucherTabRoot.deleteOneCode("cash", model.code, model.used)
                                                }
                                            }
                                        }
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: cashPaymentCodeListModel.count === 0
                                    text: "Chưa có mã tiền mặt nào"
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 15
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: [{ label: "Tất cả", val: "all" }, { label: "Chưa dùng", val: "unused" }, { label: "Đã dùng", val: "used" }]
                                    delegate: Rectangle {
                                        Layout.preferredWidth: 74
                                        height: 30
                                        radius: 8
                                        property bool sel: voucherTabRoot.cashFilter === modelData.val
                                        color: sel ? "#16a34a" : "transparent"
                                        border.color: sel ? "#16a34a" : "#2d5a8c"
                                        border.width: 1
                                        Text { anchors.centerIn: parent; text: modelData.label; color: parent.sel ? "#ffffff" : "#16a34a"; font.pixelSize: 10; font.bold: true }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                voucherTabRoot.cashFilter = modelData.val
                                                voucherTabRoot.clearSelected("cash")
                                                cashPaymentCodeListModel.reload()
                                            }
                                        }
                                    }
                                }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    visible: eventManager.isAdmin
                                    Layout.preferredWidth: visible ? 76 : 0
                                    height: 30
                                    radius: 8
                                    color: "#0ea5e9"
                                    Text { anchors.centerIn: parent; text: "Chọn tất"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voucherTabRoot.selectAllCodes("cash", cashPaymentCodeListModel) }
                                }
                                Rectangle {
                                    visible: eventManager.isAdmin
                                    Layout.preferredWidth: visible ? 88 : 0
                                    height: 30
                                    radius: 8
                                    enabled: voucherTabRoot.selectedCashCount > 0 && !voucherTabRoot.deleteBatchBusy
                                    opacity: enabled ? 1.0 : 0.45
                                    color: "#ef4444"
                                    Text { anchors.centerIn: parent; text: "Xóa (" + voucherTabRoot.selectedCashCount + ")"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: parent.enabled; onClicked: voucherTabRoot.deleteSelectedCodes("cash") }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 74
                                    height: 30
                                    radius: 8
                                    color: "#16a34a"
                                    Text { anchors.centerIn: parent; text: "TXT"; color: "#ffffff"; font.pixelSize: 10; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voucherTabRoot.exportCodes("cash", voucherTabRoot.cashFilter) }
                                }
                            }
                        }
                    }
                }

                // ── Danh sách voucher (collapsible) ──────────────────────────
                Rectangle {
                    visible: false
                    Layout.fillWidth: true
                    Layout.fillHeight: voucherTabRoot.voucherListOpen
                    Layout.maximumHeight: voucherTabRoot.voucherListOpen ? 99999 : 60
                    Layout.minimumHeight: 60
                    radius: 12; color: "transparent"
                    border.color: voucherTabRoot.voucherListOpen ? "#4FA4F2" : Theme.border; border.width: 1
                    clip: true
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10

                        // ── Header row ────────────────────────────────────────
                        RowLayout {
                            Layout.fillWidth: true; spacing: 6

                            // Cả phần tiêu đề là nút bấm mở/đóng — luôn thấy để mở lại
                            Rectangle {
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: titleRow.implicitWidth + 16
                                radius: 8
                                color: titleMa.containsMouse ? "#2a3040" : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                                RowLayout {
                                    id: titleRow
                                    anchors.centerIn: parent
                                    spacing: 8
                                    Text { text: voucherTabRoot.voucherListOpen ? "▼" : "▶"; color: "#4FA4F2"; font.pixelSize: 14; font.bold: true }
                                    Text { text: "Danh Sách Voucher"; color: root.themeTextColor; font.pixelSize: 15; font.bold: true }
                                }
                                MouseArea {
                                    id: titleMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: voucherTabRoot.voucherListOpen = !voucherTabRoot.voucherListOpen
                                }
                            }

                            Item { Layout.fillWidth: true }

                            // Filter pills (ẩn khi thu gọn)
                            Repeater {
                                model: [{ label: "Tất cả", val: "all" }, { label: "Chưa dùng", val: "unused" }, { label: "Đã dùng", val: "used" }]
                                delegate: Rectangle {
                                    visible: voucherTabRoot.voucherListOpen
                                    width: visible ? 82 : 0; height: 26; radius: 13
                                    property bool sel: voucherListFilter.currentFilter === modelData.val
                                    color: sel ? "#4FA4F2" : (fMa.containsMouse ? "#2a3040" : Theme.surface)
                                    border.color: sel ? "#4FA4F2" : Theme.border; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 100 } }
                                    Text { anchors.centerIn: parent; text: modelData.label; color: root.themeTextColor; font.pixelSize: 10; font.bold: parent.sel }
                                    MouseArea { id: fMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { voucherListFilter.currentFilter = modelData.val; voucherListModel.reload(); cashPaymentCodeListModel.reload() } }
                                }
                            }

                            // Separator
                            Rectangle { visible: voucherTabRoot.voucherListOpen; width: 1; height: 24; color: Theme.border }

                            // Export current filter to TXT (ẩn khi thu gọn)
                            Rectangle {
                                visible: voucherTabRoot.voucherListOpen
                                width: visible ? 90 : 0; height: 26; radius: 7
                                color: exportMa.pressed ? "#2a7a2a" : (exportMa.containsMouse ? "#3a8a3a" : "#1a4a1a")
                                border.color: "#4caf50"; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Xuất TXT ↓"; color: root.themeTextColor; font.pixelSize: 10; font.bold: true }
                                MouseArea {
                                    id: exportMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var filter = voucherListFilter.currentFilter
                                        var list = eventManager.getVoucherList(filter)
                                        var lines = ["# PhotoBooth Vouchers Export", "# Filter: " + filter,
                                                     "# Date: " + Qt.formatDate(new Date(), "yyyy-MM-dd"),
                                                     "# Count: " + list.length, ""]
                                        for (var i = 0; i < list.length; i++) lines.push(list[i].code)
                                        var statusLabel = filter === "unused" ? "Chưa dùng"
                                                        : (filter === "used" ? "Đã dùng" : "Tất cả")
                                        root.exportVoucherTxt(lines.join("\n"), "Voucher", statusLabel)
                                    }
                                }
                            }
                        }

                        // ── Column header ─────────────────────────────────────
                        Rectangle {
                            Layout.fillWidth: true; height: 28; radius: 6; color: "transparent"
                            visible: voucherTabRoot.voucherListOpen
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                Text { text: "Code";       color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 170 }
                                Text { text: "Giá trị";    color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 96  }
                                Text { text: "Trạng thái"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 86  }
                                Text { text: "Ca";         color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 80  }
                                Text { text: "Hiệu lực";   color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.fillWidth: true    }
                                Item { Layout.preferredWidth: 60 }
                            }
                        }

                        // ── ListView ──────────────────────────────────────────
                        ListView {
                            id: voucherListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: voucherTabRoot.voucherListOpen
                            model: voucherListModel
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                width: voucherListView.width; height: 42; radius: 6
                                color: index % 2 === 0 ? Theme.surface : Theme.field

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                                    Text { text: model.code; color: "#4FA4F2"; font.pixelSize: 13; font.family: "Courier New"; Layout.preferredWidth: 170; elide: Text.ElideRight }
                                    Text {
                                        text: Money.vnd(model.value)
                                        color: root.themeTextColor; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 96
                                    }
                                    Rectangle {
                                        // Trạng thái: Đã dùng / Hết hạn / Chưa hiệu lực / Chưa dùng
                                        property var st: voucherTabRoot.voucherStatus(model.used, model.valid_from, model.valid_until)
                                        Layout.preferredWidth: 100; height: 20; radius: 10
                                        color: st.bg
                                        border.color: st.color; border.width: 1
                                        Text { anchors.centerIn: parent; text: parent.st.label; color: parent.st.color; font.pixelSize: 10; font.bold: true }
                                    }
                                    // Ca làm việc
                                    Text {
                                        text: model.shift && model.shift !== "" ? model.shift : "—"
                                        color: model.shift && model.shift !== "" ? "#7fb8f0" : root.mutedText(0.65)
                                        font.pixelSize: 11; font.bold: true
                                        Layout.preferredWidth: 80; elide: Text.ElideRight
                                    }
                                    // Khung giờ hiệu lực theo ca
                                    Text {
                                        text: {
                                            if (!model.valid_from && !model.valid_until) return "—"
                                            function f(s) { return s ? s.replace("T", " ").substring(0, 16) : "…" }
                                            return f(model.valid_from) + " → " + (model.valid_until ? f(model.valid_until) : "∞")
                                        }
                                        color: root.mutedText(0.65); font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: visible ? 58 : 0; height: 26; radius: 6
                                        visible: eventManager.isAdmin
                                        color: dMa.pressed ? "#8b2020" : (dMa.containsMouse ? "#aa2828" : Theme.field)
                                        border.color: "#5a3535"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: "Xóa"; color: "#ef9a9a"; font.pixelSize: 11 }
                                        MouseArea {
                                            id: dMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !voucherTabRoot.deleteBatchBusy
                                            onClicked: {
                                                voucherTabRoot.deleteOneCode("voucher", model.code, model.used)
                                            }
                                        }
                                    }
                                    Item { visible: !eventManager.isAdmin; Layout.preferredWidth: 58 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: voucherListModel.count === 0
                                text: "Chưa có voucher nào"
                                color: root.mutedText(0.65); font.pixelSize: 15
                            }
                        }
                    }
                }

                // ── Danh sách mã tiền mặt ───────────────────────────────────
                Rectangle {
                    visible: false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 240
                    radius: 12; color: "transparent"
                    border.color: "#22c55e"; border.width: 1

                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8
                            Text { text: "Danh Sách Mã Tiền Mặt"; color: root.themeTextColor; font.pixelSize: 15; font.bold: true }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: eventManager.getCashPaymentCodeCount(voucherListFilter.currentFilter) + " mã"
                                color: "#9ae6b4"; font.pixelSize: 13; font.bold: true
                            }
                            Rectangle {
                                width: 90; height: 26; radius: 7
                                color: cashCodeExportMa.pressed ? "#2a7a2a" : (cashCodeExportMa.containsMouse ? "#3a8a3a" : "#1a4a1a")
                                border.color: "#4caf50"; border.width: 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Xuất TXT ↓"; color: root.themeTextColor; font.pixelSize: 10; font.bold: true }
                                MouseArea {
                                    id: cashCodeExportMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var filter = voucherListFilter.currentFilter
                                        var list = eventManager.getCashPaymentCodeList(filter)
                                        var lines = ["# PhotoBooth Cash Payment Codes Export", "# Filter: " + filter,
                                                     "# Date: " + Qt.formatDate(new Date(), "yyyy-MM-dd"),
                                                     "# Count: " + list.length, ""]
                                        for (var i = 0; i < list.length; i++) lines.push(list[i].code)
                                        var statusLabel = filter === "unused" ? "Chưa dùng"
                                                        : (filter === "used" ? "Đã dùng" : "Tất cả")
                                        root.exportVoucherTxt(lines.join("\n"), "MaTien", statusLabel)
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true; height: 28; radius: 6; color: "transparent"
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                                Text { text: "Code";       color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 170 }
                                Text { text: "Số tiền";    color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 96  }
                                Text { text: "Trạng thái"; color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 100 }
                                Text { text: "Ca";         color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.preferredWidth: 80  }
                                Text { text: "Hiệu lực";   color: root.mutedText(0.65); font.pixelSize: 11; font.bold: true; Layout.fillWidth: true    }
                                Item { Layout.preferredWidth: 60 }
                            }
                        }

                        ListView {
                            id: cashPaymentCodeListView
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            model: cashPaymentCodeListModel
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                            delegate: Rectangle {
                                width: cashPaymentCodeListView.width; height: 42; radius: 6
                                color: index % 2 === 0 ? Theme.surface : Theme.field

                                RowLayout {
                                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                                    Text { text: model.code; color: "#22c55e"; font.pixelSize: 13; font.family: "Courier New"; Layout.preferredWidth: 170; elide: Text.ElideRight }
                                    Text {
                                        text: Money.vnd(model.value)
                                        color: root.themeTextColor; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 96
                                    }
                                    Rectangle {
                                        property var st: voucherTabRoot.voucherStatus(model.used, model.valid_from, model.valid_until)
                                        Layout.preferredWidth: 100; height: 20; radius: 10
                                        color: st.bg
                                        border.color: st.color; border.width: 1
                                        Text { anchors.centerIn: parent; text: parent.st.label; color: parent.st.color; font.pixelSize: 10; font.bold: true }
                                    }
                                    Text {
                                        text: model.shift && model.shift !== "" ? model.shift : "—"
                                        color: model.shift && model.shift !== "" ? "#7fb8f0" : root.mutedText(0.65)
                                        font.pixelSize: 11; font.bold: true
                                        Layout.preferredWidth: 80; elide: Text.ElideRight
                                    }
                                    Text {
                                        text: {
                                            if (!model.valid_from && !model.valid_until) return "—"
                                            function f(s) { return s ? s.replace("T", " ").substring(0, 16) : "…" }
                                            return f(model.valid_from) + " → " + (model.valid_until ? f(model.valid_until) : "∞")
                                        }
                                        color: root.mutedText(0.65); font.pixelSize: 10; Layout.fillWidth: true; elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        Layout.preferredWidth: visible ? 58 : 0; height: 26; radius: 6
                                        visible: eventManager.isAdmin
                                        color: cashCodeDelMa.pressed ? "#8b2020" : (cashCodeDelMa.containsMouse ? "#aa2828" : Theme.field)
                                        border.color: "#5a3535"; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 100 } }
                                        Text { anchors.centerIn: parent; text: "Xóa"; color: "#ef9a9a"; font.pixelSize: 11 }
                                        MouseArea {
                                            id: cashCodeDelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; enabled: !voucherTabRoot.deleteBatchBusy
                                            onClicked: {
                                                voucherTabRoot.deleteOneCode("cash", model.code, model.used)
                                            }
                                        }
                                    }
                                    Item { visible: !eventManager.isAdmin; Layout.preferredWidth: 58 }
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: cashPaymentCodeListModel.count === 0
                                text: "Chưa có mã tiền mặt nào"
                                color: root.mutedText(0.65); font.pixelSize: 15
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Payment Tab Component removed ────────────────────────────────────────
    // paymentTabComponent removed

    // ============================================
    // FILTER TAB COMPONENT (index 8)
    // ============================================

    Component {
        id: filterTabComponent
        Item {
            id: filterTabRoot

            // Reload filter list whenever tab becomes active
            property var filterList: []
            property var stickerList: []
            property string editingId: ""
            property string editingName: ""

            function reloadFilters() {
                filterList = filterManager.getFilters()
            }
            function reloadStickers() {
                stickerList = stickerManager.getStickers()
            }

            Connections {
                target: filterManager
                function onFiltersChanged() { filterTabRoot.reloadFilters() }
            }
            Connections {
                target: stickerManager
                function onStickersChanged() { filterTabRoot.reloadStickers() }
            }

            Component.onCompleted: { reloadFilters(); reloadStickers() }

            // Rename dialog
            Popup {
                id: renamePopup
                modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                anchors.centerIn: parent
                width: 360
                height: 180
                closePolicy: Popup.CloseOnEscape

                onOpened: renameField.forceActiveFocus()

                background: Rectangle { color: "transparent"; radius: 12; border.color: "#2d5a8c"; border.width: 1 }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16

                    Text { text: "Đổi tên bộ lọc"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }

                    TextField {
                        id: renameField
                        Layout.fillWidth: true
                        text: filterTabRoot.editingName
                        color: root.themeTextColor
                        font.pixelSize: 15
                        background: Rectangle { color: "transparent"; radius: 6; border.color: "#2d5a8c"; border.width: 1 }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Huỷ"
                            onClicked: renamePopup.close()
                            background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? "#1e7eea" : "#2d5a8c"; border.width: 1 }
                            contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                        }
                        Button {
                            text: "Lưu"
                            onClicked: {
                                filterManager.renameFilter(filterTabRoot.editingId, renameField.text)
                                renamePopup.close()
                            }
                            background: Rectangle { color: parent.hovered ? "#1565c0" : "#1e7eea"; radius: 6 }
                            contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }

            ScrollView {
                anchors.fill: parent
                contentWidth: parent.width
                clip: true

                ColumnLayout {
                    width: parent.width - 80
                    spacing: 24

                    Text { text: "Trải nghiệm chỉnh ảnh"; color: Theme.settingsText; font.pixelSize: 18; font.weight: Font.DemiBold }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 1050 ? 3 : 1
                        columnSpacing: 12; rowSpacing: 12
                        SettingsToggleRow {
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            title: "Bộ lọc màu"
                            description: "Hiện bước chọn filter sau khi ghép ảnh."
                            checked: eventManager.getAppSetting("filter_enabled", "false") === "true"
                            onToggled: function(next) { eventManager.setAppSetting("filter_enabled", next ? "true" : "false"); autoSavedToast.show(next ? "Đã bật bộ lọc màu" : "Đã tắt bộ lọc màu") }
                        }
                        SettingsToggleRow {
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            title: "Sticker"
                            description: "Cho phép khách dán sticker trước khi in."
                            checked: eventManager.getAppSetting("sticker_enabled", "false") === "true"
                            onToggled: function(next) { eventManager.setAppSetting("sticker_enabled", next ? "true" : "false"); autoSavedToast.show(next ? "Đã bật sticker" : "Đã tắt sticker") }
                        }
                        SettingsToggleRow {
                            Layout.fillWidth: true; Layout.preferredWidth: 1
                            title: "Áp dụng cho toàn bộ ảnh"
                            description: "Một lựa chọn filter được áp dụng cho mọi ảnh."
                            checked: eventManager.getAppSetting("filter_apply_all_photos", "false") === "true"
                            onToggled: function(next) { eventManager.setAppSetting("filter_apply_all_photos", next ? "true" : "false"); autoSavedToast.show(next ? "Áp dụng filter cho toàn bộ ảnh" : "Áp dụng filter theo từng ảnh") }
                        }
                    }

                    // Header + Upload button
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { text: "Bộ Lọc Màu"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                            Text { text: "Quản lý các bộ lọc màu .cube để áp dụng lên ảnh."; color: root.mutedText(0.65); font.pixelSize: 14 }
                        }

                        Button {
                            text: "＋ Thêm bộ lọc"
                            onClicked: cubeUploadDialog.open()
                            background: Rectangle {
                                color: parent.hovered ? "#1565c0" : "#1e7eea"
                                radius: 8
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Text {
                                text: parent.text; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            implicitWidth: 160; implicitHeight: 44
                        }
                    }

                    // Filter list
                    Repeater {
                        model: filterTabRoot.filterList

                        delegate: Rectangle {
                            id: filterCard
                            Layout.fillWidth: true
                            height: 100
                            color: "transparent"
                            radius: 10
                            border.color: "#2d5a8c"
                            border.width: 1

                            property var fd: filterTabRoot.filterList[index]

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                // Thumbnail
                                Rectangle {
                                    width: 68; height: 68
                                    radius: 8
                                    color: "transparent"
                                    clip: true

                                    Image {
                                        anchors.fill: parent
                                        source: filterCard.fd && filterCard.fd.thumbnailPath
                                                ? ("file:///" + filterCard.fd.thumbnailPath.replace(/\\/g, "/") + "?t=" + Date.now())
                                                : ""
                                        fillMode: Image.PreserveAspectCrop
                                        visible: filterCard.fd && filterCard.fd.thumbnailPath !== ""
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🎨"
                                        font.pixelSize: 28
                                        visible: !filterCard.fd || filterCard.fd.thumbnailPath === ""
                                    }
                                }

                                // Name + file info
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4

                                    Text {
                                        text: filterCard.fd ? filterCard.fd.name : ""
                                        color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                    Text {
                                        text: filterCard.fd ? filterCard.fd.cubePath.split("/").pop().split("\\").pop() : ""
                                        color: root.mutedText(0.65); font.pixelSize: 13
                                        elide: Text.ElideRight; Layout.fillWidth: true
                                    }
                                }

                                // Action buttons
                                RowLayout {
                                    spacing: 8

                                    // ── Favourite toggle ──────────────
                                    Rectangle {
                                        implicitWidth: 44; implicitHeight: 36
                                        radius: 6
                                        property bool isFav: filterCard.fd ? filterCard.fd.favorite === true : false
                                        color: "transparent"
                                        border.color: isFav ? "#f5a623" : Theme.border; border.width: 1
                                        Behavior on color { ColorAnimation { duration: 150 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: parent.isFav ? "⭐" : "☆"
                                            font.pixelSize: 18
                                        }

                                        MouseArea {
                                            id: favMA
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                filterManager.toggleFilterFavorite(filterCard.fd.id)
                                            }
                                        }
                                    }

                                    // Rename
                                    Button {
                                        text: "✏️ Đổi tên"
                                        implicitWidth: 100; implicitHeight: 36
                                        onClicked: {
                                            filterTabRoot.editingId = filterCard.fd.id
                                            filterTabRoot.editingName = filterCard.fd.name
                                            renamePopup.open()
                                        }
                                        background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? "#1e7eea" : "#2d5a8c"; border.width: 1 }
                                        contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }

                                    // Set thumbnail
                                    Button {
                                        text: "🖼️ Chọn ảnh"
                                        implicitWidth: 110; implicitHeight: 36
                                        onClicked: {
                                            root._filterDialogTargetId = filterCard.fd.id
                                            filterThumbnailDialog.open()
                                        }
                                        background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? "#1e7eea" : "#2d5a8c"; border.width: 1 }
                                        contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }

                                    // Replace cube
                                    Button {
                                        text: "🔄 Thay cube"
                                        implicitWidth: 110; implicitHeight: 36
                                        onClicked: {
                                            root._filterDialogTargetId = filterCard.fd.id
                                            filterReplaceDialog.open()
                                        }
                                        background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? "#1e7eea" : "#2d5a8c"; border.width: 1 }
                                        contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }

                                    // Delete
                                    Button {
                                        text: "🗑️ Xoá"
                                        implicitWidth: 80; implicitHeight: 36
                                        onClicked: {
                                            filterManager.deleteFilter(filterCard.fd.id)
                                        }
                                        background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? "#dc2626" : "#2d5a8c"; border.width: 1 }
                                        contentItem: Text { text: parent.text; color: parent.hovered ? "#fca5a5" : "#e74c3c"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    }
                                }
                            }
                        }
                    }

                    // Empty state
                    Rectangle {
                        Layout.fillWidth: true
                        height: 160
                        color: "transparent"
                        radius: 10
                        border.color: "#2d5a8c"
                        border.width: 1
                        visible: filterTabRoot.filterList.length === 0

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 12
                            Text { Layout.alignment: Qt.AlignHCenter; text: "🎨"; font.pixelSize: 40 }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Chưa có bộ lọc nào"; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Bấm \"Thêm bộ lọc\" để tải file .cube lên"; color: root.mutedText(0.65); font.pixelSize: 14 }
                        }
                    }

                    // ── Divider ──
                    Rectangle { Layout.fillWidth: true; height: 1; color: "transparent" }

                    // ── Sticker library ──
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 16

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            Text { text: "Sticker"; color: root.themeTextColor; font.pixelSize: 20; font.weight: Font.Bold }
                            Text { text: "Thư viện sticker (PNG trong suốt) để dán lên ảnh ở trang chọn bộ lọc."; color: root.mutedText(0.65); font.pixelSize: 14 }
                        }

                        Button {
                            text: "＋ Tải sticker"
                            onClicked: stickerUploadDialog.open()
                            background: Rectangle {
                                color: parent.hovered ? "#1565c0" : "#1e7eea"; radius: 8
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Text {
                                text: parent.text; color: root.themeTextColor; font.pixelSize: 15; font.weight: Font.Medium
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            implicitWidth: 160; implicitHeight: 44
                        }
                    }

                    // Sticker grid
                    Flow {
                        Layout.fillWidth: true
                        spacing: 12
                        visible: filterTabRoot.stickerList.length > 0

                        Repeater {
                            model: filterTabRoot.stickerList
                            delegate: Rectangle {
                                width: 120; height: 150
                                color: "transparent"; radius: 10
                                border.color: "#2d5a8c"; border.width: 1

                                property var sd: filterTabRoot.stickerList[index]

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 4

                                    Image {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        source: sd && sd.path ? ("file:///" + sd.path.replace(/\\/g, "/")) : ""
                                        fillMode: Image.PreserveAspectFit
                                        asynchronous: true
                                        sourceSize.width: 200; sourceSize.height: 200
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: sd ? sd.name : ""
                                        color: root.mutedText(0.65); font.pixelSize: 11
                                        elide: Text.ElideMiddle; horizontalAlignment: Text.AlignHCenter
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Rectangle {
                                            Layout.fillWidth: true; height: 22; radius: 4
                                            color: "transparent"
                                            border.color: stkRenameHover.containsMouse ? "#1e7eea" : "#2d5a8c"
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: "Sửa"; color: "#5dade2"; font.pixelSize: 10 }
                                            MouseArea {
                                                id: stkRenameHover
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    filterTabRoot.editingId = sd.id
                                                    filterTabRoot.editingName = sd.name
                                                    stickerRenamePopup.open()
                                                }
                                            }
                                        }
                                        Rectangle {
                                            Layout.fillWidth: true; height: 22; radius: 4
                                            color: "transparent"
                                            border.color: stkDelHover.containsMouse ? "#e74c3c" : "#2d5a8c"
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: "Xóa"; color: "#e74c3c"; font.pixelSize: 10 }
                                            MouseArea {
                                                id: stkDelHover
                                                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                onClicked: stickerManager.deleteSticker(sd.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        visible: filterTabRoot.stickerList.length === 0
                        Layout.fillWidth: true
                        text: "Chưa có sticker. Bấm \"Tải sticker\" để thêm PNG."
                        color: root.mutedText(0.65); font.pixelSize: 14
                    }

                    Item { Layout.fillWidth: true; Layout.preferredHeight: 40 }
                }
            }

            // Sticker rename dialog
            Popup {
                id: stickerRenamePopup
                modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                anchors.centerIn: parent
                width: 360; height: 180
                closePolicy: Popup.CloseOnEscape
                onOpened: stickerRenameField.forceActiveFocus()
                background: Rectangle { color: "transparent"; radius: 12; border.color: "#2d5a8c"; border.width: 1 }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 16
                    Text { text: "Đổi tên sticker"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }
                    TextField {
                        id: stickerRenameField
                        Layout.fillWidth: true
                        text: filterTabRoot.editingName
                        color: root.themeTextColor; font.pixelSize: 15
                        background: Rectangle { color: "transparent"; radius: 6; border.color: "#2d5a8c"; border.width: 1 }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Item { Layout.fillWidth: true }
                        Button {
                            text: "Huỷ"
                            onClicked: stickerRenamePopup.close()
                            background: Rectangle { color: "transparent"; radius: 6; border.color: parent.hovered ? "#1e7eea" : "#2d5a8c"; border.width: 1 }
                            contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                        }
                        Button {
                            text: "Lưu"
                            onClicked: {
                                stickerManager.renameSticker(filterTabRoot.editingId, stickerRenameField.text)
                                stickerRenamePopup.close()
                            }
                            background: Rectangle { color: parent.hovered ? "#1565c0" : "#1e7eea"; radius: 6 }
                            contentItem: Text { text: parent.text; color: root.themeTextColor; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }
        }
    }

    // ============================================
    // MAIN LAYOUT
    // ============================================

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Warm Luxury header (luôn hiện) ───────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 78
            color: Theme.settingsSurface
            border.color: Theme.settingsBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                spacing: 12

                Rectangle {
                    Layout.preferredWidth: 46; Layout.preferredHeight: 46
                    radius: 14
                    color: warmBackMouse.containsMouse ? Theme.settingsCopperSoft : Theme.settingsCard
                    border.color: warmBackMouse.containsMouse ? Theme.settingsCopper : Theme.settingsBorder
                    SettingsIcon { anchors.centerIn: parent; width: 22; height: 22; name: "arrow-left"; color: Theme.settingsText }
                    MouseArea {
                        id: warmBackMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.currentTab === 0 && root.generalSectionTitle !== "")
                                root.generalSectionTitle = ""
                            else if (root.currentTab >= 0)
                                root.currentTab = -1
                            else
                                root.backClicked()
                        }
                    }
                }

                ColumnLayout {
                    Layout.preferredWidth: root.currentTab === -1 ? 280 : 440
                    spacing: 2
                    Text {
                        text: root.currentTab === -1 ? "TRUNG TÂM CÀI ĐẶT" : "DANH MỤC  /  " + sidebarModel.get(root.currentTab).name.toUpperCase()
                        color: Theme.settingsCopper
                        font.pixelSize: 10
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                    }
                    Text {
                        text: root.currentTab === -1 ? "Cài đặt Selfbooth"
                              : (root.currentTab === 0 && root.generalSectionTitle !== ""
                                 ? root.generalSectionTitle : sidebarModel.get(root.currentTab).name)
                        color: Theme.settingsText
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.maximumWidth: 430
                    Layout.preferredHeight: 44
                    visible: root.currentTab === -1
                    radius: 14
                    color: Theme.settingsCard
                    border.color: warmSearch.activeFocus ? Theme.settingsCopper : Theme.settingsBorder
                    border.width: warmSearch.activeFocus ? 2 : 1
                    SettingsIcon { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; width: 19; height: 19; name: "search"; color: Theme.settingsTextMuted }
                    TextField {
                        id: warmSearch
                        anchors.fill: parent
                        leftPadding: 44; rightPadding: 38
                        placeholderText: "Tìm nhanh cài đặt..."
                        color: Theme.settingsText
                        placeholderTextColor: Theme.settingsTextMuted
                        font.pixelSize: 14
                        background: Item {}
                        onTextChanged: root.settingsSearchText = text
                        Keys.onEscapePressed: text = ""
                    }
                    Text {
                        anchors.right: parent.right; anchors.rightMargin: 13; anchors.verticalCenter: parent.verticalCenter
                        visible: warmSearch.text.length > 0
                        text: "×"; color: Theme.settingsTextMuted; font.pixelSize: 22
                        MouseArea { anchors.fill: parent; anchors.margins: -10; cursorShape: Qt.PointingHandCursor; onClicked: warmSearch.text = "" }
                    }
                }

                Item { Layout.fillWidth: root.currentTab !== -1 }

                Rectangle {
                    Layout.preferredWidth: root.width <= 1100 ? 44 : 108; Layout.preferredHeight: 36
                    radius: 12
                    color: "#EDF8F3"
                    border.color: "#CDE9DC"
                    RowLayout {
                        anchors.centerIn: parent; spacing: 7
                        Rectangle { width: 7; height: 7; radius: 4; color: Theme.settingsSuccess }
                        Text { visible: root.width > 1100; text: "Đã tự lưu"; color: Theme.settingsSuccess; font.pixelSize: 12; font.weight: Font.DemiBold }
                    }
                }

                Rectangle {
                    id: warmFullscreenButton
                    Layout.preferredWidth: 44; Layout.preferredHeight: 44
                    radius: 14; color: warmFullscreenMouse.containsMouse ? Theme.settingsCopperSoft : Theme.settingsCard
                    border.color: Theme.settingsBorder
                    SettingsIcon { anchors.centerIn: parent; width: 20; height: 20; name: "maximize"; color: Theme.settingsText }
                    MouseArea {
                        id: warmFullscreenMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var win = Window.window
                            if (!win) return
                            var goFull = win.visibility !== Window.FullScreen
                            if (goFull) win.showFullScreen(); else win.showNormal()
                            eventManager.setAppSetting("Bật Full Màn Hình", goFull ? "true" : "false")
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: root.width <= 1100 ? 44 : 150; Layout.preferredHeight: 44
                    radius: 14; color: Theme.settingsCard; border.color: Theme.settingsBorder
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 8
                        Rectangle {
                            width: 28; height: 28; radius: 14; color: Theme.settingsCopperSoft
                            SettingsIcon { anchors.centerIn: parent; width: 16; height: 16; name: "account"; color: Theme.settingsCopper }
                        }
                        ColumnLayout {
                            visible: root.width > 1100
                            Layout.fillWidth: true; spacing: 0
                            Text { Layout.fillWidth: true; text: eventManager.isAdmin ? "Quản trị viên" : (eventManager.currentEmployeeName || "Nhân viên"); color: Theme.settingsText; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            Text { text: eventManager.isAdmin ? "ADMIN" : "STAFF"; color: Theme.settingsTextMuted; font.pixelSize: 9 }
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 44; Layout.preferredHeight: 44
                    radius: 14; color: warmMoreMouse.containsMouse ? Theme.settingsCopperSoft : Theme.settingsCard
                    border.color: Theme.settingsBorder
                    SettingsIcon { anchors.centerIn: parent; width: 20; height: 20; name: "more"; color: Theme.settingsText }
                    MouseArea {
                        id: warmMoreMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            warmUtilityPopup.x = Overlay.overlay.width - warmUtilityPopup.width - 24
                            warmUtilityPopup.y = 70
                            warmUtilityPopup.open()
                        }
                    }
                }
            }

            Popup {
                id: warmUtilityPopup
                parent: Overlay.overlay
                width: 280
                padding: 8
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                background: Rectangle { color: Theme.settingsSurface; radius: 16; border.color: Theme.settingsBorder; border.width: 1 }
                contentItem: Column {
                    spacing: 4
                    Rectangle {
                        width: parent.width; height: 50; radius: 10; color: logoutActionMouse.containsMouse ? Theme.settingsCopperSoft : "transparent"
                        visible: studioAccount.loggedIn
                        Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; spacing: 12
                            Image {
                                width: 20
                                height: 20
                                source: "qrc:/assets/icons/logout_account.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                            Text { text: "Đăng xuất tài khoản"; color: Theme.settingsText; font.pixelSize: 14 }
                        }
                        MouseArea { id: logoutActionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { warmUtilityPopup.close(); googleLogoutDialog.open() } }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.settingsBorder }
                    Rectangle {
                        width: parent.width; height: 50; radius: 10; color: exitActionMouse.containsMouse ? "#FDECEC" : "transparent"
                        Row { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 14; spacing: 12
                            Image {
                                width: 20
                                height: 20
                                source: "qrc:/assets/icons/quit_app.png"
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                                mipmap: true
                            }
                            Text { text: "Thoát phần mềm"; color: Theme.settingsDanger; font.pixelSize: 14; font.weight: Font.DemiBold }
                        }
                        MouseArea { id: exitActionMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { warmUtilityPopup.close(); exitConfirmDialog.open() } }
                    }
                }
            }
        }

        // Header cũ được giữ lại tạm thời để giảm rủi ro với các dialog tham chiếu id.
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 0
            visible: false
            color: root.themeSurfaceColor
            border.color: root.themeBorderColor
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                Button {
                    // Ở menu: thoát Cài đặt. Trong một mục: quay về lưới danh mục.
                    text: root.currentTab >= 0 ? "⬅ Danh mục" : "⬅ Quay Lại"
                    Layout.preferredHeight: 36

                    background: Rectangle {
                        color: parent.hovered ? root.themeFieldColor : root.themeSurfaceColor
                        radius: 6
                        border.color: root.themeBorderColor
                        border.width: 1
                    }

                    contentItem: Text {
                        text: parent.text
                        color: root.themeTextColor
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 14
                    }

                    onClicked: {
                        if (root.currentTab >= 0) root.currentTab = -1
                        else root.backClicked()
                    }
                }

                Text {
                    text: root.currentTab === -1
                          ? "Cài Đặt"
                          : (root.currentTab >= 0 && root.currentTab < sidebarModel.count
                             ? sidebarModel.get(root.currentTab).name : "Cài Đặt")
                    color: root.themeTextColor
                    font.pixelSize: 18
                    font.weight: Font.Bold
                }

                Item { Layout.fillWidth: true }

                // Badge tự động lưu (luôn hiện ở góc phải header)
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 32
                    color: "transparent"
                    radius: 6
                    border.color: "#2d6a2d"; border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "⚡"; font.pixelSize: 14 }
                        Text {
                            text: "Tự động lưu"
                            color: root.themeTextColor
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: root.themeBorderColor
            }
        }

        // ── Body: menu (lưới + thống kê) hoặc chi tiết một mục ────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ===== WARM LUXURY SETTINGS INDEX =====
            Rectangle {
                anchors.fill: parent
                anchors.margins: 22
                visible: root.currentTab === -1
                radius: Theme.settingsRadiusLarge
                color: Theme.settingsCanvas
                border.color: Theme.settingsBorder
                border.width: 1
                clip: true

                ScrollView {
                    id: warmMenuScroll
                    anchors.fill: parent
                    anchors.margins: 22
                    contentWidth: availableWidth
                    clip: true
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    ColumnLayout {
                        width: warmMenuScroll.availableWidth
                        spacing: 22

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: width < 900 ? 250 : 164
                            radius: 20
                            color: Theme.settingsCard
                            border.color: Theme.settingsBorder
                            border.width: 1

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 13

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12
                                    Rectangle {
                                        Layout.preferredWidth: 42; Layout.preferredHeight: 42; radius: 13; color: Theme.settingsCopperSoft
                                        SettingsIcon { anchors.centerIn: parent; width: 22; height: 22; name: "capture"; color: Theme.settingsCopper }
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { text: "SỰ KIỆN HIỆN TẠI"; color: Theme.settingsCopper; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.3 }
                                        Text { Layout.fillWidth: true; text: root.eventData && root.eventData.name ? root.eventData.name : "Chưa chọn sự kiện"; color: Theme.settingsText; font.pixelSize: 19; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    }
                                    Text {
                                        visible: !!(root.eventData && root.eventData.eventDate)
                                        text: {
                                            if (!root.eventData || !root.eventData.eventDate) return ""
                                            try { return new Date(root.eventData.eventDate).toLocaleDateString("vi-VN") }
                                            catch (e) { return root.eventData.eventDate }
                                        }
                                        color: Theme.settingsTextMuted; font.pixelSize: 13
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    columns: width < 850 ? 2 : 5
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Repeater {
                                        model: [
                                            { label: "Ảnh đã chụp", value: root.statPhotos.toString(), icon: "capture" },
                                            { label: "Ảnh đã in", value: root.statPrints.toString(), icon: "printer" },
                                            { label: "Khung frame", value: root.statFrames.toString(), icon: "frames" },
                                            { label: "Doanh thu", value: Money.format(root.statRevenue), icon: "revenue" }
                                        ]
                                        delegate: Rectangle {
                                            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                                            radius: 13; color: "#FFFAF7"; border.color: Theme.settingsBorder
                                            RowLayout {
                                                anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 10; spacing: 9
                                                SettingsIcon { width: 20; height: 20; name: modelData.icon; color: Theme.settingsCopper }
                                                ColumnLayout { Layout.fillWidth: true; spacing: 0
                                                    Text { Layout.fillWidth: true; text: modelData.value; color: Theme.settingsText; font.pixelSize: 18; font.weight: Font.Bold; elide: Text.ElideRight }
                                                    Text { Layout.fillWidth: true; text: modelData.label; color: Theme.settingsTextMuted; font.pixelSize: 11; elide: Text.ElideRight }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
                                        radius: 13
                                        color: warmLaunchMouse.pressed ? Theme.settingsCopperDark : (warmLaunchMouse.containsMouse ? "#D87B57" : Theme.settingsCopper)
                                        RowLayout { anchors.centerIn: parent; spacing: 9
                                            SettingsIcon { width: 21; height: 21; name: "play"; color: "#FFFFFF" }
                                            Text { text: "Khởi chạy"; color: "#FFFFFF"; font.pixelSize: 15; font.weight: Font.Bold }
                                        }
                                        MouseArea { id: warmLaunchMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.launchClicked() }
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root._groupHasMatches("operation")
                            RowLayout { Layout.fillWidth: true
                                Text { text: "Vận hành"; color: Theme.settingsText; font.pixelSize: 17; font.weight: Font.DemiBold }
                                Text { text: "Cấu hình thiết bị và luồng hoạt động"; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: root.width <= 1100 ? 2 : (width >= 1420 ? 4 : 3)
                                columnSpacing: 14; rowSpacing: 14
                                Repeater { model: [0, 1, 2, 3, 12]; delegate: warmCategoryDelegate }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.settingsBorder; visible: root._groupHasMatches("operation") && root._groupHasMatches("experience") }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root._groupHasMatches("experience")
                            RowLayout { Layout.fillWidth: true
                                Text { text: "Trải nghiệm khách"; color: Theme.settingsText; font.pixelSize: 17; font.weight: Font.DemiBold }
                                Text { text: "Cá nhân hoá hành trình và nội dung photobooth"; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: root.width <= 1100 ? 2 : (width >= 1420 ? 4 : 3)
                                columnSpacing: 14; rowSpacing: 14
                                // Các tab chia sẻ, khung, filter, AI và gallery được ẩn khỏi giao diện.
                                Repeater {
                                    model: root._visibleTabIndexes([7])
                                    delegate: warmCategoryDelegate
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.settingsBorder; visible: root._groupHasMatches("experience") && root._groupHasMatches("admin") }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            visible: root._groupHasMatches("admin")
                            RowLayout { Layout.fillWidth: true
                                Text { text: "Quản trị & kinh doanh"; color: Theme.settingsText; font.pixelSize: 17; font.weight: Font.DemiBold }
                                Text { text: "Nhân sự, thông tin và báo cáo"; color: Theme.settingsTextMuted; font.pixelSize: 12 }
                                Item { Layout.fillWidth: true }
                            }
                            GridLayout {
                                Layout.fillWidth: true
                                columns: root.width <= 1100 ? 2 : (width >= 1420 ? 4 : 3)
                                columnSpacing: 14; rowSpacing: 14
                                Repeater { model: root._visibleTabIndexes([6, 10, 11]); delegate: warmCategoryDelegate }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180
                            visible: !root._groupHasMatches("operation") && !root._groupHasMatches("experience") && !root._groupHasMatches("admin")
                            Item { Layout.fillHeight: true }
                            SettingsIcon { Layout.alignment: Qt.AlignHCenter; width: 34; height: 34; name: "search"; color: Theme.settingsTextMuted }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Không tìm thấy cài đặt phù hợp"; color: Theme.settingsText; font.pixelSize: 16; font.weight: Font.DemiBold }
                            Text { Layout.alignment: Qt.AlignHCenter; text: "Thử tên khác hoặc xoá nội dung tìm kiếm."; color: Theme.settingsTextMuted; font.pixelSize: 13 }
                            Item { Layout.fillHeight: true }
                        }

                        Item { Layout.preferredHeight: 4 }
                    }
                }
            }

            // ===== MENU: dải thống kê + lưới ô cài đặt =====
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 18
                visible: false

                // ── Dải thống kê sự kiện ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 150
                    color: root.themeSurfaceColor
                    radius: 16
                    border.color: root.themeBorderColor
                    border.width: 1
                    clip: true

                    Rectangle {
                        visible: false
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#4FA4F2" }
                            GradientStop { position: 1.0; color: "#8B5CF6" }
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        anchors.topMargin: 16
                        spacing: 14

                        // Header: tên sự kiện + ngày
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Rectangle {
                                Layout.preferredWidth: 40; Layout.preferredHeight: 40
                                radius: 10
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#4FA4F2" }
                                    GradientStop { position: 1.0; color: "#2060B0" }
                                }
                                Text { anchors.centerIn: parent; text: "📊"; font.pixelSize: 18 }
                            }

                            ColumnLayout {
                                spacing: 1
                                Text {
                                    text: "THỐNG KÊ SỰ KIỆN"
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5
                                }
                                Text {
                                    text: (root.eventData && root.eventData.name) ? root.eventData.name : "Chưa chọn sự kiện"
                                    color: root.themeTextColor
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                    elide: Text.ElideRight
                                    Layout.maximumWidth: 520
                                }
                            }

                            Item { Layout.fillWidth: true }

                            RowLayout {
                                spacing: 6
                                visible: !!(root.eventData && root.eventData.eventDate)
                                Text { text: "📅"; font.pixelSize: 14 }
                                Text {
                                    text: {
                                        if (!root.eventData || !root.eventData.eventDate) return ""
                                        try { return new Date(root.eventData.eventDate).toLocaleDateString("vi-VN") }
                                        catch (e) { return root.eventData.eventDate }
                                    }
                                    color: root.mutedText(0.65)
                                    font.pixelSize: 14
                                }
                            }
                        }

                        // Hàng 4 ô số liệu — chia đều (fillWidth + preferredWidth:1)
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 12

                            Repeater {
                                model: [
                                    { sIcon: "📸", sLabel: "Ảnh đã chụp", sValue: root.statPhotos.toString(),     sBg: "transparent", sBd: "#1A3050", sFg: "#000000" },
                                    { sIcon: "🖨️", sLabel: "Ảnh đã in",   sValue: root.statPrints.toString(),     sBg: "transparent", sBd: "#0D3020", sFg: "#000000" },
                                    { sIcon: "📋", sLabel: "Khung frame",  sValue: root.statFrames.toString(),     sBg: "transparent", sBd: "#251540", sFg: "#000000" },
                                    { sIcon: "💰", sLabel: "Doanh thu",    sValue: Money.format(root.statRevenue), sBg: "transparent", sBd: "#3A2E10", sFg: "#000000" }
                                ]
                                delegate: Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.fillHeight: true
                                    radius: 12
                                    color: modelData.sBg
                                    border.color: modelData.sBd
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 16
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Rectangle {
                                            Layout.preferredWidth: 44
                                            Layout.preferredHeight: 44
                                            radius: 11
                                            color: "transparent"
                                            border.color: modelData.sBd
                                            border.width: 1
                                            Text { anchors.centerIn: parent; text: modelData.sIcon; font.pixelSize: 20 }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: modelData.sValue
                                                color: modelData.sFg
                                                font.pixelSize: 26
                                                font.weight: Font.Bold
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                text: modelData.sLabel
                                                color: root.mutedText(0.65)
                                                font.pixelSize: 13
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Lưới ô cài đặt ──
                ScrollView {
                    id: menuScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: availableWidth
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                    // Bọc để căn giữa khối lưới theo chiều ngang
                    Item {
                        width: menuScroll.availableWidth
                        height: tilesFlow.height

                        Flow {
                            id: tilesFlow
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 18

                            // Số cột co giãn (ô tối thiểu ~300px). Trên màn rộng, mỗi ô
                            // tối đa ~360px và cả khối được căn giữa; màn hẹp thì lấp đầy.
                            property real minTileW: 300
                            property real maxTileW: 360
                            property int  columns: Math.max(2, Math.floor((menuScroll.availableWidth + spacing) / (minTileW + spacing)))
                            property real rawW: (menuScroll.availableWidth - (columns - 1) * spacing) / columns
                            property real tileW: Math.min(rawW, maxTileW)
                            property real tileH: 118
                            width: columns * tileW + (columns - 1) * spacing

                            // Các mục cài đặt (dùng lại sidebarModel)
                            Repeater {
                                model: sidebarModel
                            delegate: Rectangle {
                                width: tilesFlow.tileW
                                height: tilesFlow.tileH
                                radius: 16
                                color: "transparent"
                                border.color: tileMouse.containsMouse ? model.accent : root.themeBorderColor
                                border.width: tileMouse.containsMouse ? 2 : 1
                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 16

                                    // Chip icon màu theo nhóm
                                    Rectangle {
                                        Layout.preferredWidth: 56
                                        Layout.preferredHeight: 56
                                        radius: 14
                                        color: "transparent"
                                        border.color: model.accent
                                        border.width: 1
                                        SettingsIcon {
                                            anchors.centerIn: parent
                                            width: 28
                                            height: 28
                                            name: model.iconName || "settings"
                                            color: model.accent
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: 4

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6
                                            Text {
                                                text: model.name
                                                color: root.themeTextColor
                                                font.pixelSize: 16
                                                font.weight: Font.Bold
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                            Text {
                                                visible: root._isTabLocked(index)
                                                text: "🔒"
                                                font.pixelSize: 14
                                            }
                                        }

                                        Text {
                                            text: model.desc
                                            color: root.mutedText(0.65)
                                            font.pixelSize: 13
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            Layout.fillWidth: true
                                        }
                                    }
                                }

                                MouseArea {
                                    id: tileMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root._requestTab(index)
                                }
                            }
                        }

                        // ▶ Khởi Chạy
                        Rectangle {
                            width: tilesFlow.tileW
                            height: tilesFlow.tileH
                            radius: 16
                            color: "transparent"
                            border.color: launchTileMouse.containsMouse ? "#219653" : root.themeBorderColor
                            border.width: launchTileMouse.containsMouse ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16
                                Rectangle {
                                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                    radius: 14
                                    color: "transparent"
                                    border.color: "#219653"
                                    border.width: 1
                                    Text { anchors.centerIn: parent; text: "▶"; font.pixelSize: 24; color: root.themeTextColor }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    Text { text: "Khởi Chạy"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }
                                    Text {
                                        text: "Bắt đầu phiên chụp cho sự kiện"
                                        color: root.mutedText(0.65); opacity: 0.85
                                        font.pixelSize: 13; wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: launchTileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.launchClicked()
                            }
                        }

                        // 🚪 Đăng xuất tài khoản studio
                        Rectangle {
                            visible: studioAccount.loggedIn
                            width: tilesFlow.tileW
                            height: tilesFlow.tileH
                            radius: 16
                            color: "transparent"
                            border.color: logoutTileMouse.containsMouse ? "#E05555" : root.themeBorderColor
                            border.width: logoutTileMouse.containsMouse ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16
                                Rectangle {
                                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                    radius: 14
                                    color: "transparent"
                                    border.color: "#E05555"
                                    border.width: 1
                                    Image {
                                        anchors.centerIn: parent
                                        width: 30
                                        height: 30
                                        source: "qrc:/assets/icons/logout_account.png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    Text { text: "Đăng xuất tài khoản"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }
                                    Text {
                                        text: studioAccount.email && studioAccount.email.length > 0
                                              ? studioAccount.email : "Đăng xuất khỏi tài khoản studio"
                                        color: root.mutedText(0.65); opacity: 0.85
                                        font.pixelSize: 13; wrapMode: Text.WordWrap
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: logoutTileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    googleLogoutDialog.open()
                                }
                            }
                        }

                        // ⛶ Toàn Màn Hình / Cửa Sổ
                        Rectangle {
                            id: fsTile
                            width: tilesFlow.tileW
                            height: tilesFlow.tileH
                            radius: 16
                            property bool isFullScreen: Window.window
                                                        ? (Window.window.visibility === Window.FullScreen) : false
                            color: "transparent"
                            border.color: fsTileMouse.containsMouse ? "#27486e" : root.themeBorderColor
                            border.width: fsTileMouse.containsMouse ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16
                                Rectangle {
                                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                    radius: 14
                                    color: "transparent"
                                    border.color: "#27486e"
                                    border.width: 1
                                    Text { anchors.centerIn: parent; text: fsTile.isFullScreen ? "⊡" : "⛶"; font.pixelSize: 24; color: root.themeTextColor }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    Text { text: fsTile.isFullScreen ? "Cửa Sổ" : "Toàn Màn Hình"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }
                                    Text {
                                        text: fsTile.isFullScreen ? "Thoát chế độ toàn màn hình" : "Phóng to ứng dụng toàn màn hình"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 13; wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: fsTileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var mainWindow = Window.window
                                    if (mainWindow) {
                                        var goFullscreen = (mainWindow.visibility !== Window.FullScreen)
                                        if (goFullscreen) mainWindow.showFullScreen()
                                        else mainWindow.showNormal()
                                        eventManager.setAppSetting("Bật Full Màn Hình", goFullscreen ? "true" : "false")
                                    }
                                }
                            }
                        }

                        // ⏻ Thoát phần mềm
                        Rectangle {
                            width: tilesFlow.tileW
                            height: tilesFlow.tileH
                            radius: 16
                            color: "transparent"
                            border.color: exitTileMouse.containsMouse ? "#5a1a1a" : root.themeBorderColor
                            border.width: exitTileMouse.containsMouse ? 2 : 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 16
                                Rectangle {
                                    Layout.preferredWidth: 56; Layout.preferredHeight: 56
                                    radius: 14
                                    color: "transparent"
                                    border.color: "#5a1a1a"
                                    border.width: 1
                                    Image {
                                        anchors.centerIn: parent
                                        width: 31
                                        height: 31
                                        source: "qrc:/assets/icons/quit_app.png"
                                        fillMode: Image.PreserveAspectFit
                                        smooth: true
                                        mipmap: true
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 4
                                    Text { text: "Thoát phần mềm"; color: root.themeTextColor; font.pixelSize: 16; font.weight: Font.Bold }
                                    Text {
                                        text: "Đóng ứng dụng photobooth"
                                        color: root.mutedText(0.65)
                                        font.pixelSize: 13; wrapMode: Text.WordWrap
                                        Layout.fillWidth: true
                                    }
                                }
                            }

                            MouseArea {
                                id: exitTileMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: exitConfirmDialog.open()
                            }
                        }
                    }
                }
                }
            }

    // ── Lượt chụp Tab Component (index 15) — báo cáo + xử lý sự cố ───────────
    Component {
        id: captureAttemptsTabComponent

        Item {
            id: capTabRoot
            property string filterMode: "today"   // all | today | attention
            property var summary: ({ count: 0, gross: 0, refund: 0, net: 0, attention: 0 })

            ListModel { id: capModel }

            function money(n) { return (Number(n) || 0).toLocaleString(Qt.locale("vi_VN")) + " ₫" }

            // Nhãn + màu theo trạng thái lượt chụp (trên nền cream settings).
            function statusInfo(s) {
                switch ((s || "").toUpperCase()) {
                case "COMPLETED":       return { t: "Hoàn tất",    bg: "#DCF0E6", fg: Theme.settingsSuccess }
                case "CAPTURING":       return { t: "Đang chụp",   bg: "#DCEBF5", fg: "#2A6FA8" }
                case "WAITING_CAPTURE": return { t: "Chờ chụp",    bg: "#E4EEF6", fg: "#3B7BB0" }
                case "PARTIAL":         return { t: "Thiếu ảnh",   bg: "#FBEDD6", fg: Theme.settingsWarning }
                case "CAMERA_ERROR":    return { t: "Lỗi camera",  bg: "#F7DEDE", fg: Theme.settingsDanger }
                case "APP_INTERRUPTED": return { t: "Gián đoạn",   bg: "#FBE3D2", fg: "#B6622C" }
                case "CANCELLED":       return { t: "Đã hủy",      bg: "#ECE6E1", fg: Theme.settingsTextMuted }
                case "LEGACY_UNKNOWN":  return { t: "Cũ/không rõ", bg: "#ECE6E1", fg: Theme.settingsTextMuted }
                default:                return { t: (s || "—"),    bg: "#ECE6E1", fg: Theme.settingsTextMuted }
                }
            }

            function reload() {
                var rows = eventManager.getCaptureAttempts(eventManager.isAdmin ? -1 : -2)
                capModel.clear()
                var today = Qt.formatDate(new Date(), "yyyy-MM-dd")
                var g = 0, rf = 0, nt = 0, at = 0, cnt = 0
                for (var i = 0; i < rows.length; i++) {
                    var r = rows[i]
                    var when = r.capture_started_at || r.status_updated_at || ""
                    if (capTabRoot.filterMode === "today" && String(when).indexOf(today) !== 0) continue
                    if (capTabRoot.filterMode === "attention" && !r.needs_attention) continue
                    var dt = new Date(when)
                    var timeStr = (when && !isNaN(dt.getTime())) ? Qt.formatDateTime(dt, "dd/MM HH:mm") : (when || "—")
                    capModel.append({
                        session_id:       r.session_id || "",
                        event_id:         r.event_id || 0,
                        event_name:       r.event_name || ("#" + (r.event_id || 0)),
                        status:           r.status || "",
                        expected_photos:  r.expected_photos || 0,
                        photos_captured:  r.photos_captured || 0,
                        failure_message:  r.failure_message || r.failure_code || "",
                        gross_received:   r.gross_received || 0,
                        refund_amount:    r.refund_amount || 0,
                        net_received:     r.net_received || 0,
                        payment_status:   r.payment_status || "FREE",
                        resolution_state: r.resolution_state || "",
                        resolution_type:  r.resolution_type || "",
                        resolution_note:  r.resolution_note || "",
                        needs_attention:  r.needs_attention ? true : false,
                        timeStr:          timeStr
                    })
                    cnt++
                    g += (r.gross_received || 0); rf += (r.refund_amount || 0); nt += (r.net_received || 0)
                    if (r.needs_attention) at++
                }
                capTabRoot.summary = { count: cnt, gross: g, refund: rf, net: nt, attention: at }
            }

            Component.onCompleted: reload()
            Connections {
                target: eventManager
                function onCaptureAttemptsChanged() { capTabRoot.reload() }
            }

            Platform.FileDialog {
                id: capCsvDialog
                title: "Xuất báo cáo lượt chụp (CSV)"
                fileMode: Platform.FileDialog.SaveFile
                nameFilters: ["CSV (*.csv)"]
                defaultSuffix: "csv"
                onAccepted: {
                    var p = file.toString().replace(/^file:\/{2,3}/, "")
                    if (eventManager.exportCaptureAttemptsToCSV(decodeURIComponent(p),
                            eventManager.isAdmin ? -1 : -2))
                        autoSavedToast.show("Đã xuất báo cáo lượt chụp.")
                    else
                        autoSavedToast.show("Xuất báo cáo thất bại.")
                }
            }

            // ── Dialog xử lý sự cố (chỉ admin) ───────────────────────────────
            Popup {
                id: resolveDialog
                anchors.centerIn: Overlay.overlay
                width: 460
                modal: true
                Overlay.modal: Rectangle { color: "#80000000" }
                padding: 0
                property var row: ({})
                property string rType: "RESHOT"

                function openFor(r) {
                    row = r
                    rType = (r.resolution_type && r.resolution_type !== "") ? r.resolution_type : "RESHOT"
                    refundField.text = String(r.refund_amount || 0)
                    noteField.text = r.resolution_note || ""
                    open()
                }

                background: Rectangle {
                    color: Theme.settingsCard; radius: Theme.settingsRadiusLarge
                    border.color: Theme.settingsBorder; border.width: 1
                }
                contentItem: ColumnLayout {
                    anchors.fill: parent; anchors.margins: 22; spacing: 14
                    Text {
                        text: "Xử lý sự cố lượt chụp"
                        color: Theme.settingsText; font.pixelSize: 17; font.bold: true
                    }
                    Text {
                        text: (resolveDialog.row.event_name || "") + "  ·  đã thu " + capTabRoot.money(resolveDialog.row.gross_received)
                        color: Theme.settingsTextMuted; font.pixelSize: 12; Layout.fillWidth: true; elide: Text.ElideRight
                    }

                    Text { text: "Cách xử lý"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true }
                    RowLayout {
                        spacing: 8
                        Repeater {
                            model: [ { id: "RESHOT", t: "Chụp lại" }, { id: "REFUNDED", t: "Hoàn tiền" }, { id: "OTHER", t: "Khác" } ]
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10
                                color: resolveDialog.rType === modelData.id ? Theme.settingsCopperSoft : "#FFFFFF"
                                border.color: resolveDialog.rType === modelData.id ? Theme.settingsCopper : Theme.settingsBorder
                                Text { anchors.centerIn: parent; text: modelData.t; color: Theme.settingsText; font.pixelSize: 13 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: resolveDialog.rType = modelData.id }
                            }
                        }
                    }

                    ColumnLayout {
                        visible: resolveDialog.rType === "REFUNDED"
                        Layout.fillWidth: true; spacing: 4
                        Text {
                            text: "Tiền hoàn (tối đa " + capTabRoot.money(resolveDialog.row.gross_received) + ")"
                            color: Theme.settingsText; font.pixelSize: 12; font.bold: true
                        }
                        TextField {
                            id: refundField
                            Layout.fillWidth: true
                            inputMethodHints: Qt.ImhDigitsOnly
                            validator: IntValidator { bottom: 0 }
                            color: Theme.settingsText
                            background: Rectangle { radius: 8; color: "#FFFFFF"; border.color: Theme.settingsBorder }
                        }
                    }

                    Text { text: "Ghi chú"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true }
                    TextField {
                        id: noteField
                        Layout.fillWidth: true
                        placeholderText: "Lý do / cách xử lý…"
                        color: Theme.settingsText
                        background: Rectangle { radius: 8; color: "#FFFFFF"; border.color: Theme.settingsBorder }
                    }

                    Text {
                        id: resolveError
                        visible: text !== ""
                        text: ""
                        color: Theme.settingsDanger; font.pixelSize: 12; Layout.fillWidth: true; wrapMode: Text.Wrap
                    }

                    RowLayout {
                        Layout.alignment: Qt.AlignRight; spacing: 10
                        Rectangle {
                            width: 96; height: 38; radius: 10; color: "#FFFFFF"; border.color: Theme.settingsBorder
                            Text { anchors.centerIn: parent; text: "Hủy"; color: Theme.settingsTextMuted; font.pixelSize: 13 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: resolveDialog.close() }
                        }
                        Rectangle {
                            width: 130; height: 38; radius: 10; color: Theme.settingsCopper
                            Text { anchors.centerIn: parent; text: "Lưu xử lý"; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var gross = Number(resolveDialog.row.gross_received) || 0
                                    var refund = resolveDialog.rType === "REFUNDED" ? (parseInt(refundField.text) || 0) : 0
                                    if (refund > gross) { resolveError.text = "Tiền hoàn vượt số đã thu."; return }
                                    if (eventManager.resolveCaptureAttempt(resolveDialog.row.session_id,
                                            resolveDialog.rType, refund, noteField.text)) {
                                        resolveDialog.close()
                                        capTabRoot.reload()
                                        autoSavedToast.show("Đã lưu xử lý lượt chụp.")
                                    } else {
                                        resolveError.text = "Lưu thất bại."
                                    }
                                }
                            }
                        }
                    }
                }
                onOpened: resolveError.text = ""
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 14

                // Bộ lọc + xuất CSV
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: [ { id: "today", t: "Hôm nay" }, { id: "all", t: "Tất cả" }, { id: "attention", t: "Cần xử lý" } ]
                        delegate: Rectangle {
                            Layout.preferredHeight: 36
                            Layout.preferredWidth: chipText.implicitWidth + 28
                            radius: 10
                            color: capTabRoot.filterMode === modelData.id ? Theme.settingsCopper : "#FFFFFF"
                            border.color: capTabRoot.filterMode === modelData.id ? Theme.settingsCopper : Theme.settingsBorder
                            Text {
                                id: chipText; anchors.centerIn: parent; text: modelData.t
                                color: capTabRoot.filterMode === modelData.id ? "#FFFFFF" : Theme.settingsText
                                font.pixelSize: 13; font.bold: capTabRoot.filterMode === modelData.id
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { capTabRoot.filterMode = modelData.id; capTabRoot.reload() } }
                        }
                    }
                    Item { Layout.fillWidth: true }
                    Rectangle {
                        Layout.preferredHeight: 36; Layout.preferredWidth: 110; radius: 10
                        color: "#FFFFFF"; border.color: Theme.settingsBorder
                        Text { anchors.centerIn: parent; text: "↻ Làm mới"; color: Theme.settingsText; font.pixelSize: 13 }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: capTabRoot.reload() }
                    }
                    Rectangle {
                        Layout.preferredHeight: 36; Layout.preferredWidth: 120; radius: 10
                        color: Theme.settingsSuccess
                        Text { anchors.centerIn: parent; text: "⭳ Xuất CSV"; color: "#FFFFFF"; font.pixelSize: 13; font.bold: true }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: capCsvDialog.open() }
                    }
                }

                // Thẻ tổng quan
                RowLayout {
                    Layout.fillWidth: true; spacing: 10
                    Repeater {
                        model: [
                            { l: "Số lượt", v: capTabRoot.summary.count, a: Theme.settingsCopper },
                            { l: "Đã thu", v: capTabRoot.money(capTabRoot.summary.gross), a: Theme.settingsSuccess },
                            { l: "Đã hoàn", v: capTabRoot.money(capTabRoot.summary.refund), a: Theme.settingsWarning },
                            { l: "Doanh thu ròng", v: capTabRoot.money(capTabRoot.summary.net), a: Theme.settingsText },
                            { l: "Cần xử lý", v: capTabRoot.summary.attention, a: capTabRoot.summary.attention > 0 ? Theme.settingsDanger : Theme.settingsTextMuted }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 66
                            radius: Theme.settingsRadiusMedium; color: Theme.settingsCard; border.color: Theme.settingsBorder
                            ColumnLayout {
                                anchors.fill: parent; anchors.margins: 10; spacing: 2
                                Text { text: modelData.l; color: Theme.settingsTextMuted; font.pixelSize: 11 }
                                Text { text: modelData.v; color: modelData.a; font.pixelSize: 18; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                            }
                        }
                    }
                }

                // Header bảng
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 34
                    color: Theme.settingsCopperSoft; radius: 8
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8
                        Text { text: "Thời gian"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 90 }
                        Text { text: "Sự kiện"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.fillWidth: true }
                        Text { text: "Ảnh"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "Trạng thái"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 110 }
                        Text { text: "Đã thu"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                        Text { text: "Ròng"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                        Text { text: "Xử lý"; color: Theme.settingsText; font.pixelSize: 12; font.bold: true; Layout.preferredWidth: 92; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                // Bảng dữ liệu
                ListView {
                    id: capList
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true; spacing: 4
                    model: capModel
                    ScrollBar.vertical: ScrollBar {}

                    delegate: Rectangle {
                        width: capList.width
                        height: 46
                        radius: 8
                        color: model.needs_attention ? "#FBEAEA" : Theme.settingsCard
                        border.color: model.needs_attention ? "#E9C4C4" : Theme.settingsBorder

                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                            Text { text: model.timeStr; color: Theme.settingsTextMuted; font.pixelSize: 12; Layout.preferredWidth: 90 }
                            ColumnLayout {
                                Layout.fillWidth: true; spacing: 0
                                Text { text: model.event_name; color: Theme.settingsText; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                                Text {
                                    visible: model.failure_message !== ""
                                    text: model.failure_message; color: Theme.settingsDanger; font.pixelSize: 10
                                    elide: Text.ElideRight; Layout.fillWidth: true
                                }
                            }
                            Text {
                                text: model.photos_captured + "/" + (model.expected_photos > 0 ? model.expected_photos : "?")
                                color: Theme.settingsText; font.pixelSize: 12; Layout.preferredWidth: 60; horizontalAlignment: Text.AlignHCenter
                            }
                            Item {
                                Layout.preferredWidth: 110; height: 24
                                Rectangle {
                                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                    height: 22; radius: 11
                                    width: stTxt.implicitWidth + 18
                                    color: capTabRoot.statusInfo(model.status).bg
                                    Text { id: stTxt; anchors.centerIn: parent; text: capTabRoot.statusInfo(model.status).t; color: capTabRoot.statusInfo(model.status).fg; font.pixelSize: 11; font.bold: true }
                                }
                            }
                            Text {
                                text: model.payment_status === "PAID" ? capTabRoot.money(model.gross_received) : "—"
                                color: model.payment_status === "PAID" ? Theme.settingsSuccess : Theme.settingsTextMuted
                                font.pixelSize: 12; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                            }
                            Text {
                                text: capTabRoot.money(model.net_received)
                                color: Theme.settingsText; font.pixelSize: 12; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                            }
                            Item {
                                Layout.preferredWidth: 92; height: 30
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: model.resolution_state !== "RESOLVED"
                                    enabled: eventManager.isAdmin
                                    opacity: eventManager.isAdmin ? 1 : 0.4
                                    width: 78; height: 30; radius: 8
                                    color: "#FFFFFF"; border.color: Theme.settingsCopper
                                    Text { anchors.centerIn: parent; text: "Xử lý"; color: Theme.settingsCopperDark; font.pixelSize: 12; font.bold: true }
                                    MouseArea {
                                        anchors.fill: parent; enabled: eventManager.isAdmin; cursorShape: Qt.PointingHandCursor
                                        onClicked: resolveDialog.openFor(capModel.get(index))
                                    }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    visible: model.resolution_state === "RESOLVED"
                                    text: "✓ " + model.resolution_type
                                    color: Theme.settingsSuccess; font.pixelSize: 11; font.bold: true
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: capModel.count === 0
                        text: "Không có lượt chụp nào."
                        color: Theme.settingsTextMuted; font.pixelSize: 14
                    }
                }
            }
        }
    }

    // ── Doanh Thu Tab Component (index 10) ──────────────────────────────────
    Component {
        id: revenueTabComponent

        Item {
            id: revenueTabRoot

            property string sortBy:     "time"   // "time" | "cash" | "transfer"
            property string filterMode: "today"  // "all" | "today" | "custom"
            property string filterDate: Qt.formatDate(new Date(), "yyyy-MM-dd")
            property var    summaryData: ({
                total_revenue: 0, total_cash: 0, total_transfer: 0, total_voucher: 0,
                total_change: 0, total_received: 0, record_count: 0
            })

            // Column visibility
            property bool showCash:     sortBy !== "transfer"
            property bool showTransfer: sortBy !== "cash"

            // Lọc theo nhân viên (chỉ admin dùng). -1 = tất cả; >0 = id nhân viên.
            property int empFilterId: -1
            property var employeeList: []   // danh sách nhân viên để admin chọn

            ListModel { id: revenueModel }

            // Bản đồ id nhân viên → tên (để hiển thị cột Nhân viên trong báo cáo).
            property var empNameMap: ({})
            function buildEmpMap() {
                var m = {}
                var list = eventManager.getEmployees()
                employeeList = list
                for (var i = 0; i < list.length; i++)
                    m[list[i].id] = list[i].full_name
                empNameMap = m
            }
            function empName(id) {
                if (id === 0 || id === undefined) return "—"
                return empNameMap[id] || ("NV#" + id)
            }

            // Parse "DD/MM/YYYY" → "YYYY-MM-DD"
            function parseDateInput(text) {
                var t = text.trim()
                var parts = t.split("/")
                if (parts.length === 3 && parts[2].length === 4) {
                    var d = parts[0].padStart(2, "0")
                    var m = parts[1].padStart(2, "0")
                    return parts[2] + "-" + m + "-" + d
                }
                // already YYYY-MM-DD?
                if (/^\d{4}-\d{2}-\d{2}$/.test(t)) return t
                return ""
            }

            function computeSummary() {
                var rev = 0, cash = 0, transfer = 0, voucher = 0, change = 0, received = 0
                for (var i = 0; i < revenueModel.count; i++) {
                    var row = revenueModel.get(i)
                    rev      += row.amount_required
                    cash     += row.cash_received
                    transfer += row.transfer_amount
                    voucher  += row.voucher_amount
                    change   += row.change_amount
                    received += row.received_amount
                }
                return { total_revenue: rev, total_cash: cash,
                         total_transfer: transfer, total_voucher: voucher, total_change: change,
                         total_received: received, record_count: revenueModel.count }
            }

            // Badge trạng thái lượt chụp gắn với giao dịch. Trả về null nếu không
            // cần hiển thị (in lại / không có phiên / phiên còn đang chụp).
            // Đồng bộ nhãn-màu với statusInfo() ở Tab Lượt chụp.
            function captureBadge(row) {
                if ((row.source || "session") === "reprint") return null
                var st = (row.capture_status || "").toUpperCase()
                if (row.had_camera_error || st === "CAMERA_ERROR")
                    return { t: "⚠ Lỗi camera", bg: "#F7DEDE", fg: Theme.settingsDanger,
                             tip: row.failure_message || row.failure_code || "Lỗi máy ảnh" }
                if (st === "PARTIAL")
                    return { t: "Thiếu ảnh " + (row.photos_captured || 0) + "/" + (row.expected_photos || 0),
                             bg: "#FBEDD6", fg: Theme.settingsWarning,
                             tip: row.failure_message || "Chụp thiếu ảnh" }
                if (st === "APP_INTERRUPTED")
                    return { t: "Gián đoạn", bg: "#FBE3D2", fg: "#B6622C",
                             tip: row.failure_message || "Ứng dụng gián đoạn khi chụp" }
                if (st === "CANCELLED")
                    return { t: "Đã hủy", bg: "#ECE6E1", fg: Theme.settingsTextMuted, tip: "" }
                if (st === "COMPLETED")
                    return { t: "✓ Hoàn tất", bg: "#DCF0E6", fg: Theme.settingsSuccess, tip: "" }
                return null
            }

            function reload() {
                buildEmpMap()
                // Admin: lọc theo nhân viên đã chọn (empFilterId); nhân viên thường:
                // backend tự ép về của mình.
                var empArg = eventManager.isAdmin ? revenueTabRoot.empFilterId : -2
                var recs = eventManager.getRevenueRecords(revenueTabRoot.sortBy, empArg)
                revenueModel.clear()
                var todayStr = Qt.formatDate(new Date(), "yyyy-MM-dd")
                var target   = (filterMode === "custom") ? filterDate : todayStr

                for (var i = 0; i < recs.length; i++) {
                    var r = recs[i]
                    // Selfbooth writes a dedicated source=selfbooth record plus a
                    // source=session mirror. Show only the mirror in the main report.
                    if ((r.source || "session") === "selfbooth") continue
                    // date filter
                    if (filterMode === "today" || filterMode === "custom") {
                        if (!r.recorded_at.startsWith(target)) continue
                    }
                    var dt = new Date(r.recorded_at)
                    var timeStr = isNaN(dt.getTime()) ? r.recorded_at
                        : Qt.formatDateTime(dt, "dd/MM/yyyy HH:mm:ss")
                    revenueModel.append({
                        event_name:      r.event_name      || "",
                        recorded_at:     timeStr,
                        print_count:     r.print_count     || 0,
                        amount_required: r.amount_required || 0,
                        cash_received:   r.cash_received   || 0,
                        transfer_amount: r.transfer_amount || 0,
                        change_amount:   r.change_amount   || 0,
                        payment_method:  r.payment_method  || "",
                        employee_id:     r.employee_id     || 0,
                        employee_name:   revenueTabRoot.empName(r.employee_id || 0),
                        shift:           r.shift           || "",
                        source:          r.source          || "session",
                        received_amount: r.received_amount || 0,
                        voucher_amount:  r.voucher_amount  || 0,
                        note:            r.note            || "",
                        capture_status:  r.capture_status  || "",
                        failure_code:    r.failure_code    || "",
                        failure_message: r.failure_message || "",
                        had_camera_error: r.had_camera_error ? true : false,
                        photos_captured: r.photos_captured || 0,
                        expected_photos: r.expected_photos || 0
                    })
                }
                revenueTabRoot.summaryData = computeSummary()
            }

            Component.onCompleted: reload()

            // ── Clear confirm dialog ─────────────────────────────────────────
            Popup {
                id: clearConfirmDialog
                anchors.centerIn: parent
                width: 380; height: 180; modal: true
                Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, 0.35) }
                background: Rectangle { color: "transparent"; border.color: "#2d5a8c"; border.width: 1; radius: 12 }
                contentItem: ColumnLayout {
                    anchors.fill: parent; anchors.margins: 24; spacing: 16
                    Text { text: "Xác nhận xóa dữ liệu doanh thu?"; color: root.themeTextColor; font.pixelSize: 15; font.bold: true; Layout.alignment: Qt.AlignHCenter; wrapMode: Text.Wrap; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter }
                    Text { text: "Tất cả bản ghi sẽ bị xóa vĩnh viễn."; color: "#ef5350"; font.pixelSize: 13; Layout.alignment: Qt.AlignHCenter }
                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter; spacing: 16
                        Rectangle {
                            width: 100; height: 36; radius: 8
                            color: cancelClearMa.containsMouse ? Theme.border : Theme.field; border.color: "#2d5a8c"; border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "Hủy"; color: root.mutedText(0.65); font.pixelSize: 14 }
                            MouseArea { id: cancelClearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: clearConfirmDialog.close() }
                        }
                        Rectangle {
                            width: 100; height: 36; radius: 8
                            color: confirmClearMa.containsMouse ? "#c62828" : "#ef5350"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text { anchors.centerIn: parent; text: "Xóa hết"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                            MouseArea {
                                id: confirmClearMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    clearConfirmDialog.close()
                                    if (eventManager.clearRevenueRecords())
                                        revenueTabRoot.reload()
                                    else {
                                        autoSavedToast.show("Chỉ admin được xóa doanh thu")
                                        return
                                    }
                                    autoSavedToast.show("Đã xóa toàn bộ dữ liệu doanh thu")
                                }
                            }
                        }
                    }
                }
            }

            Platform.FileDialog {
                id: exportSaveDialog
                title: "Lưu file doanh thu"
                nameFilters: ["CSV Files (*.csv)"]
                fileMode: Platform.FileDialog.SaveFile
                defaultSuffix: "csv"
                onAccepted: {
                    var path = currentFile ? currentFile.toString() : ""
                    if (Qt.platform.os === "windows")
                        path = path.replace(/^(file:\/{3})|(file:)/, "")
                    else
                        path = path.replace(/^(file:\/\/)/, "")
                    path = decodeURIComponent(path)
                    if (eventManager.exportRevenueToCSV(path))
                        autoSavedToast.show("Đã xuất doanh thu: " + path)
                    else
                        autoSavedToast.show("Xuất thất bại — kiểm tra quyền ghi file")
                }
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 16

                // ── Summary cards ────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; spacing: 14

                    Repeater {
                        model: [
                            { label: "Tổng Doanh Thu",  key: "total_revenue",  color: "#4FA4F2", icon: "💰" },
                            { label: "Thực Nhận",        key: "total_received", color: "#f0c040", icon: "✅" },
                            { label: "Tiền Mặt",         key: "total_cash",     color: "#4caf50", icon: "💵" },
                            { label: "Chuyển Khoản",     key: "total_transfer", color: "#ab47bc", icon: "🏦" },
                            { label: "Voucher",          key: "total_voucher",  color: "#4FA4F2", icon: "🎫" },
                            { label: "Số Giao Dịch",     key: "record_count",   color: "#ff9800", icon: "📋" }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 104; radius: 14
                            color: "transparent"; border.color: modelData.color; border.width: 1

                            // Subtle top accent stripe in the card's color
                            Rectangle {
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                height: 4; radius: 2
                                color: modelData.color
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.topMargin: 16; anchors.bottomMargin: 14
                                spacing: 6

                                Text {
                                    text: modelData.icon + "  " + modelData.label
                                    color: root.mutedText(0.65); font.pixelSize: 14
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                Text {
                                    property int val: revenueTabRoot.summaryData[modelData.key] || 0
                                    text: modelData.key === "record_count" ? val
                                        : Money.vnd(val)
                                    color: modelData.color
                                    font.pixelSize: modelData.key === "record_count" ? 30 : 21
                                    font.bold: true
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }
                        }
                    }
                }

                // ── Date filter row ───────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 56; radius: 12
                    color: "transparent"; border.color: "transparent"; border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 12

                        Text { text: "📅 Xem:"; color: root.mutedText(0.65); font.pixelSize: 15; font.bold: true }

                        // Filter mode buttons
                        Repeater {
                            model: [
                                { label: "Hôm Nay", key: "today" },
                                { label: "Tất Cả",  key: "all"   },
                                { label: "Ngày Khác", key: "custom" }
                            ]
                            delegate: Rectangle {
                                height: 38; radius: 9
                                width: modelData.key === "custom" ? 120 : 96
                                property bool active: revenueTabRoot.filterMode === modelData.key
                                color: active ? "#1e3a6e" : (dateFiltMa.containsMouse ? Theme.field : "transparent")
                                border.color: active ? "#4FA4F2" : Theme.border; border.width: active ? 2 : 1
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: modelData.label; color: active ? "#ffffff" : root.mutedText(0.65); font.pixelSize: 14; font.bold: active }
                                MouseArea {
                                    id: dateFiltMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        revenueTabRoot.filterMode = modelData.key
                                        if (modelData.key !== "custom")
                                            revenueTabRoot.reload()
                                    }
                                }
                            }
                        }

                        // Custom date input (only when "Ngày Khác")
                        Rectangle {
                            visible: revenueTabRoot.filterMode === "custom"
                            width: 180; height: 38; radius: 9
                            color: "transparent"
                            border.color: customDateField.activeFocus ? "#4FA4F2" : Theme.border; border.width: 1
                            Behavior on border.color { ColorAnimation { duration: 120 } }
                            TextField {
                                id: customDateField
                                anchors.fill: parent; leftPadding: 12; rightPadding: 42
                                placeholderText: "DD/MM/YYYY"
                                color: root.themeTextColor; font.pixelSize: 15
                                verticalAlignment: TextInput.AlignVCenter
                                background: Item {}
                                inputMethodHints: Qt.ImhDigitsOnly
                                onEditingFinished: {
                                    var parsed = revenueTabRoot.parseDateInput(text)
                                    if (parsed !== "") {
                                        revenueTabRoot.filterDate = parsed
                                        revenueTabRoot.reload()
                                    }
                                }
                            }
                            // Go button
                            Rectangle {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                anchors.rightMargin: 5; width: 32; height: 28; radius: 6
                                color: goDateMa.containsMouse ? "#1e3a6e" : Theme.field
                                Behavior on color { ColorAnimation { duration: 100 } }
                                Text { anchors.centerIn: parent; text: "Go"; color: "#4FA4F2"; font.pixelSize: 13; font.bold: true }
                                MouseArea {
                                    id: goDateMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var parsed = revenueTabRoot.parseDateInput(customDateField.text)
                                        if (parsed !== "") {
                                            revenueTabRoot.filterDate = parsed
                                            revenueTabRoot.reload()
                                        }
                                    }
                                }
                            }
                        }

                        // Show current date label
                        Text {
                            visible: revenueTabRoot.filterMode === "today"
                            text: Qt.formatDate(new Date(), "dd/MM/yyyy")
                            color: "#4FA4F2"; font.pixelSize: 15; font.bold: true
                        }

                        // ── Lọc theo nhân viên (chỉ admin) ────────────────────
                        Rectangle { visible: eventManager.isAdmin; width: 1; height: 28; color: Theme.border }
                        Text { visible: eventManager.isAdmin; text: "👤 NV:"; color: root.mutedText(0.65); font.pixelSize: 15; font.bold: true }
                        ComboBox {
                            id: empFilterCombo
                            visible: eventManager.isAdmin
                            Layout.preferredWidth: 200; height: 38
                            // Mục 0 = Tất cả; sau đó là từng nhân viên
                            model: {
                                var arr = ["Tất cả nhân viên"]
                                for (var i = 0; i < revenueTabRoot.employeeList.length; i++)
                                    arr.push(revenueTabRoot.employeeList[i].full_name)
                                return arr
                            }
                            onActivated: function(idx) {
                                revenueTabRoot.empFilterId = (idx === 0)
                                    ? -1 : revenueTabRoot.employeeList[idx - 1].id
                                revenueTabRoot.reload()
                            }
                            contentItem: Text {
                                leftPadding: 12
                                text: empFilterCombo.displayText
                                color: root.themeTextColor; font.pixelSize: 14
                                verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight
                            }
                            background: Rectangle { color: "transparent"; radius: 9; border.color: "#2d5a8c"; border.width: 1 }
                            delegate: ItemDelegate {
                                width: empFilterCombo.width
                                contentItem: Text { text: modelData; color: root.themeTextColor; font.pixelSize: 14; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { color: highlighted ? "#2a3550" : Theme.field }
                                highlighted: empFilterCombo.highlightedIndex === index
                            }
                        }

                        Item { Layout.fillWidth: true }

                        // Refresh
                        Rectangle {
                            width: 40; height: 38; radius: 9
                            color: refreshRevMa.containsMouse ? Theme.field : "transparent"
                            border.color: "#2d5a8c"; border.width: 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text { anchors.centerIn: parent; text: "🔄"; font.pixelSize: 16 }
                            MouseArea { id: refreshRevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: revenueTabRoot.reload() }
                            ToolTip.visible: refreshRevMa.containsMouse; ToolTip.text: "Làm mới"
                        }

                        // Export
                        Rectangle {
                            height: 38; radius: 9; width: exportRevRow.implicitWidth + 28
                            color: exportRevMa.containsMouse ? "#1b5e20" : "#2e7d32"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout { id: exportRevRow; anchors.centerIn: parent; spacing: 6
                                Text { text: "📊"; font.pixelSize: 15 }
                                Text { text: "Xuất Excel (CSV)"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                            }
                            MouseArea {
                                id: exportRevMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var mode = revenueTabRoot.filterMode
                                    var period = mode === "custom" ? revenueTabRoot.filterDate
                                               : (mode === "today" ? Qt.formatDate(new Date(), "yyyy-MM-dd") : "TatCa")
                                    var name = root.buildExportName("DoanhThu", period, "csv")
                                    exportSaveDialog.folder = root._exportFolder
                                    exportSaveDialog.currentFile = root._exportFolder + "/" + name
                                    exportSaveDialog.open()
                                }
                            }
                        }

                        // Clear
                        Rectangle {
                            visible: eventManager.isAdmin
                            height: 38; radius: 9; width: clearRevRow.implicitWidth + 28
                            color: clearRevMa.containsMouse ? "#b71c1c" : "#c62828"
                            Behavior on color { ColorAnimation { duration: 120 } }
                            RowLayout { id: clearRevRow; anchors.centerIn: parent; spacing: 6
                                Text { text: "🗑"; font.pixelSize: 15 }
                                Text { text: "Xóa Cuối Ngày"; color: root.themeTextColor; font.pixelSize: 14; font.bold: true }
                            }
                            MouseArea { id: clearRevMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: clearConfirmDialog.open() }
                        }
                    }
                }

                // ── Sort toolbar ──────────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true; spacing: 10

                    Text { text: "Sắp xếp:"; color: root.mutedText(0.65); font.pixelSize: 15; font.bold: true }

                    Repeater {
                        model: [
                            { label: "⏱ Thời Gian",   key: "time"     },
                            { label: "💵 Tiền Mặt",    key: "cash"     },
                            { label: "🏦 Chuyển Khoản", key: "transfer" }
                        ]
                        delegate: Rectangle {
                            Layout.preferredWidth: sortBtnLabel.implicitWidth + 32
                            Layout.preferredHeight: 38
                            radius: 9
                            property bool active: revenueTabRoot.sortBy === modelData.key
                            color: active ? "#1e3a6e" : (sortMa.containsMouse ? Theme.field : "transparent")
                            border.color: active ? "#4FA4F2" : Theme.border; border.width: active ? 2 : 1
                            Behavior on color { ColorAnimation { duration: 100 } }
                            Text {
                                id: sortBtnLabel
                                anchors.centerIn: parent
                                text: modelData.label
                                color: active ? "#ffffff" : root.mutedText(0.65)
                                font.pixelSize: 14; font.bold: active
                            }
                            MouseArea {
                                id: sortMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { revenueTabRoot.sortBy = modelData.key; revenueTabRoot.reload() }
                            }
                        }
                    }

                    // Sort mode hint
                    Text {
                        visible: revenueTabRoot.sortBy !== "time"
                        text: revenueTabRoot.sortBy === "cash"
                              ? "· Chỉ hiển thị cột Tiền Mặt"
                              : "· Chỉ hiển thị cột Chuyển Khoản"
                        color: "#4FA4F2"; font.pixelSize: 13; font.italic: true
                    }

                    Item { Layout.fillWidth: true }
                    Text {
                        text: revenueModel.count + " giao dịch"
                        color: root.mutedText(0.65); font.pixelSize: 13
                    }
                }

                // ── Table header ─────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; height: 44; radius: 8
                    color: "#075aab"; border.color: "#6bb8ff"; border.width: 1

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 22; spacing: 6

                        Text { text: "Thời Gian";      color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 140 }
                        Text { text: "Nhân Viên";      color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 100 }
                        Text { text: "Ca";            color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 75 }
                        Text { text: "Loại";          color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 90 }
                        Text { text: "Số Ảnh";         color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 55; horizontalAlignment: Text.AlignRight }
                        Text { text: "Cần TT (₫)";     color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                        Text {
                            visible: revenueTabRoot.showCash
                            text: "Tiền Mặt (₫)"; color: "#ffffff"; font.pixelSize: 13; font.bold: true
                            Layout.preferredWidth: visible ? 100 : 0; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            visible: revenueTabRoot.showTransfer
                            text: "Chuyển KH (₫)"; color: "#ffffff"; font.pixelSize: 13; font.bold: true
                            Layout.preferredWidth: visible ? 105 : 0; horizontalAlignment: Text.AlignRight
                        }
                        Text { text: "Voucher (₫)";   color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight }
                        Text { text: "Thực Nhận (₫)"; color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 105; horizontalAlignment: Text.AlignRight }
                        Text { text: "Trạng Thái";    color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 120; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "Phương Thức";   color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.preferredWidth: 130; horizontalAlignment: Text.AlignHCenter }
                        Text { text: "Ghi Chú";       color: "#ffffff"; font.pixelSize: 13; font.bold: true; Layout.fillWidth: true }
                    }
                }

                // ── Record list with scroll ───────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    color: "transparent"; radius: 8; clip: true

                    Text {
                        anchors.centerIn: parent
                        visible: revenueModel.count === 0
                        text: revenueTabRoot.filterMode === "today"
                              ? "Hôm nay chưa có giao dịch nào"
                              : "Chưa có dữ liệu doanh thu"
                        color: root.mutedText(0.65); font.pixelSize: 15
                    }

                    ListView {
                        id: revenueListView
                        anchors { fill: parent; rightMargin: 12 }
                        model: revenueModel
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.VerticalFlick

                        ScrollBar.vertical: ScrollBar {
                            id: revScrollBar
                            // ScrollBar.vertical đã tự neo phải vào flickable — KHÔNG đặt lại
                            // anchors.right (gây cảnh báo "anchor loop"). Chỉ chỉnh margin để
                            // đẩy ra mép ngoài.
                            anchors.rightMargin: -12   // push to outer edge
                            policy: ScrollBar.AsNeeded
                            contentItem: Rectangle {
                                implicitWidth: 8
                                radius: 4
                                color: revScrollBar.pressed ? "#4FA4F2" : (revScrollBar.hovered ? "#7bbef8" : Theme.border)
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            background: Rectangle {
                                color: "transparent"; radius: 4
                            }
                        }

                        delegate: Rectangle {
                            width: ListView.view.width; height: 50
                            color: index % 2 === 0 ? "#0b5cad" : "#084f99"
                            border.color: "#2f8fe8"; border.width: 1

                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 6

                                Text {
                                    text: model.recorded_at; color: "#ffffff"; font.pixelSize: 13
                                    Layout.preferredWidth: 140; elide: Text.ElideRight
                                }
                                Text {
                                    text: model.employee_name; color: "#ffffff"; font.pixelSize: 13
                                    Layout.preferredWidth: 100; elide: Text.ElideRight
                                }
                                Text {
                                    text: model.shift && model.shift !== "" ? model.shift : "—"
                                    color: model.shift && model.shift !== "" ? "#ffffff" : "#dbeafe"; font.pixelSize: 13
                                    Layout.preferredWidth: 75; elide: Text.ElideRight
                                }
                                // Loại: Phiên mới / In lại
                                Rectangle {
                                    Layout.preferredWidth: 90; Layout.preferredHeight: 24; radius: 12
                                    color: model.source === "reprint" ? "#7c3aed" : "#0369a1"
                                    border.color: "#dbeafe"; border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.source === "reprint" ? "🔁 In lại" : "🆕 Phiên mới"
                                        color: "#ffffff"
                                        font.pixelSize: 10; font.bold: true
                                    }
                                }
                                Text {
                                    text: model.print_count; color: "#ffffff"; font.pixelSize: 14
                                    Layout.preferredWidth: 55; horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: Money.format(model.amount_required)
                                    color: "#ffffff"; font.pixelSize: 14
                                    Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    visible: revenueTabRoot.showCash
                                    text: model.cash_received > 0 ? Money.format(model.cash_received) : "-"
                                    color: model.cash_received > 0 ? "#ffffff" : "#dbeafe"; font.pixelSize: 14
                                    Layout.preferredWidth: visible ? 100 : 0; horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    visible: revenueTabRoot.showTransfer
                                    text: model.transfer_amount > 0 ? Money.format(model.transfer_amount) : "-"
                                    color: model.transfer_amount > 0 ? "#ffffff" : "#dbeafe"; font.pixelSize: 14
                                    Layout.preferredWidth: visible ? 105 : 0; horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    property int voucherAmt: model.voucher_amount || 0
                                    text: voucherAmt > 0 ? Money.format(voucherAmt) : "-"
                                    color: voucherAmt > 0 ? "#ffffff" : "#dbeafe"; font.pixelSize: 14
                                    Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                                }
                                Text {
                                    text: model.received_amount > 0 ? Money.format(model.received_amount) : "-"
                                    color: model.received_amount > 0 ? "#ffffff" : "#dbeafe"; font.pixelSize: 14; font.bold: true
                                    Layout.preferredWidth: 105; horizontalAlignment: Text.AlignRight
                                }
                                // Trạng thái lượt chụp (cảnh báo phiên đã thu tiền nhưng chụp lỗi)
                                Item {
                                    id: stCell
                                    Layout.preferredWidth: 120; Layout.preferredHeight: 24
                                    property var badge: revenueTabRoot.captureBadge(model)
                                    Rectangle {
                                        anchors.centerIn: parent
                                        visible: stCell.badge !== null
                                        height: 22; radius: 11
                                        width: stBadgeTxt.implicitWidth + 16
                                        color: stCell.badge ? stCell.badge.bg : "transparent"
                                        Text {
                                            id: stBadgeTxt; anchors.centerIn: parent
                                            text: stCell.badge ? stCell.badge.t : ""
                                            color: stCell.badge ? stCell.badge.fg : "transparent"
                                            font.pixelSize: 11; font.bold: true
                                        }
                                        MouseArea {
                                            id: stBadgeMa
                                            anchors.fill: parent; hoverEnabled: true
                                            ToolTip.visible: stBadgeMa.containsMouse && stCell.badge && stCell.badge.tip !== ""
                                            ToolTip.text: (stCell.badge && stCell.badge.tip) ? stCell.badge.tip : ""
                                        }
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: stCell.badge === null
                                        text: "—"; color: "#dbeafe"; font.pixelSize: 13
                                    }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 130; Layout.preferredHeight: 28; radius: 6
                                    color: model.payment_method === "cash"     ? "#15803d" :
                                           model.payment_method === "transfer"  ? "#7e22ce" :
                                           model.payment_method === "voucher"   ? "#0369a1" : "#b45309"
                                    border.color: "#dbeafe"
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: model.payment_method === "cash"     ? "💵 Tiền Mặt" :
                                              model.payment_method === "transfer"  ? "🏦 Chuyển KH" :
                                              model.payment_method === "voucher"   ? "🎫 Voucher" : "🆓 Miễn Phí"
                                        color: "#ffffff"
                                        font.pixelSize: 13; font.bold: true
                                    }
                                }
                                // Ghi chú (mã voucher đã dùng, …)
                                Text {
                                    text: model.note && model.note !== "" ? model.note : "—"
                                    color: model.note && model.note !== "" ? "#ffffff" : "#dbeafe"
                                    font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                anchors.bottom: parent.bottom; width: parent.width; height: 1
                                color: "transparent"; visible: index < revenueModel.count - 1
                            }
                        }
                    }
                }

                // ── Totals footer ─────────────────────────────────────────────
                Rectangle {
                    Layout.fillWidth: true; height: 48; radius: 8
                    color: "#064f9b"; border.color: "#6bb8ff"; border.width: 1
                    visible: revenueModel.count > 0

                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 22; spacing: 6

                        Text { text: "TỔNG (" + revenueModel.count + " GD)"; color: "#ffffff"; font.pixelSize: 14; font.bold: true; Layout.preferredWidth: 140 }
                        Item  { Layout.preferredWidth: 100 }
                        Item  { Layout.preferredWidth: 75 }
                        Item  { Layout.preferredWidth: 90 }
                        Item  { Layout.preferredWidth: 55 }
                        Text {
                            text: Money.format(revenueTabRoot.summaryData["total_revenue"] || 0)
                            color: "#ffffff"; font.pixelSize: 15; font.bold: true
                            Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            visible: revenueTabRoot.showCash
                            text: Money.format(revenueTabRoot.summaryData["total_cash"] || 0)
                            color: "#ffffff"; font.pixelSize: 15; font.bold: true
                            Layout.preferredWidth: visible ? 100 : 0; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            visible: revenueTabRoot.showTransfer
                            text: Money.format(revenueTabRoot.summaryData["total_transfer"] || 0)
                            color: "#ffffff"; font.pixelSize: 15; font.bold: true
                            Layout.preferredWidth: visible ? 105 : 0; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: Money.format(revenueTabRoot.summaryData["total_voucher"] || 0)
                            color: "#ffffff"; font.pixelSize: 15; font.bold: true
                            Layout.preferredWidth: 100; horizontalAlignment: Text.AlignRight
                        }
                        Text {
                            text: Money.format(revenueTabRoot.summaryData["total_received"] || 0)
                            color: "#ffffff"; font.pixelSize: 15; font.bold: true
                            Layout.preferredWidth: 105; horizontalAlignment: Text.AlignRight
                        }
                        Item { Layout.preferredWidth: 120 }
                        Item { Layout.fillWidth: true }
                    }
                }
            }
        }
    }

        // ===== CHI TIẾT: hiện toàn bộ cài đặt của mục đang chọn =====
        Rectangle {
            anchors.fill: parent
            anchors.margins: 22
            color: (root.currentTab === 13 || root.currentTab === 14) ? "transparent" : Theme.settingsCanvas
            radius: Theme.settingsRadiusLarge
            border.color: (root.currentTab === 13 || root.currentTab === 14) ? "transparent" : Theme.settingsBorder
            border.width: 1
            clip: true
            visible: root.currentTab >= 0

            StackLayout {
                anchors.fill: parent
                currentIndex: root.currentTab >= 0 ? root.currentTab : 0
                anchors.margins: 24

                // General Tab (index 0)
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: generalTabComponent
                    active: root.currentTab === 0
                }

                // Camera Tab (index 1)
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: cameraTabComponent
                    active: root.currentTab === 1
                }

                // Capture Tab (index 2) - NEW
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: captureTabComponent
                    active: root.currentTab === 2
                }

                // Printer Tab (index 3) - previously index 2
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: printerTabComponent
                    active: root.currentTab === 3
                }

                // Sharing Tab (index 4) - previously index 3
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: sharingTabComponent
                    active: root.currentTab === 4
                }

                // Templates Tab (index 5) - previously index 4
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: templatesTabComponent
                    active: root.currentTab === 5
                }

                // Account Tab (index 6) - previously index 5
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: accountTabComponent
                    active: root.currentTab === 6
                }

                // Backgrounds Tab (index 7)
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: backgroundsTabComponent
                    active: root.currentTab === 7
                }

                // Filter Tab (index 8)
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: filterTabComponent
                    active: root.currentTab === 8
                }

                // Voucher Tab (index 9)
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: voucherTabComponent
                    active: root.currentTab === 9
                }

                // Revenue Tab (index 10)
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: revenueTabComponent
                    active: root.currentTab === 10
                }

                // Info Tab (index 11) - HWID + license expiry
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: infoTabComponent
                    active: root.currentTab === 11
                }

                // Operation Mode Tab (index 12) - chọn chế độ vận hành
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: operationModeTabComponent
                    active: root.currentTab === 12
                }

                // Payment Tab (index 13) - appended to preserve all existing numeric indexes
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: paymentTabComponent
                    active: root.currentTab === 13
                }

                // Gallery Tab (index 14) - thư viện ảnh, chuyển từ SelectServiceScreen/CutModeScreen
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: galleryTabComponent
                    active: root.currentTab === 14
                }

                // Capture Attempts Tab (index 15) - báo cáo lượt chụp + xử lý sự cố
                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: captureAttemptsTabComponent
                    active: root.currentTab === 15
                }

            }
        }
        }
    }

    // ── Camera Switch Popup ─────────────────────────────────────────────
    Popup {
        id: cameraSwitchPopup
        anchors.centerIn: parent
        width: 360
        height: 140
        modal: true
        Overlay.modal: Rectangle { color: "transparent" }
        closePolicy: Popup.NoAutoClose

        property string brandName: "Canon"

        function switchTo(brand) {
            brandName = brand
            open()
            cameraSwitchTimeout.restart()
        }

        // Hard timeout: close popup even if no signal arrives (safety net).
        Timer {
            id: cameraSwitchTimeout
            interval: 15000
            onTriggered: cameraSwitchPopup.close()
        }

        // Close as soon as the backend finishes (success or failure).
        Connections {
            target: cameraController
            function onConnectFinished(success) {
                cameraSwitchTimeout.stop()
                cameraSwitchPopup.close()
                if (!success) {
                    autoSavedToast.showError(
                        "Không tìm thấy " + cameraSwitchPopup.brandName +
                        ". Kiểm tra kết nối USB.")
                }
            }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            NumberAnimation { property: "scale"; from: 0.9; to: 1.0; duration: 200 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 250 }
        }

        background: Rectangle {
            color: "transparent"
            radius: 14
            border.color: "#1e7eea"
            border.width: 1.5
            layer.enabled: true
            layer.effect: null
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                spacing: 12
                Layout.alignment: Qt.AlignHCenter

                BusyIndicator {
                    width: 28; height: 28
                    running: cameraSwitchPopup.visible
                }

                Text {
                    text: "Đang chuyển kết nối camera"
                    color: root.themeTextColor
                    font.pixelSize: 16
                    font.weight: Font.Bold
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Đang kết nối sang " + cameraSwitchPopup.brandName + "..."
                color: "#60a5fa"
                font.pixelSize: 14
            }

            Rectangle {
                Layout.fillWidth: true
                height: 3
                radius: 2
                color: "transparent"

                Rectangle {
                    id: progressBar
                    height: parent.height
                    width: 0
                    radius: 2
                    color: "#1e7eea"

                    NumberAnimation on width {
                        running: cameraSwitchPopup.visible
                        from: 0
                        to: progressBar.parent.width
                        duration: 3200
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    // ── Dialog nhập pass khi nhân viên vào tab bị khóa ─────────────────────────
    Popup {
        id: staffLockDialog
        property int pendingTab: -1
        property bool wrong: false
        modal: true
        Overlay.modal: Rectangle { color: "transparent" }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: Overlay.overlay
        width: 500; padding: 0

        onOpened: { staffLockDialog.wrong = false; staffPinField.text = ""; staffPinField.forceActiveFocus() }
        onClosed: Qt.inputMethod.hide()

        background: Rectangle {
            radius: 24
            clip: true
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#172033" }
                GradientStop { position: 0.55; color: "#101622" }
                GradientStop { position: 1.0; color: "#080b12" }
            }
            border.color: staffLockDialog.wrong ? "#ff4422" : "#46658d"; border.width: 2
            Behavior on border.color { ColorAnimation { duration: 200 } }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 6
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#1e7eea" }
                    GradientStop { position: 0.55; color: "#d6a84f" }
                    GradientStop { position: 1.0; color: "#ad436d" }
                }
            }
        }

        contentItem: ColumnLayout {
            spacing: 0
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 34; Layout.bottomMargin: 18; spacing: 10
                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    Layout.alignment: Qt.AlignHCenter
                    radius: 24
                    color: "#122a4d"
                    border.color: staffLockDialog.wrong ? "#ff6644" : "#4FA4F2"
                    border.width: 1
                    Text { anchors.centerIn: parent; text: "🔒"; font.pixelSize: 34 }
                }
                Text {
                    text: "Mục này cần mật khẩu"
                    color: "#ffffff"; font.pixelSize: 23; font.bold: true; Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: staffLockDialog.wrong ? "Mật khẩu không đúng!"
                        : (staffLockDialog.pendingTab >= 0 && staffLockDialog.pendingTab < sidebarModel.count
                           ? sidebarModel.get(staffLockDialog.pendingTab).name : "")
                    color: staffLockDialog.wrong ? "#ff7a5f" : "#a8b6cc"
                    font.pixelSize: 15; Layout.alignment: Qt.AlignHCenter
                }
            }

            TextField {
                id: staffPinField
                Layout.fillWidth: true; Layout.leftMargin: 34; Layout.rightMargin: 34; Layout.bottomMargin: 18
                height: 58
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhDigitsOnly
                horizontalAlignment: Text.AlignHCenter
                placeholderText: "Nhập mật khẩu..."
                color: "#ffffff"; font.pixelSize: 22; font.letterSpacing: 6
                background: Rectangle {
                    color: "#090f18"; radius: 16
                    border.color: staffPinField.activeFocus ? (staffLockDialog.wrong ? "#ff4422" : "#d6a84f") : "#344258"
                    border.width: staffPinField.activeFocus ? 2 : 1
                }
                onTextChanged: staffLockDialog.wrong = false
                Keys.onReturnPressed: staffLockDialog._submit()
                Keys.onEnterPressed:  staffLockDialog._submit()
            }

            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 34; Layout.rightMargin: 34; Layout.bottomMargin: 26; spacing: 12
                Rectangle {
                    Layout.fillWidth: true; height: 54; radius: 17
                    color: lockCancelMa.containsMouse ? "#2e1a1a" : "#111827"
                    border.color: "#aa3322"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Hủy"; color: "#ff6644"; font.pixelSize: 16; font.bold: true }
                    MouseArea { id: lockCancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: staffLockDialog.close() }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 54; radius: 17
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: lockOkMa.containsMouse ? "#2f8cf0" : "#1e7eea" }
                        GradientStop { position: 1.0; color: lockOkMa.containsMouse ? "#c14f78" : "#ad436d" }
                    }
                    Text { anchors.centerIn: parent; text: "Mở khóa"; color: "#ffffff"; font.pixelSize: 16; font.bold: true }
                    MouseArea { id: lockOkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: staffLockDialog._submit() }
                }
            }

            InputPanel {
                Layout.fillWidth: true
                visible: Qt.inputMethod.visible
                active: Qt.inputMethod.visible
            }
        }

        function _submit() {
            var stored = eventManager.getAppSetting("staff_lock_pin", "0000")
            if (staffPinField.text === stored) {
                var t = staffLockDialog.pendingTab
                staffLockDialog.close()
                if (t >= 0) root._openVisibleTab(t)
            } else {
                staffLockDialog.wrong = true
                staffPinField.text = ""
            }
        }
    }

    // ── Dialog xác nhận thoát phần mềm ─────────────────────────────────────────
    Popup {
        id: exitConfirmDialog
        modal: true
        Overlay.modal: Rectangle { color: "transparent" }
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        anchors.centerIn: Overlay.overlay
        width: 420; padding: 0

        background: Rectangle {
            color: "transparent"; radius: 16
            border.color: "#5a1a1a"; border.width: 2
        }

        contentItem: ColumnLayout {
            spacing: 0
            ColumnLayout {
                Layout.fillWidth: true; Layout.margins: 28; Layout.bottomMargin: 16; spacing: 8
                Image {
                    source: "qrc:/assets/icons/quit_app.png"
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    Layout.alignment: Qt.AlignHCenter
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                }
                Text {
                    text: "Thoát phần mềm?"
                    color: root.themeTextColor; font.pixelSize: 19; font.bold: true; Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Ứng dụng photobooth sẽ đóng lại."
                    color: "#8090a8"; font.pixelSize: 14; Layout.alignment: Qt.AlignHCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true; Layout.leftMargin: 28; Layout.rightMargin: 28; Layout.bottomMargin: 20; spacing: 12
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 12
                    color: exitCancelMa.containsMouse ? Theme.field : Theme.surface
                    border.color: "#2d5a8c"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Hủy"; color: root.mutedText(0.65); font.pixelSize: 16; font.bold: true }
                    MouseArea { id: exitCancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: exitConfirmDialog.close() }
                }
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 12
                    color: exitOkMa.containsMouse ? "#7a1f1f" : "#a83232"
                    Text { anchors.centerIn: parent; text: "Thoát"; color: root.themeTextColor; font.pixelSize: 16; font.bold: true }
                    MouseArea { id: exitOkMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Qt.quit() }
                }
            }
        }
    }

    // ── Global "Đã lưu" toast notification ─────────────────────────────
    Popup {
        id: autoSavedToast
        x: (parent.width - width) / 2
        y: parent.height - 90
        width: 280
        height: 50
        modal: false
        closePolicy: Popup.NoAutoClose

        property string message: ""
        property bool isError: false

        function show(msg) {
            autoSavedToast.isError = false
            autoSavedToast.message = msg
            autoSavedToast.open()
            toastDismiss.restart()
        }
        function showError(msg) {
            autoSavedToast.isError = true
            autoSavedToast.message = msg
            autoSavedToast.width = 360
            autoSavedToast.open()
            toastDismiss.restart()
        }

        Timer {
            id: toastDismiss
            interval: 3000
            onTriggered: { autoSavedToast.width = 280; autoSavedToast.close() }
        }

        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 300 }
        }

        background: Rectangle {
            color: autoSavedToast.isError ? "#2e1a1a" : "#1a2e1a"
            radius: 10
            border.color: autoSavedToast.isError ? "#a03030" : "#2d6a2d"
            border.width: 1.5
        }

        contentItem: RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            Rectangle {
                width: 26; height: 26; radius: 13
                color: autoSavedToast.isError ? "#a03030" : "#2d6a2d"
                Text {
                    anchors.centerIn: parent
                    text: autoSavedToast.isError ? "✕" : "✓"
                    color: autoSavedToast.isError ? "#ff6b6b" : "#4caf50"
                    font.pixelSize: 15; font.bold: true
                }
            }

            Text {
                text: autoSavedToast.message
                color: autoSavedToast.isError ? "#ff6b6b" : "#4caf50"
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }
    }
}
