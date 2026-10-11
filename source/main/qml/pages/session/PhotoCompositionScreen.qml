import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../components"

Item {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    // -------------------------------------------------------------------------
    // Properties & Signals
    // -------------------------------------------------------------------------
    signal sessionFinished(var photos, string collagePath, var transforms)
    signal closeClicked()
    signal backClicked()  // Quay về CaptureScreen (không mất dữ liệu)
    signal retakeRequested(int photoIndex) // Yêu cầu chụp lại 1 ảnh cụ thể

    property int eventId: -1
    property var eventData: null
    property string layoutPath: ""
    property var capturedPhotos: [] // Array of strings (file paths)
    property string sessionId: ""   // Received from BoothSession – used for DB + QR
    property int newPhotoIndex: -1  // Index ảnh vừa được chụp lại (-1 = không có)
    property bool selfBoothMode: false
    property int paymentModeOverride: -1
    property int photoReviewOverride: -1
    // Template mode: photos pre-assigned to slots in order (slot 0 → photos[0], etc.)
    property var preAssignedPhotos: []
    property bool isProcessing: false
    property bool autoSaveEnabled: false
    property string cachedCollagePath: ""
    property bool _pendingSessionFinish: false  // true khi async chạy từ nút "Tiếp Theo"
    property bool _preRenderInProgress: false  // true khi silentPreRender đang chạy async

    // Timer tự xóa highlight sau 4 giây
    Timer {
        id: newPhotoHighlightTimer
        interval: 4000
        running: root.newPhotoIndex >= 0
        onTriggered: root.newPhotoIndex = -1
    }

    // Internal state
    property var slotData: []        // Metadata from JSON
    property var slotAssignments: ({}) // Map: index -> photoPath

    // Click-to-assign state
    property int selectedSlotIndex: -1   // -1 = no slot selected

    // Preview state (updated on every photo click in strip)
    property string previewPhotoPath:  ""   // path of the last-clicked photo
    property int    previewPhotoIndex: -1   // index of the last-clicked photo

    // Derived from ApplicationWindow theme (live-updates when theme changes)
    property color _themeBg: {
        var win = Window.window
        return win ? win.appBgColor : "#000000"
    }
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)

    property bool _paymentEnabled: paymentModeOverride >= 0
                                   ? paymentModeOverride > 0
                                   : eventManager.getAppSetting("payment_enabled", "false") === "true"
    // Xem lại ảnh: bật → panel xem trước + dải ảnh dưới; tắt → lưới 2 hàng bên trái.
    property bool _photoReviewEnabled: photoReviewOverride >= 0
                                      ? photoReviewOverride > 0
                                      : eventManager.getAppSetting("photo_review_enabled", "false") === "true"
    // Bề rộng vùng trái dành cho lưới chọn ảnh khi tắt xem lại ảnh
    readonly property real _leftPanelW: root.selfBoothMode ? root.width * 0.45 : 720
    // No-review: right photo grid. Shows 2 rows x 3 columns, then scrolls horizontally.
    readonly property real _rightGridW: Math.max(700, root.width * 0.5)
    readonly property int  _gridRows: 2
    readonly property int  _gridColumns: 3
    readonly property real _gridThumbAspect: 1.5
    readonly property real _gridHorizontalInset: 8
    readonly property real _rightGridTopMargin: 44
    readonly property real _rightGridBottomMargin: 120
    readonly property real _layoutShiftLeft: root._noReviewGrid ? 44 : 0
    readonly property real _gridShiftDown: root._noReviewGrid ? 42 : 0
    readonly property bool _simplifiedPortrait: root.portrait && !root.selfBoothMode
    // Chế độ lưới chuẩn (tắt xem lại): lưới ảnh sát nhau bên trái + nút Lật dưới lưới,
    // nút Tiếp Theo căn giữa dưới layout. Không áp dụng selfBooth / portrait rút gọn.
    readonly property bool _noReviewGrid: !_simplifiedPortrait && !_photoReviewEnabled && !selfBoothMode
    property string backgroundImagePath: {
        var s = eventManager.getAppSetting("photo_composition_bg_image", "")
        return s !== "" ? s : "qrc:/assets/ghepkhunghinh.png"
    }
    property bool _flipEnabled: eventManager.getAppSetting("flip_photo_enabled", "false") === "true"
    property bool _photosFlipped: false  // trạng thái lật hiện tại của tất cả ảnh

    // true khi đây là item đang hiển thị trên StackView.
    // Khi màn Result/Filter được push đè lên → false → ảnh slot + overlay nhả
    // source về "" để giải phóng pixmap đã decode (model vẫn giữ assignedPath nên
    // khi user bấm "Quay Lại" ảnh tự nạp lại). Tránh giữ ~67MB ảnh trong RAM
    // suốt thời gian các màn sau đang hiển thị.
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    // Pan edit state
    property int editingSlotIndex: -1    // Slot đang được kéo

    // Tick tăng mỗi khi slotsModel thay đổi assignment → trigger re-eval dấu tích thumbnail
    property int assignedPathsTick: 0

    // Trả về true nếu ảnh đã được gán vào bất kỳ slot nào
    function isPhotoInAnySlot(photoPath) {
        var cleanPath = photoPath
        if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.substring(8)
        else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.substring(7)
        if (Qt.platform.os === "windows" && cleanPath.startsWith("/") && cleanPath.indexOf(":") === 2)
            cleanPath = cleanPath.substring(1)
        for (var i = 0; i < slotsModel.count; i++) {
            if (slotsModel.get(i).assignedPath === cleanPath) return true
        }
        return false
    }

    Component.onCompleted: {
        console.log("CompositionScreen: Loaded with", capturedPhotos.length, "photos")
        console.log("CompositionScreen: Layout path:", layoutPath)
        root._photosFlipped = false
        loadLayoutMetadata()

        // Initialize photo strip
        photoModel.clear()
        for (var i = 0; i < capturedPhotos.length; i++) {
            photoModel.append({ "path": capturedPhotos[i], "usedCount": 0 })
        }

        // Template mode: auto-assign each photo to its corresponding slot in order
        if (root.preAssignedPhotos && root.preAssignedPhotos.length > 0) {
            console.log("CompositionScreen: Auto-assigning", root.preAssignedPhotos.length, "photos to slots (template mode)")
            for (var j = 0; j < Math.min(root.preAssignedPhotos.length, slotsModel.count); j++) {
                var photoPath = root.preAssignedPhotos[j] || ""
                var cleanPath = photoPath
                if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.substring(8)
                else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.substring(7)
                if (Qt.platform.os === "windows" && cleanPath.startsWith("/") && cleanPath.indexOf(":") === 2)
                    cleanPath = cleanPath.substring(1)
                if (cleanPath !== "") {
                    slotsModel.setProperty(j, "assignedPath", cleanPath)
                    console.log("CompositionScreen: Slot", j, "→", cleanPath)
                }
            }
            root.assignedPathsTick++
        }
    }

    // ── Auto-save debounce timer ──────────────────────────────────────────────
    // Kích hoạt 1.5s sau lần chỉnh sửa cuối cùng (pan/zoom/assign)
    Timer {
        id: autoSaveTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: {
            // Pre-generate collage ngầm sau khi người dùng ngừng chỉnh sửa
            root.silentPreRender()
        }
    }

    // ── Đếm ngược phiên (chỉ ở chế độ thanh toán) ─────────────────────────────
    // Hết giờ → tự điền ô trống & xác nhận ghép (xem _autoAdvanceOnTimeout).
    Timer {
        id: compositionCountdownTimer
        property int remaining: parseInt(eventManager.getAppSetting("photo_composition_countdown", "240")) || 240
        interval: 1000
        repeat: true
        running: root._paymentEnabled
                 && root.StackView.status === StackView.Active
                 && !root.isProcessing
                 && remaining > 0
        onTriggered: {
            remaining--
            if (remaining <= 0)
                root._autoAdvanceOnTimeout()
        }
    }

    // Đếm ngược hiển thị — góc trên-trái, chỉ hiện khi bật thanh toán.
    Text {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 24
        anchors.topMargin: 14
        z: 1000
        visible: root._paymentEnabled
        text: compositionCountdownTimer.remaining + "s"
        color: "#8B5A2B"
        font.pixelSize: 40
        font.bold: true
        style: Text.Normal
    }

    // Gọi hàm này sau mỗi thay đổi để kích hoạt auto-save
    function scheduleAutoSave() {
        if (!root.isProcessing) {
            root.cachedCollagePath = ""  // Xóa cache cũ khi có thay đổi mới
            root._preRenderInProgress = false  // Pre-render cũ không còn hợp lệ
            autoSaveTimer.restart()
        }
    }

    function dispatchComposition(orderedPhotos, slotTransforms) {
        if (root.selfBoothMode) {
            eventManager.processCollageForLayoutAsync(
                root.eventId, root.layoutPath, orderedPhotos, slotTransforms,
                root.sessionId, false)
        } else {
            eventManager.processCollageWithTransformsAsync(
                root.eventId, orderedPhotos, slotTransforms, root.sessionId, false)
        }
    }

    // Pre-generate collage ngầm (không chuyển trang, chỉ cache kết quả)
    // Chạy async → không hiển thị loading overlay, không block UI
    function silentPreRender() {
        var orderedPhotos  = []
        var slotTransforms = []
        var allFilled = true
        for (var i = 0; i < slotsModel.count; i++) {
            var s = slotsModel.get(i)
            if (!s.assignedPath || s.assignedPath === "") { allFilled = false }
            orderedPhotos.push(s.assignedPath)
            slotTransforms.push({ "scale": s.imgScale, "tx": s.imgTx, "ty": s.imgTy, "flip": root._photosFlipped })
        }
        if (!allFilled) return

        // Lưu lại để onCollageReady biết đây là pre-render (isProcessing = false)
        processCompositionTimer.orderedPhotos  = orderedPhotos
        processCompositionTimer.slotTransforms = slotTransforms

        root._preRenderInProgress = true
        console.log("CompositionScreen: Silent pre-rendering (async, no overlay)...")
        // saveToDb=false: pre-render chỉ cache file trên disk, không ghi DB.
        // recordCollage() sẽ được gọi khi user xác nhận "Tiếp Theo".
        root.dispatchComposition(orderedPhotos, slotTransforms)
        // Kết quả về qua onCollageReady → chỉ cache, không sessionFinished
    }

    // -------------------------------------------------------------------------
    // Logic Functions
    // -------------------------------------------------------------------------

    function loadLayoutMetadata() {
        if (!layoutPath) return

        console.log("CompositionScreen: Loading metadata for layout:", layoutPath)

        // Use EventManager helper to load JSON (avoids XMLHttpRequest local file issues)
        var metadata = eventManager.loadLayoutMetadata(layoutPath)

        if (!metadata || !metadata.slots) {
            console.warn("CompositionScreen: Metadata missing; trying to generate from layout image")
            if (eventManager.ensureLayoutMetadata(layoutPath))
                metadata = eventManager.loadLayoutMetadata(layoutPath)
        }

        if (!metadata || !metadata.slots || metadata.slots.length === 0) {
            console.error("CompositionScreen: Failed to load metadata or no slots found")
            return
        }

        console.log("CompositionScreen: Metadata loaded. Slots:", metadata.slots.length)

        // Populate slots model
        slotsModel.clear()

        // Use JSON dimensions if available
        if (metadata.width && metadata.height) {
            layoutContainer.originalW = metadata.width
            layoutContainer.originalH = metadata.height
            layoutContainer._layoutSizeReady = true
            layoutContainer.updateScale()
            console.log("CompositionScreen: Set container size from JSON:", metadata.width, "x", metadata.height)
        }

        for (var i = 0; i < metadata.slots.length; i++) {
            var s = metadata.slots[i]
            slotsModel.append({
                "slotId": s.id,
                "xPos": s.x,
                "yPos": s.y,
                "w": s.width,
                "h": s.height,
                "assignedPath": "",
                "imgScale": 1.0,
                "imgTx": 0.0,
                "imgTy": 0.0,
                "photoNatW": 0,
                "photoNatH": 0
            })
        }
    }

    // Assign a photo to a slot by click
    function assignPhotoToSlot(photoPath) {
        var cleanPath = photoPath
        // Strip file:/// prefix to store clean path
        if (cleanPath.startsWith("file:///")) {
            cleanPath = cleanPath.substring(8)
        } else if (cleanPath.startsWith("file://")) {
            cleanPath = cleanPath.substring(7)
        }
        // On Windows, strip leading slash if it looks like /C:/
        if (Qt.platform.os === "windows" && cleanPath.startsWith("/") && cleanPath.indexOf(":") === 2) {
            cleanPath = cleanPath.substring(1)
        }

        // If a specific slot is selected, assign to that slot
        if (selectedSlotIndex >= 0 && selectedSlotIndex < slotsModel.count) {
            console.log("CompositionScreen: Assigning photo to selected slot", selectedSlotIndex)
            slotsModel.setProperty(selectedSlotIndex, "assignedPath", cleanPath)
            selectedSlotIndex = -1  // Reset selection
            root.assignedPathsTick++
            root.scheduleAutoSave()  // Auto-save sau khi gán
            return
        }

        // Otherwise, find first empty slot
        for (var i = 0; i < slotsModel.count; i++) {
            var slot = slotsModel.get(i)
            if (!slot.assignedPath || slot.assignedPath === "") {
                console.log("CompositionScreen: Assigning photo to next empty slot", i)
                slotsModel.setProperty(i, "assignedPath", cleanPath)
                root.assignedPathsTick++
                root.scheduleAutoSave()  // Auto-save sau khi gán
                return
            }
        }

        console.log("CompositionScreen: All slots are full, no assignment made")
    }

    // Gán ảnh vào ĐÚNG 1 slot (dùng cho kéo-thả). Cho phép TRÙNG: 1 ảnh vào nhiều slot;
    // thả lên slot đã có → ghi đè. Reset transform để ảnh mới vừa khít slot.
    function assignPhotoToSlotIndex(slotIndex, photoPath) {
        if (slotIndex < 0 || slotIndex >= slotsModel.count) return
        var cleanPath = photoPath
        if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.substring(8)
        else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.substring(7)
        if (Qt.platform.os === "windows" && cleanPath.startsWith("/") && cleanPath.indexOf(":") === 2)
            cleanPath = cleanPath.substring(1)

        console.log("CompositionScreen: [drop] Assigning photo to slot", slotIndex, "->", cleanPath)
        slotsModel.setProperty(slotIndex, "assignedPath", cleanPath)
        slotsModel.setProperty(slotIndex, "imgScale", 1.0)
        slotsModel.setProperty(slotIndex, "imgTx", 0.0)
        slotsModel.setProperty(slotIndex, "imgTy", 0.0)
        slotsModel.setProperty(slotIndex, "photoNatW", 0)
        slotsModel.setProperty(slotIndex, "photoNatH", 0)
        root.selectedSlotIndex = -1
        root.editingSlotIndex = -1
        root.assignedPathsTick++
        root.cachedCollagePath = ""   // Invalidate cache khi đổi ảnh slot
        root.scheduleAutoSave()
    }

    // Clear a slot and set it as selected (waiting for new photo)
    function clearAndSelectSlot(slotIndex) {
        console.log("CompositionScreen: Clearing slot", slotIndex, "and selecting it")
        slotsModel.setProperty(slotIndex, "assignedPath", "")
        slotsModel.setProperty(slotIndex, "imgScale", 1.0)
        slotsModel.setProperty(slotIndex, "imgTx", 0.0)
        slotsModel.setProperty(slotIndex, "imgTy", 0.0)
        slotsModel.setProperty(slotIndex, "photoNatW", 0)
        slotsModel.setProperty(slotIndex, "photoNatH", 0)
        selectedSlotIndex = slotIndex
        editingSlotIndex = -1
        root.assignedPathsTick++
        root.cachedCollagePath = ""  // Invalidate cache khi xóa ảnh
        autoSaveTimer.stop()
    }

    // Giới hạn zoom: 1.0 = vừa khít cover slot, 3.0 = phóng 3×
    readonly property real _minScale: 1.0
    readonly property real _maxScale: 3.0

    // Tính biên pan tối đa (fraction so với slot) theo tỉ lệ ảnh/slot và scale.
    // Khi scale > 1, ảnh hiển thị to hơn cover-size theo cả 2 chiều → biên tăng (scale-1)/2.
    function panLimits(slot) {
        var slotAR  = (slot.h > 0) ? (slot.w / slot.h) : 1.0
        var photoAR = (slot.photoNatH > 0) ? (slot.photoNatW / slot.photoNatH) : slotAR
        var scale   = slot.imgScale > 0 ? slot.imgScale : 1.0
        var maxTx = 0.0
        var maxTy = 0.0
        if (photoAR > slotAR)
            maxTx = (photoAR / slotAR - 1.0) / 2.0
        else if (photoAR < slotAR)
            maxTy = (slotAR / photoAR - 1.0) / 2.0
        // Phần overflow thêm do zoom: ảnh phóng to đều theo 2 chiều quanh tâm slot.
        var extra = (scale - 1.0) / 2.0
        return { maxTx: maxTx + extra, maxTy: maxTy + extra }
    }

    // Ràng buộc tx/ty để ảnh luôn lấp đầy slot (không lộ nền trống)
    function constrainSlot(idx) {
        var s = slotsModel.get(idx)
        if (!s) return
        var lim = root.panLimits(s)
        slotsModel.setProperty(idx, "imgTx", Math.max(-lim.maxTx, Math.min(lim.maxTx, s.imgTx)))
        slotsModel.setProperty(idx, "imgTy", Math.max(-lim.maxTy, Math.min(lim.maxTy, s.imgTy)))
    }

    // Kết nối signal async từ C++ về QML một lần khi khởi tạo
    Connections {
        target: eventManager
        function onCollageReady(collagePath) {
            console.log("[CompositionScreen] onCollageReady: collagePath =", collagePath)
            console.log("[CompositionScreen] _pendingSessionFinish =", root._pendingSessionFinish,
                        "| _preRenderInProgress =", root._preRenderInProgress)
            root.cachedCollagePath = collagePath
            root._preRenderInProgress = false

            if (root._pendingSessionFinish) {
                root._pendingSessionFinish = false
                root.isProcessing = false
                var snapPhotos = processCompositionTimer.orderedPhotos
                var snapTransforms = processCompositionTimer.slotTransforms
                var pendingPath = collagePath
                if (pendingPath.startsWith("file:///")) pendingPath = pendingPath.substring(8)
                if (!root.selfBoothMode) {
                    console.log("[CompositionScreen] recordCollage:", pendingPath, "sessionId:", root.sessionId)
                    eventManager.recordCollage(root.eventId, pendingPath, root.sessionId)
                }
                console.log("[CompositionScreen] emit sessionFinished →", snapPhotos.length, "ảnh | collagePath:", collagePath)
                root.sessionFinished(snapPhotos, collagePath, snapTransforms)
            } else {
                console.log("[CompositionScreen] Pre-render silent cached:", collagePath)
            }
        }
    }

    Timer {
        id: processCompositionTimer
        interval: 80   // Đủ để QML render overlay; C++ chạy async → không cần delay dài
        repeat: false
        property var orderedPhotos: []
        property var slotTransforms: []  // [{scale, tx, ty}, ...]
        onTriggered: {
            console.log("CompositionScreen: Dispatching async collage –",
                        orderedPhotos.length, "photos,", slotTransforms.length, "transforms")

            // Chạy trên background thread → không block UI
            // saveToDb=false: recordCollage() trong onCollageReady sẽ ghi DB khi user xác nhận.
            root.dispatchComposition(orderedPhotos, slotTransforms)
            // Kết quả sẽ về qua onCollageReady signal
        }
    }

    function processComposition() {
        // Thu thập danh sách ảnh VÀ transform từng slot
        var orderedPhotos  = []
        var slotTransforms = []

        for (var i = 0; i < slotsModel.count; i++) {
            var s = slotsModel.get(i)

            var path = s.assignedPath
            if (!path || path === "") {
                console.warn("CompositionScreen: Slot", i + 1, "is empty!")
            }
            orderedPhotos.push(path)

            // Lưu transform: {scale, tx, ty}
            // tx/ty là fraction (đơn vị QML), C++ sẽ áp dụng đúng
            slotTransforms.push({
                "scale": s.imgScale,
                "tx":    s.imgTx,
                "ty":    s.imgTy,
                "flip":  root._photosFlipped
            })
        }

        // Tái sử dụng cache nếu pre-render đã hoàn thành với cùng transform
        // (autoSaveTimer xóa cachedCollagePath ngay khi có thay đổi → cache chỉ hợp lệ
        //  khi không có chỉnh sửa nào kể từ lần pre-render cuối)
        if (root.cachedCollagePath !== "") {
            console.log("[CompositionScreen] Dùng cache → recordCollage + sessionFinished")
            console.log("[CompositionScreen] collagePath (cache):", root.cachedCollagePath)
            var cachePath = root.cachedCollagePath
            if (cachePath.startsWith("file:///")) cachePath = cachePath.substring(8)
            if (!root.selfBoothMode)
                eventManager.recordCollage(root.eventId, cachePath, root.sessionId)
            console.log("[CompositionScreen] emit sessionFinished với", orderedPhotos.length, "ảnh")
            root.sessionFinished(orderedPhotos, root.cachedCollagePath, slotTransforms)
            return
        }

        if (root._preRenderInProgress) {
            console.log("[CompositionScreen] Pre-render đang chạy → đặt _pendingSessionFinish, chờ onCollageReady")
            root.isProcessing = true
            root._pendingSessionFinish = true
            processCompositionTimer.orderedPhotos  = orderedPhotos
            processCompositionTimer.slotTransforms = slotTransforms
            return
        }

        console.log("[CompositionScreen] Không có cache → bắt đầu render async")
        root.isProcessing = true
        root._pendingSessionFinish = true

        processCompositionTimer.orderedPhotos  = orderedPhotos
        processCompositionTimer.slotTransforms = slotTransforms
        processCompositionTimer.start()
    }

    // Tất cả slot đã có ảnh? (dùng cho trạng thái bật nút Tiếp Theo)
    function _areAllSlotsFilled() {
        if (slotsModel.count === 0) return false
        for (var i = 0; i < slotsModel.count; i++) {
            var p = slotsModel.get(i).assignedPath
            if (!p || p === "") return false
        }
        return true
    }

    // Xác nhận ghép ảnh — dùng chung cho các nút "Tiếp Theo".
    function confirmComposition() {
        autoSaveTimer.stop()
        console.log("=== [CompositionScreen] Xác nhận ghép ảnh — tổng slot:", slotsModel.count)
        root.processComposition()
    }

    // Hết giờ phiên (chế độ thanh toán): tự điền ảnh vào ô còn trống theo thứ tự
    // rồi xác nhận ghép → chuyển sang bước tiếp theo.
    function _autoAdvanceOnTimeout() {
        console.log("=== [CompositionScreen] Hết giờ → tự điền ô trống & xác nhận ghép")
        if (!_areAllSlotsFilled() && photoModel.count > 0) {
            var pi = 0
            for (var i = 0; i < slotsModel.count; i++) {
                var s = slotsModel.get(i)
                if (!s.assignedPath || s.assignedPath === "") {
                    slotsModel.setProperty(i, "assignedPath",
                                           photoModel.get(pi % photoModel.count).path)
                    pi++
                }
            }
            root.assignedPathsTick++
        }
        if (_areAllSlotsFilled())
            root.confirmComposition()
    }

    // -------------------------------------------------------------------------
    // Models
    // -------------------------------------------------------------------------

    ListModel { id: slotsModel }
    ListModel { id: photoModel } // { path, usedCount }

    // -------------------------------------------------------------------------
    // UI Structure
    // -------------------------------------------------------------------------

    // Background
    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    Rectangle {
        anchors.fill: parent
        color: root.backgroundImagePath !== "" ? "transparent" : root._themeBg
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 1. Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 64
            color: root.backgroundImagePath !== "" ? "transparent" : Theme.surface
            z: 10


            // ── Tiêu đề giữa ──
            Text {
                anchors.centerIn: parent
                text: root.selectedSlotIndex >= 0
                    ? "" + (root.selectedSlotIndex + 1)
                    : ""
                color: root.selectedSlotIndex >= 0 ? "#4FA4F2" : "#ffffff"
                font.pixelSize: 20
                font.bold: true
            }

            // ── Bên phải: Hủy chọn (khi đang chọn slot) hoặc nút X ──

            // Cancel selection button (visible when a slot is selected)
            Button {
                visible: root.selectedSlotIndex >= 0
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 16
                width: 120
                height: 40

                background: Rectangle {
                    color: parent.hovered ? Theme.border : Theme.field
                    radius: 8
                }
                contentItem: Text {
                    text: "Hủy chọn"
                    color: "#ffffff"
                    font.pixelSize: 14
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.selectedSlotIndex = -1
            }

            // Nút X tròn — ĐÃ ẨN: trong flow ghép ảnh không cho thoát phiên bằng
            // nút X (tránh bấm nhầm giữa chừng). Chỉ điều hướng bằng Back/Next.
            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 16
                width: 52; height: 52; radius: 26
                visible: false
                color: closeCompArea.containsMouse ? "#c0392b" : "#e74c3c"
                border.color: "white"; border.width: 2
                z: 20
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    color: "white"; font.pixelSize: 22; font.bold: true
                }
                MouseArea {
                    id: closeCompArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.closeClicked()
                }
            }

        }

        // 2. Composition Area
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            color: root.backgroundImagePath !== "" ? "transparent" : Theme.field

            // Container for Layout Image and Slots
            Item {
                id: layoutContainer

                // Center in the space REMAINING after the side panel.
                // No-review: panel ảnh nằm BÊN PHẢI → chừa chỗ bên phải, layout dồn sang trái.
                // Các chế độ khác: chừa chỗ bên trái (preview / lưới cũ).
                property real _reservedLeft: root._simplifiedPortrait ? 0
                                            : (root._noReviewGrid ? 0
                                               : (root._photoReviewEnabled ? 500 : root._leftPanelW))
                // No-review: frame bên TRÁI, chừa panel grid ảnh bên PHẢI.
                property real _reservedRight: root._noReviewGrid ? root._rightGridW : 0
                property real availableW: parent.width - _reservedLeft - _reservedRight

                property real scaleRatio: 1.0
                property real originalW: 1800
                property real originalH: 1200
                property bool _layoutSizeReady: false
                // No-review: frame căn giữa vùng bên trái (không chừa đáy).
                property real _bottomReserve: 0
                // Hệ số lấp đầy: frame chiếm gần hết vùng bên trái.
                property real _fillFactor: root._noReviewGrid ? 0.92 : 0.95

                // width/height luôn = originalW/H * scaleRatio → đảm bảo slots
                // dùng cùng scaleRatio với container → không méo, không lệch.
                width:  originalW * scaleRatio
                height: originalH * scaleRatio
                x: _reservedLeft + (availableW - width) * 0.5 - root._layoutShiftLeft
                y: (parent.height - _bottomReserve - height) * 0.5

                // Re-calc khi availableW hoặc parent.height thay đổi
                onAvailableWChanged: updateScale()
                onHeightChanged: { /* prevent binding loop */ }

                function updateScale() {
                    var wRatio = availableW / originalW
                    var hRatio = (parent.height - _bottomReserve) / originalH
                    scaleRatio = Math.min(wRatio, hRatio) * _fillFactor
                    // width/height tự cập nhật qua binding ở trên
                    x = _reservedLeft + (availableW - width) * 0.5 - root._layoutShiftLeft
                    y = (parent.height - _bottomReserve - height) * 0.5
                }

                // 1. Slots (Clickable Areas) - Rendered BOTTOM (Behind Overlay)
                Repeater {
                    model: slotsModel
                    delegate: Item {
                        visible: layoutContainer._layoutSizeReady
                        x: model.xPos * layoutContainer.scaleRatio
                        y: model.yPos * layoutContainer.scaleRatio
                        width: model.w * layoutContainer.scaleRatio
                        height: model.h * layoutContainer.scaleRatio
                        z: 1

                        // ── Slot container ──────────────────────────────────────────
                        Item {
                            id: slotItem
                            anchors.fill: parent

                            // ── Vùng THẢ ảnh (kéo từ dải ảnh đáy) ───────────────────────
                            // DropArea không nuốt sự kiện chuột (chỉ hoạt động khi đang kéo)
                            // nên không cản pan/zoom ảnh trong slot.
                            DropArea {
                                id: slotDrop
                                anchors.fill: parent
                                z: 30
                                onDropped: function(drop) {
                                    if (drop.source && drop.source.photoPath !== undefined)
                                        root.assignPhotoToSlotIndex(index, drop.source.photoPath)
                                }
                                // Viền xanh khi kéo ảnh tới trên slot
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 4
                                    color: "#3322C55E"
                                    border.color: "#22C55E"
                                    border.width: 4
                                    visible: slotDrop.containsDrag
                                    z: 30
                                }
                            }

                            // Border overlay
                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.color: {
                                    if (index === root.editingSlotIndex)  return "#ff9800"  // Orange khi đang kéo/zoom
                                    if (index === root.selectedSlotIndex) return "#4fc3f7"  // Cyan khi chọn gán
                                    if (model.assignedPath) return "transparent"
                                    return "#FFFF00"  // Yellow cho slot rỗng
                                }
                                border.width: (index === root.editingSlotIndex || index === root.selectedSlotIndex) ? 4 : 2
                                radius: 4
                                z: 5

                                // Hint label khi đang kéo ảnh
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.left: parent.left
                                    anchors.margins: 4
                                    width: editLabel.implicitWidth + 14
                                    height: 24
                                    radius: 6
                                    color: "#CC1a1a1a"
                                    border.color: "#ff9800"
                                    border.width: 1
                                    visible: index === root.editingSlotIndex
                                    z: 10

                                    opacity: visible ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    Text {
                                        id: editLabel
                                        anchors.centerIn: parent
                                        text: "✋ Kéo · 🔍 Cuộn/2 ngón để zoom"
                                        color: "#ff9800"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }
                                }
                            }

                            // Empty slot indicator
                            Rectangle {
                                anchors.fill: parent
                                color: index === root.selectedSlotIndex ? "#334fc3f7" : "#33FFFF00"
                                visible: !model.assignedPath
                                radius: 4

                                Text {
                                    anchors.centerIn: parent
                                    text: model.slotId
                                    color: "white"
                                    style: Text.Outline
                                    styleColor: "black"
                                    font.bold: true
                                    font.pixelSize: 24 * layoutContainer.scaleRatio
                                }

                                SequentialAnimation on opacity {
                                    running: index === root.selectedSlotIndex
                                    loops: Animation.Infinite
                                    NumberAnimation { from: 0.4; to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                                    NumberAnimation { from: 1.0; to: 0.4; duration: 800; easing.type: Easing.InOutQuad }
                                }

                                // Tap empty slot → vào chế độ gán
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        root.editingSlotIndex = -1
                                        root.selectedSlotIndex = index
                                    }
                                }
                            }

                            // ── Ảnh đã gán – Pan ────────────────────────────────────
                            Rectangle {
                                id: photoClip
                                anchors.fill: parent
                                clip: true
                                color: "black"
                                radius: 4
                                visible: model.assignedPath !== ""

                                Image {
                                    id: slotPhoto

                                    // _photoAR được gán trực tiếp (không dùng binding) để tránh
                                    // binding loop qua model.photoNatW ↔ onStatusChanged.
                                    property real _photoAR: 0
                                    property real _slotAR:  (photoClip.height > 0)
                                                            ? (photoClip.width  / photoClip.height) : 1

                                    // Khôi phục AR từ model khi delegate được tạo lại
                                    Component.onCompleted: {
                                        if (model.photoNatW > 0 && model.photoNatH > 0)
                                            slotPhoto._photoAR = model.photoNatW / model.photoNatH
                                    }

                                    // Khi chưa biết AR ảnh: fill slot (PreserveAspectCrop tự cover đúng)
                                    // Khi biết AR ảnh: set đúng kích thước cover → ảnh extend ra ngoài
                                    // slot theo chiều bị tràn, photoClip.clip cắt gọn.
                                    // Kéo/pan dịch Image này → không bao giờ lộ màu đen vì
                                    // ảnh luôn lớn hơn hoặc bằng slot.
                                    width:  (_photoAR > 0 && _photoAR > _slotAR)
                                            ? photoClip.height * _photoAR   // ảnh rộng: tràn ngang
                                            : photoClip.width
                                    height: (_photoAR > 0 && _photoAR < _slotAR)
                                            ? photoClip.width / _photoAR    // ảnh cao: tràn dọc
                                            : photoClip.height

                                    anchors.centerIn: parent

                                    // Stretch chỉ khi đã biết AR (kích thước đã tính đúng)
                                    // Ngược lại dùng PreserveAspectCrop để tránh méo lúc đang load
                                    fillMode: _photoAR > 0 ? Image.Stretch : Image.PreserveAspectCrop

                                    source: {
                                        // Nhả ảnh khi màn hình bị đẩy xuống dưới StackView
                                        if (!root._isActiveScreen) return ""
                                        if (!model.assignedPath) return ""
                                        if (model.assignedPath.startsWith("file:///")) return model.assignedPath
                                        return "file:///" + model.assignedPath
                                    }
                                    // sourceSize giới hạn ở 1200px — slot hiển thị tối đa ~700px,
                                    // QML chỉ áp pan (Translate) không áp zoom → 1200 là quá đủ.
                                    // Giảm từ 2000→1200 cắt ~64% RAM và ~60% thời gian decode.
                                    sourceSize: Qt.size(1200, 1200)
                                    // asynchronous: decode JPEG trên thread pool → KHÔNG block UI
                                    // khi mở màn hình hoặc khi retake (trước đây 6 ảnh decode
                                    // đồng bộ gây Not Responding 1-2 giây).
                                    asynchronous: true
                                    // cache:false → không giữ ảnh slot trong QQuickPixmapCache,
                                    // tránh RAM tăng dần qua hàng trăm session chạy nhiều giờ.
                                    cache: false
                                    antialiasing: true
                                    smooth: true
                                    mirror: root._photosFlipped

                                    onStatusChanged: {
                                        if (status === Image.Ready && implicitWidth > 0 && implicitHeight > 0) {
                                            // Gán trực tiếp để không tạo binding loop
                                            slotPhoto._photoAR = implicitWidth / implicitHeight
                                            slotsModel.setProperty(index, "photoNatW", implicitWidth)
                                            slotsModel.setProperty(index, "photoNatH", implicitHeight)
                                        }
                                    }

                                    transform: [
                                        Scale {
                                            origin.x: slotPhoto.width  / 2
                                            origin.y: slotPhoto.height / 2
                                            xScale: model.imgScale > 0 ? model.imgScale : 1.0
                                            yScale: model.imgScale > 0 ? model.imgScale : 1.0
                                        },
                                        Translate {
                                            x: model.imgTx * photoClip.width
                                            y: model.imgTy * photoClip.height
                                        }
                                    ]
                                }

                                // ── Pan: 1 ngón chạm hoặc chuột trái ────────────────
                                DragHandler {
                                    id: panHandler
                                    target: null
                                    dragThreshold: 3
                                    grabPermissions: PointerHandler.CanTakeOverFromAnything

                                    property real startTx: 0.0
                                    property real startTy: 0.0

                                    onActiveChanged: {
                                        if (active && model.assignedPath) {
                                            startTx = model.imgTx
                                            startTy = model.imgTy
                                            root.editingSlotIndex = index
                                            root.selectedSlotIndex = -1
                                        } else if (!active && model.assignedPath) {
                                            root.constrainSlot(index)
                                            root.scheduleAutoSave()
                                            root.editingSlotIndex = -1
                                        }
                                    }

                                    onTranslationChanged: {
                                        if (!active || !model.assignedPath) return
                                        var ddx = translation.x / photoClip.width
                                        var ddy = translation.y / photoClip.height
                                        var lim = root.panLimits(slotsModel.get(index))
                                        slotsModel.setProperty(index, "imgTx",
                                            Math.max(-lim.maxTx, Math.min(lim.maxTx, startTx + ddx)))
                                        slotsModel.setProperty(index, "imgTy",
                                            Math.max(-lim.maxTy, Math.min(lim.maxTy, startTy + ddy)))
                                    }
                                }

                                // ── Zoom: 2 ngón pinch (cảm ứng) ──────────────────
                                PinchHandler {
                                    id: pinchHandler
                                    target: null
                                    minimumScale: 0.1
                                    maximumScale: 10.0

                                    property real startScale: 1.0

                                    onActiveChanged: {
                                        if (active && model.assignedPath) {
                                            startScale = model.imgScale > 0 ? model.imgScale : 1.0
                                            root.editingSlotIndex = index
                                            root.selectedSlotIndex = -1
                                        } else if (!active && model.assignedPath) {
                                            root.constrainSlot(index)
                                            root.scheduleAutoSave()
                                            root.editingSlotIndex = -1
                                        }
                                    }

                                    onActiveScaleChanged: {
                                        if (!active || !model.assignedPath) return
                                        var s = startScale * activeScale
                                        s = Math.max(root._minScale, Math.min(root._maxScale, s))
                                        slotsModel.setProperty(index, "imgScale", s)
                                        // Co biên lại nếu zoom out khiến vị trí hiện tại vượt giới hạn mới
                                        var lim = root.panLimits(slotsModel.get(index))
                                        var sl = slotsModel.get(index)
                                        slotsModel.setProperty(index, "imgTx",
                                            Math.max(-lim.maxTx, Math.min(lim.maxTx, sl.imgTx)))
                                        slotsModel.setProperty(index, "imgTy",
                                            Math.max(-lim.maxTy, Math.min(lim.maxTy, sl.imgTy)))
                                    }
                                }

                                // ── Zoom: bánh xe chuột / touchpad ────────────────
                                WheelHandler {
                                    target: null
                                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                    onWheel: (event) => {
                                        if (!model.assignedPath) return
                                        var sl = slotsModel.get(index)
                                        var cur = sl.imgScale > 0 ? sl.imgScale : 1.0
                                        // Mỗi notch (120 units) ≈ 10%
                                        var factor = Math.pow(1.1, event.angleDelta.y / 120)
                                        var next = Math.max(root._minScale, Math.min(root._maxScale, cur * factor))
                                        slotsModel.setProperty(index, "imgScale", next)

                                        root.editingSlotIndex = index
                                        root.selectedSlotIndex = -1

                                        var lim = root.panLimits(slotsModel.get(index))
                                        slotsModel.setProperty(index, "imgTx",
                                            Math.max(-lim.maxTx, Math.min(lim.maxTx, sl.imgTx)))
                                        slotsModel.setProperty(index, "imgTy",
                                            Math.max(-lim.maxTy, Math.min(lim.maxTy, sl.imgTy)))

                                        root.scheduleAutoSave()
                                        wheelStopTimer.restart()
                                        event.accepted = true
                                    }
                                }

                                // Tắt highlight chỉnh sửa sau khi ngừng cuộn 400ms
                                Timer {
                                    id: wheelStopTimer
                                    interval: 400
                                    repeat: false
                                    onTriggered: root.editingSlotIndex = -1
                                }

                                // ── Tap: cập nhật preview ─────────────────────────────
                                TapHandler {
                                    gesturePolicy: TapHandler.WithinBounds
                                    onTapped: {
                                        if (!model.assignedPath) return
                                        root.previewPhotoPath  = model.assignedPath
                                        root.previewPhotoIndex = -1
                                    }
                                }
                            }

                            // ── Nút X xóa slot (hiện khi có ảnh) ───────────────────
                            Rectangle {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: 4
                                width: 50
                                height: 50
                                color: xButtonArea.containsMouse ? "#ff4757" : "#e74c3c"
                                radius: 25
                                border.color: "white"
                                border.width: 2
                                visible: model.assignedPath !== ""
                                z: 20

                                Text {
                                    anchors.centerIn: parent
                                    text: "✕"
                                    color: "white"
                                    font.pixelSize: 26
                                    font.bold: true
                                }

                                MouseArea {
                                    id: xButtonArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.clearAndSelectSlot(index)
                                }
                            }
                        }
                    }
                }

                // 2. Background Layout Image - Rendered TOP (Overlay)
                Image {
                    id: bgImage
                    anchors.fill: parent
                    source: {
                        // Nhả overlay PNG khi màn hình bị đẩy xuống dưới StackView
                        if (!root._isActiveScreen) return ""
                        if (!root.layoutPath) return ""
                        if (root.layoutPath.startsWith("file:///")) return root.layoutPath
                        return "file:///" + root.layoutPath
                    }
                    // Stretch: layoutContainer đã được sizing đúng tỉ lệ overlay (originalW/H * scaleRatio)
                    // → không cần PreserveAspectFit (letterbox). Stretch đảm bảo overlay
                    // phủ khít 100% container, khớp pixel-perfect với vị trí slot.
                    fillMode: Image.Stretch
                    cache: false
                    // asynchronous: PNG overlay (có thể 2362×3543 ≈ 33MB) decode off UI thread.
                    // KHÔNG đặt sourceSize: onStatusChanged cần sourceSize NATIVE để set
                    // originalW/H — đây là hệ toạ độ chuẩn cho vị trí slot, sai sẽ lệch slot.
                    asynchronous: true
                    z: 10

                    visible: status === Image.Ready

                    onStatusChanged: {
                        if (status === Image.Ready) {
                            if (!layoutContainer._layoutSizeReady) {
                                // JSON không có dimensions → fallback từ PNG native size
                                layoutContainer.originalW = sourceSize.width
                                layoutContainer.originalH = sourceSize.height
                                layoutContainer._layoutSizeReady = true
                                layoutContainer.updateScale()
                                console.log("CompositionScreen: Set container size from PNG:", sourceSize.width, "x", sourceSize.height)
                            }
                            // Nếu JSON đã set size → không override, tránh race condition
                        }
                    }
                }
            }

            // ── LEFT PREVIEW PANEL (fixed 500px, always visible) ─────────────
            Rectangle {
                id: previewPanel
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width: 700
                visible: !root._simplifiedPortrait && root._photoReviewEnabled
                clip: true
                color: root.backgroundImagePath !== "" ? "transparent" : Theme.surface
                z: 20

                // Right separator
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
                    width: 1
                    color: root.backgroundImagePath !== "" ? Qt.rgba(1, 1, 1, 0.15) : Theme.border
                }

                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 12

                    // ── Header ────────────────────────────────────────────────
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Text { text: "👁"; font.pixelSize: 18 }
                        Text {
                            text: "Xem Trước Ảnh"
                            color: "#ffffff"; font.pixelSize: 16; font.bold: true
                            Layout.fillWidth: true
                        }
                    }

                    // ── Source badge (strip photo or slot photo) ──────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        visible: root.previewPhotoPath !== ""
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "#73B9F5" }
                            GradientStop { position: 1; color: "#4FA4F2" }
                        }
                        radius: 8
                        Text {
                            anchors.centerIn: parent
                            text: root.previewPhotoIndex >= 0
                                  ? "📷  Ảnh #" + (root.previewPhotoIndex + 1) + " (danh sách)"
                                  : "🖼️  Ảnh từ slot"
                            color: "white"; font.pixelSize: 13; font.bold: true
                        }
                    }

                    // ── Preview image area (~500×500) ─────────────────────────
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: root.backgroundImagePath !== "" ? Qt.rgba(0.1, 0.11, 0.14, 0.6) : "#252930"
                        radius: 12
                        clip: true
                        border.color: root.previewPhotoPath !== "" ? "#4FA4F2" : Theme.border
                        border.width: root.previewPhotoPath !== "" ? 2 : 1

                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        // Placeholder when no photo selected yet
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 14
                            visible: root.previewPhotoPath === ""

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "🖼️"
                                font.pixelSize: 52
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.preferredWidth: 280
                                text: "Click vào ảnh trong danh sách\nhoặc chạm ảnh trong slot\nđể xem trước"
                                color: Theme.textMuted
                                font.pixelSize: 14
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignHCenter
                                lineHeight: 1.5
                            }
                        }
                        // Actual preview image
                        Image {
                            id: previewImg
                            anchors.fill: parent
                            anchors.margins: 6
                            visible: root.previewPhotoPath !== ""
                            source: {
                                if (!root.previewPhotoPath) return ""
                                if (root.previewPhotoPath.startsWith("file:///")) return root.previewPhotoPath
                                return "file:///" + root.previewPhotoPath
                            }
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                            // Giới hạn giải mã ở kích thước panel thực tế — panel 700px, không cần
                            // decode ảnh DSLR gốc 5184×3456 = ~71MB chỉ để hiển thị preview nhỏ
                            sourceSize: Qt.size(parent.width, parent.height)
                            mirror: root._photosFlipped

                            Behavior on source { /* no anim — instant switch */ }

                            BusyIndicator {
                                anchors.centerIn: parent
                                running: previewImg.status === Image.Loading
                                visible: running
                            }

                            // Click → mở fullscreen overlay
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.previewPhotoPath !== "" && !root._simplifiedPortrait) {
                                        photoDetailOverlay.overlayPath  = root.previewPhotoPath
                                        photoDetailOverlay.overlayIndex = root.previewPhotoIndex
                                        photoDetailOverlay.visible = true
                                    }
                                }
                            }
                        }
                    }

                    // ── Status / hint text ────────────────────────────────────
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (root.previewPhotoPath === "") return "Chưa có ảnh được chọn"
                            if (root.selectedSlotIndex >= 0)
                                return "✅ Đã gán vào ô " + (root.selectedSlotIndex + 1)
                            return "Đang xem trước ảnh"
                        }
                        color: root.selectedSlotIndex >= 0 ? "#4FA4F2" : Theme.textMuted
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            } // previewPanel

            // ── RIGHT PHOTO GRID (khi TẮT xem lại ảnh) — thumbnail + 2 nút dưới ─
            // Trước đây nằm bên trái; đã chuyển sang phải, layout dồn sang trái.
            Item {
                id: leftPhotoGrid
                anchors.right:  parent.right
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width: root._leftPanelW
                // No-review (màn ngang) đã chuyển sang dải ảnh cuộn ngang ở đáy → ẩn lưới này.
                // Vẫn dùng cho selfbooth (selfPhotoGrid bên trong).
                visible: !root._simplifiedPortrait && !root._photoReviewEnabled && !root._noReviewGrid

                readonly property int pad: 24
                readonly property int flipReserve: 120   // chừa chỗ nút Lật dưới lưới
                property int cols: Math.max(1, Math.ceil(photoModel.count / 2))
                // Ô theo ĐÚNG tỉ lệ ảnh (lấy từ ảnh đầu tiên, fallback 3:2), fit trong
                // khối lưới; gap 0 nên các ô vẫn sát nhau, ảnh không bị cắt méo.
                property real photoAR: 1.5      // 3:2 landscape mặc định
                property bool _arLocked: false
                property real cellW: {
                    var maxW = (width  - pad * 2) / cols
                    var maxH = (height - pad * 2 - flipReserve) / 2
                    return Math.max(60, Math.min(maxW, maxH * photoAR))
                }
                property real cellH: Math.max(40, cellW / photoAR)

                // Lưới ảnh sát nhau (trên) + nút Lật Ảnh căn giữa (dưới)
                Column {
                    anchors.centerIn: parent
                    spacing: 24
                    visible: !root.selfBoothMode

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        rows: 2
                        flow: Grid.TopToBottom
                        rowSpacing: 0
                        columnSpacing: 0

                        Repeater {
                            model: photoModel
                            delegate: Item {
                                width:  leftPhotoGrid.cellW
                                height: leftPhotoGrid.cellH
                                clip: true

                                // Reactive: tính lại khi assignedPathsTick đổi
                                property bool isAssigned: { root.assignedPathsTick; return root.isPhotoInAnySlot(model.path) }

                                // Ảnh crop đầy ô — các ô sát nhau thành khối liền
                                Image {
                                    anchors.fill: parent
                                    source: model.path.startsWith("file:///") ? model.path : "file:///" + model.path
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize: Qt.size(480, 480)
                                    mirror: root._photosFlipped
                                    opacity: parent.isAssigned ? 0.45 : 1.0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }

                                    // Lấy tỉ lệ ảnh thật 1 lần để ô khớp đúng AR ảnh
                                    onStatusChanged: {
                                        if (status === Image.Ready && !leftPhotoGrid._arLocked
                                                && implicitWidth > 0 && implicitHeight > 0) {
                                            leftPhotoGrid.photoAR = implicitWidth / implicitHeight
                                            leftPhotoGrid._arLocked = true
                                        }
                                    }
                                }

                                scale: gridPhotoArea.containsMouse ? 1.03 : 1.0
                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                                MouseArea {
                                    id: gridPhotoArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.previewPhotoPath  = model.path
                                        root.previewPhotoIndex = index
                                        root.assignPhotoToSlot(model.path)
                                    }
                                }
                            }
                        }
                    }

                    // Khoảng đệm đẩy hàng nút xuống dưới một chút so với lưới ảnh.
                    Item { width: 1; height: 48 }

                    // Hàng nút dưới lưới: Lật Ảnh + Tiếp Theo (ngang hàng)
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16

                        // Nút Lật Ảnh (chỉ hiện khi bật tính năng lật)
                        Button {
                            id: gridFlipBtn
                            text: root._photosFlipped ? "↔ Bỏ Lật" : "↔ Lật Ảnh"
                            width: 180
                            height: 54
                            visible: root._flipEnabled && !root.isProcessing

                            background: Rectangle {
                                color: gridFlipBtn.hovered
                                       ? (root._photosFlipped ? "#c0392b" : "#27ae60")
                                       : (root._photosFlipped ? "#e74c3c" : "#2ecc71")
                                radius: 10
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            contentItem: Text {
                                text: gridFlipBtn.text
                                color: "white"
                                font.bold: true
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                root._photosFlipped = !root._photosFlipped
                                root.scheduleAutoSave()
                            }
                        }

                        // Nút Tiếp Theo — ngang hàng nút Lật, ngay dưới lưới ảnh
                        Button {
                            id: gridContinueBtn
                            text: "Tiếp Theo ▶"
                            width: 220
                            height: 54
                            visible: !root.isProcessing
                            // Reactive theo assignedPathsTick: bật khi mọi slot đã có ảnh.
                            enabled: { root.assignedPathsTick; return root._areAllSlotsFilled() }

                            background: Rectangle {
                                color: gridContinueBtn.enabled ? "#ad436d" : Theme.border
                                radius: 10
                            }
                            contentItem: Text {
                                text: gridContinueBtn.text
                                color: "white"
                                font.bold: true
                                font.pixelSize: 16
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: root.confirmComposition()
                        }
                    }
                }

                GridView {
                    id: selfPhotoGrid
                    anchors.fill: parent
                    anchors.margins: 24
                    anchors.bottomMargin: 120
                    visible: root.selfBoothMode
                    clip: true
                    model: photoModel
                    cellWidth: width / 2
                    cellHeight: 190
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: selfPhotoDelegate
                        required property int index
                        required property var model
                        width: selfPhotoGrid.cellWidth
                        height: selfPhotoGrid.cellHeight
                        property bool isAssigned: {
                            root.assignedPathsTick
                            return root.isPhotoInAnySlot(model.path)
                        }

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 8
                            radius: 10
                            color: "#171a20"
                            border.color: parent.isAssigned ? "#4ade80" : "#343743"
                            border.width: parent.isAssigned ? 3 : 1

                            Image {
                                anchors.fill: parent
                                anchors.margins: 8
                                source: model.path.startsWith("file:///")
                                        ? model.path : "file:///" + model.path
                                fillMode: Image.PreserveAspectFit
                                asynchronous: true
                                cache: false
                                sourceSize: Qt.size(420, 320)
                                opacity: selfPhotoDelegate.isAssigned ? 0.55 : 1.0
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.margins: 10
                                width: 32; height: 32; radius: 16
                                color: "#CC000000"
                                Text {
                                    anchors.centerIn: parent
                                    text: index + 1
                                    color: "white"; font.bold: true
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: selfPhotoDelegate.isAssigned
                                text: "✓"
                                color: "white"
                                font.pixelSize: 52
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.previewPhotoPath = model.path
                                    root.previewPhotoIndex = index
                                    root.assignPhotoToSlot(model.path)
                                }
                            }
                        }
                    }
                }
            }
        }

        // 3. Photo Strip (Click to assign) — ẩn khi tắt xem lại ảnh
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root._photoReviewEnabled ? 250 : 0
            visible: root._photoReviewEnabled
            color: root.backgroundImagePath !== "" ? "transparent" : Theme.surface

            // Top border
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 1
                color: root.backgroundImagePath !== "" ? Qt.rgba(1, 1, 1, 0.15) : Theme.border
            }

            // Instruction text
            Text {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 4
                text: root.selectedSlotIndex >= 0
                    ? "👆 Chạm ảnh để gán vào ô " + (root.selectedSlotIndex + 1)
                    : "👆 Chạm ảnh để gán vào ô trống tiếp theo"
                color: root.selectedSlotIndex >= 0 ? "#ad436d" : Theme.textMuted
                font.pixelSize: 13
                z: 5
            }

            ListView {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 24
                spacing: 15
                orientation: ListView.Horizontal
                model: photoModel

                delegate: Item {
                    width: 250
                    height: 230

                    // ─ Wrapper Rectangle: viền màu thiết kế và hover ─
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"

                        // Reactive: tính lại mỗi khi assignedPathsTick thay đổi
                        property bool isAssigned: { root.assignedPathsTick; return root.isPhotoInAnySlot(model.path) }

                        border.color: {
                            if (index === root.newPhotoIndex) return "#4caf50"
                            if (isAssigned) return "#2e7d32"
                            if (photoClickArea.containsMouse) return "#4FA4F2"
                            return Theme.border
                        }
                        border.width: {
                            if (index === root.newPhotoIndex) return 3
                            if (isAssigned) return 3
                            if (photoClickArea.containsMouse) return 3
                            return 1
                        }
                        radius: 6

                        Image {
                            id: thumbnail
                            anchors.fill: parent
                            anchors.margins: 2
                            source: {
                                if (model.path.startsWith("file:///")) return model.path
                                return "file:///" + model.path
                            }
                            fillMode: Image.PreserveAspectFit
                            cache: false
                            // asynchronous: 6 thumbnail decode trên thread pool, không block UI
                            asynchronous: true
                            // Thumbnail chỉ hiển thị 250×230px — không load full DSLR (71MB/ảnh × 6 = 426MB)
                            sourceSize: Qt.size(250, 230)
                            mirror: root._photosFlipped
                        }

                        // Photo number label
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.margins: 4
                            width: 24
                            height: 24
                            radius: 12
                            color: "#CC000000"

                            Text {
                                anchors.centerIn: parent
                                text: (index + 1)
                                color: "white"
                                font.pixelSize: 12
                                font.bold: true
                            }
                        }

                        // ── Badge "✓ Mới" khi vừa được chụp lại ───────────────────
                        Rectangle {
                            anchors.top:  parent.top
                            anchors.left: parent.left
                            anchors.margins: 6
                            width:  newBadgeLbl.implicitWidth + 14
                            height: 26
                            radius: 6
                            color:  "#4caf50"
                            visible: index === root.newPhotoIndex
                            z: 10

                            opacity: 1.0
                            SequentialAnimation on opacity {
                                running: index === root.newPhotoIndex
                                PauseAnimation  { duration: 3000 }
                                NumberAnimation { to: 0; duration: 800; easing.type: Easing.InQuad }
                            }

                            Text {
                                id: newBadgeLbl
                                anchors.centerIn: parent
                                text: "✓ Mới"
                                color: "white"
                                font.pixelSize: 11; font.bold: true
                            }
                        }

                        // ── Overlay dấu tích khi ảnh đã được gán vào slot ──────────
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 2
                            radius: 5
                            color: "#B32e7d32"
                            visible: parent.isAssigned
                            z: 8

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "#ffffff"
                                font.pixelSize: 56
                                font.bold: true
                                style: Text.Outline
                                styleColor: "#1b5e20"
                            }
                        }

                        // Hover scale effect
                        scale: photoClickArea.containsMouse ? 1.05 : 1.0
                        Behavior on scale {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        MouseArea {
                            id: photoClickArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                console.log("CompositionScreen: Photo", index, "clicked - assigning")
                                // Update preview immediately
                                root.previewPhotoPath  = model.path
                                root.previewPhotoIndex = index
                                // Assign to slot (existing logic unchanged)
                                root.assignPhotoToSlot(model.path)
                            }
                        }
                    }
                }
            }
        }
    }

    // =========================================================================
    // Processing Overlay – Popup dialog khi nhấn "Tiếp theo"
    // =========================================================================
    Rectangle {
        id: processingOverlay
        anchors.fill: parent
        color: "#CC000000"
        // Dùng visible: alpha > 0 thay vì bind thẳng vào isProcessing
        // → QML không ẩn overlay trước khi fade-out animation hoàn thành
        visible: processingOverlayOpacity.alpha > 0
        z: 100

        // Khóa mọi tương tác bên dưới
        MouseArea {
            anchors.fill: parent
            onClicked: {}   // nuốt click
            onPressed: {}
        }

        // ── Popup card ────────────────────────────────────────────────────────
        Rectangle {
            id: processingCard
            anchors.centerIn: parent
            width:  420
            height: 220
            radius: 20
            color:  Theme.field
            border.color: Theme.border
            border.width: 1

            // Scale-in animation khi xuất hiện (sync với opacity fade)
            scale: 0.85 + processingOverlayOpacity.alpha * 0.15
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 20

                // ── Custom spinner ──
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth:  68
                    implicitHeight: 68

                    RotationAnimator {
                        target: spinnerCircle
                        from:   0
                        to:     360
                        duration: 850
                        loops:  Animation.Infinite
                        running: root.isProcessing
                    }

                    Rectangle {
                        id: spinnerCircle
                        anchors.centerIn: parent
                        width: 60; height: 60
                        radius: 30
                        color: "transparent"
                        border.color: "#4FA4F2"
                        border.width: 5

                        // Dot chạy đầu vòng tròn
                        Rectangle {
                            anchors.top:              parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: -3
                            width: 11; height: 11
                            radius: 6
                            color: "#4FA4F2"
                        }
                    }

                    // Inner pulse
                    Rectangle {
                        anchors.centerIn: parent
                        width: 26; height: 26
                        radius: 13
                        color: "#73B9F5"

                        SequentialAnimation on opacity {
                            running: root.isProcessing
                            loops:   Animation.Infinite
                            NumberAnimation { from: 0.4; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
                            NumberAnimation { from: 1.0; to: 0.4; duration: 600; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                // ── Tiêu đề ──
                Text {
                    text: "Đang ghép ảnh…"
                    color: Theme.text
                    font.pixelSize: 22
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                // ── Phụ đề ──
                Text {
                    text: "Vui lòng chờ, đừng tắt màn hình"
                    color: Theme.textMuted
                    font.pixelSize: 14
                    Layout.alignment: Qt.AlignHCenter
                }
            }
        }

        // ── Opacity fade-in / fade-out ──
        // Lưu ý: không dùng tên 'opacity' cho property tự định nghĩa
        // vì opacity là FINAL property của QQuickItem trong Qt 6
        Item {
            id: processingOverlayOpacity
            property real alpha: root.isProcessing ? 1.0 : 0.0
            Behavior on alpha { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
        }
        opacity: processingOverlayOpacity.alpha
    }

    // ══════════════════════════════════════════════════════════════════════
    // DẢI ẢNH CUỘN NGANG (no-review) — click thumbnail để gán thẳng vào slot
    // ══════════════════════════════════════════════════════════════════════

    // Ảnh proxy cũ cho kéo-thả.
    // Giữ lại component để tránh sửa nhiều cấu trúc, nhưng không còn dùng trong
    // cơ chế gán ảnh mới (click-to-assign).
    Image {
        id: dragProxy
        property string photoPath: ""
        visible: false
        z: 400
        width: 200; height: 200
        opacity: 0.85
        fillMode: Image.PreserveAspectFit
        cache: false
        asynchronous: true
        mirror: root._photosFlipped
        Drag.active: false
        Drag.source: dragProxy
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2
    }

    Item {
        id: rightGridPanel
        visible: root._noReviewGrid && !root.isProcessing
        z: 40
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root._rightGridW

        // 2x3 thumbnails; extra photos add columns and scroll horizontally.
        GridView {
            id: gridView
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -root._rightGridBottomMargin * 0.25 + root._gridShiftDown
            height: Math.min(parent.height - root._rightGridTopMargin - root._rightGridBottomMargin,
                             root._gridRows * cellHeight)
            flow: GridView.FlowTopToBottom
            clip: true
            cellWidth: Math.max(120, Math.floor(width / root._gridColumns))
            cellHeight: Math.max(90, Math.floor((cellWidth - root._gridHorizontalInset * 2) / root._gridThumbAspect))
            model: photoModel
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.HorizontalFlick

            ScrollBar.horizontal: ScrollBar {
                policy: ScrollBar.AsNeeded
                height: 6
            }


            delegate: Item {
                id: cell
                width: gridView.cellWidth
                height: gridView.cellHeight
                property string photoPath: model.path
                property int    photoIndex: index

                Image {
                    id: cellThumb
                    anchors.fill: parent
                    anchors.leftMargin: root._gridHorizontalInset
                    anchors.rightMargin: root._gridHorizontalInset
                    anchors.topMargin: 0
                    anchors.bottomMargin: 0
                    source: model.path.startsWith("file:///") ? model.path : "file:///" + model.path
                    fillMode: Image.PreserveAspectFit
                    cache: false
                    asynchronous: true
                    sourceSize: Qt.size(420, 420)
                    mirror: root._photosFlipped
                }

                MouseArea {
                    id: cellMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.previewPhotoPath = cell.photoPath
                        root.previewPhotoIndex = cell.photoIndex
                        root.assignPhotoToSlot(cell.photoPath)
                    }
                }
            }
        }
    }

    // ── Nút Lật Ảnh (chỉ hiện khi flip_photo_enabled = true) ──────────────
    Button {
        id: flipBtn
        anchors.right: continueBtn.left
        anchors.verticalCenter: continueBtn.verticalCenter
        anchors.rightMargin: 16
        text: root._photosFlipped ? "↔ Bỏ Lật" : "↔ Lật Ảnh"
        z: 50
        width: 150
        height: 54
        // Hiện cạnh nút Tiếp Theo (kể cả no-review — lưới cũ đã ẩn nên dùng nút này).
        visible: root._flipEnabled && !root.isProcessing

        background: Rectangle {
            color: flipBtn.hovered
                   ? (root._photosFlipped ? "#c0392b" : "#27ae60")
                   : (root._photosFlipped ? "#e74c3c" : "#2ecc71")
            radius: 10
            Behavior on color { ColorAnimation { duration: 150 } }
        }
        contentItem: Text {
            text: flipBtn.text
            color: "white"
            font.bold: true
            font.pixelSize: 15
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            root._photosFlipped = !root._photosFlipped
            root.scheduleAutoSave()
        }
    }

    // Done Button - Positioned at bottom right corner
    Button {
        id: selfBackButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 30
        anchors.bottomMargin: 30
        width: 255
        height: 90
        z: 50
        visible: root.selfBoothMode && !root.isProcessing
        text: "◀ Quay lại"
        background: Rectangle {
            color: selfBackButton.pressed ? "#262b36"
                  : selfBackButton.hovered ? "#222732" : "#1a1d27"
            radius: 45
            border.color: Theme.border
            border.width: 2
        }
        contentItem: Text {
            text: selfBackButton.text
            color: Theme.text
            font.pixelSize: 27
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        onClicked: root.backClicked()
    }

    Button {
        id: continueBtn
        // Luôn ở góc dưới bên PHẢI (kể cả no-review — dải ảnh nằm bên trái nút).
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.bottom: parent.bottom
        // Chừa chỗ cho dải ảnh dưới chỉ khi còn hiển thị (xem lại ảnh bật)
        anchors.bottomMargin: 30 + (root._photoReviewEnabled ? 160 : 0)
        text: "Tiếp Theo ▶"
        z: 50
        width: 255
        height: 90
        visible: !root.isProcessing

        // Chỉ bật khi tất cả slot đã có ảnh
        enabled: {
            if (slotsModel.count === 0) return false
            for (var i = 0; i < slotsModel.count; i++) {
                if (!slotsModel.get(i).assignedPath || slotsModel.get(i).assignedPath === "") return false
            }
            return true
        }

        background: Rectangle {
            color: continueBtn.enabled
                ? (continueBtn.pressed ? "#ad436d" : (continueBtn.hovered ? "#ad436d" : "#ad436d"))
                : Theme.border
            radius: 45

            // Pulse animation khi nút active
            SequentialAnimation on scale {
                running: continueBtn.enabled && !continueBtn.hovered
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.04; duration: 900; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.04; to: 1.0; duration: 900; easing.type: Easing.InOutQuad }
            }
        }
        contentItem: Text {
            text: continueBtn.text
            color: "white"
            font.bold: true
            font.pixelSize: 27
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
            autoSaveTimer.stop()  // Không cần auto-save nữa
            console.log("=== [CompositionScreen] Nút 'Tiếp Theo' bấm ===")
            console.log("[CompositionScreen] Tổng slot:", slotsModel.count)
            for (var dbg = 0; dbg < slotsModel.count; dbg++) {
                var dbgSlot = slotsModel.get(dbg)
                console.log("[CompositionScreen] Slot", dbg, "→ assignedPath:", dbgSlot.assignedPath,
                            "| scale:", dbgSlot.imgScale, "| tx:", dbgSlot.imgTx, "| ty:", dbgSlot.imgTy)
            }
            console.log("[CompositionScreen] cachedCollagePath:", root.cachedCollagePath)
            console.log("[CompositionScreen] _preRenderInProgress:", root._preRenderInProgress)
            root.processComposition()
        }
    }
    // =========================================================================
    // Fullscreen Photo Detail Overlay
    // =========================================================================
    Rectangle {
        id: photoDetailOverlay
        anchors.fill: parent
        color: "#EE000000"
        visible: false
        z: 200

        onVisibleChanged: {
            if (visible && root._simplifiedPortrait)
                visible = false
        }

        property string overlayPath:  ""
        property int    overlayIndex: -1

        // Block click-through
        MouseArea { anchors.fill: parent; onClicked: {} }

        // ──── Label ────────────────────────────────────────────────────
        Text {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 30
            text: photoDetailOverlay.overlayIndex >= 0
                  ? "Ảnh #" + (photoDetailOverlay.overlayIndex + 1)
                  : "Ảnh từ slot"
            color: "white"
            font.pixelSize: 22; font.bold: true
            style: Text.Outline; styleColor: "#00000088"
        }

        // ──── Main image ───────────────────────────────────────────────
        Image {
            anchors {
                left: parent.left;   leftMargin:  60
                right: detailPanel.left; rightMargin: 20
                top: parent.top;     topMargin:   60
                bottom: parent.bottom; bottomMargin: 60
            }
            source: {
                if (!photoDetailOverlay.overlayPath) return ""
                if (photoDetailOverlay.overlayPath.startsWith("file:///")) return photoDetailOverlay.overlayPath
                return "file:///" + photoDetailOverlay.overlayPath
            }
            fillMode: Image.PreserveAspectFit
            cache: false
            // asynchronous: mở ảnh fullscreen không block UI thread
            asynchronous: true
            // Fullscreen overlay — giới hạn decode ở kích thước màn hình thay vì DSLR gốc 71MB
            sourceSize: Qt.size(width, height)
            mirror: root._photosFlipped
        }

        // ──── Right panel ─────────────────────────────────────────────
        ColumnLayout {
            id: detailPanel
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 30
            width: 180
            spacing: 12

            Item { Layout.fillHeight: true }

            // ← Quay Lại
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
                    Text { Layout.alignment: Qt.AlignHCenter; text: "←"; color: "white"; font.pixelSize: 22; font.bold: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Quay Lại"; color: "white"; font.pixelSize: 15; font.bold: true }
                }
                onClicked: photoDetailOverlay.visible = false
            }

            // 📷 Chụp Lại — ĐÃ BỎ chức năng chụp lại hoàn toàn → luôn ẩn.
            Button {
                id: retakeDetailBtn
                visible: false
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                background: Rectangle {
                    gradient: Gradient {
                        GradientStop { position: 0; color: retakeDetailBtn.hovered ? "#e04040" : "#c62828" }
                        GradientStop { position: 1; color: retakeDetailBtn.hovered ? "#b03030" : "#8b1a1a" }
                    }
                    radius: 12
                    border.color: "#e05050"; border.width: retakeDetailBtn.hovered ? 1 : 0
                }
                contentItem: ColumnLayout {
                    spacing: 4
                    Text { Layout.alignment: Qt.AlignHCenter; text: "📷"; font.pixelSize: 22 }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Chụp Lại"; color: "white"; font.pixelSize: 15; font.bold: true }
                }
                onClicked: {
                    photoDetailOverlay.visible = false

                    var idx = photoDetailOverlay.overlayIndex

                    // Nếu preview mở từ slot (overlayIndex = -1),
                    // tìm index thực trong photoModel theo path
                    if (idx < 0 && photoDetailOverlay.overlayPath !== "") {
                        var searchPath = photoDetailOverlay.overlayPath
                        // Strip file:/// nếu có để so sánh đồng nhất
                        if (searchPath.startsWith("file:///"))
                            searchPath = searchPath.substring(8)

                        for (var i = 0; i < photoModel.count; i++) {
                            var p = photoModel.get(i).path
                            if (p.startsWith("file:///")) p = p.substring(8)
                            if (p === searchPath) { idx = i; break }
                        }
                    }

                    if (idx >= 0) {
                        console.log("PhotoCompositionScreen: Retake requested for index", idx)
                        root.retakeRequested(idx)
                    } else {
                        console.warn("PhotoCompositionScreen: Could not resolve photo index for retake")
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }
    }
}
