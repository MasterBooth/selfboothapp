#include "FilterSyncManager.h"
#include "AppPaths.h"
#include "ConfigManager.h"
#include "FilterManager.h"
#include "MachineAuthenticator.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QDebug>
#include <QRegularExpression>
#include <QUrl>

FilterSyncManager::FilterSyncManager(ConfigManager *config, QObject *parent)
    : QObject(parent), m_config(config) {
    m_timer.setSingleShot(false);
    connect(&m_timer, &QTimer::timeout, this, &FilterSyncManager::poll);
}

void FilterSyncManager::setFilterManager(FilterManager *filterManager) {
    m_filterManager = filterManager;
}

void FilterSyncManager::setMachineAuthenticator(MachineAuthenticator *machineAuth) {
    m_machineAuth = machineAuth;
}

void FilterSyncManager::start(int intervalMs) {
    m_timer.start(qMax(10000, intervalMs));
    QTimer::singleShot(15000, this, &FilterSyncManager::poll);
}

QString FilterSyncManager::currentHwid() const {
    return m_machineAuth ? m_machineAuth->hwid().trimmed().toUpper() : QString();
}

QNetworkRequest FilterSyncManager::request(const QString &path) const {
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(20000);
    return req;
}

void FilterSyncManager::poll() {
    if (m_polling || m_busy || !m_config || !m_config->isValid() || !m_filterManager) return;
    const QString hwid = currentHwid();
    if (hwid.isEmpty()) return;

    m_polling = true;
    const QString path = QStringLiteral("/machine/%1/filter-jobs?status=pending")
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

QString FilterSyncManager::jobDir(const QString &jobId) const {
    const QString path = QDir(AppPaths::instance().getTempDirectory())
        .filePath(QStringLiteral("photobooth_filter_jobs/%1").arg(jobId));
    QDir().mkpath(path);
    return path;
}

QString FilterSyncManager::fileNameFromKey(const QString &key, const QString &fallback) {
    const QString tail = key.section('/', -1);
    QString name = tail.isEmpty() ? fallback : tail;
    name.replace(QRegularExpression(QStringLiteral("[\\\\/:*?\"<>|]")), QStringLiteral("_"));
    return name;
}

void FilterSyncManager::downloadToFile(const QString &url, const QString &destPath,
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

void FilterSyncManager::finishJob(const QString &jobId, bool ok, const QString &error) {
    patchJob(jobId, ok ? QStringLiteral("done") : QStringLiteral("failed"), error);
    m_busy = false;
    processNext();
}

void FilterSyncManager::processNext() {
    if (m_busy || m_jobs.isEmpty() || !m_filterManager) return;
    const QJsonObject job = m_jobs.dequeue();
    const QString jobId = job.value(QStringLiteral("id")).toString();
    const QString action = job.value(QStringLiteral("action")).toString(QStringLiteral("upload"));
    const QString filterId = job.value(QStringLiteral("filter_id")).toString();
    if (jobId.isEmpty()) return processNext();

    m_busy = true;
    patchJob(jobId, QStringLiteral("processing"));

    if (action == QStringLiteral("rename")) {
        const bool ok = m_filterManager->renameFilter(filterId, job.value(QStringLiteral("filter_name")).toString());
        return finishJob(jobId, ok, ok ? QString() : QStringLiteral("Không tìm thấy filter để sửa tên"));
    }
    if (action == QStringLiteral("delete")) {
        const bool ok = m_filterManager->deleteFilter(filterId);
        return finishJob(jobId, ok, ok ? QString() : QStringLiteral("Không tìm thấy filter để xóa"));
    }
    if (action == QStringLiteral("favorite")) {
        const bool ok = m_filterManager->setFilterFavorite(filterId, job.value(QStringLiteral("favorite")).toBool(false));
        return finishJob(jobId, ok, ok ? QString() : QStringLiteral("Không tìm thấy filter để cập nhật yêu thích"));
    }

    const QString dir = jobDir(jobId);
    const QString cubeUrl = job.value(QStringLiteral("cube_url")).toString();
    const QString thumbUrl = job.value(QStringLiteral("thumbnail_url")).toString();
    const QString cubePath = cubeUrl.isEmpty() ? QString()
        : QDir(dir).filePath(fileNameFromKey(job.value(QStringLiteral("cube_object_key")).toString(), QStringLiteral("filter.cube")));
    const QString thumbPath = thumbUrl.isEmpty() ? QString()
        : QDir(dir).filePath(fileNameFromKey(job.value(QStringLiteral("thumbnail_object_key")).toString(), QStringLiteral("thumbnail.png")));

    auto applyWithFiles = [this, job, jobId, action, filterId, cubePath, thumbPath]() {
        bool ok = false;
        QString err;
        if (action == QStringLiteral("upload")) {
            ok = m_filterManager->importFilterWithId(filterId, cubePath,
                                                     job.value(QStringLiteral("filter_name")).toString(),
                                                     thumbPath,
                                                     job.value(QStringLiteral("favorite")).toBool(false));
            if (!ok) err = QStringLiteral("Không import được filter hoặc file .cube không hợp lệ");
        } else if (action == QStringLiteral("replace")) {
            ok = m_filterManager->replaceFilterFile(filterId, cubePath);
            if (!ok) err = QStringLiteral("Không thay được file .cube");
        } else if (action == QStringLiteral("thumbnail")) {
            ok = m_filterManager->setFilterThumbnail(filterId, thumbPath);
            if (!ok) err = QStringLiteral("Không cập nhật được thumbnail");
        } else {
            err = QStringLiteral("Action filter không hợp lệ");
        }
        finishJob(jobId, ok, err);
    };

    auto downloadThumbThenApply = [this, jobId, thumbUrl, thumbPath, applyWithFiles]() {
        if (thumbUrl.isEmpty()) return applyWithFiles();
        downloadToFile(thumbUrl, thumbPath, [this, jobId, applyWithFiles](bool ok, QString err) {
            if (!ok) {
                qWarning() << "[FilterSync] thumbnail download failed for" << jobId << err;
            }
            applyWithFiles();
        });
    };

    if (!cubeUrl.isEmpty()) {
        downloadToFile(cubeUrl, cubePath, [this, jobId, downloadThumbThenApply](bool ok, QString err) {
            if (!ok) return finishJob(jobId, false, QStringLiteral("Không tải được file .cube: ") + err);
            downloadThumbThenApply();
        });
        return;
    }

    if (action == QStringLiteral("thumbnail") && !thumbUrl.isEmpty()) return downloadThumbThenApply();
    finishJob(jobId, false, QStringLiteral("Thiếu file cần đồng bộ"));
}

void FilterSyncManager::patchJob(const QString &jobId, const QString &status, const QString &error) {
    const QString hwid = currentHwid();
    if (hwid.isEmpty() || jobId.isEmpty() || !m_config || !m_config->isValid()) return;
    QJsonObject payload{{QStringLiteral("status"), status}};
    if (!error.isEmpty()) payload[QStringLiteral("error")] = error;
    const QString path = QStringLiteral("/machine/%1/filter-jobs/%2")
        .arg(QString::fromUtf8(QUrl::toPercentEncoding(hwid)),
             QString::fromUtf8(QUrl::toPercentEncoding(jobId)));
    m_net.sendCustomRequest(request(path), "PATCH", QJsonDocument(payload).toJson(QJsonDocument::Compact));
}
