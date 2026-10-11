#ifndef FUJIHOTFOLDERPROCESS_H
#define FUJIHOTFOLDERPROCESS_H

#include <QObject>
#include <QString>
#include <QTimer>

/**
 * @brief Quản lý app FUJIFILM HotFolder.exe (SDK13410 sample) cho nguồn chụp Hot Folder · Fujifilm.
 *
 * HotFolder.exe tự kết nối máy Fuji qua USB (tether), kéo ảnh khi khách bấm remote
 * và lưu vào thư mục nó đọc từ registry:
 *   HKCU\Software\COM.FUJIFILM.EID\HotFolder\SaveFolderPath  (mặc định Documents\FUJIFILM)
 * App chỉ chạy 1 instance (mutex IDS_APP_MUTEX) và tự ẩn xuống khay hệ thống.
 *
 * Lớp này: tìm exe, mở khi cần, dò còn chạy không + thư mục đổi chưa (mỗi 2s),
 * và tắt êm bằng lệnh "Exit" của menu khay (để app Fuji tự XSDK_Close/XSDK_Exit).
 */
class FujiHotFolderProcess : public QObject
{
    Q_OBJECT

public:
    explicit FujiHotFolderProcess(QObject *parent = nullptr);

    // Đường dẫn HotFolder.exe: <appDir>/tools/fuji_hotfolder/, sau đó bản dev trong SDK13410.
    // Rỗng nếu không tìm thấy.
    static QString locateExe();
    // Thư mục app Fuji đang lưu ảnh (registry), rỗng thì dùng mặc định giống app Fuji.
    static QString saveFolder();
    static bool isRunning();

    // Mở HotFolder.exe nếu chưa chạy. False nếu không có exe hoặc không mở được.
    bool launch();
    // Tắt mọi HotFolder.exe đang chạy: gửi lệnh Exit, quá timeout thì TerminateProcess.
    static void shutdown(int timeoutMs = 4000);

    void startMonitoring();
    void stopMonitoring();
    bool running() const { return m_running; }
    QString folder() const { return m_folder; }

signals:
    void runningChanged(bool running);
    void folderChanged(const QString &folder);

private:
    void poll();

    QTimer m_pollTimer;
    bool m_running = false;
    QString m_folder;
};

#endif // FUJIHOTFOLDERPROCESS_H
