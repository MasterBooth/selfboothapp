#include "PrintJobClient.h"
#include "ConfigManager.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QUrlQuery>
#include <QRegularExpression>

PrintJobClient::PrintJobClient(ConfigManager *config, QObject *parent)
    : QObject(parent)
    , m_config(config)
{
    m_pollTimer.setInterval(4500);
    connect(&m_pollTimer, &QTimer::timeout, this, &PrintJobClient::refresh);
    initStore();
    loadCachedHistory();
}

PrintJobClient::~PrintJobClient()
{
    stop();
    if (m_store.isOpen()) m_store.close();
}

void PrintJobClient::start()
{
    refresh();
    refreshHistory();
    if (!m_pollTimer.isActive()) m_pollTimer.start();
}

void PrintJobClient::stop()
{
    m_pollTimer.stop();
}

QNetworkRequest PrintJobClient::request(const QString &path) const
{
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_config->cloudApiToken().toUtf8());
    req.setTransferTimeout(20000);
    return req;
}

void PrintJobClient::refresh()
{
    if (!m_config || !m_config->hasMachineToken()) {
        setStatusText(QStringLiteral("Đăng nhập studio để nhận hàng chờ in."));
        m_jobs.clear();
        emit jobsChanged();
        return;
    }
    QNetworkReply *reply = m_net.get(request(QStringLiteral("/v1/machine/print-jobs?status=pending&limit=20")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || http < 200 || http >= 300) {
            setStatusText(QStringLiteral("Không tải được hàng chờ in."));
            return;
        }
        applyJobs(obj.value(QStringLiteral("jobs")).toArray());
        setStatusText(m_jobs.isEmpty() ? QStringLiteral("Chưa có ảnh chờ in.") : QStringLiteral("Có ảnh mới trong hàng chờ."));
    });
}

void PrintJobClient::refreshHistory()
{
    if (!m_config || !m_config->hasMachineToken()) {
        loadCachedHistory();
        return;
    }
    QNetworkReply *reply = m_net.get(request(QStringLiteral("/v1/machine/print-jobs/history?limit=50")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || http < 200 || http >= 300) return;
        applyHistory(obj.value(QStringLiteral("jobs")).toArray());
    });
}

void PrintJobClient::applyJobs(const QJsonArray &items)
{
    QVariantList next;
    for (const QJsonValue &value : items) {
        QVariantMap job = value.toObject().toVariantMap();
        const QString local = localPathForJob(job.value(QStringLiteral("id")).toString());
        if (!local.isEmpty()) job.insert(QStringLiteral("local_path"), local);
        next.append(job);
        upsertCachedJob(job, local);
    }
    m_jobs = next;
    emit jobsChanged();
}

void PrintJobClient::applyHistory(const QJsonArray &items)
{
    QVariantList next;
    for (const QJsonValue &value : items) {
        QVariantMap job = value.toObject().toVariantMap();
        const QString local = localPathForJob(job.value(QStringLiteral("id")).toString());
        if (!local.isEmpty()) job.insert(QStringLiteral("local_path"), local);
        next.append(job);
        upsertCachedJob(job, local);
    }
    m_history = next;
    emit historyChanged();
}

QVariantMap PrintJobClient::jobById(const QString &jobId) const
{
    for (const QVariant &item : m_jobs) {
        const QVariantMap job = item.toMap();
        if (job.value(QStringLiteral("id")).toString() == jobId) return job;
    }
    for (const QVariant &item : m_history) {
        const QVariantMap job = item.toMap();
        if (job.value(QStringLiteral("id")).toString() == jobId) return job;
    }
    return {};
}

void PrintJobClient::claimAndDownload(const QString &jobId)
{
    if (m_busy || jobId.isEmpty()) return;
    setBusy(true);
    m_activeJobId.clear();
    m_activeLocalPath.clear();
    emit activeJobChanged();

    QNetworkReply *reply = m_net.post(request(QStringLiteral("/v1/machine/print-jobs/%1/claim").arg(jobId)), QByteArray("{}"));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || http < 200 || http >= 300) {
            setBusy(false);
            const QString msg = obj.value(QStringLiteral("message")).toString(QStringLiteral("Không nhận được job in."));
            emit jobFailed(msg);
            return;
        }
        const QVariantMap job = obj.value(QStringLiteral("job")).toObject().toVariantMap();
        m_activeJobId = job.value(QStringLiteral("id")).toString();
        emit activeJobChanged();
        downloadActiveJob(job);
    });
}

void PrintJobClient::reprintAndDownload(const QString &jobId, int copies, const QString &orientation, const QString &printerName)
{
    if (m_busy || jobId.isEmpty()) return;
    setBusy(true);
    m_activeJobId.clear();
    m_activeLocalPath.clear();
    emit activeJobChanged();

    QJsonObject body{
        {QStringLiteral("copies"), qMax(1, copies)},
        {QStringLiteral("orientation"), orientation.isEmpty() ? QStringLiteral("auto") : orientation},
        {QStringLiteral("printer_name"), printerName},
    };
    QNetworkReply *reply = m_net.post(
        request(QStringLiteral("/v1/machine/print-jobs/%1/reprint").arg(jobId)),
        QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || http < 200 || http >= 300) {
            setBusy(false);
            const QString msg = obj.value(QStringLiteral("message")).toString(QStringLiteral("Không tạo được lượt in lại."));
            emit jobFailed(msg);
            return;
        }
        const QVariantMap job = obj.value(QStringLiteral("job")).toObject().toVariantMap();
        m_activeJobId = job.value(QStringLiteral("id")).toString();
        emit activeJobChanged();
        downloadActiveJob(job);
    });
}

void PrintJobClient::downloadActiveJob(const QVariantMap &job)
{
    const QString cached = localPathForJob(job.value(QStringLiteral("id")).toString());
    if (!cached.isEmpty()) {
        m_activeLocalPath = cached;
        emit activeJobChanged();
        patchJob(m_activeJobId, QJsonObject{{QStringLiteral("status"), QStringLiteral("printing")}});
        setBusy(false);
        emit jobReadyToPrint(cached, job.value(QStringLiteral("copies"), 1).toInt(), job.value(QStringLiteral("orientation"), "auto").toString());
        return;
    }

    QNetworkReply *reply = m_net.get(QNetworkRequest(QUrl(job.value(QStringLiteral("media_url")).toString())));
    connect(reply, &QNetworkReply::finished, this, [this, reply, job]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (reply->error() != QNetworkReply::NoError || http < 200 || http >= 300) {
            setBusy(false);
            patchJob(m_activeJobId, QJsonObject{
                {QStringLiteral("status"), QStringLiteral("failed")},
                {QStringLiteral("error_code"), QStringLiteral("download_failed")},
                {QStringLiteral("error_message"), QStringLiteral("Không tải được ảnh in")}
            });
            emit jobFailed(QStringLiteral("Không tải được ảnh in."));
            return;
        }
        const QString path = cachePathForJob(job.value(QStringLiteral("id")).toString(), job.value(QStringLiteral("file_name")).toString());
        QDir().mkpath(QFileInfo(path).absolutePath());
        QFile file(path);
        if (!file.open(QIODevice::WriteOnly) || file.write(reply->readAll()) <= 0) {
            setBusy(false);
            emit jobFailed(QStringLiteral("Không lưu được ảnh in trên máy."));
            return;
        }
        file.close();
        m_activeLocalPath = path;
        emit activeJobChanged();
        upsertCachedJob(job, path);
        patchJob(m_activeJobId, QJsonObject{{QStringLiteral("status"), QStringLiteral("printing")}});
        setBusy(false);
        emit jobReadyToPrint(path, job.value(QStringLiteral("copies"), 1).toInt(), job.value(QStringLiteral("orientation"), "auto").toString());
    });
}

void PrintJobClient::finishActivePrint(bool success, const QString &message, const QString &printerName, int copies, const QString &orientation)
{
    if (m_activeJobId.isEmpty()) return;
    QJsonObject body{
        {QStringLiteral("status"), success ? QStringLiteral("printed") : QStringLiteral("failed")},
        {QStringLiteral("printer_name"), printerName},
        {QStringLiteral("copies"), qMax(1, copies)},
        {QStringLiteral("orientation"), orientation.isEmpty() ? QStringLiteral("auto") : orientation},
    };
    if (!success) {
        body.insert(QStringLiteral("error_code"), QStringLiteral("print_failed"));
        body.insert(QStringLiteral("error_message"), message.left(500));
    }
    patchJob(m_activeJobId, body);
    m_activeJobId.clear();
    m_activeLocalPath.clear();
    emit activeJobChanged();
    refresh();
    refreshHistory();
}

void PrintJobClient::patchJob(const QString &jobId, const QJsonObject &body)
{
    if (jobId.isEmpty() || !m_config || !m_config->hasMachineToken()) return;
    QNetworkReply *reply = m_net.sendCustomRequest(
        request(QStringLiteral("/v1/machine/print-jobs/%1").arg(jobId)),
        QByteArray("PATCH"),
        QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
}

QString PrintJobClient::cachePathForJob(const QString &jobId, const QString &fileName) const
{
    const QString root = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("data/print_jobs"));
    QString safe = fileName;
    safe.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9._-]")), QStringLiteral("_"));
    if (safe.isEmpty()) safe = QStringLiteral("print.png");
    return QDir(root).filePath(jobId + QStringLiteral("_") + safe);
}

QString PrintJobClient::localPathForJob(const QString &jobId) const
{
    if (!m_store.isOpen()) return {};
    QSqlQuery q(m_store);
    q.prepare(QStringLiteral("SELECT local_path FROM cached_print_jobs WHERE id = ?"));
    q.addBindValue(jobId);
    if (!q.exec() || !q.next()) return {};
    const QString path = q.value(0).toString();
    return QFileInfo::exists(path) ? path : QString();
}

void PrintJobClient::initStore()
{
    const QString dir = QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("data"));
    QDir().mkpath(dir);
    const QString connection = QStringLiteral("printstation_%1").arg(reinterpret_cast<quintptr>(this));
    m_store = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connection);
    m_store.setDatabaseName(QDir(dir).filePath(QStringLiteral("printstation.db")));
    if (!m_store.open()) return;
    QSqlQuery q(m_store);
    q.exec(QStringLiteral(
        "CREATE TABLE IF NOT EXISTS cached_print_jobs ("
        "id TEXT PRIMARY KEY, payload_json TEXT NOT NULL, local_path TEXT NOT NULL DEFAULT '', "
        "status TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL)"));
}

void PrintJobClient::upsertCachedJob(const QVariantMap &job, const QString &localPath)
{
    if (!m_store.isOpen()) return;
    QJsonObject obj = QJsonObject::fromVariantMap(job);
    QSqlQuery q(m_store);
    q.prepare(QStringLiteral(
        "INSERT INTO cached_print_jobs (id, payload_json, local_path, status, updated_at) "
        "VALUES (?, ?, ?, ?, ?) "
        "ON CONFLICT(id) DO UPDATE SET payload_json = excluded.payload_json, "
        "local_path = CASE WHEN excluded.local_path <> '' THEN excluded.local_path ELSE cached_print_jobs.local_path END, "
        "status = excluded.status, updated_at = excluded.updated_at"));
    q.addBindValue(job.value(QStringLiteral("id")).toString());
    q.addBindValue(QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact)));
    q.addBindValue(localPath);
    q.addBindValue(job.value(QStringLiteral("status")).toString());
    q.addBindValue(QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
    q.exec();
}

void PrintJobClient::loadCachedHistory()
{
    if (!m_store.isOpen()) return;
    QVariantList rows;
    QSqlQuery q(m_store);
    if (q.exec(QStringLiteral("SELECT payload_json, local_path FROM cached_print_jobs ORDER BY updated_at DESC LIMIT 50"))) {
        while (q.next()) {
            QVariantMap job = QJsonDocument::fromJson(q.value(0).toString().toUtf8()).object().toVariantMap();
            const QString local = q.value(1).toString();
            if (!local.isEmpty() && QFileInfo::exists(local)) job.insert(QStringLiteral("local_path"), local);
            rows.append(job);
        }
    }
    m_history = rows;
    emit historyChanged();
}

void PrintJobClient::setBusy(bool busy)
{
    if (m_busy == busy) return;
    m_busy = busy;
    emit busyChanged();
}

void PrintJobClient::setStatusText(const QString &text)
{
    if (m_statusText == text) return;
    m_statusText = text;
    emit statusTextChanged();
}
