#include "CloudSyncManager.h"
#include "ConfigManager.h"
#include "DatabaseManager.h"
#include "StudioAccount.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QTimer>
#include <QUrl>
#include <QUuid>

// Cache mã dùng lại của studio (JSON) trong app_settings.
static const char *kReusableCacheKey = "cloud_reusable_codes";
static const int kFlushIntervalMs = 30 * 1000;
static const int kCodesRefreshMs  = 10 * 60 * 1000;
static const int kBatch = 20;

CloudSyncManager::CloudSyncManager(ConfigManager *config, DatabaseManager *db,
                                   StudioAccount *account, QObject *parent)
    : QObject(parent)
    , m_config(config)
    , m_db(db)
    , m_account(account)
    , m_net(new QNetworkAccessManager(this))
    , m_flushTimer(new QTimer(this))
    , m_codesTimer(new QTimer(this))
{
    m_flushTimer->setInterval(kFlushIntervalMs);
    connect(m_flushTimer, &QTimer::timeout, this, &CloudSyncManager::flush);
    m_flushTimer->start();

    m_codesTimer->setInterval(kCodesRefreshMs);
    connect(m_codesTimer, &QTimer::timeout, this, &CloudSyncManager::refreshReusableCodes);
    m_codesTimer->start();

    if (m_account) {
        connect(m_account, &StudioAccount::signedIn, this, [this]() {
            // Studio mới đăng nhập: bỏ cache mã của studio cũ, tải lại và đẩy dữ liệu chờ.
            m_db->setSetting(kReusableCacheKey, QString());
            refreshReusableCodes();
            flush();
        });
        connect(m_account, &StudioAccount::signedOut, this, [this]() {
            m_db->setSetting(kReusableCacheKey, QString());
        });
    }
}

bool CloudSyncManager::canSend() const
{
    return m_config && m_account && m_account->loggedIn() && !m_config->cloudApiBaseUrl().isEmpty();
}

void CloudSyncManager::enqueueSession(const QString &sessionId, const QJsonObject &payload)
{
    if (sessionId.isEmpty()) return;
    const QString path = "/v1/machine/sessions/" + QString::fromUtf8(QUrl::toPercentEncoding(sessionId));
    m_db->outboxEnqueue("session", "session:" + sessionId, "PUT", path,
                        QJsonDocument(payload).toJson(QJsonDocument::Compact), true);
    QTimer::singleShot(0, this, &CloudSyncManager::flush);
}

void CloudSyncManager::enqueueRevenue(const QString &revenueId, const QJsonObject &payload)
{
    if (revenueId.isEmpty()) return;
    m_db->outboxEnqueue("revenue", "revenue:" + revenueId, "POST", "/v1/machine/revenue",
                        QJsonDocument(payload).toJson(QJsonDocument::Compact), false);
    QTimer::singleShot(0, this, &CloudSyncManager::flush);
}

void CloudSyncManager::enqueueCodeUse(const QString &useId, const QJsonObject &usePayload)
{
    if (useId.isEmpty()) return;
    QJsonObject body;
    body["uses"] = QJsonArray{usePayload};
    m_db->outboxEnqueue("code_use", "code_use:" + useId, "POST", "/v1/machine/codes/uses",
                        QJsonDocument(body).toJson(QJsonDocument::Compact), false);
    QTimer::singleShot(0, this, &CloudSyncManager::flush);
}

void CloudSyncManager::flush()
{
    if (m_sending || !canSend()) return;
    sendNext();
}

// Gửi tuần tự từng bản ghi (giữ thứ tự: phiên trước doanh thu của phiên đó).
void CloudSyncManager::sendNext()
{
    if (!canSend()) { m_sending = false; return; }
    const QVariantList rows = m_db->outboxPending(1);
    if (rows.isEmpty()) { m_sending = false; return; }
    m_sending = true;

    const QVariantMap row = rows.first().toMap();
    const qint64 id = row.value("id").toLongLong();
    const QString method = row.value("method").toString();
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + row.value("path").toString()));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(15000);
    const QByteArray body = row.value("payload").toString().toUtf8();

    QNetworkReply *reply = method == "PUT" ? m_net->put(req, body) : m_net->post(req, body);
    connect(reply, &QNetworkReply::finished, this, [this, reply, id]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();

        if (http >= 200 && http < 300) {
            m_db->outboxRemove(id);
            QTimer::singleShot(0, this, &CloudSyncManager::sendNext);
            return;
        }
        if (http == 401) {
            // Token máy hết hiệu lực -> giữ nguyên hàng đợi, đăng nhập lại sẽ gửi tiếp.
            m_sending = false;
            if (m_account) m_account->handleUnauthorized();
            return;
        }
        if (http >= 400 && http < 500 && http != 408 && http != 429) {
            // Lỗi dữ liệu: đánh dấu failed để không kẹt cả hàng đợi, giữ lại để tra cứu.
            qWarning() << "[CloudSync] Rejected outbox item" << id << "HTTP" << http << obj.value("error").toString();
            m_db->outboxMarkFailed(id, QString("HTTP %1 %2").arg(http).arg(obj.value("error").toString()), true);
            QTimer::singleShot(0, this, &CloudSyncManager::sendNext);
            return;
        }
        // Mất mạng / 5xx / 429: dừng, lần flush sau (30s) thử lại.
        m_db->outboxMarkFailed(id, http == 0 ? reply->errorString() : QString("HTTP %1").arg(http), false);
        m_sending = false;
    });
}

void CloudSyncManager::refreshReusableCodes()
{
    if (!canSend()) return;
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + "/v1/machine/codes/reusable"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(15000);
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (http == 401) { if (m_account) m_account->handleUnauthorized(); return; }
        if (http < 200 || http >= 300) return;   // giữ cache cũ
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        const QJsonArray codes = obj.value("codes").toArray();
        m_db->setSetting(kReusableCacheKey, QString::fromUtf8(QJsonDocument(codes).toJson(QJsonDocument::Compact)));
        qDebug() << "[CloudSync] Cached" << codes.size() << "reusable codes";
    });
}

void CloudSyncManager::checkCode(const QString &code)
{
    if (!canSend()) {
        QVariantMap r;
        r["ok"] = false;
        r["code"] = code;
        r["error"] = "not_signed_in";
        r["message"] = QStringLiteral("Máy chưa đăng nhập studio");
        emit codeCheckFinished(r);
        return;
    }

    QJsonObject body;
    body["code"] = code;

    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + "/v1/machine/codes/check"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(8000);
    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, code]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        QVariantMap r;
        r["code"] = code;

        if (http >= 200 && http < 300) {
            r["ok"] = true;
            r["code_id"] = obj.value("code_id").toString();
            r["minutes"] = obj.value("minutes").toInt();
            r["price_vnd"] = obj.value("price_vnd").toInt();
            r["kind"] = obj.value("kind").toString();
            // Mã cấp cho lịch đặt trên web: server gửi kèm tên khách + giờ hẹn để màn chào khách.
            const QJsonObject booking = obj.value("booking").toObject();
            if (!booking.isEmpty()) {
                const int start = booking.value("start_minute").toInt();
                r["booking_customer"] = booking.value("customer_name").toString();
                r["booking_time"] = QStringLiteral("%1:%2")
                    .arg(start / 60, 2, 10, QChar('0'))
                    .arg(start % 60, 2, 10, QChar('0'));
                r["booking_room"] = booking.value("room_name").toString();
            }
        } else {
            if (http == 401 && m_account) m_account->handleUnauthorized();
            r["ok"] = false;
            r["error"] = obj.value("error").toString();
            if (http == 0 || http >= 500)
                r["message"] = QStringLiteral("Không kết nối được máy chủ");
            else
                r["message"] = redeemMessage(obj.value("error").toString(), obj.value("message").toString());
        }
        emit codeCheckFinished(r);
    });
}

void CloudSyncManager::redeemCode(const QString &code, const QString &sessionId)
{
    if (m_redeeming) return;
    if (!canSend()) {
        QVariantMap r;
        r["ok"] = false;
        r["error"] = "not_signed_in";
        r["message"] = QStringLiteral("Máy chưa đăng nhập studio");
        emit codeRedeemFinished(r);
        return;
    }
    const QString useId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    QJsonObject body;
    body["code"] = code;
    body["session_id"] = sessionId;
    body["use_id"] = useId;

    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + "/v1/machine/codes/redeem"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(10000);
    m_redeeming = true;
    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, code, sessionId]() {
        reply->deleteLater();
        m_redeeming = false;
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        QVariantMap r;

        if (http >= 200 && http < 300) {
            r["ok"] = true;
            r["code"] = code;
            r["use_id"] = obj.value("use_id").toString();
            r["minutes"] = obj.value("minutes").toInt();
            r["price_vnd"] = obj.value("price_vnd").toInt();
            r["kind"] = obj.value("kind").toString();
            r["source"] = "online";
        } else if (http == 0 || http >= 500) {
            // Không tới được server: chỉ mã dùng lại trong cache được nhận.
            r = acceptOfflineReusable(code, sessionId);
        } else {
            if (http == 401 && m_account) m_account->handleUnauthorized();
            r["ok"] = false;
            r["error"] = obj.value("error").toString();
            r["message"] = redeemMessage(obj.value("error").toString(), obj.value("message").toString());
        }
        emit codeRedeemFinished(r);
    });
}

QVariantMap CloudSyncManager::acceptOfflineReusable(const QString &code, const QString &sessionId)
{
    QVariantMap r;
    const QJsonArray codes = QJsonDocument::fromJson(m_db->getSetting(kReusableCacheKey, "[]").toUtf8()).array();
    const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    for (const QJsonValue &v : codes) {
        const QJsonObject c = v.toObject();
        if (c.value("code").toString() != code) continue;
        const QString from = c.value("valid_from").toString();
        const QString until = c.value("valid_until").toString();
        if ((!from.isEmpty() && now < from) || (!until.isEmpty() && now > until)) break;

        const QString useId = QUuid::createUuid().toString(QUuid::WithoutBraces);
        QJsonObject use;
        use["use_id"] = useId;
        use["code"] = code;
        use["session_id"] = sessionId;
        use["used_at"] = now;
        enqueueCodeUse(useId, use);

        r["ok"] = true;
        r["code"] = code;
        r["use_id"] = useId;
        r["minutes"] = c.value("minutes").toInt();
        r["price_vnd"] = c.value("price_vnd").toInt();
        r["kind"] = "reusable";
        r["source"] = "offline";
        qDebug() << "[CloudSync] Accepted reusable code offline:" << code;
        return r;
    }
    r["ok"] = false;
    r["error"] = "offline";
    r["message"] = QStringLiteral("Không kết nối được máy chủ. Mã này cần có mạng để sử dụng.");
    return r;
}

QString CloudSyncManager::redeemMessage(const QString &error, const QString &serverMessage)
{
    if (error == "code_invalid")       return QStringLiteral("Mã không đúng");
    if (error == "code_used")          return QStringLiteral("Mã đã được sử dụng");
    if (error == "code_expired")       return QStringLiteral("Mã đã hết hạn");
    if (error == "code_not_yet_valid") return QStringLiteral("Mã chưa tới thời gian sử dụng");
    if (error == "invalid_code")       return QStringLiteral("Mã gồm đúng 4 chữ số");
    if (error == "unauthorized")       return QStringLiteral("Phiên đăng nhập studio đã hết, vui lòng đăng nhập lại");
    if (!serverMessage.isEmpty())      return serverMessage;
    return QStringLiteral("Không kiểm tra được mã");
}
