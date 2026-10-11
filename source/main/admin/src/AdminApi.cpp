#include "AdminApi.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QNetworkReply>
#include <QUrl>
#include <QSaveFile>
#include <QClipboard>
#include <QGuiApplication>
#include <QDebug>

AdminApi::AdminApi(QObject *parent) : QObject(parent) {}

void AdminApi::setBaseUrl(const QString &url)
{
    QString u = url.trimmed();
    while (u.endsWith(QLatin1Char('/'))) u.chop(1);
    if (u == m_baseUrl) return;
    m_baseUrl = u;
    emit configChanged();
}

void AdminApi::setToken(const QString &token)
{
    m_token = token.trimmed();
    emit configChanged();
}

QString AdminApi::configPath() const
{
    return QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("admin-config.json"));
}

// Cấu hình để cạnh exe, tách khỏi mã nguồn — mỗi admin tự giữ token của mình.
//   { "base_url": "https://boothme.tech", "admin_token": "<ADMIN_API_TOKEN>" }
bool AdminApi::loadConfig(QString *errorOut)
{
    const QString path = configPath();
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        if (errorOut) *errorOut = QStringLiteral("Không có %1").arg(path);
        return false;
    }
    const QJsonObject o = QJsonDocument::fromJson(f.readAll()).object();
    f.close();

    setBaseUrl(o.value(QStringLiteral("base_url")).toString());
    setToken(o.value(QStringLiteral("admin_token")).toString());

    if (m_baseUrl.isEmpty() || m_token.isEmpty()) {
        if (errorOut) *errorOut = QStringLiteral("admin-config.json thiếu base_url hoặc admin_token");
        return false;
    }
    return true;
}

QString AdminApi::saveConfig(const QString &baseUrl, const QString &token)
{
    QString u = baseUrl.trimmed();
    while (u.endsWith(QLatin1Char('/'))) u.chop(1);
    if (u.endsWith(QStringLiteral("/v1"))) u.chop(3);
    if (!u.startsWith(QStringLiteral("https://")) && !u.startsWith(QStringLiteral("http://")))
        return QStringLiteral("Địa chỉ phải bắt đầu bằng https://");
    const QString t = token.trimmed().isEmpty() ? m_token : token.trimmed();
    if (t.isEmpty()) return QStringLiteral("Chưa có ADMIN_API_TOKEN");

    QJsonObject o;
    o["base_url"]    = u;
    o["admin_token"] = t;
    QSaveFile f(configPath());
    if (!f.open(QIODevice::WriteOnly))
        return QStringLiteral("Không ghi được %1: %2").arg(configPath(), f.errorString());
    f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    if (!f.commit()) return QStringLiteral("Không lưu được %1").arg(configPath());

    setBaseUrl(u);
    setToken(t);
    return QString();
}

void AdminApi::copyText(const QString &text)
{
    if (auto *cb = QGuiApplication::clipboard()) cb->setText(text);
}

QNetworkRequest AdminApi::makeRequest(const QString &path) const
{
    QNetworkRequest r{QUrl(m_baseUrl + QStringLiteral("/v1/admin/licenses") + path)};
    r.setRawHeader("Authorization", QByteArray("Bearer ") + m_token.toUtf8());
    r.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    r.setTransferTimeout(20000);
    return r;
}

void AdminApi::setBusy(bool b)
{
    if (m_busy == b) return;
    m_busy = b;
    emit busyChanged();
}

bool AdminApi::ensureConfigured()
{
    if (m_baseUrl.isEmpty() || m_token.isEmpty()) {
        emit failed(QStringLiteral("Chưa cấu hình máy chủ hoặc token admin (admin-config.json)"));
        return false;
    }
    return true;
}

// Mọi route trả {success, error?, message?, ...}. Ưu tiên `message` tiếng Việt
// của Worker; không có thì hiện mã lỗi ổn định.
void AdminApi::send(const QByteArray &verb, const QString &path, const QVariantMap &body,
                    Handler onOk)
{
    if (!ensureConfigured()) return;
    setBusy(true);
    const QByteArray payload = body.isEmpty()
        ? QByteArray() : QJsonDocument(QJsonObject::fromVariantMap(body)).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = m_net.sendCustomRequest(makeRequest(path), verb, payload);
    connect(reply, &QNetworkReply::finished, this, [this, reply, onOk]() {
        reply->deleteLater();
        setBusy(false);
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        if (http == 0) {
            emit failed(QStringLiteral("Không kết nối được máy chủ: %1").arg(reply->errorString()));
            return;
        }
        if (!o.value(QStringLiteral("success")).toBool()) {
            const QString msg = o.value(QStringLiteral("message")).toString();
            const QString code = o.value(QStringLiteral("error")).toString();
            emit failed(!msg.isEmpty() ? msg
                        : !code.isEmpty() ? QStringLiteral("%1 (HTTP %2)").arg(code).arg(http)
                        : QStringLiteral("Lỗi máy chủ (HTTP %1)").arg(http));
            return;
        }
        onOk(o.toVariantMap());
    });
}

void AdminApi::fetchMachines()
{
    send("GET", QStringLiteral("/machines"), {}, [this](const QVariantMap &o) {
        emit machinesReady(o.value(QStringLiteral("machines")).toList());
    });
}

void AdminApi::issue(const QString &license, const QString &approver, bool withOtp)
{
    if (license.isEmpty()) { emit failed(QStringLiteral("Chưa ký được giấy phép")); return; }
    QVariantMap body;
    body["license"]  = license;
    body["approver"] = approver;
    body["with_otp"] = withOtp;
    send("POST", QStringLiteral("/issue"), body, [this](const QVariantMap &o) {
        emit issued(o.value("serial").toString(), o.value("hwid").toString(),
                    o.value("otp").toString(), o.value("otp_expires_at").toString());
    });
}

void AdminApi::reissueOtp(const QString &hwid)
{
    QVariantMap body;
    body["hwid"] = hwid;
    send("POST", QStringLiteral("/otp"), body, [this](const QVariantMap &o) {
        emit otpReady(o.value("hwid").toString(), o.value("otp").toString(),
                      o.value("otp_expires_at").toString());
    });
}

void AdminApi::revoke(const QString &revocation)
{
    if (revocation.isEmpty()) { emit failed(QStringLiteral("Chưa ký được phiếu thu hồi")); return; }
    QVariantMap body;
    body["revocation"] = revocation;
    send("POST", QStringLiteral("/revoke"), body, [this](const QVariantMap &o) {
        emit revoked(o.value("serial").toString(), o.value("hwid").toString());
    });
}

void AdminApi::transfer(const QString &revocation, const QString &license, const QString &approver)
{
    if (revocation.isEmpty() || license.isEmpty()) {
        emit failed(QStringLiteral("Chưa ký được phiếu thu hồi hoặc giấy phép mới"));
        return;
    }
    QVariantMap body;
    body["revocation"] = revocation;
    body["license"]    = license;
    body["approver"]   = approver;
    send("POST", QStringLiteral("/transfer"), body, [this](const QVariantMap &o) {
        emit issued(o.value("serial").toString(), o.value("hwid").toString(),
                    o.value("otp").toString(), o.value("otp_expires_at").toString());
    });
}

void AdminApi::removeMachine(const QString &hwid)
{
    const QString path = QStringLiteral("/machines/")
                       + QString::fromLatin1(QUrl::toPercentEncoding(hwid));
    send("DELETE", path, {}, [this, hwid](const QVariantMap &) { emit removed(hwid); });
}

void AdminApi::fetchHistory(const QString &hwid)
{
    if (m_baseUrl.isEmpty() || m_token.isEmpty() || hwid.isEmpty()) {
        emit historyFailed(hwid, false);
        return;
    }
    const QString path = QStringLiteral("/machines/")
                       + QString::fromLatin1(QUrl::toPercentEncoding(hwid));
    QNetworkReply *reply = m_net.get(makeRequest(path));
    connect(reply, &QNetworkReply::finished, this, [this, reply, hwid]() {
        reply->deleteLater();
        const int http = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject o = QJsonDocument::fromJson(reply->readAll()).object();
        if (!o.value(QStringLiteral("success")).toBool()) {
            emit historyFailed(hwid, http == 404 && o.value(QStringLiteral("error")).toString() == QLatin1String("not_found"));
            return;
        }
        emit historyReady(hwid, o.toVariantMap());
    });
}
