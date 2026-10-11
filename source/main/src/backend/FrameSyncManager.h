#ifndef FRAMESYNCMANAGER_H
#define FRAMESYNCMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QQueue>
#include <QTimer>
#include <functional>

class ConfigManager;
class EventManager;
class MachineAuthenticator;
class QNetworkReply;

class FrameSyncManager : public QObject {
    Q_OBJECT

public:
    explicit FrameSyncManager(ConfigManager *config, QObject *parent = nullptr);

    void setEventManager(EventManager *eventManager);
    void setMachineAuthenticator(MachineAuthenticator *machineAuth);
    void start(int intervalMs = 30000);

private:
    void poll();
    void processNext();
    void patchJob(const QString &jobId, const QString &status, const QString &error = QString());
    QNetworkRequest request(const QString &path) const;
    void downloadToFile(const QString &url, const QString &destPath, std::function<void(bool, QString)> done);
    QString currentHwid() const;
    int eventIdForJob(const QJsonObject &job);
    QString jobDir(const QString &jobId) const;
    static QString fileNameFromKey(const QString &key, const QString &fallback);

    ConfigManager *m_config = nullptr;
    EventManager *m_eventManager = nullptr;
    MachineAuthenticator *m_machineAuth = nullptr;
    QNetworkAccessManager m_net;
    QTimer m_timer;
    QQueue<QJsonObject> m_jobs;
    bool m_polling = false;
    bool m_busy = false;
    QString m_activeJobId;
};

#endif // FRAMESYNCMANAGER_H
