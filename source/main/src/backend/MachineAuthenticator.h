#ifndef MACHINEAUTHENTICATOR_H
#define MACHINEAUTHENTICATOR_H

#include <QString>
#include <QObject>
#include <QDateTime>
#include <QTimer>
#include <QVariantMap>

class DatabaseManager;
class DynamoDBClient;
class LicenseManager;

/**
 * @class MachineAuthenticator
 * @brief Generates and validates machine HWID (Hardware ID)
 *
 * Generates HWID from CPU ID, MAC address, volume serial number
 * and validates it against DynamoDB table "photoboothhwid"
 */
class MachineAuthenticator : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString hwid READ hwid NOTIFY hwidChanged)
    Q_PROPERTY(int status READ status NOTIFY statusChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY statusChanged)
    Q_PROPERTY(QString licenseEnd READ licenseEnd NOTIFY licenseEndChanged)
    Q_PROPERTY(int studioId READ studioId NOTIFY studioIdChanged)
    Q_PROPERTY(QString plan READ plan NOTIFY planChanged)
    Q_PROPERTY(QString deviceTier READ deviceTier NOTIFY planChanged)
    Q_PROPERTY(QVariantMap capabilities READ capabilities NOTIFY planChanged)

public:
    enum AuthStatus {
        NotChecked = 0,
        Checking = 1,
        Authenticated = 2,
        Pending = 3,        // Machine not yet approved by admin
        Failed = 4,
        NetworkError = 5
    };
    Q_ENUM(AuthStatus)

    explicit MachineAuthenticator(DatabaseManager *db, QObject *parent = nullptr);
    ~MachineAuthenticator();

    /**
     * Gắn LicenseManager — nguồn quyền dựa trên chữ ký số, không phụ thuộc máy chủ.
     *
     * Bản PTB (kEnforceLicense = true): giấy phép là nguồn quyền duy nhất; mọi
     * thay đổi giấy phép (nhập OTP, gia hạn, thu hồi, hết hạn) áp ngay lập tức.
     * Bản khác: chỉ ĐỐI CHIẾU và ghi log, quyền thực tế vẫn do bypass cấp.
     */
    void setLicenseManager(LicenseManager *license);

    QString hwid() const { return m_hwid; }
    int status() const { return m_status; }
    QString statusMessage() const { return m_statusMessage; }
    // License expiry for display. Returns "dd/MM/yyyy" when a date is known,
    // or an empty string when there is no expiry (treated as unlimited in UI).
    QString licenseEnd() const {
        return m_licenseEndDate.isValid() ? m_licenseEndDate.toString("dd/MM/yyyy") : QString();
    }
    // Studio id của chủ máy (suy ra từ owner_email ở worker). 0 = chưa biết.
    int studioId() const { return m_studioId; }

    // Gói/hạng/khả năng hiện tại của máy (đọc từ Worker khi xác thực).
    QString plan() const { return m_plan; }
    QString deviceTier() const { return m_deviceTier; }
    QVariantMap capabilities() const { return m_caps; }
    // Key thiếu phải fail-closed; Worker luôn trả đủ ma trận capability.
    Q_INVOKABLE bool hasCapability(const QString &key) const {
        return m_caps.value(key, false).toBool();
    }
    Q_INVOKABLE bool canUseOperationMode(const QString &mode) const {
        if (mode == QStringLiteral("mode1")) return hasCapability(QStringLiteral("event"));
        if (mode == QStringLiteral("mode2") || mode == QStringLiteral("mode3"))
            return hasCapability(QStringLiteral("studio"));
        return false;
    }

    Q_INVOKABLE void authenticate();
    Q_INVOKABLE void retryAuthentication();

signals:
    void hwidChanged();
    void statusChanged();
    void licenseEndChanged();
    void studioIdChanged();
    void planChanged();
    void authenticationCompleted(bool success);

private slots:
    void onMachineFound(const QString &hwid, const QVariantMap &data);
    void onMachineNotFound(const QString &hwid);
    void onMachineRegistered(const QString &hwid);
    void onOperationError(const QString &error);

private:
    // Cưỡng chế: dựng quyền từ trạng thái giấy phép hiện tại (không đọc lại đĩa).
    void applyLicenseState();

    DatabaseManager *m_db;
    DynamoDBClient *m_dynamoClient;
    LicenseManager    *m_license    = nullptr;
    QString m_hwid;
    int m_status;
    QString m_statusMessage;
    QDateTime m_lastAuthAttempt;
    int m_retryCount;
    QTimer *m_pollingTimer;  // Timer to check activation status periodically
    QTimer *m_expirationCheckTimer; // Timer to enforce expiration dynamically
    QDateTime m_licenseEndDate; // Cached license end date
    int m_studioId = 0;         // studio id (gallery URL prefix), nhớ qua QSettings
    QString m_plan;             // 'trial' | mã gói | ""
    QString m_deviceTier;       // trial|event|studio|event_studio|studio_selfbooth|premium|""
    QVariantMap m_caps;         // capabilities {event,studio,selfbooth}
    bool m_machineRowEnsured = false; // đã ghi HWID vào DB trong phiên chạy này chưa

    QString generateHWID();
    QString getCPUInfo();
    QString getMACAddress();
    QString getVolumeSerialNumber();
    void setStatus(int newStatus, const QString &message);
    void checkMachineOnDynamoDB();
};

#endif // MACHINEAUTHENTICATOR_H
