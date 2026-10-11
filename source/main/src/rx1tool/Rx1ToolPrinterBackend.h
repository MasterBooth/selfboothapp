#ifndef RX1TOOLPRINTERBACKEND_H
#define RX1TOOLPRINTERBACKEND_H

#include <QObject>
#include <QStringList>
#include <QLibrary>

#ifdef Q_OS_WIN
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winspool.h>
#endif

class Rx1ToolPrinterBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList printers READ printers NOTIFY printersChanged)
    Q_PROPERTY(QString selectedPrinter READ selectedPrinter WRITE setSelectedPrinter NOTIFY selectedPrinterChanged)
    Q_PROPERTY(QString sdkStatus READ sdkStatus NOTIFY sdkStatusChanged)
    Q_PROPERTY(QString sdkPort READ sdkPort NOTIFY sdkPortChanged)
    Q_PROPERTY(QString logText READ logText NOTIFY logTextChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(bool sdkLoaded READ sdkLoaded NOTIFY sdkLoadedChanged)

public:
    explicit Rx1ToolPrinterBackend(QObject *parent = nullptr);
    ~Rx1ToolPrinterBackend() override;

    QStringList printers() const { return m_printers; }
    QString selectedPrinter() const { return m_selectedPrinter; }
    QString sdkStatus() const { return m_sdkStatus; }
    QString sdkPort() const { return m_sdkPort; }
    QString logText() const { return m_logText; }
    bool busy() const { return m_busy; }
    bool sdkLoaded() const { return m_sdkLoaded; }

    void setSelectedPrinter(const QString &printer);

    Q_INVOKABLE void scanPrinters();
    Q_INVOKABLE void scanSdkPorts();
    Q_INVOKABLE void printImage(const QString &imagePath,
                                const QString &printerName,
                                const QString &paperSize,
                                bool cutMode,
                                int copies,
                                int dpi,
                                int orientationMode);
    Q_INVOKABLE QString normalizeLocalPath(const QString &path) const;

signals:
    void printersChanged();
    void selectedPrinterChanged();
    void sdkStatusChanged();
    void sdkPortChanged();
    void logTextChanged();
    void busyChanged();
    void sdkLoadedChanged();
    void printFinished(bool success, const QString &message);

private:
    void loadSdk();
    void appendLog(const QString &line);
    void setBusy(bool busy);
    void setSdkStatus(const QString &status);
    void setSdkPort(const QString &port);
    QString decodeStatus(long status) const;
    QStringList enumerateDnpPrinters() const;
    bool isSupportedDnpPrinter(const QString &name) const;

#ifdef Q_OS_WIN
    struct DnpPaper {
        QString name;
        short number = 0;
    };

    QString printerPortName(const QString &printerName) const;
    QVector<DnpPaper> enumeratePapers(const QString &printerName) const;
    bool isCut4x6PaperName(const QString &name) const;
    bool isSixByEightPaperName(const QString &name) const;
    bool findExDevTop(void *devmodePtr, int devmodeSize, int &exDevTop) const;
    bool writeDevmodePrivateInt(void *devmodePtr, int devmodeSize, int fieldOffset, int value, const char *fieldName);
    bool modifyDevmodeCut(void *devmodePtr, int devmodeSize, bool enableCut);
    bool modifyDevmodeBorder(void *devmodePtr, int devmodeSize, bool borderOn);
    bool modifyDevmodeOrientation(void *devmodePtr, bool landscape);
    bool printImageWinApi(const QString &imagePath,
                          const QString &printerName,
                          const QString &paperSize,
                          bool cutMode,
                          int copies,
                          int dpi,
                          int orientationMode,
                          QString &message);
#endif

    typedef long (APIENTRY *PortInitializeFunc)(wchar_t *);
    typedef long (APIENTRY *GetStatusFunc)(long);
    typedef long (APIENTRY *GetMediaFunc)(long, char *);
    typedef long (APIENTRY *GetMediaCounterFunc)(long);
    typedef long (APIENTRY *GetFirmwVersionFunc)(long, char *);
    typedef long (APIENTRY *GetSerialNoFunc)(long, char *);
    typedef long (APIENTRY *GetPrinterPortNumFunc)(char *, int);

    QLibrary m_sdkLib;
    PortInitializeFunc m_portInitialize = nullptr;
    GetStatusFunc m_getStatus = nullptr;
    GetMediaFunc m_getMedia = nullptr;
    GetMediaCounterFunc m_getMediaCounter = nullptr;
    GetFirmwVersionFunc m_getFirmwVersion = nullptr;
    GetSerialNoFunc m_getSerialNo = nullptr;
    GetPrinterPortNumFunc m_getPrinterPortNum = nullptr;

    QStringList m_printers;
    QString m_selectedPrinter;
    QString m_sdkStatus = QStringLiteral("SDK not scanned");
    QString m_sdkPort;
    QString m_logText;
    bool m_busy = false;
    bool m_sdkLoaded = false;
    bool m_directDllMode = false;
    long m_portNum = -1;
};

#endif
