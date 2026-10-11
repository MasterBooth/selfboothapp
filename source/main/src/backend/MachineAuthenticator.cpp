#include "MachineAuthenticator.h"
#include "DatabaseManager.h"
#include "DynamoDBClient.h"
#include "ConfigManager.h"
#include "LicenseManager.h"
#include <QDebug>
#include <QNetworkInterface>
#include <QCryptographicHash>
#include <QTimer>
#include <QSettings>
#include <windows.h>
#include <intrin.h>

// ─────────────────────────────────────────────────────────────────────────────
// BỎ XÁC THỰC MÁY (HWID)
//
// true  → máy LUÔN được coi là đã kích hoạt, mở toàn bộ capabilities, không phụ
//         thuộc DynamoDB/Worker. App vẫn chạy bình thường khi server sập.
// false → quay lại chế độ cũ: bắt buộc online, activate=true và chưa hết hạn.
//
// HWID vẫn được sinh và dùng làm định danh máy (đường dẫn S3, gallery, doanh thu,
// đăng nhập QR...) — chỉ bỏ phần *kiểm tra quyền* dựa trên HWID.
// Khi bật bypass, app vẫn thử gọi Worker ở chế độ "best-effort" để lấy studio_id
// (tiền tố URL gallery) và đăng ký máy vào bảng quản trị, nhưng MỌI lỗi mạng hay
// trạng thái chưa kích hoạt đều bị bỏ qua, không bao giờ chặn người dùng.
static constexpr bool kBypassMachineAuth = true;

// ─────────────────────────────────────────────────────────────────────────────
// Cưỡng chế giấy phép ký số (LicenseManager).
//
//   false → CHỈ ĐỐI CHIẾU VÀ GHI LOG. Quyền thực tế vẫn do bypass cấp.
//   true  → giấy phép là nguồn quyền duy nhất; không có giấy phép hợp lệ thì
//           máy không được cấp quyền, bất kể máy chủ nói gì.
//
// Bật cho bản PTB: máy không có chữ ký hợp lệ dừng ở màn nhập OTP
// (qml/pages/ActivationScreen.qml). Bản main / selfbooth vẫn chỉ đối chiếu.
//
// Khoá công khai trong LicenseManager.cpp PHẢI là khoá thật do app admin sinh ra
// (không phải khoá dev) trước khi phát hành bản PTB.
// ─────────────────────────────────────────────────────────────────────────────
#if defined(PHOTOBOOTH_ONLY)
static constexpr bool kEnforceLicense = true;
#else
static constexpr bool kEnforceLicense = false;
#endif

// Toàn quyền khi bypass: mở cả 3 nhóm tính năng.
static QVariantMap fullCapabilities() {
    QVariantMap caps;
    caps.insert(QStringLiteral("event"), true);
    caps.insert(QStringLiteral("studio"), true);
    caps.insert(QStringLiteral("selfbooth"), true);
    return caps;
}

MachineAuthenticator::MachineAuthenticator(DatabaseManager *db, QObject *parent)
    : QObject(parent)
    , m_db(db)
    , m_dynamoClient(nullptr)
    , m_status(NotChecked)
    , m_retryCount(0)
    , m_pollingTimer(nullptr)
{
    // Nhớ studio_id lần trước (để URL gallery vẫn đúng khi khởi động offline).
    m_studioId = QSettings("BoothOS", "Machine").value("studio_id", 0).toInt();

    // Sinh HWID NGAY tại đây (chỉ đọc CPUID/MAC/volume serial — đồng bộ, rất nhanh).
    // Trước đây HWID chỉ được tạo trong authenticate(), mà authenticate() bị hoãn 500 ms
    // sau khi QML nạp xong, nên dialog đăng nhập mở ra với machineAuth.hwid rỗng →
    // qrLoginManager.start("") gọi tới /machine//qr-session → 404 → mã QR không bao giờ hiện.
    m_hwid = generateHWID();

    // Initialize DynamoDBClient
    m_dynamoClient = new DynamoDBClient(ConfigManager::instance(), this);
    connect(m_dynamoClient, &DynamoDBClient::machineFound, this, &MachineAuthenticator::onMachineFound);
    connect(m_dynamoClient, &DynamoDBClient::machineNotFound, this, &MachineAuthenticator::onMachineNotFound);
    connect(m_dynamoClient, &DynamoDBClient::machineRegistered, this, &MachineAuthenticator::onMachineRegistered);
    connect(m_dynamoClient, &DynamoDBClient::operationError, this, &MachineAuthenticator::onOperationError);

    // Initialize polling timer (checks activation status every 10 seconds when pending)
    m_pollingTimer = new QTimer(this);
    m_pollingTimer->setInterval(10000);  // 10 seconds
    connect(m_pollingTimer, &QTimer::timeout, this, [this]() {
        qDebug() << "Polling DynamoDB for activation status...";
        checkMachineOnDynamoDB();
    });

    // Initialize expiration check timer
    m_expirationCheckTimer = new QTimer(this);
    m_expirationCheckTimer->setInterval(60000); // Check every minute
    connect(m_expirationCheckTimer, &QTimer::timeout, this, [this]() {
        if (kEnforceLicense && m_license) {
            // Đọc lại để tính hạn + ân hạn theo giờ hiệu dụng; licenseChanged sẽ
            // kéo applyLicenseState() hạ quyền nếu đã quá hạn.
            m_license->load();
            return;
        }
        if (m_licenseEndDate.isValid() && m_status == Authenticated) {
            if (QDateTime::currentDateTime() > m_licenseEndDate) {
                qDebug() << "Machine license has expired during session!";
                setStatus(Pending, "Bản quyền máy đã hết hạn. Vui lòng gia hạn thêm.");
                m_db->updateMachineAuthStatus(m_hwid, "pending");
                emit authenticationCompleted(false);
                m_expirationCheckTimer->stop();
            }
        }
    });
}

MachineAuthenticator::~MachineAuthenticator() {
}

void MachineAuthenticator::setLicenseManager(LicenseManager *license) {
    m_license = license;
    if (!kEnforceLicense || !m_license) return;
    // Nhập OTP xong, nhận gia hạn, bị thu hồi hay quá hạn → áp quyền ngay, không
    // cần khởi động lại. Trong lúc authenticate() đang chạy (Checking) thì để nó
    // tự quyết, tránh phát authenticationCompleted hai lần.
    connect(m_license, &LicenseManager::licenseChanged, this, [this]() {
        if (m_status == NotChecked || m_status == Checking) return;
        applyLicenseState();
    });
}

void MachineAuthenticator::applyLicenseState() {
    if (!m_license) return;
    const bool ok = m_license->isValid();
    const int newStatus = ok ? Authenticated : Pending;
    const QVariantMap caps = ok ? m_license->capabilities() : QVariantMap();  // fail-closed
    const QString tier = ok ? m_license->deviceTier() : QString();
    const QDateTime end = ok ? m_license->notAfter().toLocalTime() : QDateTime();

    // Timer hết hạn load() lại mỗi phút → licenseChanged mỗi phút. Không đổi gì
    // thì im lặng, để QML không phản ứng lại authenticationCompleted liên tục.
    if (m_status == newStatus && m_caps == caps && m_deviceTier == tier
        && m_licenseEndDate == end && m_statusMessage == m_license->statusMessage())
        return;

    if (ok) {
        qInfo() << "[Auth] Giấy phép hợp lệ —" << m_license->serial()
                << "| tier:" << tier
                << "| hạn:" << (m_license->notAfterText().isEmpty()
                                ? QStringLiteral("không giới hạn") : m_license->notAfterText())
                << (m_license->inGrace() ? "| ĐANG TRONG ÂN HẠN" : "");
    } else {
        qWarning() << "[Auth] Chưa có giấy phép dùng được:" << m_license->statusMessage();
    }

    m_plan       = ok ? QStringLiteral("licensed") : QString();
    m_deviceTier = tier;
    m_caps       = caps;
    m_licenseEndDate = end;
    emit planChanged();
    emit licenseEndChanged();
    m_db->updateMachineAuthStatus(m_hwid, ok ? "authenticated" : "pending");
    setStatus(newStatus, m_license->statusMessage());
    m_expirationCheckTimer->start();
    emit authenticationCompleted(ok);
}

QString MachineAuthenticator::getCPUInfo() {
    // Get CPU ID using __cpuid on Windows
    int cpui[4] = {-1};
    char cpubrand[0x40] = {0};

    // Get extended IDs
    __cpuid(cpui, 0x80000000);
    unsigned int nExIds = cpui[0];

    // Get the information associated with each extended ID
    for(unsigned int i = 0x80000000; i <= nExIds; ++i) {
        __cpuid(cpui, i);

        // Interpret CPU ID
        if (i == 0x80000002) {
            memcpy(cpubrand, cpui, sizeof(cpui));
        } else if (i == 0x80000003) {
            memcpy(cpubrand + 16, cpui, sizeof(cpui));
        } else if (i == 0x80000004) {
            memcpy(cpubrand + 32, cpui, sizeof(cpui));
        }
    }

    // Get processor ID
    __cpuid(cpui, 1);
    unsigned int processorId = cpui[3]; // EDX register

    qDebug() << "CPU Processor ID:" << QString::number(processorId, 16);
    return QString::number(processorId, 16).toUpper();
}

QString MachineAuthenticator::getMACAddress() {
    // Get first non-loopback MAC address
    QList<QNetworkInterface> interfaces = QNetworkInterface::allInterfaces();
    for (int i = 0; i < interfaces.count(); ++i) {
        QNetworkInterface iface = interfaces.at(i);
        if (iface.flags() & QNetworkInterface::IsLoopBack)
            continue;

        if (iface.flags() & QNetworkInterface::IsUp) {
            QString mac = iface.hardwareAddress();
            if (!mac.isEmpty()) {
                qDebug() << "MAC Address found:" << mac;
                return mac.remove(":");
            }
        }
    }

    qDebug() << "No MAC address found";
    return "";
}

QString MachineAuthenticator::getVolumeSerialNumber() {
    // Get C: drive volume serial number on Windows
    wchar_t volumeName[MAX_PATH + 1] = {0};
    DWORD serialNumber = 0;
    DWORD maxComponentLen = 0;
    DWORD fileSystemFlags = 0;

    if (GetVolumeInformation(L"C:\\", volumeName, MAX_PATH, &serialNumber,
                             &maxComponentLen, &fileSystemFlags, nullptr, 0)) {
        qDebug() << "Volume Serial Number:" << QString::number(serialNumber, 16);
        return QString::number(serialNumber, 16).toUpper();
    }

    qDebug() << "Failed to get volume serial number";
    return "";
}

QString MachineAuthenticator::generateHWID() {
    // Gather components
    QString cpuId = getCPUInfo();
    QString macAddr = getMACAddress();
    QString volumeSerial = getVolumeSerialNumber();

    // Combine all components
    QString combined = cpuId + macAddr + volumeSerial;

    if (combined.isEmpty()) {
        qCritical() << "Failed to generate HWID: insufficient system information";
        return "";
    }

    // Hash with SHA256
    QCryptographicHash hash(QCryptographicHash::Sha256);
    hash.addData(combined.toUtf8());
    QString hashHex = hash.result().toHex().toUpper();

    // Take first 16 characters
    QString hwid = hashHex.left(16);
    qDebug() << "Generated HWID:" << hwid;

    return hwid;
}

void MachineAuthenticator::setStatus(int newStatus, const QString &message) {
    int oldStatus = m_status;

    if (m_status != newStatus || m_statusMessage != message) {
        m_status = newStatus;
        m_statusMessage = message;

        qDebug() << "Auth Status Changed:" << newStatus << "-" << message;
        emit statusChanged();
    }

    // Start/stop polling timer based on status. Cưỡng chế giấy phép thì không hỏi
    // DynamoDB nữa — quyền chỉ đổi khi có giấy phép mới (licenseChanged).
    if (kEnforceLicense && m_license) return;
    if (newStatus == Pending && oldStatus != Pending) {
        // Started pending - begin polling
        qDebug() << "Starting activation status polling (every 10 seconds)";
        m_pollingTimer->start();
    } else if (newStatus != Pending && oldStatus == Pending) {
        // Left pending state - stop polling
        qDebug() << "Stopping activation status polling";
        m_pollingTimer->stop();
    }
}

void MachineAuthenticator::authenticate() {
    if (m_status == Checking) {
        qDebug() << "Authentication already in progress";
        return;
    }

    setStatus(Checking, "Đang xác thực máy...");
    m_retryCount = 0;
    m_lastAuthAttempt = QDateTime::currentDateTime();

    // HWID đã được sinh ở constructor; nhánh này chỉ là dự phòng khi lần đó hụt.
    if (m_hwid.isEmpty()) {
        m_hwid = generateHWID();

        if (m_hwid.isEmpty()) {
            setStatus(Failed, "Không thể tạo ID máy");
            emit authenticationCompleted(false);
            return;
        }

        emit hwidChanged();
    }

    // Ghi bản ghi máy vào DB đúng một lần mỗi phiên chạy.
    if (!m_machineRowEnsured) {
        if (!m_db->addMachine(m_hwid, "Photobooth")) {
            qWarning() << "Failed to store HWID in database";
        }
        m_machineRowEnsured = true;
    }

    // ── Giấy phép ký số ──────────────────────────────────────────────────────
    // Đọc trước khi quyết định quyền. Ở giai đoạn chưa cưỡng chế thì đây thuần
    // tuý là đối chiếu để biết hệ thống cấp phép đã phủ tới đâu trước khi bật.
    if (m_license) {
        m_license->setHwid(m_hwid);
        const bool licOk = m_license->load();
        if (licOk) {
            qInfo() << "[Auth] Giấy phép hợp lệ —" << m_license->serial()
                    << "| tier:" << m_license->deviceTier()
                    << "| hạn:" << (m_license->notAfterText().isEmpty()
                                    ? QStringLiteral("không giới hạn")
                                    : m_license->notAfterText())
                    << (m_license->inGrace() ? "| ĐANG TRONG ÂN HẠN" : "");
        } else {
            qWarning() << "[Auth] Chưa có giấy phép dùng được:" << m_license->statusMessage();
        }

        if (kEnforceLicense) {
            // Cưỡng chế: giấy phép là nguồn quyền duy nhất. Không hỏi máy chủ,
            // nên lộ D1 hay lộ token đều không đổi được kết quả ở đây. Báo danh
            // máy do StudioAccount (/v1) đảm nhận, route DynamoDB cũ không gọi nữa.
            //
            // load() ở trên đã phát licenseChanged → applyLicenseState() chạy
            // trước khi m_status rời Checking nên bị bỏ qua; gọi lại cho chắc.
            applyLicenseState();
            return;
        }
    }

    if (kBypassMachineAuth) {
        // Cấp quyền tại chỗ, không chờ mạng: app dùng được kể cả khi server sập.
        m_plan       = QStringLiteral("offline");
        m_deviceTier = QStringLiteral("premium");
        m_caps       = fullCapabilities();
        emit planChanged();

        // Không có hạn dùng → licenseEnd() trả rỗng (UI hiểu là không giới hạn)
        // và timer kiểm tra hết hạn không được bật.
        m_licenseEndDate = QDateTime();
        emit licenseEndChanged();

        m_db->updateMachineAuthStatus(m_hwid, "authenticated");
        setStatus(Authenticated, "Xác thực thành công");
        emit authenticationCompleted(true);

        // Báo danh máy với API selfboothvn do StudioAccount::registerMachine() đảm nhận
        // (route /v1). Route cũ /machine/{hwid} không còn nên không gọi ở đây nữa.
        return;
    }

    // Online validation is mandatory on every launch.
    // No offline grace period: the machine MUST reach DynamoDB and have
    // activate=true (and a non-expired license) to be allowed in. This ensures
    // disabling 'activate' on AWS immediately blocks the machine on next launch.
    checkMachineOnDynamoDB();
}

void MachineAuthenticator::checkMachineOnDynamoDB() {
    if (!m_dynamoClient) {
        // Bypass: không có client cũng không hạ trạng thái máy.
        if (!kBypassMachineAuth)
            setStatus(NetworkError, "DynamoDB client not initialized");
        return;
    }

    m_dynamoClient->getMachine(m_hwid);
}

void MachineAuthenticator::onMachineFound(const QString &hwid, const QVariantMap &data) {
    if (hwid != m_hwid) {
        return;
    }

    // Studio id (tiền tố URL gallery) — lưu lại để dùng cả khi offline.
    int sid = data.value("studio_id", 0).toInt();
    if (sid > 0 && sid != m_studioId) {
        m_studioId = sid;
        QSettings("BoothOS", "Machine").setValue("studio_id", sid);
        emit studioIdChanged();
    }

    // Plan chỉ phục vụ thương mại/lịch sử. Worker suy capabilities duy nhất từ
    // device_tier (trial mở hết; tier trống/lạ fail-closed).
    // Khi bypass, gói/quyền do máy tự quyết (toàn quyền) — không nhận từ Worker nữa.
    if (!kBypassMachineAuth) {
        const QString newPlan = data.value("plan").toString();
        const QString newTier = data.value("device_tier").toString();
        const QVariantMap newCaps = data.value("capabilities").toMap();
        if (newPlan != m_plan || newTier != m_deviceTier || newCaps != m_caps) {
            m_plan = newPlan;
            m_deviceTier = newTier;
            m_caps = newCaps;
            emit planChanged();
        }
    }

    // Bypass: đã Authenticated từ authenticate(); cờ activate/license_end trên
    // server chỉ mang tính tham khảo, không được phép hạ trạng thái máy.
    if (kBypassMachineAuth) {
        qDebug() << "Machine auth bypassed; ignoring server activate/license state for" << hwid;
        return;
    }

    // Check the 'activate' boolean field from DynamoDB
    // Database schema: activate (Boolean) - True = active, False = inactive
    bool isActivated = data.value("activate", false).toBool();
    bool isExpired = false;

    if (isActivated) {
        QString licenseEndStr = data.value("license_end", "").toString();
        if (!licenseEndStr.isEmpty()) {
            QDateTime endDate;
            if (licenseEndStr.contains("T")) {
                endDate = QDateTime::fromString(licenseEndStr, Qt::ISODate);
            } else {
                endDate = QDateTime::fromString(licenseEndStr, "yyyy-MM-dd");
                if (endDate.isValid()) {
                    endDate.setTime(QTime(23, 59, 59)); // End of day
                }
            }
            
            if (endDate.isValid()) {
                m_licenseEndDate = endDate;
                emit licenseEndChanged();
                if (QDateTime::currentDateTime() > endDate) {
                    isActivated = false;
                    isExpired = true;
                }
            }
        }
    }

    if (isActivated) {
        // Machine is activated (activate = true and not expired).
        // NOTE: online validation is mandatory on every launch, so we do NOT
        // cache license_end for an offline bypass anymore. m_licenseEndDate
        // (set above from DynamoDB) is only used by the in-session expiration timer.

        // Update database (local mirror of the last known online state)
        m_db->updateMachineAuthStatus(m_hwid, "authenticated");

        // Check if we were in Pending state (polling detected activation)
        if (m_status == Pending && m_pollingTimer && m_pollingTimer->isActive()) {
            qDebug() << "Activation detected during polling! Admin has activated the machine.";
            setStatus(Authenticated, "✅ Máy đã được kích hoạt!");
            m_expirationCheckTimer->start();
            emit authenticationCompleted(true);  // Close popup and let user in immediately
        } else {
            // First time authentication - allow app to continue
            setStatus(Authenticated, "Xác thực thành công");
            m_expirationCheckTimer->start();
            emit authenticationCompleted(true);
        }
    } else {
        // Machine is not activated OR expired
        if (isExpired) {
            setStatus(Pending, "Bản quyền máy đã hết hạn. Vui lòng gia hạn thêm.");
        } else {
            setStatus(Pending, "Máy chưa được kích hoạt. Vui lòng liên hệ admin.");
        }
        
        m_db->updateMachineAuthStatus(m_hwid, "pending");
        emit authenticationCompleted(false);
    }
}

void MachineAuthenticator::onMachineNotFound(const QString &hwid) {
    if (hwid != m_hwid) {
        return;
    }

    qDebug() << "Machine not found in DynamoDB, attempting auto-registration:" << hwid;

    // Auto-register the machine with pending status
    // Admin will need to approve it (set status to "active")
    if (!m_dynamoClient) {
        if (kBypassMachineAuth) return;   // bypass: không đăng ký được cũng không sao
        setStatus(Pending, "Máy chưa được đăng ký. Vui lòng liên hệ admin.");
        emit authenticationCompleted(false);
        return;
    }

    // Bypass: vẫn đăng ký để máy hiện trong trang quản trị, nhưng im lặng —
    // giữ nguyên trạng thái Authenticated, không hiện "Đang đăng ký máy...".
    if (!kBypassMachineAuth)
        setStatus(Checking, "Đang đăng ký máy...");
    QString deviceName = ConfigManager::instance()->deviceName();
    if (deviceName.trimmed().isEmpty())
        deviceName = "Photobooth";
    m_dynamoClient->registerMachine(m_hwid, deviceName, QString(), QString(), QString());
}

void MachineAuthenticator::onOperationError(const QString &error) {
    qCritical() << "DynamoDB operation error:" << error;

    // Bypass: lỗi mạng/server sập không ảnh hưởng — máy đã được cấp quyền cục bộ.
    if (kBypassMachineAuth) {
        qWarning() << "Machine auth bypassed; ignoring network error.";
        return;
    }

    // Online validation is mandatory: a network error must NOT grant access.
    // Retry a few times, then fail closed (machine cannot be used offline).
    m_retryCount++;
    if (m_retryCount < 3) {
        setStatus(NetworkError, "Lỗi kết nối mạng. Đang thử lại...");
        // Retry the DynamoDB lookup directly (do NOT call authenticate(),
        // which would reset m_retryCount and loop forever).
        QTimer::singleShot(2000, this, &MachineAuthenticator::checkMachineOnDynamoDB);
    } else {
        setStatus(NetworkError, "Lỗi kết nối mạng. Vui lòng thử lại.");
        emit authenticationCompleted(false);
    }
}

void MachineAuthenticator::onMachineRegistered(const QString &hwid) {
    if (hwid != m_hwid) {
        return;
    }

    // Máy mới được Worker tự cấp free-trial (activate=1, license_end = +N ngày).
    // Kiểm tra lại ngay để máy vào thẳng bằng trial, không còn chờ admin duyệt.
    qDebug() << "Machine registered; re-checking for free-trial activation:" << hwid;
    // Bypass: chỉ đọc lại để lấy studio_id, không đổi trạng thái đang Authenticated.
    if (!kBypassMachineAuth)
        setStatus(Checking, "Đang kích hoạt dùng thử...");
    checkMachineOnDynamoDB();
}

void MachineAuthenticator::retryAuthentication() {
    m_retryCount = 0;
    authenticate();
}
