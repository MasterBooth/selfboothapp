#include "BackgroundSyncManager.h"
#include "AppPaths.h"
#include "ConfigManager.h"
#include "EventManager.h"
#include "MachineAuthenticator.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUrl>

BackgroundSyncManager::BackgroundSyncManager(ConfigManager *config, QObject *parent)
    : QObject(parent), m_config(config) {
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &BackgroundSyncManager::poll);
}

void BackgroundSyncManager::setEventManager(EventManager *eventManager) {
    m_eventManager = eventManager;
}

void BackgroundSyncManager::setMachineAuthenticator(MachineAuthenticator *machineAuth) {
    m_machineAuth = machineAuth;
}

void BackgroundSyncManager::start(int intervalMs) {
    m_timer.start(qMax(10000, intervalMs));
    QTimer::singleShot(18000, this, &BackgroundSyncManager::poll);
}

QString BackgroundSyncManager::currentHwid() const {
    return m_machineAuth ? m_machineAuth->hwid().trimmed().toUpper() : QString();
}

QNetworkRequest BackgroundSyncManager::request(const QString &path) const {
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(20000);
    return req;
}

void BackgroundSyncManager::poll() {
    if (m_polling || m_busy || !m_config || !m_config->isValid() || !m_eventManager) return;
    const QString hwid = currentHwid();
    if (hwid.isEmpty()) return;

    m_polling = true;
    const QString path = QStringLiteral("/machine/%1/background-jobs?status=pending")
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

QString BackgroundSyncManager::jobDir(const QString &jobId) const {
    const QString path = QDir(AppPaths::instance().getTempDirectory())
        .filePath(QStringLiteral("photobooth_background_jobs/%1").arg(jobId));
    QDir().mkpath(path);
    return path;
}

QString BackgroundSyncManager::safeSegment(const QString &value, const QString &fallback) {
    QString out = value.trimmed();
    if (out.isEmpty()) out = fallback;
    out.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|]")), QStringLiteral("_"));
    out.replace(QRegularExpression(QStringLiteral("\\s+")), QStringLiteral("_"));
    return out.isEmpty() ? fallback : out;
}

QString BackgroundSyncManager::fileNameFromKey(const QString &key, const QString &fallback) {
    const QString tail = key.section('/', -1);
    return safeSegment(tail.isEmpty() ? fallback : tail, fallback);
}

QString BackgroundSyncManager::localBackgroundPath(const QJsonObject &job) const {
    const QString eventKey = safeSegment(job.value(QStringLiteral("event_key")).toString(QStringLiteral("studio3")), QStringLiteral("studio3"));
    const QString screenKey = safeSegment(job.value(QStringLiteral("screen_key")).toString(QStringLiteral("background")), QStringLiteral("background"));
    const QString fileName = fileNameFromKey(job.value(QStringLiteral("object_key")).toString(),
                                             job.value(QStringLiteral("file_name")).toString(QStringLiteral("background.png")));
    const QString dir = QDir(AppPaths::instance().getAppDirectory())
        .filePath(QStringLiteral("backgrounds/%1/%2").arg(eventKey, screenKey));
    QDir().mkpath(dir);
    return QDir(dir).filePath(fileName);
}

int BackgroundSyncManager::eventIdForJob(const QJsonObject &job) const {
    const QString eventKey = job.value(QStringLiteral("event_key")).toString(QStringLiteral("studio3")).toLower();
    if (eventKey == QStringLiteral("studio2")) return m_eventManager->getOrCreateStudioEvent(QStringLiteral("studio2"));
    if (eventKey == QStringLiteral("selfbooth")) return m_eventManager->getOrCreateStudioEvent(QStringLiteral("selfbooth"));
    return m_eventManager->getOrCreateStudioEvent(QStringLiteral("studio3"));
}

void BackgroundSyncManager::downloadToFile(const QString &url, const QString &destPath,
                                           std::function<void(bool, QString)> done) {
    QNetworkReply *reply = m_net.get(QNetworkRequest(QUrl(url)));
    connect(reply, &QNetworkReply::finished, this, [reply, destPath, done]() {
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();
        const bool ok = reply->error() == QNetworkReply::NoError && http >= 200 && http < 300;
        const QString err = reply->errorString();
        reply->deleteLater();
        if (!ok) return done(false, err);
        QFile f(destPath);
        if (!f.open(QIODevice::WriteOnly)) return done(false, f.errorString());
        f.write(data);
        f.close();
        done(true, QString());
    });
}

bool BackgroundSyncManager::applySetting(const QJsonObject &job, const QString &value, QString *error) {
    const QString key = job.value(QStringLiteral("setting_key")).toString();
    if (key.isEmpty()) {
        if (error) *error = QStringLiteral("Thiếu setting_key");
        return false;
    }
    if (key == QStringLiteral("global_background_image") || key == QStringLiteral("landing_background")) {
        const bool ok = m_eventManager->setAppSetting(key, value);
        if (ok && key == QStringLiteral("global_background_image")) {
            m_eventManager->setAppSetting(QStringLiteral("global_background_enabled"), value.isEmpty() ? QStringLiteral("false") : QStringLiteral("true"));
        }
        if (!ok && error) *error = QStringLiteral("Không cập nhật được setting global");
        return ok;
    }
    const int eventId = eventIdForJob(job);
    if (eventId <= 0) {
        if (error) *error = QStringLiteral("Không tạo được event studio");
        return false;
    }
    const bool ok = m_eventManager->setAppSettingForEvent(eventId, key, value);
    if (!ok && error) *error = QStringLiteral("Không cập nhật được setting event");
    return ok;
}

void BackgroundSyncManager::finishJob(const QString &jobId, bool ok, const QString &error) {
    patchJob(jobId, ok ? QStringLiteral("done") : QStringLiteral("failed"), error);
    m_busy = false;
    processNext();
}

void BackgroundSyncManager::processNext() {
    if (m_busy || m_jobs.isEmpty() || !m_eventManager) return;
    const QJsonObject job = m_jobs.dequeue();
    const QString jobId = job.value(QStringLiteral("id")).toString();
    const QString action = job.value(QStringLiteral("action")).toString(QStringLiteral("upload"));
    if (jobId.isEmpty()) return processNext();

    m_busy = true;
    patchJob(jobId, QStringLiteral("processing"));

    if (action == QStringLiteral("toggle_global")) {
        const bool enabled = job.value(QStringLiteral("enabled")).toBool(false);
        const bool ok = m_eventManager->setAppSetting(QStringLiteral("global_background_enabled"), enabled ? QStringLiteral("true") : QStringLiteral("false"));
        return finishJob(jobId, ok, ok ? QString() : QStringLiteral("Không bật/tắt được hình nền chung"));
    }

    if (action == QStringLiteral("delete")) {
        QString err;
        const bool ok = applySetting(job, QString(), &err);
        return finishJob(jobId, ok, err);
    }

    if (action != QStringLiteral("upload")) {
        return finishJob(jobId, false, QStringLiteral("Action hình nền không hợp lệ"));
    }

    const QString mediaUrl = job.value(QStringLiteral("media_url")).toString();
    if (mediaUrl.isEmpty()) return finishJob(jobId, false, QStringLiteral("Thiếu URL hình nền"));

    const QString destPath = localBackgroundPath(job);
    downloadToFile(mediaUrl, destPath, [this, job, jobId, destPath](bool ok, QString err) {
        if (!ok) return finishJob(jobId, false, QStringLiteral("Không tải được hình nền: ") + err);
        QString applyErr;
        const bool applied = applySetting(job, destPath, &applyErr);
        finishJob(jobId, applied, applyErr);
    });
}

void BackgroundSyncManager::patchJob(const QString &jobId, const QString &status, const QString &error) {
    const QString hwid = currentHwid();
    if (hwid.isEmpty() || jobId.isEmpty() || !m_config || !m_config->isValid()) return;
    QJsonObject payload{{QStringLiteral("status"), status}};
    if (!error.isEmpty()) payload[QStringLiteral("error")] = error;
    const QString path = QStringLiteral("/machine/%1/background-jobs/%2")
        .arg(QString::fromUtf8(QUrl::toPercentEncoding(hwid)),
             QString::fromUtf8(QUrl::toPercentEncoding(jobId)));
    m_net.sendCustomRequest(request(path), "PATCH", QJsonDocument(payload).toJson(QJsonDocument::Compact));
}
