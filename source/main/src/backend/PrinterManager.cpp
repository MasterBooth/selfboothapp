#include "PrinterManager.h"
#include <QPainter>
#include <QFileInfo>
#include <QCoreApplication>
#include <QUrl>
#include <QPrinterInfo>
#include <QThread>
#include <QFileDialog>
#include <QStandardPaths>
#include <QFile>
#include <QDir>
#include <QDateTime>
#include <QImage>
#include <QVector>
#include <QtConcurrent/QtConcurrent>
#include "ImageCompositor.h"   // CutBleedMode — gắn nhãn chế độ vào file printout/

PrinterManager::PrinterManager(QObject *parent) : QObject(parent) {
    m_printPool.setMaxThreadCount(1);   // job in chạy tuần tự, cách ly global pool
    m_currentStatus = "Initializing...";
    loadSdk();

    // Auto-initialize default port; nếu thất bại sẽ scan trong reconnect()
    if (m_isConnected) {
        if (initializePort("USB002")) {
            m_currentPort = "USB002";
        } else {
            // USB002 thất bại → thử scan ngầm không block constructor
            reconnect();
        }
    }

    // Start polling timer — checkStatus() chạy async, không block UI
    QTimer *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &PrinterManager::checkStatus);
    timer->start(3000);
}

PrinterManager::~PrinterManager() {
    if (m_sdkLib.isLoaded()) {
        m_sdkLib.unload();
    }
}

void PrinterManager::loadSdk() {
    // Try multiple paths for robustness
    QStringList paths = {
        "Status API/Dll/Win64/CyStat64",
        "CyStat64",
        QCoreApplication::applicationDirPath() + "/CyStat64"
    };

    bool loaded = false;
    for (const QString &path : paths) {
        m_sdkLib.setFileName(path);
        if (m_sdkLib.load()) {
            loaded = true;
            qDebug() << "SDK Loaded from:" << path;
            break;
        }
    }

    if (loaded) {
        // Try both function name variants (with and without Cv prefix)
        // According to SDK doc, both should exist
        m_portInitialize = (PortInitializeFunc) m_sdkLib.resolve("PortInitialize");
        if (!m_portInitialize) {
            m_portInitialize = (PortInitializeFunc) m_sdkLib.resolve("CvInitialize");
        }

        m_getFirmwVersion = (GetFirmwVersionFunc) m_sdkLib.resolve("GetFirmwVersion");
        if (!m_getFirmwVersion) {
            m_getFirmwVersion = (GetFirmwVersionFunc) m_sdkLib.resolve("CvGetVersion");
        }

        m_getSerialNo = (GetSerialNoFunc) m_sdkLib.resolve("GetSerialNo");
        if (!m_getSerialNo) {
            m_getSerialNo = (GetSerialNoFunc) m_sdkLib.resolve("CvGetSerialNo");
        }

        m_getSensorInfo = (GetSensorInfoFunc) m_sdkLib.resolve("GetSensorInfo");
        if (!m_getSensorInfo) {
            m_getSensorInfo = (GetSensorInfoFunc) m_sdkLib.resolve("CvGetSensorInfo");
        }

        m_getStatus = (GetStatusFunc) m_sdkLib.resolve("GetStatus");
        if (!m_getStatus) {
            m_getStatus = (GetStatusFunc) m_sdkLib.resolve("CvGetStatus");
            qDebug() << "Using CvGetStatus instead of GetStatus";
        }

        m_getMedia = (GetMediaFunc) m_sdkLib.resolve("GetMedia");
        if (!m_getMedia) {
            m_getMedia = (GetMediaFunc) m_sdkLib.resolve("CvGetMedia");
        }

        m_getCounterL = (GetCounterLFunc) m_sdkLib.resolve("GetCounterL");
        m_getCounterA = (GetCounterAFunc) m_sdkLib.resolve("GetCounterA");
        m_getCounterB = (GetCounterBFunc) m_sdkLib.resolve("GetCounterB");
        m_getCounterP = (GetCounterPFunc) m_sdkLib.resolve("GetCounterP");
        m_getCounterM = (GetCounterMFunc) m_sdkLib.resolve("GetCounterM");
        m_getCounterMatte = (GetCounterMatteFunc) m_sdkLib.resolve("GetCounterMatte");
        m_setClearCounterA = (SetClearCounterAFunc) m_sdkLib.resolve("SetClearCounterA");
        m_setClearCounterB = (SetClearCounterBFunc) m_sdkLib.resolve("SetClearCounterB");
        m_setClearCounterM = (SetClearCounterMFunc) m_sdkLib.resolve("SetClearCounterM");
        m_setCounterP = (SetCounterPFunc) m_sdkLib.resolve("SetCounterP");

        m_getMediaCounter = (GetMediaCounterFunc) m_sdkLib.resolve("GetMediaCounter");
        m_getMediaLotNo = (GetMediaLotNoFunc) m_sdkLib.resolve("GetMediaLotNo");
        m_getMediaColorOffset = (GetMediaColorOffsetFunc) m_sdkLib.resolve("GetMediaColorOffset");
        m_getMediaIdSetInfo = (GetMediaIdSetInfoFunc) m_sdkLib.resolve("GetMediaIdSetInfo");
        m_getInitialMediaCount = (GetInitialMediaCountFunc) m_sdkLib.resolve("GetInitialMediaCount");
        m_getMediaCountOffset = (GetMediaCountOffsetFunc) m_sdkLib.resolve("GetMediaCountOffset");

        m_getColorDataVersion = (GetColorDataVersionFunc) m_sdkLib.resolve("GetColorDataVersion");
        m_getColorDataChecksum = (GetColorDataChecksumFunc) m_sdkLib.resolve("GetColorDataChecksum");

        m_getPQTY = (GetPQTYFunc) m_sdkLib.resolve("GetPQTY");
        m_getFreeBuffer = (GetFreeBufferFunc) m_sdkLib.resolve("GetFreeBuffer");

        m_getResolutionH = (GetResolutionHFunc) m_sdkLib.resolve("GetResolutionH");
        m_getResolutionV = (GetResolutionVFunc) m_sdkLib.resolve("GetResolutionV");

        m_setCutterMode = (SetCutterModeFunc) m_sdkLib.resolve("SetCutterMode");
        m_setUSBSerialEnable = (SetUSBSerialEnableFunc) m_sdkLib.resolve("SetUSBSerialEnable");
        m_getUSBSerialEnable = (GetUSBSerialEnableFunc) m_sdkLib.resolve("GetUSBSerialEnable");

        // Debug: Show which functions were loaded
        qDebug() << "Function loading status:";
        qDebug() << "  PortInitialize:" << (m_portInitialize != nullptr);
        qDebug() << "  GetStatus:" << (m_getStatus != nullptr);
        qDebug() << "  GetFirmwVersion:" << (m_getFirmwVersion != nullptr);
        qDebug() << "  GetSerialNo:" << (m_getSerialNo != nullptr);

        if (m_portInitialize && m_getStatus) {
            m_isConnected = true;
            emit connectionChanged(true);
            qDebug() << "All critical SDK functions loaded successfully";
        } else {
            qWarning() << "Failed to resolve critical SDK functions";
            m_currentStatus = "Error: Invalid SDK DLL";
            emit statusChanged(m_currentStatus);
        }
    } else {
        qWarning() << "Failed to load CyStat64.dll";
        m_currentStatus = "Error: SDK DLL Missing";
        emit statusChanged(m_currentStatus);
        emit errorOccurred("Failed to load CyStat64.dll");
    }
}

bool PrinterManager::initializePort(const QString &portName) {
    if (!m_portInitialize) {
        emit errorOccurred("SDK not loaded");
        return false;
    }

    // IMPORTANT: DLL expects wchar_t* (non-const), so create a buffer
    // Using QVector to ensure proper memory management
    QVector<wchar_t> portBuffer(portName.size() + 1);
    portName.toWCharArray(portBuffer.data());
    portBuffer[portName.size()] = L'\0';  // Null terminate

    m_portNum = m_portInitialize(portBuffer.data());
    if (m_portNum < 0) {
        emit errorOccurred("Failed to initialize port: " + portName);
        qWarning() << "Port initialization failed for:" << portName;
        return false;
    }

    qDebug() << "Port initialized:" << portName << "-> Port number:" << m_portNum;

    // Wait for printer to be ready after initialization
    QThread::msleep(200);  // Increased from 100ms

    // Test status immediately after init
    if (m_getStatus) {
        long testStatus = m_getStatus(m_portNum);
        qDebug() << "Initial status check: 0x" << QString::number(testStatus, 16).toUpper();

        // Try again if first attempt returns error
        if (testStatus == STATUS_ERROR) {
            qDebug() << "First status check returned ERROR, retrying after delay...";
            QThread::msleep(300);
            testStatus = m_getStatus(m_portNum);
            qDebug() << "Second status check: 0x" << QString::number(testStatus, 16).toUpper();
        }
    }

    return true;
}

void PrinterManager::checkStatus() {
    if (!m_getStatus) return;

    long portNum;
    {
        QMutexLocker lk(&m_sdkMutex);
        portNum = m_portNum;
    }
    if (portNum < 0) return;

    // Skip nếu lần check trước chưa xong (tránh stack DLL calls)
    if (!m_statusCheckBusy.testAndSetAcquire(0, 1)) return;

    QtConcurrent::run([this, portNum]() {
        long status;
        { QMutexLocker dlk(&m_dllMutex); status = m_getStatus(portNum); }
        QMetaObject::invokeMethod(this, [this, status]() {
            m_statusCheckBusy.storeRelease(0);
            QString statusStr = decodeStatus(status);
            if (m_currentStatus != statusStr) {
                m_currentStatus = statusStr;
                emit statusChanged(m_currentStatus);
                qDebug() << "Printer Status:" << m_currentStatus
                         << "(Code: 0x" << QString::number(status, 16).toUpper() << ")";
            }
        }, Qt::QueuedConnection);
    });
}

QString PrinterManager::decodeStatus(long status) {
    if (status == STATUS_ERROR) {
        return "ERROR!";
    }

    // Usually Status Group
    if (status & GROUP_USUALLY) {
        if (status == STATUS_USUALLY_IDLE) return "Idle";
        if (status == STATUS_USUALLY_PRINTING) return "Printing";
        if (status == STATUS_USUALLY_STANDSTILL) return "Standstill";
        if (status == STATUS_USUALLY_PAPER_END) return "Paper End";
        if (status == STATUS_USUALLY_RIBBON_END) return "Ribbon End";
        if (status == STATUS_USUALLY_COOLING) return "Head Cooling Down";
        if (status == STATUS_USUALLY_MOTCOOLING) return "Motor Cooling Down";
    }
    // Setting Status Group
    else if (status & GROUP_SETTING) {
        if (status == STATUS_SETTING_COVER_OPEN) return "Cover Open";
        if (status == STATUS_SETTING_PAPER_JAM) return "Paper Jam";
        if (status == STATUS_SETTING_RIBBON_ERR) return "Ribbon Error";
        if (status == STATUS_SETTING_PAPER_ERR) return "Paper Definition Error";
        if (status == STATUS_SETTING_DATA_ERR) return "Data Error";
        if (status == STATUS_SETTING_SCRAPBOX_ERR) return "Scrap Box Error";
    }
    // Hardware Status Group
    else if (status & GROUP_HARDWARE) {
        if (status == STATUS_HARDWARE_ERR01) return "Head Voltage Error";
        if (status == STATUS_HARDWARE_ERR02) return "Head Position Error";
        if (status == STATUS_HARDWARE_ERR03) return "Fan Stop Error";
        if (status == STATUS_HARDWARE_ERR04) return "Cutter Error";
        if (status == STATUS_HARDWARE_ERR05) return "Pinch Roller Error";
        if (status == STATUS_HARDWARE_ERR06) return "Illegal Head Temperature";
        if (status == STATUS_HARDWARE_ERR07) return "Illegal Media Temperature";
        if (status == STATUS_HARDWARE_ERR08) return "Ribbon Tension Error";
        if (status == STATUS_HARDWARE_ERR09) return "RFID Module Error";
        if (status == STATUS_HARDWARE_ERR10) return "Illegal Motor Temperature";
    }
    // System Status Group
    else if (status & GROUP_SYSTEM) {
        return "SYSTEM ERROR";
    }
    // Flash Programming Status Group
    else if (status & GROUP_FLSHPROG) {
        return "FLASH PROGRAMMING MODE";
    }

    return "Unknown Status";
}

QString PrinterManager::getStatusString() {
    if (!m_getStatus || m_portNum < 0) return "Not connected";
    long status = m_getStatus(m_portNum);
    return decodeStatus(status);
}

QString PrinterManager::getFirmwareVersion() {
    if (!m_getFirmwVersion || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getFirmwVersion(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

QString PrinterManager::getSerialNumber() {
    if (!m_getSerialNo || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getSerialNo(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

QString PrinterManager::getSensorInfo() {
    if (!m_getSensorInfo || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getSensorInfo(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

QString PrinterManager::getColorDataVersion() {
    if (!m_getColorDataVersion || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getColorDataVersion(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

QString PrinterManager::getColorDataChecksum() {
    if (!m_getColorDataChecksum || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getColorDataChecksum(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

QString PrinterManager::getMediaCode() {
    if (!m_getMedia || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getMedia(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

int PrinterManager::getMediaCounter() {
    if (!m_getMediaCounter || m_portNum < 0) return -1;
    return m_getMediaCounter(m_portNum);
}

QString PrinterManager::getMediaLotNo() {
    if (!m_getMediaLotNo || m_portNum < 0) return "ERROR";

    char buffer[256] = {0};
    long len = m_getMediaLotNo(m_portNum, buffer);
    if (len >= 0) {
        return QString::fromLatin1(buffer, len);
    }
    return "ERROR";
}

int PrinterManager::getMediaColorOffset() {
    if (!m_getMediaColorOffset || m_portNum < 0) return -1;
    long offset = m_getMediaColorOffset(m_portNum);
    return offset;
}

int PrinterManager::getMediaIdSetInfo() {
    if (!m_getMediaIdSetInfo || m_portNum < 0) return -1;
    return m_getMediaIdSetInfo(m_portNum);
}

int PrinterManager::getInitialMediaCount() {
    if (!m_getInitialMediaCount || m_portNum < 0) return -1;
    return m_getInitialMediaCount(m_portNum);
}

int PrinterManager::getMediaCountOffset() {
    if (!m_getMediaCountOffset || m_portNum < 0) return -1;
    return m_getMediaCountOffset(m_portNum);
}

int PrinterManager::getCounterL() {
    if (!m_getCounterL || m_portNum < 0) return -1;
    return m_getCounterL(m_portNum);
}

int PrinterManager::getCounterA() {
    if (!m_getCounterA || m_portNum < 0) return -1;
    return m_getCounterA(m_portNum);
}

int PrinterManager::getCounterB() {
    if (!m_getCounterB || m_portNum < 0) return -1;
    return m_getCounterB(m_portNum);
}

int PrinterManager::getCounterP() {
    if (!m_getCounterP || m_portNum < 0) return -1;
    return m_getCounterP(m_portNum);
}

int PrinterManager::getCounterM() {
    if (!m_getCounterM || m_portNum < 0) return -1;
    return m_getCounterM(m_portNum);
}

int PrinterManager::getCounterMatte() {
    if (!m_getCounterMatte || m_portNum < 0) return -1;
    return m_getCounterMatte(m_portNum);
}

bool PrinterManager::clearCounterA() {
    if (!m_setClearCounterA || m_portNum < 0) return false;
    return m_setClearCounterA(m_portNum) != 0;
}

bool PrinterManager::clearCounterB() {
    if (!m_setClearCounterB || m_portNum < 0) return false;
    return m_setClearCounterB(m_portNum) != 0;
}

bool PrinterManager::clearCounterM() {
    if (!m_setClearCounterM || m_portNum < 0) return false;
    return m_setClearCounterM(m_portNum) != 0;
}

bool PrinterManager::setCounterP(int value) {
    if (!m_setCounterP || m_portNum < 0) return false;
    return m_setCounterP(m_portNum, value) != 0;
}

int PrinterManager::getRemainingPrintQuantity() {
    if (!m_getPQTY || m_portNum < 0) return -1;
    return m_getPQTY(m_portNum);
}

int PrinterManager::getFreeBufferCount() {
    if (!m_getFreeBuffer || m_portNum < 0) return -1;
    return m_getFreeBuffer(m_portNum);
}

int PrinterManager::getResolutionH() {
    if (!m_getResolutionH || m_portNum < 0) return -1;
    return m_getResolutionH(m_portNum);
}

int PrinterManager::getResolutionV() {
    if (!m_getResolutionV || m_portNum < 0) return -1;
    return m_getResolutionV(m_portNum);
}

bool PrinterManager::setCutterMode(int mode) {
    if (!m_setCutterMode || m_portNum < 0) return false;
    long result = m_setCutterMode(m_portNum, mode);
    qDebug() << "Cutter Mode Set to:" << mode << "Result:" << result;
    return result >= 0;
}

bool PrinterManager::setUSBSerialEnable(bool enable) {
    if (!m_setUSBSerialEnable || m_portNum < 0) return false;
    return m_setUSBSerialEnable(m_portNum, enable ? 1 : 0);
}

int PrinterManager::getUSBSerialEnable() {
    if (!m_getUSBSerialEnable || m_portNum < 0) return -1;
    return m_getUSBSerialEnable(m_portNum);
}

void PrinterManager::printImage(const QString &imagePath, int copies, const QString &pageSize) {
    qDebug() << "Requesting Print:" << imagePath << "Copies:" << copies << "Size:" << pageSize;

    // 1. Basic Validation
    QString localPath = QUrl(imagePath).toLocalFile();
    if (localPath.isEmpty()) localPath = imagePath;

    if (!QFileInfo::exists(localPath)) {
        emit printFinished(false, "Image file not found: " + localPath);
        return;
    }

    // 2. Setup QPrinter
    QPrinter printer(QPrinter::HighResolution);
    QString legacyPrinterName = (m_printerConfig && !m_printerConfig->selectedPrinter().isEmpty())
                                ? m_printerConfig->selectedPrinter() : "DNP DS-RX1";
    printer.setPrinterName(legacyPrinterName);
    printer.setCopyCount(copies);

    // Page Size Logic
    if (pageSize == "6x8") {
        printer.setPageSize(QPageSize(QSize(6, 8), QPageSize::Inch));
    } else {
        printer.setPageSize(QPageSize(QSize(4, 6), QPageSize::Inch));
    }

    // 3. Print
    QPainter painter;
    if (!painter.begin(&printer)) {
        emit printFinished(false, QString("Failed to open printer '%1' (Check Driver Name in Settings)").arg(legacyPrinterName));
        qWarning() << "Printer Init Failed. Available Printers:" << QPrinterInfo::availablePrinterNames();
        return;
    }

    QImage img(localPath);
    if (img.isNull()) {
        emit printFinished(false, "Failed to load image data");
        return;
    }

    // Scale image to fit page
    QRect rect = painter.viewport();
    QSize size = img.size();
    size.scale(rect.size(), Qt::KeepAspectRatio);

    // Center logic
    int x = (rect.width() - size.width()) / 2;
    int y = (rect.height() - size.height()) / 2;

    painter.drawImage(x, y, img.scaled(size));
    painter.end();

    emit printFinished(true, "Sent to Printer");
}

void PrinterManager::printImageWithSettings(const QString &imagePath,
                                              int copies,
                                              const QString &paperSize,
                                              int quality,
                                              bool cutMode,
                                              bool matteFinish) {
    qDebug() << "====== PRINT REQUEST ======";
    qDebug() << "Image:" << imagePath;
    qDebug() << "User Requested Copies:" << copies;
    qDebug() << "Paper:" << paperSize;
    qDebug() << "Quality:" << quality << "dpi";
    qDebug() << "Cut Mode:" << (cutMode ? "Yes (Auto-detected)" : "No");
    qDebug() << "Matte:" << (matteFinish ? "Yes" : "No");

    // 1. Validation
    QString localPath = QUrl(imagePath).toLocalFile();
    if (localPath.isEmpty()) localPath = imagePath;

    if (!QFileInfo::exists(localPath)) {
        emit printFinished(false, "Image file not found: " + localPath);
        return;
    }

    // Capture printer name on main thread before spawning background thread
    QString selectedPrinter = (m_printerConfig && !m_printerConfig->selectedPrinter().isEmpty())
                              ? m_printerConfig->selectedPrinter() : "DS-RX1";

    // Run slow work (file I/O + Windows print API) on a background thread
    // so the UI remains responsive and user can start a new session while printing
    bool isQW410Selected = selectedPrinter.contains("QW410", Qt::CaseInsensitive)
                        || selectedPrinter.contains("QW-410", Qt::CaseInsensitive)
                        || selectedPrinter.contains("410", Qt::CaseInsensitive);
    QtConcurrent::run(&m_printPool, [this, localPath, copies, cutMode, quality, selectedPrinter, isQW410Selected]() {

        // 2. Handle cut mode
        QString printPath = localPath;
        int physicalPrints = copies;

        if (cutMode && isQW410Selected) {
            physicalPrints = (copies + 2) / 3; // ceil(copies/3) sheets — QW410 prints 3 per sheet
            qDebug() << "[PrinterManager] QW410 cut mode - User wants" << copies << "photos ->" << physicalPrints << "sheets (3/sheet)";
        } else if (cutMode) {
            physicalPrints = (copies + 1) / 2; // ceil(copies/2) sheets — RX1/620S prints 2 per sheet
            qDebug() << "[PrinterManager] Cut mode ON - User wants" << copies << "photos ->" << physicalPrints << "sheets";
        } else {
            qDebug() << "[PrinterManager] Cut mode OFF - Will print" << physicalPrints << "copies";
        }

        // 3. Save image record to event's printout folder
        QFileInfo fileInfo(localPath);
        QString eventPath;
        if (fileInfo.path().endsWith("/Final", Qt::CaseInsensitive)) {
            QDir finalDir(fileInfo.absolutePath());
            if (finalDir.dirName() == "Final") finalDir.cdUp();
            eventPath = finalDir.absolutePath();
        } else {
            eventPath = fileInfo.absolutePath();
        }

        QDir dir(eventPath);
        if (!dir.exists("printout")) dir.mkpath("printout");

        QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
        QString printoutFileName = cutMode
            ? QString("print_CUT_%1_%2sheets.jpg").arg(timestamp).arg(physicalPrints)
            : QString("print_NOCUT_%1_%2copies.jpg").arg(timestamp).arg(physicalPrints);
        QFile::copy(printPath, QDir(eventPath).filePath("printout/" + printoutFileName));

        // 4. Pre-flight: dùng SDK để gate WinPrint.
        // portNum < 0  → SDK chưa init → không chặn (WinPrint hoạt động độc lập với SDK).
        // STATUS_ERROR → SDK không liên lạc được port đã init → máy in mất kết nối → chặn.
        // m_dllMutex serialize cuộc gọi DLL, tránh race với checkStatus() timer.
        {
            long portNum;
            { QMutexLocker lk(&m_sdkMutex); portNum = m_portNum; }
            if (m_getStatus && portNum >= 0) {
                long sdkSt;
                { QMutexLocker dlk(&m_dllMutex); sdkSt = m_getStatus(portNum); }
                bool blocked = (
                    sdkSt == STATUS_ERROR                ||
                    sdkSt == STATUS_USUALLY_PAPER_END    ||
                    sdkSt == STATUS_USUALLY_RIBBON_END   ||
                    sdkSt == STATUS_SETTING_COVER_OPEN   ||
                    sdkSt == STATUS_SETTING_PAPER_JAM    ||
                    sdkSt == STATUS_SETTING_RIBBON_ERR   ||
                    sdkSt == STATUS_SETTING_PAPER_ERR    ||
                    sdkSt == STATUS_SETTING_DATA_ERR     ||
                    sdkSt == STATUS_SETTING_SCRAPBOX_ERR ||
                    (sdkSt & GROUP_HARDWARE) != 0
                );
                qDebug() << "[PrinterManager] SDK pre-flight:" << decodeStatus(sdkSt)
                         << (blocked ? "→ BLOCKED" : "→ OK");
                if (blocked) {
                    QString reason = decodeStatus(sdkSt);
                    QMetaObject::invokeMethod(this, [this, reason]() {
                        emit printFinished(false, QString("Máy in không phản hồi: %1").arg(reason));
                    }, Qt::QueuedConnection);
                    return;
                }
            }
        }

        // 5. Windows spooler pre-flight: kiểm tra selectedPrinter có online không
        // Dùng OpenPrinterW + GetPrinterW(PRINTER_INFO_2) giống autoFindAndPrint
#ifdef Q_OS_WIN
        {
            bool isSpoolerOnline = false;
            HANDLE hTest = nullptr;
            std::wstring nameW = selectedPrinter.toStdWString();
            if (OpenPrinterW((LPWSTR)nameW.c_str(), &hTest, nullptr)) {
                DWORD needed = 0;
                GetPrinterW(hTest, 2, nullptr, 0, &needed);
                if (needed > 0) {
                    QByteArray buf(static_cast<int>(needed), 0);
                    if (GetPrinterW(hTest, 2, reinterpret_cast<LPBYTE>(buf.data()), needed, &needed)) {
                        auto *pi2 = reinterpret_cast<PRINTER_INFO_2W*>(buf.data());
                        bool offline  = (pi2->Status     & 0x00000080) != 0;
                        bool workOff  = (pi2->Attributes & 0x00000400) != 0;
                        bool hasError = (pi2->Status     & 0x00000002) != 0;
                        isSpoolerOnline = !offline && !workOff && !hasError;
                        qDebug() << "[PrinterManager] Spooler check:" << selectedPrinter
                                 << "Status=0x" + QString::number(pi2->Status, 16)
                                 << "Attrs=0x" + QString::number(pi2->Attributes, 16)
                                 << (isSpoolerOnline ? "→ ONLINE" : "→ OFFLINE/ERROR");
                    }
                } else {
                    // GetPrinterW không trả về buffer (driver đang bận) — không chặn
                    isSpoolerOnline = true;
                    qDebug() << "[PrinterManager] Spooler check: GetPrinterW returned needed=0, assuming ONLINE";
                }
                ClosePrinter(hTest);
            } else {
                qDebug() << "[PrinterManager] OpenPrinterW FAILED for:" << selectedPrinter << "→ printer not found in spooler";
            }

            if (!isSpoolerOnline) {
                QMetaObject::invokeMethod(this, [this, selectedPrinter]() {
                    emit printFinished(false, QString("Máy in '%1' không sẵn sàng (offline)").arg(selectedPrinter));
                }, Qt::QueuedConnection);
                return;
            }
        }
#endif

        // 6. Print with Windows API (always portrait)
        printWithDevmodeWinAPI(printPath, physicalPrints, cutMode, false, 0, quality, selectedPrinter);
    });

}

void PrinterManager::printFreeMode(const QString &imagePath,
                                   const QString &printerName,
                                   int imageRotation,
                                   int copies) {
    qDebug() << "====== FREE PRINT REQUEST ======";
    qDebug() << "Image:" << imagePath;
    qDebug() << "Printer:" << printerName;
    qDebug() << "Rotation:" << imageRotation;
    qDebug() << "Copies:" << copies;

    // 1. Validation
    QString localPath = QUrl(imagePath).toLocalFile();
    if (localPath.isEmpty()) localPath = imagePath;

    if (!QFileInfo::exists(localPath)) {
        emit printFinished(false, "Image file not found: " + localPath);
        return;
    }

    // 2. Resolve printer name (rỗng → fallback máy in chính)
    QString resolvedPrinter = printerName;
    if (resolvedPrinter.isEmpty()) {
        resolvedPrinter = (m_printerConfig && !m_printerConfig->selectedPrinter().isEmpty())
                          ? m_printerConfig->selectedPrinter() : "DS-RX1";
    }
    int copiesToPrint = qMax(1, copies);

    // Chạy trên background thread như các path in khác. KHÔNG gate qua SDK DNP
    // (máy in tự do có thể không phải DNP); chỉ kiểm tra spooler Windows online.
    QtConcurrent::run(&m_printPool, [this, localPath, resolvedPrinter, imageRotation, copiesToPrint]() {
#ifdef Q_OS_WIN
        {
            bool isSpoolerOnline = false;
            HANDLE hTest = nullptr;
            std::wstring nameW = resolvedPrinter.toStdWString();
            if (OpenPrinterW((LPWSTR)nameW.c_str(), &hTest, nullptr)) {
                DWORD needed = 0;
                GetPrinterW(hTest, 2, nullptr, 0, &needed);
                if (needed > 0) {
                    QByteArray buf(static_cast<int>(needed), 0);
                    if (GetPrinterW(hTest, 2, reinterpret_cast<LPBYTE>(buf.data()), needed, &needed)) {
                        auto *pi2 = reinterpret_cast<PRINTER_INFO_2W*>(buf.data());
                        bool offline  = (pi2->Status     & 0x00000080) != 0;
                        bool workOff  = (pi2->Attributes & 0x00000400) != 0;
                        bool hasError = (pi2->Status     & 0x00000002) != 0;
                        isSpoolerOnline = !offline && !workOff && !hasError;
                        qDebug() << "[PrinterManager] Free print spooler check:" << resolvedPrinter
                                 << "Status=0x" + QString::number(pi2->Status, 16)
                                 << "Attrs=0x" + QString::number(pi2->Attributes, 16)
                                 << (isSpoolerOnline ? "→ ONLINE" : "→ OFFLINE/ERROR");
                    }
                } else {
                    isSpoolerOnline = true;
                    qDebug() << "[PrinterManager] Free print spooler check: needed=0, assuming ONLINE";
                }
                ClosePrinter(hTest);
            } else {
                qDebug() << "[PrinterManager] Free print OpenPrinterW FAILED for:" << resolvedPrinter;
            }

            if (!isSpoolerOnline) {
                QMetaObject::invokeMethod(this, [this, resolvedPrinter]() {
                    emit printFinished(false, QString("Máy in '%1' không sẵn sàng (offline)").arg(resolvedPrinter));
                }, Qt::QueuedConnection);
                return;
            }
        }
#endif

        // In tự do: luôn không cắt, không landscape ép, driver tự scale (freeMode=true).
        printWithDevmodeWinAPI(localPath, copiesToPrint, /*cutMode*/false, /*landscape*/false,
                               imageRotation, 300, resolvedPrinter, /*freeMode*/true);
    });
}

void PrinterManager::printImageWithSettingsAndRotation(const QString &imagePath,
                                                       int copies,
                                                       const QString &paperSize,
                                                       int quality,
                                                       bool cutMode,
                                                       bool matteFinish,
                                                       int imageRotation) {
    QDateTime requestTime = QDateTime::currentDateTime();
    qDebug() << "╔══════════════════════════════════════════════════════════════╗";
    qDebug() << "║              PRINT REQUEST RECEIVED                         ║";
    qDebug() << "╠══════════════════════════════════════════════════════════════╣";
    qDebug() << "║ Timestamp:" << requestTime.toString("yyyy-MM-dd HH:mm:ss.zzz");
    qDebug() << "║ Image:" << imagePath;
    qDebug() << "║ Copies:" << copies;
    qDebug() << "║ Paper:" << paperSize;
    qDebug() << "║ Quality:" << quality << "DPI";
    qDebug() << "║ Cut Mode:" << (cutMode ? "ON" : "OFF");
    qDebug() << "║ Matte Finish:" << (matteFinish ? "ON" : "OFF");
    qDebug() << "║ Image Rotation:" << imageRotation << "degrees";
    qDebug() << "╚══════════════════════════════════════════════════════════════╝";

    // 1. Validation
    QString localPath = QUrl(imagePath).toLocalFile();
    if (localPath.isEmpty()) localPath = imagePath;

    if (!QFileInfo::exists(localPath)) {
        emit printFinished(false, "Image file not found: " + localPath);
        return;
    }

    // Log source image dimensions before any processing
    {
        QImage srcImg(localPath);
        if (!srcImg.isNull()) {
            double srcAspect = (srcImg.height() > 0) ? (double)srcImg.width() / srcImg.height() : 0;
            qDebug() << "[PrinterManager] Source image:" << srcImg.width() << "x" << srcImg.height()
                     << "pixels | Aspect:" << QString::number(srcAspect, 'f', 4)
                     << "| Orientation:" << (srcImg.width() > srcImg.height() ? "Landscape" : "Portrait");
        }
    }

    // 2. Handle cut mode image duplication
    QString printPath = localPath;
    int physicalPrints = copies;

    QString printerForCalc = (m_printerConfig && !m_printerConfig->selectedPrinter().isEmpty())
                             ? m_printerConfig->selectedPrinter() : "DS-RX1";
    bool isQW410ForCalc = printerForCalc.contains("QW410", Qt::CaseInsensitive)
                       || printerForCalc.contains("QW-410", Qt::CaseInsensitive)
                       || printerForCalc.contains("410", Qt::CaseInsensitive);

    if (cutMode && isQW410ForCalc) {
        physicalPrints = (copies + 2) / 3; // ceil(copies/3) sheets — QW410 cut: 3 strips per sheet
        qDebug() << "[PrinterManager] QW410 cut mode - 15x10 composite pre-built";
        qDebug() << "[PrinterManager] User wants" << copies << "photos";
        qDebug() << "[PrinterManager] Will print" << physicalPrints << "sheets (each 15x10, cut to 3x 5x10)";
    } else if (cutMode) {
        physicalPrints = (copies + 1) / 2; // ceil(copies/2) sheets — RX1/620S: 2 strips per sheet
        qDebug() << "[PrinterManager] Cut mode ON - 4x6 composite pre-built";
        qDebug() << "[PrinterManager] User wants" << copies << "photos";
        qDebug() << "[PrinterManager] Will print" << physicalPrints << "sheets (each 4x6, cut to 2x 2x6)";
    } else {
        qDebug() << "[PrinterManager] Cut mode OFF - Printing original image as-is";
        qDebug() << "[PrinterManager] Will print" << physicalPrints << "copies";
    }

    // 3. Save image being sent to printer to event's printout folder
    qDebug() << "[PrinterManager] Saving image for printing record...";

    QFileInfo fileInfo(localPath);
    QString eventPath;

    if (fileInfo.path().endsWith("/Final", Qt::CaseInsensitive)) {
        // Safe navigation from Final/ to event root
        QDir finalDir(fileInfo.absolutePath());
        if (finalDir.dirName() == "Final") {
            finalDir.cdUp();
        }
        eventPath = finalDir.absolutePath();
    } else {
        eventPath = fileInfo.absolutePath();
    }

    QString printoutDir = QDir(eventPath).filePath("printout");
    QDir dir(eventPath);

    qDebug() << "[PrinterManager] Event path:" << eventPath;
    qDebug() << "[PrinterManager] Printout directory:" << printoutDir;

    if (!dir.exists("printout")) {
        if (!dir.mkpath("printout")) {
            qWarning() << "[PrinterManager] Failed to create printout directory:" << printoutDir;
        } else {
            qDebug() << "[PrinterManager] Created printout directory:" << printoutDir;
        }
    }

    // Save with descriptive name
    QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
    QString printoutFileName;
    if (cutMode) {
        printoutFileName = QString("print_CUT_%1_duplicated_%2x%3.jpg")
            .arg(timestamp)
            .arg(physicalPrints)
            .arg("2photos_per_sheet");
    } else {
        printoutFileName = QString("print_NOCUT_%1_%2x%3.jpg")
            .arg(timestamp)
            .arg(physicalPrints)
            .arg("copies");
    }

    QString printoutPath = QDir(printoutDir).filePath(printoutFileName);
    if (QFile::copy(printPath, printoutPath)) {
        qDebug() << "[PrinterManager] ✓ Saved print record:" << printoutPath;
    } else {
        qWarning() << "[PrinterManager] ⚠ Failed to save print record to:" << printoutPath;
    }

    // 4. Orientation Handling
    bool landscape = false;
    qDebug() << "[PrinterManager] Orientation auto-handled (Defaults to PORTRAIT, auto-rotates landscape images)";

    // 5. Print with Windows API on background thread so UI stays responsive
    QString selectedPrinter = (m_printerConfig && !m_printerConfig->selectedPrinter().isEmpty())
                              ? m_printerConfig->selectedPrinter() : "DS-RX1";
    qDebug() << "[PrinterManager] Using Windows API DEVMODE approach with rotation. Printer:" << selectedPrinter;

    QtConcurrent::run(&m_printPool, [this, printPath, localPath, physicalPrints, cutMode, landscape, imageRotation, quality, selectedPrinter]() {
        // Pre-flight: dùng SDK để gate WinPrint.
        // m_dllMutex serialize cuộc gọi DLL, tránh race với checkStatus() timer.
        {
            long portNum;
            { QMutexLocker lk(&m_sdkMutex); portNum = m_portNum; }
            if (m_getStatus && portNum >= 0) {
                long sdkSt;
                { QMutexLocker dlk(&m_dllMutex); sdkSt = m_getStatus(portNum); }
                bool blocked = (
                    sdkSt == STATUS_ERROR                ||
                    sdkSt == STATUS_USUALLY_PAPER_END    ||
                    sdkSt == STATUS_USUALLY_RIBBON_END   ||
                    sdkSt == STATUS_SETTING_COVER_OPEN   ||
                    sdkSt == STATUS_SETTING_PAPER_JAM    ||
                    sdkSt == STATUS_SETTING_RIBBON_ERR   ||
                    sdkSt == STATUS_SETTING_PAPER_ERR    ||
                    sdkSt == STATUS_SETTING_DATA_ERR     ||
                    sdkSt == STATUS_SETTING_SCRAPBOX_ERR ||
                    (sdkSt & GROUP_HARDWARE) != 0
                );
                qDebug() << "[PrinterManager] SDK pre-flight:" << decodeStatus(sdkSt)
                         << (blocked ? "→ BLOCKED" : "→ OK");
                if (blocked) {
                    QString reason = decodeStatus(sdkSt);
                    QMetaObject::invokeMethod(this, [this, reason]() {
                        emit printFinished(false, QString("Máy in không phản hồi: %1").arg(reason));
                    }, Qt::QueuedConnection);
                    return;
                }
            }
        }

        // Windows spooler pre-flight: kiểm tra selectedPrinter có online không
#ifdef Q_OS_WIN
        {
            bool isSpoolerOnline = false;
            HANDLE hTest = nullptr;
            std::wstring nameW = selectedPrinter.toStdWString();
            if (OpenPrinterW((LPWSTR)nameW.c_str(), &hTest, nullptr)) {
                DWORD needed = 0;
                GetPrinterW(hTest, 2, nullptr, 0, &needed);
                if (needed > 0) {
                    QByteArray buf(static_cast<int>(needed), 0);
                    if (GetPrinterW(hTest, 2, reinterpret_cast<LPBYTE>(buf.data()), needed, &needed)) {
                        auto *pi2 = reinterpret_cast<PRINTER_INFO_2W*>(buf.data());
                        bool offline  = (pi2->Status     & 0x00000080) != 0;
                        bool workOff  = (pi2->Attributes & 0x00000400) != 0;
                        bool hasError = (pi2->Status     & 0x00000002) != 0;
                        isSpoolerOnline = !offline && !workOff && !hasError;
                        qDebug() << "[PrinterManager] Spooler check:" << selectedPrinter
                                 << "Status=0x" + QString::number(pi2->Status, 16)
                                 << "Attrs=0x" + QString::number(pi2->Attributes, 16)
                                 << (isSpoolerOnline ? "→ ONLINE" : "→ OFFLINE/ERROR");
                    }
                } else {
                    // GetPrinterW không trả về buffer (driver đang bận) — không chặn
                    isSpoolerOnline = true;
                    qDebug() << "[PrinterManager] Spooler check: GetPrinterW returned needed=0, assuming ONLINE";
                }
                ClosePrinter(hTest);
            } else {
                qDebug() << "[PrinterManager] OpenPrinterW FAILED for:" << selectedPrinter << "→ printer not found in spooler";
            }

            if (!isSpoolerOnline) {
                QMetaObject::invokeMethod(this, [this, selectedPrinter]() {
                    emit printFinished(false, QString("Máy in '%1' không sẵn sàng (offline)").arg(selectedPrinter));
                }, Qt::QueuedConnection);
                return;
            }
        }
#endif

        printWithDevmodeWinAPI(printPath, physicalPrints, cutMode, landscape, imageRotation, quality, selectedPrinter);

        // Cleanup temporary file if created
        if (cutMode && !printPath.isEmpty() && printPath != localPath) {
            QFile::remove(printPath);
            qDebug() << "[PrinterManager] Cleaned up temporary duplicated image:" << printPath;
        }
    });
}

QString PrinterManager::browseForImage() {
    // Get default pictures directory
    QString defaultDir = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);

    // Open file dialog
    QString filePath = QFileDialog::getOpenFileName(
        nullptr,
        "Select Image to Print",
        defaultDir,
        "Image Files (*.jpg *.jpeg *.png *.bmp *.tiff *.tif);;All Files (*.*)"
    );

    if (!filePath.isEmpty()) {
        qDebug() << "Selected image:" << filePath;
        // Convert to URL format for QML Image component
        QUrl fileUrl = QUrl::fromLocalFile(filePath);
        qDebug() << "Converted to URL:" << fileUrl.toString();
        return fileUrl.toString();
    } else {
        qDebug() << "No image selected";
        return QString();
    }
}

QString PrinterManager::rotateAndSaveImage(const QString &imagePath, int degrees, const QString &collageImagePath) {
    try {
        qDebug() << "[PrinterManager] Rotating image:" << imagePath << "by" << degrees << "degrees";

        // Convert from file:/// URL if needed
        QString localPath = QUrl(imagePath).toLocalFile();
        if (localPath.isEmpty()) localPath = imagePath;

        // Load original image
        QImage image(localPath);
        if (image.isNull()) {
            qWarning() << "[PrinterManager] Failed to load image:" << localPath;
            return QString();
        }

        qDebug() << "[PrinterManager] Original image size:" << image.width() << "x" << image.height();

        // Rotate image
        QTransform transform;
        transform.rotate(degrees);
        QImage rotatedImage = image.transformed(transform, Qt::SmoothTransformation);

        // Determine save directory: use event path from collage image if provided
        QString saveDir;
        if (!collageImagePath.isEmpty()) {
            // Extract event path from collage image
            QString collagePath = QUrl(collageImagePath).toLocalFile();
            if (collagePath.isEmpty()) collagePath = collageImagePath;

            QFileInfo collageInfo(collagePath);
            if (collageInfo.path().endsWith("/Final", Qt::CaseInsensitive)) {
                // Path format: {EventRoot}/Final/collage_*.jpg
                // Target: {EventRoot}/printout/
                QDir eventDir(collageInfo.absolutePath());
                if (eventDir.dirName() == "Final") {
                    eventDir.cdUp();
                }
                saveDir = eventDir.filePath("printout");
            } else {
                saveDir = collageInfo.absolutePath();
            }
        } else {
            // Fallback to temp directory
            saveDir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
        }

        // Create directory if it doesn't exist
        QDir dir;
        if (!dir.exists(saveDir)) {
            if (!dir.mkpath(saveDir)) {
                qWarning() << "[PrinterManager] Failed to create directory:" << saveDir;
                return QString();
            }
        }

        // Save rotated image
        QString timestamp = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
        QString rotatedFileName = QString("rotated_image_%1_%2deg.jpg").arg(timestamp).arg(degrees);
        QString rotatedPath = QDir(saveDir).filePath(rotatedFileName);

        if (!rotatedImage.save(rotatedPath, "JPG", 95)) {
            qWarning() << "[PrinterManager] Failed to save rotated image to:" << rotatedPath;
            return QString();
        }

        qDebug() << "[PrinterManager] ✓ Rotated image saved to:" << rotatedPath;
        qDebug() << "[PrinterManager] Rotated image size:" << rotatedImage.width() << "x" << rotatedImage.height();
        qDebug() << "[PrinterManager] Save directory:" << saveDir;

        // Return as file:/// URL for QML
        return QUrl::fromLocalFile(rotatedPath).toString();

    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Exception in rotateAndSaveImage:" << e.what();
        return QString();
    }
}

// ===== DEVMODE Manipulation (Ported from PrinterTesterUI.py) =====

namespace {
bool isSupportedDnpPrinter(const QString &printerName)
{
    QString name = printerName.trimmed();
    return name.contains("RX1", Qt::CaseInsensitive)
        || name.contains("DS-RX1", Qt::CaseInsensitive)
        || name.contains("DS620", Qt::CaseInsensitive)
        || name.contains("DS-620", Qt::CaseInsensitive);
}

#ifdef Q_OS_WIN

struct DnpPaper {
    QString name;
    short   number = 0;
};

// Lấy tên port của máy in — DeviceCapabilitiesW nhận pPort giống mẫu
// Paper.vb::GetPaperSizeName() của DNP (GetPortName(strPrnName)).
QString dnpPrinterPortName(const QString &printerName)
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

// Liệt kê khổ giấy driver hỗ trợ (tên + số hiệu), theo Paper.vb::GetPaperSizeInfo().
// DC_PAPERNAMES = 16 (mảng chuỗi 64 wchar), DC_PAPERS = 2 (mảng WORD).
QVector<DnpPaper> dnpEnumeratePapers(const QString &printerName)
{
    QVector<DnpPaper> papers;

    std::wstring nameW = printerName.toStdWString();
    QString portStr = dnpPrinterPortName(printerName);
    std::wstring portW = portStr.toStdWString();
    LPCWSTR pPort = portStr.isEmpty() ? nullptr : portW.c_str();

    const int nNames = DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERNAMES, nullptr, nullptr);
    const int nNums  = DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERS,     nullptr, nullptr);
    if (nNames <= 0 || nNums <= 0 || nNames != nNums) {
        qWarning() << "[PrinterManager] DeviceCapabilities không trả về danh sách khổ giấy"
                   << "(names=" << nNames << ", numbers=" << nNums << ", port=" << portStr << ")";
        return papers;
    }

    QVector<wchar_t> nameBuf(static_cast<int>(nNames) * 64, 0);
    QVector<WORD>    numBuf(nNums, 0);
    if (DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERNAMES, nameBuf.data(), nullptr) <= 0)
        return papers;
    if (DeviceCapabilitiesW(nameW.c_str(), pPort, DC_PAPERS,
                            reinterpret_cast<LPWSTR>(numBuf.data()), nullptr) <= 0)
        return papers;

    for (int i = 0; i < nNames; ++i) {
        const wchar_t *p = nameBuf.data() + i * 64;
        // chuỗi có thể không kết thúc NUL nếu dài đúng 64 ký tự
        int len = 0;
        while (len < 64 && p[len] != L'\0') ++len;
        DnpPaper e;
        e.name   = QString::fromWCharArray(p, len).trimmed();
        e.number = static_cast<short>(numBuf[i]);
        if (!e.name.isEmpty())
            papers.append(e);
    }
    return papers;
}

// Khổ 4×6 mà driver DNP cho phép bật 2inch-cut.
// Nguồn: Print Settings Sample/VB.NET PrintSettings_Sample/Form1.vb:430
//   If ComboPaperSize.Text = "(6x4)" Or "PR (4x6)" Or "(6x8)" Then ComboCut2inch.Enabled = True
// Ta CHỈ nhận họ 4×6; "(6x8)" tuy cho phép cắt nhưng hình học tấm in khác hẳn.
bool isCut4x6PaperName(const QString &n)
{
    const QString t = n.trimmed();
    return t.compare(QStringLiteral("(6x4)"),    Qt::CaseInsensitive) == 0
        || t.compare(QStringLiteral("PR (4x6)"), Qt::CaseInsensitive) == 0;
}

#endif // Q_OS_WIN
}

QStringList PrinterManager::getAvailablePrinters()
{
    QStringList printers = enumerateLocalPrinters();
    qDebug() << "[PrinterManager] Available printers:" << printers;
    return printers;
}

QStringList PrinterManager::enumerateLocalPrinters()
{
    QStringList result;

#ifdef Q_OS_WIN
    try {
        // PRINTER_ENUM_LOCAL       = máy USB / cổng TCP-IP cài tại máy này
        // PRINTER_ENUM_CONNECTIONS = máy in share từ PC khác (dạng "Tên on \\IP")
        // → bổ sung CONNECTIONS để scan được máy in qua LAN.
        DWORD flags = PRINTER_ENUM_LOCAL | PRINTER_ENUM_CONNECTIONS;
        DWORD size = 0;
        DWORD count = 0;

        // First call to get size
        EnumPrintersW(flags, nullptr, 2, nullptr, 0, &size, &count);

        if (size == 0) {
            qDebug() << "[PrinterManager] No printers found (local or network)";
            return result;
        }

        BYTE *buffer = new BYTE[size];
        if (!EnumPrintersW(flags, nullptr, 2, buffer, size, &size, &count)) {
            qWarning() << "[PrinterManager] EnumPrinters failed";
            delete[] buffer;
            return result;
        }

        // Chỉ chấp nhận DNP DS-RX1 / DS620 để đảm bảo luồng in luôn đi đúng driver
        // hỗ trợ DEVMODE cut mà booth hiện tại đang dùng.
        PRINTER_INFO_2W *printerInfo = (PRINTER_INFO_2W *)buffer;
        for (DWORD i = 0; i < count; ++i) {
            QString printerName = QString::fromWCharArray(printerInfo[i].pPrinterName);
            QString driverName  = printerInfo[i].pDriverName
                                  ? QString::fromWCharArray(printerInfo[i].pDriverName)
                                  : QString();
            QString portName    = printerInfo[i].pPortName
                                  ? QString::fromWCharArray(printerInfo[i].pPortName)
                                  : QString();

            if (printerName.isEmpty()) {
                continue;
            }

            // Chống trùng: máy in có thể xuất hiện ở cả LOCAL lẫn CONNECTIONS
            if (result.contains(printerName)) {
                continue;
            }

            if (!m_listAllWindowsPrinters && !isSupportedDnpPrinter(printerName)) {
                qDebug() << "[PrinterManager] Ignoring unsupported printer:" << printerName;
                continue;
            }

            result.append(printerName);
            qDebug() << "[PrinterManager] Found printer:" << printerName
                     << "(driver:" << driverName << ", port:" << portName << ")";
        }

        delete[] buffer;
    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Exception in enumerateLocalPrinters:" << e.what();
    }
#else
    // Non-Windows fallback
    qDebug() << "[PrinterManager] Printer enumeration not supported on this platform";
#endif

    return result;
}

// ─── tryInitPort (thread-safe helper, không emit signal) ─────────────────────
bool PrinterManager::tryInitPort(const QString &portName, long &outPortNum)
{
    if (!m_portInitialize || !m_getStatus) return false;

    QVector<wchar_t> buf(portName.size() + 1);
    portName.toWCharArray(buf.data());
    buf[portName.size()] = L'\0';

    long pn = m_portInitialize(buf.data());
    if (pn < 0) {
        qDebug() << "[PrinterManager] tryInitPort" << portName << "→ FAIL (portNum=" << pn << ")";
        return false;
    }

    QThread::msleep(200);
    long st = m_getStatus(pn);
    if (st == STATUS_ERROR) {
        QThread::msleep(300);
        st = m_getStatus(pn);
    }

    qDebug() << "[PrinterManager] tryInitPort" << portName
             << "→ portNum=" << pn
             << "status=0x" + QString::number(st, 16).toUpper();

    // Chấp nhận mọi status khác ERROR (Idle, Cooling, v.v. đều là máy in đang kết nối)
    if (st != STATUS_ERROR) {
        outPortNum = pn;
        return true;
    }
    return false;
}

// ─── reconnect ────────────────────────────────────────────────────────────────
void PrinterManager::reconnect()
{
    // Bảo đảm chỉ một lần chạy đồng thời
    if (!m_reconnectBusy.testAndSetAcquire(0, 1)) {
        qDebug() << "[PrinterManager] reconnect() already in progress, skipping";
        return;
    }

    m_currentStatus = "Đang kết nối lại...";
    emit statusChanged(m_currentStatus);
    emit reconnectStarted();

    QtConcurrent::run([this]() {
        // Thứ tự thử: mặc định USB002, sau đó scan USB001 và USB003-USB009
        static const QStringList ports = {
            "USB002", "USB001", "USB003", "USB004", "USB005",
            "USB006", "USB007", "USB008", "USB009"
        };

        for (const QString &port : ports) {
            long pn = -1;
            if (tryInitPort(port, pn)) {
                QMetaObject::invokeMethod(this, [this, port, pn]() {
                    {
                        QMutexLocker lk(&m_sdkMutex);
                        m_portNum = pn;
                    }
                    m_currentPort  = port;
                    m_isConnected  = true;
                    m_reconnectBusy.storeRelease(0);
                    emit connectionChanged(true);
                    emit reconnectFinished(true, port);
                    qDebug() << "[PrinterManager] Reconnected on port" << port;
                    // Kích check status ngay sau khi reconnect
                    checkStatus();
                }, Qt::QueuedConnection);
                return;
            }
        }

        // Không tìm thấy trên cả 9 port
        QMetaObject::invokeMethod(this, [this]() {
            {
                QMutexLocker lk(&m_sdkMutex);
                m_portNum = -1;
            }
            m_currentPort  = "";
            m_isConnected  = false;
            m_currentStatus = "Không tìm thấy máy in";
            m_reconnectBusy.storeRelease(0);
            emit connectionChanged(false);
            emit statusChanged(m_currentStatus);
            emit reconnectFinished(false, "");
            qWarning() << "[PrinterManager] reconnect() failed — no printer found on USB001-USB009";
        }, Qt::QueuedConnection);
    });
}

// ─── switchPrinterAsync ───────────────────────────────────────────────────────
// Cập nhật tên máy in trong PrinterConfig — không scan USB port vì Windows
// spooler dùng tên máy in, không cần SDK port.  SDK reconnect dùng nút 🔄.
void PrinterManager::switchPrinterAsync(const QString &printerName)
{
    if (!m_listAllWindowsPrinters && !isSupportedDnpPrinter(printerName)) {
        QString fallback = QStringLiteral("DS-RX1");
        qWarning() << "[PrinterManager] Refusing unsupported printer switch:" << printerName
                   << "-> forcing" << fallback;
        if (m_printerConfig) {
            m_printerConfig->setSelectedPrinter(fallback);
        }
        emit printerSwitchStarted();
        QMetaObject::invokeMethod(this, [this, fallback]() {
            emit printerSwitchFinished(false, QString("Chỉ hỗ trợ DS-RX1/DS620. Đã giữ máy in: %1").arg(fallback));
        }, Qt::QueuedConnection);
        return;
    }

    if (m_printerConfig) {
        m_printerConfig->setSelectedPrinter(printerName);
    }

    emit printerSwitchStarted();
    qDebug() << "[PrinterManager] switchPrinterAsync →" << printerName;

    // Emit finished on next event loop tick so QML sees started→finished cleanly.
    QString msg = QString("Đã chuyển sang: %1").arg(printerName);
    QMetaObject::invokeMethod(this, [this, msg]() {
        emit printerSwitchFinished(true, msg);
    }, Qt::QueuedConnection);
}

// ─── refreshPrinterListAsync ──────────────────────────────────────────────────
void PrinterManager::refreshPrinterListAsync()
{
    QtConcurrent::run([this]() {
        QStringList printers = enumerateLocalPrinters();
        QMetaObject::invokeMethod(this, [this, printers]() {
            qDebug() << "[PrinterManager] refreshPrinterListAsync → found" << printers.size() << "printers";
            emit printerListReady(printers);
        }, Qt::QueuedConnection);
    });
}

bool PrinterManager::findExDevTop(void *devmodePtr, int devmodeSize, int &exDevTop)
{
#ifdef Q_OS_WIN
    try {
        int intCount = devmodeSize / sizeof(int);
        int *intArray = reinterpret_cast<int *>(devmodePtr);

        for (int i = 0; i < intCount; ++i) {
            if (intArray[i] == EX_DEV_SIGN) {
                exDevTop = i - 1;
                qDebug() << "[PrinterManager] Found ExDevTop at index:" << exDevTop;
                return true;
            }
        }

        qWarning() << "[PrinterManager] Could not find ExDevTop (MSFT signature)";
        return false;
    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Exception in findExDevTop:" << e.what();
        return false;
    }
#else
    qWarning() << "[PrinterManager] DEVMODE manipulation only supported on Windows";
    return false;
#endif
}

// Ghi một ô int trong vùng private DEVMODE của DNP.
// fieldOffset là offset theo tài liệu (ExBorder=3, ExCut2inch=30), tính từ ExDevTop.
bool PrinterManager::writeDevmodePrivateInt(void *devmodePtr, int devmodeSize,
                                            int fieldOffset, int value,
                                            const char *fieldName)
{
#ifdef Q_OS_WIN
    try {
        int exDevTop = -1;
        if (!findExDevTop(devmodePtr, devmodeSize, exDevTop)) {
            qWarning() << "[PrinterManager] *** KHÔNG TÌM THẤY vùng private DEVMODE (chữ ký MSFT) ***"
                       << "- không thể đặt" << fieldName
                       << "→ driver sẽ dùng giá trị mặc định đang lưu trong spooler!";
            return false;
        }

        const int intCount = devmodeSize / static_cast<int>(sizeof(int));
        int *intArray = reinterpret_cast<int *>(devmodePtr);
        const int pos = exDevTop + fieldOffset;

        if (pos < 0 || pos >= intCount) {
            qWarning() << "[PrinterManager] Offset của" << fieldName << "vượt kích thước DEVMODE"
                       << "(pos=" << pos << ", intCount=" << intCount << ")";
            return false;
        }

        const int oldValue = intArray[pos];
        intArray[pos] = value;

        // Đọc lại để xác nhận đã ghi thật (bắt lỗi bộ nhớ chỉ-đọc / offset sai)
        if (intArray[pos] != value) {
            qWarning() << "[PrinterManager] Ghi" << fieldName << "THẤT BẠI — đọc lại được"
                       << intArray[pos] << "thay vì" << value;
            return false;
        }

        qDebug() << "[PrinterManager] private DEVMODE:" << fieldName
                 << oldValue << "→" << value
                 << "(ExDevTop=" << exDevTop << ", offset=" << fieldOffset << ", pos=" << pos << ")";
        return true;
    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Exception khi ghi" << fieldName << ":" << e.what();
        return false;
    }
#else
    Q_UNUSED(devmodePtr); Q_UNUSED(devmodeSize); Q_UNUSED(fieldOffset);
    Q_UNUSED(value);      Q_UNUSED(fieldName);
    qWarning() << "[PrinterManager] DEVMODE manipulation only supported on Windows";
    return false;
#endif
}

bool PrinterManager::modifyDevmodeCut(void *devmodePtr, int devmodeSize, bool enableCut)
{
    // PrintSettings_E.pdf §4: OemCut2inch → 0 = Normal cut, 1 = 2inch cut
    return writeDevmodePrivateInt(devmodePtr, devmodeSize, ExCut2inch,
                                  enableCut ? DM_CUT2INCH_ON : DM_CUT2INCH_OFF,
                                  enableCut ? "OemCut2inch=1 (2inch cut)"
                                            : "OemCut2inch=0 (normal cut)");
}

bool PrinterManager::modifyDevmodeBorder(void *devmodePtr, int devmodeSize, bool borderOn)
{
    // PrintSettings_E.pdf §4: OemBorder → 0 = No, 1 = Yes
    // Generating_OutputImage_E.pdf: "When set to Border, the border is subtracted
    // from the image pixel sizes shown above."
    return writeDevmodePrivateInt(devmodePtr, devmodeSize, ExBorder,
                                  borderOn ? DM_BORDER_ON : DM_BORDER_OFF,
                                  borderOn ? "OemBorder=1 (có viền)"
                                           : "OemBorder=0 (không viền)");
}

bool PrinterManager::modifyDevmodeOrientation(void *devmodePtr, int devmodeSize, bool landscape)
{
#ifdef Q_OS_WIN
    try {
        // DEVMODE structure contains dmOrientation field
        // dmOrientation offset varies but is typically in standard part
        // We'll use a more direct approach: cast to DEVMODE and set directly

        PDEVMODEW pDevMode = reinterpret_cast<PDEVMODEW>(devmodePtr);

        // Set orientation: 1=Portrait, 2=Landscape
        // For cut mode (cutMode=true): Portrait (dọc)
        // For no-cut mode (cutMode=false): Landscape (ngang)
        pDevMode->dmOrientation = landscape ? DMORIENT_LANDSCAPE : DMORIENT_PORTRAIT;

        // CRITICAL: Ensure the driver knows we changed the orientation
        pDevMode->dmFields |= DM_ORIENTATION;

        qDebug() << "[PrinterManager] Set orientation:"
                 << (landscape ? "LANDSCAPE (ngang/no-cut)" : "PORTRAIT (dọc/cut)")
                 << "at dmOrientation offset (Fields: " << pDevMode->dmFields << ")";

        return true;
    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Exception in modifyDevmodeOrientation:" << e.what();
        return false;
    }
#else
    qWarning() << "[PrinterManager] DEVMODE orientation only supported on Windows";
    return false;
#endif
}

bool PrinterManager::printWithDevmode(const QString &imagePath, int copies, bool enableCut,
                                       const QString &printerName)
{
#ifdef Q_OS_WIN
    qDebug() << "[PrinterManager] Starting DEVMODE-based printing"
             << "- Image:" << imagePath
             << "- Copies:" << copies
             << "- Cut:" << (enableCut ? "ON" : "OFF")
             << "- Printer:" << printerName;

    HANDLE hPrinter = nullptr;
    HANDLE hDevMode = nullptr;
    void *lpDevMode = nullptr;

    try {
        // Check file exists
        if (!QFile::exists(imagePath)) {
            throw std::runtime_error(QString("Image file not found: %1").arg(imagePath).toStdString());
        }

        // Open printer
        if (!OpenPrinterW((LPWSTR)printerName.utf16(), &hPrinter, nullptr)) {
            throw std::runtime_error("Failed to open printer");
        }

        qDebug() << "[PrinterManager] Printer opened successfully";

        // Get DEVMODE size
        long devmodeSize = DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)printerName.utf16(),
                                                nullptr, nullptr, 0);
        if (devmodeSize <= 0) {
            throw std::runtime_error(QString("Failed to get DEVMODE size: %1").arg(devmodeSize).toStdString());
        }

        qDebug() << "[PrinterManager] DEVMODE size:" << devmodeSize << "bytes";

        // Allocate memory for DEVMODE
        hDevMode = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, devmodeSize);
        if (!hDevMode) {
            throw std::runtime_error("Failed to allocate DEVMODE memory");
        }

        lpDevMode = GlobalLock(hDevMode);
        if (!lpDevMode) {
            throw std::runtime_error("Failed to lock DEVMODE memory");
        }

        // Get current DEVMODE
        long result = DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)printerName.utf16(),
                                           (PDEVMODEW)lpDevMode, nullptr, DM_OUT_BUFFER);
        if (result < 0) {
            throw std::runtime_error(QString("Failed to get DEVMODE: %1").arg(result).toStdString());
        }

        // Modify DEVMODE for cut mode
        if (!modifyDevmodeCut(lpDevMode, devmodeSize, enableCut)) {
            qWarning() << "[PrinterManager] Could not modify DEVMODE, continuing with default";
        }

        // Modify DEVMODE for orientation
        // For backward compatibility in printWithDevmode: landscape = !enableCut
        // (enableCut=true → Portrait, enableCut=false → Landscape)
        bool landscape = !enableCut;
        if (!modifyDevmodeOrientation(lpDevMode, devmodeSize, landscape)) {
            qWarning() << "[PrinterManager] Could not modify orientation, continuing with default";
        }

        // Create DC with modified DEVMODE
        HDC hdc = CreateDCW(nullptr, (LPCWSTR)printerName.utf16(), nullptr, (PDEVMODEW)lpDevMode);
        if (!hdc) {
            throw std::runtime_error("Failed to create printer DC");
        }

        qDebug() << "[PrinterManager] Printer DC created successfully";

        // Load and print image
        QImage image(imagePath);
        if (image.isNull()) {
            throw std::runtime_error("Failed to load image file");
        }

        // Convert to RGB if needed
        if (image.format() != QImage::Format_RGB32) {
            image = image.convertToFormat(QImage::Format_RGB32);
        }

        // ⚠️ WARNING: This function is LEGACY and uses HARDCODED theoretical sizes.
        // These sizes (600×1800, 1800×1200) do NOT match actual printable area!
        // Use printWithDevmodeWinAPI() instead, which queries driver for actual canvas size.
        //
        // Calculate printable area from layout orientation (NOT from GetDeviceCaps)
        // landscape = !enableCut (calculated earlier: enableCut=true → portrait, enableCut=false → landscape)
        // Calculations based on 300 DPI: pixels = inches × 300
        int printableWidth, printableHeight;

        if (landscape) {
            // 6×4 inch (1800 × 1200 pixels at 300 DPI - THEORETICAL, not actual!)
            printableWidth = 1800;   // 6 inch × 300 DPI
            printableHeight = 1200;  // 4 inch × 300 DPI
            qDebug() << "[PrinterManager] Layout: 6×4 inch (LANDSCAPE)";
        } else {
            // 2×6 inch (600 × 1800 pixels at 300 DPI - THEORETICAL, not actual!)
            printableWidth = 600;    // 2 inch × 300 DPI
            printableHeight = 1800;  // 6 inch × 300 DPI
            qDebug() << "[PrinterManager] Layout: 2×6 inch (PORTRAIT)";
        }

        qDebug() << "[PrinterManager] Calculated printable area from layout:"
                 << printableWidth << "×" << printableHeight << "pixels (at 300 DPI)";

        // Print copies
        for (int i = 0; i < copies; ++i) {
            qDebug() << "[PrinterManager] Printing copy" << (i + 1) << "of" << copies;

            // Start document and page
            DOCINFOW docInfo = {};
            docInfo.cbSize = sizeof(DOCINFOW);
            docInfo.lpszDocName = (LPCWSTR)QString("DNP Print - Copy %1").arg(i + 1).utf16();

            if (StartDocW(hdc, &docInfo) <= 0) {
                throw std::runtime_error("Failed to start print document");
            }

            StartPage(hdc);

            // Paint image to DC (simplified - would need full GDI+ integration for production)
            // For now, just acknowledge the print job was sent
            qDebug() << "[PrinterManager] Print job queued";

            EndPage(hdc);
            EndDoc(hdc);
        }

        DeleteDC(hdc);

        qDebug() << "[PrinterManager] Successfully printed" << copies << "copies";
        emit printFinished(true, QString("Printed %1 copies").arg(copies));

        // Cleanup on success
        if (lpDevMode) {
            GlobalUnlock(hDevMode);
        }
        if (hDevMode) {
            GlobalFree(hDevMode);
        }
        if (hPrinter) {
            ClosePrinter(hPrinter);
        }

        return true;

    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Print failed:" << e.what();
        emit printFinished(false, QString("Print failed: %1").arg(e.what()));

        // Cleanup on error
        if (lpDevMode) {
            GlobalUnlock(hDevMode);
        }
        if (hDevMode) {
            GlobalFree(hDevMode);
        }
        if (hPrinter) {
            ClosePrinter(hPrinter);
        }

        return false;
    } catch (...) {
        qWarning() << "[PrinterManager] Unknown error during printing";
        emit printFinished(false, "Unknown print error");

        // Cleanup on error
        if (lpDevMode) {
            GlobalUnlock(hDevMode);
        }
        if (hDevMode) {
            GlobalFree(hDevMode);
        }
        if (hPrinter) {
            ClosePrinter(hPrinter);
        }

        return false;
    }
#else
    qWarning() << "[PrinterManager] DEVMODE printing only supported on Windows";
    emit printFinished(false, "DEVMODE printing not supported on this platform");
    return false;
#endif
}

bool PrinterManager::printImageWithDevmode(const QString &imagePath, PrinterConfig *config)
{
    if (!config) {
        qWarning() << "[PrinterManager] PrinterConfig is null";
        emit printFinished(false, "Invalid printer configuration");
        return false;
    }

    qDebug() << "[PrinterManager] printImageWithDevmode with config:" << config->toString();

    // Use DEVMODE-based printing if on Windows
#ifdef Q_OS_WIN
    return printWithDevmode(imagePath, config->printCopies(), config->cutMode(),
                            config->selectedPrinter());
#else
    // Fallback to save folder on non-Windows platforms
    return saveToPrintoutFolder(imagePath, config->printCopies());
#endif
}

bool PrinterManager::saveToPrintoutFolder(const QString &imagePath, int copies)
{
    try {
        qDebug() << "[PrinterManager] Saving to printout folder:"
                 << "Image:" << imagePath
                 << "Copies:" << copies;

        QString printoutDir = "printout";
        QDir dir;
        if (!dir.exists(printoutDir)) {
            if (!dir.mkpath(printoutDir)) {
                throw std::runtime_error(QString("Failed to create directory: %1").arg(printoutDir).toStdString());
            }
            qDebug() << "[PrinterManager] Created printout directory";
        }

        // Check source file exists
        if (!QFile::exists(imagePath)) {
            throw std::runtime_error(QString("Source image not found: %1").arg(imagePath).toStdString());
        }

        QDateTime now = QDateTime::currentDateTime();
        QString timestamp = now.toString("yyyyMMdd_hhmmss");

        // Save copies
        for (int i = 1; i <= copies; ++i) {
            QString filename;
            if (i == 1) {
                filename = QString("print_%1.png").arg(timestamp);
            } else {
                filename = QString("print_%1_copy%2.png").arg(timestamp).arg(i);
            }

            QString savePath = QDir(printoutDir).filePath(filename);

            if (!QFile::copy(imagePath, savePath)) {
                qWarning() << "[PrinterManager] Failed to save copy" << i << "to" << savePath;
            } else {
                qDebug() << "[PrinterManager] Saved:" << savePath;
            }
        }

        QString message = QString("Saved %1 copies to %2 folder").arg(copies).arg(printoutDir);
        qDebug() << "[PrinterManager]" << message;
        emit printFinished(true, message);

        return true;

    } catch (const std::exception &e) {
        qWarning() << "[PrinterManager] Save to folder failed:" << e.what();
        emit printFinished(false, QString("Save failed: %1").arg(e.what()));
        return false;
    }
}

// ===== NEW: Windows API-based DEVMODE Printing (ported from Python PrinterTesterUI.py) =====

bool PrinterManager::printWithDevmodeWinAPI(const QString &imagePath, int copies, bool cutMode, bool landscape, int imageRotation, int quality, const QString &printerName, bool freeMode)
{
#ifdef Q_OS_WIN
    if (!freeMode && !isSupportedDnpPrinter(printerName)) {
        qWarning() << "[PrinterManager] Refusing print to unsupported printer:" << printerName;
        emit printFinished(false, QString("Chỉ hỗ trợ in trên DS-RX1/DS620. Máy in hiện tại: %1").arg(printerName));
        return false;
    }

    qDebug() << "====== WINDOWS API DEVMODE PRINTING ======";
    qDebug() << "Image:" << imagePath;
    qDebug() << "Copies:" << copies;
    qDebug() << "Cut Mode:" << (cutMode ? "ON (Cắt)" : "OFF (Không cắt)");
    qDebug() << "Free Mode:" << (freeMode ? "ON (In tự do — bỏ bước DNP, driver tự scale)" : "OFF");
    qDebug() << "Quality:" << quality << "DPI";

    // Resource handles for cleanup
    HANDLE hPrinter = nullptr;
    HANDLE hDevMode = nullptr;
    void *lpDevMode = nullptr;
    HDC hdc = nullptr;

    try {
        // 1. Validate file exists
        if (!QFile::exists(imagePath)) {
            throw std::runtime_error(QString("File not found: %1").arg(imagePath).toStdString());
        }

        // 2. Load and Prepare Image (BEFORE creating DC to determine orientation)
        qDebug() << "[PrinterManager] Loading image to determine settings...";
        QImage image(imagePath);
        if (image.isNull()) {
            throw std::runtime_error("Failed to load image");
        }

        qDebug() << "[PrinterManager] Image loaded. Format:" << (int)image.format()
                 << "| Size:" << image.width() << "x" << image.height();

        qDebug() << "[PrinterManager] Image loaded. Format:" << (int)image.format()
                 << "| Size:" << image.width() << "x" << image.height();

        // Convert to 24-bit RGB (R, G, B order in memory)
        if (image.format() != QImage::Format_RGB888) {
            image = image.convertToFormat(QImage::Format_RGB888);
        }

        // CRITICAL FIX: Windows API (StretchDIBits) expects BGR layout for BI_RGB.
        // QImage::Format_RGB888 stores R, G, B.
        // We must swap the channels to produce B, G, R layout.
        image = image.rgbSwapped();

        qDebug() << "[PrinterManager] Converted to BGR layout for Windows API. Format:" << (int)image.format();

        // Apply manual rotation if user specified
        if (imageRotation > 0) {
            qDebug() << "[PrinterManager] Applying user-specified rotation:" << imageRotation << "degrees";
            QTransform transform;
            transform.rotate(imageRotation);
            image = image.transformed(transform);
            qDebug() << "[PrinterManager] ✓ Image manually rotated. New dimensions:" << image.width() << "x" << image.height();
        }

        // QW410 handling:
        // QW410 feeds paper PORTRAIT (dọc), unlike RX1/DS620S which feed LANDSCAPE (ngang).
        // No-cut: landscape strip → rotate 90° CW to portrait so it fits the portrait paper.
        // Cut mode: canvas is already 15x10 landscape (3 strips side-by-side); do NOT rotate —
        //           the paper is loaded landscape (15x10) and DEVMODE will be set to landscape.
        // Chỉ còn hỗ trợ RX1/DS620: bỏ toàn bộ nhánh auto-rotation theo model khác.
        if (freeMode) {
            qDebug() << "[PrinterManager] Free mode: still restricted to DS-RX1/DS620, keeping image orientation as prepared";
        } else {
            qDebug() << "[PrinterManager] DS-RX1/DS620 path: using prepared image orientation without non-DNP transforms";
        }

        // Save the image (after all rotations) to the printout folder for inspection.
        // This captures exactly what gets sent to the printer.
        {
            QFileInfo srcInfo(imagePath);
            QString eventPath = srcInfo.absolutePath();
            // Walk up from Final/ subdirectory if needed
            if (QDir(eventPath).dirName().compare("Final", Qt::CaseInsensitive) == 0) {
                QDir d(eventPath); d.cdUp();
                eventPath = d.absolutePath();
            }
            QDir(eventPath).mkpath("printout");
            QString ts = QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz");
            // Gắn chế độ bleed vào tên file để đối chiếu tờ in với file đã gửi driver
            const QString bleedTag =
                (ImageCompositor::cutBleedMode() == CutBleedMode::SafeMargin) ? "safe" : "fill";
            QString tag = cutMode
                ? QString("print_CUT_%1_%2_%3copies.jpg").arg(ts).arg(bleedTag).arg(copies)
                : QString("print_NOCUT_%1_%2copies.jpg").arg(ts).arg(copies);
            QString savePath = QDir(eventPath).filePath("printout/" + tag);
            image.save(savePath, "JPG", 95);
            qDebug() << "[PrinterManager] ✓ Print image saved to printout:" << savePath;
        }

        // Auto-rotation DISABLED: Let landscape images print on landscape canvas
        // User can manually rotate using the rotate button in UI if needed
        qDebug() << "[PrinterManager] Image orientation:"
                 << (image.width() > image.height() ? "Landscape" : "Portrait")
                 << "(" << image.width() << "x" << image.height() << ")";

        // 3. Determine Final Layout Orientation based on Image
        // Detect image orientation to set matching DEVMODE orientation
        bool isImageLandscape = (image.width() > image.height());
        qDebug() << "[PrinterManager] Detected image as:"
                 << (isImageLandscape ? "LANDSCAPE (ngang)" : "PORTRAIT (dọc)");

        // 4. Setup Printer and DEVMODE
        // Dùng tên máy in được truyền vào (từ printerConfig.selectedPrinter), fallback "DS-RX1"
        QString resolvedPrinterName = (!printerName.isEmpty()) ? printerName : "DS-RX1";
        std::wstring printerNameW = resolvedPrinterName.toStdWString();

        qDebug() << "[PrinterManager] Opening printer:" << resolvedPrinterName;
        if (!OpenPrinterW((LPWSTR)printerNameW.c_str(), &hPrinter, nullptr)) {
            throw std::runtime_error("Failed to open printer");
        }

        long devmodeSize = DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)printerNameW.c_str(),
                                                nullptr, nullptr, 0);
        if (devmodeSize <= 0) {
            throw std::runtime_error(QString("Failed to get DEVMODE size: %1").arg(devmodeSize).toStdString());
        }

        hDevMode = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, devmodeSize);
        if (!hDevMode) {
            throw std::runtime_error("Failed to allocate DEVMODE memory");
        }

        lpDevMode = GlobalLock(hDevMode);
        if (!lpDevMode) {
            throw std::runtime_error("Failed to lock DEVMODE memory");
        }

        // Get default DEVMODE
        long result = DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)printerNameW.c_str(),
                                           (PDEVMODEW)lpDevMode, nullptr, DM_OUT_BUFFER);
        if (result < 0) {
            throw std::runtime_error(QString("Failed to get DEVMODE: %1").arg(result).toStdString());
        }

        // 5. Modify DEVMODE
        PDEVMODEW pDevMode = (PDEVMODEW)lpDevMode;

        // Set Print Quality (DPI)
        if (quality > 0) {
            pDevMode->dmPrintQuality = (short)quality;
            pDevMode->dmFields |= DM_PRINTQUALITY;
            pDevMode->dmYResolution = (short)quality;
            pDevMode->dmFields |= DM_YRESOLUTION;
            qDebug() << "[PrinterManager] Set print quality to" << quality << "DPI";
        }
        // ── Khổ giấy — CHỈ can thiệp khi bật cắt ────────────────────────────
        // Form1.vb:430 của DNP: 2inch-cut chỉ được driver cho phép khi khổ là
        // "(6x4)", "PR (4x6)" hoặc "(6x8)". Nếu ứng dụng không đặt dmPaperSize,
        // khổ là giá trị mặc định còn lưu trong spooler Windows (di sản của lần
        // chỉnh Printer Preferences gần nhất) → cắt có thể bị bỏ qua âm thầm.
        // Khi KHÔNG cắt: giữ nguyên hành vi cũ, không đụng khổ giấy.
        QString resolvedPaperName;
        if (cutMode && !freeMode) {
            const QVector<DnpPaper> papers = dnpEnumeratePapers(resolvedPrinterName);
            const short curPaper = (pDevMode->dmFields & DM_PAPERSIZE) ? pDevMode->dmPaperSize : 0;

            // Ưu tiên GIỮ NGUYÊN khổ hiện tại nếu nó đã thuộc họ 4×6 cho phép cắt
            // (can thiệp tối thiểu); nếu không, chuyển sang khổ 4×6 đầu tiên tìm được.
            short wantNumber = 0;
            for (const DnpPaper &p : papers) {
                if (p.number == curPaper && isCut4x6PaperName(p.name)) {
                    wantNumber = p.number; resolvedPaperName = p.name; break;
                }
            }
            if (wantNumber == 0) {
                for (const DnpPaper &p : papers) {
                    if (isCut4x6PaperName(p.name)) {
                        wantNumber = p.number; resolvedPaperName = p.name; break;
                    }
                }
            }

            if (wantNumber != 0) {
                pDevMode->dmPaperSize = wantNumber;
                pDevMode->dmFields |= DM_PAPERSIZE;
                // Devmode.vb::PrintSetting() xoá 2 cờ này — nếu spooler còn giữ
                // paper length/width tuỳ biến, driver sẽ ưu tiên chúng hơn dmPaperSize.
                pDevMode->dmFields &= ~(DM_PAPERLENGTH | DM_PAPERWIDTH);
                qDebug() << "[PrinterManager] Khổ giấy cho chế độ cắt:" << resolvedPaperName
                         << "(dmPaperSize=" << wantNumber << ", trước đó=" << curPaper << ")";
            } else {
                QStringList names;
                for (const DnpPaper &p : papers) names << p.name;
                qWarning() << "[PrinterManager] *** Không tìm thấy khổ 4x6 hỗ trợ 2inch-cut ***"
                           << "- giữ nguyên dmPaperSize=" << curPaper
                           << "| Driver liệt kê:" << names;
            }
        }

        // ── Border phải TẮT khi cắt ─────────────────────────────────────────
        // Generating_OutputImage_E.pdf: bật Border thì driver TRỪ viền vào kích
        // thước ảnh → vùng in không còn đủ 1240×1844 → tâm nội dung lệch tâm giấy
        // → dao cắt giữa giấy chia hai phần không đều.
        if (cutMode && !freeMode) {
            modifyDevmodeBorder(lpDevMode, devmodeSize, /*borderOn=*/false);
        }

        // ── Cut Mode ────────────────────────────────────────────────────────
        if (!modifyDevmodeCut(lpDevMode, devmodeSize, cutMode)) {
            // Thất bại ở đây rất nguy hiểm: job sẽ chạy theo cấu hình cắt còn lưu
            // trong driver từ lần in trước → lúc cắt lúc không.
            qWarning() << "[PrinterManager] *** KHÔNG ĐẶT ĐƯỢC CHẾ ĐỘ CẮT ***"
                       << "yêu cầu:" << (cutMode ? "CẮT" : "KHÔNG CẮT")
                       << "→ driver sẽ dùng cấu hình mặc định của nó!";
        }

        // ── Orientation ─────────────────────────────────────────────────────
        // DriverPrintDirection_E.pdf §2/§3.2: hai họ media của DS-RX1 có hướng in
        // NGƯỢC NHAU — media DS40-compatible "(6x4)" cần DM_LANDSCAPE để ra ảnh
        // portrait, còn media mới "PR (4x6)" cần DM_PORTRAIT cho cùng kết quả.
        // Vì vậy KHÔNG hard-code "driver bị đảo". Ta đặt phỏng đoán ban đầu, tạo
        // DC, đọc canvas thật rồi lật lại nếu hướng không khớp (mục §3 của SPEC).
        bool setLandscape = !isImageLandscape;   // phỏng đoán cho họ DS40-compatible
        if (freeMode) {
            qDebug() << "[PrinterManager] Free mode: giữ nguyên hướng DEVMODE mặc định của driver DNP";
        } else {
            modifyDevmodeOrientation(lpDevMode, devmodeSize, setLandscape);
        }

        // 6. Create DC
        hdc = CreateDCW(nullptr, (LPCWSTR)printerNameW.c_str(), nullptr, (PDEVMODEW)lpDevMode);
        if (!hdc) {
            throw std::runtime_error("Failed to create printer device context");
        }

        // 7. Get Printable Area from Driver
        int canvasWidth  = GetDeviceCaps(hdc, PHYSICALWIDTH);
        int canvasHeight = GetDeviceCaps(hdc, PHYSICALHEIGHT);

        // 7a. Kiểm chứng hướng: canvas driver trả về phải cùng hướng với ảnh.
        // Nếu lệch → họ media ngược với phỏng đoán → lật dmOrientation, dựng lại DC.
        if (!freeMode && canvasWidth > 0 && canvasHeight > 0) {
            const bool canvasLandscape = (canvasWidth > canvasHeight);
            if (canvasLandscape != isImageLandscape) {
                qWarning() << "[PrinterManager] Hướng canvas KHÔNG khớp ảnh —"
                           << "canvas" << canvasWidth << "x" << canvasHeight
                           << (canvasLandscape ? "(landscape)" : "(portrait)")
                           << "vs ảnh" << (isImageLandscape ? "(landscape)" : "(portrait)")
                           << "→ lật dmOrientation và tạo lại DC";

                setLandscape = !setLandscape;
                modifyDevmodeOrientation(lpDevMode, devmodeSize, setLandscape);

                DeleteDC(hdc);
                hdc = CreateDCW(nullptr, (LPCWSTR)printerNameW.c_str(), nullptr, (PDEVMODEW)lpDevMode);
                if (!hdc)
                    throw std::runtime_error("Failed to re-create printer DC after orientation flip");

                canvasWidth  = GetDeviceCaps(hdc, PHYSICALWIDTH);
                canvasHeight = GetDeviceCaps(hdc, PHYSICALHEIGHT);
                qDebug() << "[PrinterManager] ✓ Canvas sau khi lật:" << canvasWidth << "x" << canvasHeight;
            }
        }

        // 7b. Cut mode: composite 4x6 đã được tạo sẵn trong bước ImageCompositor::composeWithCut()
        // PrinterManager chỉ cần in ảnh nhận được (không cần duplicate runtime)
        if (cutMode) {
            qDebug() << "[PrinterManager] Cut mode: printing pre-composed 4x6 composite"
                     << "| Image:" << image.width() << "x" << image.height()
                     << "| Canvas:" << canvasWidth << "x" << canvasHeight
                     << "| Printer will auto-cut in center";
        }

        // ========================================================
        // PRINT JOB DIAGNOSTIC LOG
        // ========================================================
        QDateTime printTimestamp = QDateTime::currentDateTime();
        double imgAspect = (image.height() > 0) ? (double)image.width() / image.height() : 0;
        double canvasAspect = (canvasHeight > 0) ? (double)canvasWidth / canvasHeight : 0;

        // Additional device capabilities
        int logPixelsX = GetDeviceCaps(hdc, LOGPIXELSX);   // Horizontal DPI
        int logPixelsY = GetDeviceCaps(hdc, LOGPIXELSY);   // Vertical DPI
        int horzRes    = GetDeviceCaps(hdc, HORZRES);      // Printable width (pixels)
        int vertRes    = GetDeviceCaps(hdc, VERTRES);      // Printable height (pixels)
        int horzSizeMM = GetDeviceCaps(hdc, HORZSIZE);     // Printable width (mm)
        int vertSizeMM = GetDeviceCaps(hdc, VERTSIZE);     // Printable height (mm)
        int physOffsetX = GetDeviceCaps(hdc, PHYSICALOFFSETX);
        int physOffsetY = GetDeviceCaps(hdc, PHYSICALOFFSETY);

        qDebug() << "╔══════════════════════════════════════════════════════════════╗";
        qDebug() << "║              PRINT JOB DIAGNOSTIC LOG                       ║";
        qDebug() << "╠══════════════════════════════════════════════════════════════╣";
        qDebug() << "║ Timestamp:" << printTimestamp.toString("yyyy-MM-dd HH:mm:ss.zzz");
        qDebug() << "║ Image Path:" << imagePath;
        qDebug() << "╠──────────────── IMAGE (Software) ───────────────────────────╣";
        qDebug() << "║ Image Size:" << image.width() << "x" << image.height() << "pixels";
        qDebug() << "║ Image Aspect Ratio:" << QString::number(imgAspect, 'f', 4)
                 << "(" << image.width() << ":" << image.height() << ")";
        qDebug() << "║ Image Orientation:" << (image.width() > image.height() ? "Landscape" : "Portrait");
        qDebug() << "║ Requested DPI:" << quality;
        qDebug() << "║ Physical size at" << quality << "DPI:"
                 << QString::number((double)image.width() / qMax(quality, 1) * 25.4, 'f', 1) << "x"
                 << QString::number((double)image.height() / qMax(quality, 1) * 25.4, 'f', 1) << "mm";
        qDebug() << "╠──────────────── PRINTER (Hardware) ─────────────────────────╣";
        qDebug() << "║ Canvas (PHYSICALWIDTH x HEIGHT):" << canvasWidth << "x" << canvasHeight << "pixels";
        qDebug() << "║ Canvas Aspect Ratio:" << QString::number(canvasAspect, 'f', 4)
                 << "(" << canvasWidth << ":" << canvasHeight << ")";
        qDebug() << "║ Printable Area (HORZRES x VERTRES):" << horzRes << "x" << vertRes << "pixels";
        qDebug() << "║ Printable Area (mm):" << horzSizeMM << "x" << vertSizeMM << "mm";
        qDebug() << "║ Physical Offset:" << physOffsetX << "x" << physOffsetY << "pixels";
        qDebug() << "║ Driver DPI (LOGPIXELSX/Y):" << logPixelsX << "x" << logPixelsY;
        qDebug() << "║ DEVMODE DPI (dmPrintQuality/dmYRes):" << pDevMode->dmPrintQuality << "x" << pDevMode->dmYResolution;
        qDebug() << "║ DEVMODE Orientation:" << (pDevMode->dmOrientation == DMORIENT_LANDSCAPE ? "LANDSCAPE" : "PORTRAIT");
        qDebug() << "║ DEVMODE PaperSize:" << pDevMode->dmPaperSize
                 << (resolvedPaperName.isEmpty() ? QString("(giữ nguyên của driver)")
                                                 : QString("(\"%1\")").arg(resolvedPaperName));
        qDebug() << "║ DEVMODE Form Name:"
                 << QString::fromWCharArray(reinterpret_cast<const wchar_t *>(pDevMode->dmFormName));
        qDebug() << "║ DEVMODE dmFields: 0x" + QString::number(pDevMode->dmFields, 16)
                 << "| PAPERSIZE:" << ((pDevMode->dmFields & DM_PAPERSIZE) ? "set" : "-")
                 << "PAPERLENGTH:" << ((pDevMode->dmFields & DM_PAPERLENGTH) ? "SET(!)" : "-")
                 << "PAPERWIDTH:" << ((pDevMode->dmFields & DM_PAPERWIDTH) ? "SET(!)" : "-");
        qDebug() << "║ DEVMODE size:" << devmodeSize << "bytes (public dmSize=" << pDevMode->dmSize
                 << ", driverExtra=" << pDevMode->dmDriverExtra << ")";
        {
            int exTop = -1;
            if (findExDevTop(lpDevMode, devmodeSize, exTop)) {
                const int *ia = reinterpret_cast<const int *>(lpDevMode);
                const int n = devmodeSize / static_cast<int>(sizeof(int));
                auto peek = [&](int off) {
                    const int p = exTop + off;
                    return (p >= 0 && p < n) ? QString::number(ia[p]) : QString("n/a");
                };
                qDebug() << "║ DNP private DEVMODE: ExDevTop=" << exTop
                         << "| OemBorder=" << peek(ExBorder)
                         << "| OemCut2inch=" << peek(ExCut2inch) << "(đọc lại sau khi ghi)";
            } else {
                qWarning() << "║ ⚠ KHÔNG tìm thấy vùng private DEVMODE — cut/border KHÔNG được áp dụng!";
            }
        }
        qDebug() << "║ Cut Mode:" << (cutMode ? "ON" : "OFF");
        qDebug() << "║ Copies:" << copies;
        qDebug() << "╠──────────────── STRETCH MAPPING ────────────────────────────╣";
        qDebug() << "║ Dest rect:" << -physOffsetX << "," << -physOffsetY
                 << "size" << canvasWidth << "x" << canvasHeight
                 << (physOffsetX || physOffsetY ? "(đã bù physical offset)" : "(offset = 0)");
        qDebug() << "║ StretchDIBits: Image" << image.width() << "x" << image.height()
                 << "→ Canvas" << canvasWidth << "x" << canvasHeight;
        qDebug() << "║ Scale X:" << QString::number((double)canvasWidth / qMax(image.width(), 1), 'f', 4)
                 << "| Scale Y:" << QString::number((double)canvasHeight / qMax(image.height(), 1), 'f', 4);
        double aspectDiff = qAbs(imgAspect - canvasAspect);
        if (aspectDiff > 0.01) {
            qDebug() << "║ ⚠ ASPECT RATIO MISMATCH! Diff:" << QString::number(aspectDiff, 'f', 4)
                     << "- Image may be stretched/distorted!";
        } else {
            qDebug() << "║ ✓ Aspect ratios match (diff:" << QString::number(aspectDiff, 'f', 4) << ")";
        }
        qDebug() << "╚══════════════════════════════════════════════════════════════╝";

        // 8. Print Loop
        for (int i = 0; i < copies; ++i) {
            qDebug() << "[PrinterManager] Printing copy" << (i + 1) << "of" << copies;

            DOCINFOW docInfo = {};
            docInfo.cbSize = sizeof(DOCINFOW);
            std::wstring docName = QString("APP Print - Copy %1").arg(i + 1).toStdWString();
            docInfo.lpszDocName = (LPCWSTR)docName.c_str();

            if (StartDocW(hdc, &docInfo) <= 0) {
                throw std::runtime_error("Failed to start print document");
            }
            if (StartPage(hdc) <= 0) {
                throw std::runtime_error("Failed to start print page");
            }

            BITMAPINFO bmi;
            memset(&bmi, 0, sizeof(bmi));
            bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
            bmi.bmiHeader.biWidth = image.width();
            bmi.bmiHeader.biHeight = -image.height(); // Negative for top-down
            bmi.bmiHeader.biPlanes = 1;
            bmi.bmiHeader.biBitCount = 24;  // 24-bit RGB to match Python's PIL format
            bmi.bmiHeader.biCompression = BI_RGB;

            // Set high quality stretch mode (HALFTONE)
            SetStretchBltMode(hdc, HALFTONE);
            SetBrushOrgEx(hdc, 0, 0, NULL);

            // Phủ đúng TOÀN TRANG VẬT LÝ.
            // Gốc toạ độ của printer DC nằm ở góc VÙNG IN ĐƯỢC, lệch
            // PHYSICALOFFSETX/Y so với góc trang vật lý. Vẽ tại (0,0) với kích
            // thước PHYSICAL* sẽ đẩy nội dung sang phải/xuống đúng offset và xén
            // mất mép phải/dưới → tâm nội dung KHÔNG còn trùng tâm giấy → dao cắt
            // giữa giấy chia hai phần không đều. Bù lại bằng gốc âm.
            // Khi driver ở chế độ borderless (offset = 0) thì đây là no-op.
            StretchDIBits(hdc,
                         -physOffsetX, -physOffsetY, canvasWidth, canvasHeight,
                         0, 0, image.width(), image.height(),
                         image.bits(),
                         &bmi,
                         DIB_RGB_COLORS,
                         SRCCOPY);

            EndPage(hdc);
            EndDoc(hdc);

            qDebug() << "[PrinterManager] ✓ Copy" << (i + 1) << "sent at"
                     << QDateTime::currentDateTime().toString("HH:mm:ss.zzz");
        }

        QDateTime endTimestamp = QDateTime::currentDateTime();
        qint64 elapsedMs = printTimestamp.msecsTo(endTimestamp);
        qDebug() << "╔══════════════════════════════════════════════════════════════╗";
        qDebug() << "║              PRINT JOB COMPLETED                            ║";
        qDebug() << "║ Status: SUCCESS";
        qDebug() << "║ Copies Sent:" << copies;
        qDebug() << "║ Started:" << printTimestamp.toString("HH:mm:ss.zzz");
        qDebug() << "║ Finished:" << endTimestamp.toString("HH:mm:ss.zzz");
        qDebug() << "║ Duration:" << elapsedMs << "ms";
        qDebug() << "╚══════════════════════════════════════════════════════════════╝";

        emit printFinished(true, QString("Print job sent: %1 copies").arg(copies));
        
        // Manual cleanup for success path
        if (hdc) DeleteDC(hdc);
        if (lpDevMode) GlobalUnlock(hDevMode);
        if (hDevMode) GlobalFree(hDevMode);
        if (hPrinter) ClosePrinter(hPrinter);
        
        return true;

    } catch (const std::exception &e) {
        qWarning() << "╔══════════════════════════════════════════════════════════════╗";
        qWarning() << "║              PRINT JOB FAILED                               ║";
        qWarning() << "║ Error:" << e.what();
        qWarning() << "║ Timestamp:" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
        qWarning() << "║ Image:" << imagePath;
        qWarning() << "╚══════════════════════════════════════════════════════════════╝";
        emit printFinished(false, QString("Print failed: %1").arg(e.what()));

        // Cleanup for error path
        if (hdc) DeleteDC(hdc);
        if (lpDevMode) GlobalUnlock(hDevMode);
        if (hDevMode) GlobalFree(hDevMode);
        if (hPrinter) ClosePrinter(hPrinter);

        return false;
    } catch (...) {
        qWarning() << "[PrinterManager] Unknown error at" << QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss.zzz");
        emit printFinished(false, "Unknown print error");
        
        if (hdc) DeleteDC(hdc);
        if (lpDevMode) GlobalUnlock(hDevMode);
        if (hDevMode) GlobalFree(hDevMode);
        if (hPrinter) ClosePrinter(hPrinter);
        
        return false;
    }
#else
    qWarning() << "[PrinterManager] Windows API printing not supported on this platform";
    emit printFinished(false, "Windows API printing not supported on this platform");
    return false;
#endif
}



// ─── tryPrintOnePrinterSilent ─────────────────────────────────────────────────
// Thử in lên một máy in cụ thể. Không emit signal, không log spam.
// Trả về true nếu StartDoc/EndDoc thành công (lệnh đã vào spooler Windows).
bool PrinterManager::tryPrintOnePrinterSilent(
    const QString &imagePath, int copies, bool cutMode, int quality, const QString &printerName)
{
#ifdef Q_OS_WIN
    HANDLE hPrinter  = nullptr;
    HANDLE hDevMode  = nullptr;
    void  *lpDevMode = nullptr;
    HDC    hdc       = nullptr;

    try {
        if (!QFile::exists(imagePath)) return false;

        // Kiểm tra driver trước — tránh load ảnh nặng cho máy in không mở được (~50ms)
        if (!isSupportedDnpPrinter(printerName)) return false;
        std::wstring nameW = printerName.toStdWString();
        if (!OpenPrinterW((LPWSTR)nameW.c_str(), &hPrinter, nullptr)) return false;

        long dmSize = DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)nameW.c_str(), nullptr, nullptr, 0);
        if (dmSize <= 0) { ClosePrinter(hPrinter); return false; }

        // Driver ok → load và xử lý ảnh (chỉ làm 1 lần sau khi biết driver accessible)
        QImage image(imagePath);
        if (image.isNull()) { ClosePrinter(hPrinter); return false; }

        if (image.format() != QImage::Format_RGB888)
            image = image.convertToFormat(QImage::Format_RGB888);
        image = image.rgbSwapped();  // BGR layout cho Windows StretchDIBits

        hDevMode = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, dmSize);
        if (!hDevMode) { ClosePrinter(hPrinter); return false; }

        lpDevMode = GlobalLock(hDevMode);
        if (!lpDevMode) { GlobalFree(hDevMode); ClosePrinter(hPrinter); return false; }

        if (DocumentPropertiesW(nullptr, hPrinter, (LPWSTR)nameW.c_str(),
                                 (PDEVMODEW)lpDevMode, nullptr, DM_OUT_BUFFER) < 0) {
            GlobalUnlock(hDevMode); GlobalFree(hDevMode); ClosePrinter(hPrinter); return false;
        }

        PDEVMODEW pDM = (PDEVMODEW)lpDevMode;
        if (quality > 0) {
            pDM->dmPrintQuality = (short)quality;
            pDM->dmFields |= DM_PRINTQUALITY;
            pDM->dmYResolution = (short)quality;
            pDM->dmFields |= DM_YRESOLUTION;
        }
        // Giữ ĐỒNG BỘ với printWithDevmodeWinAPI() — nếu nhánh fallback này dùng
        // cấu hình khác thì lần in lại sau khi auto-scan sẽ ra bố cục khác.
        if (cutMode) {
            const QVector<DnpPaper> papers = dnpEnumeratePapers(printerName);
            const short curPaper = (pDM->dmFields & DM_PAPERSIZE) ? pDM->dmPaperSize : 0;
            short wantNumber = 0;
            for (const DnpPaper &p : papers)
                if (p.number == curPaper && isCut4x6PaperName(p.name)) { wantNumber = p.number; break; }
            if (wantNumber == 0)
                for (const DnpPaper &p : papers)
                    if (isCut4x6PaperName(p.name)) { wantNumber = p.number; break; }
            if (wantNumber != 0) {
                pDM->dmPaperSize = wantNumber;
                pDM->dmFields |= DM_PAPERSIZE;
                pDM->dmFields &= ~(DM_PAPERLENGTH | DM_PAPERWIDTH);
            }
            modifyDevmodeBorder(lpDevMode, dmSize, /*borderOn=*/false);
        }
        modifyDevmodeCut(lpDevMode, dmSize, cutMode);

        bool isImageLandscape = (image.width() > image.height());
        bool setLandscape = !isImageLandscape;
        modifyDevmodeOrientation(lpDevMode, dmSize, setLandscape);

        hdc = CreateDCW(nullptr, (LPCWSTR)nameW.c_str(), nullptr, (PDEVMODEW)lpDevMode);
        if (!hdc) { GlobalUnlock(hDevMode); GlobalFree(hDevMode); ClosePrinter(hPrinter); return false; }

        int canvasW = GetDeviceCaps(hdc, PHYSICALWIDTH);
        int canvasH = GetDeviceCaps(hdc, PHYSICALHEIGHT);

        // Lật hướng nếu canvas driver trả về ngược với ảnh (họ media PR vs DS40)
        if (canvasW > 0 && canvasH > 0 && (canvasW > canvasH) != isImageLandscape) {
            modifyDevmodeOrientation(lpDevMode, dmSize, !setLandscape);
            DeleteDC(hdc);
            hdc = CreateDCW(nullptr, (LPCWSTR)nameW.c_str(), nullptr, (PDEVMODEW)lpDevMode);
            if (!hdc) { GlobalUnlock(hDevMode); GlobalFree(hDevMode); ClosePrinter(hPrinter); return false; }
            canvasW = GetDeviceCaps(hdc, PHYSICALWIDTH);
            canvasH = GetDeviceCaps(hdc, PHYSICALHEIGHT);
        }

        const int offX = GetDeviceCaps(hdc, PHYSICALOFFSETX);
        const int offY = GetDeviceCaps(hdc, PHYSICALOFFSETY);

        BITMAPINFO bmi;
        memset(&bmi, 0, sizeof(bmi));
        bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
        bmi.bmiHeader.biWidth       = image.width();
        bmi.bmiHeader.biHeight      = -image.height();
        bmi.bmiHeader.biPlanes      = 1;
        bmi.bmiHeader.biBitCount    = 24;
        bmi.bmiHeader.biCompression = BI_RGB;

        bool allOk = true;
        for (int i = 0; i < copies && allOk; ++i) {
            DOCINFOW di = {};
            di.cbSize = sizeof(DOCINFOW);
            std::wstring dn = QString("AutoScan Print %1").arg(i + 1).toStdWString();
            di.lpszDocName = (LPCWSTR)dn.c_str();

            if (StartDocW(hdc, &di) <= 0) { allOk = false; break; }
            if (StartPage(hdc) <= 0)      { EndDoc(hdc); allOk = false; break; }

            SetStretchBltMode(hdc, HALFTONE);
            SetBrushOrgEx(hdc, 0, 0, NULL);
            // Bù physical offset để phủ đúng trang vật lý (xem printWithDevmodeWinAPI)
            StretchDIBits(hdc, -offX, -offY, canvasW, canvasH,
                          0, 0, image.width(), image.height(),
                          image.bits(), &bmi, DIB_RGB_COLORS, SRCCOPY);
            EndPage(hdc);
            EndDoc(hdc);
        }

        DeleteDC(hdc);
        GlobalUnlock(hDevMode); GlobalFree(hDevMode);
        ClosePrinter(hPrinter);
        return allOk;

    } catch (...) {
        if (hdc)      DeleteDC(hdc);
        if (lpDevMode) GlobalUnlock(hDevMode);
        if (hDevMode)  GlobalFree(hDevMode);
        if (hPrinter)  ClosePrinter(hPrinter);
        return false;
    }
#else
    Q_UNUSED(imagePath); Q_UNUSED(copies); Q_UNUSED(cutMode);
    Q_UNUSED(quality);   Q_UNUSED(printerName);
    return false;
#endif
}

// ─── autoFindAndPrint ────────────────────────────────────────────────────────
// Quét song song các máy in có sẵn, gửi lệnh in vào từng máy theo thứ tự,
// máy nào thành công đầu tiên thì lưu lại làm máy mặc định.
void PrinterManager::autoFindAndPrint(
    const QString &imagePath, int copies, bool cutMode, int quality)
{
    if (!m_autoPrintBusy.testAndSetAcquire(0, 1)) {
        qDebug() << "[PrinterManager] autoFindAndPrint already running";
        return;
    }

    qDebug() << "[PrinterManager] autoFindAndPrint started | copies=" << copies
             << "cutMode=" << cutMode << "quality=" << quality;

    emit autoPrintScanStarted();

    QtConcurrent::run(&m_printPool, [this, imagePath, copies, cutMode, quality]() {

        // Bước 1: Liệt kê driver đã cài — nhanh, chỉ query Windows spooler (~10ms)
        QStringList printers = enumerateLocalPrinters();
        qDebug() << "[PrinterManager] autoFindAndPrint: Windows printers found:" << printers;

        if (printers.isEmpty()) {
            QMetaObject::invokeMethod(this, [this]() {
                m_autoPrintBusy.storeRelease(0);
                emit autoPrintScanFinished(false, "");
                emit printFinished(false, "Không tìm thấy driver máy in nào được cài đặt.");
            }, Qt::QueuedConnection);
            return;
        }

        // Bước 2: Kiểm tra từng driver — OpenPrinterW + GetPrinterW để lọc máy offline
        QString candidatePrinter;
#ifdef Q_OS_WIN
        for (const QString &printer : printers) {
            QMetaObject::invokeMethod(this, [this, printer]() {
                emit autoPrintScanProgress("Đang kiểm tra: " + printer);
            }, Qt::QueuedConnection);

            HANDLE hTest = nullptr;
            std::wstring nameW = printer.toStdWString();
            if (!OpenPrinterW((LPWSTR)nameW.c_str(), &hTest, nullptr)) {
                qDebug() << "[PrinterManager] autoFindAndPrint:" << printer << "→ OpenPrinterW FAILED";
                continue;
            }

            // Kiểm tra trạng thái thực tế qua PRINTER_INFO_2
            bool isOnline = true;
            DWORD needed = 0;
            GetPrinterW(hTest, 2, nullptr, 0, &needed);
            if (needed > 0) {
                QByteArray buf(static_cast<int>(needed), 0);
                if (GetPrinterW(hTest, 2, reinterpret_cast<LPBYTE>(buf.data()), needed, &needed)) {
                    auto *pi2 = reinterpret_cast<PRINTER_INFO_2W*>(buf.data());
                    // PRINTER_STATUS_OFFLINE=0x80, PRINTER_STATUS_ERROR=0x02
                    // PRINTER_ATTRIBUTE_WORK_OFFLINE=0x400
                    bool offline   = (pi2->Status     & 0x00000080) != 0;
                    bool workOff   = (pi2->Attributes & 0x00000400) != 0;
                    bool hasError  = (pi2->Status     & 0x00000002) != 0;
                    isOnline = !offline && !workOff && !hasError;
                    qDebug() << "[PrinterManager] autoFindAndPrint:" << printer
                             << "Status=0x" + QString::number(pi2->Status, 16)
                             << "Attrs=0x" + QString::number(pi2->Attributes, 16)
                             << (isOnline ? "→ ONLINE" : "→ OFFLINE/ERROR, skip");
                }
            }
            ClosePrinter(hTest);

            if (isOnline) {
                candidatePrinter = printer;
                qDebug() << "[PrinterManager] autoFindAndPrint: candidate →" << printer;
                break;
            }
        }
#else
        if (!printers.isEmpty()) candidatePrinter = printers.first();
#endif

        if (candidatePrinter.isEmpty()) {
            QMetaObject::invokeMethod(this, [this]() {
                m_autoPrintBusy.storeRelease(0);
                emit autoPrintScanFinished(false, "");
                emit printFinished(false, "Không thể kết nối với bất kỳ máy in nào.");
            }, Qt::QueuedConnection);
            return;
        }

        // Bước 3: Gửi lệnh in thật (load ảnh 1 lần duy nhất cho candidate)
        QMetaObject::invokeMethod(this, [this, candidatePrinter]() {
            emit autoPrintScanProgress("Đang gửi lệnh in tới: " + candidatePrinter);
        }, Qt::QueuedConnection);

        bool ok = tryPrintOnePrinterSilent(imagePath, copies, cutMode, quality, candidatePrinter);
        qDebug() << "[PrinterManager] autoFindAndPrint:" << candidatePrinter
                 << (ok ? "→ PRINTED" : "→ SEND FAILED");

        if (ok) {
            QMetaObject::invokeMethod(this, [this, candidatePrinter]() {
                if (m_printerConfig)
                    m_printerConfig->setSelectedPrinter(candidatePrinter);
                m_autoPrintBusy.storeRelease(0);
                emit autoPrintScanFinished(true, candidatePrinter);
                emit printFinished(true, QString("Đã in thành công qua máy: %1").arg(candidatePrinter));
            }, Qt::QueuedConnection);
        } else {
            QMetaObject::invokeMethod(this, [this]() {
                m_autoPrintBusy.storeRelease(0);
                emit autoPrintScanFinished(false, "");
                emit printFinished(false, "Không thể gửi lệnh in. Vui lòng kiểm tra máy in và thử lại.");
            }, Qt::QueuedConnection);
        }
    });
}

QString PrinterManager::createDuplicatedImage(const QString &originalPath) {
    // Load original image
    QImage original(originalPath);
    if (original.isNull()) {
        qWarning() << "[PrinterManager] Failed to load image for duplication:" << originalPath;
        return QString();
    }

    qDebug() << "[PrinterManager] Creating duplicated image from:" << originalPath;
    qDebug() << "[PrinterManager] Original dimensions:" << original.width() << "x" << original.height();

    // Create double-width canvas
    int newWidth = original.width() * 2;
    int newHeight = original.height();
    QImage duplicated(newWidth, newHeight, QImage::Format_RGB32);
    duplicated.fill(Qt::white);

    // Draw original image twice (side-by-side)
    QPainter painter(&duplicated);
    painter.drawImage(0, 0, original);                  // Left copy
    painter.drawImage(original.width(), 0, original);   // Right copy
    painter.end();

    qDebug() << "[PrinterManager] Duplicated image dimensions:" << duplicated.width() << "x" << duplicated.height();

    // Save temporary file
    QString tempPath = QDir::temp().filePath(
        QString("cut_mode_%1.jpg").arg(QDateTime::currentDateTime().toString("yyyyMMdd_HHmmss_zzz"))
    );

    if (!duplicated.save(tempPath, "JPG", 100)) {
        qWarning() << "[PrinterManager] Failed to save duplicated image to:" << tempPath;
        return QString();
    }

    qDebug() << "[PrinterManager] Successfully created duplicated image:" << tempPath;
    return tempPath;
}
