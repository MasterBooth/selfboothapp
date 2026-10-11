#include "FujiHotFolderProcess.h"
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QProcess>
#include <QSettings>
#include <QStandardPaths>
#include <vector>

#ifdef Q_OS_WIN
#include <windows.h>
#include <tlhelp32.h>
#endif

namespace {
// IDS_APP_MUTEX trong HotFolder.rc — tồn tại suốt thời gian app Fuji chạy.
const wchar_t kAppMutex[] = L"{39F78821-C62E-427d-B679-0019D70A9B18}";
// ID_POPUP_EXIT trong HotFolder/resource.h — lệnh "Exit" của menu khay.
constexpr unsigned kPopupExitCommand = 32776;
const char kRegistryKey[] = "HKEY_CURRENT_USER\\Software\\COM.FUJIFILM.EID\\HotFolder";
const wchar_t kExeName[] = L"HotFolder.exe";
constexpr int kPollMs = 2000;

#ifdef Q_OS_WIN
std::vector<DWORD> hotFolderPids()
{
    std::vector<DWORD> pids;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE)
        return pids;

    PROCESSENTRY32W entry;
    entry.dwSize = sizeof(entry);
    if (Process32FirstW(snap, &entry)) {
        do {
            if (_wcsicmp(entry.szExeFile, kExeName) == 0)
                pids.push_back(entry.th32ProcessID);
        } while (Process32NextW(snap, &entry));
    }
    CloseHandle(snap);
    return pids;
}

BOOL CALLBACK postExitToWindow(HWND hwnd, LPARAM lParam)
{
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == static_cast<DWORD>(lParam)) {
        // Hộp thoại ngoài bỏ qua lệnh này; CMainDlg (cửa sổ khay) xử lý OnPopupExit.
        PostMessageW(hwnd, WM_COMMAND, MAKEWPARAM(kPopupExitCommand, 0), 0);
    }
    return TRUE;
}
#endif
} // namespace

FujiHotFolderProcess::FujiHotFolderProcess(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setInterval(kPollMs);
    connect(&m_pollTimer, &QTimer::timeout, this, &FujiHotFolderProcess::poll);
}

QString FujiHotFolderProcess::locateExe()
{
    QStringList candidates;
    candidates << QDir(QCoreApplication::applicationDirPath())
                      .filePath("tools/fuji_hotfolder/HotFolder.exe");
#ifdef FUJI_HOTFOLDER_DEV_EXE
    candidates << QStringLiteral(FUJI_HOTFOLDER_DEV_EXE);
#endif
    for (const QString &path : candidates) {
        if (QFileInfo(path).isFile())
            return QDir::toNativeSeparators(QFileInfo(path).absoluteFilePath());
    }
    return {};
}

QString FujiHotFolderProcess::saveFolder()
{
    QSettings reg(QString::fromLatin1(kRegistryKey), QSettings::NativeFormat);
    const QString value = reg.value("SaveFolderPath").toString().trimmed();
    if (!value.isEmpty())
        return QDir::toNativeSeparators(QDir::cleanPath(value));

    // Giống CProperty::GetDefaultFolder: <Documents>\FUJIFILM, Documents nằm trên
    // ổ mạng (UNC) thì dùng C:\FUJIFILM.
    const QString docs = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (docs.isEmpty() || docs.startsWith("//") || docs.startsWith("\\\\"))
        return QStringLiteral("C:\\FUJIFILM");
    return QDir::toNativeSeparators(QDir(docs).filePath("FUJIFILM"));
}

bool FujiHotFolderProcess::isRunning()
{
#ifdef Q_OS_WIN
    HANDLE mutex = OpenMutexW(SYNCHRONIZE, FALSE, kAppMutex);
    if (mutex) {
        CloseHandle(mutex);
        return true;
    }
    // Mutex chưa tạo kịp (splash) nhưng tiến trình đã có → vẫn coi là đang chạy,
    // tránh mở instance thứ 2 (app Fuji sẽ hiện hộp thoại "already started").
    return !hotFolderPids().empty();
#else
    return false;
#endif
}

bool FujiHotFolderProcess::launch()
{
    if (isRunning()) {
        qDebug() << "FujiHotFolderProcess: HotFolder.exe already running";
        return true;
    }

    const QString exe = locateExe();
    if (exe.isEmpty()) {
        qWarning() << "FujiHotFolderProcess: HotFolder.exe not found";
        return false;
    }

    // Working dir = thư mục exe để app Fuji nạp được LIBRARY\XAPI.dll.
    const bool ok = QProcess::startDetached(exe, {}, QFileInfo(exe).absolutePath());
    qDebug() << "FujiHotFolderProcess: launch" << exe << "ok =" << ok;
    return ok;
}

void FujiHotFolderProcess::shutdown(int timeoutMs)
{
#ifdef Q_OS_WIN
    const std::vector<DWORD> pids = hotFolderPids();
    if (pids.empty())
        return;

    std::vector<HANDLE> handles;
    for (DWORD pid : pids) {
        HANDLE h = OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, FALSE, pid);
        if (h)
            handles.push_back(h);
        EnumWindows(postExitToWindow, static_cast<LPARAM>(pid));
    }
    qDebug() << "FujiHotFolderProcess: exit requested for" << int(pids.size()) << "process(es)";

    // OnPopupExit dừng thread, XSDK_Close + Sleep(600) + XSDK_Exit rồi mới thoát.
    QElapsedTimer timer;
    timer.start();
    for (HANDLE h : handles) {
        const qint64 left = qMax<qint64>(0, timeoutMs - timer.elapsed());
        if (WaitForSingleObject(h, static_cast<DWORD>(left)) == WAIT_TIMEOUT) {
            qWarning() << "FujiHotFolderProcess: HotFolder.exe did not exit in time - terminating";
            TerminateProcess(h, 0);
            WaitForSingleObject(h, 1000);
        }
        CloseHandle(h);
    }
#else
    Q_UNUSED(timeoutMs);
#endif
}

void FujiHotFolderProcess::startMonitoring()
{
    m_running = isRunning();
    m_folder = saveFolder();
    m_pollTimer.start();
}

void FujiHotFolderProcess::stopMonitoring()
{
    m_pollTimer.stop();
}

void FujiHotFolderProcess::poll()
{
    const bool running = isRunning();
    if (running != m_running) {
        m_running = running;
        qDebug() << "FujiHotFolderProcess: HotFolder.exe" << (running ? "running" : "stopped");
        emit runningChanged(running);
    }

    // Người dùng đổi thư mục qua menu khay của app Fuji → registry đổi ngay.
    const QString folder = saveFolder();
    if (folder != m_folder) {
        m_folder = folder;
        qDebug() << "FujiHotFolderProcess: save folder changed to" << folder;
        emit folderChanged(folder);
    }
}
