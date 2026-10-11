#include "QrLoginManager.h"
#include "ConfigManager.h"
#include <QNetworkAccessManager>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QUrl>
#include <QDebug>

namespace {
constexpr int kPollIntervalMs = 2500;
// Thoát khỏi "waiting" nếu quá thời gian này mà vẫn chưa có mã QR.
constexpr int kWatchdogMs = 20000;

QNetworkRequest buildReq(ConfigManager *cfg, const QString &path) {
    QNetworkRequest req(QUrl(cfg->cloudApiBaseUrl() + path));
    req.setRawHeader("Content-Type", "application/json");
    req.setRawHeader("Authorization",
                     QByteArray("Bearer ") + cfg->cloudApiToken().toUtf8());
    req.setTransferTimeout(15000);
    return req;
}
} // namespace

QrLoginManager::QrLoginManager(ConfigManager *config, QObject *parent)
    : QObject(parent)
    , m_config(config)
{
    m_net = new QNetworkAccessManager(this);
    m_pollTimer.setInterval(kPollIntervalMs);
    connect(&m_pollTimer, &QTimer::timeout, this, &QrLoginManager::poll);
}

void QrLoginManager::setStatus(const QString &status, const QString &error) {
    m_status = status;
    m_errorText = error;
    emit stateChanged();
}

void QrLoginManager::start(const QString &hwid, const QString &purpose) {
    cancel();
    if (!m_config || !m_config->isValid()) {
        setStatus(QStringLiteral("error"), QStringLiteral("Chưa cấu hình kết nối máy chủ"));
        return;
    }
    // hwid rỗng sẽ tạo URL "/machine//qr-session" → worker trả 404 route-miss và
    // người dùng chỉ thấy vòng xoay. Báo lỗi rõ ràng thay vì gửi request vô nghĩa.
    if (hwid.trimmed().isEmpty()) {
        qWarning() << "[QrLogin] start() bị gọi khi chưa có HWID";
        setStatus(QStringLiteral("error"),
                  QStringLiteral("Chưa xác định được ID máy — thử lại sau giây lát."));
        return;
    }
    m_hwid = hwid;
    m_purpose = (purpose == QStringLiteral("security")) ? QStringLiteral("security")
                                                        : QStringLiteral("login");
    const int gen = ++m_generation;
    setStatus(QStringLiteral("waiting"));

    // Chốt chặn cuối: nếu sau kWatchdogMs vẫn chưa có mã (mạng treo ở tầng DNS/proxy,
    // reply không bao giờ về…) thì thoát khỏi trạng thái "waiting" để QML hiện nút
    // "Tạo mã mới" thay vì quay vòng vô hạn.
    QTimer::singleShot(kWatchdogMs, this, [this, gen]() {
        if (gen != m_generation) return;
        if (m_status == QStringLiteral("waiting") && m_qrData.isEmpty()) {
            qWarning() << "[QrLogin] watchdog: không nhận được mã QR sau" << kWatchdogMs << "ms";
            setStatus(QStringLiteral("error"),
                      QStringLiteral("Máy chủ không phản hồi — kiểm tra kết nối mạng."));
        }
    });

    const QJsonObject body{{QStringLiteral("purpose"), m_purpose}};
    QNetworkReply *reply = m_net->post(
        buildReq(m_config, QStringLiteral("/machine/%1/qr-session").arg(m_hwid)),
        QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply, gen]() {
        reply->deleteLater();
        if (gen != m_generation) return; // phiên đã bị hủy/tạo lại
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || !obj.value("success").toBool()) {
            // Ưu tiên thông điệp của máy chủ: 404 có thể là "máy chưa gắn studio" NHƯNG
            // cũng có thể là route sai — gán cứng một nhãn khiến chẩn đoán sai hướng.
            const QString serverMsg = obj.value("error").toString();
            const QString msg = !serverMsg.isEmpty()
                ? serverMsg
                : (http == 404
                       ? QStringLiteral("Máy chưa gắn studio — đăng nhập tài khoản studio trước.")
                       : QStringLiteral("Không tạo được mã QR (HTTP %1)").arg(http));
            qWarning() << "[QrLogin] create error: http=" << http << "msg=" << msg
                       << "net=" << reply->errorString();
            setStatus(QStringLiteral("error"), msg);
            return;
        }
        m_code = obj.value("code").toString();
        m_qrData = obj.value("qr_url").toString();
        // success=true nhưng thiếu code/qr_url → poll() sẽ early-return mãi mãi và
        // trạng thái kẹt ở "waiting" (vòng xoay vĩnh viễn). Phải báo lỗi ngay.
        if (m_code.isEmpty() || m_qrData.isEmpty()) {
            qWarning() << "[QrLogin] phản hồi thiếu code/qr_url:" << obj;
            m_code.clear();
            m_qrData.clear();
            setStatus(QStringLiteral("error"),
                      QStringLiteral("Máy chủ trả về mã QR không hợp lệ."));
            return;
        }
        m_expiresAt = QDateTime::fromString(obj.value("expires_at").toString(), Qt::ISODate);
        m_pollTimer.start();
        emit stateChanged();
    });
}

void QrLoginManager::cancel() {
    ++m_generation;
    m_pollTimer.stop();
    m_code.clear();
    m_qrData.clear();
    if (m_status != QStringLiteral("idle"))
        setStatus(QStringLiteral("idle"));
}

void QrLoginManager::poll() {
    if (m_code.isEmpty() || !m_config) return;
    // Hết hạn cục bộ (worker cũng tự expire) → dừng poll, cho QML hiện "Tạo mã mới".
    if (m_expiresAt.isValid() && QDateTime::currentDateTimeUtc() > m_expiresAt.toUTC()) {
        m_pollTimer.stop();
        setStatus(QStringLiteral("expired"));
        return;
    }
    const int gen = m_generation;
    QNetworkReply *reply = m_net->get(
        buildReq(m_config, QStringLiteral("/machine/%1/qr-session/%2").arg(m_hwid, m_code)));
    connect(reply, &QNetworkReply::finished, this, [this, reply, gen]() {
        reply->deleteLater();
        if (gen != m_generation) return;
        if (reply->error() != QNetworkReply::NoError) return; // lỗi mạng tạm — poll tiếp
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (!obj.value("success").toBool()) return;
        const QString st = obj.value("status").toString();
        if (st == QStringLiteral("approved")) {
            m_pollTimer.stop();
            consume(obj.value("approver").toObject().toVariantMap());
        } else if (st == QStringLiteral("expired") || st == QStringLiteral("used")) {
            m_pollTimer.stop();
            setStatus(QStringLiteral("expired"));
        }
    });
}

// Tiêu thụ mã đã approve (đánh dấu 'used' trên worker — chống dùng lại) rồi mới báo QML.
void QrLoginManager::consume(const QVariantMap &approver) {
    const int gen = m_generation;
    QNetworkReply *reply = m_net->post(
        buildReq(m_config, QStringLiteral("/machine/%1/qr-session/%2/consume").arg(m_hwid, m_code)),
        QByteArray("{}"));
    connect(reply, &QNetworkReply::finished, this, [this, reply, gen, approver]() {
        reply->deleteLater();
        if (gen != m_generation) return;
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        if (reply->error() != QNetworkReply::NoError || !obj.value("success").toBool()) {
            qWarning() << "[QrLogin] consume failed";
            setStatus(QStringLiteral("expired"));
            return;
        }
        setStatus(QStringLiteral("approved"));
        emit approved(approver.value("email").toString(),
                      approver.value("name").toString(),
                      approver.value("role").toString(),
                      m_purpose);
    });
}

void QrLoginManager::fetchStudioInfo(const QString &hwid) {
    m_studioInfo.clear();
    m_studioInfoError.clear();

    if (!m_config || !m_config->isValid()) {
        m_studioInfoLoading = false;
        m_studioInfoError = QStringLiteral("Chưa cấu hình kết nối máy chủ");
        emit studioInfoChanged();
        return;
    }

    m_studioInfoLoading = true;
    emit studioInfoChanged();
    QNetworkReply *reply = m_net->get(
        buildReq(m_config, QStringLiteral("/machine/%1/studio-info").arg(hwid)));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();
        const QNetworkReply::NetworkError netErr = reply->error();
        reply->deleteLater();

        m_studioInfoLoading = false;
        m_studioInfo.clear();
        m_studioInfoError.clear();

        const QJsonObject obj = QJsonDocument::fromJson(data).object();
        if (netErr != QNetworkReply::NoError) {
            m_studioInfoError = QStringLiteral("Không kết nối được máy chủ");
            qWarning() << "[QrLogin] studio-info network error:" << http << QString::fromUtf8(data);
        } else if (!obj.value("success").toBool()) {
            m_studioInfoError = obj.value("error").toString(
                QStringLiteral("Lỗi máy chủ (HTTP %1)").arg(http));
            qWarning() << "[QrLogin] studio-info api error:" << http << QString::fromUtf8(data);
        } else if (!obj.value("found").toBool(true)) {
            m_studioInfoError = QStringLiteral("Không tìm thấy máy trên máy chủ");
        } else if (obj.value("owner_email").toString().trimmed().isEmpty()) {
            m_studioInfoError = QStringLiteral("Máy chưa gắn studio");
            m_studioInfo = QVariantMap{
                {QStringLiteral("owner_email"), QString()},
                {QStringLiteral("owner_name"), obj.value("owner_name").toString()},
                {QStringLiteral("brand"), obj.value("brand").toString()},
                {QStringLiteral("staff"), QVariantList()},
                {QStringLiteral("loaded"), true},
            };
        } else {
            m_studioInfo = QVariantMap{
                {QStringLiteral("owner_email"), obj.value("owner_email").toString()},
                {QStringLiteral("owner_name"), obj.value("owner_name").toString()},
                {QStringLiteral("brand"), obj.value("brand").toString()},
                {QStringLiteral("staff"), obj.value("staff").toArray().toVariantList()},
                {QStringLiteral("loaded"), true},
            };
        }
        emit studioInfoChanged();
    });
}
