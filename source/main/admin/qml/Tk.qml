// Hallmark · genre: editorial · macrostructure: Workbench (app) · design-system: design.md · designed-as-app
// Hallmark · pre-emit critique: P4 H5 E4 S5 R5 V4
pragma Singleton
import QtQuick

// Token của design.md (theme Studio) đổi từ OKLCH sang hex vì QML không hiểu oklch().
// Mọi màu / font / khoảng cách trong app admin PHẢI lấy từ đây, không viết số trần.
QtObject {
    // ── Màu ──────────────────────────────────────────────────────────────────
    readonly property color paper:        "#FBF2E6"   // oklch(96.5% 0.018 76)
    readonly property color paper2:       "#F2E8DA"   // oklch(93.5% 0.022 76)
    readonly property color paper3:       "#E5D9C8"   // oklch(89% 0.026 76)
    readonly property color surface:      "#FDF8F0"   // oklch(98% 0.012 76)
    readonly property color rule:         "#C2B5A6"   // oklch(78% 0.026 74)
    readonly property color ruleStrong:   "#9D8C78"   // oklch(65% 0.035 70)
    readonly property color neutral:      "#645141"   // oklch(45% 0.035 62)
    readonly property color muted:        "#493628"   // oklch(35% 0.035 58)
    readonly property color ink:          "#221106"   // oklch(20% 0.035 54)
    readonly property color accent:       "#6B3413"   // oklch(39% 0.09 48)
    readonly property color accentInk:    "#FDF8F0"   // oklch(98% 0.012 76)
    readonly property color accentSoft:   "#F5DCCC"   // oklch(91% 0.035 55)
    readonly property color focus:        "#A44100"   // oklch(50% 0.16 55)
    readonly property color price:        "#7C5500"   // oklch(48% 0.1 78)
    readonly property color success:      "#3C592B"   // oklch(43% 0.08 135)
    readonly property color successSoft:  "#DEEED6"   // oklch(93% 0.035 135)
    readonly property color error:        "#A52A24"   // oklch(48% 0.16 28)
    readonly property color errorSoft:    "#FFE0DB"   // oklch(93% 0.035 28)
    // Sidebar: cùng hue cocoa, hạ sáng — không thêm màu mới vào hệ thống.
    readonly property color side:         "#2B1B11"   // oklch(24% 0.03 54)
    readonly property color sideActive:   "#432D1F"   // oklch(32% 0.04 54)
    readonly property color sideInk:      "#E6DDD0"   // oklch(90% 0.02 76)
    readonly property color sideMuted:    "#A59585"   // oklch(68% 0.03 70)

    // ── Font (nhúng trong qrc, OFL) ──────────────────────────────────────────
    property FontLoader _display: FontLoader { source: Qt.resolvedUrl("fonts/Fraunces.ttf") }
    property FontLoader _body:    FontLoader { source: Qt.resolvedUrl("fonts/IBMPlexSans.ttf") }
    property FontLoader _mono:    FontLoader { source: Qt.resolvedUrl("fonts/IBMPlexMono-Regular.ttf") }
    property FontLoader _monoMd:  FontLoader { source: Qt.resolvedUrl("fonts/IBMPlexMono-Medium.ttf") }
    readonly property string display: _display.status === FontLoader.Ready ? _display.font.family : "Georgia"
    readonly property string body:    _body.status === FontLoader.Ready ? _body.font.family : "Segoe UI"
    // Mono chỉ dùng cho mã máy, OTP, serial, khoá — dữ liệu phải đọc từng ký tự.
    readonly property string mono:    _mono.status === FontLoader.Ready ? _mono.font.family : "Consolas"

    // ── Cỡ chữ (px, theo thang --text-* của tokens.css ở 16px) ────────────────
    readonly property int textXs: 12
    readonly property int textSm: 14
    readonly property int textBase: 16
    readonly property int textMd: 18
    readonly property int textLg: 22
    readonly property int textXl: 28
    readonly property int text2xl: 36
    readonly property int textOtp: 56

    // ── Khoảng cách (thang 4pt của tokens.css) ────────────────────────────────
    readonly property int s3xs: 2
    readonly property int s2xs: 4
    readonly property int sXs: 8
    readonly property int sSm: 12
    readonly property int sMd: 16
    readonly property int sLg: 24
    readonly property int sXl: 40
    readonly property int s2xl: 64

    readonly property int radiusSm: 12
    readonly property int radiusMd: 16
    readonly property int radiusLg: 24
    readonly property int radiusPill: 999
    readonly property int control: 44        // chiều cao tối thiểu control
    readonly property int durMicro: 120

    // ── Định dạng ─────────────────────────────────────────────────────────────
    function date(iso) {
        if (!iso) return "Vĩnh viễn"
        const d = new Date(iso)
        return isNaN(d.getTime()) ? iso : Qt.formatDateTime(d, "dd/MM/yyyy")
    }
    function dateTime(iso) {
        if (!iso) return "—"
        const d = new Date(iso)
        return isNaN(d.getTime()) ? iso : Qt.formatDateTime(d, "HH:mm · dd/MM/yyyy")
    }
    // "3 phút trước", "còn 5 giờ" …
    function relative(iso) {
        if (!iso) return ""
        const d = new Date(iso)
        if (isNaN(d.getTime())) return ""
        const diff = Math.round((d.getTime() - Date.now()) / 60000)   // phút
        const a = Math.abs(diff)
        let t
        if (a < 1) t = "vừa xong"
        else if (a < 60) t = a + " phút"
        else if (a < 60 * 24) t = Math.round(a / 60) + " giờ"
        else t = Math.round(a / 1440) + " ngày"
        if (t === "vừa xong") return t
        return diff < 0 ? t + " trước" : "còn " + t
    }
    function daysLeft(iso) {
        if (!iso) return -1
        const d = new Date(iso)
        return isNaN(d.getTime()) ? -1 : Math.ceil((d.getTime() - Date.now()) / 86400000)
    }
    function stateLabel(s) {
        return s === "licensed" ? "Đã kích hoạt" : s === "revoked" ? "Đã thu hồi" : "Chờ duyệt"
    }
    function tierLabel(t) {
        switch (t) {
        case "premium": return "Premium"
        case "studio": return "Studio"
        case "event": return "Sự kiện"
        case "event_studio": return "Sự kiện + Studio"
        case "studio_selfbooth": return "Studio + Selfbooth"
        case "trial": return "Dùng thử"
        }
        return t || "—"
    }
}
