#ifndef CLOUDSYNCMANAGER_H
#define CLOUDSYNCMANAGER_H

#include <QObject>
#include <QVariantMap>
#include <QJsonObject>

class ConfigManager;
class DatabaseManager;
class StudioAccount;
class QNetworkAccessManager;
class QTimer;

/**
 * Đồng bộ dữ liệu máy -> API selfboothvn (/v1) qua hàng đợi bền `cloud_outbox`.
 *
 * Phiên chụp, doanh thu, lượt dùng mã offline được GHI VÀO OUTBOX TRƯỚC rồi mới gửi:
 * mất mạng / chưa đăng nhập studio thì dữ liệu nằm chờ, có mạng + đã đăng nhập thì
 * đẩy lên. Server idempotent (revenue_id, use_id, status_version) nên gửi lặp an toàn.
 *
 * Mã gói chụp: redeemCode() kiểm tra online; mất mạng thì chỉ nhận mã DÙNG LẠI có
 * trong cache (tải từ /v1/machine/codes/reusable), lượt dùng được đẩy lên sau.
 */
class CloudSyncManager : public QObject
{
    Q_OBJECT
public:
    CloudSyncManager(ConfigManager *config, DatabaseManager *db, StudioAccount *account,
                     QObject *parent = nullptr);

    // Upsert phiên (giữ bản mới nhất theo session_id).
    void enqueueSession(const QString &sessionId, const QJsonObject &payload);
    // Doanh thu: revenueId = sha256 hex (bất biến, gửi lặp không nhân bản).
    void enqueueRevenue(const QString &revenueId, const QJsonObject &payload);
    void enqueueCodeUse(const QString &useId, const QJsonObject &usePayload);

    // Kiểm tra + dùng mã 4 số cho phiên. Kết quả qua codeRedeemFinished(result):
    //   {ok:true, code, use_id, minutes, price_vnd, kind, source:"online"|"offline"}
    //   {ok:false, error, message}
    Q_INVOKABLE void redeemCode(const QString &code, const QString &sessionId);

    // Chỉ kiểm tra mã còn hợp lệ, không tiêu thụ mã single-use.
    // Kết quả qua codeCheckFinished(result):
    //   {ok:true, code, code_id, minutes, price_vnd, kind}
    //   {ok:false, code, error, message}
    Q_INVOKABLE void checkCode(const QString &code);

public slots:
    void flush();
    void refreshReusableCodes();

signals:
    void codeCheckFinished(const QVariantMap &result);
    void codeRedeemFinished(const QVariantMap &result);

private:
    void sendNext();
    bool canSend() const;
    QVariantMap acceptOfflineReusable(const QString &code, const QString &sessionId);
    static QString redeemMessage(const QString &error, const QString &serverMessage);

    ConfigManager *m_config;
    DatabaseManager *m_db;
    StudioAccount *m_account;
    QNetworkAccessManager *m_net;
    QTimer *m_flushTimer;
    QTimer *m_codesTimer;
    bool m_sending = false;
    bool m_redeeming = false;
};

#endif // CLOUDSYNCMANAGER_H
