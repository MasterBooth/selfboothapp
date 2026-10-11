#ifndef PRINTJOBCLIENT_H
#define PRINTJOBCLIENT_H

#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QNetworkAccessManager>
#include <QSqlDatabase>

class ConfigManager;
class QNetworkReply;

class PrintJobClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QVariantList jobs READ jobs NOTIFY jobsChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusTextChanged)
    Q_PROPERTY(QString activeJobId READ activeJobId NOTIFY activeJobChanged)
    Q_PROPERTY(QString activeLocalPath READ activeLocalPath NOTIFY activeJobChanged)

public:
    explicit PrintJobClient(ConfigManager *config, QObject *parent = nullptr);
    ~PrintJobClient();

    QVariantList jobs() const { return m_jobs; }
    QVariantList history() const { return m_history; }
    bool busy() const { return m_busy; }
    QString statusText() const { return m_statusText; }
    QString activeJobId() const { return m_activeJobId; }
    QString activeLocalPath() const { return m_activeLocalPath; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void refresh();
    Q_INVOKABLE void refreshHistory();
    Q_INVOKABLE void claimAndDownload(const QString &jobId);
    Q_INVOKABLE void reprintAndDownload(const QString &jobId,
                                        int copies,
                                        const QString &orientation,
                                        const QString &printerName);
    Q_INVOKABLE void finishActivePrint(bool success,
                                       const QString &message,
                                       const QString &printerName,
                                       int copies,
                                       const QString &orientation);
    Q_INVOKABLE QString localPathForJob(const QString &jobId) const;

signals:
    void jobsChanged();
    void historyChanged();
    void busyChanged();
    void statusTextChanged();
    void activeJobChanged();
    void jobReadyToPrint(QString localPath, int copies, QString orientation);
    void jobFailed(QString message);

private:
    QNetworkRequest request(const QString &path) const;
    void setBusy(bool busy);
    void setStatusText(const QString &text);
    void applyJobs(const QJsonArray &items);
    void applyHistory(const QJsonArray &items);
    void patchJob(const QString &jobId, const QJsonObject &body);
    void downloadActiveJob(const QVariantMap &job);
    void initStore();
    void upsertCachedJob(const QVariantMap &job, const QString &localPath = QString());
    void loadCachedHistory();
    QVariantMap jobById(const QString &jobId) const;
    QString cachePathForJob(const QString &jobId, const QString &fileName) const;

    ConfigManager *m_config = nullptr;
    QNetworkAccessManager m_net;
    QTimer m_pollTimer;
    QVariantList m_jobs;
    QVariantList m_history;
    bool m_busy = false;
    QString m_statusText;
    QString m_activeJobId;
    QString m_activeLocalPath;
    QSqlDatabase m_store;
};

#endif
