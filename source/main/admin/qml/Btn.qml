import QtQuick
import QtQuick.Controls

// Nút theo CTA voice của design.md:
//   primary   — nền cocoa, chữ kem, bo pill, cao tối thiểu 44
//   secondary — viền, không nền
//   danger    — viền + chữ đỏ (thu hồi / xoá)
//   quiet     — chữ gạch chân, không khung (thao tác phụ)
// Trạng thái: thường · hover · focus (vòng 2px, hiện tức thì) · nhấn · tắt · đang chạy.
AbstractButton {
    id: b
    property string variant: "primary"
    property bool loading: false
    property bool onDark: false          // nút nằm trên sidebar tối

    readonly property bool _filled: variant === "primary"
    readonly property color _fg: variant === "primary" ? Tk.accentInk
                               : variant === "danger" ? Tk.error
                               : onDark ? Tk.sideInk : Tk.ink

    implicitHeight: variant === "quiet" ? 32 : Tk.control
    implicitWidth: Math.max(variant === "quiet" ? 0 : 96, label.implicitWidth + (variant === "quiet" ? 0 : Tk.sLg * 2))
    enabled: !loading
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus

    contentItem: Text {
        id: label
        text: b.loading ? "Đang xử lý…" : b.text
        color: b._fg
        opacity: b.enabled || b.loading ? 1.0 : 0.45
        font.family: Tk.body
        font.pixelSize: Tk.textSm
        font.weight: Font.DemiBold
        font.underline: b.variant === "quiet"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1
    }

    background: Rectangle {
        radius: b.variant === "quiet" ? 4 : Tk.radiusPill
        color: {
            if (b.variant === "quiet") return "transparent"
            if (b._filled) {
                if (!b.enabled && !b.loading) return Tk.ruleStrong
                return b.down ? Tk.ink : b.hovered ? Qt.darker(Tk.accent, 1.12) : Tk.accent
            }
            if (b.down) return b.onDark ? Tk.sideActive : Tk.paper3
            if (b.hovered && b.enabled) return b.onDark ? Tk.sideActive
                                             : b.variant === "danger" ? Tk.errorSoft : Tk.paper2
            return "transparent"
        }
        border.width: b._filled || b.variant === "quiet" ? 0 : 1
        border.color: b.variant === "danger" ? Tk.error : b.onDark ? Tk.sideMuted : Tk.ruleStrong
        Behavior on color { ColorAnimation { duration: Tk.durMicro } }

        // Vòng focus bàn phím — không animate, hiện ngay.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: parent.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Tk.focus
            visible: b.visualFocus
        }
    }
}
