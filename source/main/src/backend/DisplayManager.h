#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>

class DisplayManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(int screenCount READ screenCount NOTIFY screenCountChanged)
    Q_PROPERTY(int primaryScreenIndex READ primaryScreenIndex NOTIFY screenCountChanged)

public:
    explicit DisplayManager(QObject *parent = nullptr);

    int screenCount() const;
    int primaryScreenIndex() const;
    Q_INVOKABLE QObject *screenAt(int index) const;
    Q_INVOKABLE QVariantList screensInfo() const;
    Q_INVOKABLE bool isValidScreenIndex(int index) const;
    Q_INVOKABLE bool isPrimaryScreenIndex(int index) const;
    Q_INVOKABLE QVariantMap screenGeometry(int index) const;
    Q_INVOKABLE int defaultExternalLiveViewScreenIndex() const;
    Q_INVOKABLE int defaultPhotoWallScreenIndex() const;

signals:
    void screenCountChanged();
};
