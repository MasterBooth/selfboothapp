#ifndef FUJITETHERAPPPROCESS_H
#define FUJITETHERAPPPROCESS_H

#include <QObject>
#include <QString>
#include <QTimer>

/**
 * @brief Quản lý FUJIFILM_TetherApp.exe (app tether chính hãng) cho nguồn chụp
 *        Hot Folder · Tether App.
 *
 * Tether App là app WinForms, không nhận tham số dòng lệnh. Cài đặt lưu theo từng
 * control trong registry:
 *   HKCU\Software\COM.FUJIFILM.DENJI\FUJIFILM_TetherApp\CtrlProp\...\ctrl_<n>
 * App đọc cài đặt lúc mở và ghi lại lúc thoát → chỉ ghi thư mục đích khi app chưa chạy.
 *
 * Lớp này: tìm exe, ghi thư mục nhận ảnh của BOOTHME vào ô "Destination folder",
 * mở app ở dạng thu nhỏ, dò còn chạy không (mỗi 2s), và tắt êm bằng WM_CLOSE
 * (quá hạn thì TerminateProcess).
 */
class FujiTetherAppProcess : public QObject
{
    Q_OBJECT

public:
    explicit FujiTetherAppProcess(QObject *parent = nullptr);

    // Thứ tự: preferredExe (người dùng chọn) → <appDir>/tools/fuji_tetherapp/ (đóng gói)
    // → C:\Program Files\FUJIFILM_TetherApp\. Rỗng nếu không tìm thấy.
    static QString locateExe(const QString &preferredExe);
    // Thư mục BOOTHME bắt Tether App lưu ảnh: %LOCALAPPDATA%\Selfbooth\TetherApp.
    static QString receiveFolder();
    static bool isRunning();

    // Ghi folder vào ô Destination folder của Tether App (chỉ khi app chưa chạy).
    // Trả về số giá trị registry đã ghi; 0 = chưa có cài đặt (app chưa từng chạy)
    // hoặc không nhận ra ô thư mục.
    static int applySaveFolder(const QString &folder);
    // Thư mục Destination hiện lưu trong registry (rỗng nếu chưa có).
    static QString configuredFolder();

    // Mở Tether App thu nhỏ, không giành focus. False nếu không mở được.
    static bool launch(const QString &exe);
    // Tắt mọi FUJIFILM_TetherApp.exe: WM_CLOSE, quá timeout thì TerminateProcess.
    static void shutdown(int timeoutMs = 5000);

    void startMonitoring();
    void stopMonitoring();
    bool running() const { return m_running; }

signals:
    void runningChanged(bool running);

private:
    void poll();

    QTimer m_pollTimer;
    bool m_running = false;
};

#endif // FUJITETHERAPPPROCESS_H
