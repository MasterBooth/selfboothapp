#include "LayoutAnalyzer.h"
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QJsonDocument>
#include <QPointF>
#include <QStack>
#include <algorithm>
#include <limits>

LayoutAnalyzer::LayoutAnalyzer(QObject *parent) : QObject(parent) {}

namespace {
struct ClassifiedTransparentRegions {
    QList<QRect> photoSlots;
    QRect qrSlot;
    bool hasQrSlot = false;
};

double rectArea(const QRect &rect)
{
    return (double)rect.width() * (double)rect.height();
}

bool isNearLayoutCorner(const QRect &rect, int canvasW, int canvasH)
{
    const int left = rect.left();
    const int right = qMax(0, canvasW - rect.right() - 1);
    const int top = rect.top();
    const int bottom = qMax(0, canvasH - rect.bottom() - 1);

    const bool nearHorizontalEdge = qMin(left, right) <= qMax(20, qRound(canvasW * 0.18));
    const bool nearVerticalEdge = qMin(top, bottom) <= qMax(20, qRound(canvasH * 0.18));
    return nearHorizontalEdge && nearVerticalEdge;
}

double closestCornerDistance(const QRect &rect, int canvasW, int canvasH)
{
    const QPointF center = rect.center();
    const QPointF corners[] = {
        QPointF(0, 0),
        QPointF(canvasW, 0),
        QPointF(0, canvasH),
        QPointF(canvasW, canvasH)
    };

    double best = std::numeric_limits<double>::max();
    for (const QPointF &corner : corners) {
        const double dx = (center.x() - corner.x()) / qMax(1, canvasW);
        const double dy = (center.y() - corner.y()) / qMax(1, canvasH);
        best = qMin(best, dx * dx + dy * dy);
    }
    return best;
}

QJsonObject rectToJson(const QRect &rect, int id)
{
    QJsonObject obj;
    if (id > 0)
        obj["id"] = id;
    obj["x"] = rect.x();
    obj["y"] = rect.y();
    obj["width"] = rect.width();
    obj["height"] = rect.height();
    return obj;
}

ClassifiedTransparentRegions classifyTransparentRegions(const QList<QRect> &regions, const QSize &canvasSize)
{
    ClassifiedTransparentRegions classified;
    classified.photoSlots = regions;

    if (regions.size() < 2 || canvasSize.width() <= 0 || canvasSize.height() <= 0)
        return classified;

    QVector<double> areas;
    areas.reserve(regions.size());
    for (const QRect &rect : regions)
        areas.append(rectArea(rect));
    std::sort(areas.begin(), areas.end());

    const double medianArea = areas.at(areas.size() / 2);
    const double totalArea = (double)canvasSize.width() * (double)canvasSize.height();
    const int maxQrSide = qMax(60, qRound(qMin(canvasSize.width(), canvasSize.height()) * 0.35));

    int bestIndex = -1;
    double bestArea = std::numeric_limits<double>::max();
    double bestCornerDistance = std::numeric_limits<double>::max();

    for (int i = 0; i < regions.size(); ++i) {
        const QRect &rect = regions.at(i);
        const double area = rectArea(rect);
        const double aspect = rect.height() > 0 ? (double)rect.width() / (double)rect.height() : 0.0;

        const bool roughlySquare = aspect >= 0.70 && aspect <= 1.35;
        const bool muchSmallerThanPhoto = area <= medianArea * 0.25;
        const bool smallOnCanvas = area <= totalArea * 0.05
                                && rect.width() <= maxQrSide
                                && rect.height() <= maxQrSide;
        const bool nearCorner = isNearLayoutCorner(rect, canvasSize.width(), canvasSize.height());

        if (!roughlySquare || !muchSmallerThanPhoto || !smallOnCanvas || !nearCorner)
            continue;

        const double cornerDistance = closestCornerDistance(rect, canvasSize.width(), canvasSize.height());
        if (area < bestArea || (qFuzzyCompare(area, bestArea) && cornerDistance < bestCornerDistance)) {
            bestIndex = i;
            bestArea = area;
            bestCornerDistance = cornerDistance;
        }
    }

    if (bestIndex >= 0) {
        classified.qrSlot = regions.at(bestIndex);
        classified.hasQrSlot = true;
        classified.photoSlots.removeAt(bestIndex);
    }

    return classified;
}
}

LayoutAnalyzer::TargetSize LayoutAnalyzer::getTargetSizeByAspect(const QSize &size, const QString &dpi, const QString &printerHint)
{
    // ═══════════════════════════════════════════════════════════════════════════
    // QW410: luôn dùng 300dpi, target cố định 600×1200 (5×10")
    // ═══════════════════════════════════════════════════════════════════════════
    bool isQW410 = printerHint.contains("QW410", Qt::CaseInsensitive)
               || printerHint.contains("QW-410", Qt::CaseInsensitive)
               || printerHint.contains("410", Qt::CaseInsensitive);

    if (isQW410) {
        TargetSize t;
        double aspect = (size.height() > 0) ? (double)size.width() / size.height() : 1.0;

        if (aspect <= 0.38) {
            // 5×15 strip dọc → nhân đôi thành portrait 1200×1800 (không cắt, giống RX1)
            t.width  = 600;
            t.height = 1800;
            qDebug() << "[LayoutAnalyzer] QW410 5x15 no-cut: target = 600x1800 (aspect" << aspect << ")";
        } else if (aspect <= 0.58) {
            // 5×10 strip dọc → cắt, scale về 600×1200
            t.width  = 600;
            t.height = 1200;
            qDebug() << "[LayoutAnalyzer] QW410 5x10 cut: target = 600x1200 (aspect" << aspect << ")";
        } else if (aspect <= 1.0) {
            // No-cut portrait: 4×6 → scale về 1200×1800
            t.width  = 1200;
            t.height = 1800;
            qDebug() << "[LayoutAnalyzer] QW410 no-cut portrait: target = 1200x1800 (aspect" << aspect << ")";
        } else {
            // No-cut landscape: 6×4 → scale về 1800×1200
            t.width  = 1800;
            t.height = 1200;
            qDebug() << "[LayoutAnalyzer] QW410 no-cut landscape: target = 1800x1200 (aspect" << aspect << ")";
        }
        return t;
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // RX1/620S: ACTUAL PRINTABLE AREA from DNP DS-RX1 Driver
    // These are NOT theoretical (inch × DPI), but actual canvas size reported by driver.
    //
    // Theoretical vs Actual @ 300 DPI:
    //   2×6" strip:    600 × 1800  →  591 × 1772
    //   4×6" portrait: 1200 × 1800  →  1181 × 1772
    //   6×4" landscape: 1800 × 1200  →  1772 × 1181
    //
    // Theoretical vs Actual @ 600 DPI:
    //   2×6" strip:    1200 × 3600  →  1181 × 3543
    //   4×6" portrait: 2400 × 3600  →  2362 × 3543
    //   6×4" landscape: 3600 × 2400  →  3543 × 2362
    // ═══════════════════════════════════════════════════════════════════════════

    double aspect = (size.height() > 0)
                    ? (double)size.width() / (double)size.height()
                    : 1.0;

    TargetSize t;

    if (dpi == "600dpi") {
        if (aspect <= 0.45) {
            t.width  = 1181;
            t.height = 3543;
            qDebug() << "[LayoutAnalyzer] Paper detected: 2x6 strip @ 600dpi (aspect" << aspect << ")";
        } else if (aspect <= 1.10) {
            t.width  = 2362;
            t.height = 3543;
            qDebug() << "[LayoutAnalyzer] Paper detected: 4x6 portrait @ 600dpi (aspect" << aspect << ")";
        } else if (aspect > 2.0) {
            // 15×5 landscape strip (aspect ~3.0): target = 1 strip 15×5 thực tế driver
            // = 3543×1181 (giống 6×4 nhưng đây là strip ngang, giữ nguyên aspect)
            t.width  = 3543;
            t.height = 1181;
            qDebug() << "[LayoutAnalyzer] Paper detected: 15x5 landscape strip @ 600dpi (aspect" << aspect << ")";
        } else {
            t.width  = 3543;
            t.height = 2362;
            qDebug() << "[LayoutAnalyzer] Paper detected: 6x4 landscape @ 600dpi (aspect" << aspect << ")";
        }
    } else {
        // 300 DPI (default)
        if (aspect <= 0.45) {
            t.width  = 591;
            t.height = 1772;
            qDebug() << "[LayoutAnalyzer] Paper detected: 2x6 strip @ 300dpi (aspect" << aspect << ")";
        } else if (aspect <= 1.10) {
            t.width  = 1181;
            t.height = 1772;
            qDebug() << "[LayoutAnalyzer] Paper detected: 4x6 portrait @ 300dpi (aspect" << aspect << ")";
        } else if (aspect > 2.0) {
            // 15×5 landscape strip (aspect ~3.0): target = 1772×591
            // Giữ nguyên tỉ lệ 15×5, không scale về 6×4
            t.width  = 1772;
            t.height = 591;
            qDebug() << "[LayoutAnalyzer] Paper detected: 15x5 landscape strip @ 300dpi (aspect" << aspect << ")";
        } else {
            t.width  = 1772;
            t.height = 1181;
            qDebug() << "[LayoutAnalyzer] Paper detected: 6x4 landscape @ 300dpi (aspect" << aspect << ")";
        }
    }

    return t;
}


QString LayoutAnalyzer::getOrientation(const QSize &size)
{
    return (size.height() > size.width()) ? "portrait" : "landscape";
}

LayoutAnalyzer::TargetSize LayoutAnalyzer::getTargetSize(const QString &orientation, const QString &dpi)
{
    // LEGACY FUNCTION - Use getTargetSizeByAspect() for new code
    // Updated to use actual printable area instead of theoretical size

    TargetSize target;

    if (dpi == "300dpi") {
        if (orientation == "portrait") {
            // 2×6" strip actual printable area @ 300 DPI
            target.width = 591;
            target.height = 1772;
        } else {
            // 6×4" landscape actual printable area @ 300 DPI
            target.width = 1772;
            target.height = 1181;
        }
    } else if (dpi == "600dpi") {
        if (orientation == "portrait") {
            // 2×6" strip actual printable area @ 600 DPI
            target.width = 1181;
            target.height = 3543;
        } else {
            // 6×4" landscape actual printable area @ 600 DPI
            target.width = 3543;
            target.height = 2362;
        }
    } else {
        // Default to 300dpi portrait
        qWarning() << "LayoutAnalyzer: Unknown DPI" << dpi << ", defaulting to 300dpi portrait";
        target.width = 591;
        target.height = 1772;
    }

    return target;
}

bool LayoutAnalyzer::isLayoutValidForDPI(const QSize &layoutSize, const QString &dpi, const QString &printerHint)
{
    TargetSize target = getTargetSizeByAspect(layoutSize, dpi, printerHint);

    // Calculate ±20% tolerance
    int minWidth  = qRound(target.width  * 0.8);
    int maxWidth  = qRound(target.width  * 1.2);
    int minHeight = qRound(target.height * 0.8);
    int maxHeight = qRound(target.height * 1.2);

    bool widthValid  = (layoutSize.width()  >= minWidth  && layoutSize.width()  <= maxWidth);
    bool heightValid = (layoutSize.height() >= minHeight && layoutSize.height() <= maxHeight);

    qDebug() << "LayoutAnalyzer: Validation for" << dpi
             << "| Current:" << layoutSize.width() << "x" << layoutSize.height()
             << "| Target:" << target.width << "x" << target.height
             << "| Range: [" << minWidth << "-" << maxWidth << "] x [" << minHeight << "-" << maxHeight << "]"
             << "| Valid:" << (widthValid && heightValid);

    return widthValid && heightValid;
}


QImage LayoutAnalyzer::resizeLayout(const QImage &original, const QSize &targetSize)
{
    if (original.isNull() || targetSize.isEmpty()) {
        qWarning() << "LayoutAnalyzer: Invalid input for resize";
        return original;
    }

    // Use smooth transformation to preserve quality
    QImage resized = original.scaled(targetSize, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);

    qDebug() << "LayoutAnalyzer: Resized from" << original.size() << "to" << resized.size();

    return resized;
}

bool LayoutAnalyzer::processLayout(const QString &pngPath, const QString &jsonPath, const QString &dpi, const QString &printerHint)
{
    qDebug() << "-------------------------------------------";
    qDebug() << "[LayoutAnalyzer] *** PROCESS LAYOUT START ***";
    qDebug() << "[LayoutAnalyzer] File:" << pngPath;
    qDebug() << "[LayoutAnalyzer] Target DPI:" << dpi;

    QImageReader reader(pngPath);
    QImage image = reader.read();
    if (image.isNull()) {
        // Log đủ để chẩn đoán: ảnh quá lớn (vượt allocation limit) hay file hỏng.
        qCritical() << "[LayoutAnalyzer] *** FAILED TO LOAD IMAGE ***"
                    << "size(px)=" << reader.size()
                    << "file(MB)=" << (QFileInfo(pngPath).size() / (1024.0 * 1024.0))
                    << "allocLimit(MB)=" << QImageReader::allocationLimit()
                    << "error=" << reader.errorString();
        qDebug() << "-------------------------------------------";
        return false;
    }

    // Ensure format enables alpha access easily
    image = image.convertToFormat(QImage::Format_ARGB32);

    // Check if resize is needed
    QSize currentSize = image.size();
    QString orientation = getOrientation(currentSize);

    qDebug() << "[LayoutAnalyzer] Current size:" << currentSize.width() << "x" << currentSize.height();
    qDebug() << "[LayoutAnalyzer] Orientation:" << orientation;

    if (!isLayoutValidForDPI(currentSize, dpi, printerHint)) {
        TargetSize target = getTargetSizeByAspect(currentSize, dpi, printerHint);
        QSize targetSize(target.width, target.height);

        qDebug() << "LayoutAnalyzer: Layout not valid for" << dpi
                 << "- Resizing from" << currentSize.width() << "x" << currentSize.height()
                 << "to" << target.width << "x" << target.height;

        image = resizeLayout(image, targetSize);

        // Save the resized image (overwrite original)
        if (!image.save(pngPath, "PNG")) {
            qCritical() << "LayoutAnalyzer: Failed to save resized image to" << pngPath;
            return false;
        }

        qDebug() << "LayoutAnalyzer: Successfully saved resized layout";
    } else {
        qDebug() << "LayoutAnalyzer: Layout already valid for" << dpi << "- No resize needed";
    }

    QList<QRect> detectedSlots = findTransparentSlots(image);
    
    if (detectedSlots.isEmpty()) {
        qWarning() << "LayoutAnalyzer: No transparent slots found in" << pngPath;
        return false;
    }

    // Sort detectedSlots: Top-to-bottom, then Left-to-right
    std::sort(detectedSlots.begin(), detectedSlots.end(), [](const QRect &a, const QRect &b) {
        int yDiff = qAbs(a.top() - b.top());
        if (yDiff > 50) { // within 50px vertical band
            return a.top() < b.top();
        }
        return a.left() < b.left();
    });

    ClassifiedTransparentRegions classified = classifyTransparentRegions(detectedSlots, image.size());

    // Create JSON
    QJsonObject rootObj;
    rootObj["width"] = image.width();
    rootObj["height"] = image.height();
    rootObj["slot_count"] = classified.photoSlots.size();
    
    QJsonArray slotsArray;
    for (int i = 0; i < classified.photoSlots.count(); i++) {
        slotsArray.append(rectToJson(classified.photoSlots[i], i + 1));
    }
    
    rootObj["slots"] = slotsArray;
    if (classified.hasQrSlot)
        rootObj["qr_slot"] = rectToJson(classified.qrSlot, 0);

    // Save JSON
    QFile saveFile(jsonPath);
    if (!saveFile.open(QIODevice::WriteOnly)) {
        qCritical() << "LayoutAnalyzer: Could not write JSON to" << jsonPath;
        return false;
    }

    QJsonDocument saveDoc(rootObj);
    saveFile.write(saveDoc.toJson());
    saveFile.close();

    qDebug() << "[LayoutAnalyzer] *** PROCESS LAYOUT SUCCESS ***";
    qDebug() << "[LayoutAnalyzer] Final size:" << image.width() << "x" << image.height();
    qDebug() << "[LayoutAnalyzer] Photo slots found:" << classified.photoSlots.size();
    if (classified.hasQrSlot)
        qDebug() << "[LayoutAnalyzer] QR slot found:" << classified.qrSlot;
    qDebug() << "[LayoutAnalyzer] JSON saved to:" << jsonPath;
    qDebug() << "-------------------------------------------";
    return true;
}

QList<QRect> LayoutAnalyzer::findTransparentSlots(const QImage &image)
{
    QList<QRect> results;
    int w = image.width();
    int h = image.height();

    // ── Validation thresholds (proportional to layout size) ──────────
    // Min dimension: each side must be ≥ 3% of the corresponding layout dimension
    int minSlotW = qMax(60, (int)(w * 0.03));
    int minSlotH = qMax(60, (int)(h * 0.03));
    // Min area: bounding box area must be ≥ 0.5% of total layout area
    double layoutArea = (double)w * h;
    double minAreaRatio = 0.005;
    // Min fill ratio: transparent pixels must fill ≥ 25% of bounding box
    // Giảm xuống 25% để hỗ trợ layout nhiều hoạ tiết/trang trí làm gián đoạn vùng trong suốt
    double minFillRatio = 0.25;
    // Aspect ratio sanity: slot W:H must be between 0.15 and 6.5
    // (covers everything from tall 2x6 strips to wide panoramic slots)
    double minAspect = 0.15;
    double maxAspect = 6.5;

    qDebug() << "[LayoutAnalyzer] Slot detection thresholds:"
             << "minW=" << minSlotW << "minH=" << minSlotH
             << "minAreaRatio=" << minAreaRatio
             << "minFill=" << minFillRatio
             << "aspectRange=[" << minAspect << "-" << maxAspect << "]";

    // Visited map
    QVector<QVector<bool>> visited(h, QVector<bool>(w, false));

    int rejectedCount = 0;

    for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
            if (!visited[y][x] && qAlpha(image.pixel(x, y)) < 10) { // Threshold for transparency
                // Found a new unvisited transparent pixel -> Start Flood Fill
                int minX = x, maxX = x;
                int minY = y, maxY = y;
                int pixelCount = 0;

                QStack<QPoint> stack;
                stack.push(QPoint(x, y));
                visited[y][x] = true;

                while (!stack.isEmpty()) {
                    QPoint p = stack.pop();
                    int cx = p.x();
                    int cy = p.y();
                    pixelCount++;

                    if (cx < minX) minX = cx;
                    if (cx > maxX) maxX = cx;
                    if (cy < minY) minY = cy;
                    if (cy > maxY) maxY = cy;

                    // 4-connectivity neighbors
                    const int dx[] = {0, 0, -1, 1};
                    const int dy[] = {-1, 1, 0, 0};

                    for (int k = 0; k < 4; k++) {
                        int nx = cx + dx[k];
                        int ny = cy + dy[k];

                        if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                            if (!visited[ny][nx] && qAlpha(image.pixel(nx, ny)) < 10) {
                                visited[ny][nx] = true;
                                stack.push(QPoint(nx, ny));
                            }
                        }
                    }
                }

                // ── Validate detected region ────────────────────────────
                int rw = maxX - minX + 1;
                int rh = maxY - minY + 1;
                double bboxArea = (double)rw * rh;
                double areaRatio = bboxArea / layoutArea;
                double fillRatio = (bboxArea > 0) ? (double)pixelCount / bboxArea : 0;
                double aspect = (rh > 0) ? (double)rw / rh : 0;

                // Check 1: Minimum dimensions (proportional)
                if (rw < minSlotW || rh < minSlotH) {
                    rejectedCount++;
                    qDebug() << "[LayoutAnalyzer] Rejected region: too small"
                             << rw << "x" << rh << "at (" << minX << "," << minY << ")"
                             << "| Need >=" << minSlotW << "x" << minSlotH;
                    continue;
                }

                // Check 2: Minimum area ratio
                if (areaRatio < minAreaRatio) {
                    rejectedCount++;
                    qDebug() << "[LayoutAnalyzer] Rejected region: area too small"
                             << rw << "x" << rh << "at (" << minX << "," << minY << ")"
                             << "| areaRatio=" << QString::number(areaRatio, 'f', 4)
                             << "need >=" << minAreaRatio;
                    continue;
                }

                // Check 3: Fill ratio (reject irregular / non-rectangular shapes)
                if (fillRatio < minFillRatio) {
                    rejectedCount++;
                    qDebug() << "[LayoutAnalyzer] Rejected region: low fill ratio"
                             << rw << "x" << rh << "at (" << minX << "," << minY << ")"
                             << "| fill=" << QString::number(fillRatio, 'f', 2)
                             << "(" << pixelCount << "/" << (int)bboxArea << ")"
                             << "need >=" << minFillRatio;
                    continue;
                }

                // Check 4: Aspect ratio sanity (reject thin strips / lines)
                if (aspect < minAspect || aspect > maxAspect) {
                    rejectedCount++;
                    qDebug() << "[LayoutAnalyzer] Rejected region: bad aspect ratio"
                             << rw << "x" << rh << "at (" << minX << "," << minY << ")"
                             << "| aspect=" << QString::number(aspect, 'f', 2)
                             << "need [" << minAspect << "-" << maxAspect << "]";
                    continue;
                }

                // ✓ All checks passed — valid photo slot
                qDebug() << "[LayoutAnalyzer] ✓ Valid slot:" << rw << "x" << rh
                         << "at (" << minX << "," << minY << ")"
                         << "| area=" << QString::number(areaRatio * 100, 'f', 1) << "%"
                         << "| fill=" << QString::number(fillRatio * 100, 'f', 0) << "%"
                         << "| aspect=" << QString::number(aspect, 'f', 2);
                results.append(QRect(minX, minY, rw, rh));
            }
        }
    }

    qDebug() << "[LayoutAnalyzer] Detection complete:"
             << results.size() << "valid slots," << rejectedCount << "rejected regions";

    return results;
}
