#ifndef S3UPLOADER_H
#define S3UPLOADER_H

#include <QObject>
#include <QThread>
#include <QThreadPool>
#include <QTimer>
#include <QHash>
#include <QSet>
#include <QVariantMap>
#include <atomic>

class S3UploadWorker;
class DatabaseManager;

class S3Uploader : public QObject
{
    Q_OBJECT
public:
    explicit S3Uploader(QObject *parent = nullptr);
    ~S3Uploader();

    // Cấu hình object storage. Upload dùng presigned URL do Cloudflare Worker
    // cấp, vì vậy desktop không giữ R2/S3 secret.
    Q_INVOKABLE void setConfig(const QString &bucket, const QString &region,
                               const QString &publicBaseUrl);
    void setDatabaseManager(DatabaseManager *db) { m_dbManager = db; }
    // Gốc link gallery trong QR (public config "web.gallery_base_url"). Rỗng = giữ mặc định.
    void setGalleryBaseUrl(const QString &url);
    QString galleryBaseUrl() const { return m_galleryBaseUrl; }

    // Session-based uploads
    Q_INVOKABLE void uploadSessionPhoto(const QString &filePath, const QString &hwid,
                                        int eventId, const QString &sessionId, int photoIndex);
    Q_INVOKABLE void uploadCollage(const QString &filePath, const QString &hwid,
                                   int eventId, const QString &sessionId);
    Q_INVOKABLE void uploadVideo(const QString &filePath, const QString &hwid,
                                 int eventId, const QString &sessionId);
    Q_INVOKABLE void uploadSessionPhotos(const QStringList &filePaths, const QString &hwid,
                                         int eventId, const QString &sessionId);
    Q_INVOKABLE void uploadManifest(const QString &filePath, const QString &hwid,
                                    int eventId, const QString &sessionId);

    // Generic upload with explicit object key
    Q_INVOKABLE void uploadFile(const QString &filePath);
    Q_INVOKABLE void uploadFileWithPath(const QString &filePath, const QString &s3Key);
    Q_INVOKABLE void enqueueCaptureAsset(const QString &filePath,
                                         const QString &hwid,
                                         int eventId,
                                         const QString &sessionId,
                                         const QString &kind,
                                         int photoIndex = 0);
    Q_INVOKABLE void submitGuestShareConsent(const QString &hwid, int eventId,
                                             const QString &sessionId, bool allowed,
                                             const QString &galleryUrl);

    // Báo server danh sách ảnh của phiên (POST /finalize) khi chụp xong: server đánh dấu
    // phiên "synced" khi ảnh cuối lên, web hết báo "Đang nhận ảnh". Mất mạng → tự gửi lại.
    // Ảnh tới sau khi đã báo (ảnh về trễ) → tự báo lại danh sách mới.
    Q_INVOKABLE void finalizeSession(const QString &sessionId);

    // Link album web cho QR (https://.../gallery?t=gal_...). Server tạo token ngẫu nhiên
    // theo phiên nên khách không đoán được album người khác. Kết quả trả qua
    // galleryLinkReady / galleryLinkFailed; link đã có được nhớ theo sessionId.
    Q_INVOKABLE void requestGalleryLink(const QString &sessionId);
    Q_INVOKABLE QString cachedGalleryLink(const QString &sessionId) const { return m_galleryLinks.value(sessionId); }

    // Credentials
    Q_INVOKABLE QString getAccessKey();
    Q_INVOKABLE QString getSecretKey();
    Q_INVOKABLE bool saveCredentials(const QString &accessKey, const QString &secretKey);

    // HWID / User info
    void setCurrentHWID(const QString &hwid) { m_currentHWID = hwid; }
    QString getCurrentHWID() const { return m_currentHWID; }

    // Studio id (chủ studio) — tiền tố URL gallery /{studioId}/{hwid}/...
    // 0 = chưa biết (vẫn xem được vì trang ảnh định vị theo hwid).
    Q_INVOKABLE void setStudioId(int id) { m_studioId = id; }
    Q_INVOKABLE int  studioId() const { return m_studioId; }

    // Event raw path — set before uploading session files so pending files land in event folder
    Q_INVOKABLE void setCurrentEventRawPath(const QString &rawPath) { m_currentEventRawPath = rawPath; }
    Q_INVOKABLE QString getCurrentEventRawPath() const { return m_currentEventRawPath; }
    Q_INVOKABLE void setUserInfo(const QString &phone, const QString &name);
    Q_INVOKABLE void clearUserInfo();
    Q_INVOKABLE QString buildRootPrefix(const QString &hwid) const;
    Q_INVOKABLE QString buildSessionUrl(const QString &hwid, int eventId, const QString &sessionId) const;
    Q_INVOKABLE QString buildEventUrl(const QString &hwid, int eventId) const;

    // Pending upload stats
    Q_INVOKABLE int pendingCount() const;
    Q_INVOKABLE int pendingCountForEvent(const QString &hwid, int eventId) const;
    Q_INVOKABLE bool isOnline() const { return m_isOnline; }
    // Đẩy lại mọi file đang chờ (gọi sau khi studio đăng nhập thành công).
    Q_INVOKABLE void retryPendingUploads() { retryQueuedAssets(); retryPendingSessions(); }

    // Debug: giả lập mất mạng mà không cần tắt mạng máy tính
    Q_INVOKABLE void setSimulateOffline(bool offline);
    Q_INVOKABLE bool isSimulatingOffline() const { return m_simulateOffline; }

signals:
    void uploadStarted();
    void uploadProgress(qint64 bytesSent, qint64 bytesTotal);
    void uploadFinished(const QString &url);
    void uploadError(const QString &message);
    void pendingCountChanged(int count);
    void networkOnline();
    void networkOffline();
    void galleryLinkReady(const QString &sessionId, const QString &url);
    void galleryLinkFailed(const QString &sessionId, const QString &message);

    // Internal cross-thread dispatch
    void _enqueue(const QString &filePath, const QString &s3Key,
                  const QString &bucket, const QString &region,
                  const QString &publicBaseUrl,
                  const QString &apiBaseUrl, const QString &apiToken);
    void _enqueueAsset(const QVariantMap &asset,
                       const QString &apiBaseUrl, const QString &apiToken);

private:
    struct CloudApiCredentials {
        QString baseUrl;
        QString token;
        bool isValid() const { return !baseUrl.isEmpty() && !token.isEmpty(); }
    };

    CloudApiCredentials loadCredentials();
    // assetIdOverride: id cố định thay cho id tính từ đường dẫn (bản xem "thumb-<id ảnh>").
    void dispatchAsset(const QString &filePath, const QString &hwid, int eventId,
                       const QString &sessionId, const QString &kind,
                       int photoIndex, const QString &objectKeyHint = QString(),
                       const QString &assetIdOverride = QString());
    void retryQueuedAssets();

    // Tạo bản xem (thumbnail 720px cạnh ngắn, preview 2048px cạnh dài) của một ảnh gốc
    // trên luồng nền rồi xếp upload — ảnh gốc chỉ được đọc, không đổi.
    void scheduleDisplayCopies(const QString &photoAssetId, const QString &photoPath,
                               const QString &hwid, int eventId,
                               const QString &sessionId, int photoIndex);
    void sendFinalize(const QString &sessionId);

    // Dispatch: if online → send to worker; if offline → stage to pending folder
    // rawPath: event raw folder (e.g. D:/Events/MyEvent/Originals) — pending saved inside it
    void dispatch(const QString &filePath, const QString &s3Key,
                  const QString &hwid = QString(),
                  int eventId = -1, const QString &sessionId = QString(),
                  const QString &rawPath = QString());

    // Pending folder helpers
    // Primary:  {rawPath}/pending/{sessionId}/          (inside event folder)
    // Fallback: {appDir}/pending_uploads/{hwid}/{eventId}/{sessionId}/
    QString pendingRootDir() const;
    QString pendingSessionDir(const QString &hwid, int eventId,
                              const QString &sessionId,
                              const QString &rawPath = QString()) const;
    void stageFileToPending(const QString &filePath, const QString &s3Key,
                            const QString &hwid, int eventId,
                            const QString &sessionId,
                            const QString &rawPath = QString());
    void retryPendingSessions();
    int  countPendingFiles() const;

    // Đẩy 1 file sang worker thread để upload, có KHỬ TRÙNG LẶP:
    // nếu s3Key đang in-flight thì bỏ qua (tránh retry storm enqueue lại
    // file đang upload nhiều lần từ timer 60s / sự kiện online / startup).
    void enqueueToWorker(const QString &filePath, const QString &s3Key,
                         const QString &apiBaseUrl, const QString &apiToken);

    // Build URL public của object trên Worker media/CDN.
    QString publicUrlFor(const QString &s3Key) const;

    // Quét đĩa đếm file pending CHẠY TRÊN WORKER THREAD (không block UI),
    // cập nhật cache + emit pendingCountChanged khi xong.
    void requestPendingRecount();

    QThread              *m_workerThread;
    S3UploadWorker       *m_worker;
    DatabaseManager      *m_dbManager = nullptr;
    QString               m_bucket;
    QString               m_region;
    QString               m_publicBaseUrl;   // Worker media URL hoặc CDN/custom domain
    QString               m_currentHWID;
    int                   m_studioId = 0;    // tiền tố URL gallery; 0 = chưa biết
    QString               m_galleryBaseUrl = QStringLiteral("https://lamoment.vercel.app/gallery");
    QString               m_userPhone;
    QString               m_userName;
    bool                  m_isOnline = true;
    bool                  m_simulateOffline = false;
    QString               m_currentEventRawPath;
    QTimer               *m_retryTimer   = nullptr;
    // Map s3Key → rawPath để staging đúng folder khi upload thất bại trên worker thread
    QHash<QString, QString> m_rawPathByKey;
    QHash<QString, int>     m_eventIdByKey;   // eventId theo key (chọn thư mục pending local)

    // Các s3Key đang upload — dùng để khử trùng lặp khi retry.
    // Chỉ truy cập trên main thread (dispatch/retry + slot kết quả của worker).
    QSet<QString> m_inFlightKeys;

    // sessionId -> link album đã nhận từ server; sessionId đang chờ phản hồi.
    QHash<QString, QString> m_galleryLinks;
    QSet<QString>           m_galleryLinkPending;

    // Bản xem: 1 luồng nền (không tranh CPU với lật ảnh / live view); ảnh đã xếp tạo.
    QThreadPool   m_displayPool;
    QSet<QString> m_displayRequested;
    // /finalize: phiên đã báo (báo lại khi có ảnh mới); phiên chờ gửi → mốc sớm nhất được
    // gửi (ms, gom các lần gọi liền nhau); phiên đang gửi.
    QSet<QString>          m_finalizedSessions;
    QHash<QString, qint64> m_finalizePending;
    QSet<QString>          m_finalizeInFlight;

    // Số file pending đã cache (ghi bởi worker thread, đọc bởi main/QML).
    std::atomic<int> m_cachedPendingCount{0};
};

#endif // S3UPLOADER_H
