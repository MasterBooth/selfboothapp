#ifndef APPPATHS_H
#define APPPATHS_H

#include <QString>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDir>

/**
 * @brief Centralized path management for the Photobooth Dashboard application
 *
 * This class provides a single source of truth for all file system paths used
 * throughout the application, supporting portable deployment mode.
 *
 * Path Strategy:
 * - Portable Mode: Database and config in app directory for easy backup
 * - Events: User-accessible location (Pictures/Photobooth)
 * - Logs: AppData for proper OS integration
 */
class AppPaths {
public:
    /**
     * @brief Get the singleton instance
     * @return Reference to the singleton AppPaths instance
     */
    static AppPaths& instance();

    // === Core Application Paths ===

    /**
     * @brief Get the application directory (where the exe is located)
     * @return Absolute path to application directory
     */
    QString getAppDirectory() const;

    /**
     * @brief Get the database file path
     * @return Absolute path to photobooth.db in {app_dir}/data/
     */
    QString getDatabasePath() const;

    /**
     * @brief Get the AWS configuration file path
     * @return Absolute path to aws.json in app directory
     */
    QString getConfigPath() const;

    /**
     * @brief Get the logs directory path
     * @return Absolute path to logs directory in AppData
     */
    QString getLogsDirectory() const;

    // === Event Paths ===

    /**
     * @brief Get the base directory for all events
     * @return Absolute path to Pictures/Photobooth/Events/
     */
    QString getEventsBaseDirectory() const;

    /**
     * @brief Get the root directory for a specific event
     * @param eventName The name of the event (will be sanitized)
     * @return Absolute path to event root directory
     */
    QString getEventDirectory(const QString& eventName) const;

    /**
     * @brief Get the Originals subdirectory for an event
     * @param eventName The name of the event
     * @return Absolute path to {event}/Originals/
     */
    QString getEventOriginalsPath(const QString& eventName) const;

    /**
     * @brief Get the Final subdirectory for an event
     * @param eventName The name of the event
     * @return Absolute path to {event}/Final/
     */
    QString getEventFinalPath(const QString& eventName) const;

    /**
     * @brief Get the Layouts subdirectory for an event
     * @param eventName The name of the event
     * @return Absolute path to {event}/Layouts/
     */
    QString getEventLayoutsPath(const QString& eventName) const;

    /**
     * @brief Get the Backgrounds subdirectory for an event
     * @param eventName The name of the event
     * @return Absolute path to {event}/Backgrounds/
     */
    QString getEventBackgroundsPath(const QString& eventName) const;

    /**
     * @brief Get the printout subdirectory for an event
     * @param eventName The name of the event
     * @return Absolute path to {event}/printout/
     */
    QString getEventPrintoutPath(const QString& eventName) const;

    // === Temporary/Output Paths ===

    /**
     * @brief Get the system temporary directory
     * @return Absolute path to system temp directory
     */
    QString getTempDirectory() const;

    /**
     * @brief Get the temp dir chứa frame live-view đã ghi của 1 session (process video).
     *
     * Đặt trong AppLocalData (user-writable, không bị AV scan real-time) — giống
     * tmp_video của VideoCreator. Mỗi slot ghi vào subdir slot_<i>/. Đây là single
     * source of truth: CaptureScreen (ghi) và EventManager (compose) đều dùng hàm này.
     *
     * @param sessionId ID session (vd "session_20240101_120000_AB12")
     * @return Absolute path {AppLocalData}/session_recordings/<sessionId>
     */
    QString getSessionRecordingPath(const QString& sessionId) const;

    // === Utility Functions ===

    /**
     * @brief Ensure a directory exists, creating it if necessary
     * @param path The directory path to check/create
     * @param error Optional pointer to QString for error message
     * @return true if directory exists or was created successfully, false otherwise
     */
    bool ensureDirectoryExists(const QString& path, QString* error = nullptr) const;

    /**
     * @brief Sanitize event name for use in file paths
     *
     * Replaces spaces with underscores and removes invalid characters
     *
     * @param name The raw event name
     * @return Sanitized name safe for file system use
     */
    QString sanitizeEventName(const QString& name) const;

private:
    AppPaths();
    ~AppPaths() = default;

    // Prevent copying
    AppPaths(const AppPaths&) = delete;
    AppPaths& operator=(const AppPaths&) = delete;

    void initializePaths();

    // Cached paths
    QString m_appDir;
    QString m_eventsBaseDir;
    QString m_logsDir;
    QString m_databasePath;
    QString m_configPath;
};

#endif // APPPATHS_H
