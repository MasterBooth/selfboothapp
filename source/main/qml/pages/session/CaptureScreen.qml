import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components"
import "../../theme"

Item {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // -------------------------------------------------------------------------
    // Properties & Signals
    // -------------------------------------------------------------------------
    signal sessionFinished(var photos, string collagePath)
    signal manualCaptureFinished(var photos)
    signal retakeDiscardedPhoto(string photoPath)
    signal photoReady(string photoPath, int photoIndex)
    signal closeClicked()

    property int totalPhotos: 3
    property bool followFramePhotoCount: false
    // Safety cap for invalid/manual photo count settings.
    readonly property int captureCap: 50
    property int currentPhotoIndex: 0
    property bool isCountingDown: false
    property int countdownValue: 3
    property string sessionPath: "" // Received from BoothSession
    property string sessionId: ""   // Received from BoothSession �?" used for DB + QR
    property int eventId: -1
    property var eventData: null
    property string operationMode: eventManager.getAppSetting("app_operation_mode", "mode1")
    property bool forceManualPostFlow: false
    property bool showCloseButton: true
    property bool _endCaptureButtonVisible: false
    // BoothSession bật relay từ màn Chế �'�T; các flow khác vẫn �'�f CaptureScreen tự quản.
    property bool manageRelay: true
    property string collagePath: "" // No longer shown here, just computed at end
    property int capturingIndex: -1
    property bool isProcessing: false
    // true = user �'ã bấm "Tiếp Tục" nhưng ảnh cu�'i chưa có file path (onImageCaptured chưa fire)
    property bool _pendingCompletion: false
    // Chụp tự do (mode3) / remote: hết giờ hoặc bấm Hoàn thành → khóa bấm mới, chờ ảnh đã
    // bấm về đủ (tối đa 15 s) rồi mới kết thúc, để không mất ảnh bấm sát giờ.
    property bool _finishing: false
    property double _finishStartedAt: 0
    property double _lastFileAt: 0
    // Số lần máy ảnh báo đã chụp (Canon: cả nút trên máy / remote) mà file chưa về.
    property int _shutterPendingFiles: 0
    // Đã kết thúc chụp: ảnh tới sau đó do EventManager nhận (khung ảnh trễ), màn này bỏ qua.
    property bool _captureClosed: false
    property double _captureStartedAt: 0
    readonly property bool _appendsPhotos: root.freeCaptureUntilTimeout || root.remoteMode
    // FIFO queue: indices�'ã captured nhưng file chưa về �?" dùng trong onImageCaptured
    property var _downloadQueue: []

    // Single portrait operator screen: top half live view, bottom half photo wall.
    // Legacy external_* settings are intentionally ignored by the capture runtime.
    // Mode3 (chụp tự do): live view trên / ảnh xem dưới / film strip dưới cùng.
    readonly property bool _freeLayout: root.freeCaptureUntilTimeout
    readonly property int _filmStripH: root._freeLayout ? (root.portrait ? 90 : 76) : 200
    readonly property int _filmStripGap: root._freeLayout ? (root.portrait ? 46 : 34) : 0
    readonly property int _splitLiveViewH: _freeLayout ? Math.floor((root.height - _filmStripH - _filmStripGap) / 2)
                                                       : Math.floor(root.height * 0.5)
    readonly property int _splitPhotoWallY: _splitLiveViewH
    readonly property int _splitPhotoWallH: _freeLayout ? root.height - _filmStripH - _filmStripGap - _splitPhotoWallY
                                                        : root.height - _splitPhotoWallY

    // External operator displays: one HDMI live view window and one session photo wall.
    property bool _externalLiveViewEnabled: eventManager.getAppSetting("external_live_view_enabled", "true") === "true"
    // Mock test: giả lập có màn HDMI khi máy ch�? có 1 màn hình. Bật �?' vùng live view
    // chính �'�.i thành photo wall, live view "HDMI" m�Y �Y cửa s�. nhỏ windowed (không che app).
    property bool _externalLiveViewMockEnabled: eventManager.getAppSetting("external_live_view_mock_enabled", "false") === "true"
    property bool _externalPhotoWallEnabled: eventManager.getAppSetting("external_photo_wall_enabled", "true") === "true"
    property bool _externalWindowsFullscreen: eventManager.getAppSetting("external_windows_fullscreen", "true") === "true"
    property int _externalLiveViewScreenIndex: _resolveExternalLiveViewScreenIndex()
    property int _externalPhotoWallScreenIndex: {
        var saved = eventManager.getAppSetting("external_photo_wall_screen_index", "")
        if (saved !== "")
            return _parseIntOr(saved, 0)
        // Guard: context property có th�f null nếu binary chưa expose displayManager.
        return (typeof displayManager !== "undefined" && displayManager)
               ? displayManager.defaultPhotoWallScreenIndex() : 0
    }

    // S�' màn hình hi�?n có (guard null displayManager). Reactive qua screenCountChanged.
    readonly property int _screenCount: (typeof displayManager !== "undefined" && displayManager)
                                        ? displayManager.screenCount : 1
    readonly property int _primaryScreenIndex: (typeof displayManager !== "undefined" && displayManager)
                                               ? displayManager.primaryScreenIndex : 0
    // Có thực sự t�"n tại màn HDMI riêng cho live view phụ? (index nằm trong dải màn hình
    // và khác màn chính index 0). 1 màn hình �?' false �?' giữ live view chính như cũ.
    readonly property bool _hasExternalLiveViewScreen:
        root._isUsableExternalLiveViewScreen(root._externalLiveViewScreenIndex)

    // Live view phụ �'ược coi là "active" khi có màn HDMI thật (bật + �'ủ màn hình) HOẶC
    // �'ang bật mock test (giả lập trên 1 màn hình).
    readonly property bool _externalLiveViewActive:
        root._externalLiveViewMockEnabled
        || (root._externalLiveViewEnabled && root._hasExternalLiveViewScreen)

    // Mock test trên máy 1 màn hình: KH�"NG tạo cửa s�. OS riêng (tránh FATAL
    // "no screens available"); live view giả lập hi�fn th�< bằng overlay ngay trong app.
    readonly property bool _mockLiveViewOverlay:
        root._externalLiveViewMockEnabled && !root._hasExternalLiveViewScreen

    // Khi live view phụ active + CaptureScreen �'ang hi�fn th�<: live view ch�? ra HDMI (hoặc
    // cửa s�. mock), vùng live view chính �'�.i thành photo wall ảnh �'ã chụp.
    readonly property bool externalLiveViewMode:
        false

    function _parseIntOr(value, fallback) {
        var n = parseInt(value)
        return isNaN(n) ? fallback : n
    }

    function _isValidScreenIndex(index) {
        if (typeof displayManager === "undefined" || !displayManager)
            return index >= 0 && index < root._screenCount
        return displayManager.isValidScreenIndex(index)
    }

    function _isPrimaryScreenIndex(index) {
        if (typeof displayManager === "undefined" || !displayManager)
            return index === 0
        return displayManager.isPrimaryScreenIndex(index)
    }

    function _isUsableExternalLiveViewScreen(index) {
        return _isValidScreenIndex(index) && !_isPrimaryScreenIndex(index)
    }

    function _resolveExternalLiveViewScreenIndex() {
        var saved = _parseIntOr(eventManager.getAppSetting("external_live_view_screen_index", ""), -1)
        if (_isUsableExternalLiveViewScreen(saved))
            return saved

        if (typeof displayManager !== "undefined" && displayManager) {
            var fallback = displayManager.defaultExternalLiveViewScreenIndex()
            if (_isUsableExternalLiveViewScreen(fallback))
                return fallback
        }

        return saved >= 0 ? saved : 1
    }

    function _reloadExternalDisplaySettings() {
        root._externalLiveViewEnabled =
            eventManager.getAppSetting("external_live_view_enabled", "true") === "true"
        root._externalLiveViewMockEnabled =
            eventManager.getAppSetting("external_live_view_mock_enabled", "false") === "true"
        root._externalPhotoWallEnabled =
            eventManager.getAppSetting("external_photo_wall_enabled", "true") === "true"
        root._externalWindowsFullscreen =
            eventManager.getAppSetting("external_windows_fullscreen", "true") === "true"
        root._externalLiveViewScreenIndex = root._resolveExternalLiveViewScreenIndex()

        var savedWall = eventManager.getAppSetting("external_photo_wall_screen_index", "")
        root._externalPhotoWallScreenIndex = savedWall !== ""
            ? root._parseIntOr(savedWall, 0)
            : ((typeof displayManager !== "undefined" && displayManager)
               ? displayManager.defaultPhotoWallScreenIndex() : 0)

        root._syncLiveViewViewer()
        root._syncExternalWindows()
    }

    // �"?�"? Photo review (mask Nikon capture freeze) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Sau khi bấm máy, hi�?n ảnh vừa chụp (hoặc "�'ang xử lý") toàn màn hình �'�f CHE
    // khoảng �'ứng bắt bu�Tc của live view khi camera Device_Busy. Ch�? dùng cho
    // Nikon (Canon/Sony resume live view �'ủ nhanh, không cần che).
    property bool   _reviewActive: false
    property int    _reviewIndex: -1
    property string _reviewPath: ""

    // Auto mode: chờ kết quả collage async (signal collageReady) trư�>c khi
    // emit sessionFinished. Trư�>c �'ây processCollage() chạy �'�"ng b�T trên UI thread.
    property bool _pendingAutoCollage: false
    property var  _autoResultPhotos: []

    // Retake state: track if we're doing a single-photo retake
    property bool isRetaking: false
    property int retakeIndex: -1

    // Backup ảnh ngay trư�>c khi chụp lại �?" fallback khi phiên hết giờ giữa lúc
    // chụp lại (ảnh m�>i chưa k�<p chụp) �'�f KH�"NG mất ảnh cũ của khách.
    property bool   _retakeHasBackup: false
    property int    _retakeBackupIndex: -1
    property string _retakeBackupPath: ""
    property string _retakeBackupRealPath: ""

    // Visual highlight: index of the last retaken photo (-1 = none)
    property int lastRetakenIndex: -1

    // Cached count of captured photos �?" avoids running for-loops in multiple bindings
    property int capturedCount: 0
    // True only while a shutter command is waiting for success/error. This
    // prevents a second retake from replacing the state of the first one.
    property bool _captureInFlight: false
    property int _captureRetryCount: 0
    readonly property int _captureMaxAfRetries: 2
    property bool _captureFallbackNoAf: false
    property string _captureRetryMessage: ""
    property bool _captureTerminalError: false
    property string _terminalErrorCode: ""


    // Session countdown (auto-proceed when time runs out)
    property int _configuredSessionTimeLimit: parseInt(eventManager.getAppSetting("capture_session_countdown", "120")) || 120
    property int sessionRemainingTime: root._configuredSessionTimeLimit
    // Gi�>i hạn thời gian phiên theo G�"I CHỤP (giây). >0 = bật �'ếm ngược gói; 0 = không gi�>i hạn.
    // BoothSession truyền vào = s�' phút gói �- 60. Hết giờ �?' tự sang bư�>c chọn frame.
    property int sessionTimeLimit: 0
    // Mode3 (ma co dinh): chup tu do, khong gioi han so anh, toi het sessionTimeLimit
    // hoac khach bam Xong. Mac dinh tat -> cac mode khac giu nguyen.
    property bool freeCaptureUntilTimeout: false
    // Free mode: da gui lenh chup tu app, cho file anh ve (bo qua moi lan bam trong luc nay).
    property bool _awaitingFreeFile: false
    // Free mode: thong bao ngan khi lenh chup that bai / may ban.
    property string _freeShotNotice: ""
    readonly property int _effectiveSessionTimeLimit:
        (root.noRetakeMode || root.freeCaptureUntilTimeout)
                          ? Math.max(0, root.sessionTimeLimit)
                          : Math.max(0, root._configuredSessionTimeLimit)

    // Chụp bằng dây remote: app KH�"NG tự chụp; khách bấm nút vật lý, ảnh về qua
    // onImageCaptured. Live view full màn hình, ch�? hi�?n thời gian gói + s�' ảnh.
    // Hot Folder cũng vậy: ảnh tới từ thư mục khi thợ bấm remote, app không điều khiển máy.
    readonly property bool hotFolderMode: cameraController.captureSource === "hotfolder"
    readonly property bool remoteMode: root.hotFolderMode
                                       || eventManager.getAppSetting("remote_shutter_enabled", "false") === "true"

    // Chụp mock: khi không có máy ảnh, sinh ảnh "VIRTUAL PHOTO" �'�f test toàn lu�"ng.
    property bool mockMode: eventManager.getAppSetting("mock_capture_enabled", "false") === "true"
    readonly property bool virtualCaptureMode: root.mockMode
    onVirtualCaptureModeChanged: root._syncVirtualCaptureMode()

    // Hình nền trang chụp (cài trong Cài Đặt > Ảnh background). Mặc định = qrc 4.png;
    // admin có thể ghi đè. Khi có ảnh: panel live view + khung xem ảnh thành trong suốt.
    property string captureBgImage: eventManager.getAppSetting("capture_bg_image", "qrc:/assets/4.png")
    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "capture_bg_image")
                root.captureBgImage = (value !== "" ? value : "qrc:/assets/4.png")
            else if (key === "no_retake_enabled")
                root.noRetakeMode = (value === "true")
            else if (key === "capture_session_countdown")
                root._configuredSessionTimeLimit = parseInt(value) || 120
            else if (key === "mock_capture_enabled") {
                root.mockMode = (value === "true")
                root._syncVirtualCaptureMode()
            }
        }
    }

    function _queueCapturedAsset(index, urlPath) {
        if (!urlPath || root.sessionId === "" || root.eventId <= 0)
            return
        if (typeof s3Uploader === "undefined" || !s3Uploader)
            return
        var clean = decodeURIComponent(urlPath.toString())
        clean = clean.replace(/^file:\/\/\//, "")
        clean = clean.replace(/^file:\/\//, "")
        clean = clean.replace(/^file:/, "")
        var rawPath = (root.eventData && root.eventData.rawPath) ? root.eventData.rawPath : ""
        s3Uploader.setCurrentEventRawPath(rawPath)
        s3Uploader.enqueueCaptureAsset(clean, machineAuth.hwid, root.eventId, root.sessionId, "photo", index + 1)
    }
    function toUrl(p) {
        if (!p || p === "") return ""
        if (p.startsWith("file:") || p.startsWith("qrc:") || p.startsWith("http")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    function _syncVirtualCaptureMode() {
        if (!cameraController || typeof cameraController.setMockCaptureEnabled !== "function")
            return
        cameraController.setMockCaptureEnabled(root.virtualCaptureMode)
        if (root.virtualCaptureMode)
            console.warn("CaptureScreen: Test capture enabled - virtual photos will be generated")
    }

    // �"?�"? Layout (chế �'�T thường) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    readonly property int frameMargin: 24       // lề khung live view + lề chung
    readonly property int rightColumnWidth: 260 // bề r�Tng c�Tt thumbnail dọc bên phải

    // �"?�"? No-retake mode �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Bật qua Cài Đặt Chụp (key per-event "no_retake_enabled"). Ch�? áp dụng
    // Auto/Manual: live view �Y giữa khung trắng, trái = s�' ảnh, phải = �'ếm ngược,
    // không thumbnail/Tiếp Tục/chụp lại; chụp �'ủ ảnh tự chuy�fn bư�>c tiếp theo.
    // Luôn bật No-retake: chế �'�T chụp lại �'ã b�< bỏ hoàn toàn.
    property bool noRetakeMode: eventManager.getAppSetting("no_retake_enabled", "false") === "true"
    readonly property bool _studioCaptureMode: root.operationMode === "mode2" || root.operationMode === "mode3"
    readonly property int nrSideBand: 240   // bề r�Tng vùng count (trái) / countdown (phải)

    // �"?�"? Template Mode (shootingMode === 2) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Chế �'�T chụp theo mẫu (Template) �'ã b�< tắt hoàn toàn �?" luôn dùng Manual.
    property bool isTemplateMode: false
    readonly property bool _centeredCaptureLayout:
        !root.isTemplateMode && !root.remoteMode && !root.freeCaptureUntilTimeout
        && (root._studioCaptureMode || root.noRetakeMode)
    readonly property bool _captureReviewMode: !root.noRetakeMode
    readonly property int _captureLeftBand: root._centeredCaptureLayout ? (root.noRetakeMode ? root.nrSideBand : 0) : 0
    readonly property int _captureRightBand: root._centeredCaptureLayout ? root.nrSideBand : 0
    property var  tmSlots: []           // [{x,y,w,h}] in layout coords
    property real tmOrigW: 2362
    property real tmOrigH: 3543
    property string tmLayoutFileUrl: ""
    // Current slot, mapped to screen pixels (updated by updateTmSlotRect)
    property real tmSlotScreenX: 0
    property real tmSlotScreenY: 0
    property real tmSlotScreenW: 200
    property real tmSlotScreenH: 200
    // Screen-space rects for ALL slots [{x,y,w,h}] �?" used by slot photo Repeater
    property var tmAllSlotRects: []
    // Left margin of the centered frame on screen (empty band to its left) �?" used to
    // park the countdown OUTSIDE the frame so it doesn't cover the pose.
    property real tmFrameOffX: 0

    Timer {
        id: retakeHighlightTimer
        interval: 4000   // xanh lá hi�fn 4 giây r�"i tắt
        onTriggered: root.lastRetakenIndex = -1
    }

    Timer {
        id: sessionCountdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            root.sessionRemainingTime--
            if (root.sessionRemainingTime <= 0) {
                stop()
                // Chụp tự do / remote: không cắt ngang ảnh khách vừa bấm sát giờ.
                if (root._appendsPhotos) {
                    if (!root.isProcessing)
                        root._beginAppendFinish()
                    return
                }
                // Hết giờ phiên giữa lúc chụp lại �?' khôi phục ảnh cũ �'�f không mất ảnh.
                root._restorePrevPhotoIfRetaking()
                if (root.capturedCount > 0 && !root.isProcessing)
                    root.handleCaptureSessionCompletion()
            }
        }
    }

    // Chờ ảnh cuối (xem _beginAppendFinish): kiểm tra mỗi 0,5 s đã đủ điều kiện kết thúc chưa.
    readonly property int _finishSettleMs: 2000    // Canon báo "đã chụp" trễ 0,3–1,5 s sau khi bấm
    readonly property int _finishQuietMs: 3000     // Hot Folder: không có file mới chừng này
    readonly property int _finishMaxWaitMs: 15000  // chờ tối đa; ảnh về sau đó → khung ảnh trễ
    Timer {
        id: finishPollTimer
        interval: 500
        repeat: true
        running: false
        onTriggered: root._tryCompleteAppendFinish()
    }

    Timer {
        id: captureRetryTimer
        interval: 900
        repeat: false
        onTriggered: root._submitCapture(root._captureFallbackNoAf)
    }

    Timer {
        id: cameraDisconnectDeadline
        interval: 10000
        repeat: false
        onTriggered: root._setTerminalCameraError("CAMERA_DISCONNECTED", "Mất kết nối máy ảnh quá 10 giây")
    }

    Timer {
        id: imageDownloadDeadline
        interval: 10000
        repeat: false
        onTriggered: {
            if (root.freeCaptureUntilTimeout) {
                if (root._awaitingFreeFile || root._captureInFlight)
                    root._freeShotFailed("Máy ảnh không trả ảnh, vui lòng bấm lại")
                return
            }
            if (root._downloadQueue.length > 0)
                root._setTerminalCameraError("CAMERA_FILE_TIMEOUT", "Máy ảnh không trả file sau 10 giây")
        }
    }

    // Gi�>i hạn thời gian hi�fn review nếu không có countdown kế tiếp (ảnh cu�'i) �?"
    // tự ẩn �'�f trả lại live view thay vì kẹt màn review.
    Timer {
        id: reviewHideTimer
        interval: 2200
        repeat: false
        onTriggered: root._endReview()
    }

    // Model to store captured image paths
    ListModel {
        id: sessionPhotos
        // Elements: { "path": string, "captured": bool }
    }


    ListModel {
        id: externalSessionPhotos
        // Elements: { "path": string, "photoIndex": int }
    }

    // Photo wall (external mode): ảnh �'ang hi�fn th�< �Y ô l�>n giữa vùng. Cập nhật khi có
    // ảnh m�>i về hoặc khi khách bấm mũi tên �'iều hư�>ng. R�-ng khi chưa có ảnh.
    property string _externalWallCenterPath: ""
    // Ch�? s�' ảnh �'ang hi�fn th�< �Y giữa (index trong externalSessionPhotos); -1 = chưa có ảnh.
    property int _wallViewIndex: -1

    // Pose guide state: slots loaded from layout JSON
    property var poseSlots: []          // [{x,y,w,h}] in original layout coords
    property real poseOriginalW: 2362   // Layout canvas dimensions (updated from JSON)
    property real poseOriginalH: 3543
    property bool poseGuideActive: false  // Set by onEventDataChanged

    onEventDataChanged: {
        if (eventData) {
            poseGuideActive = eventData.poseGuide === true
            console.log("CaptureScreen: poseGuide =", poseGuideActive,
                        "| selectedLayout =", eventData.selectedLayout)
        }
    }

    // Load layout slot metadata for pose overlay
    function loadPoseSlots() {
        if (!poseGuideActive) {
            console.log("CaptureScreen Pose: poseGuide is OFF, skipping")
            return
        }
        var layoutPath = eventData ? eventData.selectedLayout : ""
        if (!layoutPath) {
            console.warn("CaptureScreen Pose: no selectedLayout in eventData")
            return
        }
        console.log("CaptureScreen Pose: loading from", layoutPath)
        var meta = eventManager.loadLayoutMetadata(layoutPath)
        if (!meta || !meta.slots) {
            console.warn("CaptureScreen Pose: metadata invalid:", JSON.stringify(meta))
            return
        }
        if (meta.width)  poseOriginalW = meta.width
        if (meta.height) poseOriginalH = meta.height

        var arr = []
        for (var i = 0; i < meta.slots.length; i++) {
            var s = meta.slots[i]
            arr.push({ x: s.x, y: s.y, w: s.width, h: s.height })
        }
        poseSlots = arr
        console.log("CaptureScreen Pose: loaded", arr.length, "slots, canvas",
                    poseOriginalW, "x", poseOriginalH)
    }

    // Compute screen-space rects for all template slots (and update current slot)
    function updateTmSlotRect() {
        if (!isTemplateMode || tmSlots.length === 0) { return }
        var scale = Math.min(width / tmOrigW, height / tmOrigH)
        var offX = (width  - tmOrigW * scale) / 2
        var offY = (height - tmOrigH * scale) / 2
        root.tmFrameOffX = offX
        // Build rects for every slot
        var rects = []
        for (var i = 0; i < tmSlots.length; i++) {
            var s = tmSlots[i]
            rects.push({ x: offX + s.x * scale, y: offY + s.y * scale,
                         w: s.w * scale,         h: s.h * scale })
        }
        root.tmAllSlotRects = rects
        // Update live-view slot (current index, clamped)
        var idx = Math.min(currentPhotoIndex, tmSlots.length - 1)
        if (idx < 0) { return }
        tmSlotScreenX = rects[idx].x
        tmSlotScreenY = rects[idx].y
        tmSlotScreenW = rects[idx].w
        tmSlotScreenH = rects[idx].h
    }

    // Load slot geometry and layout URL for template mode
    function loadTemplateSlots() {
        if (!isTemplateMode) { return }
        var layoutPath = eventData ? eventData.selectedLayout : ""
        if (!layoutPath) { return }
        root.tmLayoutFileUrl = layoutPath
        var meta = eventManager.loadLayoutMetadata(layoutPath)
        if (!meta || !meta.slots) { return }
        if (meta.width)  { root.tmOrigW = meta.width  }
        if (meta.height) { root.tmOrigH = meta.height }
        var arr = []
        for (var i = 0; i < meta.slots.length; i++) {
            var s = meta.slots[i]
            arr.push({ x: s.x, y: s.y, w: s.width, h: s.height })
        }
        root.tmSlots = arr
        updateTmSlotRect()
    }

    // �"?�"? Live view decode gating �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Đ�fng ký "viewer" v�>i CameraController khi CaptureScreen là item �'ang hi�fn
    // th�< trên StackView. Khi b�< �'ẩy xu�'ng (Composition/Result�?�), nhả viewer �?'
    // decode thread tạm dừng giải mã �?' tiết ki�?m ~15-30% CPU thường trực.
    property bool _lvViewerHeld: false

    // Lật ngang (mirror) live view: CameraController.mirrorMode là nguồn dữ liệu
    // duy nhất, áp dụng thật sự trong C++ (per-frame) — ở đây chỉ đảm bảo giá trị
    // đã lưu trong DB được áp lại mỗi khi CaptureScreen khởi tạo / được active lại
    // (kết nối lại máy ảnh, chuyển màn hình, phiên chụp mới...), phòng trường hợp
    // màn hình này là nơi đầu tiên chạy trong phiên (trước khi main.qml kịp đồng bộ).
    function _syncMirrorMode() {
        var enabled = eventManager.getAppSetting("mirror_mode", "true") === "true"
        if (cameraController.mirrorMode !== enabled)
            cameraController.setMirrorMode(enabled)
    }

    function _syncLiveViewViewer() {
        // External mode v�>i màn HDMI thật: live view ra cửa s�. riêng �?' panel chính KH�"NG
        // giữ viewer (cửa s�. �'ó tự giữ). Tránh double-count và giữ decode chạy ch�? vì panel
        // chính �'ã ẩn. Mock test không có cửa s�. riêng �?' overlay trong app là "người xem"
        // nên vẫn giữ viewer �Y �'ây.
        var want = (StackView.status === StackView.Active
                 || StackView.status === StackView.Activating)
        if (want && !_lvViewerHeld) {
            cameraController.addLiveViewViewer()
            _lvViewerHeld = true
        } else if (!want && _lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            _lvViewerHeld = false
        }
    }


    function _externalWindowsWanted() {
        return StackView.status === StackView.Active
            || StackView.status === StackView.Activating
    }

    function _syncExternalWindows() {
        return
        var want = _externalWindowsWanted()

        // Cửa s�. live view phụ CH�^ m�Y khi có màn HDMI THẬT (fullscreen, không �'è lên màn
        // chính qua fallback primary). Mock test KH�"NG tạo cửa s�. OS riêng �?" tránh FATAL
        // "no screens available" trên máy 1 màn hình; live view giả lập dùng overlay
        // trong app (mockLiveViewOverlay). 1 màn hình + không mock �?' không m�Y, giữ live
        // view chính như cũ.
        externalLiveViewWindow.displayActive =
            want && root._externalLiveViewEnabled && root._hasExternalLiveViewScreen
        externalLiveViewWindow.screenIndex = root._externalLiveViewScreenIndex
        externalLiveViewWindow.fullscreen = root._externalWindowsFullscreen
        if (externalLiveViewWindow.displayActive)
            externalLiveViewWindow.openWindow()
        else
            externalLiveViewWindow.closeWindow()

        // Photo wall window RI�SNG ch�? còn là tùy chọn nâng cao cho h�? 3 màn hình:
        // cần bật external_photo_wall_enabled, có màn thứ 3 thật (index > 0, khác màn
        // live view, nằm trong dải màn hình). Mặc �'�<nh 2 màn hình KH�"NG m�Y �?" photo wall
        // hi�fn th�< ngay trong vùng live view cũ của main app.
        var wallScreen = root._externalPhotoWallScreenIndex
        var wallWanted = want && root._externalPhotoWallEnabled
                      && root._screenCount >= 3
                      && root._isValidScreenIndex(wallScreen)
                      && !root._isPrimaryScreenIndex(wallScreen)
                      && wallScreen !== root._externalLiveViewScreenIndex
        externalPhotoWallWindow.screenIndex = wallScreen
        externalPhotoWallWindow.fullscreen = root._externalWindowsFullscreen
        if (wallWanted)
            externalPhotoWallWindow.openWindow()
        else
            externalPhotoWallWindow.closeWindow()
    }

    function _setExternalPhoto(photoIndex, photoPath) {
        if (!photoPath || photoPath === "") return
        // Ảnh m�>i chụp / chụp lại �?' hi�?n ngay �Y ô l�>n giữa photo wall.
        root._externalWallCenterPath = photoPath
        for (var i = 0; i < externalSessionPhotos.count; i++) {
            if (externalSessionPhotos.get(i).photoIndex === photoIndex) {
                externalSessionPhotos.setProperty(i, "path", photoPath)
                root._wallViewIndex = i
                return
            }
        }
        externalSessionPhotos.append({ "path": photoPath, "photoIndex": photoIndex })
        root._wallViewIndex = externalSessionPhotos.count - 1
    }

    // Điều hư�>ng photo wall bằng mũi tên: clamp trong dải ảnh + �'�"ng b�T index/�'ường d�-n.
    function _wallShow(idx) {
        if (idx < 0 || idx >= externalSessionPhotos.count) return
        root._wallViewIndex = idx
        root._externalWallCenterPath = externalSessionPhotos.get(idx).path || ""
    }
    // �"?�"? Relay (�'èn phòng chụp) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Bật relay �'ã chọn khi CaptureScreen là màn �'ang hi�fn th�<; tắt khi rời màn
    // (�'ẩy sang ghép ảnh / Auto ra kết quả / �'óng). relayController tự no-op nếu
    // tính n�fng chưa bật hoặc chưa kết n�'i thiết b�<.
    property bool _relayOn: false
    function _relayControllerAvailable() {
        return typeof relayController !== "undefined"
                && relayController !== null
                && typeof relayController.activateSelected === "function"
                && typeof relayController.deactivateSelected === "function"
    }

    function _syncRelay() {
        if (!root.manageRelay || !root._relayControllerAvailable())
            return
        var want = (StackView.status === StackView.Active
                 || StackView.status === StackView.Activating)
        if (want && !_relayOn) {
            relayController.activateSelected()
            _relayOn = true
        } else if (!want && _relayOn) {
            relayController.deactivateSelected()
            _relayOn = false
        }
    }

    StackView.onStatusChanged: {
        if (StackView.status === StackView.Active || StackView.status === StackView.Activating)
            root._syncMirrorMode()
        _syncLiveViewViewer(); _syncExternalWindows(); _syncRelay()
    }
    // Cắm/rút màn HDMI khi �'ang chụp �?' cập nhật lại viewer count + cửa s�. phụ + �'�.i
    // giữa live view chính và photo wall.
    onExternalLiveViewModeChanged: { _syncLiveViewViewer(); _syncExternalWindows() }

    // Cam/rut/chap chon HDMI man phu khien Windows ban screenRemoved+screenAdded lien
    // tiep. KHONG phan ung tuc thi (mo cua so fullscreen tren man dang qua do -> de crash);
    // doi topology man hinh on dinh roi moi reload MOT lan (debounce chong thrash).
    Timer {
        id: screenSettleTimer
        interval: 600
        repeat: false
        onTriggered: root._reloadExternalDisplaySettings()
    }
    Connections {
        target: (typeof displayManager !== "undefined" && displayManager) ? displayManager : null
        function onScreenCountChanged() {
            screenSettleTimer.restart()
        }
    }

    Connections {
        target: eventManager
        function onAppSettingChanged(key, value) {
            if (key === "external_live_view_enabled"
                    || key === "external_live_view_screen_index"
                    || key === "external_photo_wall_enabled"
                    || key === "external_photo_wall_screen_index"
                    || key === "external_windows_fullscreen"
                    || key === "external_live_view_mock_enabled") {
                root._reloadExternalDisplaySettings()
            } else if (key === "mirror_mode") {
                root._syncMirrorMode()
            }
        }
    }

    Component.onDestruction: {
        // Đã chụp xong: EventManager giữ hot folder thêm 60 s để nhận ảnh về trễ rồi tự tắt.
        if (!root._captureClosed)
            cameraController.setHotFolderArmed(false)
        if (finishPollTimer.running) finishPollTimer.stop()
        // Luôn khóa lại máy khi rời màn remote (tránh �'�f UIUnLock treo).
        if (root.freeCaptureUntilTimeout)
            cameraController.setRemoteShutterModeAsync(false)
        else if (root.remoteMode)
            cameraController.setRemoteShutterMode(false)
        if (captureRetryTimer.running)
            captureRetryTimer.stop()
        if (cameraDisconnectDeadline.running) cameraDisconnectDeadline.stop()
        if (imageDownloadDeadline.running) imageDownloadDeadline.stop()
        if (_lvViewerHeld) {
            cameraController.removeLiveViewViewer()
            _lvViewerHeld = false
        }
        // Lư�>i an toàn: tắt relay khi màn chụp b�< hủy (mọi nhánh, k�f cả Auto mode).
        if (root.manageRelay && _relayOn && root._relayControllerAvailable()) {
            relayController.deactivateSelected()
            _relayOn = false
        }
    }

    Component.onCompleted: {
        // Đảm bảo live view mirror đúng chiều ngay khi màn chụp khởi tạo, không phụ
        // thuộc việc người dùng đã từng mở Cài đặt trong phiên chạy app này chưa.
        root._syncMirrorMode()
        // Đ�fng ký viewer ngay khi màn hình xuất hi�?n
        _syncLiveViewViewer()
        _syncExternalWindows()
        // Bật relay �'ã chọn (no-op nếu tính n�fng tắt / chưa kết n�'i)
        _syncRelay()
        // Áp chế �'�T mock: khi không có máy ảnh m�>i sinh ảnh mock (cả manual & remote).
        root._syncVirtualCaptureMode()

        // Set storage path for camera
        if (sessionPath !== "") {
            console.log("CaptureScreen: Setting session path to " + sessionPath)
            cameraController.setSessionStoragePath(sessionPath)
        }


        var requestedCount = parseInt(root.totalPhotos) || 0
        if (requestedCount <= 0) {
            // Compatibility fallback for any direct CaptureScreen caller that has
            // not gone through BoothSession's capture-count resolver.
            var captureConfig = eventData
            if (root.eventId > 0) {
                var latestConfig = eventManager.getEventDetails(root.eventId)
                if (latestConfig && latestConfig.id)
                    captureConfig = latestConfig
            }
            requestedCount = captureConfig ? (parseInt(captureConfig.manualPhotoCount) || 0) : 0
        }
        if (requestedCount <= 0)
            requestedCount = 6
        root.totalPhotos = Math.max(1, Math.min(root.captureCap, requestedCount))
        console.log("CaptureScreen: Fixed capture count =", root.totalPhotos,
                    "| followFrame =", root.followFramePhotoCount)

        // Initialize placeholders
        sessionPhotos.clear()
        externalSessionPhotos.clear()
        root._externalWallCenterPath = ""
        root._wallViewIndex = -1
        root.capturedCount = 0
        root._captureStartedAt = Date.now()
        // Màn này tự nhận ảnh: đóng khung nhận ảnh trễ của phiên trước (nếu còn).
        eventManager.setCaptureAccepting(root.sessionId, root.eventId, true)
        root._syncExternalWindows()
        // Hot Folder: bắt đầu nhận ảnh từ thư mục (file có sẵn trước lúc này bị bỏ qua).
        if (root.hotFolderMode)
            cameraController.setHotFolderArmed(true)
        if (root.freeCaptureUntilTimeout) {
            // Mode3 chup tu do: khong slot dung san, khong dem nguoc 3-2-1, khong video.
            // Chup khi khach bam chuot trai / Space (app gui lenh) hoac nut remote gan
            // may (anh ve qua onImageCaptured). Mo khoa nut vat ly tren pool camera
            // de UI khong cho mutex SDK.
            root.totalPhotos = 0
            cameraController.setRemoteShutterModeAsync(true)
            if (root.sessionId !== "")
                sessionManager.beginCapture(root.sessionId, 0)
            console.log("CaptureScreen: FREE capture mode ON - mouse / Space / camera remote")
        } else if (root.remoteMode) {
            // Remote: KH�"NG pre-fill slot, KH�"NG auto-shoot. Bật chế �'�T dây remote �?'
            // máy m�Y khóa nút vật lý; ảnh về qua onImageCaptured (append �'�Tng).
            cameraController.setRemoteShutterMode(true)
            if (root.sessionId !== "")
                sessionManager.beginCapture(root.sessionId, 0)
            console.log("CaptureScreen: REMOTE shutter mode ON - waiting for physical shutter")
        } else {
            for (var i = 0; i < root.totalPhotos; i++) {
                sessionPhotos.append({ "path": "", "captured": false, "realPath": "" })
            }
            if (root.sessionId !== "")
                sessionManager.beginCapture(root.sessionId, root.totalPhotos)
            startCountdownSequence()
            loadPoseSlots()
            loadTemplateSlots()
        }
        // Gi�>i hạn thời gian theo G�"I CHỤP: nếu có sessionTimeLimit thì �'ếm ngược
        // �'úng thời lượng gói; hết giờ tự sang bư�>c chọn frame. Khách vẫn bấm "Xong"
        // �'�f dừng s�>m. Không có gói (=0) �?' không gi�>i hạn thời gian phiên.
        if (root._effectiveSessionTimeLimit > 0) {
            root.sessionRemainingTime = root._effectiveSessionTimeLimit
            sessionCountdownTimer.start()
        }
    }

    // -------------------------------------------------------------------------
    // Logic Functions
    // -------------------------------------------------------------------------

    function startCountdownSequence() {
        // Ẩn màn review �'�f khách thấy live view (tạo dáng) cho ảnh kế tiếp.
        root._endReview()

        if (currentPhotoIndex >= totalPhotos) {
            // Setup finished, waiting for user confirmation
            return
        }

        // Note: Live View runs as a persistent service
        // Just verify it's active (should always be true)
        if (!cameraController.isLiveViewActive) {
            console.warn("CaptureScreen: Live view not active - this shouldn't happen with service mode")
        }

        isCountingDown = true

        // Use different countdown based on photo index
        if (currentPhotoIndex === 0) {
            // First shot - use firstShotCountdown
            countdownValue = eventData ? (eventData.firstShotCountdown || 3) : 3
        } else {
            // Subsequent shots - use nextShotCountdown
            countdownValue = eventData ? (eventData.nextShotCountdown || 3) : 3
        }

        console.log("CaptureScreen: Starting countdown for photo", currentPhotoIndex + 1, "with", countdownValue, "seconds")

        if (!root.remoteMode && cameraController.isLiveViewActive) {
            var recDir = eventManager.getSessionRecordingDir(root.sessionId)
            cameraController.startSlotRecording(root.currentPhotoIndex, recDir)
        }

        countdownTimer.restart()
    }

    // Nikon-only speed optimisation: the AF step is the biggest, most variable
    // chunk of the per-shot live-view freeze (the camera is Device_Busy during
    // AF + exposure + processing). Live view runs continuous AF, so the subject
    // is already in focus. We AF only on the FIRST shot (and retakes) to lock
    // focus, then shoot No-AF for the rest �?" cutting ~0.3-1.5s off each freeze.
    // Canon/Sony resume live view fast, so they always AF (safest focus).
    function _captureShouldUseAF() {
        // Không có máy ảnh (mock): AF vô nghĩa �?' chụp No-AF �'�f không vư�>ng �'ường lấy nét.
        if (!cameraController.isConnected) return false
        if (!cameraController.afEnabled) return false
        if (cameraController.cameraType !== "Nikon") return true
        if (root.isRetaking) return true
        if (root.capturedCount === 0) return true   // first shot: lock focus
        return false
    }

    function _usesCaptureReviewOverlay() {
        return cameraController.cameraType === "Nikon" || cameraController.cameraType === "Fuji"
    }

    // Bật màn review �'�f che khoảng �'ứng live view (Nikon/Fuji, không phải template mode).
    function _startReview(index) {
        // Mode3: ảnh mới đã tự hiện ở nửa dưới nên không cần màn che review.
        if (root.freeCaptureUntilTimeout)
            return
        if (!root._usesCaptureReviewOverlay() || root.isTemplateMode)
            return
        root._reviewIndex  = index
        // Nếu ảnh �'ã có sẵn (chụp lại slot cũ) thì hi�?n luôn, không thì chờ file về.
        var existing = (index >= 0 && index < sessionPhotos.count)
                       ? sessionPhotos.get(index).path : ""
        root._reviewPath   = existing || ""
        root._reviewActive = true
        reviewHideTimer.restart()
    }

    function _endReview() {
        if (reviewHideTimer.running) reviewHideTimer.stop()
        root._reviewActive = false
        root._reviewPath = ""
        root._reviewIndex = -1
    }

    function triggerCapture() {
        if (root._captureInFlight) {
            console.warn("CaptureScreen: Ignoring duplicate capture while shutter is busy")
            return
        }
        isCountingDown = false
        root._captureRetryCount = 0
        root._captureFallbackNoAf = false
        root._captureRetryMessage = ""
        // Che ngay khoảnh khắc bấm máy �?" live view sẽ �'ứng từ �'ây.
        root._startReview(root.currentPhotoIndex)
        root._submitCapture(!root._captureShouldUseAF())
    }

    // Free mode (mode3): mot lan bam chuot trai / Space = mot lenh chup ngay, khong dem nguoc.
    // May dang ban (lenh chua xong / anh chua ve) -> bo qua lan bam, khong gui them lenh
    // cho SDK. Lenh loi -> khong retry (co the do remote vat ly dang chup).
    function _requestFreeShot(source) {
        if (!root.freeCaptureUntilTimeout) return
        // Hot Folder: chỉ chụp bằng remote trên máy, ảnh tự về từ thư mục.
        if (root.hotFolderMode) return
        var reason = root._captureInFlight ? "shutter busy"
                   : root._awaitingFreeFile ? "waiting for file"
                   : root.isProcessing ? "processing"
                   : root._finishing ? "finishing"
                   : root._captureTerminalError ? "camera error"
                   : !sessionCountdownTimer.running ? "session ended"
                   : ""
        if (reason !== "") {
            console.log("CaptureScreen: free shot ignored (" + source + "):", reason)
            return
        }
        root._freeShotNotice = ""
        root._captureInFlight = true
        root._awaitingFreeFile = true
        imageDownloadDeadline.restart()
        root._startReview(-1)
        var noAf = !root._captureShouldUseAF()
        console.log("CaptureScreen: free shot (" + source + ") | noAf:", noAf)
        var ok = noAf ? cameraController.takePictureNoAF() : cameraController.takePicture()
        if (!ok)
            root._freeShotFailed("Máy ảnh chưa sẵn sàng, vui lòng bấm lại")
    }

    function _freeShotFailed(msg) {
        root._captureInFlight = false
        root._awaitingFreeFile = false
        if (imageDownloadDeadline.running) imageDownloadDeadline.stop()
        root._endReview()
        root._freeShotNotice = msg
        freeShotNoticeTimer.restart()
        console.warn("CaptureScreen: free shot failed:", msg)
        // Đang chờ ảnh cuối: lệnh này không ra ảnh → xem đã kết thúc được chưa.
        if (root._finishing)
            root._tryCompleteAppendFinish()
    }

    // Nút "Hoàn thành" (mode3): như hết giờ — chờ ảnh đã bấm về đủ rồi kết thúc
    // (có ảnh → bước tiếp, 0 ảnh → huỷ lượt).
    function _onFreeDoneClicked() {
        root._beginAppendFinish()
    }

    // Hết giờ / bấm Hoàn thành (chụp tự do, remote): khóa bấm mới nhưng KHÔNG cắt ngang
    // ảnh khách đã bấm — chờ ảnh về đủ (tối đa _finishMaxWaitMs) rồi mới kết thúc.
    function _beginAppendFinish() {
        if (root._finishing || root.isProcessing || root._captureClosed)
            return
        root._finishing = true
        root._finishStartedAt = Date.now()
        root._lastFileAt = 0
        root._stopFreeCaptureTimers()
        // Chuột/Space bị chặn qua _finishing; khóa nút trên máy ảnh / remote (Canon).
        // Ảnh máy đã chụp vẫn tiếp tục truyền về.
        if (root.freeCaptureUntilTimeout)
            cameraController.setRemoteShutterModeAsync(false)
        else
            cameraController.setRemoteShutterMode(false)
        console.log("CaptureScreen: finishing - waiting for photos already taken | pending shutter:",
                    root._shutterPendingFiles, "| awaiting:", root._awaitingFreeFile || root._captureInFlight)
        finishPollTimer.restart()
    }

    function _tryCompleteAppendFinish() {
        if (!root._finishing)
            return
        var now = Date.now()
        var waited = now - root._finishStartedAt
        if (waited >= root._finishMaxWaitMs) {
            console.warn("CaptureScreen: finishing - stop waiting after", waited, "ms | pending shutter:",
                         root._shutterPendingFiles, "| hot folder busy:",
                         root.hotFolderMode && cameraController.hotFolderBusy())
            root._completeAppendFinish()
            return
        }
        if (waited < root._finishSettleMs)
            return
        if (root._shutterPendingFiles > 0 || root._awaitingFreeFile || root._captureInFlight)
            return
        if (root.hotFolderMode) {
            var quietSince = Math.max(root._finishStartedAt, root._lastFileAt)
            if (now - quietSince < root._finishQuietMs || cameraController.hotFolderBusy())
                return
        }
        root._completeAppendFinish()
    }

    function _completeAppendFinish() {
        finishPollTimer.stop()
        root._finishing = false
        root._shutterPendingFiles = 0
        root._captureInFlight = false
        root._awaitingFreeFile = false
        if (imageDownloadDeadline.running) imageDownloadDeadline.stop()
        // Ảnh đã nằm trên đĩa mà sự kiện bị lỡ → vẫn đưa vào phiên.
        root._sweepSessionFolder()
        if (root.capturedCount > 0) {
            root._pendingCompletion = false
            root.handleCaptureSessionCompletion()
        } else if (root.freeCaptureUntilTimeout) {
            root._pendingCompletion = false
            root.closeClicked()
        } else {
            // Remote chưa có ảnh nào: như trước, ở lại màn chụp chờ khách bấm.
            cameraController.setRemoteShutterMode(true)
        }
    }

    // Chụp xong: kết thúc phiên ngay (kể cả khi khách bỏ dở bước chọn frame / ghép sau đó),
    // báo server danh sách ảnh (/finalize), và nhường ảnh về trễ cho EventManager — nó giữ
    // hot folder thêm 60 s rồi tự tắt.
    function _closeCapture() {
        if (root._captureClosed)
            return
        root._captureClosed = true
        if (root.sessionId === "" || root.eventId <= 0) {
            cameraController.setHotFolderArmed(false)
            return
        }
        eventManager.setCaptureAccepting(root.sessionId, root.eventId, false, root.capturedCount)
        sessionManager.endSession(root.sessionId)
        if (typeof s3Uploader !== "undefined" && s3Uploader)
            s3Uploader.finalizeSession(root.sessionId)
    }

    function _photoPathKey(p) {
        var s = (p || "").toString().replace(/^file:\/\/\//, "").replace(/\\/g, "/")
        return decodeURIComponent(s).toLowerCase()
    }

    function _hasPhotoPath(p) {
        var key = root._photoPathKey(p)
        for (var i = 0; i < sessionPhotos.count; i++) {
            var item = sessionPhotos.get(i)
            if (root._photoPathKey(item.realPath || item.path) === key)
                return true
        }
        return false
    }

    // Ảnh của phiên đã ghi xuống thư mục (tên có mã phiên, ghi sau lúc mở màn này) nhưng
    // chưa có trong danh sách — sự kiện "ảnh về" bị lỡ. Thêm vào trước khi kết thúc.
    function _sweepSessionFolder() {
        if (root.sessionPath === "" || root.sessionId === "")
            return
        var files = eventManager.listSessionPhotoFiles(root.sessionPath, root.sessionId,
                                                       root._captureStartedAt - 2000)
        for (var i = 0; i < files.length; i++) {
            if (root._hasPhotoPath(files[i]))
                continue
            console.warn("CaptureScreen: photo on disk but never received - adding:", files[i])
            root._appendCapturedPhoto(files[i])
        }
    }

    // Chụp tự do / remote: một ảnh mới về (lệnh từ app, nút trên máy, remote, hot folder)
    // → thêm vào cuối danh sách, xếp upload.
    function _appendCapturedPhoto(path) {
        var fp = "file:///" + path.replace(/\\/g, "/")
        if (root._hasPhotoPath(fp)) {
            console.warn("CaptureScreen: duplicate photo event ignored:", fp)
            return
        }
        sessionPhotos.append({ "path": fp, "captured": true, "realPath": fp })
        if (root.freeCaptureUntilTimeout)
            root.totalPhotos = sessionPhotos.count
        root._setExternalPhoto(sessionPhotos.count - 1, fp)
        root._queueCapturedAsset(sessionPhotos.count - 1, fp)
        root.capturedCount++
        sessionManager.updateCaptureProgress(root.sessionId, root.capturedCount)
        root.photoReady(fp, sessionPhotos.count)
        if (root._shutterPendingFiles > 0)
            root._shutterPendingFiles--
        root._lastFileAt = Date.now()
        photoFlash.restart()
        console.log("CaptureScreen: [" + (root.freeCaptureUntilTimeout ? "FREE" : "REMOTE") + "] photo",
                    root.capturedCount, "->", fp)
    }

    function _submitCapture(noAf) {
        if (root.currentPhotoIndex >= root.totalPhotos)
            return
        if (root._captureInFlight)
            return

        root.capturingIndex = root.currentPhotoIndex
        root._captureInFlight = true
        var ok = noAf ? cameraController.takePictureNoAF() : cameraController.takePicture()
        if (!ok) {
            root._captureInFlight = false
            cameraController.stopSlotRecording()
            root._handleCaptureFailure(noAf ? "Không gửi được lệnh chụp No-AF" : "Không gửi được lệnh chụp")
        }
    }

    function _handleCaptureFailure(msg) {
        root._captureInFlight = false
        var targetIdx = root.capturingIndex
        if (targetIdx < 0 || targetIdx >= sessionPhotos.count)
            return
        if (sessionPhotos.get(targetIdx).captured)
            return
        if (captureRetryTimer.running)
            return

        // Không có máy ảnh (chế �'�T mock): l�?nh chụp ch�? thất bại TẠM TH�oI khi camera
        // �'ang trong lúc watchdog thử kết n�'i lại (m_isConnecting). Mock luôn tạo �'ược
        // ảnh ngay khi qua khoảng �'ó, nên KH�"NG bao giờ bỏ cu�Tc �?" cứ thử lại �'�f chắc
        // chắn luôn ra ảnh, và không hi�?n thông báo "l�-i lấy nét".
        if (!cameraController.isConnected) {
            if (!cameraDisconnectDeadline.running)
                cameraDisconnectDeadline.restart()
            root._captureRetryCount = 0
            root._captureFallbackNoAf = false
            root._captureRetryMessage = ""
            captureRetryTimer.restart()
            return
        }

        if (cameraDisconnectDeadline.running) cameraDisconnectDeadline.stop()

        if (root._captureRetryCount < root._captureMaxAfRetries) {
            root._captureRetryCount++
            root._captureFallbackNoAf = false
            root._captureRetryMessage = "Lỗi lấy nét, đang chụp lại lần " + root._captureRetryCount + "/" + root._captureMaxAfRetries
            console.warn("CaptureScreen:", root._captureRetryMessage, "-", msg)
            captureRetryTimer.restart()
            return
        }

        if (!root._captureFallbackNoAf && cameraController.afEnabled) {
            root._captureFallbackNoAf = true
            root._captureRetryMessage = "Lấy nét thất bại, thử chụp không AF để không kẹt phiên"
            console.warn("CaptureScreen:", root._captureRetryMessage, "-", msg)
            captureRetryTimer.restart()
            return
        }

        root._captureFallbackNoAf = false
        root._captureRetryMessage = "Chụp ảnh thất bại. Vui lòng chọn chụp lại khi camera sẵn sàng."
        console.error("CaptureScreen: Capture failed after retries:", msg)
        root.capturingIndex = -1
        // Never loop shutter commands forever. If this was a retake, restore
        // the original photo so a failed attempt cannot erase it.
        root._restorePrevPhotoIfRetaking()
        root._setTerminalCameraError("CAPTURE_COMMAND_FAILED", msg)
    }

    function _setTerminalCameraError(code, message) {
        if (captureRetryTimer.running) captureRetryTimer.stop()
        if (cameraDisconnectDeadline.running) cameraDisconnectDeadline.stop()
        if (imageDownloadDeadline.running) imageDownloadDeadline.stop()
        root._captureInFlight = false
        root.capturingIndex = -1
        root._captureTerminalError = true
        root._terminalErrorCode = code
        root._captureRetryMessage = message
        sessionManager.failCapture(root.sessionId, code, message, root.capturedCount)
        cameraController.stopSlotRecording()
    }

    function retryAfterCameraError() {
        root._captureTerminalError = false
        root._terminalErrorCode = ""
        root._captureRetryMessage = ""
        sessionManager.retryCapture(root.sessionId)
        var nextIdx = root._firstUncapturedIndex()
        if (nextIdx < 0) nextIdx = Math.min(root.currentPhotoIndex, root.totalPhotos - 1)
        root.currentPhotoIndex = Math.max(0, nextIdx)
        root.startCountdownSequence()
    }

    // Single-photo retake: only retakes the selected photo, then resumes
    function retakePhoto(index) {
        // Mode3 chup tu do: thumbnail chi de xem, khong chup lai.
        if (root.freeCaptureUntilTimeout)
            return
        if (index < 0 || index >= sessionPhotos.count || !sessionPhotos.get(index).captured)
            return
        if (root.isRetaking) {
            console.warn("CaptureScreen: Retake already active for index", root.retakeIndex,
                         "- ignoring request for", index)
            return
        }
        if (root._captureInFlight) {
            console.warn("CaptureScreen: Camera is still capturing - retake request ignored")
            return
        }
        console.log("CaptureScreen: Retaking SINGLE photo at index", index)

        // If currently counting down or capturing, interrupt it
        if (isCountingDown) {
            console.log("CaptureScreen: Interrupting current countdown to retake")
            countdownTimer.stop()
            isCountingDown = false
        }
        if (nextShotTimer.running) {
            nextShotTimer.stop()
        }
        if (captureRetryTimer.running) {
            captureRetryTimer.stop()
        }
        root._captureRetryCount = 0
        root._captureFallbackNoAf = false
        root._captureRetryMessage = ""

        // A retake is an isolated one-photo operation. Never resume an older
        // countdown automatically after it finishes.
        // Lưu lại ảnh hi�?n tại TRƯ�sC khi xoá �?" fallback nếu phiên kết thúc giữa
        // lúc chụp lại mà ảnh m�>i chưa k�<p về.
        var _prev = sessionPhotos.get(index)
        root._retakeHasBackup      = _prev.captured && (((_prev.realPath && _prev.realPath !== "")
                                                        || (_prev.path && _prev.path !== "")) ? true : false)
        root._retakeBackupIndex    = index
        root._retakeBackupPath     = _prev.path || ""
        root._retakeBackupRealPath = (_prev.realPath && _prev.realPath !== "") ? _prev.realPath : (_prev.path || "")
        if (root._retakeHasBackup && root._retakeBackupRealPath !== "")
            root.retakeDiscardedPhoto(root._retakeBackupRealPath)

        // Reset the specific photo
        sessionPhotos.setProperty(index, "path", "")
        sessionPhotos.setProperty(index, "realPath", "")
        if (sessionPhotos.get(index).captured) root.capturedCount--
        sessionPhotos.setProperty(index, "captured", false)

        // Set retake state
        isRetaking = true
        retakeIndex = index
        currentPhotoIndex = index
        root._pendingCompletion = false  // reset vì �'ang chụp lại, không còn pending

        startCountdownSequence()
    }

    // Khôi phục ảnh cũ nếu �'ang chụp lại mà ảnh m�>i CHƯA chụp (vd: hết giờ phiên).
    // Trả về true nếu �'ã �'ưa ảnh cũ tr�Y lại slot.
    function _restorePrevPhotoIfRetaking() {
        if (!root.isRetaking) return false
        var idx = root.retakeIndex
        if (idx < 0 || idx >= sessionPhotos.count) return false
        // Ảnh m�>i �'ã chụp (�'ang tải file về) �?' �'�f yên, ảnh m�>i sẽ về qua onImageCaptured.
        if (sessionPhotos.get(idx).captured) return false
        // Không có ảnh cũ �'�f khôi phục (slot v�'n tr�'ng) �?' bỏ qua.
        if (!root._retakeHasBackup || root._retakeBackupIndex !== idx) return false

        console.log("CaptureScreen: Phiên kết thúc giữa lúc chụp lại - khôi phục ảnh cũ ở slot", idx)
        // Dừng �'ếm ngược / ghi hình của lần chụp lại �'ang d�Y.
        if (root.isCountingDown) { countdownTimer.stop(); root.isCountingDown = false }
        if (nextShotTimer.running) nextShotTimer.stop()
        if (captureRetryTimer.running) captureRetryTimer.stop()
        cameraController.stopSlotRecording()

        sessionPhotos.setProperty(idx, "path", root._retakeBackupPath)
        sessionPhotos.setProperty(idx, "realPath", root._retakeBackupRealPath)
        sessionPhotos.setProperty(idx, "captured", true)
        root.capturedCount++

        root.isRetaking = false
        root.retakeIndex = -1
        root._retakeHasBackup = false
        root._retakeBackupIndex = -1
        root._captureRetryMessage = ""
        return true
    }


    // Real Camera Signal Connection
    Connections {
        target: cameraController

        // 1. Shutter confirmed �?" start next shot immediately, don't wait for file
        function onCaptureCompleted() {
            if (root._appendsPhotos) {
                // Chụp tự do / remote: máy đã chụp (lệnh từ app hoặc nút trên máy / remote),
                // file về sau ở onImageCaptured. Đếm lại để hết giờ thì chờ đủ ảnh này.
                if (!root.isProcessing && !root._captureClosed)
                    root._shutterPendingFiles++
                root._captureInFlight = false
                if (captureRetryTimer.running) captureRetryTimer.stop()
                return
            }
            var targetIdx = root.capturingIndex
            if (targetIdx < 0) return
            root._captureInFlight = false
            root.capturingIndex = -1

            // Some camera SDKs can emit duplicate completion callbacks. Do not
            // count or enqueue the same slot twice.
            if (targetIdx >= sessionPhotos.count || sessionPhotos.get(targetIdx).captured) {
                console.warn("CaptureScreen: Ignoring duplicate completion for index", targetIdx)
                return
            }

            if (captureRetryTimer.running)
                captureRetryTimer.stop()
            root._captureRetryCount = 0
            root._captureFallbackNoAf = false
            root._captureRetryMessage = ""

            console.log("CaptureScreen: Capture confirmed for index " + targetIdx)
            cameraController.stopSlotRecording()
            sessionPhotos.setProperty(targetIdx, "captured", true)
            root.capturedCount++
            sessionManager.updateCaptureProgress(root.sessionId, root.capturedCount)
            imageDownloadDeadline.restart()

            // Enqueue index so onImageCaptured can find the right slot (FIFO)
            var q = root._downloadQueue.slice()
            q.push(targetIdx)
            root._downloadQueue = q

            if (!root.isRetaking) {
                // Advance immediately �?" file download happens in background
                if (targetIdx < root.totalPhotos - 1) {
                    nextShotTimer.start()   // nextShotTimer does currentPhotoIndex++ internally
                } else {
                    currentPhotoIndex++     // last photo: mark session done
                    // No-retake: chụp �'ủ ảnh �?' tự chuy�fn bư�>c tiếp theo (không chờ user).
                    // handleCaptureSessionCompletion tự xử lý chờ file nếu chưa về.
                    if (root.noRetakeMode)
                        root.handleCaptureSessionCompletion()
                }
            }
            // Retake: onImageCaptured handles resume after file arrives
        }

        // 2. File arrived async �?" update thumbnail, resume pending completion
        function onImageCaptured(path) {
            // Free mode (mode3): anh tu lenh app (chuot/Space) hay remote gan may deu
            // append vao cuoi -> khong phu thuoc thu tu slot. Da ket thuc thi bo qua.
            //    Remote: khách bấm nút vật lý → ảnh mới về. Cả hai append vào cuối danh sách.
            if (root._appendsPhotos) {
                if (root.isProcessing || root._captureClosed) {
                    // Đã kết thúc chụp: EventManager nhận ảnh này (khung ảnh trễ) và đưa lên web.
                    console.log("CaptureScreen: photo after capture ended -> late window:", path)
                    return
                }
                root._appendCapturedPhoto(path)
                if (root.freeCaptureUntilTimeout) {
                    root._captureInFlight = false
                    root._awaitingFreeFile = false
                    if (imageDownloadDeadline.running) imageDownloadDeadline.stop()
                    if (root._reviewActive) {
                        root._reviewPath = "file:///" + path.replace(/\\/g, "/")
                        reviewHideTimer.restart()
                    }
                }
                if (root._finishing)
                    root._tryCompleteAppendFinish()
                return
            }
            if (root._downloadQueue.length === 0) {
                console.warn("CaptureScreen: onImageCaptured fired but download queue is empty")
                return
            }
            // Pop the oldest pending slot (FIFO matches SDK download order)
            var q = root._downloadQueue.slice()
            var targetIdx = q.shift()
            root._downloadQueue = q
            if (root._downloadQueue.length === 0 && imageDownloadDeadline.running)
                imageDownloadDeadline.stop()

            console.log("CaptureScreen: File for index " + targetIdx + " saved at " + path)
            var urlPath = "file:///" + path.replace(/\\/g, "/")
            sessionPhotos.setProperty(targetIdx, "path", urlPath)
            sessionPhotos.setProperty(targetIdx, "realPath", urlPath)
            root._setExternalPhoto(targetIdx, urlPath)
            root._queueCapturedAsset(targetIdx, urlPath)
            root.photoReady(urlPath, targetIdx + 1)

            // Ảnh �'ang review vừa có file �?' �'�.i từ "�'ang xử lý" sang ảnh thật.
            if (root._reviewActive && targetIdx === root._reviewIndex)
                root._reviewPath = urlPath

            // User pressed "Tiếp Tục" before all files arrived �?" resume now if ready
            if (root._pendingCompletion && root._allCapturedPhotosReady()) {
                console.log("CaptureScreen: All files ready - resuming pending completion")
                root.handleCaptureSessionCompletion()
                return
            }

            // Retake: resume capture sequence after file arrives
            if (root.isRetaking && targetIdx === root.retakeIndex) {
                console.log("CaptureScreen: Retake completed for index", targetIdx)
                root.isRetaking = false
                root.retakeIndex = -1
                root._retakeHasBackup = false
                root._retakeBackupIndex = -1
                root.lastRetakenIndex = targetIdx
                retakeHighlightTimer.restart()

                // Nếu vẫn còn ảnh CHƯA chụp (khách chụp lại xen giữa lúc �'ang chụp
                // d�Y �?" vd chụp lại ảnh 1 khi ảnh 2 chưa chụp) �?' tiếp tục tự �'�Tng chụp
                // các ảnh còn thiếu. Ảnh vừa chụp lại �'ã �'ược �'ánh dấu captured �Y
                // onCaptureCompleted nên hàm ch�? tìm ảnh thực sự còn thiếu.
                // Nếu �'ã �'ủ ảnh �?' dừng sau �'úng m�Tt ảnh chụp lại (khách tự bấm
                // thumbnail khác nếu mu�'n chụp lại tiếp).
                var nextIdx = root._firstUncapturedIndex()
                if (nextIdx >= 0) {
                    root.currentPhotoIndex = nextIdx
                    root.startCountdownSequence()
                } else {
                    root.currentPhotoIndex = root.totalPhotos
                }
            }
        }

        function onError(msg) {
            if (root.virtualCaptureMode && !cameraController.isConnected) {
                console.warn("CaptureScreen: Ignoring camera error while test capture is enabled:", msg)
                return
            }
            console.error("CaptureScreen Error: " + msg)
            if (root.freeCaptureUntilTimeout) {
                // Free mode: khong retry / khong khoa phien, khach bam lai la chup.
                if (root._awaitingFreeFile || root._captureInFlight)
                    root._freeShotFailed("Chụp chưa được, vui lòng bấm lại")
                return
            }
            root._captureInFlight = false
            root._handleCaptureFailure(msg)
        }
    }

    // Nhận kết quả collage async (Auto mode). Ch�? xử lý khi �'ang chờ
    // (_pendingAutoCollage) �?" tránh phản ứng v�>i collageReady của màn khác.
    Connections {
        target: eventManager
        function onCollageReady(collagePath) {
            if (!root._pendingAutoCollage) return
            root._pendingAutoCollage = false
            root.isProcessing = false
            console.log("CaptureScreen: Async collage ready:", collagePath)
            root.sessionFinished(root._autoResultPhotos, collagePath)
            root._autoResultPhotos = []
        }
    }

    function _stopFreeCaptureTimers() {
        sessionCountdownTimer.stop()
        nextShotTimer.stop()
        captureRetryTimer.stop()
        if (root.isCountingDown) {
            countdownTimer.stop()
            root.isCountingDown = false
        }
    }

    function _allCapturedPhotosReady() {
        for (var i = 0; i < sessionPhotos.count; i++) {
            var p = sessionPhotos.get(i)
            if (p.captured && (!p.realPath || p.realPath === ""))
                return false
        }
        return true
    }

    // Ch�? s�' ảnh ĐẦU TI�SN chưa chụp (-1 = �'ã chụp �'ủ tất cả).
    function _firstUncapturedIndex() {
        for (var i = 0; i < sessionPhotos.count; i++) {
            if (!sessionPhotos.get(i).captured)
                return i
        }
        return -1
    }

    function handleCaptureSessionCompletion() {
        // Free mode: bam Xong khi anh vua chup chua ve -> cho anh do roi moi ket thuc.
        if (root.freeCaptureUntilTimeout && (root._awaitingFreeFile || root._captureInFlight)) {
            root._stopFreeCaptureTimers()
            root._pendingCompletion = true
            return
        }
        // Stop all timers before proceeding
        sessionCountdownTimer.stop()
        root._endReview()
        if (root.isCountingDown) {
            countdownTimer.stop()
            root.isCountingDown = false
        }
        cameraController.stopSlotRecording()
        if (nextShotTimer.running) {
            nextShotTimer.stop()
        }
        if (captureRetryTimer.running) {
            captureRetryTimer.stop()
        }
        root._captureRetryMessage = ""

        // Đang chụp lại mà ảnh m�>i chưa chụp xong �?' dùng lại ảnh cũ, tránh mất ảnh.
        root._restorePrevPhotoIfRetaking()

        // Nếu có ảnh �'ã captured nhưng file chưa �'ược camera ghi xong (realPath r�-ng),
        // �'ánh dấu pending và chờ onImageCaptured fire �'ủ hết r�"i m�>i proceed.
        if (!_allCapturedPhotosReady()) {
            console.log("CaptureScreen: Some photos captured but file not yet saved - waiting for onImageCaptured...")
            root._pendingCompletion = true
            root.isProcessing = true
            return
        }

        root._pendingCompletion = false
        root.isProcessing = true
        // Từ đây ảnh về thêm do khung ảnh trễ của EventManager nhận (không có khe hở).
        if (root.capturedCount > 0)
            root._closeCapture()

        // Give UI a moment to show busy indicator
        Qt.callLater(function() {
            var result = []
            var pathsForCollage = []
            for (var i = 0; i < sessionPhotos.count; i++) {
                var photoItem = sessionPhotos.get(i)
                // Dùng realPath v�>i fallback sang path, tránh push empty string
                var realPath = photoItem.realPath || photoItem.path
                if (photoItem.captured && realPath && realPath !== "") {
                    result.push(realPath)
                    pathsForCollage.push(realPath)
                }
            }

            if (result.length === 0) {
                console.warn("CaptureScreen: No photos captured yet, cannot proceed")
                root.isProcessing = false
                return
            }

            console.log("CaptureScreen: Proceeding with", result.length, "of", root.totalPhotos, "photos")

            // Check Shooting Mode
            // Manual (1) and Template (2) both go through PhotoCompositionScreen.
            // Template mode pre-assigns photos to slots in order.
            if (root.forceManualPostFlow || (root.eventData && (root.eventData.shootingMode === 1 || root.eventData.shootingMode === 2))) {
                var modeLabel2 = root.forceManualPostFlow ? "Post-capture frame" : (root.eventData && root.eventData.shootingMode === 2 ? "Template" : "Manual")
                console.log("CaptureScreen:", modeLabel2, "mode - proceeding to composition")
                root.isProcessing = false;
                root.manualCaptureFinished(pathsForCollage);
            } else {
                console.log("CaptureScreen: Generating Final Collage (async)...")
                // ASYNC: ImageCompositor chạy trên background thread (QtConcurrent
                // bên trong processCollageWithTransformsAsync) �?' KH�"NG block UI.
                // Trư�>c �'ây processCollage() decode 6�-24MP + composite + save JPG
                // ngay trên UI thread �?' block 2-6s �?' Not Responding.
                // Kết quả trả về qua signal collageReady (xử lý �Y Connections bên dư�>i).
                root._autoResultPhotos   = result
                root._pendingAutoCollage = true
                root.isProcessing = true
                eventManager.processCollageWithTransformsAsync(
                    root.eventId, pathsForCollage, [], root.sessionId, true)
            }
        })
    }

    Timer {
        id: nextShotTimer
        interval: root.eventData ? root.eventData.shotInterval : 2000
        onTriggered: {
            currentPhotoIndex++
            startCountdownSequence()
        }
    }

    // -------------------------------------------------------------------------
    // UI Structure
    // -------------------------------------------------------------------------

    // �"?�"? Backdrop (nền trang) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Template: t�'i; chế �'�T thường: trắng (live view thu trong khung �?' vùng quanh
    // khung cần nền; thumbnail nằm trực tiếp trên nền trắng này).
    Rectangle {
        anchors.fill: parent
        color: root.isTemplateMode ? "#111214" : "#FFF8E7"
        z: 0
    }

    // Ảnh nền tùy chỉnh (nếu admin đã cài) �?" phủ toàn màn, hiện quanh live view & khung ảnh.
    BackgroundMedia {
        anchors.fill: parent
        z: 0
        visible: !root.isTemplateMode && root.captureBgImage !== ""
        sourcePath: root.captureBgImage
    }

    // 1. Live View �?" chế �'�T thường: khung bên trái, chừa ch�- c�Tt thumbnail dọc;
    //    template mode: confine trong slot �'ang chụp.
    //    Hidden in template mode once all photos are captured
    LiveViewPanel {
        id: liveViewPanel
        isActive: cameraController.isLiveViewActive
        // Ch�? tiêu thụ frame khi CaptureScreen là màn �'ang hi�fn th�< (cùng �'iều ki�?n
        // giữ live-view viewer). Khi b�< �'ẩy xu�'ng Composition/Result �?' ngừng update.
        // External mode: panel chính ẩn �?' không tiêu thụ (mock overlay tự tiêu thụ).
        consuming: root._lvViewerHeld
        z: 1
        // External mode: live view chính nhường ch�- cho photo wall (live view ra HDMI).
        visible: !root.isTemplateMode || root.currentPhotoIndex < root.totalPhotos
        // Remote: phủ TO�?N màn hình (không viền, không lề). Ưu tiên trư�>c mọi chế �'�T.
        x:      root.isTemplateMode ? root.tmSlotScreenX
                : root._captureLeftBand
        y:      root.isTemplateMode ? root.tmSlotScreenY : 0
        width:  root.isTemplateMode ? root.tmSlotScreenW
                : Math.max(1, parent.width - root._captureLeftBand - root._captureRightBand)
        height: root.isTemplateMode ? root.tmSlotScreenH
                : (root._centeredCaptureLayout ? parent.height : root._splitLiveViewH)

        // No-retake: live view �Y giữa, viền trắng bao quanh (imageMargins + nền trắng).
        // Chế �'�T thường: phủ kín khung (Crop). Template: nền �'en. Remote: phủ kín, không viền.
        fillMode:     (root.remoteMode || root._freeLayout) ? Image.PreserveAspectCrop
                : (root.noRetakeMode ? Image.PreserveAspectFit : Image.PreserveAspectCrop)
        imageMargins: (root.remoteMode || root._freeLayout || !root.noRetakeMode) ? 0 : 18
        color:        root.isTemplateMode ? "#000000"
                : (root.captureBgImage !== "" ? "transparent" : "#FFF8E7")
        border.color: root.remoteMode ? "transparent"
                : (root.isTemplateMode ? "#3a3d45"
                : (root.noRetakeMode ? "#e6e8ec" : "#d6d9e0"))
    }

    // 1a. Photo wall thay live view chính khi live view xuất ra HDMI (external mode).
    //     Dùng Đ�sNG vùng của LiveViewPanel �'�f không phá layout �'iều khi�fn.
    //     B�' cục: ảnh l�>n �Y GIỮA (ảnh m�>i chụp / ảnh vừa click) + filmstrip cu�Tn ngang
    //     bên DƯ�sI (thumbnail + s�' thứ tự, không viền/hi�?u ứng). Ch�? ảnh THẬT �'ã chụp.
    Rectangle {
        id: mainPhotoWall
        z: 1
        visible: !root.isTemplateMode && !root._centeredCaptureLayout
        x:      0
        y:      root._splitPhotoWallY
        width:  parent.width
        height: root._splitPhotoWallH
        color: "transparent"
        border.color: "transparent"
        border.width: 0

        // Ảnh lớn phủ kín nửa dưới để live view và ảnh chụp dính sát nhau, không lộ nền.
        Image {
            anchors.fill: parent
            anchors.margins: 0
            source: root._externalWallCenterPath
            visible: root._externalWallCenterPath !== ""
            fillMode: root._freeLayout ? Image.PreserveAspectCrop : Image.PreserveAspectFit
            cache: false
            asynchronous: true
            sourceSize: Qt.size(1280, 1280)
        }

        // Placeholder khi chưa có ảnh — hiển thị hướng dẫn ở giữa.
        Text {
            anchors.centerIn: parent
            verticalAlignment: Text.AlignVCenter
            visible: root._externalWallCenterPath === ""
            text: "Ảnh chụp sẽ hiển thị ở đây"
            color: "#8B5A2B"
            opacity: 0.55
            font.pixelSize: 24
            font.bold: true
        }

        // Mũi tên TRÁI �?" xem ảnh trư�>c �'ó.
        Rectangle {
            id: wallPrevArrow
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 72; height: 72; radius: 36
            visible: externalSessionPhotos.count > 1 && !root._freeLayout
            enabled: root._wallViewIndex > 0
            opacity: enabled ? 1.0 : 0.35
            color: wallPrevArea.containsMouse && enabled ? "#6f4522" : "#8B5A2B"
            border.color: "white"; border.width: 2
            z: 3
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "‹"
                color: "white"; font.pixelSize: 44; font.bold: true
            }
            MouseArea {
                id: wallPrevArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._wallShow(root._wallViewIndex - 1)
            }
        }

        // Mũi tên PHẢI �?" xem ảnh kế tiếp.
        Rectangle {
            id: wallNextArrow
            anchors.right: parent.right
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            width: 72; height: 72; radius: 36
            visible: externalSessionPhotos.count > 1 && !root._freeLayout
            enabled: root._wallViewIndex < externalSessionPhotos.count - 1
            opacity: enabled ? 1.0 : 0.35
            color: wallNextArea.containsMouse && enabled ? "#6f4522" : "#8B5A2B"
            border.color: "white"; border.width: 2
            z: 3
            Behavior on color { ColorAnimation { duration: 120 } }
            Text {
                anchors.centerIn: parent
                text: "›"
                color: "white"; font.pixelSize: 44; font.bold: true
            }
            MouseArea {
                id: wallNextArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._wallShow(root._wallViewIndex + 1)
            }
        }

        // Ch�? s�' v�< trí ảnh �'ang xem (vd "2 / 5") �?" pill nhỏ �Y �'áy giữa.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            visible: externalSessionPhotos.count > 0 && !root._freeLayout
            width: wallCounterText.implicitWidth + 28
            height: 34
            radius: 17
            color: "#CC111827"
            z: 3
            Text {
                id: wallCounterText
                anchors.centerIn: parent
                text: (root._wallViewIndex + 1) + " / " + externalSessionPhotos.count
                color: "#ffffff"
                font.pixelSize: 16
                font.bold: true
            }
        }
    }

    // Line màu nâu ngăn cách nửa trên (live view) và nửa dưới (photo wall).
    Rectangle {
        z: 2
        visible: !root.isTemplateMode && !root._centeredCaptureLayout
        x: 0
        y: root._splitPhotoWallY - height / 2
        width: parent.width
        height: 6
        color: "#8B5A2B"
    }

    // 1a-mock. Live view "HDMI" GIẢ LẬP cho mock test (máy 1 màn hình): overlay n�.i nhỏ
    //     ngay trong app, KH�"NG tạo cửa s�. OS riêng (tránh FATAL "no screens available").
    //     Không có camera thật thì ô này �'en �?" bình thường; phần chính cần ki�fm là photo wall.
    // Free mode (mode3): chuot trai bam bat ky dau = chup. z thap (tren nen, duoi moi
    // thanh phan khac) nen nut / thumbnail / overlay co MouseArea rieng van nhan truoc.
    MouseArea {
        id: freeShotMouseArea
        anchors.fill: parent
        z: 0.5
        enabled: root.freeCaptureUntilTimeout
        acceptedButtons: Qt.LeftButton
        onPressed: root._requestFreeShot("mouse")
    }

    // Free mode: Space = chup. Shortcut khong phu thuoc focus (nut da bam khong nuot
    // phim); chi bat khi man nay dang o dinh StackView; giu phim khong bam lien tuc.
    Shortcut {
        sequence: "Space"
        context: Qt.WindowShortcut
        autoRepeat: false
        enabled: root.freeCaptureUntilTimeout && root.StackView.status === StackView.Active
        onActivated: root._requestFreeShot("space")
    }

    Timer {
        id: freeShotNoticeTimer
        interval: 2500
        onTriggered: root._freeShotNotice = ""
    }

    // Free mode: thong bao loi chup ngan (tu an) o day nua live view.
    Rectangle {
        z: 15
        visible: root.freeCaptureUntilTimeout && !root.isProcessing && root._freeShotNotice !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        y: root._splitLiveViewH - height - 24
        width: freeShotHint.implicitWidth + 44
        height: 52
        radius: 26
        color: Qt.rgba(0.75, 0.22, 0.17, 0.85)

        Text {
            id: freeShotHint
            anchors.centerIn: parent
            text: root._freeShotNotice
            color: "#ffffff"; font.pixelSize: 20; font.bold: true
        }
    }

    // Mode3: timer và nút hoàn thành nổi gọn ở góc, không phủ thanh mờ ngang live view.
    Item {
        id: freeTimeBand
        z: 12
        visible: root._freeLayout
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 78

        Rectangle {
            id: freeTimerPill
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 14
            height: 48
            width: freeTimeText.implicitWidth + 32
            radius: 24
            color: "#E6FFF8E7"
            border.color: "#A68B5A2B"
            border.width: 1

            // Chặn chạm đúng vùng pill để không kích hoạt chụp.
            MouseArea { anchors.fill: parent }

            Text {
                id: freeTimeText
                anchors.centerIn: parent
                text: {
                    var s = Math.max(0, root.sessionRemainingTime)
                    var m = Math.floor(s / 60)
                    var ss = s % 60
                    return (m < 10 ? "0" + m : m) + ":" + (ss < 10 ? "0" + ss : ss)
                }
                color: root.sessionRemainingTime <= 15 ? "#B42318" : "#5F3A1C"
                font.pixelSize: 24
                font.bold: true
            }
        }

        Rectangle {
            id: freeDoneBtn
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.topMargin: 12
            height: 52
            width: Math.max(148, freeDoneText.implicitWidth + 42)
            radius: 26
            enabled: !root.isProcessing && !root._finishing
            opacity: enabled ? 1.0 : 0.55
            color: !enabled ? "#D6CAB8"
                  : freeDoneArea.pressed ? "#6F4522"
                  : freeDoneArea.containsMouse ? "#9A6230"
                  : "#8B5A2B"
            border.color: "#F8EFE2"; border.width: 2
            Behavior on color { ColorAnimation { duration: 120 } }
            scale: freeDoneArea.pressed ? 0.97 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }

            Text {
                id: freeDoneText
                anchors.centerIn: parent
                text: root._finishing ? "Đang nhận ảnh..." : "Hoàn thành"
                color: "#ffffff"; font.pixelSize: 20; font.bold: true
            }
            MouseArea {
                id: freeDoneArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: freeDoneBtn.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: root._onFreeDoneClicked()
            }
        }
    }

    // Mode3: film strip thumbnail dưới cùng; bấm thumbnail → xem ảnh ở nửa dưới.
    Rectangle {
        id: freeFilmStrip
        z: 10
        visible: root._freeLayout
        x: 0
        y: parent.height - height
        width: parent.width
        height: root._filmStripH
        color: "transparent"

        // Chặn chạm vùng trống của strip để không kích hoạt chụp.
        MouseArea { anchors.fill: parent }

        ListView {
            id: filmStripList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            anchors.bottomMargin: 8
            height: parent.height - 12
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: externalSessionPhotos
            onCountChanged: positionViewAtEnd()

            Connections {
                target: root
                function on_WallViewIndexChanged() {
                    if (root._wallViewIndex >= 0)
                        filmStripList.positionViewAtIndex(root._wallViewIndex, ListView.Contain)
                }
            }

            delegate: Item {
                width: Math.round(filmStripList.height * 1.55)
                height: filmStripList.height

                Image {
                    anchors.fill: parent
                    source: model.path
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    sourceSize: Qt.size(340, 230)
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 4
                    width: stripIndexText.implicitWidth + 10
                    height: 20
                    radius: 5
                    color: "#B8111827"
                    Text {
                        id: stripIndexText
                        anchors.centerIn: parent
                        text: index + 1
                        color: "#ffffff"; font.pixelSize: 11; font.bold: true
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: index === root._wallViewIndex
                    border.width: 3
                    border.color: "#2F80ED"
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._wallShow(index)
                }
            }
        }
    }

    Rectangle {
        id: mockLiveViewOverlay
        z: 60
        visible: root.externalLiveViewMode && root._mockLiveViewOverlay
        width:  420
        height: 264
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin:  24
        anchors.bottomMargin: 24
        color: "#000000"
        border.color: "#f59e0b"
        border.width: 2

        LiveViewPanel {
            anchors.fill: parent
            anchors.margins: 2
            isActive: cameraController.isLiveViewActive
            consuming: mockLiveViewOverlay.visible
            fillMode: Image.PreserveAspectCrop
            imageMargins: 0
            panelRadius: 0
            panelBorderWidth: 0
            color: "#000000"
            border.color: "transparent"
        }

        // Badge phân bi�?t �'ây là live view mock.
        Rectangle {
            anchors.top:  parent.top
            anchors.left: parent.left
            anchors.margins: 6
            width:  mockOverlayBadge.implicitWidth + 14
            height: mockOverlayBadge.implicitHeight + 8
            radius: 5
            color: "#CCf59e0b"
            Text {
                id: mockOverlayBadge
                anchors.centerIn: parent
                text: "MOCK HDMI"
                color: "#1a1200"
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    // 1c. (Đã gỡ HUD thông s�' máy ảnh �?" shutter/aperture/ISO/AF không còn hi�fn th�<.)

    property bool _paymentEnabled: eventManager.getAppSetting("payment_enabled", "false") === "true"

    // Nút "Kết thúc" �?" góc trên bên TRÁI, bo viền nâu, bấm �?' về ModeSelection.
    Rectangle {
        id: endButton
        visible: root.showCloseButton && root._endCaptureButtonVisible
        anchors.left: parent.left
        anchors.top:  parent.top
        anchors.leftMargin: 20
        anchors.topMargin:  20
        height: 54
        width: endBtnText.implicitWidth + 44
        radius: 27
        color: endCaptureArea.containsMouse ? "#F3E9DE" : "transparent"
        border.color: "#8B5A2B"; border.width: 2
        z: 12
        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            id: endBtnText
            anchors.centerIn: parent
            text: "Kết thúc"
            color: "#8B5A2B"; font.pixelSize: 22; font.bold: true
        }
        MouseArea {
            id: endCaptureArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                sessionManager.cancelCapture(root.sessionId, "Khách hủy lượt chụp")
                root.closeClicked()
            }
        }
    }

    // Thanh tiến trình thời gian G�"I CHỤP �?" ngang trên cùng, fill nâu chạy ngược về
    // hết = hết giờ; text "Thời gian còn lại: mm:ss" �Y giữa thanh.
    Rectangle {
        id: sessionProgressBar
        z: 11
        visible: root._effectiveSessionTimeLimit > 0 && !root._freeLayout
        anchors.top: parent.top
        anchors.topMargin: 20
        anchors.right: parent.right
        anchors.rightMargin: 28
        width: Math.max(144, sessionSecondsText.implicitWidth + 64)
        height: 80
        radius: 40
        color: root.sessionRemainingTime <= 15 ? "#C0392B" : "#8B5A2B"
        border.color: "#ffffff"; border.width: 2
        clip: false
        Behavior on color { ColorAnimation { duration: 300 } }

        // Fill nâu �?" bề r�Tng theo tỉ l�? thời gian còn lại; hết = hết giờ.
        Rectangle {
            id: sessionProgressFill
            visible: false
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * Math.max(0, Math.min(1,
                       root._effectiveSessionTimeLimit > 0 ? root.sessionRemainingTime / root._effectiveSessionTimeLimit : 0))
            radius: parent.radius
            color: root.sessionRemainingTime <= 15 ? "#C0392B" : "#8B5A2B"
            Behavior on width { NumberAnimation { duration: 950; easing.type: Easing.Linear } }
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Text thời gian còn lại �Y giữa thanh (viền t�'i �'�f �'ọc rõ trên cả nền nâu & nền sáng).
        Text {
            visible: false
            anchors.centerIn: parent
            z: 1
            text: {
                var s = Math.max(0, root.sessionRemainingTime)
                var m = Math.floor(s / 60)
                var ss = s % 60
                return "Thời gian còn lại: " + (m < 10 ? "0" + m : m) + ":" + (ss < 10 ? "0" + ss : ss)
            }
            color: "#ffffff"
            font.pixelSize: 24
            font.bold: true
            style: Text.Outline; styleColor: "#66000000"
        }

        Text {
            id: sessionSecondsText
            anchors.centerIn: parent
            text: Math.max(0, root.sessionRemainingTime)
            color: "#ffffff"
            font.pixelSize: 45
            font.bold: true
        }
    }

    // 1b. Pose Guide Overlay �?" vùng t�'i chính xác theo từng slot.
    //     Bám theo khung live view (không full màn) vì live view �'ã thu vào khung trái.
    Rectangle {
        anchors.fill: parent
        visible: root._captureTerminalError
        color: "#dd0b1220"
        z: 100
        MouseArea { anchors.fill: parent }
        Rectangle {
            anchors.centerIn: parent
            width: 620; height: 300; radius: 24
            color: "#171b24"; border.color: "#ef4444"; border.width: 2
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 32; spacing: 18
                Text { text: "Lỗi máy ảnh"; color: "#f87171"; font.pixelSize: 30; font.bold: true; Layout.alignment: Qt.AlignHCenter }
                Text { text: root._captureRetryMessage; color: "white"; font.pixelSize: 18; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true }
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter; spacing: 18
                    Button { text: "Thử lại"; onClicked: root.retryAfterCameraError() }
                    Button { visible: root.showCloseButton && root._endCaptureButtonVisible; text: "Kết thúc lượt"; onClicked: root.closeClicked() }
                }
            }
        }
    }

    Canvas {
        id: poseCanvas
        x: liveViewPanel.x
        y: liveViewPanel.y
        width:  liveViewPanel.width
        height: liveViewPanel.height
        z: 5
        visible: root.poseGuideActive && !root.isTemplateMode && !root.externalLiveViewMode
                 && root.poseSlots.length > 0

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            if (!root.poseGuideActive || root.poseSlots.length === 0) return
            if (root.currentPhotoIndex < 0) return

            // Clamp to last available slot so the overlay covers ALL photos
            // in the session, even when totalPhotos > number of slots in layout
            var slot = root.poseSlots[Math.min(root.currentPhotoIndex, root.poseSlots.length - 1)]

            // Fit slot aspect ratio to screen (CONTAIN) �?" bright window = slot area
            var slotAspect   = slot.w / slot.h
            var screenAspect = width / height
            var sx, sy, sw, sh
            if (slotAspect > screenAspect) {
                sw = width;          sh = width / slotAspect
                sx = 0;              sy = (height - sh) / 2
            } else {
                sh = height;         sw = height * slotAspect
                sx = (width - sw) / 2; sy = 0
            }

            // Dark vignette outside the slot area �?" no border, no decorations
            ctx.fillStyle = "rgba(0, 0, 0, 0.65)"
            if (sy > 0) {
                ctx.fillRect(0, 0,       width, sy)
                ctx.fillRect(0, sy + sh, width, sy)
            }
            if (sx > 0) {
                ctx.fillRect(0,       0, sx, height)
                ctx.fillRect(sx + sw, 0, sx, height)
            }
        }

        // Trigger repaint when slot or canvas size changes
        function _repaint() { if (visible) requestPaint() }

        Connections {
            target: root
            function onCurrentPhotoIndexChanged() { poseCanvas._repaint() }
            function onPoseSlotsChanged()         { poseCanvas._repaint() }
            function onPoseGuideActiveChanged()   { poseCanvas._repaint() }
        }
        onWidthChanged:  Qt.callLater(poseCanvas._repaint)
        onHeightChanged: Qt.callLater(poseCanvas._repaint)
    }

    // �"?�"? Template Mode: Captured photos rendered inside each slot (z:3)
    // Sits below the frame PNG (z:4) and shows through its transparent cutouts.
    Repeater {
        model: root.isTemplateMode ? root.tmSlots.length : 0

        delegate: Item {
            z: 3
            x:      root.tmAllSlotRects.length > index ? root.tmAllSlotRects[index].x : 0
            y:      root.tmAllSlotRects.length > index ? root.tmAllSlotRects[index].y : 0
            width:  root.tmAllSlotRects.length > index ? root.tmAllSlotRects[index].w : 0
            height: root.tmAllSlotRects.length > index ? root.tmAllSlotRects[index].h : 0
            visible: index < sessionPhotos.count && sessionPhotos.get(index).captured

            // Captured photo
            Image {
                anchors.fill: parent
                source: index < sessionPhotos.count ? (sessionPhotos.get(index).path || "") : ""
                fillMode: Image.PreserveAspectCrop
                cache: false
                clip: true
                asynchronous: true
                sourceSize: Qt.size(600, 600)
            }

            // "�o" M�>i" retake badge (top-left, matches thumbnail strip badge)
            Rectangle {
                anchors.top:    parent.top
                anchors.left:   parent.left
                anchors.margins: 6
                width:  tmSlotNewBadge.implicitWidth + 14
                height: 26
                radius: 6
                color:   "#4caf50"
                visible: index === root.lastRetakenIndex
                z: 1

                opacity: 1.0
                SequentialAnimation on opacity {
                    running: index === root.lastRetakenIndex
                    PauseAnimation  { duration: 3000 }
                    NumberAnimation { to: 0; duration: 800; easing.type: Easing.InQuad }
                }

                Text {
                    id: tmSlotNewBadge
                    anchors.centerIn: parent
                    text: "✓ Mới"
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            // Click �?' open fullscreen preview (same as thumbnail click)
            MouseArea {
                anchors.fill: parent
                enabled: !root.isRetaking && !root._captureInFlight
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (index < sessionPhotos.count && sessionPhotos.get(index).captured) {
                        previewOverlay.previewSource      = sessionPhotos.get(index).path
                        previewOverlay.previewTargetIndex = index
                        previewOverlay.visible            = true
                    }
                }
            }
        }
    }

    // �"?�"? Template Mode: Frame overlay �?" layout PNG covers full screen (z:4)
    // The PNG has transparent slot areas, so the live view shows through them.
    Image {
        id: tmFrameImage
        anchors.fill: parent
        z: 4
        visible: root.isTemplateMode && root.tmLayoutFileUrl !== ""
        source: root.tmLayoutFileUrl
        fillMode: Image.PreserveAspectFit
        opacity: 1.0
        sourceSize: Qt.size(parent.width, parent.height)
        onStatusChanged: {
            if (status === Image.Error) { console.error("[TemplateMode] Frame load failed:", root.tmLayoutFileUrl) }
            else if (status === Image.Ready) { console.log("[TemplateMode] Frame loaded OK:", root.tmLayoutFileUrl) }
        }
    }

    // �"?�"? Template Mode: Highlight border around the active slot (z:6) �"?�"?�"?�"?�"?�"?�"?�"?�"?
    Rectangle {
        id: tmSlotHighlight
        x: root.tmSlotScreenX
        y: root.tmSlotScreenY
        width:  root.tmSlotScreenW
        height: root.tmSlotScreenH
        z: 6
        visible: root.isTemplateMode && root.tmSlots.length > 0 && root.currentPhotoIndex < root.totalPhotos
        color: "transparent"
        border.color: "#00e5ff"
        border.width: 3
        radius: 4

        Behavior on x      { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on y      { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on width  { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

        // Pulse border width while counting down
        SequentialAnimation on border.width {
            running: root.isTemplateMode && root.isCountingDown
            loops: Animation.Infinite
            NumberAnimation { to: 5; duration: 400 }
            NumberAnimation { to: 3; duration: 400 }
        }

        // Slot badge: "1 / 3" at top-right corner of the slot
        Rectangle {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 0
            width: slotBadgeText.implicitWidth + 14
            height: 24
            radius: 4
            color: "#00e5ff"
            Text {
                id: slotBadgeText
                anchors.centerIn: parent
                text: (root.currentPhotoIndex + 1) + " / " + root.totalPhotos
                color: "#000000"
                font.pixelSize: 12
                font.bold: true
            }
        }
    }

    // �"?�"? Template Mode: recompute slot rect when index or screen size changes �"?�"?
    Connections {
        target: root
        function onCurrentPhotoIndexChanged() { root.updateTmSlotRect() }
        function onTmSlotsChanged()           { root.updateTmSlotRect() }
        function onWidthChanged()             { Qt.callLater(root.updateTmSlotRect) }
        function onHeightChanged()            { Qt.callLater(root.updateTmSlotRect) }
    }

    // �"?�"? Photo Review Overlay �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
    // Che live view trong khoảng camera Device_Busy (Nikon): hi�?n "�'ang xử lý"
    // ngay khi bấm máy, r�"i ảnh vừa chụp khi file về. Tự ẩn khi countdown ảnh kế
    // tiếp bắt �'ầu (hoặc sau reviewHideTimer cho ảnh cu�'i).
    Rectangle {
        id: reviewOverlay
        anchors.fill: parent
        color: "#0b0d11"
        visible: root._reviewActive
        z: 80

        // Ảnh vừa chụp (khi �'ã có file)
        Image {
            anchors.fill: parent
            anchors.margins: 24
            source: root._reviewPath
            visible: root._reviewPath !== ""
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: true
            sourceSize: Qt.size(1280, 960)
        }

        // Trạng thái "�'ang xử lý" trong lúc chờ file (chính là lúc live view �'ứng)
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 18
            visible: root._reviewPath === ""
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: reviewOverlay.visible && root._reviewPath === ""
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Đang xử lý ảnh..."
                color: "white"
                font.pixelSize: 26
                font.bold: true
            }
        }

        // Nhãn s�' thứ tự ảnh (góc trên trái)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 24
            width: reviewBadge.implicitWidth + 24
            height: 40
            radius: 20
            color: "#CC1e7eea"
            visible: root._reviewIndex >= 0
            Text {
                id: reviewBadge
                anchors.centerIn: parent
                text: "Ảnh " + (root._reviewIndex + 1) + " / " + root.totalPhotos
                color: "white"
                font.pixelSize: 18
                font.bold: true
            }
        }
    }

    // Processing Overlay (Only shown during final merge)
    Rectangle {
        id: processingOverlay
        anchors.fill: parent
        color: "#AA000000"
        visible: root.isProcessing || root._finishing
        z: 100

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 20
            BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                running: parent.visible
            }
            Text {
                text: root._finishing
                      ? "Đang nhận ảnh cuối từ máy ảnh..."
                      : root._pendingCompletion
                      ? "Vui lòng chờ, đang lưu ảnh..."
                      : "Tạo Khoảnh Khắc Của Bạn"
                color: "white"
                font.pixelSize: 24
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }

    // 2. Countdown number �?" góc trên-trái CỦA khung live view (không nền tròn).
    //    No-retake mode hi�?n s�' �'ếm �Y dải bên phải nên ẩn cái này.
    Text {
        id: countdownOverlay
        z: 8
        visible: isCountingDown && countdownValue > 0 && !root.noRetakeMode
        x: root.isTemplateMode ? 8
           : (root._freeLayout ? (liveViewPanel.x + 22) : (liveViewPanel.x + 20))
        y: root.isTemplateMode ? (parent.height / 2 - height / 2)
           : (root._freeLayout ? (liveViewPanel.y + 82) : (liveViewPanel.y + 64))
        text: root.countdownValue
        color: "white"
        font.pixelSize: root._freeLayout ? 72 : (root.portrait ? 132 : 150)
        font.bold: true
        style: Text.Outline
        styleColor: "#000000"
    }

    // 2b. No-retake: s�' ảnh �'ã chụp (dải bên TRÁI khung live view).
    //     Remote: ẩn (�'ếm s�' ảnh chuy�fn lên góc phải cạnh �'�"ng h�").
    Column {
        z: 8
        visible: root.noRetakeMode && root._centeredCaptureLayout && !root.remoteMode
        anchors.left: parent.left
        width: root.nrSideBand
        y: liveViewPanel.y + liveViewPanel.height / 2 - height / 2
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Đã chụp"
            color: "#9aa0aa"
            font.pixelSize: 24
            font.bold: true
        }
        // S�' ảnh �'ã chụp (không gi�>i hạn �?" không hi�fn th�< t�.ng).
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.capturedCount
            color: "#222222"
            font.pixelSize: 96
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ảnh"
            color: "#9aa0aa"
            font.pixelSize: 20
        }
    }

    // 2d. Góc trên bên PHẢI �?" �'�"ng h�" thời gian G�"I CHỤP (mm:ss) + s�' ảnh �'ã chụp.
    //     Remote: chữ trắng viền �'en �'�f �'ọc rõ trên live view full màn hình.
    Row {
        z: 9
        visible: root.remoteMode && !root._freeLayout
        anchors.right: parent.right
        // Có gói → có thanh tiến trình trên cùng: đẩy số ảnh xuống dưới thanh để không đè.
        anchors.top: root._effectiveSessionTimeLimit > 0 ? sessionProgressBar.bottom : parent.top
        anchors.rightMargin: 28
        anchors.topMargin: root._effectiveSessionTimeLimit > 0 ? 16 : 24
        spacing: 18

        // Đồng hồ mm:ss cũ đã thay bằng thanh tiến trình trên cùng (dùng chung auto + remote).

        // �"?�"? S�' ảnh �'ã chụp (remote) �"?�"?
        Row {
            spacing: 8
            visible: root.remoteMode
            anchors.verticalCenter: parent.verticalCenter
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "📷"; font.pixelSize: 30
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.capturedCount + " ảnh"
                color: "#ffffff"
                font.pixelSize: 40
                font.bold: true
                style: Text.Outline; styleColor: "#000000"
            }
        }
    }

    // 2c. No-retake: �'ếm ngược m�-i ảnh (dải bên PHẢI khung live view)
    Column {
        z: 8
        visible: root.noRetakeMode && root._centeredCaptureLayout && !root.remoteMode && root.isCountingDown && root.countdownValue > 0
        anchors.right: parent.right
        width: root.nrSideBand
        y: liveViewPanel.y + liveViewPanel.height / 2 - height / 2
        spacing: 6

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Đếm ngược"
            color: "#9aa0aa"
            font.pixelSize: 22
            font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.countdownValue
            color: "#1e7eea"
            font.pixelSize: 120
            font.bold: true
        }
    }

    Rectangle {
        z: 12
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 118
        width: Math.min(parent.width - 80, retryText.implicitWidth + 42)
        height: 46
        radius: 23
        color: "#CC1a1200"
        border.color: "#f0c040"
        border.width: 1
        visible: root._captureRetryMessage !== ""

        Text {
            id: retryText
            anchors.centerIn: parent
            width: parent.width - 32
            text: root._captureRetryMessage
            color: "#f8d36a"
            font.pixelSize: 15
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }

    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownValue--
            if (root.countdownValue <= 0) {
                stop()
                triggerCapture()
            }
        }
    }


    // 4. Thumbnail Column �?" c�Tt dọc bên phải, ch�? ảnh (không nền/khung bao quanh).
    //    Ẩn hoàn toàn trong template mode.
    ListView {
        id: thumbColumn
        visible: !root.isTemplateMode && !root.noRetakeMode && !root._freeLayout
        z: 10
        anchors.right:  parent.right;  anchors.rightMargin: root.frameMargin
        anchors.top:    parent.top;    anchors.topMargin: 84    // chừa nút X / badge �'ếm giờ
        anchors.bottom: parent.bottom; anchors.bottomMargin: 110 // chừa nút "Tiếp Tục"
        width: root._centeredCaptureLayout
               ? Math.max(1, root.nrSideBand - root.frameMargin * 2)
               : root.rightColumnWidth - root.frameMargin
        orientation: ListView.Vertical
        spacing: 14
        clip: true
        model: sessionPhotos

        // Tự cu�Tn t�>i ảnh �'ang chụp (t�'i thi�fu �'�f ảnh nằm trong viewport).
        currentIndex: root.currentPhotoIndex
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            width:  thumbColumn.width
            height: width * 0.85

            // Ảnh �'ã chụp �?" ch�? ảnh, không margin, không nền.
            Image {
                anchors.fill: parent
                source: model.path
                fillMode: Image.PreserveAspectFit
                visible: model.captured
                cache: false
                asynchronous: true
                sourceSize: Qt.size(320, 280)
            }

            // Placeholder chưa chụp �?" ô s�' mờ.
            Rectangle {
                anchors.fill: parent
                visible: !model.captured
                color: "#eef0f3"
                radius: 8
                Text {
                    anchors.centerIn: parent
                    text: (index + 1)
                    color: "#b0b4bd"
                    font.pixelSize: 40
                    font.bold: true
                }
            }

            // Viền highlight (overlay riêng): �'ang chụp = xanh dương; vừa retake = xanh lá.
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 8
                visible: index === root.currentPhotoIndex || index === root.lastRetakenIndex
                border.width: 4
                border.color: index === root.lastRetakenIndex ? "#4caf50" : "#1e7eea"
            }

            // �"?�"? Badge "�o" M�>i" khi vừa chụp lại �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
            Rectangle {
                anchors.top:   parent.top
                anchors.left:  parent.left
                anchors.margins: 6
                width:  newBadgeText.implicitWidth + 14
                height: 26
                radius: 6
                color:   "#4caf50"
                visible: index === root.lastRetakenIndex
                z: 10

                // Fade-out animation �'�"ng b�T v�>i timer
                opacity: 1.0
                SequentialAnimation on opacity {
                    running: index === root.lastRetakenIndex
                    PauseAnimation   { duration: 3000 }   // hi�fn rõ 3s
                    NumberAnimation  { to: 0; duration: 800; easing.type: Easing.InQuad }
                }

                Text {
                    id: newBadgeText
                    anchors.centerIn: parent
                    text: "✓ Mới"
                    color: "white"
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            // Click handler - m�Y xem ảnh trực tiếp (không qua popup trung gian)
            MouseArea {
                anchors.fill: parent
                enabled: model.captured && !root.isRetaking && !root._captureInFlight
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (model.captured) {
                        previewOverlay.previewSource      = model.path
                        previewOverlay.previewTargetIndex = index
                        previewOverlay.visible            = true
                    }
                }
            }

            // Overlay "Ready" khi �'ang �'ếm ngược ảnh hi�?n tại
            Rectangle {
                anchors.fill: parent
                radius: 8
                color: "#AA000000"
                visible: index === root.currentPhotoIndex && root.isCountingDown
                Text {
                    anchors.centerIn: parent
                    text: "Ready"
                    color: "white"
                }
            }
        }
    }

    // 4b. Nút "Tiếp Tục" �?" góc dư�>i-phải (chế �'�T thường).
    Button {
        id: continueBtn
        // Chup tu do (mode3): dung nut "Hoan thanh" tren dai thoi gian thay cho nut nay.
        visible: root.freeCaptureUntilTimeout
                 ? false
                 : (!root.isTemplateMode
                    && root._captureReviewMode
                    && root.currentPhotoIndex >= root.totalPhotos
                    && root.capturedCount > 0
                    && root._downloadQueue.length === 0
                    && root._allCapturedPhotosReady())
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root._centeredCaptureLayout ? Math.max(16, (root._captureRightBand - width) / 2) : 30
        anchors.bottomMargin: 30
        width:  200
        height: 60
        z: 10

        // Luôn enable khi có ít nhất 1 ảnh �'ã chụp
        enabled: root.capturedCount > 0 && !root.isProcessing

        // Hi�fn th�< tiến �'�T (ảnh �'ã chụp / t�.ng)
        text: root.freeCaptureUntilTimeout
              ? "Xong (" + root.capturedCount + " ảnh) →"
              : root.capturedCount >= sessionPhotos.count
              ? "Xong / Tiếp tục →"
              : "Tiếp Tục (" + root.capturedCount + "/" + sessionPhotos.count + ") →"

        // Nhấp nháy nhẹ khi �'ã chụp �'ủ ảnh
        scale: (continueBtn.enabled && root.capturedCount >= sessionPhotos.count) ? 1.04 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 800; easing.type: Easing.InOutQuad }
        }

        background: Rectangle {
            color: parent.enabled ? "#ad436d" : Theme.border
            radius: 8
        }

        contentItem: Text {
            text: parent.text
            color: parent.enabled ? "white" : Theme.textMuted
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: root.remoteMode ? root._beginAppendFinish() : root.handleCaptureSessionCompletion()
    }

    // Hư�>ng dẫn dư�>i màn (remote): nhắc khách bấm nút vật lý.
    Rectangle {
        z: 15
        visible: root.remoteMode && !root.freeCaptureUntilTimeout && !root.isProcessing
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 28
        width: remoteHint.implicitWidth + 44
        height: 52
        radius: 26
        color: Qt.rgba(0, 0, 0, 0.6)

        Text {
            id: remoteHint
            anchors.centerIn: parent
            text: "Bấm remote để chụp ảnh"
            color: "#ffffff"; font.pixelSize: 20; font.bold: true
        }
    }

    // Nút CHỤP TEST �?" ch�? khi chụp remote + bật mock + KH�"NG có máy ảnh.
    // Bấm �?' cameraController.takePicture() �?' nhánh mock (vì !isConnected) �?' imageCaptured.
    Rectangle {
        id: mockTestBtn
        z: 25
        visible: false
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 96
        width: 280; height: 68; radius: 34
        color: mockTestMa.pressed ? "#b45309"
             : mockTestMa.containsMouse ? "#d97706" : "#f59e0b"
        border.color: "#ffffff"; border.width: 2
        Behavior on color { ColorAnimation { duration: 100 } }
        scale: mockTestMa.pressed ? 0.95 : 1.0
        Behavior on scale { NumberAnimation { duration: 80 } }

        Row {
            anchors.centerIn: parent
            spacing: 10
            Text { text: "🧪"; font.pixelSize: 26; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: "CHỤP TEST"
                color: "#1a1200"; font.pixelSize: 22; font.bold: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            id: mockTestMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: cameraController.takePicture()
        }
    }

    // Hi�?u ứng flash m�-i khi có ảnh m�>i (dùng cho remote �?" bấm nút vật lý).
    Rectangle {
        id: photoFlashRect
        anchors.fill: parent
        color: "white"; opacity: 0; z: 40
        SequentialAnimation {
            id: photoFlash
            NumberAnimation { target: photoFlashRect; property: "opacity"; to: 0.6; duration: 60 }
            NumberAnimation { target: photoFlashRect; property: "opacity"; to: 0.0; duration: 220 }
        }
    }

    // 4c. Nút "Xong" �?" No-retake: khách chụp bao nhiêu tùy ý r�"i bấm �'�f dừng
    //     và sang bư�>c chọn frame. Bật khi �'ã có ít nhất 1 ảnh.
    Button {
        id: doneBtn
        visible: false
        // Nằm gọn trong dải trắng bên phải �?" c�fn giữa dải, hẹp, không chiếm di�?n tích.
        anchors.right:  parent.right
        anchors.rightMargin: (root.nrSideBand - width) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        width:  116
        height: 96
        z: 10

        enabled: root.capturedCount > 0 && !root.isProcessing

        scale: (doneBtn.enabled && !doneBtn.pressed) ? 1.0 : 0.98
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

        // Màu h�"ng �?" nút "Tiếp tục".
        background: Rectangle {
            color: doneBtn.enabled ? (doneBtn.hovered ? "#db2777" : "#ec4899") : "#c7ccd4"
            radius: 12
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        // Mũi tên, dư�>i là chữ "Tiếp tục".
        contentItem: Column {
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "→"
                color: doneBtn.enabled ? "white" : "#8a8f98"
                font.pixelSize: 30
                font.bold: true
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Tiếp tục"
                color: doneBtn.enabled ? "white" : "#8a8f98"
                font.pixelSize: 15
                font.bold: true
            }
        }

        onClicked: root.handleCaptureSessionCompletion()
    }

    // -------------------------------------------------------------------------
    // (actionPopup removed �?" thumbnail click now opens preview directly)
    // -------------------------------------------------------------------------

    // (confirmRetakePopup removed �?" "Chụp Lại" now calls retakePhoto() directly)

    // -------------------------------------------------------------------------
    // Fullscreen Preview Overlay
    // -------------------------------------------------------------------------
    Rectangle {
        id: previewOverlay
        anchors.fill: parent
        color: "#EE000000"
        visible: false
        z: 90

        property string previewSource: ""
        property int    previewTargetIndex: -1

        // Block click-through
        MouseArea { anchors.fill: parent; onClicked: {} }

        // �"?�"?�"?�"? Photo number label (top-left) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 30
            text: "Ảnh " + (previewOverlay.previewTargetIndex + 1)
            color: "white"
            font.pixelSize: 22
            font.bold: true
            style: Text.Outline; styleColor: "#00000088"
        }

        // �"?�"?�"?�"? Main image (centre, leaves room for right panel) �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
        Image {
            anchors {
                left:   parent.left;  leftMargin:  60
                right:  rightPanel.left; rightMargin: 20
                top:    parent.top;   topMargin:   60
                bottom: parent.bottom; bottomMargin: 60
            }
            source: previewOverlay.previewSource
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: true
            sourceSize: Qt.size(1200, 900)
        }

        // �"?�"?�"?�"? Right panel: nut Đóng + Chụp Lại �"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?�"?
        ColumnLayout {
            id: rightPanel
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 30
            width: 180
            spacing: 16

            Item { Layout.fillHeight: true }

            // Quay Lai
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                background: Rectangle {
                    color: parent.hovered ? "#3a4455" : Theme.field
                    radius: 12
                    border.color: "#4a5570"; border.width: 1
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    Text { Layout.alignment: Qt.AlignHCenter; text: "\u2190"; color: "white"; font.pixelSize: 22; font.bold: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Quay L\u1ea1i"; color: "white"; font.pixelSize: 15; font.bold: true }
                }
                onClicked: {
                    previewOverlay.previewSource = ""
                    previewOverlay.visible = false
                }
            }

            // �Y"� Chụp lại button
            Button {
                id: retakeBtn
                visible: !root.freeCaptureUntilTimeout
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                enabled: !root.isRetaking && !root._captureInFlight
                opacity: enabled ? 1.0 : 0.45

                background: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0; color: retakeBtn.hovered ? "#e04040" : "#c62828" }
                        GradientStop { position: 1; color: retakeBtn.hovered ? "#b03030" : "#8b1a1a" }
                    }
                    radius: 12
                    border.color: "#e05050"; border.width: retakeBtn.hovered ? 1 : 0
                }

                contentItem: ColumnLayout {
                    spacing: 4
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "📷"
                        font.pixelSize: 22
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: "Chụp Lại"
                        color: "white"
                        font.pixelSize: 15; font.bold: true
                    }
                }

                onClicked: {
                    var targetIdx = previewOverlay.previewTargetIndex
                    previewOverlay.previewSource = ""
                    previewOverlay.visible = false
                    root.retakePhoto(targetIdx)
                }
            }

            Item { Layout.fillHeight: true }
        }
    }

    // �"?�"? Template Mode: "Tiếp Tục" button �?" bottom-right corner (z:10) �"?�"?�"?�"?�"?�"?�"?�"?�"?
    Button {
        id: tmContinueBtn
        visible: false
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 30
        width:  200
        height: 60
        z: 10

        enabled: root.capturedCount > 0

        text: root.capturedCount >= sessionPhotos.count
              ? "Tiếp Tục →"
              : "Tiếp Tục (" + root.capturedCount + "/" + sessionPhotos.count + ") →"

        background: Rectangle {
            color: parent.enabled ? "#ad436d" : Theme.border
            radius: 8
        }
        contentItem: Text {
            text: parent.text
            color: parent.enabled ? "white" : Theme.textMuted
            font.pixelSize: 18
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment:   Text.AlignVCenter
        }

        onClicked: root.handleCaptureSessionCompletion()
    }

}
