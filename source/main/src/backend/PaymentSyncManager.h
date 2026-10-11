#ifndef PAYMENTSYNCMANAGER_H
#define PAYMENTSYNCMANAGER_H

#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QQueue>
#include <QSet>
#include <QTimer>

class ConfigManager;
class EventManager;
class MachineAuthenticator;

class PaymentSyncManager : public QObject {
    Q_OBJECT

public:
    explicit PaymentSyncManager(ConfigManager *config, QObject *parent = nullptr);

    void setEventManager(EventManager *eventManager);
    void setMachineAuthenticator(MachineAuthenticator *machineAuth);
    void start(int intervalMs = 30000);

private:
    void poll();
    void processNext();
    void patchJob(const QString &jobId, const QString &status, const QString &error = QString());
    QNetworkRequest request(const QString &path) const;
    QString currentHwid() const;
    int eventIdForKey(const QString &eventKey) const;
    bool applyJob(const QJsonObject &job, QString *error);
    bool isAllowedSetting(const QString &key) const;
    bool validatePrintOptionsJson(const QString &value) const;

    ConfigManager *m_config = nullptr;
    EventManager *m_eventManager = nullptr;
    MachineAuthenticator *m_machineAuth = nullptr;
    QNetworkAccessManager m_net;
    QTimer m_timer;
    QQueue<QJsonObject> m_jobs;
    bool m_polling = false;
    bool m_busy = false;
    QSet<QString> m_allowedKeys;
};

#endif // PAYMENTSYNCMANAGER_H
