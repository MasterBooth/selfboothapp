#include "DisplayManager.h"

#include <QDebug>
#include <QGuiApplication>
#include <QRect>
#include <QScreen>

DisplayManager::DisplayManager(QObject *parent)
    : QObject(parent) {
    auto *app = qGuiApp;
    if (!app) return;
    connect(app, &QGuiApplication::screenAdded,
            this, [this](QScreen *) { emit screenCountChanged(); });
    connect(app, &QGuiApplication::screenRemoved,
            this, [this](QScreen *) { emit screenCountChanged(); });
    connect(app, &QGuiApplication::primaryScreenChanged,
            this, [this](QScreen *) { emit screenCountChanged(); });
}

int DisplayManager::screenCount() const {
    return QGuiApplication::screens().size();
}

int DisplayManager::primaryScreenIndex() const {
    const auto screens = QGuiApplication::screens();
    QScreen *primary = QGuiApplication::primaryScreen();
    if (!primary) return screens.isEmpty() ? -1 : 0;
    const int idx = screens.indexOf(primary);
    return idx >= 0 ? idx : 0;
}

QObject *DisplayManager::screenAt(int index) const {
    const auto screens = QGuiApplication::screens();
    if (index >= 0 && index < screens.size()) return screens.at(index);
    qWarning() << "DisplayManager: invalid screen index" << index
               << "screenCount =" << screens.size();
    return nullptr;
}

QVariantList DisplayManager::screensInfo() const {
    QVariantList result;
    const auto screens = QGuiApplication::screens();
    const int primaryIdx = primaryScreenIndex();
    for (int i = 0; i < screens.size(); ++i) {
        QScreen *screen = screens.at(i);
        const QRect g = screen->geometry();
        QVariantMap item;
        item.insert(QStringLiteral("index"), i);
        item.insert(QStringLiteral("name"), screen->name());
        item.insert(QStringLiteral("primary"), i == primaryIdx);
        item.insert(QStringLiteral("x"), g.x());
        item.insert(QStringLiteral("y"), g.y());
        item.insert(QStringLiteral("width"), g.width());
        item.insert(QStringLiteral("height"), g.height());
        item.insert(QStringLiteral("label"),
                    QStringLiteral("%1%2 - %3x%4 @ %5,%6")
                        .arg(screen->name().isEmpty()
                                 ? QStringLiteral("Screen %1").arg(i)
                                 : screen->name())
                        .arg(i == primaryIdx ? QStringLiteral(" (primary)") : QString())
                        .arg(g.width())
                        .arg(g.height())
                        .arg(g.x())
                        .arg(g.y()));
        result.append(item);
    }
    return result;
}

bool DisplayManager::isValidScreenIndex(int index) const {
    return index >= 0 && index < screenCount();
}

bool DisplayManager::isPrimaryScreenIndex(int index) const {
    return index >= 0 && index == primaryScreenIndex();
}

QVariantMap DisplayManager::screenGeometry(int index) const {
    QVariantMap result;
    const auto screens = QGuiApplication::screens();
    if (index < 0 || index >= screens.size())
        return result;

    QScreen *screen = screens.at(index);
    const QRect g = screen->geometry();
    result.insert(QStringLiteral("index"), index);
    result.insert(QStringLiteral("name"), screen->name());
    result.insert(QStringLiteral("primary"), index == primaryScreenIndex());
    result.insert(QStringLiteral("x"), g.x());
    result.insert(QStringLiteral("y"), g.y());
    result.insert(QStringLiteral("width"), g.width());
    result.insert(QStringLiteral("height"), g.height());
    return result;
}

int DisplayManager::defaultExternalLiveViewScreenIndex() const {
    const int count = screenCount();
    if (count < 2) return -1;

    const int primaryIdx = primaryScreenIndex();
    for (int i = 0; i < count; ++i) {
        if (i != primaryIdx) return i;
    }
    return -1;
}

int DisplayManager::defaultPhotoWallScreenIndex() const {
    const int count = screenCount();
    if (count < 3) return 0;

    const int primaryIdx = primaryScreenIndex();
    const int liveViewIdx = defaultExternalLiveViewScreenIndex();
    for (int i = 0; i < count; ++i) {
        if (i != primaryIdx && i != liveViewIdx) return i;
    }
    return 0;
}
