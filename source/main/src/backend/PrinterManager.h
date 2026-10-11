#ifndef PRINTERMANAGER_H
#define PRINTERMANAGER_H

#ifdef _WIN32
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winspool.h>
#endif

#include <QObject>
#include <QPrinter>
#include <QLibrary>
#include <QTimer>
#include <QDebug>
#include <QStringList>
#include <QAtomicInt>
#include <QMutex>
#include <QThreadPool>
#include "DNPStatusCodes.h"
#include "PrinterConfig.h"

// ── Private DEVMODE của DNP ────────────────────────────────────────────────
// Nguồn: Status API/Window SDK/.../Print Settings Sample/Doc/PrintSettings_E.pdf §2(2), §4
//        và .../VB.NET PrintSettings_Sample/Devmode.vb
// Xem docs/DNP_RX1_CUT_PRINT_SPEC.md §4.
//
// Vùng private nằm ngay sau public DEVMODEW; vị trí thay đổi theo máy nên phải
// dò chuỗi "MSFT". ExDevTop = (chỉ số int chứa "MSFT") - 1 vì OemExStrSize ở
// offset 0 và OemExSign ở offset 1.
#ifdef Q_OS_WIN
#define EX_DEV_SIGN 0x4D534654  // "MSFT" — OemExSign

#define ExBorder    3           // OemBorder     : 0 = No border, 1 = Border
#define ExCut2inch  30          // OemCut2inch   : 0 = Normal cut, 1 = 2inch cut

#define DM_BORDER_OFF   0
#define DM_BORDER_ON    1
#define DM_CUT2INCH_OFF 0
#define DM_CUT2INCH_ON 1

// DEVMODE orientation for cut direction
#define DMORIENT_PORTRAIT 1   // Cắt dọc (vertical) - mặc định
#define DMORIENT_LANDSCAPE 2  // Cắt ngang (horizontal)
#endif

class PrinterManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(bool isConnected READ isConnected NOTIFY connectionChanged)

public:
    explicit PrinterManager(QObject *parent = nullptr);
    ~PrinterManager();

    // Printing
    Q_INVOKABLE void printImage(const QString &imagePath, int copies, const QString &pageSize);
    Q_INVOKABLE void printImageWithSettings(const QString &imagePath,
                                             int copies,
                                             const QString &paperSize,
                                             int quality,
                                             bool cutMode,
                                             bool matteFinish);
    Q_INVOKABLE void printImageWithSettingsAndRotation(const QString &imagePath,
                                                       int copies,
                                                       const QString &paperSize,
                                                       int quality,
                                                       bool cutMode,
                                                       bool matteFinish,
                                                       int imageRotation);
    // In tự do (Free Print): gửi ảnh đã ghép nguyên trạng tới máy in bất kỳ,
    // để driver tự scale theo khổ của nó. Bỏ mọi bước đặc thù DNP (auto-rotation
    // theo model, đảo hướng DEVMODE, gate SDK) và LUÔN in không cắt.
    Q_INVOKABLE void printFreeMode(const QString &imagePath,
                                   const QString &printerName,
                                   int imageRotation,
                                   int copies);
    Q_INVOKABLE QString browseForImage();
    Q_INVOKABLE QString rotateAndSaveImage(const QString &imagePath, int degrees, const QString &collageImagePath = "");

    // Status and Information
    Q_INVOKABLE void checkStatus();
    Q_INVOKABLE QString getStatusString();
    Q_INVOKABLE QString getFirmwareVersion();
    Q_INVOKABLE QString getSerialNumber();
    Q_INVOKABLE QString getSensorInfo();
    Q_INVOKABLE QString getColorDataVersion();
    Q_INVOKABLE QString getColorDataChecksum();

    // Media Information
    Q_INVOKABLE QString getMediaCode();
    Q_INVOKABLE int getMediaCounter();
    Q_INVOKABLE QString getMediaLotNo();
    Q_INVOKABLE int getMediaColorOffset();
    Q_INVOKABLE int getMediaIdSetInfo();
    Q_INVOKABLE int getInitialMediaCount();
    Q_INVOKABLE int getMediaCountOffset();

    // Counters
    Q_INVOKABLE int getCounterL();      // Life counter
    Q_INVOKABLE int getCounterA();      // Counter A
    Q_INVOKABLE int getCounterB();      // Counter B
    Q_INVOKABLE int getCounterP();      // Counter P
    Q_INVOKABLE int getCounterM();      // Counter M
    Q_INVOKABLE int getCounterMatte();  // Matte counter

    Q_INVOKABLE bool clearCounterA();
    Q_INVOKABLE bool clearCounterB();
    Q_INVOKABLE bool clearCounterM();
    Q_INVOKABLE bool setCounterP(int value);

    // Print Queue and Buffer
    Q_INVOKABLE int getRemainingPrintQuantity();
    Q_INVOKABLE int getFreeBufferCount();

    // Resolution
    Q_INVOKABLE int getResolutionH();
    Q_INVOKABLE int getResolutionV();

    // Settings
    Q_INVOKABLE bool setCutterMode(int mode);
    Q_INVOKABLE bool setUSBSerialEnable(bool enable);
    Q_INVOKABLE int getUSBSerialEnable();

    // Connection
    Q_INVOKABLE bool initializePort(const QString &portName);
    Q_INVOKABLE void setListAllWindowsPrinters(bool enabled) { m_listAllWindowsPrinters = enabled; }
    // Async reconnect: thử USB002 trước, nếu không scan USB001-USB005
    Q_INVOKABLE void reconnect();
    // Async switch printer: update config + reinit port trên background thread
    Q_INVOKABLE void switchPrinterAsync(const QString &printerName);
    // Async refresh printer list: emit printerListReady khi xong
    Q_INVOKABLE void refreshPrinterListAsync();
    // Auto-scan tất cả máy in có sẵn và gửi lệnh in vào máy đầu tiên thành công
    Q_INVOKABLE void autoFindAndPrint(const QString &imagePath, int copies, bool cutMode, int quality);

    // Printer config binding — gọi từ main.cpp sau khi tạo cả hai đối tượng
    void setPrinterConfig(PrinterConfig *config) { m_printerConfig = config; }

    // DEVMODE-based Printing (Enhanced from PrinterTesterUI.py)
    Q_INVOKABLE QStringList getAvailablePrinters();
    Q_INVOKABLE bool printImageWithDevmode(const QString &imagePath, PrinterConfig *config);
    Q_INVOKABLE bool saveToPrintoutFolder(const QString &imagePath, int copies);

    QString status() const { return m_currentStatus; }
    bool isConnected() const { return m_isConnected; }

signals:
    void statusChanged(QString newStatus);
    void printFinished(bool success, QString message);
    void connectionChanged(bool connected);
    void errorOccurred(QString error);
    // Phát sau refreshPrinterListAsync() hoàn thành
    void printerListReady(QStringList printers);
    // Phát khi bắt đầu / kết thúc switchPrinterAsync()
    void printerSwitchStarted();
    void printerSwitchFinished(bool success, QString message);
    // Phát khi bắt đầu / kết thúc reconnect()
    void reconnectStarted();
    void reconnectFinished(bool success, QString port);
    // Phát trong quá trình autoFindAndPrint()
    void autoPrintScanStarted();
    void autoPrintScanProgress(const QString &message);
    void autoPrintScanFinished(bool success, const QString &printerName);

private:
    // Pool RIÊNG cho JOB IN (1 luồng). Máy in vật lý không in 2 job cùng lúc,
    // và 1 job in poll trạng thái 30–60s. Trước đây chạy trên global thread
    // pool → chiếm hết slot, task chụp ảnh bị xếp hàng vô thời hạn → app "đơ".
    QThreadPool m_printPool;

    void loadSdk();
    QString decodeStatus(long statusCode);
    // Thử init một port cụ thể trên background thread — trả về true nếu thành công
    // KHÔNG emit signal, KHÔNG gọi QObject slot (thread-safe helper)
    bool tryInitPort(const QString &portName, long &outPortNum);

    // DEVMODE manipulation methods (ported from PrinterTesterUI.py)
    bool findExDevTop(void *devmodePtr, int devmodeSize, int &exDevTop);
    bool modifyDevmodeCut(void *devmodePtr, int devmodeSize, bool enableCut);
    bool modifyDevmodeOrientation(void *devmodePtr, int devmodeSize, bool landscape);
    // OemBorder (private offset 3). Tài liệu: khi bật Border, driver TRỪ viền vào
    // kích thước ảnh ⇒ vùng in không còn đủ 1240×1844 ⇒ tâm nội dung lệch tâm giấy.
    // Chế độ cắt bắt buộc Border = OFF.
    bool modifyDevmodeBorder(void *devmodePtr, int devmodeSize, bool borderOn);
    // Ghi giá trị vào một ô int của vùng private DEVMODE (dùng chung cho cut/border)
    bool writeDevmodePrivateInt(void *devmodePtr, int devmodeSize,
                                int fieldOffset, int value, const char *fieldName);
    bool printWithDevmode(const QString &imagePath, int copies, bool enableCut,
                          const QString &printerName);

    bool printWithDevmodeWinAPI(const QString &imagePath, int copies, bool cutMode, bool landscape = false, int imageRotation = 0, int quality = 300, const QString &printerName = QString(), bool freeMode = false);
    // Thử in trực tiếp lên một máy in cụ thể — không emit signal, dùng cho autoFindAndPrint
    bool tryPrintOnePrinterSilent(const QString &imagePath, int copies, bool cutMode, int quality, const QString &printerName);

    // Image duplication for cut mode
    QString createDuplicatedImage(const QString &originalPath);

    QStringList enumerateLocalPrinters();

    // SDK Function Pointers - Information Functions
    // IMPORTANT: Use wchar_t* (not const) to match DLL signature LPWSTR
    typedef long (APIENTRY *PortInitializeFunc)(wchar_t*);
    typedef long (APIENTRY *GetFirmwVersionFunc)(long, char*);
    typedef long (APIENTRY *GetSerialNoFunc)(long, char*);
    typedef long (APIENTRY *GetSensorInfoFunc)(long, char*);
    typedef long (APIENTRY *GetStatusFunc)(long);
    typedef long (APIENTRY *GetMediaFunc)(long, char*);

    // Counter Functions
    typedef long (APIENTRY *GetCounterLFunc)(long);
    typedef long (APIENTRY *GetCounterAFunc)(long);
    typedef long (APIENTRY *GetCounterBFunc)(long);
    typedef long (APIENTRY *GetCounterPFunc)(long);
    typedef long (APIENTRY *GetCounterMFunc)(long);
    typedef long (APIENTRY *GetCounterMatteFunc)(long);
    typedef long (APIENTRY *SetClearCounterAFunc)(long);
    typedef long (APIENTRY *SetClearCounterBFunc)(long);
    typedef long (APIENTRY *SetClearCounterMFunc)(long);
    typedef long (APIENTRY *SetCounterPFunc)(long, long);

    // Media Functions
    typedef long (APIENTRY *GetMediaCounterFunc)(long);
    typedef long (APIENTRY *GetMediaLotNoFunc)(long, char*);
    typedef long (APIENTRY *GetMediaColorOffsetFunc)(long);
    typedef long (APIENTRY *GetMediaIdSetInfoFunc)(long);
    typedef long (APIENTRY *GetInitialMediaCountFunc)(long);
    typedef long (APIENTRY *GetMediaCountOffsetFunc)(long);

    // Color Data Functions
    typedef long (APIENTRY *GetColorDataVersionFunc)(long, char*);
    typedef long (APIENTRY *GetColorDataChecksumFunc)(long, char*);

    // Print Queue Functions
    typedef long (APIENTRY *GetPQTYFunc)(long);
    typedef long (APIENTRY *GetFreeBufferFunc)(long);

    // Resolution Functions
    typedef long (APIENTRY *GetResolutionHFunc)(long);
    typedef long (APIENTRY *GetResolutionVFunc)(long);

    // Settings Functions
    typedef long (APIENTRY *SetCutterModeFunc)(long, long);
    typedef BOOL (APIENTRY *SetUSBSerialEnableFunc)(long, DWORD);
    typedef long (APIENTRY *GetUSBSerialEnableFunc)(long);

    // Function Pointers
    PortInitializeFunc m_portInitialize = nullptr;
    GetFirmwVersionFunc m_getFirmwVersion = nullptr;
    GetSerialNoFunc m_getSerialNo = nullptr;
    GetSensorInfoFunc m_getSensorInfo = nullptr;
    GetStatusFunc m_getStatus = nullptr;
    GetMediaFunc m_getMedia = nullptr;

    GetCounterLFunc m_getCounterL = nullptr;
    GetCounterAFunc m_getCounterA = nullptr;
    GetCounterBFunc m_getCounterB = nullptr;
    GetCounterPFunc m_getCounterP = nullptr;
    GetCounterMFunc m_getCounterM = nullptr;
    GetCounterMatteFunc m_getCounterMatte = nullptr;
    SetClearCounterAFunc m_setClearCounterA = nullptr;
    SetClearCounterBFunc m_setClearCounterB = nullptr;
    SetClearCounterMFunc m_setClearCounterM = nullptr;
    SetCounterPFunc m_setCounterP = nullptr;

    GetMediaCounterFunc m_getMediaCounter = nullptr;
    GetMediaLotNoFunc m_getMediaLotNo = nullptr;
    GetMediaColorOffsetFunc m_getMediaColorOffset = nullptr;
    GetMediaIdSetInfoFunc m_getMediaIdSetInfo = nullptr;
    GetInitialMediaCountFunc m_getInitialMediaCount = nullptr;
    GetMediaCountOffsetFunc m_getMediaCountOffset = nullptr;

    GetColorDataVersionFunc m_getColorDataVersion = nullptr;
    GetColorDataChecksumFunc m_getColorDataChecksum = nullptr;

    GetPQTYFunc m_getPQTY = nullptr;
    GetFreeBufferFunc m_getFreeBuffer = nullptr;

    GetResolutionHFunc m_getResolutionH = nullptr;
    GetResolutionVFunc m_getResolutionV = nullptr;

    SetCutterModeFunc m_setCutterMode = nullptr;
    SetUSBSerialEnableFunc m_setUSBSerialEnable = nullptr;
    GetUSBSerialEnableFunc m_getUSBSerialEnable = nullptr;

    QLibrary m_sdkLib;
    long m_portNum = -1;
    QString m_currentPort;                  // Port đang dùng (e.g. "USB002")
    QString m_currentStatus;
    bool m_isConnected = false;
    bool m_listAllWindowsPrinters = false;
    PrinterConfig *m_printerConfig = nullptr;

    // Atomic flags ngăn concurrent DLL calls
    QAtomicInt m_statusCheckBusy{0};  // 1 khi đang check status trên background
    QAtomicInt m_reconnectBusy{0};    // 1 khi đang reconnect
    QAtomicInt m_autoPrintBusy{0};    // 1 khi đang autoFindAndPrint
    QMutex m_sdkMutex;                // Bảo vệ m_portNum khi đọc/ghi từ nhiều thread
    QMutex m_dllMutex;                // Serialize mọi lần gọi vào CyStat64 DLL (không thread-safe)
};


#endif // PRINTERMANAGER_H
