#include "WebcamLiveView.h"
#include "LiveViewImageProvider.h"
#include <QDebug>
#include <chrono>
#include <thread>
#include <algorithm>

#ifdef USE_WEBCAM_LIVEVIEW
#include <opencv2/videoio.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/imgcodecs.hpp>

namespace {
// Phát hiện vùng nội dung (bỏ viền đen pillarbox/letterbox) trong tín hiệu HDMI.
// Trả về cv::Rect vùng "sáng"; nếu bất thường → trả full frame (an toàn).
//
// Cách làm: thu nhỏ tạm về width 320 cho nhẹ, chuyển gray, rồi quét từ mỗi mép
// vào trong — một hàng/cột bị coi là viền đen nếu ≥ 98% pixel của nó tối
// (< ngưỡng). Dừng ở hàng/cột đầu tiên không phải viền.
cv::Rect detectContentRect(const cv::Mat &bgr)
{
    const cv::Rect full(0, 0, bgr.cols, bgr.rows);
    if (bgr.empty())
        return full;

    constexpr int   kSmallW       = 320;   // width ảnh phân tích
    constexpr int   kBlackThresh  = 18;    // mức sáng coi là "đen" (0..255)
    constexpr double kBorderRatio = 0.98;  // tỉ lệ pixel tối để coi là viền

    // Thu nhỏ giữ tỉ lệ để phân tích nhanh
    double scale = static_cast<double>(kSmallW) / bgr.cols;
    if (scale > 1.0) scale = 1.0;
    cv::Mat small;
    cv::resize(bgr, small, cv::Size(), scale, scale, cv::INTER_AREA);

    cv::Mat gray;
    cv::cvtColor(small, gray, cv::COLOR_BGR2GRAY);

    const int W = gray.cols, H = gray.rows;
    auto colIsBorder = [&](int x) {
        int dark = 0;
        for (int y = 0; y < H; ++y)
            if (gray.at<uchar>(y, x) < kBlackThresh) ++dark;
        return dark >= static_cast<int>(H * kBorderRatio);
    };
    auto rowIsBorder = [&](int y) {
        int dark = 0;
        for (int x = 0; x < W; ++x)
            if (gray.at<uchar>(y, x) < kBlackThresh) ++dark;
        return dark >= static_cast<int>(W * kBorderRatio);
    };

    int left = 0;            while (left < W && colIsBorder(left))            ++left;
    int right = W - 1;       while (right > left && colIsBorder(right))       --right;
    int top = 0;             while (top < H && rowIsBorder(top))              ++top;
    int bottom = H - 1;      while (bottom > top && rowIsBorder(bottom))      --bottom;

    // Map về toạ độ gốc
    double inv = 1.0 / scale;
    int x0 = static_cast<int>(left   * inv);
    int y0 = static_cast<int>(top    * inv);
    int x1 = static_cast<int>((right  + 1) * inv);
    int y1 = static_cast<int>((bottom + 1) * inv);

    x0 = std::max(0, std::min(x0, bgr.cols - 1));
    y0 = std::max(0, std::min(y0, bgr.rows - 1));
    x1 = std::max(x0 + 1, std::min(x1, bgr.cols));
    y1 = std::max(y0 + 1, std::min(y1, bgr.rows));

    cv::Rect roi(x0, y0, x1 - x0, y1 - y0);

    // Kết quả bất thường (crop quá nhiều / quá ít) → trả full để an toàn
    if (roi.width  < bgr.cols / 2 || roi.height < bgr.rows / 2)
        return full;
    return roi;
}
} // namespace
#endif

WebcamLiveView::WebcamLiveView(QObject *parent)
    : QObject(parent)
{
}

WebcamLiveView::~WebcamLiveView()
{
    stop();
}

QStringList WebcamLiveView::scanDevices()
{
    QStringList devices;

#ifdef USE_WEBCAM_LIVEVIEW
    for (int i = 0; i < 10; ++i) {
        cv::VideoCapture cap;
        // CAP_DSHOW trên Windows cho phép truy cập HDMI capture card qua DirectShow
        if (cap.open(i, cv::CAP_DSHOW)) {
            // Thử đọc 1 frame để xác nhận thiết bị hoạt động
            cv::Mat frame;
            cap.read(frame);
            cap.release();
            if (!frame.empty()) {
                devices.append(QString("Camera %1").arg(i));
            }
        }
    }
    qDebug() << "WebcamLiveView: found" << devices.size() << "device(s)";
#else
    qDebug() << "WebcamLiveView: built without OpenCV — no devices available";
#endif

    return devices;
}

bool WebcamLiveView::start(int deviceIndex)
{
#ifdef USE_WEBCAM_LIVEVIEW
    stop();

    m_deviceIndex = deviceIndex;
    m_roiValid.store(false);   // tính lại ROI cho thiết bị mới
    m_running.store(true);
    m_thread = std::thread(&WebcamLiveView::captureLoop, this);
    qDebug() << "WebcamLiveView: started device" << deviceIndex;
    return true;
#else
    Q_UNUSED(deviceIndex)
    qDebug() << "WebcamLiveView: built without OpenCV — cannot start";
    return false;
#endif
}

void WebcamLiveView::stop()
{
    if (m_running.exchange(false)) {
        if (m_thread.joinable())
            m_thread.join();
        qDebug() << "WebcamLiveView: stopped";
    }
}

void WebcamLiveView::captureLoop()
{
#ifdef USE_WEBCAM_LIVEVIEW
    cv::VideoCapture cap;
    if (!cap.open(m_deviceIndex, cv::CAP_DSHOW)) {
        qWarning() << "WebcamLiveView: cannot open device" << m_deviceIndex;
        m_running.store(false);
        return;
    }

    // ── QUAN TRỌNG cho FPS: yêu cầu MJPG ────────────────────────────────────
    // Mặc định DirectShow trả ảnh RAW (YUY2) — 1920x1080 raw vượt băng thông USB
    // nên card tụt xuống ~5-25 FPS. Yêu cầu MJPG (nén) để đạt full 60 FPS giống
    // khi xem bằng app khác (OBS/Camera). Set FOURCC TRƯỚC khi set resolution.
    cap.set(cv::CAP_PROP_FOURCC, cv::VideoWriter::fourcc('M', 'J', 'P', 'G'));

    // Yêu cầu Full HD + 60fps; thiết bị tự điều chỉnh nếu không hỗ trợ.
    // (Trước đây ép 1280x720 khiến card letterbox; giờ dùng native rồi crop viền đen.)
    cap.set(cv::CAP_PROP_FRAME_WIDTH,  1920);
    cap.set(cv::CAP_PROP_FRAME_HEIGHT, 1080);
    cap.set(cv::CAP_PROP_FPS,          60);

    cv::Mat frame;
    bool loggedResolution = false;

    // Đo FPS riêng cho webcam (phân biệt với decodeLoop của SDK)
    auto   fpsTimer   = std::chrono::steady_clock::now();
    int    frameCount = 0;

    while (m_running.load()) {
        if (!cap.read(frame) || frame.empty()) {
            // Thiết bị bị ngắt kết nối
            qWarning() << "WebcamLiveView: frame read failed, stopping";
            break;
        }

        if (!loggedResolution) {
            qWarning() << "WebcamLiveView: capture resolution"
                       << frame.cols << "x" << frame.rows;
            loggedResolution = true;
        }

        // ── Auto-crop viền đen (pillarbox/letterbox của tín hiệu HDMI) ───────
        // Tính ROI 1 lần và cache; tính lại nếu đổi kích thước frame hoặc khi
        // m_roiValid bị reset (đổi setting autoCrop).
        if (m_autoCrop.load()) {
            if (!m_roiValid.load()
                || frame.cols != m_lastFrameW || frame.rows != m_lastFrameH) {
                cv::Rect roi = detectContentRect(frame);
                m_roiX = roi.x; m_roiY = roi.y; m_roiW = roi.width; m_roiH = roi.height;
                m_lastFrameW = frame.cols; m_lastFrameH = frame.rows;
                m_roiValid.store(true);
                qWarning() << "WebcamLiveView: content ROI ="
                           << m_roiX << m_roiY << m_roiW << m_roiH
                           << "(from" << frame.cols << "x" << frame.rows << ")";
            }
            if (m_roiW > 0 && m_roiH > 0
                && (m_roiW != frame.cols || m_roiH != frame.rows)) {
                frame = frame(cv::Rect(m_roiX, m_roiY, m_roiW, m_roiH));
            }
        }

        // OpenCV trả BGR, Qt cần RGB
        cv::Mat rgb;
        cv::cvtColor(frame, rgb, cv::COLOR_BGR2RGB);

        QImage qimg(
            rgb.data,
            rgb.cols, rgb.rows,
            static_cast<int>(rgb.step),
            QImage::Format_RGB888
        );
        // deep copy trước khi cv::Mat bị overwrite ở vòng lặp tiếp theo
        qimg = qimg.copy();

        // ── Downscale theo max width (giống decodeLoop của SDK) ──────────────
        int maxW = m_maxWidth.load();
        if (maxW > 0 && qimg.width() > maxW) {
            qimg = qimg.scaled(maxW,
                               qimg.height() * maxW / qimg.width(),
                               Qt::KeepAspectRatio,
                               Qt::FastTransformation);
        }

        // ── Mirror mode (giống decodeLoop của SDK) ───────────────────────────
        if (m_mirror.load()) {
            qimg = qimg.mirrored(true, false);
        }

        if (m_imageProvider)
            m_imageProvider->setImage(qimg);

        emit frameReady();

        // ── KHÔNG throttle: chạy theo native FPS của card (mượt nhất) ─────────
        // cap.read() đã tự blocking theo nhịp frame của capture card nên vòng lặp
        // không busy-spin. Bỏ sleep để không tự hạ FPS xuống dưới native.
        if (++frameCount >= 120) {
            auto now = std::chrono::steady_clock::now();
            auto ms  = std::chrono::duration_cast<std::chrono::milliseconds>(
                now - fpsTimer).count();
            if (ms > 0) {
                qWarning() << "[WebcamLiveView] FPS:" << (frameCount * 1000LL / ms)
                           << "| frames:" << frameCount << "over" << ms << "ms";
            }
            frameCount = 0;
            fpsTimer   = now;
        }
    }

    cap.release();
    m_running.store(false);
#endif
}
