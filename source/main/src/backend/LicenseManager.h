#ifndef LICENSEMANAGER_H
#define LICENSEMANAGER_H

#include <QObject>
#include <QDateTime>
#include <QVariantMap>
#include <QStringList>

class DatabaseManager;

// ─────────────────────────────────────────────────────────────────────────────
// LicenseManager — nguồn quyền sử dụng của máy, KHÔNG phụ thuộc máy chủ.
//
// Vì sao tồn tại
// ──────────────
// Trước đây quyền của máy do cột `activate`/`device_tier` trong D1 quyết định.
// Nghĩa là ai nắm được cơ sở dữ liệu (hoặc bearer token — mà token đó hiện đang
// được phát công khai trong web-lamoment/portal/config.js) thì bật/tắt được mọi
// máy ngoài hiện trường.
//
// Lớp này đảo chiều tin cậy: máy không hỏi máy chủ "tôi có được chạy không?",
// mà tự hỏi "tôi có giấy phép do admin ký không?". Khoá ký private chỉ nằm trên
// máy admin; ở đây chỉ có khoá công khai nên bản build khách hàng KHÔNG BAO GIỜ
// ký được giấy phép — nó chỉ xác minh.
//
// Hệ quả: lộ toàn bộ D1 cũng không tạo được license giả, không hạ cấp được máy,
// không tắt được máy đang chạy.
//
// Định dạng token
// ───────────────
//     LM1.<base64url(payload JSON)>.<base64url(chữ ký Ed25519 64 byte)>
//
// Chữ ký phủ lên ĐÚNG chuỗi byte payload đã giải mã base64url, không phải lên
// JSON đã phân tích lại. Nhờ vậy không có vấn đề chuẩn hoá (thứ tự khoá, khoảng
// trắng) giữa bên ký và bên xác minh — một cái bẫy kinh điển của license ký số.
//
// Payload giấy phép (typ "license"; token cũ thiếu typ cũng được hiểu là license):
//   { v, typ, kid, hwid, owner_email, brand, device_tier,
//     caps:{event,studio,selfbooth}, serial, issued_at, not_after, grace_days }
//
// Phiếu thu hồi (typ "revoke"), cũng do admin ký:
//   { v, typ, kid, hwid, serial, issued_at, reason }
//
// Đơn điệu theo issued_at: máy nhớ mốc issued_at lớn nhất từng nhận và từ chối
// mọi token ký trước mốc đó. Admin hạ hạng / rút hạn được (bản ký sau luôn
// thắng), còn kẻ nắm D1 không phát lại được token cũ.
// ─────────────────────────────────────────────────────────────────────────────
class LicenseManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    valid         READ isValid       NOTIFY licenseChanged)
    Q_PROPERTY(QString serial        READ serial        NOTIFY licenseChanged)
    Q_PROPERTY(QString deviceTier    READ deviceTier    NOTIFY licenseChanged)
    Q_PROPERTY(QString ownerEmail    READ ownerEmail    NOTIFY licenseChanged)
    Q_PROPERTY(QString brand         READ brand         NOTIFY licenseChanged)
    Q_PROPERTY(QString notAfterText  READ notAfterText  NOTIFY licenseChanged)
    Q_PROPERTY(int     daysRemaining READ daysRemaining NOTIFY licenseChanged)
    Q_PROPERTY(bool    inGrace       READ inGrace       NOTIFY licenseChanged)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY licenseChanged)
    // true khi giấy phép vừa bị thu hồi bằng phiếu đã ký (màn kích hoạt hiện lời khác).
    Q_PROPERTY(bool    revoked       READ isRevoked     NOTIFY licenseChanged)

public:
    // Kết quả kiểm — dùng cho log và chẩn đoán, không hiện thẳng cho khách.
    enum Result {
        Ok = 0,
        NoFile,          // chưa kích hoạt
        Malformed,       // sai định dạng / base64 hỏng / JSON hỏng
        BadSignature,    // chữ ký không khớp → nghi giả mạo
        UnknownKey,      // kid không nằm trong bảng khoá công khai đã biết
        WrongMachine,    // license của máy khác
        Expired,         // quá hạn kể cả sau ân hạn
        NotNewer,        // adopt() bị từ chối vì ký trước bản đã từng nhận
        Revoked,         // serial đã có phiếu thu hồi hợp lệ
        WrongType        // token đúng chữ ký nhưng sai loại (license ↔ revoke)
    };
    Q_ENUM(Result)

    explicit LicenseManager(DatabaseManager *db, QObject *parent = nullptr);

    // HWID do MachineAuthenticator sinh; phải đặt trước khi load().
    void setHwid(const QString &hwid);
    QString hwid() const { return m_hwid; }

    // Đọc và xác minh tệp license trên đĩa. An toàn khi gọi lại nhiều lần.
    Q_INVOKABLE bool load();

    // Nhận một token mới (từ luồng kích hoạt hoặc gia hạn).
    // Chỉ ghi đè khi token hợp lệ, chưa bị thu hồi VÀ không ký trước bản đã nhận.
    Q_INVOKABLE bool adopt(const QString &token, QString *errorOut = nullptr);

    // Áp một phiếu thu hồi đã ký. Trả true nếu phiếu hợp lệ (dù có trúng giấy
    // phép đang dùng hay không). Trúng thì xoá tệp và chuyển sang Revoked.
    Q_INVOKABLE bool applyRevocation(const QString &token, QString *errorOut = nullptr);

    // Xoá license khỏi máy (dùng khi chuyển chủ / kích hoạt lại).
    Q_INVOKABLE bool clear();

    bool        isValid() const       { return m_valid; }
    QString     serial() const        { return m_payload.value("serial").toString(); }
    QString     deviceTier() const    { return m_payload.value("device_tier").toString(); }
    QString     ownerEmail() const    { return m_payload.value("owner_email").toString(); }
    QString     brand() const         { return m_payload.value("brand").toString(); }
    QVariantMap capabilities() const  { return m_payload.value("caps").toMap(); }
    QDateTime   notAfter() const      { return m_notAfter; }
    QString     notAfterText() const;
    int         daysRemaining() const;
    bool        inGrace() const       { return m_inGrace; }
    QString     statusMessage() const { return m_statusMessage; }
    Result      lastResult() const    { return m_lastResult; }
    bool        isRevoked() const     { return m_lastResult == Revoked; }

    QString licenseFilePath() const;

    // Xác minh thuần tuý, không đụng trạng thái — dùng cho kiểm thử và cho
    // luồng adopt() trước khi quyết định ghi đè.
    static Result verifyToken(const QString &token,
                              const QString &expectedHwid,
                              QVariantMap   *payloadOut,
                              QString       *errorOut);

    // Giờ hiệu dụng = max(đồng hồ hệ thống, mốc đã ghi nhận).
    // Vặn đồng hồ về quá khứ không kéo dài được hạn dùng.
    QDateTime effectiveNow() const;

signals:
    void licenseChanged();
    // Phát khi phát hiện tệp license bị sửa hoặc ký sai — đáng ghi log cảnh báo.
    void tamperDetected(const QString &reason);

private:
    void applyPayload(const QVariantMap &payload, const QString &token);
    void resetState(Result result, const QString &message);
    void rememberSeenTime();
    QStringList revokedSerials() const;
    QDateTime   issuedWatermark() const;
    void        raiseIssuedWatermark(const QDateTime &issuedAt);

    DatabaseManager *m_db = nullptr;
    QString      m_hwid;
    QString      m_token;
    QVariantMap  m_payload;
    QDateTime    m_notAfter;
    bool         m_valid   = false;
    bool         m_inGrace = false;
    Result       m_lastResult = NoFile;
    QString      m_statusMessage;
};

#endif // LICENSEMANAGER_H
