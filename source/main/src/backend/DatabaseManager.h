#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

#include <QDateTime>
#include <QHash>
#include <QMutex>
#include <QObject>
#include <QSqlDatabase>
#include <QString>

struct Event {
  int id = 0;
  QString name;
  QString location;
  QDateTime eventDate;
  QDateTime createdAt;
  QDateTime updatedAt;
  QString captureMode; // "photo", "gif", "boomerang", "video"
  bool digitalProps = false;
  bool beautyFilter = false;
  bool watermark = false;
  bool postProcessing = false;
  QString thumbnailPath;
  QString rawPath;
  QString finalPath;
  QString deviceName;
  QString startScreenMessage;
  QString selectedLayout; // Path to the selected .json/.png layout
  bool autoCut = false;           // Auto-detected from layout width (< 800px = true)
  int countdownDuration = 3;  // DEPRECATED: Legacy countdown - use firstShotCountdown instead
  int firstShotCountdown = 3; // Countdown for first shot in seconds (default: 3)
  int nextShotCountdown = 3;  // Countdown for subsequent shots in seconds (default: 3)
  int shotInterval = 2000;       // Waiting time between photos in milliseconds (default: 2000)
  int shootingMode = 0;       // 0: Auto (default), 1: Manual
  int manualPhotoCount = 0;   // Number of photos to take in Manual mode (default: 0)
  bool mirrorMode = false;        // Flip image horizontally if true
  bool liveViewOverlay = false;   // Show layout overlay on live view (for 1-slot landscape layouts)
  QString landingBackground;         // Path to landing page background image
  QString modeSelectionBackground;   // Path to mode selection background image
  bool liveViewBackground = false;   // Use live view as background for mode selection
  bool poseGuide = false;             // Show pose guide overlay on live view during capture
};

struct RevenueRecord {
    int     id             = 0;
    int     eventId        = 0;
    QString eventName;
    QString sessionId;
    QString recordedAt;
    int     printCount     = 0;   // số ảnh in
    int     amountRequired = 0;   // số tiền cần thanh toán
    int     cashReceived   = 0;   // tiền mặt nạp vào (0 nếu chuyển khoản)
    int     transferAmount = 0;   // chuyển khoản (0 nếu tiền mặt)
    int     changeAmount   = 0;   // tiền thừa
    QString paymentMethod;        // "cash" | "transfer" | "free" | "voucher"
    int     employeeId     = 0;   // nhân viên ghi nhận (0 = admin/legacy)
    QString shift;                // tên ca làm việc (suy theo giờ giao dịch)
    QString source         = "session"; // "session" (phiên mới) | "reprint" (in lại từ Gallery)
    int     receivedAmount = 0;   // tổng tiền thực nhận (cash/transfer/mệnh giá voucher)
    int     voucherAmount  = 0;   // giá trị voucher đã áp dụng
    QString note;                 // ghi chú (vd mã voucher đã dùng)
};

struct Employee {
    int       id = 0;
    QString   fullName;
    QString   prefix;        // tiền tố mã voucher, vd "NV01"
    QString   passHash;      // SHA-256
    QDateTime createdAt;
    bool      active = true;
};

struct UserAccount {
    int id = 0;
    QString fullName;
    QString phone;
    QString passwordHash;
    QDateTime createdAt;
    QDateTime lastLogin;
};

struct Photo {
    int id          = 0;
    int eventId     = 0;
    QString filePath;
    QString sessionId;   // session that produced this photo (empty for legacy records)
    QString type;        // "original" | "collage"
    QDateTime createdAt;
};

struct UploadAsset {
    QString assetId;
    QString sessionId;
    QString kind;
    QString localPath;
    QString fileName;
    QString contentType;
    QString checksumSha256;
    QString objectKey;
    QString uploadUrl;
    QString expiresAt;
    QString status;
    QString lastError;
    qint64 sizeBytes = 0;
    int photoIndex = 0;
    int attempts = 0;
};

class DatabaseManager : public QObject {
  Q_OBJECT

public:
  explicit DatabaseManager(QObject *parent = nullptr);
  ~DatabaseManager();

  bool initialize(const QString &dbPath = "photobooth.db");
  bool createTables();

  // CRUD operations
  int createEvent(const Event &event);
  bool updateEvent(const Event &event);
  bool deleteEvent(int eventId);
  Event getEvent(int eventId);
  QList<Event> getAllEvents();
  QList<Event> searchEvents(const QString &query);

  // Photo operations
  bool addPhoto(const Photo &photo);
  QList<Photo> getPhotosForEvent(int eventId);

  // Machine operations
  bool addMachine(const QString &hwid, const QString &deviceName);
  bool updateMachineAuthStatus(const QString &hwid, const QString &status);
  QString getMachineHWID();
  QString getMachineAuthStatus(const QString &hwid);

  // Session operations
  bool createSession(const QString &sessionId, int eventId, const QString &hwid);
  bool endSession(const QString &sessionId);
  bool updateSessionState(const QString &sessionId, const QString &status,
                          int expectedPhotos = -1, int capturedPhotos = -1,
                          const QString &failureCode = QString(),
                          const QString &failureMessage = QString());
  bool markSessionPaid(const QString &sessionId);
  bool resolveCaptureAttempt(const QString &sessionId, const QString &resolutionType,
                             int refundAmount, const QString &note,
                             const QString &resolvedBy);
  int recoverInterruptedSessions();
  QVariantList getCaptureAttempts(int employeeId = -1);
  bool exportCaptureAttemptsToCSV(const QString &filePath, int employeeId = -1);
  bool addPhotoToSession(int photoId, const QString &sessionId);
  QVariantMap getSessionInfo(const QString &sessionId);
  // Đường dẫn tuyệt đối các ảnh GỐC ('original') của 1 session, cũ → mới.
  QStringList getSessionOriginalPhotos(const QString &sessionId);
  // Danh sách session GẦN NHẤT của 1 event (mới → cũ) cho quầy thu ngân lấy ảnh.
  // Mỗi phần tử: { sessionId, startedAt, photoCount, firstPhoto }.
  QVariantList getRecentSessions(int eventId, int limit = 50);

  // User account operations
  bool registerUser(const QString &fullName, const QString &phone, const QString &passwordHash);
  bool getUserByPhone(const QString &phone, UserAccount &user);
  bool getUserByName(const QString &fullName, UserAccount &user);
  bool updateLastLogin(const QString &phone);
  bool userPhoneExists(const QString &phone);

  // Upload queue operations
  bool addToUploadQueue(int photoId, const QString &sessionId,
                        const QString &s3Path, const QString &localPath);
  bool updateUploadStatus(int queueId, const QString &status);
  QList<QVariantMap> getPendingUploads();

  // Durable capture asset upload queue.
  bool upsertUploadAsset(const UploadAsset &asset);
  QString getUploadAssetStatus(const QString &assetId);
  QVariantList pendingUploadAssets(int limit);
  // asset_id của mọi ảnh loại `kind` đã đưa vào hàng đợi cho phiên (gửi /finalize).
  QStringList uploadAssetIdsForSession(const QString &sessionId, const QString &kind);
  bool updateUploadAssetPrepared(const QString &assetId, qint64 sizeBytes,
                                 const QString &checksumSha256,
                                 const QString &objectKey,
                                 const QString &uploadUrl,
                                 const QString &expiresAt);
  bool updateUploadAssetStatus(const QString &assetId, const QString &status,
                               const QString &error = QString());
  bool markUploadAssetRetry(const QString &assetId, const QString &error,
                            int delaySeconds);
  bool markUploadAssetConfirmed(const QString &assetId, qint64 sizeBytes,
                                const QString &objectKey);
  int uploadAssetPendingCount() const;

  // App settings operations
  bool setSetting(const QString &key, const QString &value);
  QString getSetting(const QString &key, const QString &defaultValue = "");

  // Per-event settings operations (event_settings table).
  // getEventSettingRaw() returns kEventSettingAbsent when the event has no
  // override for the key, so the caller can fall back to the global value.
  static const QString kEventSettingAbsent;
  bool setEventSetting(int eventId, const QString &key, const QString &value);
  QString getEventSettingRaw(int eventId, const QString &key);
  bool copyEventSettings(int sourceEventId, int targetEventId);
  bool copyPrinterSettings(int sourceEventId, int targetEventId);

  // Utility
  bool duplicateEvent(int eventId);

  // Print tracking operations
  bool incrementPrintCount(int eventId, int copies, bool cutMode);
  int getPrintCount(int eventId) const;
  int getCutPrintCount(int eventId) const;
  int getNoCutPrintCount(int eventId) const;
  int getOriginalPhotoCount(int eventId) const;  // only 'original' type, not collages
  int getSessionCount(int eventId) const;        // total sessions for an event
  int getTotalEventCount() const;                // total events in the DB

  // Employee account operations
  int          createEmployee(const QString &fullName, const QString &prefix, const QString &passHash);
  bool         updateEmployeePassword(int id, const QString &passHash);
  bool         updateEmployeeName(int id, const QString &fullName);
  bool         deleteEmployee(int id);
  QVariantList getEmployees();
  QVariantMap  getEmployee(int id);
  QVariantMap  getEmployeeByName(const QString &fullName);
  bool         employeePrefixExists(const QString &prefix);

  // Voucher CRUD
  bool insertVoucher(const QString &code, const QString &type, int value,
                     int employeeId = 0, const QString &validFrom = "",
                     const QString &validUntil = "", const QString &shift = "",
                     const QString &note = "", int packageMinutes = 0,
                     int packagePrints = 1, const QString &packageName = "",
                     int usageLimit = 1);
  bool markVoucherUsed(const QString &code, const QString &sessionId,
                       int usedByEmpId = 0, int paidAmount = 0);
  QVariantMap getVoucher(const QString &code);
  QVariantList getVouchers(const QString &filter = "all", int employeeId = -1,
                           const QString &codeKind = "voucher");
  bool deleteVoucher(const QString &code);
  int getVoucherCount(const QString &filter = "all", int employeeId = -1,
                      const QString &codeKind = "voucher");
  // Đồng bộ cloud: mã local chưa đẩy lên kho studio (synced=0).
  QVariantList getUnsyncedVouchers();
  bool markVouchersSynced(const QStringList &codes);

  // Revenue record operations
  bool logRevenueRecord(const RevenueRecord &rec);
  QVariantList getRevenueRecords(const QString &sortBy = "time", int employeeId = -1);
  bool clearRevenueRecords();
  bool exportRevenueToCSV(const QString &filePath);
  QVariantMap getRevenueSummary(int employeeId = -1);

  // Hàng đợi đồng bộ lên API (CloudSyncManager). dedupe_key trùng: replace=true thì
  // thay payload (phiên: giữ bản mới nhất), false thì bỏ qua (doanh thu, lượt dùng mã).
  bool outboxEnqueue(const QString &kind, const QString &dedupeKey, const QString &method,
                     const QString &path, const QByteArray &payload, bool replace);
  QVariantList outboxPending(int limit);   // [{id, kind, method, path, payload}]
  bool outboxRemove(qint64 id);
  bool outboxMarkFailed(qint64 id, const QString &error, bool permanent);

private:
  QSqlDatabase m_database;
  bool executeQuery(const QString &query);

  // In-memory cache for app_settings. getSetting() is called from QML property
  // bindings on the UI thread; issuing a SQLite query on every call caused
  // visible UI stalls. The whole (tiny) table is loaded once and kept in sync
  // write-through by setSetting().
  QHash<QString, QString> m_settingsCache;
  bool                    m_settingsCacheLoaded = false;
  QMutex                  m_settingsMutex;
  void loadSettingsCache();  // populate m_settingsCache from app_settings (caller holds m_settingsMutex)

  // Write-through cache for per-event overrides, keyed by "<eventId>\x1f<key>"
  // (composite QString avoids relying on qHash(QPair) across Qt versions).
  // Mirrors the app_settings cache strategy; protected by m_settingsMutex.
  QHash<QString, QString> m_eventSettingsCache;
  static QString eventSettingCacheKey(int eventId, const QString &key);

  // Migration system
  int getSchemaVersion();
  bool setSchemaVersion(int version);
  bool applyMigration_v1();  // Create machines, sessions tables
  bool applyMigration_v2();  // Create upload_queue table, add columns to photos
  bool applyMigration_v3();  // Add background columns
  bool applyMigration_v4();  // Create app_settings table
  bool applyMigration_v5();  // Add live_view_overlay column
  bool applyMigration_v6();  // Add first_shot_countdown and next_shot_countdown columns
  bool applyMigration_v7();  // Add shooting_mode and manual_photo_count columns
  bool applyMigration_v8();  // Add live_view_background column
  bool applyMigration_v9();   // Add session_id column to photos table
  bool applyMigration_v10();  // Add pose_guide column
  bool applyMigration_v11();  // Add print_count column
  bool applyMigration_v12();  // Add print_count_cut / print_count_nocut columns
  bool applyMigration_v13();  // Add users table
  bool applyMigration_v14();  // Add vouchers table
  bool applyMigration_v15();  // Add revenue_records table
  bool applyMigration_v16();  // Add employees table
  bool applyMigration_v17();  // Add employee/validity columns to vouchers + revenue_records
  bool applyMigration_v18();  // Add shift column to vouchers
  bool applyMigration_v19();  // Add shift/source/received_amount to revenue_records
  bool applyMigration_v20();  // Add note column to revenue_records
  bool applyMigration_v21();  // Add voucher_amount to revenue_records
  bool applyMigration_v22();  // Create event_settings table (per-event overrides)
  bool applyMigration_v23();  // Capture-attempt lifecycle/reporting fields
  bool applyMigration_v24();  // Voucher provenance (created_via) + cloud sync flag
  bool applyMigration_v25();  // Voucher note (ghi chú) column
  bool applyMigration_v26();  // Voucher package columns (mã gói chụp trả trước)
  bool applyMigration_v27();  // Voucher local package usage limit
  bool applyMigration_v28();  // Durable upload_assets queue
};

#endif // DATABASEMANAGER_H
