#ifndef ADMINAPI_H
#define ADMINAPI_H

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <QNetworkAccessManager>
#include <functional>

class QNetworkReply;

// ─────────────────────────────────────────────────────────────────────────────
// AdminApi — nói chuyện với Worker selfboothvn-api (/v1/admin/licenses/*) bằng
// ADMIN_API_TOKEN riêng.
//
// Cố ý KHÔNG dùng chung token máy của app booth.
// phát cho mọi máy nên coi như ai cũng có.
//
// Lưu ý: token này chỉ mở được danh sách máy và cổng nộp giấy phép / phiếu thu
// hồi. Nó KHÔNG tạo được giấy phép hay khoá được máy — việc đó cần chữ ký, mà
// khoá ký nằm ở LicenseSigner. Worker xác minh chữ ký trước khi lưu bất cứ thứ gì.
// ─────────────────────────────────────────────────────────────────────────────
class AdminApi : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString baseUrl READ baseUrl WRITE setBaseUrl NOTIFY configChanged)
    Q_PROPERTY(bool    hasToken READ hasToken NOTIFY configChanged)
    Q_PROPERTY(bool    busy    READ busy    NOTIFY busyChanged)
    Q_PROPERTY(QString configPath READ configPath CONSTANT)

public:
    explicit AdminApi(QObject *parent = nullptr);

    QString baseUrl() const { return m_baseUrl; }
    void    setBaseUrl(const QString &url);
    bool    hasToken() const { return !m_token.isEmpty(); }
    bool    busy() const { return m_busy; }
    QString configPath() const;

    // Nạp cấu hình từ admin-config.json cạnh exe (base_url + admin_token).
    Q_INVOKABLE bool loadConfig(QString *errorOut = nullptr);
    Q_INVOKABLE void setToken(const QString &token);
    // Ghi admin-config.json cạnh exe rồi dùng ngay. token rỗng = giữ token đang có.
    // Trả chuỗi lỗi, rỗng nếu thành công.
    Q_INVOKABLE QString saveConfig(const QString &baseUrl, const QString &token);
    Q_INVOKABLE void copyText(const QString &text);

    // Danh sách máy: chờ duyệt / đã kích hoạt / đã thu hồi.
    Q_INVOKABLE void fetchMachines();
    // Cấp mới (withOtp = true) hoặc gia hạn / đổi hạng (withOtp = false).
    Q_INVOKABLE void issue(const QString &license, const QString &approver, bool withOtp);
    Q_INVOKABLE void reissueOtp(const QString &hwid);
    Q_INVOKABLE void revoke(const QString &revocation);
    Q_INVOKABLE void transfer(const QString &revocation, const QString &license,
                              const QString &approver);
    Q_INVOKABLE void removeMachine(const QString &hwid);
    // Lịch sử giấy phép + OTP của một máy. Không bật busy — tải nền khi chọn máy.
    Q_INVOKABLE void fetchHistory(const QString &hwid);

signals:
    void configChanged();
    void busyChanged();
    void machinesReady(const QVariantList &machines);
    // otp rỗng khi gia hạn không kèm mã.
    void issued(const QString &serial, const QString &hwid,
                const QString &otp, const QString &otpExpiresAt);
    void otpReady(const QString &hwid, const QString &otp, const QString &otpExpiresAt);
    void revoked(const QString &serial, const QString &hwid);
    void removed(const QString &hwid);
    void historyReady(const QString &hwid, const QVariantMap &history);
    // notSupported = máy chủ chưa có route lịch sử (Worker cũ).
    void historyFailed(const QString &hwid, bool notSupported);
    void failed(const QString &message);

private:
    using Handler = std::function<void(const QVariantMap &)>;
    QNetworkRequest makeRequest(const QString &path) const;
    bool ensureConfigured();
    void send(const QByteArray &verb, const QString &path, const QVariantMap &body,
              Handler onOk);
    void setBusy(bool b);

    QNetworkAccessManager m_net;
    QString m_baseUrl;
    QString m_token;
    bool    m_busy = false;
};

#endif // ADMINAPI_H
