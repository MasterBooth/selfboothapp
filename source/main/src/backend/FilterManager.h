#ifndef FILTERMANAGER_H
#define FILTERMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>
#include <QImage>
#include <array>
#include <atomic>

// 3D LUT parsed from a .cube file
struct LUT3D {
    int size = 0;
    QVector<std::array<float, 3>> data; // indexed [r*size*size + g*size + b]

    bool loadFromFile(const QString& path);
    void lookup(float ri, float gi, float bi,
                float& ro, float& go, float& bo) const;
    bool isValid() const { return size > 0 && data.size() == size * size * size; }
};

class FilterManager : public QObject {
    Q_OBJECT

public:
    explicit FilterManager(QObject* parent = nullptr);

    // ── Filter CRUD ──────────────────────────────────────────────────────────
    Q_INVOKABLE QVariantList getFilters();
    Q_INVOKABLE QVariantList getFavoriteFilters();
    Q_INVOKABLE bool importFilters(const QStringList& cubePaths);
    Q_INVOKABLE bool renameFilter(const QString& filterId, const QString& newName);
    Q_INVOKABLE bool deleteFilter(const QString& filterId);
    Q_INVOKABLE bool setFilterThumbnail(const QString& filterId, const QString& imagePath);
    Q_INVOKABLE bool replaceFilterFile(const QString& filterId, const QString& newCubePath);
    Q_INVOKABLE bool toggleFilterFavorite(const QString& filterId);
    Q_INVOKABLE bool setFilterFavorite(const QString& filterId, bool favorite);
    Q_INVOKABLE bool importFilterWithId(const QString& filterId,
                                        const QString& cubePath,
                                        const QString& name,
                                        const QString& thumbnailPath = QString(),
                                        bool favorite = false);
    Q_INVOKABLE bool isValidCubeFile(const QString& cubePath);

    // ── Apply filter ─────────────────────────────────────────────────────────
    // Async: result delivered via filterApplyComplete signal
    Q_INVOKABLE void applyFilterAsync(const QString& imagePath,
                                      const QString& filterId,
                                      const QString& layoutPath);

    // Filter ĐÚNG CÁCH: áp LUT lên từng ảnh slot gốc rồi mới overlay frame.
    // Frame (kể cả hoạ tiết đè lên slot) KHÔNG đi qua filter → không bị ám màu.
    // photoPaths: ảnh gốc theo slot; layoutPath: PNG frame (JSON slots cạnh nó);
    // transforms: [{scale,tx,ty}] pan/zoom mỗi slot.
    // Result delivered via filterApplyComplete signal.
    // autoCut=true: tạo strip không-margin (overlay-size) để composeCutFromStrip xử lý tiếp.
    // autoCut=false (no-cut): tạo ảnh in hoàn chỉnh có safe-margin (giống compose()).
    // printerHint: tên máy in để chọn margin đúng (RX1/620S/QW410).
    Q_INVOKABLE void applyFilterToCompositionAsync(const QStringList& photoPaths,
                                                   const QString& filterId,
                                                   const QString& layoutPath,
                                                   const QVariantList& transforms,
                                                   bool autoCut,
                                                   const QString& printerHint);

    Q_INVOKABLE void applyFilterToPhotosAsync(const QStringList& photoPaths,
                                              const QString& filterId);

signals:
    void filtersChanged();
    void filterApplyComplete(bool success, const QString& outputPath);
    void photosFilterComplete(bool success);

private:
    QString filtersDir() const;
    QString metadataPath() const;
    QVariantList loadMetadata() const;
    void saveMetadata(const QVariantList& list);
    QString generateId() const;

    // Synchronous apply — called from background thread
    // serial: tăng mỗi lần applyFilterAsync được gọi mới; dùng để huỷ operation cũ.
    QString applyFilterSync(const QString& imagePath,
                            const QString& cubePath,
                            const QString& layoutPath,
                            int serial);

    // Serial counter — tăng atomically mỗi lần request mới, thread cũ kiểm tra để tự huỷ
    std::atomic<int> m_applySerial{0};
};

#endif // FILTERMANAGER_H
