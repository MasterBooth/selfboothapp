#include "CameraController.h"
#include "CameraEventBridge.h"
#include "LiveViewImageProvider.h"
#include "WebcamLiveView.h"
#include "HotFolderWatcher.h"
#include "FujiHotFolderProcess.h"
#include "EventManager.h"
#include <QCoreApplication>
#include <QDebug>
#include <QTimer>
#include <QImage>
#include <QImageReader>
#include <QImageWriter>
#include <QBuffer>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QPainter>
#ifdef Q_OS_WIN
#include <windows.h>
#include <io.h>
#endif
#include <QDateTime>
#include <QColor>
#include <QFont>
#include <QRandomGenerator>
#include <QSettings>
#include <QThread>
#include <QtConcurrent/QtConcurrent>
#include <chrono>
#include <algorithm>

namespace {

static const QString kPersistedSettingAbsent =
    QStringLiteral("\x01__CAMERA_SETTING_ABSENT__\x01");

static inline int clampChannel(int value)
{
    return std::max(0, std::min(255, value));
}

static QString normalizeCameraType(const QString &type)
{
    const QString t = type.trimmed();
    if (t.compare("Sony", Qt::CaseInsensitive) == 0)
        return QStringLiteral("Sony");
    if (t.compare("Nikon", Qt::CaseInsensitive) == 0)
        return QStringLiteral("Nikon");
    if (t.compare("Fuji", Qt::CaseInsensitive) == 0
            || t.compare("Fujifilm", Qt::CaseInsensitive) == 0)
        return QStringLiteral("Fuji");
    return QStringLiteral("Canon");
}

static QString normalizeSdkType(const std::string &sdkType)
{
    return normalizeCameraType(QString::fromStdString(sdkType));
}

// Fuji X SDK live view can stay at ~1024px even when SIZE_L is requested.
// This mild 4-neighbour unsharp pass restores edge clarity after the booth UI
// scales that frame to a large preview, without touching still-photo output.
static void applyFujiLiveViewSharpen(QImage &img)
{
    if (img.width() < 4 || img.height() < 4)
        return;

    if (img.format() != QImage::Format_ARGB32 && img.format() != QImage::Format_RGB32)
        img = img.convertToFormat(QImage::Format_ARGB32);

    const QImage src = img.copy();
    constexpr int amountNum = 3;   // 0.375 strength
    constexpr int amountDen = 8;

    for (int y = 1; y < img.height() - 1; ++y) {
        const QRgb *prev = reinterpret_cast<const QRgb *>(src.constScanLine(y - 1));
        const QRgb *cur  = reinterpret_cast<const QRgb *>(src.constScanLine(y));
        const QRgb *next = reinterpret_cast<const QRgb *>(src.constScanLine(y + 1));
        QRgb *dst = reinterpret_cast<QRgb *>(img.scanLine(y));

        for (int x = 1; x < img.width() - 1; ++x) {
            const QRgb c = cur[x];
            const QRgb l = cur[x - 1];
            const QRgb r = cur[x + 1];
            const QRgb u = prev[x];
            const QRgb d = next[x];

            const int cr = qRed(c);
            const int cg = qGreen(c);
            const int cb = qBlue(c);

            const int er = 4 * cr - qRed(l)   - qRed(r)   - qRed(u)   - qRed(d);
            const int eg = 4 * cg - qGreen(l) - qGreen(r) - qGreen(u) - qGreen(d);
            const int eb = 4 * cb - qBlue(l)  - qBlue(r)  - qBlue(u)  - qBlue(d);

            dst[x] = qRgba(clampChannel(cr + er * amountNum / amountDen),
                           clampChannel(cg + eg * amountNum / amountDen),
                           clampChannel(cb + eb * amountNum / amountDen),
                           qAlpha(c));
        }
    }
}

} // namespace

CameraController::CameraController(QObject *parent)
    : QObject(parent)
    , m_imageProvider(nullptr)
    , m_isConnected(false)
    , m_isLiveViewActive(false)
{
    // Camera SDK calls are serialized here so brand switching, reconnect, and
    // capture cannot touch the native SDKs at the same time.
    m_camPool.setMaxThreadCount(1);

    // Initialize camera backend and create event bridge
    m_eventBridge = std::make_unique<CameraEventBridge>(this);
    auto& camera = CameraBackend::camera();
    camera.addEventListener(m_eventBridge.get());

    // Setup watchdog timer for monitoring connection
    m_watchdogTimer = new QTimer(this);
    m_watchdogTimer->setInterval(m_watchdogTimeout);
    m_watchdogTimer->setSingleShot(false);
    connect(m_watchdogTimer, &QTimer::timeout, this, &CameraController::onWatchdogTimeout);

    // Load live-view performance settings from QSettings (written by setMaxLiveViewWidth /
    // setTargetLiveViewFps, which are also called from main.qml on startup with DB values).
    // QSettings is read once here — the decode thread never touches QSettings again.
    {
        QSettings qs;
        m_maxLiveViewWidth.store(qs.value("live_view_max_width",  0).toInt());
        m_targetLiveViewFps.store(qs.value("live_view_target_fps", 30).toInt());
        m_fujiLiveViewSize = qs.value("fuji_live_view_size", "auto").toString();
        m_fujiLiveViewQuality = qs.value("fuji_live_view_quality", "fine").toString();
        // FPS ghi process-video — thấp hơn live view để giảm tải JPEG-encode + I/O
        // của writer khi đếm ngược. Clip slot không cần mượt bằng preview.
        int recordTargetFps = qs.value("record_target_fps", 15).toInt();
        if (recordTargetFps < 1) recordTargetFps = 15;
        m_recordTargetFps.store(recordTargetFps);
        m_recordMinFrameIntervalMs = 1000 / recordTargetFps;

        // Camera source/type chosen by the user in Settings (default: Canon).
        m_cameraType = normalizeCameraType(qs.value("camera_type", "Canon").toString());

        // Webcam live view setting
        m_useWebcamLiveView   = qs.value("liveview_source", "sdk").toString() == "webcam";
        m_selectedWebcamIndex = qs.value("liveview_webcam_index", -1).toInt();

        // Nguồn chụp Hot Folder — nhớ qua các lần mở app. connectAsync() lúc khởi
        // động (main.cpp) sẽ tự theo dõi lại thay vì kết nối SDK.
        m_captureSource   = qs.value("capture_source", "sdk").toString() == "hotfolder"
                            ? QStringLiteral("hotfolder") : QStringLiteral("sdk");
        m_hotFolderKind   = qs.value("hotfolder_kind", "folder").toString() == "fuji"
                            ? QStringLiteral("fuji") : QStringLiteral("folder");
        m_hotFolderFolder = qs.value("hotfolder_folder_path").toString();
        if (isHotFolderSource())
            m_useWebcamLiveView = true;   // Hot Folder không có live view SDK
    }

    m_hotFolderPool.setMaxThreadCount(1);
    m_hotFolderWatcher = new HotFolderWatcher(this);
    connect(m_hotFolderWatcher, &HotFolderWatcher::watchingChanged,
            this, [this]() { refreshHotFolderState(); });
    connect(m_hotFolderWatcher, &HotFolderWatcher::fileReady,
            this, &CameraController::onHotFolderFileReady);

    m_fujiHotFolder = new FujiHotFolderProcess(this);
    connect(m_fujiHotFolder, &FujiHotFolderProcess::runningChanged, this, [this](bool running) {
        if (running)
            m_fujiStarting = false;
        refreshHotFolderState();
    });
    connect(m_fujiHotFolder, &FujiHotFolderProcess::folderChanged, this, [this](const QString &folder) {
        if (isHotFolderSource() && m_hotFolderKind == QLatin1String("fuji"))
            setHotFolderPathInternal(folder);
    });
    // Thoát app → tắt HotFolder.exe để nhả máy ảnh (lần mở sau app tự mở lại).
    connect(qApp, &QCoreApplication::aboutToQuit, this, [this]() {
        if (isHotFolderSource() && m_hotFolderKind == QLatin1String("fuji"))
            FujiHotFolderProcess::shutdown();
    });

    camera.setPreferredBrand(m_cameraType.toStdString());
    qDebug() << "CameraController: preferred camera type =" << m_cameraType
             << "| webcam mode =" << m_useWebcamLiveView
             << "| capture source =" << m_captureSource << "/" << m_hotFolderKind;

    // SDK type reported after initialize() — logged in connectToServer()
}

void CameraController::setEventManager(EventManager *eventManager)
{
    m_eventManager = eventManager;
    loadPersistedCameraSettings();
}

QString CameraController::loadCameraSetting(QSettings &settings,
                                            const QString &key,
                                            const QString &legacyValue)
{
    QString value = legacyValue;
    if (m_eventManager) {
        const QString stored = m_eventManager->getAppSetting(key, kPersistedSettingAbsent);
        if (stored == kPersistedSettingAbsent)
            m_eventManager->setAppSetting(key, legacyValue);
        else
            value = stored;
    }
    settings.setValue(key, value);
    return value;
}

void CameraController::persistCameraSetting(const QString &key, const QString &value)
{
    QSettings qs;
    qs.setValue(key, value);
    if (m_eventManager)
        m_eventManager->setAppSetting(key, value);
}

void CameraController::loadPersistedCameraSettings()
{
    QSettings qs;

    m_maxLiveViewWidth.store(
        loadCameraSetting(qs, QStringLiteral("live_view_max_width"),
                          QString::number(m_maxLiveViewWidth.load())).toInt());
    m_targetLiveViewFps.store(
        loadCameraSetting(qs, QStringLiteral("live_view_target_fps"),
                          QString::number(m_targetLiveViewFps.load())).toInt());

    const QString fujiSize = loadCameraSetting(qs, QStringLiteral("fuji_live_view_size"),
                                               m_fujiLiveViewSize);
    m_fujiLiveViewSize = (fujiSize.compare(QStringLiteral("L"), Qt::CaseInsensitive) == 0)
                         ? QStringLiteral("L")
                         : (fujiSize.compare(QStringLiteral("M"), Qt::CaseInsensitive) == 0)
                           ? QStringLiteral("M")
                           : (fujiSize.compare(QStringLiteral("S"), Qt::CaseInsensitive) == 0)
                             ? QStringLiteral("S") : QStringLiteral("auto");

    const QString fujiQuality = loadCameraSetting(qs, QStringLiteral("fuji_live_view_quality"),
                                                  m_fujiLiveViewQuality).trimmed().toLower();
    m_fujiLiveViewQuality = (fujiQuality == QLatin1String("normal")
                             || fujiQuality == QLatin1String("basic"))
                            ? fujiQuality : QStringLiteral("fine");

    m_cameraType = normalizeCameraType(
        loadCameraSetting(qs, QStringLiteral("camera_type"), m_cameraType));
    CameraBackend::camera().setPreferredBrand(m_cameraType.toStdString());

    m_captureSource = loadCameraSetting(qs, QStringLiteral("capture_source"), m_captureSource)
                              .trimmed().compare(QStringLiteral("hotfolder"), Qt::CaseInsensitive) == 0
                      ? QStringLiteral("hotfolder") : QStringLiteral("sdk");
    m_hotFolderKind = loadCameraSetting(qs, QStringLiteral("hotfolder_kind"), m_hotFolderKind)
                              .trimmed().compare(QStringLiteral("fuji"), Qt::CaseInsensitive) == 0
                      ? QStringLiteral("fuji") : QStringLiteral("folder");

    QString hotFolderFolder = loadCameraSetting(qs, QStringLiteral("hotfolder_folder_path"),
                                                m_hotFolderFolder).trimmed();
    m_hotFolderFolder = hotFolderFolder.isEmpty()
                        ? QString()
                        : QDir::toNativeSeparators(QDir::cleanPath(hotFolderFolder));

    m_useWebcamLiveView =
        loadCameraSetting(qs, QStringLiteral("liveview_source"),
                          m_useWebcamLiveView ? QStringLiteral("webcam") : QStringLiteral("sdk"))
            == QLatin1String("webcam");
    m_selectedWebcamIndex =
        loadCameraSetting(qs, QStringLiteral("liveview_webcam_index"),
                          QString::number(m_selectedWebcamIndex)).toInt();

    if (isHotFolderSource())
        m_useWebcamLiveView = true;

    persistCameraSetting(QStringLiteral("camera_type"), m_cameraType);
    persistCameraSetting(QStringLiteral("capture_source"), m_captureSource);
    persistCameraSetting(QStringLiteral("hotfolder_kind"), m_hotFolderKind);
    persistCameraSetting(QStringLiteral("hotfolder_folder_path"), m_hotFolderFolder);
    persistCameraSetting(QStringLiteral("liveview_source"), m_useWebcamLiveView
                         ? QStringLiteral("webcam") : QStringLiteral("sdk"));
    persistCameraSetting(QStringLiteral("liveview_webcam_index"),
                         QString::number(m_selectedWebcamIndex));

    qDebug() << "CameraController: persisted settings loaded"
             << "| type =" << m_cameraType
             << "| capture =" << m_captureSource << "/" << m_hotFolderKind
             << "| hotFolder =" << m_hotFolderFolder
             << "| liveView =" << (m_useWebcamLiveView ? "webcam" : "sdk")
             << "| webcamIndex =" << m_selectedWebcamIndex;
}

void CameraController::setMaxLiveViewWidth(int width)
{
    m_maxLiveViewWidth.store(width);
    persistCameraSetting(QStringLiteral("live_view_max_width"), QString::number(width));
    if (m_webcamLiveView)
        m_webcamLiveView->setMaxWidth(width);
    qDebug() << "CameraController: maxLiveViewWidth =" << width;
}

void CameraController::setTargetLiveViewFps(int fps)
{
    m_targetLiveViewFps.store(fps);
    persistCameraSetting(QStringLiteral("live_view_target_fps"), QString::number(fps));
    if (m_webcamLiveView)
        m_webcamLiveView->setTargetFps(fps);
    qDebug() << "CameraController: targetLiveViewFps =" << fps;
}

void CameraController::setFujiLiveViewOptions(const QString &size, const QString &quality)
{
    QString normalizedSize = size.trimmed();
    if (normalizedSize.compare("L", Qt::CaseInsensitive) == 0)
        normalizedSize = "L";
    else if (normalizedSize.compare("M", Qt::CaseInsensitive) == 0)
        normalizedSize = "M";
    else if (normalizedSize.compare("S", Qt::CaseInsensitive) == 0)
        normalizedSize = "S";
    else
        normalizedSize = "auto";

    QString normalizedQuality = quality.trimmed().toLower();
    if (normalizedQuality != "normal" && normalizedQuality != "basic")
        normalizedQuality = "fine";

    m_fujiLiveViewSize = normalizedSize;
    m_fujiLiveViewQuality = normalizedQuality;

    persistCameraSetting(QStringLiteral("fuji_live_view_size"), m_fujiLiveViewSize);
    persistCameraSetting(QStringLiteral("fuji_live_view_quality"), m_fujiLiveViewQuality);

    auto& camera = CameraBackend::camera();
    camera.setFujiLiveViewOptions(m_fujiLiveViewSize.toStdString(),
                                  m_fujiLiveViewQuality.toStdString());

    qDebug() << "CameraController: Fuji live view options size =" << m_fujiLiveViewSize
             << "quality =" << m_fujiLiveViewQuality;
}

void CameraController::addLiveViewViewer()
{
    int n = m_liveViewViewers.fetch_add(1) + 1;
    // Đánh thức decode thread để nó tiếp tục giải mã ngay lập tức
    m_jpegCondition.notify_all();
    qDebug() << "[LiveView] viewer added — active viewers =" << n;
}

void CameraController::removeLiveViewViewer()
{
    int prev = m_liveViewViewers.fetch_sub(1);
    if (prev <= 0) {
        // Guard chống underflow nếu add/remove lệch nhau
        m_liveViewViewers.store(0);
        qWarning() << "[LiveView] removeLiveViewViewer() called with no active viewer";
        return;
    }
    qDebug() << "[LiveView] viewer removed — active viewers =" << (prev - 1);
}

void CameraController::connectAsync()
{
    // Hot Folder: không đụng SDK. Nút "Bắt đầu theo dõi / Theo dõi lại" và lần
    // tự kết nối lúc mở app (main.cpp) đều đi vào đây → theo dõi lại thư mục.
    if (isHotFolderSource()) {
        releaseSdkForHotFolder();
        if (m_useWebcamLiveView && m_selectedWebcamIndex >= 0 && !isLiveViewActive())
            startWebcamLiveView(m_selectedWebcamIndex);
        startHotFolder();
        QTimer::singleShot(0, this, [this]() { emit connectFinished(m_hotFolderReady); });
        return;
    }

    // Single-flight guard: a second Connect click must not start or queue a
    // duplicate SDK operation. Brand changes while connecting are queued from
    // setCameraType(), where we know the target type actually changed.
    if (m_isConnecting.exchange(true)) {
        qDebug() << "CameraController::connectAsync: already in progress, ignoring duplicate request";
        return;
    }

    const QString requestedType = m_cameraType;
    qDebug() << "CameraController::connectAsync: starting background connect for"
             << requestedType;
    emit isConnectingChanged();

    // Run the blocking detection + connect off the main thread so the UI loop
    // never stalls during USB enumeration. The dedicated camera pool has a
    // single worker, so switch/reconnect cannot overlap with capture.
    (void)QtConcurrent::run(&m_camPool, [this, requestedType]() {
        bool ok = connectToServerForType(requestedType);
        const QString connectedType = ok ? normalizeSdkType(CameraBackend::camera().sdkType())
                                         : requestedType;
        if (ok && connectedType != "Nikon") {
            // startLiveView touches Qt objects — dispatch to main thread.
            QMetaObject::invokeMethod(this, [this]() {
                startLiveView();
            }, Qt::QueuedConnection);
        } else if (ok) {
            QMetaObject::invokeMethod(this, [this]() {
                QTimer::singleShot(1000, this, [this]() {
                    if (m_cameraType != "Nikon" || m_isLiveViewActive)
                        return;
                    if (!CameraBackend::camera().isConnected())
                        return;

                    qWarning() << "CameraController: starting Nikon live view after connect delay";
                    if (!startLiveView()) {
                        qWarning() << "CameraController: Nikon live view start failed:"
                                   << m_lastError;
                    }
                });
            }, Qt::QueuedConnection);
        }

        // Signal back to QML on the main thread.
        QMetaObject::invokeMethod(this, [this, requestedType, ok]() {
            finishConnectAttempt(requestedType, ok);
        }, Qt::QueuedConnection);
    });
}

void CameraController::setCameraType(const QString &type)
{
    QString t = normalizeCameraType(type);
    if (t == m_cameraType)
        return;

    m_cameraType = t;

    persistCameraSetting(QStringLiteral("camera_type"), m_cameraType);

    if (m_isConnecting.load()) {
        m_pendingConnectRequest.store(true);
        qDebug() << "CameraController: camera type changed while connecting; queued reconnect";
    }

    qDebug() << "CameraController: camera type changed to" << m_cameraType
             << "- press Connect/Reconnect to use it.";
    emit cameraTypeChanged();
}

void CameraController::switchCameraType(const QString &type)
{
    const QString t = normalizeCameraType(type);

    // Đang Hot Folder mà chọn một hãng → về SDK rồi kết nối đúng hãng đó.
    if (isHotFolderSource()) {
        leaveHotFolder();
        setCameraType(t);
        connectAsync();
        return;
    }

    const bool changed = (t != m_cameraType);
    setCameraType(t);

    // If the UI asks to switch to the SDK that is already active (common after
    // auto-detect connected Fuji while the saved setting still said Canon), do
    // not tear down a healthy session just to reconnect to itself.
    const QString activeType = normalizeSdkType(CameraBackend::camera().sdkType());
    if (!changed && activeType == t && CameraBackend::camera().isConnected()) {
        qDebug() << "CameraController: switchCameraType no-op; already connected via" << activeType;
        QMetaObject::invokeMethod(this, [this]() {
            emit connectFinished(true);
        }, Qt::QueuedConnection);
        return;
    }

    connectAsync();
}

void CameraController::finishConnectAttempt(const QString& requestedType, bool ok)
{
    m_isConnecting.store(false);
    emit isConnectingChanged();
    emit connectFinished(ok);

    const bool hasPending = m_pendingConnectRequest.exchange(false);
    if (!hasPending)
        return;

    if (m_cameraType != requestedType) {
        qDebug() << "CameraController: running queued connect for latest camera type"
                 << m_cameraType;
        QTimer::singleShot(0, this, &CameraController::connectAsync);
    } else {
        qDebug() << "CameraController: skipped duplicate queued connect for"
                 << requestedType;
    }
}

CameraController::~CameraController()
{
    stopRecordThread();

    auto& camera = CameraBackend::camera();
    camera.removeEventListener(m_eventBridge.get());

    if (m_isLiveViewActive) {
        stopLiveView();
    }

    camera.disconnectCamera();
    camera.shutdown();
}

void CameraController::setSessionStoragePath(const QString &path)
{
    qDebug() << "CameraController: Setting session path to" << path;
    m_sessionPath = path;

    QDir dir(m_sessionPath);
    if (!dir.exists()) {
        dir.mkpath(".");
    }

    // Configure camera save folder
    auto& camera = CameraBackend::camera();
    camera.setSaveFolder(path.toStdString() + "/");

    emit statusMessage("Session storage configured");
}

void CameraController::setCurrentSessionId(const QString &sessionId)
{
    qDebug() << "CameraController: Session ID set to" << sessionId;
    m_currentSessionId    = sessionId;
    m_sessionPhotoCounter = 0;   // reset counter for the new session
}

bool CameraController::connectToServer()
{
    return connectToServerForType(m_cameraType);
}

bool CameraController::connectToServerForType(const QString& cameraType)
{
    qDebug() << "CameraController: Connecting to camera...";
    emit statusMessage("Connecting to camera...");

    std::unique_lock<std::mutex> sdkLock(m_sdkOperationMutex);
    auto& camera = CameraBackend::camera();

    stopSdkLiveViewForReconnect(camera);

    // Disconnect any existing session so both SDKs can enumerate freely.
    // Sony CRSDK cannot run EnumCameraObjects while a session is open;
    // skipping this causes "no Sony camera found" on the second Canon→Sony switch.
    if (camera.isConnected()) {
        qDebug() << "CameraController: disconnecting previous session before re-connect";
        camera.setLiveViewFrameCallback({});
        camera.disconnectCamera();
        m_lastFrameMs.store(0);
    }

    // Initialize SDK if not already done
    if (!camera.initialize()) {
        QString errMsg = "Failed to initialize camera SDK";
        m_lastError = errMsg;
        emit error(errMsg);
        emit lastErrorChanged();
        return false;
    }

    // Honour the user-selected camera source (Canon/Sony) before enumeration
    // so the preferred brand is listed first and connected to.
    camera.setPreferredBrand(cameraType.toStdString());

    // Find available cameras
    std::vector<CameraBackend::CameraInfo> cameras;
    if (!camera.findCameras(cameras)) {
        QString errMsg = "Failed to enumerate cameras";
        m_lastError = errMsg;
        emit error(errMsg);
        emit lastErrorChanged();
        return false;
    }

    if (cameras.empty()) {
        QString errMsg = "No cameras found";
        m_lastError = errMsg;
        emit error(errMsg);
        emit lastErrorChanged();
        return false;
    }

    if (cameras.size() > 1) {
        qDebug() << "CameraController:" << (int)cameras.size()
                 << "cameras detected — auto-selecting first.";
        // TODO: emit a camerasAvailable(QStringList) signal so QML can show
        //       a selection dialog instead of always picking index 0.
    }

    // Connect to first camera (index 0). Nikon's Control Service Layer is
    // sensitive around session open, so run just this step on the QObject/main
    // thread while keeping the slower detection step on the camera worker.
    bool connected = false;
    if (cameraType == "Nikon" && QThread::currentThread() != thread()) {
        qWarning() << "CameraController: dispatching Nikon connectCamera(0) to main thread";
        const bool invoked = QMetaObject::invokeMethod(this, [&camera, &connected]() {
            qWarning() << "CameraController: Nikon connectCamera(0) begin";
            connected = camera.connectCamera(0);
            qWarning() << "CameraController: Nikon connectCamera(0) end ok =" << connected;
        }, Qt::BlockingQueuedConnection);
        if (!invoked) {
            qWarning() << "CameraController: failed to dispatch Nikon connectCamera(0)";
        }
    } else {
        qWarning() << "CameraController: connectCamera(0) begin for" << cameraType;
        connected = camera.connectCamera(0);
        qWarning() << "CameraController: connectCamera(0) end for" << cameraType
                   << "ok =" << connected;
    }

    if (!connected) {
        QString errMsg = "Failed to connect to camera";
        m_lastError = errMsg;
        emit error(errMsg);
        emit lastErrorChanged();
        return false;
    }

    m_cameraModel = QString::fromStdString(camera.getCameraModel());
    emit cameraModelChanged();
    const QString actualType = normalizeSdkType(camera.sdkType());
    qDebug() << "CameraController: connected via" << actualType << "SDK";
    adoptConnectedCameraType(actualType, cameraType);

    // Populate property lists + current values from camera. Defer Nikon/Fuji
    // property probing during connect until each SDK path is proven stable.
    if (camera.sdkType() != "Nikon" && camera.sdkType() != "Fuji") {
        fetchCameraPropertyLists();
    } else {
        qWarning() << "CameraController:" << QString::fromStdString(camera.sdkType())
                   << "property fetch skipped during connect";
    }

    // Sony SDK needs ~1.5 s after connection for all device properties to be populated.
    if (camera.sdkType() == "Sony") {
        QTimer::singleShot(1500, this, [this]() {
            if (CameraBackend::camera().isConnected()) {
                qDebug() << "CameraController: Sony delayed property refresh...";
                fetchCameraPropertyLists();
            }
        });
    }

    // Keep the still-photo quality selected on the camera body. The capture
    // path downloads the camera-created file verbatim, so forcing this setting
    // here can silently override the operator's JPEG/RAW size choice.
    qDebug() << "CameraController: preserving camera image quality setting";

    // Register live view frame callback.
    // This lambda runs on the EDSDK streaming thread.  It ONLY copies the raw
    // JPEG bytes into a shared buffer and wakes the dedicated decode thread —
    // no JPEG decoding happens here.  The streaming thread is free to start
    // downloading the next camera frame immediately, so download and decode
    // run in parallel rather than sequentially.
    camera.setLiveViewFrameCallback([this](const uint8_t* data, size_t size) {
        if (!data || size == 0) return;
        // Đóng dấu thời gian mỗi frame để watchdog phát hiện live view "đứng"
        // (USB treo mà SDK không phát Disconnected). Atomic → an toàn từ
        // streaming thread; chạy kể cả khi không có viewer (decode bỏ qua).
        m_lastFrameMs.store(QDateTime::currentMSecsSinceEpoch());
        {
            std::lock_guard<std::mutex> lock(m_jpegMutex);
            // Reuse existing allocation when frame size is stable (avoids malloc)
            if (m_pendingJpeg.size() != size) m_pendingJpeg.resize(size);
            memcpy(m_pendingJpeg.data(), data, size);
            m_pendingMirror = m_mirrorMode;
            m_hasNewJpeg    = true;
        }
        m_jpegCondition.notify_one();
    });

    emit statusMessage("Connected: " + m_cameraModel);
    return true;
}

void CameraController::stopSdkLiveViewForReconnect(ICameraSDK& camera)
{
    if (!m_isLiveViewActive || m_useWebcamLiveView)
        return;

    qWarning() << "CameraController: stopping active SDK live view before reconnect/source switch";

    if (m_performanceTimer.isValid()) {
        qint64 sessionMs = m_performanceTimer.elapsed();
        qWarning() << "[LiveView] Session ended | duration:" << sessionMs << "ms"
                   << "| final FPS:" << m_currentFps
                   << "| drops:" << m_frameDropCount
                   << "| health:" << m_bufferHealth << "%";
    }

    camera.stopLiveViewStreaming();
    camera.stopLiveView();
    camera.setLiveViewFrameCallback({});
    stopDecodeThread();

    m_isLiveViewActive = false;
    m_lastFrameMs.store(0);

    QMetaObject::invokeMethod(this, [this]() {
        emit isLiveViewActiveChanged();
        emit statusMessage("Live view stopped");
    }, Qt::QueuedConnection);
}

void CameraController::adoptConnectedCameraType(const QString& actualType,
                                                const QString& requestedType)
{
    if (actualType != "Canon" && actualType != "Sony"
            && actualType != "Nikon" && actualType != "Fuji") {
        return;
    }

    if (actualType == m_cameraType)
        return;

    qWarning() << "CameraController: requested camera source" << requestedType
               << "but connected via" << actualType
               << "- updating source state";

    m_cameraType = actualType;

    persistCameraSetting(QStringLiteral("camera_type"), m_cameraType);
    CameraBackend::camera().setPreferredBrand(m_cameraType.toStdString());

    QMetaObject::invokeMethod(this, [this]() {
        emit cameraTypeChanged();
    }, Qt::QueuedConnection);
}

bool CameraController::startLiveView()
{
    qDebug() << "CameraController: Starting live view...";

    // Ở chế độ webcam: không khởi động SDK live view stream (tránh tranh chấp
    // LiveViewImageProvider). Nếu đã lưu device thì start webcam để các trang có
    // live view ngay khi mở app. Kết nối điều khiển camera vẫn giữ nguyên.
    if (m_useWebcamLiveView) {
        if (m_selectedWebcamIndex >= 0)
            return startWebcamLiveView(m_selectedWebcamIndex);
        qDebug() << "CameraController: webcam mode but no device saved yet";
        return false;
    }

    if (m_isLiveViewActive) {
        qDebug() << "Live view already active";
        return true;
    }

    // Reset mốc frame để watchdog có khoảng ân hạn — tránh báo "đứng feed" giả
    // ngay sau khi start trong khi frame đầu tiên chưa kịp về.
    m_lastFrameMs.store(QDateTime::currentMSecsSinceEpoch());

    auto& camera = CameraBackend::camera();
    const QString sdkType = QString::fromStdString(camera.sdkType());
    if (sdkType == "Fuji") {
        camera.setFujiLiveViewOptions(m_fujiLiveViewSize.toStdString(),
                                      m_fujiLiveViewQuality.toStdString());
    }

    if (sdkType == "Nikon") {
        qWarning() << "CameraController: Starting Nikon live view stream...";
        startDecodeThread();

        if (!camera.startLiveViewStreaming()) {
            stopDecodeThread();
            QString errMsg = "Failed to start Nikon live view: "
                           + QString::fromStdString(camera.getLastError());
            m_lastError = errMsg;
            emit error(errMsg);
            emit lastErrorChanged();
            return false;
        }

        m_fpsTimer.start();
        m_frameCount = 0;
        m_currentFps = 0;
        m_performanceTimer.start();
        m_frameDropCount = 0;
        m_skippedFrameCount = 0;
        m_bufferHealth = 100;
        m_expectedFps = 30;

        qWarning() << "[LiveView] Nikon started | target FPS:"
                   << m_targetLiveViewFps.load()
                   << "| maxWidth:" << m_maxLiveViewWidth.load();

        m_isLiveViewActive = true;
        emit isLiveViewActiveChanged();
        emit statusMessage("Live view started");
        return true;
    }

    // Start live view
    if (!camera.startLiveView()) {
        QString errMsg = "Failed to start live view: " + QString::fromStdString(camera.getLastError());
        m_lastError = errMsg;
        emit error(errMsg);
        emit lastErrorChanged();
        return false;
    }

    // Start the dedicated JPEG decode thread before streaming begins
    startDecodeThread();

    // Start streaming
    if (!camera.startLiveViewStreaming()) {
        stopDecodeThread();
        camera.stopLiveView();
        QString errMsg = "Failed to start live view streaming";
        m_lastError = errMsg;
        emit error(errMsg);
        emit lastErrorChanged();
        return false;
    }

    // Initialize FPS tracking
    m_fpsTimer.start();
    m_frameCount = 0;
    m_currentFps = 0;
    m_performanceTimer.start();
    m_frameDropCount = 0;
    m_skippedFrameCount = 0;
    m_bufferHealth = 100;
    m_expectedFps = 30;

    qWarning() << "[LiveView] Started | target FPS:" << m_targetLiveViewFps.load()
               << "| maxWidth:" << m_maxLiveViewWidth.load();

    m_isLiveViewActive = true;
    emit isLiveViewActiveChanged();
    emit statusMessage("Live view started");

    return true;
}

bool CameraController::stopLiveView()
{
    qDebug() << "CameraController: Stopping live view...";

    if (!m_isLiveViewActive) {
        qDebug() << "Live view already stopped";
        return true;
    }

    // Log final FPS summary for the live view session
    if (m_performanceTimer.isValid()) {
        qint64 sessionMs = m_performanceTimer.elapsed();
        qWarning() << "[LiveView] Session ended | duration:" << sessionMs << "ms"
                   << "| final FPS:" << m_currentFps
                   << "| drops:" << m_frameDropCount
                   << "| health:" << m_bufferHealth << "%";
    }

    auto& camera = CameraBackend::camera();
    camera.stopLiveViewStreaming();
    camera.stopLiveView();

    // Stop decode thread after streaming has stopped (no more frames will arrive)
    stopDecodeThread();

    m_isLiveViewActive = false;
    emit isLiveViewActiveChanged();
    emit statusMessage("Live view stopped");

    return true;
}

bool CameraController::takePicture()
{
    qDebug() << "CameraController: Taking picture...";

    auto& camera = CameraBackend::camera();

    if (m_isConnecting.load() && !m_mockCaptureEnabled) {
        qWarning() << "CameraController: capture ignored while camera connect/switch is in progress";
        emit statusMessage("Camera is connecting; capture skipped");
        return false;
    }

    if (m_mockCaptureEnabled) {
        qDebug() << "CameraController: Mock capture enabled. Generating virtual image.";
        emit statusMessage("Mock capturing image...");

        // Simulate shutter firing delay
        QTimer::singleShot(200, [this]() {
            emit this->captureCompleted();

            // Simulate file format processing and download delay
            QTimer::singleShot(600, [this]() {
                QImage mockImg(1920, 1080, QImage::Format_RGB32);
                int r = QRandomGenerator::global()->bounded(100) + 100;
                int g = QRandomGenerator::global()->bounded(100) + 100;
                int b = QRandomGenerator::global()->bounded(100) + 100;
                mockImg.fill(QColor(r, g, b));

                QPainter painter(&mockImg);
                painter.setBrush(QColor(255, 255, 255, 200));
                painter.setPen(Qt::NoPen);
                painter.drawRect(mockImg.rect().adjusted(100, 100, -100, -100));

                painter.setPen(Qt::black);
                painter.setFont(QFont("Arial", 80, QFont::Bold));
                painter.drawText(mockImg.rect(), Qt::AlignCenter, "VIRTUAL PHOTO");
                
                painter.setFont(QFont("Arial", 40));
                QString timeStr = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
                painter.drawText(mockImg.rect().adjusted(0, 200, 0, 0), Qt::AlignCenter, timeStr);
                painter.end();

                QDir dir(m_sessionPath);
                if (!dir.exists()) {
                    dir.mkpath(".");
                }
                
                m_sessionPhotoCounter++;
                QString fileName = QString("MOCK_%1_%2.jpg")
                                       .arg(m_currentSessionId.isEmpty() ? "IMG" : m_currentSessionId)
                                       .arg(m_sessionPhotoCounter, 4, 10, QChar('0'));
                QString filePath = dir.filePath(fileName);

                mockImg.save(filePath, "JPG", 90);
                
                qDebug() << "CameraController: Mock image saved to" << filePath;
                emit this->imageCaptured(filePath);
            });
        });
        return true;
    }

    // Hot Folder: app không điều khiển máy — ảnh tới khi khách bấm remote.
    if (isHotFolderSource()) {
        qDebug() << "CameraController: capture ignored - Hot Folder source (photos come from the folder)";
        emit statusMessage("Hot Folder: bấm remote trên máy ảnh để chụp");
        return false;
    }

    if (!camera.isConnected()) {
        qWarning() << "CameraController: capture rejected because camera is disconnected";
        emit error("Camera not connected");
        emit statusMessage("Camera not connected");
        return false;
    }

    emit statusMessage("Capturing image...");

    // Run on a true background thread via QtConcurrent so pressShutter()'s
    // future.wait() never blocks the Qt main thread / UI event loop.
    bool useAF = m_afEnabled;
    QtConcurrent::run(&m_camPool, [this, useAF]() {
        auto& camera = CameraBackend::camera();
        // Measure total blocking capture time (AF + exposure + image transfer).
        // For Nikon this is exactly the window where live view is frozen, so it
        // tells us how much the per-shot stutter is and where to optimise.
        QElapsedTimer capTimer; capTimer.start();
        const QString sdkType = QString::fromStdString(camera.sdkType());
        bool ok = false;
        if (useAF) {
            ok = camera.takePhoto();
        } else {
            ok = camera.takePhotoNoAF();
        }
        if (sdkType == "Fuji") {
            qWarning() << "[Capture] takePhoto() command duration" << capTimer.elapsed()
                       << "ms | sdkType:" << sdkType << "| AF:" << useAF;
        } else {
            qWarning() << "[Capture] takePhoto() blocked for" << capTimer.elapsed()
                       << "ms (AF+exposure+transfer) | sdkType:" << sdkType
                       << "| AF:" << useAF;
        }
        if (!ok) {
            QMetaObject::invokeMethod(this, [this]() {
                emit error("Camera capture command failed");
                emit statusMessage("Capture command failed");
            }, Qt::QueuedConnection);
        }
        // SDK events (captureCompleted, imageCaptured) fire automatically
    });

    return true;
}

bool CameraController::takePictureNoAF()
{
    qDebug() << "CameraController: Taking picture without AF...";

    if (m_mockCaptureEnabled || isHotFolderSource()) {
        return takePicture();
    }

    if (m_isConnecting.load()) {
        qWarning() << "CameraController: no-AF capture ignored while camera connect/switch is in progress";
        emit statusMessage("Camera is connecting; capture skipped");
        return false;
    }

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        return takePicture();
    }

    emit statusMessage("Capturing image without AF...");
    QtConcurrent::run(&m_camPool, [this]() {
        auto& camera = CameraBackend::camera();
        const bool ok = camera.takePhotoNoAF();
        if (!ok) {
            QMetaObject::invokeMethod(this, [this]() {
                emit error("Camera no-AF capture command failed");
                emit statusMessage("No-AF capture command failed");
            }, Qt::QueuedConnection);
        }
    });

    return true;
}

void CameraController::setRemoteShutterMode(bool on)
{
    if (isHotFolderSource())
        return;   // máy ảnh do phần mềm hot folder giữ, không có phiên SDK
    std::lock_guard<std::mutex> lock(m_sdkOperationMutex);
    CameraBackend::camera().setRemoteShutterMode(on);
    qDebug() << "CameraController: Remote shutter mode" << (on ? "enabled" : "disabled");
}

void CameraController::setRemoteShutterModeAsync(bool on)
{
    (void)QtConcurrent::run(&m_camPool, [this, on]() {
        setRemoteShutterMode(on);
    });
}

bool CameraController::setIso(const QString &iso)
{
    qDebug() << "CameraController: Setting ISO to" << iso;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    emit statusMessage(QString("Setting ISO to %1...").arg(iso));
    bool ok = camera.setISO(iso.toInt());
    if (ok) {
        m_iso = iso;
        emit currentIsoChanged(m_iso);
    }
    return ok;
}

bool CameraController::setAperture(const QString &aperture)
{
    qDebug() << "CameraController: Setting Aperture to" << aperture;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    emit statusMessage(QString("Setting Aperture to %1...").arg(aperture));
    bool ok = camera.setAperture(aperture.toStdString());
    if (ok) {
        m_aperture = aperture;
        emit currentApertureChanged(m_aperture);
    }
    return ok;
}

bool CameraController::setShutterSpeed(const QString &speed)
{
    qDebug() << "CameraController: Setting Shutter Speed to" << speed;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    emit statusMessage(QString("Setting Shutter Speed to %1...").arg(speed));
    bool ok = camera.setShutterSpeed(speed.toStdString());
    if (ok) {
        m_shutterSpeed = speed;
        emit currentShutterSpeedChanged(m_shutterSpeed);
    }
    return ok;
}

bool CameraController::setWhiteBalance(const QString &wb)
{
    qDebug() << "CameraController: Setting White Balance to" << wb;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    // Map WB label → preset code.
    // Includes English labels (Canon path) + Vietnamese labels (Sony formatWb() path).
    // For Sony-only codes that have no Canon equivalent the "code" value is the raw
    // Sony CrInt16u value; we detect those below and bypass canonWbToSony().
    static const struct { const char* label; int code; } kWb[] = {
        // English (Canon)
        { "Auto",         0  }, { "Daylight",   1  }, { "Shade",      2  },
        { "Cloudy",       3  }, { "Tungsten",   4  }, { "Fluorescent", 5  },
        { "Flash",        6  }, { "Custom",     8  }, { "Color Temp", 9  },
        { "AWB White",    15 },
        // Vietnamese equivalents of Canon codes
        { "Tự động",                     0  },
        { "Ánh sáng ban ngày",           1  },
        { "Bóng râm",                    2  },
        { "Có mây",                      3  },
        { "Đèn dây tóc",                 4  },
        { "Đèn huỳnh quang",             5  },
        { "Đèn Flash",                   6  },
        { "Tùy chỉnh 1",                 8  },
        { "Nhiệt độ màu",                9  },
        // Sony-only codes (no Canon equivalent) — sent directly to camera
        { "Dưới nước",                   0x000B },
        { "Tùy chỉnh",                   0x0011 },
        { "Tự động (ưu tiên ấm)",        0x0012 },
        { "Tự động (ưu tiên trắng)",      0x0013 },
        { "Tự động (ưu tiên tự nhiên)",   0x0014 },
        { "Tùy chỉnh 2",                 0x0020 },
        { "Tùy chỉnh 3",                 0x0021 },
        { "Đèn huỳnh quang ấm",          0x0022 },
        { "Đèn huỳnh quang lạnh",        0x0023 },
        { "Đèn huỳnh quang ban ngày",    0x0024 },
        { "CT (tùy chỉnh)",              0x0030 },
        { "Đèn huỳnh quang TL84",        0x0100 },
        { "Đèn huỳnh quang CWF",         0x0101 },
        { "Đèn huỳnh quang D50",         0x0102 },
        { "Đèn huỳnh quang D65",         0x0103 },
    };

    int code = wb.toInt();  // fallback: raw integer code passed as string
    bool foundInTable = false;
    for (auto& e : kWb) {
        if (wb == QString::fromUtf8(e.label)) { code = e.code; foundInTable = true; break; }
    }

    // Handle residual "WB 0x00XX" strings (truly unknown codes still shown as hex)
    if (!foundInTable && wb.startsWith("WB 0x", Qt::CaseInsensitive)) {
        bool parseOk = false;
        int parsed = wb.mid(3).toInt(&parseOk, 16);
        if (parseOk) { code = parsed; foundInTable = true; }
    }

    emit statusMessage(QString("Setting WB to %1...").arg(wb));

    // Sony-only codes: bypass the Canon→Sony remapping table inside setWhiteBalance()
    // by sending the raw Sony WB code directly.
    if (camera.sdkType() == "Sony") {
        static const int kCanonCodes[] = { 0,1,2,3,4,5,6,8,9,15 };
        bool isCanonCode = false;
        for (int c : kCanonCodes) { if (code == c) { isCanonCode = true; break; } }
        if (foundInTable && !isCanonCode && code > 9) {
            bool ok = camera.setWhiteBalance(code);
            if (ok) {
                m_whiteBalance = wb;
                emit currentWhiteBalanceChanged(m_whiteBalance);
            }
            return ok;
        }
    }

    bool ok = camera.setWhiteBalance(code);
    if (ok) {
        m_whiteBalance = wb;
        emit currentWhiteBalanceChanged(m_whiteBalance);
    }
    return ok;
}


bool CameraController::setCompressionSetting(const QString &quality)
{
    qDebug() << "CameraController: Setting compression to" << quality;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    return camera.setImageQuality(quality.toInt());
}

bool CameraController::setExposureCompensation(const QString &ev)
{
    qDebug() << "CameraController: Setting exposure compensation to" << ev;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    // Map EV label → EDSDK signed code (each 1/3 stop = 3 units, +1 EV = 8)
    static const struct { const char* label; int code; } kEv[] = {
        { "+3", 24 }, { "+2 2/3", 21 }, { "+2 1/3", 19 }, { "+2", 16 },
        { "+1 2/3", 13 }, { "+1 1/3", 11 }, { "+1", 8 }, { "+2/3", 5 },
        { "+1/3", 3 }, { "0", 0 },
        { "-1/3", -3 }, { "-2/3", -5 }, { "-1", -8 }, { "-1 1/3", -11 },
        { "-1 2/3", -13 }, { "-2", -16 }, { "-2 1/3", -19 }, { "-2 2/3", -21 },
        { "-3", -24 },
    };
    int code = ev.toInt();  // fallback
    for (auto& e : kEv) {
        if (ev == e.label) { code = e.code; break; }
    }

    emit statusMessage(QString("Setting EV to %1...").arg(ev));
    bool ok = camera.setExposureComp(code);
    if (ok) {
        m_exposureCompensation = ev;
        emit currentExposureCompensationChanged(m_exposureCompensation);
    }
    return ok;
}

bool CameraController::setColorTemperature(const QString &kelvin)
{
    qDebug() << "CameraController: Setting color temperature to" << kelvin;

    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) {
        emit error("Camera not connected");
        return false;
    }

    int k = kelvin.toInt();
    k = qBound(2500, k, 10000);
    k = ((k + 5) / 10) * 10;

    emit statusMessage(QString("Setting CT to %1K...").arg(k));
    bool ok = camera.setColorTemperature(k);
    if (ok) {
        m_colorTemperature = QString::number(k);
        emit currentColorTemperatureChanged(m_colorTemperature);
    }
    return ok;
}

bool CameraController::setCameraParameter(const QString &param, const QString &value)
{
    qDebug() << "CameraController: Setting parameter" << param << "=" << value;
    // Generic parameter setting - delegate to specific setters
    if (param == "iso") {
        return setIso(value);
    } else if (param == "aperture") {
        return setAperture(value);
    } else if (param == "shutter") {
        return setShutterSpeed(value);
    } else if (param == "wb") {
        return setWhiteBalance(value);
    } else if (param == "colorTemperature" || param == "color-temperature" ||
               param == "colorTemp" || param == "kelvin") {
        return setColorTemperature(value);
    }
    return false;
}

bool CameraController::getCurrentIso()
{
    auto state = CameraBackend::camera().getState();
    if (!state.valid) return false;
    m_iso = QString::number(state.iso);
    emit currentIsoChanged(m_iso);
    return true;
}

bool CameraController::getCurrentAperture()
{
    auto state = CameraBackend::camera().getState();
    if (!state.valid) return false;
    m_aperture = QString::number(state.av);
    emit currentApertureChanged(m_aperture);
    return true;
}

bool CameraController::getCurrentShutterSpeed()
{
    auto state = CameraBackend::camera().getState();
    if (!state.valid) return false;
    m_shutterSpeed = QString::number(state.tv);
    emit currentShutterSpeedChanged(m_shutterSpeed);
    return true;
}

bool CameraController::getCurrentWhiteBalance()
{
    auto state = CameraBackend::camera().getState();
    if (!state.valid) return false;
    m_whiteBalance = QString::number(state.whiteBalance);
    emit currentWhiteBalanceChanged(m_whiteBalance);
    return true;
}

bool CameraController::getCurrentCompressionSetting()
{
    return false;
}

bool CameraController::getCurrentExposureCompensation()
{
    auto state = CameraBackend::camera().getState();
    if (!state.valid) return false;
    m_exposureCompensation = QString::number(state.exposureComp);
    emit currentExposureCompensationChanged(m_exposureCompensation);
    return true;
}

bool CameraController::getCurrentColorTemperature()
{
    auto state = CameraBackend::camera().getState();
    if (!state.valid) return false;
    m_colorTemperature = QString::number(state.colorTemp);
    emit currentColorTemperatureChanged(m_colorTemperature);
    return true;
}

bool CameraController::fetchCameraPropertyLists()
{
    auto& camera = CameraBackend::camera();
    if (!camera.isConnected()) return false;

    qDebug() << "CameraController: Fetching property lists from camera...";

    // We emit signals manually after fetching
    auto fetchOne = [&](uint32_t propId, QStringList& list, QString& current) {
        std::vector<std::string> rawList;
        std::string rawCurrent;
        if (camera.getPropertyStrings(propId, rawList, rawCurrent)) {
            list.clear();
            for (auto& s : rawList) list << QString::fromStdString(s);
            current = QString::fromStdString(rawCurrent);
            return true;
        }
        return false;
    };

    bool any = false;

    if (fetchOne(CameraBackend::PropISO, m_isoList, m_iso)) {
        m_isoList.removeAll("Auto");
        // If camera was set to Auto ISO, force the first manual value
        if (m_iso == "Auto" || m_iso.toInt() == 0) {
            m_iso = m_isoList.isEmpty() ? "400" : m_isoList.first();
            camera.setISO(m_iso.toInt());
            qWarning() << "CameraController: Auto ISO detected — forced to" << m_iso;
        }
        emit isoListChanged(m_isoList);
        emit currentIsoChanged(m_iso);
        any = true;
    }
    if (fetchOne(CameraBackend::PropTv, m_shutterSpeedList, m_shutterSpeed)) {
        m_shutterSpeedList.removeAll("bulb");
        emit shutterSpeedListChanged(m_shutterSpeedList);
        emit currentShutterSpeedChanged(m_shutterSpeed);
        any = true;
    }
    if (fetchOne(CameraBackend::PropAv, m_apertureList, m_aperture)) {
        emit apertureListChanged(m_apertureList);
        emit currentApertureChanged(m_aperture);
        any = true;
    }
    if (fetchOne(CameraBackend::PropWB, m_whiteBalanceList, m_whiteBalance)) {
        m_whiteBalanceList.removeAll("Auto");
        m_whiteBalanceList.removeAll("AWB White");
        emit whiteBalanceListChanged(m_whiteBalanceList);
        emit currentWhiteBalanceChanged(m_whiteBalance);
        any = true;
    }
    if (fetchOne(CameraBackend::PropEV, m_exposureCompensationList, m_exposureCompensation)) {
        emit exposureCompensationListChanged(m_exposureCompensationList);
        emit currentExposureCompensationChanged(m_exposureCompensation);
        any = true;
    }

    // Color Temperature (Kelvin). Both Canon EDSDK and Sony CRSDK accept the
    // common 2500–10000 K range in 100 K steps; the camera clamps anything
    // it does not support. A fixed list keeps the dropdown identical for
    // both brands.
    if (m_colorTemperatureList.isEmpty()) {
        for (int k = 2500; k <= 10000; k += 100)
            m_colorTemperatureList << QString::number(k);
        emit colorTemperatureListChanged(m_colorTemperatureList);
    }
    getCurrentColorTemperature();   // sync current value from the camera

    qDebug() << "CameraController: fetchCameraPropertyLists done:"
             << "ISO" << m_isoList.size() << "Tv" << m_shutterSpeedList.size()
             << "Av" << m_apertureList.size() << "WB" << m_whiteBalanceList.size()
             << "EV" << m_exposureCompensationList.size();
    return any;
}

bool CameraController::getAllCameraProperties()
{
    // Trigger read of all properties
    getCurrentIso();
    getCurrentAperture();
    getCurrentShutterSpeed();
    getCurrentWhiteBalance();
    getCurrentExposureCompensation();
    getCurrentColorTemperature();
    return true;
}

bool CameraController::isLiveViewActive() const
{
    if (m_useWebcamLiveView)
        return m_webcamLiveView && m_webcamLiveView->isActive();
    return m_isLiveViewActive;
}

void CameraController::setImageProvider(LiveViewImageProvider *provider)
{
    m_imageProvider = provider;
    if (m_webcamLiveView)
        m_webcamLiveView->setImageProvider(provider);
}

QByteArray CameraController::latestFrameAsJpeg() const
{
    if (!m_imageProvider) return {};

    QSize sz;
    QImage img = m_imageProvider->requestImage("frame", &sz, QSize());
    // 1×1 sentinel means no real frame yet
    if (img.isNull() || sz.width() <= 1) return {};

    QByteArray ba;
    QBuffer buf(&ba);
    buf.open(QIODevice::WriteOnly);
    img.save(&buf, "JPEG", 85);   // quality 85 — buena relación tamaño/calidad
    return ba;
}


void CameraController::setMirrorMode(bool enabled)
{
    m_mirrorMode = enabled;
    if (m_webcamLiveView)
        m_webcamLiveView->setMirror(enabled);
    emit mirrorModeChanged(enabled);
}

void CameraController::setAfEnabled(bool enabled)
{
    if (m_afEnabled == enabled) return;
    m_afEnabled = enabled;
    emit afEnabledChanged(enabled);
}

// ---------------------------------------------------------------------------
// Webcam Live View
// ---------------------------------------------------------------------------

void CameraController::ensureWebcamLiveView()
{
    if (m_webcamLiveView)
        return;

    m_webcamLiveView = std::make_unique<WebcamLiveView>(this);
    m_webcamLiveView->setImageProvider(m_imageProvider);
    // Đẩy cài đặt hiện tại xuống để webcam xử lý frame nhất quán với SDK
    m_webcamLiveView->setMirror(m_mirrorMode);
    m_webcamLiveView->setMaxWidth(m_maxLiveViewWidth.load());
    m_webcamLiveView->setTargetFps(m_targetLiveViewFps.load());
    // Khi webcam có frame mới, emit frameReady với QImage rỗng để LiveViewPanel
    // kéo frame mới nhất từ LiveViewImageProvider (giống SDK path)
    connect(m_webcamLiveView.get(), &WebcamLiveView::frameReady,
            this, [this]() { emit frameReady(QImage{}); }, Qt::QueuedConnection);
}

QStringList CameraController::scanWebcams()
{
    ensureWebcamLiveView();

    m_webcamList = m_webcamLiveView->scanDevices();
    emit webcamListChanged();
    return m_webcamList;
}

bool CameraController::startWebcamLiveView(int deviceIndex)
{
    ensureWebcamLiveView();

    // Dừng SDK live view stream để nhả LiveViewImageProvider (giữ kết nối camera
    // → chụp ảnh & chỉnh thông số vẫn hoạt động bình thường).
    if (m_isLiveViewActive)
        stopLiveView();

    // Đồng bộ cài đặt hiện tại trước khi chạy
    m_webcamLiveView->setMirror(m_mirrorMode);
    m_webcamLiveView->setMaxWidth(m_maxLiveViewWidth.load());
    m_webcamLiveView->setTargetFps(m_targetLiveViewFps.load());

    bool ok = m_webcamLiveView->start(deviceIndex);
    if (ok) {
        m_selectedWebcamIndex = deviceIndex;
        persistCameraSetting(QStringLiteral("liveview_webcam_index"),
                             QString::number(deviceIndex));
        emit selectedWebcamIndexChanged();
        // Thông báo QML rằng live view đang active (qua webcam)
        emit isLiveViewActiveChanged();
    }
    return ok;
}

void CameraController::stopWebcamLiveView()
{
    if (m_webcamLiveView && m_webcamLiveView->isActive()) {
        m_webcamLiveView->stop();
        emit isLiveViewActiveChanged();
    }
}

void CameraController::setUseWebcamLiveView(bool use)
{
    if (m_useWebcamLiveView == use) return;
    if (!use && isHotFolderSource()) {
        qDebug() << "CameraController: SDK live view unavailable while using Hot Folder";
        emit useWebcamLiveViewChanged();   // QML đặt lại combo về HDMI/Webcam
        return;
    }
    m_useWebcamLiveView = use;
    persistCameraSetting(QStringLiteral("liveview_source"),
                         use ? QStringLiteral("webcam") : QStringLiteral("sdk"));
    emit useWebcamLiveViewChanged();

    if (use) {
        // Chuyển sang webcam: dừng SDK live view stream (giữ kết nối camera để
        // chụp ảnh & chỉnh thông số vẫn chạy). Nếu đã lưu device thì start luôn
        // để live view hiện ngay ở mọi trang; nếu chưa, user Scan + chọn device.
        if (m_isLiveViewActive)
            stopLiveView();
        if (m_selectedWebcamIndex >= 0)
            startWebcamLiveView(m_selectedWebcamIndex);
        else
            emit isLiveViewActiveChanged();
    } else {
        // Chuyển về SDK: dừng webcam nếu đang chạy, rồi khởi động lại SDK live view
        stopWebcamLiveView();
        startLiveView();
        emit isLiveViewActiveChanged();
    }
}

void CameraController::setWatchdogEnabled(bool enabled)
{
    m_watchdogEnabled = enabled;
    if (enabled && !m_watchdogTimer->isActive()) {
        m_watchdogTimer->start();
    } else if (!enabled && m_watchdogTimer->isActive()) {
        m_watchdogTimer->stop();
    }
}

void CameraController::onWatchdogTimeout()
{
    // Đang có thao tác SDK chạy nền (connect/capture) → để yên, single-flight
    // guard m_isConnecting sẽ chống chạy chồng; lần tick sau sẽ kiểm tra lại.
    if (m_isConnecting.load())
        return;

    // Hot Folder: SDK cố ý ngắt — không tự kết nối lại (sẽ giành USB của HotFolder.exe).
    if (isHotFolderSource())
        return;

    auto& camera = CameraBackend::camera();

    // (1) Hard disconnect: SDK báo mất kết nối (vd: rút USB và SDK phát Disconnected).
    bool lost = !camera.isConnected();
    QString reason = lost ? "camera reported disconnected" : QString();

    // (2) Frozen feed: vẫn "connected" nhưng live view đang bật mà không có frame
    //     mới quá m_watchdogTimeout → USB/SDK treo im lặng. Webcam dùng đường
    //     riêng (không qua callback này) nên bỏ qua khi đang ở chế độ webcam.
    if (!lost && m_isLiveViewActive && !m_useWebcamLiveView) {
        const qint64 last = m_lastFrameMs.load();
        const qint64 age  = QDateTime::currentMSecsSinceEpoch() - last;
        if (last > 0 && age > m_watchdogTimeout) {
            lost   = true;
            reason = QString("live view frozen (%1 ms without a frame)").arg(age);
        }
    }

    if (!lost) {
        // Kết nối lành mạnh → reset cờ throttle để lần mất kết nối sau lại log.
        m_watchdogLoggedDisconnect = false;

        // ── Keep-alive chủ động ──────────────────────────────────────────────
        // Gửi ExtendShutDownTimer định kỳ để máy ảnh/USB không tự ngủ khi idle
        // (Canon auto-power-off). Lệnh round-trip này cũng là phép "dò sống":
        // thất bại trong khi vẫn báo connected → nghi USB treo im lặng (chỉ log,
        // để tick watchdog sau lo reconnect; tránh phản ứng nhầm với
        // EDS_ERR_DEVICE_BUSY thoáng qua lúc đang chụp). Chỉ áp dụng Canon —
        // Sony/Nikon extendKeepAlive() là no-op trả true.
        if (!m_isConnecting.load() && camera.sdkType() == "Canon") {
            const qint64 now  = QDateTime::currentMSecsSinceEpoch();
            const qint64 last = m_lastKeepAliveMs.load();
            if (last == 0 || now - last >= m_keepAliveIntervalMs) {
                m_lastKeepAliveMs.store(now);
                // Chạy trên m_camPool (đơn luồng) để serialize với connect/capture
                // và không block UI thread.
                (void)QtConcurrent::run(&m_camPool, [this]() {
                    bool ok = CameraBackend::camera().extendKeepAlive();
                    if (ok) {
                        m_keepAliveFailCount = 0;
                    } else if (CameraBackend::camera().isConnected()) {
                        if (++m_keepAliveFailCount >= 2)
                            qWarning() << "CameraController: keep-alive failed twice while still"
                                          " connected — possible silent USB hang";
                    }
                    qDebug() << "CameraController: keep-alive sent, ok =" << ok;
                });
            }
        }
        return;
    }

    if (!m_watchdogLoggedDisconnect) {
        qWarning() << "CameraController: Watchdog detected disconnection ("
                   << reason << ") — attempting reconnect...";
        m_watchdogLoggedDisconnect = true;
    }

    // connectAsync() set m_isConnecting=true ngay (single-flight), chạy detection
    // + connect trên m_camPool nền nên KHÔNG block UI; thành công sẽ tự startLiveView().
    connectAsync();
}

// -----------------------------------------------------------------------------
// Dedicated JPEG decode thread
// -----------------------------------------------------------------------------

void CameraController::startDecodeThread()
{
    if (m_decodeRunning.load()) return;

    // Clear any stale pending data from a previous session
    {
        std::lock_guard<std::mutex> lock(m_jpegMutex);
        m_pendingJpeg.clear();
        m_hasNewJpeg = false;
    }

    m_decodeRunning.store(true);
    m_decodeThread = std::thread(&CameraController::decodeLoop, this);
    qDebug() << "CameraController: JPEG decode thread started";
}

void CameraController::stopDecodeThread()
{
    if (!m_decodeRunning.load()) return;

    {
        std::lock_guard<std::mutex> lock(m_jpegMutex);
        m_decodeRunning.store(false);
        m_hasNewJpeg = false;
    }
    m_jpegCondition.notify_all();   // wake thread so it can exit

    if (m_decodeThread.joinable()) {
        m_decodeThread.join();
    }
    qDebug() << "CameraController: JPEG decode thread stopped";
}

// ───────────────────────── Slot recording (process video) ────────────────────

void CameraController::startSlotRecording(int slotIndex, const QString &sessionDir)
{
    QString slotDir = QDir::fromNativeSeparators(sessionDir)
                      + QString("/slot_%1").arg(slotIndex);

    // Xoá sạch nội dung cũ (vd khi chụp lại slot này) để frame + manifest không
    // bị trộn với lần ghi trước (writer append manifest).
    QDir sd(QDir::toNativeSeparators(slotDir));
    if (sd.exists()) sd.removeRecursively();
    QDir().mkpath(slotDir);

    startRecordThread();   // bật writer thread nếu chưa chạy

    {
        std::lock_guard<std::mutex> lk(m_recordMutex);
        m_recordDir          = slotDir;
        m_recordFrameCounter = 0;
        m_recordLastFrameMs  = -1;
        m_recordTimer.restart();
        m_recording.store(true);
    }
    qDebug() << "CameraController: startSlotRecording slot" << slotIndex
             << "->" << slotDir;
}

void CameraController::stopSlotRecording()
{
    std::lock_guard<std::mutex> lk(m_recordMutex);
    if (!m_recording.load()) return;
    m_recording.store(false);
    m_recordDir.clear();   // chặn push frame mới; writer vẫn drain nốt hàng đợi
    qDebug() << "CameraController: stopSlotRecording (queue draining,"
             << m_recordQueue.size() << "pending)";
}

void CameraController::startRecordThread()
{
    if (m_recordThreadRunning.load()) return;
    m_recordThreadRunning.store(true);
    m_recordThread = std::thread(&CameraController::recordWriterLoop, this);
    qDebug() << "CameraController: record writer thread started";
}

void CameraController::stopRecordThread()
{
    if (!m_recordThreadRunning.load()) return;
    {
        std::lock_guard<std::mutex> lk(m_recordMutex);
        m_recording.store(false);
        m_recordThreadRunning.store(false);
    }
    m_recordCondition.notify_all();
    if (m_recordThread.joinable())
        m_recordThread.join();
    qDebug() << "CameraController: record writer thread stopped";
}

void CameraController::recordWriterLoop()
{
    qDebug() << "CameraController: recordWriterLoop() running on writer thread";

    while (true) {
        RecFrame rf;
        {
            std::unique_lock<std::mutex> lock(m_recordMutex);
            m_recordCondition.wait(lock, [this] {
                return !m_recordQueue.empty() || !m_recordThreadRunning.load();
            });
            if (!m_recordThreadRunning.load() && m_recordQueue.empty())
                break;
            if (m_recordQueue.empty())
                continue;
            rf = std::move(m_recordQueue.front());
            m_recordQueue.pop_front();
        }

        // Encode JPEG vào RAM trước rồi ghi nguyên khối — AV-safe (giống VideoCreator)
        QByteArray jpeg;
        {
            QBuffer buf(&jpeg);
            buf.open(QIODevice::WriteOnly);
            if (!rf.image.save(&buf, "JPEG", 85)) {
                qWarning() << "CameraController: failed to encode recording frame"
                           << rf.destPath;
                continue;
            }
        }
        {
            QFile f(QDir::toNativeSeparators(rf.destPath));
            if (!f.open(QIODevice::WriteOnly)) {
                qWarning() << "CameraController: cannot write recording frame"
                           << rf.destPath;
                continue;
            }
            f.write(jpeg);
            f.close();   // KHÔNG FlushFileBuffers mỗi frame: fsync vật lý ~30 lần/giây
                         // ngốn I/O và làm khựng live view khi đếm ngược. Frame chỉ
                         // được ffmpeg đọc vài giây sau (đã drain xong); mất 1 session
                         // process-video khi crash giữa chừng là chấp nhận được.
        }
        // Append manifest line ("<file> <ms>")
        {
            QFile mf(QDir::toNativeSeparators(rf.manifestPath));
            if (mf.open(QIODevice::Append)) {
                mf.write(rf.line);
                mf.close();
            }
        }
    }

    qDebug() << "CameraController: recordWriterLoop() exiting";
}

void CameraController::decodeLoop()
{
    qDebug() << "CameraController: decodeLoop() running on decode thread";

    // Local buffer reused across iterations to avoid repeated heap allocation
    std::vector<uint8_t> jpeg;
    uint64_t decodedFrameCount = 0;
    while (true) {
        bool mirror = false;

        // ── Wait for a new JPEG frame ────────────────────────────────────────
        {
            std::unique_lock<std::mutex> lock(m_jpegMutex);
            m_jpegCondition.wait(lock, [this] {
                return m_hasNewJpeg || !m_decodeRunning.load();
            });

            if (!m_decodeRunning.load()) break;

            // Swap buffers: take ownership of the latest JPEG data.
            // The streaming thread will reuse m_pendingJpeg for the next frame.
            jpeg.swap(m_pendingJpeg);
            mirror       = m_pendingMirror;
            m_hasNewJpeg = false;
        }
        // ── m_jpegMutex released — streaming thread can write next frame ────

        if (jpeg.empty()) continue;

        // ── Tạm dừng decode khi không có màn hình nào hiển thị live view ─────
        // Buffer JPEG đã được swap ở trên (đã "tiêu thụ" frame) nên chỉ cần
        // bỏ qua phần nặng: loadFromData (giải mã JPEG) + scaled + mirrored +
        // emit. Camera vẫn streaming → khi addLiveViewViewer() được gọi lại,
        // frame kế tiếp hiển thị ngay, không có độ trễ khởi động.
        if (m_liveViewViewers.load() <= 0) {
            continue;
        }

        // Track start of this frame for FPS throttle below
        auto frameStart = std::chrono::steady_clock::now();

        // ── Decode JPEG (runs fully outside the lock) ────────────────────────
        QImage img;
        img.loadFromData(jpeg.data(), static_cast<int>(jpeg.size()), "JPG");

        if (img.isNull()) continue;

        const QSize decodedSize = img.size();
        const QString sdkType = QString::fromStdString(CameraBackend::camera().sdkType());
        const bool isFujiFrame = (sdkType == "Fuji");

        // Downscale using cached atomic — no QSettings read per frame.
        // FastTransformation (nearest-neighbour) is sufficient for live view
        // and is significantly faster than SmoothTransformation on weak CPUs.
        const int requestedMaxW = m_maxLiveViewWidth.load();
        int maxW = requestedMaxW;
        if (isFujiFrame && requestedMaxW == 960 && decodedSize.width() <= 1280) {
            maxW = 0;
        }
        if (maxW > 0 && img.width() > maxW) {
            img = img.scaled(maxW,
                             img.height() * maxW / img.width(),
                             Qt::KeepAspectRatio,
                             Qt::FastTransformation);
        }

        const bool enhancedFujiFrame = isFujiFrame && img.width() <= 1280;
        if (enhancedFujiFrame) {
            applyFujiLiveViewSharpen(img);
        }

        ++decodedFrameCount;
        if (decodedFrameCount == 1 || (decodedFrameCount % 150) == 0) {
            qWarning() << "[LiveView] decoded frame" << decodedFrameCount
                       << "| source:" << decodedSize
                       << "| displayed:" << img.size()
                       << "| target FPS:" << m_targetLiveViewFps.load()
                       << "| maxWidth:" << requestedMaxW
                       << "| effectiveMaxWidth:" << maxW
                       << "| sdkType:" << sdkType
                       << "| fujiEnhance:" << enhancedFujiFrame;
        }

        if (mirror) {
            img = img.mirrored(true, false);
        }

        // ── Slot recording: snapshot frame hiện tại vào hàng đợi writer ──────
        // Lấy bản copy (implicit-share, O(1)) TRƯỚC khi std::move img vào provider.
        if (m_recording.load()) {
            std::lock_guard<std::mutex> lk(m_recordMutex);
            if (m_recording.load() && !m_recordDir.isEmpty()
                    && m_recordQueue.size() < 90) {  // cap để bảo vệ RAM nếu writer chậm
                qint64 ts = m_recordTimer.elapsed();
                if (m_recordLastFrameMs < 0
                        || ts - m_recordLastFrameMs >= m_recordMinFrameIntervalMs) {
                    m_recordLastFrameMs = ts;
                    int     idx   = m_recordFrameCounter++;
                    QString fname = QString("frame_%1.jpg").arg(idx, 5, 10, QChar('0'));
                    RecFrame rf;
                    rf.image        = img;
                    rf.destPath     = m_recordDir + "/" + fname;
                    rf.manifestPath = m_recordDir + "/manifest.txt";
                    rf.line         = fname.toUtf8() + " " + QByteArray::number(ts) + "\n";
                    m_recordQueue.push_back(std::move(rf));
                    m_recordCondition.notify_one();
                }
            }
        }

        // ── Store decoded frame and notify QML ───────────────────────────────
        if (m_imageProvider) {
            m_imageProvider->setImage(std::move(img));
        }

        // emit from non-main thread: Qt AutoConnection posts a QueuedConnection
        // event to the main thread — safe, no extra locking needed.
        emit frameReady(QImage());

        // ── FPS measurement and log (every 5 s → app.log) ───────────────────
        ++m_frameCount;
        qint64 elapsed = m_fpsTimer.elapsed();
        if (elapsed >= 5000) {
            m_currentFps = static_cast<int>(m_frameCount * 1000LL / elapsed);
            qWarning() << "[LiveView] FPS:" << m_currentFps
                       << "| target:" << m_targetLiveViewFps.load()
                       << "| frames:" << m_frameCount
                       << "over" << elapsed << "ms";
            m_frameCount = 0;
            m_fpsTimer.restart();
        }

        // ── FPS throttle: sleep the remaining time of the target interval ────
        // While we sleep the camera keeps depositing frames into m_pendingJpeg;
        // on the next iteration we wake up and take the LATEST frame ("latest wins").
        // This yields CPU time to other threads/processes on weak machines.
        int targetFps = m_targetLiveViewFps.load();
        if (targetFps > 0 && targetFps < 61) {
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(
                std::chrono::steady_clock::now() - frameStart).count();
            int sleepMs = (1000 / targetFps) - static_cast<int>(elapsed) - 2; // -2 ms buffer
            if (sleepMs > 5) {
                std::this_thread::sleep_for(std::chrono::milliseconds(sleepMs));
            }
        }
    }

    qDebug() << "CameraController: decodeLoop() exiting";
}

// -----------------------------------------------------------------------------
// Hậu xử lý ảnh chụp — dùng chung cho SDK (CameraEventBridge) và Hot Folder
// -----------------------------------------------------------------------------

QString CameraController::nextSessionPhotoPath(const QString &dir, const QString &ext,
                                               const QString &fallbackName)
{
    const QDir d(dir);
    QString name;
    if (!m_currentSessionId.isEmpty()) {
        // <sessionId>_photo_001.jpg — tránh ghi đè ảnh phiên cũ sau khi mất điện.
        const int counter = ++m_sessionPhotoCounter;
        name = QString("%1_photo_%2.%3")
                   .arg(m_currentSessionId)
                   .arg(counter, 3, 10, QChar('0'))
                   .arg(ext);
        if (QFile::exists(d.filePath(name))) {
            name = QString("%1_photo_%2_%3.%4")
                       .arg(m_currentSessionId)
                       .arg(counter, 3, 10, QChar('0'))
                       .arg(QDateTime::currentMSecsSinceEpoch())
                       .arg(ext);
        }
    } else {
        name = fallbackName;
        if (QFile::exists(d.filePath(name))) {
            const QFileInfo fi(fallbackName);
            name = QString("%1_%2.%3")
                       .arg(fi.completeBaseName())
                       .arg(QDateTime::currentMSecsSinceEpoch())
                       .arg(ext);
        }
    }
    return d.filePath(name);
}

bool CameraController::mirrorJpegInPlace(const QString &path)
{
    // QImage load + horizontal-flip + save mất 200-600 ms với JPEG full-size —
    // người gọi chạy hàm này trên thread nền.
    constexpr int kMirrorJpegQuality = 100;
    const QFileInfo beforeInfo(path);
    const qint64 beforeBytes = beforeInfo.exists() ? beforeInfo.size() : -1;

    QImageReader reader(path);
    // QImageWriter không ghi lại EXIF → xoay theo Orientation trước, nếu không
    // ảnh dọc sẽ nằm ngang sau khi lật.
    reader.setAutoTransform(true);
    const QImage image = reader.read();
    if (image.isNull()) {
        qWarning() << "CameraController: Mirror skipped; failed to load image" << path
                   << "| beforeBytes:" << beforeBytes << "|" << reader.errorString();
        return false;
    }

    const QImage mirrored = image.mirrored(true, false);
    const QString suffix = beforeInfo.suffix().toLower();
    const QByteArray format = (suffix == "jpeg" || suffix == "jpg")
                              ? suffix.toLatin1() : QByteArray("jpg");

    QImageWriter writer(path, format.constData());
    writer.setQuality(kMirrorJpegQuality);
    if (!writer.write(mirrored)) {
        qWarning() << "CameraController: Mirror save failed; keeping original" << path
                   << "| imageSize:" << mirrored.size()
                   << "| beforeBytes:" << beforeBytes
                   << "| error:" << writer.errorString();
        return false;
    }

    qDebug() << "CameraController: Mirror applied to" << path
             << "| imageSize:" << mirrored.size()
             << "| quality:" << kMirrorJpegQuality
             << "| beforeBytes:" << beforeBytes
             << "| afterBytes:" << QFileInfo(path).size();
    return true;
}

// -----------------------------------------------------------------------------
// Nguồn chụp Hot Folder
// -----------------------------------------------------------------------------

QString CameraController::cameraModel() const
{
    if (isHotFolderSource()) {
        return m_hotFolderKind == QLatin1String("fuji")
               ? QStringLiteral("Hot Folder · Fujifilm")
               : QStringLiteral("Hot Folder · Thư mục ảnh");
    }
    return m_cameraModel;
}

void CameraController::setCaptureSource(const QString &source)
{
    const bool wantHotFolder = source.trimmed().compare("hotfolder", Qt::CaseInsensitive) == 0;
    if (wantHotFolder == isHotFolderSource())
        return;

    if (wantHotFolder) {
        enterHotFolder();
    } else {
        leaveHotFolder();
        connectAsync();
    }
}

void CameraController::enterHotFolder()
{
    qWarning() << "CameraController: capture source -> Hot Folder (" << m_hotFolderKind << ")";

    m_captureSource = QStringLiteral("hotfolder");
    persistCameraSetting(QStringLiteral("capture_source"), m_captureSource);
    emit captureSourceChanged();

    // HotFolder.exe / phần mềm tether cần độc quyền USB → nhả phiên SDK.
    releaseSdkForHotFolder();

    // Không còn live view SDK → chuyển sang HDMI/Webcam, nhớ nguồn cũ để trả lại.
    QSettings qs;
    qs.setValue("liveview_source_before_hotfolder", m_useWebcamLiveView ? "webcam" : "sdk");
    if (!m_useWebcamLiveView)
        setUseWebcamLiveView(true);
    else if (m_selectedWebcamIndex >= 0 && !isLiveViewActive())
        startWebcamLiveView(m_selectedWebcamIndex);

    startHotFolder();
    emit cameraModelChanged();
    emit isConnectedChanged();
}

void CameraController::leaveHotFolder()
{
    qWarning() << "CameraController: capture source -> SDK";

    stopHotFolder(m_hotFolderKind == QLatin1String("fuji"));

    m_captureSource = QStringLiteral("sdk");
    persistCameraSetting(QStringLiteral("capture_source"), m_captureSource);
    emit captureSourceChanged();

    restoreLiveViewSourceAfterHotFolder();
    refreshHotFolderState();
    emit cameraModelChanged();
    emit isConnectedChanged();
}

void CameraController::restoreLiveViewSourceAfterHotFolder()
{
    QSettings qs;
    const bool wantSdk = qs.value("liveview_source_before_hotfolder", "sdk").toString() == "sdk";
    if (!wantSdk || !m_useWebcamLiveView)
        return;

    // Không gọi setUseWebcamLiveView(false): nó startLiveView() SDK ngay khi máy
    // CHƯA kết nối → báo lỗi giả. connectAsync() thành công sẽ tự startLiveView().
    stopWebcamLiveView();
    m_useWebcamLiveView = false;
    persistCameraSetting(QStringLiteral("liveview_source"), QStringLiteral("sdk"));
    emit useWebcamLiveViewChanged();
    emit isLiveViewActiveChanged();
}

void CameraController::releaseSdkForHotFolder()
{
    // Live view SDK chạm decode thread + Qt signals → dừng trên main thread.
    if (m_isLiveViewActive && !m_useWebcamLiveView)
        stopLiveView();

    // Ngắt máy trên m_camPool (cùng hàng đợi với connect/capture). Việc mở
    // HotFolder.exe cũng xếp vào pool này SAU lệnh ngắt → không tranh USB.
    (void)QtConcurrent::run(&m_camPool, [this]() {
        std::lock_guard<std::mutex> lock(m_sdkOperationMutex);
        auto& camera = CameraBackend::camera();
        if (!camera.isConnected())
            return;
        camera.setLiveViewFrameCallback({});
        camera.disconnectCamera();
        m_lastFrameMs.store(0);
        qWarning() << "CameraController: SDK camera released for Hot Folder";
        QMetaObject::invokeMethod(this, [this]() {
            m_isConnected = false;
            emit isConnectedChanged();
        }, Qt::QueuedConnection);
    });
}

void CameraController::startHotFolder()
{
    if (!isHotFolderSource())
        return;

    m_fujiLaunchFailed = false;
    if (m_hotFolderKind == QLatin1String("fuji")) {
        m_fujiHotFolder->startMonitoring();
        setHotFolderPathInternal(m_fujiHotFolder->folder());

        if (!FujiHotFolderProcess::isRunning()) {
            if (FujiHotFolderProcess::locateExe().isEmpty()) {
                m_fujiLaunchFailed = true;
            } else {
                m_fujiStarting = true;
                (void)QtConcurrent::run(&m_camPool, [this]() {
                    const bool ok = m_fujiHotFolder->launch();
                    QMetaObject::invokeMethod(this, [this, ok]() {
                        if (!ok) {
                            m_fujiStarting = false;
                            m_fujiLaunchFailed = true;
                        }
                        refreshHotFolderState();
                    }, Qt::QueuedConnection);
                });
                // App Fuji hiện splash ~2.5s rồi mới tạo mutex; quá 20s vẫn chưa thấy → báo đã tắt.
                QTimer::singleShot(20000, this, [this]() {
                    if (!m_fujiStarting)
                        return;
                    m_fujiStarting = false;
                    refreshHotFolderState();
                });
            }
        }
    } else {
        m_fujiHotFolder->stopMonitoring();
        m_fujiStarting = false;
        setHotFolderPathInternal(m_hotFolderFolder);
    }

    if (!m_hotFolderPath.isEmpty())
        m_hotFolderWatcher->start(m_hotFolderPath);
    else
        m_hotFolderWatcher->stop();
    refreshHotFolderState();
}

void CameraController::stopHotFolder(bool closeFujiApp)
{
    m_hotFolderWatcher->setArmed(false);
    m_hotFolderWatcher->stop();
    m_fujiHotFolder->stopMonitoring();
    m_fujiStarting = false;
    m_fujiLaunchFailed = false;

    if (closeFujiApp) {
        // Chờ app Fuji tự XSDK_Close (≤ 4s) trên m_camPool → lần connect SDK xếp
        // sau trong pool chỉ chạy khi máy ảnh đã được nhả, UI không bị treo.
        (void)QtConcurrent::run(&m_camPool, []() {
            FujiHotFolderProcess::shutdown();
        });
    }
}

void CameraController::setHotFolderKind(const QString &kind)
{
    const QString k = kind.trimmed().compare("fuji", Qt::CaseInsensitive) == 0
                      ? QStringLiteral("fuji") : QStringLiteral("folder");
    if (k == m_hotFolderKind)
        return;

    const bool wasFuji = m_hotFolderKind == QLatin1String("fuji");
    if (isHotFolderSource())
        stopHotFolder(wasFuji);

    m_hotFolderKind = k;
    persistCameraSetting(QStringLiteral("hotfolder_kind"), m_hotFolderKind);
    emit hotFolderKindChanged();
    emit cameraModelChanged();

    startHotFolder();
}

void CameraController::setHotFolderFolder(const QString &path)
{
    QString local = path.trimmed();
    if (local.startsWith("file:", Qt::CaseInsensitive))
        local = QUrl(local).toLocalFile();
    local = local.isEmpty() ? QString() : QDir::toNativeSeparators(QDir::cleanPath(local));
    if (local == m_hotFolderFolder)
        return;

    m_hotFolderFolder = local;
    persistCameraSetting(QStringLiteral("hotfolder_folder_path"), m_hotFolderFolder);
    qDebug() << "CameraController: hot folder path set to" << m_hotFolderFolder;

    if (isHotFolderSource() && m_hotFolderKind == QLatin1String("folder"))
        startHotFolder();
    else if (m_hotFolderKind == QLatin1String("folder"))
        setHotFolderPathInternal(m_hotFolderFolder);
}

void CameraController::relaunchFujiHotFolder()
{
    if (!isHotFolderSource() || m_hotFolderKind != QLatin1String("fuji"))
        return;
    startHotFolder();
}

void CameraController::setHotFolderArmed(bool armed)
{
    m_hotFolderWatcher->setArmed(armed && isHotFolderSource());
}

void CameraController::setHotFolderPathInternal(const QString &path)
{
    if (path == m_hotFolderPath)
        return;
    m_hotFolderPath = path;
    emit hotFolderPathChanged();

    // Fuji đổi thư mục giữa chừng → theo dõi thư mục mới.
    if (isHotFolderSource() && m_hotFolderWatcher->folder() != QDir::cleanPath(path)
            && !path.isEmpty())
        m_hotFolderWatcher->start(path);
    refreshHotFolderState();
}

void CameraController::refreshHotFolderState()
{
    QString state = QStringLiteral("idle");
    bool ready = false;

    if (isHotFolderSource()) {
        const bool watching = m_hotFolderWatcher->isWatching();
        if (m_hotFolderKind == QLatin1String("fuji")) {
            if (m_fujiLaunchFailed)
                state = QStringLiteral("fuji_exe_missing");
            else if (!m_fujiHotFolder->running())
                state = m_fujiStarting ? QStringLiteral("fuji_starting") : QStringLiteral("fuji_stopped");
            else if (!watching)
                state = QStringLiteral("folder_missing");
            else
                state = QStringLiteral("watching");
        } else {
            if (m_hotFolderPath.isEmpty())
                state = QStringLiteral("folder_unset");
            else if (!watching)
                state = QStringLiteral("folder_missing");
            else
                state = QStringLiteral("watching");
        }
        ready = state == QLatin1String("watching");
    }

    if (state != m_hotFolderState) {
        m_hotFolderState = state;
        qDebug() << "CameraController: hot folder state =" << state << "|" << m_hotFolderPath;
        emit hotFolderStateChanged();
    }
    if (ready != m_hotFolderReady) {
        m_hotFolderReady = ready;
        emit isConnectedChanged();
    }
}

bool CameraController::hotFolderBusy() const
{
    if (!isHotFolderSource())
        return false;
    return m_hotFolderImporting > 0 || (m_hotFolderWatcher && m_hotFolderWatcher->hasPendingFiles());
}

void CameraController::onHotFolderFileReady(const QString &path)
{
    if (!isHotFolderSource() || !m_hotFolderWatcher->isArmed())
        return;
    if (m_sessionPath.isEmpty()) {
        qWarning() << "CameraController: hot folder photo ignored - no session folder yet" << path;
        return;
    }

    const QFileInfo src(path);
    const QString ext = src.suffix().toLower();
    // Cấp tên trên main thread (bộ đếm dùng chung với luồng SDK); di chuyển + lật
    // trên m_hotFolderPool một luồng → ảnh vào phiên đúng thứ tự chụp.
    const QString dest = nextSessionPhotoPath(m_sessionPath, ext, src.fileName());
    const bool mirror = m_mirrorMode;
    ++m_hotFolderImporting;

    (void)QtConcurrent::run(&m_hotFolderPool, [this, path, dest, mirror]() {
        QDir().mkpath(QFileInfo(dest).absolutePath());

        bool moved = QFile::rename(path, dest);
        if (!moved && !QFile::exists(dest) && QFile::copy(path, dest)) {
            moved = true;
            if (!QFile::remove(path))
                qWarning() << "CameraController: hot folder copy OK but source not removed" << path;
        }
        if (!moved) {
            qWarning() << "CameraController: failed to move hot folder photo" << path << "->" << dest;
            QMetaObject::invokeMethod(this, [this, path]() {
                m_hotFolderImporting = qMax(0, m_hotFolderImporting - 1);
                emit error("Không chuyển được ảnh từ Hot Folder: " + path);
            }, Qt::QueuedConnection);
            return;
        }

        if (mirror)
            mirrorJpegInPlace(dest);

        qDebug() << "CameraController: hot folder photo ->" << dest << "| mirror:" << mirror;
        QMetaObject::invokeMethod(this, [this, dest]() {
            m_hotFolderImporting = qMax(0, m_hotFolderImporting - 1);
            emit imageCaptured(dest);
            emit statusMessage("✓ Photo saved: " + dest);
        }, Qt::QueuedConnection);
    });
}
