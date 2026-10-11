#include "VideoCreator.h"

#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QImage>
#include <QDebug>
#include <QProcess>
#include <QCoreApplication>
#include <QTextStream>
#include <QDateTime>
#include <QRegularExpression>
#include <QtConcurrent>
#include <QFutureWatcher>
#include <QBuffer>
#include <QStandardPaths>
#include <QVariant>
#include <QVariantMap>
#include <QVector>
#include <QPair>
#ifdef Q_OS_WIN
#include <windows.h>
#include <io.h>
#endif

// ---------------------------------------------------------------------------

VideoCreator::VideoCreator(QObject *parent) : QObject(parent)
{
    // 1 luồng: ffmpeg encode tuần tự, cách ly khỏi global thread pool.
    m_pool.setMaxThreadCount(1);

    m_watcher = new QFutureWatcher<QString>(this);

    connect(m_watcher, &QFutureWatcher<QString>::finished, this, [this]() {
        QString err = m_watcher->result();
        if (err.isEmpty()) {
            QString outPath = m_watcher->property("outputPath").toString();
            qDebug() << "[VideoCreator] Done:" << outPath;
            emit videoCreationFinished(outPath);
        } else {
            qCritical() << "[VideoCreator] Error:" << err;
            emit videoCreationError(err);
        }
    });
}

VideoCreator::~VideoCreator()
{
    if (m_watcher->isRunning())
        m_watcher->waitForFinished();
}

// ---------------------------------------------------------------------------

QString VideoCreator::resolveFfmpegPath() const
{
    if (!m_ffmpegPath.isEmpty() && QFile::exists(m_ffmpegPath))
        return m_ffmpegPath;

    // 1. Dùng GetModuleFileName để lấy path exe chính xác tuyệt đối.
    //    QCoreApplication::applicationDirPath() có thể trả sai khi shortcut
    //    RunAsAdmin thay đổi working directory trên Windows.
#ifdef Q_OS_WIN
    wchar_t buf[32768] = {};
    DWORD len = GetModuleFileNameW(nullptr, buf, 32767);
    if (len > 0) {
        QString exePath = QDir::fromNativeSeparators(QString::fromWCharArray(buf, len));
        QString candidate = QFileInfo(exePath).absolutePath() + "/ffmpeg.exe";
        qDebug() << "[VideoCreator] resolveFfmpegPath: exe=" << exePath
                 << "candidate=" << candidate
                 << "exists=" << QFile::exists(candidate);
        if (QFile::exists(candidate)) return candidate;
    }
#endif

    // 2. Fallback: applicationDirPath
    QString appDir = QCoreApplication::applicationDirPath();
    QString candidate = appDir + "/ffmpeg.exe";
    qDebug() << "[VideoCreator] resolveFfmpegPath fallback: appDir=" << appDir
             << "exists=" << QFile::exists(candidate);
    if (QFile::exists(candidate)) return candidate;

    // 3. PATH system
    return "ffmpeg.exe";
}

bool VideoCreator::isFfmpegAvailable()
{
    QString ffmpeg = resolveFfmpegPath();
    QProcess proc;
    proc.start(ffmpeg, {"-version"});
    proc.waitForFinished(5000);
    return proc.exitCode() == 0;
}

// ---------------------------------------------------------------------------

void VideoCreator::createVideoFromImages(const QStringList &imagePaths,
                                          const QString &outputPath,
                                          int fps,
                                          int maxLongEdge)
{
    if (imagePaths.isEmpty()) {
        emit videoCreationError("No images provided");
        return;
    }

    int clampedMax = (maxLongEdge > 0) ? qBound(1080, maxLongEdge, 4320) : 0;

    emit videoCreationStarted();
    qDebug() << "[VideoCreator] Queuing FFmpeg encode —" << imagePaths.count()
             << "photos ->" << outputPath << "| maxLongEdge:" << clampedMax;

    m_watcher->setProperty("outputPath", outputPath);

    QFuture<QString> future = QtConcurrent::run(
        &m_pool,
        [this, imagePaths, outputPath, fps, clampedMax]() {
            return encodeWithFfmpeg(imagePaths, outputPath, fps, clampedMax);
        });

    m_watcher->setFuture(future);
}

// ---------------------------------------------------------------------------

void VideoCreator::createProcessVideo(const QString &framePng,
                                      const QVariantList &slotList,
                                      int canvasW, int canvasH,
                                      const QStringList &stillPhotos,
                                      const QStringList &slotRecordDirs,
                                      const QString &outputPath,
                                      int fps,
                                      int maxLongEdge)
{
    if (slotList.isEmpty()) {
        emit videoCreationError("No slots provided for process video");
        return;
    }

    int clampedMax = (maxLongEdge > 0) ? qBound(720, maxLongEdge, 4320) : 0;

    emit videoCreationStarted();
    qDebug() << "[VideoCreator] Queuing process video —" << slotList.count()
             << "slots ->" << outputPath << "| canvas" << canvasW << "x" << canvasH
             << "| maxLongEdge:" << clampedMax;

    m_watcher->setProperty("outputPath", outputPath);

    QFuture<QString> future = QtConcurrent::run(
        &m_pool,
        [=]() {
            return encodeProcessVideo(framePng, slotList, canvasW, canvasH,
                                      stillPhotos, slotRecordDirs, outputPath,
                                      fps, clampedMax);
        });

    m_watcher->setFuture(future);
}

// ---------------------------------------------------------------------------

int VideoCreator::runFfmpeg(const QStringList &args, QString *output)
{
    QString ffmpeg = resolveFfmpegPath();

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.setProgram(ffmpeg);
    proc.setArguments(args);

    qDebug() << "[VideoCreator] ffmpeg" << args.join(" ");

    proc.start();
    if (!proc.waitForStarted(10000)) {
        if (output) *output = proc.errorString();
        return -1;
    }
    proc.waitForFinished(-1);
    if (output) *output = QString::fromLocal8Bit(proc.readAll());
    return proc.exitCode();
}

// ---------------------------------------------------------------------------

QByteArray VideoCreator::escapeConcatPath(const QString &path)
{
    QString p = QDir::fromNativeSeparators(path);
    p.replace("\\", "\\\\");
    p.replace("'", "'\\''");
    return p.toUtf8();
}

// ---------------------------------------------------------------------------

QString VideoCreator::encodeWithFfmpeg(const QStringList &imagePaths,
                                        const QString &outputPath,
                                        int fps,
                                        int maxLongEdge)
{
    QString ffmpeg = resolveFfmpegPath();
    if (!QFile::exists(ffmpeg) && ffmpeg != "ffmpeg.exe") {
        return QString("ffmpeg.exe not found. Expected at: %1").arg(
            QCoreApplication::applicationDirPath() + "/ffmpeg.exe");
    }

    // ── 1. Validate ảnh đầu vào ──────────────────────────────────────────────
    for (const QString &p : imagePaths) {
        if (!QFile::exists(p))
            return QString("Image not found: %1").arg(p);
    }

    QDir().mkpath(QFileInfo(outputPath).absolutePath());

    // ── 2. Tính frame size từ ảnh đầu tiên ───────────────────────────────────
    QImage first(imagePaths.first());
    if (first.isNull())
        return QString("Cannot load first image: %1").arg(imagePaths.first());

    int frameW = (m_videoWidth  > 0) ? m_videoWidth  : first.width();
    int frameH = (m_videoHeight > 0) ? m_videoHeight : first.height();

    if (maxLongEdge > 0) {
        int longEdge = qMax(frameW, frameH);
        if (longEdge > maxLongEdge) {
            double ratio = (double)maxLongEdge / longEdge;
            frameW = (int)(frameW * ratio);
            frameH = (int)(frameH * ratio);
        }
    }
    // libx264 yêu cầu chiều chia hết cho 2
    frameW = (frameW / 2) * 2;
    frameH = (frameH / 2) * 2;

    qDebug() << "[VideoCreator] Frame size:" << frameW << "x" << frameH
             << "| FPS:" << fps << "| CRF:" << m_crf;

    // ── 3. Temp dir: dùng AppLocalData (C:\Users\...\AppData\Local\VietBoothEvent)
    // KHÔNG dùng Program Files hay %TEMP% system — cả hai đều bị AV scan real-time
    // khi chạy elevated từ installed path → JPEG bị lock giữa chừng → corrupt.
    // AppLocalData là user-writable, không bị AV scan real-time, không cần elevation.
    emit videoCreationProgress(5);

    QString ts = QString::number(QDateTime::currentMSecsSinceEpoch());
    QString tempDir = QDir::fromNativeSeparators(
        QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
        + "/tmp_video_" + ts);

    if (!QDir().mkpath(tempDir)) {
        // Fallback nếu AppLocalData không tạo được
        tempDir = QDir::fromNativeSeparators(
            QDir::homePath() + "/AppData/Local/Temp/vb_" + ts);
        QDir().mkpath(tempDir);
    }
    qDebug() << "[VideoCreator] tempDir:" << tempDir;

    // ── 4. Scale ảnh, encode JPEG trong RAM, ghi nguyên khối xuống disk ──────
    // Encode trước vào QByteArray (RAM) → write() 1 lần duy nhất → không có
    // partial-write window để AV chen vào giữa chừng.
    QStringList scaledPaths;
    int total = imagePaths.count();
    for (int i = 0; i < total; ++i) {
        QImage img(imagePaths[i]);
        if (img.isNull()) {
            qWarning() << "[VideoCreator] Skipping unreadable:" << imagePaths[i];
            continue;
        }

        QImage scaled = img.scaled(frameW, frameH,
                                   Qt::KeepAspectRatioByExpanding,
                                   Qt::SmoothTransformation);
        if (scaled.width() != frameW || scaled.height() != frameH)
            scaled = scaled.copy((scaled.width()  - frameW) / 2,
                                 (scaled.height() - frameH) / 2,
                                 frameW, frameH);

        // 1. Encode JPEG vào RAM trước
        QByteArray jpegData;
        {
            QBuffer buf(&jpegData);
            buf.open(QIODevice::WriteOnly);
            if (!scaled.save(&buf, "JPEG", 92)) {
                cleanupTempDir(tempDir);
                return QString("Failed to encode JPEG for frame %1").arg(i);
            }
        }

        // 2. Ghi toàn bộ vào file 1 lần, flush ngay
        QString dest = QString("%1/frame_%2.jpg").arg(tempDir).arg(i, 4, 10, QChar('0'));
        {
            QFile f(QDir::toNativeSeparators(dest));
            if (!f.open(QIODevice::WriteOnly)) {
                cleanupTempDir(tempDir);
                return QString("Cannot open frame for writing: %1").arg(dest);
            }
            qint64 written = f.write(jpegData);
            f.flush();
#ifdef Q_OS_WIN
            FlushFileBuffers((HANDLE)_get_osfhandle(f.handle()));
#endif
            f.close();

            if (written != jpegData.size()) {
                cleanupTempDir(tempDir);
                return QString("Short write on frame %1: %2/%3 bytes")
                           .arg(i).arg(written).arg(jpegData.size());
            }
        }

        scaledPaths.append(dest);

        int pct = 5 + (int)(((i + 1) * 25LL) / total);
        emit videoCreationProgress(pct);
    }

    if (scaledPaths.isEmpty()) {
        cleanupTempDir(tempDir);
        return "No valid images to encode";
    }

    // ── 5. Tạo concat list — mỗi ảnh 0.4s, lặp 2 vòng ───────────────────────
    const double durationPerImage = 0.4;
    const int    loopCount        = 2;

    // concat list phải dùng forward slash và UTF-8 không BOM, không CRLF
    QString listPath = tempDir + "/concat_list.txt";
    {
        QFile listFile(QDir::toNativeSeparators(listPath));
        if (!listFile.open(QIODevice::WriteOnly)) {
            cleanupTempDir(tempDir);
            return "Cannot create concat list file";
        }
        QByteArray content;
        for (int loop = 0; loop < loopCount; ++loop) {
            for (const QString &p : scaledPaths) {
                content += "file '" + escapeConcatPath(p) + "'\n";
                content += "duration " + QByteArray::number(durationPerImage) + "\n";
            }
        }
        // repeat dòng cuối để tránh drop frame cuối (FFmpeg concat quirk)
        content += "file '" + escapeConcatPath(scaledPaths.last()) + "'\n";
        listFile.write(content);
        listFile.close();
    }

    emit videoCreationProgress(35);

    // ── 6. Chạy FFmpeg ────────────────────────────────────────────────────────
    QFile::remove(outputPath);

    // -i nhận forward-slash path — QProcess không đi qua shell nên không cần escape
    QStringList args;
    args << "-y"
         << "-f"    << "concat"
         << "-safe" << "0"
         << "-i"    << listPath           // forward slash, không native
         << "-vf"   << QString("fps=%1").arg(fps)
         << "-vcodec" << "libx264"
         << "-crf"    << QString::number(m_crf)
         << "-preset" << "fast"
         << "-pix_fmt"   << "yuv420p"
         << "-movflags"  << "+faststart"
         << outputPath;

    // ── DEBUG: log concat list và args để so sánh bin/release vs installed ────
    qDebug() << "[VideoCreator] tempDir:" << tempDir;
    qDebug() << "[VideoCreator] listPath:" << listPath;
    qDebug() << "[VideoCreator] FFmpeg path:" << ffmpeg;
    qDebug() << "[VideoCreator] FFmpeg args:" << args.join(" ");
    {
        QFile dbg(QDir::toNativeSeparators(listPath));
        if (dbg.open(QIODevice::ReadOnly)) {
            qDebug() << "[VideoCreator] concat_list.txt:\n" << dbg.readAll();
            dbg.close();
        }
        for (const QString &p : scaledPaths) {
            QFileInfo fi(QDir::toNativeSeparators(p));
            qDebug() << "[VideoCreator] frame:" << p
                     << "exists=" << fi.exists()
                     << "size=" << fi.size();
        }
    }

    int totalFrames = qMax(1, (int)(scaledPaths.count() * loopCount * durationPerImage * fps));

    QProcess proc;
    proc.setProcessChannelMode(QProcess::MergedChannels);
    proc.setProgram(ffmpeg);
    proc.setArguments(args);
    proc.start();

    if (!proc.waitForStarted(10000)) {
        cleanupTempDir(tempDir);
        return QString("Failed to start ffmpeg: %1").arg(proc.errorString());
    }

    // Theo dõi progress qua stderr của FFmpeg (frame=N)
    int lastPct = 35;
    while (!proc.waitForFinished(500)) {
        QString output = QString::fromLocal8Bit(proc.readAll());
        // Parse "frame=  NNN" từ FFmpeg progress output
        QRegularExpression re("frame=\\s*(\\d+)");
        auto match = re.match(output);
        if (match.hasMatch() && totalFrames > 0) {
            int frame = match.captured(1).toInt();
            int pct = 35 + (int)((double)frame / totalFrames * 60.0);
            if (pct > lastPct && pct <= 95) {
                lastPct = pct;
                emit videoCreationProgress(pct);
            }
        }
    }

    QString ffmpegOutput = QString::fromLocal8Bit(proc.readAll());
    int exitCode = proc.exitCode();

    qDebug() << "[VideoCreator] FFmpeg exit:" << exitCode;
    qDebug() << "[VideoCreator] FFmpeg output:\n" << ffmpegOutput;

    // Dọn temp files
    cleanupTempDir(tempDir);

    if (exitCode != 0) {
        qCritical() << "[VideoCreator] FFmpeg failed (exit" << exitCode << "):" << ffmpegOutput;
        return QString("FFmpeg encoding failed (exit code %1).\n%2")
               .arg(exitCode).arg(ffmpegOutput.right(500));
    }

    if (!QFile::exists(outputPath)) {
        return QString("FFmpeg exited OK but output file not found: %1").arg(outputPath);
    }

    emit videoCreationProgress(100);
    qDebug() << "[VideoCreator] FFmpeg encode complete:" << outputPath
             << "| Size:" << QFileInfo(outputPath).size() / 1024 << "KB";

    return QString(); // empty = success
}

// ---------------------------------------------------------------------------
// Process video: frame overlay + mỗi slot phát clip "quá trình tạo dáng".
// 2 giai đoạn: (1) dựng clip mỗi slot dài chuẩn = T; (2) overlay tất cả + frame.
// ---------------------------------------------------------------------------

QString VideoCreator::encodeProcessVideo(const QString &framePng,
                                         const QVariantList &slotList,
                                         int canvasW, int canvasH,
                                         const QStringList &stillPhotos,
                                         const QStringList &slotRecordDirs,
                                         const QString &outputPath,
                                         int fps, int maxLongEdge)
{
    QString ffmpeg = resolveFfmpegPath();
    if (!QFile::exists(ffmpeg) && ffmpeg != "ffmpeg.exe")
        return QString("ffmpeg.exe not found. Expected at: %1")
                   .arg(QCoreApplication::applicationDirPath() + "/ffmpeg.exe");

    if (canvasW <= 0 || canvasH <= 0)
        return QString("Invalid canvas size %1x%2").arg(canvasW).arg(canvasH);

    const int n = slotList.count();
    QDir().mkpath(QFileInfo(outputPath).absolutePath());
    emit videoCreationProgress(3);

    // ── Scale canvas + slots theo maxLongEdge; libx264 cần chiều chẵn ────────
    auto even = [](int v){ v = (v / 2) * 2; return v < 2 ? 2 : v; };
    double ratio = 1.0;
    if (maxLongEdge > 0) {
        int longEdge = qMax(canvasW, canvasH);
        if (longEdge > maxLongEdge) ratio = (double)maxLongEdge / longEdge;
    }
    int Wv = even((int)qRound(canvasW * ratio));
    int Hv = even((int)qRound(canvasH * ratio));

    struct SlotRect { int x, y, w, h; };
    QVector<SlotRect> rects;
    rects.reserve(n);
    for (int i = 0; i < n; ++i) {
        QVariantMap m = slotList[i].toMap();
        int sx = (int)qRound(m.value("x").toInt()      * ratio);
        int sy = (int)qRound(m.value("y").toInt()      * ratio);
        int sw = even((int)qRound(m.value("width").toInt()  * ratio));
        int sh = even((int)qRound(m.value("height").toInt() * ratio));
        if (sx < 0) sx = 0;
        if (sy < 0) sy = 0;
        if (sx + sw > Wv) sw = even(Wv - sx);
        if (sy + sh > Hv) sh = even(Hv - sy);
        if (sw < 2) sw = 2;
        if (sh < 2) sh = 2;
        rects.append({sx, sy, sw, sh});
    }

    // ── Temp dir (AppLocalData — không bị AV scan, giống encodeWithFfmpeg) ──
    QString ts = QString::number(QDateTime::currentMSecsSinceEpoch());
    QString tempDir = QDir::fromNativeSeparators(
        QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)
        + "/tmp_pvideo_" + ts);
    if (!QDir().mkpath(tempDir)) {
        tempDir = QDir::fromNativeSeparators(QDir::homePath() + "/AppData/Local/Temp/pv_" + ts);
        QDir().mkpath(tempDir);
    }

    // ── 1. Đọc manifest mỗi slot → concat list + thời lượng; tính T = max ───
    QVector<double>  recDur(n, 0.0);
    QVector<QString> recConcat(n);
    double T = 0.0;
    for (int i = 0; i < n; ++i) {
        QString dir = (i < slotRecordDirs.size())
                      ? QDir::fromNativeSeparators(slotRecordDirs[i]) : QString();
        if (dir.isEmpty()) continue;

        QFile mf(QDir::toNativeSeparators(dir + "/manifest.txt"));
        if (!mf.open(QIODevice::ReadOnly)) continue;

        QList<QPair<QString, qint64>> frames;
        while (!mf.atEnd()) {
            QByteArray ln = mf.readLine().trimmed();
            if (ln.isEmpty()) continue;
            int sp = ln.lastIndexOf(' ');
            if (sp <= 0) continue;
            frames.append({ QString::fromUtf8(ln.left(sp)), ln.mid(sp + 1).toLongLong() });
        }
        mf.close();
        if (frames.size() < 2) continue;   // cần ≥2 frame để có thời lượng

        QString listPath = tempDir + QString("/rec_%1.txt").arg(i);
        QFile lf(QDir::toNativeSeparators(listPath));
        if (!lf.open(QIODevice::WriteOnly)) continue;

        QByteArray content;
        double total = 0.0;
        for (int k = 0; k < frames.size(); ++k) {
            double d = (k + 1 < frames.size())
                       ? (frames[k + 1].second - frames[k].second) / 1000.0
                       : 1.0 / fps;
            if (d < 0.001) d = 0.001;
            total += d;
            content += "file '" + escapeConcatPath(dir + "/" + frames[k].first) + "'\n";
            content += "duration " + QByteArray::number(d, 'f', 4) + "\n";
        }
        // repeat dòng cuối để tránh drop frame cuối (FFmpeg concat quirk)
        content += "file '" + escapeConcatPath(dir + "/" + frames.last().first) + "'\n";
        lf.write(content);
        lf.close();

        recConcat[i] = listPath;
        recDur[i]    = total;
        if (total > T) T = total;
    }
    if (T <= 0.01) T = 4.0;   // không có bản ghi nào → video tĩnh 4s

    qDebug() << "[VideoCreator] process video T=" << T << "s | canvas"
             << Wv << "x" << Hv << "| slots:" << n;
    emit videoCreationProgress(10);

    // ── 2. Stage 1: dựng clip mỗi slot, độ dài chuẩn hoá = T ────────────────
    QStringList clipPaths;
    for (int i = 0; i < n; ++i) {
        const SlotRect &r = rects[i];
        QString clipPath = tempDir + QString("/clip_%1.mp4").arg(i);
        // cover-crop về đúng kích thước slot (giống KeepAspectRatioByExpanding)
        QString crop = QString("scale=%1:%2:force_original_aspect_ratio=increase,"
                               "crop=%1:%2,setsar=1").arg(r.w).arg(r.h);

        QString still = (i < stillPhotos.size())
                        ? QDir::fromNativeSeparators(stillPhotos[i]) : QString();
        bool hasStill = !still.isEmpty() && QFile::exists(still);

        QStringList a;
        a << "-y";
        QString filter;

        if (!recConcat[i].isEmpty()) {
            a << "-f" << "concat" << "-safe" << "0" << "-i" << recConcat[i];
            double pad = T - recDur[i];
            if (hasStill && pad > 0.05) {
                // clip ghi + freeze ảnh tĩnh (cùng cover-crop ⇒ chuyển liền mạch)
                a << "-loop" << "1" << "-t" << QString::number(pad, 'f', 3) << "-i" << still;
                filter = QString("[0:v]fps=%1,%2[c0];[1:v]fps=%1,%2[c1];"
                                 "[c0][c1]concat=n=2:v=1:a=0[v]").arg(fps).arg(crop);
            } else {
                filter = QString("[0:v]fps=%1,%2[v]").arg(fps).arg(crop);
            }
        } else if (hasStill) {
            // fallback: không ghi được → clip tĩnh từ ảnh chụp, dài T
            a << "-loop" << "1" << "-t" << QString::number(T, 'f', 3) << "-i" << still;
            filter = QString("[0:v]fps=%1,%2[v]").arg(fps).arg(crop);
        } else {
            // không có gì → ô đen dài T
            a << "-f" << "lavfi" << "-i"
              << QString("color=black:s=%1x%2:d=%3:r=%4")
                     .arg(r.w).arg(r.h).arg(QString::number(T, 'f', 3)).arg(fps);
            filter = "[0:v]setsar=1[v]";
        }

        a << "-filter_complex" << filter
          << "-map" << "[v]"
          << "-t" << QString::number(T, 'f', 3)
          << "-r" << QString::number(fps)
          << "-vcodec" << "libx264" << "-crf" << QString::number(m_crf)
          << "-preset" << "fast" << "-pix_fmt" << "yuv420p"
          << clipPath;

        QString out;
        int ec = runFfmpeg(a, &out);
        if (ec != 0 || !QFile::exists(clipPath)) {
            cleanupTempDir(tempDir);
            return QString("Stage1 clip %1 failed (exit %2):\n%3")
                       .arg(i).arg(ec).arg(out.right(600));
        }
        clipPaths.append(clipPath);
        emit videoCreationProgress(10 + (int)((i + 1) * 50LL / qMax(1, n)));
    }

    // ── 3. Stage 2: overlay tất cả clip + frame PNG lên canvas trắng ────────
    QFile::remove(outputPath);

    QStringList a;
    a << "-y";
    a << "-f" << "lavfi" << "-i"
      << QString("color=white:s=%1x%2:d=%3:r=%4")
             .arg(Wv).arg(Hv).arg(QString::number(T, 'f', 3)).arg(fps);   // input 0 = bg
    for (const QString &cp : clipPaths)
        a << "-i" << cp;                                                   // input 1..n = clips
    bool hasFrame = !framePng.isEmpty()
                    && QFile::exists(QDir::fromNativeSeparators(framePng));
    if (hasFrame)
        a << "-loop" << "1" << "-i" << QDir::fromNativeSeparators(framePng); // input n+1 = frame

    QString fg;
    QString cur = "[0:v]";
    for (int i = 0; i < clipPaths.size(); ++i) {
        QString lbl = QString("[ov%1]").arg(i);
        fg += QString("%1[%2:v]overlay=%3:%4%5;")
                  .arg(cur).arg(i + 1).arg(rects[i].x).arg(rects[i].y).arg(lbl);
        cur = lbl;
    }
    if (hasFrame) {
        int frameIdx = 1 + clipPaths.size();
        fg += QString("[%1:v]scale=%2:%3[fr];").arg(frameIdx).arg(Wv).arg(Hv);
        fg += QString("%1[fr]overlay=0:0[out]").arg(cur);
    } else {
        fg += QString("%1null[out]").arg(cur);
    }

    a << "-filter_complex" << fg
      << "-map" << "[out]"
      << "-t" << QString::number(T, 'f', 3)
      << "-r" << QString::number(fps)
      << "-vcodec" << "libx264" << "-crf" << QString::number(m_crf)
      << "-preset" << "fast" << "-pix_fmt" << "yuv420p"
      << "-movflags" << "+faststart"
      << outputPath;

    emit videoCreationProgress(70);
    QString out;
    int ec = runFfmpeg(a, &out);

    cleanupTempDir(tempDir);

    if (ec != 0 || !QFile::exists(outputPath)) {
        qCritical() << "[VideoCreator] process video stage2 failed:" << out.right(800);
        return QString("Stage2 composite failed (exit %1):\n%2").arg(ec).arg(out.right(800));
    }

    emit videoCreationProgress(100);
    qDebug() << "[VideoCreator] process video complete:" << outputPath
             << "| Size:" << QFileInfo(outputPath).size() / 1024 << "KB";
    return QString();   // empty = success
}

void VideoCreator::cleanupTempDir(const QString &tempDir)
{
    QDir dir(tempDir);
    if (dir.exists())
        dir.removeRecursively();
}
