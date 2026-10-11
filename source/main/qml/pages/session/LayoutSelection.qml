import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"
import "../../components"

Rectangle {
    id: root
    width: Window.window ? Window.window._designW : 1920
    height: Window.window ? Window.window._designH : 1080
    readonly property bool portrait: Window.window && Window.window.isPortrait

    property int eventId: -1
    property var eventData: null
    property string selectedLayoutPath: ""
    property int selectedSlotCount: 3
    // "event" keeps the existing behavior; "selfbooth" reads the dedicated
    // machine-wide Selfbooth frame repository.
    property string layoutSource: "event"
    property int paymentModeOverride: -1
    property bool countdownEnabled: true
    property bool alwaysShowTitle: false
    property string titleText: ""
    // Ẩn nút X khi flow đã có nút Quay lại riêng.
    // Mặc định TẮT: trong flow chụp xong → chọn layout, không cho khách thoát
    // phiên bằng nút X (tránh bấm nhầm). Chỉ điều hướng bằng Back/Next.
    property bool showCloseButton: false
    // Ẩn nút Quay lại khi đây là màn đầu (không còn màn trước để quay về).
    property bool showBackButton: true

    // -1 = hiển thị tất cả, 0 = nocut, 1 = cut
    property int cutModeFilter: -1

    // "" = không lọc theo nhóm; ngược lại chỉ hiện frame thuộc category này
    property string categoryFilter: ""
    property bool categoryPickerMode: false
    property bool _showCategoryPicker: categoryPickerMode && categoryFilter === ""
    property var categoryList: {
        var raw = eventManager.getAppSetting("frame_categories", "")
        var out = []
        var parts = raw.split("|")
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].trim()
            if (t.length > 0) out.push(t)
        }
        return out
    }

    signal layoutSelected(string layoutPath, int slotCount, string printLabel, int printPrice, bool isCut)
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    // Điều hướng về bước trước (CutModeScreen / ModeSelection).
    signal backClicked()

    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    property string _paymentBgPath: eventManager.getAppSetting("layout_selection_bg_image", "")
    property string _categoryBgPath: eventManager.getAppSetting("layout_category_bg_image", "")
    property string backgroundImagePath: {
        if (root._showCategoryPicker && _categoryBgPath !== "") return _categoryBgPath
        if (_paymentBgPath !== "") return _paymentBgPath
        var dash = root.Window.window ? root.Window.window.dashboardBgImage : ""
        return dash !== "" ? dash : "qrc:/assets/frame.png"
    }
    property bool _paymentEnabled: paymentModeOverride >= 0
                                   ? paymentModeOverride > 0
                                   : eventManager.getAppSetting("payment_enabled", "false") === "true"
    // Kiểu "frame hàng dưới" (preview lớn + dải thumbnail): luôn dùng khi payment tắt;
    // ở mode2 thì dùng khi admin bật toggle "hiển thị frame hàng dưới".
    property bool _bottomStripMode: !_paymentEnabled
        || (eventManager.getAppSetting("app_operation_mode","mode1") === "mode2"
            && eventManager.getAppSetting("mode2_show_bottom_strip","false") === "true")
    // 0 = tắt (hành vi cũ); 3/5/7 = số layout đại diện hiển thị cùng lúc (chỉ carousel)
    property int _previewCount: parseInt(eventManager.getAppSetting("layout_preview_count", "0")) || 0
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating
    color: "transparent"

    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

    // ── Background ───────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        color: root._themeBg
        z: -2
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
        z: -2
    }


    // Dark vignette disabled: keep layout selection background clean.
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        z: -1
        visible: false
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: "#CC000000" }
            GradientStop { position: 0.4; color: "#00000000" }
            GradientStop { position: 0.8; color: "#00000000" }
            GradientStop { position: 1.0; color: "#EE000000" }
        }
    }

    ListModel { id: layoutModel }
    ListModel { id: categoryPickerModel }
    property bool _layoutsLoading: false
    property bool _completed: false
    property bool _reloadQueued: false
    property bool _categoryReloadQueued: false
    property int _layoutRequestSeq: 0
    property int _activeLayoutRequestSeq: 0
    property string _activeLayoutRequestKey: ""

    Component.onCompleted: {
        root._completed = true
        loadLayouts()
    }

    onEventIdChanged: queueLayoutReload()
    onCutModeFilterChanged: queueLayoutReload()
    onCategoryFilterChanged: queueLayoutReload()
    onLayoutSourceChanged: queueLayoutReload()
    onCategoryPickerModeChanged: queueLayoutReload()
    onCategoryListChanged: queueCategoryPickerReload()

    function _layoutRequestKey() {
        return root.layoutSource + "|" + root.eventId + "|" + root.cutModeFilter + "|"
             + root.categoryFilter + "|" + (root.categoryPickerMode ? "cat" : "layout")
    }

    function queueLayoutReload() {
        if (!root._completed || root._reloadQueued) return
        root._reloadQueued = true
        Qt.callLater(function() {
            root._reloadQueued = false
            root.loadLayouts()
        })
    }

    function queueCategoryPickerReload() {
        if (!root._completed || root._categoryReloadQueued) return
        root._categoryReloadQueued = true
        Qt.callLater(function() {
            root._categoryReloadQueued = false
            root.rebuildCategoryPickerModel()
        })
    }

    // Nhận kết quả async từ backend
    Connections {
        target: eventManager
        function onLayoutsReady(eventId, layouts) {
            if (root.layoutSource !== "event") return
            if (eventId !== root.eventId) return
            if (root._activeLayoutRequestKey !== root._layoutRequestKey()) {
                console.log("LayoutSelection: ignoring stale layouts for filters",
                            root._activeLayoutRequestKey, "current", root._layoutRequestKey())
                return
            }
            root._layoutsLoading = false
            layoutModel.clear()
            root.appendLayouts(layouts)
            root.rebuildCategoryPickerModel()
            if (layoutModel.count > 0) selectLayout(0)
        }
        function onLayoutUploaded(eventId) {
            if (root.layoutSource === "selfbooth" && eventId === -2)
                root.loadLayouts()
        }
    }

    // Tách tên nhóm (category) từ tên file dạng "Category__name.png".
    // Không có tiền tố "__" → trả "Khác".
    function categoryOf(fileName) {
        var base = (fileName || "").replace(/\.png$/i, "")
        var idx = base.indexOf("__")
        return idx > 0 ? base.substring(0, idx) : "Khác"
    }

    function layoutIsCut(w, h) {
        if (w <= 0 || h <= 0) return false
        var aspect = w / h
        var isQW410 = printerConfig.selectedPrinter
                        ? printerConfig.selectedPrinter.indexOf("QW410") >= 0
                        : false
        return isQW410 ? (aspect > 0.38 && aspect <= 0.55)
                       : (aspect <= 0.45 || aspect > 2.0)
    }

    function loadLayouts() {
        root._layoutRequestSeq++
        root._activeLayoutRequestSeq = root._layoutRequestSeq
        root._activeLayoutRequestKey = root._layoutRequestKey()
        root._layoutsLoading = true
        root.selectedLayoutPath = ""
        root.selectedSlotCount = 3
        root.selectedIsCut = false
        layoutModel.clear()
        if (root._showCategoryPicker)
            root.rebuildCategoryPickerModel()
        if (root.layoutSource === "selfbooth") {
            root.appendLayouts(eventManager.getSelfBoothLayouts())
            root._layoutsLoading = false
            if (layoutModel.count > 0) selectLayout(0)
            return
        }
        if (root.eventId <= 0) {
            root._layoutsLoading = false
            return
        }
        console.log("LayoutSelection: request layouts", root._activeLayoutRequestSeq,
                    "event", root.eventId, "cut", root.cutModeFilter,
                    "category", root.categoryFilter)
        eventManager.requestLayouts(root.eventId)
    }

    function appendLayouts(layouts) {
        var beforeCount = layoutModel.count
        for (var i = 0; i < layouts.length; i++) {
            var item = layouts[i]
            var metadata = item.metadata || ({})
            var w = metadata.width || 0
            var h = metadata.height || 0
            var isCut = root.layoutIsCut(w, h)
            if (root._showCategoryPicker) continue
            if (root.cutModeFilter >= 0 && isCut !== (root.cutModeFilter === 1))
                continue
            if (root.categoryFilter !== ""
                    && root.categoryOf(item.fileName) !== root.categoryFilter)
                continue
            layoutModel.append({
                "fileName": item.fileName,
                "path": item.path,
                "slotCount": metadata.slot_count || 3,
                "layoutWidth": w,
                "layoutHeight": h,
                "isCut": isCut
            })
        }
        console.log("LayoutSelection: appended", layoutModel.count - beforeCount,
                    "of", layouts.length, "layouts for cut", root.cutModeFilter,
                    "category", root.categoryFilter)
    }

    function selectLayout(index) {
        if (index < 0 || index >= layoutModel.count) return
        var item = layoutModel.get(index)
        root.selectedLayoutPath = item.path
        root.selectedSlotCount  = item.slotCount
        root.selectedIsCut      = item.isCut
        root.selectedCategoryName = root.categoryFilter !== "" ? root.categoryFilter : root.categoryOf(item.fileName || "")
        strip.currentIndex      = index
        strip.positionViewAtIndex(index, ListView.Center)
        // carousel dùng StrictlyEnforceRange với range ôm tâm 1 slot → chỉ cần
        // đổi currentIndex, ListView tự cuộn ô về chính giữa. Không gọi
        // positionViewAtIndex để tránh double-scroll/giật.
        carousel.currentIndex   = index
    }

    property bool selectedIsCut: false
    property string selectedCategoryName: ""

    function emitSelectedLayout() {
        if (root.selectedLayoutPath === "") return
        var category = root.selectedCategoryName || root.categoryFilter || ""
        var price = category !== ""
            ? (parseInt(eventManager.getAppSetting("cate_price_" + category, "0"), 10) || 0)
            : 0
        root.layoutSelected(root.selectedLayoutPath, root.selectedSlotCount, category, price, root.selectedIsCut)
    }

    function _isEventLayoutPath(path) {
        var p = (path || "").replace(/\\/g, "/")
        return p.indexOf("/Photobooth/Events/") >= 0 && p.indexOf("/Layouts/") >= 0
    }

    function _layoutInfoFromItem(item) {
        if (!item) return null
        var metadata = item.metadata || ({})
        var w = metadata.width || item.layoutWidth || 0
        var h = metadata.height || item.layoutHeight || 0
        var isCut = root.layoutIsCut(w, h)
        return {
            "path": item.path || "",
            "slotCount": metadata.slot_count || item.slotCount || 3,
            "width": w,
            "height": h,
            "isCut": isCut
        }
    }

    function _firstLayoutInCategory(category) {
        if (root.eventId <= 0) return null
        var layouts = eventManager.getLayouts(root.eventId)
        for (var i = 0; i < layouts.length; i++) {
            var item = layouts[i]
            if (root.categoryOf(item.fileName) !== category)
                continue
            var info = root._layoutInfoFromItem(item)
            if (!info || info.path === "")
                continue
            if (root.cutModeFilter >= 0 && info.isCut !== (root.cutModeFilter === 1))
                continue
            return info
        }
        return null
    }

    function _categoryLayoutInfo(category) {
        var thumbPath = eventManager.getAppSetting("cate_thumb_" + category, "")
        if (thumbPath !== "" && root._isEventLayoutPath(thumbPath)) {
            if (!eventManager.ensureLayoutMetadata(thumbPath))
                console.warn("LayoutSelection Mode3: category thumbnail metadata is missing:", thumbPath)

            var width = eventManager.getLayoutWidth(thumbPath)
            var height = eventManager.getLayoutHeight(thumbPath)
            if (width > 0 && height > 0) {
                return {
                    "path": thumbPath,
                    "width": width,
                    "height": height,
                    "isCut": root.layoutIsCut(width, height)
                }
            }
        }

        return root._firstLayoutInCategory(category)
    }

    function rebuildCategoryPickerModel() {
        categoryPickerModel.clear()
        if (!root._showCategoryPicker)
            return

        var cutRows = []
        var noCutRows = []
        for (var i = 0; i < root.categoryList.length; i++) {
            var category = root.categoryList[i]
            var info = root._categoryLayoutInfo(category)
            var row = {
                "name": category,
                "isCut": info ? info.isCut : false,
                "sectionStart": false
            }
            if (row.isCut)
                cutRows.push(row)
            else
                noCutRows.push(row)
        }

        for (var c = 0; c < cutRows.length; c++)
            categoryPickerModel.append(cutRows[c])
        for (var n = 0; n < noCutRows.length; n++) {
            noCutRows[n].sectionStart = cutRows.length > 0 && n === 0
            categoryPickerModel.append(noCutRows[n])
        }
        if (categoryPickerModel.count > 0) {
            categoryListView.currentIndex = 0
            Qt.callLater(function() {
                if (categoryPickerModel.count > 0)
                    categoryListView.positionViewAtIndex(0, ListView.Beginning)
            })
        }
    }

    function chooseCategory(category) {
        var thumbPath = eventManager.getAppSetting("cate_thumb_" + category, "")
        var chosen = null

        if (thumbPath !== "" && root._isEventLayoutPath(thumbPath)) {
            if (!eventManager.ensureLayoutMetadata(thumbPath))
                console.warn("LayoutSelection Mode3: default frame metadata is missing or has no slots:", thumbPath)

            var slotCount = eventManager.getLayoutSlotCount(thumbPath)
            var width = eventManager.getLayoutWidth(thumbPath)
            var height = eventManager.getLayoutHeight(thumbPath)
            var isCut = root.layoutIsCut(width, height)
            if (root.cutModeFilter < 0 || isCut === (root.cutModeFilter === 1)) {
                chosen = {
                    "path": thumbPath,
                    "slotCount": slotCount,
                    "width": width,
                    "height": height,
                    "isCut": isCut
                }
            }
        }

        if (!chosen)
            chosen = root._firstLayoutInCategory(category)

        if (!chosen) {
            console.warn("LayoutSelection Mode3: category has no matching frame:", category)
            return
        }

        var price = parseInt(eventManager.getAppSetting("cate_price_" + category, "0"), 10) || 0
        root.selectedLayoutPath = chosen.path
        root.selectedSlotCount = chosen.slotCount
        root.selectedIsCut = chosen.isCut
        root.selectedCategoryName = category
        root.layoutSelected(chosen.path, chosen.slotCount, category, price, chosen.isCut)
    }

    function resetCategoryChoice() {
        root.categoryFilter = ""
        loadLayouts()
    }

    // =========================================================
    // TOP BAR
    // =========================================================
    Item {
        id: topBar
        width: parent.width
        height: 90
        anchors.top: parent.top
        z: 10

        // Gradient fade at top disabled: no black overlay on the top area.
        Rectangle {
            anchors.fill: parent
            visible: false
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#DD000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }
        }

        // Title — ẩn tiêu đề khi bật thanh toán
        Text {
            anchors.centerIn: parent
            text: root._showCategoryPicker ? "" : root.titleText
            color: "#ffffff"
            font.pixelSize: 30
            font.weight: Font.Bold
            // Mode3 (thanh toán bật): ẩn tiêu đề "Chọn Nhóm Khung Hình" ở bước chọn nhóm.
            visible: root.alwaysShowTitle || !root._paymentEnabled
        }

        // Countdown — góc trên-phải (cạnh trái nút X), số trần, không nền/icon
        Text {
            anchors.right: closeLayoutBtn.left
            anchors.verticalCenter: closeLayoutBtn.verticalCenter
            anchors.rightMargin: 24
            visible: root._paymentEnabled && root.countdownEnabled
            text: countdownTimer.remaining + "s"
            color: "#8B5A2B"
            font.pixelSize: 52
            font.bold: true
            style: Text.Normal
            z: 20
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        // Nút X tròn — luôn hiện, bấm → về ModeSelection
        Button {
            id: closeLayoutBtn
            visible: root.showCloseButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            width: 60
            height: 60
            z: 20
            opacity: closeLayoutGuard.holding ? 0.65 : root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }

            background: Rectangle {
                color: closeLayoutBtn.hovered ? "#ff4757" : Theme.field
                radius: 30
                border.color: closeLayoutBtn.hovered ? "#ff4757" : Theme.border
                border.width: 2
                opacity: closeLayoutBtn.hovered ? 1.0 : 0.8
                Behavior on color       { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            contentItem: Text {
                text: "✕"
                color: "white"
                font.pixelSize: 28
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            scale: closeLayoutBtn.hovered ? 1.08 : 1.0
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            onClicked: root.closeClicked()
        }

        // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
        HoldToActivate {
            id: closeLayoutGuard
            anchors.fill: closeLayoutBtn
            onActivated: root.closeClicked()
        }

        Timer {
            id: countdownTimer
            property int remaining: parseInt(eventManager.getAppSetting("layout_selection_countdown", "60")) || 60
            interval: 1000
            repeat: true
            // Chạy khi bật thanh toán và trang đang Active trong StackView.
            // Dùng binding (thay vì start() trong onCompleted) để tránh bị
            // StackView.onStatusChanged dừng timer trong lúc chuyển trang
            // (status = Activating) khiến đếm ngược không bao giờ chạy.
            running: root._paymentEnabled
                     && root.countdownEnabled
                     && !root._showCategoryPicker
                     && root.StackView.status === StackView.Active
                     && remaining > 0
            onTriggered: {
                // Đếm ngược đang chạy mà chưa chọn frame → chọn frame đầu tiên
                if (root.selectedLayoutPath === "" && layoutModel.count > 0)
                    selectLayout(0)
                remaining--
                if (remaining <= 0) {
                    if (layoutModel.count > 0) {
                        if (root.selectedLayoutPath === "") selectLayout(0)
                        root.emitSelectedLayout()
                    } else {
                        root.closeClicked()
                    }
                }
            }
        }

    }

    // ── Nút Quay lại — mũi tên trần căn giữa, chữ nằm dưới (góc dưới trái) ────
    // Giữ width cố định: thumbnailRow neo theo backPill.right.
    Item {
        id: backPill
        visible: root.showBackButton
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: lsBackMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "‹"
                color: "#7A4B2A"
                opacity: lsBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back"
                color: "#7A4B2A"
                opacity: lsBackMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: lsBackMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.categoryPickerMode && root.categoryFilter !== "")
                    root.resetCategoryChoice()
                else
                    root.backClicked()
            }
        }
    }

    // =========================================================
    // MODE 3 — Category picker before selecting layouts
    // =========================================================
    Item {
        id: categoryPicker
        visible: root._showCategoryPicker
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: categoryPickerModel.count === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "🗂"
                font.pixelSize: 72
                opacity: 0.35
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Chưa có nhóm frame nào.\nVui lòng tạo nhóm trong Cài Đặt → Khung frame."
                color: "#6680a8"
                font.pixelSize: 22
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.5
            }
        }

        ListView {
            id: categoryListView
            visible: categoryPickerModel.count > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.portrait ? 60 : 100
            height: root.portrait ? Math.min(720, parent.height * 0.72) : 560
            orientation: ListView.Horizontal
            spacing: 36
            model: categoryPickerModel
            clip: true
            interactive: true
            boundsBehavior: Flickable.DragOverBounds
            flickDeceleration: 2500
            maximumFlickVelocity: 5000
            snapMode: ListView.SnapToItem
            highlightRangeMode: ListView.NoHighlightRange
            highlightMoveDuration: 0
            leftMargin: root.portrait ? 24 : 80
            rightMargin: leftMargin

            property int itemWidth: root.portrait ? 300 : 340
            property int itemHeight: root.portrait ? 640 : 520
            property int sectionGap: root.portrait ? 96 : 120
            property real _moveStartX: 0

            onMovementStarted: _moveStartX = contentX
            onMovementEnded: _wrapOrSnap()
            onFlickEnded: _wrapOrSnap()

            function _wrapOrSnap() {
                if (count <= 1) {
                    _snapToCenter()
                    return
                }

                var dx = contentX - _moveStartX
                if (atXEnd && dx > 24) {
                    currentIndex = 0
                    positionViewAtIndex(0, ListView.Beginning)
                    return
                }
                if (atXBeginning && dx < -24) {
                    currentIndex = count - 1
                    positionViewAtIndex(count - 1, ListView.End)
                    return
                }

                _snapToCenter()
            }

            function _snapToCenter() {
                var idx = indexAt(contentX + width / 2, height / 2)
                if (idx < 0) idx = Math.round(contentX / (itemWidth + spacing))
                idx = Math.max(0, Math.min(idx, count - 1))
                currentIndex = idx
                positionViewAtIndex(idx, ListView.Center)
            }

            delegate: Item {
                width: categoryListView.itemWidth + (model.sectionStart ? categoryListView.sectionGap : 0)
                height: categoryListView.itemHeight

                property string catName: model.name
                property string displayPath: eventManager.getAppSetting("cate_image_" + catName, "") !== ""
                                             ? eventManager.getAppSetting("cate_image_" + catName, "")
                                             : eventManager.getAppSetting("cate_thumb_" + catName, "")
                // Hiển thị: ưu tiên ảnh (cate_image_) khách đã tải lên; nếu chưa có
                // thì dùng file thumbnail (cate_thumb_ — cũng là file layout) làm ảnh.
                property string thumbSrc: root._resolveImg(displayPath)

                Item {
                    x: model.sectionStart ? categoryListView.sectionGap : 0
                    width: categoryListView.itemWidth
                    height: parent.height

                    Image {
                        anchors.fill: parent
                        source: thumbSrc
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                        smooth: true
                        visible: thumbSrc !== ""
                    }

                    SlotNumberOverlay {
                        anchors.fill: parent
                        layoutPath: root._isEventLayoutPath(displayPath) ? displayPath : ""
                        numberColor: "#7A4B2A"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "🖼"
                        font.pixelSize: 72
                        opacity: 0.28
                        visible: thumbSrc === ""
                    }

                    MouseArea {
                        id: categoryMouse
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        property int _pressX: 0
                        property bool _drag: false
                        onPressed: (e) => { _pressX = e.x; _drag = false }
                        onPositionChanged: (e) => { if (Math.abs(e.x - _pressX) > 10) _drag = true }
                        onReleased: {
                            if (_drag) return
                            categoryListView.currentIndex = index
                            categoryListView.positionViewAtIndex(index, ListView.Center)
                            root.chooseCategory(catName)
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // CENTER — Large preview of selected layout
    // =========================================================
    Item {
        id: centerArea
        visible: root._bottomStripMode && !root._showCategoryPicker
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bottomStrip.top
        anchors.topMargin: root.portrait ? 8 : 20
        anchors.bottomMargin: 16

        // Loading indicator (hiện khi đang fetch async)
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: root._layoutsLoading
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: root._layoutsLoading }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Đang tải khung hình..."
                color: "#6080a0"; font.pixelSize: 18
            }
        }

        // Empty state
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: !root._layoutsLoading && layoutModel.count === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "🖼️"
                font.pixelSize: 72
                opacity: 0.3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.layoutSource === "selfbooth"
                      ? "Chưa có khung frame Selfbooth.\nVui lòng tải frame trong Cài đặt Selfbooth."
                      : "Chưa có khung hình nào.\nVui lòng upload layout trong Cài Đặt Event."
                color: "#445577"; font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.6
            }
        }

        // Preview container — centers the image preserving aspect ratio
        Item {
            anchors.fill: parent
            visible: layoutModel.count > 0 && root.selectedLayoutPath !== ""

            // Soft glow behind preview
            Rectangle {
                anchors.centerIn: previewImg
                width: previewImg.paintedWidth + 40
                height: previewImg.paintedHeight + 40
                radius: 16
                color: "transparent"
                border.color: Qt.rgba(0.31, 0.64, 0.95, 0.25)
                border.width: 20
            }

            Image {
                id: previewImg
                anchors.fill: parent
                anchors.margins: root.portrait ? 12 : 30
                source: root._resolveImg(root.selectedLayoutPath)
                fillMode: Image.PreserveAspectFit
                smooth: true
                cache: true

                Behavior on source {
                    // Fade transition when switching layouts
                    SequentialAnimation {
                        NumberAnimation { target: previewImg; property: "opacity"; to: 0.0; duration: 80 }
                        PropertyAction  { target: previewImg; property: "source" }
                        NumberAnimation { target: previewImg; property: "opacity"; to: 1.0; duration: 160 }
                    }
                }

                // Đánh số + tô màu các ô đục lỗ của layout đang xem
                SlotNumberOverlay {
                    anchors.fill: parent
                    layoutPath: root.selectedLayoutPath
                }
            }

            // Selected label overlay (bottom of preview)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 8
                visible: layoutModel.count > 0
                width: labelRow.width + 32; height: 36; radius: 18
                color: "#CC0D1020"
                border.color: Theme.border
                border.width: 1

                Row {
                    id: labelRow
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: "#4FA4F2"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: layoutModel.count > 0 && strip.currentIndex >= 0 && strip.currentIndex < layoutModel.count
                              ? layoutModel.get(strip.currentIndex).fileName : ""
                        color: "#1F2937"
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                }
            }

            // Layout counter badge (top-right of preview area)
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 8
                visible: layoutModel.count > 1
                width: counterText.width + 20; height: 28; radius: 14
                color: "#CC0D1020"
                border.color: Theme.border
                border.width: 1

                Text {
                    id: counterText
                    anchors.centerIn: parent
                    text: (strip.currentIndex + 1) + " / " + layoutModel.count
                    color: "#7090C0"
                    font.pixelSize: 13
                }
            }
        }
    }

    // =========================================================
    // BOTTOM STRIP — thumbnail row + arrows + continue button
    // =========================================================
    Item {
        id: bottomStrip
        visible: root._bottomStripMode && !root._showCategoryPicker
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: root.portrait ? 180 : 210
        property real thumbnailScale: 1.3

        // Keep the bottom frame strip fully transparent so the page background
        // remains visible behind transparent frame artwork.
        Rectangle {
            anchors.fill: parent
            color: "transparent"
        }

        // (Đã bỏ nút mũi tên điều hướng trái/phải — vuốt để lướt khung hình.)

        // Thumbnail horizontal strip
        Item {
            id: thumbnailRow
            // backPill là con của root (không phải sibling) → né bằng leftMargin
            // theo geometry của backPill thay vì anchor trực tiếp.
            anchors.left: parent.left
            anchors.leftMargin: root.showBackButton
                ? (backPill.x + backPill.width + (root.portrait ? 8 : 16))
                : 40
            anchors.right: continueBtn.left
            anchors.top: parent.top
            anchors.bottom: dotRow.top
            anchors.rightMargin: root.portrait ? 8 : 16
            // Enlarge the thumbnail display area by about 30% upward while
            // keeping the navigation buttons at their existing positions.
            anchors.topMargin: 20 - Math.round((bottomStrip.height - 46)
                                               * (bottomStrip.thumbnailScale - 1.0))
            anchors.bottomMargin: 8
            clip: true

            // Edge guards intentionally stay transparent (no black overlay).
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 40
                z: 5
                color: "transparent"
            }
            Rectangle {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 40
                z: 5
                color: "transparent"
            }

            ListView {
                id: strip
                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: 10
                clip: true
                interactive: true
                flickDeceleration: 2000
                maximumFlickVelocity: 4000
                boundsBehavior: Flickable.StopAtBounds
                snapMode: ListView.SnapToItem
                highlightFollowsCurrentItem: false
                model: layoutModel

                property int thumbH: height
                property int thumbW: Math.round(thumbH * 0.72)

                highlight: Item {}

                onMovementEnded: _snap()
                onFlickEnded:    _snap()

                function _snap() {
                    var idx = indexAt(contentX + width / 2, height / 2)
                    if (idx < 0) idx = Math.round(contentX / (thumbW + spacing))
                    idx = Math.max(0, Math.min(idx, count - 1))
                    currentIndex = idx
                    positionViewAtIndex(idx, ListView.Center)
                    root.selectedLayoutPath = layoutModel.get(idx).path
                    root.selectedSlotCount  = layoutModel.get(idx).slotCount
                }

                delegate: Item {
                    id: thumb
                    width: strip.thumbW
                    height: strip.thumbH

                    property bool isCurrent: ListView.isCurrentItem

                    Rectangle {
                        anchors.centerIn: parent
                        width: strip.thumbW
                        height: strip.thumbH
                        radius: 10

                        // Selected: blue border + slight scale up
                        scale: thumb.isCurrent ? 1.0 : 0.88
                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }

                        color: "transparent"
                        border.color: thumb.isCurrent ? "#4FA4F2" : Theme.border
                        border.width: thumb.isCurrent ? 2 : 1
                        Behavior on border.color { ColorAnimation { duration: 180 } }

                        // Thumbnail image
                        Image {
                            anchors.fill: parent
                            anchors.margins: 6
                            source: root._resolveImg(model.path)
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            cache: true
                            asynchronous: true
                            // Giới hạn decode size — thumbnail không cần full resolution
                            sourceSize.width: 320
                            sourceSize.height: 320

                            // Placeholder khi đang decode
                            Text {
                                anchors.centerIn: parent
                                text: "🖼️"
                                font.pixelSize: 24
                                opacity: 0.2
                                visible: parent.status !== Image.Ready
                            }

                            // Đánh số + tô màu các ô đục lỗ
                            SlotNumberOverlay {
                                anchors.fill: parent
                                layoutPath: model.path
                            }
                        }

                        // Selected check mark
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 6
                            width: 20; height: 20; radius: 10
                            color: "#4FA4F2"
                            opacity: thumb.isCurrent ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 180 } }

                            Text {
                                anchors.centerIn: parent
                                text: "✓"; color: "#ffffff"
                                font.pixelSize: 11; font.weight: Font.Bold
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            property int _pressX: 0
                            property bool _drag: false
                            onPressed:  (e) => { _pressX = e.x; _drag = false }
                            onPositionChanged: (e) => { if (Math.abs(e.x - _pressX) > 10) _drag = true }
                            onReleased: (e) => { if (!_drag) selectLayout(index) }
                        }
                    }
                }
            }
        }

        // Dot indicators
        Row {
            id: dotRow
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: thumbnailRow.horizontalCenter
            anchors.bottomMargin: 12
            spacing: 7
            visible: layoutModel.count > 1 && layoutModel.count <= 20

            Repeater {
                model: layoutModel.count
                Rectangle {
                    width:  strip.currentIndex === index ? 22 : 6
                    height: 6; radius: 3
                    color:  strip.currentIndex === index ? "#4FA4F2" : Theme.textMuted
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        // Continue button — mũi tên trần căn giữa, chữ nằm dưới (phải strip)
        Item {
            id: continueBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: root.portrait ? 16 : 40
            width: 160; height: 150

            opacity: root.selectedLayoutPath !== "" ? 1.0 : 0.35
            Behavior on opacity { NumberAnimation { duration: 200 } }

            scale: continueMouse.pressed ? 0.92 : 1.0
            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "›"
                    color: "#ad436d"
                    opacity: continueMouse.containsMouse ? 1.0 : 0.9
                    font.pixelSize: 84; font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Next"
                    color: "#ad436d"
                    opacity: continueMouse.containsMouse ? 1.0 : 0.9
                    font.pixelSize: 30; font.weight: Font.Bold
                    horizontalAlignment: Text.AlignHCenter
                    Behavior on opacity { NumberAnimation { duration: 130 } }
                }
            }

            MouseArea {
                id: continueMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: root.selectedLayoutPath !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    root.emitSelectedLayout()
                }
            }
        }
    }

    // =========================================================
    // NEW CAROUSEL DESIGN — hiển thị khi bật thanh toán
    // =========================================================
    Item {
        id: carouselDesign
        visible: !root._bottomStripMode && !root._showCategoryPicker
        anchors.top: topBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Loading indicator
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: root._layoutsLoading
            BusyIndicator { anchors.horizontalCenter: parent.horizontalCenter; running: root._layoutsLoading }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Đang tải khung hình..."
                color: "#6080a0"; font.pixelSize: 18
            }
        }

        // Empty state
        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: !root._layoutsLoading && layoutModel.count === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "🖼️"; font.pixelSize: 72; opacity: 0.3
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.layoutSource === "selfbooth"
                      ? "Chưa có khung frame Selfbooth.\nVui lòng tải frame trong Cài đặt Selfbooth."
                      : "Chưa có khung hình nào.\nVui lòng upload layout trong Cài Đặt Event."
                color: "#445577"; font.pixelSize: 20
                horizontalAlignment: Text.AlignHCenter
                lineHeight: 1.6
            }
        }

        // Carousel content
        Item {
            anchors.fill: parent
            visible: !root._layoutsLoading && layoutModel.count > 0

            // ── Strip area (arrows + carousel coverflow) ────────────────
            Item {
                id: caStripArea
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: caBottomArea.top
                anchors.topMargin: 10
                anchors.bottomMargin: 10

                // (Đã bỏ nút mũi tên điều hướng trái/phải — vuốt để lướt khung hình.)

                // Horizontal carousel
                Item {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: root.portrait ? 12 : 36
                    anchors.rightMargin: root.portrait ? 12 : 36
                    clip: true

                    ListView {
                        id: carousel
                        anchors.fill: parent
                        orientation: ListView.Horizontal
                        // Khoảng hở rộng để ô đang chọn phóng to (tràn ra ngoài slot)
                        // không đè lên ảnh của 2 ô kề bên — tạo bố cục coverflow.
                        // N lớn → thu hẹp khe để ô không bị bóp quá nhỏ.
                        spacing: root.portrait ? 28
                               : (root._previewCount <= 0  ? 90
                               : (root._previewCount <= 7  ? 90
                               : (root._previewCount <= 11 ? 48 : 28)))
                        clip: true
                        interactive: true
                        flickDeceleration: 2500
                        maximumFlickVelocity: 5000
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: true
                        highlightRangeMode: ListView.StrictlyEnforceRange
                        highlightMoveDuration: 280
                        // Range = đúng 1 slot ở CHÍNH GIỮA view → ô đang chọn luôn
                        // được cuộn về tâm màn hình rồi mới phóng to. Mọi ô cùng
                        // slotW nên range này ôm trọn tâm 1 ô.
                        preferredHighlightBegin: width / 2 - carousel.slotW / 2
                        preferredHighlightEnd:   width / 2 + carousel.slotW / 2
                        model: layoutModel
                        highlight: Item {}

                        // Chiều rộng slot ĐỒNG ĐỀU cho mọi ô — điều kiện để canh
                        // tâm ổn định (begin/end ôm trọn 1 ô ở giữa).
                        // _previewCount > 0 → chia bề rộng view cho số ô cần thấy
                        // để N layout vừa khít; ô đang chọn vẫn căn chính giữa.
                        property real slotW: {
                            if (root._previewCount <= 0)
                                return Math.round(Math.min(height * 0.62, width * 0.34))  // hành vi cũ
                            var n = root._previewCount                                    // 3/5/7
                            var avail = width - spacing * (n - 1)
                            return Math.round(Math.min(avail / n, height * 0.62))
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0 && currentIndex < layoutModel.count) {
                                root.selectedLayoutPath = layoutModel.get(currentIndex).path
                                root.selectedSlotCount  = layoutModel.get(currentIndex).slotCount
                                root.selectedIsCut      = layoutModel.get(currentIndex).isCut
                                strip.currentIndex = currentIndex
                            }
                        }

                        delegate: Item {
                            id: caThumb

                            property bool isCurrent: ListView.isCurrentItem

                            // Tỉ lệ thật của layout (rộng / cao). Fallback 0.72 nếu
                            // thiếu metadata để không chia cho 0.
                            property real aspect: (model.layoutWidth > 0 && model.layoutHeight > 0)
                                                  ? (model.layoutWidth / model.layoutHeight)
                                                  : 0.72

                            // --- Kích thước HIỂN THỊ (animate) — ô đang chọn to hơn,
                            // tràn ra ngoài slot và nổi lên trên (z cao) → coverflow.
                            property bool isNoCutLayout: model.isCut === false
                            property real cellH: Math.round(
                                carousel.height * (isCurrent
                                    ? (isNoCutLayout ? 0.82 : 0.74)
                                    : (isNoCutLayout ? 0.64 : 0.58)))
                            // Hệ số phóng ô giữa: N nhỏ → slotW lớn nên phóng ít để
                            // không đè ô kề bên; N lớn → slotW nhỏ nên phóng nhiều hơn
                            // để ô giữa vẫn đủ to/nổi bật. N=0 (tắt) giữ nguyên 2.4.
                            property real _baseCurScale: root._previewCount <= 0  ? 1.55
                                                        : (root._previewCount <= 3  ? 1.25
                                                        : (root._previewCount <= 5  ? 1.45
                                                        : (root._previewCount <= 7  ? 1.6
                                                        : (root._previewCount <= 11 ? 1.9
                                                        : (root._previewCount <= 13 ? 2.1 : 2.3)))))
                            property real _curScale: _baseCurScale * (isNoCutLayout ? 1.18 : 1.0)
                            property real cellW: Math.min(
                                Math.round(cellH * aspect),
                                Math.round(carousel.slotW * (isCurrent ? _curScale : 1.0)))

                            // width TĨNH & ĐỒNG ĐỀU cho mọi ô → ListView canh tâm ô
                            // current vào tâm view chuẩn. Phần phóng to nằm ở Rectangle
                            // bên trong (nở quanh tâm slot), tràn lên khoảng spacing
                            // nên không đè ảnh ô kề bên.
                            width: carousel.slotW
                            height: carousel.height

                            // Ô đang chọn nổi lên trên để phần to ra không bị
                            // các thumbnail kế bên che mất.
                            z: isCurrent ? 2 : 0

                            Rectangle {
                                anchors.centerIn: parent
                                width:  caThumb.cellW
                                height: caThumb.cellH
                                radius: 0

                                Behavior on width  { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

                                opacity: caThumb.isCurrent ? 1.0 : 0.45
                                Behavior on opacity { NumberAnimation { duration: 260 } }

                                color: "transparent"
                                border.width: 0

                                Image {
                                    anchors.fill: parent
                                    source: root._resolveImg(model.path)
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    cache: true
                                    asynchronous: true
                                    sourceSize.width: 480
                                    sourceSize.height: 480

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🖼️"
                                        font.pixelSize: 36
                                        opacity: 0.2
                                        visible: parent.status !== Image.Ready
                                    }

                                    // Đánh số + tô màu các ô đục lỗ
                                    SlotNumberOverlay {
                                        anchors.fill: parent
                                        layoutPath: model.path
                                    }
                                }

                                // Selected check mark
                                Rectangle {
                                    anchors.top: parent.top
                                    anchors.right: parent.right
                                    anchors.margins: 10
                                    width: 28; height: 28; radius: 14
                                    color: "#4FA4F2"
                                    opacity: caThumb.isCurrent ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"; color: "#ffffff"
                                        font.pixelSize: 15; font.weight: Font.Bold
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    property int _pressX: 0
                                    property bool _drag: false
                                    onPressed:  (e) => { _pressX = e.x; _drag = false }
                                    onPositionChanged: (e) => { if (Math.abs(e.x - _pressX) > 10) _drag = true }
                                    onReleased: (e) => { if (!_drag) selectLayout(index) }
                                }
                            }
                        }
                    }
                }
            }

            // ── Bottom area: counter + centered continue button ─────────
            Item {
                id: caBottomArea
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 170

                // Counter X / total
                Text {
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: layoutModel.count > 1 ? (carousel.currentIndex + 1) + " / " + layoutModel.count : ""
                    color: "#7090B0"
                    font.pixelSize: 18
                    visible: layoutModel.count > 1
                }

                // Dot indicators
                Row {
                    id: caDotRow
                    anchors.top: parent.top
                    anchors.topMargin: 34
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    visible: layoutModel.count > 1 && layoutModel.count <= 20

                    Repeater {
                        model: layoutModel.count
                        Rectangle {
                            width:  carousel.currentIndex === index ? 26 : 7
                            height: 7; radius: 4
                            color:  carousel.currentIndex === index ? "#4FA4F2" : Theme.textMuted
                            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                        }
                    }
                }

                // Continue button — mũi tên trần căn giữa, chữ nằm dưới
                Item {
                    id: caContinueBtn
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.rightMargin: 40
                    width: 160; height: 150

                    opacity: root.selectedLayoutPath !== "" ? 1.0 : 0.35
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    scale: caContMouse.pressed ? 0.92 : 1.0
                    Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

                    Column {
                        anchors.centerIn: parent
                        spacing: 6

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "›"
                            color: "#ad436d"
                            opacity: caContMouse.containsMouse ? 1.0 : 0.9
                            font.pixelSize: 84; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "Next"
                            color: "#ad436d"
                            opacity: caContMouse.containsMouse ? 1.0 : 0.9
                            font.pixelSize: 30; font.weight: Font.Bold
                            horizontalAlignment: Text.AlignHCenter
                            Behavior on opacity { NumberAnimation { duration: 130 } }
                        }
                    }

                    MouseArea {
                        id: caContMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.selectedLayoutPath !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                            root.emitSelectedLayout()
                        }
                    }
                }
            }
        }
    }

    // =========================================================
    // SLOT NUMBER OVERLAY — đánh số + tô màu các ô đục lỗ của layout
    // =========================================================
    // Phủ lên ảnh layout (PreserveAspectFit): mỗi ô đục lỗ một màu đặc riêng + số
    // thứ tự (1,2,3…). Tự nạp hình học ô từ metadata của layoutPath. Không chứa
    // MouseArea nên không chặn thao tác chọn.
    component SlotNumberOverlay: Item {
        id: ov
        property string layoutPath: ""
        property color numberColor: "#ffffff"
        property real origW: 0
        property real origH: 0
        property var  slots: []

        // Bảng màu phân biệt cho từng ô (lặp lại nếu nhiều hơn số màu)
        readonly property var _palette: [
            "#E53935", "#1E88E5", "#43A047", "#FB8C00", "#8E24AA",
            "#00ACC1", "#FDD835", "#D81B60", "#3949AB", "#7CB342"
        ]

        onLayoutPathChanged: _reload()
        Component.onCompleted: _reload()

        function _reload() {
            ov.slots = []
            ov.origW = 0
            ov.origH = 0
            if (!layoutPath) return
            var meta = eventManager.loadLayoutMetadata(layoutPath)
            if (!meta || !meta.slots || meta.slots.length === 0) {
                if (eventManager.ensureLayoutMetadata(layoutPath))
                    meta = eventManager.loadLayoutMetadata(layoutPath)
            }
            if (!meta || !meta.slots || meta.slots.length === 0) return
            ov.origW = meta.width || 0
            ov.origH = meta.height || 0
            ov.slots = meta.slots
        }

        // Painted-rect của ảnh PreserveAspectFit trong chính item này
        readonly property real _scale: (origW > 0 && origH > 0)
            ? Math.min(width / origW, height / origH) : 0
        readonly property real _offX: (width  - origW * _scale) / 2
        readonly property real _offY: (height - origH * _scale) / 2

        Repeater {
            model: ov.slots
            delegate: Rectangle {
                x:      ov._offX + (modelData.x      || 0) * ov._scale
                y:      ov._offY + (modelData.y      || 0) * ov._scale
                width:  (modelData.width  || 0) * ov._scale
                height: (modelData.height || 0) * ov._scale
                visible: ov._scale > 0 && width > 0 && height > 0
                color: ov._palette[index % ov._palette.length]
                radius: Math.min(width, height) * 0.04
                border.color: Qt.rgba(1, 1, 1, 0.85)
                border.width: Math.max(1, Math.min(width, height) * 0.02)

                Text {
                    anchors.centerIn: parent
                    text: index + 1
                    color: ov.numberColor
                    font.bold: true
                    font.pixelSize: Math.max(10, Math.min(parent.width, parent.height) * 0.5)
                    style: Text.Outline
                    styleColor: "#66000000"
                }
            }
        }
    }
}
