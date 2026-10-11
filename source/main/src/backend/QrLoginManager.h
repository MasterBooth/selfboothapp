#ifndef QRLOGINMANAGER_H
#define QRLOGINMANAGER_H

#include <QObject>
#include <QString>
#include <QVariantMap>
#include <QDateTime>
#include <QTimer>

class ConfigManager;
class QNetworkAccessManager;

/**
 * @class QrLoginManager
 * @brief Đăng nhập / mở khóa Cài đặt bằng mã QR quét từ portal (cms-vietbooth).
 *
 * Luồng: start(hwid, purpose) → Worker tạo phiên QR một lần (TTL 3 phút) →
 * desktop hiển thị qrData qua image://qr/... → điện thoại quét, đăng nhập portal
 * và xác nhận → desktop poll thấy 'approved' → gọi consume (single-use) →
 * emit approved(email, name, role, purpose).
 *
 * Ngoài ra fetchStudioInfo(hwid) tải chủ studio + danh sách nhân viên cho tab
 * Thông tin. Dùng cùng base URL + bearer token với DynamoDBClient (ConfigManager).
 */
class QrLoginManager : public QObject {
    Q_OBJECT
    // status: idle | waiting | approved | expired | error
    Q_PROPERTY(bool active READ active NOTIFY stateChanged)
    Q_PROPERTY(QString status READ status NOTIFY stateChanged)
    Q_PROPERTY(QString qrData READ qrData NOTIFY stateChanged)
    Q_PROPERTY(QString errorText READ errorText NOTIFY stateChanged)
    Q_PROPERTY(QVariantMap studioInfo READ studioInfo NOTIFY studioInfoChanged)
    Q_PROPERTY(bool studioInfoLoading READ studioInfoLoading NOTIFY studioInfoChanged)
    Q_PROPERTY(QString studioInfoError READ studioInfoError NOTIFY studioInfoChanged)

public:
    explicit QrLoginManager(ConfigManager *config, QObject *parent = nullptr);

    bool active() const { return m_status == QStringLiteral("waiting"); }
    QString status() const { return m_status; }
    QString qrData() const { return m_qrData; }
    QString errorText() const { return m_errorText; }
    QVariantMap studioInfo() const { return m_studioInfo; }
    bool studioInfoLoading() const { return m_studioInfoLoading; }
    QString studioInfoError() const { return m_studioInfoError; }

    /** purpose = "login" (đăng nhập app) hoặc "security" (mở khóa Cài đặt). */
    Q_INVOKABLE void start(const QString &hwid, const QString &purpose);
    Q_INVOKABLE void cancel();
    /** Tải {owner_email, owner_name, brand, staff[]} cho tab Thông tin. */
    Q_INVOKABLE void fetchStudioInfo(const QString &hwid);

signals:
    void stateChanged();
    void studioInfoChanged();
    /** Portal đã xác nhận và mã đã được tiêu thụ — an toàn để đăng nhập/mở khóa. */
    void approved(const QString &email, const QString &name,
                  const QString &role, const QString &purpose);

private:
    void setStatus(const QString &status, const QString &error = QString());
    void poll();
    void consume(const QVariantMap &approver);

    ConfigManager *m_config;
    QNetworkAccessManager *m_net;
    QTimer m_pollTimer;

    QString m_status = QStringLiteral("idle");
    QString m_qrData;
    QString m_errorText;
    QString m_hwid;
    QString m_code;
    QString m_purpose;
    QDateTime m_expiresAt;
    // Thế hệ phiên — tăng mỗi lần start()/cancel() để loại reply mạng về trễ.
    int m_generation = 0;

    QVariantMap m_studioInfo;
    bool m_studioInfoLoading = false;
    QString m_studioInfoError;
};

#endif // QRLOGINMANAGER_H
