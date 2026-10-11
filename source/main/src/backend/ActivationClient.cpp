#include "ActivationClient.h"
#include "ConfigManager.h"
#include "LicenseManager.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QDebug>

namespace {
// Đồng bộ định kỳ: đủ để gia hạn / thu hồi tới máy trong ngày, không gây tải.
constexpr int kSyncIntervalMs = 6 * 60 * 60 * 1000;
}

ActivationClient::ActivationClient(ConfigManager *config, LicenseManager *license,
                                   QObject *parent)
    : QObject(parent), m_config(config), m_license(license)
{
    m_syncTimer.setInterval(kSyncIntervalMs);
    connect(&m_syncTimer, &QTimer::timeout, this, &ActivationClient::syncStatus);
    m_syncTimer.start();
}

QNetworkRequest ActivationClient::makeRequest(const QString &path) const
{
    QNetworkRequest r{QUrl(m_config->cloudApiBaseUrl() + QStringLiteral("/v1/machine/license") + path)};
    r.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    r.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    r.setTransferTimeout(15000);
    return r;
}

// Route giấy phép cần token máy — chỉ có sau khi đăng nhập studio.
bool ActivationClient::canCallServer() const
{
    return m_config && m_license && !m_config->cloudApiBaseUrl().isEmpty()
           && m_config->hasMachineToken();
}

void ActivationClient::setState(bool busy, const QString &message, const QString &errorCode)
{
    m_busy = busy;
    m_message = message;
    m_errorCode = errorCode;
    emit stateChanged();
}

// ── Báo chờ duyệt ────────────────────────────────────────────────────────────

void ActivationClient::requestActivation()
{
    if (!canCallServer()) return;
    QNetworkReply *reply = m_net.post(makeRequest(QStringLiteral("/request")), QByteArray("{}"));
    connect(reply, &QNetworkReply::finished, this, [reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (http >= 200 && http < 300)
            qInfo() << "[Activation] Đã gửi yêu cầu kích hoạt, chờ admin cấp mã";
        else
            qWarning() << "[Activation] Gửi yêu cầu kích hoạt thất bại: HTTP" << http << reply->errorString();
    });
}

// ── Nhập OTP ─────────────────────────────────────────────────────────────────

void ActivationClient::redeemOtp(const QString &otp)
{
    if (m_busy) return;
    const QString code = otp.trimmed();
    if (!QRegularExpression(QStringLiteral("^[0-9]{4}$")).match(code).hasMatch()) {
        setState(false, QStringLiteral("Mã kích hoạt gồm 4 chữ số"), QStringLiteral("invalid_otp_format"));
        emit failed(m_message);
        return;
    }
    if (!m_config || m_config->cloudApiBaseUrl().isEmpty()) {
        setState(false, QStringLiteral("Thiếu cấu hình máy chủ"), QStringLiteral("no_config"));
        emit failed(m_message);
        return;
    }
    if (!m_config->hasMachineToken()) {
        setState(false, QStringLiteral("Đăng nhập studio trước khi kích hoạt máy"), QStringLiteral("not_signed_in"));
        emit failed(m_message);
        return;
    }

    setState(true, QStringLiteral("Đang kích hoạt..."));
    QJsonObject body;
    body["otp"] = code;
    QNetworkReply *reply = m_net.post(makeRequest(QStringLiteral("/redeem")),
                                      QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onRedeemReply(reply); });
}

void ActivationClient::onRedeemReply(QNetworkReply *reply)
{
    reply->deleteLater();
    const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();

    if (o.contains(QStringLiteral("attempts_left")))
        m_attemptsLeft = o.value(QStringLiteral("attempts_left")).toInt();

    const QString token = o.value(QStringLiteral("license")).toString();
    if (http < 200 || http >= 300 || token.isEmpty()) {
        const QString code = o.value(QStringLiteral("error")).toString();
        const QString msg = messageForError(code, o.value(QStringLiteral("message")).toString(), http);
        qWarning() << "[Activation] Nhập mã thất bại: HTTP" << http << code;
        setState(false, msg, code.isEmpty() ? QStringLiteral("http_%1").arg(http) : code);
        emit failed(msg);
        return;
    }

    // Tới đây vẫn CHƯA tin máy chủ: LicenseManager xác minh chữ ký admin + HWID.
    QString err;
    if (!m_license->adopt(token, &err)) {
        qWarning() << "[Activation] Từ chối giấy phép nhận được:" << err;
        const QString msg = QStringLiteral("Giấy phép nhận được không hợp lệ (%1). Liên hệ quản trị viên.").arg(err);
        setState(false, msg, QStringLiteral("license_rejected"));
        emit failed(msg);
        return;
    }

    m_attemptsLeft = -1;
    setState(false, QStringLiteral("Đã kích hoạt"));
    qInfo() << "[Activation] Đã kích hoạt bằng OTP —" << m_license->serial();
    emit activated(m_license->serial());
}

// ── Đồng bộ: thu hồi + gia hạn ───────────────────────────────────────────────

void ActivationClient::syncStatus()
{
    if (m_syncing || !canCallServer()) return;
    m_syncing = true;
    QNetworkReply *reply = m_net.get(makeRequest(QStringLiteral("/status")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        m_syncing = false;
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        // Mất mạng / D1 lỗi / Worker sập: giữ nguyên chữ ký đang có, không làm gì.
        if (!o.value(QStringLiteral("success")).toBool()) return;

        // Thu hồi trước: phiếu phải có chữ ký admin + đúng HWID mới có tác dụng.
        for (const QJsonValue &v : o.value(QStringLiteral("revocations")).toArray())
            m_license->applyRevocation(v.toString());

        const QString token = o.value(QStringLiteral("license")).toString();
        if (token.isEmpty()) return;
        const bool wasValid = m_license->isValid();
        const QString before = m_license->serial();
        QString err;
        // adopt() tự bỏ qua token cũ hơn bản đã nhận (chống phát lại từ D1).
        if (m_license->adopt(token, &err)) {
            if (m_license->serial() != before || !wasValid) {
                qInfo() << "[Activation] Nhận giấy phép mới qua đồng bộ —" << m_license->serial();
                emit activated(m_license->serial());
            }
        } else {
            qWarning() << "[Activation] Bỏ qua giấy phép từ máy chủ:" << err;
        }
    });
}

QString ActivationClient::messageForError(const QString &code, const QString &serverMessage, int http)
{
    if (http == 0)
        return QStringLiteral("Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.");
    if (code == QLatin1String("otp_not_found"))
        return QStringLiteral("Máy chưa có mã kích hoạt. Liên hệ quản trị viên để nhận mã.");
    if (code == QLatin1String("otp_expired"))
        return QStringLiteral("Mã kích hoạt đã hết hạn. Liên hệ quản trị viên để nhận mã mới.");
    if (code == QLatin1String("otp_locked"))
        return QStringLiteral("Nhập sai quá 5 lần, mã đã bị khoá. Liên hệ quản trị viên để nhận mã mới.");
    if (code == QLatin1String("license_not_active"))
        return QStringLiteral("Giấy phép của máy không còn hiệu lực. Liên hệ quản trị viên.");
    if (code == QLatin1String("unauthorized"))
        return QStringLiteral("Phiên đăng nhập studio đã hết hạn. Đăng nhập lại rồi thử lại.");
    if (code == QLatin1String("machine_disabled"))
        return QStringLiteral("Máy này đã bị vô hiệu hoá");
    if (!serverMessage.isEmpty()) return serverMessage;
    return QStringLiteral("Lỗi máy chủ (HTTP %1)").arg(http);
}
