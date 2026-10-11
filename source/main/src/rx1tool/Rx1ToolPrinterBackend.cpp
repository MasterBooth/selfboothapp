#include "Rx1ToolPrinterBackend.h"
#include "../backend/DNPStatusCodes.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QMetaObject>
#include <QMutex>
#include <QPainter>
#include <QThread>
#include <QTransform>
#include <QUrl>
#include <QtConcurrent/QtConcurrent>

#ifdef Q_OS_WIN
#define EX_DEV_SIGN 0x4D534654
#define ExBorder 3
#define ExCut2inch 30
#define DM_BORDER_OFF 0
#define DM_BORDER_ON 1
#define DM_CUT2INCH_OFF 0
#define DM_CUT2INCH_ON 1
#endif

Rx1ToolPrinterBackend::Rx1ToolPrinterBackend(QObject *parent)
    : QObject(parent)
{
    loadSdk();
    appendLog(QStringLiteral("RX1 Print Tool ready."));
}

Rx1ToolPrinterBackend::~Rx1ToolPrinterBackend()
{
    if (m_sdkLib.isLoaded())
        m_sdkLib.unload();
}

void Rx1ToolPrinterBackend::loadSdk()
{
    const QString directDllDir = QCoreApplication::applicationDirPath() + QStringLiteral("/dnp");
    const QStringList paths = {
        QCoreApplication::applicationDirPath() + QStringLiteral("/CyStat64.dll"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/cspstat64.dll"),
        directDllDir + QStringLiteral("/cspstat64.dll"),
        QDir::current().absoluteFilePath(QStringLiteral("CyStat64.dll")),
        QDir::current().absoluteFilePath(QStringLiteral("cspstat64.dll")),
        QDir::current().absoluteFilePath(QStringLiteral("dnp/cspstat64.dll")),
        QStringLiteral("Status API/Dll/Win64/CyStat64"),
        QStringLiteral("Status API/Dll/Win64/CyStat64.dll"),
        QStringLiteral("Status API/Window SDK/DirectDLL v0.7.1.2_D_foreign/DirectDLL v0.7.1.2_D_foreign/Dll/64bit/cspstat64.dll"),
        QStringLiteral("CyStat64"),
        QStringLiteral("CyStat64.dll"),
        QStringLiteral("cspstat64"),
        QStringLiteral("cspstat64.dll"),
        QCoreApplication::applicationDirPath() + QStringLiteral("/CyStat64")
    };

    QStringList loadErrors;
    for (const QString &path : paths) {
        m_sdkLib.setFileName(path);
        if (m_sdkLib.load()) {
            appendLog(QStringLiteral("Loaded CyStat64 from: %1").arg(path));
            break;
        }
        loadErrors << QStringLiteral("%1 -> %2").arg(path, m_sdkLib.errorString());
    }

    if (!m_sdkLib.isLoaded()) {
        appendLog(QStringLiteral("DNP status DLL could not be loaded. Printing can still use Windows driver."));
        appendLog(loadErrors.join(QStringLiteral("\n")));
        setSdkStatus(QStringLiteral("SDK DLL missing"));
        return;
    }

    m_portInitialize = reinterpret_cast<PortInitializeFunc>(m_sdkLib.resolve("PortInitialize"));
    if (!m_portInitialize)
        m_portInitialize = reinterpret_cast<PortInitializeFunc>(m_sdkLib.resolve("CvInitialize"));
    m_getStatus = reinterpret_cast<GetStatusFunc>(m_sdkLib.resolve("GetStatus"));
    if (!m_getStatus)
        m_getStatus = reinterpret_cast<GetStatusFunc>(m_sdkLib.resolve("CvGetStatus"));
    m_getMedia = reinterpret_cast<GetMediaFunc>(m_sdkLib.resolve("GetMedia"));
    if (!m_getMedia)
        m_getMedia = reinterpret_cast<GetMediaFunc>(m_sdkLib.resolve("CvGetMedia"));
    m_getMediaCounter = reinterpret_cast<GetMediaCounterFunc>(m_sdkLib.resolve("GetMediaCounter"));
    if (!m_getMediaCounter)
        m_getMediaCounter = reinterpret_cast<GetMediaCounterFunc>(m_sdkLib.resolve("CvGetMediaCounter"));
    m_getFirmwVersion = reinterpret_cast<GetFirmwVersionFunc>(m_sdkLib.resolve("GetFirmwVersion"));
    if (!m_getFirmwVersion)
        m_getFirmwVersion = reinterpret_cast<GetFirmwVersionFunc>(m_sdkLib.resolve("CvGetVersion"));
    m_getSerialNo = reinterpret_cast<GetSerialNoFunc>(m_sdkLib.resolve("GetSerialNo"));
    if (!m_getSerialNo)
        m_getSerialNo = reinterpret_cast<GetSerialNoFunc>(m_sdkLib.resolve("CvGetSerialNo"));
    m_getPrinterPortNum = reinterpret_cast<GetPrinterPortNumFunc>(m_sdkLib.resolve("GetPrinterPortNum"));

    m_directDllMode = (!m_portInitialize && m_getPrinterPortNum && m_getStatus);
    m_sdkLoaded = ((m_portInitialize || m_getPrinterPortNum) && m_getStatus);
    emit sdkLoadedChanged();
    if (m_sdkLoaded) {
        setSdkStatus(m_directDllMode
                         ? QStringLiteral("DirectDLL loaded")
                         : QStringLiteral("CyStat SDK loaded"));
        appendLog(m_directDllMode
                      ? QStringLiteral("Using DirectDLL mode: GetPrinterPortNum + GetStatus.")
                      : QStringLiteral("Using CyStat mode: PortInitialize + GetStatus."));
    } else {
        setSdkStatus(QStringLiteral("SDK functions missing"));
        appendLog(QStringLiteral("Missing required functions. PortInitialize=%1, GetPrinterPortNum=%2, GetStatus=%3")
                      .arg(m_portInitialize != nullptr)
                      .arg(m_getPrinterPortNum != nullptr)
                      .arg(m_getStatus != nullptr));
    }
}

void Rx1ToolPrinterBackend::appendLog(const QString &line)
{
    const QString stamped = QStringLiteral("[%1] %2")
        .arg(QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss")), line);
    m_logText = m_logText.isEmpty() ? stamped : (m_logText + QLatin1Char('\n') + stamped);
    emit logTextChanged();
}

void Rx1ToolPrinterBackend::setBusy(bool busy)
{
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void Rx1ToolPrinterBackend::setSdkStatus(const QString &status)
{
    if (m_sdkStatus == status)
        return;
    m_sdkStatus = status;
    emit sdkStatusChanged();
}

void Rx1ToolPrinterBackend::setSdkPort(const QString &port)
{
    if (m_sdkPort == port)
        return;
    m_sdkPort = port;
    emit sdkPortChanged();
}

void Rx1ToolPrinterBackend::setSelectedPrinter(const QString &printer)
{
    if (m_selectedPrinter == printer)
        return;
    m_selectedPrinter = printer;
    emit selectedPrinterChanged();
}

QString Rx1ToolPrinterBackend::normalizeLocalPath(const QString &path) const
{
    QString local = QUrl(path).toLocalFile();
    return local.isEmpty() ? path : local;
}

bool Rx1ToolPrinterBackend::isSupportedDnpPrinter(const QString &name) const
{
    const QString n = name.trimmed();
    return n.contains(QStringLiteral("RX1"), Qt::CaseInsensitive)
        || n.contains(QStringLiteral("DS-RX1"), Qt::CaseInsensitive)
        || n.contains(QStringLiteral("DS620"), Qt::CaseInsensitive)
        || n.contains(QStringLiteral("DS-620"), Qt::CaseInsensitive);
}

QString Rx1ToolPrinterBackend::decodeStatus(long status) const
{
    if (status == STATUS_ERROR)
        return QStringLiteral("ERROR");
    if (status == STATUS_USUALLY_IDLE)
        return QStringLiteral("Idle");
    if (status == STATUS_USUALLY_PRINTING)
        return QStringLiteral("Printing");
    if (status == STATUS_USUALLY_STANDSTILL)
        return QStringLiteral("Standstill");
    if (status == STATUS_USUALLY_PAPER_END)
        return QStringLiteral("Paper End");
    if (status == STATUS_USUALLY_RIBBON_END)
        return QStringLiteral("Ribbon End");
    if (status == STATUS_USUALLY_COOLING)
        return QStringLiteral("Head Cooling");
    if (status == STATUS_USUALLY_MOTCOOLING)
        return QStringLiteral("Motor Cooling");
    if (status == STATUS_SETTING_COVER_OPEN)
        return QStringLiteral("Cover Open");
    if (status == STATUS_SETTING_PAPER_JAM)
        return QStringLiteral("Paper Jam");
    if (status == STATUS_SETTING_RIBBON_ERR)
        return QStringLiteral("Ribbon Error");
    if (status == STATUS_SETTING_PAPER_ERR)
        return QStringLiteral("Paper Error");
    if (status == STATUS_SETTING_DATA_ERR)
        return QStringLiteral("Data Error");
    if (status == STATUS_SETTING_SCRAPBOX_ERR)
        return QStringLiteral("Scrap Box Error");
    if (status == STATUS_HARDWARE_ERR04)
        return QStringLiteral("Cutter Error");
    if (status & GROUP_HARDWARE)
        return QStringLiteral("Hardware Error 0x%1").arg(QString::number(status, 16).toUpper());
    if (status & GROUP_SYSTEM)
        return QStringLiteral("System Error");
    return QStringLiteral("Unknown 0x%1").arg(QString::number(status, 16).toUpper());
}

QStringList Rx1ToolPrinterBackend::enumerateDnpPrinters() const
{
    QStringList result;
    QStringList fallbackPrinters;
#ifdef Q_OS_WIN
    DWORD size = 0;
    DWORD count = 0;
    EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2, nullptr, 0, &size, &count);
    if (size == 0)
        return result;

    QByteArray buffer(static_cast<int>(size), 0);
    if (!EnumPrintersW(PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS, nullptr, 2,
                       reinterpret_cast<LPBYTE>(buffer.data()), size, &size, &count)) {
        return result;
    }

    auto *info = reinterpret_cast<PRINTER_INFO_2W *>(buffer.data());
    for (DWORD i = 0; i < count; ++i) {
        QString name = info[i].pPrinterName ? QString::fromWCharArray(info[i].pPrinterName) : QString();
        if (name.isEmpty())
            continue;
        if (!fallbackPrinters.contains(name))
            fallbackPrinters.append(name);
        if (isSupportedDnpPrinter(name) && !result.contains(name))
            result.append(name);
    }
#endif
    return result.isEmpty() ? fallbackPrinters : result;
}

void Rx1ToolPrinterBackend::scanPrinters()
{
    setBusy(true);
    QtConcurrent::run([this]() {
        const QStringList found = enumerateDnpPrinters();
        QMetaObject::invokeMethod(this, [this, found]() {
            m_printers = found;
            emit printersChanged();
            if (!found.isEmpty() && (m_selectedPrinter.isEmpty() || !found.contains(m_selectedPrinter)))
                setSelectedPrinter(found.first());
            appendLog(found.isEmpty()
                          ? QStringLiteral("No printer drivers found.")
                          : QStringLiteral("Found printers: %1").arg(found.join(QStringLiteral(", "))));
            setBusy(false);
        }, Qt::QueuedConnection);
    });
}

void Rx1ToolPrinterBackend::scanSdkPorts()
{
    if (!m_sdkLoaded) {
        appendLog(QStringLiteral("Cannot scan SDK ports: CyStat64 is not loaded."));
        return;
    }

    setBusy(true);
    setSdkStatus(QStringLiteral("Scanning USB001-USB009..."));
    QtConcurrent::run([this]() {
        if (m_directDllMode) {
            QByteArray portArray(256, 0);
            const long count = m_getPrinterPortNum(portArray.data(), portArray.size());
            QList<long> ports;

            const QByteArray text = portArray.left(qMin(portArray.indexOf('\0') >= 0 ? portArray.indexOf('\0') : portArray.size(), portArray.size())).trimmed();
            if (!text.isEmpty()) {
                const QList<QByteArray> parts = text.split(',');
                for (const QByteArray &part : parts) {
                    bool ok = false;
                    long n = part.trimmed().toLong(&ok);
                    if (ok && n >= 0 && !ports.contains(n))
                        ports.append(n);
                }
            }

            for (int i = 0; i < portArray.size(); ++i) {
                const unsigned char b = static_cast<unsigned char>(portArray.at(i));
                if (b != 0 && b < 32 && !ports.contains(static_cast<long>(b)))
                    ports.append(static_cast<long>(b));
            }

            if (ports.isEmpty() && count > 0) {
                for (long i = 0; i < count && i < portArray.size(); ++i) {
                    const unsigned char b = static_cast<unsigned char>(portArray.at(static_cast<int>(i)));
                    if (b != 0 && !ports.contains(static_cast<long>(b)))
                        ports.append(static_cast<long>(b));
                }
            }

            for (long pn : ports) {
                long status = m_getStatus(pn);
                if (status == STATUS_ERROR) {
                    QThread::msleep(300);
                    status = m_getStatus(pn);
                }
                if (status != STATUS_ERROR) {
                    QString detail = decodeStatus(status);
                    char media[256] = {0};
                    if (m_getMedia && m_getMedia(pn, media) >= 0)
                        detail += QStringLiteral(" | Media: %1").arg(QString::fromLatin1(media).trimmed());
                    if (m_getMediaCounter)
                        detail += QStringLiteral(" | Remaining: %1").arg(m_getMediaCounter(pn));
                    QMetaObject::invokeMethod(this, [this, pn, detail]() {
                        m_portNum = pn;
                        setSdkPort(QStringLiteral("Port #%1").arg(pn));
                        setSdkStatus(detail);
                        appendLog(QStringLiteral("DirectDLL connected on port #%1: %2").arg(pn).arg(detail));
                        setBusy(false);
                    }, Qt::QueuedConnection);
                    return;
                }
            }

            const QString rawHex = QString::fromLatin1(portArray.left(32).toHex(' '));
            QMetaObject::invokeMethod(this, [this, count, rawHex]() {
                m_portNum = -1;
                setSdkPort(QString());
                setSdkStatus(QStringLiteral("No DirectDLL printer port found"));
                appendLog(QStringLiteral("GetPrinterPortNum returned %1, raw[0..31]=%2").arg(count).arg(rawHex));
                setBusy(false);
            }, Qt::QueuedConnection);
            return;
        }

        const QStringList ports = {
            QStringLiteral("USB002"), QStringLiteral("USB001"), QStringLiteral("USB003"),
            QStringLiteral("USB004"), QStringLiteral("USB005"), QStringLiteral("USB006"),
            QStringLiteral("USB007"), QStringLiteral("USB008"), QStringLiteral("USB009")
        };

        for (const QString &port : ports) {
            QVector<wchar_t> buf(port.size() + 1);
            port.toWCharArray(buf.data());
            buf[port.size()] = L'\0';
            const long pn = m_portInitialize(buf.data());
            if (pn < 0)
                continue;

            QThread::msleep(200);
            long status = m_getStatus(pn);
            if (status == STATUS_ERROR) {
                QThread::msleep(300);
                status = m_getStatus(pn);
            }
            if (status != STATUS_ERROR) {
                QString detail = decodeStatus(status);
                char media[256] = {0};
                if (m_getMedia && m_getMedia(pn, media) >= 0)
                    detail += QStringLiteral(" | Media: %1").arg(QString::fromLatin1(media).trimmed());
                if (m_getMediaCounter)
                    detail += QStringLiteral(" | Remaining: %1").arg(m_getMediaCounter(pn));
                QMetaObject::invokeMethod(this, [this, port, pn, detail]() {
                    m_portNum = pn;
                    setSdkPort(port);
                    setSdkStatus(detail);
                    appendLog(QStringLiteral("SDK connected on %1: %2").arg(port, detail));
                    setBusy(false);
                }, Qt::QueuedConnection);
                return;
            }
        }

        QMetaObject::invokeMethod(this, [this]() {
            m_portNum = -1;
            setSdkPort(QString());
            setSdkStatus(QStringLiteral("No RX1 SDK port found"));
            appendLog(QStringLiteral("No RX1 responded on USB001-USB009."));
            setBusy(false);
        }, Qt::QueuedConnection);
    });
}

void Rx1ToolPrinterBackend::printImage(const QString &imagePath,
                                       const QString &printerName,
                                       const QString &paperSize,
                                       bool cutMode,
                                       int copies,
                                       int dpi,
                                       int orientationMode)
{
    const QString localPath = normalizeLocalPath(imagePath);
    const QString printer = printerName.isEmpty() ? m_selectedPrinter : printerName;
    if (localPath.isEmpty() || !QFile::exists(localPath)) {
        const QString msg = QStringLiteral("Image file not found.");
        appendLog(msg);
        emit printFinished(false, msg);
        return;
    }
    if (!isSupportedDnpPrinter(printer))
        appendLog(QStringLiteral("Warning: selected printer name does not look like RX1/DS620; trying Windows driver anyway."));

    setBusy(true);
    QtConcurrent::run([this, localPath, printer, paperSize, cutMode, copies, dpi, orientationMode]() {
        QString message;
        bool ok = false;
#ifdef Q_OS_WIN
        ok = printImageWinApi(localPath, printer, paperSize, cutMode, qBound(1, copies, 10), dpi, orientationMode, message);
#else
        Q_UNUSED(paperSize); Q_UNUSED(cutMode); Q_UNUSED(copies); Q_UNUSED(dpi); Q_UNUSED(orientationMode);
        message = QStringLiteral("Printing is only supported on Windows.");
#endif
        QMetaObject::invokeMethod(this, [this, ok, message]() {
            appendLog(message);
            emit printFinished(ok, message);
            setBusy(false);
        }, Qt::QueuedConnection);
    });
}

#ifdef Q_OS_WIN
QString Rx1ToolPrinterBackend::printerPortName(const QString &printerName) const
{
    QString port;
    HANDLE h = nullptr;
    std::wstring nameW = printerName.toStdWString();
    if (!OpenPrinterW((LPWSTR)nameW.c_str(), &h, nullptr))
        return port;
    DWORD needed = 0;
    GetPrinterW(h, 2, nullptr, 0, &needed);
    if (needed > 0) {
        QByteArray buf(static_cast<int>(needed), 0);
        if (GetPrinterW(h, 2, reinterpret_cast<LPBYTE>(buf.data()), needed, &needed)) {
            auto *pi2 = reinterpret_cast<PRINTER_INFO_2W *>(buf.data());
            if (pi2->pPortName)
                port = QString::fromWCharArray(pi2->pPortName);
        }
    }
    ClosePrinter(h);
    return port;
}

QVector<Rx1ToolPrinterBackend::DnpPaper> Rx1ToolPrinterBackend::enumeratePapers(const QString &printerName) const
{
    QVector<DnpPaper> papers;
    const QString port = printerPortName(printerName);
    const std::wstring nameW = printerName.toStdWString();
    const std::wstring portW = port.toStdWString();
    LPCWSTR pPort = port.isEmpty() ? nullptr : portW.c_str();
    const int nNames = DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERNAMES, nullptr, nullptr);
    const int nNums = DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERS, nullptr, nullptr);
    if (nNames <= 0 || nNums <= 0 || nNames != nNums)
        return papers;

    QVector<wchar_t> names(nNames * 64, 0);
    QVector<WORD> nums(nNums, 0);
    if (DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERNAMES, names.data(), nullptr) <= 0)
        return papers;
    if (DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERS, reinterpret_cast<LPWSTR>(nums.data()), nullptr) <= 0)
        return papers;

    for (int i = 0; i < nNames; ++i) {
        const wchar_t *p = names.data() + i * 64;
        int len = 0;
        while (len < 64 && p[len] != L'\0')
            ++len;
        DnpPaper paper;
        paper.name = QString::fromWCharArray(p, len).trimmed();
        paper.number = static_cast<short>(nums[i]);
        if (!paper.name.isEmpty())
            papers.append(paper);
    }
    return papers;
}

bool Rx1ToolPrinterBackend::isCut4x6PaperName(const QString &name) const
{
    const QString n = name.trimmed();
    return n.compare(QStringLiteral("(6x4)"), Qt::CaseInsensitive) == 0
        || n.compare(QStringLiteral("PR (4x6)"), Qt::CaseInsensitive) == 0
        || n.contains(QStringLiteral("4x6"), Qt::CaseInsensitive)
        || n.contains(QStringLiteral("6x4"), Qt::CaseInsensitive);
}

bool Rx1ToolPrinterBackend::isSixByEightPaperName(const QString &name) const
{
    const QString n = name.trimmed();
    return n.contains(QStringLiteral("6x8"), Qt::CaseInsensitive)
        || n.contains(QStringLiteral("8x6"), Qt::CaseInsensitive);
}

bool Rx1ToolPrinterBackend::findExDevTop(void *devmodePtr, int devmodeSize, int &exDevTop) const
{
    const int intCount = devmodeSize / static_cast<int>(sizeof(int));
    int *ints = reinterpret_cast<int *>(devmodePtr);
    for (int i = 0; i < intCount; ++i) {
        if (ints[i] == EX_DEV_SIGN) {
            exDevTop = i - 1;
            return true;
        }
    }
    return false;
}

bool Rx1ToolPrinterBackend::writeDevmodePrivateInt(void *devmodePtr, int devmodeSize, int fieldOffset, int value, const char *fieldName)
{
    int exDevTop = -1;
    if (!findExDevTop(devmodePtr, devmodeSize, exDevTop)) {
        appendLog(QStringLiteral("Cannot find DNP private DEVMODE MSFT signature for %1.").arg(QString::fromLatin1(fieldName)));
        return false;
    }
    const int intCount = devmodeSize / static_cast<int>(sizeof(int));
    const int pos = exDevTop + fieldOffset;
    if (pos < 0 || pos >= intCount)
        return false;
    reinterpret_cast<int *>(devmodePtr)[pos] = value;
    return true;
}

bool Rx1ToolPrinterBackend::modifyDevmodeCut(void *devmodePtr, int devmodeSize, bool enableCut)
{
    return writeDevmodePrivateInt(devmodePtr, devmodeSize, ExCut2inch,
                                  enableCut ? DM_CUT2INCH_ON : DM_CUT2INCH_OFF,
                                  enableCut ? "OemCut2inch" : "OemCut2inch");
}

bool Rx1ToolPrinterBackend::modifyDevmodeBorder(void *devmodePtr, int devmodeSize, bool borderOn)
{
    return writeDevmodePrivateInt(devmodePtr, devmodeSize, ExBorder,
                                  borderOn ? DM_BORDER_ON : DM_BORDER_OFF,
                                  "OemBorder");
}

bool Rx1ToolPrinterBackend::modifyDevmodeOrientation(void *devmodePtr, bool landscape)
{
    auto *dm = reinterpret_cast<PDEVMODEW>(devmodePtr);
    dm->dmOrientation = landscape ? DMORIENT_LANDSCAPE : DMORIENT_PORTRAIT;
    dm->dmFields |= DM_ORIENTATION;
    return true;
}

bool Rx1ToolPrinterBackend::printImageWinApi(const QString &imagePath,
                                             const QString &printerName,
                                             const QString &paperSize,
                                             bool cutMode,
                                             int copies,
                                             int dpi,
                                             int orientationMode,
                                             QString &message)
{
    HANDLE hPrinter = nullptr;
    HANDLE hDevMode = nullptr;
    void *lpDevMode = nullptr;
    HDC hdc = nullptr;

    try {
        QImage image(imagePath);
        if (image.isNull())
            throw std::runtime_error("Failed to load image.");
        if (image.format() != QImage::Format_RGB888)
            image = image.convertToFormat(QImage::Format_RGB888);
        image = image.rgbSwapped();

        std::wstring printerW = printerName.toStdWString();
        if (!OpenPrinterW((LPWSTR)printerW.c_str(), &hPrinter, nullptr))
            throw std::runtime_error("Failed to open printer.");

        long devmodeSize = DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)printerW.c_str(), nullptr, nullptr, 0);
        if (devmodeSize <= 0)
            throw std::runtime_error("Failed to get DEVMODE size.");

        hDevMode = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, devmodeSize);
        if (!hDevMode)
            throw std::runtime_error("Failed to allocate DEVMODE.");
        lpDevMode = GlobalLock(hDevMode);
        if (!lpDevMode)
            throw std::runtime_error("Failed to lock DEVMODE.");

        if (DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)printerW.c_str(),
                                reinterpret_cast<PDEVMODEW>(lpDevMode), nullptr, DM_OUT_BUFFER) < 0) {
            throw std::runtime_error("Failed to read DEVMODE.");
        }

        auto *dm = reinterpret_cast<PDEVMODEW>(lpDevMode);
        if (dpi > 0) {
            dm->dmPrintQuality = static_cast<short>(dpi);
            dm->dmYResolution = static_cast<short>(dpi);
            dm->dmFields |= DM_PRINTQUALITY | DM_YRESOLUTION;
        }

        const QVector<DnpPaper> papers = enumeratePapers(printerName);
        short wantedPaper = 0;
        for (const DnpPaper &paper : papers) {
            if ((paperSize == QStringLiteral("6x8") && isSixByEightPaperName(paper.name))
                || (paperSize != QStringLiteral("6x8") && isCut4x6PaperName(paper.name))) {
                wantedPaper = paper.number;
                break;
            }
        }
        if (wantedPaper != 0) {
            dm->dmPaperSize = wantedPaper;
            dm->dmFields |= DM_PAPERSIZE;
            dm->dmFields &= ~(DM_PAPERLENGTH | DM_PAPERWIDTH);
        }

        if (cutMode)
            modifyDevmodeBorder(lpDevMode, devmodeSize, false);
        if (!modifyDevmodeCut(lpDevMode, devmodeSize, cutMode))
            appendLog(QStringLiteral("Warning: cut DEVMODE flag could not be written; driver default may be used."));

        const bool imageLandscape = image.width() > image.height();
        const bool autoOrientation = (orientationMode <= 0);
        bool setLandscape = false;
        if (orientationMode == 1) {
            setLandscape = true;
        } else if (orientationMode == 2) {
            setLandscape = false;
        } else {
            setLandscape = !imageLandscape;
        }
        modifyDevmodeOrientation(lpDevMode, setLandscape);
        appendLog(QStringLiteral("Print settings: paper=%1, cut=%2, dpi=%3, orientation=%4")
                      .arg(paperSize,
                           cutMode ? QStringLiteral("2inch") : QStringLiteral("normal"),
                           QString::number(dpi),
                           autoOrientation ? QStringLiteral("auto")
                                           : (setLandscape ? QStringLiteral("landscape") : QStringLiteral("portrait"))));

        hdc = CreateDCW(nullptr, printerW.c_str(), nullptr, reinterpret_cast<PDEVMODEW>(lpDevMode));
        if (!hdc)
            throw std::runtime_error("Failed to create printer DC.");

        int canvasW = GetDeviceCaps(hdc, PHYSICALWIDTH);
        int canvasH = GetDeviceCaps(hdc, PHYSICALHEIGHT);
        if (autoOrientation && canvasW > 0 && canvasH > 0 && ((canvasW > canvasH) != imageLandscape)) {
            setLandscape = !setLandscape;
            modifyDevmodeOrientation(lpDevMode, setLandscape);
            DeleteDC(hdc);
            hdc = CreateDCW(nullptr, printerW.c_str(), nullptr, reinterpret_cast<PDEVMODEW>(lpDevMode));
            if (!hdc)
                throw std::runtime_error("Failed to recreate printer DC.");
            canvasW = GetDeviceCaps(hdc, PHYSICALWIDTH);
            canvasH = GetDeviceCaps(hdc, PHYSICALHEIGHT);
        }

        const int offsetX = GetDeviceCaps(hdc, PHYSICALOFFSETX);
        const int offsetY = GetDeviceCaps(hdc, PHYSICALOFFSETY);

        BITMAPINFO bmi;
        memset(&bmi, 0, sizeof(bmi));
        bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
        bmi.bmiHeader.biWidth = image.width();
        bmi.bmiHeader.biHeight = -image.height();
        bmi.bmiHeader.biPlanes = 1;
        bmi.bmiHeader.biBitCount = 24;
        bmi.bmiHeader.biCompression = BI_RGB;

        for (int i = 0; i < copies; ++i) {
            DOCINFOW docInfo = {};
            docInfo.cbSize = sizeof(DOCINFOW);
            std::wstring docName = QStringLiteral("RX1 Print Tool %1").arg(i + 1).toStdWString();
            docInfo.lpszDocName = docName.c_str();
            if (StartDocW(hdc, &docInfo) <= 0)
                throw std::runtime_error("Failed to start print document.");
            if (StartPage(hdc) <= 0) {
                EndDoc(hdc);
                throw std::runtime_error("Failed to start print page.");
            }
            SetStretchBltMode(hdc, HALFTONE);
            SetBrushOrgEx(hdc, 0, 0, nullptr);
            StretchDIBits(hdc, -offsetX, -offsetY, canvasW, canvasH,
                          0, 0, image.width(), image.height(),
                          image.bits(), &bmi, DIB_RGB_COLORS, SRCCOPY);
            EndPage(hdc);
            EndDoc(hdc);
        }

        DeleteDC(hdc);
        GlobalUnlock(hDevMode);
        GlobalFree(hDevMode);
        ClosePrinter(hPrinter);
        message = QStringLiteral("Sent %1 copy/copies to %2 (%3, %4, %5).")
                      .arg(copies)
                      .arg(printerName, paperSize,
                           cutMode ? QStringLiteral("cut") : QStringLiteral("no cut"),
                           autoOrientation ? QStringLiteral("auto")
                                           : (setLandscape ? QStringLiteral("landscape") : QStringLiteral("portrait")));
        return true;
    } catch (const std::exception &e) {
        if (hdc)
            DeleteDC(hdc);
        if (lpDevMode)
            GlobalUnlock(hDevMode);
        if (hDevMode)
            GlobalFree(hDevMode);
        if (hPrinter)
            ClosePrinter(hPrinter);
        message = QStringLiteral("Print failed: %1").arg(QString::fromLocal8Bit(e.what()));
        return false;
    }
}
#endif
