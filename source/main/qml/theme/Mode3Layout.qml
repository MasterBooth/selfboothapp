pragma Singleton
import QtQuick

// Hằng số bố cục 3 cột của FilterScreen ở Mode 3:
//     FRAME (trái) │ LAYOUT (giữa) │ FILTER + STICKER (phải)
//
// Để ở singleton vì Mode3ThumbPreloader (chạy từ BoothSession) cũng phải biết kích
// thước thumbnail để nạp sẵn ảnh vào cache TRƯỚC khi mở FilterScreen — khoá cache của
// Qt Quick gồm cả sourceSize, lệch một pixel là cache trượt và việc nạp sẵn mất tác dụng.
//
// Chỉnh bố cục cho khớp chữ vẽ trên ảnh nền thì sửa ở đây, không sửa rải rác nơi khác.
QtObject {
    readonly property int circle:      92    // đường kính thumbnail tròn (dùng chung cả 3 nhóm)
    readonly property int colWidth:   466    // bề rộng cột trái/phải
    readonly property int sideMargin:  70    // lề ngoài của 2 cột
    readonly property int rowSpacing:  18    // khoảng cách dọc giữa các hàng
    readonly property int topOffset:   30    // dịch cụm frame/filter xuống thêm so với mốc đáy
    readonly property int colsPerRow:   4    // số thumbnail nhìn thấy cùng lúc trên 1 hàng
    readonly property int frameRows:    3
    readonly property int filterRows:   4
    readonly property int stickerRows:  1

    // Khoảng cách ngang giữa các thumbnail, suy ra từ bề rộng cột.
    readonly property real itemSpacing: (colWidth - colsPerRow * circle) / (colsPerRow - 1)
    // Khoảng nghỉ giữa cụm filter và hàng sticker.
    readonly property int  stickerGap:  Math.round(rowSpacing / 2)

    // Chiều cao cột phải = (4 hàng filter + 1 hàng sticker) + 5 khoảng cách + khoảng nghỉ.
    // Cột được đặt sao cho đáy chạm bottomBar → phần trống phía trên là chỗ vẽ chữ.
    // Với số hiện tại: 5*88 + 5*18 + 9 = 539 → hàng đầu bắt đầu ở y = 920 - 539 = 381.
    readonly property int rightColHeight: (filterRows + stickerRows) * circle
                                          + (filterRows + stickerRows) * rowSpacing
                                          + stickerGap

    // Kích thước giải mã thumbnail. CircleThumb đặt sourceSize = diameter * 3, nên
    // preloader phải dùng đúng con số này thì mới trúng cache.
    readonly property int thumbSourceSize: circle * 3
}
