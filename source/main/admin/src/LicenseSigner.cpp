#include "LicenseSigner.h"

#include <QFile>
#include <QDir>
#include <QSaveFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QDateTime>
#include <QStandardPaths>
#include <QRandomGenerator>
#include <QDebug>

extern "C" {
#include "vendor/monocypher.h"
#include "vendor/monocypher-ed25519.h"
}

namespace {

// Tham số Argon2i. 64 MB × 3 lượt là mức khuyến nghị cho khoá tương tác: một
// lần mở khoá mất chưa tới một giây trên máy admin, nhưng khiến dò mật khẩu
// hàng loạt bằng GPU trở nên quá đắt.
constexpr uint32_t kArgonBlocks = 65536;   // 64 MB
constexpr uint32_t kArgonPasses = 3;
constexpr int kSaltLen  = 16;
constexpr int kNonceLen = 24;              // XChaCha20 dùng nonce 24 byte
constexpr int kMacLen   = 16;
constexpr int kSeedLen  = 32;

QByteArray randomBytes(int n)
{
    QByteArray out(n, Qt::Uninitialized);
    // QRandomGenerator::system() = nguồn ngẫu nhiên của hệ điều hành.
    // KHÔNG dùng global() ở đây — global() không phải nguồn mật mã.
    QRandomGenerator::system()->generate(
        reinterpret_cast<quint32 *>(out.data()),
        reinterpret_cast<quint32 *>(out.data() + n));
    return out;
}

QByteArray b64url(const QByteArray &in)
{
    return in.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
}

// Dẫn xuất khoá mã hoá tệp từ mật khẩu.
QByteArray deriveKey(const QString &passphrase, const QByteArray &salt)
{
    QByteArray pass = passphrase.toUtf8();
    QByteArray key(32, Qt::Uninitialized);

    // Argon2 cần vùng nhớ nháp do người gọi cấp.
    QByteArray work(static_cast<int>(kArgonBlocks) * 1024, Qt::Uninitialized);

    crypto_argon2_config cfg{};
    cfg.algorithm = CRYPTO_ARGON2_I;
    cfg.nb_blocks = kArgonBlocks;
    cfg.nb_passes = kArgonPasses;
    cfg.nb_lanes  = 1;

    crypto_argon2_inputs inputs{};
    inputs.pass      = reinterpret_cast<const uint8_t *>(pass.constData());
    inputs.pass_size = static_cast<uint32_t>(pass.size());
    inputs.salt      = reinterpret_cast<const uint8_t *>(salt.constData());
    inputs.salt_size = static_cast<uint32_t>(salt.size());

    crypto_argon2_extras extras{};

    crypto_argon2(reinterpret_cast<uint8_t *>(key.data()), 32,
                  work.data(), cfg, inputs, extras);

    crypto_wipe(pass.data(), static_cast<size_t>(pass.size()));
    crypto_wipe(work.data(), static_cast<size_t>(work.size()));
    return key;
}

} // namespace

// ─────────────────────────────────────────────────────────────────────────────

LicenseSigner::LicenseSigner(QObject *parent) : QObject(parent) {}

LicenseSigner::~LicenseSigner() { wipeSecret(); }

void LicenseSigner::wipeSecret()
{
    if (!m_secret.isEmpty())
        crypto_wipe(m_secret.data(), static_cast<size_t>(m_secret.size()));
    m_secret.clear();
}

QString LicenseSigner::keyFilePath() const
{
    // Để trong thư mục dữ liệu người dùng, KHÔNG để cạnh exe: exe hay bị chép
    // đi chép lại và khoá ký sẽ vô tình đi theo.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    return QDir(dir).filePath(QStringLiteral("signing-key.lmkey"));
}

bool LicenseSigner::hasKeyFile() const { return QFile::exists(keyFilePath()); }

// ── Sinh khoá ────────────────────────────────────────────────────────────────

bool LicenseSigner::createKey(const QString &kid, const QString &passphrase, QString *errorOut)
{
    auto fail = [errorOut](const QString &m) { if (errorOut) *errorOut = m; return false; };

    if (kid.trimmed().isEmpty())        return fail(QStringLiteral("Thiếu mã khoá (kid)"));
    if (passphrase.size() < 12)         return fail(QStringLiteral("Mật khẩu phải từ 12 ký tự trở lên"));
    if (hasKeyFile())
        // Ghi đè là mất khả năng gia hạn cho MỌI máy đã cấp phép bằng khoá cũ.
        return fail(QStringLiteral("Đã có tệp khoá. Sao lưu và xoá thủ công trước khi tạo khoá mới."));

    QByteArray seed = randomBytes(kSeedLen);

    // THỨ TỰ Ở ĐÂY LÀ BẮT BUỘC: mã hoá seed TRƯỚC, dẫn xuất cặp khoá SAU.
    //
    // crypto_ed25519_key_pair() của Monocypher XOÁ SẠCH seed đầu vào theo đúng
    // hợp đồng của nó. Nếu gọi nó trước thì thứ được mã hoá vào tệp là 32 byte
    // số 0, và mọi tệp khoá admin sẽ mở ra cùng một khoá — hỏng toàn bộ mô hình
    // bảo mật. Kiểm tra nhất quán khoá công khai ở unlock() bắt được lỗi này.
    const QByteArray salt  = randomBytes(kSaltLen);
    const QByteArray nonce = randomBytes(kNonceLen);
    QByteArray fileKey = deriveKey(passphrase, salt);

    QByteArray cipher(kSeedLen, Qt::Uninitialized);
    QByteArray mac(kMacLen, Qt::Uninitialized);
    crypto_aead_lock(reinterpret_cast<uint8_t *>(cipher.data()),
                     reinterpret_cast<uint8_t *>(mac.data()),
                     reinterpret_cast<const uint8_t *>(fileKey.constData()),
                     reinterpret_cast<const uint8_t *>(nonce.constData()),
                     nullptr, 0,
                     reinterpret_cast<const uint8_t *>(seed.constData()), kSeedLen);

    QByteArray secret(64, Qt::Uninitialized);
    QByteArray publicKey(32, Qt::Uninitialized);
    crypto_ed25519_key_pair(reinterpret_cast<uint8_t *>(secret.data()),
                            reinterpret_cast<uint8_t *>(publicKey.data()),
                            reinterpret_cast<uint8_t *>(seed.data()));  // seed bị xoá tại đây

    QJsonObject o;
    o["v"]        = 1;
    o["kid"]      = kid.trimmed();
    o["kdf"]      = QStringLiteral("argon2i");
    o["m_kb"]     = int(kArgonBlocks);
    o["passes"]   = int(kArgonPasses);
    o["salt"]     = QString::fromLatin1(salt.toHex());
    o["nonce"]    = QString::fromLatin1(nonce.toHex());
    o["cipher"]   = QString::fromLatin1(cipher.toHex());
    o["mac"]      = QString::fromLatin1(mac.toHex());
    o["public"]   = QString::fromLatin1(publicKey.toHex());
    o["created"]  = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);

    QDir().mkpath(QFileInfo(keyFilePath()).absolutePath());
    QSaveFile f(keyFilePath());
    if (!f.open(QIODevice::WriteOnly)) {
        crypto_wipe(seed.data(), kSeedLen);
        crypto_wipe(fileKey.data(), 32);
        crypto_wipe(secret.data(), 64);
        return fail(QStringLiteral("Không ghi được tệp khoá: %1").arg(f.errorString()));
    }
    f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    const bool okWrite = f.commit();

    crypto_wipe(seed.data(), kSeedLen);
    crypto_wipe(fileKey.data(), 32);
    if (!okWrite) {
        crypto_wipe(secret.data(), 64);
        return fail(QStringLiteral("Không lưu được tệp khoá"));
    }

    m_secret    = secret;                       // giữ lại: vừa tạo là dùng được ngay
    m_kid       = kid.trimmed();
    m_publicHex = QString::fromLatin1(publicKey.toHex());
    m_unlocked  = true;
    emit stateChanged();

    qInfo() << "[Signer] Đã tạo khoá ký" << m_kid << "| công khai:" << m_publicHex;
    return true;
}

// ── Mở khoá ──────────────────────────────────────────────────────────────────

bool LicenseSigner::unlock(const QString &passphrase, QString *errorOut)
{
    auto fail = [errorOut](const QString &m) { if (errorOut) *errorOut = m; return false; };

    QFile f(keyFilePath());
    if (!f.open(QIODevice::ReadOnly)) return fail(QStringLiteral("Chưa có tệp khoá ký"));
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject()) return fail(QStringLiteral("Tệp khoá hỏng"));

    const QJsonObject o = doc.object();
    const QByteArray salt   = QByteArray::fromHex(o["salt"].toString().toLatin1());
    const QByteArray nonce  = QByteArray::fromHex(o["nonce"].toString().toLatin1());
    const QByteArray cipher = QByteArray::fromHex(o["cipher"].toString().toLatin1());
    const QByteArray mac    = QByteArray::fromHex(o["mac"].toString().toLatin1());
    if (salt.size() != kSaltLen || nonce.size() != kNonceLen
        || cipher.size() != kSeedLen || mac.size() != kMacLen)
        return fail(QStringLiteral("Tệp khoá hỏng"));

    QByteArray fileKey = deriveKey(passphrase, salt);
    QByteArray seed(kSeedLen, Qt::Uninitialized);

    // Trả khác 0 khi mật khẩu sai HOẶC tệp bị sửa — thẻ Poly1305 bắt cả hai.
    const int rc = crypto_aead_unlock(
        reinterpret_cast<uint8_t *>(seed.data()),
        reinterpret_cast<const uint8_t *>(mac.constData()),
        reinterpret_cast<const uint8_t *>(fileKey.constData()),
        reinterpret_cast<const uint8_t *>(nonce.constData()),
        nullptr, 0,
        reinterpret_cast<const uint8_t *>(cipher.constData()), kSeedLen);
    crypto_wipe(fileKey.data(), 32);

    if (rc != 0) {
        crypto_wipe(seed.data(), kSeedLen);
        return fail(QStringLiteral("Sai mật khẩu hoặc tệp khoá đã bị sửa"));
    }

    QByteArray secret(64, Qt::Uninitialized);
    QByteArray publicKey(32, Qt::Uninitialized);
    crypto_ed25519_key_pair(reinterpret_cast<uint8_t *>(secret.data()),
                            reinterpret_cast<uint8_t *>(publicKey.data()),
                            reinterpret_cast<uint8_t *>(seed.data()));
    crypto_wipe(seed.data(), kSeedLen);

    const QString storedPub = o["public"].toString();
    const QString derivedPub = QString::fromLatin1(publicKey.toHex());
    if (!storedPub.isEmpty() && storedPub != derivedPub) {
        crypto_wipe(secret.data(), 64);
        return fail(QStringLiteral("Tệp khoá không nhất quán"));
    }

    wipeSecret();
    m_secret    = secret;
    m_kid       = o["kid"].toString();
    m_publicHex = derivedPub;
    m_unlocked  = true;
    emit stateChanged();
    return true;
}

void LicenseSigner::lock()
{
    wipeSecret();
    m_unlocked = false;
    emit stateChanged();
}

// ── Ma trận quyền ────────────────────────────────────────────────────────────
// Giữ khớp với TIER_CAPS bên Worker. Hạng lạ → không có quyền nào (fail-closed).
QVariantMap LicenseSigner::capsForTier(const QString &tier)
{
    QVariantMap c;
    c["event"] = false; c["studio"] = false; c["selfbooth"] = false;
    const QString t = tier.trimmed().toLower();
    if (t == "trial" || t == "premium") {
        c["event"] = true; c["studio"] = true; c["selfbooth"] = true;
    } else if (t == "event") {
        c["event"] = true;
    } else if (t == "studio") {
        c["studio"] = true;
    } else if (t == "event_studio") {
        c["event"] = true; c["studio"] = true;
    } else if (t == "studio_selfbooth") {
        c["studio"] = true; c["selfbooth"] = true;
    }
    return c;
}

// ── Ký giấy phép ─────────────────────────────────────────────────────────────

QString LicenseSigner::signLicense(const QString &hwid, const QString &ownerEmail,
                                   const QString &brand, const QString &deviceTier,
                                   const QString &serial, int months, int graceDays,
                                   QString *errorOut)
{
    // months = 0 → không khai not_after → vô thời hạn.
    const QDateTime notAfter = months > 0
        ? QDateTime::currentDateTimeUtc().addMonths(months) : QDateTime();
    return signLicenseImpl(hwid, ownerEmail, brand, deviceTier, serial, notAfter,
                           graceDays, errorOut);
}

QString LicenseSigner::signLicenseUntil(const QString &hwid, const QString &ownerEmail,
                                        const QString &brand, const QString &deviceTier,
                                        const QString &serial, const QString &notAfterIso,
                                        int graceDays)
{
    QDateTime notAfter;
    if (!notAfterIso.trimmed().isEmpty()) {
        notAfter = QDateTime::fromString(notAfterIso.trimmed(), Qt::ISODate);
        if (!notAfter.isValid()) {
            m_lastError = QStringLiteral("Hạn dùng không hợp lệ: %1").arg(notAfterIso);
            return QString();
        }
        notAfter = notAfter.toUTC();
    }
    return signLicenseImpl(hwid, ownerEmail, brand, deviceTier, serial, notAfter,
                           graceDays, nullptr);
}

QString LicenseSigner::signLicenseImpl(const QString &hwid, const QString &ownerEmail,
                                       const QString &brand, const QString &deviceTier,
                                       const QString &serial, const QDateTime &notAfter,
                                       int graceDays, QString *errorOut)
{
    auto fail = [this, errorOut](const QString &m) {
        m_lastError = m;
        if (errorOut) *errorOut = m;
        return QString();
    };

    if (!m_unlocked || m_secret.size() != 64) return fail(QStringLiteral("Chưa mở khoá ký"));
    const QString h = hwid.trimmed().toUpper();
    if (h.isEmpty())            return fail(QStringLiteral("Thiếu HWID"));
    if (serial.trimmed().isEmpty()) return fail(QStringLiteral("Thiếu số hiệu giấy phép"));

    const QVariantMap caps = capsForTier(deviceTier);
    if (!caps.value("event").toBool() && !caps.value("studio").toBool()
        && !caps.value("selfbooth").toBool())
        return fail(QStringLiteral("Hạng thiết bị không hợp lệ: %1").arg(deviceTier));

    const QDateTime now = QDateTime::currentDateTimeUtc();

    QJsonObject capsObj;
    for (auto it = caps.constBegin(); it != caps.constEnd(); ++it)
        capsObj[it.key()] = it.value().toBool();

    QJsonObject p;
    p["v"]           = 1;
    p["typ"]         = QStringLiteral("license");
    p["kid"]         = m_kid;
    p["hwid"]        = h;
    p["owner_email"] = ownerEmail.trimmed().toLower();
    p["brand"]       = brand.trimmed();
    p["device_tier"] = deviceTier.trimmed().toLower();
    p["caps"]        = capsObj;
    p["serial"]      = serial.trimmed();
    p["issued_at"]   = now.toString(Qt::ISODate);
    if (notAfter.isValid())
        p["not_after"] = notAfter.toUTC().toString(Qt::ISODate);
    p["grace_days"]  = graceDays;

    m_lastError.clear();
    if (errorOut) errorOut->clear();
    return signPayload(p);
}

QString LicenseSigner::signRevocation(const QString &hwid, const QString &serial,
                                      const QString &reason)
{
    if (!m_unlocked || m_secret.size() != 64) {
        m_lastError = QStringLiteral("Chưa mở khoá ký");
        return QString();
    }
    const QString h = hwid.trimmed().toUpper();
    if (h.isEmpty() || serial.trimmed().isEmpty()) {
        m_lastError = QStringLiteral("Thiếu HWID hoặc số hiệu giấy phép");
        return QString();
    }

    QJsonObject p;
    p["v"]         = 1;
    p["typ"]       = QStringLiteral("revoke");
    p["kid"]       = m_kid;
    p["hwid"]      = h;
    p["serial"]    = serial.trimmed();
    p["issued_at"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
    p["reason"]    = reason.trimmed();

    m_lastError.clear();
    return signPayload(p);
}

QString LicenseSigner::signPayload(const QJsonObject &p) const
{
    // Compact: chuỗi byte này CHÍNH LÀ thứ được ký, và bên xác minh cũng kiểm
    // trên đúng nó sau khi giải mã base64url — không tuần tự hoá lại lần nữa.
    const QByteArray payload = QJsonDocument(p).toJson(QJsonDocument::Compact);

    QByteArray sig(64, Qt::Uninitialized);
    crypto_ed25519_sign(reinterpret_cast<uint8_t *>(sig.data()),
                        reinterpret_cast<const uint8_t *>(m_secret.constData()),
                        reinterpret_cast<const uint8_t *>(payload.constData()),
                        static_cast<size_t>(payload.size()));

    return QStringLiteral("LM1.") + QString::fromLatin1(b64url(payload))
         + QLatin1Char('.') + QString::fromLatin1(b64url(sig));
}

QString LicenseSigner::wranglerVarLine() const
{
    if (m_publicHex.isEmpty()) return QString();
    return QStringLiteral("LICENSE_PUBLIC_KEYS = \"%1:%2\"").arg(m_kid, m_publicHex);
}

QString LicenseSigner::cppConstantLine() const
{
    if (m_publicHex.isEmpty()) return QString();
    return QStringLiteral("    { \"%1\", \"%2\" },").arg(m_kid, m_publicHex);
}
