#ifndef CONFIGMANAGER_H
#define CONFIGMANAGER_H

#include <QString>
#include <QJsonObject>
#include <QObject>

/**
 * @class ConfigManager
 * @brief Centralized configuration management for Cloudflare services
 *
 * Singleton pattern - loads public configuration and provides access
 * to object storage + Worker REST API settings for other backend
 * services. Secrets are never loaded from the desktop config file.
 */
class ConfigManager : public QObject
{
    Q_OBJECT

public:
    /**
     * @brief Get singleton instance
     */
    static ConfigManager* instance();

    /**
     * @brief Load public configuration from config file
     * @param configPath Path to config.json (default: "config.json" in app directory)
     * @return true if loaded successfully, false otherwise
     */
    bool loadConfig(const QString &configPath = "config.json");

    // ========== Object Storage Settings ==========
    QString s3BucketName() const { return m_s3BucketName; }
    QString s3Region() const { return m_s3Region; }
    QString s3PublicBaseUrl() const { return m_s3PublicBaseUrl; }

    // Backward-compatible aliases while callers are migrated.
    QString r2BucketName() const { return m_s3BucketName; }
    QString r2AccountId() const { return m_s3Region; }
    QString r2PublicBaseUrl() const { return m_s3PublicBaseUrl; }

    // ========== Cloudflare Worker REST API ==========
    QString cloudApiBaseUrl() const { return m_cloudApiBaseUrl; }
    // Token gửi kèm request tới API: token riêng của máy (cấp khi studio đăng nhập).
    QString cloudApiToken() const { return m_machineToken; }
    void setMachineToken(const QString &token) { m_machineToken = token; }
    bool hasMachineToken() const { return !m_machineToken.isEmpty(); }

    // ========== Web (tùy chọn) ==========
    // Gốc link gallery in trong QR. Rỗng = dùng mặc định của S3Uploader.
    QString webGalleryBaseUrl() const { return m_webGalleryBaseUrl; }

    // ========== Machine Settings ==========
    QString deviceName() const { return m_deviceName; }
    bool autoRetry() const { return m_autoRetry; }
    int maxRetries() const { return m_maxRetries; }

    /**
     * @brief Check if configuration is valid
     */
    bool isValid() const { return m_isValid; }

    /**
     * @brief Get last error message
     */
    QString lastError() const { return m_lastError; }

private:
    ConfigManager(QObject *parent = nullptr);
    ~ConfigManager() = default;

    // Prevent copy and move
    ConfigManager(const ConfigManager&) = delete;
    ConfigManager& operator=(const ConfigManager&) = delete;

    static ConfigManager *s_instance;

    // Object storage configuration. Names stay s3* for API compatibility.
    QString m_s3BucketName;
    QString m_s3Region;
    QString m_s3PublicBaseUrl;

    // Cloudflare Worker REST API configuration
    QString m_cloudApiBaseUrl;
    QString m_machineToken;   // StudioAccount đặt sau khi đăng nhập (lưu bằng SecureStore)

    // Web configuration (tùy chọn)
    QString m_webGalleryBaseUrl;

    // Machine settings
    QString m_deviceName;
    bool m_autoRetry;
    int m_maxRetries;

    // Status
    bool m_isValid;
    QString m_lastError;

    /**
     * @brief Parse object storage settings from JSON config
     */
    bool parseS3Settings(const QJsonObject &s3Config,
                         const QString &sectionName,
                         bool requireRegion);

    /**
     * @brief Parse Cloudflare Worker API settings from JSON config
     */
    bool parseCloudApiSettings(const QJsonObject &apiConfig);

    /**
     * @brief Parse machine settings from JSON config
     */
    bool parseMachineSettings(const QJsonObject &machineConfig);
};

#endif // CONFIGMANAGER_H
