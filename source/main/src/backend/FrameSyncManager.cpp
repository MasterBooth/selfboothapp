#include "FrameSyncManager.h"
#include "AppPaths.h"
#include "ConfigManager.h"
#include "EventManager.h"
#include "MachineAuthenticator.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUrl>
#include <QUrlQuery>

FrameSyncManager::FrameSyncManager(ConfigManager *config, QObject *parent)
    : QObject(parent), m_config(config) {
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &FrameSyncManager::poll);
}

void FrameSyncManager::setEventManager(EventManager *eventManager) {
    m_eventManager = eventManager;
}

void FrameSyncManager::setMachineAuthenticator(MachineAuthenticator *machineAuth) {
    m_machineAuth = machineAuth;
}

void FrameSyncManager::start(int intervalMs) {
    m_timer.start(qMax(10000, intervalMs));
    QTimer::singleShot(12000, this, &FrameSyncManager::poll);
}

QString FrameSyncManager::currentHwid() const {
    return m_machineAuth ? m_machineAuth->hwid().trimmed().toUpper() : QString();
}

QNetworkRequest FrameSyncManager::request(const QString &path) const {
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(20000);
    return req;
}

void FrameSyncManager::poll() {
    if (m_polling || m_busy || !m_config || !m_config->isValid() || !m_eventManager) return;
    const QString hwid = currentHwid();
    if (hwid.isEmpty()) return;

    m_polling = true;
    const QString path = QStringLiteral("/machine/%1/frame-jobs?status=pending")
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

QString FrameSyncManager::jobDir(const QString &jobId) const {
    const QString path = QDir(AppPaths::instance().getTempDirectory())
        .filePath(QStringLiteral("photobooth_frame_jobs/%1").arg(jobId));
    QDir().mkpath(path);
    return path;
}

QString FrameSyncManager::fileNameFromKey(const QString &key, const QString &fallback) {
    const QString tail = key.section('/', -1);
    QString name = tail.isEmpty() ? fallback : tail;
    name.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|]")), QStringLiteral("_"));
    return name;
}

int FrameSyncManager::eventIdForJob(const QJsonObject &job) {
    const QString eventKey = job.value(QStringLiteral("event_key")).toString(QStringLiteral("studio3")).toLower();
    if (eventKey == QStringLiteral("studio2")) return m_eventManager->getOrCreateStudioEvent(QStringLiteral("studio2"));
    if (eventKey == QStringLiteral("selfbooth")) return m_eventManager->getOrCreateStudioEvent(QStringLiteral("selfbooth"));
    return m_eventManager->getOrCreateStudioEvent(QStringLiteral("studio3"));
}

void FrameSyncManager::downloadToFile(const QString &url, const QString &destPath,
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

void FrameSyncManager::processNext() {
    if (m_busy || m_jobs.isEmpty() || !m_eventManager) return;
    const QJsonObject job = m_jobs.dequeue();
    const QString jobId = job.value(QStringLiteral("id")).toString();
    const QString action = job.value(QStringLiteral("action")).toString(QStringLiteral("upload"));
    const QString category = job.value(QStringLiteral("category")).toString(QStringLiteral("Khác")).trimmed();
    const QString frameUrl = job.value(QStringLiteral("frame_url")).toString();
    if (jobId.isEmpty()) return processNext();

    m_busy = true;
    m_activeJobId = jobId;
    patchJob(jobId, QStringLiteral("processing"));

    if (action == QStringLiteral("delete") || action == QStringLiteral("rename")) {
        const int eventId = eventIdForJob(job);
        const QString originalName = job.value(QStringLiteral("original_name")).toString();
        const QString layoutPath = m_eventManager->findFrameLayoutPath(eventId, category, originalName);
        if (layoutPath.isEmpty()) {
            patchJob(jobId, QStringLiteral("failed"), QStringLiteral("Không tìm thấy frame trên máy: ") + originalName);
            m_busy = false; m_activeJobId.clear(); processNext(); return;
        }
        QMetaObject::Connection *conn = new QMetaObject::Connection;
        *conn = connect(m_eventManager, &EventManager::frameTaskFinished, this,
            [this, conn, jobId, action](const QString &op, int ok, int failed, const QStringList &errors) {
                if (op != action) return;
                disconnect(*conn);
                delete conn;
                if (ok > 0 && failed == 0) patchJob(jobId, QStringLiteral("done"));
                else patchJob(jobId, QStringLiteral("failed"), errors.join(QStringLiteral("; ")));
                m_busy = false;
                m_activeJobId.clear();
                processNext();
            });
        if (action == QStringLiteral("delete")) {
            m_eventManager->deleteLayoutsBatch(eventId, QStringList{layoutPath});
        } else {
            QString cleanCategory = category;
            cleanCategory.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|]")), QStringLiteral("_"));
            QString newName = fileNameFromKey(job.value(QStringLiteral("new_name")).toString(), QStringLiteral("frame.png"));
            if (!newName.endsWith(QStringLiteral(".png"), Qt::CaseInsensitive)) newName += QStringLiteral(".png");
            const QString toName = (cleanCategory.isEmpty() || cleanCategory == QStringLiteral("Khác"))
                ? newName : cleanCategory + QStringLiteral("__") + newName;
            QVariantMap pair;
            pair[QStringLiteral("from")] = layoutPath;
            pair[QStringLiteral("to")] = toName;
            m_eventManager->renameLayoutsBatch(eventId, QVariantList{pair});
        }
        return;
    }

    if (frameUrl.isEmpty()) {
        patchJob(jobId, QStringLiteral("failed"), QStringLiteral("Thiếu URL frame"));
        m_busy = false; m_activeJobId.clear(); processNext(); return;
    }

    const QString dir = jobDir(jobId);
    const QString framePath = QDir(dir).filePath(fileNameFromKey(job.value(QStringLiteral("frame_object_key")).toString(),
                                                                QStringLiteral("frame.png")));
    const QString displayUrl = job.value(QStringLiteral("display_image_url")).toString();
    const QString displayPath = displayUrl.isEmpty()
        ? QString()
        : QDir(dir).filePath(fileNameFromKey(job.value(QStringLiteral("display_image_object_key")).toString(),
                                            QStringLiteral("display.png")));

    downloadToFile(frameUrl, framePath, [this, job, jobId, category, framePath, displayUrl, displayPath](bool ok, QString err) {
        if (!ok) {
            patchJob(jobId, QStringLiteral("failed"), QStringLiteral("Không tải được frame: ") + err);
            m_busy = false; m_activeJobId.clear(); processNext(); return;
        }
        auto startUpload = [this, job, jobId, category, framePath, displayPath]() {
            const int eventId = eventIdForJob(job);
            if (eventId <= 0) {
                patchJob(jobId, QStringLiteral("failed"), QStringLiteral("Không tạo được event studio"));
                m_busy = false; m_activeJobId.clear(); processNext(); return;
            }
            m_eventManager->ensureFrameCategory(eventId, category);
            if (!displayPath.isEmpty()) m_eventManager->importCategoryDisplayImage(eventId, category, displayPath);
            QMetaObject::Connection *conn = new QMetaObject::Connection;
            *conn = connect(m_eventManager, &EventManager::frameTaskFinished, this,
                [this, conn, jobId](const QString &op, int ok, int failed, const QStringList &errors) {
                    if (op != QStringLiteral("upload")) return;
                    disconnect(*conn);
                    delete conn;
                    if (ok > 0 && failed == 0) patchJob(jobId, QStringLiteral("done"));
                    else patchJob(jobId, QStringLiteral("failed"), errors.join(QStringLiteral("; ")));
                    m_busy = false;
                    m_activeJobId.clear();
                    processNext();
                });
            m_eventManager->uploadLayoutsBatch(eventId, QStringList{framePath}, category);
        };
        if (displayUrl.isEmpty()) return startUpload();
        downloadToFile(displayUrl, displayPath, [this, jobId, startUpload](bool ok2, QString err2) {
            if (!ok2) qWarning() << "[FrameSync] display image download failed for" << jobId << err2;
            startUpload();
        });
    });
}

void FrameSyncManager::patchJob(const QString &jobId, const QString &status, const QString &error) {
    const QString hwid = currentHwid();
    if (hwid.isEmpty() || jobId.isEmpty() || !m_config || !m_config->isValid()) return;
    QJsonObject payload{{QStringLiteral("status"), status}};
    if (!error.isEmpty()) payload[QStringLiteral("error")] = error;
    const QString path = QStringLiteral("/machine/%1/frame-jobs/%2")
        .arg(QString::fromUtf8(QUrl::toPercentEncoding(hwid)),
             QString::fromUtf8(QUrl::toPercentEncoding(jobId)));
    m_net.sendCustomRequest(request(path), "PATCH", QJsonDocument(payload).toJson(QJsonDocument::Compact));
}
