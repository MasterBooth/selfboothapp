#ifndef VIDEOCREATOR_H
#define VIDEOCREATOR_H

#include <QObject>
#include <QStringList>
#include <QVariantList>
#include <QFutureWatcher>
#include <QThreadPool>

/**
 * @class VideoCreator
 * @brief Creates MP4 videos from image sequences using FFmpeg (libx264).
 *
 * FFmpeg static build — no system codec dependency, works on all Windows editions.
 * Encoding runs on a background thread via QtConcurrent.
 */
class VideoCreator : public QObject
{
    Q_OBJECT
public:
    explicit VideoCreator(QObject *parent = nullptr);
    ~VideoCreator();

    // Main method — async, emits signals when done.
    // maxLongEdge: giới hạn cạnh dài (px), tối thiểu 1080. 0 = dùng kích thước gốc.
    Q_INVOKABLE void createVideoFromImages(const QStringList &imagePaths,
                                           const QString &outputPath,
                                           int fps = 30,
                                           int maxLongEdge = 1920);

    // ── Process video ─────────────────────────────────────────────────────────
    // Dựng video "quá trình tạo dáng": hiển thị frame (PNG trong suốt) đã chọn,
    // mỗi slot phát lại clip quá trình chụp (đã ghi ở <slotRecordDirs[i]>), tất cả
    // các slot phát ĐỒNG THỜI. Khi clip 1 slot kết thúc, ô freeze ở ảnh tĩnh đã
    // chụp (stillPhotos[i]). Video dài = max thời lượng các clip.
    //   slots: QVariantList< {x,y,width,height} > theo toạ độ canvas gốc (px).
    //   canvasW/H: kích thước canvas frame gốc (px) — sẽ được scale theo maxLongEdge.
    //   stillPhotos / slotRecordDirs: 1 phần tử / slot, cùng thứ tự với slots.
    Q_INVOKABLE void createProcessVideo(const QString &framePng,
                                        const QVariantList &slotList,
                                        int canvasW, int canvasH,
                                        const QStringList &stillPhotos,
                                        const QStringList &slotRecordDirs,
                                        const QString &outputPath,
                                        int fps = 30,
                                        int maxLongEdge = 1920);

    // Đường dẫn tới ffmpeg.exe — mặc định tìm cạnh exe của app
    Q_INVOKABLE void setFfmpegPath(const QString &path) { m_ffmpegPath = path; }
    Q_INVOKABLE QString getFfmpegPath() const { return m_ffmpegPath; }
    Q_INVOKABLE bool isFfmpegAvailable();

    Q_INVOKABLE void setVideoQuality(int crf) { m_crf = qBound(0, crf, 51); }
    Q_INVOKABLE void setVideoResolution(int width, int height) {
        m_videoWidth = width; m_videoHeight = height;
    }

signals:
    void videoCreationStarted();
    void videoCreationProgress(int percentage);
    void videoCreationFinished(const QString &videoPath);
    void videoCreationError(const QString &error);

private:
    QString encodeWithFfmpeg(const QStringList &imagePaths,
                             const QString &outputPath,
                             int fps,
                             int maxLongEdge);

    // Process video (chạy trên m_pool).
    QString encodeProcessVideo(const QString &framePng,
                               const QVariantList &slotList,
                               int canvasW, int canvasH,
                               const QStringList &stillPhotos,
                               const QStringList &slotRecordDirs,
                               const QString &outputPath,
                               int fps, int maxLongEdge);

    // Chạy ffmpeg đồng bộ, gộp stdout+stderr vào *output, trả exit code (-1 nếu
    // không start được). Dùng chung cho các stage của process video.
    int runFfmpeg(const QStringList &args, QString *output);

    QString resolveFfmpegPath() const;
    void    cleanupTempDir(const QString &tempDir);
    static QByteArray escapeConcatPath(const QString &path);

    QFutureWatcher<QString> *m_watcher = nullptr;

    // Pool RIÊNG cho ffmpeg (1 luồng → encode tuần tự, KHÔNG chiếm slot của
    // global QThreadPool mà chụp ảnh / ghép ảnh đang dùng). Trước đây ffmpeg
    // (10–30s/video) chạy trên global pool → chụp ảnh bị xếp hàng, app "đơ".
    QThreadPool m_pool;

    QString m_ffmpegPath;   // empty = auto-detect
    int m_crf         = 23; // libx264 CRF quality (0=lossless, 51=worst, 23=default)
    int m_videoWidth  = 0;
    int m_videoHeight = 0;
};

#endif // VIDEOCREATOR_H
