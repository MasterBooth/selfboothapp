#ifndef CAMERACONTROLLER_H
#define CAMERACONTROLLER_H

#include <QObject>
#include <QDir>
#include <QUrl>
#include <QMutex>
#include <QElapsedTimer>
#include <QAtomicInt>
#include <QImage>
#include <QThreadPool>
#include <QMap>
#include <memory>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <vector>
#include <atomic>
#include <deque>
#include <QString>
#include <QByteArray>
#include "CameraBackend.h"

// Forward declarations
class LiveViewImageProvider;
class CameraEventBridge;
class WebcamLiveView;
class HotFolderWatcher;
class FujiHotFolderProcess;
class FujiTetherAppProcess;
class EventManager;
class QSettings;

/**
 * @brief High-level camera controller using CameraApp API
 *
 * Qt wrapper around CameraApp::CameraController that provides signals for QML
 * Bridges CameraApp events to Qt signals for seamless QML integration
 */
class CameraController : public QObject
{
    Q_OBJECT
    friend class CameraEventBridge;

    Q_PROPERTY(bool isConnected READ isConnected NOTIFY isConnectedChanged)
    Q_PROPERTY(bool isLiveViewActive READ isLiveViewActive NOTIFY isLiveViewActiveChanged)
    Q_PROPERTY(QString cameraModel READ cameraModel NOTIFY cameraModelChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool mockCaptureEnabled READ mockCaptureEnabled CONSTANT)

    // === CAMERA SOURCE / TYPE ("Canon", "Sony", "Nikon", or "Fuji") ===
    Q_PROPERTY(QString cameraType READ cameraType WRITE setCameraType NOTIFY cameraTypeChanged)

    // === CONNECTION STATE ===
    Q_PROPERTY(bool isConnecting READ isConnecting NOTIFY isConnectingChanged)

    // === CAPTURE SOURCE ("sdk" = điều khiển máy qua SDK, "hotfolder" = nhận ảnh từ thư mục) ===
    Q_PROPERTY(QString captureSource READ captureSource NOTIFY captureSourceChanged)
    Q_PROPERTY(QString hotFolderKind READ hotFolderKind NOTIFY hotFolderKindChanged)       // "folder" | "fuji" | "tether"
    Q_PROPERTY(QString hotFolderPath READ hotFolderPath NOTIFY hotFolderPathChanged)
    // idle · watching · folder_missing · folder_unset · fuji_exe_missing · fuji_starting · fuji_stopped
    // · tether_exe_missing · tether_starting · tether_stopped
    Q_PROPERTY(QString hotFolderState READ hotFolderState NOTIFY hotFolderStateChanged)
    // Đường dẫn FUJIFILM_TetherApp.exe sẽ dùng (rỗng = không tìm thấy).
    Q_PROPERTY(QString tetherAppExePath READ tetherAppExePath NOTIFY tetherAppExePathChanged)

    // === Live View Properties ===
    Q_PROPERTY(QUrl liveViewSource READ liveViewSource NOTIFY liveViewSourceChanged)
    Q_PROPERTY(int liveViewFps READ liveViewFps NOTIFY liveViewFpsChanged)

    // === WEBCAM LIVE VIEW ===
    Q_PROPERTY(bool useWebcamLiveView READ useWebcamLiveView NOTIFY useWebcamLiveViewChanged)
    Q_PROPERTY(QStringList webcamList READ webcamList NOTIFY webcamListChanged)
    Q_PROPERTY(int selectedWebcamIndex READ selectedWebcamIndex NOTIFY selectedWebcamIndexChanged)
    Q_PROPERTY(bool webcamScanning READ webcamScanning NOTIFY webcamScanningChanged)

    // === MIRROR MODE ===
    Q_PROPERTY(bool mirrorMode READ mirrorMode WRITE setMirrorMode NOTIFY mirrorModeChanged)

    // === AF MODE ===
    Q_PROPERTY(bool afEnabled READ afEnabled WRITE setAfEnabled NOTIFY afEnabledChanged)

    // === PHASE 2 PERFORMANCE MONITORING ===
    Q_PROPERTY(int frameDropCount READ frameDropCount NOTIFY frameDropCountChanged)
    Q_PROPERTY(int bufferHealth READ bufferHealth NOTIFY bufferHealthChanged)

    // Camera Parameters
    Q_PROPERTY(QString iso READ iso WRITE setIso NOTIFY currentIsoChanged)
    Q_PROPERTY(QStringList isoList READ isoList NOTIFY isoListChanged)
    Q_PROPERTY(QString aperture READ aperture WRITE setAperture NOTIFY currentApertureChanged)
    Q_PROPERTY(QStringList apertureList READ apertureList NOTIFY apertureListChanged)
    Q_PROPERTY(QString shutterSpeed READ shutterSpeed WRITE setShutterSpeed NOTIFY currentShutterSpeedChanged)
    Q_PROPERTY(QStringList shutterSpeedList READ shutterSpeedList NOTIFY shutterSpeedListChanged)
    Q_PROPERTY(QString whiteBalance READ whiteBalance WRITE setWhiteBalance NOTIFY currentWhiteBalanceChanged)
    Q_PROPERTY(QStringList whiteBalanceList READ whiteBalanceList NOTIFY whiteBalanceListChanged)
    Q_PROPERTY(QString exposureCompensation READ exposureCompensation WRITE setExposureCompensation NOTIFY currentExposureCompensationChanged)
    Q_PROPERTY(QStringList exposureCompensationList READ exposureCompensationList NOTIFY exposureCompensationListChanged)
    Q_PROPERTY(QString colorTemperature READ colorTemperature WRITE setColorTemperature NOTIFY currentColorTemperatureChanged)
    Q_PROPERTY(QStringList colorTemperatureList READ colorTemperatureList NOTIFY colorTemperatureListChanged)

public:
    explicit CameraController(QObject *parent = nullptr);
    ~CameraController();
    void setEventManager(EventManager *eventManager);

    // Properties
    // Hot Folder: "connected" = đang theo dõi được thư mục (Fuji: HotFolder.exe cũng đang chạy),
    // để các overlay "mất kết nối máy ảnh" trong QML không bật nhầm.
    bool isConnected() const { return isHotFolderSource() ? m_hotFolderReady : m_isConnected; }
    bool isLiveViewActive() const;
    QString cameraModel() const;
    QString lastError() const { return m_lastError; }
    bool mockCaptureEnabled() const { return m_mockCaptureEnabled; }
    Q_INVOKABLE void setMockCaptureEnabled(bool enabled) { m_mockCaptureEnabled = enabled; }

    // === CONNECTION STATE ===
    bool isConnecting() const { return m_isConnecting.load(); }

    // === CAMERA SOURCE / TYPE ===
    QString cameraType() const { return m_cameraType; }
    Q_INVOKABLE void setCameraType(const QString &type);
    Q_INVOKABLE void switchCameraType(const QString &type);

    // === CAPTURE SOURCE / HOT FOLDER ===
    QString captureSource() const { return m_captureSource; }
    QString hotFolderKind() const { return m_hotFolderKind; }
    QString hotFolderPath() const { return m_hotFolderPath; }
    QString hotFolderState() const { return m_hotFolderState; }
    bool isHotFolderSource() const { return m_captureSource == QLatin1String("hotfolder"); }
    // "hotfolder": ngắt SDK, live view sang HDMI/Webcam, bắt đầu theo dõi thư mục.
    // "sdk": dừng theo dõi, tắt HotFolder.exe, trả live view cũ rồi kết nối lại SDK.
    Q_INVOKABLE void setCaptureSource(const QString &source);
    Q_INVOKABLE void setHotFolderKind(const QString &kind);
    // Thư mục cho kiểu "folder" (nhận cả URL file:///).
    Q_INVOKABLE void setHotFolderFolder(const QString &path);
    // Mở lại app nhận ảnh của kiểu hiện tại (HotFolder.exe hoặc Tether App).
    Q_INVOKABLE void relaunchFujiHotFolder();
    QString tetherAppExePath() const;
    // Người dùng chọn exe Tether App (nhận cả URL file:///); rỗng = tự tìm.
    Q_INVOKABLE void setTetherAppExePath(const QString &path);
    // CaptureScreen bật khi bắt đầu chụp, tắt khi xong — chỉ nhận ảnh trong lúc này.
    Q_INVOKABLE void setHotFolderArmed(bool armed);
    // Hot folder còn ảnh đang về: file đang được ghi dở, hoặc đã ghi xong nhưng còn
    // đang chuyển/lật vào thư mục phiên (chưa phát imageCaptured).
    Q_INVOKABLE bool hotFolderBusy() const;

    // Non-blocking connect for QML: runs detecti on + connect on a background
    // thread so the UI event loop never stalls during camera enumeration.
    // Emits isConnectingChanged(true) immediately, then emits
    // isConnectingChanged(false) + connectFinished(success) when done.
    Q_INVOKABLE void connectAsync();

    // === Live View Properties ===
    QUrl liveViewSource() const { return m_liveViewSource; }
    int liveViewFps() const { return m_currentFps; }

    // === PHASE 2 Performance Monitoring ===
    int frameDropCount() const { return m_frameDropCount; }
    int bufferHealth() const { return m_bufferHealth; }  // 0-100 scale (100 = healthy)

    // === WEBCAM LIVE VIEW ===
    bool useWebcamLiveView() const { return m_useWebcamLiveView; }
    QStringList webcamList() const { return m_webcamList; }
    // Index DirectShow của thiết bị đang chọn (KHÔNG phải vị trí trong webcamList).
    int selectedWebcamIndex() const { return m_selectedWebcamIndex; }
    bool webcamScanning() const { return m_webcamScanning; }
    // Quét ở luồng nền (mở thử từng thiết bị mất vài giây) → không treo UI.
    // Kết quả qua webcamListChanged + webcamScanFinished.
    Q_INVOKABLE void scanWebcams();
    // webcamList chỉ chứa thiết bị đọc được → vị trí trong list ≠ index thiết bị.
    Q_INVOKABLE int webcamDeviceAt(int listIndex) const;
    Q_INVOKABLE int webcamListIndexOf(int deviceIndex) const;
    Q_INVOKABLE bool startWebcamLiveView(int deviceIndex);
    Q_INVOKABLE void stopWebcamLiveView();
    Q_INVOKABLE void setUseWebcamLiveView(bool use);

    // === MIRROR MODE ===
    bool mirrorMode() const { return m_mirrorMode; }
    Q_INVOKABLE void setMirrorMode(bool enabled);

    // === AF MODE ===
    bool afEnabled() const { return m_afEnabled; }
    Q_INVOKABLE void setAfEnabled(bool enabled);

    // === WATCHDOG for Auto Reconnect ===
    bool isWatchdogEnabled() const { return m_watchdogEnabled; }
    void setWatchdogEnabled(bool enabled);

    // Camera Parameter Accessors
    QString iso() const { return m_iso; }
    QStringList isoList() const { return m_isoList; }
    QString aperture() const { return m_aperture; }
    QStringList apertureList() const { return m_apertureList; }
    QString shutterSpeed() const { return m_shutterSpeed; }
    QStringList shutterSpeedList() const { return m_shutterSpeedList; }
    QString whiteBalance() const { return m_whiteBalance; }
    QStringList whiteBalanceList() const { return m_whiteBalanceList; }
    QString exposureCompensation() const { return m_exposureCompensation; }
    QStringList exposureCompensationList() const { return m_exposureCompensationList; }
    QString colorTemperature() const { return m_colorTemperature; }
    QStringList colorTemperatureList() const { return m_colorTemperatureList; }

    // Set image provider for live view
    void setImageProvider(LiveViewImageProvider *provider);

    // Live view performance settings (thread-safe, apply immediately without restart)
    Q_INVOKABLE void setMaxLiveViewWidth(int width);   // 0 = no limit
    Q_INVOKABLE void setTargetLiveViewFps(int fps);    // 0 = no limit (use camera rate)
    Q_INVOKABLE void setFujiLiveViewOptions(const QString &size, const QString &quality);

    // ── Live-view viewer counting ─────────────────────────────────────────────
    // Mỗi màn hình QML đang HIỂN THỊ live view gọi addLiveViewViewer() khi xuất
    // hiện và removeLiveViewViewer() khi ẩn/đóng. Khi không còn viewer nào, decode
    // thread BỎ QUA bước giải mã JPEG + scale + mirror (vốn tốn ~15-30% CPU liên
    // tục) — camera vẫn streaming nên khi quay lại không có độ trễ khởi động.
    Q_INVOKABLE void addLiveViewViewer();
    Q_INVOKABLE void removeLiveViewViewer();

    // ── Slot recording (process video) ───────────────────────────────────────
    // Ghi lại các frame live-view trong cửa sổ đếm-ngược→chụp của TỪNG ảnh để
    // sau đó dựng "process video" (mỗi slot phát lại quá trình tạo dáng).
    //   startSlotRecording: bật ghi cho slot <slotIndex>; frame lưu vào
    //     <sessionDir>/slot_<slotIndex>/frame_NNNNN.jpg kèm manifest.txt
    //     (mỗi dòng: "<file> <ms-tương-đối-từ-lúc-start>").
    //   stopSlotRecording: tắt ghi (writer thread tự ghi nốt hàng đợi còn lại).
    Q_INVOKABLE void startSlotRecording(int slotIndex, const QString &sessionDir);
    Q_INVOKABLE void stopSlotRecording();

    // Camera control methods
    Q_INVOKABLE bool connectToServer();
    Q_INVOKABLE bool startLiveView();
    Q_INVOKABLE bool stopLiveView();
    Q_INVOKABLE bool takePicture();
    Q_INVOKABLE bool takePictureNoAF();
    Q_INVOKABLE void setRemoteShutterMode(bool on);
    // Same as setRemoteShutterMode but runs on the camera worker pool so the UI
    // thread never waits on the SDK mutex (serialized with capture commands).
    Q_INVOKABLE void setRemoteShutterModeAsync(bool on);

    // Session management
    Q_INVOKABLE void setSessionStoragePath(const QString &path);
    // Set the current session ID so captured photos are named after the session
    // (avoids overwriting photos from previous sessions after a power outage)
    Q_INVOKABLE void setCurrentSessionId(const QString &sessionId);
    
    // Camera property control
    Q_INVOKABLE bool setIso(const QString &iso);
    Q_INVOKABLE bool setAperture(const QString &aperture);
    Q_INVOKABLE bool setShutterSpeed(const QString &speed);
    Q_INVOKABLE bool setWhiteBalance(const QString &wb);
    Q_INVOKABLE bool setCompressionSetting(const QString &quality);
    Q_INVOKABLE bool setExposureCompensation(const QString &ev);
    Q_INVOKABLE bool setColorTemperature(const QString &kelvin);
    Q_INVOKABLE bool setCameraParameter(const QString &param, const QString &value);
    
    // Get current camera property values
    Q_INVOKABLE bool getCurrentIso();
    Q_INVOKABLE bool getCurrentAperture();
    Q_INVOKABLE bool getCurrentShutterSpeed();
    Q_INVOKABLE bool getCurrentWhiteBalance();
    Q_INVOKABLE bool getCurrentCompressionSetting();
    Q_INVOKABLE bool getCurrentExposureCompensation();
    Q_INVOKABLE bool getCurrentColorTemperature();
    Q_INVOKABLE bool getAllCameraProperties();

    // Populate property lists from camera (ISO/Tv/Av/WB/EV lists + current values)
    Q_INVOKABLE bool fetchCameraPropertyLists();

    // ── HttpBridge support ────────────────────────────────────────────────────
    // Trả về frame live-view mới nhất dưới dạng JPEG bytes (cho HTTP /api/camera/frame).
    // Trả về mảng rỗng nếu chưa có frame.
    QByteArray latestFrameAsJpeg() const;

signals:
    void isConnectedChanged();
    void isLiveViewActiveChanged();
    void cameraModelChanged();
    void lastErrorChanged();
    void cameraTypeChanged();
    void isConnectingChanged();
    void captureSourceChanged();
    void hotFolderKindChanged();
    void hotFolderPathChanged();
    void hotFolderStateChanged();
    void tetherAppExePathChanged();
    // Emitted when connectAsync() finishes: success=true means camera opened OK.
    void connectFinished(bool success);

    // Live View
    void liveViewSourceChanged();
    void liveViewFpsChanged();
    void frameReady(QImage frame);
    void newFrameAvailable();

    // Performance Monitoring
    void frameDropCountChanged();
    void bufferHealthChanged();

    // Webcam Live View
    void useWebcamLiveViewChanged();
    void webcamListChanged();
    void selectedWebcamIndexChanged();
    void webcamScanningChanged();
    void webcamScanFinished(int count);

    // Mirror Mode
    void mirrorModeChanged(bool enabled);

    // AF Mode
    void afEnabledChanged(bool enabled);

    // Camera Events
    void error(const QString &message);
    void captureCompleted();
    void imageCaptured(const QString &path);
    // Hot Folder + mirror: bản nhỏ đã lật (chỉ để hiển thị) có trước khi ảnh gốc
    // lật xong. imageCaptured(path) cùng path vẫn đến sau như thường.
    void hotFolderPhotoPreview(const QString &path, const QString &previewPath);
    void statusMessage(const QString &message);

    // Camera property signals
    void currentIsoChanged(const QString &iso);
    void currentApertureChanged(const QString &aperture);
    void currentShutterSpeedChanged(const QString &speed);
    void isoListChanged(const QStringList &list);
    void apertureListChanged(const QStringList &list);
    void shutterSpeedListChanged(const QStringList &list);
    void currentWhiteBalanceChanged(const QString &wb);
    void whiteBalanceListChanged(const QStringList &list);
    void currentExposureCompensationChanged(const QString &ev);
    void exposureCompensationListChanged(const QStringList &list);
    void currentColorTemperatureChanged(const QString &kelvin);
    void colorTemperatureListChanged(const QStringList &list);
    void currentCompressionSettingChanged(const QString &quality);

private slots:
    void onWatchdogTimeout();

private:
    // Helper methods for CameraEventBridge
    void setConnectionStatus(bool connected) { m_isConnected = connected; }
    void setLiveViewActiveInternal(bool active) { m_isLiveViewActive = active; }
    void setCurrentISO(const QString& iso) { m_iso = iso; }
    void setCurrentAperture(const QString& aperture) { m_aperture = aperture; }
    void setCurrentShutterSpeed(const QString& speed) { m_shutterSpeed = speed; }
    void setCurrentWhiteBalance(const QString& wb) { m_whiteBalance = wb; }
    QString getCurrentISO() const { return m_iso; }
    QString getCurrentAperture() const { return m_aperture; }
    QString getCurrentShutterSpeed() const { return m_shutterSpeed; }
    QString getCurrentWhiteBalance() const { return m_whiteBalance; }
    bool isMirrorModeEnabled() const { return m_mirrorMode; }

    // CameraApp API and event bridge
    std::unique_ptr<CameraEventBridge> m_eventBridge;
    LiveViewImageProvider *m_imageProvider;
    EventManager *m_eventManager = nullptr;

    void loadPersistedCameraSettings();
    void persistCameraSetting(const QString &key, const QString &value);
    QString loadCameraSetting(QSettings &settings,
                              const QString &key,
                              const QString &legacyValue);

    bool connectToServerForType(const QString& cameraType);

    // ── Hậu xử lý ảnh chụp (dùng chung SDK + Hot Folder) ─────────────────────
    // Cấp đường dẫn <dir>/<sessionId>_photo_NNN.<ext> (tăng m_sessionPhotoCounter).
    // Không có sessionId → giữ tên gốc (fallbackName), tránh trùng bằng hậu tố thời gian.
    QString nextSessionPhotoPath(const QString &dir, const QString &ext,
                                 const QString &fallbackName);
    // Lật ngang JPEG tại chỗ (quality 100). Áp EXIF Orientation trước khi lật vì
    // QImageWriter không ghi lại EXIF — ảnh dọc vẫn đúng chiều.
    static bool mirrorJpegInPlace(const QString &path);

    // ── Hot Folder ───────────────────────────────────────────────────────────
    void enterHotFolder();
    void leaveHotFolder();                 // về "sdk", KHÔNG tự kết nối (người gọi quyết)
    void startHotFolder();                 // mở app Fuji (nếu cần) + theo dõi thư mục
    // Dừng theo dõi; closeApp = tắt app nhận ảnh của kiểu HIỆN TẠI (HotFolder.exe / Tether App).
    void stopHotFolder(bool closeApp);
    void releaseSdkForHotFolder();         // dừng live view SDK + ngắt máy trên m_camPool
    void restoreLiveViewSourceAfterHotFolder();
    void refreshHotFolderState();
    void setHotFolderPathInternal(const QString &path);
    void onHotFolderFileReady(const QString &path);
    HotFolderWatcher     *m_hotFolderWatcher = nullptr;
    FujiHotFolderProcess *m_fujiHotFolder = nullptr;
    FujiTetherAppProcess *m_tetherApp = nullptr;
    QString m_tetherAppExe;               // exe người dùng chọn (rỗng = tự tìm)
    bool    m_tetherStarting = false;     // đang đóng app cũ / ghi registry / mở Tether App
    bool    m_tetherLaunchFailed = false;
    QString m_captureSource = "sdk";
    QString m_hotFolderKind = "folder";
    QString m_hotFolderFolder;            // thư mục người dùng chọn (kiểu "folder")
    QString m_hotFolderPath;              // thư mục đang theo dõi thực tế
    QString m_hotFolderState = "idle";
    bool    m_hotFolderReady = false;
    bool    m_fujiLaunchFailed = false;
    bool    m_fujiStarting = false;       // đã mở exe, chờ app Fuji qua màn splash
    // Di chuyển + lật ảnh hot folder song song (2 luồng); imageCaptured vẫn phát
    // đúng thứ tự chụp nhờ số thứ tự — xem finishHotFolderImport().
    QThreadPool m_hotFolderPool;
    // Ảnh hot folder đã nhận nhưng chưa phát imageCaptured (chỉ đụng trên main thread).
    int m_hotFolderImporting = 0;
    struct HotFolderResult {
        QString dest;            // rỗng = chuyển ảnh thất bại
        QString failedSource;
    };
    quint64 m_hotFolderNextSeq = 0;   // số thứ tự cấp cho ảnh mới
    quint64 m_hotFolderEmitSeq = 0;   // ảnh kế tiếp được phát imageCaptured
    QMap<quint64, HotFolderResult> m_hotFolderDone;
    void finishHotFolderImport(quint64 seq, const QString &dest, const QString &failedSource);
    // Bản xem trước cũng phát theo thứ tự chụp; ảnh đã phát imageCaptured thì bỏ qua.
    quint64 m_hotFolderPreviewSeq = 0;
    QMap<quint64, QPair<QString, QString>> m_hotFolderPreviewsReady;   // seq → (dest, preview)
    void flushHotFolderPreviews();
    // <thư mục ảnh>/.display/<tên>_live.jpg — cạnh dài ~1600px, chất lượng 90.
    static QString writeLivePreview(const QString &photoPath, bool mirror);
    void finishConnectAttempt(const QString& requestedType, bool ok);
    void stopSdkLiveViewForReconnect(ICameraSDK& camera);
    void adoptConnectedCameraType(const QString& actualType, const QString& requestedType);

    // Webcam Live View
    // Tạo m_webcamLiveView (nếu chưa có), gắn image provider, đẩy cài đặt hiện
    // tại xuống và nối signal frameReady — gọi trước khi scan/start webcam.
    void ensureWebcamLiveView();
    std::unique_ptr<WebcamLiveView> m_webcamLiveView;
    bool        m_useWebcamLiveView    = false;
    QStringList m_webcamList;
    QList<int>  m_webcamDevices;               // song song với m_webcamList
    int         m_selectedWebcamIndex  = -1;
    bool        m_webcamScanning       = false;
    // Thiết bị cần chạy lại sau khi quét xong (-1 = không).
    int         m_webcamResumeIndex    = -1;

    // Connection state
    bool m_isConnected = false;
    bool m_isLiveViewActive = false;
    QString m_cameraModel;
    QString m_lastError;
    QString m_cameraType = "Canon";   // "Canon" (default), "Sony", "Nikon", or "Fuji"
    std::atomic<bool> m_isConnecting{false};
    std::atomic<bool> m_pendingConnectRequest{false};
    std::mutex m_sdkOperationMutex;

    // Live View State
    QUrl m_liveViewSource;
    int m_frameVersion = 0;
    int m_currentFps = 0;
    int m_frameCount = 0;
    QElapsedTimer m_fpsTimer;
    QMutex m_versionMutex;

    // Performance Monitoring
    int m_frameDropCount = 0;
    int m_bufferHealth = 100;
    int m_expectedFps = 30;
    QElapsedTimer m_performanceTimer;

    // Camera Parameter Storage
    QString m_iso;
    QStringList m_isoList;
    QString m_aperture;
    QStringList m_apertureList;
    QString m_shutterSpeed;
    QStringList m_shutterSpeedList;
    QString m_whiteBalance;
    QStringList m_whiteBalanceList;
    QString m_exposureCompensation;
    QStringList m_exposureCompensationList;
    QString m_colorTemperature;
    QStringList m_colorTemperatureList;

    // Session Storage
    QString m_sessionPath;
    QString m_currentSessionId;      // e.g. "session_20240101_120000_AB12"
    int     m_sessionPhotoCounter = 0; // 1-based counter per session
    bool    m_mockCaptureEnabled = false;

    // Mirror Mode — mặc định BẬT (soi gương) ngay cả trước khi main.qml đồng bộ
    // giá trị đã lưu trong DB, để live view không bao giờ hiện chưa-mirror lúc mở app.
    bool m_mirrorMode = true;

    // AF Mode
    bool m_afEnabled = true;

    // Watchdog
    QTimer *m_watchdogTimer = nullptr;
    // Mốc thời gian (epoch ms) của live-view frame gần nhất. Ghi từ streaming
    // thread trong setLiveViewFrameCallback, đọc từ watchdog (main thread) →
    // dùng atomic để khỏi cần mutex. 0 = chưa có frame nào kể từ lúc start.
    std::atomic<qint64> m_lastFrameMs{0};
    bool m_watchdogEnabled = true;
    int m_watchdogTimeout = 5000;
    // Throttle log "No cameras found" của watchdog để không spam mỗi 5s khi
    // chưa cắm máy. Chỉ log lần đầu mỗi đợt mất kết nối.
    bool m_watchdogLoggedDisconnect = false;
    // Khi mất kết nối: thử kết nối lại ngay lần đầu, sau đó cách nhau
    // m_reconnectIntervalMs (mỗi lần thử có thể mất vài giây dò USB).
    qint64 m_lastReconnectAttemptMs = 0;
    int m_reconnectIntervalMs = 10000;

    // ── Keep-alive chủ động (Canon) ──────────────────────────────────────────
    // Watchdog (5s) gửi ExtendShutDownTimer mỗi m_keepAliveIntervalMs khi máy
    // đang kết nối & idle, để máy ảnh/USB không tự ngủ sau thời gian dài. Mốc
    // thời gian atomic vì ghi từ watchdog (main thread); fail-count chỉ đụng
    // trong lambda chạy trên m_camPool (đơn luồng) nên để int thường.
    std::atomic<qint64> m_lastKeepAliveMs{0};
    int m_keepAliveIntervalMs = 30000;   // 30s — an toàn dưới ngưỡng auto-off (~1 phút)
    int m_keepAliveFailCount  = 0;

    // -------------------------------------------------------------------------
    // Dedicated JPEG decode thread
    // -------------------------------------------------------------------------
    // The EDSDK streaming thread deposits raw JPEG bytes here and immediately
    // starts downloading the next frame.  The decode thread picks up the latest
    // JPEG, decodes it with Qt, and stores the result in the image provider.
    // This makes download and decode run in parallel, halving per-frame latency.
    void decodeLoop();
    void startDecodeThread();
    void stopDecodeThread();

    std::thread              m_decodeThread;
    std::atomic<bool>        m_decodeRunning{false};
    std::mutex               m_jpegMutex;
    std::condition_variable  m_jpegCondition;
    std::vector<uint8_t>     m_pendingJpeg;   // "latest wins" — overwritten each frame
    bool                     m_pendingMirror = false;
    bool                     m_hasNewJpeg    = false;

    // Cached live-view settings — written from main thread, read from decode thread.
    // Stored as atomics so the decode thread can read without a mutex.
    std::atomic<int>         m_maxLiveViewWidth{0};
    std::atomic<int>         m_targetLiveViewFps{30};
    QString                  m_fujiLiveViewSize = "auto";
    QString                  m_fujiLiveViewQuality = "fine";

    // Số màn hình QML đang hiển thị live view. decode thread đọc giá trị này;
    // khi == 0 thì bỏ qua giải mã frame để tiết kiệm CPU.
    std::atomic<int>         m_liveViewViewers{0};

    // -------------------------------------------------------------------------
    // Slot recording (process video) — writer thread RIÊNG để KHÔNG làm tụt fps
    // live view (cùng lý do tách decode thread). decode thread chỉ đẩy QImage
    // (implicit-share, rẻ) + path đã tính sẵn vào hàng đợi; writer encode JPEG +
    // ghi đĩa AV-safe + append manifest.
    // -------------------------------------------------------------------------
    void recordWriterLoop();
    void startRecordThread();
    void stopRecordThread();

    struct RecFrame {
        QImage     image;        // QImage implicit-share — copy O(1)
        QString    destPath;     // <slotDir>/frame_NNNNN.jpg
        QString    manifestPath; // <slotDir>/manifest.txt
        QByteArray line;         // "frame_NNNNN.jpg <ms>\n"
    };

    std::thread             m_recordThread;
    std::atomic<bool>       m_recordThreadRunning{false};
    std::atomic<bool>       m_recording{false};
    std::mutex              m_recordMutex;
    std::condition_variable m_recordCondition;
    std::deque<RecFrame>    m_recordQueue;
    QString                 m_recordDir;            // thư mục slot hiện tại (guarded by m_recordMutex)
    int                     m_recordFrameCounter = 0;
    qint64                  m_recordLastFrameMs = -1;
    std::atomic<int>        m_recordTargetFps{15};
    int                     m_recordMinFrameIntervalMs = 67; // ~15 FPS for process-video
    QElapsedTimer           m_recordTimer;          // timestamp tương đối từ lúc start slot

    // Frame Processing
    QAtomicInt m_isProcessingFrame{0};
    int m_skippedFrameCount = 0;

    // Pool RIÊNG cho kết nối camera + CHỤP ẢNH. Tách khỏi global QThreadPool
    // (nơi ffmpeg/in cũng chạy) để thao tác chụp KHÔNG BAO GIỜ bị xếp hàng
    // sau video/in dài → đảm bảo chụp luôn phản hồi khi vận hành 24/7.
    QThreadPool m_camPool;
};

#endif // CAMERACONTROLLER_H
