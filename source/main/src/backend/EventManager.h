#ifndef EVENTMANAGER_H
#define EVENTMANAGER_H

#include "DatabaseManager.h"
#include "EventModel.h"
#include "LayoutAnalyzer.h"
#include "PrinterConfig.h"
#include <QObject>
#include <QHash>
#include <QSet>
#include <QString>
#include <QTimer>
#include <QVariantMap>

class SessionManager;
class MachineAuthenticator;
class S3Uploader;
class VideoCreator;
class CameraController;
class PrinterManager;

class EventManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(EventModel *eventModel READ eventModel CONSTANT)
  // Phiên đăng nhập nhân viên / admin
  Q_PROPERTY(int currentEmployeeId READ currentEmployeeId NOTIFY currentEmployeeChanged)
  Q_PROPERTY(QString currentEmployeeName READ currentEmployeeName NOTIFY currentEmployeeChanged)
  Q_PROPERTY(bool isAdmin READ isAdmin NOTIFY currentEmployeeChanged)
  Q_PROPERTY(bool isLoggedIn READ isLoggedIn NOTIFY currentEmployeeChanged)

public:
  explicit EventManager(DatabaseManager* dbManager, QObject *parent = nullptr);
  ~EventManager();

  EventModel *eventModel() const { return m_eventModel; }

  // Setters for integrated managers
  void setSessionManager(SessionManager *sessionManager);
  // Đồng bộ phiên/doanh thu lên API selfboothvn qua outbox (CloudSyncManager).
  void setCloudSync(class CloudSyncManager *cloudSync) { m_cloudSync = cloudSync; }
  // Gắn lượt dùng mã gói (use_id từ server/cache) vào phiên để đồng bộ capture_sessions.
  Q_INVOKABLE void setSessionCodeUse(const QString &sessionId, const QString &useId);
  void setMachineAuthenticator(MachineAuthenticator *machineAuth) { m_machineAuth = machineAuth; }
  void setS3Uploader(S3Uploader *s3Uploader) { m_s3Uploader = s3Uploader; }
  void setVideoCreator(VideoCreator *videoCreator) { m_videoCreator = videoCreator; }
  void setCameraController(CameraController *ctrl);
  // Màn chụp bắt đầu (accepting=true) / thôi nhận ảnh của phiên (false, lúc chụp xong).
  // Thôi nhận → trong 60 s, ảnh máy ảnh còn trả về (bấm sát giờ, truyền chậm) vẫn được
  // ghi vào phiên và đưa lên gallery web dù màn hình đã sang bước khác.
  Q_INVOKABLE void setCaptureAccepting(const QString &sessionId, int eventId, bool accepting,
                                       int photoCount = 0);
  // Ảnh JPG mang mã phiên trong thư mục ảnh (thư mục chung của sự kiện), ghi từ mốc
  // modifiedSinceMs (ms epoch, 0 = mọi lúc), sắp theo tên.
  Q_INVOKABLE QStringList listSessionPhotoFiles(const QString &dir, const QString &sessionId,
                                                double modifiedSinceMs = 0) const;
  void setPrinterManager(PrinterManager *printerMgr) { m_printerManager = printerMgr; }
  void setPrinterConfig(PrinterConfig *config) {
    m_printerConfig = config;
    connect(config, &PrinterConfig::resolutionChanged, this, [this]() {
      // When DPI changes, normalise layouts for every event asynchronously
      int count = m_eventModel->rowCount();
      for (int i = 0; i < count; ++i)
          reprocessLayoutForEvent(m_eventModel->getEventId(i));
    });
    connect(config, &PrinterConfig::selectedPrinterChanged, this, [this]() {
      // When printer changes, normalise layouts for every event asynchronously
      int count = m_eventModel->rowCount();
      for (int i = 0; i < count; ++i)
          reprocessLayoutForEvent(m_eventModel->getEventId(i));
    });
  }

  Q_INVOKABLE bool createEvent(const QString &name, const QString &location,
                               const QString &eventDate);
  Q_INVOKABLE int getOrCreatePaperEvent();
  Q_INVOKABLE int getOrCreateBoothosEvent();
  // nameOverride: tên sự kiện studio cần dùng/tạo (vd "studio2" cho chế độ 2,
  // "studio3" cho chế độ 3). Để trống → dùng "studio" như mặc định.
  Q_INVOKABLE int getOrCreateStudioEvent(const QString &nameOverride = QString());

  Q_INVOKABLE bool updateEventName(int eventId, const QString &newName);
  Q_INVOKABLE bool deleteEvent(int eventId);
  Q_INVOKABLE bool duplicateEvent(int eventId);

  Q_INVOKABLE bool updateCaptureMode(int eventId, const QString &mode);
  Q_INVOKABLE bool updateEffect(int eventId, const QString &effectName,
                                bool enabled);
  Q_INVOKABLE bool updateEventPath(int eventId, const QString &pathType,
                                   const QString &newPath);
  Q_INVOKABLE bool updateEventBool(int eventId, const QString &key, bool value);
  Q_INVOKABLE bool updateCaptureTimings(int eventId, int firstShotCountdown, int nextShotCountdown, int shotInterval);
  Q_INVOKABLE bool updateMirrorMode(int eventId, bool enabled);
  Q_INVOKABLE bool updateLiveViewOverlay(int eventId, bool enabled);
  Q_INVOKABLE bool updateShootingMode(int eventId, int shootingMode, int manualPhotoCount);

  Q_INVOKABLE QVariantMap getEventDetails(int eventId);
  Q_INVOKABLE QVariantList getEventPhotos(int eventId);
  Q_INVOKABLE bool updateEventLayout(int eventId, const QString &layoutPath);
  Q_INVOKABLE bool saveSessionPhotos(int eventId, const QStringList &filePaths, const QString &sessionId = "");
  // Async: flip ảnh + ghi DB + queue S3 chạy trên background thread, không block UI
  Q_INVOKABLE void saveSessionPhotosAsync(int eventId, const QStringList &filePaths, const QString &sessionId = "");
  Q_INVOKABLE bool enqueueCaptureAsset(int eventId, const QString &filePath,
                                       const QString &sessionId, int photoIndex);
  Q_INVOKABLE QString processCollage(int eventId, const QStringList &photoPaths,
                                     const QString &sessionId = QString());
  // Overload nhận transform data (scale, tx, ty) để áp dụng pan/zoom khi ghép ảnh
  Q_INVOKABLE QString processCollageWithTransforms(int eventId,
                                                   const QStringList &photoPaths,
                                                   const QVariantList &transforms,
                                                   const QString &sessionId = QString());
  // Async version: chạy trên background thread, phát signal collageReady khi xong.
  // saveToDb=false để pre-render ngầm không ghi DB; ghi DB khi user xác nhận (saveToDb=true).
  Q_INVOKABLE void processCollageWithTransformsAsync(int eventId,
                                                     const QStringList &photoPaths,
                                                     const QVariantList &transforms,
                                                     const QString &sessionId = QString(),
                                                     bool saveToDb = true);
  // Selfbooth variant: compose against an explicit frame without changing the
  // event's selected layout or applying printer cut-mode rules.
  Q_INVOKABLE void processCollageForLayoutAsync(int eventId,
                                                const QString &layoutPath,
                                                const QStringList &photoPaths,
                                                const QVariantList &transforms,
                                                const QString &sessionId = QString(),
                                                bool saveToDb = true);
  // Ghi một collage path đã có trên disk vào DB (dùng sau khi dùng cache từ pre-render với saveToDb=false)
  Q_INVOKABLE void recordCollage(int eventId, const QString &filePath, const QString &sessionId = QString());
  // Preview strip (no cut duplication) – dùng cho FilterScreen
  Q_INVOKABLE QString processCollageNoCut(int eventId,
                                          const QStringList &photoPaths,
                                          const QVariantList &transforms,
                                          const QString &sessionId = QString());
  // Async version: kết quả phát qua signal previewReady(path)
  Q_INVOKABLE void processCollageNoCutAsync(int eventId,
                                            const QStringList &photoPaths,
                                            const QVariantList &transforms,
                                            const QString &sessionId = QString());
  // Nhân đôi strip đã filter thành 4x6 canvas
  Q_INVOKABLE QString composeCutFromStrip(const QString &stripPath, int eventId);
  // Dán nhiều sticker (PNG) lên strip đơn TRƯỚC khi nhân đôi.
  // stickers: [{path, xNorm, yNorm, wNorm, rotDeg}] — toạ độ tâm + bề rộng chuẩn hoá theo strip.
  // Trả "file:///..." của strip mới (đã dán), hoặc trả lại stripPath nếu lỗi/không có sticker.
  Q_INVOKABLE QString applyStickersToStrip(const QString &stripPath, const QVariantList &stickers);
  // slotCaptureIndices[i] = chỉ số chụp (thứ tự slot_<k>) của ảnh khách xếp vào ô i.
  // Rỗng → ghép theo index chụp mặc định (tương thích caller cũ).
  Q_INVOKABLE void createVideoFromSession(int eventId, const QString &sessionId, const QStringList &photoPaths, int maxLongEdge = 1920,
                                          const QVariantList &slotCaptureIndices = QVariantList());
  Q_INVOKABLE void createVideoFromSessionQml(int eventId, const QString &sessionId, const QVariantList &photoPaths, int maxLongEdge = 1920,
                                             const QVariantList &slotCaptureIndices = QVariantList());
  Q_INVOKABLE void printQrCode(const QString &qrUrl, const QString &eventName);
  // Tải mã QR từ qrUrl và lưu xuống thư mục Pictures của máy.
  // Kết quả phát qua signal qrCodeSaved(success, path).
  Q_INVOKABLE void saveQrCode(const QString &qrUrl, const QString &eventName);
  // Upload stats cho tab Chia Sẻ: {totalPhotos, pendingFiles, isOnline}
  Q_INVOKABLE QVariantMap getEventUploadStats(int eventId) const;
  Q_INVOKABLE QString applyQrOverlay(const QString &imagePath, const QString &qrUrl, double xNorm, double yNorm, double sizeNorm);
  Q_INVOKABLE QString applyQrOverlayRect(const QString &imagePath, const QString &qrUrl,
                                         double xNorm, double yNorm,
                                         double wNorm, double hNorm);
  Q_INVOKABLE QString applyQrOverlayForCut(const QString &imagePath, const QString &qrUrl,
                                           double x1Norm, double y1Norm, double size1Norm,
                                           double x2Norm, double y2Norm, double size2Norm);
  // Multi-strip QR overlay: replicate QR into N equal vertical strips at same relative position
  // xNorm/yNorm/sizeNorm are normalized relative to ONE strip width (not full canvas)
  Q_INVOKABLE QString applyQrOverlayFor2(const QString &imagePath, const QString &qrUrl,
                                         double xNorm, double yNorm, double sizeNorm);
  // 2 strips xếp DỌC (trên/dưới) — layout 15×5 RX1/620S cut ngang, canvas 15×10
  Q_INVOKABLE QString applyQrOverlayFor2Vertical(const QString &imagePath, const QString &qrUrl,
                                                  double xNorm, double yNorm, double sizeNorm);
  Q_INVOKABLE QString applyQrOverlayFor3(const QString &imagePath, const QString &qrUrl,
                                         double xNorm, double yNorm, double sizeNorm);
  // Async QR overlay — runs download + paint + save on a background thread so
  // the UI never freezes on the network call. Result delivered via qrOverlayReady.
  //   mode "single"   → applyQrOverlay
  //   mode "2h"       → applyQrOverlayFor2          (strips side by side)
  //   mode "2v"       → applyQrOverlayFor2Vertical  (strips stacked)
  //   mode "qw410cut" → applyQrOverlay + composeCutCanvas (ghép 15×10 trên worker)
  // eventId chỉ cần cho mode "qw410cut" (đọc layout/finalPath + ghi Photo).
  Q_INVOKABLE void applyQrOverlayAsync(const QString &imagePath, const QString &qrUrl,
                                       const QString &mode,
                                       double xNorm, double yNorm, double sizeNorm,
                                       int eventId = -1);
  // Rect variant: burn QR into the exact normalized rectangle. In cut modes,
  // imagePath is the single strip and the cut canvas is composed after QR burn.
  Q_INVOKABLE void applyQrOverlayRectAsync(const QString &imagePath, const QString &qrUrl,
                                           const QString &mode,
                                           double xNorm, double yNorm,
                                           double wNorm, double hNorm,
                                           int eventId = -1);
  // Returns width/height aspect of a layout image (1.0 if not found)
  Q_INVOKABLE double getLayoutAspect(const QString &layoutPath);


  // Layouts Management
  Q_INVOKABLE bool uploadLayout(int eventId, const QString &filePath);
  Q_INVOKABLE bool uploadLayoutToCategory(int eventId, const QString &filePath, const QString &category);
  bool ensureFrameCategory(int eventId, const QString &category);
  QString findFrameLayoutPath(int eventId, const QString &category, const QString &fileName) const;
  bool importCategoryDisplayImage(int eventId, const QString &category, const QString &filePath);
  Q_INVOKABLE bool deleteLayout(int eventId, const QString &layoutPath);
  Q_INVOKABLE bool renameLayout(int eventId, const QString &oldPath, const QString &newName);

  // ── Thao tác khung theo LÔ ────────────────────────────────────────────────
  // Bản đơn ở trên phát layoutUploaded sau MỖI file; gọi chúng trong vòng lặp
  // khiến QML nạp lại toàn bộ danh sách N+1 lần (mỗi lần quét lại thư mục và
  // dựng lại GridView) — đó là nguồn gốc hiện tượng "load lại + lag".
  // Ba hàm dưới xử lý cả lô trong MỘT thread nền, phát tiến trình từng file và
  // chỉ phát layoutUploaded ĐÚNG MỘT LẦN khi xong.
  //   category rỗng  → chép đè như uploadLayout
  //   category có giá trị → đặt tiền tố "Category__" như uploadLayoutToCategory
  Q_INVOKABLE void uploadLayoutsBatch(int eventId, const QStringList &filePaths,
                                      const QString &category = QString());
  Q_INVOKABLE void deleteLayoutsBatch(int eventId, const QStringList &layoutPaths);
  // pairs: [{ "from": <đường dẫn hiện tại>, "to": <tên mới, không cần .png> }, …]
  Q_INVOKABLE void renameLayoutsBatch(int eventId, const QVariantList &pairs);
  Q_INVOKABLE bool uploadPaperLayout(const QString &filePath);
  Q_INVOKABLE bool deletePaperLayout(const QString &layoutPath);
  Q_INVOKABLE QVariantList getPaperLayouts();
  Q_INVOKABLE bool uploadSelfBoothLayout(const QString &filePath);
  Q_INVOKABLE bool deleteSelfBoothLayout(const QString &layoutPath);
  Q_INVOKABLE QVariantList getSelfBoothLayouts();
  Q_INVOKABLE void reprocessAllLayouts();
  Q_INVOKABLE QVariantList getLayouts(int eventId);
  Q_INVOKABLE void requestLayouts(int eventId);
  Q_INVOKABLE int getLayoutSlotCount(const QString &layoutPath);
  Q_INVOKABLE int getLayoutWidth(const QString &layoutPath);
  Q_INVOKABLE int getLayoutHeight(const QString &layoutPath);
  Q_INVOKABLE bool getLayoutIsLandscape(const QString &layoutPath);
  Q_INVOKABLE QString getPaperSizeFromLayout(const QString &layoutPath);
  Q_INVOKABLE bool ensureLayoutMetadata(const QString &layoutPath);
  // Vá dữ liệu cũ: phân tích lại các khung PNG bị thiếu file .json cùng tên (di chứng
  // của bug ghi JSON theo baseName()). Chạy nền, xong thì emit layoutUploaded(eventId).
  Q_INVOKABLE void repairMissingLayoutMetadata(int eventId);

  // Background Management
  Q_INVOKABLE bool uploadLandingBackground(int eventId, const QString &filePath);
  Q_INVOKABLE bool uploadModeSelectionBackground(int eventId, const QString &filePath);
  Q_INVOKABLE QString getLandingBackground(int eventId);
  Q_INVOKABLE QString getModeSelectionBackground(int eventId);

  // App Settings. These route to per-event overrides when an event is active
  // (see setActiveEventId) and the key is not in kMachineGlobalKeys; otherwise
  // they read/write the shared global app_settings table. Unset per-event keys
  // fall back live to the global value.
  Q_INVOKABLE bool setAppSetting(const QString &key, const QString &value);
  Q_INVOKABLE bool setAppSettingForEvent(int eventId, const QString &key, const QString &value);
  Q_INVOKABLE QString getAppSetting(const QString &key, const QString &defaultValue = "");

  // ── Chế độ bleed của tấm in cắt ("fill" | "safe") ─────────────────────────
  // "fill" = FillToEdge: thiết kế phủ kín vùng in, phần nhô ra rơi ngoài giấy
  //          → borderless thật, không lộ sọc nền, mất ~1.7mm rìa thiết kế.
  // "safe" = SafeMargin: thiết kế co vừa vùng giấy thật, bleed để màu nền
  //          → giữ trọn thiết kế, nhưng giấy lệch cơ khí có thể lộ sọc nền.
  // Cả hai cho đường cắt chính giữa như nhau. Xem docs/DNP_RX1_CUT_PRINT_SPEC.md.
  Q_INVOKABLE QString cutBleedMode();
  Q_INVOKABLE bool    setCutBleedMode(const QString &mode);
  // Nạp giá trị đã lưu vào ImageCompositor (gọi một lần lúc khởi động)
  void applyCutBleedModeFromSettings();
  // Phương thức bảo mật dùng chung cho mọi cửa xác thực (mở app, vào Cài đặt,
  // thoát session về trang quản lý sự kiện): "pin" | "qr" | "both".
  // securityMethod() tự suy ra từ qr_login_enabled/qr_security_enabled khi máy
  // chưa từng đặt security_method (giữ nguyên hành vi sau khi cập nhật app).
  Q_INVOKABLE QString securityMethod();
  Q_INVOKABLE bool setSecurityMethod(const QString &method);
  // PIN bảo mật chung cho mở app / vào Cài đặt. PIN cũ trong app_setting
  // "admin_pin" được migrate tự động sang hash khi xác thực hoặc đổi PIN.
  Q_INVOKABLE bool verifySecurityPin(const QString &pin);
  Q_INVOKABLE QString setSecurityPin(const QString &currentPin, const QString &newPin);
  Q_INVOKABLE bool enterAdminWithoutPassword();
  // Ghi các giá trị bật/tắt mặc định khi mở app (chỉ khi key CHƯA từng được đặt),
  // để cấu hình mới ra khỏi hộp đúng như mong muốn mà không đè lựa chọn đã lưu.
  void seedDefaultAppSettings();
  // Địa chỉ IPv4 LAN của máy này (để hiển thị URL quầy thu ngân). Rỗng nếu không có.
  Q_INVOKABLE QString getLocalIpAddress() const;

  // The event whose settings getAppSetting/setAppSetting operate on. Set before
  // opening SettingsPage for an event or launching a BoothSession; reset to -1
  // on the dashboard so global settings resolve normally.
  Q_INVOKABLE void setActiveEventId(int eventId);
  Q_INVOKABLE int activeEventId() const { return m_activeEventId; }
  Q_INVOKABLE bool setGlobalLandingBackground(const QString &filePath);
  Q_INVOKABLE QString getGlobalLandingBackground();
  Q_INVOKABLE QString getSelfBoothBaseDir() const;
  Q_INVOKABLE void restartApp();

  // File utilities
  Q_INVOKABLE bool writeTextFile(const QString &filePath, const QString &content);
  // Tạo thư mục (đệ quy) nếu chưa có — dùng cho ảnh mockup ở chế độ chụp test.
  Q_INVOKABLE bool ensureDir(const QString &dirPath);

  // ── Employee session / accounts ─────────────────────────────────────────
  int     currentEmployeeId()   const { return m_currentEmployeeId; }
  QString currentEmployeeName() const { return m_currentEmployeeName; }
  bool    isAdmin()             const { return m_currentEmployeeId == -1; }
  bool    isLoggedIn()          const { return m_currentEmployeeId != 0; }

  // Id dành riêng cho nhân viên cloud đăng nhập qua QR (không có trong bảng employees).
  // 0 = chưa đăng nhập, -1 = admin, -2 = nhân viên QR, > 0 = nhân viên local.
  static constexpr int kCloudStaffEmployeeId = -2;

  // name == "root" → admin (so với PIN bảo mật chung, mặc định legacy "0000").
  // Trả "" nếu thành công, ngược lại trả message lỗi tiếng Việt.
  Q_INVOKABLE QString employeeLogin(const QString &name, const QString &password);
  // Đăng nhập qua mã QR đã được portal xác nhận (role: "owner" → Admin, khác → staff -2).
  Q_INVOKABLE QString qrLogin(const QString &email, const QString &name, const QString &role);
  // Chỉ ghi lại lượt quét QR (vd mở khóa Cài đặt) — không đổi trạng thái đăng nhập.
  Q_INVOKABLE void recordQrScan(const QString &email, const QString &name, const QString &role);
  Q_INVOKABLE void    employeeLogout();
  Q_INVOKABLE bool    restoreEmployeeSession();

  Q_INVOKABLE QVariantList getEmployees();
  Q_INVOKABLE int syncCloudStaffAccounts(const QVariantList &staffList);
  Q_INVOKABLE QVariantList employeePermissionCatalog();
  // Trả "" nếu thành công, ngược lại message lỗi.
  Q_INVOKABLE QString createEmployee(const QString &fullName, const QString &password);
  Q_INVOKABLE bool    setEmployeePassword(int id, const QString &newPassword);
  Q_INVOKABLE bool    setEmployeePermissions(int id, const QVariantList &permissions);
  Q_INVOKABLE bool    renameEmployee(int id, const QString &fullName);
  Q_INVOKABLE bool    deleteEmployee(int id);

  // Voucher operations
  // requiredAmount >= 0: kiểm tra khớp đúng tuyệt đối cho voucher loại "cash".
  // requiredAmount < 0: bỏ qua kiểm tra số tiền (luồng cũ discount/print).
  Q_INVOKABLE QVariantMap validateVoucher(const QString &code, int requiredAmount = -1);
  Q_INVOKABLE bool redeemVoucher(const QString &code, const QString &sessionId, int paidAmount = 0);
  // Voucher nhân viên: loại "cash", khớp đúng số tiền, gắn nhân viên đang đăng nhập.
  Q_INVOKABLE QStringList generateVouchers(int value, int count,
                                           const QString &validFrom = "",
                                           const QString &validUntil = "",
                                           const QString &shift = "",
                                           const QString &note = "");
  Q_INVOKABLE QVariantList getVoucherList(const QString &filter);
  // Kéo danh sách voucher toàn studio từ cloud (async) → signal cloudVouchersReady.
  Q_INVOKABLE void refreshCloudVouchers(const QString &filter);
  // Preset {notes, prices, durations} đọc từ cloud (đồng nhất với web tạo voucher).
  Q_INVOKABLE QVariantMap getVoucherPresets();
  Q_INVOKABLE bool deleteVoucher(const QString &code);
  Q_INVOKABLE void deleteVoucherBatch(const QString &kind, const QVariantList &items);
  Q_INVOKABLE int getVoucherCount(const QString &filter);
  Q_INVOKABLE QVariantMap validateCashPaymentCode(const QString &code, int requiredAmount);
  Q_INVOKABLE bool redeemCashPaymentCode(const QString &code, const QString &sessionId, int paidAmount = 0);
  Q_INVOKABLE QVariantMap createPayosPayment(int amount, const QString &description,
                                             const QString &returnUrl,
                                             const QString &cancelUrl);
  Q_INVOKABLE QVariantMap getPayosPaymentStatus(const QString &id);
  // Mã gói chụp trả trước (type='package_code'). Cloud là nguồn chân lý; validate trả
  // {valid, code, type, value, package_minutes, package_prints, package_name}.
  Q_INVOKABLE QVariantMap validatePackageCode(const QString &code);
  Q_INVOKABLE QVariantMap validateLocalPackageCode(const QString &code);
  Q_INVOKABLE QVariantMap redeemLocalPackageCode(const QString &code, const QString &sessionId, int paidAmount = 0);
  Q_INVOKABLE bool redeemPackageCode(const QString &code, const QString &sessionId, int paidAmount = 0);
  Q_INVOKABLE QStringList generatePackageCodes(const QString &packageName,
                                               int value,
                                               int minutes,
                                               int prints,
                                               int usageLimit,
                                               int count,
                                               const QString &validFrom = "",
                                               const QString &validUntil = "",
                                               const QString &note = "");
  Q_INVOKABLE QVariantList getPackageCodeList(const QString &filter);
  Q_INVOKABLE int getPackageCodeCount(const QString &filter);
  Q_INVOKABLE QStringList generateCashPaymentCodes(int value, int count,
                                                   const QString &validFrom = "",
                                                   const QString &validUntil = "",
                                                   const QString &shift = "",
                                                   const QString &note = "");
  Q_INVOKABLE QVariantList getCashPaymentCodeList(const QString &filter);
  Q_INVOKABLE int getCashPaymentCodeCount(const QString &filter);

  // Printing from Gallery
  Q_INVOKABLE void printPhotoFromGallery(int eventId, const QString &photoPath);
  // Overload: user can override copies and cut mode from the Gallery UI
  Q_INVOKABLE void printPhotoFromGalleryWithOptions(int eventId, const QString &photoPath,
                                                    int copies, bool cutMode);

  // Print tracking
  Q_INVOKABLE void incrementPrintCount(int eventId, int photoCount, bool cutMode);
  Q_INVOKABLE int getEventPrintCount(int eventId) const;
  Q_INVOKABLE int getEventCutPrintCount(int eventId) const;
  Q_INVOKABLE int getEventNoCutPrintCount(int eventId) const;
  Q_INVOKABLE int getLastGalleryPrintPhotoCount() const;
  Q_INVOKABLE bool getLastGalleryPrintCutMode() const;
  
  // Revenue tracking
  // shift: để trống → tự suy theo giờ giao dịch + danh sách ca (voucher_shifts).
  // source: "session" (phiên mới) | "reprint" (in lại từ Gallery).
  Q_INVOKABLE bool logRevenue(int eventId, const QString &eventName, const QString &sessionId,
                              int printCount, int amountRequired,
                              int cashReceived, int transferAmount, int changeAmount,
                              const QString &paymentMethod,
                              const QString &shift = "", const QString &source = "session",
                              const QString &note = "", int voucherAmount = 0);
  // Suy ra tên ca làm việc cho một mốc thời gian ISO (đối chiếu voucher_shifts).
  Q_INVOKABLE QString resolveShift(const QString &isoTime);
  // getRevenueRecords/getRevenueSummary tự lọc theo nhân viên đang đăng nhập
  // (admin root thấy tất cả). employeeFilter: -2 = theo quyền đăng nhập (mặc định);
  // admin có thể truyền id cụ thể (>0) để xem 1 nhân viên, hoặc -1 = tất cả.
  Q_INVOKABLE QVariantList getRevenueRecords(const QString &sortBy = "time", int employeeFilter = -2);
  Q_INVOKABLE bool clearRevenueRecords();
  Q_INVOKABLE bool exportRevenueToCSV(const QString &filePath);
  Q_INVOKABLE QVariantMap getRevenueSummary();
  Q_INVOKABLE QVariantList getCaptureAttempts(int employeeFilter = -2);
  Q_INVOKABLE bool resolveCaptureAttempt(const QString &sessionId,
                                         const QString &resolutionType,
                                         int refundAmount, const QString &note);
  Q_INVOKABLE bool exportCaptureAttemptsToCSV(const QString &filePath,
                                              int employeeFilter = -2);

  // Sync to DynamoDB
  Q_INVOKABLE void syncEventToDynamoDB(int eventId);

  // Load Layout Metadata JSON (for QML to avoid XMLHttpRequest issues)
  Q_INVOKABLE QVariantMap loadLayoutMetadata(const QString &layoutPath);

  // Thư mục tạm ghi frame live-view cho process video của 1 session (tạo nếu chưa
  // có). CaptureScreen lấy đường dẫn này rồi truyền vào startSlotRecording().
  Q_INVOKABLE QString getSessionRecordingDir(const QString &sessionId);

  // Đường dẫn file video process của 1 session dưới dạng file:/// URL — rỗng nếu
  // video chưa được encode xong. WaitingResults dùng để phát lại video lượt chụp.
  Q_INVOKABLE QString getSessionVideoPath(int eventId, const QString &sessionId);

signals:
  void eventCreated(int eventId);
  void eventUpdated(int eventId);
  void eventDeleted(int eventId);
  void error(const QString &message);
  void layoutUploaded(int eventId); // UI update trigger
  // Khung tải lên nhưng phân tích thất bại — để UI báo cho người dùng thay vì im lặng.
  void layoutFailed(int eventId, const QString &fileName, const QString &reason);
  void layoutReady(int eventId, QVariantMap layout);
  void layoutsReady(int eventId, QVariantList layouts);
  void backgroundUploaded(int eventId, const QString &backgroundType);
  void layoutReprocessStarted(int totalLayouts);
  void layoutReprocessProgress(int current, int total, QString fileName);
  void layoutReprocessFinished(int layoutsProcessed);
  // ── Tiến trình thao tác khung theo lô (upload/delete/rename) ──────────────
  // op: "upload" | "delete" | "rename". Dùng chung một dialog tiến trình ở QML.
  void frameTaskStarted(const QString &op, int total);
  void frameTaskProgress(int current, int total, const QString &fileName);
  void frameTaskFinished(const QString &op, int ok, int failed, const QStringList &errors);
  // Phát sau mỗi file xử lý xong để QML dọn/di chuyển app-setting "frame_image_*"
  // (khóa do QML sinh nên C++ không tự suy ra được). layoutPath là đúng chuỗi
  // QML đã truyền vào, để hàm chuẩn hóa bên QML khớp khóa cũ.
  void frameDeleted(const QString &layoutPath);
  void frameRenamed(const QString &oldPath, const QString &newPath);
  void printCountChanged(int eventId);
  void layoutScaledForQW410(const QString &originalPath, const QString &scaledPath);
  // Phát ra khi processCollageWithTransformsAsync hoàn thành
  void collageReady(const QString &collagePath);
  // Phát ra khi saveSessionPhotosAsync hoàn thành (tất cả ảnh đã flip + ghi DB)
  void sessionPhotosSaved();
  // Phát ra khi video process của 1 session đã encode xong — videoUrl là file:/// URL.
  void processVideoReady(const QString &sessionId, const QString &videoUrl);
  // Phát ra khi processCollageNoCutAsync hoàn thành
  void previewReady(const QString &previewPath);
  // Phát ra khi applyQrOverlayAsync hoàn thành — resultPath luôn dùng được
  // (bằng ảnh gốc nếu tải QR lỗi/timeout).
  void qrOverlayReady(const QString &resultPath);
  void eventLayoutNormalised(int eventId, int layoutsProcessed);
  // Phát ra khi saveQrCode hoàn thành — success=false nếu tải/ghi lỗi.
  void qrCodeSaved(bool success, const QString &path);
  void appSettingChanged(const QString &key, const QString &value);
  void currentEmployeeChanged();
  void captureAttemptsChanged();
  // Danh sách voucher cloud đã về (poll realtime). ok=false → QML fallback local.
  void cloudVouchersReady(const QVariantList &data, bool ok);
  void voucherBatchDeleteProgress(const QString &kind, int done, int total);
  void voucherBatchDeleteFinished(const QString &kind, int requested, int deleted,
                                  int skippedUsed, int failed, const QString &message);

private:
  // Validate/redeem voucher trên LOCAL DB (fallback khi mất mạng; cloud là nguồn chân lý).
  QVariantMap validateVoucherLocal(const QString &code, int requiredAmount);
  QVariantMap validateCashPaymentCodeLocal(const QString &code, int requiredAmount);
  QVariantMap validatePackageCodeLocal(const QString &code);
  // HWID hiện tại của máy (ưu tiên MachineAuthenticator, fallback DB).
  QString currentHwid() const;
  // Đẩy các mã local chưa đồng bộ (synced=0) lên kho cloud của studio; chỉ đánh dấu
  // synced=1 khi cloud xác nhận (mất mạng thì giữ lại để lần sau retry).
  // KHÔNG hoạt động khi bật chế độ "mã tại máy" (xem kCodesLocalFirst).
  void syncPendingVouchers();
  // Sinh mã dùng chung cho voucher ("cash") và mã tiền mặt ("cash_code").
  // Chế độ "mã tại máy": sinh thẳng ở DB máy, không hỏi cloud, không đẩy lên cloud.
  QStringList generateCodesInternal(const QString &type, int value, int count,
                                    const QString &validFrom, const QString &validUntil,
                                    const QString &shift, const QString &note = "");
  // Mã CHỈ nằm ở máy này (có bản ghi local + synced=0) → mọi thao tác kiểm tra/
  // sử dụng/xóa đều làm tại máy, không phụ thuộc cloud.
  bool isLocalOnlyCode(const QString &code) const;
  // Trộn mã tại máy vào danh sách kéo từ cloud (mã tại máy được ưu tiên khi trùng
  // và luôn hiển thị dù cloud không có).
  QVariantList mergeLocalCodesIntoCloudList(const QVariantList &cloudList) const;

  // Cache preset voucher lần cuối tải được (fallback khi mất mạng).
  struct VoucherDeleteBatchState {
    QString kind;
    int requested = 0;
    int deleted = 0;
    int skippedUsed = 0;
    int failed = 0;
    int completed = 0;
    int totalCloud = 0;
  };
  QString finishVoucherDeleteBatch(const QString &batchId);
  QVariantMap m_voucherPresetsCache;
  QHash<QString, VoucherDeleteBatchState> m_voucherDeleteBatches;

  DatabaseManager *m_dbManager;
  EventModel *m_eventModel;
  LayoutAnalyzer *m_layoutAnalyzer;
  SessionManager *m_sessionManager;
  MachineAuthenticator *m_machineAuth;
  class DynamoDBClient *m_dynamoClient;
  class CloudSyncManager *m_cloudSync = nullptr;
  QHash<QString, QString> m_sessionCodeUse;   // session_id -> package code use_id
  S3Uploader *m_s3Uploader;
  VideoCreator *m_videoCreator;
  PrinterConfig *m_printerConfig = nullptr;
  CameraController *m_cameraController = nullptr;
  PrinterManager *m_printerManager = nullptr;

  // Nhận ảnh về trễ sau khi màn chụp kết thúc (xem setCaptureAccepting).
  void onCameraImageCaptured(const QString &path);
  QString m_lateSessionId;          // rỗng = không trong khung nhận ảnh trễ
  int m_lateEventId = -1;
  int m_lateNextIndex = 1;          // số thứ tự ảnh kế tiếp của phiên
  QTimer *m_lateWindowTimer = nullptr;

  // Track pending gallery print for photo count increment
  int m_pendingGalleryPrintEventId = -1;
  int m_pendingGalleryPhotoCount = 0;
  bool m_pendingGalleryCutMode = false;

  // Cache cho App Settings — getAppSetting() được gọi rất nhiều từ QML binding;
  // mỗi lần là 1 SQL query trên main thread. Cache lại để chỉ đọc DB 1 lần/key.
  // setAppSetting() cập nhật cache đồng thời nên không bao giờ stale.
  QHash<QString, QString> m_settingsCache;

  // Sự kiện đang được chỉnh/đang chạy. >0 thì getAppSetting/setAppSetting định
  // tuyến sang event_settings (trừ kMachineGlobalKeys). -1 = phạm vi global.
  int m_activeEventId = -1;
  // Các key giữ phạm vi global (bảo mật, phần cứng, định danh máy/merchant).
  static const QSet<QString> kMachineGlobalKeys;

  // ── Phiên đăng nhập ──────────────────────────────────────────────────────
  // 0 = chưa đăng nhập; -1 = admin root; >0 = id nhân viên trong bảng employees.
  int     m_currentEmployeeId = 0;
  QString m_currentEmployeeName;
  // SHA-256 hash, dùng chung kiểu UserAuthManager để băm mật khẩu nhân viên.
  static QString hashPassword(const QString &password);

  int getAutoCutThreshold() const;
  void updateAutoCutForAllEvents();

  // Normalise all layouts for a single event (async, non-blocking)
  void reprocessLayoutForEvent(int eventId);

  // ── Lõi thao tác file khung, KHÔNG phát tín hiệu ──────────────────────────
  // Dùng chung cho bản đơn (phát tín hiệu ngay sau khi gọi) và bản lô (gom tín
  // hiệu về cuối). Gọi được từ thread nền vì chỉ đụng filesystem.
  static bool doDeleteLayout(const QString &layoutPath, QString *err = nullptr);
  static bool doRenameLayout(const QString &oldPath, const QString &newName,
                             QString *outNewPath = nullptr, QString *err = nullptr);

  // Scale layout for QW410 printer (600x1200 @300dpi for 5x10")
  // Runs asynchronously to avoid blocking UI
  void scaleLayoutForQW410IfNeeded(const QString &layoutPath);
  void syncSessionToCloud(const QString &sessionId);

};

#endif // EVENTMANAGER_H
