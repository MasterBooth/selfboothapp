#include "StudioAccount.h"
#include "ConfigManager.h"
#include "SecureStore.h"

#include <QCoreApplication>
#include <QDebug>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QTimer>

static const char *kSettingsOrg = "BoothOS";
static const char *kSettingsApp = "Studio";
// Web admin coi máy "Online" nếu báo danh trong 10 phút gần nhất.
static const int kHeartbeatMs = 5 * 60 * 1000;

StudioAccount::StudioAccount(ConfigManager *config, const QString &hwid, QObject *parent)
    : QObject(parent)
    , m_config(config)
    , m_net(new QNetworkAccessManager(this))
    , m_hwid(hwid)
    , m_heartbeat(new QTimer(this))
{
    m_heartbeat->setInterval(kHeartbeatMs);
    connect(m_heartbeat, &QTimer::timeout, this, &StudioAccount::refreshMachine);
    m_heartbeat->start();
}

void StudioAccount::restore()
{
    QSettings s(kSettingsOrg, kSettingsApp);
    if (s.value("hwid").toString() != m_hwid) {
        if (!s.value("studio_id").toString().isEmpty())
            qWarning() << "[StudioAccount] Saved metadata belongs to another HWID, ignoring";
        return;
    }
    QString secureError;
    m_token      = SecureStore::loadToken(m_hwid, &secureError);
    if (!secureError.isEmpty())
        qWarning() << "[StudioAccount] Secure token restore failed:" << secureError;
    m_studioId   = s.value("studio_id").toString();
    m_studioName = s.value("studio_name").toString();
    m_email      = s.value("email").toString();
    m_machineName = s.value("machine_name").toString();
    if (m_config) m_config->setMachineToken(m_token);
    if (loggedIn()) QTimer::singleShot(0, this, &StudioAccount::refreshMachine);
    qDebug() << "[StudioAccount] Restored:" << (loggedIn() ? m_studioName : QStringLiteral("(not signed in)"));
    emit accountChanged();
}

void StudioAccount::registerMachine()
{
    refreshMachine();
}

void StudioAccount::login(const QString &email, const QString &password)
{
    QVariantMap body;
    body["email"] = email.trimmed();
    body["password"] = password;
    sendAuth("/v1/auth/login", body);
}

void StudioAccount::registerStudio(const QString &studioName, const QString &email,
                                   const QString &password)
{
    QVariantMap body;
    body["studio_name"] = studioName.trimmed();
    body["email"] = email.trimmed();
    body["password"] = password;
    sendAuth("/v1/studios/register", body);
}

void StudioAccount::sendAuth(const QString &path, const QVariantMap &fields)
{
    if (m_busy) return;
    if (!m_config || m_config->cloudApiBaseUrl().isEmpty()) {
        emit authFailed(QStringLiteral("Thiếu cấu hình máy chủ"));
        return;
    }
    QJsonObject body = QJsonObject::fromVariantMap(fields);
    body["hwid"] = m_hwid;
    body["device_name"] = m_config->deviceName();
    body["app_version"] = QCoreApplication::applicationVersion();

    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + path));
    req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    req.setTransferTimeout(20000);
    setBusy(true);
    QNetworkReply *reply = m_net->post(req, QJsonDocument(body).toJson(QJsonDocument::Compact));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() { onAuthReply(reply); });
}

void StudioAccount::onAuthReply(QNetworkReply *reply)
{
    reply->deleteLater();
    setBusy(false);
    const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();

    if (http < 200 || http >= 300 || obj.value("token").toString().isEmpty()) {
        const QString msg = messageForError(obj.value("error").toString(),
                                            obj.value("message").toString(), http);
        qWarning() << "[StudioAccount] Auth failed: HTTP" << http << obj.value("error").toString();
        emit authFailed(msg);
        return;
    }

    const QJsonObject studio = obj.value("studio").toObject();
    const QJsonObject user = obj.value("user").toObject();
    m_token      = obj.value("token").toString();
    m_studioId   = studio.value("id").toString();
    m_studioName = studio.value("name").toString();
    m_email      = user.value("email").toString();
    applyMachine(obj.value("machine").toObject());

    QSettings s(kSettingsOrg, kSettingsApp);
    s.setValue("hwid", m_hwid);
    s.setValue("studio_id", m_studioId);
    s.setValue("studio_name", m_studioName);
    s.setValue("email", m_email);
    QString secureError;
    if (!SecureStore::saveToken(m_hwid, m_token, &secureError))
        qWarning() << "[StudioAccount] Secure token save failed:" << secureError;
    if (m_config) m_config->setMachineToken(m_token);

    qDebug() << "[StudioAccount] Signed in to studio" << m_studioName;
    emit accountChanged();
    emit signedIn();
}

void StudioAccount::logout()
{
    // Thu hồi token trên server (best-effort); phiên local xóa ngay kể cả khi mất mạng.
    if (m_config && !m_token.isEmpty() && !m_config->cloudApiBaseUrl().isEmpty()) {
        QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + "/v1/auth/logout"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
        req.setTransferTimeout(10000);
        QNetworkReply *reply = m_net->post(req, QByteArray("{}"));
        connect(reply, &QNetworkReply::finished, reply, &QObject::deleteLater);
    }
    clearSession();
}

void StudioAccount::refreshMachine()
{
    if (!loggedIn() || !m_config || m_config->cloudApiBaseUrl().isEmpty()) return;
    QNetworkRequest req(QUrl(m_config->cloudApiBaseUrl() + "/v1/machine/me"));
    req.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    req.setTransferTimeout(15000);
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        if (http == 401) { handleUnauthorized(); return; }
        if (http < 200 || http >= 300) return;   // mất mạng: giữ tên cũ, lần sau thử lại
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        const QString studioName = obj.value("studio").toObject().value("name").toString();
        if (!studioName.isEmpty() && studioName != m_studioName) {
            m_studioName = studioName;
            QSettings(kSettingsOrg, kSettingsApp).setValue("studio_name", m_studioName);
            emit accountChanged();
        }
        applyMachine(obj.value("machine").toObject());
    });
}

void StudioAccount::applyMachine(const QJsonObject &machine)
{
    QString name = machine.value("display_name").toString().trimmed();
    if (name.isEmpty()) name = machine.value("device_name").toString().trimmed();
    if (name.isEmpty() && m_config) name = m_config->deviceName().trimmed();
    if (name.isEmpty() || name == m_machineName) return;
    m_machineName = name;
    QSettings(kSettingsOrg, kSettingsApp).setValue("machine_name", m_machineName);
    emit accountChanged();
}

void StudioAccount::handleUnauthorized()
{
    if (!loggedIn()) return;
    qWarning() << "[StudioAccount] Machine token rejected by server — signing out";
    clearSession();
}

void StudioAccount::clearSession()
{
    const bool was = loggedIn();
    m_token.clear();
    m_studioId.clear();
    m_studioName.clear();
    m_email.clear();
    m_machineName.clear();
    QSettings s(kSettingsOrg, kSettingsApp);
    s.remove("machine_name");
    s.remove("studio_id");
    s.remove("studio_name");
    s.remove("email");
    QString secureError;
    if (!SecureStore::deleteToken(m_hwid, &secureError))
        qWarning() << "[StudioAccount] Secure token delete failed:" << secureError;
    if (m_config) m_config->setMachineToken(QString());
    emit accountChanged();
    if (was) emit signedOut();
}

void StudioAccount::setBusy(bool busy)
{
    if (m_busy == busy) return;
    m_busy = busy;
    emit busyChanged();
}

QString StudioAccount::messageForError(const QString &code, const QString &serverMessage, int httpStatus)
{
    if (httpStatus == 0)
        return QStringLiteral("Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.");
    if (code == "invalid_credentials") return QStringLiteral("Sai email hoặc mật khẩu");
    if (code == "email_taken")         return QStringLiteral("Email đã được đăng ký");
    if (code == "login_locked")        return QStringLiteral("Đăng nhập sai quá nhiều lần, thử lại sau 15 phút");
    if (code == "password_too_short")  return QStringLiteral("Mật khẩu tối thiểu 8 ký tự");
    if (code == "invalid_email")       return QStringLiteral("Email không hợp lệ");
    if (code == "studio_name_required") return QStringLiteral("Nhập tên studio");
    if (code == "user_disabled")       return QStringLiteral("Tài khoản đã bị khóa");
    if (code == "studio_suspended")    return QStringLiteral("Studio đang bị tạm ngưng");
    if (code == "machine_disabled")    return QStringLiteral("Máy này đã bị vô hiệu hóa");
    if (!serverMessage.isEmpty())      return serverMessage;
    return QStringLiteral("Lỗi máy chủ (HTTP %1)").arg(httpStatus);
}
