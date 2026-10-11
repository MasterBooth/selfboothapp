#include "LicenseStore.h"
#include "ConfigManager.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QDebug>

LicenseStore::LicenseStore(ConfigManager *config, QObject *parent)
    : QObject(parent)
    , m_config(config)
{
    m_net = new QNetworkAccessManager(this);
    connect(m_net, &QNetworkAccessManager::finished, this, &LicenseStore::onReply);
}

void LicenseStore::setBusy(bool b) {
    if (m_busy != b) { m_busy = b; emit busyChanged(); }
}

static QNetworkRequest buildReq(ConfigManager *cfg, const QString &path) {
    QNetworkRequest req(QUrl(cfg->cloudApiBaseUrl() + path));
    req.setRawHeader("Content-Type", "application/json");
    req.setRawHeader("Authorization",
                     QByteArray("Bearer ") + cfg->cloudApiToken().toUtf8());
    req.setTransferTimeout(15000);
    return req;
}

void LicenseStore::fetchPlans() {
    if (!m_config || !m_config->isValid()) { emit errorOccurred("Chưa cấu hình kết nối"); return; }
    m_op = "plans";
    setBusy(true);
    m_net->get(buildReq(m_config, "/plans"));
}

void LicenseStore::createIntent(const QString &hwid, const QString &planCode,
                                int years, const QString &mode) {
    if (!m_config || !m_config->isValid()) { emit errorOccurred("Chưa cấu hình kết nối"); return; }
    m_op = "intent";
    setBusy(true);
    QJsonObject body{
        {"plan_code", planCode},
        {"years", qMax(1, years)},
        {"mode", mode.isEmpty() ? QStringLiteral("new") : mode},
    };
    m_net->post(buildReq(m_config, QString("/machine/%1/payment-intent").arg(hwid)),
                QJsonDocument(body).toJson(QJsonDocument::Compact));
}

void LicenseStore::checkIntent(const QString &hwid, const QString &code) {
    if (!m_config || !m_config->isValid()) return;
    m_op = "poll";
    m_pendingCode = code;
    m_net->get(buildReq(m_config, QString("/machine/%1/payment-intent/%2").arg(hwid, code)));
}

void LicenseStore::onReply(QNetworkReply *reply) {
    const QString op = m_op;
    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray data = reply->readAll();
    const QNetworkReply::NetworkError netErr = reply->error();
    reply->deleteLater();

    const QJsonObject obj = QJsonDocument::fromJson(data).object();

    if (op == "poll") {
        // Poll: không bật/tắt busy, không báo lỗi ồn ào.
        if (netErr != QNetworkReply::NoError || status < 200 || status >= 300) {
            emit intentStatus(m_pendingCode, "error");
            return;
        }
        const QString st = obj.value("found").toBool(false)
                           ? obj.value("status").toString("pending")
                           : "notfound";
        emit intentStatus(m_pendingCode, st);
        return;
    }

    setBusy(false);

    if (netErr != QNetworkReply::NoError || status < 200 || status >= 300 || !obj.value("success").toBool()) {
        const QString msg = obj.contains("error") ? obj.value("error").toString()
                                                  : QString("HTTP %1").arg(status);
        qWarning() << "[LicenseStore]" << op << "error:" << msg << data;
        emit errorOccurred(msg);
        return;
    }

    if (op == "plans") {
        m_plans = obj.value("plans").toArray().toVariantList();
        m_sepay = obj.value("sepay").toObject().toVariantMap();
        m_trialDays = obj.value("trial_days").toInt(3);
        m_discountPct = obj.value("year_discount_pct").toInt(10);
        m_discountFloor = obj.value("discount_floor_pct").toInt(70);
        emit plansChanged();
    } else if (op == "intent") {
        if (obj.value("applied").toBool(false)) {
            // Đổi gói miễn phí — Worker đã áp dụng ngay, không cần QR.
            emit switchApplied();
        } else {
            emit intentCreated(obj.toVariantMap());
        }
    }
}
