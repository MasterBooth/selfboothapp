#ifndef ACTIVATIONCLIENT_H
#define ACTIVATIONCLIENT_H

#include <QObject>
#include <QNetworkAccessManager>
#include <QTimer>

class ConfigManager;
class LicenseManager;
class QNetworkReply;

// ─────────────────────────────────────────────────────────────────────────────
// ActivationClient — phía máy booth của luồng kích hoạt bằng OTP.
//
//   1. requestActivation() → báo máy chủ "máy này chưa có chữ ký" để hiện trong
//                            mục Chờ duyệt của app admin.
//   2. Admin ký giấy phép tại app admin, Worker sinh mã OTP 4 số, admin đọc mã
//      cho khách.
//   3. redeemOtp()         → đổi OTP lấy token ĐÃ KÝ, giao LicenseManager xác minh
//                            chữ ký + HWID rồi lưu xuống đĩa.
//   4. syncStatus()        → khi có mạng: áp phiếu thu hồi (đã ký) và nhận bản gia
//                            hạn / đổi hạng mới nhất. Lỗi mạng bỏ qua im lặng.
//
// Sau bước 3 máy chạy hoàn toàn bằng chữ ký đã lưu — D1/Worker sập cũng không ảnh
// hưởng. Mọi route dùng token máy (cấp khi đăng nhập studio); máy chủ lấy HWID từ
// token, không tin giá trị client gửi.
// ─────────────────────────────────────────────────────────────────────────────
class ActivationClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    busy         READ busy         NOTIFY stateChanged)
    Q_PROPERTY(QString message      READ message      NOTIFY stateChanged)
    Q_PROPERTY(QString errorCode    READ errorCode    NOTIFY stateChanged)
    Q_PROPERTY(int     attemptsLeft READ attemptsLeft NOTIFY stateChanged)

public:
    explicit ActivationClient(ConfigManager *config, LicenseManager *license,
                              QObject *parent = nullptr);

    bool    busy() const         { return m_busy; }
    QString message() const      { return m_message; }
    QString errorCode() const    { return m_errorCode; }
    int     attemptsLeft() const { return m_attemptsLeft; }   // -1 = chưa biết

    // Báo máy chủ máy đang chờ cấp phép. Im lặng khi lỗi.
    Q_INVOKABLE void requestActivation();

    // Đổi mã OTP 4 số lấy giấy phép.
    Q_INVOKABLE void redeemOtp(const QString &otp);

    // Áp phiếu thu hồi + nhận giấy phép mới nhất. Im lặng khi mất mạng.
    Q_INVOKABLE void syncStatus();

signals:
    void stateChanged();
    // Đã nhận và xác minh xong giấy phép — máy có thể chạy.
    void activated(const QString &serial);
    void failed(const QString &reason);

private:
    QNetworkRequest makeRequest(const QString &path) const;
    bool canCallServer() const;
    void setState(bool busy, const QString &message, const QString &errorCode = QString());
    void onRedeemReply(QNetworkReply *reply);
    static QString messageForError(const QString &code, const QString &serverMessage, int http);

    ConfigManager  *m_config  = nullptr;
    LicenseManager *m_license = nullptr;
    QNetworkAccessManager m_net;
    QTimer   m_syncTimer;

    bool     m_busy = false;
    bool     m_syncing = false;
    QString  m_message;
    QString  m_errorCode;
    int      m_attemptsLeft = -1;
};

#endif // ACTIVATIONCLIENT_H
