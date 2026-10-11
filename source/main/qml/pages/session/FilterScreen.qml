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

    // ── Public API ───────────────────────────────────────────────────────────
    property string collagePath: ""   // ảnh preview (có thể bị cập nhật thành raw strip ở cut mode)
    property string layoutPath:  ""   // file PNG frame/template để re-overlay
    property int    eventId:     -1
    property var    eventData:   null
    property string selectedCategory: ""
    // Dữ liệu để compose ảnh cuối khi bấm Tiếp tục
    property var    photos:      []   // danh sách ảnh gốc
    property var    transforms:  []   // [{scale, tx, ty}, ...]
    property string sessionId:   ""
    // Lưu collagePath gốc (cut canvas hoặc single strip) — không thay đổi khi _previewUpdateFilter cập nhật collagePath.
    // Dùng để tránh gọi lại processCollageWithTransforms khi không chọn filter.
    property string _originalCollagePath: ""

    signal filterComplete(string finalPath, string filteredStrip)  // finalPath = ready-to-print, filteredStrip = single no-cut strip (or "" if no filter)
    signal frameSelected(string framePath)
    signal closeClicked()
    // Bấm "In Ảnh" → BoothSession điều hướng sang WaitingResults (in chạy nền ở màn này).
    signal printRequested(string finalPath, string filteredStrip)
    signal finalPrintImageReady(string finalPath)

    // ── QR + In ảnh (gộp từ ResultScreen) ───────────────────────────────────
    property string hwid: ""
    property string qrImageUrl: (sessionId !== "" && hwid !== "")
        ? ("image://qr/" + encodeURIComponent(s3Uploader.buildSessionUrl(hwid, eventId, sessionId)))
        : ""
    // Print state
    property bool   isPrinting: false
    property string printStatus: ""
    property string printError: ""
    property bool   lastPrintCutMode: false
    property int    lastPrintPhotos: 0
    property bool   pendingPrintCutMode: false
    property int    pendingPrintPhotos: 1
    property string _lastAutoScanPath: ""   // path đã gửi cho printer, dùng lại khi auto-scan
    property bool   _autoScanActive: false
    property bool   _awaitingQr: false       // đang chờ applyQrOverlayAsync trả kết quả
    // Pre-payment (đã thanh toán ở PrintQuantityScreen → in thẳng, không hỏi)
    property bool   prePaymentDone: false
    property bool   prePaymentCutMode: false
    property int    prePaymentCopies: 1
    property bool   _prePaymentPrintRequested: false
    // Ảnh cuối đã finalize (giữ giữa bước tính toán composite và bước in)
    property string _finalPrintPath: ""      // ảnh ready-to-print (≈ collagePath của ResultScreen)
    property string _finalDisplayPath: ""    // strip no-cut để vẽ QR (≈ displayPath của ResultScreen)

    // In tự do (Free Print): ghi đè lệnh in trong phiên — gửi ảnh khung nguyên trạng
    // tới máy in đã chọn, luôn không cắt, để driver tự scale theo khổ.
    property bool   _freePrintEnabled: eventManager.getAppSetting("free_print_enabled", "false") === "true"
    property string _freePrintPrinter: eventManager.getAppSetting("free_print_printer", "")
    property string _freePrintRotation: eventManager.getAppSetting("free_print_rotation", "0")

    property bool _paymentEnabled: eventManager.getAppSetting("payment_enabled", "false") === "true"
    property string _effectiveCategory: selectedCategory !== "" ? selectedCategory : categoryOfPath(layoutPath)
    property bool _isMode3: eventManager.getAppSetting("app_operation_mode", "mode1") === "mode3"
    property bool _mode3FramePicker: _isMode3 && _effectiveCategory !== ""
    // Bố cục 3 cột (frame trái | layout giữa | filter + sticker phải) — chỉ ở mode3 màn ngang.
    property bool _mode3Layout: _isMode3 && !root.portrait
    // Sticker chỉ hoạt động khi BẬT cả filter lẫn sticker
    property bool _stickerEnabled: eventManager.getAppSetting("sticker_enabled", "false") === "true"
    // Mode3 luôn có cột sticker, không phụ thuộc cài đặt sticker_enabled.
    property bool _stickerActive: _stickerEnabled || _isMode3
    property bool _leftPanelVisible: (_stickerEnabled || _mode3FramePicker) && !_mode3Layout
    // Tăng mỗi lần categoryFrameModel được nạp lại — xem reloadCategoryFrames().
    property int    _frameRev: 0
    // Trạng thái danh sách frame đang giữ trong model, dùng để bỏ qua reload thừa.
    property string _frameListSig: ""
    property int    _frameListEventId: -1
    property string _frameListCategory: ""

    // ── Bố cục 3 cột Mode 3 ──────────────────────────────────────────────────
    // Kích thước lấy từ singleton Mode3Layout (theme/) — sửa bố cục thì sửa ở đó,
    // vì Mode3ThumbPreloader cũng đọc cùng chỗ để nạp cache đúng kích thước.
    readonly property int  _m3Circle:       Mode3Layout.circle
    readonly property int  _m3ColWidth:     Mode3Layout.colWidth
    readonly property int  _m3SideMargin:   Mode3Layout.sideMargin
    readonly property int  _m3RowSpacing:   Mode3Layout.rowSpacing
    readonly property int  _m3ColsPerRow:   Mode3Layout.colsPerRow
    readonly property int  _m3FrameRows:    Mode3Layout.frameRows
    readonly property int  _m3FilterRows:   Mode3Layout.filterRows
    readonly property real _m3ItemSpacing:  Mode3Layout.itemSpacing
    readonly property int  _m3RowHeight:    Mode3Layout.circle

    // Đặt 2 cột sao cho ĐÁY cột phải chạm bottomBar → toàn bộ khoảng trống dồn lên
    // trên cho phần chữ vẽ sẵn trên ảnh nền. Với số hiện tại: y = 920 - 539 = 381.
    // Vị trí này CỐ ĐỊNH, không phụ thuộc có bao nhiêu frame/filter/sticker, để không
    // bao giờ lệch khỏi chữ trên ảnh nền.
    readonly property int _m3TopY: bottomBar.y - Mode3Layout.rightColHeight + Mode3Layout.topOffset
    // Chia đều item cho các hàng; hàng nào vượt _m3ColsPerRow thì cuộn ngang.
    readonly property int _m3FramePerRow: Math.max(_m3ColsPerRow,
                                                   Math.ceil(categoryFrameModel.count / _m3FrameRows))
    readonly property int _m3FilterPerRow: Math.max(_m3ColsPerRow,
                                                    Math.ceil((filterListModel.count + 1) / _m3FilterRows))

    // Sticker đã đặt lên preview. Toạ độ chuẩn hoá theo VÙNG ẢNH hiển thị (0..1).
    // xN,yN = tâm; wN = bề rộng / ảnh; rot = độ.
    ListModel { id: placedStickers }
    property int _selectedStickerIndex: -1

    function addSticker(path) {
        placedStickers.append({ "path": path, "xN": 0.5, "yN": 0.5, "wN": 0.25, "rot": 0.0 })
        root._selectedStickerIndex = placedStickers.count - 1
    }
    function removeSticker(idx) {
        if (idx < 0 || idx >= placedStickers.count) return
        placedStickers.remove(idx)
        root._selectedStickerIndex = -1
    }

    // ── Internal state ───────────────────────────────────────────────────────
    property string selectedFilterId: ""     // "" = không filter
    property string previewPath:      ""     // ảnh đang hiển thị (file:/// URL)
    property bool   isApplying:       false
    property bool   isProcessingFinal: false  // đang tạo ảnh cuối khi Tiếp tục
    property string applyError:       ""
    // true khi BoothSession đang tạo raw strip (cut mode) — disable filter selection
    property bool   _previewLoading:  false
    property string selectedFramePath: layoutPath
    property bool   _frameChanged: false

    // Khi BoothSession cập nhật collagePath từ ngoài (cut mode — raw strip về sau),
    // và user chưa chọn filter thì update preview ngay
    onCollagePathChanged: {
        if (collagePath !== "" && selectedFilterId === "" && !isApplying) {
            previewPath = toUrl(collagePath)
        }
    }

    // Derived theme
    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)

    // Convert Windows local path → file:/// URL for QML Image
    function toUrl(path) {
        if (!path || path === "") return ""
        if (path.startsWith("file:")
                || path.startsWith("qrc:")
                || path.startsWith("image:")
                || path.startsWith("http://")
                || path.startsWith("https://"))
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    // Strip file:/// back to local path for C++ consumption
    function toLocalPath(url) {
        return url.replace(/\?t=\d+$/, "").replace(/^file:\/{3}/, "").replace(/\//g, "\\")
    }

    function samePath(a, b) {
        return toLocalPath(a || "").toLowerCase() === toLocalPath(b || "").toLowerCase()
    }

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
        return path ? eventManager.getAppSetting(frameImageKey(path), "") : ""
    }

    function frameDisplayPath(path) {
        var img = frameImagePath(path)
        return img !== "" ? img : path
    }

    function categoryOf(fileName) {
        var base = (fileName || "").replace(/\.png$/i, "")
        var idx = base.indexOf("__")
        return idx > 0 ? base.substring(0, idx) : "Khác"
    }

    function fileNameOf(path) {
        var p = (path || "").replace(/\?t=\d+$/, "").replace(/^file:\/{3}/, "")
        p = p.replace(/\\/g, "/")
        var idx = p.lastIndexOf("/")
        return idx >= 0 ? p.substring(idx + 1) : p
    }

    function categoryOfPath(path) {
        var file = fileNameOf(path)
        return file !== "" ? categoryOf(file) : ""
    }

    // categoryFrameModel đã chứa đúng frame này chưa? (so theo đường dẫn cục bộ)
    function _frameModelHas(localLower) {
        if (localLower === "") return false
        for (var i = 0; i < categoryFrameModel.count; i++) {
            if (root.toLocalPath(categoryFrameModel.get(i).path).toLowerCase() === localLower)
                return true
        }
        return false
    }

    // Nạp danh sách frame cùng nhóm cho Mode 3.
    //
    // Hàm này chạy lại MỖI LẦN người dùng chọn frame (onLayoutPathChanged). Nếu cứ
    // clear() rồi append() lại thì toàn bộ delegate bị huỷ và tạo mới → thumbnail phải
    // giải mã lại, các hàng mất vị trí cuộn, màn hình nháy. Trong khi chọn frame KHÔNG
    // hề làm đổi danh sách. Vì vậy có 2 lớp chặn trước khi đụng vào model:
    //   1. Đường tắt: cùng event + cùng nhóm + frame đang chọn đã nằm trong danh sách
    //      → thoát ngay, khỏi đọc lại thư mục Layouts từ ổ đĩa.
    //   2. So chữ ký nội dung: dựng danh sách vào mảng tạm, chỉ dựng lại model khi
    //      nội dung thực sự khác.
    function reloadCategoryFrames() {
        if (!root._mode3FramePicker || root.eventId <= 0) {
            if (categoryFrameModel.count > 0) {
                categoryFrameModel.clear()
                root._frameListSig = ""
                root._frameRev++
            }
            return
        }

        var category = root._effectiveCategory
        var selectedLocal = root.toLocalPath(root.selectedFramePath || root.layoutPath).toLowerCase()

        // ── Lớp chặn 1 ──
        if (categoryFrameModel.count > 0
                && root._frameListEventId === root.eventId
                && root._frameListCategory === category
                && root._frameModelHas(selectedLocal))
            return

        // Dựng vào mảng tạm — chưa đụng tới model.
        var rows = []
        var hasSelected = false
        var layouts = eventManager.getLayouts(root.eventId)
        for (var i = 0; i < layouts.length; i++) {
            var item = layouts[i]
            if (categoryOf(item.fileName) !== category) continue
            rows.push({
                "fileName": item.fileName,
                "path": item.path,
                "displayPath": frameDisplayPath(item.path),
                "slotCount": item.metadata && item.metadata.slot_count ? item.metadata.slot_count : 0
            })
            if (root.toLocalPath(item.path).toLowerCase() === selectedLocal) hasSelected = true
        }
        if (!hasSelected && root.layoutPath !== "") {
            rows.unshift({
                "fileName": fileNameOf(root.layoutPath),
                "path": root.layoutPath,
                "displayPath": frameDisplayPath(root.layoutPath),
                "slotCount": 0
            })
        }

        // ── Lớp chặn 2 ──
        var sig = ""
        for (var s = 0; s < rows.length; s++)
            sig += rows[s].path + "|" + rows[s].displayPath + ";;"
        if (sig === root._frameListSig && categoryFrameModel.count === rows.length) {
            root._frameListEventId  = root.eventId
            root._frameListCategory = category
            return
        }

        categoryFrameModel.clear()
        for (var r = 0; r < rows.length; r++)
            categoryFrameModel.append(rows[r])

        root._frameListSig      = sig
        root._frameListEventId  = root.eventId
        root._frameListCategory = category
        // ListModel.get() trong delegate KHÔNG tạo binding vào nội dung model →
        // tăng _frameRev để delegate lấy lại dữ liệu thay vì giữ row đã bị clear().
        root._frameRev++
        console.log("[FilterScreen] Mode3 frames loaded:", categoryFrameModel.count,
                    "| category:", category, "| selected:", root.layoutPath)
    }

    function selectFrame(framePath) {
        if (!framePath || framePath === "" || samePath(framePath, root.selectedFramePath)) return
        eventManager.ensureLayoutMetadata(framePath)
        root.selectedFramePath = framePath
        root.layoutPath = framePath
        root._frameChanged = true
        root.applyError = ""
        root._previewLoading = true
        root.frameSelected(framePath)

        if (root.selectedFilterId !== "") {
            filterDebounceTimer.pendingFilterId = root.selectedFilterId
            filterDebounceTimer.restart()
        }
    }

    onSelectedCategoryChanged: Qt.callLater(reloadCategoryFrames)
    onLayoutPathChanged: {
        if (!root._frameChanged)
            root.selectedFramePath = layoutPath
        Qt.callLater(reloadCategoryFrames)
    }

    // ── In ảnh (port từ ResultScreen) ───────────────────────────────────────
    function preparePrePaymentPrint() {
        if (!root.prePaymentDone) return true
        if (!root._finalPrintPath || root._finalPrintPath === "") {
            root.printError = "Image path is empty"
            return false
        }
        // In tự do luôn không cắt → mỗi bản là 1 tờ.
        root.pendingPrintCutMode = root._freePrintEnabled ? false : root.prePaymentCutMode
        var sheets = root.prePaymentCopies
        root.pendingPrintPhotos = root.pendingPrintCutMode
            ? sheets * printOptionsDialog.photosPerSheet
            : sheets
        return true
    }

    function executePrint() {
        root._autoScanActive = false
        root._awaitingQr = false
        // In tự do: ép không cắt bất kể lựa chọn ở hộp thoại / pre-payment.
        if (root._freePrintEnabled) root.pendingPrintCutMode = false
        var cutMode = root.pendingPrintCutMode
        var photos = root.pendingPrintPhotos
        var imagePath = root._finalPrintPath

        if (!imagePath || imagePath === "") {
            root.printError = "Image path is empty"
            printOptionsDialog.close()
            return
        }

        printOptionsDialog.close()
        // Bấm In → điều hướng NGAY sang WaitingResults; việc in tiếp tục chạy nền ở màn này.
        root.printRequested(root._finalPrintPath, root._finalDisplayPath)
        if (root.prePaymentDone) root._prePaymentPrintRequested = true

        root.isPrinting = true
        root.printError = ""
        root.printStatus = "Processing..."
        root.lastPrintCutMode = cutMode
        root.lastPrintPhotos = photos

        // Burn QR vào bản in (nếu bật) — chạy async, kết quả về onQrOverlayReady().
        if (overlayArea.showQrInPrint && overlayArea.qrUrlPath !== "") {
            if (!overlayArea.hasUsablePrintPosition())
                overlayArea.calculateInitialPosition()
            var nx = overlayArea.printNormalizedX()
            var ny = overlayArea.printNormalizedY()
            var nw = overlayArea.printNormalizedW()
            var nh = overlayArea.printNormalizedH()
            root._awaitingQr = true
            var hasSingleStrip = root._finalDisplayPath !== ""
                                 && !root.samePath(root._finalDisplayPath, root._finalPrintPath)
            if (cutMode && !root._freePrintEnabled && hasSingleStrip) {
                eventManager.applyQrOverlayRectAsync(root._finalDisplayPath, overlayArea.qrUrlPath, "cutstrip", nx, ny, nw, nh, root.eventId)
            } else {
                eventManager.applyQrOverlayRectAsync(imagePath, overlayArea.qrUrlPath, "single", nx, ny, nw, nh, root.eventId)
            }
        } else {
            root._sendToPrinter(imagePath)
        }
    }

    function _sendToPrinter(imagePath) {
        var cleanPath = imagePath.toString().replace(/^(file:\/{3})|(file:)/, "")
        if (Qt.platform.os === "windows") cleanPath = cleanPath.replace(/^(file:\/\/\/)/, "")
        cleanPath = decodeURIComponent(cleanPath)
        root._lastAutoScanPath = cleanPath
        // In tự do: gửi thẳng tới máy in đã chọn, driver tự scale, luôn không cắt.
        if (root._freePrintEnabled && root._freePrintPrinter !== "") {
            printerManager.printFreeMode(cleanPath, root._freePrintPrinter,
                                         parseInt(root._freePrintRotation) || 0, root.lastPrintPhotos)
            return
        }
        var paperSize = root.eventData && root.eventData.paperSize ? root.eventData.paperSize : "6x4"
        printerManager.printImageWithSettings(cleanPath, root.lastPrintPhotos, paperSize, 300,
                                              root.lastPrintCutMode, false)
    }

    // QR overlay async hoàn thành → gửi in.
    Connections {
        target: eventManager
        function onQrOverlayReady(resultPath) {
            if (!root._awaitingQr) return
            root._awaitingQr = false
            root._finalPrintPath = resultPath
            root._finalDisplayPath = resultPath
            root.finalPrintImageReady(resultPath)
            root._sendToPrinter(resultPath)
        }
    }

    // Kết quả in + auto-scan khi máy in mặc định không phản hồi.
    Connections {
        target: printerManager
        function onPrintFinished(success, message) {
            // In tự do dùng đúng máy in đã chọn — không quét fallback máy DNP khi lỗi.
            if (!success && !root._autoScanActive && !root._freePrintEnabled) {
                root._autoScanActive = true
                var sheetsToSend = root.pendingPrintCutMode
                    ? Math.ceil(root.pendingPrintPhotos / printOptionsDialog.photosPerSheet)
                    : root.pendingPrintPhotos
                printerManager.autoFindAndPrint(
                    root._lastAutoScanPath, sheetsToSend, root.pendingPrintCutMode, 300)
                return
            }
            root.isPrinting = false
            root._autoScanActive = false
            autoScanPopupCloseTimer.start()
            if (success) {
                root.printStatus = message
                root.printError = ""
                if (root.eventId > 0 && root.lastPrintPhotos > 0)
                    eventManager.incrementPrintCount(root.eventId, root.lastPrintPhotos, root.lastPrintCutMode)
                printSuccessTimer.start()
            } else {
                root.printError = message
                root.printStatus = ""
            }
        }
        function onErrorOccurred(error) {
            root.isPrinting = false
            root._autoScanActive = false
            autoScanPopup.visible = false
            root.printError = error
            root.printStatus = ""
        }
        function onAutoPrintScanStarted() {
            autoScanPopup.visible = true
            autoScanStatusText.text = "Đang quét máy in..."
        }
        function onAutoPrintScanProgress(message) { autoScanStatusText.text = message }
        function onAutoPrintScanFinished(success, printerName) {
            if (success) autoScanStatusText.text = "Đang in ảnh..."
            else         autoScanPopup.visible = false
        }
    }

    // Lưới an toàn: nếu raw strip (cut mode) không về, _previewLoading sẽ khoá nút
    // "In Ảnh" vĩnh viễn. Sau 15s tự mở khoá để phiên không bị kẹt.
    Timer {
        id: previewLoadingGuard
        interval: 15000
        repeat: false
        running: root._previewLoading
        onTriggered: {
            console.warn("[FilterScreen] Preview timeout — mở khoá nút In Ảnh")
            root._previewLoading = false
        }
    }

    Timer { id: printSuccessTimer; interval: 3000; onTriggered: root.printStatus = "" }
    Timer { id: autoScanPopupCloseTimer; interval: 1500; repeat: false; onTriggered: autoScanPopup.visible = false }

    // ── Đếm ngược phiên (chỉ ở chế độ thanh toán) ─────────────────────────────
    // Hết giờ → tự bấm "In Ảnh" với bộ lọc đang chọn (giữ nguyên logic nút).
    Timer {
        id: filterCountdownTimer
        property int remaining: parseInt(eventManager.getAppSetting("filter_screen_countdown", "240")) || 240
        interval: 1000
        repeat: true
        running: root._paymentEnabled
                 && root.StackView.status === StackView.Active
                 && !root.isPrinting
                 && !root.isProcessingFinal
                 && remaining > 0
        onTriggered: {
            remaining--
            if (remaining <= 0 && filterContinueBtn.enabled)
                filterContinueBtn.clicked()
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
        text: filterCountdownTimer.remaining + "s"
        color: "#8B5A2B"
        font.pixelSize: 40
        font.bold: true
        style: Text.Normal
    }

    // Khi mở trang, hiển thị ảnh gốc và load danh sách filter
    Component.onCompleted: {
        _originalCollagePath = collagePath   // lưu trước khi collagePath có thể bị cập nhật bởi _previewUpdateFilter
        previewPath      = toUrl(collagePath)
        selectedFilterId = ""
        filterListModel.reload()
        reloadCategoryFrames()
        if (root._stickerActive) stickerLibModel.reload()
        // Yêu cầu GC giải phóng QImage của PhotoCompositionScreen slot photos vừa bị destroy
        gc()
    }

    // ── Debounce timer: đợi 350ms sau lần click cuối mới thực sự apply filter ──
    // Ngăn người dùng click nhanh nhiều filter tạo ra nhiều QtConcurrent thread đồng thời
    // → CPU spike. Mỗi click mới restart timer, chỉ click cuối được apply.
    Timer {
        id: filterDebounceTimer
        interval: 350
        repeat: false
        property string pendingFilterId: ""
        onTriggered: {
            if (pendingFilterId === "") return
            root.isApplying = true
            // Filter ĐÚNG CÁCH: áp LUT lên từng ảnh slot gốc rồi overlay frame lại.
            // Frame (kể cả hoạ tiết đè lên slot) không bị ám màu filter.
            var autoCut = !!(root.eventData && root.eventData.autoCut)
            var printerHint = (typeof printerConfig !== "undefined" && printerConfig)
                              ? printerConfig.selectedPrinter : ""
            filterManager.applyFilterToCompositionAsync(
                root.photos, pendingFilterId, root.layoutPath, root.transforms,
                autoCut, printerHint)
        }
    }

    // ── Filter result handler ─────────────────────────────────────────────────
    Connections {
        target: filterManager
        function onFilterApplyComplete(success, outputPath) {
            root.isApplying = false
            console.log("[FilterScreen] onFilterApplyComplete: success=" + success + " | outputPath=" + outputPath)
            if (success) {
                root.previewPath = toUrl(outputPath) + "?t=" + Date.now()
                root.applyError  = ""
                console.log("[FilterScreen] previewPath updated to:", root.previewPath)
            } else {
                root.applyError  = "Áp dụng filter thất bại"
                root.previewPath = toUrl(root.collagePath)
            }
        }
    }

    // ── Filter list model ────────────────────────────────────────────────────
    property bool showingFavoritesOnly: false

    ListModel {
        id: filterListModel
        function reload() {
            filterListModel.clear()
            var favs = filterManager.getFavoriteFilters()
            if (favs.length > 0) {
                root.showingFavoritesOnly = true
                for (var i = 0; i < favs.length; i++)
                    filterListModel.append(favs[i])
            } else {
                root.showingFavoritesOnly = false
                var filters = filterManager.getFilters()
                for (var j = 0; j < filters.length; j++)
                    filterListModel.append(filters[j])
            }
        }
    }

    ListModel { id: categoryFrameModel }

    // Thư viện sticker (từ StickerManager) để chọn dán lên ảnh
    ListModel {
        id: stickerLibModel
        function reload() {
            stickerLibModel.clear()
            var list = stickerManager.getStickers()
            for (var i = 0; i < list.length; i++)
                stickerLibModel.append(list[i])
        }
    }

    // ── Background ───────────────────────────────────────────────────────────
    property string _bgImagePath: {
        var s = eventManager.getAppSetting("filter_screen_bg_image", "")
        return s !== "" ? s : "qrc:/assets/filter.png"
    }

    Rectangle {
        anchors.fill: parent
        color: root._themeBg
        visible: root._bgImagePath === ""
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root._bgImagePath
        visible: root._bgImagePath !== ""
    }

    // ── Top bar ──────────────────────────────────────────────────────────────
    Item {
        id: topBar
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 80

        Text {
            anchors.centerIn: parent
            text: ""
            color: Theme.text; font.pixelSize: 26; font.weight: Font.Bold
        }

        // Nút X tròn — ĐÃ ẨN: trong flow chỉnh filter không cho thoát phiên bằng
        // nút X (tránh bấm nhầm giữa chừng). Chỉ điều hướng bằng Back/Confirm.
        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 20
            width: 52; height: 52; radius: 26
            visible: false
            color: closeFilterArea.containsMouse ? "#c0392b" : "#e74c3c"
            border.color: "white"; border.width: 2
            z: 20
            Behavior on color { ColorAnimation { duration: 120 } }

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: "white"; font.pixelSize: 22; font.bold: true
            }
            MouseArea {
                id: closeFilterArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.closeClicked()
            }
        }
    }

    // ── Right panel: cụm frame Mode 3 + Bộ lọc màu + Sticker ──────────────────
    // (Đã chuyển sang phải; layout/preview hiển thị bên trái.)
    Rectangle {
        id: leftPanel
        visible: root._leftPanelVisible
        anchors.top:    topBar.bottom
        // Dời panel xuống một chút (ngang hàng với layout) ở chế độ ngang.
        anchors.topMargin: root.portrait ? 0 : 40
        anchors.right:  parent.right
        anchors.bottom: bottomBar.top
        width: 540
        color: "transparent"

        states: [
            State {
                when: root.portrait
                AnchorChanges {
                    target: leftPanel
                    anchors.top: undefined
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: bottomBar.top
                }
                PropertyChanges {
                    leftPanel.height: Math.min(560, Math.max(420, root.height * 0.30))
                }
            },
            State {
                when: !root.portrait
                AnchorChanges {
                    target: leftPanel
                    anchors.top: topBar.bottom
                    anchors.left: undefined
                    anchors.right: parent.right
                    anchors.bottom: bottomBar.top
                }
                PropertyChanges {
                    leftPanel.width: 540
                }
            }
        ]

        Rectangle {
            anchors.left: parent.left
            width: 1
            height: parent.height
            color: "#442a2d35"
            visible: !root.portrait
        }

        Rectangle {
            anchors.top: parent.top
            width: parent.width
            height: 1
            color: "#442a2d35"
            visible: root.portrait
        }

        // Tính số hàng filter (4 hàng) và sticker (3 hàng), mỗi hàng 5 thumbnail
        // Thumbnail filter: 64x78 + spacing 6 => cuộn ngang nếu >5 item/hàng
        // Thumbnail sticker: 64x64 + spacing 6

        property int _thumbW:  root.portrait ? 132 : 96
        property int _thumbH:  root.portrait ? 162 : 117
        property int _stkThumbW: root.portrait ? 132 : 96
        property int _stkThumbH: root.portrait ? 132 : 96
        property int _frameThumbW: root.portrait ? 132 : 96
        property int _frameThumbH: root.portrait ? 180 : 126
        property int _thumbSpacing: root.portrait ? 8 : 6
        property int _rowsFilter:  4
        property int _rowsSticker: 3
        // Số thumbnail hiển thị cùng lúc trên 1 hàng (tối thiểu) — quyết định bề rộng panel.
        property int _visiblePerRow: 5
        // Số item mỗi hàng "ôm": chia đều trên các hàng; nếu vượt _visiblePerRow thì
        // hàng đó CUỘN NGANG để xem hết các filter/sticker còn lại.
        property int _filterPerRow:  Math.max(_visiblePerRow, Math.ceil(_totalFilterItems / _rowsFilter))
        property int _stickerPerRow: Math.max(_visiblePerRow, Math.ceil(stickerLibModel.count / _rowsSticker))

        // Mảng từng hàng filter (bao gồm item "Gốc" ở index 0)
        // Mỗi hàng: indices từ filterWithOrigin model
        // filterWithOrigin = [{id:"",name:"Gốc",...}, ...filterListModel]
        // Ta dùng computed row slices bằng cách map index qua delegate

        // Tổng số filter items kể cả "Gốc"
        property int _totalFilterItems: filterListModel.count + 1

        ScrollView {
            anchors.fill: parent
            anchors.margins: 10
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Column {
                width: root.portrait ? Math.min(leftPanel.width - 20, 760) : leftPanel.width - 20
                x: root.portrait ? Math.max(0, (leftPanel.width - width) * 0.5) : 0
                spacing: 14

                // ══ Khung frame cho Chế độ 3 ══
                Column {
                    width: parent.width
                    spacing: 8
                    visible: root._mode3FramePicker

                    Text {
                        text: "Khung frame"
                        color: Theme.text; font.pixelSize: 15; font.weight: Font.Bold
                    }

                    GridView {
                        id: frameGrid
                        width: parent.width
                        // Tối đa 2 hàng × 4 cột hiển thị cùng lúc; vuốt NGANG để xem/chọn thêm.
                        flow: GridView.FlowTopToBottom
                        cellWidth: Math.floor(width / 4)
                        cellHeight: leftPanel._frameThumbH + leftPanel._thumbSpacing
                        height: categoryFrameModel.count > 0
                                ? Math.min(2, categoryFrameModel.count) * cellHeight
                                : 38
                        interactive: true
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick
                        model: categoryFrameModel

                        ScrollBar.horizontal: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            height: 4
                        }

                        delegate: Item {
                            width: frameGrid.cellWidth
                            height: frameGrid.cellHeight

                            property bool selected: root.samePath(root.selectedFramePath, model.path)

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: leftPanel._thumbSpacing / 2
                                radius: 4
                                color: "transparent"
                                border.color: selected ? "#4FA4F2" : "transparent"
                                border.width: selected ? 2 : 0
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: selected ? 4 : 0
                                    source: root.toUrl(model.displayPath && model.displayPath !== "" ? model.displayPath : model.path)
                                    fillMode: Image.PreserveAspectFit
                                    asynchronous: true
                                    cache: false
                                    sourceSize.width: 140
                                    sourceSize.height: 180
                                }

                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 2
                                    width: 16; height: 16; radius: 8
                                    color: "transparent"
                                    visible: false
                                    Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 9; font.bold: true }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.selectFrame(model.path)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: categoryFrameModel.count === 0
                        text: root._effectiveCategory !== ""
                              ? "Chưa có frame trong nhóm " + root._effectiveCategory + "."
                              : "Chưa xác định được nhóm frame."
                        color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap
                    }

                    Rectangle { width: parent.width; height: 1; color: "#553a3d45" }
                }

                // ══ Bộ lọc màu ══
                Text {
                    text: "Bộ lọc màu"
                    color: Theme.text; font.pixelSize: 15; font.weight: Font.Bold
                }

                // 4 hàng filter, mỗi hàng cuộn ngang, hiển thị 5 thumbnail đại diện
                Column {
                    width: parent.width
                    spacing: leftPanel._thumbSpacing

                    Repeater {
                        model: leftPanel._rowsFilter
                        delegate: Item {
                            id: filterRowItem
                            property int rowIndex: index
                            // startIdx trong danh sách gốc+filter (0 = "Gốc")
                            property int startIdx: rowIndex * leftPanel._filterPerRow
                            property int endIdx:   Math.min(startIdx + leftPanel._filterPerRow - 1,
                                                            leftPanel._totalFilterItems - 1)
                            property int rowCount: Math.max(0, endIdx - startIdx + 1)

                            width: parent.width
                            height: rowCount > 0 ? leftPanel._thumbH : 0
                            visible: rowCount > 0

                            ListView {
                                id: filterRowList
                                anchors.fill: parent
                                orientation: ListView.Horizontal
                                spacing: leftPanel._thumbSpacing
                                clip: true
                                interactive: filterRowItem.rowCount > leftPanel._visiblePerRow
                                model: filterRowItem.rowCount

                                ScrollBar.horizontal: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    height: 4
                                }

                                delegate: Item {
                                    property int globalIdx: filterRowItem.startIdx + index
                                    property bool isOrigin: globalIdx === 0
                                    // filter data: globalIdx-1 trong filterListModel
                                    property var fdata: (!isOrigin && globalIdx - 1 < filterListModel.count)
                                                        ? filterListModel.get(globalIdx - 1) : null
                                    property string fid:   isOrigin ? "" : (fdata ? fdata.id : "")
                                    property string fname: isOrigin ? "Gốc" : (fdata ? fdata.name : "")
                                    property string fthumb: isOrigin ? "" : (fdata ? fdata.thumbnailPath : "")
                                    property bool selected: root.selectedFilterId === fid && (isOrigin ? root.selectedFilterId === "" : true)

                                    width:  leftPanel._thumbW
                                    height: leftPanel._thumbH

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 5
                                        color: "transparent"
                                        border.color: (isOrigin ? root.selectedFilterId === "" : root.selectedFilterId === fid)
                                                      ? "#6c5ce7" : "transparent"
                                        border.width: (isOrigin ? root.selectedFilterId === "" : root.selectedFilterId === fid) ? 2 : 0
                                        clip: true

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: (isOrigin ? root.selectedFilterId === "" : root.selectedFilterId === fid) ? 4 : 0
                                            spacing: 0

                                            // Thumbnail area
                                            Rectangle {
                                                width: parent.width
                                                height: parent.height
                                                color: "transparent"; radius: 5; clip: true

                                                // Origin icon
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "✕"
                                                    color: root.selectedFilterId === "" ? "#6c5ce7" : Theme.textMuted
                                                    font.pixelSize: 20; font.bold: true
                                                    visible: isOrigin
                                                }

                                                // Filter thumbnail
                                                Image {
                                                    anchors.fill: parent
                                                    source: (!isOrigin && fthumb !== "") ? toUrl(fthumb) : ""
                                                    fillMode: Image.PreserveAspectCrop
                                                    cache: false
                                                    visible: !isOrigin && fthumb !== ""
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "🎨"; font.pixelSize: 18
                                                    visible: !isOrigin && fthumb === ""
                                                }

                                                // Selected checkmark
                                                Rectangle {
                                                    anchors.top: parent.top; anchors.right: parent.right
                                                    anchors.margins: 2
                                                    width: 16; height: 16; radius: 8
                                                    color: "transparent"
                                                    visible: false
                                                    Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 9; font.bold: true }
                                                }
                                            }

                                            // Name label
                                            Text {
                                                width: parent.width
                                                height: 0
                                                visible: false
                                                text: fname
                                                color: "white"; font.pixelSize: 9
                                                elide: Text.ElideRight
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (isOrigin) {
                                                    root.selectedFilterId = ""
                                                    root.previewPath = toUrl(root.collagePath)
                                                    root.applyError = ""
                                                } else {
                                                    if (root.selectedFilterId === fid && !filterDebounceTimer.running) return
                                                    root.selectedFilterId = fid
                                                    root.applyError = ""
                                                    filterDebounceTimer.pendingFilterId = fid
                                                    filterDebounceTimer.restart()
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Empty state filters
                Text {
                    width: parent.width
                    visible: filterListModel.count === 0
                    text: root.showingFavoritesOnly
                          ? "Chưa có filter yêu thích.\nVào Cài Đặt → ☆ để chọn."
                          : "Chưa có bộ lọc nào."
                    color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap
                }

                // Divider
                Rectangle { width: parent.width; height: 1; color: Theme.field }

                // ══ Sticker ══
                Text {
                    text: "Sticker (chạm để thêm)"
                    color: "#ffffff"; font.pixelSize: 15; font.weight: Font.Bold
                }

                // 3 hàng sticker, mỗi hàng cuộn ngang, hiển thị 5 sticker đại diện
                Column {
                    width: parent.width
                    spacing: leftPanel._thumbSpacing

                    Repeater {
                        model: leftPanel._rowsSticker
                        delegate: Item {
                            id: stickerRowItem
                            property int rowIndex: index
                            property int startIdx: rowIndex * leftPanel._stickerPerRow
                            property int endIdx:   Math.min(startIdx + leftPanel._stickerPerRow - 1,
                                                            stickerLibModel.count - 1)
                            property int rowCount: Math.max(0, endIdx - startIdx + 1)

                            width: parent.width
                            height: rowCount > 0 ? leftPanel._stkThumbH : 0
                            visible: rowCount > 0

                            ListView {
                                anchors.fill: parent
                                orientation: ListView.Horizontal
                                spacing: leftPanel._thumbSpacing
                                clip: true
                                interactive: stickerRowItem.rowCount > leftPanel._visiblePerRow
                                model: stickerRowItem.rowCount

                                ScrollBar.horizontal: ScrollBar {
                                    policy: ScrollBar.AsNeeded
                                    height: 4
                                }

                                delegate: Item {
                                    property int globalIdx: stickerRowItem.startIdx + index
                                    property var sdata: globalIdx < stickerLibModel.count
                                                        ? stickerLibModel.get(globalIdx) : null

                                    width:  leftPanel._stkThumbW
                                    height: leftPanel._stkThumbH

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: 8
                                        color: root._bgImagePath !== "" ? "#661f2229" : Theme.surface
                                        border.color: Theme.border; border.width: 1

                                        Image {
                                            anchors.fill: parent; anchors.margins: 6
                                            source: (sdata && sdata.path) ? toUrl(sdata.path) : ""
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            sourceSize.width: 120; sourceSize.height: 120
                                        }

                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: if (sdata) root.addSticker(sdata.path)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: stickerLibModel.count === 0
                    text: "Chưa có sticker. Thêm trong Cài Đặt → Bộ Lọc Màu."
                    color: Theme.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════════
    // Bố cục Mode 3: FRAME (trái) │ LAYOUT (giữa) │ FILTER + STICKER (phải)
    // Không vẽ chữ tiêu đề — chữ "Frame"/"Filter" nằm sẵn trên ảnh nền.
    // ══════════════════════════════════════════════════════════════════════════

    // ── Cột trái: Frame — 4 thumbnail/hàng × 3 hàng, mỗi hàng cuộn ngang ──────
    Column {
        id: mode3FrameCol
        visible: root._mode3Layout && root._mode3FramePicker
        anchors.left:      parent.left
        anchors.leftMargin: root._m3SideMargin
        anchors.top:       parent.top
        anchors.topMargin: root._m3TopY
        width:   root._m3ColWidth
        spacing: root._m3RowSpacing
        z: 10

        Repeater {
            model: root._m3FrameRows

            delegate: Item {
                id: m3FrameRow
                property int rowIndex: index
                property int startIdx: rowIndex * root._m3FramePerRow
                property int endIdx:   Math.min(startIdx + root._m3FramePerRow - 1,
                                                categoryFrameModel.count - 1)
                property int rowCount: Math.max(0, endIdx - startIdx + 1)

                // Chiều cao CỐ ĐỊNH kể cả khi hàng rỗng — hàng dưới không được xê dịch
                // theo số lượng frame, nếu không sẽ lệch khỏi chữ vẽ trên ảnh nền.
                width:  root._m3ColWidth
                height: root._m3RowHeight

                ListView {
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: root._m3ItemSpacing
                    clip: true
                    interactive: m3FrameRow.rowCount > root._m3ColsPerRow
                    boundsBehavior: Flickable.StopAtBounds
                    model: m3FrameRow.rowCount

                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 4 }

                    delegate: Item {
                        id: m3FrameCell
                        width:  root._m3Circle
                        height: ListView.view.height

                        property int gIdx: m3FrameRow.startIdx + index
                        // Điều kiện _frameRev >= 0 luôn đúng — nó chỉ để tạo phụ thuộc,
                        // buộc binding chạy lại sau mỗi lần model được nạp lại.
                        property var fdata: (root._frameRev >= 0 && gIdx < categoryFrameModel.count)
                                            ? categoryFrameModel.get(gIdx) : null

                        CircleThumb {
                            anchors.centerIn: parent
                            diameter: root._m3Circle
                            // Bật cache: ListView huỷ/tạo lại delegate khi cuộn ngang, không
                            // cache thì mỗi lần cuộn qua lại đều phải giải mã ảnh từ ổ đĩa.
                            // Ảnh đại diện (frame_image_) chỉ đổi được ở màn Cài Đặt, mà mỗi
                            // phiên chụp lại tạo FilterScreen mới nên không sợ hiển thị bản cũ.
                            cacheImage: true
                            source: m3FrameCell.fdata
                                    ? root.toUrl(m3FrameCell.fdata.displayPath
                                                 && m3FrameCell.fdata.displayPath !== ""
                                                 ? m3FrameCell.fdata.displayPath
                                                 : m3FrameCell.fdata.path)
                                    : ""
                            selected: m3FrameCell.fdata
                                      ? root.samePath(root.selectedFramePath, m3FrameCell.fdata.path)
                                      : false
                            onClicked: if (m3FrameCell.fdata) root.selectFrame(m3FrameCell.fdata.path)
                        }
                    }
                }
            }
        }

    }

    // Thông báo rỗng — để NGOÀI Column để không đẩy các hàng lệch vị trí.
    Text {
        visible: mode3FrameCol.visible && categoryFrameModel.count === 0
        anchors.left: mode3FrameCol.left
        anchors.top:  mode3FrameCol.top
        width: root._m3ColWidth
        text: root._effectiveCategory !== ""
              ? "Chưa có frame trong nhóm " + root._effectiveCategory + "."
              : "Chưa xác định được nhóm frame."
        color: root._themeMutedText
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        z: 11
    }

    // ── Cột phải: Filter (4 hàng) + Sticker (1 hàng), mỗi hàng cuộn ngang ─────
    Column {
        id: mode3RightCol
        visible: root._mode3Layout
        anchors.right:      parent.right
        anchors.rightMargin: root._m3SideMargin
        anchors.top:        parent.top
        anchors.topMargin:  root._m3TopY
        width:   root._m3ColWidth
        spacing: root._m3RowSpacing
        z: 10

        // ══ Bộ lọc màu — index 0 của danh sách là mục "Gốc" (bỏ filter) ══
        Repeater {
            model: root._m3FilterRows

            delegate: Item {
                id: m3FilterRow
                property int rowIndex: index
                property int startIdx: rowIndex * root._m3FilterPerRow
                // Tổng số mục = filterListModel.count + 1 ("Gốc") → index cuối = count
                property int endIdx:   Math.min(startIdx + root._m3FilterPerRow - 1,
                                                filterListModel.count)
                property int rowCount: Math.max(0, endIdx - startIdx + 1)

                // Chiều cao CỐ ĐỊNH kể cả khi hàng rỗng — xem ghi chú ở cột frame.
                width:  root._m3ColWidth
                height: root._m3RowHeight

                ListView {
                    anchors.fill: parent
                    orientation: ListView.Horizontal
                    spacing: root._m3ItemSpacing
                    clip: true
                    interactive: m3FilterRow.rowCount > root._m3ColsPerRow
                    boundsBehavior: Flickable.StopAtBounds
                    model: m3FilterRow.rowCount

                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 4 }

                    delegate: Item {
                        id: m3FilterCell
                        width:  root._m3Circle
                        height: ListView.view.height

                        property int  globalIdx: m3FilterRow.startIdx + index
                        property bool isOrigin:  globalIdx === 0
                        property var  fdata: (!isOrigin && globalIdx - 1 < filterListModel.count)
                                             ? filterListModel.get(globalIdx - 1) : null
                        property string fid:    isOrigin ? "" : (fdata ? fdata.id : "")
                        property string fthumb: isOrigin ? "" : (fdata ? fdata.thumbnailPath : "")

                        CircleThumb {
                            anchors.centerIn: parent
                            diameter: root._m3Circle
                            source: m3FilterCell.fthumb !== "" ? root.toUrl(m3FilterCell.fthumb) : ""
                            placeholder: m3FilterCell.isOrigin ? "✕" : "🎨"
                            selected: m3FilterCell.isOrigin
                                      ? root.selectedFilterId === ""
                                      : root.selectedFilterId === m3FilterCell.fid

                            onClicked: {
                                if (m3FilterCell.isOrigin) {
                                    root.selectedFilterId = ""
                                    root.previewPath = root.toUrl(root.collagePath)
                                    root.applyError = ""
                                    console.log("[FilterScreen] Filter cleared (Gốc selected)")
                                } else {
                                    var fid = m3FilterCell.fid
                                    if (root.selectedFilterId === fid && !filterDebounceTimer.running) return
                                    root.selectedFilterId = fid
                                    root.applyError = ""
                                    filterDebounceTimer.pendingFilterId = fid
                                    filterDebounceTimer.restart()
                                }
                            }
                        }
                    }
                }
            }
        }

        // Khoảng nghỉ trước hàng sticker
        Item { width: 1; height: Mode3Layout.stickerGap }

        // ══ Sticker — 1 hàng, chạm để dán lên ảnh ══
        Item {
            id: m3StickerRow
            width:  root._m3ColWidth
            height: root._m3RowHeight

            ListView {
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: root._m3ItemSpacing
                clip: true
                interactive: stickerLibModel.count > root._m3ColsPerRow
                boundsBehavior: Flickable.StopAtBounds
                model: stickerLibModel

                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded; height: 4 }

                delegate: Item {
                    id: m3StickerCell
                    width:  root._m3Circle
                    height: ListView.view.height

                    property string spath: model.path

                    CircleThumb {
                        anchors.centerIn: parent
                        diameter: root._m3Circle
                        // Sticker là PNG trong suốt → thu vừa vòng tròn, không cắt.
                        // inset để 4 góc sticker vuông không bị vòng tròn cắt mất.
                        fitMode: Image.PreserveAspectFit
                        inset: Math.round(root._m3Circle * 0.15)
                        source: root.toUrl(m3StickerCell.spath)
                        onClicked: root.addSticker(m3StickerCell.spath)
                    }
                }
            }
        }
    }

    // Thông báo rỗng — để NGOÀI Column để không đẩy hàng sticker lệch vị trí.
    Text {
        visible: mode3RightCol.visible && filterListModel.count === 0
        anchors.left: mode3RightCol.left
        anchors.top:  mode3RightCol.top
        width: root._m3ColWidth
        text: root.showingFavoritesOnly ? "Chưa có filter yêu thích." : "Chưa có bộ lọc nào."
        color: root._themeMutedText
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        z: 11
    }

    Text {
        visible: mode3RightCol.visible && stickerLibModel.count === 0
        anchors.left: m3StickerRow.left
        anchors.verticalCenter: m3StickerRow.verticalCenter
        width: root._m3ColWidth
        text: "Chưa có sticker."
        color: root._themeMutedText
        font.pixelSize: 14
        wrapMode: Text.WordWrap
        z: 11
    }

    // ── Preview area ─────────────────────────────────────────────────────────
    Item {
        id: previewArea
        // Mode 3: nằm gọn giữa cột frame (trái) và cột filter/sticker (phải), bắt đầu
        // NGANG HÀNG với 2 cột để không đè lên chữ vẽ ở phần trên ảnh nền.
        anchors.top:    root._mode3Layout ? parent.top : topBar.bottom
        anchors.left:   root._mode3Layout ? mode3FrameCol.right : parent.left
        anchors.right:  root._mode3Layout ? mode3RightCol.left
                      : root.portrait     ? parent.right
                                          : (root._leftPanelVisible ? leftPanel.left : parent.right)
        // Kéo xuống tận đáy: nút "In Ảnh" nằm lệch hẳn bên phải (x≥1625) nên không
        // vướng cột giữa — nhờ vậy ảnh layout được cao nhất có thể.
        anchors.bottom: root._mode3Layout ? parent.bottom
                      : root._leftPanelVisible
                        ? (root.portrait ? leftPanel.top : bottomBar.top)
                        : filterStrip.top
        anchors.margins: root.portrait ? 10 : 16
        anchors.leftMargin:   root._mode3Layout ? 24 : (root.portrait ? 10 : 16)
        anchors.rightMargin:  root._mode3Layout ? 24 : (root.portrait ? 10 : 16)
        anchors.topMargin:    root._mode3Layout ? root._m3TopY : (root.portrait ? 10 : 40)
        anchors.bottomMargin: root._mode3Layout ? 40 : (root.portrait ? 10 : 16)

        Image {
            id: previewImage
            anchors.centerIn: parent
            width:  Math.min(parent.width * (root.portrait ? 0.94 : (root._mode3Layout ? 1.0 : 0.7)),
                             parent.height * (root._mode3Layout ? 0.99 : 0.95))
            height: parent.height * (root.portrait ? 0.92 : (root._mode3Layout ? 0.98 : 0.95))
            source: root.previewPath
            fillMode: Image.PreserveAspectFit
            cache: false
            asynchronous: true
            // Giới hạn giải mã ở kích thước hiển thị thực tế — ảnh composited không cần
            // load ở độ phân giải in (vd 1181×3543) chỉ để hiển thị preview nhỏ trên màn hình.
            sourceSize: Qt.size(width, height)

            Rectangle {
                anchors.fill: parent; z: -1
                color: "transparent"
                border.color: root._bgImagePath !== "" ? "transparent" : Theme.border
                border.width: 1
            }
        }

        // ── Lớp sticker tương tác (chỉ khi bật sticker) ──
        // Phủ đúng vùng ảnh hiển thị (paintedWidth/Height, canh giữa previewImage).
        Item {
            id: stickerLayer
            visible: root._stickerActive
            width:  previewImage.paintedWidth
            height: previewImage.paintedHeight
            x: previewImage.x + (previewImage.width  - previewImage.paintedWidth)  / 2
            y: previewImage.y + (previewImage.height - previewImage.paintedHeight) / 2
            z: 5

            // Bấm vùng trống → bỏ chọn
            MouseArea {
                anchors.fill: parent
                onClicked: root._selectedStickerIndex = -1
            }

            Repeater {
                model: placedStickers
                delegate: Item {
                    id: stkItem
                    property real imgRatio: stkImg.implicitHeight > 0 && stkImg.implicitWidth > 0
                                            ? stkImg.implicitHeight / stkImg.implicitWidth : 1.0
                    width:  model.wN * stickerLayer.width
                    height: width * imgRatio
                    x: model.xN * stickerLayer.width  - width  / 2
                    y: model.yN * stickerLayer.height - height / 2
                    rotation: model.rot
                    z: index === root._selectedStickerIndex ? 100 : 10

                    // Lưu wN tại thời điểm bắt đầu pinch để nhân đúng tỉ lệ
                    property real _pinchStartWN: 0
                    property real _pinchStartRot: 0

                    Image {
                        id: stkImg
                        anchors.fill: parent
                        source: root.toUrl(model.path)
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }

                    // Viền + góc bo khi đang chọn
                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.color: "#6c5ce7"; border.width: 2
                        radius: 4
                        visible: index === root._selectedStickerIndex
                    }

                    TapHandler {
                        onTapped: root._selectedStickerIndex = index
                    }

                    // ── Kéo di chuyển (1 ngón trên thân sticker) ──
                    DragHandler {
                        id: stkDrag
                        target: null
                        onActiveChanged: if (active) root._selectedStickerIndex = index
                        onTranslationChanged: {
                            var nx = (stkItem.x + stkItem.width  / 2 + (centroid.position.x - centroid.pressPosition.x)) / stickerLayer.width
                            var ny = (stkItem.y + stkItem.height / 2 + (centroid.position.y - centroid.pressPosition.y)) / stickerLayer.height
                            placedStickers.setProperty(index, "xN", Math.max(0, Math.min(1, nx)))
                            placedStickers.setProperty(index, "yN", Math.max(0, Math.min(1, ny)))
                        }
                    }

                    // ── Pinch 2 ngón: phóng to/thu nhỏ + xoay ──
                    PinchHandler {
                        id: stkPinch
                        target: null
                        // Snap wN tại thời điểm bắt đầu, rồi nhân activeScale mỗi frame
                        onActiveChanged: {
                            if (active) {
                                root._selectedStickerIndex = index
                                stkItem._pinchStartWN  = model.wN
                                stkItem._pinchStartRot = model.rot
                            }
                        }
                        onActiveScaleChanged: {
                            var nw = Math.max(0.05, Math.min(2.0, stkItem._pinchStartWN * activeScale))
                            placedStickers.setProperty(index, "wN", nw)
                        }
                        onActiveRotationChanged: {
                            placedStickers.setProperty(index, "rot", stkItem._pinchStartRot + activeRotation)
                        }
                    }

                    // ── Nút xoá góc trên-phải ──
                    Rectangle {
                        id: deleteBtn
                        width: 28; height: 28; radius: 14
                        color: deleteTap.pressed ? "#c0392b" : "#e74c3c"
                        border.color: "white"; border.width: 1.5
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.rightMargin: -10; anchors.topMargin: -10
                        visible: index === root._selectedStickerIndex
                        rotation: -stkItem.rotation
                        z: 20
                        Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 14; font.bold: true }
                        TapHandler { id: deleteTap; onTapped: root.removeSticker(index) }
                    }

                    // ── Handle kéo để resize (góc dưới-phải) ──
                    // Kéo handle này theo hướng diagonal để thay đổi wN
                    Rectangle {
                        id: resizeHandle
                        width: 32; height: 32; radius: 16
                        color: resizeDrag.active ? "#6c5ce7" : "#8e7cf5"
                        border.color: "white"; border.width: 1.5
                        anchors.right:  parent.right;  anchors.bottom: parent.bottom
                        anchors.rightMargin: -12; anchors.bottomMargin: -12
                        visible: index === root._selectedStickerIndex
                        rotation: -stkItem.rotation
                        z: 20
                        opacity: resizeDrag.active ? 1.0 : 0.85

                        // Icon mũi tên resize
                        Text {
                            anchors.centerIn: parent
                            text: "⤡"
                            color: "white"; font.pixelSize: 16; font.bold: true
                            rotation: 0
                        }

                        // Trạng thái lúc bắt đầu kéo handle (gộp phóng to + xoay)
                        property real _startWN: 0
                        property real _startRot: 0
                        property real _startDist: 1
                        property real _startAngle: 0

                        // Tâm sticker trong toạ độ scene (ổn định kể cả khi sticker xoay).
                        function _centerScene() {
                            return stickerLayer.mapToItem(null,
                                model.xN * stickerLayer.width,
                                model.yN * stickerLayer.height)
                        }

                        DragHandler {
                            id: resizeDrag
                            target: null
                            onActiveChanged: {
                                if (active) {
                                    root._selectedStickerIndex = index
                                    resizeHandle._startWN  = model.wN
                                    resizeHandle._startRot = model.rot
                                    // Vector tâm → điểm nhấn (toạ độ scene)
                                    var c = resizeHandle._centerScene()
                                    var dx = centroid.scenePressPosition.x - c.x
                                    var dy = centroid.scenePressPosition.y - c.y
                                    resizeHandle._startDist  = Math.max(1, Math.sqrt(dx*dx + dy*dy))
                                    resizeHandle._startAngle = Math.atan2(dy, dx) * 180 / Math.PI
                                }
                            }
                            onCentroidChanged: {
                                if (!active) return
                                // Vector tâm → ngón tay hiện tại (toạ độ scene)
                                var c = resizeHandle._centerScene()
                                var dx = centroid.scenePosition.x - c.x
                                var dy = centroid.scenePosition.y - c.y
                                // Phóng to/thu nhỏ theo khoảng cách tới tâm
                                var curDist = Math.max(1, Math.sqrt(dx*dx + dy*dy))
                                var nw = Math.max(0.05, Math.min(2.0,
                                         resizeHandle._startWN * (curDist / resizeHandle._startDist)))
                                placedStickers.setProperty(index, "wN", nw)
                                // Xoay theo góc quay quanh tâm
                                var curAngle = Math.atan2(dy, dx) * 180 / Math.PI
                                placedStickers.setProperty(index, "rot",
                                    resizeHandle._startRot + (curAngle - resizeHandle._startAngle))
                            }
                        }
                    }
                }
            }
        }

        // ── QR overlay cho BẢN IN (kéo/đổi kích thước để đặt vị trí) ──────────
        // Phủ đúng vùng ảnh hiển thị (paintedWidth/Height) của previewImage.
        Item {
            id: overlayArea
            width:  previewImage.paintedWidth
            height: previewImage.paintedHeight
            x: previewImage.x + (previewImage.width  - previewImage.paintedWidth)  / 2
            y: previewImage.y + (previewImage.height - previewImage.paintedHeight) / 2
            z: 6
            visible: overlayArea.showQrInPrint && overlayArea.qrUrlPath !== ""

            property bool qrSettingEnabled: eventManager.getAppSetting("qr_code_enabled", "false") === "true"
            property bool showQrInPrint: qrSettingEnabled
            property string qrUrlPath: (root.sessionId && root.hwid)
                    ? s3Uploader.buildSessionUrl(root.hwid, root.eventId, root.sessionId)
                    : ""

            // Detect printer & layout
            property bool isQW410: printerConfig.selectedPrinter.indexOf("QW410") >= 0
                                || printerConfig.selectedPrinter.indexOf("QW-410") >= 0
            property string selectedLayoutPath: {
                if (root.selectedFramePath && root.selectedFramePath !== "")
                    return root.selectedFramePath
                if (root.layoutPath && root.layoutPath !== "")
                    return root.layoutPath
                return root.eventData && root.eventData.selectedLayout
                        ? root.eventData.selectedLayout : ""
            }
            property real layoutAspect: selectedLayoutPath !== ""
                                        ? eventManager.getLayoutAspect(selectedLayoutPath) : 1.0
            property bool is5x10Layout: layoutAspect > 0.38 && layoutAspect <= 0.58
            property bool is5x15Layout: layoutAspect <= 0.38
            property bool is15x5Layout: layoutAspect > 2.0

            property bool isQW410Cut: isQW410 && is5x10Layout && printerConfig.cutMode
            property bool isQW4105x15: isQW410 && is5x15Layout
            property bool isRX1Cut: !isQW410 && is5x15Layout && (root.eventData && root.eventData.autoCut) && printerConfig.cutMode
            property bool isRX1HCut: !isQW410 && is15x5Layout && (root.eventData && root.eventData.autoCut) && printerConfig.cutMode
            property bool isTwoQR: isRX1Cut || isQW4105x15

            property var qrSlot: ({})
            property real qrLayoutW: 0
            property real qrLayoutH: 0

            property int numStrips: isQW410Cut ? 3 : (isTwoQR ? 2 : 1)

            property real stripW: isQW4105x15 ? overlayArea.width / 2 : overlayArea.width
            property real stripH: overlayArea.height

            property real normalizedX:    overlayArea.stripW > 0 ? (qrBox.x / overlayArea.stripW) : 0
            property real normalizedY:    overlayArea.stripH > 0 ? (qrBox.y / overlayArea.stripH) : 0
            property real normalizedW:    overlayArea.stripW > 0 ? (qrBox.width / overlayArea.stripW) : 0
            property real normalizedH:    overlayArea.stripH > 0 ? (qrBox.height / overlayArea.stripH) : 0
            property real normalizedSize: Math.min(overlayArea.stripW, overlayArea.stripH) > 0
                                         ? (qrBox.width / Math.min(overlayArea.stripW, overlayArea.stripH)) : 0

            function reloadQrSlot() {
                qrSlot = ({})
                qrLayoutW = 0
                qrLayoutH = 0
                if (!selectedLayoutPath) {
                    Qt.callLater(calculateInitialPosition)
                    return
                }
                var meta = eventManager.loadLayoutMetadata(selectedLayoutPath)
                if (meta && meta.qr_slot) {
                    qrSlot = meta.qr_slot
                    qrLayoutW = meta.width || 0
                    qrLayoutH = meta.height || 0
                }
                Qt.callLater(calculateInitialPosition)
            }

            function resetQrSlotForLayout() {
                Qt.callLater(function() {
                    qrBox.userAdjusted = false
                    reloadQrSlot()
                })
            }

            function hasQrSlot() {
                return qrSlot && qrSlot.width > 0 && qrSlot.height > 0
                       && qrLayoutW > 0 && qrLayoutH > 0
            }

            function qrSlotBaseW() {
                return qrLayoutW > 0 ? qrLayoutW : overlayArea.stripW
            }

            function qrSlotBaseH() {
                return qrLayoutH > 0 ? qrLayoutH : overlayArea.stripH
            }

            function qrSlotNormalizedX() {
                return Math.max(0, Math.min(1, (qrSlot.x || 0) / Math.max(1, qrSlotBaseW())))
            }

            function qrSlotNormalizedY() {
                return Math.max(0, Math.min(1, (qrSlot.y || 0) / Math.max(1, qrSlotBaseH())))
            }

            function qrSlotNormalizedW() {
                return Math.max(0.02, Math.min(1, (qrSlot.width || 0) / Math.max(1, qrSlotBaseW())))
            }

            function qrSlotNormalizedH() {
                return Math.max(0.02, Math.min(1, (qrSlot.height || 0) / Math.max(1, qrSlotBaseH())))
            }

            function applyQrSlotPosition() {
                if (!overlayArea.hasQrSlot())
                    return false
                var sx = overlayArea.stripW / Math.max(1, overlayArea.qrSlotBaseW())
                var sy = overlayArea.stripH / Math.max(1, overlayArea.qrSlotBaseH())
                var w = Math.max(1, Math.round((qrSlot.width || 0) * sx))
                var h = Math.max(1, Math.round((qrSlot.height || 0) * sy))
                qrBox.width = w
                qrBox.height = h
                qrBox.x = Math.max(0, Math.min(overlayArea.stripW - w, Math.round((qrSlot.x || 0) * sx)))
                qrBox.y = Math.max(0, Math.min(overlayArea.stripH - h, Math.round((qrSlot.y || 0) * sy)))
                return true
            }

            function hasUsablePrintPosition() {
                return overlayArea.normalizedSize > 0
                       && (qrBox.userAdjusted || qrBox.x > 1 || qrBox.y > 1)
            }
            function fallbackLowerRightNorm() {
                var ns = overlayArea.printNormalizedSize()
                return Math.max(0, Math.min(0.95, 1.0 - ns - 0.04))
            }
            function printNormalizedX() {
                if (overlayArea.hasQrSlot())
                    return overlayArea.qrSlotNormalizedX()
                if (overlayArea.hasUsablePrintPosition())
                    return Math.max(0, Math.min(1, overlayArea.normalizedX))
                return overlayArea.fallbackLowerRightNorm()
            }
            function printNormalizedY() {
                if (overlayArea.hasQrSlot())
                    return overlayArea.qrSlotNormalizedY()
                if (overlayArea.hasUsablePrintPosition())
                    return Math.max(0, Math.min(1, overlayArea.normalizedY))
                return overlayArea.fallbackLowerRightNorm()
            }
            function printNormalizedSize() {
                if (overlayArea.hasQrSlot())
                    return Math.max(overlayArea.qrSlotNormalizedW(), overlayArea.qrSlotNormalizedH())
                if (overlayArea.normalizedSize > 0)
                    return Math.max(0.02, Math.min(0.8, overlayArea.normalizedSize))
                return 0.12
            }
            function printNormalizedW() {
                if (overlayArea.hasQrSlot())
                    return overlayArea.qrSlotNormalizedW()
                if (overlayArea.normalizedW > 0)
                    return Math.max(0.02, Math.min(1, overlayArea.normalizedW))
                return overlayArea.printNormalizedSize()
            }
            function printNormalizedH() {
                if (overlayArea.hasQrSlot())
                    return overlayArea.qrSlotNormalizedH()
                if (overlayArea.normalizedH > 0)
                    return Math.max(0.02, Math.min(1, overlayArea.normalizedH))
                return overlayArea.printNormalizedSize()
            }

            function calculateInitialPosition() {
                if (overlayArea.width <= 0 || overlayArea.height <= 0) return
                if (overlayArea.applyQrSlotPosition()) return
                // Giữ vị trí người dùng đã kéo chỉ cho frame không có qr_slot.
                if (qrBox.userAdjusted) return
                var sw = overlayArea.stripW
                var fullH = overlayArea.height
                var em = 25
                var sz, targetX, targetY

                if (overlayArea.isQW410Cut) {
                    sz = Math.max(Math.round(Math.min(sw, fullH) * 0.12), 50)
                    sz = Math.min(sz, sw - em * 2)
                    targetX = Math.max(0, sw - sz - em)
                    targetY = Math.max(0, fullH - sz - em)
                } else if (overlayArea.isQW4105x15) {
                    sz = Math.max(Math.round(Math.min(sw, fullH) * 0.11), 50)
                    sz = Math.min(sz, sw - em * 2)
                    targetX = Math.max(0, sw - sz - em)
                    targetY = Math.max(0, Math.round(fullH * 0.88) - sz - em)
                } else if (overlayArea.isRX1Cut) {
                    sz = Math.max(Math.round(Math.min(sw, fullH) * 0.12), 50)
                    sz = Math.min(sz, sw - em * 2)
                    targetX = Math.max(0, sw - sz - em)
                    targetY = Math.max(0, fullH - sz - em)
                } else if (overlayArea.isRX1HCut) {
                    sz = Math.max(Math.round(Math.min(sw, fullH) * 0.12), 50)
                    sz = Math.min(sz, fullH - em * 2)
                    targetX = Math.max(0, sw - sz - em)
                    targetY = Math.max(0, fullH - sz - em)
                } else {
                    sz = Math.max(Math.round(Math.min(sw, fullH) * 0.14), 50)
                    sz = Math.min(sz, sw - em * 2)
                    targetX = Math.max(0, sw - sz - em)
                    targetY = Math.max(0, fullH - sz - em)
                }
                qrBox.width = sz; qrBox.height = sz
                qrBox.x = targetX
                qrBox.y = targetY
            }

            onWidthChanged:         Qt.callLater(calculateInitialPosition)
            onHeightChanged:        Qt.callLater(calculateInitialPosition)
            onIsQW410CutChanged:    Qt.callLater(calculateInitialPosition)
            onIsQW4105x15Changed:   Qt.callLater(calculateInitialPosition)
            onIsRX1CutChanged:      Qt.callLater(calculateInitialPosition)
            onIsRX1HCutChanged:     Qt.callLater(calculateInitialPosition)
            onIsTwoQRChanged:       Qt.callLater(calculateInitialPosition)
            onSelectedLayoutPathChanged: resetQrSlotForLayout()
            Component.onCompleted: resetQrSlotForLayout()

            // ── QR Box chính — kéo trong strip 1 ──
            Rectangle {
                id: qrBox
                color: "white"; radius: 8
                border.color: "#1e7eea"; border.width: 2
                visible: overlayArea.showQrInPrint && overlayArea.qrUrlPath !== ""

                property bool userAdjusted: false
                property real minSize: 40
                property real maxSize: Math.min(overlayArea.stripW, overlayArea.stripH) * 0.8

                Image {
                    anchors.fill: parent
                    source: overlayArea.qrUrlPath !== ""
                        ? ("image://qr/" + encodeURIComponent(overlayArea.qrUrlPath))
                        : ""
                    fillMode: Image.Stretch; cache: false
                }

                Rectangle {
                    visible: overlayArea.numStrips > 1
                    anchors.bottom: parent.top; anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 3; color: "#1e7eea"; radius: 3
                    width: lbHint.implicitWidth + 8; height: 16
                    Text { id: lbHint; anchors.centerIn: parent
                        text: overlayArea.isQW410Cut ? "vị trí áp dụng cho cả 3 ảnh" : "vị trí áp dụng cho cả 2 ảnh"
                        color: "white"; font.pixelSize: 9; font.bold: true }
                }

                MouseArea {
                    id: dragArea; anchors.fill: parent
                    enabled: !overlayArea.hasQrSlot()
                    drag.target: qrBox; drag.axis: Drag.XAndYAxis
                    drag.minimumX: 0
                    drag.maximumX: overlayArea.stripW - qrBox.width
                    drag.minimumY: 0
                    drag.maximumY: overlayArea.height - qrBox.height
                    cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                    onPressed: qrBox.userAdjusted = true
                }

                Rectangle {
                    id: qrResizeHandle
                    visible: !overlayArea.hasQrSlot()
                    enabled: visible
                    width: 28; height: 28; radius: 6
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 3
                    color: qrResizeMA.containsMouse || qrResizeMA.pressed ? "#1e7eea" : "#3a8ff0"
                    border.color: "white"; border.width: 1.5; z: 10
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text { anchors.centerIn: parent; text: "⤡"; color: "white"; font.pixelSize: 14; font.bold: true }
                    MouseArea {
                        id: qrResizeMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.SizeFDiagCursor
                        property real startX: 0; property real startY: 0; property real startW: 0
                        onPressed: (mouse) => {
                            qrBox.userAdjusted = true
                            startX = mouse.x + qrResizeHandle.x + qrBox.x
                            startY = mouse.y + qrResizeHandle.y + qrBox.y
                            startW = qrBox.width
                        }
                        onPositionChanged: (mouse) => {
                            if (!pressed) return
                            var dx = (mouse.x + qrResizeHandle.x + qrBox.x) - startX
                            var dy = (mouse.y + qrResizeHandle.y + qrBox.y) - startY
                            var delta = (Math.abs(dx) > Math.abs(dy)) ? dx : dy
                            var s = Math.round(startW + delta)
                            s = Math.max(qrBox.minSize, Math.min(qrBox.maxSize, s))
                            s = Math.min(s, overlayArea.stripW - qrBox.x)
                            s = Math.min(s, overlayArea.height - qrBox.y)
                            qrBox.width = s; qrBox.height = s
                        }
                    }
                }

                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: qrCloseMA.containsMouse ? "#ff4757" : "#e74c3c"
                    anchors.top: parent.top; anchors.right: parent.right; anchors.margins: -12
                    border.color: "white"; border.width: 2.5; z: 10
                    Text { text: "✕"; color: "white"; font.pixelSize: 18; font.bold: true; anchors.centerIn: parent }
                    MouseArea {
                        id: qrCloseMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: overlayArea.showQrInPrint = false
                    }
                }
            }

            // ── QR Box mirror — chỉ khi QW410 5x15 (2 cột thực trên UI) ──
            Rectangle {
                id: qrBoxMirror
                visible: overlayArea.showQrInPrint && overlayArea.qrUrlPath !== ""
                      && overlayArea.isQW4105x15
                color: "white"; radius: 8
                border.color: "#1e7eea"; border.width: 2
                opacity: 0.85
                x: qrBox.x + overlayArea.stripW
                y: qrBox.y
                width: qrBox.width
                height: qrBox.height
                Image {
                    anchors.fill: parent
                    source: overlayArea.qrUrlPath !== ""
                        ? ("image://qr/" + encodeURIComponent(overlayArea.qrUrlPath))
                        : ""
                    fillMode: Image.Stretch; cache: false
                }
            }
        }

        // Loading overlay
        Rectangle {
            anchors.fill: previewImage
            color: "#aa000000"
            radius: 10
            visible: root.isApplying

            Column {
                anchors.centerIn: parent
                spacing: 12
                BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: root.isApplying }
                Text { text: "Đang áp dụng..."; color: "white"; font.pixelSize: 16; font.bold: true }
            }
        }

        // Error message
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            width: errText.implicitWidth + 32; height: 40; radius: 8
            color: "#c0392b"
            visible: root.applyError !== ""
            Text {
                id: errText
                anchors.centerIn: parent
                text: root.applyError; color: "white"; font.pixelSize: 13
            }
        }
    }

    // ── Filter strip (horizontal) — ẩn khi bật sticker (đã có panel trái) ──────
    Rectangle {
        id: filterStrip
        visible: !root._leftPanelVisible
        anchors.bottom: bottomBar.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: root._stickerEnabled ? 0 : 160
        color: "transparent"

        Rectangle {
            anchors.top: parent.top; width: parent.width; height: 1; color: "#442a2d35"
        }

        // Loading badge (cut mode: đang tạo raw strip trong background)
        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: loadingBadgeText.implicitWidth + 36; height: 22; radius: 11
            color: "#1a2a3a"; border.color: "#4FA4F2"; border.width: 1
            visible: root._previewLoading
            z: 3
            Row {
                anchors.centerIn: parent; spacing: 6
                BusyIndicator { width: 14; height: 14; running: root._previewLoading }
                Text {
                    id: loadingBadgeText
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Đang chuẩn bị preview..."
                    color: "#4FA4F2"; font.pixelSize: 10; font.bold: true
                }
            }
        }

        // Favourite-only badge
        Rectangle {
            anchors.top: parent.top; anchors.topMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: favBadgeText.implicitWidth + 20; height: 22; radius: 11
            color: "#3d2e00"; border.color: "#f5a623"; border.width: 1
            visible: root.showingFavoritesOnly && !root._previewLoading
            z: 2
            Text {
                id: favBadgeText
                anchors.centerIn: parent
                text: "⭐ Chỉ hiển thị filter yêu thích"
                color: "#f5a623"; font.pixelSize: 10; font.bold: true
            }
        }

        ListView {
            id: filterList
            anchors.fill: parent
            anchors.margins: 12
            orientation: ListView.Horizontal
            spacing: 12
            clip: true
            model: filterListModel

            // "Không filter" option prepended via header
            header: Item {
                width: 120; height: parent.height

                Rectangle {
                    anchors.fill: parent; anchors.margins: 4
                    radius: 10
                    color: root.selectedFilterId === ""
                           ? (root._bgImagePath !== "" ? "#993a3d55" : "#3a3d55")
                           : (root._bgImagePath !== "" ? "#661f2229"  : Theme.surface)
                    border.color: root.selectedFilterId === "" ? "#6c5ce7" : Theme.border
                    border.width: root.selectedFilterId === "" ? 3 : 1

                    Column {
                        anchors.centerIn: parent; spacing: 6
                        Text {
                            text: "✕"; color: root.selectedFilterId === "" ? "#6c5ce7" : Theme.textMuted
                            font.pixelSize: 28; font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Gốc"; color: "white"; font.pixelSize: 12; font.bold: true
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.selectedFilterId = ""
                            root.previewPath      = toUrl(root.collagePath)
                            root.applyError       = ""
                            console.log("[FilterScreen] Filter cleared (Gốc selected)")
                        }
                    }
                }
            }

            delegate: Item {
                width: 120; height: filterList.height

                Rectangle {
                    anchors.fill: parent; anchors.margins: 4
                    radius: 10
                    color: root.selectedFilterId === model.id
                           ? (root._bgImagePath !== "" ? "#993a3d55" : "#3a3d55")
                           : (root._bgImagePath !== "" ? "#661f2229"  : Theme.surface)
                    border.color: root.selectedFilterId === model.id ? "#6c5ce7" : Theme.border
                    border.width: root.selectedFilterId === model.id ? 3 : 1

                    Column {
                        anchors.fill: parent; anchors.margins: 6; spacing: 4

                        // Thumbnail
                        Rectangle {
                            width: parent.width; height: parent.height - 28
                            color: "transparent"; radius: 6; clip: true

                            Image {
                                anchors.fill: parent
                                source: model.thumbnailPath !== "" ? toUrl(model.thumbnailPath) : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                visible: model.thumbnailPath !== ""
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "🎨"
                                font.pixelSize: 28
                                visible: model.thumbnailPath === ""
                            }
                        }

                        // Name
                        Text {
                            width: parent.width
                            text: model.name
                            color: "white"; font.pixelSize: 11
                            elide: Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    // Check mark
                    Rectangle {
                        anchors.top: parent.top; anchors.right: parent.right; anchors.margins: 4
                        width: 20; height: 20; radius: 10; color: "#6c5ce7"
                        visible: root.selectedFilterId === model.id
                        Text { anchors.centerIn: parent; text: "✓"; color: "white"; font.pixelSize: 12; font.bold: true }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            // Filter dùng ảnh gốc (root.photos) + frame → không phụ thuộc raw strip,
                            // có thể chọn ngay cả khi preview "Gốc" (cut mode) đang load.
                            if (root.selectedFilterId === model.id && !filterDebounceTimer.running) return
                            root.selectedFilterId = model.id
                            root.applyError       = ""
                            console.log("[FilterScreen] Filter queued (debounce):", model.id)
                            // Dùng debounce: restart timer mỗi click, chỉ click cuối được apply
                            filterDebounceTimer.pendingFilterId = model.id
                            filterDebounceTimer.restart()
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                text: root.showingFavoritesOnly
                      ? "Bạn chưa có filter yêu thích nào.\nVào Cài Đặt → Bộ Lọc Màu rồi ấn ☆ để chọn."
                      : "Chưa có bộ lọc nào.\nThêm filter trong Cài Đặt → Bộ Lọc Màu."
                color: Theme.textMuted; font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter; lineHeight: 1.5
                visible: filterListModel.count === 0
            }
        }
    }

    // ── Spacer đáy: các phần tử phía trên anchor vào bottomBar.top để chừa chỗ ──
    Item {
        id: bottomBar
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height: 160
    }

    // ── Nút "Hiện QR" — bật lại QR overlay nếu lỡ bấm X tắt ──────────────────
    // Chỉ hiện khi QR đang bật trong cài đặt, có link hợp lệ, nhưng đang bị ẩn.
    Button {
        id: showQrAgainBtn
        anchors.right: filterContinueBtn.left
        anchors.verticalCenter: filterContinueBtn.verticalCenter
        anchors.rightMargin: 16
        width: 180; height: 90
        z: 100
        visible: overlayArea.qrSettingEnabled
                 && !overlayArea.showQrInPrint
                 && overlayArea.qrUrlPath !== ""

        scale: showQrAgainBtn.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

        background: Rectangle {
            radius: 45
            color: showQrAgainBtn.pressed ? "#24496f" : "#2d5a8c"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: Text {
            text: "▦ Hiện QR"
            color: "#ffffff"
            font.pixelSize: 24; font.bold: true
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }

        onClicked: overlayArea.showQrInPrint = true
    }

    // ── Nút In Ảnh — chuẩn: góc dưới bên phải (thay nút Tiếp tục cũ) ──────────
    Button {
        id: filterContinueBtn
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 40
        anchors.bottomMargin: 40
        width: 255; height: 90
        z: 100
        enabled: !root.isApplying && !root.isProcessingFinal && !root._previewLoading && !root.isPrinting

        scale: filterContinueBtn.pressed ? 0.96 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }

        background: Rectangle {
            radius: 45
            color: !filterContinueBtn.enabled ? "#ad436d"
                 : filterContinueBtn.pressed  ? "#ad436d"
                 : filterContinueBtn.hovered  ? "#ad436d" : "#ad436d"
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        contentItem: Text {
            text: root.isProcessingFinal ? "Đang xử lý..."
                : root.isPrinting        ? "Đang in..."
                                         : "🖨 In Ảnh"
            color: filterContinueBtn.enabled ? "#ffffff" : Theme.textMuted
            font.pixelSize: 27; font.bold: true
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }

        onClicked: {
                root.isProcessingFinal = true
                var autoCut = root.eventData && root.eventData.autoCut
                var hasStickers = root._stickerActive && placedStickers.count > 0

                Qt.callLater(function() {
                    var finalPath
                    var filteredStrip = ""  // no-cut strip path; passed to ResultScreen as displayPath

                    // baseStrip = single strip used for stickers/auto-cut. If the frame was
                    // changed without a filter, rebuild from photos + the selected frame first;
                    // otherwise printing can reuse the old collage and miss the new frame.
                    var baseStrip
                    if (root.selectedFilterId !== "") {
                        baseStrip = root.previewPath.replace(/\?t=\d+$/, "")
                        filteredStrip = baseStrip
                    } else if (root._frameChanged) {
                        if (autoCut) {
                            var rebuilt = eventManager.processCollageNoCut(
                                root.eventId, root.photos, root.transforms || [], root.sessionId)
                            baseStrip = rebuilt
                            filteredStrip = rebuilt
                        } else {
                            baseStrip = eventManager.processCollageWithTransforms(
                                root.eventId, root.photos, root.transforms || [], root.sessionId)
                            filteredStrip = baseStrip
                        }
                    } else {
                        baseStrip = autoCut ? root.collagePath : root._originalCollagePath
                    }

                    // Dán sticker lên strip đơn (đồng nhất trên mọi bản copy sau khi nhân đôi)
                    if (hasStickers && baseStrip && baseStrip !== "") {
                        var arr = []
                        for (var i = 0; i < placedStickers.count; i++) {
                            var s = placedStickers.get(i)
                            arr.push({ "path": s.path, "xNorm": s.xN, "yNorm": s.yN,
                                       "wNorm": s.wN, "rotDeg": s.rot })
                        }
                        var stk = eventManager.applyStickersToStrip(baseStrip, arr)
                        if (stk && stk !== "") {
                            baseStrip = stk
                            filteredStrip = stk
                        }
                    }

                    if (root.selectedFilterId === "" && !hasStickers && !root._frameChanged) {
                        // Không filter, không sticker → dùng lại collage gốc, tránh tạo file thừa
                        var orig = root._originalCollagePath
                        finalPath = orig.startsWith("file:") ? orig : "file:///" + orig.replace(/\\/g, "/")
                        // Cut mode: baseStrip là strip ĐƠN (no-cut). Phải giữ lại làm
                        // filteredStrip — QR overlay "qw410cut" vẽ QR lên strip đơn RỒI
                        // mới ghép canvas; đưa canvas vào sẽ bị ghép chồng lần hai.
                        if (autoCut && baseStrip && baseStrip !== "" && !root.samePath(baseStrip, orig))
                            filteredStrip = baseStrip.startsWith("file:") ? baseStrip
                                          : "file:///" + baseStrip.replace(/\\/g, "/")
                    } else {
                        if (finalPath && finalPath !== "") {
                            // Already rebuilt above, for example non-cut frame change.
                        } else if (autoCut) {
                            // Nhân đôi/ba strip (đã dán sticker) thành canvas in
                            finalPath = eventManager.composeCutFromStrip(baseStrip, root.eventId)
                        } else {
                            finalPath = baseStrip.startsWith("file:") ? baseStrip
                                      : "file:///" + baseStrip.replace(/\\/g, "/")
                            filteredStrip = finalPath
                        }
                    }

                    // In tự do: luôn dùng strip đơn (không cắt) làm ảnh in, bỏ canvas cắt.
                    // Driver máy in thường sẽ tự scale theo khổ của nó.
                    if (root._freePrintEnabled && baseStrip && baseStrip !== "") {
                        finalPath = baseStrip.startsWith("file:") ? baseStrip
                                  : "file:///" + baseStrip.replace(/\\/g, "/")
                        filteredStrip = finalPath
                    }

                    root.isProcessingFinal = false
                    console.log("[FilterScreen] In Ảnh: finalPath=" + finalPath + " | filteredStrip=" + filteredStrip)

                    if (!finalPath || finalPath === "") {
                        root.applyError = "Không thể tạo ảnh cuối"
                        return
                    }

                    // Giữ ảnh đã finalize cho bước in.
                    root._finalPrintPath   = finalPath
                    root._finalDisplayPath = (filteredStrip && filteredStrip !== "") ? filteredStrip : finalPath

                    // Đã thanh toán trước (payment) → in thẳng; ngược lại → mở hộp chọn in.
                    if (root.prePaymentDone) {
                        if (root.preparePrePaymentPrint())
                            root.executePrint()
                    } else {
                        printOptionsDialog.open()
                    }
                })
            }
        }

    // ── Print Options Dialog (chọn chế độ cắt + số bản; chỉ khi TẮT thanh toán) ──
    Rectangle {
        id: printOptionsDialog

        property int photosPerSheet: {
            var p = printerConfig.selectedPrinter
            if (p.indexOf("QW410") >= 0 || p.indexOf("QW-410") >= 0 || p.indexOf("410") >= 0)
                return 3
            return 2
        }
        // Mặc định PHẢI khớp điều kiện dùng khi GHÉP ảnh ở EventManager:
        //   cutMode_compose = event.autoCut && printerConfig.cutMode
        property bool canCut: !!(root.eventData && root.eventData.autoCut) && printerConfig.cutMode
        property bool selectedCutMode: printOptionsDialog.canCut

        anchors.centerIn: parent
        width: 500
        height: 620
        color: Theme.field
        radius: 20
        border.color: Theme.border
        border.width: 2
        visible: false
        z: 1000

        Rectangle {
            anchors.fill: parent
            color: "#000000"; opacity: 0.5; z: -1
            anchors.centerIn: parent
            width: parent.parent.width
            height: parent.parent.height
        }

        function open() {
            printOptionsDialog.visible = true
            printOptionsDialog.selectedCutMode = printOptionsDialog.canCut
            var isCut = printOptionsDialog.selectedCutMode
            photosSpinner.value = isCut ? printOptionsDialog.photosPerSheet : 1
        }
        function close() { printOptionsDialog.visible = false }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 20

            Text {
                text: ""
                color: "white"; font.pixelSize: 28; font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }

            // Cut Mode Toggle
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 68
                radius: 10; border.width: 1
                color: cutModeMouse.containsMouse
                       ? (printOptionsDialog.selectedCutMode ? "#1e2d40" : Theme.field)
                       : "#FFFFFF"
                border.color: printOptionsDialog.selectedCutMode ? "#4ade80" : Theme.border
                Behavior on color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 14

                    Rectangle {
                        implicitWidth: 48; implicitHeight: 26; radius: 13
                        color: printOptionsDialog.selectedCutMode ? "#4ade80" : Theme.border
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Rectangle {
                            x: printOptionsDialog.selectedCutMode ? parent.width - width - 2 : 2
                            width: 22; height: 22; radius: 11; color: "#ffffff"
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on x { NumberAnimation { duration: 200 } }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "🔪 Chế độ cắt: " + (printOptionsDialog.selectedCutMode ? "CẮT" : "KHÔNG CẮT")
                            color: printOptionsDialog.selectedCutMode ? "#4ade80" : Theme.textMuted
                            font.pixelSize: 14; font.bold: true
                        }
                        Text {
                            text: printOptionsDialog.selectedCutMode
                                  ? ("Cắt thành " + printOptionsDialog.photosPerSheet + " ảnh / tờ")
                                  : "In nguyên tờ không cắt"
                            color: Theme.textMuted; font.pixelSize: 12
                        }
                    }
                }

                MouseArea {
                    id: cutModeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Chỉ cho phép BẬT cắt khi ảnh đã được ghép thành canvas 2 strip.
                        if (!printOptionsDialog.canCut && !printOptionsDialog.selectedCutMode) {
                            console.log("[FilterScreen] Bỏ qua bật cắt: ảnh không được ghép ở chế độ cắt",
                                        "(autoCut=", !!(root.eventData && root.eventData.autoCut),
                                        ", printerConfig.cutMode=", printerConfig.cutMode, ")")
                            return
                        }
                        printOptionsDialog.selectedCutMode = !printOptionsDialog.selectedCutMode
                        var isCut = printOptionsDialog.selectedCutMode
                        photosSpinner.value = isCut ? printOptionsDialog.photosPerSheet : 1
                    }
                }
            }

            // Image Preview
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                color: "#000000"; radius: 10
                border.color: Theme.border; border.width: 1

                Image {
                    id: printPreviewImage
                    anchors.fill: parent
                    anchors.margins: 5
                    source: toUrl(root._finalDisplayPath !== "" ? root._finalDisplayPath : root.previewPath)
                    fillMode: Image.PreserveAspectFit
                    cache: false; asynchronous: true
                    sourceSize: Qt.size(480, 140)
                }
                Text {
                    anchors.centerIn: parent
                    text: "Ảnh Xem Trước"
                    color: Theme.textMuted; font.pixelSize: 18
                    visible: printPreviewImage.status !== Image.Ready
                }
            }

            // Copies Section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: Theme.field; radius: 10
                border.color: Theme.border; border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    Text { text: "Số ảnh in"; color: Theme.textMuted; font.pixelSize: 18; font.bold: true }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 15

                        Button {
                            text: "-"
                            Layout.preferredWidth: 50; Layout.preferredHeight: 45
                            property int step: printOptionsDialog.selectedCutMode ? printOptionsDialog.photosPerSheet : 1
                            enabled: photosSpinner.value > step
                            background: Rectangle {
                                color: parent.hovered && parent.enabled ? Theme.border : Theme.field
                                radius: 8; border.color: Theme.border; border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text; color: parent.enabled ? "white" : Theme.textMuted
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: if (photosSpinner.value > step) photosSpinner.value -= step
                        }

                        Rectangle {
                            Layout.fillWidth: true; Layout.preferredHeight: 45
                            color: Theme.field; radius: 8
                            border.color: Theme.border; border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: photosSpinner.value + " ảnh"
                                color: "white"; font.pixelSize: 22; font.bold: true
                            }
                        }

                        Button {
                            text: "+"
                            Layout.preferredWidth: 50; Layout.preferredHeight: 45
                            property int step: printOptionsDialog.selectedCutMode ? printOptionsDialog.photosPerSheet : 1
                            property int max: printOptionsDialog.selectedCutMode ? printOptionsDialog.photosPerSheet * 4 : 4
                            enabled: photosSpinner.value < max
                            background: Rectangle {
                                color: parent.hovered && parent.enabled ? Theme.border : Theme.field
                                radius: 8; border.color: Theme.border; border.width: 1
                            }
                            contentItem: Text {
                                text: parent.text; color: parent.enabled ? "white" : Theme.textMuted
                                font.pixelSize: 20
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                            }
                            onClicked: if (photosSpinner.value < max) photosSpinner.value += step
                        }
                    }

                    Text {
                        property int toSend: printOptionsDialog.selectedCutMode
                                             ? Math.ceil(photosSpinner.value / printOptionsDialog.photosPerSheet)
                                             : photosSpinner.value
                        text: "→ Gửi máy in: " + toSend + " bản"
                        color: "#4ade80"; font.pixelSize: 13; font.bold: true
                        Layout.alignment: Qt.AlignHCenter
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Action Buttons
            RowLayout {
                Layout.fillWidth: true
                spacing: 15

                Button {
                    text: "Huỷ"
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    background: Rectangle { color: parent.hovered ? "#e74c3c" : "#c0392b"; radius: 10 }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: printOptionsDialog.close()
                }

                Button {
                    text: "In Ảnh"
                    Layout.fillWidth: true; Layout.preferredHeight: 50
                    background: Rectangle { color: parent.hovered ? "#2a8fff" : "#1e7eea"; radius: 10 }
                    contentItem: Text {
                        text: parent.text; color: "white"; font.pixelSize: 16; font.bold: true
                        horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.pendingPrintCutMode = printOptionsDialog.selectedCutMode
                        root.pendingPrintPhotos  = photosSpinner.value
                        root.executePrint()
                    }
                }
            }
        }
    }

    // Spinner value holder
    Item { id: photosSpinner; property int value: 1 }

    // ── Auto-scan popup: hiện khi máy in mặc định không phản hồi ──────────────
    Rectangle {
        id: autoScanPopup
        anchors.fill: parent
        color: "#BB000000"
        visible: false
        z: 3000

        Rectangle {
            anchors.centerIn: parent
            width: 480; height: 260
            color: Theme.field; radius: 20
            border.color: Theme.textMuted; border.width: 2

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 36
                spacing: 20

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 52; height: 52; radius: 26
                    color: "transparent"
                    border.color: "#1e7eea"; border.width: 4
                    RotationAnimator on rotation {
                        running: autoScanPopup.visible
                        from: 0; to: 360; duration: 800; loops: Animation.Infinite
                    }
                }
                Text {
                    text: "Vui lòng chờ"
                    color: "#ffffff"; font.pixelSize: 26; font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    id: autoScanStatusText
                    text: "Đang kiểm tra máy in..."
                    color: Theme.textMuted; font.pixelSize: 15
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
