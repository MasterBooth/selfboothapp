#ifndef FILTERSYNCMANAGER_H
#define FILTERSYNCMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QQueue>
#include <QTimer>
#include <functional>

class ConfigManager;
class FilterManager;
class MachineAuthenticator;

class FilterSyncManager : public QObject {
    Q_OBJECT

public:
    explicit FilterSyncManager(ConfigManager *config, QObject *parent = nullptr);

    void setFilterManager(FilterManager *filterManager);
    void setMachineAuthenticator(MachineAuthenticator *machineAuth);
    void start(int intervalMs = 30000);

private:
    void poll();
    void processNext();
    void patchJob(const QString &jobId, const QString &status, const QString &error = QString());
    QNetworkRequest request(const QString &path) const;
    void downloadToFile(const QString &url, const QString &destPath, std::function<void(bool, QString)> done);
    QString currentHwid() const;
    QString jobDir(const QString &jobId) const;
    static QString fileNameFromKey(const QString &key, const QString &fallback);
    void finishJob(const QString &jobId, bool ok, const QString &error = QString());

    ConfigManager *m_config = nullptr;
    FilterManager *m_filterManager = nullptr;
    MachineAuthenticator *m_machineAuth = nullptr;
    QNetworkAccessManager m_net;
    QTimer m_timer;
    QQueue<QJsonObject> m_jobs;
    bool m_polling = false;
    bool m_busy = false;
};

#endif // FILTERSYNCMANAGER_H
