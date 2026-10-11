#ifndef LICENSESTORE_H
#define LICENSESTORE_H

#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

class ConfigManager;
class QNetworkAccessManager;
class QNetworkReply;

/**
 * @class LicenseStore
 * @brief Cầu nối QML ↔ Worker cho danh mục gói + thanh toán SePay.
 *
 * - fetchPlans(): tải gói đang bán + thông tin nhận tiền SePay (giá do admin chỉnh
 *   trên web, tự cập nhật xuống máy).
 * - createIntent(hwid, planCode): tạo intent → nhận mã + URL QR SePay theo số tiền.
 * - checkIntent(hwid, code): hỏi trạng thái thanh toán (app poll tới khi 'paid').
 *
 * Dùng cùng base URL + bearer token với DynamoDBClient (ConfigManager).
 */
class LicenseStore : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList plans READ plans NOTIFY plansChanged)
    Q_PROPERTY(QVariantMap  sepay READ sepay NOTIFY plansChanged)
    Q_PROPERTY(int trialDays READ trialDays NOTIFY plansChanged)
    Q_PROPERTY(int yearDiscountPct READ yearDiscountPct NOTIFY plansChanged)
    Q_PROPERTY(int discountFloorPct READ discountFloorPct NOTIFY plansChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit LicenseStore(ConfigManager *config, QObject *parent = nullptr);

    QVariantList plans() const { return m_plans; }
    QVariantMap  sepay() const { return m_sepay; }
    int  trialDays() const { return m_trialDays; }
    int  yearDiscountPct() const { return m_discountPct; }
    int  discountFloorPct() const { return m_discountFloor; }
    bool busy() const { return m_busy; }

    // Tổng tiền mua `years` năm của 1 gói, áp giảm giá theo năm (khớp Worker).
    Q_INVOKABLE int totalForYears(int pricePerYear, int years) const {
        const double disc = m_discountPct / 100.0, floor = m_discountFloor / 100.0;
        double mult = 0;
        for (int i = 0; i < qMax(1, years); ++i) mult += qMax(floor, 1.0 - disc * i);
        return qRound(pricePerYear * mult);
    }

    Q_INVOKABLE void fetchPlans();
    /** mode = "new" (mua/gia hạn `years` năm) hoặc "switch" (đổi gói). */
    Q_INVOKABLE void createIntent(const QString &hwid, const QString &planCode,
                                  int years = 1, const QString &mode = "new");
    Q_INVOKABLE void checkIntent(const QString &hwid, const QString &code);

signals:
    void plansChanged();
    void busyChanged();
    /** Tạo intent thành công: {code, amount, qr_url, content, bank, account, holder, kind}. */
    void intentCreated(const QVariantMap &intent);
    /** Đổi gói miễn phí (không phát sinh phí) → đã áp dụng ngay, không cần QR. */
    void switchApplied();
    /** Kết quả poll: status = 'pending' | 'paid' | 'expired' | 'notfound'. */
    void intentStatus(const QString &code, const QString &status);
    void errorOccurred(const QString &message);

private slots:
    void onReply(QNetworkReply *reply);

private:
    void setBusy(bool b);
    QString m_op;              // thao tác hiện tại để định tuyến onReply
    QString m_pendingCode;     // code intent đang poll

    ConfigManager *m_config;
    QNetworkAccessManager *m_net;

    QVariantList m_plans;
    QVariantMap  m_sepay;
    int  m_trialDays = 3;
    int  m_discountPct = 10;
    int  m_discountFloor = 70;
    bool m_busy = false;
};

#endif // LICENSESTORE_H
