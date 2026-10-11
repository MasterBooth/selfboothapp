#include "AppPaths.h"
#include <QDebug>
#include <QFileInfo>
#include <QRegularExpression>

AppPaths& AppPaths::instance() {
    static AppPaths instance;
    return instance;
}

AppPaths::AppPaths() {
    initializePaths();
}

void AppPaths::initializePaths() {
    // Get application directory (where the exe is)
    m_appDir = QCoreApplication::applicationDirPath();

    // Portable mode: Database in {app_dir}/data/
    QString dataDir = QDir(m_appDir).filePath("data");
    m_databasePath = QDir(dataDir).filePath("photobooth.db");

    // Optional public config file in app directory. Secrets are stored elsewhere.
    m_configPath = QDir(m_appDir).filePath("config.json");

    // Events in user-accessible Pictures folder
    QString picturesPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    m_eventsBaseDir = QDir(picturesPath).filePath("Photobooth/Events");

    // Logs next to exe (portable mode, easy to find)
    m_logsDir = QDir(m_appDir).filePath("logs");

    qDebug() << "AppPaths initialized:";
    qDebug() << "  App Directory:" << m_appDir;
    qDebug() << "  Database:" << m_databasePath;
    qDebug() << "  Config:" << m_configPath;
    qDebug() << "  Events Base:" << m_eventsBaseDir;
    qDebug() << "  Logs:" << m_logsDir;

    // Ensure critical directories exist
    QString error;
    if (!ensureDirectoryExists(QFileInfo(m_databasePath).absolutePath(), &error)) {
        qCritical() << "Failed to create data directory:" << error;
    }
    if (!ensureDirectoryExists(m_eventsBaseDir, &error)) {
        qWarning() << "Failed to create events base directory:" << error;
    }
    if (!ensureDirectoryExists(m_logsDir, &error)) {
        qWarning() << "Failed to create logs directory:" << error;
    }
}

// === Core Application Paths ===

QString AppPaths::getAppDirectory() const {
    return m_appDir;
}

QString AppPaths::getDatabasePath() const {
    return m_databasePath;
}

QString AppPaths::getConfigPath() const {
    return m_configPath;
}

QString AppPaths::getLogsDirectory() const {
    return m_logsDir;
}

// === Event Paths ===

QString AppPaths::getEventsBaseDirectory() const {
    return m_eventsBaseDir;
}

QString AppPaths::getEventDirectory(const QString& eventName) const {
    QString safeName = sanitizeEventName(eventName);
    return QDir(m_eventsBaseDir).filePath(safeName);
}

QString AppPaths::getEventOriginalsPath(const QString& eventName) const {
    return QDir(getEventDirectory(eventName)).filePath("Originals");
}

QString AppPaths::getEventFinalPath(const QString& eventName) const {
    return QDir(getEventDirectory(eventName)).filePath("Final");
}

QString AppPaths::getEventLayoutsPath(const QString& eventName) const {
    return QDir(getEventDirectory(eventName)).filePath("Layouts");
}

QString AppPaths::getEventBackgroundsPath(const QString& eventName) const {
    return QDir(getEventDirectory(eventName)).filePath("Backgrounds");
}

QString AppPaths::getEventPrintoutPath(const QString& eventName) const {
    return QDir(getEventDirectory(eventName)).filePath("printout");
}

// === Temporary/Output Paths ===

QString AppPaths::getTempDirectory() const {
    return QStandardPaths::writableLocation(QStandardPaths::TempLocation);
}

QString AppPaths::getSessionRecordingPath(const QString& sessionId) const {
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QString safeId = sessionId;
    safeId.remove(QRegularExpression("[<>:\"/\\\\|?*]"));
    return QDir::fromNativeSeparators(QDir(base).filePath("session_recordings/" + safeId));
}

// === Utility Functions ===

bool AppPaths::ensureDirectoryExists(const QString& path, QString* error) const {
    QDir dir(path);
    if (dir.exists()) {
        return true;  // Already exists
    }

    // Try to create the directory
    if (QDir().mkpath(path)) {
        qDebug() << "Created directory:" << path;
        return true;
    }

    // Failed to create
    QString errorMsg = QString("Failed to create directory: %1").arg(path);
    qWarning() << errorMsg;

    if (error) {
        *error = errorMsg;
    }

    return false;
}

QString AppPaths::sanitizeEventName(const QString& name) const {
    QString safeName = name;

    // Replace spaces with underscores
    safeName.replace(" ", "_");

    // Remove invalid file system characters
    // Windows invalid chars: < > : " / \ | ? *
    safeName.remove(QRegularExpression("[<>:\"/\\\\|?*]"));

    // Remove leading/trailing dots and spaces (Windows limitation)
    safeName = safeName.trimmed();
    while (safeName.startsWith('.')) {
        safeName.remove(0, 1);
    }
    while (safeName.endsWith('.')) {
        safeName.chop(1);
    }

    // Ensure not empty
    if (safeName.isEmpty()) {
        safeName = "Unnamed_Event";
    }

    return safeName;
}
