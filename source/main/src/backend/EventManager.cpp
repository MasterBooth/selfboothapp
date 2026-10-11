#include "EventManager.h"
#include "CameraController.h"
#include "ImageCompositor.h"
#include "SessionManager.h"
#include "MachineAuthenticator.h"
#include "S3Uploader.h"
#include "VideoCreator.h"
#include "PrinterManager.h"
#include "DynamoDBClient.h"
#include "CloudSyncManager.h"
#include "ConfigManager.h"
#include "DatabaseManager.h"
#include "AppPaths.h"
#include "QrImageProvider.h"
#include <QCoreApplication>
#include <QDir>
#include <QDateTime>
#include <QHash>
#include <QVariantList>
#include <QPair>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QNetworkInterface>
#include <QHostAddress>
#include <QEventLoop>
#include <QPainter>
#include <QPointF>
#include <QImage>
#include <QImageReader>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QTextStream>
#include <QRandomGenerator>
#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QUuid>
#include <QProcess>
#include <QSharedPointer>
#include <QtConcurrent/QtConcurrent>
#include <QFuture>
#include <QMetaObject>
#include <QTimer>
#include <QStandardPaths>
#include <QRegularExpression>
#include <QDirIterator>
#include <cmath>
#include <limits>

namespace {
double safeNorm(double value, double fallback = 0.0)
{
    if (!std::isfinite(value))
        return fallback;
    return qBound(0.0, value, 1.0);
}

int qrSizeFromNorm(int width, int height, double sizeNorm, int minimum = 40)
{
    int refDim = qMax(1, qMin(width, height));
    double safeSizeNorm = std::isfinite(sizeNorm) && sizeNorm > 0.0 ? sizeNorm : 0.12;
    if (refDim <= minimum)
        return refDim;
    return qBound(minimum, qRound(refDim * safeSizeNorm), refDim);
}

QString normalizeVoucherDateTimeForCloud(const QString &value)
{
    QString s = value.trimmed();
    if (s.isEmpty())
        return QString();

    QDateTime dt = QDateTime::fromString(s, Qt::ISODate);
    if (!dt.isValid() && s.contains(' '))
        dt = QDateTime::fromString(s, QStringLiteral("yyyy-MM-dd HH:mm"));
    if (!dt.isValid())
        dt = QDateTime::fromString(s, QStringLiteral("yyyy-MM-ddTHH:mm"));
    if (!dt.isValid())
        dt = QDateTime::fromString(s, QStringLiteral("yyyy-MM-ddTHH:mm:ss"));

    if (!dt.isValid())
        return s;
    return dt.toUTC().toString(Qt::ISODate);
}

int qrPositionFromNorm(int extent, double posNorm, int qrSize)
{
    int maxPos = qMax(0, extent - qrSize);
    return qBound(0, qRound(extent * safeNorm(posNorm)), maxPos);
}

double jsonSlotArea(const QJsonObject &slot)
{
    return (double)slot.value(QStringLiteral("width")).toInt()
         * (double)slot.value(QStringLiteral("height")).toInt();
}

QRect jsonSlotRect(const QJsonObject &slot)
{
    return QRect(slot.value(QStringLiteral("x")).toInt(),
                 slot.value(QStringLiteral("y")).toInt(),
                 slot.value(QStringLiteral("width")).toInt(),
                 slot.value(QStringLiteral("height")).toInt());
}

QJsonObject rectMetadataObject(const QRect &rect)
{
    QJsonObject obj;
    obj[QStringLiteral("x")] = rect.x();
    obj[QStringLiteral("y")] = rect.y();
    obj[QStringLiteral("width")] = rect.width();
    obj[QStringLiteral("height")] = rect.height();
    return obj;
}

bool jsonSlotNearCorner(const QRect &rect, int canvasW, int canvasH)
{
    const int left = rect.left();
    const int right = qMax(0, canvasW - rect.right() - 1);
    const int top = rect.top();
    const int bottom = qMax(0, canvasH - rect.bottom() - 1);
    const bool nearHorizontalEdge = qMin(left, right) <= qMax(20, qRound(canvasW * 0.18));
    const bool nearVerticalEdge = qMin(top, bottom) <= qMax(20, qRound(canvasH * 0.18));
    return nearHorizontalEdge && nearVerticalEdge;
}

double jsonSlotClosestCornerDistance(const QRect &rect, int canvasW, int canvasH)
{
    const QPointF center = rect.center();
    const QPointF corners[] = {
        QPointF(0, 0),
        QPointF(canvasW, 0),
        QPointF(0, canvasH),
        QPointF(canvasW, canvasH)
    };

    double best = std::numeric_limits<double>::max();
    for (const QPointF &corner : corners) {
        const double dx = (center.x() - corner.x()) / qMax(1, canvasW);
        const double dy = (center.y() - corner.y()) / qMax(1, canvasH);
        best = qMin(best, dx * dx + dy * dy);
    }
    return best;
}

QJsonObject normalizeLayoutMetadataObject(const QJsonObject &input, bool *changed = nullptr)
{
    QJsonObject obj = input;
    bool didChange = false;

    QJsonArray slotArray = obj.value(QStringLiteral("slots")).toArray();
    const int canvasW = obj.value(QStringLiteral("width")).toInt();
    const int canvasH = obj.value(QStringLiteral("height")).toInt();

    if (!obj.contains(QStringLiteral("qr_slot")) && slotArray.size() >= 2 && canvasW > 0 && canvasH > 0) {
        QVector<double> areas;
        areas.reserve(slotArray.size());
        for (const QJsonValue &value : slotArray)
            areas.append(jsonSlotArea(value.toObject()));
        std::sort(areas.begin(), areas.end());

        const double medianArea = areas.at(areas.size() / 2);
        const double totalArea = (double)canvasW * (double)canvasH;
        const int maxQrSide = qMax(60, qRound(qMin(canvasW, canvasH) * 0.35));

        int bestIndex = -1;
        double bestArea = std::numeric_limits<double>::max();
        double bestCornerDistance = std::numeric_limits<double>::max();

        for (int i = 0; i < slotArray.size(); ++i) {
            const QJsonObject slot = slotArray.at(i).toObject();
            const QRect rect = jsonSlotRect(slot);
            const double area = jsonSlotArea(slot);
            const double aspect = rect.height() > 0 ? (double)rect.width() / (double)rect.height() : 0.0;

            const bool roughlySquare = aspect >= 0.70 && aspect <= 1.35;
            const bool muchSmallerThanPhoto = area <= medianArea * 0.25;
            const bool smallOnCanvas = area <= totalArea * 0.05
                                    && rect.width() <= maxQrSide
                                    && rect.height() <= maxQrSide;
            const bool nearCorner = jsonSlotNearCorner(rect, canvasW, canvasH);
            if (!roughlySquare || !muchSmallerThanPhoto || !smallOnCanvas || !nearCorner)
                continue;

            const double cornerDistance = jsonSlotClosestCornerDistance(rect, canvasW, canvasH);
            if (area < bestArea || (qFuzzyCompare(area, bestArea) && cornerDistance < bestCornerDistance)) {
                bestIndex = i;
                bestArea = area;
                bestCornerDistance = cornerDistance;
            }
        }

        if (bestIndex >= 0) {
            const QRect qrRect = jsonSlotRect(slotArray.at(bestIndex).toObject());
            QJsonArray photoSlots;
            for (int i = 0; i < slotArray.size(); ++i) {
                if (i == bestIndex)
                    continue;
                QJsonObject photoSlot = slotArray.at(i).toObject();
                photoSlot[QStringLiteral("id")] = photoSlots.size() + 1;
                photoSlots.append(photoSlot);
            }
            slotArray = photoSlots;
            obj[QStringLiteral("slots")] = slotArray;
            obj[QStringLiteral("qr_slot")] = rectMetadataObject(qrRect);
            didChange = true;
        }
    }

    if (obj.value(QStringLiteral("slot_count")).toInt(-1) != slotArray.size()) {
        obj[QStringLiteral("slot_count")] = slotArray.size();
        didChange = true;
    }

    if (changed)
        *changed = didChange;
    return obj;
}

QVariantMap layoutMapFromFile(const QString &layoutPath) {
    QFileInfo fi(layoutPath);
    QVariantMap map;
    if (!fi.exists()) return map;

    map["fileName"] = fi.fileName();
    map["path"] = "file:///" + fi.absoluteFilePath();

    QString jsonPath = fi.absoluteFilePath();
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    QFile jsonFile(jsonPath);
    if (jsonFile.open(QIODevice::ReadOnly)) {
        QJsonDocument doc = QJsonDocument::fromJson(jsonFile.readAll());
        map["metadata"] = normalizeLayoutMetadataObject(doc.object()).toVariantMap();
        jsonFile.close();
    }

    return map;
}

QString uniqueLayoutFilePath(const QString &layoutDirPath, const QString &fileName) {
    QFileInfo sourceInfo(fileName);
    QString baseName = sourceInfo.completeBaseName();
    QString suffix = sourceInfo.suffix().isEmpty() ? "png" : sourceInfo.suffix();
    QString candidate = QDir(layoutDirPath).filePath(baseName + "." + suffix);
    int n = 1;
    while (QFile::exists(candidate)) {
        candidate = QDir(layoutDirPath).filePath(baseName + "_" + QString::number(n) + "." + suffix);
        ++n;
    }
    return candidate;
}

QString stripFileUrl(const QString &path)
{
    QString clean = path;
    if (clean.startsWith("file:///"))
        clean = clean.mid(8);
    return QDir::toNativeSeparators(clean);
}

QString restoreFileUrlIfNeeded(const QString &originalPath, const QString &nativePath)
{
    if (originalPath.startsWith("file:///"))
        return "file:///" + QDir::fromNativeSeparators(nativePath);
    return QDir::toNativeSeparators(nativePath);
}

QString rewritePathIfUnderDir(const QString &originalPath,
                              const QString &sourceDir,
                              const QString &targetDir)
{
    if (originalPath.isEmpty())
        return originalPath;

    const QString cleanOriginal = stripFileUrl(originalPath);
    const QString cleanSourceDir = QDir::cleanPath(QDir::toNativeSeparators(sourceDir));
    const QString cleanTargetDir = QDir::cleanPath(QDir::toNativeSeparators(targetDir));
    const QString normalizedSourcePrefix = cleanSourceDir.endsWith(QDir::separator())
                                         ? cleanSourceDir
                                         : cleanSourceDir + QDir::separator();

    if (!cleanOriginal.startsWith(normalizedSourcePrefix, Qt::CaseInsensitive) &&
        cleanOriginal.compare(cleanSourceDir, Qt::CaseInsensitive) != 0)
        return originalPath;

    QString relativePath = QDir(cleanSourceDir).relativeFilePath(cleanOriginal);
    QString rewritten = QDir(cleanTargetDir).filePath(relativePath);
    return restoreFileUrlIfNeeded(originalPath, rewritten);
}

bool copyDirectoryRecursive(const QString &sourceDirPath, const QString &targetDirPath, QString *error = nullptr)
{
    QDir sourceDir(sourceDirPath);
    if (!sourceDir.exists())
        return true;

    if (!QDir().mkpath(targetDirPath)) {
        if (error)
            *error = QStringLiteral("Failed to create directory: %1").arg(targetDirPath);
        return false;
    }

    QDirIterator it(sourceDirPath, QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot,
                    QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString sourcePath = QDir::toNativeSeparators(it.next());
        const QFileInfo info = it.fileInfo();
        const QString relativePath = sourceDir.relativeFilePath(sourcePath);
        const QString targetPath = QDir(targetDirPath).filePath(relativePath);

        if (info.isDir()) {
            if (!QDir().mkpath(targetPath)) {
                if (error)
                    *error = QStringLiteral("Failed to create directory: %1").arg(targetPath);
                return false;
            }
            continue;
        }

        const QString targetParent = QFileInfo(targetPath).absolutePath();
        if (!QDir().mkpath(targetParent)) {
            if (error)
                *error = QStringLiteral("Failed to create directory: %1").arg(targetParent);
            return false;
        }
        if (QFile::exists(targetPath))
            QFile::remove(targetPath);
        if (!QFile::copy(sourcePath, targetPath)) {
            if (error)
                *error = QStringLiteral("Failed to copy %1 to %2").arg(sourcePath, targetPath);
            return false;
        }
    }

    return true;
}

// Trả thư mục Final theo PHIÊN: finalPath/<sessionId> (tạo nếu chưa có).
// sessionId rỗng → giữ nguyên finalPath (tương thích ngược).
QString sessionFinalDir(const QString &finalPath, const QString &sessionId)
{
    if (finalPath.isEmpty() || sessionId.isEmpty())
        return finalPath;
    const QString dir = QDir(finalPath).filePath(sessionId);
    QDir().mkpath(dir);
    return dir;
}

QString uniqueCopyName(const QString &baseName, const QList<Event> &events)
{
    QSet<QString> existingNames;
    for (const Event &event : events)
        existingNames.insert(event.name.trimmed().toLower());

    const QString copySuffix = QStringLiteral(" (Copy)");
    QString candidate = baseName + copySuffix;
    if (!existingNames.contains(candidate.trimmed().toLower()))
        return candidate;

    int n = 2;
    while (true) {
        candidate = QStringLiteral("%1 (Copy %2)").arg(baseName).arg(n);
        if (!existingNames.contains(candidate.trimmed().toLower()))
            return candidate;
        ++n;
    }
}

// Đồng bộ tải 1 URL với timeout CỨNG. Trả về data rỗng nếu lỗi/timeout.
//
// Trước đây các hàm QR dùng `QEventLoop::exec()` KHÔNG timeout trên main thread:
// nếu endpoint QR chậm/chết → UI treo vô hạn + nested event loop tái nhập handler
// → có thể crash. Helper này đặt 2 lớp bảo vệ:
//   1. QNetworkRequest::setTransferTimeout() — Qt tự abort khi transfer đứng.
//   2. QTimer guard — chặn trần thời gian tường (kể cả khi reply không bao giờ
//      phát finished), abort reply rồi thoát loop.
QByteArray httpGetSyncWithTimeout(const QString &url, int timeoutMs = 15000)
{
    QNetworkAccessManager manager;
    QNetworkRequest request{QUrl(url)};
    request.setTransferTimeout(timeoutMs);
    QNetworkReply *reply = manager.get(request);

    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, &loop, [reply, &loop, timeoutMs, url]() {
        qWarning() << "[EventManager] httpGetSync: timeout after" << timeoutMs
                   << "ms —" << url;
        reply->abort();
        loop.quit();
    });
    guard.start(timeoutMs);

    loop.exec();

    QByteArray data;
    if (reply->error() == QNetworkReply::NoError)
        data = reply->readAll();
    else
        qWarning() << "[EventManager] httpGetSync failed:" << reply->errorString();
    reply->deleteLater();
    return data;
}
} // namespace

EventManager::EventManager(DatabaseManager* dbManager, QObject *parent)
    : QObject(parent)
    , m_dbManager(dbManager)
    , m_sessionManager(nullptr)
    , m_machineAuth(nullptr)
    , m_s3Uploader(nullptr)
    , m_videoCreator(nullptr)
{
  m_dynamoClient = new DynamoDBClient(ConfigManager::instance(), this);
  // Relay danh sách voucher cloud (poll nền) ra QML qua cloudVouchersReady.
  // Trộn thêm mã tạo tại máy (không nằm trên cloud) để chúng luôn hiện trong danh sách.
  connect(m_dynamoClient, &DynamoDBClient::voucherListReady, this,
          [this](const QVariantList &data, bool ok) {
              emit cloudVouchersReady(ok ? mergeLocalCodesIntoCloudList(data) : data, ok);
          });
  connect(m_dynamoClient, &DynamoDBClient::voucherDeleteReady, this,
          [this](const QString &code, const QString &contextId, bool success,
                 bool networkError, const QString &error) {
              if (!m_voucherDeleteBatches.contains(contextId)) {
                  qWarning() << "[VoucherDelete] Result for unknown batch" << contextId << code << error;
                  return;
              }
              VoucherDeleteBatchState &state = m_voucherDeleteBatches[contextId];
              state.completed++;
              if (success) {
                  const bool localOk = m_dbManager->deleteVoucher(code);
                  state.deleted++;
                  qDebug() << "[VoucherDelete] Cloud deleted" << code << "localOk" << localOk;
              } else {
                  state.failed++;
                  qWarning() << "[VoucherDelete] Cloud delete failed" << code
                             << "network" << networkError << error;
              }
              emit voucherBatchDeleteProgress(state.kind, state.completed, state.totalCloud);
              if (state.completed >= state.totalCloud)
                  finishVoucherDeleteBatch(contextId);
          });
  // Database is already initialized in main.cpp, just use the passed pointer
  // No need to create or initialize DatabaseManager here

  m_eventModel = new EventModel(m_dbManager, this);
  m_layoutAnalyzer = new LayoutAnalyzer(this);

  // Ghi m?c d?nh b?t/t?t cho l?n ch?y d?u (DB d� init xong ? main.cpp). Ch?y
  // tru?c khi QML n?p n�n UI ph?n �nh d�ng tr?ng th�i ngay t? d?u.
  seedDefaultAppSettings();
}

EventManager::~EventManager() {}

void EventManager::setSessionManager(SessionManager *sessionManager) {
    if (m_sessionManager == sessionManager) return;
    m_sessionManager = sessionManager;
    if (!m_sessionManager) return;
    connect(m_sessionManager, &SessionManager::sessionStateChanged, this,
            [this](const QString &sessionId) {
                syncSessionToCloud(sessionId);
                emit captureAttemptsChanged();
            });
}

// Phiên chụp -> outbox (PUT /v1/machine/sessions/{id}); hwid/studio do server lấy từ
// token máy. Chưa đăng nhập / mất mạng thì bản mới nhất của phiên nằm chờ trong outbox.
void EventManager::syncSessionToCloud(const QString &sessionId) {
    if (!m_sessionManager || !m_cloudSync) return;
    const QVariantMap s = m_sessionManager->getSessionInfo(sessionId);
    if (s.isEmpty() || s.value("status").toString() == "PREPARED") return;
    QJsonObject payload;
    payload["event_id"]        = s.value("event_id").toInt();
    payload["operation_mode"]  = getAppSetting("app_operation_mode", "mode1");
    payload["status"]          = s.value("status").toString();
    payload["status_version"]  = s.value("status_version").toInt();
    payload["photos_count"]    = s.value("photo_count").toInt();
    payload["expected_photos"] = s.value("expected_photos").toInt();
    const QString startedAt = s.value("capture_started_at").toString();
    const QString endedAt   = s.value("ended_at").toString();
    if (!startedAt.isEmpty()) payload["started_at"] = startedAt;
    if (!endedAt.isEmpty())   payload["ended_at"]   = endedAt;
    const QString useId = m_sessionCodeUse.value(sessionId);
    if (!useId.isEmpty()) payload["code_use_id"] = useId;
    m_cloudSync->enqueueSession(sessionId, payload);
}

void EventManager::setSessionCodeUse(const QString &sessionId, const QString &useId) {
    if (sessionId.isEmpty() || useId.isEmpty()) return;
    m_sessionCodeUse.insert(sessionId, useId);
    syncSessionToCloud(sessionId);
}

bool EventManager::createEvent(const QString &name, const QString &location,
                               const QString &eventDate) {
  if (name.isEmpty()) {
    emit error("Event name cannot be empty");
    return false;
  }

  // Use AppPaths for centralized path management
  QString safeName = AppPaths::instance().sanitizeEventName(name);

  QString originalsPath = AppPaths::instance().getEventOriginalsPath(safeName);
  QString finalPath = AppPaths::instance().getEventFinalPath(safeName);
  QString layoutsPath = AppPaths::instance().getEventLayoutsPath(safeName);

  // Create directories with error checking
  QString errorMsg;
  if (!AppPaths::instance().ensureDirectoryExists(originalsPath, &errorMsg)) {
    emit this->error("Failed to create Originals directory: " + errorMsg);
    return false;
  }
  if (!AppPaths::instance().ensureDirectoryExists(finalPath, &errorMsg)) {
    emit this->error("Failed to create Final directory: " + errorMsg);
    return false;
  }
  if (!AppPaths::instance().ensureDirectoryExists(layoutsPath, &errorMsg)) {
    emit this->error("Failed to create Layouts directory: " + errorMsg);
    return false;
  }

  qDebug() << "Event directories created:";
  qDebug() << "  Originals:" << originalsPath;
  qDebug() << "  Final:" << finalPath;
  qDebug() << "  Layouts:" << layoutsPath;

  Event event;
  event.name = name;
  event.location = location;
  event.eventDate = QDateTime::fromString(eventDate, Qt::ISODate);
  event.captureMode = "photo"; // Default
  event.digitalProps = false;
  event.beautyFilter = false;
  event.watermark = true;
  event.postProcessing = false;
  event.countdownDuration = 3;     // Default: 3 seconds
  event.firstShotCountdown = 6;    // Default: 6 seconds
  event.nextShotCountdown = 5;     // Default: 5 seconds
  event.shotInterval = 500;        // Default: 500 milliseconds (0.5 seconds)
  event.shootingMode = 1;          // Default: Manual
  event.manualPhotoCount = 6;      // Default: 6 ảnh
  event.autoCut = false;
  event.mirrorMode = true;         // Default: BẬT
  event.liveViewOverlay = false;
  event.liveViewBackground = true; // Default: BẬT
  event.poseGuide = false;         // Default: TẮT

  // Save paths to DB
  event.rawPath = originalsPath;
  event.finalPath = finalPath;
  // We don't store layout path explicit in DB, we infer it or add col?
  // Infer from structure for now.

  int eventId = m_dbManager->createEvent(event);
  if (eventId > 0) {
    m_eventModel->refresh();
    emit eventCreated(eventId);
    return true;
  }

  emit error("Failed to create event");
  return false;
}

int EventManager::getOrCreatePaperEvent() {
  const QString paperName = QStringLiteral("Paper");
  const QList<Event> events = m_dbManager->getAllEvents();
  for (const Event &event : events) {
    if (event.name.compare(paperName, Qt::CaseInsensitive) == 0)
      return event.id;
  }

  if (!createEvent(paperName, QString(), QDateTime::currentDateTime().toString(Qt::ISODate)))
    return -1;

  const QList<Event> updatedEvents = m_dbManager->getAllEvents();
  for (const Event &event : updatedEvents) {
    if (event.name.compare(paperName, Qt::CaseInsensitive) == 0)
      return event.id;
  }

  return -1;
}

int EventManager::getOrCreateBoothosEvent() {
  const QString boothosName = QStringLiteral("selfbooth");
  const QList<Event> events = m_dbManager->getAllEvents();
  for (const Event &event : events) {
    if (event.name.compare(boothosName, Qt::CaseInsensitive) == 0)
      return event.id;
  }
  if (!createEvent(boothosName, QString(), QDateTime::currentDateTime().toString(Qt::ISODate)))
    return -1;
  const QList<Event> updatedEvents = m_dbManager->getAllEvents();
  for (const Event &event : updatedEvents) {
    if (event.name.compare(boothosName, Qt::CaseInsensitive) == 0)
      return event.id;
  }
  return -1;
}
int EventManager::getOrCreateStudioEvent(const QString &nameOverride) {
  const QString studioName = nameOverride.isEmpty() ? QStringLiteral("studio")
                                                    : nameOverride;
  const QList<Event> events = m_dbManager->getAllEvents();
  for (const Event &event : events) {
    if (event.name.compare(studioName, Qt::CaseInsensitive) == 0)
      return event.id;
  }

  if (!createEvent(studioName, QString(), QDateTime::currentDateTime().toString(Qt::ISODate)))
    return -1;

  const QList<Event> updatedEvents = m_dbManager->getAllEvents();
  for (const Event &event : updatedEvents) {
    if (event.name.compare(studioName, Qt::CaseInsensitive) == 0)
      return event.id;
  }

  return -1;
}
// ... (Keep existing methods) ...

bool EventManager::uploadLayout(int eventId, const QString &filePath) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        emit error("Event not found");
        return false;
    }
    
    // Get Layouts directory path using AppPaths
    QString layoutDirPath = AppPaths::instance().getEventLayoutsPath(event.name);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(layoutDirPath, &errorMsg)) {
        qWarning() << "Failed to ensure Layouts directory:" << errorMsg;
    }
    
    // Clean Input Path
    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) {
        sourcePath = sourcePath.mid(8);
    }
    
    QFileInfo fi(sourcePath);
    if (!fi.exists()) {
        emit error("Source file not found: " + sourcePath);
        return false;
    }
    
    QString destPath = QDir(layoutDirPath).filePath(fi.fileName());
    
    // Copy
    if (QFile::exists(destPath)) QFile::remove(destPath);
    if (!QFile::copy(sourcePath, destPath)) {
        emit error("Failed to copy file to event folder");
        return false;
    }
    
    // Normalise the layout async in a background thread (non-blocking UI)
    QString dpi         = m_printerConfig ? m_printerConfig->resolution()       : "300dpi";
    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter()  : QString();
    // completeBaseName() cắt tại dấu chấm CUỐI — phải khớp với cách requestLayouts/
    // getLayouts/loadLayoutMetadata tìm file .json, nếu không khung có dấu chấm trong
    // tên (vd "frame1.75.png") sẽ ghi JSON sai tên và không bao giờ hiện trong danh sách.
    QString jsonPath    = QFileInfo(destPath).absolutePath() + "/"
                        + QFileInfo(destPath).completeBaseName() + ".json";

    qDebug() << "[EventManager] uploadLayout: starting async normalisation for event" << eventId
             << "dpi=" << dpi << "printer=" << printerName;

    QString fileName = QFileInfo(destPath).fileName();
    (void)QtConcurrent::run([this, eventId, destPath, jsonPath, dpi, printerName, fileName]() {
        bool ok = m_layoutAnalyzer->processLayout(destPath, jsonPath, dpi, printerName);
        QMetaObject::invokeMethod(this, [this, eventId, ok, fileName]() {
            if (ok) {
                emit layoutUploaded(eventId);
                qInfo() << "[EventManager] Layout uploaded and processed successfully";
            } else {
                emit layoutFailed(eventId, fileName,
                                  "Không tìm thấy vùng trong suốt hợp lệ hoặc không đọc được ảnh");
            }
        }, Qt::QueuedConnection);
    });

    // Return true immediately — processing continues in background
    return true;
}

bool EventManager::uploadLayoutToCategory(int eventId, const QString &filePath, const QString &category) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        emit error("Event not found");
        return false;
    }

    QString layoutDirPath = AppPaths::instance().getEventLayoutsPath(event.name);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(layoutDirPath, &errorMsg)) {
        qWarning() << "Failed to ensure Layouts directory:" << errorMsg;
    }

    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) {
        sourcePath = sourcePath.mid(8);
    }

    QFileInfo fi(sourcePath);
    if (!fi.exists()) {
        emit error("Source file not found: " + sourcePath);
        return false;
    }

    QString cleanCategory = category.trimmed();
    cleanCategory.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    QString destFileName = (cleanCategory.isEmpty() || cleanCategory == "Khác")
        ? fi.fileName()
        : cleanCategory + "__" + fi.fileName();
    QString destPath = uniqueLayoutFilePath(layoutDirPath, destFileName);

    if (!QFile::copy(sourcePath, destPath)) {
        emit error("Failed to copy file to event folder");
        return false;
    }

    QString dpi         = m_printerConfig ? m_printerConfig->resolution()       : "300dpi";
    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter()  : QString();
    // Xem chú thích ở uploadLayout: phải dùng completeBaseName() để khớp với bên đọc.
    QString jsonPath    = QFileInfo(destPath).absolutePath() + "/"
                        + QFileInfo(destPath).completeBaseName() + ".json";

    qDebug() << "[EventManager] uploadLayoutToCategory: starting async normalisation for event" << eventId
             << "category=" << cleanCategory << "dpi=" << dpi << "printer=" << printerName;

    QString fileName = QFileInfo(destPath).fileName();
    (void)QtConcurrent::run([this, eventId, destPath, jsonPath, dpi, printerName, fileName]() {
        bool ok = m_layoutAnalyzer->processLayout(destPath, jsonPath, dpi, printerName);
        QVariantMap layout = ok ? layoutMapFromFile(destPath) : QVariantMap();
        QMetaObject::invokeMethod(this, [this, eventId, ok, layout, fileName]() {
            if (ok && !layout.isEmpty()) {
                emit layoutReady(eventId, layout);
                emit layoutUploaded(eventId);
                qInfo() << "[EventManager] Layout uploaded and processed successfully";
            } else {
                emit layoutFailed(eventId, fileName,
                                  "Không tìm thấy vùng trong suốt hợp lệ hoặc không đọc được ảnh");
            }
        }, Qt::QueuedConnection);
    });

    return true;
}

bool EventManager::ensureFrameCategory(int eventId, const QString &category) {
    QString cleanCategory = category.trimmed();
    cleanCategory.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    if (eventId <= 0 || cleanCategory.isEmpty() || cleanCategory == QStringLiteral("Khác"))
        return false;

    const QString key = QStringLiteral("frame_categories");
    QString raw = m_dbManager->getEventSettingRaw(eventId, key);
    if (raw == DatabaseManager::kEventSettingAbsent)
        raw = m_dbManager->getSetting(key, QString());

    QStringList parts;
    for (const QString &part : raw.split('|')) {
        const QString t = part.trimmed();
        if (!t.isEmpty() && !parts.contains(t)) parts << t;
    }
    if (parts.contains(cleanCategory)) return true;
    parts << cleanCategory;
    return m_dbManager->setEventSetting(eventId, key, parts.join('|'));
}

QString EventManager::findFrameLayoutPath(int eventId, const QString &category, const QString &fileName) const {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return QString();

    QString cleanCategory = category.trimmed();
    cleanCategory.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    QString cleanName = QFileInfo(fileName).fileName();
    cleanName.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    if (cleanName.isEmpty()) return QString();

    const QString layoutDirPath = AppPaths::instance().getEventLayoutsPath(event.name);
    const QString preferred = cleanCategory.isEmpty() || cleanCategory == QStringLiteral("Khác")
        ? QDir(layoutDirPath).filePath(cleanName)
        : QDir(layoutDirPath).filePath(cleanCategory + QStringLiteral("__") + cleanName);
    if (QFile::exists(preferred)) return QStringLiteral("file:///") + QDir::fromNativeSeparators(QFileInfo(preferred).absoluteFilePath());

    QDir dir(layoutDirPath);
    const QStringList files = dir.entryList(QStringList() << QStringLiteral("*.png"), QDir::Files, QDir::Time);
    const QString prefix = cleanCategory + QStringLiteral("__");
    for (const QString &f : files) {
        if (!cleanCategory.isEmpty() && cleanCategory != QStringLiteral("Khác") && !f.startsWith(prefix))
            continue;
        const QString localName = (!cleanCategory.isEmpty() && cleanCategory != QStringLiteral("Khác"))
            ? f.mid(prefix.size()) : f;
        if (localName.compare(cleanName, Qt::CaseInsensitive) == 0
                || localName.startsWith(QFileInfo(cleanName).completeBaseName() + QStringLiteral("_"))) {
            return QStringLiteral("file:///") + QDir::fromNativeSeparators(QFileInfo(dir.filePath(f)).absoluteFilePath());
        }
    }
    return QString();
}

constexpr int kSecurityPinIterations = 120000;

bool isSecurityPinFormat(const QString &pin)
{
    static const QRegularExpression rx(QStringLiteral("^\\d{4,6}$"));
    return rx.match(pin).hasMatch();
}

QString randomSaltHex()
{
    QByteArray bytes;
    bytes.resize(16);
    for (int i = 0; i < bytes.size(); ++i)
        bytes[i] = static_cast<char>(QRandomGenerator::global()->bounded(256));
    return QString::fromLatin1(bytes.toHex());
}

QByteArray securityPinHashHex(const QString &pin, const QString &saltHex, int iterations)
{
    const QByteArray salt = QByteArray::fromHex(saltHex.toLatin1());
    const QByteArray secret = pin.toUtf8();
    QByteArray digest = salt + secret;
    const int rounds = qMax(10000, iterations);
    for (int i = 0; i < rounds; ++i) {
        QCryptographicHash h(QCryptographicHash::Sha256);
        h.addData(salt);
        h.addData(digest);
        h.addData(secret);
        digest = h.result();
    }
    return digest.toHex();
}

bool constantTimeEqual(const QByteArray &a, const QByteArray &b)
{
    if (a.size() != b.size())
        return false;
    uchar diff = 0;
    for (int i = 0; i < a.size(); ++i)
        diff |= static_cast<uchar>(a.at(i) ^ b.at(i));
    return diff == 0;
}

bool EventManager::importCategoryDisplayImage(int eventId, const QString &category, const QString &filePath) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return false;

    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) sourcePath = sourcePath.mid(8);
    const QFileInfo src(sourcePath);
    if (!src.exists()) return false;

    QString cleanCategory = category.trimmed();
    cleanCategory.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    if (cleanCategory.isEmpty()) return false;

    const QString dirPath = QDir(AppPaths::instance().getEventLayoutsPath(event.name))
                                .filePath(QStringLiteral("DisplayImages"));
    QString err;
    if (!AppPaths::instance().ensureDirectoryExists(dirPath, &err)) {
        qWarning() << "[EventManager] importCategoryDisplayImage: cannot create dir:" << err;
        return false;
    }

    QString ext = src.suffix().toLower();
    if (ext.isEmpty()) ext = QStringLiteral("png");
    const QString destPath = QDir(dirPath).filePath(cleanCategory + QStringLiteral(".") + ext);
    if (QFile::exists(destPath)) QFile::remove(destPath);
    if (!QFile::copy(sourcePath, destPath)) return false;

    return m_dbManager->setEventSetting(eventId,
        QStringLiteral("cate_image_") + cleanCategory,
        QStringLiteral("file:///") + QDir::fromNativeSeparators(QFileInfo(destPath).absoluteFilePath()));
}

bool EventManager::uploadPaperLayout(const QString &filePath) {
    QString layoutDirPath = QDir(AppPaths::instance().getAppDirectory()).filePath("data/PaperLayouts");
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(layoutDirPath, &errorMsg)) {
        qWarning() << "Failed to ensure PaperLayouts directory:" << errorMsg;
        return false;
    }

    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) {
        sourcePath = sourcePath.mid(8);
    }

    QFileInfo fi(sourcePath);
    if (!fi.exists()) {
        emit error("Source file not found: " + sourcePath);
        return false;
    }

    QString destPath = QDir(layoutDirPath).filePath(fi.fileName());
    if (QFile::exists(destPath)) QFile::remove(destPath);
    if (!QFile::copy(sourcePath, destPath)) {
        emit error("Failed to copy file to paper layout folder");
        return false;
    }

    QString dpi         = m_printerConfig ? m_printerConfig->resolution()       : "300dpi";
    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter()  : QString();
    QString jsonPath    = QFileInfo(destPath).absolutePath() + "/"
                        + QFileInfo(destPath).completeBaseName() + ".json";

    (void)QtConcurrent::run([this, destPath, jsonPath, dpi, printerName]() {
        bool ok = m_layoutAnalyzer->processLayout(destPath, jsonPath, dpi, printerName);
        QMetaObject::invokeMethod(this, [this, ok]() {
            emit layoutUploaded(-1);
            emit error(ok ? "Paper layout uploaded and processed successfully!"
                          : "Failed to analyse paper layout slots. Ensure transparency exists.");
        }, Qt::QueuedConnection);
    });

    return true;
}

bool EventManager::deletePaperLayout(const QString &layoutPath) {
    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);

    if (!QFile::exists(path)) return false;
    QString jsonPath = path;
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    bool ok = QFile::remove(path);
    if (QFile::exists(jsonPath)) QFile::remove(jsonPath);
    if (ok) emit layoutUploaded(-1);
    return ok;
}

bool EventManager::ensureLayoutMetadata(const QString &layoutPath) {
    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);

    if (path.isEmpty() || !QFile::exists(path)) {
        qWarning() << "[EventManager] ensureLayoutMetadata: layout image not found:" << path;
        return false;
    }

    QString jsonPath = path;
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    QVariantMap existing = loadLayoutMetadata(path);
    QVariantList existingSlots = existing.value("slots").toList();
    if (!existingSlots.isEmpty()) return true;

    QString dpi = m_printerConfig ? m_printerConfig->resolution() : "300dpi";
    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    bool ok = m_layoutAnalyzer->processLayout(path, jsonPath, dpi, printerName);
    qDebug() << "[EventManager] ensureLayoutMetadata:" << (ok ? "OK" : "FAILED")
             << "path=" << path << "json=" << jsonPath;
    return ok;
}

// ── Lõi xoá/đổi tên khung — KHÔNG phát tín hiệu, gọi được từ thread nền ──────
bool EventManager::doDeleteLayout(const QString &layoutPath, QString *err) {
    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);

    QFileInfo fi(path);
    if (!fi.exists()) {
        if (err) *err = QStringLiteral("Không tìm thấy tệp: %1").arg(fi.fileName());
        return false;
    }

    // Delete JSON sidecar if present
    QString jsonPath = fi.absolutePath() + "/" + fi.completeBaseName() + ".json";
    if (QFile::exists(jsonPath)) QFile::remove(jsonPath);

    if (!QFile::remove(path)) {
        if (err) *err = QStringLiteral("Không xoá được tệp: %1").arg(fi.fileName());
        return false;
    }
    return true;
}

bool EventManager::doRenameLayout(const QString &oldPath, const QString &newName,
                                  QString *outNewPath, QString *err) {
    QString path = oldPath;
    if (path.startsWith("file:///")) path = path.mid(8);

    QFileInfo fi(path);
    if (!fi.exists()) {
        if (err) *err = QStringLiteral("Không tìm thấy tệp: %1").arg(fi.fileName());
        return false;
    }

    QString dir = fi.absolutePath();
    QString newBase = newName;
    // Ensure .png extension
    if (!newBase.endsWith(".png", Qt::CaseInsensitive)) newBase += ".png";

    QString newFilePath = dir + "/" + newBase;
    if (QFile::exists(newFilePath)) {
        if (err) *err = QStringLiteral("Đã có khung trùng tên: %1").arg(newBase);
        return false;
    }

    // Rename PNG
    if (!QFile::rename(path, newFilePath)) {
        if (err) *err = QStringLiteral("Không đổi tên được: %1").arg(fi.fileName());
        return false;
    }

    // Rename JSON sidecar
    QString oldJson = dir + "/" + fi.completeBaseName() + ".json";
    QString newJson = dir + "/" + QFileInfo(newBase).completeBaseName() + ".json";
    if (QFile::exists(oldJson)) QFile::rename(oldJson, newJson);

    if (outNewPath)
        *outNewPath = "file:///" + QFileInfo(newFilePath).absoluteFilePath();
    return true;
}

bool EventManager::deleteLayout(int eventId, const QString &layoutPath) {
    QString err;
    if (!doDeleteLayout(layoutPath, &err)) {
        emit error(err);
        return false;
    }

    emit layoutUploaded(eventId); // reuse signal to trigger UI refresh
    return true;
}

bool EventManager::renameLayout(int eventId, const QString &oldPath, const QString &newName) {
    QString err;
    if (!doRenameLayout(oldPath, newName, nullptr, &err)) {
        emit error(err);
        return false;
    }

    emit layoutUploaded(eventId); // trigger UI refresh
    return true;
}

// ── Thao tác khung theo LÔ ───────────────────────────────────────────────────
//
// Điểm khác biệt so với gọi bản đơn trong vòng lặp:
//   * toàn lô chạy TUẦN TỰ trong MỘT thread nền (trước đây mỗi file một
//     QtConcurrent::run → N thread cùng đọc/quét pixel PNG lớn, nghẽn CPU/IO);
//   * layoutUploaded chỉ phát MỘT lần ở cuối → QML nạp lại danh sách 1 lần
//     thay vì N+1 lần;
//   * có frameTaskStarted/Progress/Finished để QML hiện dialog tiến trình.
//
void EventManager::uploadLayoutsBatch(int eventId, const QStringList &filePaths,
                                      const QString &category) {
    if (filePaths.isEmpty()) return;

    // Đọc DB ở main thread (nhanh, tránh dùng SQLite từ thread nền).
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        emit error("Event not found");
        return;
    }

    const QString layoutDirPath = AppPaths::instance().getEventLayoutsPath(event.name);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(layoutDirPath, &errorMsg))
        qWarning() << "Failed to ensure Layouts directory:" << errorMsg;

    QString cleanCategory = category.trimmed();
    cleanCategory.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    const bool useCategory = !cleanCategory.isEmpty() && cleanCategory != QStringLiteral("Khác");

    const QString dpi         = m_printerConfig ? m_printerConfig->resolution()      : "300dpi";
    const QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();

    qInfo() << "[EventManager] uploadLayoutsBatch:" << filePaths.size() << "khung, event"
            << eventId << "category=" << (useCategory ? cleanCategory : QStringLiteral("(không)"));

    emit frameTaskStarted(QStringLiteral("upload"), filePaths.size());

    (void)QtConcurrent::run([this, eventId, filePaths, layoutDirPath, cleanCategory,
                             useCategory, dpi, printerName]() {
        int ok = 0, failed = 0;
        QStringList errors;

        for (int i = 0; i < filePaths.size(); ++i) {
            QString sourcePath = filePaths.at(i);
            if (sourcePath.startsWith("file:///")) sourcePath = sourcePath.mid(8);

            const QFileInfo srcInfo(sourcePath);
            const QString fileName = srcInfo.fileName();

            auto reportProgress = [this, i, total = filePaths.size(), fileName]() {
                QMetaObject::invokeMethod(this, [this, i, total, fileName]() {
                    emit frameTaskProgress(i + 1, total, fileName);
                }, Qt::QueuedConnection);
            };

            if (!srcInfo.exists()) {
                ++failed;
                errors << QStringLiteral("%1 — không tìm thấy tệp nguồn").arg(fileName);
                reportProgress();
                continue;
            }

            // Cùng quy tắc đặt tên với uploadLayout/uploadLayoutToCategory:
            // không có nhóm → chép đè cùng tên; có nhóm → tiền tố + tránh trùng.
            QString destPath;
            if (useCategory) {
                destPath = uniqueLayoutFilePath(layoutDirPath,
                                                cleanCategory + "__" + fileName);
            } else {
                destPath = QDir(layoutDirPath).filePath(fileName);
                if (QFile::exists(destPath)) QFile::remove(destPath);
            }

            if (!QFile::copy(sourcePath, destPath)) {
                ++failed;
                errors << QStringLiteral("%1 — không chép được vào thư mục sự kiện").arg(fileName);
                reportProgress();
                continue;
            }

            // completeBaseName() cắt tại dấu chấm CUỐI — phải khớp với cách
            // requestLayouts/getLayouts tìm file .json, nếu không khung có dấu
            // chấm trong tên (vd "frame1.75.png") sẽ không bao giờ hiện ra.
            const QString jsonPath = QFileInfo(destPath).absolutePath() + "/"
                                   + QFileInfo(destPath).completeBaseName() + ".json";
            const QString destName = QFileInfo(destPath).fileName();

            if (m_layoutAnalyzer->processLayout(destPath, jsonPath, dpi, printerName)) {
                ++ok;
                const QVariantMap layout = layoutMapFromFile(destPath);
                if (!layout.isEmpty()) {
                    // Phát từng khung để lưới hiện dần trong lúc lô còn chạy.
                    // Đây là append vào model, KHÔNG phải nạp lại toàn danh sách.
                    QMetaObject::invokeMethod(this, [this, eventId, layout]() {
                        emit layoutReady(eventId, layout);
                    }, Qt::QueuedConnection);
                }
            } else {
                ++failed;
                errors << QStringLiteral("%1 — không tìm thấy vùng trong suốt hợp lệ").arg(destName);
                QMetaObject::invokeMethod(this, [this, eventId, destName]() {
                    emit layoutFailed(eventId, destName,
                                      "Không tìm thấy vùng trong suốt hợp lệ hoặc không đọc được ảnh");
                }, Qt::QueuedConnection);
            }

            reportProgress();
        }

        QMetaObject::invokeMethod(this, [this, eventId, ok, failed, errors]() {
            emit layoutUploaded(eventId);   // ← ĐÚNG MỘT LẦN cho cả lô
            emit frameTaskFinished(QStringLiteral("upload"), ok, failed, errors);
            qInfo() << "[EventManager] uploadLayoutsBatch xong — ok:" << ok << "lỗi:" << failed;
        }, Qt::QueuedConnection);
    });
}

void EventManager::deleteLayoutsBatch(int eventId, const QStringList &layoutPaths) {
    if (layoutPaths.isEmpty()) return;

    qInfo() << "[EventManager] deleteLayoutsBatch:" << layoutPaths.size() << "khung, event" << eventId;
    emit frameTaskStarted(QStringLiteral("delete"), layoutPaths.size());

    (void)QtConcurrent::run([this, eventId, layoutPaths]() {
        int ok = 0, failed = 0;
        QStringList errors;

        for (int i = 0; i < layoutPaths.size(); ++i) {
            const QString path = layoutPaths.at(i);
            const QString fileName = QFileInfo(path).fileName();

            QString err;
            if (doDeleteLayout(path, &err)) {
                ++ok;
                // QML cần chuỗi gốc để dựng lại đúng khóa app-setting frame_image_*.
                QMetaObject::invokeMethod(this, [this, path]() {
                    emit frameDeleted(path);
                }, Qt::QueuedConnection);
            } else {
                ++failed;
                errors << err;
            }

            QMetaObject::invokeMethod(this, [this, i, total = layoutPaths.size(), fileName]() {
                emit frameTaskProgress(i + 1, total, fileName);
            }, Qt::QueuedConnection);
        }

        QMetaObject::invokeMethod(this, [this, eventId, ok, failed, errors]() {
            emit layoutUploaded(eventId);   // ← ĐÚNG MỘT LẦN cho cả lô
            emit frameTaskFinished(QStringLiteral("delete"), ok, failed, errors);
            qInfo() << "[EventManager] deleteLayoutsBatch xong — ok:" << ok << "lỗi:" << failed;
        }, Qt::QueuedConnection);
    });
}

void EventManager::renameLayoutsBatch(int eventId, const QVariantList &pairs) {
    if (pairs.isEmpty()) return;

    // Chuẩn hoá về cặp (from, to) ngay ở main thread — QVariantList từ QML
    // không nên đọc chéo thread.
    QList<QPair<QString, QString>> jobs;
    jobs.reserve(pairs.size());
    for (const QVariant &v : pairs) {
        const QVariantMap m = v.toMap();
        const QString from = m.value("from").toString();
        const QString to   = m.value("to").toString();
        if (!from.isEmpty() && !to.isEmpty())
            jobs.append(qMakePair(from, to));
    }
    if (jobs.isEmpty()) return;

    qInfo() << "[EventManager] renameLayoutsBatch:" << jobs.size() << "khung, event" << eventId;
    emit frameTaskStarted(QStringLiteral("rename"), jobs.size());

    (void)QtConcurrent::run([this, eventId, jobs]() {
        int ok = 0, failed = 0;
        QStringList errors;

        for (int i = 0; i < jobs.size(); ++i) {
            const QString from = jobs.at(i).first;
            const QString to   = jobs.at(i).second;
            const QString fileName = QFileInfo(from).fileName();

            QString newPath, err;
            if (doRenameLayout(from, to, &newPath, &err)) {
                ++ok;
                QMetaObject::invokeMethod(this, [this, from, newPath]() {
                    emit frameRenamed(from, newPath);
                }, Qt::QueuedConnection);
            } else {
                ++failed;
                errors << err;
            }

            QMetaObject::invokeMethod(this, [this, i, total = jobs.size(), fileName]() {
                emit frameTaskProgress(i + 1, total, fileName);
            }, Qt::QueuedConnection);
        }

        QMetaObject::invokeMethod(this, [this, eventId, ok, failed, errors]() {
            emit layoutUploaded(eventId);   // ← ĐÚNG MỘT LẦN cho cả lô
            emit frameTaskFinished(QStringLiteral("rename"), ok, failed, errors);
            qInfo() << "[EventManager] renameLayoutsBatch xong — ok:" << ok << "lỗi:" << failed;
        }, Qt::QueuedConnection);
    });
}

int EventManager::getAutoCutThreshold() const {
    if (m_printerConfig && m_printerConfig->resolution() == "600dpi") {
        return 1500;
    }
    return 800; // 300dpi default
}

// ─── Normalise layouts for ONE event only (async) ────────────────────────────
//
// Layout classification by W:H aspect ratio:
//   aspect ≤ 0.38          → 5×15 strip   (RX1/620S 2×6, ratio ~0.33)
//   0.38 < aspect ≤ 0.58   → 5×10 strip   (QW410, ratio ~0.50)
//   0.58 < aspect ≤ 1.0    → portrait/4×6 (ratio ~0.67)
//   aspect > 2.0            → 15×5 strip   (RX1/620S landscape cut, ratio ~3.0)
//
// Actions per printer:
//   QW410   :  5×15 → DELETE  |  5×10 → SCALE to 600×1200  |  15×5 → DELETE  |  other → KEEP
//   RX1/620S:  5×10 → DELETE  |  5×15 → KEEP (process)     |  15×5 → KEEP    |  other → KEEP
//
void EventManager::reprocessLayoutForEvent(int eventId) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return;

    QString dpi         = m_printerConfig ? m_printerConfig->resolution()      : "300dpi";
    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    bool isQW410 = printerName.contains("QW410", Qt::CaseInsensitive)
               || printerName.contains("QW-410", Qt::CaseInsensitive)
               || printerName.contains("410", Qt::CaseInsensitive);

    // ── Classify each layout ──────────────────────────────────────────────────
    enum Action { Keep, Scale, Delete };
    struct LayoutTask {
        QString pngPath, jsonPath, fileName;
        Action  action;
        QString hint;   // printerHint passed to processLayout
    };
    QList<LayoutTask> tasks;

    QDir dir(event.rawPath);
    if (dir.dirName() == "Originals") dir.cdUp();
    QDir layoutDir(dir.filePath("Layouts"));

    if (!layoutDir.exists()) {
        qDebug() << "[EventManager] reprocessLayoutForEvent: no Layouts dir for event" << eventId;
        return;
    }

    for (const QFileInfo &fi : layoutDir.entryInfoList(QStringList() << "*.png", QDir::Files)) {
        QImage img(fi.absoluteFilePath());
        if (img.isNull()) continue;

        double aspect = img.height() > 0 ? (double)img.width() / img.height() : 0.0;
        bool is5x15  = (aspect <= 0.38);
        bool is5x10  = (aspect > 0.38 && aspect <= 0.58);
        bool is15x5  = (aspect > 2.0);   // 15×5 landscape strip, ratio ~3.0

        LayoutTask t;
        t.pngPath  = fi.absoluteFilePath();
        t.jsonPath = layoutDir.filePath(fi.completeBaseName() + ".json");
        t.fileName = fi.fileName();
        t.hint     = QString();

        if (isQW410) {
            // Tất cả layout đều scale với hint QW410:
            //   5×15 (aspect ≤ 0.38)  → 600×1800 (nhân đôi, in portrait, không cắt)
            //   5×10 (0.38–0.58)      → 600×1200 (cut mode)
            //   portrait (0.58–1.0)   → 1200×1800 (no-cut)
            //   15×5 (aspect > 2.0)   → DELETE (QW410 không hỗ trợ cut ngang)
            //   landscape khác (1–2)  → 1800×1200 (no-cut)
            if (is15x5) t.action = Delete;
            else { t.action = Scale; t.hint = printerName; }
        } else {
            if      (is5x10) t.action = Delete;   // RX1/620S không dùng 5×10
            else              t.action = Keep;    // giữ 5×15, 15×5, và layout khác
        }

        qDebug() << "[EventManager] reprocessLayoutForEvent: layout" << t.fileName
                 << "aspect=" << QString::number(aspect, 'f', 2)
                 << (t.action == Delete ? "→ DELETE"
                   : t.action == Scale  ? "→ SCALE(QW410)"
                                        : "→ KEEP");
        tasks.append(t);
    }

    if (tasks.isEmpty()) {
        qDebug() << "[EventManager] reprocessLayoutForEvent: no layouts found for event" << eventId;
        return;
    }

    qDebug() << "[EventManager] reprocessLayoutForEvent: event" << eventId
             << tasks.size() << "layouts, printer=" << printerName;

    (void)QtConcurrent::run([this, eventId, tasks, dpi, isQW410]() {
        int processed = 0;
        QStringList deletedPaths;

        for (const LayoutTask &task : tasks) {
            if (task.action == Delete) {
                QFile::remove(task.pngPath);
                QFile::remove(task.jsonPath);
                deletedPaths << task.pngPath;
                qDebug() << "[EventManager] reprocessLayoutForEvent: deleted" << task.fileName;
            } else {
                // Scale passes QW410 printerHint → target 600×1200
                // Keep  passes empty hint       → standard RX1/620S sizing
                if (m_layoutAnalyzer->processLayout(task.pngPath, task.jsonPath, dpi, task.hint)) {
                    processed++;
                    qDebug() << "[EventManager] reprocessLayoutForEvent: processed" << task.fileName;
                } else {
                    qWarning() << "[EventManager] reprocessLayoutForEvent: failed" << task.fileName;
                }
            }
        }

        QMetaObject::invokeMethod(this, [this, eventId, processed, deletedPaths, isQW410]() {
            Event ev = m_dbManager->getEvent(eventId);
            if (ev.id > 0) {
                QString cleanLayout = ev.selectedLayout;
                if (cleanLayout.startsWith("file:///")) cleanLayout = cleanLayout.mid(8);
                cleanLayout = QDir::toNativeSeparators(cleanLayout);

                if (!cleanLayout.isEmpty() && deletedPaths.contains(cleanLayout)) {
                    // Selected layout was deleted — clear it
                    ev.selectedLayout.clear();
                    ev.autoCut = false;
                    m_dbManager->updateEvent(ev);
                    qDebug() << "[EventManager] reprocessLayoutForEvent: selected layout deleted, cleared for event" << eventId;
                } else if (!cleanLayout.isEmpty()) {
                    // Update autoCut based on selected layout aspect
                    int w = getLayoutWidth(cleanLayout), h = getLayoutHeight(cleanLayout);
                    if (w > 0 && h > 0) {
                        double aspect = (double)w / h;
                        // QW410: chỉ cut layout 5×10 (0.38 < aspect ≤ 0.55), không cut 5×15 (≤ 0.38), không cut 15×5 (> 2.0)
                        // RX1/620S: cut khi aspect ≤ 0.45 (5×15) HOẶC aspect > 2.0 (15×5)
                        bool newAutoCut = isQW410 ? (aspect > 0.38 && aspect <= 0.55)
                                                  : (aspect <= 0.45 || aspect > 2.0);
                        if (ev.autoCut != newAutoCut) {
                            ev.autoCut = newAutoCut;
                            m_dbManager->updateEvent(ev);
                            qDebug() << "[EventManager] reprocessLayoutForEvent: autoCut="
                                     << newAutoCut << "for event" << eventId;
                        }
                    }
                }
            }
            m_eventModel->refresh();
            emit eventLayoutNormalised(eventId, processed);
            qDebug() << "[EventManager] reprocessLayoutForEvent: done event" << eventId
                     << "processed=" << processed << "deleted=" << deletedPaths.size();
        }, Qt::QueuedConnection);
    });
}

void EventManager::reprocessAllLayouts() {
    QString dpi = "300dpi";
    if (m_printerConfig) {
        dpi = m_printerConfig->resolution();
    }

    qDebug() << "=========================================";
    qDebug() << "[EventManager] *** REPROCESS ALL LAYOUTS CALLED ***";
    qDebug() << "[EventManager] Target DPI:" << dpi;
    qDebug() << "=========================================";


    // 1. Collect all layout tasks on main thread (fast operation)
    struct LayoutTask {
        QString pngPath;
        QString jsonPath;
        QString fileName;
        int eventId;
    };
    QList<LayoutTask> tasks;

    int eventCount = m_eventModel->rowCount();
    qDebug() << "[EventManager] Scanning" << eventCount << "events for layouts";

    for (int i = 0; i < eventCount; ++i) {
        int eventId = m_eventModel->getEventId(i);
        Event event = m_dbManager->getEvent(eventId);
        if (event.id == 0) {
            qDebug() << "[EventManager] Event" << i << "- Invalid event ID, skipping";
            continue;
        }

        qDebug() << "[EventManager] Event" << eventId << "(" << event.name << ") - rawPath:" << event.rawPath;

        // Find layouts directory
        QDir dir(event.rawPath);
        if (dir.dirName() == "Originals") dir.cdUp();
        QDir layoutDir(dir.filePath("Layouts"));

        qDebug() << "[EventManager] Looking for layouts in:" << layoutDir.absolutePath();

        if (!layoutDir.exists()) {
            qDebug() << "[EventManager] Layouts directory does NOT exist, skipping";
            continue;
        }

        // Collect all PNG layout paths
        QStringList filters;
        filters << "*.png";
        QFileInfoList files = layoutDir.entryInfoList(filters, QDir::Files);

        qDebug() << "[EventManager] Found" << files.size() << "PNG files in Layouts directory";

        for (const QFileInfo &fi : files) {
            LayoutTask task;
            task.pngPath = fi.absoluteFilePath();
            task.jsonPath = task.pngPath;
            int lastDot = task.jsonPath.lastIndexOf('.');
            if (lastDot != -1) task.jsonPath = task.jsonPath.left(lastDot);
            task.jsonPath += ".json";
            task.fileName = fi.fileName();
            task.eventId = eventId;
            tasks.append(task);

            qDebug() << "[EventManager]   - Layout:" << task.fileName << "| PNG:" << task.pngPath;
        }
    }

    qDebug() << "=========================================";
    qDebug() << "[EventManager] *** TOTAL LAYOUTS TO PROCESS:" << tasks.size() << "***";
    qDebug() << "=========================================";


    // Always emit start signal even if no tasks (to show dialog for autoCut update)
    int totalTasks = qMax(tasks.size(), 1);  // At least 1 for UI feedback
    emit layoutReprocessStarted(totalTasks);

    if (tasks.isEmpty()) {
        qDebug() << "[EventManager] No layouts found, but updating autoCut thresholds";
        // Still update autoCut even if no layouts need resizing
        QTimer::singleShot(100, this, [this]() {
            updateAutoCutForAllEvents();
            m_eventModel->refresh();
            emit layoutReprocessFinished(0);
        });
        return;
    }

    qDebug() << "[EventManager] Starting async reprocess of" << tasks.size() << "layouts";

    // 2. Run in background thread using QtConcurrent
    QString printerHint = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    (void)QtConcurrent::run([this, tasks, dpi, printerHint]() {
        int processed = 0;

        for (const LayoutTask &task : tasks) {
            // Process layout in worker thread — pass printer hint for QW410-aware scaling
            bool success = m_layoutAnalyzer->processLayout(task.pngPath, task.jsonPath, dpi, printerHint);

            if (success) {
                processed++;
            }

            // Emit progress (thread-safe via QMetaObject::invokeMethod)
            QMetaObject::invokeMethod(this, [this, processed, total = tasks.size(), fileName = task.fileName]() {
                emit layoutReprocessProgress(processed, total, fileName);
            }, Qt::QueuedConnection);
        }

        // Emit finished (thread-safe)
        QMetaObject::invokeMethod(this, [this, processed, dpi, tasks]() {
            // Update autoCut for all events (on main thread)
            updateAutoCutForAllEvents();
            m_eventModel->refresh();
            emit layoutReprocessFinished(processed);
            qDebug() << "[EventManager] Reprocessed" << processed << "layouts for DPI:" << dpi;

            // QW410 scaling is handled directly in processLayout via printerHint
        }, Qt::QueuedConnection);
    });
}

void EventManager::updateAutoCutForAllEvents() {
    int eventCount = m_eventModel->rowCount();

    for (int i = 0; i < eventCount; ++i) {
        int eventId = m_eventModel->getEventId(i);
        Event event = m_dbManager->getEvent(eventId);
        if (event.id == 0) continue;

        if (!event.selectedLayout.isEmpty()) {
            int w = getLayoutWidth(event.selectedLayout);
            int h = getLayoutHeight(event.selectedLayout);

            bool newAutoCut = false;
            if (w > 0 && h > 0) {
                double aspect = (double)w / (double)h;
                // RX1/620S: 5×15 dọc (≤0.45) hoặc 15×5 ngang (>2.0)
                // QW410 không dùng hàm này (hàm này chỉ chạy cho RX1/620S path)
                newAutoCut = (aspect <= 0.45 || aspect > 2.0);
            }

            if (event.autoCut != newAutoCut) {
                event.autoCut = newAutoCut;
                m_dbManager->updateEvent(event);
                qDebug() << "[EventManager] Event" << eventId << "autoCut updated to" << newAutoCut
                         << "(layout:" << w << "x" << h
                         << ", aspect:" << (h > 0 ? (double)w/h : 0.0) << ")";
            }
        }
    }
}

bool EventManager::uploadLandingBackground(int eventId, const QString &filePath) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        emit error("Event not found");
        return false;
    }

    // Get Backgrounds directory path using AppPaths
    QString backgroundDirPath = AppPaths::instance().getEventBackgroundsPath(event.name);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(backgroundDirPath, &errorMsg)) {
        emit this->error("Failed to create Backgrounds directory: " + errorMsg);
        return false;
    }

    // Clean input path (remove file:/// prefix)
    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) {
        sourcePath = sourcePath.mid(8);
    }

    QFileInfo fi(sourcePath);
    if (!fi.exists()) {
        emit error("Source file not found: " + sourcePath);
        return false;
    }

    // Generate filename: landing_bg.{ext}
    QString destFileName = QString("landing_bg.%1").arg(fi.suffix());
    QString destPath = QDir(backgroundDirPath).filePath(destFileName);

    // Copy file (overwrite if exists)
    if (QFile::exists(destPath)) QFile::remove(destPath);
    if (!QFile::copy(sourcePath, destPath)) {
        emit error("Failed to copy background file");
        return false;
    }

    // Update database
    event.landingBackground = destPath;
    if (!m_dbManager->updateEvent(event)) {
        emit error("Failed to update event in database");
        return false;
    }

    m_eventModel->refresh();
    emit backgroundUploaded(eventId, "landing");
    emit error("Landing background uploaded successfully!"); // Info toast
    return true;
}

bool EventManager::uploadModeSelectionBackground(int eventId, const QString &filePath) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        emit error("Event not found");
        return false;
    }

    // Get Backgrounds directory path using AppPaths
    QString backgroundDirPath = AppPaths::instance().getEventBackgroundsPath(event.name);
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(backgroundDirPath, &errorMsg)) {
        emit this->error("Failed to create Backgrounds directory: " + errorMsg);
        return false;
    }

    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) {
        sourcePath = sourcePath.mid(8);
    }

    QFileInfo fi(sourcePath);
    if (!fi.exists()) {
        emit error("Source file not found: " + sourcePath);
        return false;
    }

    QString destFileName = QString("mode_selection_bg.%1").arg(fi.suffix());
    QString destPath = QDir(backgroundDirPath).filePath(destFileName);

    if (QFile::exists(destPath)) QFile::remove(destPath);
    if (!QFile::copy(sourcePath, destPath)) {
        emit error("Failed to copy background file");
        return false;
    }

    event.modeSelectionBackground = destPath;
    if (!m_dbManager->updateEvent(event)) {
        emit error("Failed to update event in database");
        return false;
    }

    m_eventModel->refresh();
    emit backgroundUploaded(eventId, "modeSelection");
    emit error("Mode Selection background uploaded successfully!");
    return true;
}

QString EventManager::getLandingBackground(int eventId) {
    Event event = m_dbManager->getEvent(eventId);
    if (!event.landingBackground.isEmpty()) {
        return "file:///" + event.landingBackground;
    }
    return ""; // Empty = use default gradient
}

QString EventManager::getModeSelectionBackground(int eventId) {
    Event event = m_dbManager->getEvent(eventId);
    if (!event.modeSelectionBackground.isEmpty()) {
        return "file:///" + event.modeSelectionBackground;
    }
    return "";
}

// ============= Global App Settings =============

// Marker phân biệt "key không tồn tại trong DB" với "key có giá trị rỗng".
// Ký tự điều khiển 0x01 chắc chắn không xuất hiện trong giá trị setting thật.
static const QString kSettingAbsent = QStringLiteral("\x01__ABSENT__\x01");

// Các key luôn ở phạm vi global, KHÔNG tách theo sự kiện:
//  - Bảo mật/quyền: PIN hash, legacy admin_pin, staff_lock_pin, security_enabled, staff_locked_tabs
//  - Phần cứng/hiển thị của máy: live-view limits, hướng/tỉ lệ màn hình, cổng bill acceptor
//  - Định danh merchant/thanh toán dùng chung: tài khoản ngân hàng, SePay key
//  - Nền dashboard (không thuộc sự kiện nào)
// Mọi key khác trong app_settings sẽ tách riêng theo sự kiện đang active.
const QSet<QString> EventManager::kMachineGlobalKeys = {
    QStringLiteral("admin_pin"),
    QStringLiteral("security_pin_hash"),
    QStringLiteral("security_pin_salt"),
    QStringLiteral("security_pin_iterations"),
    QStringLiteral("staff_lock_pin"),
    QStringLiteral("security_enabled"),
    QStringLiteral("app_open_security_enabled"),
    // Yêu cầu đăng nhập khi mở app là cấp máy (kiểm tra lúc khởi động ở scope
    // global). Nếu lưu theo sự kiện, tắt trong Cài đặt sẽ không có tác dụng khi
    // mở app vì startup đọc giá trị global → vẫn bắt đăng nhập.
    QStringLiteral("login_required"),
    // Chế độ vận hành là cấp máy (không gắn theo sự kiện) — nếu lưu theo sự kiện,
    // sau khi xoá hết sự kiện sẽ mất, app lại rơi về mode1/Dashboard.
    QStringLiteral("app_operation_mode"),
    QStringLiteral("payment_enabled"),
    QStringLiteral("multi_event_enabled"),
    // Sự kiện vừa dùng (cấp máy) → khởi động chế độ một sự kiện sẽ fallback về đây,
    // tránh trạng thái "chưa chọn sự kiện". Phải global, không tách theo sự kiện.
    QStringLiteral("last_event_id"),
    QStringLiteral("global_background_enabled"),
    QStringLiteral("global_background_image"),
    QStringLiteral("staff_locked_tabs"),
    QStringLiteral("camera_type"),
    QStringLiteral("capture_source"),
    QStringLiteral("hotfolder_kind"),
    QStringLiteral("hotfolder_folder_path"),
    QStringLiteral("liveview_source"),
    QStringLiteral("liveview_webcam_index"),
    QStringLiteral("live_view_max_width"),
    QStringLiteral("live_view_target_fps"),
    QStringLiteral("fuji_live_view_size"),
    QStringLiteral("fuji_live_view_quality"),
    QStringLiteral("external_live_view_enabled"),
    QStringLiteral("external_live_view_screen_index"),
    QStringLiteral("external_live_view_mock_enabled"),
    QStringLiteral("external_photo_wall_enabled"),
    QStringLiteral("external_photo_wall_screen_index"),
    QStringLiteral("external_windows_fullscreen"),
    // Qu?y thu ng�n LAN l� c?p M�Y: main.cpp d?c global l�c kh?i d?ng d? quy?t d?nh
    // bind LAN + PIN. N?u luu theo s? ki?n, startup d?c global ? lu�n t?t. Ph?i global.
    QStringLiteral("lan_pickup_enabled"),
    QStringLiteral("lan_pickup_pin"),
    QStringLiteral("screen_orientation"),
    QStringLiteral("screen_aspect_ratio"),
    // Cách xử lý vùng bleed khi ghép tấm in cắt ("fill" | "safe"). Là đặc tính của
    // MÁY IN + cách canh giấy của từng máy, không phải của sự kiện → phải global.
    QStringLiteral("cut_bleed_mode"),
    QStringLiteral("bill_acceptor_port"),
    QStringLiteral("dashboard_bg_image"),
    QStringLiteral("landing_background"),
    QStringLiteral("payment_bank_id"),
    QStringLiteral("payment_account_no"),
    QStringLiteral("payment_account_name"),
    QStringLiteral("payment_sepay_key"),
    QStringLiteral("payment_provider"),
    QStringLiteral("payment_payos_client_id"),
    QStringLiteral("payment_payos_api_key"),
    QStringLiteral("payment_payos_checksum_key"),
    QStringLiteral("payment_payos_return_url"),
    QStringLiteral("payment_payos_cancel_url"),
    QStringLiteral("payment_va_account_no"),
    // Giá & số lượng in là cấu hình thanh toán cấp máy (như tài khoản ngân hàng),
    // KHÔNG tách theo sự kiện — nếu tách, sửa giá ở 1 sự kiện sẽ không áp dụng cho
    // phiên booth chạy sự kiện khác (vd studio2/studio3), gây "đổi giá mà không cập nhật".
    QStringLiteral("print_options_cut"),
    QStringLiteral("print_options_nocut"),
    QStringLiteral("print_option4_cut_enabled"),
    QStringLiteral("print_option4_nocut_enabled"),
    // In t? do (Free Print): m�y in l� ph?n c?ng d�ng chung ? c?p m�y, kh�ng t�ch
    // theo s? ki?n. B?t/m�y in d�ch/d? xoay d?u c?p m�y nhu print_options_*.
    QStringLiteral("free_print_enabled"),
    QStringLiteral("free_print_printer"),
    QStringLiteral("free_print_rotation"),
    // Chế độ tính tiền (theo số lượng ảnh hay theo giá nhóm khung) là cấp máy —
    // nhất quán với payment_enabled / print_options_*. Giá từng nhóm (cate_price_*)
    // vẫn theo sự kiện.
    QStringLiteral("pricing_by_category_enabled"),
    // Live view làm nền ở màn Landing — bật trước khi chọn sự kiện nên là cấp máy.
    QStringLiteral("landing_liveview_enabled"),
    // Đăng nhập/mở khóa bằng mã QR (quét từ portal) — cấp máy như login_required.
    QStringLiteral("qr_login_enabled"),
    QStringLiteral("qr_security_enabled"),
    // Phương thức bảo mật chung (pin/qr/both) — cấp máy như security_enabled.
    QStringLiteral("security_method"),
    // Lượt đăng nhập QR gần nhất (hiển thị ở tab Thông tin) — thuộc máy, không thuộc sự kiện.
    QStringLiteral("last_qr_login_email"),
    QStringLiteral("last_qr_login_name"),
    QStringLiteral("last_qr_login_role"),
    QStringLiteral("last_qr_login_at"),
    QStringLiteral("cloud_staff_accounts"),
    QStringLiteral("employee_permissions"),
};

void EventManager::setActiveEventId(int eventId) {
    // Giá trị per-event được phân giải trực tiếp qua cache (event,key) của
    // DatabaseManager, còn m_settingsCache ở đây chỉ chứa giá trị global, nên
    // không cần xoá cache khi đổi sự kiện.
    m_activeEventId = eventId;
}

bool EventManager::setAppSetting(const QString &key, const QString &value) {
    // Định tuyến theo sự kiện: ghi override cho sự kiện đang active (trừ key máy).
    if (m_activeEventId > 0 && !kMachineGlobalKeys.contains(key)) {
        bool ok = m_dbManager->setEventSetting(m_activeEventId, key, value);
        if (ok)
            emit appSettingChanged(key, value);
        return ok;
    }

    bool ok = m_dbManager->setSetting(key, value);
    if (ok) {
        m_settingsCache.insert(key, value);   // giữ cache đồng bộ với DB
        emit appSettingChanged(key, value);
    }
    return ok;
}

bool EventManager::setAppSettingForEvent(int eventId, const QString &key, const QString &value) {
    if (eventId > 0 && !kMachineGlobalKeys.contains(key)) {
        const bool ok = m_dbManager->setEventSetting(eventId, key, value);
        if (ok)
            emit appSettingChanged(key, value);
        return ok;
    }
    return setAppSetting(key, value);
}

QString EventManager::securityMethod() {
    const QString stored = getAppSetting(QStringLiteral("security_method"), QString());
    if (stored == QLatin1String("pin") || stored == QLatin1String("qr") ||
        stored == QLatin1String("both"))
        return stored;

    // Chưa từng đặt → suy ra từ 2 toggle QR cũ để máy đang chạy không đổi hành vi.
    const bool qrOn =
        getAppSetting(QStringLiteral("qr_security_enabled"), QStringLiteral("false")) == QLatin1String("true") ||
        getAppSetting(QStringLiteral("qr_login_enabled"), QStringLiteral("false")) == QLatin1String("true");
    return qrOn ? QStringLiteral("both") : QStringLiteral("pin");
}

bool EventManager::setSecurityMethod(const QString &method) {
    QString m = method.trimmed().toLower();
    if (m != QLatin1String("qr") && m != QLatin1String("both"))
        m = QStringLiteral("pin");

    bool ok = setAppSetting(QStringLiteral("security_method"), m);
    // Ghi đồng bộ 2 key cũ để các nơi còn đọc chúng vẫn đúng.
    const QString qrOn = (m == QLatin1String("pin")) ? QStringLiteral("false")
                                                     : QStringLiteral("true");
    ok = setAppSetting(QStringLiteral("qr_login_enabled"), qrOn) && ok;
    ok = setAppSetting(QStringLiteral("qr_security_enabled"), qrOn) && ok;
    return ok;
}

bool EventManager::verifySecurityPin(const QString &pin) {
    const QString trimmed = pin.trimmed();
    if (!isSecurityPinFormat(trimmed))
        return false;

    const QString hash = m_dbManager->getSetting(QStringLiteral("security_pin_hash"), QString()).trimmed();
    const QString salt = m_dbManager->getSetting(QStringLiteral("security_pin_salt"), QString()).trimmed();
    const int iterations = m_dbManager->getSetting(
        QStringLiteral("security_pin_iterations"),
        QString::number(kSecurityPinIterations)).toInt();

    if (!hash.isEmpty() && !salt.isEmpty()) {
        const QByteArray actual = securityPinHashHex(trimmed, salt, iterations);
        return constantTimeEqual(actual, hash.toLatin1());
    }

    // Legacy migration: old versions stored the admin PIN as plaintext in
    // app_settings.admin_pin. Accept it once, then replace it with hash+salt.
    const QString legacyPin = m_dbManager->getSetting(QStringLiteral("admin_pin"), QStringLiteral("0000"));
    if (trimmed != legacyPin)
        return false;

    const QString newSalt = randomSaltHex();
    const QString newHash = QString::fromLatin1(
        securityPinHashHex(trimmed, newSalt, kSecurityPinIterations));
    bool ok = m_dbManager->setSetting(QStringLiteral("security_pin_salt"), newSalt);
    ok = m_dbManager->setSetting(QStringLiteral("security_pin_hash"), newHash) && ok;
    ok = m_dbManager->setSetting(QStringLiteral("security_pin_iterations"),
                                 QString::number(kSecurityPinIterations)) && ok;
    ok = m_dbManager->setSetting(QStringLiteral("admin_pin"), QString()) && ok;
    if (!ok)
        qWarning() << "[Security] Failed to migrate legacy admin_pin";
    return true;
}

QString EventManager::setSecurityPin(const QString &currentPin, const QString &newPin) {
    const QString next = newPin.trimmed();
    if (!isSecurityPinFormat(next))
        return QStringLiteral("PIN mới phải gồm 4-6 chữ số");
    if (!verifySecurityPin(currentPin))
        return QStringLiteral("PIN hiện tại không đúng");

    const QString salt = randomSaltHex();
    const QString hash = QString::fromLatin1(
        securityPinHashHex(next, salt, kSecurityPinIterations));
    bool ok = m_dbManager->setSetting(QStringLiteral("security_pin_salt"), salt);
    ok = m_dbManager->setSetting(QStringLiteral("security_pin_hash"), hash) && ok;
    ok = m_dbManager->setSetting(QStringLiteral("security_pin_iterations"),
                                 QString::number(kSecurityPinIterations)) && ok;
    ok = m_dbManager->setSetting(QStringLiteral("admin_pin"), QString()) && ok;
    if (!ok)
        return QStringLiteral("Không lưu được PIN bảo mật");
    return QString();
}

bool EventManager::enterAdminWithoutPassword() {
    m_currentEmployeeId = -1;
    m_currentEmployeeName = QStringLiteral("Admin");
    emit currentEmployeeChanged();
    return true;
}

QString EventManager::getLocalIpAddress() const {
    // Uu ti�n IPv4 private (192.168.*, 10.*, 172.16�31.*) tr�n interface dang ch?y,
    // b? loopback/?o. Tr? v? c�i d?u ti�n t�m du?c.
    const auto ifaces = QNetworkInterface::allInterfaces();
    for (const auto &iface : ifaces) {
        const auto flags = iface.flags();
        if (!flags.testFlag(QNetworkInterface::IsUp) ||
            !flags.testFlag(QNetworkInterface::IsRunning) ||
            flags.testFlag(QNetworkInterface::IsLoopBack))
            continue;
        for (const auto &entry : iface.addressEntries()) {
            const QHostAddress ip = entry.ip();
            if (ip.protocol() != QAbstractSocket::IPv4Protocol) continue;
            if (ip.isLoopback()) continue;
            const QString s = ip.toString();
            if (s.startsWith("169.254.")) continue;  // APIPA (chua c� DHCP)
            return s;
        }
    }
    return QString();
}

// ── Chế độ bleed của tấm in cắt ─────────────────────────────────────────────
// Lưu ở app setting "cut_bleed_mode" (machine-global). Mặc định "fill" —
// khớp cách làm phổ biến ngoài thực tế (gửi canvas phủ kín, để máy in xén rìa).
QString EventManager::cutBleedMode()
{
    const QString v = getAppSetting(QStringLiteral("cut_bleed_mode"),
                                    QStringLiteral("fill")).trimmed().toLower();
    return (v == QStringLiteral("safe")) ? QStringLiteral("safe")
                                         : QStringLiteral("fill");
}

bool EventManager::setCutBleedMode(const QString &mode)
{
    const QString v = (mode.trimmed().toLower() == QStringLiteral("safe"))
                          ? QStringLiteral("safe") : QStringLiteral("fill");
    const bool ok = setAppSetting(QStringLiteral("cut_bleed_mode"), v);
    if (ok)
        ImageCompositor::setCutBleedMode(v == QStringLiteral("safe")
                                             ? CutBleedMode::SafeMargin
                                             : CutBleedMode::FillToEdge);
    return ok;
}

void EventManager::applyCutBleedModeFromSettings()
{
    const QString v = cutBleedMode();
    ImageCompositor::setCutBleedMode(v == QStringLiteral("safe")
                                         ? CutBleedMode::SafeMargin
                                         : CutBleedMode::FillToEdge);
}

QString EventManager::getAppSetting(const QString &key, const QString &defaultValue) {
    auto globalSetting = [this](const QString &settingKey,
                                const QString &fallback = QString()) {
        auto it = m_settingsCache.constFind(settingKey);
        if (it == m_settingsCache.constEnd()) {
            QString value = m_dbManager->getSetting(settingKey, kSettingAbsent);
            it = m_settingsCache.insert(settingKey, value);
        }
        return (it.value() == kSettingAbsent) ? fallback : it.value();
    };

    // Nền chung chỉ ưu tiên khi đọc các key ảnh nền. Các giá trị nền riêng vẫn
    // được giữ nguyên trong DB và tự dùng lại khi tắt global_background_enabled.
    const bool isBackgroundImageKey =
        key != QStringLiteral("global_background_image") &&
        key != QStringLiteral("app_bg_color") &&
        (key == QStringLiteral("dashboard_bg_image") ||
         key == QStringLiteral("landing_background") ||
         key.contains(QStringLiteral("_bg_")) ||
         key.endsWith(QStringLiteral("_bg")) ||
         key.endsWith(QStringLiteral("_bg_image")) ||
         key.startsWith(QStringLiteral("selfbooth_bg_")));
    if (isBackgroundImageKey &&
        globalSetting(QStringLiteral("global_background_enabled"),
                      QStringLiteral("false")) == QStringLiteral("true")) {
        const QString globalPath =
            globalSetting(QStringLiteral("global_background_image"));
        if (!globalPath.isEmpty())
            return globalPath;
    }

    // Định tuyến theo sự kiện: ưu tiên override của sự kiện đang active; nếu sự
    // kiện chưa đặt key này thì fallback xuống giá trị global bên dưới.
    if (m_activeEventId > 0 && !kMachineGlobalKeys.contains(key)) {
        QString ev = m_dbManager->getEventSettingRaw(m_activeEventId, key);
        if (ev != DatabaseManager::kEventSettingAbsent)
            return ev;
    }

    // Global: đọc DB đúng MỘT lần cho mỗi key; các lần sau lấy từ cache RAM.
    // getAppSetting() được gọi rất nhiều trong QML binding → tránh spam SQLite
    // trên main thread.
    auto it = m_settingsCache.constFind(key);
    if (it == m_settingsCache.constEnd()) {
        QString v = m_dbManager->getSetting(key, kSettingAbsent);
        it = m_settingsCache.insert(key, v);
    }
    const QString &cached = it.value();
    return (cached == kSettingAbsent) ? defaultValue : cached;
}

void EventManager::seedDefaultAppSettings() {
    // Tr?ng th�i b?t/t?t m?c d?nh khi m? app l?n d?u. CH? ghi khi key chua t?n
    // t?i trong DB (chua t?ng du?c d?t) ? kh�ng d� gi� tr? ngu?i d�ng d� luu,
    // k? c? khi h? ch? d?ng t?t m?t t�nh nang tru?c d�.
    static const QList<QPair<QString, QString>> kDefaults = {
        // -- C�i d?t chung --------------------------------------------------
        { QStringLiteral("qr_code_enabled"),               QStringLiteral("true")  }, // g?n m� QR l�n ?nh
        { QStringLiteral("payment_enabled"),               QStringLiteral("true")  }, // cho ph�p thanh to�n
        { QStringLiteral("relay_enabled"),                 QStringLiteral("true")  }, // b?t relay
        { QStringLiteral("frame_selection_enabled"),       QStringLiteral("false") }, // t?t ch?n khung sau khi ch?p
        { QStringLiteral("capture_count_follow_frame"),    QStringLiteral("true")  },
        // -- C�i d?t m�y ?nh / m�n h�nh ph? ---------------------------------
        { QStringLiteral("external_live_view_enabled"),    QStringLiteral("true")  }, // live view HDMI
        { QStringLiteral("external_photo_wall_enabled"),   QStringLiteral("true")  }, // photo wall
        { QStringLiteral("external_windows_fullscreen"),   QStringLiteral("true")  }, // fullscreen c?a s? ph?
        { QStringLiteral("landing_liveview_enabled"),      QStringLiteral("false") }, // t?t live view background
        { QStringLiteral("external_live_view_mock_enabled"), QStringLiteral("false") }, // t?t mock test HDMI
        // -- Voucher + Thanh to�n -------------------------------------------
        { QStringLiteral("voucher_enabled"),               QStringLiteral("true")  }, // s? d?ng voucher
        { QStringLiteral("bank_transfer_enabled"),         QStringLiteral("true")  }, // chuy?n kho?n
        { QStringLiteral("payment_provider"),              QStringLiteral("sepay") },
        { QStringLiteral("cash_payment_enabled"),          QStringLiteral("true")  }, // ti?n m?t
        { QStringLiteral("cash_payment_code_enabled"),     QStringLiteral("true")  }, // m� ti?n m?t
        { QStringLiteral("prepaid_package_enabled"),       QStringLiteral("false") }, // m� g�i ch?p tr? tru?c
        // -- Filter / sticker ------------------------------------------------
        { QStringLiteral("filter_enabled"),                QStringLiteral("true")  },
        { QStringLiteral("sticker_enabled"),               QStringLiteral("true")  },
    };

    for (const auto &kv : kDefaults) {
        if (m_dbManager->getSetting(kv.first, kSettingAbsent) != kSettingAbsent)
            continue;   // d� c� gi� tr? ? t�n tr?ng l?a ch?n hi?n t?i
        m_dbManager->setSetting(kv.first, kv.second);
        m_settingsCache.insert(kv.first, kv.second);   // gi? cache d?ng b? v?i DB
    }
}

bool EventManager::setGlobalLandingBackground(const QString &filePath) {
    QString normalizedPath = QDir::toNativeSeparators(filePath);
    qDebug() << "[EventManager] Setting global landing background:" << normalizedPath;
    bool ok = m_dbManager->setSetting("landing_background", normalizedPath);
    if (ok)
        m_settingsCache.insert("landing_background", normalizedPath);  // giữ cache đồng bộ
    return ok;
}

QString EventManager::getGlobalLandingBackground() {
    QString path;
    if (getAppSetting(QStringLiteral("global_background_enabled"),
                      QStringLiteral("false")) == QStringLiteral("true")) {
        path = getAppSetting(QStringLiteral("global_background_image"));
    }
    if (path.isEmpty())
        path = m_dbManager->getSetting("landing_background", "");
    if (!path.isEmpty()) {
        if (path.startsWith(QStringLiteral("file:")) ||
            path.startsWith(QStringLiteral("qrc:")) ||
            path.startsWith(QStringLiteral("http:")) ||
            path.startsWith(QStringLiteral("https:")))
            return path;
        return "file:///" + path;
    }
    return "";
}

QString EventManager::getSelfBoothBaseDir() const {
    QString picturesPath = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    QString selfBoothDir = QDir(picturesPath).filePath("Photobooth/SelfBooth");
    QDir().mkpath(selfBoothDir);
    return selfBoothDir;
}

void EventManager::printPhotoFromGallery(int eventId, const QString &photoPath) {
    if (!m_printerManager) {
        qWarning() << "[EventManager] PrinterManager not set, cannot print";
        emit error("Printer manager not available");
        return;
    }

    if (!m_printerConfig) {
        qWarning() << "[EventManager] PrinterConfig not set, cannot print";
        emit error("Printer config not available");
        return;
    }

    // Clean file path
    QString cleanPath = photoPath;
    if (cleanPath.startsWith("file:///")) {
        cleanPath = cleanPath.mid(8);
    } else if (cleanPath.startsWith("file://")) {
        cleanPath = cleanPath.mid(7);
    }

    qDebug() << "[EventManager] Printing photo from gallery:";
    qDebug() << "  Original path:" << photoPath;
    qDebug() << "  Clean path:" << cleanPath;

    // Load image to get dimensions
    QImage image(cleanPath);
    if (image.isNull()) {
        qCritical() << "[EventManager] Failed to load image for printing:" << cleanPath;
        emit error("Cannot load image file");
        return;
    }

    int width = image.width();
    int height = image.height();
    bool isPortrait = (height > width);

    qDebug() << "  Image size:" << width << "x" << height;
    qDebug() << "  Orientation:" << (isPortrait ? "Portrait" : "Landscape");

    // Get event details for paper size
    Event event = m_dbManager->getEvent(eventId);
    QString paperSize = "6x4";  // Default
    if (event.id > 0 && !event.selectedLayout.isEmpty()) {
        paperSize = getPaperSizeFromLayout(event.selectedLayout);
    }

    // Get DPI and print settings
    QString dpi = m_printerConfig->resolution();
    int quality = (dpi == "600dpi") ? 600 : 300;
    int copies = m_printerConfig->printCopies();

    // Calculate autoCut
    // Logic:
    // 1. If printing a Collage (in Final path), respect the Event's autoCut setting from DB.
    // 2. If printing an Original (in Originals path), use dimension-based detection.
    int cutThreshold = getAutoCutThreshold();
    bool cutMode = false;

    QString finalPathNative = QDir::toNativeSeparators(event.finalPath);
    QString cleanPathNative = QDir::toNativeSeparators(cleanPath);

    // Check if file is in Final folder (Collage)
    // We use a loose check (contains) or strictly startsWith? 
    // QFileInfo::dir() is safer.
    QFileInfo fileInfo(cleanPath);
    QString parentDir = fileInfo.dir().path(); // This returns generic separators usually (/)
    
    // Normalize for comparison
    bool isCollage = (QDir::toNativeSeparators(parentDir).contains(QDir::toNativeSeparators("Final"), Qt::CaseInsensitive));

    // printerConfig.cutMode là nguồn sự thật duy nhất cho việc có cắt hay không.
    // Đồng bộ với ResultScreen: cutMode = event.autoCut && printerConfig.cutMode
    bool printerCutEnabled = m_printerConfig->cutMode();

    if (isCollage) {
        cutMode = event.autoCut && printerCutEnabled;
        qDebug() << "  [AutoCut] Collage (Final folder). event.autoCut:" << event.autoCut
                 << "printerConfig.cutMode:" << printerCutEnabled << "-> cutMode:" << cutMode;
    } else {
        // Original photo: detect by aspect ratio (short side heuristic)
        // 2x6" strip image will have a very narrow aspect (portrait with W:H ≈ 1:3)
        double aspect = (width > 0 && height > 0)
                        ? (double)qMin(width, height) / (double)qMax(width, height)
                        : 1.0;  // shortSide / longSide
        // A 2x6" strip has shortSide/longSide ≈ 0.333; 4x6" ≈ 0.667
        cutMode = (aspect <= 0.45) && printerCutEnabled;
        qDebug() << "  [AutoCut] Original photo. Size:" << width << "x" << height
                 << "short/long aspect:" << aspect << "printerConfig.cutMode:" << printerCutEnabled
                 << "-> cut:" << cutMode;
    }

    qDebug() << "  DPI:" << dpi << "| Quality:" << quality << "| Cut threshold:" << cutThreshold;
    qDebug() << "  Paper size:" << paperSize << "| Copies:" << copies;
    qDebug() << "  Cut mode:" << cutMode;

    // Calculate actual photo count considering cut mode
    // If cut mode: 1 print job = 2 physical photos (due to cutting)
    // If no cut: 1 print job = 1 physical photo
    int actualPhotoCount = copies * (cutMode ? 2 : 1);

    // Store pending print info for tracking when print finishes
    m_pendingGalleryPrintEventId = eventId;
    m_pendingGalleryPhotoCount = actualPhotoCount;
    m_pendingGalleryCutMode = cutMode;

    // Print using PrinterManager
    bool matteFinish = false;  // Default to glossy
    m_printerManager->printImageWithSettings(
        cleanPath,
        copies,
        paperSize,
        quality,
        cutMode,
        matteFinish
    );

    qDebug() << "[EventManager] Print job sent to printer (actual photo count for tracking:" << actualPhotoCount << ")";
}

void EventManager::printPhotoFromGalleryWithOptions(int eventId, const QString &photoPath,
                                                     int copies, bool cutMode) {
    if (!m_printerManager) {
        qWarning() << "[EventManager] PrinterManager not set, cannot print";
        emit error("Printer manager not available");
        return;
    }
    if (!m_printerConfig) {
        qWarning() << "[EventManager] PrinterConfig not set, cannot print";
        emit error("Printer config not available");
        return;
    }

    // Clean file path
    QString cleanPath = photoPath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://"))  cleanPath = cleanPath.mid(7);

    qDebug() << "[EventManager] printPhotoFromGalleryWithOptions:";
    qDebug() << "  Path:"     << cleanPath;
    qDebug() << "  Copies:"   << copies;
    qDebug() << "  CutMode:"  << cutMode;

    // Validate image file exists (avoid loading full QImage on main thread)
    if (!QFileInfo::exists(cleanPath)) {
        qCritical() << "[EventManager] Image file not found:" << cleanPath;
        emit error("Cannot load image file");
        return;
    }

    // Get paper size from event layout
    Event event = m_dbManager->getEvent(eventId);
    QString paperSize = "6x4";
    if (event.id > 0 && !event.selectedLayout.isEmpty())
        paperSize = getPaperSizeFromLayout(event.selectedLayout);

    QString dpi     = m_printerConfig->resolution();
    int     quality = (dpi == "600dpi") ? 600 : 300;

    // Calculate actual photo count for tracking
    int actualPhotoCount = copies * (cutMode ? 2 : 1);
    m_pendingGalleryPrintEventId = eventId;
    m_pendingGalleryPhotoCount   = actualPhotoCount;
    m_pendingGalleryCutMode      = cutMode;

    bool matteFinish = false;
    m_printerManager->printImageWithSettings(cleanPath, copies, paperSize, quality, cutMode, matteFinish);

    qDebug() << "[EventManager] Print job sent (actualPhotoCount:" << actualPhotoCount << ")";
}

void EventManager::incrementPrintCount(int eventId, int photoCount, bool cutMode) {
    if (eventId <= 0 || photoCount <= 0) {
        qWarning() << "[EventManager] Invalid parameters for incrementPrintCount: eventId=" << eventId << "photoCount=" << photoCount;
        return;
    }

    if (m_dbManager->incrementPrintCount(eventId, photoCount, cutMode)) {
        qDebug() << "[EventManager] Print count incremented for event" << eventId << "by" << photoCount
                 << "photos" << (cutMode ? "(cut)" : "(no-cut)");
        emit printCountChanged(eventId);
        syncEventToDynamoDB(eventId);
    } else {
        qWarning() << "[EventManager] Failed to increment print count for event" << eventId;
    }
}

int EventManager::getEventPrintCount(int eventId) const {
    if (eventId <= 0) {
        qWarning() << "[EventManager] Invalid eventId for getEventPrintCount:" << eventId;
        return 0;
    }
    return m_dbManager->getPrintCount(eventId);
}

int EventManager::getEventCutPrintCount(int eventId) const {
    if (eventId <= 0) return 0;
    return m_dbManager->getCutPrintCount(eventId);
}

int EventManager::getEventNoCutPrintCount(int eventId) const {
    if (eventId <= 0) return 0;
    return m_dbManager->getNoCutPrintCount(eventId);
}

int EventManager::getLastGalleryPrintPhotoCount() const {
    return m_pendingGalleryPhotoCount;
}

bool EventManager::getLastGalleryPrintCutMode() const {
    return m_pendingGalleryCutMode;
}

QVariantList EventManager::getLayouts(int eventId) {
    QVariantList list;
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return list;
    
    QDir dir(event.rawPath);
    if (dir.dirName() == "Originals") dir.cdUp();
    QDir layoutDir(dir.filePath("Layouts"));
    
    if (!layoutDir.exists()) return list;
    
    QStringList filters;
    filters << "*.png";
    QFileInfoList files = layoutDir.entryInfoList(filters, QDir::Files);
    
    for (const QFileInfo &fi : files) {
        QVariantMap map;
        map["fileName"] = fi.fileName();
        map["path"] = "file:///" + fi.absoluteFilePath();
        
        // Load JSON metadata if exists
        QString jsonPath = fi.absoluteFilePath();
        int lastDot = jsonPath.lastIndexOf('.');
        if (lastDot != -1) jsonPath = jsonPath.left(lastDot);
        jsonPath += ".json";
        
        QFile jsonFile(jsonPath);
        if (jsonFile.open(QIODevice::ReadOnly)) {
            QJsonDocument doc = QJsonDocument::fromJson(jsonFile.readAll());
            map["metadata"] = normalizeLayoutMetadataObject(doc.object()).toVariantMap();
            jsonFile.close();
            
            // Add to list only if valid metadata
            list.append(map);
        }
    }
    
    return list;
}

QVariantList EventManager::getPaperLayouts() {
    QVariantList list;
    QDir layoutDir(QDir(AppPaths::instance().getAppDirectory()).filePath("data/PaperLayouts"));
    if (!layoutDir.exists()) return list;

    QFileInfoList files = layoutDir.entryInfoList(QStringList() << "*.png", QDir::Files);
    for (const QFileInfo &fi : files) {
        QVariantMap map;
        map["fileName"] = fi.fileName();
        map["path"] = "file:///" + fi.absoluteFilePath();

        QString jsonPath = fi.absoluteFilePath();
        int lastDot = jsonPath.lastIndexOf('.');
        if (lastDot != -1) jsonPath = jsonPath.left(lastDot);
        jsonPath += ".json";

        QFile jsonFile(jsonPath);
        if (jsonFile.open(QIODevice::ReadOnly)) {
            QJsonDocument doc = QJsonDocument::fromJson(jsonFile.readAll());
            map["metadata"] = normalizeLayoutMetadataObject(doc.object()).toVariantMap();
            jsonFile.close();
        }
        list.append(map);
    }

    return list;
}

bool EventManager::uploadSelfBoothLayout(const QString &filePath) {
    const QString layoutDirPath =
        QDir(AppPaths::instance().getAppDirectory()).filePath("data/SelfBoothLayouts");
    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(layoutDirPath, &errorMsg)) {
        qWarning() << "Failed to ensure SelfBoothLayouts directory:" << errorMsg;
        return false;
    }

    QString sourcePath = filePath;
    if (sourcePath.startsWith("file:///")) sourcePath = sourcePath.mid(8);

    QFileInfo fi(sourcePath);
    if (!fi.exists()) {
        emit error("Source file not found: " + sourcePath);
        return false;
    }

    const QString destPath = uniqueLayoutFilePath(layoutDirPath, fi.fileName());
    if (!QFile::copy(sourcePath, destPath)) {
        emit error("Failed to copy file to Selfbooth frame folder");
        return false;
    }

    const QString dpi = m_printerConfig ? m_printerConfig->resolution() : "300dpi";
    const QString printerName =
        m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    QString jsonPath = QFileInfo(destPath).absolutePath() + "/"
                     + QFileInfo(destPath).completeBaseName() + ".json";

    (void)QtConcurrent::run([this, destPath, jsonPath, dpi, printerName]() {
        const bool ok =
            m_layoutAnalyzer->processLayout(destPath, jsonPath, dpi, printerName);
        QMetaObject::invokeMethod(this, [this, ok]() {
            emit layoutUploaded(-2);
            emit error(ok ? "Selfbooth frame uploaded and processed successfully!"
                          : "Failed to analyse Selfbooth frame slots. Ensure transparency exists.");
        }, Qt::QueuedConnection);
    });
    return true;
}

bool EventManager::deleteSelfBoothLayout(const QString &layoutPath) {
    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);
    if (!QFile::exists(path)) return false;

    QString jsonPath = path;
    const int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    const bool ok = QFile::remove(path);
    if (QFile::exists(jsonPath)) QFile::remove(jsonPath);
    if (ok) emit layoutUploaded(-2);
    return ok;
}

QVariantList EventManager::getSelfBoothLayouts() {
    QVariantList list;
    QDir layoutDir(
        QDir(AppPaths::instance().getAppDirectory()).filePath("data/SelfBoothLayouts"));
    if (!layoutDir.exists()) return list;

    const QFileInfoList files =
        layoutDir.entryInfoList(QStringList() << "*.png", QDir::Files, QDir::Name);
    for (const QFileInfo &fi : files) {
        QVariantMap map;
        map["fileName"] = fi.fileName();
        map["path"] = "file:///" + fi.absoluteFilePath();

        QString jsonPath = fi.absoluteFilePath();
        const int dot = jsonPath.lastIndexOf('.');
        if (dot != -1) jsonPath = jsonPath.left(dot);
        jsonPath += ".json";

        QFile jsonFile(jsonPath);
        if (!jsonFile.open(QIODevice::ReadOnly)) continue;
        map["metadata"] =
            normalizeLayoutMetadataObject(
                QJsonDocument::fromJson(jsonFile.readAll()).object()).toVariantMap();
        list.append(map);
    }
    return list;
}

void EventManager::requestLayouts(int eventId) {
    // DB read stays on main thread (fast, avoids SQLite threading issues)
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        emit layoutsReady(eventId, QVariantList());
        return;
    }
    QString rawPath = event.rawPath;

    // File I/O (JSON reads per PNG) moved to background thread
    QtConcurrent::run([this, eventId, rawPath]() {
        QVariantList list;
        QDir dir(rawPath);
        if (dir.dirName() == "Originals") dir.cdUp();
        QDir layoutDir(dir.filePath("Layouts"));

        if (layoutDir.exists()) {
            QFileInfoList files = layoutDir.entryInfoList(
                QStringList() << "*.png", QDir::Files);

            for (const QFileInfo &fi : files) {
                QVariantMap map;
                map["fileName"] = fi.fileName();
                map["path"]     = "file:///" + fi.absoluteFilePath();

                QString jsonPath = fi.absoluteFilePath();
                int dot = jsonPath.lastIndexOf('.');
                if (dot != -1) jsonPath = jsonPath.left(dot);
                jsonPath += ".json";

                QFile f(jsonPath);
                if (f.open(QIODevice::ReadOnly)) {
                    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
                    map["metadata"] = normalizeLayoutMetadataObject(doc.object()).toVariantMap();
                    f.close();
                    list.append(map);
                }
            }
        }

        QMetaObject::invokeMethod(this, [this, eventId, list]() {
            emit layoutsReady(eventId, list);
        }, Qt::QueuedConnection);
    });
}

void EventManager::repairMissingLayoutMetadata(int eventId) {
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return;

    // Cùng cách suy ra thư mục Layouts như requestLayouts để không lệch đường dẫn.
    QDir dir(event.rawPath);
    if (dir.dirName() == "Originals") dir.cdUp();
    const QString layoutDirPath = dir.filePath("Layouts");

    const QString dpi         = m_printerConfig ? m_printerConfig->resolution()      : "300dpi";
    const QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();

    (void)QtConcurrent::run([this, eventId, layoutDirPath, dpi, printerName]() {
        QDir layoutDir(layoutDirPath);
        if (!layoutDir.exists()) return;

        int repaired = 0;
        for (const QFileInfo &fi : layoutDir.entryInfoList(QStringList() << "*.png", QDir::Files)) {
            const QString jsonPath = layoutDir.filePath(fi.completeBaseName() + ".json");
            if (QFile::exists(jsonPath)) continue;

            qInfo() << "[EventManager] repairMissingLayoutMetadata: phân tích lại" << fi.fileName();
            if (m_layoutAnalyzer->processLayout(fi.absoluteFilePath(), jsonPath, dpi, printerName))
                ++repaired;
            else
                qWarning() << "[EventManager] repairMissingLayoutMetadata: thất bại" << fi.fileName();
        }

        if (repaired > 0) {
            qInfo() << "[EventManager] repairMissingLayoutMetadata: đã khôi phục" << repaired << "khung";
            QMetaObject::invokeMethod(this, [this, eventId]() {
                emit layoutUploaded(eventId);
            }, Qt::QueuedConnection);
        }
    });
}

bool EventManager::updateEventName(int eventId, const QString &newName) {
  if (newName.isEmpty()) {
    emit error("Event name cannot be empty");
    return false;
  }

  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) {
    emit error("Event not found");
    return false;
  }

  event.name = newName;
  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }

  emit error("Failed to update event name");
  return false;
}

bool EventManager::deleteEvent(int eventId) {
  if (m_dbManager->deleteEvent(eventId)) {
    m_eventModel->refresh();
    emit eventDeleted(eventId);
    return true;
  }

  emit error("Failed to delete event");
  return false;
}

bool EventManager::duplicateEvent(int eventId) {
  Event original = m_dbManager->getEvent(eventId);
  if (original.id == 0) {
    emit error("Event not found");
    return false;
  }

  const QList<Event> existingEvents = m_dbManager->getAllEvents();
  const QString sourceName = original.name;
  const QString sourceLayoutDir = AppPaths::instance().getEventLayoutsPath(sourceName);
  const QString sourceBackgroundDir = AppPaths::instance().getEventBackgroundsPath(sourceName);

  original.name = uniqueCopyName(original.name, existingEvents);
  original.id = 0;

  // Generate dedicated paths for the copy (not sharing with original)
  QString safeName = AppPaths::instance().sanitizeEventName(original.name);
  QString originalsPath = AppPaths::instance().getEventOriginalsPath(safeName);
  QString finalPath = AppPaths::instance().getEventFinalPath(safeName);
  QString layoutsPath = AppPaths::instance().getEventLayoutsPath(safeName);
  QString backgroundsPath = AppPaths::instance().getEventBackgroundsPath(safeName);

  QString errorMsg;
  if (!AppPaths::instance().ensureDirectoryExists(originalsPath, &errorMsg)) {
    emit error("Failed to create Originals directory: " + errorMsg);
    return false;
  }
  if (!AppPaths::instance().ensureDirectoryExists(finalPath, &errorMsg)) {
    emit error("Failed to create Final directory: " + errorMsg);
    return false;
  }
  if (!AppPaths::instance().ensureDirectoryExists(layoutsPath, &errorMsg)) {
    emit error("Failed to create Layouts directory: " + errorMsg);
    return false;
  }
  if (!AppPaths::instance().ensureDirectoryExists(backgroundsPath, &errorMsg)) {
    emit error("Failed to create Backgrounds directory: " + errorMsg);
    return false;
  }

  original.rawPath = originalsPath;
  original.finalPath = finalPath;
  original.thumbnailPath = rewritePathIfUnderDir(original.thumbnailPath, sourceLayoutDir, layoutsPath);
  original.selectedLayout = rewritePathIfUnderDir(original.selectedLayout, sourceLayoutDir, layoutsPath);
  original.landingBackground = rewritePathIfUnderDir(original.landingBackground, sourceBackgroundDir, backgroundsPath);
  original.modeSelectionBackground = rewritePathIfUnderDir(original.modeSelectionBackground, sourceBackgroundDir, backgroundsPath);

  int newId = m_dbManager->createEvent(original);
  if (newId > 0) {
    if (!copyDirectoryRecursive(sourceLayoutDir, layoutsPath, &errorMsg)) {
      m_dbManager->deleteEvent(newId);
      emit error("Failed to copy event layouts: " + errorMsg);
      return false;
    }
    if (!copyDirectoryRecursive(sourceBackgroundDir, backgroundsPath, &errorMsg)) {
      m_dbManager->deleteEvent(newId);
      emit error("Failed to copy event backgrounds: " + errorMsg);
      return false;
    }
    if (!m_dbManager->copyEventSettings(eventId, newId)) {
      m_dbManager->deleteEvent(newId);
      emit error("Failed to copy event settings");
      return false;
    }
    if (!m_dbManager->copyPrinterSettings(eventId, newId)) {
      m_dbManager->deleteEvent(newId);
      emit error("Failed to copy printer settings");
      return false;
    }
    m_eventModel->refresh();
    emit eventCreated(newId);
    return true;
  }

  emit error("Failed to duplicate event");
  return false;
}

bool EventManager::updateEventBool(int eventId, const QString &key, bool value) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) return false;

  if (key == "liveViewBackground") {
    event.liveViewBackground = value;
  } else if (key == "poseGuide") {
    event.poseGuide = value;
    qDebug() << "[EventManager] poseGuide set to" << value << "for event" << eventId;
  } else {
    qWarning() << "[EventManager] updateEventBool: unknown key" << key;
    return false;
  }

  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }
  return false;
}

bool EventManager::updateCaptureMode(int eventId, const QString &mode) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0)
    return false;

  event.captureMode = mode;
  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }

  return false;
}

bool EventManager::updateEffect(int eventId, const QString &effectName,
                                bool enabled) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0)
    return false;

  if (effectName == "digitalProps") {
    event.digitalProps = enabled;
  } else if (effectName == "beautyFilter") {
    event.beautyFilter = enabled;
  } else if (effectName == "watermark") {
    event.watermark = enabled;
  } else if (effectName == "postProcessing") {
    event.postProcessing = enabled;
  }

  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }

  return false;
}

bool EventManager::updateEventPath(int eventId, const QString &pathType,
                                   const QString &newPath) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0)
    return false;

  if (pathType == "rawPath") {
    event.rawPath = newPath;
  } else if (pathType == "finalPath") {
    event.finalPath = newPath;
  } else if (pathType == "startScreenMessage") {
    event.startScreenMessage = newPath;
  } else if (pathType == "landingBackground") {
    QString normalizedPath = QDir::toNativeSeparators(newPath);
    qDebug() << "[EventManager] updateEventPath - Saving landingBackground:" << normalizedPath;
    event.landingBackground = normalizedPath;
  } else if (pathType == "modeSelectionBackground") {
    QString normalizedPath = QDir::toNativeSeparators(newPath);
    qDebug() << "[EventManager] updateEventPath - Saving modeSelectionBackground:" << normalizedPath;
    event.modeSelectionBackground = normalizedPath;
  } else {
    qWarning() << "Invalid path type:" << pathType;
    return false;
  }

  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }

  return false;
}

QVariantMap EventManager::getEventDetails(int eventId) {
  Event event = m_dbManager->getEvent(eventId);
  QVariantMap map;

  if (event.id > 0) {
    map["id"] = event.id;
    map["name"] = event.name;
    map["location"] = event.location;
    map["eventDate"] = event.eventDate;
    map["captureMode"] = event.captureMode;
    map["digitalProps"] = event.digitalProps;
    map["beautyFilter"] = event.beautyFilter;
    map["watermark"] = event.watermark;
    map["postProcessing"] = event.postProcessing;
    map["rawPath"] = event.rawPath;
    map["finalPath"] = event.finalPath;
    map["startScreenMessage"] = event.startScreenMessage;
    map["selectedLayout"] = event.selectedLayout;
    map["countdownDuration"] = event.countdownDuration;  // Legacy field
    map["firstShotCountdown"] = event.firstShotCountdown;
    map["nextShotCountdown"] = event.nextShotCountdown;
    map["shotInterval"] = event.shotInterval;
    map["autoCut"] = event.autoCut;
    map["mirrorMode"] = event.mirrorMode;
    map["liveViewOverlay"] = event.liveViewOverlay;
    map["shootingMode"] = event.shootingMode;
    map["manualPhotoCount"] = event.manualPhotoCount;
    // Add file:/// prefix for QML Image components
    QString landingBg = event.landingBackground.isEmpty() ? "" : "file:///" + event.landingBackground;
    QString modeBg = event.modeSelectionBackground.isEmpty() ? "" : "file:///" + event.modeSelectionBackground;
    
    qDebug() << "[EventManager] getEventDetails - landingBackground DB value:" << event.landingBackground;
    qDebug() << "[EventManager] getEventDetails - landingBackground returned:" << landingBg;
    qDebug() << "[EventManager] getEventDetails - modeSelectionBackground DB value:" << event.modeSelectionBackground;
    qDebug() << "[EventManager] getEventDetails - modeSelectionBackground returned:" << modeBg;
    
    map["landingBackground"] = landingBg;
    map["modeSelectionBackground"] = modeBg;
    map["paperSize"] = getPaperSizeFromLayout(event.selectedLayout);
    map["isLandscape"] = getLayoutIsLandscape(event.selectedLayout);
    map["layoutSlotCount"] = getLayoutSlotCount(event.selectedLayout);
    map["liveViewBackground"] = event.liveViewBackground;
    map["poseGuide"]           = event.poseGuide;

    // Thống kê — đồng bộ với EventDetailPanel.qml: totalPhotos / printCount / pendingFiles
    map["totalPhotos"]  = m_dbManager->getOriginalPhotoCount(eventId);
    map["printCount"]   = m_dbManager->getPrintCount(eventId);
    map["pendingFiles"] = (m_s3Uploader && m_machineAuth)
                          ? m_s3Uploader->pendingCountForEvent(m_machineAuth->hwid(), eventId)
                          : 0;
  }

  return map;
}

QVariantList EventManager::getEventPhotos(int eventId) {
  QVariantList photoList;
  QList<Photo> photos = m_dbManager->getPhotosForEvent(eventId);

  qDebug() << "EventManager: Retrieved" << photos.size() << "photos for event" << eventId;

  for (const Photo &photo : photos) {
    QVariantMap photoMap;
    photoMap["id"]        = photo.id;
    photoMap["eventId"]   = photo.eventId;
    photoMap["filePath"]  = "file:///" + photo.filePath;
    photoMap["sessionId"] = photo.sessionId;   // ← needed for QR generation
    photoMap["type"]      = photo.type;
    photoMap["createdAt"] = photo.createdAt;
    photoList.append(photoMap);
  }
  
  return photoList;
}

bool EventManager::updateEventLayout(int eventId, const QString &layoutPath) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) return false;

  event.selectedLayout = layoutPath;

  // Auto-detect cut mode by ASPECT RATIO, not just width.
  // RX1/620S: 2x6" strip (aspect ≈ 0.33) → threshold = 0.45
  // QW410:    5x10" strip (aspect ≈ 0.50) → threshold = 0.55
  // 4x6" portrait (aspect ≈ 0.67) must NOT trigger autoCut even though it's narrow.
  int layoutWidth  = getLayoutWidth(layoutPath);
  int layoutHeight = getLayoutHeight(layoutPath);
  if (layoutWidth > 0 && layoutHeight > 0) {
      double aspect = (double)layoutWidth / (double)layoutHeight;

      // Check which printer is selected to determine the correct threshold
      QString selectedPrinter = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
      bool isQW410 = selectedPrinter.contains("QW410", Qt::CaseInsensitive)
                  || selectedPrinter.contains("QW-410", Qt::CaseInsensitive)
                  || selectedPrinter.contains("410", Qt::CaseInsensitive);

      // QW410: chỉ cut layout 5×10 (0.38 < aspect ≤ 0.55), không cut 5×15 (≤ 0.38), không cut 15×5 (> 2.0)
      // RX1/620S: cut khi aspect ≤ 0.45 (5×15 dọc) HOẶC aspect > 2.0 (15×5 ngang)
      event.autoCut = isQW410 ? (aspect > 0.38 && aspect <= 0.55)
                               : (aspect <= 0.45 || aspect > 2.0);
  } else {
      event.autoCut = false;
  }

  qDebug() << "[EventManager] Layout" << layoutWidth << "x" << layoutHeight
           << "aspect" << (layoutHeight > 0 ? (double)layoutWidth/layoutHeight : 0.0)
           << "-> auto_cut:" << event.autoCut;

  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }
  return false;
}

bool EventManager::updateCaptureTimings(int eventId, int firstShotCountdown, int nextShotCountdown, int shotInterval) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) {
    emit error("Event not found");
    return false;
  }

  // Keep countdownDuration in sync with firstShotCountdown for backwards compatibility
  event.countdownDuration = firstShotCountdown;
  event.firstShotCountdown = firstShotCountdown;
  event.nextShotCountdown = nextShotCountdown;
  event.shotInterval = shotInterval;
  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    qDebug() << "EventManager: Capture timings saved - first:" << firstShotCountdown
             << "next:" << nextShotCountdown << "interval:" << shotInterval;
    return true;
  }

  emit error("Failed to update capture timings");
  return false;
}

bool EventManager::updateMirrorMode(int eventId, bool enabled) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) {
    emit error("Event not found");
    return false;
  }

  event.mirrorMode = enabled;
  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    return true;
  }

  return false;
}

bool EventManager::updateLiveViewOverlay(int eventId, bool enabled) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) {
    emit error("Event not found");
    return false;
  }

  event.liveViewOverlay = enabled;
  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    qDebug() << "EventManager: Live view overlay" << (enabled ? "enabled" : "disabled") << "for event" << eventId;
    return true;
  }

  return false;
}

bool EventManager::updateShootingMode(int eventId, int shootingMode, int manualPhotoCount) {
  Event event = m_dbManager->getEvent(eventId);
  if (event.id == 0) {
    emit error("Event not found");
    return false;
  }

  event.shootingMode = shootingMode;
  event.manualPhotoCount = manualPhotoCount;
  
  if (m_dbManager->updateEvent(event)) {
    m_eventModel->refresh();
    emit eventUpdated(eventId);
    qDebug() << "EventManager: Shooting mode set to" << shootingMode << "with count" << manualPhotoCount;
    return true;
  }

  return false;
}

// Ghi photos.json của một phiên ra file tạm RIÊNG theo sessionId: hàng đợi upload chỉ
// đọc file khi tới lượt, dùng chung một file thì phiên sau ghi đè manifest phiên trước.
// Mode3 (chụp tự do) không có ảnh ghép lẫn video -> không khai hai trường đó.
// Trả về đường dẫn file, rỗng nếu ghi lỗi.
static QString writeSessionManifestFile(const QString &hwid, int eventId,
                                        const QString &sessionId,
                                        const QStringList &photoFilenames,
                                        bool hasVideoAndCollage)
{
    QJsonObject manifest;
    manifest["sessionId"]  = sessionId;
    manifest["eventId"]    = eventId;
    manifest["hwid"]       = hwid;
    manifest["photoCount"] = photoFilenames.count();
    if (hasVideoAndCollage) {
        manifest["video"]   = "video.mp4";
        manifest["collage"] = "collage.jpg";
    }
    QJsonArray photosArray;
    for (const QString &filename : photoFilenames)
        photosArray.append(filename);
    manifest["photos"] = photosArray;

    QString safeId = sessionId;
    safeId.replace(QRegularExpression("[^A-Za-z0-9_.-]"), "_");
    const QString path = QDir::temp().filePath(QString("photos_manifest_%1.json").arg(safeId));
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly))
        return QString();
    f.write(QJsonDocument(manifest).toJson(QJsonDocument::Compact));
    f.close();
    return path;
}

// Khóa so sánh đường dẫn ảnh: bỏ tiền tố file://, thống nhất "/", không phân biệt hoa thường.
static QString photoPathKey(QString path)
{
    if (path.startsWith("file:///")) path = path.mid(8);
    else if (path.startsWith("file://")) path = path.mid(7);
    path = QUrl::fromPercentEncoding(path.toUtf8());
    return QDir::cleanPath(QDir::fromNativeSeparators(path)).toLower();
}

// Ảnh gốc đã ghi vào DB cho phiên (theo photoPathKey).
static QSet<QString> recordedPhotoKeys(DatabaseManager *db, const QString &sessionId)
{
    QSet<QString> keys;
    if (!db || sessionId.isEmpty())
        return keys;
    for (const QString &path : db->getSessionOriginalPhotos(sessionId))
        keys.insert(photoPathKey(path));
    return keys;
}

QStringList EventManager::listSessionPhotoFiles(const QString &dir, const QString &sessionId,
                                                double modifiedSinceMs) const
{
    QStringList files;
    QString clean = dir;
    if (clean.startsWith("file:///")) clean = clean.mid(8);
    else if (clean.startsWith("file://")) clean = clean.mid(7);
    if (clean.isEmpty() || sessionId.isEmpty())
        return files;
    // Thư mục ảnh là thư mục chung của sự kiện: chỉ lấy file mang mã phiên
    // (<sessionId>_photo_NNN.jpg, MOCK_<sessionId>_NNNN.jpg), không lấy ảnh khách khác.
    const QDir d(clean);
    const QFileInfoList entries = d.entryInfoList({QStringLiteral("*.jpg"), QStringLiteral("*.jpeg")},
                                                  QDir::Files, QDir::Name);
    for (const QFileInfo &info : entries) {
        if (!info.fileName().contains(sessionId, Qt::CaseInsensitive))
            continue;
        if (modifiedSinceMs > 0 && info.lastModified().toMSecsSinceEpoch() < qint64(modifiedSinceMs))
            continue;
        files << QDir::fromNativeSeparators(info.absoluteFilePath());
    }
    return files;
}

// Sau khi màn chụp kết thúc, ảnh máy ảnh còn trả về trong khung này (bấm sát giờ, truyền
// chậm) vẫn vào phiên và lên gallery web. Hết khung: ngừng nhận như trước.
static constexpr int kLateCaptureWindowMs = 60000;

void EventManager::setCameraController(CameraController *ctrl)
{
    m_cameraController = ctrl;
    if (ctrl)
        connect(ctrl, &CameraController::imageCaptured, this, &EventManager::onCameraImageCaptured);
}

void EventManager::setCaptureAccepting(const QString &sessionId, int eventId, bool accepting, int photoCount)
{
    if (accepting) {
        // Màn chụp mới tự nhận ảnh của nó: đóng khung nhận ảnh trễ của phiên trước.
        if (m_lateWindowTimer)
            m_lateWindowTimer->stop();
        m_lateSessionId.clear();
        return;
    }
    if (sessionId.isEmpty() || eventId <= 0)
        return;
    m_lateSessionId = sessionId;
    m_lateEventId = eventId;
    m_lateNextIndex = qMax(1, photoCount + 1);
    if (!m_lateWindowTimer) {
        m_lateWindowTimer = new QTimer(this);
        m_lateWindowTimer->setSingleShot(true);
        connect(m_lateWindowTimer, &QTimer::timeout, this, [this]() {
            qDebug() << "[LateCapture] window closed for" << m_lateSessionId;
            m_lateSessionId.clear();
            // Hết khung: ảnh hot folder tới sau đó nằm lại trong thư mục như trước.
            if (m_cameraController)
                m_cameraController->setHotFolderArmed(false);
        });
    }
    m_lateWindowTimer->start(kLateCaptureWindowMs);
}

void EventManager::onCameraImageCaptured(const QString &path)
{
    if (m_lateSessionId.isEmpty())
        return;   // màn chụp đang tự nhận ảnh, hoặc ngoài khung nhận ảnh trễ
    if (!QFileInfo(path).fileName().contains(m_lateSessionId, Qt::CaseInsensitive)) {
        qWarning() << "[LateCapture] ignored, file not named for session" << m_lateSessionId << path;
        return;
    }
    if (recordedPhotoKeys(m_dbManager, m_lateSessionId).contains(photoPathKey(path)))
        return;
    const QString sessionId = m_lateSessionId;
    const int index = m_lateNextIndex++;
    qWarning() << "[LateCapture] photo arrived after capture ended -> session" << sessionId
               << "index" << index << path;
    if (enqueueCaptureAsset(m_lateEventId, path, sessionId, index)) {
        if (m_sessionManager)
            m_sessionManager->endSession(sessionId);   // cập nhật số ảnh của phiên
        if (m_s3Uploader)
            m_s3Uploader->finalizeSession(sessionId);
    }
}

bool EventManager::saveSessionPhotos(int eventId, const QStringList &filePaths, const QString &providedSessionId) {
    if (eventId <= 0 || filePaths.isEmpty()) {
        return false;
    }

    // Check if event exists
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return false;

    QString hwid;
    QString sessionId;

    // Get HWID from machine authenticator if available
    if (m_machineAuth) {
        hwid = m_machineAuth->hwid();
    }

    // If no hwid from auth, get from database (for backward compatibility)
    if (hwid.isEmpty()) {
        hwid = m_dbManager->getMachineHWID();
    }

    // If still no HWID, use default
    if (hwid.isEmpty()) {
        hwid = "default_machine";
        qWarning() << "No HWID available, using default";
    }

    // Use provided session ID or create a new session
    if (!providedSessionId.isEmpty()) {
        sessionId = providedSessionId;
        qDebug() << "Using provided session ID:" << sessionId;
    } else if (m_sessionManager) {
        sessionId = m_sessionManager->createSession(eventId, hwid);
        if (sessionId.isEmpty()) {
            qWarning() << "Failed to create session";
            return false;
        }
        qDebug() << "Created new session ID:" << sessionId;
    } else {
        // Fallback: generate session ID manually
        sessionId = QString("session_%1_%2")
            .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"))
            .arg(QString::number(QRandomGenerator::global()->generate() % 0x10000, 16).toUpper().rightJustified(4, '0'));
        qWarning() << "SessionManager not set, using fallback session ID:" << sessionId;
    }

    // Tell S3Uploader where the event's raw folder is so pending files land there
    if (m_s3Uploader)
        m_s3Uploader->setCurrentEventRawPath(event.rawPath);

    bool success = true;
    int photoIndex = 1;  // Track photo index for S3 upload
    QStringList photoFilenames;  // Track filenames for manifest
    // Ảnh đã ghi lúc chụp (enqueueCaptureAsset) không ghi lại lần nữa — trước đây phiên
    // bị đếm gấp đôi số ảnh.
    QSet<QString> recorded = recordedPhotoKeys(m_dbManager, sessionId);

    for (const QString &path : filePaths) {
        // Skip preview URLs or empty paths
        if (path.startsWith("http") || path.isEmpty()) continue;

        // Remove file:/// prefix for DB storage if present
        QString cleanPath = path;
        if (cleanPath.startsWith("file:///")) {
            cleanPath = cleanPath.mid(8);
        }

        Photo photo;
        photo.eventId   = eventId;
        photo.filePath  = cleanPath;
        photo.sessionId = sessionId;   // attach session so gallery QR works
        photo.type      = "original";

        const bool known = recorded.contains(photoPathKey(cleanPath));
        if (!known && !m_dbManager->addPhoto(photo)) {
            success = false;
            qWarning() << "Failed to add photo to database:" << cleanPath;
        } else {
            if (!known) {
                recorded.insert(photoPathKey(cleanPath));
                qDebug() << "Saved photo to DB for event" << eventId << ":" << cleanPath;
                // Add photo to session
                if (m_sessionManager) {
                    m_sessionManager->addPhotoToSession(sessionId, cleanPath);
                }
            }

            // Upload to S3 with session folder structure: {hwid}/{eventId}/{sessionId}/photos/001_{filename}
            if (m_s3Uploader) {
                QString fileName = QFileInfo(cleanPath).fileName();
                QString s3FileName = QString("%1_%2")
                    .arg(QString::number(photoIndex).rightJustified(3, '0'))
                    .arg(fileName);
                photoFilenames.append(s3FileName);

                m_s3Uploader->uploadSessionPhoto(cleanPath, hwid, eventId, sessionId, photoIndex);
            } else {
                qWarning() << "S3Uploader not set, skipping upload";
            }

            photoIndex++;  // Increment photo index for next photo
        }
    }

    // Create and upload manifest file
    if (m_s3Uploader && !photoFilenames.isEmpty()) {
        const bool hasVideoAndCollage = getAppSetting("app_operation_mode", "mode1") != "mode3";
        const QString tempManifestPath = writeSessionManifestFile(
            hwid, eventId, sessionId, photoFilenames, hasVideoAndCollage);
        if (!tempManifestPath.isEmpty()) {
            m_s3Uploader->uploadManifest(tempManifestPath, hwid, eventId, sessionId);
            qDebug() << "Created and uploaded manifest with" << photoFilenames.count() << "photos";
        }
    }

    // End the session
    if (m_sessionManager && !sessionId.isEmpty()) {
        m_sessionManager->endSession(sessionId);
    }

    if (success) {
        syncEventToDynamoDB(eventId);
    }

    return success;
}

bool EventManager::enqueueCaptureAsset(int eventId, const QString &filePath,
                                       const QString &sessionId, int photoIndex)
{
    if (eventId <= 0 || filePath.isEmpty() || sessionId.isEmpty())
        return false;

    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0)
        return false;

    QString cleanPath = filePath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    cleanPath = QDir::toNativeSeparators(QUrl::fromPercentEncoding(cleanPath.toUtf8()));
    if (!QFileInfo::exists(cleanPath)) {
        qWarning() << "[UploadAsset] Local file missing, not queued:" << sessionId << photoIndex << cleanPath;
        return false;
    }

    if (!recordedPhotoKeys(m_dbManager, sessionId).contains(photoPathKey(cleanPath))) {
        Photo photo;
        photo.eventId = eventId;
        photo.filePath = cleanPath;
        photo.sessionId = sessionId;
        photo.type = "original";
        if (!m_dbManager->addPhoto(photo))
            qWarning() << "[UploadAsset] Failed to record photo metadata:" << sessionId << cleanPath;
        if (m_sessionManager)
            m_sessionManager->addPhotoToSession(sessionId, cleanPath);
    }

    QString hwid = m_machineAuth ? m_machineAuth->hwid() : m_dbManager->getMachineHWID();
    if (hwid.isEmpty()) hwid = "default_machine";
    if (m_s3Uploader) {
        m_s3Uploader->setCurrentEventRawPath(event.rawPath);
        m_s3Uploader->enqueueCaptureAsset(cleanPath, hwid, eventId, sessionId, "photo", photoIndex);
        qDebug() << "[UploadAsset] Queued photo" << sessionId << "asset index" << photoIndex << cleanPath;
        return true;
    }
    return false;
}

// ─── saveSessionPhotosAsync ───────────────────────────────────────────────────
// Tương tự saveSessionPhotos nhưng phần nặng (flip ảnh, ghi đĩa) chạy trên
// background thread. DB write, S3 queue, DynamoDB sync đều về main thread.
// Không block UI — ResultScreen push ngay, background tự hoàn thành sau.
void EventManager::saveSessionPhotosAsync(int eventId, const QStringList &filePaths,
                                          const QString &providedSessionId)
{
    if (eventId <= 0 || filePaths.isEmpty()) {
        emit sessionPhotosSaved();
        return;
    }

    // ── Bước 1: Đọc data nhẹ trên MAIN THREAD ────────────────────────────────
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) { emit sessionPhotosSaved(); return; }

    QString hwid = m_machineAuth ? m_machineAuth->hwid() : m_dbManager->getMachineHWID();
    if (hwid.isEmpty()) hwid = "default_machine";

    QString sessionId = providedSessionId;
    if (sessionId.isEmpty() && m_sessionManager)
        sessionId = m_sessionManager->createSession(eventId, hwid);

    if (m_s3Uploader)
        m_s3Uploader->setCurrentEventRawPath(event.rawPath);

    // Normalize paths — string ops only, fast
    QStringList cleanPaths;
    for (const QString &p : filePaths) {
        if (p.startsWith("http") || p.isEmpty()) continue;
        QString clean = p;
        if (clean.startsWith("file:///")) clean = clean.mid(8);
        cleanPaths.append(clean);
    }

    // ── Bước 2: DB write + S3 queue + DynamoDB về MAIN THREAD ────────────────
    QtConcurrent::run([this, eventId, sessionId, hwid, cleanPaths, event]() {
        // ── Bước 3: DB write + S3 queue + DynamoDB về MAIN THREAD ────────────
        QMetaObject::invokeMethod(this, [this, eventId, sessionId, hwid, cleanPaths, event]() {
            QStringList photoFilenames;
            int photoIndex = 1;
            // Ảnh đã ghi lúc chụp không ghi lại (trước đây phiên bị đếm gấp đôi số ảnh).
            QSet<QString> recorded = recordedPhotoKeys(m_dbManager, sessionId);

            for (const QString &cleanPath : cleanPaths) {
                Photo photo;
                photo.eventId   = eventId;
                photo.filePath  = cleanPath;
                photo.sessionId = sessionId;
                photo.type      = "original";

                const bool known = recorded.contains(photoPathKey(cleanPath));
                if (known || m_dbManager->addPhoto(photo)) {
                    if (!known) {
                        recorded.insert(photoPathKey(cleanPath));
                        if (m_sessionManager)
                            m_sessionManager->addPhotoToSession(sessionId, cleanPath);
                    }

                    if (m_s3Uploader) {
                        QString s3Name = QString("%1_%2")
                            .arg(QString::number(photoIndex).rightJustified(3, '0'))
                            .arg(QFileInfo(cleanPath).fileName());
                        photoFilenames.append(s3Name);
                        m_s3Uploader->uploadSessionPhoto(cleanPath, hwid, eventId, sessionId, photoIndex);
                    }
                    photoIndex++;
                }
            }

            // Manifest
            if (m_s3Uploader && !photoFilenames.isEmpty()) {
                const bool hasVideoAndCollage = getAppSetting("app_operation_mode", "mode1") != "mode3";
                const QString tmpPath = writeSessionManifestFile(
                    hwid, eventId, sessionId, photoFilenames, hasVideoAndCollage);
                if (!tmpPath.isEmpty())
                    m_s3Uploader->uploadManifest(tmpPath, hwid, eventId, sessionId);
            }

            if (m_sessionManager) m_sessionManager->endSession(sessionId);
            syncEventToDynamoDB(eventId);

            emit sessionPhotosSaved();
        }, Qt::QueuedConnection);
    });
}

QString EventManager::processCollage(int eventId, const QStringList &photoPaths,
                                     const QString &sessionId) {
    if (photoPaths.isEmpty()) return "";

    // 0. Normalize paths — remove file:/// prefix
    QStringList cleanPhotoPaths;
    for (const QString &path : photoPaths) {
        QString clean = path;
        if (clean.startsWith("file:///")) clean = clean.mid(8);
        cleanPhotoPaths.append(QDir::toNativeSeparators(clean));
    }

    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0 || event.selectedLayout.isEmpty()) {
        qWarning() << "EventManager: No layout selected for event" << eventId;
        return "";
    }

    // 1. Resolve layout JSON metadata path
    QString layoutPng = event.selectedLayout;
    if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
    layoutPng = QDir::toNativeSeparators(layoutPng);

    QString layoutJson = layoutPng;
    int lastDot = layoutJson.lastIndexOf('.');
    if (lastDot != -1) layoutJson = layoutJson.left(lastDot);
    layoutJson += ".json";

    // 2. Load JSON metadata
    QFile jsonFile(layoutJson);
    if (!jsonFile.open(QIODevice::ReadOnly)) {
        qWarning() << "EventManager: Could not open layout metadata" << layoutJson;
        return "";
    }
    QJsonDocument doc = QJsonDocument::fromJson(jsonFile.readAll());
    QJsonObject layoutMeta = normalizeLayoutMetadataObject(doc.object());
    QVariantList layoutSlots = layoutMeta.value(QStringLiteral("slots")).toArray().toVariantList();
    jsonFile.close();

    if (layoutSlots.isEmpty()) {
        qWarning() << "EventManager: Layout has no slots";
        return "";
    }

    // 3. Prepare output path (Final folder)
    QString outputFileName = QString("collage_%1.jpg").arg(
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"));
    QString finalDir = sessionFinalDir(event.finalPath, sessionId);
    if (finalDir.isEmpty())
        finalDir = QFileInfo(layoutPng).absolutePath();
    QString outputPath = QDir(finalDir).absoluteFilePath(outputFileName);

    // 4. Compose!
    QString printerNameForCompose = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    if (ImageCompositor::compose(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, QVariantList(), printerNameForCompose)) {
        // 5. Record collage in DB so GalleryScreen can show it
        Photo collagePhoto;
        collagePhoto.eventId   = eventId;
        collagePhoto.filePath  = outputPath;
        collagePhoto.sessionId = sessionId;   // may be empty for legacy callers
        collagePhoto.type      = "collage";
        if (!m_dbManager->addPhoto(collagePhoto)) {
            qWarning() << "EventManager: Failed to save collage to DB:" << outputPath;
        } else {
            qDebug() << "EventManager: Collage saved to DB for event" << eventId
                     << "session" << sessionId;
        }

        return "file:///" + outputPath;
    }

    return "";
}

// ─── processCollageWithTransforms ─────────────────────────────────────────────
// Giống processCollage nhưng truyền transform data (scale/tx/ty) cho từng slot
// để ImageCompositor áp dụng đúng pan/zoom mà user đã chỉnh trong QML.
QString EventManager::processCollageWithTransforms(int eventId,
                                                    const QStringList &photoPaths,
                                                    const QVariantList &transforms,
                                                    const QString &sessionId)
{
    if (photoPaths.isEmpty()) return "";

    // 0. Normalize paths
    QStringList cleanPhotoPaths;
    for (const QString &path : photoPaths) {
        QString clean = path;
        if (clean.startsWith("file:///")) clean = clean.mid(8);
        cleanPhotoPaths.append(QDir::toNativeSeparators(clean));
    }

    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0 || event.selectedLayout.isEmpty()) {
        qWarning() << "EventManager: No layout selected for event" << eventId;
        return "";
    }

    // 1. Layout paths
    QString layoutPng = event.selectedLayout;
    if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
    layoutPng = QDir::toNativeSeparators(layoutPng);

    QString layoutJson = layoutPng;
    int lastDot = layoutJson.lastIndexOf('.');
    if (lastDot != -1) layoutJson = layoutJson.left(lastDot);
    layoutJson += ".json";

    // 2. Load JSON
    QFile jsonFile(layoutJson);
    if (!jsonFile.open(QIODevice::ReadOnly)) {
        qWarning() << "EventManager: Could not open layout metadata" << layoutJson;
        return "";
    }
    QJsonDocument doc = QJsonDocument::fromJson(jsonFile.readAll());
    QJsonObject layoutMeta = normalizeLayoutMetadataObject(doc.object());
    QVariantList layoutSlots = layoutMeta.value(QStringLiteral("slots")).toArray().toVariantList();
    jsonFile.close();

    if (layoutSlots.isEmpty()) return "";

    // 3. Output path
    QString outputFileName = QString("collage_%1.jpg").arg(
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"));
    QString finalDir = sessionFinalDir(event.finalPath, sessionId);
    if (finalDir.isEmpty())
        finalDir = QFileInfo(layoutPng).absolutePath();
    QString outputPath = QDir(finalDir).absoluteFilePath(outputFileName);

    // 4. Compose WITH transforms
    // Khi layout là 2x6 (autoCut=true) VÀ printer cutMode=ON → tạo canvas 4x6 (RX1/620S) hoặc 15x10 (QW410)
    bool cutMode = event.autoCut && (m_printerConfig ? m_printerConfig->cutMode() : false);

    QString selectedPrinterName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    bool isQW410Printer = selectedPrinterName.contains("QW410", Qt::CaseInsensitive)
                       || selectedPrinterName.contains("QW-410", Qt::CaseInsensitive)
                       || selectedPrinterName.contains("410", Qt::CaseInsensitive);

    qDebug() << "[EventManager] processCollageWithTransforms: applying"
             << transforms.size() << "transforms for" << photoPaths.size() << "photos"
             << "| cutMode=" << cutMode << "| isQW410=" << isQW410Printer;

    // Detect layout aspect để phân biệt các loại layout đặc biệt
    // Dùng QImageReader.size() — không decode pixel, không cấp phát ~8-16MB
    QImageReader _lr1(layoutPng);
    QSize _ls1 = _lr1.size();
    double layoutAspect = (_ls1.height() > 0) ? (double)_ls1.width() / _ls1.height() : 1.0;
    bool is5x15Layout = (layoutAspect <= 0.38);
    bool is15x5Layout = (layoutAspect > 2.0);   // 15×5 landscape strip

    bool ok;
    if (cutMode && isQW410Printer)
        // QW410 5×10 cut: 3 strip ngang → 1200×1800
        ok = ImageCompositor::composeWithCutQW410(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
    else if (cutMode && is15x5Layout)
        // RX1/620S 15×5 cut: nhân đôi dọc → canvas 15×10 landscape
        ok = ImageCompositor::composeWithCutHorizontal(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
    else if (cutMode)
        // RX1/620S 5×15 cut: nhân đôi ngang → canvas 4×6 portrait
        ok = ImageCompositor::composeWithCut(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
    else if (isQW410Printer && is5x15Layout)
        // QW410 5×15 no-cut: nhân đôi ngang → 1200×1800, margin=0
        ok = ImageCompositor::composeWithCut(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms, selectedPrinterName);
    else
        ok = ImageCompositor::compose(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms, selectedPrinterName);

    if (ok) {
        Photo collagePhoto;
        collagePhoto.eventId   = eventId;
        collagePhoto.filePath  = outputPath;
        collagePhoto.sessionId = sessionId;
        collagePhoto.type      = "collage";
        if (!m_dbManager->addPhoto(collagePhoto)) {
            qWarning() << "EventManager: Failed to save collage to DB:" << outputPath;
        } else {
            QString cutLabel = !cutMode ? "(normal)"
                                    : (isQW410Printer   ? "(15x10 QW410 cut)"
                                    : is15x5Layout      ? "(15x10 RX1 horizontal cut)"
                                                        : "(4x6 RX1 vertical cut)");
        qDebug() << "EventManager: Collage" << cutLabel
                     << "saved to DB for event" << eventId << "session" << sessionId;
        }
        return "file:///" + outputPath;
    }

    return "";
}

// ─── processCollageWithTransformsAsync ────────────────────────────────────────
// Chạy xử lý ảnh (ImageCompositor) trên background thread — KHÔNG block UI.
//
// Thread-safety: QSqlDatabase và QObject (PrinterConfig) KHÔNG được dùng từ
// background thread. Giải pháp: đọc toàn bộ data cần thiết trên main thread
// trước, truyền plain data (struct/QString) vào lambda, ghi DB sau khi xong
// bằng QMetaObject::invokeMethod về main thread.
void EventManager::processCollageWithTransformsAsync(int eventId,
                                                     const QStringList &photoPaths,
                                                     const QVariantList &transforms,
                                                     const QString &sessionId,
                                                     bool saveToDb)
{
    if (photoPaths.isEmpty()) {
        emit collageReady("");
        return;
    }

    // ── Bước 1: Đọc toàn bộ data cần thiết trên MAIN THREAD ─────────────────
    QStringList cleanPhotoPaths;
    for (const QString &path : photoPaths) {
        QString clean = path;
        if (clean.startsWith("file:///")) clean = clean.mid(8);
        cleanPhotoPaths.append(QDir::toNativeSeparators(clean));
    }

    Event event = m_dbManager->getEvent(eventId);   // DB read — main thread OK
    if (event.id == 0 || event.selectedLayout.isEmpty()) {
        qWarning() << "[Async] No layout for event" << eventId;
        emit collageReady("");
        return;
    }

    QString layoutPng = event.selectedLayout;
    if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
    layoutPng = QDir::toNativeSeparators(layoutPng);

    QString layoutJson = layoutPng;
    int lastDot = layoutJson.lastIndexOf('.');
    if (lastDot != -1) layoutJson = layoutJson.left(lastDot);
    layoutJson += ".json";

    QFile jsonFile(layoutJson);
    if (!jsonFile.open(QIODevice::ReadOnly)) {
        qWarning() << "[Async] Cannot open layout JSON:" << layoutJson;
        emit collageReady("");
        return;
    }
    QVariantList layoutSlots =
        normalizeLayoutMetadataObject(QJsonDocument::fromJson(jsonFile.readAll()).object())
            .value(QStringLiteral("slots")).toArray().toVariantList();
    jsonFile.close();

    if (layoutSlots.isEmpty()) {
        emit collageReady("");
        return;
    }

    // Đọc PrinterConfig trên main thread (QObject — không thread-safe)
    bool   cutMode            = event.autoCut && (m_printerConfig ? m_printerConfig->cutMode() : false);
    QString selectedPrinter   = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();

    // Dùng QImageReader.size() — không decode pixel, không cấp phát ~8-16MB
    QImageReader _lr2(layoutPng);
    QSize _ls2 = _lr2.size();
    double layoutAspect = (_ls2.height() > 0) ? (double)_ls2.width() / _ls2.height() : 1.0;
    bool is5x15Layout = (layoutAspect <= 0.38);
    bool is15x5Layout = (layoutAspect > 2.0);

    QString outputFileName = QString("collage_%1.jpg").arg(
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"));
    QString finalDir = event.finalPath.isEmpty()
                       ? QFileInfo(layoutPng).absolutePath()
                       : sessionFinalDir(event.finalPath, sessionId);
    QString outputPath = QDir(finalDir).absoluteFilePath(outputFileName);

    // ── Bước 2: Chỉ chạy ImageCompositor (CPU-heavy) trên background thread ──
    QtConcurrent::run([this, eventId, sessionId, saveToDb,
                       cleanPhotoPaths, transforms, layoutSlots,
                       layoutPng, outputPath, selectedPrinter,
                       cutMode, is5x15Layout, is15x5Layout]()
    {
        bool isQW410 = selectedPrinter.contains("QW410", Qt::CaseInsensitive)
                    || selectedPrinter.contains("QW-410", Qt::CaseInsensitive)
                    || selectedPrinter.contains("410", Qt::CaseInsensitive);

        qDebug() << "[Async] Compositing" << cleanPhotoPaths.size() << "photos"
                 << "| cutMode=" << cutMode << "| isQW410=" << isQW410;

        bool ok = false;
        if (cutMode && isQW410)
            ok = ImageCompositor::composeWithCutQW410(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
        else if (cutMode && is15x5Layout)
            ok = ImageCompositor::composeWithCutHorizontal(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
        else if (cutMode)
            ok = ImageCompositor::composeWithCut(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
        else if (isQW410 && is5x15Layout)
            ok = ImageCompositor::composeWithCut(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms, selectedPrinter);
        else
            ok = ImageCompositor::compose(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms, selectedPrinter);

        QString resultPath = ok ? ("file:///" + outputPath) : QString();

        // ── Bước 3: Ghi DB và emit signal — phải về MAIN THREAD ─────────────
        QMetaObject::invokeMethod(this, [this, ok, resultPath, eventId, sessionId, outputPath, saveToDb]() {
            if (ok && saveToDb) {
                Photo collagePhoto;
                collagePhoto.eventId   = eventId;
                collagePhoto.filePath  = outputPath;
                collagePhoto.sessionId = sessionId;
                collagePhoto.type      = "collage";
                if (!m_dbManager->addPhoto(collagePhoto))
                    qWarning() << "[Async] Failed to save collage to DB:" << outputPath;
            }
            emit collageReady(resultPath);
        }, Qt::QueuedConnection);
    });
}

void EventManager::processCollageForLayoutAsync(
    int eventId, const QString &layoutPath, const QStringList &photoPaths,
    const QVariantList &transforms, const QString &sessionId, bool saveToDb)
{
    if (layoutPath.isEmpty() || photoPaths.isEmpty()) {
        emit collageReady("");
        return;
    }

    QStringList cleanPhotoPaths;
    for (QString path : photoPaths) {
        if (path.startsWith("file:///")) path = path.mid(8);
        else if (path.startsWith("file://")) path = path.mid(7);
        cleanPhotoPaths.append(QDir::toNativeSeparators(path));
    }

    QString layoutPng = layoutPath;
    if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
    else if (layoutPng.startsWith("file://")) layoutPng = layoutPng.mid(7);
    layoutPng = QDir::toNativeSeparators(layoutPng);

    QString layoutJson = layoutPng;
    const int dot = layoutJson.lastIndexOf('.');
    if (dot != -1) layoutJson = layoutJson.left(dot);
    layoutJson += ".json";

    QFile jsonFile(layoutJson);
    if (!jsonFile.open(QIODevice::ReadOnly)) {
        qWarning() << "[SelfBooth] Cannot open frame metadata:" << layoutJson;
        emit collageReady("");
        return;
    }
    const QVariantList layoutSlots =
        normalizeLayoutMetadataObject(QJsonDocument::fromJson(jsonFile.readAll()).object())
            .value(QStringLiteral("slots")).toArray().toVariantList();
    if (layoutSlots.isEmpty()) {
        emit collageReady("");
        return;
    }

    QString outputDir = QFileInfo(cleanPhotoPaths.first()).absolutePath();
    if (outputDir.isEmpty()) outputDir = QFileInfo(layoutPng).absolutePath();
    const QString outputPath = QDir(outputDir).absoluteFilePath(
        QString("selfbooth_collage_%1.jpg")
            .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz")));

    (void)QtConcurrent::run(
        [this, eventId, sessionId, saveToDb, cleanPhotoPaths, transforms,
         layoutSlots, layoutPng, outputPath]() {
            const bool ok = ImageCompositor::composeRaw(
                cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms);
            const QString resultPath = ok ? ("file:///" + outputPath) : QString();

            QMetaObject::invokeMethod(
                this,
                [this, ok, resultPath, eventId, sessionId, outputPath, saveToDb]() {
                    if (ok && saveToDb) {
                        Photo collagePhoto;
                        collagePhoto.eventId = eventId;
                        collagePhoto.filePath = outputPath;
                        collagePhoto.sessionId = sessionId;
                        collagePhoto.type = "collage";
                        if (!m_dbManager->addPhoto(collagePhoto))
                            qWarning() << "[SelfBooth] Failed to save collage to DB:"
                                       << outputPath;
                    }
                    emit collageReady(resultPath);
                },
                Qt::QueuedConnection);
        });
}

// ─── recordCollage ────────────────────────────────────────────────────────────
// Ghi một collage path đã có trên disk vào DB.
// Dùng sau khi sử dụng kết quả pre-render (saveToDb=false) khi user xác nhận.
void EventManager::recordCollage(int eventId, const QString &filePath, const QString &sessionId)
{
    QString cleanPath = filePath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    cleanPath = QDir::toNativeSeparators(cleanPath);
    Photo p;
    p.eventId   = eventId;
    p.filePath  = cleanPath;
    p.sessionId = sessionId;
    p.type      = "collage";
    if (!m_dbManager->addPhoto(p))
        qWarning() << "[EventManager] recordCollage: Failed to save to DB:" << cleanPath;
    else
        qDebug() << "[EventManager] recordCollage: Saved to DB:" << cleanPath;
}

// ─── processCollageNoCut ──────────────────────────────────────────────────────
// Giống processCollageWithTransforms nhưng LUÔN dùng compose() (không nhân đôi strip).
// Dùng để tạo preview 2x6 cho FilterScreen trước khi apply filter.
QString EventManager::processCollageNoCut(int eventId,
                                          const QStringList &photoPaths,
                                          const QVariantList &transforms,
                                          const QString &sessionId)
{
    if (photoPaths.isEmpty()) return "";

    QStringList cleanPhotoPaths;
    for (const QString &path : photoPaths) {
        QString clean = path;
        if (clean.startsWith("file:///")) clean = clean.mid(8);
        cleanPhotoPaths.append(QDir::toNativeSeparators(clean));
    }

    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0 || event.selectedLayout.isEmpty()) {
        qWarning() << "[EventManager] processCollageNoCut: No layout for event" << eventId;
        return "";
    }

    QString layoutPng = event.selectedLayout;
    if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
    layoutPng = QDir::toNativeSeparators(layoutPng);

    QString layoutJson = layoutPng;
    int lastDot = layoutJson.lastIndexOf('.');
    if (lastDot != -1) layoutJson = layoutJson.left(lastDot);
    layoutJson += ".json";

    QFile jsonFile(layoutJson);
    if (!jsonFile.open(QIODevice::ReadOnly)) {
        qWarning() << "[EventManager] processCollageNoCut: Cannot open JSON" << layoutJson;
        return "";
    }
    QJsonDocument doc = QJsonDocument::fromJson(jsonFile.readAll());
    QJsonObject layoutMeta = normalizeLayoutMetadataObject(doc.object());
    QVariantList layoutSlots = layoutMeta.value(QStringLiteral("slots")).toArray().toVariantList();
    jsonFile.close();
    if (layoutSlots.isEmpty()) return "";

    QString outputFileName = QString("preview_%1.jpg").arg(
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"));
    QString finalDir = sessionFinalDir(event.finalPath, sessionId);
    if (finalDir.isEmpty()) finalDir = QFileInfo(layoutPng).absolutePath();
    QString outputPath = QDir(finalDir).absoluteFilePath(outputFileName);

    // Dùng composeRaw() – không áp safe-margin để strip "sạch" cho filter
    // composeCutFromStrip() sẽ đặt strip này vào 4x6 canvas với margin đúng
    if (ImageCompositor::composeRaw(cleanPhotoPaths, layoutPng, layoutSlots, outputPath, transforms)) {
        qDebug() << "[EventManager] processCollageNoCut: Preview strip saved:" << outputPath;
        return "file:///" + outputPath;
    }
    return "";
}

void EventManager::processCollageNoCutAsync(int eventId,
                                            const QStringList &photoPaths,
                                            const QVariantList &transforms,
                                            const QString &sessionId)
{
    if (photoPaths.isEmpty()) { emit previewReady(""); return; }

    QStringList cleanPaths;
    for (const QString &p : photoPaths) {
        QString c = p;
        if (c.startsWith("file:///")) c = c.mid(8);
        cleanPaths.append(QDir::toNativeSeparators(c));
    }

    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0 || event.selectedLayout.isEmpty()) {
        emit previewReady(""); return;
    }

    QString layoutPng = event.selectedLayout;
    if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
    layoutPng = QDir::toNativeSeparators(layoutPng);

    QString layoutJson = layoutPng;
    int lastDot2 = layoutJson.lastIndexOf(QChar('.'));
    if (lastDot2 != -1) layoutJson = layoutJson.left(lastDot2);
    layoutJson += QString(".json");

    QFile jsonFile2(layoutJson);
    if (!jsonFile2.open(QIODevice::ReadOnly)) { emit previewReady(""); return; }
    QJsonDocument doc2 = QJsonDocument::fromJson(jsonFile2.readAll());
    jsonFile2.close();

    QJsonArray slotsArr = normalizeLayoutMetadataObject(doc2.object())
                               .value(QStringLiteral("slots")).toArray();
    QVariantList layoutSlots2 = slotsArr.toVariantList();
    if (layoutSlots2.isEmpty()) { emit previewReady(""); return; }

    QString finalDir2 = event.finalPath.isEmpty()
                        ? QFileInfo(layoutPng).absolutePath()
                        : sessionFinalDir(event.finalPath, sessionId);
    QString outputPath = QDir(finalDir2).absoluteFilePath(
        QString("preview_%1.jpg").arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz")));

    QtConcurrent::run([this, cleanPaths, layoutPng, layoutSlots2, outputPath, transforms]() {
        bool ok = ImageCompositor::composeRaw(cleanPaths, layoutPng, layoutSlots2, outputPath, transforms);
        QString result = ok ? (QString("file:///") + outputPath) : QString();
        QMetaObject::invokeMethod(this, [this, result]() {
            emit previewReady(result);
        }, Qt::QueuedConnection);
    });
}

// ─── composeCutCanvas ─────────────────────────────────────────────────────────
// Ghép strip (đã render/filter) thành canvas in. Đây là phần XỬ LÝ ẢNH THUẦN —
// KHÔNG chạm DatabaseManager/PrinterConfig nên an toàn gọi từ worker thread.
//   RX1/620S: nhân 2 → 4x6 hoặc 15x10.   QW410: nhân 3 ngang → 15x10 portrait.
// finalDirHint rỗng → lưu cạnh strip. Trả về đường dẫn file (rỗng nếu lỗi).
static QString composeCutCanvas(const QString &stripPath, const QColor &bgColor,
                                const QString &finalDirHint, bool isQW410)
{
    QString cleanPath = stripPath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    cleanPath = QDir::toNativeSeparators(cleanPath);
    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());

    QImage strip(cleanPath);
    if (strip.isNull()) {
        qWarning() << "[EventManager] composeCutCanvas: Failed to load strip:" << cleanPath;
        return "";
    }

    int stripW = strip.width();
    int stripH = strip.height();

    QImage result;
    QPainter painter;

    if (isQW410) {
        // bleed = 2mm @300dpi ≈ 24px, cutGap = 15px
        const int safeMarginY = 20;
        const int innerGap    = 5;
        const int safeEdge    = 20;

        int canvasW = stripW * 3;
        int canvasH = stripH;

        int imgW = (canvasW - 2 * safeEdge - 2 * innerGap) / 3;
        int imgH = stripH - 2 * safeMarginY;

        int x1   = safeEdge;
        int x2   = safeEdge + imgW + innerGap;
        int x3   = canvasW - safeEdge - imgW;
        int yTop = safeMarginY;

        qDebug() << "[EventManager] composeCutFromStrip QW410: strip=" << stripW << "x" << stripH
                 << "innerGap=" << innerGap << "safeEdge=" << safeEdge << "safeMarginY=" << safeMarginY
                 << "→ canvas=" << canvasW << "x" << canvasH << "imgW=" << imgW;

        result = QImage(canvasW, canvasH, QImage::Format_ARGB32);
        result.fill(bgColor);
        painter.begin(&result);
        painter.setRenderHint(QPainter::Antialiasing);
        painter.setRenderHint(QPainter::SmoothPixmapTransform);

        painter.drawImage(QRect(x1, yTop, imgW, imgH), strip);
        painter.drawImage(QRect(x2, yTop, imgW, imgH), strip);
        painter.drawImage(QRect(x3, yTop, imgW, imgH), strip);
        painter.end();

        // Xoay 90° CW: landscape (stripW*3 × stripH) → portrait (stripH × stripW*3)
        // e.g. 1800×1200 → 1200×1800 — gửi QW410 in portrait (dọc)
        QTransform rot;
        rot.rotate(90);
        result = result.transformed(rot, Qt::SmoothTransformation);
        qDebug() << "[EventManager] composeCutFromStrip QW410: rotated 90° →" << result.width() << "x" << result.height();
    } else {
        // RX1/DS620S — phân biệt 5×15 (cắt dọc) vs 15×5 (cắt ngang) theo aspect.
        //
        // Hình học BẮT BUỘC giống hệt ImageCompositor::composeWithCut() —
        // hai hàm này là hai đường vào cùng một loại tấm in (một đường cho ảnh
        // không filter, một đường cho ảnh đã filter/sticker). Nếu lệch nhau thì
        // cùng một phiên chụp sẽ in ra hai bố cục khác nhau.
        // Chuẩn số liệu: docs/DNP_RX1_CUT_PRINT_SPEC.md §2.
        double stripAspect = (stripH > 0) ? (double)stripW / stripH : 0.0;
        bool is15x5Strip   = (stripAspect > 2.0);  // strip landscape 15×5

        qDebug() << "[EventManager] composeCutCanvas RX1/620S"
                 << (is15x5Strip ? "15×5 (cắt ngang)" : "5×15 (cắt dọc)")
                 << "strip=" << stripW << "x" << stripH;

        // Dùng CHUNG buildCutSheet() với ImageCompositor::composeWithCut() —
        // đây chính là chỗ trước đây hai đường ghép tự cài đặt riêng và cho ra
        // hai bố cục khác nhau tuỳ user có áp filter hay không.
        result = ImageCompositor::buildCutSheet(
            strip, bgColor,
            is15x5Strip ? ImageCompositor::cutSheetLandscape(strip.size())
                        : ImageCompositor::cutSheetPortrait(strip.size()),
            /*stacked=*/is15x5Strip);
        strip = QImage();
    }

    QString finalDir = !finalDirHint.isEmpty() ? finalDirHint
                                               : QFileInfo(cleanPath).absolutePath();

    QString outputFileName = QString("collage_cut_%1.jpg").arg(
        QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"));
    QString outputPath = QDir(finalDir).absoluteFilePath(outputFileName);

    QString errorMsg;
    if (!AppPaths::instance().ensureDirectoryExists(finalDir, &errorMsg)) {
        qCritical() << "[EventManager] composeCutCanvas: Cannot create dir:" << errorMsg;
        return "";
    }

    if (result.save(outputPath, "JPG", 100)) {
        qDebug() << "[EventManager] composeCutCanvas: Saved"
                 << (isQW410 ? "QW410 cut canvas" : "RX1/620S cut canvas") << "→" << outputPath;
        return outputPath;
    }

    qWarning() << "[EventManager] composeCutCanvas: Failed to save:" << outputPath;
    return "";
}

// ─── composeCutFromStrip ──────────────────────────────────────────────────────
// Wrapper main-thread: đọc DB (màu nền layout + finalPath + ghi Photo) rồi gọi
// composeCutCanvas. QSqlDatabase không dùng được cross-thread nên phần DB phải ở
// main thread; phần ảnh nặng (composeCutCanvas) có thể chạy nền — xem
// applyQrOverlayAsync gọi thẳng composeCutCanvas trên worker thread.
QString EventManager::composeCutFromStrip(const QString &stripPath, int eventId)
{
    QColor  bgColor = Qt::white;
    // Lưu canvas cắt CÙNG thư mục với strip (strip đã nằm trong Final/<sessionId>/),
    // để ảnh in theo đúng folder phiên thay vì Final gốc chung.
    QString cleanStripForDir = stripPath;
    if (cleanStripForDir.startsWith("file:///")) cleanStripForDir = cleanStripForDir.mid(8);
    else if (cleanStripForDir.startsWith("file://")) cleanStripForDir = cleanStripForDir.mid(7);
    cleanStripForDir = QDir::toNativeSeparators(QUrl::fromPercentEncoding(cleanStripForDir.toUtf8()));
    QString finalDirHint = QFileInfo(cleanStripForDir).absolutePath();
    Event   event = m_dbManager->getEvent(eventId);
    if (event.id > 0) {
        if (!event.selectedLayout.isEmpty()) {
            QString layoutPng = event.selectedLayout;
            if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
            layoutPng = QDir::toNativeSeparators(layoutPng);
            QImage overlayBg(layoutPng);
            if (!overlayBg.isNull()) {
                overlayBg = overlayBg.convertToFormat(QImage::Format_ARGB32);
                bgColor = ImageCompositor::sampleBgColor(overlayBg);
            }
        }
    }

    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    bool isQW410 = printerName.contains("QW410", Qt::CaseInsensitive)
                || printerName.contains("QW-410", Qt::CaseInsensitive)
                || printerName.contains("410", Qt::CaseInsensitive);

    QString outputPath = composeCutCanvas(stripPath, bgColor, finalDirHint, isQW410);
    if (outputPath.isEmpty()) return "";

    if (event.id > 0) {
        Photo collagePhoto;
        collagePhoto.eventId  = eventId;
        collagePhoto.filePath = outputPath;
        collagePhoto.type     = "collage";
        m_dbManager->addPhoto(collagePhoto);
    }
    return "file:///" + outputPath;
}

QString EventManager::applyStickersToStrip(const QString &stripPath, const QVariantList &stickers)
{
    if (stickers.isEmpty()) return stripPath;

    // Làm sạch đường dẫn strip (bỏ tiền tố file:/// + giải mã %xx)
    QString cleanPath = stripPath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());
    cleanPath = QDir::toNativeSeparators(cleanPath);

    QImage base(cleanPath);
    if (base.isNull()) {
        qWarning() << "[EventManager] applyStickersToStrip: cannot load strip" << cleanPath;
        return stripPath;
    }
    base = base.convertToFormat(QImage::Format_ARGB32);

    const int W = base.width();
    const int H = base.height();

    QPainter painter(&base);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    for (const QVariant &v : stickers) {
        QVariantMap m = v.toMap();
        QString sp = m.value("path").toString();
        if (sp.startsWith("file:///")) sp = sp.mid(8);
        else if (sp.startsWith("file://")) sp = sp.mid(7);
        sp = QUrl::fromPercentEncoding(sp.toUtf8());
        sp = QDir::toNativeSeparators(sp);

        QImage stk(sp);
        if (stk.isNull()) {
            qWarning() << "[EventManager] applyStickersToStrip: skip missing sticker" << sp;
            continue;
        }
        stk = stk.convertToFormat(QImage::Format_ARGB32);

        double xNorm   = m.value("xNorm",   0.5).toDouble();   // tâm X (0..1)
        double yNorm   = m.value("yNorm",   0.5).toDouble();   // tâm Y (0..1)
        double wNorm   = m.value("wNorm",   0.2).toDouble();   // bề rộng / strip width
        double rotDeg  = m.value("rotDeg",  0.0).toDouble();

        int targetW = qMax(1, (int)qRound(wNorm * W));
        int targetH = qMax(1, (int)qRound((double)targetW * stk.height() / stk.width()));
        QImage scaled = stk.scaled(targetW, targetH,
                                   Qt::KeepAspectRatio, Qt::SmoothTransformation);

        double cx = xNorm * W;
        double cy = yNorm * H;

        painter.save();
        painter.translate(cx, cy);
        if (!qFuzzyIsNull(rotDeg)) painter.rotate(rotDeg);
        // Vẽ canh tâm sticker tại (cx, cy)
        painter.drawImage(QPointF(-scaled.width() / 2.0, -scaled.height() / 2.0), scaled);
        painter.restore();
    }
    painter.end();

    // Lưu ra file mới cạnh strip gốc với hậu tố _stk
    QFileInfo fi(cleanPath);
    QString outPath = fi.absolutePath() + "/" + fi.completeBaseName() + "_stk."
                    + (fi.suffix().isEmpty() ? QStringLiteral("jpg") : fi.suffix());
    bool ok = base.save(outPath, nullptr, 100);
    if (!ok) {
        qWarning() << "[EventManager] applyStickersToStrip: failed to save" << outPath;
        return stripPath;
    }
    return "file:///" + QDir::fromNativeSeparators(outPath);
}

void EventManager::createVideoFromSessionQml(int eventId, const QString &sessionId,
                                             const QVariantList &photoPaths,
                                             int maxLongEdge,
                                             const QVariantList &slotCaptureIndices)
{
    QStringList paths;
    paths.reserve(photoPaths.size());
    for (const QVariant &v : photoPaths) {
        QString p = v.toString();
        if (!p.isEmpty())
            paths << p;
    }

    qDebug() << "[EventManager] createVideoFromSessionQml:"
             << "event" << eventId << "| session" << sessionId
             << "| QVariant photos" << photoPaths.size()
             << "| QString photos" << paths.size()
             << "| slot map" << slotCaptureIndices;

    createVideoFromSession(eventId, sessionId, paths, maxLongEdge, slotCaptureIndices);
}

void EventManager::createVideoFromSession(int eventId, const QString &sessionId, const QStringList &photoPaths, int maxLongEdge,
                                          const QVariantList &slotCaptureIndices)
{
    qDebug() << "[EventManager] ===== CREATE VIDEO FROM SESSION =====";
    qDebug() << "[EventManager] Event ID:" << eventId << "| Session:" << sessionId
             << "| Photos:" << photoPaths.count();

    if (!m_videoCreator) {
        qWarning() << "[EventManager] VideoCreator not set, skipping video creation";
        return;
    }
    if (photoPaths.isEmpty()) {
        qWarning() << "[EventManager] No photos provided for video creation";
        return;
    }
    if (!m_videoCreator->isFfmpegAvailable()) {
        qWarning() << "[EventManager] ffmpeg.exe not found — video creation skipped."
                   << "Place ffmpeg.exe next to the application executable to enable this feature.";
        return;
    }

    // Clean paths on main thread (cheap string ops only)
    QStringList cleanPhotoPaths;
    for (const QString &path : photoPaths) {
        QString clean = path;
        if (clean.startsWith("file:///")) clean = clean.mid(8);
        else if (clean.startsWith("file://")) clean = clean.mid(7);
        cleanPhotoPaths.append(QDir::toNativeSeparators(clean));
    }

    // Resolve output path on main thread (DB read is fast)
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) {
        qWarning() << "[EventManager] Event not found:" << eventId;
        return;
    }

    QString eventFinalDir = event.finalPath.isEmpty()
                            ? AppPaths::instance().getEventFinalPath(event.name)
                            : event.finalPath;
    QString finalDir = QDir(eventFinalDir).absoluteFilePath(sessionId);
    QDir().mkpath(finalDir);  // non-blocking, just mkdir

    QString outputPath = QDir(finalDir).absoluteFilePath(
        QString("video_%1.mp4").arg(sessionId));

    qDebug() << "[EventManager] Video output:" << outputPath;

    // Prepare upload info
    QString hwid    = (m_machineAuth) ? m_machineAuth->hwid() : "UNKNOWN";
    QString rawPath = event.rawPath;

    // ── Process video: nạp frame + slots từ layout đã chọn ──────────────────
    // framePng = layout PNG đã chọn; slots/canvas lấy từ JSON layout đi kèm.
    QVariantMap meta = loadLayoutMetadata(event.selectedLayout);
    QVariantList slotList = meta.value("slots").toList();
    int canvasW = meta.value("width").toInt();
    int canvasH = meta.value("height").toInt();

    // Làm sạch đường dẫn frame PNG để FFmpeg overlay được (selectedLayout thường
    // có tiền tố file:/// và có thể là .json → cần đổi sang .png).
    QString framePng = event.selectedLayout;
    if (framePng.startsWith("file:///"))     framePng = framePng.mid(8);
    else if (framePng.startsWith("file://")) framePng = framePng.mid(7);
    framePng = QUrl::fromPercentEncoding(framePng.toUtf8());
    if (framePng.endsWith(".json", Qt::CaseInsensitive))
        framePng = framePng.left(framePng.length() - 5) + ".png";
    framePng = QDir::toNativeSeparators(framePng);
    qDebug() << "[EventManager] process video frame overlay:" << framePng
             << "exists=" << QFile::exists(framePng);

    // Thư mục chứa frame live-view đã ghi của từng slot (CaptureScreen ghi vào đây).
    QString recBase = AppPaths::instance().getSessionRecordingPath(sessionId);
    QStringList slotRecordDirs;
    for (int i = 0; i < slotList.size(); ++i) {
        // Bản ghi tạo dáng của ô i = lần chụp mà khách xếp vào ô i (slotCaptureIndices[i]).
        // Không có ánh xạ / không tìm thấy (-1) → fallback theo index chụp (slot_i).
        int k = i;
        if (i < slotCaptureIndices.size()) {
            int ci = slotCaptureIndices.at(i).toInt();
            if (ci >= 0) k = ci;
        }
        slotRecordDirs << (recBase + QString("/slot_%1").arg(k));
    }

    // Dọn thư mục ghi tạm sau khi xong (cả thành công lẫn lỗi).
    auto cleanupRecordings = [recBase]() {
        QDir d(QDir::toNativeSeparators(recBase));
        if (d.exists()) d.removeRecursively();
    };

    // Disconnect any leftover connections from previous session
    disconnect(m_videoCreator, &VideoCreator::videoCreationFinished, this, nullptr);
    disconnect(m_videoCreator, &VideoCreator::videoCreationError,    this, nullptr);

    // On success: upload video to S3 (runs on main thread via queued signal)
    connect(m_videoCreator, &VideoCreator::videoCreationFinished, this,
            [this, hwid, eventId, sessionId, rawPath, cleanupRecordings](const QString &videoPath) {
                qDebug() << "[EventManager] Video ready, uploading:" << videoPath;
                // Báo cho UI (WaitingResults) biết video đã encode xong để phát lại.
                emit processVideoReady(sessionId, QUrl::fromLocalFile(videoPath).toString());
                if (m_s3Uploader) {
                    m_s3Uploader->setCurrentEventRawPath(rawPath);
                    m_s3Uploader->uploadVideo(videoPath, hwid, eventId, sessionId);
                }
                cleanupRecordings();
            }, Qt::SingleShotConnection);

    const bool canCreateProcessVideo = !slotList.isEmpty() && canvasW > 0 && canvasH > 0;
    auto fallbackAttempted = QSharedPointer<bool>::create(!canCreateProcessVideo);

    connect(m_videoCreator, &VideoCreator::videoCreationError, this,
            [this, sessionId, cleanPhotoPaths, outputPath, maxLongEdge, cleanupRecordings, fallbackAttempted](const QString &error) {
                qCritical() << "[EventManager] Video creation failed for session"
                            << sessionId << ":" << error;
                if (!*fallbackAttempted) {
                    *fallbackAttempted = true;
                    qWarning() << "[EventManager] Process video failed; falling back to slideshow video for session"
                               << sessionId << "->" << outputPath;
                    m_videoCreator->createVideoFromImages(cleanPhotoPaths, outputPath, 30, maxLongEdge);
                    return;
                }
                cleanupRecordings();
            });

    // Kick off encoding — runs entirely on a background thread (QtConcurrent inside VideoCreator).
    // Returns immediately, does NOT block the UI or upload pipeline.
    if (canCreateProcessVideo) {
        qDebug() << "[EventManager] Creating PROCESS video |" << slotList.size()
                 << "slots | canvas" << canvasW << "x" << canvasH << "| frame:" << framePng
                 << "| slot→capture map:" << slotCaptureIndices << "| recDirs:" << slotRecordDirs;
        m_videoCreator->createProcessVideo(framePng, slotList, canvasW, canvasH,
                                           cleanPhotoPaths, slotRecordDirs,
                                           outputPath, 30, maxLongEdge);
    } else {
        // Fallback: layout không có metadata slots → dùng slideshow ghép ảnh cũ.
        qWarning() << "[EventManager] No slot metadata for layout — falling back to slideshow video";
        m_videoCreator->createVideoFromImages(cleanPhotoPaths, outputPath, 30, maxLongEdge);
    }
}

QString EventManager::getSessionRecordingDir(const QString &sessionId)
{
    QString dir = AppPaths::instance().getSessionRecordingPath(sessionId);
    QDir().mkpath(dir);
    return dir;
}

QString EventManager::getSessionVideoPath(int eventId, const QString &sessionId)
{
    if (sessionId.isEmpty())
        return QString();
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0)
        return QString();

    // Cùng quy tắc với createVideoFromSession: <finalDir>/<sessionId>/video_<sessionId>.mp4
    QString eventFinalDir = event.finalPath.isEmpty()
                            ? AppPaths::instance().getEventFinalPath(event.name)
                            : event.finalPath;
    QString finalDir = QDir(eventFinalDir).absoluteFilePath(sessionId);
    QString outputPath = QDir(finalDir).absoluteFilePath(
        QString("video_%1.mp4").arg(sessionId));

    if (!QFile::exists(outputPath))
        return QString();   // chưa encode xong → UI chờ signal processVideoReady
    return QUrl::fromLocalFile(outputPath).toString();
}

// ---------------------------------------------------------------------------
// printQrCode — tạo ảnh 4x6" (1800×1200 @300dpi) với mã QR + tên sự kiện rồi in
// ---------------------------------------------------------------------------
void EventManager::printQrCode(const QString &qrUrl, const QString &eventName)
{
    if (!m_printerManager) {
        qWarning() << "[EventManager] printQrCode: PrinterManager not set";
        return;
    }
    if (qrUrl.isEmpty()) {
        qWarning() << "[EventManager] printQrCode: qrUrl is empty";
        return;
    }

    // Generate QR + build canvas + save are heavy — run on worker thread.
    QtConcurrent::run([this, qrUrl, eventName]() {

    // ── 1. Generate QR image locally (no network) ─────────────────────────────
    // ── 2. Tạo canvas 4x6" landscape (1800×1200 px @300dpi) ──────────────────
    const int canvasW = 1800;
    const int canvasH = 1200;
    QImage canvas(canvasW, canvasH, QImage::Format_RGB32);
    canvas.fill(Qt::white);

    QPainter painter(&canvas);
    painter.setRenderHint(QPainter::Antialiasing);
    painter.setRenderHint(QPainter::SmoothPixmapTransform);

    const int qrSize = 700;
    QImage qrScaled = generateQrImage(qrUrl, qrSize);
    int qrX = (canvasH - qrScaled.width())  / 2 + 80;   // padding trái 80px
    int qrY = (canvasH - qrScaled.height()) / 2;
    painter.drawImage(qrX, qrY, qrScaled);

    // Text bên phải QR
    int textX = qrX + qrSize + 80;
    int textW  = canvasW - textX - 60;

    // "Quét mã để xem ảnh"
    QFont labelFont("Arial", 38, QFont::Normal);
    painter.setFont(labelFont);
    painter.setPen(QColor("#555555"));
    painter.drawText(QRect(textX, canvasH / 2 - 120, textW, 60),
                     Qt::AlignLeft | Qt::AlignVCenter,
                     "Quét mã để xem ảnh");

    // Tên sự kiện
    if (!eventName.isEmpty()) {
        QFont nameFont("Arial", 48, QFont::Bold);
        painter.setFont(nameFont);
        painter.setPen(QColor("#1a1a1a"));
        painter.drawText(QRect(textX, canvasH / 2 - 40, textW, 120),
                         Qt::AlignLeft | Qt::AlignVCenter | Qt::TextWordWrap,
                         eventName);
    }

    painter.end();

    // ── 3. Lưu tạm vào temp dir ───────────────────────────────────────────────
    QString tempPath = QDir::temp().filePath(
        QString("qr_print_%1.jpg").arg(QDateTime::currentMSecsSinceEpoch()));
    if (!canvas.save(tempPath, "JPEG", 95)) {
        qWarning() << "[EventManager] printQrCode: Failed to save temp image:" << tempPath;
        return;
    }

    qDebug() << "[EventManager] printQrCode: Temp image saved:" << tempPath;

    // ── 4. Gọi PrinterManager in (trên main thread) ──────────────────────────
    QMetaObject::invokeMethod(this, [this, tempPath, eventName]() {
        m_printerManager->printImageWithSettings(
            tempPath,
            1,        // 1 bản
            "6x4",    // paper 4x6"
            300,      // 300 dpi
            false,    // không cắt
            false     // không matte
        );
        qDebug() << "[EventManager] printQrCode: Print job sent for event:" << eventName;
    }, Qt::QueuedConnection);

    });  // QtConcurrent::run
}

// ---------------------------------------------------------------------------
// saveQrCode — tải ảnh QR từ qrUrl và lưu xuống thư mục Pictures của máy
// ---------------------------------------------------------------------------
void EventManager::saveQrCode(const QString &qrUrl, const QString &eventName)
{
    if (qrUrl.isEmpty()) {
        qWarning() << "[EventManager] saveQrCode: qrUrl is empty";
        emit qrCodeSaved(false, QString());
        return;
    }

    // Generate + save runs on worker thread to avoid UI block.
    QtConcurrent::run([this, qrUrl, eventName]() {

    // Generate QR locally (no network)
    QImage qrImg = generateQrImage(qrUrl, 400);

    // Thư mục đích: Pictures của máy (fallback về home nếu không có)
    QString destDir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (destDir.isEmpty())
        destDir = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    QDir().mkpath(destDir);

    // Tên file: làm sạch tên sự kiện, bỏ ký tự không hợp lệ trên Windows
    QString safeName = eventName;
    safeName.replace(QRegularExpression("[\\\\/:*?\"<>|]"), "_");
    safeName = safeName.trimmed();
    if (safeName.isEmpty())
        safeName = "event";

    QString fileName = QString("QR_%1_%2.png")
                           .arg(safeName)
                           .arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss"));
    QString destPath = QDir(destDir).filePath(fileName);

    bool ok = qrImg.save(destPath, "PNG");
    if (ok)
        qDebug() << "[EventManager] saveQrCode: QR saved to:" << destPath;
    else
        qWarning() << "[EventManager] saveQrCode: Failed to save QR to:" << destPath;

    QMetaObject::invokeMethod(this, [this, ok, destPath]() {
        emit qrCodeSaved(ok, ok ? destPath : QString());
    }, Qt::QueuedConnection);

    });  // QtConcurrent::run
}

QVariantMap EventManager::getEventUploadStats(int eventId) const
{
    QVariantMap stats;
    stats["totalPhotos"] = 0;
    stats["pendingFiles"] = 0;
    stats["isOnline"] = true;

    if (eventId <= 0) return stats;

    // Số ảnh gốc đã chụp (không tính collage)
    int total = m_dbManager->getOriginalPhotoCount(eventId);
    stats["totalPhotos"] = total;

    // Số file đang chờ upload cho event này
    if (m_s3Uploader) {
        QString hwid = m_machineAuth ? m_machineAuth->hwid() : "";
        int pending  = m_s3Uploader->pendingCountForEvent(hwid, eventId);
        stats["pendingFiles"] = pending;
        stats["isOnline"]     = m_s3Uploader->isOnline();
    }

    return stats;
}

int EventManager::getLayoutSlotCount(const QString &layoutPath) {
    if (layoutPath.isEmpty()) {
        qDebug() << "EventManager: No layout selected, using default 3 photos";
        return 3; 
    }

    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);

    QString jsonPath = path;
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    QFile file(jsonPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "EventManager: Could not open layout metadata at:" << jsonPath << "- Using default 3";
        return 3;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    QJsonObject layoutMeta = normalizeLayoutMetadataObject(doc.object());
    QJsonArray layoutSlots = layoutMeta.value(QStringLiteral("slots")).toArray();
    file.close();

    int count = layoutSlots.size();
    qDebug() << "EventManager: Layout" << jsonPath << "has" << count << "slots";
    
    return (count > 0) ? count : 3;
}

int EventManager::getLayoutWidth(const QString &layoutPath) {
    if (layoutPath.isEmpty()) {
        qDebug() << "[EventManager] No layout selected, defaulting width to -1 (auto_cut = false)";
        return -1;
    }

    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);

    QString jsonPath = path;
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    QFile file(jsonPath);
    if (!file.open(QIODevice::ReadOnly)) {
        QImageReader reader(path);
        QSize imageSize = reader.size();
        int imageWidth = imageSize.isValid() ? imageSize.width() : -1;
        qWarning() << "[EventManager] Could not open layout metadata at:" << jsonPath
                   << "- Using image width:" << imageWidth;
        return imageWidth;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    QJsonObject layoutObj = doc.object();
    int width = layoutObj.value("width").toInt(-1);
    file.close();

    qDebug() << "[EventManager] Layout" << jsonPath << "has width:" << width << "px";

    return width;
}

int EventManager::getLayoutHeight(const QString &layoutPath) {
    if (layoutPath.isEmpty()) {
        return -1;
    }

    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);

    QString jsonPath = path;
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    QFile file(jsonPath);
    if (!file.open(QIODevice::ReadOnly)) {
        QImageReader reader(path);
        QSize imageSize = reader.size();
        int imageHeight = imageSize.isValid() ? imageSize.height() : -1;
        qWarning() << "[EventManager] Could not open layout metadata at:" << jsonPath
                   << "- Using image height:" << imageHeight;
        return imageHeight;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    QJsonObject layoutObj = doc.object();
    int height = layoutObj.value("height").toInt(-1);
    file.close();

    qDebug() << "[EventManager] Layout" << jsonPath << "has height:" << height << "px";

    return height;
}

bool EventManager::getLayoutIsLandscape(const QString &layoutPath) {
    int width = getLayoutWidth(layoutPath);
    int height = getLayoutHeight(layoutPath);

    // Landscape if width > height
    bool isLandscape = (width > 0 && height > 0 && width > height);

    qDebug() << "[EventManager] Layout" << width << "x" << height
             << "-> Orientation:" << (isLandscape ? "LANDSCAPE" : "PORTRAIT");

    return isLandscape;
}

QString EventManager::getPaperSizeFromLayout(const QString &layoutPath) {
    int width  = getLayoutWidth(layoutPath);
    int height = getLayoutHeight(layoutPath);

    if (width <= 0 || height <= 0) {
        qDebug() << "[EventManager] No layout dimensions, defaulting to 6x4";
        return "6x4";
    }

    // Use aspect ratio to classify paper size (DPI-independent)
    double aspect = (double)width / (double)height;
    QString paperSize;

    if (aspect <= 0.45) {
        paperSize = "2x6";   // 2" strip: W:H ≈ 0.33  (600x1800 or 1200x3600)
    } else if (aspect <= 1.10) {
        paperSize = "4x6";   // 4x6" portrait: W:H ≈ 0.67 (1200x1800 or 2400x3600)
    } else {
        paperSize = "6x4";   // 6x4" landscape: W:H ≈ 1.5  (1800x1200 or 3600x2400)
    }

    qDebug() << "[EventManager] Layout" << width << "x" << height
             << "aspect" << aspect << "-> paper:" << paperSize;
    return paperSize;
}

QVariantMap EventManager::loadLayoutMetadata(const QString &layoutPath) {
    QVariantMap result;

    if (layoutPath.isEmpty()) {
        qWarning() << "[EventManager] loadLayoutMetadata: Empty layout path";
        return result;
    }

    QString path = layoutPath;
    if (path.startsWith("file:///")) path = path.mid(8);
    path = QDir::toNativeSeparators(path);

    QString jsonPath = path;
    int dot = jsonPath.lastIndexOf('.');
    if (dot != -1) jsonPath = jsonPath.left(dot);
    jsonPath += ".json";

    QFile file(jsonPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "[EventManager] loadLayoutMetadata: Could not open JSON file:" << jsonPath;
        return result;
    }

    QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    file.close();

    if (doc.isNull() || !doc.isObject()) {
        qWarning() << "[EventManager] loadLayoutMetadata: Invalid JSON in file:" << jsonPath;
        return result;
    }

    bool changed = false;
    QJsonObject metadata = normalizeLayoutMetadataObject(doc.object(), &changed);
    if (changed) {
        QFile outFile(jsonPath);
        if (outFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            outFile.write(QJsonDocument(metadata).toJson());
            outFile.close();
            qDebug() << "[EventManager] loadLayoutMetadata: Normalized QR slot metadata in" << jsonPath;
        } else {
            qWarning() << "[EventManager] loadLayoutMetadata: Could not persist normalized metadata:" << jsonPath;
        }
    }

    result = metadata.toVariantMap();
    qDebug() << "[EventManager] loadLayoutMetadata: Loaded metadata with"
             << result.value("slot_count", 0).toInt() << "slots";

    return result;
}

QString EventManager::applyQrOverlay(const QString &imagePath, const QString &qrUrl, double xNorm, double yNorm, double sizeNorm) {
    if (imagePath.isEmpty() || qrUrl.isEmpty()) return imagePath;

    QString cleanPath = imagePath;
    if (cleanPath.startsWith("file:///")) {
#ifdef Q_OS_WIN
        cleanPath = cleanPath.mid(8);
#else
        cleanPath = cleanPath.mid(7);
#endif
    }
    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());

    QImage originalImg(cleanPath);
    if (originalImg.isNull()) {
        qWarning() << "[EventManager] applyQrOverlay: Failed to load original image" << cleanPath;
        return imagePath;
    }

    // sizeNorm comes from the UI as a fraction of the shorter displayed edge.
    int qrTargetSize = qrSizeFromNorm(originalImg.width(), originalImg.height(), sizeNorm, 60);
    QImage qrImg = generateQrImage(qrUrl, qrTargetSize);

    int xPos = qrPositionFromNorm(originalImg.width(), xNorm, qrTargetSize);
    int yPos = qrPositionFromNorm(originalImg.height(), yNorm, qrTargetSize);

    qDebug() << "[EventManager] applyQrOverlay: image=" << originalImg.width() << "x" << originalImg.height()
             << "norm=(" << xNorm << "," << yNorm << ") sizeNorm=" << sizeNorm
             << "-> qr=(" << xPos << "," << yPos << ") size=" << qrTargetSize;

    QPainter painter(&originalImg);
    painter.drawImage(xPos, yPos, qrImg);
    painter.end();

    QFileInfo fileInfo(cleanPath);
    QString newPath = fileInfo.absolutePath() + "/" + fileInfo.completeBaseName() + "_qr." + fileInfo.suffix();

    if (originalImg.save(newPath, "JPEG", 95)) {
        qDebug() << "[EventManager] applyQrOverlay: Saved composited image to" << newPath;
        return "file:///" + newPath;
    } else {
        qWarning() << "[EventManager] applyQrOverlay: Failed to save image to" << newPath;
        return imagePath;
    }
}

QString EventManager::applyQrOverlayRect(const QString &imagePath, const QString &qrUrl,
                                         double xNorm, double yNorm,
                                         double wNorm, double hNorm)
{
    if (imagePath.isEmpty() || qrUrl.isEmpty()) return imagePath;

    QString cleanPath = imagePath;
    if (cleanPath.startsWith("file:///")) {
#ifdef Q_OS_WIN
        cleanPath = cleanPath.mid(8);
#else
        cleanPath = cleanPath.mid(7);
#endif
    } else if (cleanPath.startsWith("file://")) {
        cleanPath = cleanPath.mid(7);
    }
    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());

    QImage originalImg(cleanPath);
    if (originalImg.isNull()) {
        qWarning() << "[EventManager] applyQrOverlayRect: Failed to load original image" << cleanPath;
        return imagePath;
    }

    const int imgW = originalImg.width();
    const int imgH = originalImg.height();
    const int x = qBound(0, qRound(imgW * safeNorm(xNorm)), qMax(0, imgW - 1));
    const int y = qBound(0, qRound(imgH * safeNorm(yNorm)), qMax(0, imgH - 1));
    const int maxW = qMax(1, imgW - x);
    const int maxH = qMax(1, imgH - y);
    const int w = qBound(1, qRound(imgW * safeNorm(wNorm, 0.12)), maxW);
    const int h = qBound(1, qRound(imgH * safeNorm(hNorm, 0.12)), maxH);

    QImage qrImg = generateQrImage(qrUrl, qMax(w, h));
    const QRect targetRect(x, y, w, h);

    qDebug() << "[EventManager] applyQrOverlayRect: image=" << imgW << "x" << imgH
             << "normRect=(" << xNorm << "," << yNorm << "," << wNorm << "," << hNorm << ")"
             << "-> rect=" << targetRect;

    QPainter painter(&originalImg);
    painter.drawImage(targetRect, qrImg);
    painter.end();

    QFileInfo fileInfo(cleanPath);
    QString newPath = fileInfo.absolutePath() + "/" + fileInfo.completeBaseName() + "_qr." + fileInfo.suffix();

    if (originalImg.save(newPath, "JPEG", 95)) {
        qDebug() << "[EventManager] applyQrOverlayRect: Saved composited image to" << newPath;
        return "file:///" + newPath;
    }

    qWarning() << "[EventManager] applyQrOverlayRect: Failed to save image to" << newPath;
    return imagePath;
}

// ── applyQrOverlayAsync — chạy QR overlay trên background thread ────────────
// applyQrOverlay* gọi httpGetSyncWithTimeout (QEventLoop). Khi chạy trên UI
// thread, nested event loop làm treo UI tới 15 s nếu mạng chậm. Đẩy toàn bộ
// (tải QR + vẽ + lưu) sang worker thread; nested event loop khi đó nằm ngoài
// UI thread nên an toàn và không treo giao diện.
void EventManager::applyQrOverlayAsync(const QString &imagePath, const QString &qrUrl,
                                       const QString &mode,
                                       double xNorm, double yNorm, double sizeNorm,
                                       int eventId)
{
    // mode "qw410cut": sau khi vẽ QR lên strip, ghép luôn canvas cắt 15×10 NGAY
    // trên worker thread → màn QML không còn phải gọi composeCutFromStrip đồng bộ.
    const bool composeCut = (mode == "qw410cut");

    // ── DB prep PHẢI ở main thread (QSqlDatabase không cross-thread) ──────────
    QColor  bgColor = Qt::white;
    QString finalDirHint;
    bool    isQW410 = false;
    if (composeCut) {
        // Canvas cắt lưu CÙNG thư mục với ảnh nguồn (đã theo Final/<sessionId>/).
        QString cleanImg = imagePath;
        if (cleanImg.startsWith("file:///")) cleanImg = cleanImg.mid(8);
        else if (cleanImg.startsWith("file://")) cleanImg = cleanImg.mid(7);
        cleanImg = QDir::toNativeSeparators(QUrl::fromPercentEncoding(cleanImg.toUtf8()));
        finalDirHint = QFileInfo(cleanImg).absolutePath();
        Event ev = m_dbManager->getEvent(eventId);
        if (ev.id > 0) {
            if (!ev.selectedLayout.isEmpty()) {
                QString layoutPng = ev.selectedLayout;
                if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
                layoutPng = QDir::toNativeSeparators(layoutPng);
                QImage overlayBg(layoutPng);
                if (!overlayBg.isNull()) {
                    overlayBg = overlayBg.convertToFormat(QImage::Format_ARGB32);
                    bgColor = ImageCompositor::sampleBgColor(overlayBg);
                }
            }
        }
        QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
        isQW410 = printerName.contains("QW410", Qt::CaseInsensitive)
               || printerName.contains("QW-410", Qt::CaseInsensitive)
               || printerName.contains("410", Qt::CaseInsensitive);
    }

    QtConcurrent::run([this, imagePath, qrUrl, mode, xNorm, yNorm, sizeNorm,
                       composeCut, bgColor, finalDirHint, isQW410, eventId]() {
        QString result;
        if (mode == "2h")
            result = applyQrOverlayFor2(imagePath, qrUrl, xNorm, yNorm, sizeNorm);
        else if (mode == "2v")
            result = applyQrOverlayFor2Vertical(imagePath, qrUrl, xNorm, yNorm, sizeNorm);
        else  // "single" hoặc "qw410cut" — đều vẽ 1 QR lên strip/ảnh
            result = applyQrOverlay(imagePath, qrUrl, xNorm, yNorm, sizeNorm);

        // QW410 cut: ghép strip (đã có QR) thành canvas in — vẫn trên worker thread.
        QString cutOutputPath;   // plain path, dùng để ghi DB trên main thread
        if (composeCut && !result.isEmpty()) {
            cutOutputPath = composeCutCanvas(result, bgColor, finalDirHint, isQW410);
            if (!cutOutputPath.isEmpty())
                result = "file:///" + cutOutputPath;
        }

        // Phát signal + ghi DB trên UI thread (QueuedConnection vì this sống ở main thread).
        QMetaObject::invokeMethod(this, [this, result, cutOutputPath, eventId]() {
            if (!cutOutputPath.isEmpty() && eventId > 0) {
                Photo collagePhoto;
                collagePhoto.eventId  = eventId;
                collagePhoto.filePath = cutOutputPath;
                collagePhoto.type     = "collage";
                m_dbManager->addPhoto(collagePhoto);
            }
            emit qrOverlayReady(result);
        }, Qt::QueuedConnection);
    });
}

void EventManager::applyQrOverlayRectAsync(const QString &imagePath, const QString &qrUrl,
                                           const QString &mode,
                                           double xNorm, double yNorm,
                                           double wNorm, double hNorm,
                                           int eventId)
{
    const bool composeCut = (mode == "cutstrip" || mode == "qw410cut");

    QColor  bgColor = Qt::white;
    QString finalDirHint;
    bool    isQW410 = false;
    if (composeCut) {
        QString cleanImg = imagePath;
        if (cleanImg.startsWith("file:///")) cleanImg = cleanImg.mid(8);
        else if (cleanImg.startsWith("file://")) cleanImg = cleanImg.mid(7);
        cleanImg = QDir::toNativeSeparators(QUrl::fromPercentEncoding(cleanImg.toUtf8()));
        finalDirHint = QFileInfo(cleanImg).absolutePath();

        Event ev = m_dbManager->getEvent(eventId);
        if (ev.id > 0 && !ev.selectedLayout.isEmpty()) {
            QString layoutPng = ev.selectedLayout;
            if (layoutPng.startsWith("file:///")) layoutPng = layoutPng.mid(8);
            layoutPng = QDir::toNativeSeparators(layoutPng);
            QImage overlayBg(layoutPng);
            if (!overlayBg.isNull()) {
                overlayBg = overlayBg.convertToFormat(QImage::Format_ARGB32);
                bgColor = ImageCompositor::sampleBgColor(overlayBg);
            }
        }

        QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
        isQW410 = printerName.contains("QW410", Qt::CaseInsensitive)
               || printerName.contains("QW-410", Qt::CaseInsensitive)
               || printerName.contains("410", Qt::CaseInsensitive);
    }

    QtConcurrent::run([this, imagePath, qrUrl, xNorm, yNorm, wNorm, hNorm,
                       composeCut, bgColor, finalDirHint, isQW410, eventId]() {
        QString result = applyQrOverlayRect(imagePath, qrUrl, xNorm, yNorm, wNorm, hNorm);

        QString cutOutputPath;
        if (composeCut && !result.isEmpty()) {
            cutOutputPath = composeCutCanvas(result, bgColor, finalDirHint, isQW410);
            if (!cutOutputPath.isEmpty())
                result = "file:///" + cutOutputPath;
        }

        QMetaObject::invokeMethod(this, [this, result, cutOutputPath, eventId]() {
            if (!cutOutputPath.isEmpty() && eventId > 0) {
                Photo collagePhoto;
                collagePhoto.eventId  = eventId;
                collagePhoto.filePath = cutOutputPath;
                collagePhoto.type     = "collage";
                m_dbManager->addPhoto(collagePhoto);
            }
            emit qrOverlayReady(result);
        }, Qt::QueuedConnection);
    });
}

// ── QR Overlay cho ảnh cắt – vẽ 2 QR với vị trí độc lập ────────────────────
// x1/y1/size1Norm: vị trí QR nửa trái (normalized theo toàn bộ canvas width/height)
// x2/y2/size2Norm: vị trí QR nửa phải (normalized theo toàn bộ canvas width/height)
// Tất cả normalized coords khớp với hệ tọa độ của overlayArea trong QML.
QString EventManager::applyQrOverlayForCut(const QString &imagePath, const QString &qrUrl,
                                             double x1Norm, double y1Norm, double size1Norm,
                                             double x2Norm, double y2Norm, double size2Norm)
{
    if (imagePath.isEmpty() || qrUrl.isEmpty()) return imagePath;

    QString cleanPath = imagePath;
    if (cleanPath.startsWith("file:///")) {
#ifdef Q_OS_WIN
        cleanPath = cleanPath.mid(8);
#else
        cleanPath = cleanPath.mid(7);
#endif
    }
    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());

    QImage originalImg(cleanPath);
    if (originalImg.isNull()) {
        qWarning() << "[EventManager] applyQrOverlayForCut: Failed to load image" << cleanPath;
        return imagePath;
    }

    int fullW = originalImg.width();
    int H     = originalImg.height();

    // Generate QR locally from the session URL
    int qr1Size = qrSizeFromNorm(fullW, H, size1Norm, 60);
    int qr1X    = qrPositionFromNorm(fullW, x1Norm, qr1Size);
    int qr1Y    = qrPositionFromNorm(H, y1Norm, qr1Size);
    QImage qrImg1 = generateQrImage(qrUrl, qr1Size);

    int qr2Size = qrSizeFromNorm(fullW, H, size2Norm, 60);
    int qr2X    = qrPositionFromNorm(fullW, x2Norm, qr2Size);
    int qr2Y    = qrPositionFromNorm(H, y2Norm, qr2Size);
    QImage qrImg2 = generateQrImage(qrUrl, qr2Size);

    qDebug() << "[applyQrOverlayForCut] canvas=" << fullW << "x" << H
             << "| QR1=(" << qr1X << "," << qr1Y << ") size=" << qr1Size
             << "| QR2=(" << qr2X << "," << qr2Y << ") size=" << qr2Size;

    QPainter painter(&originalImg);
    painter.drawImage(qr1X, qr1Y, qrImg1);
    painter.drawImage(qr2X, qr2Y, qrImg2);
    painter.end();

    QFileInfo fileInfo(cleanPath);
    QString newPath = fileInfo.absolutePath() + "/" + fileInfo.completeBaseName() + "_qr." + fileInfo.suffix();

    if (originalImg.save(newPath, "JPEG", 95)) {
        qDebug() << "[EventManager] applyQrOverlayForCut: Saved to" << newPath;
        return "file:///" + newPath;
    }

    qWarning() << "[EventManager] applyQrOverlayForCut: Failed to save to" << newPath;
    return imagePath;
}

double EventManager::getLayoutAspect(const QString &layoutPath)
{
    if (layoutPath.isEmpty()) return 1.0;
    QString clean = layoutPath;
    if (clean.startsWith("file:///")) clean = clean.mid(8);
    // QImageReader::size() chỉ đọc HEADER ảnh để lấy kích thước — KHÔNG decode
    // toàn bộ pixel. Trước đây dùng `QImage img(clean)` decode nguyên file PNG
    // layout (~2362×3543 ≈ 33MB RGBA) ngay trên main thread → freeze UI vài trăm
    // ms mỗi lần ResultScreen mở (binding layoutAspect). Đọc header nhanh hơn
    // hàng trăm lần và không cấp phát bộ nhớ lớn.
    QImageReader reader(clean);
    const QSize sz = reader.size();
    if (!sz.isValid() || sz.height() == 0) return 1.0;
    return (double)sz.width() / sz.height();
}

// Helper: replicate QR into N strips at the same relative position.
// stripsVertical=true  → strips stacked top-to-bottom (QW410 5×10 cut, 3 strips)
//                         xNorm/yNorm/sizeNorm relative to one strip (segW=fullW, segH=fullH/N)
// stripsVertical=false → strips side by side left-to-right (RX1/5×15, 2 strips)
//                         xNorm/yNorm/sizeNorm relative to one strip (segW=fullW/N, segH=fullH)
static QString applyQrOverlayForNStrips(const QString &imagePath, const QString &qrUrl,
                                         double xNorm, double yNorm, double sizeNorm,
                                         int numStrips, bool stripsVertical)
{
    if (imagePath.isEmpty() || qrUrl.isEmpty() || numStrips < 1) return imagePath;

    QString cleanPath = imagePath;
    if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
    else if (cleanPath.startsWith("file://")) cleanPath = cleanPath.mid(7);
    cleanPath = QUrl::fromPercentEncoding(cleanPath.toUtf8());

    QImage img(cleanPath);
    if (img.isNull()) {
        qWarning() << "[EventManager] applyQrOverlayForNStrips: cannot load" << cleanPath;
        return imagePath;
    }

    int fullW = img.width();
    int fullH = img.height();

    int segW = stripsVertical ? fullW            : fullW / numStrips;
    int segH = stripsVertical ? fullH / numStrips : fullH;

    // sizeNorm is relative to the smaller strip dimension; generate QR locally
    int qrSize  = qrSizeFromNorm(segW, segH, sizeNorm, 40);
    int offsetX = qrPositionFromNorm(segW, xNorm, qrSize);
    int offsetY = qrPositionFromNorm(segH, yNorm, qrSize);

    QImage qrImg = generateQrImage(qrUrl, qrSize);

    QPainter painter(&img);
    for (int i = 0; i < numStrips; ++i) {
        int dx = stripsVertical ? 0        : segW * i;
        int dy = stripsVertical ? segH * i : 0;
        painter.drawImage(offsetX + dx, offsetY + dy, qrImg);
    }
    painter.end();

    qDebug() << "[EventManager] applyQrOverlayFor" << numStrips
             << (stripsVertical ? "vertical" : "horizontal")
             << "strips: offsetX=" << offsetX << "offsetY=" << offsetY << "qrSize=" << qrSize;

    QFileInfo fi(cleanPath);
    QString newPath = fi.absolutePath() + "/" + fi.completeBaseName() + "_qr." + fi.suffix();
    if (img.save(newPath, "JPEG", 95))
        return "file:///" + newPath;

    qWarning() << "[EventManager] applyQrOverlayForNStrips: failed to save" << newPath;
    return imagePath;
}

// 2-strip horizontal (RX1 / QW410 5×15): strips side by side
QString EventManager::applyQrOverlayFor2(const QString &imagePath, const QString &qrUrl,
                                          double xNorm, double yNorm, double sizeNorm)
{
    return applyQrOverlayForNStrips(imagePath, qrUrl, xNorm, yNorm, sizeNorm, 2, /*stripsVertical=*/false);
}

// 2-strip vertical (RX1/620S 15×5 cut ngang): strips stacked top-to-bottom
// Canvas 15×10: strip trên (y=0..halfH) và strip dưới (y=halfH..fullH)
// xNorm/yNorm/sizeNorm normalized relative to ONE strip (segW=fullW, segH=fullH/2)
QString EventManager::applyQrOverlayFor2Vertical(const QString &imagePath, const QString &qrUrl,
                                                   double xNorm, double yNorm, double sizeNorm)
{
    return applyQrOverlayForNStrips(imagePath, qrUrl, xNorm, yNorm, sizeNorm, 2, /*stripsVertical=*/true);
}

// 3-strip vertical (QW410 5×10 cut): strips stacked top-to-bottom
QString EventManager::applyQrOverlayFor3(const QString &imagePath, const QString &qrUrl,
                                          double xNorm, double yNorm, double sizeNorm)
{
    return applyQrOverlayForNStrips(imagePath, qrUrl, xNorm, yNorm, sizeNorm, 3, /*stripsVertical=*/true);
}

void EventManager::syncEventToDynamoDB(int eventId) {
    if (!m_dynamoClient || !m_dbManager || eventId <= 0) return;
    
    Event event = m_dbManager->getEvent(eventId);
    if (event.id == 0) return;
    
    QString hwid;
    if (m_machineAuth) {
        hwid = m_machineAuth->hwid();
    }
    if (hwid.isEmpty()) {
        hwid = m_dbManager->getMachineHWID();
    }
    if (hwid.isEmpty()) {
        qWarning() << "[EventManager] skip syncEventToDynamoDB, no HWID";
        return;
    }
    
    int totalPhotos = m_dbManager->getPhotosForEvent(eventId).size();
    int printsCut = m_dbManager->getCutPrintCount(eventId);
    int printsNoCut = m_dbManager->getNoCutPrintCount(eventId);

    qDebug() << "[EventManager] Syncing event stats to DynamoDB for event" << eventId;
    m_dynamoClient->syncEventData(hwid, eventId, event.name, totalPhotos, printsCut, printsNoCut);
}

// ─── Scale layout for QW410 (600x1200 @300dpi) ───────────────────────────────
// QW410 in 300dpi. Khi user tải layout, nếu nó không phải 600x1200 hoặc tương đương
// (e.g. 1200x2400) thì scale để đạt đúng kích thước 300dpi layout.
// Chạy bất đồng bộ để không block UI.
void EventManager::scaleLayoutForQW410IfNeeded(const QString &layoutPath) {
    if (layoutPath.isEmpty()) return;

    QString printerName = m_printerConfig ? m_printerConfig->selectedPrinter() : QString();
    bool isQW410 = printerName.contains("QW410", Qt::CaseInsensitive)
               || printerName.contains("QW-410", Qt::CaseInsensitive)
               || printerName.contains("410", Qt::CaseInsensitive);

    if (!isQW410) {
        qDebug() << "[EventManager] scaleLayoutForQW410IfNeeded: Not QW410 printer, skipping scale";
        return;
    }

    // Run scaling asynchronously
    (void)QtConcurrent::run([this, layoutPath]() {
        QString cleanPath = layoutPath;
        if (cleanPath.startsWith("file:///")) cleanPath = cleanPath.mid(8);
        cleanPath = QDir::toNativeSeparators(cleanPath);

        QImage original(cleanPath);
        if (original.isNull()) {
            qWarning() << "[EventManager] scaleLayoutForQW410IfNeeded: Failed to load layout" << cleanPath;
            return;
        }

        int w = original.width();
        int h = original.height();
        double aspect = h > 0 ? (double)w / h : 0.0;

        qDebug() << "[EventManager] scaleLayoutForQW410IfNeeded: Original size" << w << "x" << h << "aspect" << aspect;

        // Target: 600×1200 (or 1200×2400, etc - but 600×1200 is standard @300dpi)
        const int targetW = 600;
        const int targetH = 1200;
        const double targetAspect = (double)targetW / targetH;  // ≈ 0.50

        // If already correct, skip
        if (w == targetW && h == targetH) {
            qDebug() << "[EventManager] scaleLayoutForQW410IfNeeded: Already correct size 600x1200";
            return;
        }

        // Check if aspect ratio matches (5×10 layout)
        if (qAbs(aspect - targetAspect) > 0.01) {
            qWarning() << "[EventManager] scaleLayoutForQW410IfNeeded: Aspect mismatch. Expected ~0.50, got" << aspect;
            return;
        }

        // Scale to target
        QImage scaled = original.scaledToWidth(targetW, Qt::SmoothTransformation);
        if (scaled.height() != targetH) {
            scaled = original.scaledToHeight(targetH, Qt::SmoothTransformation);
        }

        // Save to same directory with _qw410_scaled suffix
        QFileInfo fileInfo(cleanPath);
        QString baseName = fileInfo.completeBaseName();
        QString ext = fileInfo.suffix();
        QString scaledPath = fileInfo.absolutePath() + "/" + baseName + "_qw410_scaled." + ext;

        if (scaled.save(scaledPath, ext.toUpper().toLatin1().constData(), 100)) {
            qDebug() << "[EventManager] scaleLayoutForQW410IfNeeded: Scaled to" << scaled.width() << "x" << scaled.height()
                     << "saved to" << scaledPath;
            emit layoutScaledForQW410(cleanPath, scaledPath);
        } else {
            qWarning() << "[EventManager] scaleLayoutForQW410IfNeeded: Failed to save scaled layout" << scaledPath;
        }
    });
}

// ============= File Utilities =============

bool EventManager::writeTextFile(const QString &filePath, const QString &content) {
    QString path = filePath;
    if (path.startsWith("file:///"))
        path = QUrl(filePath).toLocalFile();
    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qWarning() << "[EventManager] writeTextFile: cannot open" << path << file.errorString();
        return false;
    }
    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);
    out << content;
    file.close();
    qDebug() << "[EventManager] writeTextFile: saved" << path;
    return true;
}

bool EventManager::ensureDir(const QString &dirPath) {
    QString path = dirPath;
    if (path.startsWith("file:///"))
        path = QUrl(dirPath).toLocalFile();
    if (path.isEmpty())
        return false;
    return QDir().mkpath(path);
}

void EventManager::restartApp() {
    const QString program = QCoreApplication::applicationFilePath();
    const QStringList args = QCoreApplication::arguments().mid(1);
    QProcess::startDetached(program, args);
    QCoreApplication::quit();
}

// ============= Employee Session / Accounts =============

QString EventManager::hashPassword(const QString &password) {
    return QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256)
            .toHex();
}

QString EventManager::employeeLogin(const QString &name, const QString &password) {
    const QString trimmed = name.trimmed();

    // Admin root — dùng PIN bảo mật chung; legacy admin_pin được migrate trong
    // verifySecurityPin().
    if (trimmed.compare("root", Qt::CaseInsensitive) == 0) {
        if (!verifySecurityPin(password))
            return QStringLiteral("Mật khẩu admin không đúng");
        m_currentEmployeeId   = -1;
        m_currentEmployeeName = QStringLiteral("Admin");
        emit currentEmployeeChanged();
        return QString();
    }

    // Nhân viên thường — tra theo họ tên.
    QVariantMap emp = m_dbManager->getEmployeeByName(trimmed);
    if (!emp.value("found").toBool())
        return QStringLiteral("Không tìm thấy nhân viên này");
    if (emp.value("pass_hash").toString() != hashPassword(password))
        return QStringLiteral("Mật khẩu không đúng");

    m_currentEmployeeId   = emp.value("id").toInt();
    m_currentEmployeeName = emp.value("full_name").toString();
    emit currentEmployeeChanged();
    return QString();
}

// Lưu lượt quét QR gần nhất (đăng nhập hoặc mở khóa Cài đặt) để hiển thị ở tab
// Thông tin — không thay đổi trạng thái đăng nhập.
void EventManager::recordQrScan(const QString &email, const QString &name, const QString &role) {
    setAppSetting(QStringLiteral("last_qr_login_email"), email.trimmed().toLower());
    setAppSetting(QStringLiteral("last_qr_login_name"), name.trimmed());
    setAppSetting(QStringLiteral("last_qr_login_role"), role);
    setAppSetting(QStringLiteral("last_qr_login_at"),
                  QDateTime::currentDateTime().toString(Qt::ISODate));
}

// Đăng nhập qua quét mã QR (đã được portal xác nhận): chủ studio → Admin (-1),
// nhân viên cloud → id dành riêng -2 (không trùng nhân viên local id > 0).
QString EventManager::qrLogin(const QString &email, const QString &name, const QString &role) {
    const QString trimmedEmail = email.trimmed().toLower();
    if (trimmedEmail.isEmpty())
        return QStringLiteral("Thiếu email người xác nhận");

    if (role == QStringLiteral("owner")) {
        m_currentEmployeeId   = -1;
        m_currentEmployeeName = QStringLiteral("Admin");
    } else {
        m_currentEmployeeId   = kCloudStaffEmployeeId;
        m_currentEmployeeName = name.trimmed().isEmpty() ? trimmedEmail : name.trimmed();
    }

    recordQrScan(trimmedEmail, name, role);
    emit currentEmployeeChanged();
    return QString();
}

void EventManager::employeeLogout() {
    m_currentEmployeeId   = 0;
    m_currentEmployeeName.clear();
    emit currentEmployeeChanged();
}

// Phiên KHÔNG được nhớ giữa các lần mở app — mỗi lần mở phải đăng nhập lại.
// Hàm này luôn đặt trạng thái về "chưa đăng nhập" để dialog đăng nhập hiện ra.
bool EventManager::restoreEmployeeSession() {
    m_currentEmployeeId = 0;
    m_currentEmployeeName.clear();
    emit currentEmployeeChanged();
    return false;
}

static QJsonObject settingObject(DatabaseManager *db, const QString &key) {
    const QString raw = db->getSetting(key, QStringLiteral("{}"));
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    return doc.isObject() ? doc.object() : QJsonObject();
}

static QVariantList normalizePermissionList(const QVariant &value) {
    QVariantList input = value.toList();
    QVariantList out;
    QSet<QString> seen;
    for (const QVariant &item : input) {
        const QString key = item.toString().trimmed();
        if (key.isEmpty() || seen.contains(key)) continue;
        seen.insert(key);
        out.append(key);
    }
    return out;
}

static QStringList permissionKeys(const QVariantList &permissions) {
    QStringList keys;
    for (const QVariant &item : permissions) {
        const QString key = item.toString().trimmed();
        if (!key.isEmpty() && !keys.contains(key)) keys << key;
    }
    return keys;
}

static QString uniqueEmployeeName(DatabaseManager *db, const QString &preferred, const QString &email) {
    QString base = preferred.trimmed();
    if (base.isEmpty()) base = email;
    if (!db->getEmployeeByName(base).value("found").toBool()) return base;

    const QString withEmail = QStringLiteral("%1 (%2)").arg(base, email);
    if (!db->getEmployeeByName(withEmail).value("found").toBool()) return withEmail;

    for (int i = 2; i < 100; ++i) {
        const QString candidate = QStringLiteral("%1 (%2 %3)").arg(base, email).arg(i);
        if (!db->getEmployeeByName(candidate).value("found").toBool()) return candidate;
    }
    return QStringLiteral("%1 (%2)").arg(email, QString::number(QDateTime::currentSecsSinceEpoch()));
}

QVariantList EventManager::employeePermissionCatalog() {
    QVariantList list;
    auto add = [&list](const QString &key, const QString &label) {
        QVariantMap row;
        row[QStringLiteral("key")] = key;
        row[QStringLiteral("label")] = label;
        list.append(row);
    };
    // ⚠️ ĐÂY LÀ NGUỒN CHUẨN DUY NHẤT của bộ khoá quyền. Trang quản trị web dùng
    // đúng những khoá này (web-lamoment/portal/portal.js → PERM_CATALOG) và lưu
    // chúng vào studio_staff.permissions trên Worker. Thêm/đổi khoá ở đây thì
    // PHẢI sửa cả bên đó, nếu không quyền tick trên web máy sẽ không hiểu.
    // Đổi nhãn thì tự do — chỉ khoá mới có ý nghĩa.
    add(QStringLiteral("revenue.view"), QStringLiteral("Xem và lọc doanh thu"));
    add(QStringLiteral("revenue.delete"), QStringLiteral("Xóa doanh thu"));
    add(QStringLiteral("voucher.create"), QStringLiteral("Tạo voucher/mã tiền mặt"));
    add(QStringLiteral("voucher.view"), QStringLiteral("Xem và lọc voucher"));
    add(QStringLiteral("voucher.delete"), QStringLiteral("Xóa voucher"));
    add(QStringLiteral("media.view"), QStringLiteral("Xem và lọc ảnh"));
    add(QStringLiteral("media.delete"), QStringLiteral("Xóa ảnh"));
    add(QStringLiteral("frame.manage"), QStringLiteral("Thêm frame từ xa"));
    add(QStringLiteral("filter.manage"), QStringLiteral("Quản lý filter từ xa"));
    add(QStringLiteral("background.manage"), QStringLiteral("Quản lý hình nền từ xa"));
    add(QStringLiteral("payment.manage"), QStringLiteral("Cấu hình thanh toán từ xa"));
    add(QStringLiteral("report.view"), QStringLiteral("Xem báo cáo"));
    add(QStringLiteral("report.resolve"), QStringLiteral("Xử lý lượt chụp"));
    add(QStringLiteral("machine.rename"), QStringLiteral("Đổi tên máy"));
    add(QStringLiteral("app.unlock"), QStringLiteral("Quét QR mở khóa ứng dụng"));
    return list;
}

QVariantList EventManager::getEmployees() {
    QVariantList list = m_dbManager->getEmployees();
    const QJsonObject cloudAccounts = settingObject(m_dbManager, QStringLiteral("cloud_staff_accounts"));
    const QJsonObject employeePerms = settingObject(m_dbManager, QStringLiteral("employee_permissions"));

    QHash<int, QJsonObject> cloudById;
    for (auto it = cloudAccounts.begin(); it != cloudAccounts.end(); ++it) {
        const QJsonObject row = it.value().toObject();
        const int id = row.value(QStringLiteral("id")).toInt(0);
        if (id > 0) cloudById.insert(id, row);
    }

    for (QVariant &item : list) {
        QVariantMap row = item.toMap();
        const int id = row.value(QStringLiteral("id")).toInt();
        const QString idKey = QString::number(id);
        const QJsonObject cloud = cloudById.value(id);
        const bool isCloud = !cloud.isEmpty();
        row[QStringLiteral("source")] = isCloud ? QStringLiteral("cloud") : QStringLiteral("local");
        row[QStringLiteral("cloud_email")] = isCloud ? cloud.value(QStringLiteral("email")).toString() : QString();

        QVariantList perms;
        if (employeePerms.contains(idKey)) {
            perms = employeePerms.value(idKey).toArray().toVariantList();
        } else if (isCloud) {
            perms = cloud.value(QStringLiteral("permissions")).toArray().toVariantList();
        }
        row[QStringLiteral("permissions")] = normalizePermissionList(perms);
        item = row;
    }
    return list;
}

int EventManager::syncCloudStaffAccounts(const QVariantList &staffList) {
    QJsonObject cloudAccounts = settingObject(m_dbManager, QStringLiteral("cloud_staff_accounts"));
    QJsonObject employeePerms = settingObject(m_dbManager, QStringLiteral("employee_permissions"));
    int changed = 0;

    for (const QVariant &item : staffList) {
        const QVariantMap staff = item.toMap();
        const QString email = staff.value(QStringLiteral("staff_email")).toString().trimmed().toLower();
        if (email.isEmpty()) continue;

        const QString staffName = staff.value(QStringLiteral("staff_name")).toString().trimmed();
        const QString displayName = staffName.isEmpty() ? email : staffName;
        const QVariantList perms = normalizePermissionList(staff.value(QStringLiteral("permissions")));

        QJsonObject account = cloudAccounts.value(email).toObject();
        int id = account.value(QStringLiteral("id")).toInt(0);
        QVariantMap existing = id > 0 ? m_dbManager->getEmployee(id) : QVariantMap();
        if (!existing.value(QStringLiteral("found")).toBool()) {
            id = 0;
        }

        if (id <= 0) {
            const QString localName = uniqueEmployeeName(m_dbManager, displayName, email);
            QString prefix;
            for (int i = 1; i <= 999; ++i) {
                const QString candidate = QStringLiteral("NV%1").arg(i, 2, 10, QChar('0'));
                if (!m_dbManager->employeePrefixExists(candidate)) { prefix = candidate; break; }
            }
            if (prefix.isEmpty()) continue;
            id = m_dbManager->createEmployee(localName, prefix, hashPassword(QStringLiteral("0000")));
            if (id <= 0) continue;
            account[QStringLiteral("full_name")] = localName;
            ++changed;
        } else {
            const QString currentName = existing.value(QStringLiteral("full_name")).toString();
            const QString previousName = account.value(QStringLiteral("full_name")).toString();
            if (!displayName.isEmpty() && currentName == previousName && currentName != displayName &&
                !m_dbManager->getEmployeeByName(displayName).value(QStringLiteral("found")).toBool()) {
                if (m_dbManager->updateEmployeeName(id, displayName)) {
                    account[QStringLiteral("full_name")] = displayName;
                    ++changed;
                }
            } else if (account.value(QStringLiteral("full_name")).toString().isEmpty()) {
                account[QStringLiteral("full_name")] = currentName;
            }
        }

        account[QStringLiteral("id")] = id;
        account[QStringLiteral("email")] = email;
        account[QStringLiteral("staff_name")] = staffName;
        account[QStringLiteral("permissions")] = QJsonArray::fromStringList(permissionKeys(perms));
        account[QStringLiteral("synced_at")] = QDateTime::currentDateTime().toString(Qt::ISODate);
        cloudAccounts[email] = account;

        const QString idKey = QString::number(id);
        const QJsonArray nextPerms = QJsonArray::fromStringList(permissionKeys(perms));
        if (employeePerms.value(idKey).toArray() != nextPerms) {
            employeePerms[idKey] = nextPerms;
            ++changed;
        }
    }

    m_dbManager->setSetting(QStringLiteral("cloud_staff_accounts"),
                            QString::fromUtf8(QJsonDocument(cloudAccounts).toJson(QJsonDocument::Compact)));
    m_dbManager->setSetting(QStringLiteral("employee_permissions"),
                            QString::fromUtf8(QJsonDocument(employeePerms).toJson(QJsonDocument::Compact)));
    return changed;
}

QString EventManager::createEmployee(const QString &fullName, const QString &password) {
    const QString name = fullName.trimmed();
    if (name.isEmpty())
        return QStringLiteral("Vui lòng nhập họ và tên");
    if (name.compare("root", Qt::CaseInsensitive) == 0)
        return QStringLiteral("Tên 'root' dành cho admin");
    if (m_dbManager->getEmployeeByName(name).value("found").toBool())
        return QStringLiteral("Đã tồn tại nhân viên cùng tên");

    // Tự sinh tiền tố NVxx duy nhất (NV01, NV02, …).
    QString prefix;
    for (int i = 1; i <= 999; ++i) {
        QString candidate = QString("NV%1").arg(i, 2, 10, QChar('0'));
        if (!m_dbManager->employeePrefixExists(candidate)) { prefix = candidate; break; }
    }
    if (prefix.isEmpty())
        return QStringLiteral("Không cấp được tiền tố mã");

    QString pass = password.isEmpty() ? QStringLiteral("0000") : password;
    int id = m_dbManager->createEmployee(name, prefix, hashPassword(pass));
    if (id < 0)
        return QStringLiteral("Tạo nhân viên thất bại");
    qDebug() << "[Employee] Created" << name << "prefix" << prefix << "id" << id;
    return QString();
}

bool EventManager::setEmployeePassword(int id, const QString &newPassword) {
    QString pass = newPassword.isEmpty() ? QStringLiteral("0000") : newPassword;
    return m_dbManager->updateEmployeePassword(id, hashPassword(pass));
}

bool EventManager::setEmployeePermissions(int id, const QVariantList &permissions) {
    if (id <= 0 || !m_dbManager->getEmployee(id).value(QStringLiteral("found")).toBool())
        return false;

    QJsonObject employeePerms = settingObject(m_dbManager, QStringLiteral("employee_permissions"));
    employeePerms[QString::number(id)] = QJsonArray::fromStringList(permissionKeys(normalizePermissionList(permissions)));
    return m_dbManager->setSetting(QStringLiteral("employee_permissions"),
                                   QString::fromUtf8(QJsonDocument(employeePerms).toJson(QJsonDocument::Compact)));
}

bool EventManager::renameEmployee(int id, const QString &fullName) {
    const QString name = fullName.trimmed();
    if (name.isEmpty()) return false;
    return m_dbManager->updateEmployeeName(id, name);
}

bool EventManager::deleteEmployee(int id) {
    return m_dbManager->deleteEmployee(id);
}

// ============= Voucher Operations =============

// ─────────────────────────────────────────────────────────────────────────────
// CHẾ ĐỘ "MÃ TẠI MÁY" (local-first)
//
// true  → mã voucher / mã tiền mặt tạo tại máy sẽ:
//           • sinh thẳng trong DB máy, KHÔNG xin cloud cấp mã;
//           • KHÔNG bao giờ được đẩy lên kho studio (server xóa cũng không mất mã);
//           • được ưu tiên tuyệt đối khi kiểm tra / sử dụng / xóa — không hỏi cloud.
//         Mã do web tạo (không có bản ghi tại máy) vẫn dùng cloud như cũ, và mã cũ
//         đã từng đồng bộ (synced=1) cũng giữ nguyên luồng cloud để tránh xài 2 lần
//         trên nhiều máy.
// false → quay lại cơ chế cũ: cloud cấp mã và là nguồn chân lý.
//
// Không áp dụng cho mã gói chụp (package_code) vì mã đó do web/portal phát hành.
static constexpr bool kCodesLocalFirst = true;

// Mã voucher = 4 chữ số thuần (không tiền tố). Kho dùng chung web + mọi máy của studio.
static QString makeVoucherCode() {
    int n = QRandomGenerator::global()->bounded(10000); // 0..9999
    return QString("%1").arg(n, 4, 10, QChar('0'));
}

// Có bản ghi tại máy và chưa từng đẩy lên cloud → mã "của máy này".
bool EventManager::isLocalOnlyCode(const QString &code) const {
    if (!kCodesLocalFirst || !m_dbManager) return false;
    const QVariantMap row = m_dbManager->getVoucher(code.toUpper());
    return row.value("found").toBool() && !row.value("synced").toBool();
}

// Danh sách hiển thị cho admin được kéo từ cloud; mã tại máy không nằm trên cloud
// nên phải chèn thêm vào đây, nếu không mã vừa tạo sẽ "biến mất" sau lần poll kế.
QVariantList EventManager::mergeLocalCodesIntoCloudList(const QVariantList &cloudList) const {
    if (!kCodesLocalFirst || !m_dbManager) return cloudList;

    const int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    QVariantList locals = m_dbManager->getVouchers("all", empFilter, "voucher");
    locals += m_dbManager->getVouchers("all", empFilter, "cash_code");

    QHash<int, QString> nameCache;
    QSet<QString> localCodes;
    QVariantList merged;
    for (const QVariant &item : locals) {
        QVariantMap v = item.toMap();
        // Mã gói chụp do web phát hành — để cloud quản lý, không trộn vào đây.
        if (v.value("type").toString() == "package_code") continue;
        if (v.value("synced").toBool()) continue;   // đã có trên cloud → dùng bản cloud

        const int empId = v.value("employee_id").toInt();
        QString name;
        if (empId == -1) name = QStringLiteral("Admin");
        else if (nameCache.contains(empId)) name = nameCache.value(empId);
        else {
            name = m_dbManager->getEmployee(empId).value("full_name").toString();
            if (name.isEmpty()) name = QStringLiteral("Nhân viên");
            nameCache.insert(empId, name);
        }
        v["created_by"] = name;
        localCodes.insert(v.value("code").toString().toUpper());
        merged << v;
    }

    // Mã tại máy đứng trước; bản cloud trùng mã bị bỏ (bản tại máy mới là bản dùng).
    for (const QVariant &item : cloudList) {
        const QString code = item.toMap().value("code").toString().toUpper();
        if (localCodes.contains(code)) continue;
        merged << item;
    }
    return merged;
}

QString EventManager::currentHwid() const {
    if (m_machineAuth && !m_machineAuth->hwid().isEmpty()) return m_machineAuth->hwid();
    return m_dbManager ? m_dbManager->getMachineHWID() : QString();
}

void EventManager::syncPendingVouchers() {
    // Chế độ "mã tại máy": KHÔNG đẩy mã lên cloud. Mã nằm nguyên ở máy nên admin
    // hay sự cố phía server đều không xóa được mã đã in cho khách.
    if (kCodesLocalFirst) {
        qDebug() << "[Voucher] Chế độ mã tại máy — bỏ qua đồng bộ lên cloud";
        return;
    }
    if (!m_dynamoClient || !m_dbManager) return;
    const QString hwid = currentHwid();
    if (hwid.isEmpty()) return;
    const QVariantList pending = m_dbManager->getUnsyncedVouchers();
    if (pending.isEmpty()) return;

    // Bồi created_by = TÊN nhân viên (cloud ghi nguồn cho báo cáo). Cache theo employee_id.
    QHash<int, QString> nameCache;
    QVariantList payload;
    QStringList codes;
    for (const QVariant &item : pending) {
        QVariantMap v = item.toMap();
        const int empId = v.value("employee_id").toInt();
        QString name;
        if (empId == -1) name = "Admin";
        else if (nameCache.contains(empId)) name = nameCache.value(empId);
        else {
            name = m_dbManager->getEmployee(empId).value("full_name").toString();
            if (name.isEmpty()) name = "Nhân viên";
            nameCache.insert(empId, name);
        }
        QVariantMap out;
        out["code"]        = v.value("code");
        out["type"]        = v.value("type");
        out["value"]       = v.value("value");
        out["valid_from"]  = v.value("valid_from");
        out["valid_until"] = v.value("valid_until");
        out["shift"]       = v.value("shift");
        out["note"]        = v.value("note");
        out["created_by"]  = name;
        out["created_at"]  = v.value("created_at");
        payload << out;
        codes << v.value("code").toString();
    }

    QVariantMap res = m_dynamoClient->pushVouchersCloudSync(hwid, payload);
    if (!res.value("network_error").toBool() && res.value("success").toBool()) {
        m_dbManager->markVouchersSynced(codes);
        qDebug() << "[Voucher] Synced" << codes.size() << "mã lên cloud (pushed="
                 << res.value("pushed").toInt() << ")";
    } else {
        qWarning() << "[Voucher] Đẩy mã lên cloud thất bại (giữ lại retry):"
                   << res.value("error");
    }
}

// Voucher giảm giá: cloud là nguồn chân lý (dùng chung mọi máy của studio).
// Mất mạng → fallback local. Quy tắc nghiệp vụ (cash <= requiredAmount, loại cash_code
// không nhận ở đây) áp dụng phía trên kết quả cloud.
QVariantMap EventManager::validateVoucher(const QString &code, int requiredAmount) {
    const QString normalized = code.toUpper().remove(' ').remove('\t');
    // ƯU TIÊN MÃ TẠI MÁY: mã do máy này tạo được xử lý hoàn toàn tại chỗ, kể cả
    // khi cloud vẫn sống (cloud không có mã này nên hỏi cloud sẽ báo sai mã).
    if (isLocalOnlyCode(normalized)) {
        qDebug() << "[Voucher] Dùng mã tại máy:" << normalized;
        return validateVoucherLocal(normalized, requiredAmount);
    }
    if (m_dynamoClient) {
        QVariantMap cloud = m_dynamoClient->validateVoucherCloud(currentHwid(), normalized);
        if (!cloud.value("network_error").toBool()) {
            QVariantMap result;
            if (!cloud.value("valid").toBool()) {
                result["valid"] = false;
                result["error"] = cloud.value("error").toString().isEmpty()
                                  ? QStringLiteral("Sai mã voucher") : cloud.value("error").toString();
                return result;
            }
            const QString type = cloud.value("type").toString();
            const int value = cloud.value("value").toInt();
            if (type == "cash_code") {                 // mã tiền mặt không nhận ở luồng voucher
                result["valid"] = false; result["error"] = "Sai mã voucher"; return result;
            }
            if (type == "cash" && requiredAmount >= 0 && value > requiredAmount) {
                result["valid"] = false;
                result["error"] = "Voucher vượt quá số tiền cần thanh toán";
                return result;
            }
            result["valid"] = true; result["code"] = normalized;
            result["type"] = type;  result["value"] = value;
            return result;
        }
        qWarning() << "[Voucher] Cloud validate lỗi mạng → fallback local:" << cloud.value("error");
    }
    return validateVoucherLocal(normalized, requiredAmount);
}

QVariantMap EventManager::validateVoucherLocal(const QString &code, int requiredAmount) {
    QVariantMap result;
    QString normalized = code.toUpper().remove(' ').remove('\t');

    QVariantMap row = m_dbManager->getVoucher(normalized);
    if (!row.value("found").toBool()) {
        result["valid"] = false;
        result["error"] = "Sai mã voucher";
        return result;
    }
    if (row.value("used").toBool()) {
        result["valid"] = false;
        result["error"] = "Voucher này đã được sử dụng";
        return result;
    }

    // Khung giờ hiệu lực theo ca (ISO datetime; rỗng = không giới hạn).
    const QDateTime now = QDateTime::currentDateTime();
    QString vFrom  = row.value("valid_from").toString();
    QString vUntil = row.value("valid_until").toString();
    if (!vFrom.isEmpty()) {
        QDateTime from = QDateTime::fromString(vFrom, Qt::ISODate);
        if (from.isValid() && now < from) {
            result["valid"] = false;
            result["error"] = "Voucher chưa tới giờ hiệu lực";
            return result;
        }
    }
    if (!vUntil.isEmpty()) {
        QDateTime until = QDateTime::fromString(vUntil, Qt::ISODate);
        if (until.isValid() && now > until) {
            result["valid"] = false;
            result["error"] = "Voucher đã hết hạn sử dụng";
            return result;
        }
    }

    // Ngày hết hạn chung (tương thích cũ, format "YYYY-MM-DD").
    QString expiryStr = m_dbManager->getSetting("voucher_expiry_date", "");
    if (!expiryStr.isEmpty()) {
        QDate expiry = QDate::fromString(expiryStr, "yyyy-MM-dd");
        if (expiry.isValid() && QDate::currentDate() > expiry) {
            result["valid"] = false;
            result["error"] = "Voucher đã hết hạn sử dụng";
            return result;
        }
    }

    const QString type = row.value("type").toString();
    if (type == "cash_code") {
        result["valid"] = false;
        result["error"] = "Sai mã voucher";
        return result;
    }

    const int value = row.value("value").toInt();

    // Voucher "cash": hợp lệ khi giá trị KHÔNG vượt quá số tiền cần thanh toán.
    // (vd cần trả 70.000 → voucher 1.000–70.000 hợp lệ; 80.000 không hợp lệ).
    // Khi áp dụng sẽ trừ thẳng giá trị voucher vào số tiền cần trả.
    if (type == "cash" && requiredAmount >= 0 && value > requiredAmount) {
        result["valid"] = false;
        result["error"] = "Voucher vượt quá số tiền cần thanh toán";
        return result;
    }

    result["valid"]       = true;
    result["code"]        = row["code"];
    result["type"]        = type;
    result["value"]       = value;
    result["employee_id"] = row["employee_id"];
    return result;
}

bool EventManager::redeemVoucher(const QString &code, const QString &sessionId, int paidAmount) {
    // Người dùng voucher = nhân viên đang đăng nhập (0 nếu chưa đăng nhập / admin chung).
    int usedBy = (m_currentEmployeeId > 0) ? m_currentEmployeeId : 0;
    const QString normalized = code.toUpper();
    // Mã tại máy: đánh dấu đã dùng ngay trong DB máy, không đụng cloud.
    if (isLocalOnlyCode(normalized))
        return m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
    if (m_dynamoClient) {
        QVariantMap cloud = m_dynamoClient->redeemVoucherCloud(currentHwid(), normalized,
                                                               sessionId, usedBy, paidAmount);
        if (!cloud.value("network_error").toBool()) {
            const bool ok = cloud.value("success").toBool();
            // Đồng bộ trạng thái local (best-effort cho mã gốc-desktop; mã gốc-web không có row local).
            if (ok) m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
            return ok;
        }
        qWarning() << "[Voucher] Cloud redeem lỗi mạng → fallback local:" << cloud.value("error");
    }
    return m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
}

QStringList EventManager::generateVouchers(int value, int count,
                                           const QString &validFrom,
                                           const QString &validUntil,
                                           const QString &shift,
                                           const QString &note) {
    return generateCodesInternal("cash", value, count, validFrom, validUntil, shift, note);
}

// Sinh mã 4 số (không tiền tố). Ưu tiên cloud sinh (duy nhất toàn studio) khi online;
// mất mạng → sinh local rồi đồng bộ sau. created_by = TÊN nhân viên (cho báo cáo).
QStringList EventManager::generateCodesInternal(const QString &type, int value, int count,
                                                const QString &validFrom, const QString &validUntil,
                                                const QString &shift, const QString &note) {
    QStringList codes;
    if (m_currentEmployeeId == 0) {
        qWarning() << "[Voucher] generateCodesInternal: chưa đăng nhập nhân viên";
        emit error("Vui lòng đăng nhập trước khi tạo mã");
        return codes;
    }
    const QString createdBy = m_currentEmployeeName.isEmpty() ? QStringLiteral("Admin")
                                                              : m_currentEmployeeName;
    const QString hwid = currentHwid();
    const QString normalizedValidFrom = normalizeVoucherDateTimeForCloud(validFrom);
    const QString normalizedValidUntil = normalizeVoucherDateTimeForCloud(validUntil);

    // Online: cloud cấp mã 4 số DUY NHẤT → lưu local (đánh dấu đã đồng bộ) để không đẩy lại.
    if (!kCodesLocalFirst && m_dynamoClient && !hwid.isEmpty()) {
        QVariantMap res = m_dynamoClient->generateVouchersCloud(hwid, type, value, count,
                                                                normalizedValidFrom, normalizedValidUntil, note, createdBy);
        if (!res.value("network_error").toBool() && res.value("success").toBool()) {
            const QVariantList cloudCodes = res.value("codes").toList();
            QStringList synced;
            for (const QVariant &c : cloudCodes) {
                const QString code = c.toString();
                if (code.isEmpty()) continue;
                m_dbManager->insertVoucher(code, type, value, m_currentEmployeeId,
                                           normalizedValidFrom, normalizedValidUntil, shift, note);
                codes << code;
                synced << code;
            }
            if (!synced.isEmpty()) m_dbManager->markVouchersSynced(synced);
            qDebug() << "[Voucher] Cloud-generated" << codes.size() << type << "value" << value
                     << "by" << createdBy;
            return codes;
        }
        qWarning() << "[Voucher] Cloud generate lỗi mạng → sinh local:" << res.value("error");
    }

    // Sinh tại máy: mã 4 số duy nhất trong DB máy. Đây là đường đi CHÍNH khi bật
    // chế độ "mã tại máy" (và vẫn là fallback offline khi tắt chế độ đó).
    int attempts = 0;
    while (codes.size() < count && attempts < count * 20) {
        ++attempts;
        QString code = makeVoucherCode();
        if (m_dbManager->insertVoucher(code, type, value, m_currentEmployeeId,
                                       normalizedValidFrom, normalizedValidUntil, shift, note))
            codes << code;
    }
    qDebug() << "[Voucher] Local-generated" << codes.size() << type << "value" << value
             << "by" << createdBy;
    // Chế độ "mã tại máy" giữ mã ở lại máy (syncPendingVouchers là no-op).
    syncPendingVouchers();
    return codes;
}

QVariantList EventManager::getVoucherList(const QString &filter) {
    // Admin (-1) thấy tất cả; nhân viên chỉ thấy của mình.
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getVouchers(filter, empFilter, "voucher");
}

// Kéo danh sách voucher toàn studio từ cloud (ASYNC). Kết quả về qua cloudVouchersReady.
// QML dùng cho poll realtime; nếu ok=false (mất mạng) QML tự fallback getVoucherList().
void EventManager::refreshCloudVouchers(const QString &filter) {
    const QString hwid = currentHwid();
    if (!m_dynamoClient || hwid.isEmpty()) {
        emit cloudVouchersReady(QVariantList(), false);
        return;
    }
    m_dynamoClient->fetchVoucherList(hwid, filter);
}

// Đọc preset ghi chú / giá gợi ý / thời gian hiệu lực từ cloud (đồng nhất với web).
// Trả {notes, prices, durations, network_error}; cache lần cuối để fallback offline.
QVariantMap EventManager::getVoucherPresets() {
    const QString hwid = currentHwid();
    if (m_dynamoClient && !hwid.isEmpty()) {
        QVariantMap res = m_dynamoClient->voucherPresetsCloud(hwid);
        if (!res.value("network_error").toBool()) {
            m_voucherPresetsCache = res;
            return res;
        }
    }
    return m_voucherPresetsCache; // rỗng nếu chưa từng tải được
}

bool EventManager::deleteVoucher(const QString &code) {
    if (!isAdmin()) {
        qWarning() << "[Permission] Staff attempted to delete voucher/code" << code;
        emit error(QStringLiteral("Chỉ admin được xóa voucher hoặc mã"));
        return false;
    }
    const QString up = code.toUpper();
    // Mã tại máy không có bản trên cloud → xóa local là xong, không cần mạng.
    const bool localOnly = isLocalOnlyCode(up);
    // Xo� b?n local tru?c (fallback offline / danh s�ch nh�n vi�n).
    const bool localOk = m_dbManager->deleteVoucher(up);
    if (localOnly) {
        qDebug() << "[Voucher] Đã xóa mã tại máy:" << up << "ok" << localOk;
        return localOk;
    }

    // QUAN TR?NG: kho voucher to�n studio n?m tr�n CLOUD v� l� ngu?n ch�n l� cho
    // m�n admin (danh s�ch du?c poll l?i t? cloud m?i 12s). N?u ch? xo� local, m� s?
    // HI?N L?I sau l?n poll k? ? ph?i xo� c? tr�n cloud.
    const QString hwid = currentHwid();
    if (m_dynamoClient && !hwid.isEmpty()) {
        QVariantMap res = m_dynamoClient->deleteVoucherCloud(hwid, up);
        const bool netErr = res.value("network_error").toBool();
        const bool cloudOk = res.value("success").toBool();
        if (netErr) {
            // M?t m?ng: kh�ng xo� du?c cloud ? m� v?n c�n tr�n kho studio. B�o l?i d?
            // caller kh�ng hi?n th? "d� xo�" gi?.
            qWarning() << "[Voucher] Cloud delete network error for" << up << ":" << res.value("error").toString();
            emit error(QStringLiteral("M�y chưa kết nối mạng � chưa xo� được mã trên kho studio"));
            return false;
        }
        if (!cloudOk)
            qWarning() << "[Voucher] Cloud delete failed for" << up << ":" << res.value("error").toString();
        return cloudOk;
    }
    // Kh�ng c� cloud client / hwid ? ch? c�n c�ch local.
    return localOk;
}

void EventManager::deleteVoucherBatch(const QString &kind, const QVariantList &items) {
    const QString normalizedKind = (kind == "cash") ? QStringLiteral("cash") : QStringLiteral("voucher");
    const int requested = items.size();
    if (!isAdmin()) {
        qWarning() << "[VoucherDelete] Non-admin attempted batch delete" << normalizedKind << requested;
        emit voucherBatchDeleteFinished(normalizedKind, requested, 0, 0, requested,
                                        QStringLiteral("Only admin can delete codes"));
        return;
    }

    QStringList codes;
    QSet<QString> seen;
    for (const QVariant &item : items) {
        QVariantMap row = item.toMap();
        QString code = row.value(QStringLiteral("code")).toString().trimmed().toUpper();
        if (code.isEmpty() && item.canConvert<QString>())
            code = item.toString().trimmed().toUpper();
        if (code.isEmpty() || seen.contains(code)) continue;
        seen.insert(code);
        codes << code;
    }

    qDebug() << "[VoucherDelete] Batch start" << normalizedKind << "requested" << requested
             << "eligible" << codes.size();

    if (codes.isEmpty()) {
        const QString msg = QStringLiteral("No codes selected");
        qDebug() << "[VoucherDelete] Batch finish" << normalizedKind << "deleted" << 0
                 << "failed" << 0;
        emit voucherBatchDeleteFinished(normalizedKind, requested, 0, 0, 0, msg);
        return;
    }

    // Tách mã tại máy ra xóa ngay tại chỗ; phần còn lại (mã trên kho studio) mới gửi cloud.
    int localDeleted = 0;
    int localFailed = 0;
    QStringList cloudTargets;
    for (const QString &code : codes) {
        if (!isLocalOnlyCode(code)) { cloudTargets << code; continue; }
        if (m_dbManager->deleteVoucher(code)) localDeleted++;
        else localFailed++;
    }
    if (localDeleted || localFailed)
        qDebug() << "[VoucherDelete] Mã tại máy đã xóa" << localDeleted << "lỗi" << localFailed;

    const QString hwid = currentHwid();
    if (cloudTargets.isEmpty() || !m_dynamoClient || hwid.isEmpty()) {
        int deleted = localDeleted;
        int failed = localFailed;
        for (int i = 0; i < cloudTargets.size(); ++i) {
            if (m_dbManager->deleteVoucher(cloudTargets.at(i))) deleted++;
            else failed++;
            emit voucherBatchDeleteProgress(normalizedKind, i + 1, cloudTargets.size());
        }
        qDebug() << "[VoucherDelete] Local batch finish" << normalizedKind << "deleted" << deleted
                 << "failed" << failed;
        emit voucherBatchDeleteFinished(normalizedKind, requested, deleted, 0, failed,
                                        QStringLiteral("Batch delete finished"));
        return;
    }

    const QString batchId = QStringLiteral("%1:%2:%3")
        .arg(normalizedKind, QString::number(QDateTime::currentMSecsSinceEpoch()), QString::number(requested));
    VoucherDeleteBatchState state;
    state.kind = normalizedKind;
    state.requested = requested;
    state.totalCloud = cloudTargets.size();
    // Mã tại máy đã xóa xong ở trên → cộng sẵn vào kết quả tổng của lô.
    state.deleted = localDeleted;
    state.failed = localFailed;
    m_voucherDeleteBatches.insert(batchId, state);

    for (const QString &code : cloudTargets)
        m_dynamoClient->deleteVoucherCloudAsync(hwid, code, batchId);
}
QString EventManager::finishVoucherDeleteBatch(const QString &batchId) {
    if (!m_voucherDeleteBatches.contains(batchId)) return QString();
    const VoucherDeleteBatchState state = m_voucherDeleteBatches.take(batchId);
    qDebug() << "[VoucherDelete] Cloud batch finish" << state.kind << "requested" << state.requested
             << "deleted" << state.deleted << "skippedUsed" << state.skippedUsed
             << "failed" << state.failed;
    const QString msg = QStringLiteral("Batch delete finished");
    emit voucherBatchDeleteFinished(state.kind, state.requested, state.deleted,
                                    state.skippedUsed, state.failed, msg);
    return msg;
}
int EventManager::getVoucherCount(const QString &filter) {
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getVoucherCount(filter, empFilter, "voucher");
}

// Mã tiền mặt: cloud là nguồn chân lý. Mất mạng → fallback local. Yêu cầu khớp đúng số tiền.
QVariantMap EventManager::validateCashPaymentCode(const QString &code, int requiredAmount) {
    const QString normalized = code.toUpper().remove(' ').remove('\t');
    // Ưu tiên mã tại máy (xem kCodesLocalFirst).
    if (isLocalOnlyCode(normalized)) {
        qDebug() << "[CashCode] Dùng mã tại máy:" << normalized;
        return validateCashPaymentCodeLocal(normalized, requiredAmount);
    }
    if (m_dynamoClient) {
        QVariantMap cloud = m_dynamoClient->validateVoucherCloud(currentHwid(), normalized);
        if (!cloud.value("network_error").toBool()) {
            QVariantMap result;
            const QString type = cloud.value("type").toString();
            if (!cloud.value("valid").toBool() || type != "cash_code") {
                result["valid"] = false;
                result["error"] = (!cloud.value("valid").toBool() && !cloud.value("error").toString().isEmpty())
                                  ? cloud.value("error").toString() : QStringLiteral("Sai mã tiền mặt");
                return result;
            }
            const int value = cloud.value("value").toInt();
            if (requiredAmount >= 0 && value != requiredAmount) {
                result["valid"] = false;
                result["error"] = "Mã tiền mặt không khớp số tiền cần thanh toán";
                return result;
            }
            result["valid"] = true; result["code"] = normalized;
            result["type"] = type;  result["value"] = value;
            return result;
        }
        qWarning() << "[CashCode] Cloud validate lỗi mạng → fallback local:" << cloud.value("error");
    }
    return validateCashPaymentCodeLocal(normalized, requiredAmount);
}

QVariantMap EventManager::validateCashPaymentCodeLocal(const QString &code, int requiredAmount) {
    QVariantMap result;
    QString normalized = code.toUpper().remove(' ').remove('\t');

    QVariantMap row = m_dbManager->getVoucher(normalized);
    if (!row.value("found").toBool() || row.value("type").toString() != "cash_code") {
        result["valid"] = false;
        result["error"] = "Sai mã tiền mặt";
        return result;
    }
    if (row.value("used").toBool()) {
        result["valid"] = false;
        result["error"] = "Mã tiền mặt này đã được sử dụng";
        return result;
    }

    const QDateTime now = QDateTime::currentDateTime();
    QString vFrom  = row.value("valid_from").toString();
    QString vUntil = row.value("valid_until").toString();
    if (!vFrom.isEmpty()) {
        QDateTime from = QDateTime::fromString(vFrom, Qt::ISODate);
        if (from.isValid() && now < from) {
            result["valid"] = false;
            result["error"] = "Mã tiền mặt chưa tới giờ hiệu lực";
            return result;
        }
    }
    if (!vUntil.isEmpty()) {
        QDateTime until = QDateTime::fromString(vUntil, Qt::ISODate);
        if (until.isValid() && now > until) {
            result["valid"] = false;
            result["error"] = "Mã tiền mặt đã hết hạn sử dụng";
            return result;
        }
    }

    const int value = row.value("value").toInt();
    if (requiredAmount >= 0 && value != requiredAmount) {
        result["valid"] = false;
        result["error"] = "Mã tiền mặt không khớp số tiền cần thanh toán";
        return result;
    }

    result["valid"]       = true;
    result["code"]        = row["code"];
    result["type"]        = row["type"];
    result["value"]       = value;
    result["employee_id"] = row["employee_id"];
    return result;
}

bool EventManager::redeemCashPaymentCode(const QString &code, const QString &sessionId, int paidAmount) {
    int usedBy = (m_currentEmployeeId > 0) ? m_currentEmployeeId : 0;
    const QString normalized = code.toUpper();
    // Mã tại máy: đánh dấu đã dùng ngay trong DB máy, không đụng cloud.
    if (isLocalOnlyCode(normalized))
        return m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
    if (m_dynamoClient) {
        QVariantMap cloud = m_dynamoClient->redeemVoucherCloud(currentHwid(), normalized,
                                                               sessionId, usedBy, paidAmount);
        if (!cloud.value("network_error").toBool()) {
            const bool ok = cloud.value("success").toBool();
            if (ok) m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
            return ok;
        }
        qWarning() << "[CashCode] Cloud redeem lỗi mạng → fallback local:" << cloud.value("error");
    }
    return m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
}

// Mã gói chụp trả trước: cloud là nguồn chân lý (mã do web/portal tạo). Mất mạng →
// fallback local, chỉ dùng được nếu mã từng được sync về máy. Trả kèm metadata gói.
QVariantMap EventManager::validatePackageCode(const QString &code) {
    const QString normalized = code.toUpper().remove(' ').remove('\t');
    if (isLocalOnlyCode(normalized)) {
        qDebug() << "[PackageCode] Dùng mã gói tại máy:" << normalized;
        return validatePackageCodeLocal(normalized);
    }
    if (m_dynamoClient) {
        QVariantMap cloud = m_dynamoClient->validateVoucherCloud(currentHwid(), normalized);
        if (!cloud.value("network_error").toBool()) {
            QVariantMap result;
            const QString type = cloud.value("type").toString();
            if (!cloud.value("valid").toBool() || type != "package_code") {
                result["valid"] = false;
                // KHÔNG dùng chuỗi lỗi từ server: một số message trả về bị double-encode
                // UTF-8 nên hiển thị lỗi font (mojibake). Luôn dùng thông báo tiếng Việt
                // sinh tại máy để đảm bảo đúng font (sai mã hoặc hết hạn đều gộp chung).
                result["error"] = QStringLiteral("Mã gói chụp không đúng hoặc đã hết hạn");
                return result;
            }
            result["valid"]           = true;
            result["code"]            = normalized;
            result["type"]            = type;
            result["value"]           = cloud.value("value").toInt();
            result["package_minutes"] = cloud.value("package_minutes").toInt();
            result["package_prints"]  = qMax(1, cloud.value("package_prints").toInt());
            result["package_name"]    = cloud.value("package_name").toString();
            return result;
        }
        qWarning() << "[PackageCode] Cloud validate lỗi mạng → fallback local:" << cloud.value("error");
    }
    return validatePackageCodeLocal(normalized);
}

QVariantMap EventManager::validateLocalPackageCode(const QString &code) {
    return validatePackageCodeLocal(code);
}

QVariantMap EventManager::validatePackageCodeLocal(const QString &code) {
    QVariantMap result;
    QString normalized = code.toUpper().remove(' ').remove('\t');

    QVariantMap row = m_dbManager->getVoucher(normalized);
    if (!row.value("found").toBool() || row.value("type").toString() != "package_code") {
        result["valid"] = false;
        result["error"] = "Sai mã gói chụp";
        return result;
    }
    if (row.value("used").toBool()) {
        result["valid"] = false;
        result["error"] = "Mã gói chụp này đã được sử dụng";
        return result;
    }

    const QDateTime now = QDateTime::currentDateTime();
    QString vFrom  = row.value("valid_from").toString();
    QString vUntil = row.value("valid_until").toString();
    if (!vFrom.isEmpty()) {
        QDateTime from = QDateTime::fromString(vFrom, Qt::ISODate);
        if (from.isValid() && now < from) {
            result["valid"] = false;
            result["error"] = "Mã gói chụp chưa tới giờ hiệu lực";
            return result;
        }
    }
    if (!vUntil.isEmpty()) {
        QDateTime until = QDateTime::fromString(vUntil, Qt::ISODate);
        if (until.isValid() && now > until) {
            result["valid"] = false;
            result["error"] = "Mã gói chụp đã hết hạn sử dụng";
            return result;
        }
    }

    result["valid"]           = true;
    result["code"]            = row["code"];
    result["type"]            = row["type"];
    result["value"]           = row.value("value").toInt();
    result["package_minutes"] = row.value("package_minutes").toInt();
    result["package_prints"]  = qMax(1, row.value("package_prints").toInt());
    result["package_name"]    = row.value("package_name").toString();
    result["usage_limit"]     = qMax(1, row.value("usage_limit").toInt());
    result["use_count"]       = qMax(0, row.value("use_count").toInt());
    result["employee_id"]     = row["employee_id"];
    return result;
}

bool EventManager::redeemPackageCode(const QString &code, const QString &sessionId, int paidAmount) {
    int usedBy = (m_currentEmployeeId > 0) ? m_currentEmployeeId : 0;
    const QString normalized = code.toUpper().remove(' ').remove('\t');
    if (isLocalOnlyCode(normalized))
        return redeemLocalPackageCode(normalized, sessionId, paidAmount).value("ok").toBool();
    if (m_dynamoClient) {
        QVariantMap cloud = m_dynamoClient->redeemVoucherCloud(currentHwid(), normalized,
                                                               sessionId, usedBy, paidAmount);
        if (!cloud.value("network_error").toBool()) {
            const bool ok = cloud.value("success").toBool();
            if (ok) m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
            return ok;
        }
        qWarning() << "[PackageCode] Cloud redeem lỗi mạng → fallback local:" << cloud.value("error");
    }
    return m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, paidAmount);
}

QVariantMap EventManager::redeemLocalPackageCode(const QString &code, const QString &sessionId, int paidAmount) {
    QVariantMap result;
    const QString normalized = code.toUpper().remove(' ').remove('\t');
    const QVariantMap local = validatePackageCodeLocal(normalized);
    if (!local.value("valid").toBool()) {
        result["ok"] = false;
        result["error"] = local.value("error").toString();
        return result;
    }

    const int usedBy = (m_currentEmployeeId > 0) ? m_currentEmployeeId : 0;
    const int price = paidAmount > 0 ? paidAmount : local.value("value").toInt();
    if (!m_dbManager->markVoucherUsed(normalized, sessionId, usedBy, price)) {
        result["ok"] = false;
        result["error"] = QStringLiteral("Mã gói chụp này đã được sử dụng");
        return result;
    }

    const QString useId = QUuid::createUuid().toString(QUuid::WithoutBraces);
    if (m_cloudSync) {
        QJsonObject use;
        use["use_id"] = useId;
        use["code"] = normalized;
        use["session_id"] = sessionId;
        use["used_at"] = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
        use["kind"] = "local";
        use["source"] = "local";
        use["minutes"] = local.value("package_minutes").toInt();
        use["price_vnd"] = price;
        use["package_name"] = local.value("package_name").toString();
        use["room_name"] = QStringLiteral("Local");
        m_cloudSync->enqueueCodeUse(useId, use);
    }
    if (!sessionId.isEmpty())
        setSessionCodeUse(sessionId, useId);

    result["ok"] = true;
    result["code"] = normalized;
    result["use_id"] = useId;
    result["minutes"] = local.value("package_minutes").toInt();
    result["price_vnd"] = price;
    result["kind"] = "local";
    result["source"] = "local";
    result["package_name"] = local.value("package_name").toString();
    return result;
}

QStringList EventManager::generatePackageCodes(const QString &packageName,
                                               int value,
                                               int minutes,
                                               int prints,
                                               int usageLimit,
                                               int count,
                                               const QString &validFrom,
                                               const QString &validUntil,
                                               const QString &note) {
    QStringList codes;
    if (m_currentEmployeeId == 0) {
        qWarning() << "[PackageCode] generatePackageCodes: chưa đăng nhập nhân viên";
        emit error("Vui lòng đăng nhập trước khi tạo mã");
        return codes;
    }

    const int safeValue = qMax(0, value);
    const int safeMinutes = qMax(1, minutes);
    const int safePrints = qMax(1, prints);
    const int safeUses = qMax(1, usageLimit);
    const int safeCount = qBound(1, count, 200);
    const QString normalizedValidFrom = normalizeVoucherDateTimeForCloud(validFrom);
    const QString normalizedValidUntil = normalizeVoucherDateTimeForCloud(validUntil);
    const QString safeName = packageName.trimmed().isEmpty()
        ? QStringLiteral("Gói local")
        : packageName.trimmed();

    int attempts = 0;
    while (codes.size() < safeCount && attempts < safeCount * 30) {
        ++attempts;
        const QString code = makeVoucherCode();
        if (m_dbManager->insertVoucher(code, "package_code", safeValue, m_currentEmployeeId,
                                       normalizedValidFrom, normalizedValidUntil, "",
                                       note, safeMinutes, safePrints, safeName, safeUses))
            codes << code;
    }
    qDebug() << "[PackageCode] Local-generated" << codes.size()
             << "package codes for" << safeName << "uses" << safeUses;
    return codes;
}

QVariantList EventManager::getPackageCodeList(const QString &filter) {
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getVouchers(filter, empFilter, "package_code");
}

int EventManager::getPackageCodeCount(const QString &filter) {
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getVoucherCount(filter, empFilter, "package_code");
}

QStringList EventManager::generateCashPaymentCodes(int value, int count,
                                                   const QString &validFrom,
                                                   const QString &validUntil,
                                                   const QString &shift,
                                                   const QString &note) {
    return generateCodesInternal("cash_code", value, count, validFrom, validUntil, shift, note);
}

QVariantList EventManager::getCashPaymentCodeList(const QString &filter) {
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getVouchers(filter, empFilter, "cash_code");
}

int EventManager::getCashPaymentCodeCount(const QString &filter) {
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getVoucherCount(filter, empFilter, "cash_code");
}

// ============= Revenue Tracking =============

bool EventManager::logRevenue(int eventId, const QString &eventName, const QString &sessionId,
                              int printCount, int amountRequired,
                              int cashReceived, int transferAmount, int changeAmount,
                              const QString &paymentMethod,
                              const QString &shift, const QString &source,
                              const QString &note, int voucherAmount) {
    const QString normalizedSource = source.isEmpty() ? QStringLiteral("session") : source;
    if (normalizedSource == "session" && m_sessionManager && !sessionId.isEmpty() &&
        m_sessionManager->getSessionInfo(sessionId).isEmpty()) {
        QString hwid = m_machineAuth ? m_machineAuth->hwid() : m_dbManager->getMachineHWID();
        if (!hwid.isEmpty()) m_sessionManager->ensureSession(sessionId, eventId, hwid);
    }

    RevenueRecord rec;
    rec.eventId        = eventId;
    rec.eventName      = eventName;
    rec.sessionId      = sessionId;
    rec.recordedAt     = QDateTime::currentDateTime().toString(Qt::ISODate);
    rec.printCount     = printCount;
    rec.amountRequired = amountRequired;
    rec.cashReceived   = cashReceived;
    rec.transferAmount = transferAmount;
    rec.changeAmount   = changeAmount;
    rec.paymentMethod  = paymentMethod;
    // Nhân viên ghi nhận (0 nếu chưa đăng nhập / admin chung).
    rec.employeeId     = (m_currentEmployeeId > 0) ? m_currentEmployeeId : 0;
    // Ca làm việc: dùng giá trị truyền vào, nếu rỗng thì tự suy theo giờ giao dịch.
    rec.shift          = shift.isEmpty() ? resolveShift(rec.recordedAt) : shift;
    rec.source         = normalizedSource;
    rec.note           = note;
    rec.voucherAmount  = qMax(0, voucherAmount);
    // Tiền thực nhận theo phương thức.
    if (paymentMethod == "cash")
        rec.receivedAmount = cashReceived - changeAmount;   // tiền giữ lại sau khi trả thừa
    else if (paymentMethod == "transfer")
        rec.receivedAmount = transferAmount;
    else if (paymentMethod == "voucher" || paymentMethod == "prepaid_code")
        rec.receivedAmount = amountRequired;                // mệnh giá voucher / gói trả trước
    else
        rec.receivedAmount = 0;                             // free
    if (rec.receivedAmount < 0) rec.receivedAmount = 0;

    bool ok = m_dbManager->logRevenueRecord(rec);
    if (ok && rec.source == "session" && m_sessionManager && !sessionId.isEmpty())
        m_sessionManager->markPaid(sessionId);

    // Đẩy lên API qua outbox (bền: mất mạng / chưa đăng nhập studio thì chờ gửi sau).
    // revenue_id giữ công thức cũ -> server INSERT OR IGNORE, gửi lặp không nhân bản.
    if (ok && m_cloudSync) {
        QString hwid;
        if (m_machineAuth) hwid = m_machineAuth->hwid();
        if (hwid.isEmpty()) hwid = m_dbManager->getMachineHWID();

        const QString revenueKey = QStringLiteral("%1|%2|%3|%4|%5")
            .arg(hwid).arg(eventId).arg(sessionId).arg(rec.source).arg(rec.recordedAt);
        const QString revenueId = QString::fromLatin1(
            QCryptographicHash::hash(revenueKey.toUtf8(), QCryptographicHash::Sha256).toHex());
        QJsonObject payload;
        payload["revenue_id"]      = revenueId;
        payload["session_id"]      = sessionId;
        payload["event_id"]        = eventId;
        payload["event_name"]      = eventName;
        payload["recorded_at"]     = rec.recordedAt;
        payload["amount_required"] = amountRequired;
        payload["received_amount"] = rec.receivedAmount;
        payload["cash_received"]   = cashReceived;
        payload["transfer_amount"] = transferAmount;
        payload["change_amount"]   = changeAmount;
        payload["voucher_amount"]  = rec.voucherAmount;
        payload["print_count"]     = printCount;
        payload["payment_method"]  = paymentMethod;
        payload["source"]          = rec.source;
        payload["note"]            = rec.note;
        const QString codeUseId = m_sessionCodeUse.value(sessionId);
        if (!codeUseId.isEmpty()) payload["code_use_id"] = codeUseId;
        m_cloudSync->enqueueRevenue(revenueId, payload);
    }

    return ok;
}

QVariantList EventManager::getRevenueRecords(const QString &sortBy, int employeeFilter) {
    int empFilter;
    if (isAdmin()) {
        // Admin: -2 (mặc định) → tất cả; ngược lại dùng đúng filter truyền vào
        // (-1 = tất cả, >0 = một nhân viên cụ thể).
        empFilter = (employeeFilter == -2) ? -1 : employeeFilter;
    } else {
        // Nhân viên thường: luôn ép về của mình (không cho xem người khác).
        empFilter = m_currentEmployeeId;
    }
    return m_dbManager->getRevenueRecords(sortBy, empFilter);
}

bool EventManager::clearRevenueRecords() {
    if (!isAdmin()) {
        qWarning() << "[Permission] Staff attempted to clear revenue records";
        emit error(QStringLiteral("Chỉ admin được xóa doanh thu"));
        return false;
    }
    return m_dbManager->clearRevenueRecords();
}

bool EventManager::exportRevenueToCSV(const QString &filePath) {
    return m_dbManager->exportRevenueToCSV(filePath);
}

QVariantMap EventManager::getRevenueSummary() {
    int empFilter = isAdmin() ? -1 : m_currentEmployeeId;
    return m_dbManager->getRevenueSummary(empFilter);
}

QVariantList EventManager::getCaptureAttempts(int employeeFilter) {
    int empFilter = isAdmin() ? ((employeeFilter == -2) ? -1 : employeeFilter)
                              : m_currentEmployeeId;
    return m_dbManager->getCaptureAttempts(empFilter);
}

bool EventManager::resolveCaptureAttempt(const QString &sessionId,
                                         const QString &resolutionType,
                                         int refundAmount, const QString &note) {
    if (!isAdmin()) {
        emit error(QStringLiteral("Chỉ admin được cập nhật xử lý lượt chụp"));
        return false;
    }
    const bool ok = m_dbManager->resolveCaptureAttempt(
        sessionId, resolutionType, refundAmount, note, QStringLiteral("desktop:admin"));
    if (ok) {
        syncSessionToCloud(sessionId);
        emit captureAttemptsChanged();
    }
    return ok;
}

bool EventManager::exportCaptureAttemptsToCSV(const QString &filePath, int employeeFilter) {
    const int empFilter = isAdmin() ? ((employeeFilter == -2) ? -1 : employeeFilter)
                                    : m_currentEmployeeId;
    return m_dbManager->exportCaptureAttemptsToCSV(filePath, empFilter);
}

QString EventManager::resolveShift(const QString &isoTime) {
    // Đọc danh sách ca (app_settings "voucher_shifts"): [{name,start,end}, ...]
    QString json = m_dbManager->getSetting("voucher_shifts", "");
    if (json.isEmpty()) return QString();

    QJsonParseError perr;
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8(), &perr);
    if (perr.error != QJsonParseError::NoError || !doc.isArray()) return QString();

    QDateTime dt = QDateTime::fromString(isoTime, Qt::ISODate);
    if (!dt.isValid()) dt = QDateTime::currentDateTime();
    int mins = dt.time().hour() * 60 + dt.time().minute();   // phút trong ngày 0..1439

    auto toMins = [](const QString &hhmm) -> int {
        QStringList p = hhmm.split(':');
        if (p.size() != 2) return -1;
        return p[0].toInt() * 60 + p[1].toInt();
    };

    const QJsonArray arr = doc.array();
    for (const QJsonValue &v : arr) {
        QJsonObject o = v.toObject();
        int s = toMins(o.value("start").toString());
        int e = toMins(o.value("end").toString());
        if (s < 0 || e < 0) continue;
        bool inShift;
        if (s == e) {
            // 00:00–00:00 (chưa đặt giờ) → coi như cả ngày
            inShift = true;
        } else if (s < e) {
            inShift = (mins >= s && mins < e);
        } else {
            // Ca qua đêm (vd 22:00–06:00)
            inShift = (mins >= s || mins < e);
        }
        if (inShift) return o.value("name").toString();
    }
    return QString();
}

QVariantMap EventManager::createPayosPayment(int amount, const QString &description,
                                             const QString &returnUrl,
                                             const QString &cancelUrl) {
    QVariantMap result;
    result["ok"] = false;

    const QString clientId = getAppSetting(QStringLiteral("payment_payos_client_id")).trimmed();
    const QString apiKey = getAppSetting(QStringLiteral("payment_payos_api_key")).trimmed();
    const QString checksumKey = getAppSetting(QStringLiteral("payment_payos_checksum_key")).trimmed();
    const QString ret = returnUrl.trimmed().isEmpty()
                            ? QStringLiteral("https://payos.vn")
                            : returnUrl.trimmed();
    const QString cancel = cancelUrl.trimmed().isEmpty()
                               ? QStringLiteral("https://payos.vn")
                               : cancelUrl.trimmed();
    const QString desc = description.trimmed();

    if (amount <= 0 || clientId.isEmpty() || apiKey.isEmpty() || checksumKey.isEmpty() ||
        ret.isEmpty() || cancel.isEmpty() || desc.isEmpty()) {
        result["error"] = QStringLiteral("Thiếu cấu hình payOS hoặc số tiền không hợp lệ");
        return result;
    }

    const qint64 orderCode = QDateTime::currentMSecsSinceEpoch() % 1000000000000LL;
    const QString signatureData =
        QStringLiteral("amount=%1&cancelUrl=%2&description=%3&orderCode=%4&returnUrl=%5")
            .arg(amount)
            .arg(cancel, desc)
            .arg(orderCode)
            .arg(ret);
    const QString signature = QString::fromLatin1(
        QMessageAuthenticationCode::hash(signatureData.toUtf8(),
                                         checksumKey.toUtf8(),
                                         QCryptographicHash::Sha256).toHex());

    QJsonObject body;
    body["orderCode"] = orderCode;
    body["amount"] = amount;
    body["description"] = desc;
    body["returnUrl"] = ret;
    body["cancelUrl"] = cancel;
    body["signature"] = signature;

    QNetworkAccessManager manager;
    QNetworkRequest request(QUrl(QStringLiteral("https://api-merchant.payos.vn/v2/payment-requests")));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setRawHeader("x-client-id", clientId.toUtf8());
    request.setRawHeader("x-api-key", apiKey.toUtf8());
    request.setTransferTimeout(15000);

    QNetworkReply *reply = manager.post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    guard.start(16000);
    loop.exec();

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray raw = reply->readAll();
    const bool networkOk = reply->error() == QNetworkReply::NoError;
    reply->deleteLater();

    result["httpStatus"] = status;
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &parseError);
    if (!networkOk || parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        result["error"] = QStringLiteral("Không thể tạo link thanh toán payOS");
        result["raw"] = QString::fromUtf8(raw.left(500));
        return result;
    }

    const QJsonObject obj = doc.object();
    const QJsonObject data = obj.value(QStringLiteral("data")).toObject();
    result["code"] = obj.value(QStringLiteral("code")).toString();
    result["desc"] = obj.value(QStringLiteral("desc")).toString();
    result["orderCode"] = QString::number(orderCode);
    result["paymentLinkId"] = data.value(QStringLiteral("paymentLinkId")).toString();
    result["checkoutUrl"] = data.value(QStringLiteral("checkoutUrl")).toString();
    result["qrCode"] = data.value(QStringLiteral("qrCode")).toString();
    result["status"] = data.value(QStringLiteral("status")).toString();
    result["ok"] = status >= 200 && status < 300 &&
                   obj.value(QStringLiteral("code")).toString() == QStringLiteral("00") &&
                   !result.value("qrCode").toString().isEmpty();
    if (!result.value("ok").toBool() && result.value("desc").toString().isEmpty())
        result["error"] = QStringLiteral("payOS từ chối tạo link thanh toán");
    return result;
}

QVariantMap EventManager::getPayosPaymentStatus(const QString &id) {
    QVariantMap result;
    result["ok"] = false;
    const QString clientId = getAppSetting(QStringLiteral("payment_payos_client_id")).trimmed();
    const QString apiKey = getAppSetting(QStringLiteral("payment_payos_api_key")).trimmed();
    const QString cleanId = id.trimmed();
    if (clientId.isEmpty() || apiKey.isEmpty() || cleanId.isEmpty()) {
        result["error"] = QStringLiteral("Thiếu cấu hình payOS hoặc mã thanh toán");
        return result;
    }

    QNetworkAccessManager manager;
    QNetworkRequest request(QUrl(QStringLiteral("https://api-merchant.payos.vn/v2/payment-requests/%1")
                                     .arg(QString::fromUtf8(QUrl::toPercentEncoding(cleanId)))));
    request.setRawHeader("x-client-id", clientId.toUtf8());
    request.setRawHeader("x-api-key", apiKey.toUtf8());
    request.setTransferTimeout(12000);

    QNetworkReply *reply = manager.get(request);
    QEventLoop loop;
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, reply, &QNetworkReply::abort);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    guard.start(13000);
    loop.exec();

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray raw = reply->readAll();
    const bool networkOk = reply->error() == QNetworkReply::NoError;
    reply->deleteLater();

    result["httpStatus"] = status;
    QJsonParseError parseError;
    const QJsonDocument doc = QJsonDocument::fromJson(raw, &parseError);
    if (!networkOk || parseError.error != QJsonParseError::NoError || !doc.isObject()) {
        result["error"] = QStringLiteral("Không thể kiểm tra trạng thái payOS");
        result["raw"] = QString::fromUtf8(raw.left(500));
        return result;
    }

    const QJsonObject obj = doc.object();
    const QJsonObject data = obj.value(QStringLiteral("data")).toObject();
    result["code"] = obj.value(QStringLiteral("code")).toString();
    result["desc"] = obj.value(QStringLiteral("desc")).toString();
    result["status"] = data.value(QStringLiteral("status")).toString();
    result["amount"] = data.value(QStringLiteral("amount")).toInt();
    result["amountPaid"] = data.value(QStringLiteral("amountPaid")).toInt();
    result["amountRemaining"] = data.value(QStringLiteral("amountRemaining")).toInt();
    result["ok"] = status >= 200 && status < 300 &&
                   obj.value(QStringLiteral("code")).toString() == QStringLiteral("00");
    return result;
}

