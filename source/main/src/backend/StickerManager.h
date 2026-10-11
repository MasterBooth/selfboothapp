#ifndef STICKERMANAGER_H
#define STICKERMANAGER_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QStringList>

// Quản lý thư viện sticker (PNG trong suốt) — song song với FilterManager.
// Lưu file ở {AppDir}/stickers/{id}/sticker.png + metadata.json (mảng {id,name,path}).
class StickerManager : public QObject {
    Q_OBJECT

public:
    explicit StickerManager(QObject* parent = nullptr);

    Q_INVOKABLE QVariantList getStickers();
    Q_INVOKABLE bool importStickers(const QStringList& paths);
    Q_INVOKABLE bool renameSticker(const QString& stickerId, const QString& newName);
    Q_INVOKABLE bool deleteSticker(const QString& stickerId);

signals:
    void stickersChanged();

private:
    QString stickersDir() const;
    QString metadataPath() const;
    QVariantList loadMetadata() const;
    void saveMetadata(const QVariantList& list);
    QString generateId() const;
};

#endif // STICKERMANAGER_H
