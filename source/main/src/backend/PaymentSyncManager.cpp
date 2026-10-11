#include "PaymentSyncManager.h"
#include "ConfigManager.h"
#include "EventManager.h"
#include "MachineAuthenticator.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

PaymentSyncManager::PaymentSyncManager(ConfigManager *config, QObject *parent)
    : QObject(parent), m_config(config) {
    m_allowedKeys = QSet<QString>{
        QStringLiteral("payment_enabled"),
        QStringLiteral("payment_provider"),
        QStringLiteral("payment_bank_id"),
        QStringLiteral("payment_account_no"),
        QStringLiteral("payment_account_name"),
        QStringLiteral("payment_sepay_key"),
        QStringLiteral("payment_va_enabled"),
        QStringLiteral("payment_va_account_no"),
        QStringLiteral("payment_payos_client_id"),
        QStringLiteral("payment_payos_api_key"),
        QStringLiteral("payment_payos_checksum_key"),
        QStringLiteral("payment_payos_return_url"),
        QStringLiteral("payment_payos_cancel_url"),
        QStringLiteral("bank_transfer_enabled"),
        QStringLiteral("cash_payment_enabled"),
        QStringLiteral("cash_payment_code_enabled"),
        QStringLiteral("voucher_enabled"),
        QStringLiteral("pricing_by_category_enabled"),
        QStringLiteral("print_options_cut"),
        QStringLiteral("print_options_nocut"),
        QStringLiteral("print_option4_cut_enabled"),
        QStringLiteral("print_option4_nocut_enabled"),
    };
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &PaymentSyncManager::poll);
}

void PaymentSyncManager::setEventManager(EventManager *eventManager) {
    m_eventManager = eventManager;
}

void PaymentSyncManager::setMachineAuthenticator(MachineAuthenticator *machineAuth) {
    m_machineAuth = machineAuth;
}

void PaymentSyncManager::start(int intervalMs) {
    m_timer.start(qMax(10000, intervalMs));
    QTimer::singleShot(21000, this, &PaymentSyncManager::poll);
}

QString PaymentSyncManager::currentHwid() const {
    return m_machineAuth ? m_machineAuth->hwid().trimmed().toUpper() : QString();
}

QNetworkRequest PaymentSyncManager::request(const QString &path) const {
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(20000);
    return req;
}

void PaymentSyncManager::poll() {
    if (m_polling || m_busy || !m_config || !m_config->isValid() || !m_eventManager) return;
    const QString hwid = currentHwid();
    if (hwid.isEmpty()) return;

    m_polling = true;
    const QString path = QStringLiteral("/machine/%1/payment-jobs?status=pending")
        .arg(QString::fromUtf8(QUrl::toPercentEncoding(hwid)));
    QNetworkReply *reply = m_net.get(request(path));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_polling = false;
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const bool ok = reply->error() == QNetworkReply::NoError && http >= 200 && http < 300;
        reply->deleteLater();
        if (!ok) return;
        const QJsonArray arr = QJsonDocument::fromJson(body).object().value(QStringLiteral("data")).toArray();
        for (const QJsonValue &v : arr) {
            const QJsonObject job = v.toObject();
            if (!job.value(QStringLiteral("id")).toString().isEmpty()) m_jobs.enqueue(job);
        }
        processNext();
    });
}

int PaymentSyncManager::eventIdForKey(const QString &eventKey) const {
    const QString key = eventKey.trimmed().toLower();
    if (key == QStringLiteral("studio2")) return m_eventManager->getOrCreateStudioEvent(QStringLiteral("studio2"));
    if (key == QStringLiteral("selfbooth")) return m_eventManager->getOrCreateStudioEvent(QStringLiteral("selfbooth"));
    return m_eventManager->getOrCreateStudioEvent(QStringLiteral("studio3"));
}

bool PaymentSyncManager::isAllowedSetting(const QString &key) const {
    return m_allowedKeys.contains(key);
}

bool PaymentSyncManager::validatePrintOptionsJson(const QString &value) const {
    const QJsonDocument doc = QJsonDocument::fromJson(value.toUtf8());
    if (!doc.isArray()) return false;
    const QJsonArray arr = doc.array();
    if (arr.isEmpty() || arr.size() > 5) return false;
    for (const QJsonValue &v : arr) {
        const QJsonObject o = v.toObject();
        if (!o.contains(QStringLiteral("qty")) || !o.contains(QStringLiteral("price")) || !o.contains(QStringLiteral("discount")))
            return false;
        if (o.value(QStringLiteral("qty")).toInt(-1) < 0
                || o.value(QStringLiteral("price")).toInt(-1) < 0
                || o.value(QStringLiteral("discount")).toInt(-1) < 0)
            return false;
    }
    return true;
}

bool PaymentSyncManager::applyJob(const QJsonObject &job, QString *error) {
    const QJsonObject settings = job.value(QStringLiteral("settings")).toObject();
    for (auto it = settings.begin(); it != settings.end(); ++it) {
        const QString key = it.key();
        const QString value = it.value().toString();
        if (!isAllowedSetting(key)) {
            if (error) *error = QStringLiteral("Setting không hợp lệ: ") + key;
            return false;
        }
        if ((key == QStringLiteral("print_options_cut") || key == QStringLiteral("print_options_nocut"))
                && !validatePrintOptionsJson(value)) {
            if (error) *error = QStringLiteral("print_options không hợp lệ");
            return false;
        }
    }

    for (auto it = settings.begin(); it != settings.end(); ++it) {
        if (!m_eventManager->setAppSetting(it.key(), it.value().toString())) {
            if (error) *error = QStringLiteral("Không lưu được setting: ") + it.key();
            return false;
        }
    }

    const QJsonObject prices = job.value(QStringLiteral("category_prices")).toObject();
    if (!prices.isEmpty()) {
        const int eventId = eventIdForKey(job.value(QStringLiteral("event_key")).toString(QStringLiteral("studio3")));
        if (eventId <= 0) {
            if (error) *error = QStringLiteral("Không tạo được event studio");
            return false;
        }
        for (auto it = prices.begin(); it != prices.end(); ++it) {
            const int price = qMax(0, it.value().toInt(0));
            if (!m_eventManager->setAppSettingForEvent(eventId, QStringLiteral("cate_price_") + it.key(), QString::number(price))) {
                if (error) *error = QStringLiteral("Không lưu được giá nhóm: ") + it.key();
                return false;
            }
        }
    }
    return true;
}

void PaymentSyncManager::processNext() {
    if (m_busy || m_jobs.isEmpty() || !m_eventManager) return;
    const QJsonObject job = m_jobs.dequeue();
    const QString jobId = job.value(QStringLiteral("id")).toString();
    if (jobId.isEmpty()) return processNext();

    m_busy = true;
    patchJob(jobId, QStringLiteral("processing"));
    QString err;
    const bool ok = applyJob(job, &err);
    patchJob(jobId, ok ? QStringLiteral("done") : QStringLiteral("failed"), err);
    m_busy = false;
    processNext();
}

void PaymentSyncManager::patchJob(const QString &jobId, const QString &status, const QString &error) {
    const QString hwid = currentHwid();
    if (hwid.isEmpty() || jobId.isEmpty() || !m_config || !m_config->isValid()) return;
    QJsonObject payload{{QStringLiteral("status"), status}};
    if (!error.isEmpty()) payload[QStringLiteral("error")] = error;
    const QString path = QStringLiteral("/machine/%1/payment-jobs/%2")
        .arg(QString::fromUtf8(QUrl::toPercentEncoding(hwid)),
             QString::fromUtf8(QUrl::toPercentEncoding(jobId)));
    m_net.sendCustomRequest(request(path), "PATCH", QJsonDocument(payload).toJson(QJsonDocument::Compact));
}
