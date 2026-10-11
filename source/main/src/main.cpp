#include "backend/CameraController.h"
#include "backend/CameraBackend.h"
#include "backend/EventManager.h"
#include "backend/LiveViewImageProvider.h"
#include "backend/QrImageProvider.h"
#include "backend/PrinterManager.h"
#include "backend/PrinterConfig.h"
#include "backend/DatabaseManager.h"
#include "backend/S3Uploader.h"
#include "backend/VideoCreator.h"
#include "backend/ConfigManager.h"
#include "backend/MachineAuthenticator.h"
#include "backend/LicenseManager.h"
#include "backend/ActivationClient.h"
#include "backend/LicenseStore.h"
#include "backend/QrLoginManager.h"
#include "backend/StudioAccount.h"
#include "backend/CloudSyncManager.h"
#include "backend/SessionManager.h"
#include "backend/UserAuthManager.h"
#include "backend/AppPaths.h"
#include "backend/Logger.h"
#include "backend/HttpBridge.h"
#include "backend/FilterManager.h"
#include "backend/StickerManager.h"
#include "backend/BillAcceptor.h"
#include "backend/RelayController.h"
#include "backend/DisplayManager.h"
#include "backend/FrameSyncManager.h"
#include "backend/FilterSyncManager.h"
#include "backend/BackgroundSyncManager.h"
#include "backend/PaymentSyncManager.h"
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QDebug>
#include <QTimer>
#include <QCoreApplication>
#include <QEventLoop>
#include <QMetaObject>
#include <QtGlobal>
#include <QStandardPaths>
#include <QThread>
#include <QThreadPool>
#include <QSysInfo>
#include <QImageReader>
#include <QLibrary>
#include <QProcess>
#ifdef Q_OS_WIN
#  include <windows.h>
#endif

#ifndef APP_FIXED_OPERATION_MODE
#define APP_FIXED_OPERATION_MODE ""
#endif

// Tắt "USB selective suspend" của Windows trên power-plan đang dùng. Đây là
// nguyên nhân phổ biến khiến máy ảnh USB rớt kết nối sau một thời gian idle
// (OS cắt nguồn cổng USB). Chạy idempotent mỗi lần khởi động, không block —
// powercfg trả về ngay. GUID: SUB_USB / "USB selective suspend setting"; 0 = Disabled.
static void disableUsbSelectiveSuspend() {
#ifdef Q_OS_WIN
    const QString sub  = "2a737441-1930-4402-8d77-b2bebba308a3"; // SUB_USB
    const QString item = "48e6b7a6-50f5-4782-a5d4-53bb8f07e226"; // USB selective suspend
    QProcess::startDetached("powercfg",
        { "/SETACVALUEINDEX", "SCHEME_CURRENT", sub, item, "0" });
    QProcess::startDetached("powercfg",
        { "/SETDCVALUEINDEX", "SCHEME_CURRENT", sub, item, "0" });
    QProcess::startDetached("powercfg", { "/SETACTIVE", "SCHEME_CURRENT" });
    qDebug() << "[SYS] Requested disable of USB selective suspend (powercfg)";
#endif
}

// Thử tạo D3D11 device để kiểm tra GPU có dùng được không.
// Gọi trực tiếp d3d11.dll qua LoadLibrary — không link tĩnh để tránh crash
// trên máy không có d3d11.dll (rất hiếm nhưng có thể xảy ra trên VM cũ).
// Trả về true nếu D3D11 feature level >= 11.0, false nếu không dùng được.
static bool probeD3D11() {
    QLibrary d3d("d3d11");
    if (!d3d.load()) return false;

    typedef HRESULT(__stdcall *PFN_D3D11_CREATE)(
        void*, int, void*, UINT, void*, UINT, UINT, void**, int*, void**);
    auto fn = (PFN_D3D11_CREATE)d3d.resolve("D3D11CreateDevice");
    if (!fn) return false;

    // D3D_DRIVER_TYPE_HARDWARE = 1, SDK_VERSION = 7
    void* dev = nullptr, *ctx = nullptr;
    int featureLevel = 0;
    HRESULT hr = fn(nullptr, 1, nullptr, 0, nullptr, 0, 7, &dev, &featureLevel, &ctx);

    // Giải phóng COM objects nếu tạo được
    if (dev) { auto** p = (void**)dev; ((HRESULT(__stdcall**)(void*))(*p))[2](dev); }
    if (ctx) { auto** p = (void**)ctx; ((HRESULT(__stdcall**)(void*))(*p))[2](ctx); }

    // D3D_FEATURE_LEVEL_11_0 = 0xb000
    return SUCCEEDED(hr) && featureLevel >= 0xb000;
}

int main(int argc, char *argv[]) {
  // Bật Qt Virtual Keyboard — phải set trước khi tạo QGuiApplication
  qputenv("QT_IM_MODULE", "qtvirtualkeyboard");
  qputenv("QT_VIRTUALKEYBOARD_STYLE", "studio");

  // Chọn renderer tự động: ưu tiên D3D11 (GPU), fallback sang software.
  // Nếu user đã set QSG_RHI_BACKEND trong environment thì tôn trọng lựa chọn đó.
  if (qgetenv("QSG_RHI_BACKEND").isEmpty()) {
      if (probeD3D11()) {
          qputenv("QSG_RHI_BACKEND", "d3d11");
      } else {
          qputenv("QSG_RHI_BACKEND", "software");
      }
  }
  qputenv("QSG_INFO", "1");

  QGuiApplication app(argc, argv);

  // Initialize logging system (do this FIRST before any qDebug/qWarning calls)
  Logger::instance().initialize();
  qInstallMessageHandler(Logger::messageHandler);

  qDebug() << "========================================";
  qDebug() << "Photobooth Dashboard Starting...";
  qDebug() << "========================================";

  // Chống rớt kết nối máy ảnh USB: tắt USB selective suspend của Windows ngay
  // khi khởi động (kết hợp keep-alive chủ động trong CameraController).
  disableUsbSelectiveSuspend();

  // Camera/ffmpeg/in đã có pool RIÊNG (xem CameraController/VideoCreator/
  // PrinterManager). Global pool giờ chỉ còn các tác vụ ngắn (ghép ảnh,
  // QR, misc) — nới trần để chúng không tự xếp hàng lẫn nhau khi 24/7.
  {
      int ideal = QThread::idealThreadCount();
      QThreadPool::globalInstance()->setMaxThreadCount(qMax(8, ideal * 2));
      qDebug() << "[SYS] Global QThreadPool max threads:"
               << QThreadPool::globalInstance()->maxThreadCount();
  }

  // Khung ảnh do người dùng thiết kế có thể rất lớn (600 dpi khổ 12×18" ≈ 78 Mpx).
  // Mặc định Qt 6 chỉ cho phép 256 MB (~64 Mpx) và trả về QImage rỗng KHÔNG báo lỗi,
  // khiến khung tải lên xong không hiện. Nới lên 1 GB (~256 Mpx) cho cả LayoutAnalyzer
  // lẫn mọi Image trong QML.
  QImageReader::setAllocationLimit(1024);
  qDebug() << "[SYS] QImageReader allocation limit (MB):" << QImageReader::allocationLimit();

  // ── System & GPU diagnostic info ────────────────────────────────────────────
  qDebug() << "[SYS] OS:"          << QSysInfo::prettyProductName();
  qDebug() << "[SYS] Kernel:"      << QSysInfo::kernelVersion();
  qDebug() << "[SYS] CPU arch:"    << QSysInfo::currentCpuArchitecture();
  qDebug() << "[SYS] Qt version:"  << qVersion();
  qDebug() << "[SYS] RHI backend env:" << qgetenv("QSG_RHI_BACKEND");

  // ────────────────────────────────────────────────────────────────────────────

  // Set Qt Quick Controls style to Basic
  QQuickStyle::setStyle("Basic");

  QQmlApplicationEngine splashEngine;
  QObject* startupSplash = nullptr;
  auto updateStartupSplash = [&startupSplash](qreal progress, const QString& status) {
      if (!startupSplash)
          return;
      startupSplash->setProperty("progress", qBound<qreal>(0.0, progress, 1.0));
      startupSplash->setProperty("statusText", status);
      QCoreApplication::processEvents(QEventLoop::AllEvents, 20);
  };

  splashEngine.load(QUrl(QStringLiteral("qrc:/components/StartupSplash.qml")));
  if (!splashEngine.rootObjects().isEmpty()) {
      startupSplash = splashEngine.rootObjects().first();
      updateStartupSplash(0.06, QStringLiteral("Đang mở ứng dụng…"));
  } else {
      qWarning() << "StartupSplash: failed to create splash window";
  }

  // Create backend
  qDebug() << "Startup: Creating Managers...";
  updateStartupSplash(0.12, QStringLiteral("Đang khởi tạo hệ thống…"));

  // 1. Initialize Database (using AppPaths for portable deployment)
  DatabaseManager databaseManager;
  QString dbPath = AppPaths::instance().getDatabasePath();
  if (!databaseManager.initialize(dbPath)) {
    qCritical() << "Failed to initialize database at:" << dbPath;
    return -1;  // Exit if database initialization fails
  }
  qDebug() << "Database initialized successfully at:" << dbPath;
  updateStartupSplash(0.22, QStringLiteral("Đang tải dữ liệu…"));

  // 2. Load public configuration (object storage and Cloud API endpoints)
  ConfigManager* configManager = ConfigManager::instance();
  configManager->loadConfig(AppPaths::instance().getConfigPath());

  // 3. Create Authentication Manager (HWID generation and validation)
  MachineAuthenticator* machineAuth = new MachineAuthenticator(&databaseManager);

  // 3a1b. Giấy phép ký số — nguồn quyền KHÔNG phụ thuộc máy chủ.
  //   Máy xác minh chữ ký Ed25519 của admin bằng khoá công khai biên dịch cứng,
  //   thay vì tin cột `activate` trong D1. Nhờ vậy lộ cơ sở dữ liệu (hoặc lộ
  //   bearer token) không bật/tắt được máy ngoài hiện trường.
  //   Bản PTB cưỡng chế (không có chữ ký → màn nhập OTP); bản khác chỉ đối chiếu —
  //   xem kEnforceLicense ở MachineAuthenticator.cpp.
  LicenseManager* licenseManager = new LicenseManager(&databaseManager, &app);
  licenseManager->setHwid(machineAuth->hwid());
  licenseManager->load();
  machineAuth->setLicenseManager(licenseManager);
  QObject::connect(licenseManager, &LicenseManager::tamperDetected,
                   &app, [](const QString &reason) {
    qCritical() << "[License] PHÁT HIỆN CAN THIỆP tệp giấy phép:" << reason;
  });

  // Luồng kích hoạt (OTP 4 số do admin cấp) + tự nhận gia hạn / phiếu thu hồi khi
  // có mạng. Đồng bộ chạy nền sau khi đã nạp phiên studio (cần token máy) — xem
  // mục 3c; im lặng khi không có gì mới hoặc khi mất mạng.
  ActivationClient* activation = new ActivationClient(configManager, licenseManager, &app);

  updateStartupSplash(0.34, QStringLiteral("Đang khởi tạo đăng nhập…"));

  // 3a2. License store (gói + thanh toán SePay) — dùng chung config với DynamoDBClient.
  LicenseStore* licenseStore = new LicenseStore(configManager, &app);

  // 3a3. Đăng nhập/mở khóa bằng mã QR (quét từ portal) — cùng config/token.
  QrLoginManager* qrLoginManager = new QrLoginManager(configManager, &app);

  // 3b. Create User Auth Manager (register / login / logout)
  UserAuthManager* userAuth = new UserAuthManager(&databaseManager);

  // 3c. Tài khoản studio (API selfboothvn /v1): nạp phiên đã lưu + báo danh máy.
  StudioAccount* studioAccount = new StudioAccount(configManager, machineAuth->hwid(), &app);
  studioAccount->restore();
  // Giấy phép: đồng bộ (thu hồi / gia hạn) khi khởi động và ngay sau khi đăng nhập.
  QTimer::singleShot(5000, activation, [activation]() { activation->syncStatus(); });
  QObject::connect(studioAccount, &StudioAccount::signedIn, activation, &ActivationClient::syncStatus);

  // 3d. Đồng bộ phiên / doanh thu / lượt dùng mã qua outbox bền.
  CloudSyncManager* cloudSync = new CloudSyncManager(configManager, &databaseManager, studioAccount, &app);

  // 4. Create Session Manager
  SessionManager* sessionManager = new SessionManager(&databaseManager);

  EventManager eventManager(&databaseManager);  // Pass DatabaseManager pointer
  const QString fixedOperationMode = QStringLiteral(APP_FIXED_OPERATION_MODE);
  if (fixedOperationMode == QStringLiteral("mode2") || fixedOperationMode == QStringLiteral("mode3")) {
      eventManager.setAppSetting(QStringLiteral("app_operation_mode"), fixedOperationMode);
      eventManager.setAppSetting(QStringLiteral("payment_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("multi_event_enabled"), QStringLiteral("false"));
      eventManager.setAppSetting(QStringLiteral("qr_code_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("bank_transfer_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("cash_payment_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("cash_payment_code_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("voucher_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("filter_enabled"), QStringLiteral("true"));
      eventManager.setAppSetting(QStringLiteral("sticker_enabled"), QStringLiteral("true"));
      qDebug() << "Startup: Fixed operation mode build:" << fixedOperationMode;
  }
  CameraController cameraController;
  cameraController.setEventManager(&eventManager);
  cameraController.setMockCaptureEnabled(
      QCoreApplication::arguments().contains(QStringLiteral("--mock-camera")));
  S3Uploader s3Uploader;
  s3Uploader.setDatabaseManager(&databaseManager);
  s3Uploader.setDatabaseManager(&databaseManager);
  VideoCreator videoCreator;
  PrinterManager printerManager;
  PrinterConfig printerConfig;
  FilterManager filterManager;
  StickerManager stickerManager;
  BillAcceptor  billAcceptor;
  printerConfig.setDatabaseManager(&databaseManager);
  FrameSyncManager frameSyncManager(configManager);
  FilterSyncManager filterSyncManager(configManager);
  BackgroundSyncManager backgroundSyncManager(configManager);
  PaymentSyncManager paymentSyncManager(configManager);

  // Auto-connect bill acceptor if COM port was previously saved
  {
      QString savedPort = databaseManager.getSetting("bill_acceptor_port", "");
      if (!savedPort.isEmpty()) {
          if (billAcceptor.openPort(savedPort))
              qDebug() << "BillAcceptor: auto-connected on" << savedPort;
          else
              qWarning() << "BillAcceptor: failed to auto-connect on" << savedPort;
      }
  }

  // 5a. Apply object storage config (bucket + public media domain)
  if (configManager->isValid()) {
    s3Uploader.setConfig(configManager->s3BucketName(), configManager->s3Region(),
                         configManager->s3PublicBaseUrl());
    qDebug() << "Object storage configured: bucket=" << configManager->s3BucketName()
             << "region/account=" << configManager->s3Region()
             << "publicUrl=" << configManager->s3PublicBaseUrl();
    // Gốc link gallery trong QR: public config "web.gallery_base_url" (tùy chọn).
    s3Uploader.setGalleryBaseUrl(configManager->webGalleryBaseUrl());
    qDebug() << "Gallery base URL:" << s3Uploader.galleryBaseUrl();
  }

  // 5a2. Studio id (tiền tố URL gallery) — đồng bộ từ MachineAuthenticator sang S3Uploader.
  //   Giá trị ban đầu lấy từ QSettings (lần chạy trước); cập nhật khi worker trả về.
  s3Uploader.setStudioId(machineAuth->studioId());
  QObject::connect(machineAuth, &MachineAuthenticator::studioIdChanged,
                   &s3Uploader, [machineAuth, &s3Uploader]() {
    s3Uploader.setStudioId(machineAuth->studioId());
    qDebug() << "Studio id updated for gallery URLs:" << machineAuth->studioId();
  });

  // 5. Connect EventManager with SessionManager, S3Uploader, VideoCreator, MachineAuthenticator, PrinterConfig, and PrinterManager
  eventManager.setSessionManager(sessionManager);
  eventManager.setCloudSync(cloudSync);
  eventManager.setS3Uploader(&s3Uploader);
  // Studio vừa đăng nhập: đẩy ảnh đang chờ (chụp khi chưa gắn studio / mất mạng).
  QObject::connect(studioAccount, &StudioAccount::signedIn, &s3Uploader,
                   [&s3Uploader]() { s3Uploader.retryPendingUploads(); });
  eventManager.setVideoCreator(&videoCreator);
  eventManager.setMachineAuthenticator(machineAuth);
  eventManager.setPrinterConfig(&printerConfig);
  eventManager.setCameraController(&cameraController);
  eventManager.setPrinterManager(&printerManager);
  frameSyncManager.setEventManager(&eventManager);
  frameSyncManager.setMachineAuthenticator(machineAuth);
  frameSyncManager.start(5000);
  filterSyncManager.setFilterManager(&filterManager);
  filterSyncManager.setMachineAuthenticator(machineAuth);
  filterSyncManager.start(5000);
  backgroundSyncManager.setEventManager(&eventManager);
  backgroundSyncManager.setMachineAuthenticator(machineAuth);
  backgroundSyncManager.start(5000);
  paymentSyncManager.setEventManager(&eventManager);
  paymentSyncManager.setMachineAuthenticator(machineAuth);
  paymentSyncManager.start(5000);
  printerManager.setPrinterConfig(&printerConfig);  // Cho phép PrinterManager đọc tên máy in đã chọn
  // Nạp chế độ bleed của tấm in cắt vào ImageCompositor (ImageCompositor toàn static,
  // không đọc DB được). Phải chạy TRƯỚC phiên chụp đầu tiên.
  eventManager.applyCutBleedModeFromSettings();
  qDebug() << "Startup: Connected EventManager with SessionManager, S3Uploader, VideoCreator, MachineAuthenticator, PrinterConfig, CameraController, and PrinterManager";
  updateStartupSplash(0.56, QStringLiteral("Đang kết nối dịch vụ…"));

  // 6. Start HTTP Bridge — LAN pickup is always available for the cashier device.
  //    Binding 0.0.0.0 keeps localhost SDK clients working and exposes the gallery
  //    to machines on the same LAN.
  const bool lanPickupEnabled = true;
  const QString lanPickupPin;
  HttpBridge httpBridge;
  httpBridge.setCameraController(&cameraController);
  httpBridge.setEventManager(&eventManager);
  httpBridge.setSessionManager(sessionManager);
  httpBridge.setPickupToken(lanPickupPin);
  if (httpBridge.start(5514, lanPickupEnabled)) {
      qDebug() << "HttpBridge: Python SDK available at http://localhost:5514";
      if (lanPickupEnabled)
          qDebug() << "HttpBridge: LAN pickup gallery available on this machine's IP at :5514";
      // Đẩy sự kiện camera tới Python qua SSE
      QObject::connect(&cameraController, &CameraController::imageCaptured,
                       &httpBridge, [&httpBridge](const QString &path){
          httpBridge.pushEvent("imageCaptured", QJsonObject{{"path", path}});
      });
      QObject::connect(&cameraController, &CameraController::error,
                       &httpBridge, [&httpBridge](const QString &msg){
          httpBridge.pushEvent("cameraError", QJsonObject{{"message", msg}});
      });
      QObject::connect(&cameraController, &CameraController::isLiveViewActiveChanged,
                       &httpBridge, [&httpBridge, &cameraController](){
          if (cameraController.isLiveViewActive())
              httpBridge.pushEvent("liveViewStarted");
          else
              httpBridge.pushEvent("liveViewStopped");
      });
  } else {
      qWarning() << "HttpBridge: không thể khởi động — Python SDK sẽ không hoạt động";
  }
  updateStartupSplash(0.70, QStringLiteral("Đang chuẩn bị giao diện…"));

  // Setup QML engine
  qDebug() << "Startup: Setting up QML Engine...";
  QQmlApplicationEngine engine;
  engine.addImportPath(QStringLiteral("qrc:/kbstyles"));

  // Setup Live View Provider
  LiveViewImageProvider *liveViewProvider = new LiveViewImageProvider();
  engine.addImageProvider("live", liveViewProvider);

  // Local QR code provider — image://qr/<percent-encoded-data>
  engine.addImageProvider("qr", new QrImageProvider());

  // Connect Camera Controller -> Live View Provider
  cameraController.setImageProvider(liveViewProvider);

  // Register PrinterConfig type for QML
  qmlRegisterType<PrinterConfig>("com.photobooth.printer", 1, 0, "PrinterConfig");

  // USB Relay controller (dieu khien den/thiet bi qua helper 32-bit RelayCli.exe).
  RelayController relayController(&eventManager);
  DisplayManager displayManager;

  // Expose Managers to QML
  engine.rootContext()->setContextProperty("eventManager", &eventManager);
  engine.rootContext()->setContextProperty("cameraController", &cameraController);
  engine.rootContext()->setContextProperty("relayController", &relayController);
  engine.rootContext()->setContextProperty("displayManager", &displayManager);
  engine.rootContext()->setContextProperty("s3Uploader", &s3Uploader);
  engine.rootContext()->setContextProperty("videoCreator", &videoCreator);
  engine.rootContext()->setContextProperty("printerManager", &printerManager);
  engine.rootContext()->setContextProperty("printerConfig", &printerConfig);
  engine.rootContext()->setContextProperty("machineAuth", machineAuth);
  engine.rootContext()->setContextProperty("licenseManager", licenseManager);
  engine.rootContext()->setContextProperty("activation", activation);
  engine.rootContext()->setContextProperty("licenseStore", licenseStore);
  engine.rootContext()->setContextProperty("qrLoginManager", qrLoginManager);
  engine.rootContext()->setContextProperty("studioAccount", studioAccount);
  engine.rootContext()->setContextProperty("cloudSync", cloudSync);
  engine.rootContext()->setContextProperty("sessionManager", sessionManager);
  engine.rootContext()->setContextProperty("userAuth", userAuth);
  engine.rootContext()->setContextProperty("filterManager", &filterManager);
  engine.rootContext()->setContextProperty("stickerManager", &stickerManager);
  engine.rootContext()->setContextProperty("billAcceptor", &billAcceptor);
  engine.rootContext()->setContextProperty("buildFixedOperationMode", fixedOperationMode);
  // Keep cameraManager property for backward compatibility if needed, or remove if QML updated
  // engine.rootContext()->setContextProperty("cameraManager", &cameraController); 
  updateStartupSplash(0.86, QStringLiteral("Đang nạp giao diện…"));

  // Load main QML file
#if defined(SELFBOOTH_ONLY)
  qDebug() << "Startup: Loading selfbooth_main.qml (SELFBOOTH_ONLY build)...";
  const QUrl url(QStringLiteral("qrc:/selfbooth_main.qml"));
#elif defined(PHOTOBOOTH_ONLY)
  qDebug() << "Startup: Loading ptb_main.qml (PHOTOBOOTH_ONLY build)...";
  const QUrl url(QStringLiteral("qrc:/ptb_main.qml"));
#else
  qDebug() << "Startup: Loading main.qml...";
  const QUrl url(QStringLiteral("qrc:/main.qml"));
#endif
  
  // Bắt lỗi QML load — ghi vào log trước khi exit
  QObject::connect(
      &engine, &QQmlApplicationEngine::warnings, &app,
      [](const QList<QQmlError>& warnings) {
          for (const auto& w : warnings)
              qCritical() << "QML Warning:" << w.toString();
      });

  QObject::connect(
      &engine, &QQmlApplicationEngine::objectCreated, &app,
      [url, &cameraController, machineAuth, &eventManager, startupSplash](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) {
           qCritical() << "Startup Error: Failed to create root object for" << url;
           QCoreApplication::exit(-1);
        } else {
           qDebug() << "Startup Success: Root object created. Initializing authentication...";
           if (startupSplash) {
               startupSplash->setProperty("progress", 1.0);
               startupSplash->setProperty("statusText", QStringLiteral("Sẵn sàng"));
               QTimer::singleShot(350, startupSplash, [startupSplash]() {
                   QMetaObject::invokeMethod(startupSplash, "finish", Qt::QueuedConnection);
               });
           }
           // Initialize authentication after a short delay to let UI show
           QTimer::singleShot(500, [machineAuth, &cameraController, &eventManager]() {
               qDebug() << "Starting machine authentication...";
               machineAuth->authenticate();

#if defined(USE_SONY_SDK)
               // Sony SDK only: no Canon main-thread requirement.
               // connectAsync() chạy initialize() + findCameras() + connectCamera()
               // trên pool nền nên KHÔNG block UI; bật watchdog để tự reconnect.
               qWarning() << "Sony SDK build: auto-connecting camera at startup...";
               cameraController.connectAsync();
               cameraController.setWatchdogEnabled(true);

#elif defined(USE_DUAL_SDK)
               // Dual-SDK (Canon + Sony):
               //   Phase 1 — initialize() MUST run on the main thread (Canon EDSDK
               //             requires the Windows message pump thread for COM).
               //   Phase 2 — findCameras() + connectCamera() run on a background thread.
               //             Sony EnumCameraObjects blocks for up to ~8 s; keeping it
               //             off the main thread prevents UI freeze.
               //
               // connectToServer() calls initialize() internally, but the guard
               // "if (m_sdkInit) return true" makes it a no-op on the background thread
               // since we already initialised here on the main thread.
               {
                   auto& sdkCamera = CameraBackend::camera();
                   if (!sdkCamera.initialize()) {
                       qCritical() << "Dual-SDK initialization failed on main thread";
                       return;
                   }
               }
               // initialize() đã chạy trên main thread (yêu cầu COM của Canon).
               // connectAsync() chỉ làm findCameras()/connectCamera() trên pool nền
               // (initialize() bên trong là no-op) → không block UI. Bật watchdog
               // để tự reconnect khi mất kết nối / live view treo.
               qWarning() << "Camera SDKs initialized. Auto-connecting camera at startup...";
               cameraController.connectAsync();
               cameraController.setWatchdogEnabled(true);

#else
               // Canon EDSDK only:
               //   Phase 1 — initialize() on the main thread (Windows COM requirement).
               //   Phase 2 — connectToServer() on a background thread.
               //             USB download / camera session can block for 5+ s.
               QTimer::singleShot(0, [&cameraController]() {
                   auto& sdkCamera = CameraBackend::camera();
                   if (!sdkCamera.initialize()) {
                       qWarning() << "Canon EDSDK initialization failed";
                       return;
                   }
                   // initialize() phải chạy trên main thread (COM). connectAsync()
                   // chỉ làm findCameras()/connectCamera() trên pool nền (initialize
                   // bên trong là no-op) → không block UI. Bật watchdog để tự reconnect.
                   qWarning() << "Canon SDK initialized. Auto-connecting camera at startup...";
                   cameraController.connectAsync();
                   cameraController.setWatchdogEnabled(true);
               });
#endif
           });
        }
      },
      Qt::QueuedConnection);

  updateStartupSplash(0.94, QStringLiteral("Đang mở màn hình chính…"));
  engine.load(url);
  qDebug() << "Startup: Entering app event loop...";
  return app.exec();
}
