#include "Logger.h"
#include "AppPaths.h"
#include <QDateTime>
#include <QDir>
#include <QRegularExpression>
#include <QStringConverter>
#include <iostream>

Logger& Logger::instance() {
    static Logger instance;
    return instance;
}

Logger::Logger()
    : m_qmlLogFile(nullptr)
    , m_qmlLogStream(nullptr)
    , m_appLogFile(nullptr)
    , m_appLogStream(nullptr)
{
}

Logger::~Logger() {
    QMutexLocker locker(&m_mutex);
    if (m_qmlLogStream) { delete m_qmlLogStream; m_qmlLogStream = nullptr; }
    if (m_qmlLogFile)   { m_qmlLogFile->close(); delete m_qmlLogFile; m_qmlLogFile = nullptr; }
    if (m_appLogStream) { delete m_appLogStream; m_appLogStream = nullptr; }
    if (m_appLogFile)   { m_appLogFile->close(); delete m_appLogFile; m_appLogFile = nullptr; }
}

void Logger::initialize() {
    QMutexLocker locker(&m_mutex);

    // logs/ folder next to exe
    QString logsDir = AppPaths::instance().getLogsDirectory();
    QDir().mkpath(logsDir);

    openLogFile();
}

void Logger::openLogFile() {
    // --- qml.log (truncate fresh on each launch) ---
    if (m_qmlLogStream) { delete m_qmlLogStream; m_qmlLogStream = nullptr; }
    if (m_qmlLogFile)   { m_qmlLogFile->close(); delete m_qmlLogFile; m_qmlLogFile = nullptr; }

    QString qmlLogPath = QDir(AppPaths::instance().getLogsDirectory()).filePath("qml.log");
    m_qmlLogFile = new QFile(qmlLogPath);
    if (m_qmlLogFile->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        m_qmlLogStream = new QTextStream(m_qmlLogFile);
        m_qmlLogStream->setEncoding(QStringConverter::Utf8);
        *m_qmlLogStream << "=== QML Log - " << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << " ===\n";
        m_qmlLogStream->flush();
        std::cout << "QML log: " << qmlLogPath.toStdString() << std::endl;
    } else {
        std::cerr << "Logger: Cannot open " << qmlLogPath.toStdString() << std::endl;
        delete m_qmlLogFile;
        m_qmlLogFile = nullptr;
    }

    // --- app.log (C++ backend, append so history preserved across auth restarts) ---
    if (m_appLogStream) { delete m_appLogStream; m_appLogStream = nullptr; }
    if (m_appLogFile)   { m_appLogFile->close(); delete m_appLogFile; m_appLogFile = nullptr; }

    QString appLogPath = QDir(AppPaths::instance().getLogsDirectory()).filePath("app.log");
    m_appLogFile = new QFile(appLogPath);
    if (m_appLogFile->open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        m_appLogStream = new QTextStream(m_appLogFile);
        m_appLogStream->setEncoding(QStringConverter::Utf8);
        *m_appLogStream << "=== App Backend Log - " << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss") << " ===\n";
        m_appLogStream->flush();
        std::cout << "App log: " << appLogPath.toStdString() << std::endl;
    } else {
        std::cerr << "Logger: Cannot open " << appLogPath.toStdString() << std::endl;
        delete m_appLogFile;
        m_appLogFile = nullptr;
    }
}

// Not used but required by header
QString Logger::currentLogFileName() { return "qml.log"; }
void Logger::cleanup() {}

void Logger::log(QtMsgType type, const QString& message, bool toApp) {
    QMutexLocker locker(&m_mutex);

    QString safeMessage = redactSensitiveData(message);
    QString timestamp   = QDateTime::currentDateTime().toString("HH:mm:ss.zzz");

    QString typeStr;
    switch (type) {
        case QtDebugMsg:    typeStr = "DEBUG"; break;
        case QtInfoMsg:     typeStr = "INFO "; break;
        case QtWarningMsg:  typeStr = "WARN "; break;
        case QtCriticalMsg: typeStr = "ERROR"; break;
        case QtFatalMsg:    typeStr = "FATAL"; break;
    }

    QString line = timestamp + " [" + typeStr + "] " + safeMessage + "\n";

    if (toApp) {
        if (m_appLogStream) {
            *m_appLogStream << line;
            m_appLogStream->flush();
        }
        // Also print to stderr so it shows in console
        std::cerr << line.toStdString();
    } else {
        if (m_qmlLogStream) {
            *m_qmlLogStream << line;
            m_qmlLogStream->flush();
        }
    }
}

QString Logger::redactSensitiveData(const QString& message) {
    QString result = message;

    static QRegularExpression awsKey(R"(AKIA[A-Z0-9]{16})");
    result.replace(awsKey, "AKIA[REDACTED]");

    static QRegularExpression secretKey(R"("secret_access_key"\s*:\s*"[A-Za-z0-9+/]{40}")");
    result.replace(secretKey, R"("secret_access_key": "[REDACTED]")");

    static QRegularExpression password(
        R"((password[^:]*:\s*)[^\s,}]+)",
        QRegularExpression::CaseInsensitiveOption);
    result.replace(password, R"(\1[REDACTED])");

    return result;
}

void Logger::messageHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg) {
    if (type == QtFatalMsg) {
        std::cerr << "FATAL: " << msg.toStdString() << std::endl;
        Logger::instance().log(type, msg, true);
        abort();
    }

    QString file = context.file ? QString::fromUtf8(context.file) : QString();
    bool isQml = file.endsWith(".qml", Qt::CaseInsensitive)
              || file.contains("/qml/", Qt::CaseInsensitive)
              || file.contains("\\qml\\", Qt::CaseInsensitive);

    if (isQml) {
        // QML messages → qml.log
        Logger::instance().log(type, msg, false);
    } else {
        // C++ backend messages → app.log   (all levels)
        Logger::instance().log(type, msg, true);
    }
}
