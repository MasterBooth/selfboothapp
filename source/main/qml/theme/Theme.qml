pragma Singleton
import QtQuick

QtObject {
    // ── BRAND CỐ ĐỊNH — admin dùng theme này, không cho khách đổi ──
    property color bg:      "#000000"   // nền chính
    property color text:    "#FFFFFF"   // chữ chính

    // ── token phụ trợ ──
    property color surface: "#121212"   // nền card/panel
    property color field:   "#2E2E2E"   // nền input/field (xám rõ)
    property color border:  "#3A3A3A"   // viền

    // ── chữ phụ / mờ (suy ra từ text) ──
    property color textMuted: Qt.rgba(text.r, text.g, text.b, 0.65)

    // ── màu ngữ nghĩa (cố định, tinh chỉnh tập trung tại đây) ──
    readonly property color primary: "#1E7EEA"   // xanh accent (#1e7eea/#4fa4f2)
    readonly property color success: "#22C55E"   // xanh lá (#4caf50/#22c55e/#4ade80)
    readonly property color danger:  "#E74C3C"   // đỏ (#c62828/#d32f2f/#e74c3c)
    readonly property color warning: "#FF9800"   // cam (#ff9800/#f0c040)

    // ── SETTINGS / ADMIN — Warm Luxury ───────────────────────────────
    // Các token này tách khỏi theme booth tối để giao diện quản trị luôn có
    // độ tương phản ổn định trên ảnh nền thương hiệu.
    readonly property color settingsCanvas:     "#FFFFFF"
    readonly property color settingsSurface:    "#FFFFFF"
    readonly property color settingsCard:       "#FFFFFF"
    readonly property color settingsBorder:     "#E8DDD5"
    readonly property color settingsText:       "#2A211C"
    readonly property color settingsTextMuted:  "#766A62"
    readonly property color settingsCopper:     "#C96F4A"
    readonly property color settingsCopperDark: "#A95435"
    readonly property color settingsCopperSoft: "#FBE8DD"
    readonly property color settingsSuccess:    "#2E8B65"
    readonly property color settingsWarning:    "#C58A33"
    readonly property color settingsDanger:     "#C94F4F"

    readonly property int settingsRadiusSmall:  12
    readonly property int settingsRadiusMedium: 16
    readonly property int settingsRadiusLarge:  24
}
