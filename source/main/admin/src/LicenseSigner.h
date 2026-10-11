#ifndef LICENSESIGNER_H
#define LICENSESIGNER_H

#include <QObject>
#include <QVariantMap>
#include <QByteArray>
#include <QDateTime>
#include <QJsonObject>

// ─────────────────────────────────────────────────────────────────────────────
// LicenseSigner — giữ khoá ký và cấp giấy phép. CHỈ có trong app admin.
//
// Đây là thứ duy nhất trên đời tạo được giấy phép hợp lệ. Toàn bộ mô hình bảo
// mật dựa vào việc khoá private không rời khỏi máy này: Worker, D1 và bản build
// khách hàng đều chỉ có khoá công khai.
//
// Bảo vệ khoá trên đĩa
// ────────────────────
// Tệp khoá không bao giờ chứa khoá trần. Cấu trúc:
//
//     mật khẩu ──Argon2i(m=64MB, t=3)──► khoá 32 byte
//                                          │
//     seed 32 byte ──XChaCha20-Poly1305────┘──► ciphertext + thẻ xác thực
//
// Argon2i chống dò mật khẩu bằng GPU (tốn bộ nhớ, không chỉ tốn CPU). Thẻ
// Poly1305 khiến sửa một byte trong tệp là mở khoá thất bại chứ không ra khoá
// sai âm thầm. Cả hai đều lấy từ Monocypher đã nhúng — không thêm phụ thuộc.
//
// Khoá giải mã chỉ nằm trong RAM khi app đang mở, và được crypto_wipe() khi khoá
// sổ hoặc khi thoát.
// ─────────────────────────────────────────────────────────────────────────────
class LicenseSigner : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool    unlocked     READ isUnlocked     NOTIFY stateChanged)
    Q_PROPERTY(bool    hasKeyFile   READ hasKeyFile     NOTIFY stateChanged)
    Q_PROPERTY(QString keyId        READ keyId          NOTIFY stateChanged)
    Q_PROPERTY(QString publicKeyHex READ publicKeyHex   NOTIFY stateChanged)
    Q_PROPERTY(QString keyFilePath  READ keyFilePath    CONSTANT)

public:
    explicit LicenseSigner(QObject *parent = nullptr);
    ~LicenseSigner() override;

    bool    isUnlocked() const   { return m_unlocked; }
    bool    hasKeyFile() const;
    QString keyId() const        { return m_kid; }
    QString publicKeyHex() const { return m_publicHex; }
    QString keyFilePath() const;

    // Sinh cặp khoá mới và ghi ra đĩa (đã mã hoá). Từ chối nếu đã có tệp khoá —
    // ghi đè nhầm là mất khả năng gia hạn cho toàn bộ máy đã cấp phép.
    Q_INVOKABLE bool createKey(const QString &kid, const QString &passphrase,
                               QString *errorOut = nullptr);

    // Mở khoá sổ bằng mật khẩu. Sai mật khẩu → thất bại, không tiết lộ gì thêm.
    Q_INVOKABLE bool unlock(const QString &passphrase, QString *errorOut = nullptr);

    // Xoá khoá khỏi RAM.
    Q_INVOKABLE void lock();

    // Ký một giấy phép. Trả token "LM1.<payload>.<chữ ký>", rỗng nếu lỗi.
    // deviceTier quyết định caps theo đúng ma trận Worker đang dùng.
    Q_INVOKABLE QString signLicense(const QString &hwid,
                                    const QString &ownerEmail,
                                    const QString &brand,
                                    const QString &deviceTier,
                                    const QString &serial,
                                    int months,
                                    int graceDays,
                                    QString *errorOut = nullptr);

    // Như signLicense nhưng giữ đúng hạn cho trước (ISO-8601 UTC; rỗng = vô thời
    // hạn). Dùng khi chuyển giấy phép sang máy mới: máy mới giữ nguyên hạn cũ.
    Q_INVOKABLE QString signLicenseUntil(const QString &hwid,
                                         const QString &ownerEmail,
                                         const QString &brand,
                                         const QString &deviceTier,
                                         const QString &serial,
                                         const QString &notAfterIso,
                                         int graceDays);

    // Ký phiếu thu hồi một serial của một máy. Máy booth chỉ xoá giấy phép khi
    // phiếu có chữ ký hợp lệ — nắm D1/Worker cũng không khoá được máy nào.
    Q_INVOKABLE QString signRevocation(const QString &hwid,
                                       const QString &serial,
                                       const QString &reason);

    // Lỗi của lần ký gần nhất (để QML hiện ra; QML không truyền được errorOut).
    Q_INVOKABLE QString lastError() const { return m_lastError; }

    // Dòng cấu hình dán vào wrangler.toml, và hằng số C++ dán vào
    // LicenseManager.cpp — để không phải chép tay khoá công khai (dễ sai).
    Q_INVOKABLE QString wranglerVarLine() const;
    Q_INVOKABLE QString cppConstantLine() const;

    // Ma trận quyền theo hạng thiết bị, khớp TIER_CAPS bên Worker.
    static QVariantMap capsForTier(const QString &tier);

signals:
    void stateChanged();

private:
    void wipeSecret();
    QString signLicenseImpl(const QString &hwid, const QString &ownerEmail,
                            const QString &brand, const QString &deviceTier,
                            const QString &serial, const QDateTime &notAfter,
                            int graceDays, QString *errorOut);
    // Ký đúng chuỗi byte JSON compact của payload, trả "LM1.<payload>.<sig>".
    QString signPayload(const QJsonObject &payload) const;

    bool       m_unlocked = false;
    QString    m_lastError;
    QString    m_kid;
    QString    m_publicHex;
    QByteArray m_secret;      // 64 byte khoá ký Ed25519, chỉ tồn tại khi đã mở khoá
};

#endif // LICENSESIGNER_H
