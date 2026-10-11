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

    signal cutModeChosen(bool isCut)
    signal categoryChosen(string category)
    // Chế độ nhóm: phát ra cả nhóm và loại in (cut/nocut) đã chọn ở bước 1.
    signal categoryFlowChosen(string category, bool isCut)
    signal closeClicked()

    // Độ mờ nút điều khiển (⚙ / ✕) — 1.0 bình thường, 0.25 mờ, 0.0 tàng hình.
    // Dùng opacity nên nút vẫn bấm được ở đúng vị trí cũ dù không nhìn thấy.
    readonly property real _chromeOpacity: Window.window ? Window.window.appChromeOpacity : 1.0
    // Điều hướng về bước trước (ModeSelection / SelectServiceScreen).
    signal backClicked()
    // Ẩn nút Quay lại khi đây là màn đầu tiên (không còn màn trước để quay về).
    // Riêng bước chọn nhóm (categoryMode bước 2) vẫn hiện Back để quay về bước 1.
    property bool showBackButton: true
    property bool paymentMode: false
    property int eventId: -1
    property bool filterCategoriesBySelectedCut: false

    // Khi bật, hiển thị lưới nhóm (category) thay vì 2 ô Cắt / Không cắt.
    property bool categoryMode: eventManager.getAppSetting("frame_category_enabled", "false") === "true"
    // Bỏ bước Cắt/Không cắt (cỡ ảnh) → vào thẳng bước chọn nhóm (dùng cho mode1 & mode3).
    property bool startAtCategory: false
    // Ẩn nút X khi flow đã có nút Quay lại riêng.
    property bool showCloseButton: true
    // Bật đếm ngược phiên ở bước chọn nhóm (dùng cho mode3 — bước cuối trước thanh toán).
    property bool countdownEnabled: false

    // Quy trình chế độ nhóm: bước 1 = chọn Cắt/Không cắt, bước 2 = chọn nhóm.
    // (Chọn loại in trước để lọc khung trong nhóm đúng loại in.)
    property int _catStep: 1
    property bool _catChosenCut: false
    // Danh sách nhóm cấu hình ở Settings (phân tách bằng "|").
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
    property var _eventLayouts: []
    property bool _layoutsLoading: false
    property int _activeLayoutsEventId: -1
    property var displayCategoryList: {
        if (!root.filterCategoriesBySelectedCut)
            return root.categoryList
        return root.matchingCategories(root._catChosenCut)
    }

    function _resolveImg(p) {
        if (!p) return ""
        if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
        return "file:///" + p.replace(/\\/g, "/")
    }

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

    function matchingCategories(isCut) {
        var matched = {}
        for (var i = 0; i < root._eventLayouts.length; i++) {
            var item = root._eventLayouts[i]
            var metadata = item.metadata || ({})
            var w = metadata.width || 0
            var h = metadata.height || 0
            if (w <= 0 || h <= 0) continue
            if (root.layoutIsCut(w, h) !== isCut) continue
            matched[root.categoryOf(item.fileName)] = true
        }

        var out = []
        for (var j = 0; j < root.categoryList.length; j++) {
            var cat = root.categoryList[j]
            if (matched[cat])
                out.push(cat)
        }
        return out
    }

    function reloadEventLayouts() {
        if (!root.filterCategoriesBySelectedCut || root.eventId <= 0) {
            root._eventLayouts = []
            root._layoutsLoading = false
            root._activeLayoutsEventId = -1
            return
        }
        root._eventLayouts = []
        root._layoutsLoading = true
        root._activeLayoutsEventId = root.eventId
        eventManager.requestLayouts(root.eventId)
    }

    function ensureEventLayoutsLoaded() {
        if (!root.filterCategoriesBySelectedCut || root.eventId <= 0)
            return
        if (root._layoutsLoading)
            return
        if (root._activeLayoutsEventId !== root.eventId || root._eventLayouts.length === 0)
            root.reloadEventLayouts()
    }

    property color _themeBg: Window.window ? Window.window.appBgColor : "#000000"
    property color _themeText: Window.window ? Window.window.appTextColor : "#FFFFFF"
    property color _themeSurface: Window.window ? Window.window.appSurfaceColor : "#121212"
    property color _themeField: Window.window ? Window.window.appFieldColor : "#1A1A1A"
    property color _themeBorder: Window.window ? Window.window.appBorderColor : "#3A3A3A"
    property color _themeMutedText: Qt.rgba(_themeText.r, _themeText.g, _themeText.b, 0.65)
    // Bước 1 (chọn loại in) dùng nền cutmode; bước 2 (chọn nhóm khung hình) dùng nền nhóm riêng,
    // fallback về nền cutmode khi admin chưa đặt để không bị trống.
    property string _cutBgPath: eventManager.getAppSetting("cutmode_bg_image", "")
    property string _categoryBgPath: eventManager.getAppSetting("layout_category_bg_image", "")
    property string backgroundImagePath: {
        if (root.categoryMode && root._catStep === 2 && _categoryBgPath !== "")
            return _categoryBgPath
        return _cutBgPath !== "" ? _cutBgPath : "qrc:/assets/bg/cut_mode.png"
    }
    property bool _isActiveScreen: StackView.status === StackView.Active
                                || StackView.status === StackView.Activating

    color: "transparent"

    // Bỏ bước Cắt/Không cắt → bắt đầu luôn ở bước chọn nhóm.
    Component.onCompleted: {
        if (root.startAtCategory && root.categoryMode)
            root._catStep = 2
        root.reloadEventLayouts()
    }

    onEventIdChanged: root.reloadEventLayouts()
    onFilterCategoriesBySelectedCutChanged: root.reloadEventLayouts()
    onCategoryModeChanged: root.reloadEventLayouts()

    Connections {
        target: eventManager
        function onLayoutsReady(eventId, layouts) {
            if (!root.filterCategoriesBySelectedCut) return
            if (eventId !== root._activeLayoutsEventId) return
            root._layoutsLoading = false
            root._eventLayouts = layouts
        }
    }

    Rectangle {
        anchors.fill: parent
        visible: root.backgroundImagePath === ""
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.lighter(root._themeBg, 1.08) }
            GradientStop { position: 1.0; color: Qt.darker(root._themeBg,  1.30) }
        }
    }

    BackgroundMedia {
        anchors.fill: parent
        sourcePath: root.backgroundImagePath
        visible: root.backgroundImagePath !== ""
    }

    // ── Top bar ──────────────────────────────────────────────────────────────
    Item {
        id: topBar
        width: parent.width
        height: 100
        anchors.top: parent.top
        z: 10

        Text {
            anchors.centerIn: parent
            text: root.categoryMode ? "" : ""
            color: "#ffffff"
            font.pixelSize: 36
            font.weight: Font.Bold
            visible: false
        }

        // Đếm ngược phiên — chỉ ở bước chọn nhóm (step 2), số trần cạnh nút X.
        Text {
            id: cmCountdown
            visible: root.countdownEnabled && root.categoryMode && root._catStep === 2
            anchors.right: cmCloseBtn.left
            anchors.verticalCenter: cmCloseBtn.verticalCenter
            anchors.rightMargin: 24
            text: cmCountdownTimer.remaining + "s"
            color: cmCountdownTimer.remaining <= 10 ? "#FF4422" : "#ffffff"
            font.pixelSize: 52; font.bold: true
            style: Text.Outline; styleColor: "#88000000"
            z: 20
            Behavior on color { ColorAnimation { duration: 300 } }
        }

        Timer {
            id: cmCountdownTimer
            property int remaining: parseInt(eventManager.getAppSetting("layout_selection_countdown", "60")) || 60
            interval: 1000
            repeat: true
            running: root.countdownEnabled && root.categoryMode && root._catStep === 2
                     && root.StackView.status === StackView.Active
                     && remaining > 0
            onTriggered: {
                remaining--
                if (remaining <= 0) {
                    // Hết giờ chưa chọn nhóm → tự chọn nhóm đầu tiên (kèm loại in đã chọn).
                    if (root.displayCategoryList.length > 0)
                        root.categoryFlowChosen(root.displayCategoryList[0], root._catChosenCut)
                    else if (root.filterCategoriesBySelectedCut)
                        return
                    else
                        root.closeClicked()
                }
            }
        }

        Button {
            id: cmCloseBtn
            visible: root.showCloseButton && (!root.categoryMode || root._catStep === 1)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 40
            width: 60; height: 60
            opacity: cmCloseGuard.holding ? 0.65 : root._chromeOpacity
            Behavior on opacity { NumberAnimation { duration: 180 } }
            background: Rectangle {
                color: parent.hovered ? "#ff4757" : Theme.field
                radius: 30
                border.color: parent.hovered ? "#ff4757" : Theme.border
                border.width: 2
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            contentItem: Text {
                text: "✕"; color: "white"
                font.pixelSize: 28; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: root.closeClicked()
        }

        // Chống khách chạm nhầm khi nút ✕ tàng hình: phải giữ 1 giây mới thoát.
        HoldToActivate {
            id: cmCloseGuard
            anchors.fill: cmCloseBtn
            onActivated: root.closeClicked()
        }
    }

    // ── Center content ────────────────────────────────────────────────────────
    Item {
        anchors.top: topBar.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        // Vuốt ngang để xem & chọn (các ô to nên có thể tràn màn → cho cuộn ngang).
        Flickable {
            id: modeFlick
            // Hiện ở luồng thường, hoặc ở bước 1 của chế độ nhóm.
            visible: !root.categoryMode || root._catStep === 1
            anchors.centerIn: parent
            width: parent.width
            height: root.portrait ? 740 : 840
            // Lề trái khớp với nút "Xem Ảnh" (góc trên-trái) → thumbnail luôn bắt đầu
            // cùng vị trí x đó, không sát mép. Cùng giá trị với leftMargin của nút.
            readonly property int leftPad: 140
            // Đủ chỗ → không cuộn; tràn (vd 3 ô) → cuộn sang phải, vẫn chừa lề 2 bên.
            contentWidth: Math.max(width, modeRow.width + leftPad * 2)
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds
            clip: false

            Row {
                id: modeRow
                height: parent.height
                spacing: root.portrait ? 80 : 120
                // Bắt đầu từ lề trái (cùng x với nút "Xem Ảnh"), không quá sát mép.
                x: modeFlick.leftPad

            // ── Ảnh cắt ──────────────────────────────────────────────────
            Column {
                spacing: 24
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    width: root.portrait ? 600 : 740
                    height: root.portrait ? 740 : 840

                    Image {
                        id: cutThumb
                        anchors.fill: parent
                        source: {
                            var p = eventManager.getAppSetting("cutmode_thumbnail_cut", "")
                            if (!p) return "qrc:/assets/bg/thumb_cut.png"
                            if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
                            return "file:///" + p.replace(/\\/g, "/")
                        }
                        fillMode: Image.PreserveAspectFit
                        visible: source !== ""
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.field
                        border.color: "#1e7eea"
                        border.width: 3
                        visible: cutThumb.source === ""

                        Column {
                            anchors.centerIn: parent
                            spacing: 20
                            Text { text: "✂️"; font.pixelSize: 80; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "Ảnh Cắt"; color: "#ffffff"; font.pixelSize: 28; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.categoryMode) {
                                // Lưu loại in rồi sang bước chọn nhóm.
                                root._catChosenCut = true
                                root.ensureEventLayoutsLoaded()
                                root._catStep = 2
                                cmCountdownTimer.remaining = parseInt(eventManager.getAppSetting("layout_selection_countdown", "60")) || 60
                            } else {
                                root.cutModeChosen(true)
                            }
                        }
                    }
                }

                
            }

            // ── Ảnh không cắt ────────────────────────────────────────────
            Column {
                spacing: 24
                anchors.verticalCenter: parent.verticalCenter

                Item {
                    width: root.portrait ? 600 : 740
                    height: root.portrait ? 740 : 840

                    Image {
                        id: noCutThumb
                        anchors.fill: parent
                        source: {
                            var p = eventManager.getAppSetting("cutmode_thumbnail_nocut", "")
                            if (!p) return "qrc:/assets/bg/thumb_nocut.png"
                            if (p.startsWith("http") || p.startsWith("file:") || p.startsWith("qrc:")) return p
                            return "file:///" + p.replace(/\\/g, "/")
                        }
                        fillMode: Image.PreserveAspectFit
                        visible: source !== ""
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.field
                        border.color: "#4caf50"
                        border.width: 3
                        visible: noCutThumb.source === ""

                        Column {
                            anchors.centerIn: parent
                            spacing: 20
                            Text { text: "🖼️"; font.pixelSize: 80; anchors.horizontalCenter: parent.horizontalCenter }
                            Text { text: "Ảnh Không Cắt"; color: "#ffffff"; font.pixelSize: 28; font.weight: Font.Bold; anchors.horizontalCenter: parent.horizontalCenter }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.categoryMode) {
                                root._catChosenCut = false
                                root.ensureEventLayoutsLoaded()
                                root._catStep = 2
                                cmCountdownTimer.remaining = parseInt(eventManager.getAppSetting("layout_selection_countdown", "60")) || 60
                            } else {
                                root.cutModeChosen(false)
                            }
                        }
                    }
                }


            }
        }
        }

        // ── Danh sách nhóm theo chiều ngang ─────────────────────────────────
        Item {
            id: catStrip
            visible: root.categoryMode && root._catStep === 2
                     && !root._layoutsLoading
                     && root.displayCategoryList.length > 0
            anchors.centerIn: parent
            width: parent.width
            height: root.portrait ? 740 : 840

            ListView {
                id: catListView
                // Kích thước thumbnail nhóm khớp với ô chọn loại in ở bước 1 để đồng bộ.
                readonly property int cellW:    root.portrait ? 600 : 740
                readonly property int cellH:    root.portrait ? 740 : 840
                readonly property int cellWAlt: Math.round(cellW * 0.62)
                readonly property int cellHAlt: Math.round(cellH * 0.62)

                anchors.centerIn: parent
                width: parent.width
                height: cellH

                orientation: ListView.Horizontal
                spacing: 32
                model: root.displayCategoryList
                clip: false
                currentIndex: 0

                leftMargin:  (width - cellW) / 2
                rightMargin: (width - cellW) / 2

                snapMode: ListView.SnapToItem
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: (width - cellW) / 2
                preferredHighlightEnd:   (width - cellW) / 2 + cellW
                highlightMoveDuration: 300

                highlight: Item {}

                delegate: Item {
                    id: del
                    width: catListView.cellW
                    height: catListView.height

                    property bool isCurrent: ListView.isCurrentItem
                    // Ưu tiên ảnh hiển thị của nhóm; nếu chưa đặt → fallback về thumbnail
                    // (thumbnail vẫn dùng cho slot/mode3, không thay thế).
                    property string thumbSrc: root._resolveImg(
                        eventManager.getAppSetting("cate_image_" + modelData, "") !== ""
                            ? eventManager.getAppSetting("cate_image_" + modelData, "")
                            : eventManager.getAppSetting("cate_thumb_" + modelData, ""))

                    Item {
                        id: card
                        width:  del.isCurrent ? catListView.cellW : catListView.cellWAlt
                        height: del.isCurrent ? catListView.cellH : catListView.cellHAlt
                        anchors.centerIn: parent

                        Behavior on width  { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

                        Image {
                            anchors.fill: parent
                            source: del.thumbSrc
                            fillMode: Image.PreserveAspectFit
                            visible: del.thumbSrc !== ""
                            asynchronous: true
                            smooth: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.field
                            radius: 8
                            visible: del.thumbSrc === ""

                            Text {
                                anchors.centerIn: parent
                                text: "🗂️"
                                font.pixelSize: del.isCurrent ? 100 : 70
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                catListView.currentIndex = index
                                // Phát kèm loại in đã chọn ở bước 1 để lọc khung.
                                root.categoryFlowChosen(modelData, root._catChosenCut)
                            }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: root.categoryMode && root._catStep === 2 && root._layoutsLoading

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: parent.visible
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Đang tải khung hình..."
                color: Theme.textMuted
                font.pixelSize: 24
            }
        }

        // Thông báo khi bật chọn theo nhóm nhưng chưa cấu hình nhóm nào
        Text {
            anchors.centerIn: parent
            visible: root.categoryMode && root._catStep === 2
                     && !root._layoutsLoading
                     && root.displayCategoryList.length === 0
            text: root.filterCategoriesBySelectedCut
                  ? "Không có nhóm khung hình phù hợp với lựa chọn này.\nVui lòng quay lại và chọn kiểu cắt khác."
                  : "Chưa có nhóm khung hình.\nVui lòng thêm nhóm trong Cài đặt → Khung frame."
            color: Theme.textMuted
            font.pixelSize: 24
            horizontalAlignment: Text.AlignHCenter
        }
    }

    // ── Nút Quay lại — mũi tên trần căn giữa, chữ nằm dưới (góc dưới trái) ────
    Item {
        id: backPill
        // Ẩn khi là màn đầu; vẫn hiện ở bước chọn nhóm để quay về bước 1
        // (trừ khi đã bỏ bước Cắt/Không cắt — lúc đó không còn bước 1 để về).
        visible: root.showBackButton || (root.categoryMode && root._catStep === 2 && !root.startAtCategory)
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 40
        anchors.bottomMargin: 40
        width: 160; height: 150
        z: 100

        scale: backMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }

        Column {
            anchors.centerIn: parent
            spacing: 6

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "‹"
                color: Theme.text
                opacity: backMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 84; font.bold: true
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Back"
                color: Theme.text
                opacity: backMouse.containsMouse ? 1.0 : 0.85
                font.pixelSize: 30; font.weight: Font.Bold
                horizontalAlignment: Text.AlignHCenter
                Behavior on opacity { NumberAnimation { duration: 130 } }
            }
        }

        MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                // Ở bước chọn nhóm → quay về bước chọn loại in; còn lại → về trang trước.
                // Khi đã bỏ bước Cắt/Không cắt thì không quay về bước 1 nữa.
                if (root.categoryMode && root._catStep === 2 && !root.startAtCategory)
                    root._catStep = 1
                else
                    root.backClicked()
            }
        }
    }
}
