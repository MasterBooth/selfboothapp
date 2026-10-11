#ifndef DYNAMODBCLIENT_H
#define DYNAMODBCLIENT_H

#include <QString>
#include <QObject>
#include <QVariantMap>
#include <QVariantList>
#include <QNetworkAccessManager>

class ConfigManager;
class QNetworkReply;

/**
 * @class DynamoDBClient
 * @brief Cloud machine/analytics client — gọi Cloudflare Worker REST API.
 *
 * (Trước đây ký SigV4 gọi thẳng AWS DynamoDB. Sau migration, gọi REST tới
 *  Worker + D1. Giữ nguyên tên class + chữ ký hàm + signals để
 *  MachineAuthenticator / EventManager không phải sửa.)
 *
 * Auth: header `Authorization: Bearer <machine_token>` từ ConfigManager::cloudApiToken().
 */
class DynamoDBClient : public QObject {
    Q_OBJECT

public:
    explicit DynamoDBClient(ConfigManager *config, QObject *parent = nullptr);
    ~DynamoDBClient();

    void getMachine(const QString &hwid);
    void registerMachine(const QString &hwid, const QString &deviceName,
                         const QString &ownerEmail = QString(),
                         const QString &ownerName  = QString(),
                         const QString &brand      = QString());
    /** Gắn email chủ + tên studio cho máy đã đăng ký (PATCH, không đụng activate). */
    void claimMachine(const QString &hwid, const QString &ownerEmail,
                      const QString &ownerName, const QString &brand);
    void syncEventData(const QString &hwid, int eventId, const QString &eventName,
                       int totalPhotos, int printsCut, int printsNoCut);
    void syncSessionData(const QString &hwid, int eventId, const QString &sessionId,
                         const QString &printerType, int photosCaptured,
                         int printsCut, int printsNoCut, const QString &status,
                         int expectedPhotos = 0,
                         const QString &captureStartedAt = QString(),
                         const QString &endedAt = QString(),
                         const QString &statusUpdatedAt = QString(),
                         const QString &failureCode = QString(),
                         const QString &failureMessage = QString(),
                         int cameraErrorCount = 0, bool hadCameraError = false,
                         int statusVersion = 1);
    void syncRevenueRecord(const QString &hwid, int eventId, const QString &eventName,
                           const QString &sessionId, const QString &recordedAt,
                           int printCount, int amountRequired,
                           int cashReceived, int transferAmount, int changeAmount,
                           const QString &paymentMethod, int employeeId,
                           const QString &shift, const QString &source,
                           int receivedAmount, int voucherAmount, const QString &note);

    // ── Voucher / mã tiền mặt toàn studio (cloud là nguồn chân lý) ─────────────
    // validate/redeem chạy ĐỒNG BỘ (blocking, QEventLoop) để giữ API đồng bộ cho QML.
    // Kết quả luôn kèm "network_error" (true nếu mất mạng/timeout) để gọi fallback local.
    QVariantMap validateVoucherCloud(const QString &hwid, const QString &code);
    QVariantMap redeemVoucherCloud(const QString &hwid, const QString &code,
                                   const QString &sessionId, int empId, int paidAmount);
    // Xoá 1 mã khỏi kho studio trên cloud (BLOCKING). Trả {success, deleted, network_error}.
    QVariantMap deleteVoucherCloud(const QString &hwid, const QString &code);
    // Async delete for voucher batch; result is emitted via voucherDeleteReady.
    void deleteVoucherCloudAsync(const QString &hwid, const QString &code, const QString &contextId);
    // Đẩy mã tạo từ local lên kho studio (BLOCKING; idempotent ở worker). Trả map JSON
    // kèm "network_error" để gọi biết có nên đánh dấu synced hay giữ lại retry sau.
    QVariantMap pushVouchersCloudSync(const QString &hwid, const QVariantList &vouchers);
    // Cloud sinh mã 4 số DUY NHẤT cho desktop (online). Trả {success, codes, network_error}.
    QVariantMap generateVouchersCloud(const QString &hwid, const QString &type, int value, int count,
                                      const QString &validFrom, const QString &validUntil,
                                      const QString &note, const QString &createdBy);
    // Kéo danh sách voucher toàn studio (ASYNC) — kết quả qua signal voucherListReady.
    void fetchVoucherList(const QString &hwid, const QString &filter);
    // Đọc preset ghi chú/giá/hiệu lực (BLOCKING) → {notes, prices, durations, network_error}.
    QVariantMap voucherPresetsCloud(const QString &hwid);

signals:
    // Danh sách voucher cloud đã về (ok=false nếu mất mạng/lỗi → gọi fallback local).
    void voucherListReady(const QVariantList &data, bool ok);
    void voucherDeleteReady(const QString &code, const QString &contextId, bool success,
                            bool networkError, const QString &error);
    void machineFound(const QString &hwid, const QVariantMap &data);
    void machineNotFound(const QString &hwid);
    void machineRegistered(const QString &hwid);
    void operationError(const QString &error);

private slots:
    void onNetworkReply(QNetworkReply *reply);

private:
    ConfigManager *m_config;
    QNetworkAccessManager *m_networkManager;
    QString m_currentHwid;
    // Build request tới Worker: {base_url}{path} + header Bearer + content-type JSON.
    QNetworkRequest buildRequest(const QString &path) const;
    // Gửi 1 request (GET / POST / PUT) với verb + payload tùy chọn.
    void sendRequest(const QString &verb, const QString &path,
                     const QJsonObject &payload, const QString &operation,
                     const QString &contextId = QString());
    // Request ĐỒNG BỘ (blocking) dùng cho validate/redeem voucher. Trả map JSON đã parse,
    // kèm "network_error"(bool) và "http"(int). Mạng lỗi/timeout → network_error=true.
    QVariantMap blockingRequest(const QString &verb, const QString &path,
                                const QJsonObject &payload);
};

#endif // DYNAMODBCLIENT_H
