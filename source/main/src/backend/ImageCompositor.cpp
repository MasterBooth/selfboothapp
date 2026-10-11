#include "ImageCompositor.h"
#include "AppPaths.h"
#include <QDebug>
#include <QFileInfo>
#include <QDir>
#include <QImageReader>
#include <QAtomicInt>

// ── Hình học tấm in cắt DNP ─────────────────────────────────────────────────
// Số liệu lấy nguyên văn từ Generating_OutputImage_E.pdf §3 và
// DriverPrintDirection_E.pdf §4. KHÔNG tự tính "inch × dpi" — vùng in của DNP
// lớn hơn giấy 2.0mm trái/phải và 1.5mm trên/dưới nên tỉ lệ KHÔNG phải 2:3.
//   4×6 portrait @300dpi: canvas 1240×1844, giấy 1200×1800, bleed 20 / 22
//   4×6 portrait @600dpi: canvas 2480×3688, giấy 2400×3600, bleed 40 / 44
namespace {
// strip 2×6 chuẩn cao 1800 px @300dpi, 3600 px @600dpi → ngưỡng phân loại 2400
constexpr int kDpiSwitchStripHeight = 2400;

// Chế độ bleed dùng chung. Ghi từ main thread (khi nạp/đổi setting), đọc từ
// worker thread (khi ghép ảnh) → dùng atomic.
QAtomicInt g_cutBleedMode{ static_cast<int>(CutBleedMode::FillToEdge) };

// FillToEdge: bỏ vùng an toàn — nội dung phủ kín canvas, phần nhô ra rơi ngoài giấy.
void applyBleedMode(DnpCutSheet &s)
{
    if (ImageCompositor::cutBleedMode() == CutBleedMode::FillToEdge) {
        s.contentW = s.canvasW;
        s.contentH = s.canvasH;
        s.bleedX   = 0;
        s.bleedY   = 0;
    }
}
}

void ImageCompositor::setCutBleedMode(CutBleedMode mode)
{
    g_cutBleedMode.storeRelease(static_cast<int>(mode));
    qDebug() << "[ImageCompositor] Chế độ bleed tấm in cắt:"
             << (mode == CutBleedMode::FillToEdge
                     ? "FillToEdge (tràn mép — thiết kế phủ kín, mất ~1.7mm rìa)"
                     : "SafeMargin (hiện đủ — giữ trọn thiết kế, bleed để màu nền)");
}

CutBleedMode ImageCompositor::cutBleedMode()
{
    return static_cast<CutBleedMode>(g_cutBleedMode.loadAcquire());
}

DnpCutSheet ImageCompositor::cutSheetPortrait(const QSize &stripSize)
{
    const bool hiRes = (stripSize.height() >= kDpiSwitchStripHeight);

    DnpCutSheet s;
    s.canvasW  = hiRes ? 2480 : 1240;
    s.canvasH  = hiRes ? 3688 : 1844;
    s.contentW = hiRes ? 2400 : 1200;
    s.contentH = hiRes ? 3600 : 1800;
    s.bleedX   = (s.canvasW - s.contentW) / 2;   // 40 / 20
    s.bleedY   = (s.canvasH - s.contentH) / 2;   // 44 / 22
    applyBleedMode(s);
    return s;
}

DnpCutSheet ImageCompositor::cutSheetLandscape(const QSize &stripSize)
{
    // Strip 6×2 landscape: chiều dài 6" nằm ngang → dùng width để chọn dpi
    const bool hiRes = (stripSize.width() >= kDpiSwitchStripHeight);

    DnpCutSheet s;
    s.canvasW  = hiRes ? 3688 : 1844;
    s.canvasH  = hiRes ? 2480 : 1240;
    s.contentW = hiRes ? 3600 : 1800;
    s.contentH = hiRes ? 2400 : 1200;
    s.bleedX   = (s.canvasW - s.contentW) / 2;   // 44 / 22
    s.bleedY   = (s.canvasH - s.contentH) / 2;   // 40 / 20
    applyBleedMode(s);
    return s;
}

// ── buildCutSheet: đường DUY NHẤT đặt ảnh lên tấm in cắt ────────────────────
QImage ImageCompositor::buildCutSheet(const QImage &strip, const QColor &bgColor,
                                      const DnpCutSheet &sh, bool stacked)
{
    QImage sheet(sh.canvasW, sh.canvasH, QImage::Format_ARGB32);
    sheet.fill(bgColor);
    if (strip.isNull() || strip.width() <= 0 || strip.height() <= 0)
        return sheet;

    // Ô dành cho MỘT strip. Cắt dọc → chia đôi theo chiều ngang, và ngược lại.
    const int cellW = stacked ? sh.contentW : sh.contentW / 2;
    const int cellH = stacked ? sh.contentH / 2 : sh.contentH;

    const double sx = (double)cellW / strip.width();
    const double sy = (double)cellH / strip.height();
    // FillToEdge dùng COVER (max) để phủ kín, phần thừa bị xén.
    // SafeMargin dùng CONTAIN (min) để giữ trọn thiết kế.
    const bool fill = (cutBleedMode() == CutBleedMode::FillToEdge);
    const double scaleU = fill ? qMax(sx, sy) : qMin(sx, sy);

    const int dW = qRound(strip.width()  * scaleU);
    const int dH = qRound(strip.height() * scaleU);

    const int slack = (stacked ? cellH - dH : cellW - dW);

    // slack ≥ 0 (CONTAIN/safe): còn chỗ trống → chia ĐỐI XỨNG GƯƠNG, ceil về phía
    //   mép ngoài và floor về phía đường cắt, để lề trắng hai mép ngoài bằng nhau
    //   và tâm nội dung trùng đường cắt kể cả khi slack lẻ.
    // slack < 0 (COVER/fill): ảnh tràn ra ngoài ô → dùng CÙNG một offset cho cả
    //   hai ô, nhờ vậy hai strip bị xén y hệt nhau và hai ảnh in ra giống hệt.
    //   Đối xứng của tấm in vẫn được bảo toàn vì hai ô vốn đối xứng qua đường cắt.
    const int insetNear = (slack >= 0) ? (slack + 1) / 2 : slack / 2;
    const int insetFar  = (slack >= 0) ? (slack / 2)     : slack / 2;

    QPainter p(&sheet);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::SmoothPixmapTransform);

    // Clip từng ô: ở chế độ COVER ảnh tràn ra ngoài ô của nó, nếu không clip thì
    // strip này sẽ đè sang nửa kia và phá đối xứng quanh đường cắt.
    for (int i = 0; i < 2; ++i) {
        const int nearOfs = (i == 0) ? insetNear : insetFar;
        QRect cell, dst;
        if (stacked) {
            const int cellTop = sh.bleedY + i * cellH;
            cell = QRect(sh.bleedX, cellTop, cellW, cellH);
            dst  = QRect(sh.bleedX + (cellW - dW) / 2, cellTop + nearOfs, dW, dH);
        } else {
            const int cellLeft = sh.bleedX + i * cellW;
            cell = QRect(cellLeft, sh.bleedY, cellW, cellH);
            dst  = QRect(cellLeft + nearOfs, sh.bleedY + (cellH - dH) / 2, dW, dH);
        }
        p.save();
        p.setClipRect(cell);
        p.drawImage(dst, strip);
        p.restore();
    }
    p.end();

    // Bất biến INV-2: hai ô phải đối xứng tuyệt đối quanh đường cắt.
    const int cutAxis  = stacked ? sh.canvasH / 2 : sh.canvasW / 2;
    const int cellAxis = stacked ? (sh.bleedY + cellH) : (sh.bleedX + cellW);
    if (cellAxis != cutAxis) {
        qWarning() << "[ImageCompositor] buildCutSheet: RANH GIỚI Ô KHÔNG TRÙNG ĐƯỜNG CẮT!"
                   << "cellAxis=" << cellAxis << "cutAxis=" << cutAxis;
    }

    qDebug() << "[ImageCompositor] buildCutSheet"
             << (stacked ? "(xếp chồng / cắt ngang)" : "(cạnh nhau / cắt dọc)")
             << "| strip=" << strip.width() << "x" << strip.height()
             << "→ canvas=" << sh.canvasW << "x" << sh.canvasH
             << "| ô=" << cellW << "x" << cellH
             << "| bleed=" << sh.bleedX << "/" << sh.bleedY
             << "| mode=" << (fill ? "FILL(cover)" : "SAFE(contain)")
             << "| scale=" << scaleU << "vẽ=" << dW << "x" << dH
             << "| slack=" << slack << "| đường cắt=" << cutAxis;

    return sheet;
}

// ── loadPhotoScaled ─────────────────────────────────────────────────────────
// Decode ảnh ở độ phân giải vừa đủ cho slot thay vì full 24MP.
// Ví dụ: ảnh DSLR 6000×4000 (~96MB ARGB) cho slot 1200×1800 → decode về
// ~2300×3500 (~32MB) → giảm ~65% RAM và rút ngắn thời gian decode đáng kể.
QImage ImageCompositor::loadPhotoScaled(const QString &path, const QSize &slotSize,
                                        double imgScale)
{
    QImageReader reader(path);
    QSize orig = reader.size();

    // Không đọc được kích thước (định dạng lạ) → fallback decode nguyên bản.
    if (!orig.isValid() || slotSize.isEmpty())
        return QImage(path);

    // Nhu cầu phân giải: kích thước slot × zoom × 1.3 (dự phòng cho cover-crop
    // và lấy mẫu mượt). zoom>1 khi user phóng to ảnh trong slot.
    double zoom = (imgScale > 1.0) ? imgScale : 1.0;
    int needW = qRound(slotSize.width()  * zoom * 1.3);
    int needH = qRound(slotSize.height() * zoom * 1.3);

    // Ảnh gốc đã nhỏ hơn nhu cầu → decode nguyên bản, tuyệt đối không upscale.
    if (orig.width() <= needW && orig.height() <= needH)
        return reader.read();

    // Scale khi decode, giữ tỉ lệ và phủ kín nhu cầu (ByExpanding).
    QSize scaled = orig.scaled(needW, needH, Qt::KeepAspectRatioByExpanding);
    reader.setScaledSize(scaled);
    QImage img = reader.read();

    // Một số plugin ảnh không hỗ trợ setScaledSize → fallback decode nguyên bản.
    if (img.isNull())
        return QImage(path);
    return img;
}

ImageCompositor::ImageCompositor(QObject *parent) : QObject(parent) {}

// ── sampleBgColor: lấy màu nền thực sự của overlay ──────────────────────────
// Pixel (0,0) thường trong suốt (bo tròn, shadow, frame không có nền đặc).
// Hàm này sample tại nhiều điểm: 4 góc + 4 cạnh giữa + tâm,
// trả về pixel đặc (alpha≥128) đầu tiên tìm được theo thứ tự ưu tiên.
// Nếu toàn bộ trong suốt → fallback Qt::white.
QColor ImageCompositor::sampleBgColor(const QImage &overlay)
{
    if (overlay.isNull()) return Qt::white;

    int W = overlay.width();
    int H = overlay.height();

    // Danh sách điểm sample theo thứ tự ưu tiên:
    // cạnh giữa (thường là vùng viền frame đặc màu) → góc → tâm
    QList<QPoint> candidates = {
        { W / 2, 0 },          // cạnh trên giữa
        { W / 2, H - 1 },      // cạnh dưới giữa
        { 0,     H / 2 },      // cạnh trái giữa
        { W - 1, H / 2 },      // cạnh phải giữa
        { 0,     0 },          // góc trên-trái
        { W - 1, 0 },          // góc trên-phải
        { 0,     H - 1 },      // góc dưới-trái
        { W - 1, H - 1 },      // góc dưới-phải
        { W / 2, H / 2 },      // tâm
    };

    for (const QPoint &pt : candidates) {
        QRgb px = overlay.pixel(pt.x(), pt.y());
        if (qAlpha(px) >= 128)
            return QColor(px);
    }
    return Qt::white;
}

bool ImageCompositor::compose(const QStringList &photoPaths,
                             const QString &overlayPath,
                             const QVariantList &layoutSlots,
                             const QString &outputPath,
                             const QVariantList &transforms,
                             const QString &printerHint,
                             const std::function<void(QImage&)> &slotFilter)
{
    if (overlayPath.isEmpty() || layoutSlots.isEmpty()) {
        qWarning() << "ImageCompositor: Missing overlay or slot metadata";
        return false;
    }

    // 1. Load Overlay để lấy kích thước chuẩn (Canvas size)
    QImage overlayImage(overlayPath);
    if (overlayImage.isNull()) {
        qWarning() << "ImageCompositor: Failed to load overlay" << overlayPath;
        return false;
    }
    // Convert một lần duy nhất → dùng lại cho cả lấy màu nền và vẽ (tránh convert 2 lần)
    overlayImage = overlayImage.convertToFormat(QImage::Format_ARGB32);

    int W = overlayImage.width();
    int H = overlayImage.height();

    bool isQW410 = printerHint.contains("QW410", Qt::CaseInsensitive)
               || printerHint.contains("QW-410", Qt::CaseInsensitive)
               || printerHint.contains("410", Qt::CaseInsensitive);
    bool isPortrait = (W <= H);  // portrait dọc hoặc vuông

    // QW410 portrait no-cut: safe margin nhỏ top/bottom=10, trái/phải=15
    // QW410 landscape no-cut: không margin (fill sát cạnh)
    // RX1/620S: margin chuẩn
    const int outerMarginY = isQW410 ? (isPortrait ? 10 : 0) : 50;
    const int outerMarginX = isQW410 ? (isPortrait ? 15 : 0) : 20;

    // 2. Khởi tạo Canvas cuối cùng
    // Dùng màu nền từ overlay (lấy pixel góc trên-trái); fallback sang trắng nếu trong suốt
    QColor bgColor = sampleBgColor(overlayImage);
    QImage resultImage(W, H, QImage::Format_ARGB32);
    resultImage.fill(bgColor);

    QPainter painter(&resultImage);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    // 3. Khởi tạo Canvas trung gian (Raw Content) để gom ảnh + overlay
    // Dùng Qt::white thay vì transparent: slot thiếu ảnh hiển thị trắng
    // thay vì lộ bgColor (có thể xám từ border overlay).
    QImage contentImage(W, H, QImage::Format_ARGB32);
    contentImage.fill(Qt::white);
    QPainter contentPainter(&contentImage);
    contentPainter.setRenderHint(QPainter::Antialiasing);
    contentPainter.setRenderHint(QPainter::SmoothPixmapTransform);

    // 4. Vẽ các ảnh vào Slot trên contentImage – có hỗ trợ pan/zoom transform
    for (int i = 0; i < layoutSlots.size(); ++i) {
        if (i >= photoPaths.size() || photoPaths[i].isEmpty()) continue;

        QVariantMap slotMap = layoutSlots[i].toMap();
        QRect targetRect(slotMap["x"].toInt(), slotMap["y"].toInt(),
                         slotMap["width"].toInt(), slotMap["height"].toInt());

        // Lấy transform TRƯỚC (cần imgScale để quyết định độ phân giải decode)
        double imgScale = 1.0;
        double imgTx    = 0.0;
        double imgTy    = 0.0;
        bool flipH      = false;
        if (i < transforms.size()) {
            QVariantMap t = transforms[i].toMap();
            imgScale = t.value("scale", 1.0).toDouble();
            imgTx    = t.value("tx",    0.0).toDouble();
            imgTy    = t.value("ty",    0.0).toDouble();
            flipH    = t.value("flip", false).toBool();
        }

        // Decode ảnh ở độ phân giải vừa đủ cho slot — không nạp full 24MP
        QImage photo = loadPhotoScaled(photoPaths[i], targetRect.size(), imgScale);
        if (photo.isNull()) {
            qWarning() << "ImageCompositor: Failed to load photo at" << photoPaths[i];
            continue;
        }

        if (flipH) photo = photo.mirrored(true, false);

        QImage croppedPhoto;
        bool hasTransform = (imgScale > 1.001 || qAbs(imgTx) > 0.001 || qAbs(imgTy) > 0.001);
        if (hasTransform) {
            croppedPhoto = transformedCrop(photo, targetRect.size(), imgScale, imgTx, imgTy);
        } else {
            croppedPhoto = centerCrop(photo, targetRect.size());
        }

        // Áp filter (LUT) lên ảnh slot TRƯỚC khi vẽ → frame vẽ sau không bị filter
        if (slotFilter)
            slotFilter(croppedPhoto);

        contentPainter.drawImage(targetRect, croppedPhoto);
    }

    // 5. Vẽ Overlay lên trên cùng (Z-index Max) của contentImage
    contentPainter.drawImage(0, 0, overlayImage);
    contentPainter.end();

    // 6. Copy contentImage vào ResultImage: thu lại cả 4 cạnh theo margin
    // BUG FIX: KHÔNG được scale contentImage (W×H) vào rect (W-2*mX)×(H-2*mY) trực tiếp,
    // vì nếu marginX ≠ marginY thì scale X ≠ scale Y → toàn bộ ảnh bị méo (non-uniform stretch).
    //
    // Ví dụ: W=1800, H=1200, marginX=20, marginY=50
    //   scaleX = 1760/1800 = 0.9778,  scaleY = 1100/1200 = 0.9167  → lệch 6.7%!
    //
    // Fix: dùng uniformScale = min(scaleX, scaleY) để giữ tỉ lệ, rồi căn giữa trong safe area.
    {
        double scaleX = (double)(W - 2 * outerMarginX) / W;
        double scaleY = (double)(H - 2 * outerMarginY) / H;
        double uniformScale = qMin(scaleX, scaleY);

        int drawW = qRound(W * uniformScale);
        int drawH = qRound(H * uniformScale);

        // Căn giữa trong toàn bộ canvas (không chỉ trong safe area)
        int drawX = (W - drawW) / 2;
        int drawY = (H - drawH) / 2;

        painter.drawImage(QRect(drawX, drawY, drawW, drawH), contentImage);
    }
    painter.end();

    // 5. Lưu kết quả
    QFileInfo fileInfo(outputPath);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(fileInfo.absolutePath(), &errorMsg)) {
        qCritical() << "Failed to create compositor output directory:" << errorMsg;
        return false;
    }

    if (resultImage.save(outputPath, "JPG", 95)) {
        qDebug() << "ImageCompositor: Successfully saved composition to" << outputPath;
        return true;
    }

    qWarning() << "ImageCompositor: Failed to save result to" << outputPath;
    return false;
}

// ── renderStrip: render photos + overlay thành QImage (full overlay size, no margin) ──
QImage ImageCompositor::renderStrip(const QStringList &photoPaths,
                                     const QImage &overlayImage,
                                     const QVariantList &layoutSlots,
                                     const QVariantList &transforms)
{
    int W = overlayImage.width();
    int H = overlayImage.height();

    QImage strip(W, H, QImage::Format_ARGB32);
    strip.fill(Qt::white);
    QPainter p(&strip);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::SmoothPixmapTransform);

    for (int i = 0; i < layoutSlots.size(); ++i) {
        if (i >= photoPaths.size() || photoPaths[i].isEmpty()) continue;

        QVariantMap slotMap = layoutSlots[i].toMap();
        QRect targetRect(slotMap["x"].toInt(), slotMap["y"].toInt(),
                         slotMap["width"].toInt(), slotMap["height"].toInt());

        double imgScale = 1.0, imgTx = 0.0, imgTy = 0.0;
        bool flipH = false;
        if (i < transforms.size()) {
            QVariantMap t = transforms[i].toMap();
            imgScale = t.value("scale", 1.0).toDouble();
            imgTx    = t.value("tx",    0.0).toDouble();
            imgTy    = t.value("ty",    0.0).toDouble();
            flipH    = t.value("flip", false).toBool();
        }

        // Decode ảnh ở độ phân giải vừa đủ cho slot — không nạp full 24MP
        QImage photo = loadPhotoScaled(photoPaths[i], targetRect.size(), imgScale);
        if (photo.isNull()) {
            qWarning() << "[ImageCompositor] renderStrip: Failed to load photo:" << photoPaths[i];
            continue;
        }

        if (flipH) photo = photo.mirrored(true, false);

        bool hasTransform = (imgScale > 1.001 || qAbs(imgTx) > 0.001 || qAbs(imgTy) > 0.001);
        QImage cropped = hasTransform
            ? transformedCrop(photo, targetRect.size(), imgScale, imgTx, imgTy)
            : centerCrop(photo, targetRect.size());

        p.drawImage(targetRect, cropped);
    }

    p.drawImage(0, 0, overlayImage);
    p.end();
    return strip;
}

// ── composePrintSheetH: 2 strips nằm ngang trong canvas stripW*2 × stripH ──
// Margin áp đều 4 cạnh: outerMarginX (ngoài), innerMarginX (giữa/cut line), outerMarginY (trên/dưới).
QImage ImageCompositor::composePrintSheetH(const QImage &strip, const QColor &bgColor,
                                            int outerMarginX, int innerMarginX, int outerMarginY)
{
    int stripW = strip.width();
    int stripH = strip.height();
    int canvasW = stripW * 2;
    int canvasH = stripH;

    int safeW = stripW - outerMarginX - innerMarginX;
    int safeH = stripH - 2 * outerMarginY;
    double scaleU = qMin((double)safeW / stripW, (double)safeH / stripH);
    int dW = qRound(stripW * scaleU);
    int dH = qRound(stripH * scaleU);
    int ox = (safeW - dW) / 2;
    int oy = (safeH - dH) / 2;

    QImage sheet(canvasW, canvasH, QImage::Format_ARGB32);
    sheet.fill(bgColor);
    QPainter p(&sheet);
    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::SmoothPixmapTransform);
    p.drawImage(QRect(outerMarginX + ox,          outerMarginY + oy, dW, dH), strip);
    p.drawImage(QRect(stripW + innerMarginX + ox,  outerMarginY + oy, dW, dH), strip);
    p.end();
    return sheet;
}

// ── Cut mode: tạo canvas 4×6 portrait chuẩn DNP với cả hai nửa giống hệt ────
// RX1/DS620 (xem docs/DNP_RX1_CUT_PRINT_SPEC.md §2):
//   canvas  = 1240×1844 (@300dpi) hoặc 2480×3688 (@600dpi)
//   content = 1200×1800            hoặc 2400×3600      (= vùng giấy thật)
//   Strip 1: [bleedX .. bleedX+halfW],  Strip 2: [bleedX+halfW .. bleedX+contentW]
//   Đường cắt = canvasW/2 = bleedX + halfW  → nội dung đối xứng tuyệt đối (INV-2).
// QW410: giữ nguyên logic composePrintSheetH (canvas = stripW*2 × stripH)
bool ImageCompositor::composeWithCut(const QStringList &photoPaths,
                                     const QString &overlayPath,
                                     const QVariantList &layoutSlots,
                                     const QString &outputPath,
                                     const QVariantList &transforms,
                                     const QString &printerHint)
{
    if (overlayPath.isEmpty() || layoutSlots.isEmpty()) {
        qWarning() << "[ImageCompositor] composeWithCut: Missing overlay or slot metadata";
        return false;
    }

    QImage overlayImage(overlayPath);
    if (overlayImage.isNull()) {
        qWarning() << "[ImageCompositor] composeWithCut: Failed to load overlay:" << overlayPath;
        return false;
    }
    overlayImage = overlayImage.convertToFormat(QImage::Format_ARGB32);

    bool isQW410 = printerHint.contains("QW410", Qt::CaseInsensitive)
               || printerHint.contains("QW-410", Qt::CaseInsensitive)
               || printerHint.contains("410", Qt::CaseInsensitive);

    QImage strip = renderStrip(photoPaths, overlayImage, layoutSlots, transforms);
    QColor bgColor = sampleBgColor(overlayImage);
    QImage sheet;

    if (isQW410) {
        // QW410: canvas = stripW*2 × stripH, margin-based positioning
        sheet = composePrintSheetH(strip, bgColor, /*outerMarginX=*/30, /*innerMarginX=*/0, /*outerMarginY=*/0);
        qDebug() << "[ImageCompositor] composeWithCut QW410: strip=" << strip.width() << "x" << strip.height()
                 << "→ sheet=" << sheet.width() << "x" << sheet.height();
    } else {
        // RX1/DS620 — hình học chuẩn DNP (SPEC §2), đặt ảnh qua buildCutSheet()
        // để mọi đường ghép dùng chung một cài đặt duy nhất.
        sheet = buildCutSheet(strip, bgColor, cutSheetPortrait(strip.size()),
                              /*stacked=*/false);
    }

    QFileInfo fileInfo(outputPath);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(fileInfo.absolutePath(), &errorMsg)) {
        qCritical() << "[ImageCompositor] composeWithCut: Failed to create output dir:" << errorMsg;
        return false;
    }
    if (sheet.save(outputPath, "JPG", 95)) {
        qDebug() << "[ImageCompositor] composeWithCut: Saved 4x6 composite:" << outputPath;
        return true;
    }
    qWarning() << "[ImageCompositor] composeWithCut: Failed to save:" << outputPath;
    return false;
}

// ── QW410 Cut mode: tạo canvas 15x10 với 3 strip ngang ──────────────────────
// Strip 5×10 (portrait) được nhân 3 lần nằm ngang với khoảng cách 3mm giữa các strip.
// Kết quả là canvas landscape 15×10 gửi đến QW410, người dùng tự cắt thành 3 ảnh.
bool ImageCompositor::composeWithCutQW410(const QStringList &photoPaths,
                                           const QString &overlayPath,
                                           const QVariantList &layoutSlots,
                                           const QString &outputPath,
                                           const QVariantList &transforms)
{
    if (overlayPath.isEmpty() || layoutSlots.isEmpty()) {
        qWarning() << "[ImageCompositor] composeWithCutQW410: Missing overlay or slot metadata";
        return false;
    }

    QImage overlayImage(overlayPath);
    if (overlayImage.isNull()) {
        qWarning() << "[ImageCompositor] composeWithCutQW410: Failed to load overlay:" << overlayPath;
        return false;
    }
    // Convert một lần duy nhất → dùng lại cho cả lấy màu nền và vẽ (tránh convert 2 lần)
    overlayImage = overlayImage.convertToFormat(QImage::Format_ARGB32);

    int stripW = overlayImage.width();   // e.g. 600 @300dpi
    int stripH = overlayImage.height();  // e.g. 1200 @300dpi

    // Canvas cố định = stripW*3 × stripH để sau xoay 90°CW đúng khổ giấy QW410
    // - safeMarginY = 20px: trên/dưới
    // - innerGap    = 30px: tổng khoảng trắng giữa 2 ảnh (bao gồm vùng cắt)
    // - safeEdge    = 35px: rìa ngoài ảnh 1 (trái) và ảnh 3 (phải)
    // imgW = (canvasW - 2*safeEdge - 2*innerGap) / 3

    const int safeMarginY = 20;
    const int innerGap    = 5;    // tổng khoảng giữa 2 ảnh kề nhau
    const int safeEdge    = 20;   // rìa ngoài trái/phải

    int canvasW = stripW * 3;   // 1800px
    int canvasH = stripH;       // 1200px

    int imgW = (canvasW - 2 * safeEdge - 2 * innerGap) / 3;  // (1800-70-60)/3 = 556px
    int imgH = stripH - 2 * safeMarginY;                       // 1160px

    int x1   = safeEdge;                        // 35
    int x2   = safeEdge + imgW + innerGap;      // 35+556+30 = 621
    int x3   = canvasW - safeEdge - imgW;       // 1800-35-556 = 1209
    int yTop = safeMarginY;                     // 20

    qDebug() << "[ImageCompositor] composeWithCutQW410: strip=" << stripW << "x" << stripH
             << "innerGap=" << innerGap << "safeEdge=" << safeEdge << "safeMarginY=" << safeMarginY
             << "→ canvas=" << canvasW << "x" << canvasH << "imgW=" << imgW;

    QColor bgColor = sampleBgColor(overlayImage);

    QImage resultImage(canvasW, canvasH, QImage::Format_ARGB32);
    resultImage.fill(bgColor);

    QPainter painter(&resultImage);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    QImage fullStrip = renderStrip(photoPaths, overlayImage, layoutSlots, transforms);

    // Đặt 3 bản sao vào canvas — dùng uniformScale giữ tỉ lệ, tránh méo
    {
        double scaleU = qMin((double)imgW / stripW, (double)imgH / stripH);
        int dW = qRound(stripW * scaleU);
        int dH = qRound(stripH * scaleU);
        int ox = (imgW - dW) / 2;
        int oy = (imgH - dH) / 2;

        painter.drawImage(QRect(x1 + ox, yTop + oy, dW, dH), fullStrip);
        painter.drawImage(QRect(x2 + ox, yTop + oy, dW, dH), fullStrip);
        painter.drawImage(QRect(x3 + ox, yTop + oy, dW, dH), fullStrip);
    }
    painter.end();

    // Xoay 90° CW: canvas landscape → portrait
    // e.g. 1830×1200 → 1200×1830
    {
        QTransform rot;
        rot.rotate(90);
        resultImage = resultImage.transformed(rot, Qt::SmoothTransformation);
        qDebug() << "[ImageCompositor] composeWithCutQW410: rotated 90° →" << resultImage.width() << "x" << resultImage.height();
    }

    QFileInfo fileInfo(outputPath);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(fileInfo.absolutePath(), &errorMsg)) {
        qCritical() << "[ImageCompositor] composeWithCutQW410: Failed to create output dir:" << errorMsg;
        return false;
    }

    if (resultImage.save(outputPath, "JPG", 95)) {
        qDebug() << "[ImageCompositor] composeWithCutQW410: Saved 15x10 composite:" << outputPath;
        return true;
    }

    qWarning() << "[ImageCompositor] composeWithCutQW410: Failed to save:" << outputPath;
    return false;
}

// ── 15x5 cut (RX1/620S): tạo canvas 15x10 nhân đôi strip ngang theo chiều dọc ──
// Layout 15×5 (landscape) được nhân 2 lần xếp chồng dọc.
// Canvas kết quả 15×10 gửi RX1/620S (landscape), máy cắt ngang giữa → 2 strip 15×5.
bool ImageCompositor::composeWithCutHorizontal(const QStringList &photoPaths,
                                                const QString &overlayPath,
                                                const QVariantList &layoutSlots,
                                                const QString &outputPath,
                                                const QVariantList &transforms)
{
    if (overlayPath.isEmpty() || layoutSlots.isEmpty()) {
        qWarning() << "[ImageCompositor] composeWithCutHorizontal: Missing overlay or slot metadata";
        return false;
    }

    QImage overlayImage(overlayPath);
    if (overlayImage.isNull()) {
        qWarning() << "[ImageCompositor] composeWithCutHorizontal: Failed to load overlay:" << overlayPath;
        return false;
    }
    // Convert một lần duy nhất → dùng lại cho cả lấy màu nền và vẽ (tránh convert 2 lần)
    overlayImage = overlayImage.convertToFormat(QImage::Format_ARGB32);

    // Step 1: render strip independently
    QImage strip = renderStrip(photoPaths, overlayImage, layoutSlots, transforms);
    QColor bgColor = sampleBgColor(overlayImage);

    // Step 2: canvas 6×4 landscape chuẩn DNP (SPEC §2), 2 strip 6×2 xếp chồng dọc.
    //   canvas 1844×1240 (@300dpi) / 3688×2480 (@600dpi)
    //   Đường cắt ngang = canvasH/2
    QImage sheet = buildCutSheet(strip, bgColor, cutSheetLandscape(strip.size()),
                                 /*stacked=*/true);

    qDebug() << "[ImageCompositor] composeWithCutHorizontal: strip=" << strip.width() << "x" << strip.height()
             << "→ sheet=" << sheet.width() << "x" << sheet.height();

    // Step 3: save
    QFileInfo fileInfo(outputPath);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(fileInfo.absolutePath(), &errorMsg)) {
        qCritical() << "[ImageCompositor] composeWithCutHorizontal: Failed to create output dir:" << errorMsg;
        return false;
    }
    if (sheet.save(outputPath, "JPG", 95)) {
        qDebug() << "[ImageCompositor] composeWithCutHorizontal: Saved 15x10 landscape composite:" << outputPath;
        return true;
    }
    qWarning() << "[ImageCompositor] composeWithCutHorizontal: Failed to save:" << outputPath;
    return false;
}

// ── composeRaw: render ảnh vào slot KHÔNG áp safe-margin ────────────────────
// Output kích thước = overlay (W×H), ảnh đặt chính xác vào từng slot.
// Dùng để tạo strip cho filter: strip "sạch" rồi composeCutFromStrip() mới
// đặt nó vào 4x6 canvas với margin đúng – tránh double-margin/scaling.
bool ImageCompositor::composeRaw(const QStringList &photoPaths,
                                  const QString &overlayPath,
                                  const QVariantList &layoutSlots,
                                  const QString &outputPath,
                                  const QVariantList &transforms)
{
    return composeRawFiltered(photoPaths, overlayPath, layoutSlots, outputPath,
                              transforms, nullptr);
}

bool ImageCompositor::composeRawFiltered(const QStringList &photoPaths,
                                         const QString &overlayPath,
                                         const QVariantList &layoutSlots,
                                         const QString &outputPath,
                                         const QVariantList &transforms,
                                         const std::function<void(QImage&)> &slotFilter)
{
    if (overlayPath.isEmpty() || layoutSlots.isEmpty()) {
        qWarning() << "[ImageCompositor] composeRawFiltered: Missing overlay or slot metadata";
        return false;
    }

    QImage overlayImage(overlayPath);
    if (overlayImage.isNull()) {
        qWarning() << "[ImageCompositor] composeRawFiltered: Failed to load overlay:" << overlayPath;
        return false;
    }
    // Convert một lần duy nhất → dùng lại cho cả lấy màu nền và vẽ (tránh convert 2 lần)
    overlayImage = overlayImage.convertToFormat(QImage::Format_ARGB32);

    int W = overlayImage.width();
    int H = overlayImage.height();

    // Canvas = kích thước overlay, fill bằng màu nền của overlay
    QColor bgColor = sampleBgColor(overlayImage);
    QImage result(W, H, QImage::Format_ARGB32);
    result.fill(bgColor);

    QPainter painter(&result);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    // Vẽ ảnh trực tiếp vào slot (KHÔNG thu nhỏ theo margin)
    for (int i = 0; i < layoutSlots.size(); ++i) {
        if (i >= photoPaths.size() || photoPaths[i].isEmpty()) continue;

        QVariantMap slotMap = layoutSlots[i].toMap();
        QRect targetRect(slotMap["x"].toInt(), slotMap["y"].toInt(),
                         slotMap["width"].toInt(), slotMap["height"].toInt());

        double imgScale = 1.0, imgTx = 0.0, imgTy = 0.0;
        bool flipH = false;
        if (i < transforms.size()) {
            QVariantMap t = transforms[i].toMap();
            imgScale = t.value("scale", 1.0).toDouble();
            imgTx    = t.value("tx",    0.0).toDouble();
            imgTy    = t.value("ty",    0.0).toDouble();
            flipH    = t.value("flip", false).toBool();
        }

        // Decode ảnh ở độ phân giải vừa đủ cho slot — không nạp full 24MP
        QImage photo = loadPhotoScaled(photoPaths[i], targetRect.size(), imgScale);
        if (photo.isNull()) {
            qWarning() << "[ImageCompositor] composeRawFiltered: Failed to load photo:" << photoPaths[i];
            continue;
        }
        if (flipH) photo = photo.mirrored(true, false);
        bool hasTransform = (imgScale > 1.001 || qAbs(imgTx) > 0.001 || qAbs(imgTy) > 0.001);
        QImage croppedPhoto = hasTransform
            ? transformedCrop(photo, targetRect.size(), imgScale, imgTx, imgTy)
            : centerCrop(photo, targetRect.size());

        // Áp filter (LUT) lên ảnh slot TRƯỚC khi vẽ → frame vẽ sau không bị filter
        if (slotFilter)
            slotFilter(croppedPhoto);

        painter.drawImage(targetRect, croppedPhoto);
    }

    // Vẽ overlay frame lên trên cùng (đã ở Format_ARGB32 từ đầu hàm)
    painter.drawImage(0, 0, overlayImage);
    painter.end();

    QFileInfo fileInfo(outputPath);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(fileInfo.absolutePath(), &errorMsg)) {
        qCritical() << "[ImageCompositor] composeRawFiltered: Cannot create dir:" << errorMsg;
        return false;
    }

    if (result.save(outputPath, "JPG", 95)) {
        qDebug() << "[ImageCompositor] composeRawFiltered: Saved raw strip:" << outputPath;
        return true;
    }
    qWarning() << "[ImageCompositor] composeRawFiltered: Failed to save:" << outputPath;
    return false;
}


QImage ImageCompositor::centerCrop(const QImage &source, const QSize &targetSize) {
    if (source.isNull() || targetSize.isEmpty()) return source;

    double sourceAspect = (double)source.width() / source.height();
    double targetAspect = (double)targetSize.width() / targetSize.height();

    // Crop vùng có tỉ lệ khớp targetAspect từ ảnh gốc → scale lên targetSize
    // (không scale toàn bộ ảnh gốc lên kích thước trung gian lớn)
    QRect cropRect;
    if (sourceAspect > targetAspect) {
        // Ảnh rộng hơn slot: crop bớt hai bên trái/phải
        int newWidth = qRound((double)source.height() * targetAspect);
        newWidth = qMin(newWidth, source.width());
        cropRect = QRect((source.width() - newWidth) / 2, 0, newWidth, source.height());
    } else {
        // Ảnh cao hơn slot: crop bớt trên/dưới
        int newHeight = qRound((double)source.width() / targetAspect);
        newHeight = qMin(newHeight, source.height());
        cropRect = QRect(0, (source.height() - newHeight) / 2, source.width(), newHeight);
    }

    // cropRect đã có cùng aspect ratio với targetSize → IgnoreAspectRatio an toàn
    return source.copy(cropRect).scaled(targetSize, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
}

// ── Crop với transform pan/zoom (mirror logic từ QML photoWrapper) ────────────
// imgScale: zoom multiplier (1.0 = không zoom, 2.0 = zoom 2x)
// imgTx/imgTy: pan offset dưới dạng fraction so với kích thước slot
//
// PERF: Thay vì scale toàn bộ ảnh gốc (18-24MP) lên kích thước trung gian rồi mới crop,
//       ta làm ngược lại: tính vùng crop trên ảnh gốc theo tỉ lệ, copy vùng nhỏ đó,
//       rồi chỉ scale vùng crop nhỏ lên targetSize.
//       Ví dụ: ảnh 5184×3456, slot 600×800 → vùng crop gốc ~800×600px thay vì scale
//       toàn bộ 5184px lên → tiết kiệm ~85% bộ nhớ và thời gian scale.
QImage ImageCompositor::transformedCrop(const QImage &source, const QSize &targetSize,
                                         double imgScale, double imgTx, double imgTy)
{
    if (source.isNull() || targetSize.isEmpty()) return source;

    int srcW = source.width();
    int srcH = source.height();

    // Tính tỉ lệ cover: phần src tương ứng để phủ kín targetSize ở zoom=1
    double baseScaleX = (double)targetSize.width()  / srcW;
    double baseScaleY = (double)targetSize.height() / srcH;
    double coverScale = qMax(baseScaleX, baseScaleY);

    // totalScale = tổng scale từ src → scaled image (bao gồm zoom user)
    double totalScale = coverScale * imgScale;

    // Kích thước vùng src tương ứng với targetSize sau khi áp totalScale
    // (ngược chiều: targetSize / totalScale = kích thước cần lấy từ src)
    double srcCropW = targetSize.width()  / totalScale;
    double srcCropH = targetSize.height() / totalScale;

    // Tâm crop trong ảnh gốc, sau đó dịch theo pan (imgTx/imgTy là fraction của targetSize)
    // Pan pixel trên src = imgTx * targetSize / totalScale = imgTx * srcCropW
    double centerX = srcW / 2.0 - imgTx * srcCropW;
    double centerY = srcH / 2.0 - imgTy * srcCropH;

    // Tính crop rect trên ảnh gốc
    int cropX = qRound(centerX - srcCropW / 2.0);
    int cropY = qRound(centerY - srcCropH / 2.0);
    int cropW = qRound(srcCropW);
    int cropH = qRound(srcCropH);

    // Clamp để không ra ngoài biên ảnh gốc
    cropX = qBound(0, cropX, qMax(0, srcW - 1));
    cropY = qBound(0, cropY, qMax(0, srcH - 1));
    cropW = qMin(cropW, srcW - cropX);
    cropH = qMin(cropH, srcH - cropY);

    if (cropW <= 0 || cropH <= 0) return source;

    // Sau khi clamp, cropW/cropH có thể bị cắt ngắn và không còn khớp
    // aspect ratio của targetSize nữa → nếu dùng IgnoreAspectRatio sẽ gây méo.
    // Giải pháp: điều chỉnh lại cropW hoặc cropH để giữ đúng tỉ lệ targetSize,
    // luôn lấy chiều nhỏ hơn để không vượt biên ảnh.
    double targetAspect = (double)targetSize.width() / targetSize.height();
    double cropAspect   = (double)cropW / cropH;
    if (qAbs(cropAspect - targetAspect) > 0.001) {
        if (cropAspect > targetAspect) {
            // cropW quá rộng → thu lại
            cropW = qRound(cropH * targetAspect);
            cropW = qMin(cropW, srcW - cropX);
        } else {
            // cropH quá cao → thu lại
            cropH = qRound(cropW / targetAspect);
            cropH = qMin(cropH, srcH - cropY);
        }
    }

    if (cropW <= 0 || cropH <= 0) return source;

    // Crop vùng từ ảnh gốc → scale lên targetSize (aspect ratio đã khớp → không méo)
    QImage cropped = source.copy(cropX, cropY, cropW, cropH);
    return cropped.scaled(targetSize, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
}
