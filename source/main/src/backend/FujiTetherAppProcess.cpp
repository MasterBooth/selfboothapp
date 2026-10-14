#include "FujiTetherAppProcess.h"
#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QElapsedTimer>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSettings>
#include <vector>

#ifdef Q_OS_WIN
#include <windows.h>
#include <tlhelp32.h>
#endif

namespace {
const wchar_t kExeName[] = L"FUJIFILM_TetherApp.exe";
const char kCtrlPropKey[] =
    "HKEY_CURRENT_USER\\Software\\COM.FUJIFILM.DENJI\\FUJIFILM_TetherApp\\CtrlProp";
constexpr int kPollMs = 2000;

// Ô "Destination folder" lưu dạng chuỗi đường dẫn thư mục tuyệt đối. Các ô đường
// dẫn khác của Tether App (phần mềm mở RAW/HEIF) trỏ tới file .exe → loại ra.
bool looksLikeFolderPath(const QString &value)
{
    static const QRegularExpression absPath(QStringLiteral(R"(^([A-Za-z]:[\\/]|\\\\))"));
    const QString s = value.trimmed();
    if (!absPath.match(s).hasMatch())
        return false;
    const QFileInfo fi(s);
    if (fi.isDir())
        return true;
    return !fi.exists() && fi.suffix().isEmpty();
}

#ifdef Q_OS_WIN
std::vector<DWORD> tetherPids()
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

BOOL CALLBACK postCloseToWindow(HWND hwnd, LPARAM lParam)
{
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    // Chỉ cửa sổ chính (không có owner, đang hiện — kể cả thu nhỏ): form WinForms
    // nhận WM_CLOSE và tự nhả máy ảnh như khi người dùng bấm X.
    if (pid == static_cast<DWORD>(lParam) && IsWindowVisible(hwnd)
            && GetWindow(hwnd, GW_OWNER) == nullptr) {
        PostMessageW(hwnd, WM_CLOSE, 0, 0);
    }
    return TRUE;
}
#endif
} // namespace

FujiTetherAppProcess::FujiTetherAppProcess(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setInterval(kPollMs);
    connect(&m_pollTimer, &QTimer::timeout, this, &FujiTetherAppProcess::poll);
}

QString FujiTetherAppProcess::locateExe(const QString &preferredExe)
{
    QStringList candidates;
    if (!preferredExe.trimmed().isEmpty())
        candidates << preferredExe.trimmed();
    candidates << QDir(QCoreApplication::applicationDirPath())
                      .filePath("tools/fuji_tetherapp/FUJIFILM_TetherApp.exe");
    candidates << QStringLiteral("C:/Program Files/FUJIFILM_TetherApp/FUJIFILM_TetherApp.exe");
    for (const QString &path : candidates) {
        if (QFileInfo(path).isFile())
            return QDir::toNativeSeparators(QFileInfo(path).absoluteFilePath());
    }
    return {};
}

QString FujiTetherAppProcess::receiveFolder()
{
    QString base = qEnvironmentVariable("LOCALAPPDATA");
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/AppData/Local");
    return QDir::toNativeSeparators(QDir(base).filePath(QStringLiteral("Selfbooth/TetherApp")));
}

bool FujiTetherAppProcess::isRunning()
{
#ifdef Q_OS_WIN
    return !tetherPids().empty();
#else
    return false;
#endif
}

int FujiTetherAppProcess::applySaveFolder(const QString &folder)
{
    if (isRunning()) {
        qWarning() << "FujiTetherAppProcess: app is running - save folder not changed";
        return 0;
    }

    QSettings reg(QString::fromLatin1(kCtrlPropKey), QSettings::NativeFormat);
    const QStringList keys = reg.allKeys();
    if (keys.isEmpty()) {
        qWarning() << "FujiTetherAppProcess: no Tether App settings yet (never run) -"
                   << "set Destination folder once in Tether App";
        return 0;
    }

    const QString target = QDir::toNativeSeparators(QDir::cleanPath(folder));
    int written = 0;
    for (const QString &key : keys) {
        const QVariant v = reg.value(key);
        if (v.typeId() != QMetaType::QString || !looksLikeFolderPath(v.toString()))
            continue;
        if (QDir::cleanPath(v.toString()).compare(QDir::cleanPath(target), Qt::CaseInsensitive) != 0) {
            qWarning() << "FujiTetherAppProcess: destination" << key << ":" << v.toString()
                       << "->" << target;
            reg.setValue(key, target);
        }
        ++written;
    }
    reg.sync();
    if (written == 0) {
        qWarning() << "FujiTetherAppProcess: destination folder setting not found among"
                   << keys.size() << "values:" << keys;
    }
    return written;
}

QString FujiTetherAppProcess::configuredFolder()
{
    QSettings reg(QString::fromLatin1(kCtrlPropKey), QSettings::NativeFormat);
    const QStringList keys = reg.allKeys();
    for (const QString &key : keys) {
        const QVariant v = reg.value(key);
        if (v.typeId() == QMetaType::QString && looksLikeFolderPath(v.toString()))
            return QDir::toNativeSeparators(QDir::cleanPath(v.toString().trimmed()));
    }
    return {};
}

bool FujiTetherAppProcess::launch(const QString &exe)
{
    if (isRunning()) {
        qWarning() << "FujiTetherAppProcess: FUJIFILM_TetherApp.exe already running";
        return true;
    }
    if (exe.isEmpty() || !QFileInfo(exe).isFile()) {
        qWarning() << "FujiTetherAppProcess: FUJIFILM_TetherApp.exe not found" << exe;
        return false;
    }

#ifdef Q_OS_WIN
    const QString nativeExe = QDir::toNativeSeparators(exe);
    const QString workDir = QDir::toNativeSeparators(QFileInfo(exe).absolutePath());
    std::wstring cmd = L"\"" + nativeExe.toStdWString() + L"\"";
    const std::wstring wdir = workDir.toStdWString();

    STARTUPINFOW si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_SHOWMINNOACTIVE;   // thu nhỏ xuống taskbar, không giành focus BOOTHME
    PROCESS_INFORMATION pi;
    ZeroMemory(&pi, sizeof(pi));

    const BOOL ok = CreateProcessW(nullptr, cmd.data(), nullptr, nullptr, FALSE,
                                   0, nullptr, wdir.c_str(), &si, &pi);
    if (!ok) {
        qWarning() << "FujiTetherAppProcess: launch failed" << nativeExe
                   << "| error" << GetLastError();
        return false;
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    qWarning() << "FujiTetherAppProcess: launched (minimized)" << nativeExe;
    return true;
#else
    return false;
#endif
}

void FujiTetherAppProcess::shutdown(int timeoutMs)
{
#ifdef Q_OS_WIN
    const std::vector<DWORD> pids = tetherPids();
    if (pids.empty())
        return;

    std::vector<HANDLE> handles;
    for (DWORD pid : pids) {
        HANDLE h = OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, FALSE, pid);
        if (h)
            handles.push_back(h);
        EnumWindows(postCloseToWindow, static_cast<LPARAM>(pid));
    }
    qWarning() << "FujiTetherAppProcess: close requested for" << int(pids.size()) << "process(es)";

    QElapsedTimer timer;
    timer.start();
    for (HANDLE h : handles) {
        const qint64 left = qMax<qint64>(0, timeoutMs - timer.elapsed());
        if (WaitForSingleObject(h, static_cast<DWORD>(left)) == WAIT_TIMEOUT) {
            qWarning() << "FujiTetherAppProcess: Tether App did not exit in time - terminating";
            TerminateProcess(h, 0);
            WaitForSingleObject(h, 1000);
        }
        CloseHandle(h);
    }
    qWarning() << "FujiTetherAppProcess: closed after" << timer.elapsed() << "ms";
#else
    Q_UNUSED(timeoutMs);
#endif
}

void FujiTetherAppProcess::startMonitoring()
{
    m_running = isRunning();
    m_pollTimer.start();
}

void FujiTetherAppProcess::stopMonitoring()
{
    m_pollTimer.stop();
}

void FujiTetherAppProcess::poll()
{
    const bool running = isRunning();
    if (running != m_running) {
        m_running = running;
        qWarning() << "FujiTetherAppProcess: Tether App" << (running ? "running" : "stopped");
        emit runningChanged(running);
    }
}
