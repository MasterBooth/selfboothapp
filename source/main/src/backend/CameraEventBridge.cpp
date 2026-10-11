#include "CameraEventBridge.h"
#include "CameraController.h"
#include <QDebug>
#include <QImage>
#include <QImageWriter>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDateTime>
#include <QMetaObject>
#include <QtConcurrent/QtConcurrent>

CameraEventBridge::CameraEventBridge(CameraController* owner)
    : m_owner(owner)
{
    Q_ASSERT(m_owner != nullptr);
}

void CameraEventBridge::onCameraEvent(const CameraApp::CameraEvent& event)
{
    if (!m_owner) return;

    switch (event.type) {
    case CameraApp::CameraEventType::Connected:
        handleConnected(event);
        break;

    case CameraApp::CameraEventType::Disconnected:
        handleDisconnected(event);
        break;

    case CameraApp::CameraEventType::CaptureStarted:
        handleCaptureStarted(event);
        break;

    case CameraApp::CameraEventType::CaptureCompleted:
        handleCaptureCompleted(event);
        break;

    case CameraApp::CameraEventType::CaptureError:
        handleCaptureError(event);
        break;

    case CameraApp::CameraEventType::LiveViewStarted:
        handleLiveViewStarted(event);
        break;

    case CameraApp::CameraEventType::LiveViewStopped:
        handleLiveViewStopped(event);
        break;

    case CameraApp::CameraEventType::LiveViewFrameReceived:
        handleLiveViewFrameReceived(event);
        break;

    case CameraApp::CameraEventType::PropertyChanged:
        handlePropertyChanged(event);
        break;

    case CameraApp::CameraEventType::DownloadProgress:
        handleDownloadProgress(event);
        break;

    default:
        qWarning() << "CameraEventBridge: Unknown event type";
        break;
    }
}

void CameraEventBridge::handleConnected(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Camera connected -" << QString::fromStdString(event.message);
    m_owner->setConnectionStatus(true);
    m_owner->m_cameraModel = QString::fromStdString(
        CameraBackend::camera().getCameraModel());
    emit m_owner->isConnectedChanged();
    emit m_owner->cameraModelChanged();
    emit m_owner->statusMessage("✓ Connected: " + QString::fromStdString(event.message));
}

void CameraEventBridge::handleDisconnected(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Camera disconnected";
    m_owner->setConnectionStatus(false);
    emit m_owner->isConnectedChanged();
    emit m_owner->statusMessage("✗ Camera disconnected");
}

void CameraEventBridge::handleCaptureStarted(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Shutter fired — emitting captureCompleted early";
    // Fire captureCompleted the moment the shutter is confirmed (before USB download).
    // CaptureScreen.qml uses this to start the next countdown immediately, keeping
    // the capture thread and the save thread running in parallel on slow machines.
    emit m_owner->captureCompleted();
    emit m_owner->statusMessage("📸 Saving image...");
}

void CameraEventBridge::handleCaptureCompleted(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Capture completed -" << QString::fromStdString(event.fileName);
    // Timing breakdown (Nikon doCapture fills event.message with "shoot=Xms transfer=Yms").
    if (!event.message.empty())
        qWarning() << "[Capture] breakdown:" << QString::fromStdString(event.message)
                   << "— shoot = live-view dead window; transfer = USB download";

    QString photoPath = QString::fromStdString(event.fileName);

    // ── Rename file based on sessionId to avoid overwrite after power loss ───
    // Format: {sessionId}_photo_{NNN}.jpg (e.g. session_20240101_120000_AB12_photo_001.jpg)
    if (!m_owner->m_currentSessionId.isEmpty() && QFile::exists(photoPath)) {
        QFileInfo fi(photoPath);
        QString ext = fi.suffix().toLower();          // usually "jpg"
        if (ext.isEmpty()) ext = "jpg";

        const QString newPath = m_owner->nextSessionPhotoPath(fi.absolutePath(), ext, fi.fileName());
        if (QFile::rename(photoPath, newPath)) {
            qDebug() << "CameraEventBridge: Renamed" << photoPath << "->" << newPath;
            photoPath = newPath;
        } else {
            qWarning() << "CameraEventBridge: Failed to rename" << photoPath << "to" << newPath
                       << "- keeping original name";
        }
    }

    // Apply mirror mode if enabled (shared with the Hot Folder path).
    // Offload to a QtConcurrent thread; post imageCaptured back to the main thread
    // once done.  captureCompleted was already emitted early in handleCaptureStarted.
    if (m_owner->isMirrorModeEnabled()) {
        CameraController* owner = m_owner;
        QtConcurrent::run([owner, photoPath]() {
            CameraController::mirrorJpegInPlace(photoPath);
            QMetaObject::invokeMethod(owner, [owner, photoPath]() {
                emit owner->imageCaptured(photoPath);
                emit owner->statusMessage("✓ Photo saved: " + photoPath);
            }, Qt::QueuedConnection);
        });
        return;
    }

    // Non-mirror path: only imageCaptured here; captureCompleted already fired early.
    emit m_owner->imageCaptured(photoPath);
    emit m_owner->statusMessage("✓ Photo saved: " + photoPath);
}

void CameraEventBridge::handleCaptureError(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Capture error -" << QString::fromStdString(event.message);
    emit m_owner->error("Capture error: " + QString::fromStdString(event.message));
    emit m_owner->statusMessage("✗ Capture error: " + QString::fromStdString(event.message));
}

void CameraEventBridge::handleLiveViewStarted(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Live view started";
    m_owner->setLiveViewActiveInternal(true);
    emit m_owner->isLiveViewActiveChanged();
    emit m_owner->statusMessage("🎥 Live view started");
}

void CameraEventBridge::handleLiveViewStopped(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Live view stopped";
    m_owner->setLiveViewActiveInternal(false);
    emit m_owner->isLiveViewActiveChanged();
    emit m_owner->statusMessage("Live view stopped");
}

void CameraEventBridge::handleLiveViewFrameReceived(const CameraApp::CameraEvent& event)
{
    // Frame delivery is handled entirely by the setLiveViewFrameCallback path in
    // CameraController::connectToServer().  Emitting frameReady here would cause a
    // duplicate signal (and a second requestImage() call) for every frame, so we
    // intentionally do nothing in this event handler.
    Q_UNUSED(event);
}

// ── Code → label helpers (mirrors lookup tables in CameraApp/API/CameraController.cpp) ──
static QString isoCodeToQt(quint32 code) {
    static const struct { quint32 c; const char* l; } t[] = {
        {0x28,"6"},{0x30,"12"},{0x38,"25"},{0x40,"50"},
        {0x48,"100"}, {0x4b,"125"}, {0x4d,"160"},
        {0x50,"200"}, {0x53,"250"}, {0x55,"320"},
        {0x58,"400"}, {0x5b,"500"}, {0x5d,"640"},
        {0x60,"800"}, {0x63,"1000"},{0x65,"1250"},
        {0x68,"1600"},{0x6b,"2000"},{0x6d,"2500"},
        {0x70,"3200"},{0x73,"4000"},{0x75,"5000"},
        {0x78,"6400"},{0x7b,"8000"},{0x7d,"10000"},
        {0x80,"12800"},{0x83,"16000"},{0x85,"20000"},
        {0x88,"25600"},{0x8b,"32000"},{0x8d,"40000"},
        {0x90,"51200"},{0x93,"64000"},{0x95,"80000"},
        {0x98,"102400"},{0xa0,"204800"},{0xa8,"409600"},
    };
    for (auto& e : t) if (e.c == code) return e.l;
    return QString::number(code);
}
static QString tvCodeToQt(quint32 code) {
    // Must match kTvRev in CameraApp/API/CameraController.cpp
    // Canon EDSDK standard: higher code = faster shutter = less light
    static const struct { quint32 c; const char* l; } t[] = {
        {0x0C,"bulb"},{0x10,"30"},  {0x13,"25"},  {0x14,"20"},  {0x15,"20"},
        {0x18,"15"},  {0x1B,"13"},  {0x1C,"10"},  {0x1D,"10"},  {0x20,"8"},
        {0x23,"6"},   {0x24,"6"},   {0x25,"5"},   {0x28,"4"},   {0x2B,"3.2"},
        {0x2C,"3"},   {0x2D,"2.5"},{0x30,"2"},   {0x33,"1.6"}, {0x34,"1.5"},
        {0x35,"1.3"}, {0x38,"1"},   {0x3B,"0.8"},{0x3C,"0.7"}, {0x3D,"0.6"},
        {0x40,"0.5"}, {0x43,"0.4"},{0x44,"0.3"}, {0x45,"0.3"}, {0x48,"1/4"},
        {0x4B,"1/5"}, {0x4C,"1/6"},{0x4D,"1/6"}, {0x50,"1/8"}, {0x53,"1/10"},
        {0x54,"1/10"},{0x55,"1/13"},{0x58,"1/15"},{0x5B,"1/20"},{0x5C,"1/20"},
        {0x5D,"1/25"},{0x60,"1/30"},{0x63,"1/40"},{0x64,"1/45"},{0x65,"1/50"},
        {0x68,"1/60"},{0x6B,"1/80"},{0x6C,"1/90"},{0x6D,"1/100"},{0x70,"1/125"},
        {0x73,"1/160"},{0x74,"1/180"},{0x75,"1/200"},{0x78,"1/250"},{0x7B,"1/320"},
        {0x7C,"1/350"},{0x7D,"1/400"},{0x80,"1/500"},{0x83,"1/640"},{0x84,"1/750"},
        {0x85,"1/800"},{0x88,"1/1000"},{0x8B,"1/1250"},{0x8C,"1/1500"},{0x8D,"1/1600"},
        {0x90,"1/2000"},{0x93,"1/2500"},{0x94,"1/3000"},{0x95,"1/3200"},{0x98,"1/4000"},
        {0x9B,"1/5000"},{0x9C,"1/6000"},{0x9D,"1/6400"},{0xA0,"1/8000"},
    };
    for (auto& e : t) if (e.c == code) return e.l;
    return QString::number(code);
}
static QString avCodeToQt(quint32 code) {
    static const struct { quint32 c; const char* l; } t[] = {
        {0x08,"1"},{0x0B,"1.1"},{0x0C,"1.2"},{0x10,"1.4"},{0x13,"1.6"},
        {0x15,"1.8"},{0x18,"2"},{0x1B,"2.2"},{0x1D,"2.5"},{0x20,"2.8"},
        {0x23,"3.2"},{0x25,"3.5"},{0x28,"4"},{0x2B,"4.5"},{0x2D,"5"},
        {0x30,"5.6"},{0x33,"6.3"},{0x35,"7.1"},{0x38,"8"},{0x3B,"9"},
        {0x3D,"10"},{0x40,"11"},{0x43,"13"},{0x45,"14"},{0x48,"16"},
        {0x4B,"18"},{0x4D,"20"},{0x50,"22"},{0x53,"25"},{0x55,"29"},
        {0x58,"32"},{0x5B,"36"},{0x5D,"40"},{0x60,"45"},
    };
    for (auto& e : t) if (e.c == code) return e.l;
    return QString::number(code);
}
static QString wbCodeToQt(quint32 code) {
    static const struct { quint32 c; const char* l; } t[] = {
        {0,"Auto"},{1,"Daylight"},{2,"Shade"},{3,"Cloudy"},
        {4,"Tungsten"},{5,"Fluorescent"},{6,"Flash"},
        {8,"Custom"},{9,"Color Temp"},{15,"AWB White"},
    };
    for (auto& e : t) if (e.c == code) return e.l;
    return QString::number(code);
}
static QString evCodeToQt(qint32 code) {
    static const struct { qint32 c; const char* l; } t[] = {
        {24,"+3"},{21,"+2 2/3"},{19,"+2 1/3"},{16,"+2"},
        {13,"+1 2/3"},{11,"+1 1/3"},{8,"+1"},{5,"+2/3"},{3,"+1/3"},{0,"0"},
        {-3,"-1/3"},{-5,"-2/3"},{-8,"-1"},{-11,"-1 1/3"},
        {-13,"-1 2/3"},{-16,"-2"},{-19,"-2 1/3"},{-21,"-2 2/3"},{-24,"-3"},
    };
    for (auto& e : t) if (e.c == code) return e.l;
    return QString::number(code);
}

void CameraEventBridge::handlePropertyChanged(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Property changed -" << event.propertyId << "=" << event.propertyValue;

#if defined(USE_SONY_SDK) || defined(USE_DUAL_SDK)
    // Sony fires PropertyChanged with propertyId = 0 (generic event) or a raw
    // CrDevicePropertyCode that doesn't map to a Canon EdsPropertyID.
    // In both cases, refresh all property lists so QML stays in sync.
    if (event.propertyId == 0) {
        m_owner->fetchCameraPropertyLists();
        m_owner->getCurrentColorTemperature();
        return;
    }
    {
        bool isKnownCanonProp =
            (event.propertyId == kEdsPropID_ISOSpeed           ||
             event.propertyId == kEdsPropID_Tv                 ||
             event.propertyId == kEdsPropID_Av                 ||
             event.propertyId == kEdsPropID_WhiteBalance        ||
             event.propertyId == kEdsPropID_ColorTemperature    ||
             event.propertyId == kEdsPropID_ExposureCompensation);
        if (!isKnownCanonProp) {
            m_owner->fetchCameraPropertyLists();
            m_owner->getCurrentColorTemperature();
            return;
        }
    }
#endif

    // Convert raw EDSDK code → human-readable label
    switch (event.propertyId) {
    case kEdsPropID_ISOSpeed: {
        QString val = isoCodeToQt(event.propertyValue);
        m_owner->m_iso = val;
        emit m_owner->currentIsoChanged(val);
        break;
    }
    case kEdsPropID_Tv: {
        QString val = tvCodeToQt(event.propertyValue);
        m_owner->m_shutterSpeed = val;
        emit m_owner->currentShutterSpeedChanged(val);
        break;
    }
    case kEdsPropID_Av: {
        QString val = avCodeToQt(event.propertyValue);
        m_owner->m_aperture = val;
        emit m_owner->currentApertureChanged(val);
        break;
    }
    case kEdsPropID_WhiteBalance: {
        QString val = wbCodeToQt(event.propertyValue);
        m_owner->setCurrentWhiteBalance(val);
        emit m_owner->currentWhiteBalanceChanged(val);
        break;
    }
    case kEdsPropID_ExposureCompensation: {
        QString val = evCodeToQt(static_cast<qint32>(event.propertyValue));
        m_owner->m_exposureCompensation = val;
        emit m_owner->currentExposureCompensationChanged(val);
        break;
    }
    case kEdsPropID_ColorTemperature: {
        if (event.propertyValue > 0) {
            m_owner->m_colorTemperature = QString::number(event.propertyValue);
            emit m_owner->currentColorTemperatureChanged(m_owner->m_colorTemperature);
        }
        break;
    }
    default:
        break;
    }
}

void CameraEventBridge::handleDownloadProgress(const CameraApp::CameraEvent& event)
{
    qDebug() << "CameraEventBridge: Download progress -" << event.downloadPercent << "%";
    emit m_owner->statusMessage(QString("Downloading: %1%").arg(event.downloadPercent));
}
