#include "S3Uploader.h"
#include "AppPaths.h"
#include "ConfigManager.h"
#include "DatabaseManager.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>
#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QDateTime>
#include <QDebug>
#include <QUrl>
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QNetworkInformation>
#include <QDirIterator>
#include <QSet>
#include <QQueue>
#include <QSharedPointer>
#include <QRandomGenerator>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QSaveFile>
#include <QtConcurrent/QtConcurrentRun>

// Thư mục gốc chung trên R2: studio/<hwid>/<sessionId>/...  Mở bucket thấy một
// thư mục "studio", bên trong là từng máy (hwid), rồi từng phiên.
static const QString kStorageRoot = QStringLiteral("studio");

// Tách hwid + sessionId từ key studio/<hwid>/<sessionId>/<file>. Sai dạng -> false.
static bool parseStorageKey(const QString &s3Key, QString *hwid, QString *sessionId)
{
    const QStringList parts = s3Key.split('/');
    if (parts.size() < 4 || parts.at(0) != kStorageRoot)
        return false;
    if (hwid) *hwid = parts.at(1);
    if (sessionId) *sessionId = parts.at(2);
    return true;
}

static QString stableCaptureAssetId(const QString &sessionId, const QString &kind,
                                    const QString &fileName, int photoIndex)
{
    const QByteArray input = QString("%1|%2|%3|%4")
        .arg(sessionId, kind, QString::number(photoIndex), fileName).toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(input, QCryptographicHash::Sha256).toHex());
}

static QString uploadContentTypeForFile(const QString &filePath)
{
    const QString ext = QFileInfo(filePath).suffix().toLower();
    if (ext == "jpg" || ext == "jpeg") return "image/jpeg";
    if (ext == "png") return "image/png";
    if (ext == "webp") return "image/webp";
    if (ext == "mp4") return "video/mp4";
    if (ext == "mov") return "video/quicktime";
    if (ext == "json") return "application/json";
    return "application/octet-stream";
}

// ─────────────────────────────────────────────────────────────────────────────
// S3UploadWorker — lives on the background thread. The name is kept for API
// compatibility; uploads target Worker-issued object storage URLs.
// ─────────────────────────────────────────────────────────────────────────────

class S3UploadWorker : public QObject
{
    Q_OBJECT
public:
    explicit S3UploadWorker(QObject *parent = nullptr)
        : QObject(parent), m_nam(nullptr) {}

    // Giới hạn số upload chạy song song. Trước đây mỗi onUpload() bắn ngay
    // 1 QNetworkReply giữ TOÀN BỘ ảnh trong RAM tới khi xong → chụp dồn +
    // mạng chậm = hàng chục buffer vài MB cùng lúc → bùng RAM → crash.
    static constexpr int kMaxConcurrent = 3;

public slots:
    void initialize()
    {
        m_nam = new QNetworkAccessManager(this);
        qDebug() << "[StorageWorker] Ready on thread" << QThread::currentThread();
    }

    // Legacy entry point kept for old calls that pass an explicit object key.
    void onUpload(const QString &filePath, const QString &s3Key,
                  const QString &bucket,   const QString &region,
                  const QString &publicBaseUrl,
                  const QString &apiBaseUrl, const QString &apiToken)
    {
        Q_UNUSED(bucket);
        Q_UNUSED(region);
        Q_UNUSED(publicBaseUrl);
        QString hwid, sessionId;
        parseStorageKey(s3Key, &hwid, &sessionId);
        QVariantMap asset;
        asset["asset_id"] = stableAssetId(sessionId, s3Key, filePath);
        asset["session_id"] = sessionId;
        asset["kind"] = kindForKey(s3Key);
        asset["local_path"] = filePath;
        asset["file_name"] = QFileInfo(filePath).fileName();
        asset["content_type"] = contentTypeForFile(filePath);
        asset["photo_index"] = photoIndexForKey(s3Key);
        asset["object_key"] = s3Key;
        asset["status"] = "pending";
        onUploadAsset(asset, apiBaseUrl, apiToken);
    }

    void onUploadAsset(const QVariantMap &asset, const QString &apiBaseUrl,
                       const QString &apiToken)
    {
        // Bản xem nhỏ (thumbnail/preview) chen lên trước mọi ảnh gốc đang xếp hàng,
        // giữ thứ tự giữa chúng với nhau: khách thấy ảnh trên web trong vài giây.
        const QString kind = asset.value("kind").toString();
        if (kind == QLatin1String("thumbnail") || kind == QLatin1String("preview")) {
            int at = 0;
            while (at < m_queue.size()) {
                const QString queued = m_queue.at(at).asset.value("kind").toString();
                if (queued != QLatin1String("thumbnail") && queued != QLatin1String("preview"))
                    break;
                ++at;
            }
            m_queue.insert(at, { asset, apiBaseUrl, apiToken });
        } else {
            m_queue.enqueue({ asset, apiBaseUrl, apiToken });
        }
        pump();
    }

private:
    struct Job {
        QVariantMap asset;
        QString apiBaseUrl;
        QString apiToken;
    };
    QQueue<Job> m_queue;
    int         m_active = 0;   // số reply đang in-flight (chỉ chạm trên worker thread)

    // Bơm hàng đợi: khởi động upload tới khi chạm trần đồng thời.
    void pump()
    {
        while (m_active < kMaxConcurrent && !m_queue.isEmpty())
            startUpload(m_queue.dequeue());
    }

    void startUpload(const Job &job)
    {
        const QVariantMap asset = job.asset;
        const QString filePath = asset.value("local_path").toString();
        const QString s3Key = asset.value("asset_id").toString();
        const QString apiBaseUrl = job.apiBaseUrl;
        const QString apiToken = job.apiToken;
        const QString assetId = asset.value("asset_id").toString();
        const QString sessionId = asset.value("session_id").toString();
        QString kind = asset.value("kind").toString();
        if (kind.isEmpty()) kind = QStringLiteral("other");
        const int photoIndex = asset.value("photo_index").toInt();
        const QString bucket;
        const QString region;
        const QString publicBaseUrl;

        qDebug() << "[StorageWorker] Uploading:" << s3Key
                 << "| active:" << m_active << "queued:" << m_queue.size();

        // Lỗi sớm: KHÔNG tăng m_active và return. Vòng while trong pump()
        // (caller) sẽ tự dequeue job kế — hàng đợi không bị kẹt bởi 1 file
        // hỏng, đồng thời tránh đệ quy startUpload→pump→startUpload.
        if (!m_nam) {
            emit uploadHardError(filePath, s3Key, "Worker not initialized");
            return;
        }
        if (assetId.isEmpty() || sessionId.isEmpty()) {
            emit uploadHardError(filePath, s3Key, "Missing asset_id/session_id");
            return;
        }

        QFileInfo sourceInfo(filePath);
        if (!sourceInfo.exists() || !sourceInfo.isFile()) {
            emit uploadHardError(filePath, s3Key, QString("Cannot open: %1").arg(filePath));
            return;
        }
        const qint64 fileSize = sourceInfo.size();
        if (fileSize <= 0) {
            emit uploadHardError(filePath, s3Key, QString("Empty file: %1").arg(filePath));
            return;
        }
        QString checksumSha256;
        qint64 hashedSize = 0;
        if (!hashFile(filePath, &hashedSize, &checksumSha256)) {
            emit uploadHardError(filePath, s3Key, QString("Cannot hash: %1").arg(filePath));
            return;
        }

        const QString contentType = contentTypeForFile(filePath);
        QUrl presignUrl(apiBaseUrl + "/v1/machine/sessions/"
                        + QString::fromUtf8(QUrl::toPercentEncoding(sessionId))
                        + "/assets/prepare");
        QNetworkRequest presignReq(presignUrl);
        presignReq.setRawHeader("Content-Type", "application/json");
        presignReq.setRawHeader("Authorization", QByteArray("Bearer ") + apiToken.toUtf8());
        presignReq.setTransferTimeout(15000);

        QJsonObject one;
        one["asset_id"] = assetId;
        one["kind"] = kind;
        QString uploadFileName = asset.value("file_name").toString();
        if (uploadFileName.isEmpty()) uploadFileName = QFileInfo(filePath).fileName();
        one["file_name"] = uploadFileName;
        one["content_type"] = contentType;
        one["size_bytes"] = hashedSize;
        one["checksum_sha256"] = checksumSha256;
        one["photo_index"] = photoIndex;
        QJsonObject payload;
        payload["assets"] = QJsonArray{one};

        emit uploadStarted();
        ++m_active;
        QNetworkReply *presignReply = m_nam->post(
            presignReq, QJsonDocument(payload).toJson(QJsonDocument::Compact));

        connect(presignReply, &QNetworkReply::finished, this,
                [this, presignReply, filePath, s3Key, contentType, fileSize,
                 assetId, checksumSha256, apiBaseUrl, apiToken, sessionId]() {
            const int httpCode = presignReply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QByteArray body = presignReply->readAll();
            const auto netErr = presignReply->error();
            const QString errStr = presignReply->errorString();
            presignReply->deleteLater();

            if (netErr != QNetworkReply::NoError || httpCode < 200 || httpCode >= 300) {
                qCritical() << "[StorageWorker] Presign failed:" << s3Key << errStr << "HTTP" << httpCode;
                finishFailure(filePath, s3Key, httpCode, netErr, errStr);
                return;
            }

            const QJsonObject obj = QJsonDocument::fromJson(body).object();
            const QJsonArray assets = obj.value("assets").toArray();
            const QJsonObject prepared = assets.isEmpty() ? QJsonObject() : assets.first().toObject();
            const QString uploadUrl = prepared.value("upload_url").toString();
            const QString objectKey = prepared.value("object_key").toString();
            const QString expiresAt = prepared.value("expires_at").toString();
            // Server đã có asset này (vd thumbnail trình duyệt khách tạo trước): xong, không upload lại.
            if (prepared.value("status").toString() == QLatin1String("committed") && !objectKey.isEmpty()) {
                qDebug() << "[StorageWorker] Already on server:" << assetId << objectKey;
                emit assetConfirmed(assetId, objectKey, filePath, objectKey, fileSize);
                emit uploadFinished(objectKey, filePath, objectKey);
                if (m_active > 0) --m_active;
                pump();
                return;
            }
            if (uploadUrl.isEmpty() || objectKey.isEmpty()) {
                emit uploadHardError(filePath, s3Key, "Invalid presign response");
                if (m_active > 0) --m_active;
                pump();
                return;
            }
            emit assetPrepared(assetId, fileSize, checksumSha256, objectKey, uploadUrl, expiresAt);

            QNetworkRequest putReq{QUrl(uploadUrl)};
            putReq.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
            putReq.setHeader(QNetworkRequest::ContentLengthHeader, fileSize);
            putReq.setTransferTimeout(60000);
            QFile *uploadFile = new QFile(filePath);
            if (!uploadFile->open(QIODevice::ReadOnly)) {
                delete uploadFile;
                emit uploadHardError(filePath, s3Key, QString("Cannot open for upload: %1").arg(filePath));
                if (m_active > 0) --m_active;
                pump();
                return;
            }
            QNetworkReply *reply = m_nam->put(putReq, uploadFile);
            uploadFile->setParent(reply);
            connect(reply, &QNetworkReply::uploadProgress,
                    this, [this](qint64 sent, qint64 total) {
                        emit uploadProgress(sent, total);
                    });
            connect(reply, &QNetworkReply::finished, this,
                    [this, reply, filePath, s3Key, assetId, objectKey, fileSize, apiBaseUrl, apiToken, sessionId]() {
                const int putCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
                if (reply->error() == QNetworkReply::NoError) {
                    qDebug() << "[StorageWorker] Uploaded:" << assetId << objectKey;
                    emit assetUploaded(assetId);
                    commitAsset(assetId, filePath, objectKey, fileSize, apiBaseUrl, apiToken, sessionId);
                    reply->deleteLater();
                    return;
                } else {
                    qCritical() << "[StorageWorker] FAIL:" << s3Key
                                << reply->errorString() << "HTTP" << putCode;
                    finishFailure(filePath, s3Key, putCode, reply->error(), reply->errorString());
                    reply->deleteLater();
                    return;
                }
                reply->deleteLater();
                if (m_active > 0) --m_active;
                pump();
            });
        });
    }

signals:
    void uploadStarted();
    void uploadFinished(const QString &url, const QString &localFilePath, const QString &s3Key);
    void uploadProgress(qint64 sent, qint64 total);
    // Emitted when upload fails due to network — caller decides how to handle
    void uploadNetworkError(const QString &filePath, const QString &s3Key);
    // Lỗi cứng (HTTP 4xx/5xx, file lỗi…) — KÈM s3Key để caller dọn map/in-flight.
    void uploadHardError(const QString &filePath, const QString &s3Key,
                         const QString &message);
    void assetPrepared(const QString &assetId, qint64 sizeBytes,
                       const QString &checksumSha256, const QString &objectKey,
                       const QString &uploadUrl, const QString &expiresAt);
    void assetUploaded(const QString &assetId);
    void assetConfirmed(const QString &assetId, const QString &url,
                        const QString &localFilePath, const QString &objectKey,
                        qint64 sizeBytes);
    void assetRetry(const QString &assetId, const QString &message, int delaySeconds);
    void assetFailed(const QString &assetId, const QString &message);

private:
    QNetworkAccessManager *m_nam;

    void commitAsset(const QString &assetId, const QString &filePath,
                     const QString &objectKey, qint64 sizeBytes,
                     const QString &apiBaseUrl, const QString &apiToken,
                     const QString &sessionId)
    {
        QNetworkRequest req(QUrl(apiBaseUrl + "/v1/machine/sessions/"
            + QString::fromUtf8(QUrl::toPercentEncoding(sessionId))
            + "/assets/commit"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", QByteArray("Bearer ") + apiToken.toUtf8());
        req.setTransferTimeout(15000);
        QJsonObject payload;
        payload["assets"] = QJsonArray{QJsonObject{{"asset_id", assetId}}};
        QNetworkReply *reply = m_nam->post(req, QJsonDocument(payload).toJson(QJsonDocument::Compact));
        connect(reply, &QNetworkReply::finished, this,
                [this, reply, assetId, filePath, objectKey, sizeBytes]() {
            const int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            const QByteArray body = reply->readAll();
            const auto netErr = reply->error();
            const QString errStr = reply->errorString();
            reply->deleteLater();

            if (netErr != QNetworkReply::NoError || httpCode < 200 || httpCode >= 300) {
                qCritical() << "[StorageWorker] Commit failed:" << assetId << errStr << "HTTP" << httpCode;
                finishFailure(filePath, assetId, httpCode, netErr, errStr);
                return;
            }

            const QJsonObject obj = QJsonDocument::fromJson(body).object();
            const QJsonArray missing = obj.value("missing").toArray();
            for (const QJsonValue &v : missing) {
                if (v.toString() == assetId) {
                    finishFailure(filePath, assetId, 404,
                                  QNetworkReply::ContentNotFoundError,
                                  QStringLiteral("Commit reports missing asset"));
                    return;
                }
            }

            qint64 confirmedSize = sizeBytes;
            QString confirmedKey = objectKey;
            const QJsonArray assets = obj.value("assets").toArray();
            for (const QJsonValue &v : assets) {
                const QJsonObject a = v.toObject();
                if (a.value("asset_id").toString() != assetId) continue;
                confirmedSize = a.value("size_bytes").toVariant().toLongLong();
                confirmedKey = a.value("object_key").toString(objectKey);
                break;
            }
            qDebug() << "[StorageWorker] Confirmed:" << assetId << confirmedKey;
            emit assetConfirmed(assetId, confirmedKey, filePath, confirmedKey, confirmedSize);
            emit uploadFinished(confirmedKey, filePath, confirmedKey);
            if (m_active > 0) --m_active;
            pump();
        });
    }

    void finishFailure(const QString &filePath, const QString &s3Key, int httpCode,
                       QNetworkReply::NetworkError error, const QString &message)
    {
        bool isNetworkError = (httpCode == 0
            || error == QNetworkReply::HostNotFoundError
            || error == QNetworkReply::TimeoutError
            || error == QNetworkReply::OperationCanceledError
            || error == QNetworkReply::TemporaryNetworkFailureError
            || error == QNetworkReply::NetworkSessionFailedError
            || error == QNetworkReply::UnknownNetworkError);

        if (isNetworkError || httpCode == 408 || httpCode == 429 || httpCode >= 500
            || httpCode == 401 || httpCode == 403) {
            emit uploadNetworkError(filePath, s3Key);
            emit assetRetry(s3Key, QString("%1 (HTTP %2)").arg(message).arg(httpCode),
                            retryDelaySeconds(httpCode));
        } else {
            emit uploadHardError(filePath, s3Key,
                QString("%1 (HTTP %2)").arg(message).arg(httpCode));
            emit assetFailed(s3Key, QString("%1 (HTTP %2)").arg(message).arg(httpCode));
        }
        if (m_active > 0) --m_active;
        pump();
    }

    static int retryDelaySeconds(int httpCode)
    {
        if (httpCode == 401 || httpCode == 403)
            return 30 * 60;
        int base = 30;
        if (httpCode == 429) base = 120;
        if (httpCode >= 500) base = 60;
        const int spread = qMax(1, base / 2);
        return base - spread + QRandomGenerator::global()->bounded(spread * 2 + 1);
    }

    static bool hashFile(const QString &filePath, qint64 *sizeBytes, QString *sha256)
    {
        QFile file(filePath);
        if (!file.open(QIODevice::ReadOnly)) return false;
        QCryptographicHash hash(QCryptographicHash::Sha256);
        qint64 total = 0;
        QByteArray buffer;
        buffer.resize(1024 * 1024);
        while (!file.atEnd()) {
            const qint64 n = file.read(buffer.data(), buffer.size());
            if (n < 0) return false;
            if (n == 0) break;
            hash.addData(buffer.constData(), n);
            total += n;
        }
        if (sizeBytes) *sizeBytes = total;
        if (sha256) *sha256 = QString::fromLatin1(hash.result().toHex());
        return true;
    }

    static QString stableAssetId(const QString &sessionId, const QString &objectKey,
                                 const QString &filePath)
    {
        const QByteArray input = QString("%1|%2|%3")
            .arg(sessionId, objectKey, QFileInfo(filePath).fileName()).toUtf8();
        return QString::fromLatin1(QCryptographicHash::hash(input, QCryptographicHash::Sha256).toHex());
    }

    static QString kindForKey(const QString &key)
    {
        if (key.contains("/photos/")) return "photo";
        if (key.endsWith("/photos.json")) return "manifest";
        if (key.contains("/collage.")) return "collage";
        if (key.contains("/video.")) return "video";
        return "other";
    }

    static int photoIndexForKey(const QString &key)
    {
        const QString name = QFileInfo(key).fileName();
        const int underscore = name.indexOf('_');
        if (underscore <= 0) return 0;
        bool ok = false;
        const int n = name.left(underscore).toInt(&ok);
        return ok ? n : 0;
    }

    static QString contentTypeForFile(const QString &filePath)
    {
        const QString ext = QFileInfo(filePath).suffix().toLower();
        if (ext == "jpg" || ext == "jpeg") return "image/jpeg";
        if (ext == "png") return "image/png";
        if (ext == "webp") return "image/webp";
        if (ext == "mp4") return "video/mp4";
        if (ext == "mov") return "video/quicktime";
        if (ext == "json") return "application/json";
        return "application/octet-stream";
    }
};

#include "S3Uploader.moc"

// ─────────────────────────────────────────────────────────────────────────────
// S3Uploader — public API, main thread. Name kept for QML/C++ compatibility.
// ─────────────────────────────────────────────────────────────────────────────

// Gallery mặc định nằm trong LaMoment web tại lamoment.vercel.app/gallery
// (m_galleryBaseUrl); public config "web.gallery_base_url" ghi đè qua setGalleryBaseUrl().
// URL QR: {galleryBase}/{studioId}/{hwid}/{eventId}/{sessionId}

S3Uploader::S3Uploader(QObject *parent)
    : QObject(parent)
    , m_workerThread(new QThread(this))
    , m_worker(new S3UploadWorker)
    , m_bucket("lamoment")
    , m_region("auto")
{
    m_worker->moveToThread(m_workerThread);

    connect(m_workerThread, &QThread::started,  m_worker, &S3UploadWorker::initialize);
    connect(this,     &S3Uploader::_enqueue,    m_worker, &S3UploadWorker::onUpload);
    connect(this,     &S3Uploader::_enqueueAsset, m_worker, &S3UploadWorker::onUploadAsset);

    connect(m_worker, &S3UploadWorker::uploadStarted,
            this,     &S3Uploader::uploadStarted);
    connect(m_worker, &S3UploadWorker::uploadProgress,
            this,     &S3Uploader::uploadProgress);

    connect(m_worker, &S3UploadWorker::assetPrepared,
            this, [this](const QString &assetId, qint64 sizeBytes,
                         const QString &checksumSha256, const QString &objectKey,
                         const QString &uploadUrl, const QString &expiresAt) {
        if (m_dbManager)
            m_dbManager->updateUploadAssetPrepared(assetId, sizeBytes, checksumSha256,
                                                   objectKey, uploadUrl, expiresAt);
    });
    connect(m_worker, &S3UploadWorker::assetUploaded,
            this, [this](const QString &assetId) {
        if (m_dbManager)
            m_dbManager->updateUploadAssetStatus(assetId, "uploaded");
    });
    connect(m_worker, &S3UploadWorker::assetRetry,
            this, [this](const QString &assetId, const QString &message, int delaySeconds) {
        m_inFlightKeys.remove(assetId);
        if (m_dbManager)
            m_dbManager->markUploadAssetRetry(assetId, message, delaySeconds);
        requestPendingRecount();
    });
    connect(m_worker, &S3UploadWorker::assetFailed,
            this, [this](const QString &assetId, const QString &message) {
        m_inFlightKeys.remove(assetId);
        if (m_dbManager)
            m_dbManager->updateUploadAssetStatus(assetId, "failed", message);
        requestPendingRecount();
    });
    connect(m_worker, &S3UploadWorker::assetConfirmed,
            this, [this](const QString &assetId, const QString &url,
                         const QString &localFilePath, const QString &objectKey,
                         qint64 sizeBytes) {
        if (m_dbManager)
            m_dbManager->markUploadAssetConfirmed(assetId, sizeBytes, objectKey);
        m_inFlightKeys.remove(assetId);
        Q_UNUSED(url);
        Q_UNUSED(localFilePath);
        requestPendingRecount();
    });

    // Lỗi cứng (HTTP 4xx/5xx, file lỗi…): KÈM s3Key → dọn map + in-flight
    // (trước đây uploadError không có s3Key nên m_rawPathByKey rò rỉ dần).
    connect(m_worker, &S3UploadWorker::uploadHardError,
            this, [this](const QString &filePath, const QString &s3Key,
                         const QString &message) {
        m_rawPathByKey.remove(s3Key);
        m_eventIdByKey.remove(s3Key);
        m_inFlightKeys.remove(s3Key);
        if (m_dbManager && !m_dbManager->getUploadAssetStatus(s3Key).isEmpty())
            m_dbManager->updateUploadAssetStatus(s3Key, "failed", message);
        qCritical() << "[S3Uploader] Hard error:" << s3Key << message;
        emit uploadError(message);
        Q_UNUSED(filePath);
    });

    // Upload succeeded — delete staged copy if it was from any pending folder
    connect(m_worker, &S3UploadWorker::uploadFinished,
            this, [this](const QString &url, const QString &localFilePath, const QString &s3Key) {
        emit uploadFinished(url);

        // Dọn map entry + in-flight (upload thành công)
        m_rawPathByKey.remove(s3Key);
        m_eventIdByKey.remove(s3Key);
        m_inFlightKeys.remove(s3Key);

        // Xóa file pending ở bất kỳ vị trí nào (appDir fallback hoặc rawPath/pending/)
        bool isPending = localFilePath.startsWith(pendingRootDir())
                      || localFilePath.contains("/pending/");
        if (isPending) {
            QFile::remove(localFilePath);
            qDebug() << "[S3Uploader] Removed pending file after upload:" << localFilePath;

            // Dọn thư mục session rỗng (chỉ còn meta.json)
            QDir sessionDir = QFileInfo(localFilePath).absoluteDir();
            QStringList remaining = sessionDir.entryList(QDir::Files);
            if (remaining.isEmpty() || (remaining.size() == 1 && remaining.first() == "meta.json")) {
                sessionDir.remove("meta.json");
                QDir parent = sessionDir;
                parent.cdUp();
                parent.rmdir(sessionDir.dirName());
            }

            requestPendingRecount();   // đếm trên worker thread, không block UI
        }
    });

    // Upload failed due to network — stage file to pending folder
    connect(m_worker, &S3UploadWorker::uploadNetworkError,
            this, [this](const QString &filePath, const QString &s3Key) {
        // Key: studio/{hwid}/{sessionId}/... — eventId không nằm trong key, lấy từ
        // map lưu lúc dispatch (chỉ dùng để chọn thư mục pending local).
        QString hwid, sessionId;
        if (!parseStorageKey(s3Key, &hwid, &sessionId)) {
            m_inFlightKeys.remove(s3Key);
            requestPendingRecount();
            return;
        }
        const int eventId = m_eventIdByKey.value(s3Key, 0);
        m_eventIdByKey.remove(s3Key);

        // Tra map để lấy rawPath đã lưu khi dispatch — đảm bảo file vào đúng folder event
        QString rawPath = m_rawPathByKey.value(s3Key, QString());
        m_rawPathByKey.remove(s3Key);   // dọn entry
        m_inFlightKeys.remove(s3Key);   // cho phép retry sau này

        qWarning() << "[S3Uploader] Network error, staging to pending:" << s3Key
                   << "| rawPath:" << (rawPath.isEmpty() ? "(appDir fallback)" : rawPath);
        stageFileToPending(filePath, s3Key, hwid, eventId, sessionId, rawPath);
        emit uploadError(QString("No network — queued: %1").arg(QFileInfo(filePath).fileName()));
        requestPendingRecount();
    });

    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    m_workerThread->setObjectName("ObjectStorageUploadThread");
    m_workerThread->start();

    // ── Network monitor ───────────────────────────────────────────────────────
    if (QNetworkInformation::loadDefaultBackend()) {
        connect(QNetworkInformation::instance(),
                &QNetworkInformation::reachabilityChanged,
                this, [this](QNetworkInformation::Reachability reachability) {
            bool isOnline = (reachability == QNetworkInformation::Reachability::Online);
            if (isOnline && !m_isOnline) {
                qDebug() << "[S3Uploader] Network online — retrying pending uploads";
                m_isOnline = true;
                emit networkOnline();
                retryQueuedAssets();
                retryPendingSessions();
            } else if (!isOnline && m_isOnline) {
                qDebug() << "[S3Uploader] Network offline";
                m_isOnline = false;
                emit networkOffline();
            }
        });
    } else {
        qWarning() << "[S3Uploader] QNetworkInformation backend unavailable, using timer-only retry";
    }

    // Periodic retry every 60s as backup
    m_retryTimer = new QTimer(this);
    m_retryTimer->setInterval(60000);
    connect(m_retryTimer, &QTimer::timeout, this, [this]() {
        // Dùng giá trị cache (không quét đĩa trên main thread mỗi 60s).
        // Việc enqueue trùng đã được khử trong enqueueToWorker().
        if (m_isOnline)
            retryQueuedAssets();
        if (m_isOnline && m_cachedPendingCount.load() > 0)
            retryPendingSessions();
        requestPendingRecount();   // làm tươi cache cho lần sau
    });
    m_retryTimer->start();

    // Bản xem tạo lần lượt trên 1 luồng ưu tiên thấp: không giành CPU của live view / lật ảnh.
    m_displayPool.setMaxThreadCount(1);
    m_displayPool.setThreadPriority(QThread::LowPriority);

    // Retry pending from previous session after 5s
    QTimer::singleShot(5000, this, [this]() {
        requestPendingRecount();
        retryQueuedAssets();
        retryPendingSessions();
    });
}

S3Uploader::~S3Uploader()
{
    m_workerThread->quit();
    m_workerThread->wait(5000);
}

// ── Pending folder helpers ────────────────────────────────────────────────────

QString S3Uploader::pendingRootDir() const
{
    return AppPaths::instance().getAppDirectory() + "/pending_uploads";
}

QString S3Uploader::pendingSessionDir(const QString &hwid, int eventId,
                                       const QString &sessionId,
                                       const QString &rawPath) const
{
    if (!rawPath.isEmpty())
        return QString("%1/pending/%2").arg(rawPath, sessionId);
    return QString("%1/%2/%3/%4").arg(pendingRootDir(), hwid).arg(eventId).arg(sessionId);
}

void S3Uploader::stageFileToPending(const QString &filePath, const QString &s3Key,
                                     const QString &hwid, int eventId,
                                     const QString &sessionId,
                                     const QString &rawPath)
{
    // Skip if file is already in a pending folder (retry scenario)
    QString primaryPendingBase = rawPath.isEmpty() ? pendingRootDir()
                                                   : rawPath + "/pending";
    if (filePath.startsWith(primaryPendingBase) || filePath.startsWith(pendingRootDir()))
        return;

    QString sessionDir = pendingSessionDir(hwid, eventId, sessionId, rawPath);
    QDir().mkpath(sessionDir);

    // Copy file into pending session folder, preserving filename
    QString destFile = sessionDir + "/" + QFileInfo(filePath).fileName();
    if (!QFile::exists(destFile))
        QFile::copy(filePath, destFile);

    // Update meta.json — maps filename → s3Key
    QString metaPath = sessionDir + "/meta.json";
    QJsonObject meta;
    {
        QFile mf(metaPath);
        if (mf.open(QIODevice::ReadOnly)) {
            meta = QJsonDocument::fromJson(mf.readAll()).object();
            mf.close();
        }
    }
    meta["hwid"]      = hwid;
    meta["eventId"]   = eventId;
    meta["sessionId"] = sessionId;
    if (!rawPath.isEmpty())
        meta["rawPath"] = rawPath;

    QJsonObject files = meta["files"].toObject();
    files[QFileInfo(filePath).fileName()] = s3Key;
    meta["files"] = files;

    QFile mf(metaPath);
    if (mf.open(QIODevice::WriteOnly)) {
        mf.write(QJsonDocument(meta).toJson(QJsonDocument::Compact));
        mf.close();
    }

    qDebug() << "[S3Uploader] Staged to pending:" << destFile << "→" << s3Key;

    // Nếu staged vào event-local rawPath, ghi index vào appDir để retryPendingSessions
    // có thể tìm lại rawPath sau khi restart app
    if (!rawPath.isEmpty()) {
        QString indexDir  = QString("%1/%2/%3/%4").arg(pendingRootDir(), hwid).arg(eventId).arg(sessionId);
        QDir().mkpath(indexDir);
        QString indexPath = indexDir + "/meta.json";
        QJsonObject idxMeta;
        {
            QFile mf(indexPath);
            if (mf.open(QIODevice::ReadOnly)) {
                idxMeta = QJsonDocument::fromJson(mf.readAll()).object();
                mf.close();
            }
        }
        idxMeta["hwid"]      = hwid;
        idxMeta["eventId"]   = eventId;
        idxMeta["sessionId"] = sessionId;
        idxMeta["rawPath"]   = rawPath;   // ← key: để retryPendingSessions scan được rawPath
        // Không ghi "files" vào đây — files thực tế nằm ở rawPath/pending/
        QFile mf(indexPath);
        if (mf.open(QIODevice::WriteOnly)) {
            mf.write(QJsonDocument(idxMeta).toJson(QJsonDocument::Compact));
            mf.close();
        }
    }
}

// Retry all sessions found inside a pending root directory
// pendingRoot layout: {pendingRoot}/{sessionId}/meta.json  (for event-local)
//                  or {pendingRoot}/{hwid}/{eventId}/{sessionId}/meta.json  (for appDir fallback)
// We detect by checking if direct subdirs contain meta.json (event-local) or go deeper (appDir).
void S3Uploader::retryPendingSessions()
{
    CloudApiCredentials creds = loadCredentials();
    if (!creds.isValid()) {
        qWarning() << "[S3Uploader] retryPendingSessions: no Cloud API credentials";
        return;
    }

    // Helper lambda: retry all files from a session dir that has meta.json
    auto retrySessionDir = [&](const QString &sessionDir) {
        QString metaPath = sessionDir + "/meta.json";
        QFile mf(metaPath);
        if (!mf.open(QIODevice::ReadOnly)) return;
        QJsonObject meta = QJsonDocument::fromJson(mf.readAll()).object();
        mf.close();

        QJsonObject files = meta["files"].toObject();
        qDebug() << "[S3Uploader] Retrying session" << QFileInfo(sessionDir).fileName()
                 << "—" << files.count() << "files";

        for (auto it = files.constBegin(); it != files.constEnd(); ++it) {
            QString pendingFile = sessionDir + "/" + it.key();
            QString s3Key       = it.value().toString();
            if (!QFile::exists(pendingFile)) continue;
            // enqueueToWorker khử trùng lặp: nếu s3Key đang upload sẽ bỏ qua,
            // tránh "bão" enqueue lại cùng file từ timer/online/startup.
            enqueueToWorker(pendingFile, s3Key, creds.baseUrl, creds.token);
        }
    };

    // 1. Scan appDir fallback: {pendingRoot}/{hwid}/{eventId}/{sessionId}/
    QDir root(pendingRootDir());
    if (root.exists()) {
        for (const QString &hwidDir : root.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
            QDir hwidPath(root.filePath(hwidDir));
            for (const QString &eventDir : hwidPath.entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
                QDir eventPath(hwidPath.filePath(eventDir));
                for (const QString &sessDir : eventPath.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
                    retrySessionDir(eventPath.filePath(sessDir));
            }
        }
    }

    // 2. Scan event-local pending: {rawPath}/pending/{sessionId}/
    //    rawPath is stored in meta.json so we discover them via appDir meta entries first,
    //    then read rawPath from meta and scan those too.
    //    For event-local folders, scan all known rawPaths from DB is not accessible here.
    //    Instead: scan pending dirs that were stored with rawPath in meta.json.
    //    They were already retried in step 1 (appDir copy). But if staged directly to rawPath,
    //    we need a separate scan. We use QDirIterator on appDir to find rawPath values in metas.
    QSet<QString> scannedRawPending;
    QDirIterator metaIt(pendingRootDir(), QStringList() << "meta.json",
                        QDir::Files, QDirIterator::Subdirectories);
    while (metaIt.hasNext()) {
        metaIt.next();
        QFile mf(metaIt.filePath());
        if (!mf.open(QIODevice::ReadOnly)) continue;
        QJsonObject meta = QJsonDocument::fromJson(mf.readAll()).object();
        mf.close();
        QString rp = meta["rawPath"].toString();
        if (rp.isEmpty() || scannedRawPending.contains(rp)) continue;
        scannedRawPending.insert(rp);
        QDir pendingDir(rp + "/pending");
        if (!pendingDir.exists()) continue;
        for (const QString &sessDir : pendingDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot))
            retrySessionDir(pendingDir.filePath(sessDir));
    }
}

int S3Uploader::countPendingFiles() const
{
    int count = 0;

    // 1. appDir fallback tree
    QDirIterator it(pendingRootDir(), QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        it.next();
        if (it.fileName() != "meta.json") ++count;
    }

    // 2. rawPath/pending/ — tìm qua index meta.json trong appDir
    QSet<QString> scanned;
    QDirIterator metaIt(pendingRootDir(), QStringList() << "meta.json",
                        QDir::Files, QDirIterator::Subdirectories);
    while (metaIt.hasNext()) {
        metaIt.next();
        QFile mf(metaIt.filePath());
        if (!mf.open(QIODevice::ReadOnly)) continue;
        QJsonObject meta = QJsonDocument::fromJson(mf.readAll()).object();
        mf.close();
        QString rp = meta["rawPath"].toString();
        if (rp.isEmpty() || scanned.contains(rp)) continue;
        scanned.insert(rp);
        QDirIterator pit(rp + "/pending", QDir::Files, QDirIterator::Subdirectories);
        while (pit.hasNext()) {
            pit.next();
            if (pit.fileName() != "meta.json") ++count;
        }
    }

    return count;
}

// Trả về giá trị CACHE (không quét đĩa trên main/QML thread).
// Cache được làm tươi bởi requestPendingRecount() chạy ở worker thread.
int S3Uploader::pendingCount() const
{
    return m_cachedPendingCount.load()
        + (m_dbManager ? m_dbManager->uploadAssetPendingCount() : 0);
}

void S3Uploader::enqueueToWorker(const QString &filePath, const QString &s3Key,
                                 const QString &apiBaseUrl, const QString &apiToken)
{
    if (m_inFlightKeys.contains(s3Key)) {
        qDebug() << "[S3Uploader] Skip duplicate in-flight:" << s3Key;
        return;
    }
    m_inFlightKeys.insert(s3Key);
    emit _enqueue(filePath, s3Key, m_bucket, m_region, m_publicBaseUrl, apiBaseUrl, apiToken);
}

static QString localAssetId(const QString &hwid, const QString &sessionId,
                            const QString &kind, int photoIndex,
                            const QString &filePath)
{
    const QByteArray input = QString("%1|%2|%3|%4|%5")
        .arg(hwid, sessionId, kind)
        .arg(photoIndex)
        .arg(QFileInfo(filePath).fileName()).toUtf8();
    return QString::fromLatin1(QCryptographicHash::hash(input, QCryptographicHash::Sha256).toHex());
}

static QString localContentTypeForFile(const QString &filePath)
{
    const QString ext = QFileInfo(filePath).suffix().toLower();
    if (ext == "jpg" || ext == "jpeg") return "image/jpeg";
    if (ext == "png") return "image/png";
    if (ext == "webp") return "image/webp";
    if (ext == "mp4") return "video/mp4";
    if (ext == "mov") return "video/quicktime";
    if (ext == "json") return "application/json";
    return "application/octet-stream";
}

// ── Bản xem (display copies) ─────────────────────────────────────────────────
// Ảnh gốc ~20 MB giữ nguyên tuyệt đối (tải về, in luôn dùng ảnh gốc). Hai bản nhỏ chỉ để
// hiển thị trên web: lưới ảnh dùng thumbnail, xem lớn / ô chỉnh sửa dùng preview.
static constexpr int kThumbShortEdge = 720;
static constexpr int kPreviewLongEdge = 2048;
static constexpr int kDisplayJpegQuality = 90;

static bool saveDisplayJpeg(const QImage &image, const QString &path)
{
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly))
        return false;
    QImageWriter writer(&file, "jpg");
    writer.setQuality(kDisplayJpegQuality);
    writer.setOptimizedWrite(true);
    if (!writer.write(image)) {
        file.cancelWriting();
        return false;
    }
    return file.commit();
}

// Đọc ảnh gốc một lần ở cỡ preview (JPEG giải mã thẳng ở 1/2, 1/4… nên nhanh, ít RAM),
// rồi thu tiếp ra thumbnail. Chạy trên luồng nền.
static bool writeDisplayCopies(const QString &photoPath, const QString &thumbPath,
                               const QString &previewPath)
{
    QImageReader reader(photoPath);
    reader.setAutoTransform(true);   // đúng chiều như trình duyệt hiển thị ảnh gốc
    const QSize full = reader.size();
    if (!full.isValid())
        return false;
    if (qMax(full.width(), full.height()) > kPreviewLongEdge)
        reader.setScaledSize(full.scaled(kPreviewLongEdge, kPreviewLongEdge, Qt::KeepAspectRatio));
    QImage preview = reader.read();
    if (preview.isNull()) {
        qWarning() << "[S3Uploader] Display copy: cannot read" << photoPath << reader.errorString();
        return false;
    }
    if (preview.format() != QImage::Format_RGB32 && preview.format() != QImage::Format_ARGB32)
        preview = preview.convertToFormat(QImage::Format_RGB32);

    QImage thumb = preview;
    const int shortEdge = qMin(preview.width(), preview.height());
    if (shortEdge > kThumbShortEdge) {
        const double f = double(kThumbShortEdge) / shortEdge;
        thumb = preview.scaled(qRound(preview.width() * f), qRound(preview.height() * f),
                               Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    }
    return saveDisplayJpeg(thumb, thumbPath) && saveDisplayJpeg(preview, previewPath);
}

void S3Uploader::scheduleDisplayCopies(const QString &photoAssetId, const QString &photoPath,
                                       const QString &hwid, int eventId,
                                       const QString &sessionId, int photoIndex)
{
    if (m_displayRequested.contains(photoAssetId))
        return;
    m_displayRequested.insert(photoAssetId);

    // <thư mục ảnh>/.display/<tên ảnh>_thumb.jpg | _preview.jpg
    const QFileInfo info(photoPath);
    const QString dir = info.absolutePath() + QStringLiteral("/.display");
    const QString thumbPath = QDir(dir).filePath(info.completeBaseName() + QStringLiteral("_thumb.jpg"));
    const QString previewPath = QDir(dir).filePath(info.completeBaseName() + QStringLiteral("_preview.jpg"));

    (void)QtConcurrent::run(&m_displayPool, [this, photoAssetId, photoPath, thumbPath, previewPath,
                                             dir, hwid, eventId, sessionId, photoIndex]() {
        bool ok = QFile::exists(thumbPath) && QFile::exists(previewPath);
        if (!ok) {
            QDir().mkpath(dir);
            ok = writeDisplayCopies(photoPath, thumbPath, previewPath);
        }
        if (!ok) {
            qWarning() << "[S3Uploader] Display copies failed (web falls back to the original):" << photoPath;
            return;
        }
        QMetaObject::invokeMethod(this, [this, photoAssetId, thumbPath, previewPath,
                                         hwid, eventId, sessionId, photoIndex]() {
            // Id gắn với ảnh gốc ("thumb-"/"prev-" + id ảnh): server ghép đúng ảnh, kể cả khi
            // trình duyệt khách đã tạo thumbnail cùng id trước (server báo đã có → xong).
            dispatchAsset(thumbPath, hwid, eventId, sessionId, QStringLiteral("thumbnail"), photoIndex,
                          QString(), QStringLiteral("thumb-") + photoAssetId);
            dispatchAsset(previewPath, hwid, eventId, sessionId, QStringLiteral("preview"), photoIndex,
                          QString(), QStringLiteral("prev-") + photoAssetId);
        }, Qt::QueuedConnection);
    });
}

void S3Uploader::dispatchAsset(const QString &filePath, const QString &hwid, int eventId,
                               const QString &sessionId, const QString &kind,
                               int photoIndex, const QString &objectKeyHint,
                               const QString &assetIdOverride)
{
    if (!m_dbManager) {
        qWarning() << "[S3Uploader] dispatchAsset: no DatabaseManager, fallback legacy upload";
        if (!objectKeyHint.isEmpty())
            dispatch(filePath, objectKeyHint, hwid, eventId, sessionId, m_currentEventRawPath);
        return;
    }

    QString cleanPath = filePath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    cleanPath = QDir::toNativeSeparators(cleanPath);

    if (hwid.trimmed().isEmpty() || sessionId.trimmed().isEmpty() || cleanPath.isEmpty()) {
        emit uploadError("Missing upload asset identity");
        return;
    }

    UploadAsset asset;
    asset.assetId = assetIdOverride.isEmpty()
        ? localAssetId(hwid, sessionId, kind, photoIndex, cleanPath)
        : assetIdOverride;
    asset.sessionId = sessionId;
    asset.kind = kind.isEmpty() ? QStringLiteral("other") : kind;
    asset.localPath = cleanPath;
    asset.fileName = QFileInfo(cleanPath).fileName();
    asset.contentType = localContentTypeForFile(cleanPath);
    asset.photoIndex = photoIndex;
    asset.objectKey = objectKeyHint;
    asset.status = QStringLiteral("pending");
    if (!m_dbManager->upsertUploadAsset(asset)) {
        emit uploadError("Cannot persist upload asset " + asset.fileName);
        return;
    }

    qDebug() << "[S3Uploader] Queued asset" << asset.assetId
             << "session" << sessionId << "kind" << asset.kind << "path" << cleanPath;
    retryQueuedAssets();
    requestPendingRecount();

    if (asset.kind == QLatin1String("photo")) {
        scheduleDisplayCopies(asset.assetId, cleanPath, hwid, eventId, sessionId, photoIndex);
        // Ảnh tới sau khi phiên đã báo /finalize (ảnh về trễ): báo lại danh sách có ảnh này.
        if (m_finalizedSessions.contains(sessionId))
            finalizeSession(sessionId);
    }
}

void S3Uploader::finalizeSession(const QString &sessionId)
{
    const QString sid = sessionId.trimmed();
    if (sid.isEmpty() || !m_dbManager)
        return;
    m_finalizedSessions.insert(sid);
    // Gom nhiều lần gọi liền nhau (vd lưu phiên đưa lại cả loạt ảnh) thành một lần gửi.
    constexpr int kFinalizeDebounceMs = 1500;
    m_finalizePending.insert(sid, QDateTime::currentMSecsSinceEpoch() + kFinalizeDebounceMs);
    QTimer::singleShot(kFinalizeDebounceMs + 50, this, [this, sid]() { sendFinalize(sid); });
}

void S3Uploader::sendFinalize(const QString &sessionId)
{
    if (!m_finalizePending.contains(sessionId) || m_finalizeInFlight.contains(sessionId))
        return;
    if (QDateTime::currentMSecsSinceEpoch() < m_finalizePending.value(sessionId))
        return;   // còn trong khoảng gom; hẹn giờ của finalizeSession sẽ gửi
    CloudApiCredentials creds = loadCredentials();
    if (!creds.isValid() || !m_isOnline || m_simulateOffline)
        return;   // gửi lại ở retryQueuedAssets() khi có mạng

    const QStringList ids = m_dbManager->uploadAssetIdsForSession(sessionId, QStringLiteral("photo"));
    if (ids.isEmpty()) {
        m_finalizePending.remove(sessionId);
        return;
    }
    QJsonArray expected;
    for (const QString &id : ids)
        expected.append(id);
    QJsonObject payload;
    payload["expected_asset_ids"] = expected;
    payload["status"] = QStringLiteral("COMPLETED");   // chỉ dùng khi server chưa có phiên này
    payload["photos_count"] = int(ids.size());

    QNetworkRequest request(QUrl(creds.baseUrl + "/v1/machine/sessions/"
        + QString::fromUtf8(QUrl::toPercentEncoding(sessionId)) + "/finalize"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + creds.token.toUtf8());
    request.setTransferTimeout(15000);

    m_finalizePending.remove(sessionId);
    m_finalizeInFlight.insert(sessionId);
    auto *manager = new QNetworkAccessManager(this);
    QNetworkReply *reply = manager->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, manager, sessionId, count = ids.size()]() {
        const int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto netErr = reply->error();
        const QString err = reply->errorString();
        reply->deleteLater();
        manager->deleteLater();
        m_finalizeInFlight.remove(sessionId);
        if (netErr != QNetworkReply::NoError || httpCode < 200 || httpCode >= 300) {
            qWarning() << "[S3Uploader] Finalize failed, will retry:" << sessionId << err << "HTTP" << httpCode;
            // 4xx khác 401/403/408/429 là lỗi dữ liệu: không thử lại vô hạn.
            if (httpCode == 0 || httpCode >= 500 || httpCode == 401 || httpCode == 403
                || httpCode == 408 || httpCode == 429)
                m_finalizePending.insert(sessionId, 0);
            return;
        }
        qDebug() << "[S3Uploader] Finalized session" << sessionId << "with" << count << "photos";
    });
}

void S3Uploader::retryQueuedAssets()
{
    if (!m_dbManager) return;
    CloudApiCredentials creds = loadCredentials();
    if (!creds.isValid() || !m_isOnline || m_simulateOffline)
        return;
    const QVariantList jobs = m_dbManager->pendingUploadAssets(24);
    for (const QVariant &v : jobs) {
        const QVariantMap job = v.toMap();
        const QString assetId = job.value("asset_id").toString();
        if (assetId.isEmpty() || m_inFlightKeys.contains(assetId))
            continue;
        if (!QFile::exists(job.value("local_path").toString())) {
            m_dbManager->updateUploadAssetStatus(assetId, "failed", "local_file_missing");
            continue;
        }
        m_inFlightKeys.insert(assetId);
        emit _enqueueAsset(job, creds.baseUrl, creds.token);
    }
    // /finalize chưa gửi được (mất mạng / lỗi server) → gửi lại khi có mạng.
    const QStringList finalizeRetry = m_finalizePending.keys();
    for (const QString &sid : finalizeRetry)
        sendFinalize(sid);
}

QString S3Uploader::publicUrlFor(const QString &s3Key) const
{
    if (!m_publicBaseUrl.isEmpty())
        return QString("%1/%2").arg(m_publicBaseUrl, s3Key);
    if (m_region == "auto")
        return s3Key;
    return QString("https://%1.s3.%2.amazonaws.com/%3")
        .arg(m_bucket, m_region, s3Key);
}

void S3Uploader::requestPendingRecount()
{
    // Quét đĩa (đệ quy + đọc mọi meta.json) RẤT nặng khi nhiều file pending.
    // Chạy trên worker thread để KHÔNG đơ UI; chỉ countPendingFiles() (const,
    // chỉ đọc filesystem) chạy ở đó — không chạm state chia sẻ.
    QMetaObject::invokeMethod(m_worker, [this]() {
        int c = countPendingFiles();
        QMetaObject::invokeMethod(this, [this, c]() {
            const int total = c + (m_dbManager ? m_dbManager->uploadAssetPendingCount() : 0);
            m_cachedPendingCount.store(c);
            emit pendingCountChanged(total);
        }, Qt::QueuedConnection);
    }, Qt::QueuedConnection);
}

void S3Uploader::setSimulateOffline(bool offline)
{
    if (m_simulateOffline == offline) return;
    m_simulateOffline = offline;
    m_isOnline = !offline;
    qDebug() << "[S3Uploader] Simulate offline:" << offline;
    if (offline) {
        emit networkOffline();
    } else {
        emit networkOnline();
        retryQueuedAssets();
        retryPendingSessions();
    }
}

// Đếm file pending thuộc về một event cụ thể
// Scan cả 2 vị trí: appDir fallback ({pendingRoot}/{hwid}/{eventId}/)
// và event-local (rawPath/pending/) qua meta.json
int S3Uploader::pendingCountForEvent(const QString &hwid, int eventId) const
{
    if (hwid.isEmpty() || eventId <= 0) return 0;

    int count = 0;

    // 1. appDir fallback: {pendingRoot}/{hwid}/{eventId}/{sessionId}/
    QDir eventDir(QString("%1/%2/%3").arg(pendingRootDir(), hwid).arg(eventId));
    if (eventDir.exists()) {
        QDirIterator it(eventDir.absolutePath(), QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            it.next();
            if (it.fileName() != "meta.json") ++count;
        }
    }

    // 2. Event-local: đọc meta.json từ appDir fallback để tìm rawPath,
    //    sau đó đếm trong rawPath/pending/
    QSet<QString> scannedRawPending;
    if (eventDir.exists()) {
        QDirIterator metaIt(eventDir.absolutePath(), QStringList() << "meta.json",
                            QDir::Files, QDirIterator::Subdirectories);
        while (metaIt.hasNext()) {
            metaIt.next();
            QFile mf(metaIt.filePath());
            if (!mf.open(QIODevice::ReadOnly)) continue;
            QJsonObject meta = QJsonDocument::fromJson(mf.readAll()).object();
            mf.close();
            QString rp = meta["rawPath"].toString();
            if (rp.isEmpty() || scannedRawPending.contains(rp)) continue;
            scannedRawPending.insert(rp);
            QDir pendingDir(rp + "/pending");
            if (!pendingDir.exists()) continue;
            QDirIterator pit(pendingDir.absolutePath(), QDir::Files,
                             QDirIterator::Subdirectories);
            while (pit.hasNext()) {
                pit.next();
                if (pit.fileName() != "meta.json") ++count;
            }
        }
    }

    return count;
}

// ── Credentials ───────────────────────────────────────────────────────────────

// Upload chỉ chạy bằng token riêng của máy (studio đã đăng nhập). Chưa có token →
// creds rỗng → dispatch/retry giữ file trong hàng chờ local, đăng nhập xong mới đẩy.
S3Uploader::CloudApiCredentials S3Uploader::loadCredentials()
{
    CloudApiCredentials creds;
    ConfigManager *cfg = ConfigManager::instance();
    if (!cfg || !cfg->hasMachineToken())
        return creds;
    creds.baseUrl = cfg->cloudApiBaseUrl();
    creds.token = cfg->cloudApiToken();
    return creds;
}

QString S3Uploader::getAccessKey() { return QString(); }
QString S3Uploader::getSecretKey() { return QString(); }

bool S3Uploader::saveCredentials(const QString &accessKey, const QString &secretKey)
{
    Q_UNUSED(accessKey);
    Q_UNUSED(secretKey);
    qWarning() << "[S3Uploader] Refusing to save storage credentials on desktop";
    return false;
}

// ── User info ─────────────────────────────────────────────────────────────────

void S3Uploader::setUserInfo(const QString &phone, const QString &name)
{
    m_userPhone = phone.trimmed();
    m_userName  = name.trimmed().replace(QRegularExpression("[^A-Za-z0-9\\p{L}]"), "_");
}

void S3Uploader::clearUserInfo() { m_userPhone.clear(); m_userName.clear(); }

QString S3Uploader::buildRootPrefix(const QString &hwid) const { return hwid; }

QString S3Uploader::buildSessionUrl(const QString &hwid, int eventId,
                                     const QString &sessionId) const
{
    // {galleryBase}/{studioId}/{hwid}/{eventId}/{sessionId}
    const int sid = m_studioId > 0 ? m_studioId : 0;
    return QString("%1/%2/%3/%4/%5")
        .arg(m_galleryBaseUrl).arg(sid).arg(buildRootPrefix(hwid)).arg(eventId).arg(sessionId);
}

QString S3Uploader::buildEventUrl(const QString &hwid, int eventId) const
{
    // {galleryBase}/{studioId}/{hwid}/{eventId}
    const int sid = m_studioId > 0 ? m_studioId : 0;
    return QString("%1/%2/%3/%4")
        .arg(m_galleryBaseUrl).arg(sid).arg(buildRootPrefix(hwid)).arg(eventId);
}

// ── Internal dispatch ─────────────────────────────────────────────────────────

void S3Uploader::dispatch(const QString &filePath, const QString &s3Key,
                           const QString &hwid, int eventId,
                           const QString &sessionId, const QString &rawPath)
{
    CloudApiCredentials creds = loadCredentials();
    const bool canStage = !hwid.isEmpty() && eventId > 0 && !sessionId.isEmpty();

    QString cleanPath = filePath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);

    // Máy chưa gắn studio (chưa đăng nhập): giữ file ở hàng chờ local, đăng nhập xong
    // StudioAccount gọi retryPendingSessions() để đẩy lên.
    if (!creds.isValid()) {
        if (canStage) {
            qDebug() << "[S3Uploader] Not signed in to a studio, staging:" << s3Key;
            stageFileToPending(cleanPath, s3Key, hwid, eventId, sessionId, rawPath);
            requestPendingRecount();
        } else {
            emit uploadError("Chưa đăng nhập studio — không upload được " + QFileInfo(cleanPath).fileName());
        }
        return;
    }

    if ((!m_isOnline || m_simulateOffline) && canStage) {
        qDebug() << "[S3Uploader] Offline, staging directly:" << s3Key;
        stageFileToPending(cleanPath, s3Key, hwid, eventId, sessionId, rawPath);
        requestPendingRecount();
        return;
    }

    // Lưu rawPath + eventId để staging đúng folder nếu worker báo network error
    // (eventId không còn nằm trong key studio/<hwid>/<sessionId>/...).
    m_rawPathByKey[s3Key] = rawPath;
    m_eventIdByKey[s3Key] = eventId;

    qDebug() << "[S3Uploader] Dispatching:" << s3Key;
    enqueueToWorker(cleanPath, s3Key, creds.baseUrl, creds.token);
}

// ── Session-based upload methods ──────────────────────────────────────────────

// Tiền tố key của một phiên trên R2: studio/<hwid>/<sessionId> (không có eventId;
// eventId vẫn ghi trong photos.json).
static QString sessionKeyPrefix(const QString &hwid, const QString &sessionId)
{
    return QString("%1/%2/%3").arg(kStorageRoot, hwid, sessionId);
}

void S3Uploader::uploadSessionPhoto(const QString &filePath, const QString &hwid,
                                    int eventId, const QString &sessionId, int photoIndex)
{
    QString fileName = QFileInfo(filePath).fileName();
    QString s3Key = QString("%1/photos/%2_%3")
                        .arg(sessionKeyPrefix(hwid, sessionId))
                        .arg(photoIndex, 3, 10, QChar('0')).arg(fileName);
    dispatchAsset(filePath, hwid, eventId, sessionId, "photo", photoIndex, s3Key);
}

void S3Uploader::uploadCollage(const QString &filePath, const QString &hwid,
                               int eventId, const QString &sessionId)
{
    QString s3Key = QString("%1/collage.%2")
                        .arg(sessionKeyPrefix(hwid, sessionId), QFileInfo(filePath).suffix());
    dispatchAsset(filePath, hwid, eventId, sessionId, "collage", 0, s3Key);
}

void S3Uploader::uploadVideo(const QString &filePath, const QString &hwid,
                             int eventId, const QString &sessionId)
{
    QString s3Key = QString("%1/video.%2")
                        .arg(sessionKeyPrefix(hwid, sessionId), QFileInfo(filePath).suffix());
    dispatchAsset(filePath, hwid, eventId, sessionId, "video", 0, s3Key);
}

void S3Uploader::uploadManifest(const QString &filePath, const QString &hwid,
                                int eventId, const QString &sessionId)
{
    QString s3Key = QString("%1/photos.json").arg(sessionKeyPrefix(hwid, sessionId));
    dispatchAsset(filePath, hwid, eventId, sessionId, "manifest", 0, s3Key);
}

void S3Uploader::uploadSessionPhotos(const QStringList &filePaths, const QString &hwid,
                                     int eventId, const QString &sessionId)
{
    for (int i = 0; i < filePaths.count(); ++i)
        uploadSessionPhoto(filePaths.at(i), hwid, eventId, sessionId, i + 1);
}

void S3Uploader::enqueueCaptureAsset(const QString &filePath,
                                     const QString &hwid,
                                     int eventId,
                                     const QString &sessionId,
                                     const QString &kind,
                                     int photoIndex)
{
    dispatchAsset(filePath, hwid, eventId, sessionId, kind, photoIndex);
}

void S3Uploader::uploadFile(const QString &filePath)
{
    dispatch(filePath, QFileInfo(filePath).fileName());
}

void S3Uploader::uploadFileWithPath(const QString &filePath, const QString &s3Key)
{
    QString key = s3Key;
    if (!key.startsWith(kStorageRoot + "/"))
        key = kStorageRoot + "/" + key;
    dispatch(filePath, key);
}

void S3Uploader::submitGuestShareConsent(const QString &hwid, int eventId,
                                          const QString &sessionId, bool allowed,
                                          const QString &galleryUrl)
{
    CloudApiCredentials creds = loadCredentials();
    if (!creds.isValid()) {
        emit uploadError("Missing Cloud API credentials");
        return;
    }
    if (hwid.trimmed().isEmpty() || eventId <= 0 || sessionId.trimmed().isEmpty()) {
        emit uploadError("Missing guest share identity");
        return;
    }

    QUrl url(creds.baseUrl + "/shared-moments/consent");
    QNetworkRequest request(url);
    request.setRawHeader("Content-Type", "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + creds.token.toUtf8());
    request.setTransferTimeout(15000);

    QJsonObject payload;
    payload["hwid"] = hwid.trimmed();
    payload["event_id"] = eventId;
    payload["session_id"] = sessionId.trimmed();
    payload["allowed"] = allowed;
    payload["gallery_url"] = galleryUrl.trimmed();

    auto *manager = new QNetworkAccessManager(this);
    QNetworkReply *reply = manager->post(
        request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, manager]() {
        const int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto netErr = reply->error();
        const QString err = reply->errorString();
        reply->deleteLater();
        manager->deleteLater();
        if (netErr != QNetworkReply::NoError || httpCode < 200 || httpCode >= 300) {
            emit uploadError(QString("Guest share consent failed: %1 (HTTP %2)").arg(err).arg(httpCode));
        }
    });
}

void S3Uploader::requestGalleryLink(const QString &sessionId)
{
    const QString sid = sessionId.trimmed();
    if (sid.isEmpty()) return;
    if (m_galleryLinks.contains(sid)) {
        emit galleryLinkReady(sid, m_galleryLinks.value(sid));
        return;
    }
    if (m_galleryLinkPending.contains(sid)) return;

    CloudApiCredentials creds = loadCredentials();
    if (!creds.isValid()) {
        emit galleryLinkFailed(sid, QStringLiteral("Máy chưa đăng nhập studio"));
        return;
    }

    QNetworkRequest request(QUrl(creds.baseUrl + "/v1/machine/sessions/"
        + QString::fromUtf8(QUrl::toPercentEncoding(sid)) + "/gallery-link"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QByteArray("Bearer ") + creds.token.toUtf8());
    request.setTransferTimeout(15000);

    m_galleryLinkPending.insert(sid);
    auto *manager = new QNetworkAccessManager(this);
    QNetworkReply *reply = manager->post(request, QByteArray("{}"));
    connect(reply, &QNetworkReply::finished, this, [this, reply, manager, sid]() {
        const int httpCode = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const auto netErr = reply->error();
        const QString err = reply->errorString();
        const QByteArray body = reply->readAll();
        reply->deleteLater();
        manager->deleteLater();
        m_galleryLinkPending.remove(sid);

        const QString url = QJsonDocument::fromJson(body).object().value("url").toString();
        if (netErr != QNetworkReply::NoError || httpCode < 200 || httpCode >= 300 || url.isEmpty()) {
            qWarning() << "[S3Uploader] Gallery link failed:" << sid << err << "HTTP" << httpCode;
            emit galleryLinkFailed(sid, err.isEmpty() ? QStringLiteral("HTTP %1").arg(httpCode) : err);
            return;
        }
        m_galleryLinks.insert(sid, url);
        emit galleryLinkReady(sid, url);
    });
}

void S3Uploader::setConfig(const QString &bucket, const QString &region,
                           const QString &publicBaseUrl)
{
    m_bucket        = bucket;
    m_region        = region;
    m_publicBaseUrl = publicBaseUrl;
    while (m_publicBaseUrl.endsWith('/'))
        m_publicBaseUrl.chop(1);
}

void S3Uploader::setGalleryBaseUrl(const QString &url)
{
    QString clean = url.trimmed();
    while (clean.endsWith('/'))
        clean.chop(1);
    if (clean.isEmpty())
        return;
    m_galleryBaseUrl = clean;
}
