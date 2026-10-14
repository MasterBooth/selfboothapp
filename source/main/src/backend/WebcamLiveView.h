#pragma once

#include <QObject>
#include <QImage>
#include <QString>
#include <QStringList>
#include <atomic>
#include <thread>
#include <memory>

class LiveViewImageProvider;

/**
 * WebcamLiveView — live view qua HDMI/webcam dùng OpenCV
 *
 * Scan các thiết bị capture, mở webcam theo index, đưa frame vào
 * cùng LiveViewImageProvider với SDK path. QML không cần thay đổi.
 *
 * Build với -DUSE_WEBCAM_LIVEVIEW=ON để bật OpenCV. Khi tắt, các
 * method vẫn compile nhưng trả về empty/false.
 */
class WebcamLiveView : public QObject
{
    Q_OBJECT

public:
    explicit WebcamLiveView(QObject *parent = nullptr);
    ~WebcamLiveView();

    // Scan các webcam khả dụng (index 0..9), trả về index DirectShow của thiết bị
    // đọc được frame. Không đụng trạng thái object → gọi được từ luồng nền.
    static QList<int> scanDevices();

    // Mở webcam theo index từ scanDevices(), bắt đầu streaming
    bool start(int deviceIndex);

    // Dừng streaming và giải phóng thiết bị
    void stop();

    bool isActive() const { return m_running.load(); }
    int currentDeviceIndex() const { return m_deviceIndex; }

    void setImageProvider(LiveViewImageProvider *provider) { m_imageProvider = provider; }

    // Cài đặt xử lý frame — đồng nhất với SDK decodeLoop. CameraController đẩy
    // các giá trị này xuống mỗi khi user thay đổi (có thể gọi khi đang chạy).
    void setMirror(bool on)       { m_mirror.store(on); }
    void setMaxWidth(int width)   { m_maxWidth.store(width); }
    void setTargetFps(int fps)    { m_targetFps.store(fps); }

    // Tự động phát hiện & crop viền đen (pillarbox/letterbox) trong tín hiệu HDMI.
    // Đặt false để tắt crop nếu cần. Đổi giá trị → tính lại ROI ở frame kế tiếp.
    void setAutoCrop(bool on)     { m_autoCrop.store(on); m_roiValid.store(false); }

signals:
    // Phát mỗi khi có frame mới — cùng tên với CameraController::frameReady
    // để LiveViewPanel có thể dùng chung Connections target
    void frameReady();
    // Luồng capture tự dừng (không mở được thiết bị / đọc frame lỗi). Phát từ
    // luồng capture → nối bằng QueuedConnection.
    void streamEnded();

private:
    void captureLoop();

    LiveViewImageProvider *m_imageProvider = nullptr;
    std::atomic<bool>      m_running{false};
    std::thread            m_thread;
    int                    m_deviceIndex = -1;

    // Cài đặt xử lý frame (mặc định trùng với decodeLoop khi không set)
    std::atomic<bool>      m_mirror{false};
    std::atomic<int>       m_maxWidth{960};
    std::atomic<int>       m_targetFps{30};

    // Auto-crop viền đen. ROI lưu dạng int (không phụ thuộc OpenCV trong header),
    // tính 1 lần và cache; tính lại khi đổi kích thước frame hoặc tắt/bật autoCrop.
    std::atomic<bool>      m_autoCrop{true};
    std::atomic<bool>      m_roiValid{false};
    int                    m_roiX = 0, m_roiY = 0, m_roiW = 0, m_roiH = 0;
    int                    m_lastFrameW = 0, m_lastFrameH = 0;
};
