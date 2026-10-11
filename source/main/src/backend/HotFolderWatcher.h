#ifndef HOTFOLDERWATCHER_H
#define HOTFOLDERWATCHER_H

#include <QObject>
#include <QFileSystemWatcher>
#include <QHash>
#include <QSet>
#include <QString>
#include <QTimer>

/**
 * @brief Theo dõi một thư mục "hot folder" và báo khi có ảnh JPG mới đã ghi xong.
 *
 * - Chỉ nhận ảnh khi đang ARMED (CaptureScreen bật lúc bắt đầu chụp). Lúc arm,
 *   mọi file đang có trong thư mục được ghi vào baseline và bị bỏ qua — ảnh của
 *   khách trước không lọt vào phiên mới. Khi không arm, file để nguyên.
 * - Chỉ .jpg/.jpeg; RAF/HEIC và file tạm của Fuji (.___ / .seq) bị bỏ qua.
 * - File phải "ổn định" (kích thước không đổi ≥ kStableMs, đọc được bằng
 *   QImageReader) mới báo fileReady — phần mềm tether ghi file dần vẫn an toàn.
 * - QFileSystemWatcher + quét định kỳ (dự phòng khi Windows bỏ sót sự kiện).
 *
 * Chạy hoàn toàn trên main thread; việc di chuyển/lật ảnh do CameraController làm.
 */
class HotFolderWatcher : public QObject
{
    Q_OBJECT

public:
    explicit HotFolderWatcher(QObject *parent = nullptr);

    // Bắt đầu theo dõi thư mục. Trả về false nếu thư mục không tồn tại (vẫn
    // tiếp tục dò lại định kỳ và báo watchingChanged(true) khi thư mục xuất hiện).
    bool start(const QString &dir);
    void stop();

    QString folder() const { return m_dir; }
    bool isWatching() const { return m_started && m_dirPresent; }

    void setArmed(bool armed);
    bool isArmed() const { return m_armed; }
    // Có ảnh mới đang được ghi dở (chưa "ổn định") — dùng khi hết giờ để chờ ảnh cuối.
    bool hasPendingFiles() const { return m_armed && !m_pending.isEmpty(); }

signals:
    void watchingChanged(bool watching);
    // Ảnh mới đã ghi xong, đường dẫn tuyệt đối trong hot folder.
    void fileReady(const QString &path);

private:
    void scheduleScan();
    void scan();
    void updatePresence();
    void updatePollInterval();
    QStringList listJpegs(bool sortByTime) const;

    struct Pending {
        qint64 size = -1;
        qint64 firstSeenMs = 0;
        qint64 lastChangeMs = 0;
    };

    QFileSystemWatcher m_fsw;
    QTimer m_pollTimer;
    QTimer m_debounce;
    QString m_dir;
    bool m_started = false;
    bool m_dirPresent = false;
    bool m_armed = false;
    QSet<QString> m_baseline;   // tên file có sẵn lúc arm → bỏ qua
    QSet<QString> m_handled;    // đã báo fileReady (hoặc đã bỏ cuộc) → không xử lý lại
    QHash<QString, Pending> m_pending;
};

#endif // HOTFOLDERWATCHER_H
