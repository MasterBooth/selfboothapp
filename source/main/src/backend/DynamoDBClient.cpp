#include "DynamoDBClient.h"
#include "ConfigManager.h"
#include <QDebug>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QUrl>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QBuffer>
#include <QCryptographicHash>
#include <QEventLoop>
#include <QTimer>
#include <QJsonArray>

// ─────────────────────────────────────────────────────────────────────────────
// DynamoDBClient — sau migration: REST client tới Cloudflare Worker (+ D1).
// Giữ nguyên API công khai + signals; chỉ thay phần vận chuyển (bỏ SigV4 AWS).
// ─────────────────────────────────────────────────────────────────────────────

DynamoDBClient::DynamoDBClient(ConfigManager *config, QObject *parent)
    : QObject(parent)
    , m_config(config)
{
    m_networkManager = new QNetworkAccessManager(this);
    connect(m_networkManager, &QNetworkAccessManager::finished, this, &DynamoDBClient::onNetworkReply);
}

DynamoDBClient::~DynamoDBClient() {
}

QNetworkRequest DynamoDBClient::buildRequest(const QString &path) const {
    QString base = m_config->cloudApiBaseUrl();
    QNetworkRequest req(QUrl(base + path));
    req.setRawHeader("Content-Type", "application/json");
    req.setRawHeader("Authorization",
                     QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(15000);
    return req;
}

void DynamoDBClient::sendRequest(const QString &verb, const QString &path,
                                 const QJsonObject &payload, const QString &operation,
                                 const QString &contextId) {
    if (!m_config || !m_config->isValid()) {
        emit operationError("Configuration not loaded");
        return;
    }

    QNetworkRequest req = buildRequest(path);
    QByteArray body = payload.isEmpty() ? QByteArray()
                                        : QJsonDocument(payload).toJson(QJsonDocument::Compact);

    qDebug() << "[CloudAPI]" << verb << path << (body.isEmpty() ? "" : QString::fromUtf8(body));

    QNetworkReply *reply = nullptr;
    if (verb == "GET") {
        reply = m_networkManager->get(req);
    } else if (verb == "POST") {
        reply = m_networkManager->post(req, body);
    } else if (verb == "PUT") {
        reply = m_networkManager->put(req, body);
    } else {
        // DELETE / khác: dùng sendCustomRequest
        QBuffer *buf = new QBuffer;
        buf->setData(body);
        buf->open(QIODevice::ReadOnly);
        reply = m_networkManager->sendCustomRequest(req, verb.toUtf8(), buf);
        buf->setParent(reply);
    }
    if (reply) {
        reply->setProperty("cloudOperation", operation);
        reply->setProperty("cloudHwid", m_currentHwid);
        reply->setProperty("cloudContextId", contextId);
    }
}

void DynamoDBClient::getMachine(const QString &hwid) {
    m_currentHwid = hwid;
    sendRequest("GET", QString("/machine/%1").arg(hwid), QJsonObject(), "GetItem");
}

void DynamoDBClient::registerMachine(const QString &hwid, const QString &deviceName,
                                     const QString &ownerEmail, const QString &ownerName,
                                     const QString &brand) {
    m_currentHwid = hwid;
    QJsonObject payload;
    payload["device_name"] = deviceName;
    if (!ownerEmail.isEmpty()) payload["owner_email"] = ownerEmail;
    if (!ownerName.isEmpty())  payload["owner_name"]  = ownerName;
    if (!brand.isEmpty())      payload["brand"]       = brand;
    sendRequest("POST", QString("/machine/%1").arg(hwid), payload, "PutItem");
}

void DynamoDBClient::claimMachine(const QString &hwid, const QString &ownerEmail,
                                  const QString &ownerName, const QString &brand) {
    m_currentHwid = hwid;
    QJsonObject payload;
    if (!ownerEmail.isEmpty()) payload["owner_email"] = ownerEmail;
    if (!ownerName.isEmpty())  payload["owner_name"]  = ownerName;
    if (!brand.isEmpty())      payload["brand"]       = brand;
    if (payload.isEmpty()) return;
    sendRequest("PATCH", QString("/machine/%1").arg(hwid), payload, "ClaimMachine");
}

void DynamoDBClient::syncEventData(const QString &hwid, int eventId, const QString &eventName,
                                   int totalPhotos, int printsCut, int printsNoCut) {
    Q_UNUSED(hwid)
    Q_UNUSED(eventName)
    Q_UNUSED(totalPhotos)
    Q_UNUSED(printsCut)
    Q_UNUSED(printsNoCut)
    // API selfboothvn hien tai khong con endpoint tong hop /machine/{hwid}/event.
    // Phien chup va doanh thu duoc dong bo qua cac route /v1 rieng; giu request
    // cu se roi sang web admin va tao 404 HTML trong log.
    qDebug() << "[CloudAPI] Skip legacy event stats sync for event" << eventId;
}

void DynamoDBClient::syncSessionData(const QString &hwid, int eventId, const QString &sessionId,
                                     const QString &printerType, int photosCaptured,
                                     int printsCut, int printsNoCut, const QString &status,
                                     int expectedPhotos, const QString &captureStartedAt,
                                     const QString &endedAt, const QString &statusUpdatedAt,
                                     const QString &failureCode, const QString &failureMessage,
                                     int cameraErrorCount, bool hadCameraError, int statusVersion) {
    m_currentHwid = hwid;
    QJsonObject payload;
    payload["event_id"]        = eventId;
    payload["session_id"]      = sessionId;
    payload["printer_type"]    = printerType;
    payload["photos_captured"] = photosCaptured;
    payload["prints_cut"]      = printsCut;
    payload["prints_nocut"]    = printsNoCut;
    payload["total_prints"]    = printsCut + printsNoCut;
    payload["status"]          = status;
    payload["expected_photos"] = expectedPhotos;
    payload["capture_started_at"] = captureStartedAt;
    payload["ended_at"] = endedAt;
    payload["status_updated_at"] = statusUpdatedAt;
    payload["failure_code"] = failureCode;
    payload["failure_message"] = failureMessage;
    payload["camera_error_count"] = cameraErrorCount;
    payload["had_camera_error"] = hadCameraError;
    payload["status_version"] = statusVersion;
    sendRequest("PUT", QString("/machine/%1/session").arg(hwid), payload,
                "PutSessionItem", sessionId);
}

void DynamoDBClient::syncRevenueRecord(const QString &hwid, int eventId, const QString &eventName,
                                       const QString &sessionId, const QString &recordedAt,
                                       int printCount, int amountRequired,
                                       int cashReceived, int transferAmount, int changeAmount,
                                       const QString &paymentMethod, int employeeId,
                                       const QString &shift, const QString &source,
                                       int receivedAmount, int voucherAmount, const QString &note) {
    m_currentHwid = hwid;
    const QString normalizedSource = source.isEmpty() ? QStringLiteral("session") : source;
    const QString revenueKey = QStringLiteral("%1|%2|%3|%4|%5")
        .arg(hwid)
        .arg(eventId)
        .arg(sessionId)
        .arg(normalizedSource)
        .arg(recordedAt);
    const QString revenueId = QString::fromLatin1(
        QCryptographicHash::hash(revenueKey.toUtf8(), QCryptographicHash::Sha256).toHex());
    QJsonObject payload;
    payload["revenue_id"]      = revenueId;
    payload["event_id"]        = eventId;
    payload["event_name"]      = eventName;
    payload["session_id"]      = sessionId;
    payload["recorded_at"]     = recordedAt;
    payload["print_count"]     = printCount;
    payload["amount_required"] = amountRequired;
    payload["cash_received"]   = cashReceived;
    payload["transfer_amount"] = transferAmount;
    payload["change_amount"]   = changeAmount;
    payload["payment_method"]  = paymentMethod;
    payload["employee_id"]     = employeeId;
    payload["shift"]           = shift;
    payload["source"]          = normalizedSource;
    payload["received_amount"] = receivedAmount;
    payload["voucher_amount"]  = voucherAmount;
    payload["note"]            = note;
    sendRequest("POST", QString("/machine/%1/revenue").arg(hwid), payload, "PutRevenueItem");
}

// ── Voucher cloud ────────────────────────────────────────────────────────────

QVariantMap DynamoDBClient::blockingRequest(const QString &verb, const QString &path,
                                            const QJsonObject &payload) {
    QVariantMap result;
    if (!m_config || !m_config->isValid()) {
        result["network_error"] = true;
        result["error"] = "Configuration not loaded";
        return result;
    }
    // QNAM riêng để KHÔNG kích hoạt slot onNetworkReply (vốn dành cho luồng async).
    QNetworkAccessManager nam;
    QNetworkRequest req = buildRequest(path);
    const QByteArray body = payload.isEmpty() ? QByteArray()
                                              : QJsonDocument(payload).toJson(QJsonDocument::Compact);
    qDebug() << "[CloudAPI/sync]" << verb << path << (body.isEmpty() ? "" : QString::fromUtf8(body));

    QNetworkReply *reply = nullptr;
    if (verb == "GET")       reply = nam.get(req);
    else if (verb == "POST") reply = nam.post(req, body);
    else {
        QBuffer buf; buf.setData(body); buf.open(QIODevice::ReadOnly);
        reply = nam.sendCustomRequest(req, verb.toUtf8(), &buf);
    }

    // Chờ đồng bộ với timeout cứng (transferTimeout=15s đã set; thêm guard 16s).
    QEventLoop loop;
    QTimer guard; guard.setSingleShot(true);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    guard.start(16000);
    loop.exec();

    if (!reply->isFinished()) {            // timeout → coi như lỗi mạng
        reply->abort();
        result["network_error"] = true;
        result["error"] = "Hết thời gian chờ máy chủ";
        reply->deleteLater();
        return result;
    }

    const int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data = reply->readAll();
    const QNetworkReply::NetworkError netErr = reply->error();
    const QString errStr = reply->errorString();
    reply->deleteLater();

    const QJsonObject obj = QJsonDocument::fromJson(data).object();
    for (auto it = obj.constBegin(); it != obj.constEnd(); ++it)
        result[it.key()] = it.value().toVariant();
    result["http"] = statusCode;
    // Lỗi mạng thực sự (không phải HTTP 4xx do nghiệp vụ) → cho phép fallback local.
    result["network_error"] = (netErr != QNetworkReply::NoError && statusCode == 0);
    if (statusCode == 0 && !result.contains("error"))
        result["error"] = errStr;
    return result;
}

QVariantMap DynamoDBClient::validateVoucherCloud(const QString &hwid, const QString &code) {
    return blockingRequest("GET",
        QString("/machine/%1/vouchers/%2").arg(hwid, QString(QUrl::toPercentEncoding(code))),
        QJsonObject());
}

QVariantMap DynamoDBClient::redeemVoucherCloud(const QString &hwid, const QString &code,
                                               const QString &sessionId, int empId, int paidAmount) {
    QJsonObject payload;
    payload["session_id"]  = sessionId;
    payload["emp_id"]      = empId;
    payload["paid_amount"] = paidAmount;
    return blockingRequest("POST",
        QString("/machine/%1/vouchers/%2/redeem").arg(hwid, QString(QUrl::toPercentEncoding(code))),
        payload);
}

QVariantMap DynamoDBClient::deleteVoucherCloud(const QString &hwid, const QString &code) {
    return blockingRequest("DELETE",
        QString("/machine/%1/vouchers/%2").arg(hwid, QString(QUrl::toPercentEncoding(code))),
        QJsonObject());
}

void DynamoDBClient::deleteVoucherCloudAsync(const QString &hwid, const QString &code, const QString &contextId) {
    const QString normalized = code.toUpper();
    if (!m_config || !m_config->isValid()) {
        emit voucherDeleteReady(normalized, contextId, false, true, QStringLiteral("Configuration not loaded"));
        return;
    }
    if (hwid.isEmpty() || normalized.isEmpty()) {
        emit voucherDeleteReady(normalized, contextId, false, false, QStringLiteral("Missing HWID or voucher code"));
        return;
    }
    m_currentHwid = hwid;
    const QString path = QString("/machine/%1/vouchers/%2")
        .arg(hwid, QString(QUrl::toPercentEncoding(normalized)));
    sendRequest("DELETE", path, QJsonObject(), "DeleteVoucher", contextId + "|" + normalized);
}

QVariantMap DynamoDBClient::pushVouchersCloudSync(const QString &hwid, const QVariantList &vouchers) {
    if (vouchers.isEmpty()) { QVariantMap r; r["success"] = true; r["pushed"] = 0; return r; }
    QJsonArray arr;
    for (const QVariant &v : vouchers)
        arr.append(QJsonObject::fromVariantMap(v.toMap()));
    QJsonObject payload;
    payload["vouchers"] = arr;
    return blockingRequest("POST", QString("/machine/%1/vouchers").arg(hwid), payload);
}

QVariantMap DynamoDBClient::generateVouchersCloud(const QString &hwid, const QString &type, int value, int count,
                                                  const QString &validFrom, const QString &validUntil,
                                                  const QString &note, const QString &createdBy) {
    QJsonObject payload;
    payload["type"]        = type;
    payload["value"]       = value;
    payload["count"]       = count;
    payload["valid_from"]  = validFrom;
    payload["valid_until"] = validUntil;
    payload["note"]        = note;
    payload["created_by"]  = createdBy;
    return blockingRequest("POST", QString("/machine/%1/vouchers/generate").arg(hwid), payload);
}

// Kéo danh sách voucher toàn studio (đồng bộ với web) — ASYNC để không chặn UI khi poll.
// Kết quả trả qua signal voucherListReady(data, ok). filter: "all" | "unused" | "used".
void DynamoDBClient::fetchVoucherList(const QString &hwid, const QString &filter) {
    m_currentHwid = hwid;
    QString path = QString("/machine/%1/vouchers").arg(hwid);
    if (filter == "unused")    path += "?status=unused";
    else if (filter == "used") path += "?status=used";
    sendRequest("GET", path, QJsonObject(), "ListVouchers");
}

// Đọc 3 danh sách preset (ghi chú / giá gợi ý / thời gian hiệu lực) — BLOCKING, gọi 1 lần
// khi mở tab (hiếm). Trả {notes, prices, durations, network_error}.
QVariantMap DynamoDBClient::voucherPresetsCloud(const QString &hwid) {
    QVariantMap out;
    const QVariantMap notes = blockingRequest("GET", QString("/machine/%1/voucher-notes").arg(hwid), QJsonObject());
    const QVariantMap prices = blockingRequest("GET", QString("/machine/%1/voucher-prices").arg(hwid), QJsonObject());
    const QVariantMap durs = blockingRequest("GET", QString("/machine/%1/voucher-durations").arg(hwid), QJsonObject());
    out["notes"]     = notes.value("data").toList();
    out["prices"]    = prices.value("data").toList();
    out["durations"] = durs.value("data").toList();
    out["network_error"] = notes.value("network_error").toBool()
                        || prices.value("network_error").toBool()
                        || durs.value("network_error").toBool();
    return out;
}

void DynamoDBClient::onNetworkReply(QNetworkReply *reply) {
    const QString operation = reply->property("cloudOperation").toString();
    const QString requestHwid = reply->property("cloudHwid").toString();
    int statusCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    QByteArray responseData = reply->readAll();
    QNetworkReply::NetworkError netErr = reply->error();
    QString errStr = reply->errorString();
    reply->deleteLater();

    QJsonObject obj = QJsonDocument::fromJson(responseData).object();

    // Danh sách voucher (poll nền): tự xử lý cả thành công lẫn lỗi → không phát
    // operationError (tránh popup lỗi mỗi lần mất mạng), báo qua voucherListReady(ok).
    if (operation == "ListVouchers") {
        const bool ok = (netErr == QNetworkReply::NoError && statusCode >= 200
                         && statusCode < 300 && obj.value("success").toBool());
        emit voucherListReady(obj.value("data").toArray().toVariantList(), ok);
        return;
    }

    // Lỗi mạng / HTTP != 2xx → operationError (online validation bắt buộc).
    if (operation == "DeleteVoucher") {
        const QString packedContext = reply->property("cloudContextId").toString();
        QString contextId = packedContext;
        QString code;
        const int sep = packedContext.lastIndexOf('|');
        if (sep >= 0) {
            contextId = packedContext.left(sep);
            code = packedContext.mid(sep + 1);
        }
        const bool httpOk = (statusCode >= 200 && statusCode < 300);
        const bool success = (netErr == QNetworkReply::NoError && httpOk && obj.value("success").toBool());
        const bool networkError = (netErr != QNetworkReply::NoError && statusCode == 0);
        QString msg = obj.contains("error") ? obj.value("error").toString() : errStr;
        if (!success && msg.isEmpty()) msg = QString("HTTP %1").arg(statusCode);
        emit voucherDeleteReady(code, contextId, success, networkError, msg);
        return;
    }
    if (netErr != QNetworkReply::NoError || statusCode < 200 || statusCode >= 300) {
        QString msg = obj.contains("error") ? obj["error"].toString() : errStr;
        qCritical() << "[CloudAPI] Error (HTTP" << statusCode << "):" << msg
                    << "| body:" << responseData;
        emit operationError(msg.isEmpty() ? QString("HTTP %1").arg(statusCode) : msg);
        return;
    }

    if (operation == "GetItem") {
        // GET /machine/:hwid → { success, found, machine? }
        if (obj.value("found").toBool() && obj.contains("machine")) {
            QJsonObject m = obj["machine"].toObject();
            QVariantMap itemData;
            for (auto it = m.constBegin(); it != m.constEnd(); ++it)
                itemData[it.key()] = it.value().toVariant();
            qDebug() << "[CloudAPI] Machine found:" << requestHwid
                     << "| activate:" << itemData.value("activate").toBool();
            emit machineFound(requestHwid, itemData);
        } else {
            qDebug() << "[CloudAPI] Machine not found:" << m_currentHwid;
            emit machineNotFound(requestHwid);
        }
    } else if (operation == "PutItem") {
        qDebug() << "[CloudAPI] Machine registered:" << m_currentHwid;
        emit machineRegistered(requestHwid);
    } else if (operation == "PutEventEventItem") {
        qDebug() << "[CloudAPI] Event data synced for HWID:" << m_currentHwid;
    } else if (operation == "PutSessionItem") {
        qDebug() << "[CloudAPI] Session data synced for HWID:" << m_currentHwid;
    } else if (operation == "PutRevenueItem") {
        qDebug() << "[CloudAPI] Revenue record synced for HWID:" << m_currentHwid;
    } else {
        qDebug() << "[CloudAPI] Operation" << operation << "completed.";
    }
}
