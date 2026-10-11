import QtQuick
import "../theme"

// Nạp sẵn thumbnail frame / filter / sticker của Mode 3 vào cache ảnh của Qt Quick,
// bắt đầu ngay khi khách chọn nhóm frame. Không có nó thì FilterScreen phải giải mã
// hàng chục ảnh in độ phân giải cao (vd 1181×3543) đúng lúc mở màn, khách ngồi nhìn
// các vòng tròn trống hiện dần.
//
// HAI ĐIỀU KIỆN để việc nạp sẵn có tác dụng:
//   1. Item này phải SỐNG tới khi FilterScreen mở — Qt Quick chỉ giữ chắc pixmap còn
//      được tham chiếu, ảnh không còn ai giữ có thể bị dọn khỏi cache bất cứ lúc nào.
//      → đặt nó ở BoothSession (sống suốt phiên), không đặt trong màn nào.
//   2. sourceSize phải trùng với CircleThumb, vì khoá cache gồm cả sourceSize.
//      → cả hai cùng lấy từ Mode3Layout.
Item {
    id: root

    // Số ảnh giải mã cùng lúc. Giữ thấp vì lúc này khách thường đang ở màn chụp có
    // live view — chiếm hết luồng giải mã sẽ làm live view giật.
    property int  concurrency: 2
    property bool active: true

    property var _sources: []
    property int _issued: 0      // số ảnh đã phát ra để nạp
    property int _finished: 0    // số ảnh đã nạp xong (kể cả lỗi)

    readonly property int  total: _sources.length
    readonly property int  ready: _finished
    readonly property bool done: total > 0 && _finished >= total

    visible: false
    width: 0
    height: 0

    // ── Helper đường dẫn (khớp với FilterScreen) ─────────────────────────────
    function toUrl(path) {
        if (!path || path === "") return ""
        if (path.startsWith("file:") || path.startsWith("qrc:") || path.startsWith("image:")
                || path.startsWith("http://") || path.startsWith("https://"))
            return path
        return "file:///" + path.replace(/\\/g, "/")
    }

    function normalizedFramePath(path) {
        var p = (path || "").toString().replace(/\?t=\d+$/, "")
        if (Qt.platform.os === "windows")
            p = p.replace(/^(file:\/{3})|(file:)/, "")
        else
            p = p.replace(/^(file:\/\/)/, "")
        return decodeURIComponent(p).replace(/\\/g, "/").toLowerCase()
    }

    function frameDisplayPath(path) {
        if (!path) return ""
        var img = eventManager.getAppSetting(
                    "frame_image_" + encodeURIComponent(normalizedFramePath(path)), "")
        return img !== "" ? img : path
    }

    function categoryOf(fileName) {
        var base = (fileName || "").replace(/\.png$/i, "")
        var idx = base.indexOf("__")
        return idx > 0 ? base.substring(0, idx) : "Khác"
    }

    // ── Dựng danh sách và bắt đầu nạp ────────────────────────────────────────
    function warm(eventId, category) {
        var list = []

        // Frame cùng nhóm — đắt nhất, vì là ảnh in độ phân giải cao.
        if (eventId > 0 && category && category !== "") {
            var layouts = eventManager.getLayouts(eventId)
            for (var i = 0; i < layouts.length; i++) {
                if (root.categoryOf(layouts[i].fileName) !== category) continue
                var fp = root.toUrl(root.frameDisplayPath(layouts[i].path))
                if (fp !== "") list.push(fp)
            }
        }

        // Filter — cùng quy tắc với FilterScreen: có filter yêu thích thì chỉ lấy nhóm đó.
        var favs = filterManager.getFavoriteFilters()
        var filters = (favs && favs.length > 0) ? favs : filterManager.getFilters()
        for (var j = 0; j < filters.length; j++) {
            var tp = root.toUrl(filters[j].thumbnailPath)
            if (tp !== "") list.push(tp)
        }

        // Sticker
        var stickers = stickerManager.getStickers()
        for (var k = 0; k < stickers.length; k++) {
            var sp = root.toUrl(stickers[k].path)
            if (sp !== "") list.push(sp)
        }

        root._finished = 0
        root._issued   = 0
        root._sources  = list
        root._pump()
        console.log("[Mode3Preloader] Nạp sẵn", list.length, "thumbnail | nhóm:", category)
    }

    function _pump() {
        while (root.active && root._issued < root.total
               && (root._issued - root._finished) < root.concurrency)
            root._issued++
    }

    onActiveChanged: if (root.active) root._pump()

    onDoneChanged: if (root.done) console.log("[Mode3Preloader] Xong", root.total, "thumbnail")

    // Mỗi Image giữ một tham chiếu tới pixmap trong cache — đó chính là thứ khiến
    // FilterScreen mở ra là có ảnh ngay. Không được xoá chúng đi.
    Repeater {
        model: root._issued
        delegate: Image {
            source: root._sources[index]
            sourceSize: Qt.size(Mode3Layout.thumbSourceSize, Mode3Layout.thumbSourceSize)
            asynchronous: true
            cache: true
            visible: false
            width: 1
            height: 1
            onStatusChanged: {
                if (status === Image.Ready || status === Image.Error) {
                    root._finished++
                    Qt.callLater(root._pump)
                }
            }
        }
    }
}
