#include "SessionManager.h"
#include "DatabaseManager.h"
#include <QDebug>
#include <QDateTime>
#include <QRandomGenerator>

SessionManager::SessionManager(DatabaseManager *db, QObject *parent)
    : QObject(parent)
    , m_db(db)
{
    const int recovered = m_db ? m_db->recoverInterruptedSessions() : 0;
    if (recovered > 0) qWarning() << "Recovered" << recovered << "interrupted capture sessions";
}

bool SessionManager::ensureSession(const QString &sessionId, int eventId, const QString &hwid) {
    if (!m_db || sessionId.isEmpty() || eventId <= 0 || hwid.isEmpty()) return false;
    if (!m_db->getSessionInfo(sessionId).isEmpty()) return true;
    const bool ok = m_db->createSession(sessionId, eventId, hwid);
    if (ok) emit sessionStateChanged(sessionId);
    return ok;
}

SessionManager::~SessionManager() {
}

QString SessionManager::generateSessionId() {
    // Format: session_YYYYMMDD_HHmmss_XXXX
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss");
    QString random = QString::number(QRandomGenerator::global()->generate() % 0x10000, 16).toUpper();
    random = random.rightJustified(4, '0');
    return QString("session_%1_%2").arg(timestamp, random);
}

QString SessionManager::createSession(int eventId, const QString &hwid) {
    if (!m_db) {
        qCritical() << "DatabaseManager not initialized";
        return "";
    }

    if (hwid.isEmpty()) {
        qCritical() << "HWID cannot be empty";
        return "";
    }

    // Generate unique session ID
    QString sessionId = generateSessionId();

    // Create session in database
    if (!m_db->createSession(sessionId, eventId, hwid)) {
        qCritical() << "Failed to create session in database";
        return "";
    }

    qDebug() << "Session created:" << sessionId << "for event:" << eventId;
    return sessionId;
}

void SessionManager::endSession(const QString &sessionId) {
    if (!m_db) {
        qCritical() << "DatabaseManager not initialized";
        return;
    }

    if (sessionId.isEmpty()) {
        qCritical() << "Session ID cannot be empty";
        return;
    }

    if (m_db->endSession(sessionId)) {
        qDebug() << "Session ended:" << sessionId;
        emit sessionStateChanged(sessionId);
    } else {
        qCritical() << "Failed to end session:" << sessionId;
    }
}

bool SessionManager::markPaid(const QString &sessionId) {
    const bool ok = m_db && m_db->markSessionPaid(sessionId);
    if (ok) emit sessionStateChanged(sessionId);
    return ok;
}

bool SessionManager::beginCapture(const QString &sessionId, int expectedPhotos) {
    const bool ok = m_db && m_db->updateSessionState(sessionId, "CAPTURING", expectedPhotos, 0);
    if (ok) emit sessionStateChanged(sessionId);
    return ok;
}

bool SessionManager::updateCaptureProgress(const QString &sessionId, int capturedPhotos) {
    const bool ok = m_db && m_db->updateSessionState(sessionId, "CAPTURING", -1, capturedPhotos);
    if (ok) emit sessionStateChanged(sessionId);
    return ok;
}

bool SessionManager::retryCapture(const QString &sessionId) {
    const QVariantMap info = getSessionInfo(sessionId);
    return beginCapture(sessionId, info.value("expected_photos").toInt());
}

bool SessionManager::failCapture(const QString &sessionId, const QString &code,
                                 const QString &message, int capturedPhotos) {
    const bool ok = m_db && m_db->updateSessionState(sessionId, "CAMERA_ERROR", -1,
                                                     capturedPhotos, code, message);
    if (ok) emit sessionStateChanged(sessionId);
    return ok;
}

bool SessionManager::cancelCapture(const QString &sessionId, const QString &reason) {
    const bool ok = m_db && m_db->updateSessionState(sessionId, "CANCELLED", -1, -1,
                                                     "USER_CANCELLED", reason);
    if (ok) emit sessionStateChanged(sessionId);
    return ok;
}

void SessionManager::addPhotoToSession(const QString &sessionId, const QString &filePath) {
    if (!m_db) {
        qCritical() << "DatabaseManager not initialized";
        return;
    }

    if (sessionId.isEmpty() || filePath.isEmpty()) {
        qCritical() << "Session ID and file path cannot be empty";
        return;
    }

    // This would typically be called after the photo is inserted into the database
    // with its photo ID. The EventManager handles this integration.
    qDebug() << "Photo added to session:" << sessionId << "-" << filePath;
}

QStringList SessionManager::getSessionPhotos(const QString &sessionId) {
    QStringList photos;

    if (!m_db) {
        qCritical() << "DatabaseManager not initialized";
        return photos;
    }

    if (sessionId.isEmpty()) {
        qCritical() << "Session ID cannot be empty";
        return photos;
    }

    // Trả đường dẫn tuyệt đối các ảnh GỐC của session (cũ → mới).
    return m_db->getSessionOriginalPhotos(sessionId);
}

QVariantList SessionManager::getRecentSessions(int eventId, int limit) {
    if (!m_db) {
        qCritical() << "DatabaseManager not initialized";
        return QVariantList();
    }
    return m_db->getRecentSessions(eventId, limit);
}

QVariantMap SessionManager::getSessionInfo(const QString &sessionId) {
    if (!m_db) {
        qCritical() << "DatabaseManager not initialized";
        return QVariantMap();
    }

    if (sessionId.isEmpty()) {
        qCritical() << "Session ID cannot be empty";
        return QVariantMap();
    }

    return m_db->getSessionInfo(sessionId);
}
