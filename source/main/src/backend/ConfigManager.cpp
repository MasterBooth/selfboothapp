#include "ConfigManager.h"

#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QCoreApplication>
#include <QStandardPaths>
#include <QDebug>
#include <QStringList>

// Initialize static instance
ConfigManager *ConfigManager::s_instance = nullptr;

namespace {
constexpr const char *kDefaultBucketName = "selfboothvn";
constexpr const char *kDefaultR2Account = "auto";
constexpr const char *kDefaultPublicBaseUrl = "https://boothme.tech/media";
constexpr const char *kDefaultCloudApiBaseUrl = "https://boothme.tech";
}

ConfigManager::ConfigManager(QObject *parent)
    : QObject(parent)
    , m_autoRetry(true)
    , m_maxRetries(3)
    , m_isValid(false)
{
}

ConfigManager* ConfigManager::instance()
{
    if (!s_instance) {
        s_instance = new ConfigManager();
    }
    return s_instance;
}

bool ConfigManager::loadConfig(const QString &configPath)
{
    QString fullPath = configPath;

    // Only prepend appDir for relative paths — never modify absolute paths
    if (!QFileInfo(fullPath).isAbsolute()) {
        fullPath = QCoreApplication::applicationDirPath() + "/" + configPath;
    }

    qDebug() << "Loading configuration from:" << fullPath;

    m_s3BucketName = QString::fromLatin1(kDefaultBucketName);
    m_s3Region = QString::fromLatin1(kDefaultR2Account);
    m_s3PublicBaseUrl = QString::fromLatin1(kDefaultPublicBaseUrl);
    m_cloudApiBaseUrl = QString::fromLatin1(kDefaultCloudApiBaseUrl);
    m_webGalleryBaseUrl.clear();
    m_deviceName = QStringLiteral("Boothme");

    QFile file(fullPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        m_lastError.clear();
        m_isValid = true;
        qWarning() << "Public config file not found; using built-in defaults:" << fullPath;
        return true;
    }

    QByteArray fileData = file.readAll();
    file.close();

    QJsonParseError parseError;
    QJsonDocument doc = QJsonDocument::fromJson(fileData, &parseError);

    if (doc.isNull()) {
        m_lastError = QString("JSON parse error: %1").arg(parseError.errorString());
        qCritical() << m_lastError;
        m_isValid = false;
        return false;
    }

    QJsonObject rootObj = doc.object();

    // Prefer R2 settings for LaMoment, but keep s3_settings as a compatibility
    // fallback because the desktop only passes object keys to the Worker.
    const bool hasR2Settings = rootObj.contains("r2_settings");
    const QString storageSection = hasR2Settings ? QStringLiteral("r2_settings")
                                                 : QStringLiteral("s3_settings");
    if (rootObj.contains(storageSection)) {
        if (!parseS3Settings(rootObj[storageSection].toObject(), storageSection, !hasR2Settings)) {
            m_isValid = false;
            return false;
        }
    }

    // Parse Cloudflare Worker API settings. The desktop config may override
    // public URLs. Machine tokens are issued by the API after studio login.
    if (rootObj.contains("cloud_api")) {
        if (!parseCloudApiSettings(rootObj["cloud_api"].toObject())) {
            m_isValid = false;
            return false;
        }
    }

    // Parse web settings (optional): gallery link embedded in QR codes.
    m_webGalleryBaseUrl.clear();
    if (rootObj.contains("web")) {
        m_webGalleryBaseUrl = rootObj["web"].toObject()["gallery_base_url"].toString().trimmed();
        while (m_webGalleryBaseUrl.endsWith('/'))
            m_webGalleryBaseUrl.chop(1);
    }

    // Parse machine settings (optional)
    if (rootObj.contains("machine_settings")) {
        parseMachineSettings(rootObj["machine_settings"].toObject());
    }

    m_isValid = true;
    qDebug() << "Configuration loaded successfully";
    qDebug() << "Object storage section:" << storageSection;
    qDebug() << "Object storage bucket:" << m_s3BucketName;
    qDebug() << "Object storage region/account:" << m_s3Region;
    qDebug() << "Object storage public URL:" << m_s3PublicBaseUrl;
    qDebug() << "Cloud API:" << m_cloudApiBaseUrl;
    qDebug() << "Web gallery base:" << (m_webGalleryBaseUrl.isEmpty()
                                        ? QStringLiteral("(default)") : m_webGalleryBaseUrl);
    qDebug() << "Device Name:" << m_deviceName;

    return true;
}

bool ConfigManager::parseS3Settings(const QJsonObject &s3Config,
                                    const QString &sectionName,
                                    bool requireRegion)
{
    // Required fields
    QStringList requiredFields = { QStringLiteral("bucket_name"),
                                   QStringLiteral("public_base_url") };
    if (requireRegion)
        requiredFields << QStringLiteral("region");

    for (const QString &field : requiredFields) {
        if (!s3Config.contains(field)) {
            m_lastError = QString("Missing %1 in %2").arg(field, sectionName);
            qCritical() << m_lastError;
            return false;
        }
    }

    m_s3BucketName    = s3Config["bucket_name"].toString();
    m_s3Region        = requireRegion ? s3Config["region"].toString()
                                      : s3Config["account_id"].toString("auto");
    if (!requireRegion && m_s3Region.trimmed().isEmpty())
        m_s3Region = QStringLiteral("auto");
    m_s3PublicBaseUrl = s3Config["public_base_url"].toString();
    while (m_s3PublicBaseUrl.endsWith('/'))
        m_s3PublicBaseUrl.chop(1);

    if (m_s3BucketName.isEmpty() || m_s3Region.isEmpty() || m_s3PublicBaseUrl.isEmpty()) {
        m_lastError = QString("%1 contains empty values").arg(sectionName);
        qCritical() << m_lastError;
        return false;
    }

    return true;
}

bool ConfigManager::parseCloudApiSettings(const QJsonObject &apiConfig)
{
    if (!apiConfig.contains("base_url")) {
        m_lastError = "Missing base_url in cloud_api";
        qCritical() << m_lastError;
        return false;
    }

    m_cloudApiBaseUrl = apiConfig["base_url"].toString();
    while (m_cloudApiBaseUrl.endsWith('/'))
        m_cloudApiBaseUrl.chop(1);
    if (m_cloudApiBaseUrl.isEmpty()) {
        m_lastError = "cloud_api base_url is empty";
        qCritical() << m_lastError;
        return false;
    }

    return true;
}

bool ConfigManager::parseMachineSettings(const QJsonObject &machineConfig)
{
    if (machineConfig.contains("device_name")) {
        m_deviceName = machineConfig["device_name"].toString();
    }

    if (machineConfig.contains("auto_retry")) {
        m_autoRetry = machineConfig["auto_retry"].toBool();
    }

    if (machineConfig.contains("max_retries")) {
        m_maxRetries = machineConfig["max_retries"].toInt();
        if (m_maxRetries < 1) {
            m_maxRetries = 3;
        }
    }

    return true;
}
