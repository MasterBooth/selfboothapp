#ifndef SESSIONMANAGER_H
#define SESSIONMANAGER_H

#include <QString>
#include <QObject>
#include <QStringList>
#include <QVariantMap>
#include <QVariantList>

class DatabaseManager;

/**
 * @class SessionManager
 * @brief Manages photo capture sessions
 *
 * Creates and tracks photo sessions for each event
 * Session ID format: session_YYYYMMDD_HHmmss_XXXX
 */
class SessionManager : public QObject {
    Q_OBJECT

public:
    explicit SessionManager(DatabaseManager *db, QObject *parent = nullptr);
    ~SessionManager();

    Q_INVOKABLE QString createSession(int eventId, const QString &hwid);
    Q_INVOKABLE bool ensureSession(const QString &sessionId, int eventId, const QString &hwid);
    Q_INVOKABLE void endSession(const QString &sessionId);
    Q_INVOKABLE bool markPaid(const QString &sessionId);
    Q_INVOKABLE bool beginCapture(const QString &sessionId, int expectedPhotos);
    Q_INVOKABLE bool updateCaptureProgress(const QString &sessionId, int capturedPhotos);
    Q_INVOKABLE bool retryCapture(const QString &sessionId);
    Q_INVOKABLE bool failCapture(const QString &sessionId, const QString &code,
                                 const QString &message, int capturedPhotos = -1);
    Q_INVOKABLE bool cancelCapture(const QString &sessionId, const QString &reason = QString());
    Q_INVOKABLE void addPhotoToSession(const QString &sessionId, const QString &filePath);
    Q_INVOKABLE QStringList getSessionPhotos(const QString &sessionId);
    Q_INVOKABLE QVariantMap getSessionInfo(const QString &sessionId);
    // Danh sách session gần nhất của event (mới → cũ) cho quầy thu ngân lấy ảnh gốc.
    Q_INVOKABLE QVariantList getRecentSessions(int eventId, int limit = 50);

signals:
    void sessionStateChanged(const QString &sessionId);

private:
    DatabaseManager *m_db;

    QString generateSessionId();
};

#endif // SESSIONMANAGER_H
