#include "StickerManager.h"
#include "AppPaths.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QUuid>
#include <QDebug>

StickerManager::StickerManager(QObject* parent) : QObject(parent) {
    QDir().mkpath(stickersDir());
}

QString StickerManager::stickersDir() const {
    return QDir(AppPaths::instance().getAppDirectory()).filePath("stickers");
}

QString StickerManager::metadataPath() const {
    return QDir(stickersDir()).filePath("metadata.json");
}

QString StickerManager::generateId() const {
    return QUuid::createUuid().toString(QUuid::WithoutBraces).left(8);
}

QVariantList StickerManager::loadMetadata() const {
    QFile f(metadataPath());
    if (!f.open(QIODevice::ReadOnly)) return {};
    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    QVariantList result;
    for (const auto& v : doc.array())
        result << v.toObject().toVariantMap();
    return result;
}

void StickerManager::saveMetadata(const QVariantList& list) {
    QJsonArray arr;
    for (const auto& v : list)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    QFile f(metadataPath());
    if (f.open(QIODevice::WriteOnly))
        f.write(QJsonDocument(arr).toJson());
}

QVariantList StickerManager::getStickers() {
    return loadMetadata();
}

bool StickerManager::importStickers(const QStringList& paths) {
    auto meta = loadMetadata();
    bool any = false;
    for (const QString& src : paths) {
        QFileInfo fi(src);
        if (!fi.exists()) continue;
        QString id  = generateId();
        QString dir = QDir(stickersDir()).filePath(id);
        QDir().mkpath(dir);
        QString suffix = fi.suffix().isEmpty() ? QStringLiteral("png") : fi.suffix();
        QString dest = QDir(dir).filePath("sticker." + suffix);
        if (!QFile::copy(src, dest)) {
            qWarning() << "[StickerManager] Failed to copy" << src;
            continue;
        }
        QVariantMap entry;
        entry["id"]   = id;
        entry["name"] = fi.baseName();
        entry["path"] = dest;
        meta << entry;
        any = true;
    }
    if (any) { saveMetadata(meta); emit stickersChanged(); }
    return any;
}

bool StickerManager::renameSticker(const QString& stickerId, const QString& newName) {
    auto meta = loadMetadata();
    for (auto& v : meta) {
        auto m = v.toMap();
        if (m["id"].toString() == stickerId) {
            m["name"] = newName;
            v = m;
            saveMetadata(meta);
            emit stickersChanged();
            return true;
        }
    }
    return false;
}

bool StickerManager::deleteSticker(const QString& stickerId) {
    auto meta = loadMetadata();
    for (int i = 0; i < meta.size(); i++) {
        auto m = meta[i].toMap();
        if (m["id"].toString() == stickerId) {
            QDir(QDir(stickersDir()).filePath(stickerId)).removeRecursively();
            meta.removeAt(i);
            saveMetadata(meta);
            emit stickersChanged();
            return true;
        }
    }
    return false;
}
