#ifndef STUDIOACCOUNT_H
#define STUDIOACCOUNT_H

#include <QObject>
#include <QString>
#include <QVariantMap>

class ConfigManager;
class QJsonObject;
class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

/**
 * Tài khoản studio đăng nhập trên máy (API selfboothvn /v1).
 *
 * - Đăng ký / đăng nhập studio bằng email + mật khẩu → server gắn máy vào studio và
 *   cấp token riêng của máy. Token lưu qua SecureStore, còn thông tin studio
 *   không nhạy cảm lưu QSettings (BoothOS/Studio).
 * - Server trả 401 cho token máy (bị thu hồi / máy đổi studio) → xóa phiên local,
 *   app quay về màn đăng nhập.
 * - Đang đăng nhập: báo danh GET /v1/machine/me mỗi 5 phút (web admin thấy máy Online)
 *   và lấy tên máy studio đặt trên web (display_name) — tên này không bị file cấu hình ghi đè.
 */
class StudioAccount : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool loggedIn READ loggedIn NOTIFY accountChanged)
    Q_PROPERTY(QString studioId READ studioId NOTIFY accountChanged)
    Q_PROPERTY(QString studioName READ studioName NOTIFY accountChanged)
    Q_PROPERTY(QString email READ email NOTIFY accountChanged)
    Q_PROPERTY(QString machineName READ machineName NOTIFY accountChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    StudioAccount(ConfigManager *config, const QString &hwid, QObject *parent = nullptr);

    bool loggedIn() const { return !m_token.isEmpty(); }
    QString studioId() const { return m_studioId; }
    QString studioName() const { return m_studioName; }
    QString email() const { return m_email; }
    // Tên máy: tên studio đặt trên web, không có thì tên trong file cấu hình.
    QString machineName() const { return m_machineName; }
    bool busy() const { return m_busy; }
    QString hwid() const { return m_hwid; }

    // Nạp phiên đã lưu (gọi một lần khi khởi động, trước khi QML nạp).
    void restore();
    // Báo danh máy lên server sau khi đã có machine token.
    Q_INVOKABLE void registerMachine();

    Q_INVOKABLE void login(const QString &email, const QString &password);
    Q_INVOKABLE void registerStudio(const QString &studioName, const QString &email,
                                    const QString &password);
    Q_INVOKABLE void logout();
    // Báo danh + lấy lại tên máy / tên studio từ server (cũng chạy định kỳ khi đăng nhập).
    Q_INVOKABLE void refreshMachine();

    // Client API khác gặp 401 với token máy → phiên không còn hiệu lực.
    void handleUnauthorized();

signals:
    void accountChanged();
    void busyChanged();
    void signedIn();                          // đăng nhập / đăng ký thành công
    void authFailed(const QString &message);  // thông báo tiếng Việt để hiện trên màn
    void signedOut();

private:
    void sendAuth(const QString &path, const QVariantMap &body);
    void onAuthReply(QNetworkReply *reply);
    void setBusy(bool busy);
    void clearSession();
    void applyMachine(const QJsonObject &machine);
    static QString messageForError(const QString &code, const QString &serverMessage, int httpStatus);

    ConfigManager *m_config;
    QNetworkAccessManager *m_net;
    QString m_hwid;
    QString m_token;
    QString m_studioId;
    QString m_studioName;
    QString m_email;
    QString m_machineName;
    QTimer *m_heartbeat = nullptr;
    bool m_busy = false;
};

#endif // STUDIOACCOUNT_H
