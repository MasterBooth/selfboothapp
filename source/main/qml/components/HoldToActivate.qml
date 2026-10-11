import QtQuick
import QtQuick.Window

// Lớp chắn chống bấm nhầm cho nút ✕ (thoát) khi đang ở chế độ "tàng hình".
//
// Ở chế độ tàng hình nút ✕ vô hình nhưng vẫn bấm được — khách chạm trúng là mất
// phiên chụp giữa chừng. Lớp này bắt buộc phải GIỮ đủ holdMs mới kích hoạt.
// Nút ⚙ không cần vì đã có PIN chắn ở _openSettingsSecure.
//
// Cách dùng: đặt NGAY SAU nút cần bảo vệ, cùng cha, và fill theo nút đó —
// khai báo sau nên nằm trên nút trong thứ tự xếp chồng:
//
//     Button { id: closeBtn; ... ; onClicked: root.closeClicked() }
//     HoldToActivate { anchors.fill: closeBtn; onActivated: root.closeClicked() }
//
// Khi KHÔNG ở chế độ tàng hình, enabled = false nên chuột/chạm xuyên thẳng
// xuống nút bên dưới và nút hoạt động bình thường như cũ.
MouseArea {
    id: guard

    property int holdMs: 1000
    // Đang giữ — dùng để nút bên dưới hiện tạm cho người thao tác thấy phản hồi.
    readonly property bool holding: holdTimer.running

    signal activated()

    enabled: Window.window ? Window.window.appChromeGhost === true : false
    // Không nuốt sự kiện khi đang tắt, để nút bên dưới nhận như thường.
    visible: enabled
    hoverEnabled: false

    onPressed: holdTimer.restart()
    onReleased: holdTimer.stop()
    onCanceled: holdTimer.stop()

    Timer {
        id: holdTimer
        interval: guard.holdMs
        repeat: false
        onTriggered: guard.activated()
    }
}
