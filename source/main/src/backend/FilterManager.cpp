#include "FilterManager.h"
#include "AppPaths.h"
#include "ImageCompositor.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QUuid>
#include <QDebug>
#include <QPainter>
#include <QUrl>
#include <QtConcurrent/QtConcurrent>
#include <cmath>
#include <memory>

static QString toLocalPath(const QString& p) {
    // Strip file:/// or file:// prefix if present
    if (p.startsWith("file:///")) return QUrl(p).toLocalFile();
    if (p.startsWith("file://"))  return QUrl(p).toLocalFile();
    return p;
}

// ─────────────────────────────────────────────────────────────────────────────
// LUT3D implementation
// ─────────────────────────────────────────────────────────────────────────────

bool LUT3D::loadFromFile(const QString& path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "[LUT3D] Cannot open:" << path;
        return false;
    }

    size = 0;
    data.clear();

    QTextStream in(&f);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) continue;

        // Parse LUT_3D_SIZE
        if (line.startsWith("LUT_3D_SIZE", Qt::CaseInsensitive)) {
            size = line.section(' ', -1).toInt();
            data.reserve(size * size * size);
            continue;
        }

        // Skip other keywords
        if (line.contains(' ') && !line[0].isDigit() && line[0] != '-' && line[0] != '+')
            continue;

        // Parse r g b data line
        QStringList parts = line.split(' ', Qt::SkipEmptyParts);
        if (parts.size() >= 3) {
            data.append({parts[0].toFloat(), parts[1].toFloat(), parts[2].toFloat()});
        }
    }

    if (!isValid()) {
        qWarning() << "[LUT3D] Invalid LUT: size=" << size << "data=" << data.size();
        return false;
    }
    qDebug() << "[LUT3D] Loaded" << size << "^3 LUT from" << path;
    return true;
}

void LUT3D::lookup(float ri, float gi, float bi,
                   float& ro, float& go, float& bo) const {
    float rf = ri * (size - 1);
    float gf = gi * (size - 1);
    float bf = bi * (size - 1);

    int r0 = (int)rf; if (r0 >= size - 1) r0 = size - 2;
    int g0 = (int)gf; if (g0 >= size - 1) g0 = size - 2;
    int b0 = (int)bf; if (b0 >= size - 1) b0 = size - 2;
    int r1 = r0 + 1, g1 = g0 + 1, b1 = b0 + 1;

    float dr = rf - r0, dg = gf - g0, db = bf - b0;

    // Adobe/common .cube files list red fastest, then green, with blue as the
    // outer axis. The previous R-major lookup sampled the wrong cube cells and
    // produced a strong blue cast on Photoshop-exported LUTs.
    auto idx = [&](int ri_, int gi_, int bi_) -> int {
        return bi_ * size * size + gi_ * size + ri_;
    };

    const auto& c000 = data[idx(r0, g0, b0)];
    const auto& c001 = data[idx(r0, g0, b1)];
    const auto& c010 = data[idx(r0, g1, b0)];
    const auto& c011 = data[idx(r0, g1, b1)];
    const auto& c100 = data[idx(r1, g0, b0)];
    const auto& c101 = data[idx(r1, g0, b1)];
    const auto& c110 = data[idx(r1, g1, b0)];
    const auto& c111 = data[idx(r1, g1, b1)];

    float w000 = (1-dr)*(1-dg)*(1-db);
    float w001 = (1-dr)*(1-dg)*   db ;
    float w010 = (1-dr)*   dg *(1-db);
    float w011 = (1-dr)*   dg *   db ;
    float w100 =    dr *(1-dg)*(1-db);
    float w101 =    dr *(1-dg)*   db ;
    float w110 =    dr *   dg *(1-db);
    float w111 =    dr *   dg *   db ;

    ro = c000[0]*w000 + c001[0]*w001 + c010[0]*w010 + c011[0]*w011
       + c100[0]*w100 + c101[0]*w101 + c110[0]*w110 + c111[0]*w111;
    go = c000[1]*w000 + c001[1]*w001 + c010[1]*w010 + c011[1]*w011
       + c100[1]*w100 + c101[1]*w101 + c110[1]*w110 + c111[1]*w111;
    bo = c000[2]*w000 + c001[2]*w001 + c010[2]*w010 + c011[2]*w011
       + c100[2]*w100 + c101[2]*w101 + c110[2]*w110 + c111[2]*w111;
}

// ─────────────────────────────────────────────────────────────────────────────
// FilterManager
// ─────────────────────────────────────────────────────────────────────────────

FilterManager::FilterManager(QObject* parent) : QObject(parent) {
    QDir().mkpath(filtersDir());
}

QString FilterManager::filtersDir() const {
    return QDir(AppPaths::instance().getAppDirectory()).filePath("filters");
}

QString FilterManager::metadataPath() const {
    return QDir(filtersDir()).filePath("metadata.json");
}

QString FilterManager::generateId() const {
    return QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
}

QVariantList FilterManager::loadMetadata() const {
    QFile f(metadataPath());
    if (!f.open(QIODevice::ReadOnly)) return {};
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    QVariantList result;
    for (const auto& v : doc.array())
        result << v.toObject().toVariantMap();
    return result;
}

void FilterManager::saveMetadata(const QVariantList& list) {
    QJsonArray arr;
    for (const auto& v : list)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    QFile f(metadataPath());
    if (f.open(QIODevice::WriteOnly))
        f.write(QJsonDocument(arr).toJson());
}

QVariantList FilterManager::getFilters() {
    return loadMetadata();
}

QVariantList FilterManager::getFavoriteFilters() {
    QVariantList result;
    for (const auto& v : loadMetadata()) {
        auto m = v.toMap();
        if (m.value("favorite", false).toBool())
            result << m;
    }
    return result;
}

bool FilterManager::toggleFilterFavorite(const QString& filterId) {
    auto meta = loadMetadata();
    for (auto& v : meta) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            m["favorite"] = !m.value("favorite", false).toBool();
            v = m;
            saveMetadata(meta);
            emit filtersChanged();
            return m["favorite"].toBool();
        }
    }
    return false;
}

bool FilterManager::setFilterFavorite(const QString& filterId, bool favorite) {
    auto meta = loadMetadata();
    for (auto& v : meta) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            m["favorite"] = favorite;
            v = m;
            saveMetadata(meta);
            emit filtersChanged();
            return true;
        }
    }
    return false;
}

bool FilterManager::isValidCubeFile(const QString& cubePath) {
    LUT3D lut;
    return lut.loadFromFile(toLocalPath(cubePath));
}

bool FilterManager::importFilterWithId(const QString& filterId,
                                       const QString& cubePath,
                                       const QString& name,
                                       const QString& thumbnailPath,
                                       bool favorite) {
    const QString cleanId = filterId.trimmed();
    if (cleanId.isEmpty() || !isValidCubeFile(cubePath)) return false;

    auto meta = loadMetadata();
    for (int i = 0; i < meta.size(); ++i) {
        if (meta[i].toMap().value(QStringLiteral("id")).toString() == cleanId) {
            deleteFilter(cleanId);
            meta = loadMetadata();
            break;
        }
    }

    const QString dir = QDir(filtersDir()).filePath(cleanId);
    QDir().mkpath(dir);
    const QString dest = QDir(dir).filePath(QStringLiteral("filter.cube"));
    QFile::remove(dest);
    if (!QFile::copy(toLocalPath(cubePath), dest)) return false;

    QString thumbDest;
    const QString cleanThumb = toLocalPath(thumbnailPath);
    if (!cleanThumb.isEmpty() && QFile::exists(cleanThumb)) {
        QFileInfo tfi(cleanThumb);
        QString suffix = tfi.suffix().isEmpty() ? QStringLiteral("png") : tfi.suffix();
        thumbDest = QDir(dir).filePath(QStringLiteral("thumbnail.") + suffix);
        QFile::remove(thumbDest);
        if (!QFile::copy(cleanThumb, thumbDest)) thumbDest.clear();
    }

    QVariantMap entry;
    entry[QStringLiteral("id")] = cleanId;
    entry[QStringLiteral("name")] = name.trimmed().isEmpty() ? QFileInfo(cubePath).baseName() : name.trimmed();
    entry[QStringLiteral("cubePath")] = dest;
    entry[QStringLiteral("thumbnailPath")] = thumbDest;
    entry[QStringLiteral("favorite")] = favorite;
    meta << entry;
    saveMetadata(meta);
    emit filtersChanged();
    return true;
}

bool FilterManager::importFilters(const QStringList& cubePaths) {
    auto meta = loadMetadata();
    bool any = false;
    for (const QString& src : cubePaths) {
        QFileInfo fi(src);
        if (!fi.exists()) continue;
        QString id  = generateId();
        QString dir = QDir(filtersDir()).filePath(id);
        QDir().mkpath(dir);
        QString dest = QDir(dir).filePath("filter.cube");
        if (!QFile::copy(src, dest)) {
            qWarning() << "[FilterManager] Failed to copy" << src;
            continue;
        }
        QVariantMap entry;
        entry["id"]            = id;
        entry["name"]          = fi.baseName();
        entry["cubePath"]      = dest;
        entry["thumbnailPath"] = "";
        meta << entry;
        any = true;
    }
    if (any) { saveMetadata(meta); emit filtersChanged(); }
    return any;
}

bool FilterManager::renameFilter(const QString& filterId, const QString& newName) {
    auto meta = loadMetadata();
    for (auto& v : meta) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            m["name"] = newName;
            v = m;
            saveMetadata(meta);
            emit filtersChanged();
            return true;
        }
    }
    return false;
}

bool FilterManager::deleteFilter(const QString& filterId) {
    auto meta = loadMetadata();
    for (int i = 0; i < meta.size(); i++) {
        auto m = meta[i].toMap();
        if (m["id"].toString() == filterId) {
            // Remove directory
            QDir(QDir(filtersDir()).filePath(filterId)).removeRecursively();
            meta.removeAt(i);
            saveMetadata(meta);
            emit filtersChanged();
            return true;
        }
    }
    return false;
}

bool FilterManager::setFilterThumbnail(const QString& filterId, const QString& imagePath) {
    auto meta = loadMetadata();
    for (auto& v : meta) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            QString dir  = QDir(filtersDir()).filePath(filterId);
            QFileInfo fi(imagePath);
            QString dest = QDir(dir).filePath("thumbnail" + fi.suffix().prepend('.'));
            // Remove old thumbnail
            QString oldThumb = m["thumbnailPath"].toString();
            if (!oldThumb.isEmpty() && oldThumb != dest) QFile::remove(oldThumb);
            if (!QFile::copy(imagePath, dest)) {
                // try remove then copy
                QFile::remove(dest);
                if (!QFile::copy(imagePath, dest)) return false;
            }
            m["thumbnailPath"] = dest;
            v = m;
            saveMetadata(meta);
            emit filtersChanged();
            return true;
        }
    }
    return false;
}

bool FilterManager::replaceFilterFile(const QString& filterId, const QString& newCubePath) {
    if (!isValidCubeFile(newCubePath)) return false;
    auto meta = loadMetadata();
    for (auto& v : meta) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            QString dest = QDir(QDir(filtersDir()).filePath(filterId)).filePath("filter.cube");
            QFile::remove(dest);
            if (!QFile::copy(newCubePath, dest)) return false;
            m["cubePath"] = dest;
            v = m;
            saveMetadata(meta);
            emit filtersChanged();
            return true;
        }
    }
    return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Apply filter (async)
// ─────────────────────────────────────────────────────────────────────────────

void FilterManager::applyFilterAsync(const QString& imagePath,
                                     const QString& filterId,
                                     const QString& layoutPath) {
    // Tìm cubePath trên calling thread (main thread) — tránh đọc file JSON trong background thread
    QString cubePath;
    for (const auto& v : loadMetadata()) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            cubePath = m["cubePath"].toString();
            break;
        }
    }
    if (cubePath.isEmpty() || !QFile::exists(cubePath)) {
        qWarning() << "[FilterManager] Cube not found for filter:" << filterId;
        emit filterApplyComplete(false, imagePath);
        return;
    }

    // Tăng serial: thread cũ đang chạy sẽ đọc serial mới → tự thoát vòng lặp pixel
    int serial = ++m_applySerial;

    QtConcurrent::run([this, imagePath, cubePath, layoutPath, serial]() {
        // Kiểm tra ngay đầu: nếu đã có request mới hơn thì bỏ qua luôn
        if (m_applySerial.load(std::memory_order_relaxed) != serial) return;

        QString result = applyFilterSync(imagePath, cubePath, layoutPath, serial);

        // Chỉ emit nếu đây vẫn là operation hiện tại (không bị supersede)
        if (m_applySerial.load(std::memory_order_relaxed) == serial) {
            emit filterApplyComplete(!result.isEmpty(), result.isEmpty() ? imagePath : result);
        }
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// Apply filter ĐÚNG CÁCH: filter từng ảnh slot rồi overlay frame (frame không bị filter)
// ─────────────────────────────────────────────────────────────────────────────

void FilterManager::applyFilterToCompositionAsync(const QStringList& photoPaths,
                                                  const QString& filterId,
                                                  const QString& layoutPath,
                                                  const QVariantList& transforms,
                                                  bool autoCut,
                                                  const QString& printerHint) {
    // Tìm cubePath trên main thread
    QString cubePath;
    for (const auto& v : loadMetadata()) {
        auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            cubePath = m["cubePath"].toString();
            break;
        }
    }
    if (cubePath.isEmpty() || !QFile::exists(cubePath)) {
        qWarning() << "[FilterManager] Cube not found for filter:" << filterId;
        emit filterApplyComplete(false, QString());
        return;
    }

    // Chuẩn hoá đường dẫn PNG frame + tìm JSON slots cạnh nó (trên main thread)
    const QString layoutPng = toLocalPath(layoutPath);
    QString layoutJson = layoutPng;
    int lastDot = layoutJson.lastIndexOf('.');
    if (lastDot != -1) layoutJson = layoutJson.left(lastDot);
    layoutJson += ".json";

    QVariantList layoutSlots;
    {
        QFile jf(layoutJson);
        if (jf.open(QIODevice::ReadOnly)) {
            QJsonDocument doc = QJsonDocument::fromJson(jf.readAll());
            layoutSlots = doc.object()["slots"].toArray().toVariantList();
        }
    }
    if (layoutSlots.isEmpty()) {
        qWarning() << "[FilterManager] No slots in layout JSON:" << layoutJson;
        emit filterApplyComplete(false, QString());
        return;
    }

    // Làm sạch đường dẫn ảnh gốc
    QStringList cleanPaths;
    for (const QString& p : photoPaths)
        cleanPaths << QDir::toNativeSeparators(toLocalPath(p));

    if (cleanPaths.isEmpty()) {
        qWarning() << "[FilterManager] No photos to filter";
        emit filterApplyComplete(false, QString());
        return;
    }

    // Output ghi cạnh ảnh gốc đầu tiên (thư mục session — chắc chắn ghi được),
    // KHÔNG ghi cạnh frame template (có thể nằm trong thư mục read-only).
    QFileInfo fi(cleanPaths.first());
    QString outputPath = QDir(fi.absolutePath()).filePath(
        QString("filtered_%1.jpg").arg(
            QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz")));

    int serial = ++m_applySerial;

    QtConcurrent::run([this, cleanPaths, cubePath, layoutPng, layoutSlots,
                       outputPath, transforms, autoCut, printerHint, serial]() {
        if (m_applySerial.load(std::memory_order_relaxed) != serial) return;

        // Load LUT một lần trong worker thread
        auto lut = std::make_shared<LUT3D>();
        if (!lut->loadFromFile(cubePath)) {
            if (m_applySerial.load(std::memory_order_relaxed) == serial)
                emit filterApplyComplete(false, QString());
            return;
        }

        // Lambda áp LUT lên một ảnh slot (in-place). Chỉ biến đổi RGB, giữ alpha.
        auto slotFilter = [lut](QImage& slot) {
            if (slot.isNull()) return;
            if (slot.format() != QImage::Format_ARGB32)
                slot = slot.convertToFormat(QImage::Format_ARGB32);
            for (int y = 0; y < slot.height(); ++y) {
                QRgb* row = reinterpret_cast<QRgb*>(slot.scanLine(y));
                for (int x = 0; x < slot.width(); ++x) {
                    QRgb px = row[x];
                    float ro, go, bo;
                    lut->lookup(qRed(px)/255.0f, qGreen(px)/255.0f, qBlue(px)/255.0f,
                                ro, go, bo);
                    row[x] = qRgba(
                        qBound(0, (int)(ro * 255.0f + 0.5f), 255),
                        qBound(0, (int)(go * 255.0f + 0.5f), 255),
                        qBound(0, (int)(bo * 255.0f + 0.5f), 255),
                        qAlpha(px));
                }
            }
        };

        // autoCut: tạo strip không-margin (overlay-size) → composeCutFromStrip xử lý canvas in.
        // no-cut : tạo ảnh in hoàn chỉnh có safe-margin (compose() — giống output không filter).
        // Keep the filtered result on the same raw overlay-size canvas as the
        // unfiltered composition preview. Cut/print canvas expansion is handled
        // later by FilterScreen/EventManager when the user prints.
        Q_UNUSED(autoCut)
        Q_UNUSED(printerHint)
        bool ok = ImageCompositor::composeRawFiltered(
            cleanPaths, layoutPng, layoutSlots, outputPath, transforms, slotFilter);

        if (m_applySerial.load(std::memory_order_relaxed) == serial) {
            emit filterApplyComplete(ok, ok ? outputPath : QString());
        }
    });
}

// cubePath được truyền thẳng từ applyFilterAsync (đã tìm trên main thread)
// serial dùng để huỷ vòng lặp pixel khi có request mới hơn
void FilterManager::applyFilterToPhotosAsync(const QStringList& photoPaths,
                                             const QString& filterId) {
    if (photoPaths.isEmpty() || filterId.isEmpty()) {
        emit photosFilterComplete(true);
        return;
    }

    QString cubePath;
    for (const auto& v : loadMetadata()) {
        const auto m = v.toMap();
        if (m["id"].toString() == filterId) {
            cubePath = m["cubePath"].toString();
            break;
        }
    }

    if (cubePath.isEmpty() || !QFile::exists(cubePath)) {
        qWarning() << "[FilterManager] Individual photo LUT not found for filter:"
                   << filterId;
        emit photosFilterComplete(true);
        return;
    }

    QStringList cleanPaths;
    for (const QString& p : photoPaths) {
        const QString clean = QDir::toNativeSeparators(toLocalPath(p));
        if (!clean.isEmpty())
            cleanPaths << clean;
    }

    if (cleanPaths.isEmpty()) {
        emit photosFilterComplete(true);
        return;
    }

    QtConcurrent::run([this, cleanPaths, cubePath]() {
        LUT3D lut;
        bool success = true;
        if (!lut.loadFromFile(cubePath)) {
            emit photosFilterComplete(false);
            return;
        }

        for (const QString& path : cleanPaths) {
            QImage img(path);
            if (img.isNull()) {
                qWarning() << "[FilterManager] Cannot load individual photo:" << path;
                success = false;
                continue;
            }

            if (img.format() != QImage::Format_ARGB32)
                img = img.convertToFormat(QImage::Format_ARGB32);

            for (int y = 0; y < img.height(); ++y) {
                QRgb* row = reinterpret_cast<QRgb*>(img.scanLine(y));
                for (int x = 0; x < img.width(); ++x) {
                    QRgb px = row[x];
                    float ro, go, bo;
                    lut.lookup(qRed(px) / 255.0f,
                               qGreen(px) / 255.0f,
                               qBlue(px) / 255.0f,
                               ro, go, bo);
                    row[x] = qRgba(
                        qBound(0, static_cast<int>(ro * 255.0f + 0.5f), 255),
                        qBound(0, static_cast<int>(go * 255.0f + 0.5f), 255),
                        qBound(0, static_cast<int>(bo * 255.0f + 0.5f), 255),
                        qAlpha(px));
                }
            }

            if (!img.save(path, "JPG", 95)) {
                qWarning() << "[FilterManager] Cannot overwrite filtered photo:" << path;
                success = false;
            }
        }

        emit photosFilterComplete(success);
    });
}

QString FilterManager::applyFilterSync(const QString& rawImagePath,
                                       const QString& cubePath,
                                       const QString& rawLayoutPath,
                                       int serial) {
    const QString imagePath  = toLocalPath(rawImagePath);
    const QString layoutPath = toLocalPath(rawLayoutPath);

    // 1. Load the base image
    QImage img(imagePath);
    if (img.isNull()) {
        qWarning() << "[FilterManager] Cannot load image:" << imagePath;
        return "";
    }
    img = img.convertToFormat(QImage::Format_ARGB32);

    // 2. Load LUT (cubePath đã được validate trên main thread)
    LUT3D lut;
    if (!lut.loadFromFile(cubePath)) return "";

    // Save original for frame-mask restoration after LUT application
    QImage original;
    if (!layoutPath.isEmpty() && QFile::exists(layoutPath)) {
        original = img.copy();
    }

    // 3. Apply LUT — kiểm tra serial mỗi hàng để thoát sớm khi có request mới
    for (int y = 0; y < img.height(); y++) {
        // Cancellation check: nếu serial không khớp → request mới đã đến, bỏ luôn
        if (m_applySerial.load(std::memory_order_relaxed) != serial) {
            qDebug() << "[FilterManager] applyFilterSync: cancelled at row" << y;
            return "";
        }
        QRgb* row = reinterpret_cast<QRgb*>(img.scanLine(y));
        for (int x = 0; x < img.width(); x++) {
            QRgb px = row[x];
            float ri = qRed(px)   / 255.0f;
            float gi = qGreen(px) / 255.0f;
            float bi = qBlue(px)  / 255.0f;
            float ro, go, bo;
            lut.lookup(ri, gi, bi, ro, go, bo);
            row[x] = qRgba(
                qBound(0, (int)(ro * 255.0f + 0.5f), 255),
                qBound(0, (int)(go * 255.0f + 0.5f), 255),
                qBound(0, (int)(bo * 255.0f + 0.5f), 255),
                qAlpha(px)
            );
        }
    }

    // 4. Restore frame pixels using frame PNG alpha as mask.
    //    frame alpha = 0   (slot area)    → keep filtered pixel
    //    frame alpha = 255 (solid frame)  → restore original pixel (no filter bleed)
    //    frame alpha = 1-254 (semi-trans) → proportional blend toward original
    if (!layoutPath.isEmpty() && QFile::exists(layoutPath) && !original.isNull()) {
        QImage frame(layoutPath);
        if (!frame.isNull()) {
            frame = frame.scaled(img.size(), Qt::IgnoreAspectRatio, Qt::SmoothTransformation)
                         .convertToFormat(QImage::Format_ARGB32);
            for (int y = 0; y < img.height(); y++) {
                const QRgb* origRow  = reinterpret_cast<const QRgb*>(original.constScanLine(y));
                QRgb*       filtRow  = reinterpret_cast<QRgb*>(img.scanLine(y));
                const QRgb* frameRow = reinterpret_cast<const QRgb*>(frame.constScanLine(y));
                for (int x = 0; x < img.width(); x++) {
                    int fa = qAlpha(frameRow[x]);
                    if (fa == 0) continue;
                    if (fa == 255) {
                        filtRow[x] = origRow[x];
                    } else {
                        int fi = 255 - fa;
                        filtRow[x] = qRgba(
                            (qRed(origRow[x])   * fa + qRed(filtRow[x])   * fi) / 255,
                            (qGreen(origRow[x]) * fa + qGreen(filtRow[x]) * fi) / 255,
                            (qBlue(origRow[x])  * fa + qBlue(filtRow[x])  * fi) / 255,
                            qAlpha(filtRow[x])
                        );
                    }
                }
            }
            frame = QImage();
        }
    }

    // 5. Save output next to the original with "_filtered" suffix
    QFileInfo fi(imagePath);
    QString outputPath = QDir(fi.absolutePath()).filePath(
        fi.baseName() + "_filtered." + fi.suffix());
    if (!img.save(outputPath, nullptr, 95)) {
        qWarning() << "[FilterManager] Failed to save filtered image:" << outputPath;
        return "";
    }
    qDebug() << "[FilterManager] Filter applied:" << outputPath;
    return outputPath;
}
