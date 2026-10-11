#ifndef IMAGECOMPOSITOR_H
#define IMAGECOMPOSITOR_H

#include <QObject>
#include <QImage>
#include <QPainter>
#include <QStringList>
#include <QVariantMap>
#include <functional>

/**
 * @struct DnpCutSheet
 * @brief Hình học tấm in cắt của DS-RX1/DS620, lấy TRỰC TIẾP từ tài liệu hãng.
 *
 * Nguồn: Status API/Window SDK/.../ReferenceMaterial/Generating_OutputImage_E.pdf §3
 *        (bảng "Reference image size") và DriverPrintDirection_E.pdf §4.
 *        Xem docs/DNP_RX1_CUT_PRINT_SPEC.md.
 *
 * Khổ 4×6 portrait:            300dpi = 1240×1844   |  600dpi = 2480×3688
 * Vùng giấy thật bên trong:    300dpi = 1200×1800   |  600dpi = 2400×3600
 * Bleed (vùng in > giấy):      trục 4" = 20/40 px, trục 6" = 22/44 px
 *
 * Dao 2inch-cut đi qua TÂM VẬT LÝ của cạnh 4" ⇒ đường cắt = canvasW/2.
 * Nội dung phải đối xứng tuyệt đối qua tâm đó (INV-2 trong SPEC).
 */
struct DnpCutSheet {
    int canvasW  = 0;   // toàn bộ vùng in (đã gồm bleed) — kích thước file gửi driver
    int canvasH  = 0;
    int contentW = 0;   // vùng ảnh được vẽ (xem CutBleedMode)
    int contentH = 0;
    int bleedX   = 0;
    int bleedY   = 0;

    int cutLine() const { return canvasW / 2; }          // trục dao cắt
    int halfW()   const { return contentW / 2; }         // bề rộng 1 strip 2×6
};

/**
 * @enum CutBleedMode
 * @brief Xử lý vùng bleed (phần vùng in nhô ra ngoài giấy) khi ghép tấm in cắt.
 *
 * Vùng in của DNP lớn hơn giấy 2.0mm ngang / 1.5mm dọc. Có hai cách dùng:
 *
 *  FillToEdge (TRÀN MÉP) — thiết kế phủ kín canvas, phần nhô ra rơi ngoài giấy.
 *      → in borderless thật, không bao giờ lộ sọc trắng ở mép.
 *      → đổi lại mất ~1.7mm rìa ngoài cùng của thiết kế.
 *      → đây là cách các phần mềm photobooth khác vẫn làm (gửi thẳng 1200×1800).
 *
 *  SafeMargin (HIỆN ĐỦ) — thiết kế co vừa đúng vùng giấy thật, bleed để màu nền.
 *      → giữ trọn vẹn thiết kế, không mất hoạ tiết sát mép.
 *      → đổi lại nếu giấy lệch cơ khí vài phần mười mm sẽ lộ sọc nền ở mép.
 *
 * CẢ HAI đều cho đường cắt chính giữa như nhau — chỉ khác phần rìa.
 * Chọn bằng app setting "cut_bleed_mode" (xem EventManager::setCutBleedMode).
 */
enum class CutBleedMode {
    FillToEdge = 0,
    SafeMargin = 1
};

class ImageCompositor : public QObject
{
    Q_OBJECT
public:
    explicit ImageCompositor(QObject *parent = nullptr);

    // Chế độ bleed — đọc/ghi được từ nhiều thread (ghép ảnh chạy trên worker).
    // Mặc định FillToEdge: khớp cách làm phổ biến ngoài thực tế.
    static void         setCutBleedMode(CutBleedMode mode);
    static CutBleedMode cutBleedMode();

    /**
     * @brief Chọn hình học tấm in cắt 4×6 PORTRAIT (2 strip 2×6 nằm cạnh nhau).
     * @param stripSize kích thước strip 2×6 nguồn — chỉ dùng để chọn 300 hay 600 dpi.
     *
     * Ngưỡng: strip cao ≥ 2400 px ⇒ dùng bộ 600dpi, ngược lại 300dpi.
     * (strip 2×6 chuẩn: 1800 px @300dpi, 3600 px @600dpi)
     *
     * canvasW/H LUÔN là kích thước vùng in chuẩn DNP. contentW/H và bleed phụ
     * thuộc cutBleedMode(): FillToEdge ⇒ content = canvas, bleed = 0.
     */
    static DnpCutSheet cutSheetPortrait(const QSize &stripSize);

    /**
     * @brief Như trên nhưng cho tấm 6×4 LANDSCAPE (2 strip 6×2 xếp chồng dọc).
     * Hoán vị W↔H và bleedX↔bleedY so với bản portrait.
     */
    static DnpCutSheet cutSheetLandscape(const QSize &stripSize);

    /**
     * @brief Dựng tấm in cắt: vẽ HAI bản của `strip` đối xứng qua đường cắt.
     *
     * ĐÂY LÀ ĐƯỜNG DUY NHẤT được phép đặt ảnh lên tấm in cắt. Mọi nơi cần tấm
     * cắt (có filter / không filter / có sticker) đều phải gọi hàm này — trước
     * đây hai đường ghép tự cài đặt riêng nên cho ra hai bố cục khác nhau.
     *
     * @param stacked  false = 2 strip nằm cạnh nhau (cắt dọc, tấm portrait)
     *                 true  = 2 strip xếp chồng   (cắt ngang, tấm landscape)
     *
     * Tỉ lệ ảnh luôn được giữ nguyên (không ép méo):
     *   FillToEdge  → scale COVER, phần thừa bị xén đối xứng, phủ kín tuyệt đối
     *   SafeMargin  → scale CONTAIN, phần thiếu để màu nền, thiết kế còn nguyên
     */
    static QImage buildCutSheet(const QImage &strip, const QColor &bgColor,
                                const DnpCutSheet &sheet, bool stacked);

    /**
     * @brief Ghép ảnh theo layout
     * @param photoPaths Danh sách đường dẫn ảnh đã chụp
     * @param overlayPath Đường dẫn file PNG trang trí (có độ trong suốt)
     * @param metadata Dữ liệu tọa độ các slot lấy từ file JSON
     * @param outputPath Nơi lưu kết quả
     * @return true nếu thành công
     */
    static bool compose(const QStringList &photoPaths,
                        const QString &overlayPath,
                        const QVariantList &layoutSlots,
                        const QString &outputPath,
                        const QVariantList &transforms = QVariantList(),
                        const QString &printerHint = QString(),
                        const std::function<void(QImage&)> &slotFilter = nullptr);

    /**
     * @brief Ghép ảnh cho chế độ cut RX1/DS620: tạo canvas 4×6 portrait chuẩn DNP.
     *
     * Canvas = DnpCutSheet::canvasW × canvasH (1240×1844 @300dpi, 2480×3688 @600dpi).
     * Hai strip 2×6 giống hệt nhau, mỗi strip rộng contentW/2, đặt sát nhau và
     * căn giữa tuyệt đối quanh đường cắt canvasW/2:
     *   Strip 1: [bleedX               .. bleedX + contentW/2]
     *   Strip 2: [bleedX + contentW/2  .. bleedX + contentW  ]
     * Phần bleed 2 cạnh ngoài + trên/dưới là vùng máy in xén bỏ khi ra giấy.
     *
     * QW410 giữ nguyên logic cũ (composePrintSheetH).
     */
    static bool composeWithCut(const QStringList &photoPaths,
                                const QString &overlayPath,
                                const QVariantList &layoutSlots,
                                const QString &outputPath,
                                const QVariantList &transforms = QVariantList(),
                                const QString &printerHint = QString());

    /**
     * @brief Ghép ảnh cho chế độ cut của QW410: tạo canvas 15x10 với 3 strip ngang
     *
     * QW410 in ảnh theo chiều dọc (portrait), strip 5×10 được nhân 3 lần theo chiều ngang.
     * Canvas kết quả là 15×10 tại 300dpi với khoảng cách 3mm giữa các strip.
     * Máy in sẽ cắt thành 3 ảnh 5×10 giống nhau.
     *
     * @param overlayPath  Đường dẫn layout PNG 5x10 (kích thước xác định từng strip)
     */
    static bool composeWithCutQW410(const QStringList &photoPaths,
                                     const QString &overlayPath,
                                     const QVariantList &layoutSlots,
                                     const QString &outputPath,
                                     const QVariantList &transforms = QVariantList());

    /**
     * @brief Ghép ảnh cho layout 15×5 (RX1/620S cắt ngang): tạo canvas 15×10 bằng cách
     * nhân đôi strip 15×5 theo chiều dọc (stack trên/dưới).
     * Kết quả in 15×10 → máy in cắt ngang giữa → 2 strip 15×5 giống nhau.
     *
     * @param overlayPath  Đường dẫn layout PNG 15×5 (kích thước xác định từng strip)
     */
    static bool composeWithCutHorizontal(const QStringList &photoPaths,
                                          const QString &overlayPath,
                                          const QVariantList &layoutSlots,
                                          const QString &outputPath,
                                          const QVariantList &transforms = QVariantList());

    /**
     * @brief Render ảnh vào slot KHÔNG áp safe-margin (output = kích thước overlay).
     * Dùng khi cần strip sạch để truyền qua filter rồi đặt vào composeWithCut layout.
     * Layout overlay vẫn được vẽ lên trên cùng để giữ frame.
     */
    static bool composeRaw(const QStringList &photoPaths,
                           const QString &overlayPath,
                           const QVariantList &layoutSlots,
                           const QString &outputPath,
                           const QVariantList &transforms = QVariantList());

    /**
     * @brief Như composeRaw nhưng áp filter (LUT) lên TỪNG ảnh slot trước khi vẽ,
     * rồi mới overlay frame lên trên. Frame KHÔNG đi qua filter → hoạ tiết frame
     * (kể cả phần đè lên slot) giữ nguyên màu gốc với anti-alias chuẩn.
     *
     * @param slotFilter Hàm biến đổi màu áp lên ảnh slot đã crop (in-place trên QImage).
     *                   Nếu null → tương đương composeRaw.
     */
    static bool composeRawFiltered(const QStringList &photoPaths,
                                   const QString &overlayPath,
                                   const QVariantList &layoutSlots,
                                   const QString &outputPath,
                                   const QVariantList &transforms,
                                   const std::function<void(QImage&)> &slotFilter);

    // Lấy màu nền đúng từ overlay: sample nhiều điểm ở 4 góc và cạnh giữa,
    // trả về pixel đặc (alpha≥128) đầu tiên tìm được. Fallback: Qt::white.
    static QColor sampleBgColor(const QImage &overlay);

private:
    // Render photos + overlay into a strip image (overlay size, no margin)
    static QImage renderStrip(const QStringList &photoPaths,
                               const QImage &overlayImage,
                               const QVariantList &layoutSlots,
                               const QVariantList &transforms);

    // Place 2 copies of strip side-by-side into a canvas (stripW*2 × stripH)
    static QImage composePrintSheetH(const QImage &strip, const QColor &bgColor,
                                      int outerMarginX, int innerMarginX, int outerMarginY);

    static QImage centerCrop(const QImage &source, const QSize &targetSize);
    static QImage transformedCrop(const QImage &source, const QSize &targetSize,
                                  double imgScale, double imgTx, double imgTy);

    // Decode ảnh ở độ phân giải vừa đủ cho slot (cover × zoom × dự phòng) thay vì
    // full 24MP. JPEG decoder scale ngay khi giải mã → nhanh hơn và tốn ít RAM hơn
    // nhiều so với QImage(path) rồi mới crop. Không áp EXIF auto-transform để giữ
    // hành vi giống QImage(path) cũ.
    static QImage loadPhotoScaled(const QString &path, const QSize &slotSize,
                                  double imgScale = 1.0);
};

#endif // IMAGECOMPOSITOR_H
