#ifndef LOGGER_H
#define LOGGER_H

#include <QString>
#include <QFile>
#include <QMutex>
#include <QTextStream>

/**
 * @brief Centralized logging system with file rotation and sensitive data redaction
 *
 * Features:
 * - Dual output: Console + file
 * - Auto-rotation: Keep last 7 days of logs
 * - Sensitive data redaction (AWS keys, credentials)
 * - Thread-safe file writes
 * - Qt message handler integration
 */
class Logger {
public:
    /**
     * @brief Get the singleton instance
     * @return Reference to the singleton Logger instance
     */
    static Logger& instance();

    /**
     * @brief Initialize the logging system
     *
     * Call this once at application startup before any logging occurs
     */
    void initialize();

    /**
     * @brief Clean up old log files (older than 7 days)
     */
    void cleanup();

    /**
     * @brief Qt message handler callback
     *
     * Install with: qInstallMessageHandler(Logger::messageHandler);
     */
    static void messageHandler(QtMsgType type, const QMessageLogContext& context, const QString& msg);

private:
    Logger();
    ~Logger();

    // Prevent copying
    Logger(const Logger&) = delete;
    Logger& operator=(const Logger&) = delete;

    /**
     * @brief Write a log message to file and console
     * @param type Message type (Debug, Warning, Critical, etc.)
     * @param message The log message
     */
    void log(QtMsgType type, const QString& message, bool toApp = false);

    /**
     * @brief Redact sensitive data from log messages
     * @param message The original message
     * @return Message with sensitive data replaced by [REDACTED]
     */
    QString redactSensitiveData(const QString& message);

    /**
     * @brief Get the current log file name
     * @return Log file name in format: app_YYYYMMDD.log
     */
    QString currentLogFileName();

    /**
     * @brief Open or rotate the log file
     */
    void openLogFile();

    QFile* m_qmlLogFile;
    QTextStream* m_qmlLogStream;
    QFile* m_appLogFile;          // C++ backend log
    QTextStream* m_appLogStream;
    QMutex m_mutex;
    QString m_currentLogDate;  // Track current log date for rotation
};

#endif // LOGGER_H
