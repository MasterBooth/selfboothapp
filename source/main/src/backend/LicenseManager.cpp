#include "LicenseManager.h"
#include "DatabaseManager.h"
#include "AppPaths.h"

#include <QFile>
#include <QDir>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QSaveFile>
#include <QDebug>

extern "C" {
#include "vendor/monocypher-ed25519.h"
}

namespace {

// ── Khoá công khai của bên cấp phép ──────────────────────────────────────────
//
// BIÊN DỊCH CỨNG VÀO NHỊ PHÂN, cố ý không đọc từ file cấu hình cạnh exe:
// exe và ai cũng thay được, còn đổi hằng số này thì phải thay chính exe.
//
// Khoá private tương ứng CHỈ nằm trên máy admin (app BOOTHME_ADMIN). Bản build
// này không có và không cần khoá private — nó chỉ xác minh, không bao giờ ký.
//
// Bảng nhiều dòng để luân chuyển khoá: license cũ ký bằng kid cũ vẫn xác minh
// được sau khi thêm kid mới.
struct PublicKeyEntry {
    const char *kid;
    const char *hex;   // 32 byte = 64 ký tự hex
};

const PublicKeyEntry kPublicKeys[] = {
    // Khoá thật do BOOTHME_ADMIN sinh ngày 2026-09-27 (signing-key.lmkey trên máy
    // admin). Trùng với LICENSE_PUBLIC_KEYS trong wrangler.toml của Worker.
    { "lm-2026-01", "1b0a0d0283e1fe92ea42c5aae4d37e030eda7668c315c6e069af0e507f76ef62" },
};

const char *kTokenPrefix   = "LM1";
const char *kSeenTimeKey   = "license_last_seen_utc";
const char *kRevokedKey    = "license_revoked_serials";   // JSON mảng serial đã thu hồi
const char *kIssuedMarkKey = "license_issued_watermark";  // issued_at lớn nhất từng nhận
const char *kLicenseFile   = "license.lic";

// Token cũ (trước khi có trường typ) đều là giấy phép.
QString tokenType(const QVariantMap &payload)
{
    const QString t = payload.value(QStringLiteral("typ")).toString().trimmed();
    return t.isEmpty() ? QStringLiteral("license") : t;
}

QByteArray fromBase64Url(const QByteArray &in, bool *ok)
{
    // QByteArray::fromBase64Encoding trả về lỗi tường minh — dùng nó thay vì
    // bản im lặng để token hỏng bị bắt ngay chứ không thành mảng rỗng.
    auto res = QByteArray::fromBase64Encoding(
        in, QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals);
    if (ok) *ok = (res.decodingStatus == QByteArray::Base64DecodingStatus::Ok);
    return res.decoded;
}

bool lookupPublicKey(const QString &kid, quint8 out[32])
{
    for (const auto &e : kPublicKeys) {
        if (kid != QString::fromLatin1(e.kid)) continue;
        const QByteArray raw = QByteArray::fromHex(QByteArray(e.hex));
        if (raw.size() != 32) return false;      // bảng khoá bị viết sai
        memcpy(out, raw.constData(), 32);
        return true;
    }
    return false;
}

QDateTime parseIso(const QString &s)
{
    QDateTime dt = QDateTime::fromString(s, Qt::ISODate);
    if (dt.isValid()) dt.setTimeSpec(Qt::UTC);
    return dt;
}

} // namespace

// ─────────────────────────────────────────────────────────────────────────────

LicenseManager::LicenseManager(DatabaseManager *db, QObject *parent)
    : QObject(parent)
    , m_db(db)
{
    m_statusMessage = QStringLiteral("Chưa kích hoạt");
}

void LicenseManager::setHwid(const QString &hwid)
{
    m_hwid = hwid.trimmed().toUpper();
}

QString LicenseManager::licenseFilePath() const
{
    return QDir(AppPaths::instance().getAppDirectory())
               .filePath(QStringLiteral("data/") + QLatin1String(kLicenseFile));
}

// ── Giờ hiệu dụng ────────────────────────────────────────────────────────────
// Lấy mốc lớn hơn giữa đồng hồ hệ thống và mốc đã ghi nhận lần trước. Vặn đồng
// hồ về quá khứ để "hồi sinh" license hết hạn sẽ không có tác dụng.
QDateTime LicenseManager::effectiveNow() const
{
    const QDateTime sys = QDateTime::currentDateTimeUtc();
    if (!m_db) return sys;

    const QString stored = m_db->getSetting(QLatin1String(kSeenTimeKey), QString());
    if (stored.isEmpty()) return sys;

    const QDateTime seen = parseIso(stored);
    if (!seen.isValid()) return sys;
    return (seen > sys) ? seen : sys;
}

void LicenseManager::rememberSeenTime()
{
    if (!m_db) return;
    const QDateTime sys = QDateTime::currentDateTimeUtc();
    const QString stored = m_db->getSetting(QLatin1String(kSeenTimeKey), QString());
    const QDateTime seen = stored.isEmpty() ? QDateTime() : parseIso(stored);
    // Chỉ tiến, không bao giờ lùi.
    if (!seen.isValid() || sys > seen)
        m_db->setSetting(QLatin1String(kSeenTimeKey), sys.toString(Qt::ISODate));
}

// ── Danh sách thu hồi + mốc issued_at ────────────────────────────────────────
// Lưu trong DB chứ không trong license.lic: chép đè tệp giấy phép cũ (đã bị thu
// hồi, hoặc ký trước bản đang dùng) từ bản sao lưu vẫn không chạy lại được.

QStringList LicenseManager::revokedSerials() const
{
    if (!m_db) return {};
    const QJsonDocument doc = QJsonDocument::fromJson(
        m_db->getSetting(QLatin1String(kRevokedKey), QStringLiteral("[]")).toUtf8());
    QStringList out;
    for (const QJsonValue &v : doc.array()) out << v.toString();
    return out;
}

QDateTime LicenseManager::issuedWatermark() const
{
    if (!m_db) return {};
    return parseIso(m_db->getSetting(QLatin1String(kIssuedMarkKey), QString()));
}

void LicenseManager::raiseIssuedWatermark(const QDateTime &issuedAt)
{
    if (!m_db || !issuedAt.isValid()) return;
    const QDateTime cur = issuedWatermark();
    if (!cur.isValid() || issuedAt > cur)
        m_db->setSetting(QLatin1String(kIssuedMarkKey), issuedAt.toString(Qt::ISODate));
}

// ── Xác minh thuần tuý ───────────────────────────────────────────────────────

LicenseManager::Result LicenseManager::verifyToken(const QString &token,
                                                   const QString &expectedHwid,
                                                   QVariantMap   *payloadOut,
                                                   QString       *errorOut)
{
    auto fail = [errorOut](Result r, const QString &msg) {
        if (errorOut) *errorOut = msg;
        return r;
    };

    const QStringList parts = token.trimmed().split(QLatin1Char('.'));
    if (parts.size() != 3 || parts.at(0) != QLatin1String(kTokenPrefix))
        return fail(Malformed, QStringLiteral("Sai định dạng token"));

    bool okPayload = false, okSig = false;
    const QByteArray payloadBytes = fromBase64Url(parts.at(1).toLatin1(), &okPayload);
    const QByteArray sigBytes     = fromBase64Url(parts.at(2).toLatin1(), &okSig);

    if (!okPayload || !okSig || payloadBytes.isEmpty())
        return fail(Malformed, QStringLiteral("Base64 hỏng"));
    if (sigBytes.size() != 64)
        return fail(Malformed, QStringLiteral("Chữ ký sai độ dài"));

    // Đọc kid TRƯỚC khi xác minh chỉ để tra khoá — chưa tin gì ở nội dung này.
    QJsonParseError perr{};
    const QJsonDocument doc = QJsonDocument::fromJson(payloadBytes, &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isObject())
        return fail(Malformed, QStringLiteral("JSON hỏng: %1").arg(perr.errorString()));

    const QVariantMap payload = doc.object().toVariantMap();
    const QString kid = payload.value(QStringLiteral("kid")).toString();

    quint8 pk[32];
    if (!lookupPublicKey(kid, pk))
        return fail(UnknownKey, QStringLiteral("Không biết khoá ký '%1'").arg(kid));

    // Xác minh trên ĐÚNG chuỗi byte đã giải mã, không phải trên JSON tuần tự lại.
    const int rc = crypto_ed25519_check(
        reinterpret_cast<const quint8 *>(sigBytes.constData()),
        pk,
        reinterpret_cast<const quint8 *>(payloadBytes.constData()),
        static_cast<size_t>(payloadBytes.size()));
    if (rc != 0)
        return fail(BadSignature, QStringLiteral("Chữ ký không hợp lệ"));

    // Từ đây trở đi nội dung payload mới đáng tin.
    //
    // Chuẩn hoá CẢ HAI vế trước khi so. setHwid() đã viết hoa sẵn, nhưng đây là
    // hàm static công khai — app admin và bộ kiểm thử gọi thẳng với chuỗi chưa
    // chuẩn hoá, và khi đó chỉ chuẩn hoá một vế sẽ từ chối nhầm license hợp lệ.
    if (!expectedHwid.trimmed().isEmpty()) {
        const QString licHwid = payload.value(QStringLiteral("hwid")).toString().trimmed().toUpper();
        const QString wantHwid = expectedHwid.trimmed().toUpper();
        if (licHwid != wantHwid)
            return fail(WrongMachine,
                        QStringLiteral("License thuộc máy khác (%1)").arg(licHwid));
    }

    if (payloadOut) *payloadOut = payload;
    if (errorOut) errorOut->clear();
    return Ok;
}

// ── Nạp từ đĩa ───────────────────────────────────────────────────────────────

bool LicenseManager::load()
{
    const QString path = licenseFilePath();
    QFile f(path);
    if (!f.exists()) {
        resetState(NoFile, QStringLiteral("Chưa kích hoạt"));
        return false;
    }
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        resetState(NoFile, QStringLiteral("Không đọc được tệp giấy phép"));
        return false;
    }
    const QString token = QString::fromLatin1(f.readAll()).trimmed();
    f.close();

    QVariantMap payload;
    QString err;
    const Result r = verifyToken(token, m_hwid, &payload, &err);

    if (r != Ok) {
        // Chữ ký sai hoặc sai máy là dấu hiệu can thiệp, không phải lỗi thường.
        if (r == BadSignature || r == WrongMachine || r == Malformed) {
            qCritical() << "[License] Tệp giấy phép không hợp lệ:" << err;
            emit tamperDetected(err);
        } else {
            qWarning() << "[License] Không dùng được giấy phép:" << err;
        }
        resetState(r, err);
        return false;
    }

    if (tokenType(payload) != QLatin1String("license")) {
        qCritical() << "[License] Tệp giấy phép chứa token sai loại:" << tokenType(payload);
        emit tamperDetected(QStringLiteral("Token sai loại"));
        resetState(WrongType, QStringLiteral("Tệp giấy phép không hợp lệ"));
        return false;
    }

    const QString ser = payload.value(QStringLiteral("serial")).toString();
    if (revokedSerials().contains(ser)) {
        qWarning() << "[License] Giấy phép" << ser << "đã bị thu hồi";
        QFile::remove(path);
        resetState(Revoked, QStringLiteral("Giấy phép đã bị thu hồi"));
        return false;
    }

    // Tệp bị thay bằng một giấy phép ký TRƯỚC bản máy đã từng nhận → phát lại.
    const QDateTime issued = parseIso(payload.value(QStringLiteral("issued_at")).toString());
    const QDateTime mark = issuedWatermark();
    if (mark.isValid() && issued.isValid() && issued < mark) {
        qCritical() << "[License] Tệp giấy phép cũ hơn bản đã nhận — từ chối";
        emit tamperDetected(QStringLiteral("Giấy phép cũ bị phát lại"));
        resetState(NotNewer, QStringLiteral("Tệp giấy phép không hợp lệ"));
        return false;
    }

    applyPayload(payload, token);
    raiseIssuedWatermark(issued);
    rememberSeenTime();
    return m_valid;
}

// ── Nhận token mới ───────────────────────────────────────────────────────────

bool LicenseManager::adopt(const QString &token, QString *errorOut)
{
    QVariantMap payload;
    QString err;
    const Result r = verifyToken(token, m_hwid, &payload, &err);
    if (r != Ok) {
        if (errorOut) *errorOut = err;
        qWarning() << "[License] Từ chối token mới:" << err;
        return false;
    }

    if (tokenType(payload) != QLatin1String("license")) {
        if (errorOut) *errorOut = QStringLiteral("Token không phải giấy phép");
        return false;
    }

    // Đúng token đang giữ (đồng bộ định kỳ trả lại bản cũ) → không cần làm gì.
    if (m_valid && token.trimmed() == m_token) {
        if (errorOut) errorOut->clear();
        return true;
    }

    const QString ser = payload.value(QStringLiteral("serial")).toString();
    if (revokedSerials().contains(ser)) {
        const QString msg = QStringLiteral("Giấy phép này đã bị thu hồi");
        if (errorOut) *errorOut = msg;
        qWarning() << "[License]" << msg << ser;
        return false;
    }

    // Quy tắc đơn điệu theo issued_at — chốt chặn quan trọng nhất trước kịch bản
    // lộ D1. Token ký trước bản máy đã từng nhận bị từ chối, nên kẻ có quyền ghi
    // cơ sở dữ liệu không phát lại được giấy phép cũ (kể cả sau khi bị thu hồi).
    // Admin vẫn hạ hạng / rút hạn được vì bản ký sau luôn có issued_at mới hơn.
    const QDateTime incoming = parseIso(payload.value(QStringLiteral("issued_at")).toString());
    const QDateTime mark = issuedWatermark();
    if (!incoming.isValid() || (mark.isValid() && incoming < mark)) {
        const QString msg = QStringLiteral("Giấy phép ký trước bản đã nhận — bỏ qua");
        if (errorOut) *errorOut = msg;
        qWarning() << "[License]" << msg;
        return false;
    }

    const QString path = licenseFilePath();
    QString mkErr;
    AppPaths::instance().ensureDirectoryExists(QFileInfo(path).absolutePath(), &mkErr);

    // QSaveFile: ghi ra tệp tạm rồi đổi tên nguyên tử. Mất điện giữa chừng sẽ
    // không để lại giấy phép cụt làm máy tự khoá mình.
    QSaveFile out(path);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Text)) {
        const QString msg = QStringLiteral("Không ghi được tệp giấy phép: %1").arg(out.errorString());
        if (errorOut) *errorOut = msg;
        qCritical() << "[License]" << msg;
        return false;
    }
    out.write(token.trimmed().toLatin1());
    if (!out.commit()) {
        const QString msg = QStringLiteral("Không lưu được tệp giấy phép");
        if (errorOut) *errorOut = msg;
        qCritical() << "[License]" << msg;
        return false;
    }

    applyPayload(payload, token.trimmed());
    raiseIssuedWatermark(incoming);
    rememberSeenTime();
    qInfo() << "[License] Đã nhận giấy phép" << serial()
            << "| tier:" << deviceTier() << "| hạn:" << notAfterText();
    if (errorOut) errorOut->clear();
    return m_valid;
}

// ── Thu hồi ──────────────────────────────────────────────────────────────────

bool LicenseManager::applyRevocation(const QString &token, QString *errorOut)
{
    QVariantMap payload;
    QString err;
    // Phiếu phải có chữ ký admin VÀ đúng HWID máy này — Worker hay D1 bị chiếm
    // cũng không tự tạo được phiếu để khoá máy.
    const Result r = verifyToken(token, m_hwid, &payload, &err);
    if (r != Ok || tokenType(payload) != QLatin1String("revoke")) {
        if (errorOut) *errorOut = r != Ok ? err : QStringLiteral("Token không phải phiếu thu hồi");
        qWarning() << "[License] Bỏ qua phiếu thu hồi không hợp lệ:" << (r != Ok ? err : QStringLiteral("sai loại"));
        return false;
    }

    const QString ser = payload.value(QStringLiteral("serial")).toString().trimmed();
    if (ser.isEmpty()) {
        if (errorOut) *errorOut = QStringLiteral("Phiếu thu hồi thiếu serial");
        return false;
    }

    QStringList list = revokedSerials();
    if (!list.contains(ser) && m_db) {
        list << ser;
        m_db->setSetting(QLatin1String(kRevokedKey),
                         QString::fromUtf8(QJsonDocument(QJsonArray::fromStringList(list))
                                               .toJson(QJsonDocument::Compact)));
    }

    if (serial() == ser) {
        qWarning() << "[License] Giấy phép" << ser << "đã bị admin thu hồi —"
                   << payload.value(QStringLiteral("reason")).toString();
        QFile::remove(licenseFilePath());
        resetState(Revoked, QStringLiteral("Giấy phép đã bị thu hồi"));
    }
    if (errorOut) errorOut->clear();
    return true;
}

bool LicenseManager::clear()
{
    const QString path = licenseFilePath();
    bool ok = true;
    if (QFile::exists(path)) ok = QFile::remove(path);
    resetState(NoFile, QStringLiteral("Chưa kích hoạt"));
    return ok;
}

// ── Nội bộ ───────────────────────────────────────────────────────────────────

void LicenseManager::applyPayload(const QVariantMap &payload, const QString &token)
{
    m_payload = payload;
    m_token   = token;
    m_notAfter = parseIso(payload.value(QStringLiteral("not_after")).toString());

    const QDateTime now = effectiveNow();
    const int graceDays = payload.value(QStringLiteral("grace_days"), 0).toInt();

    if (!m_notAfter.isValid()) {
        // Không khai hạn → coi là vô thời hạn. Chỉ admin mới ký được như vậy.
        m_valid = true;
        m_inGrace = false;
        m_lastResult = Ok;
        m_statusMessage = QStringLiteral("Đã kích hoạt · không giới hạn");
    } else if (now <= m_notAfter) {
        m_valid = true;
        m_inGrace = false;
        m_lastResult = Ok;
        m_statusMessage = QStringLiteral("Đã kích hoạt");
    } else if (graceDays > 0 && now <= m_notAfter.addDays(graceDays)) {
        // Ân hạn: máy hết hạn nhưng đang offline dài ngày vẫn phải chụp được.
        // Thà cho chạy thêm ít hôm còn hơn khoá giữa buổi tiệc của khách.
        m_valid = true;
        m_inGrace = true;
        m_lastResult = Ok;
        m_statusMessage = QStringLiteral("Giấy phép đã hết hạn — đang trong thời gian gia hạn");
    } else {
        m_valid = false;
        m_inGrace = false;
        m_lastResult = Expired;
        m_statusMessage = QStringLiteral("Giấy phép đã hết hạn");
    }

    emit licenseChanged();
}

void LicenseManager::resetState(Result result, const QString &message)
{
    m_payload.clear();
    m_token.clear();
    m_notAfter = QDateTime();
    m_valid    = false;
    m_inGrace  = false;
    m_lastResult = result;
    m_statusMessage = message;
    emit licenseChanged();
}

QString LicenseManager::notAfterText() const
{
    if (!m_notAfter.isValid()) return QString();   // QML hiểu rỗng = không giới hạn
    return m_notAfter.toLocalTime().toString(QStringLiteral("dd/MM/yyyy"));
}

int LicenseManager::daysRemaining() const
{
    if (!m_notAfter.isValid()) return -1;          // -1 = không giới hạn
    return static_cast<int>(effectiveNow().daysTo(m_notAfter));
}
