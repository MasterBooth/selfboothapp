#include "HttpBridge.h"
#include "CameraController.h"
#include "EventManager.h"
#include "SessionManager.h"
#include "AppPaths.h"

#include <QTcpServer>
#include <QTcpSocket>
#include <QJsonDocument>
#include <QJsonArray>
#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QUrl>
#include <QUrlQuery>

// Lấy 1 tham số query (đã decode). query = phần sau '?' trong URL.
static QString qParam(const QString &query, const QString &key)
{
    QUrlQuery q(query);
    return q.queryItemValue(key, QUrl::FullyDecoded);
}

// ─────────────────────────────────────────────────────────────────────────────
// Construction / lifecycle
// ─────────────────────────────────────────────────────────────────────────────

HttpBridge::HttpBridge(QObject *parent) : QObject(parent)
{
    m_server = new QTcpServer(this);
    connect(m_server, &QTcpServer::newConnection, this, &HttpBridge::onNewConnection);
}

HttpBridge::~HttpBridge()
{
    stop();
}

bool HttpBridge::start(quint16 port, bool lan)
{
    m_lanEnabled = lan;
    const QHostAddress addr = lan ? QHostAddress::Any : QHostAddress::LocalHost;
    if (!m_server->listen(addr, port)) {
        qWarning() << "HttpBridge: không thể mở port" << port << "–" << m_server->errorString();
        return false;
    }
    if (lan)
        qDebug() << "HttpBridge: đang lắng nghe LAN tại http://0.0.0.0:" << m_server->serverPort();
    else
        qDebug() << "HttpBridge: đang lắng nghe tại http://127.0.0.1:" << m_server->serverPort();
    return true;
}

void HttpBridge::stop()
{
    m_server->close();
    for (auto *s : m_clients.keys()) s->close();
    for (auto *s : m_sseClients)     s->close();
}

quint16 HttpBridge::port() const
{
    return m_server->serverPort();
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection handling
// ─────────────────────────────────────────────────────────────────────────────

void HttpBridge::onNewConnection()
{
    while (m_server->hasPendingConnections()) {
        QTcpSocket *sock = m_server->nextPendingConnection();
        ClientState cs;
        cs.fromLoopback = sock->peerAddress().isLoopback();
        m_clients[sock] = cs;
        connect(sock, &QTcpSocket::readyRead,    this, &HttpBridge::onClientData);
        connect(sock, &QTcpSocket::disconnected, this, &HttpBridge::onClientDisconnected);
    }
}

void HttpBridge::onClientData()
{
    auto *sock = qobject_cast<QTcpSocket*>(sender());
    if (!sock) return;

    auto &cs = m_clients[sock];
    cs.buf.append(sock->readAll());

    if (!tryParse(cs)) return;  // request not complete yet

    const bool loopback = cs.fromLoopback;

    if (cs.req.path == "/api/stream") {
        // SSE cũng phải qua token gate với client LAN (tránh rò sự kiện ra ngoài).
        if (!authOk(cs.req, loopback)) {
            sock->write(jsonErr("Unauthorized", 401));
            sock->flush();
            sock->disconnectFromHost();
            return;
        }
        // SSE upgrade: keep socket open, no Content-Length response
        sock->write(sseHandshake());
        sock->flush();
        m_sseClients.append(sock);
        m_clients.remove(sock);
    } else {
        sock->write(dispatch(cs.req, loopback));
        sock->flush();
        sock->disconnectFromHost();
    }
}

void HttpBridge::onClientDisconnected()
{
    auto *sock = qobject_cast<QTcpSocket*>(sender());
    if (!sock) return;
    m_clients.remove(sock);
    m_sseClients.removeAll(sock);
    sock->deleteLater();
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP request parsing (minimal HTTP/1.1, đủ cho localhost IPC)
// ─────────────────────────────────────────────────────────────────────────────

bool HttpBridge::tryParse(ClientState &cs)
{
    auto &buf = cs.buf;
    auto &req = cs.req;

    if (cs.state == WantHeaders) {
        int sep = buf.indexOf("\r\n\r\n");
        if (sep < 0) return false;

        QByteArray headerPart = buf.left(sep);
        buf.remove(0, sep + 4);

        QList<QByteArray> lines = headerPart.split('\n');
        if (lines.isEmpty()) return false;

        // Request line: METHOD PATH HTTP/x.x
        QList<QByteArray> rl = lines[0].trimmed().split(' ');
        if (rl.size() < 2) return false;
        req.method = QString::fromUtf8(rl[0]).toUpper();
        req.path   = QString::fromUtf8(rl[1]);

        // Tách query string (giữ lại cho token/path/limit)
        int qmark = req.path.indexOf('?');
        if (qmark >= 0) {
            req.query = req.path.mid(qmark + 1);
            req.path  = req.path.left(qmark);
        } else {
            req.query.clear();
        }

        int contentLength = 0;
        for (int i = 1; i < lines.size(); ++i) {
            QByteArray line = lines[i].trimmed();
            int c = line.indexOf(':');
            if (c < 0) continue;
            QString k = QString::fromUtf8(line.left(c)).trimmed().toLower();
            QString v = QString::fromUtf8(line.mid(c + 1)).trimmed();
            req.headers[k] = v;
            if (k == "content-length") contentLength = v.toInt();
        }

        if (contentLength > 0) {
            cs.state = WantBody;
        } else {
            cs.state = Done;
            return true;
        }
    }

    if (cs.state == WantBody) {
        int need = req.headers.value("content-length", "0").toInt();
        if (buf.size() < need) return false;
        req.body = buf.left(need);
        cs.state = Done;
        return true;
    }

    return cs.state == Done;
}

// ─────────────────────────────────────────────────────────────────────────────
// Routing
// ─────────────────────────────────────────────────────────────────────────────

QByteArray HttpBridge::dispatch(const Request &req, bool fromLoopback)
{
    const QString &path   = req.path;
    const QString &method = req.method;

    // CORS preflight
    if (method == "OPTIONS")
        return httpResponse(204, "", "");

    // ── Trang gallery quầy thu ngân (không cần token — trang tự hỏi PIN) ──────
    if (method == "GET" && (path == "/" || path == "/pickup" || path == "/index.html"))
        return serveStatic("pickup.html");

    // ── Kiểm PIN cho quầy thu ngân: trả {ok} để client biết PIN đúng/sai ──────
    if (path == "/api/pickup/auth") {
        const QString t = qParam(req.query, "token");
        const bool ok = m_pickupToken.isEmpty() || (t == m_pickupToken);
        return jsonOk(QJsonObject{{"ok", ok}});
    }

    // ── Token gate: client LAN (không loopback) phải có token hợp lệ ──────────
    if (!authOk(req, fromLoopback))
        return jsonErr("Unauthorized", 401);

    // ── Tải file ảnh gốc từ đĩa (guard trong thư mục Events) ──────────────────
    if (method == "GET" && path == "/api/file")
        return routeFile(req.query);

    // Parse JSON body (nếu có)
    QJsonObject body;
    if (!req.body.isEmpty()) {
        QJsonParseError pe;
        auto doc = QJsonDocument::fromJson(req.body, &pe);
        if (pe.error == QJsonParseError::NoError && doc.isObject())
            body = doc.object();
    }

    // ── /api/status ────────────────────────────────────────────────────────
    if (path == "/api/status") {
        QJsonObject s;
        s["ok"]               = true;
        s["cameraConnected"]  = m_camera ? m_camera->isConnected()      : false;
        s["liveViewActive"]   = m_camera ? m_camera->isLiveViewActive()  : false;
        s["cameraModel"]      = m_camera ? m_camera->cameraModel()       : QString();
        s["fps"]              = m_camera ? m_camera->liveViewFps()       : 0;
        return jsonOk(s);
    }

    if (path.startsWith("/api/camera"))
        return routeCamera(path.mid(11), method, body);

    if (path.startsWith("/api/events"))
        return routeEvents(path.mid(11), method, body);

    if (path.startsWith("/api/sessions"))
        return routeSessions(path.mid(13), method, body);

    if (path.startsWith("/api/settings"))
        return routeSettings(path.mid(13), method, body);

    if (path == "/api/stream")
        return {};  // caller handles SSE upgrade

    return jsonErr("Not found", 404);
}

// ─────────────────────────────────────────────────────────────────────────────
// /api/camera/*
// ─────────────────────────────────────────────────────────────────────────────

QByteArray HttpBridge::routeCamera(const QString &sub,
                                   const QString &method,
                                   const QJsonObject &body)
{
    if (!m_camera)
        return jsonErr("CameraController không có sẵn", 503);

    // GET /api/camera  –  trạng thái tổng quát
    if ((sub.isEmpty() || sub == "/") && method == "GET") {
        QJsonObject s;
        s["connected"]      = m_camera->isConnected();
        s["liveViewActive"] = m_camera->isLiveViewActive();
        s["model"]          = m_camera->cameraModel();
        s["fps"]            = m_camera->liveViewFps();
        s["mirrorMode"]     = m_camera->mirrorMode();
        s["afEnabled"]      = m_camera->afEnabled();
        s["lastError"]      = m_camera->lastError();
        return jsonOk(s);
    }

    if (sub == "/connect" && method == "POST") {
        // KHÔNG gọi connectToServer() trực tiếp: nó BLOCK main/UI thread 5–8s
        // (USB enumeration) và đụng EDSDK/CRSDK trên main thread trong khi
        // connectAsync()/watchdog có thể đang dùng SDK ở m_camPool → truy cập
        // SDK đồng thời (không thread-safe) → crash.
        // connectAsync() chạy nền + có guard m_isConnecting (chống chạy chồng);
        // client theo dõi kết quả qua SSE (liveViewStarted / cameraError).
        m_camera->connectAsync();
        return jsonOk(QJsonObject{{"ok", true}, {"async", true}});
    }

    if (sub == "/live-view/start" && method == "POST") {
        bool ok = m_camera->startLiveView();
        return jsonOk(QJsonObject{{"ok", ok}});
    }

    if (sub == "/live-view/stop" && method == "POST") {
        bool ok = m_camera->stopLiveView();
        return jsonOk(QJsonObject{{"ok", ok}});
    }

    if (sub == "/capture" && method == "POST") {
        bool ok = m_camera->takePicture();
        return jsonOk(QJsonObject{{"ok", ok}});
    }

    // GET /api/camera/frame  –  JPEG binary của frame live-view mới nhất
    if (sub == "/frame" && method == "GET") {
        QByteArray jpeg = m_camera->latestFrameAsJpeg();
        if (jpeg.isEmpty())
            return jsonErr("Chưa có frame", 503);
        return httpResponse(200, "image/jpeg", jpeg);
    }

    // GET /api/camera/properties  –  tất cả giá trị camera + danh sách
    if (sub == "/properties" && method == "GET") {
        const bool listsOk = m_camera->fetchCameraPropertyLists();
        m_camera->getAllCameraProperties();
        QJsonObject p;
        p["listsOk"]          = listsOk;
        p["iso"]              = m_camera->iso();
        p["isoList"]          = QJsonArray::fromStringList(m_camera->isoList());
        p["aperture"]         = m_camera->aperture();
        p["apertureList"]     = QJsonArray::fromStringList(m_camera->apertureList());
        p["shutterSpeed"]     = m_camera->shutterSpeed();
        p["shutterSpeedList"] = QJsonArray::fromStringList(m_camera->shutterSpeedList());
        p["whiteBalance"]     = m_camera->whiteBalance();
        p["whiteBalanceList"] = QJsonArray::fromStringList(m_camera->whiteBalanceList());
        p["ev"]               = m_camera->exposureCompensation();
        p["evList"]           = QJsonArray::fromStringList(m_camera->exposureCompensationList());
        p["colorTemp"]        = m_camera->colorTemperature();
        p["colorTempList"]    = QJsonArray::fromStringList(m_camera->colorTemperatureList());
        return jsonOk(p);
    }

    // POST các thông số camera
    if (sub == "/iso"      && method == "POST") return jsonOk(QJsonObject{{"ok", m_camera->setIso(body["value"].toString())}});
    if (sub == "/aperture" && method == "POST") return jsonOk(QJsonObject{{"ok", m_camera->setAperture(body["value"].toString())}});
    if (sub == "/shutter"  && method == "POST") return jsonOk(QJsonObject{{"ok", m_camera->setShutterSpeed(body["value"].toString())}});
    if (sub == "/wb"       && method == "POST") return jsonOk(QJsonObject{{"ok", m_camera->setWhiteBalance(body["value"].toString())}});
    if (sub == "/ev"       && method == "POST") return jsonOk(QJsonObject{{"ok", m_camera->setExposureCompensation(body["value"].toString())}});
    if ((sub == "/color-temperature" || sub == "/colorTemp") && method == "POST")
        return jsonOk(QJsonObject{{"ok", m_camera->setColorTemperature(body["value"].toString())}});
    if (sub == "/af" && method == "POST") {
        m_camera->setAfEnabled(body["enabled"].toBool(true));
        return jsonOk(QJsonObject{{"ok", true}, {"afEnabled", m_camera->afEnabled()}});
    }
    if (sub == "/mirror"   && method == "POST") {
        m_camera->setMirrorMode(body["enabled"].toBool());
        return jsonOk(QJsonObject{{"ok", true}});
    }

    return jsonErr("Endpoint camera không tồn tại", 404);
}

// ─────────────────────────────────────────────────────────────────────────────
// /api/events/*
// ─────────────────────────────────────────────────────────────────────────────

QByteArray HttpBridge::routeEvents(const QString &sub,
                                   const QString &method,
                                   const QJsonObject &body)
{
    if (!m_events)
        return jsonErr("EventManager không có sẵn", 503);

    // GET/POST /api/events
    if (sub.isEmpty() || sub == "/") {
        if (method == "GET") {
            // Trả danh sách từ EventModel
            auto *model = m_events->eventModel();
            QJsonArray arr;
            for (int i = 0; i < model->rowCount(); ++i) {
                auto d = model->getEventData(i);
                arr.append(QJsonObject::fromVariantMap(d));
            }
            return jsonOk(QJsonObject{{"events", arr}});
        }
        if (method == "POST") {
            bool ok = m_events->createEvent(
                body["name"].toString(),
                body["location"].toString(),
                body["date"].toString());
            return jsonOk(QJsonObject{{"ok", ok}});
        }
    }

    // /api/events/{id}[/photos|/capture]
    QStringList parts = sub.split('/', Qt::SkipEmptyParts);
    if (!parts.isEmpty()) {
        bool isNum;
        int id = parts[0].toInt(&isNum);
        if (!isNum) return jsonErr("Event id không hợp lệ", 400);

        if (parts.size() == 1 && method == "GET")
            return jsonOk(m_events->getEventDetails(id));

        if (parts.size() == 2 && parts[1] == "photos" && method == "GET") {
            auto photos = m_events->getEventPhotos(id);
            QJsonArray arr;
            for (auto &v : photos) arr.append(QJsonValue::fromVariant(v));
            return jsonOk(QJsonObject{{"photos", arr}});
        }

        // GET /api/events/{id}/sessions — danh sách session gần nhất (quầy thu ngân)
        if (parts.size() == 2 && parts[1] == "sessions" && method == "GET") {
            if (!m_sessions) return jsonErr("SessionManager không có sẵn", 503);
            const auto list = m_sessions->getRecentSessions(id, 50);
            QJsonArray arr;
            for (const auto &v : list) arr.append(QJsonObject::fromVariantMap(v.toMap()));
            return jsonOk(QJsonObject{{"sessions", arr}});
        }

        if (parts.size() == 2 && parts[1] == "capture" && method == "POST") {
            if (!m_camera) return jsonErr("Camera không có sẵn", 503);
            bool ok = m_camera->takePicture();
            return jsonOk(QJsonObject{{"ok", ok}});
        }
    }

    return jsonErr("Endpoint events không tồn tại", 404);
}

// ─────────────────────────────────────────────────────────────────────────────
// /api/sessions/*
// ─────────────────────────────────────────────────────────────────────────────

QByteArray HttpBridge::routeSessions(const QString &sub,
                                     const QString &method,
                                     const QJsonObject &body)
{
    if (!m_sessions)
        return jsonErr("SessionManager không có sẵn", 503);

    if ((sub.isEmpty() || sub == "/") && method == "POST") {
        QString sid = m_sessions->createSession(
            body["eventId"].toInt(),
            body["hwid"].toString("python-client"));
        return jsonOk(QJsonObject{{"sessionId", sid}});
    }

    QStringList parts = sub.split('/', Qt::SkipEmptyParts);

    if (parts.size() == 1 && method == "GET")
        return jsonOk(m_sessions->getSessionInfo(parts[0]));

    if (parts.size() == 2 && parts[1] == "photos" && method == "GET") {
        auto photos = m_sessions->getSessionPhotos(parts[0]);
        return jsonOk(QJsonObject{{"photos", QJsonArray::fromStringList(photos)}});
    }

    return jsonErr("Endpoint sessions không tồn tại", 404);
}

// ─────────────────────────────────────────────────────────────────────────────
// /api/settings/{key}
// ─────────────────────────────────────────────────────────────────────────────

QByteArray HttpBridge::routeSettings(const QString &sub,
                                     const QString &method,
                                     const QJsonObject &body)
{
    if (!m_events)
        return jsonErr("EventManager không có sẵn", 503);

    QString key = sub.startsWith('/') ? sub.mid(1) : sub;
    if (key.isEmpty())
        return jsonErr("Thiếu key", 400);

    if (method == "GET") {
        QString val = m_events->getAppSetting(key, "");
        return jsonOk(QJsonObject{{"key", key}, {"value", val}});
    }
    if (method == "POST") {
        bool ok = m_events->setAppSetting(key, body["value"].toString());
        return jsonOk(QJsonObject{{"ok", ok}});
    }

    return jsonErr("Method không được hỗ trợ", 405);
}

// ─────────────────────────────────────────────────────────────────────────────
// Quầy thu ngân LAN: token gate, tải file gốc, trang tĩnh
// ─────────────────────────────────────────────────────────────────────────────

bool HttpBridge::authOk(const Request &req, bool fromLoopback) const
{
    if (fromLoopback) return true;    // localhost (Python SDK) luôn được phép
    if (!m_lanEnabled) return false;  // có client ngoài nhưng chưa bật LAN → chặn
    if (m_pickupToken.isEmpty()) return true;  // LAN mở, không đặt PIN
    QString t = qParam(req.query, "token");
    if (t.isEmpty()) t = req.headers.value("x-pickup-token");
    return t == m_pickupToken;
}

QByteArray HttpBridge::routeFile(const QString &query)
{
    QString p = qParam(query, "path");
    if (p.isEmpty())
        return jsonErr("Thiếu tham số path", 400);
    if (p.startsWith("file:///"))   // phòng khi client gửi kèm scheme
        p = p.mid(8);

    // Guard chống path traversal: file phải nằm TRONG thư mục Events.
    const QString base = QDir(AppPaths::instance().getEventsBaseDirectory()).canonicalPath();
    const QString canon = QFileInfo(p).canonicalFilePath();
    if (base.isEmpty() || canon.isEmpty())
        return jsonErr("Không tìm thấy file", 404);
    // Windows: so sánh không phân biệt hoa thường; đảm bảo có dấu phân tách để
    // "…/Events" không khớp nhầm "…/Events_backup".
    const QString baseWithSep = base.endsWith('/') ? base : base + '/';
    if (!(canon + '/').startsWith(baseWithSep, Qt::CaseInsensitive))
        return jsonErr("Truy cập bị từ chối", 403);

    QFile f(canon);
    if (!f.open(QIODevice::ReadOnly))
        return jsonErr("Không mở được file", 404);
    const QByteArray bytes = f.readAll();

    const QString ext = QFileInfo(canon).suffix().toLower();
    QByteArray ct = "application/octet-stream";
    if (ext == "jpg" || ext == "jpeg") ct = "image/jpeg";
    else if (ext == "png")             ct = "image/png";
    return httpResponse(200, ct, bytes);
}

QByteArray HttpBridge::serveStatic(const QString &name)
{
    QFile f(":/pickup/" + name);
    if (!f.open(QIODevice::ReadOnly))
        return httpResponse(404, "text/plain; charset=utf-8", "Not found");
    return httpResponse(200, "text/html; charset=utf-8", f.readAll());
}

// ─────────────────────────────────────────────────────────────────────────────
// SSE push
// ─────────────────────────────────────────────────────────────────────────────

void HttpBridge::pushEvent(const QString &type, const QJsonObject &data)
{
    QJsonObject ev;
    ev["type"] = type;
    ev["data"] = data;
    QByteArray line = "data: "
        + QJsonDocument(ev).toJson(QJsonDocument::Compact)
        + "\n\n";

    // Xóa các socket đã đóng
    m_sseClients.erase(
        std::remove_if(m_sseClients.begin(), m_sseClients.end(),
                       [](QTcpSocket *s){ return !s->isOpen(); }),
        m_sseClients.end());

    for (QTcpSocket *s : m_sseClients) {
        s->write(line);
        s->flush();
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Response helpers
// ─────────────────────────────────────────────────────────────────────────────

static const char* statusText(int code)
{
    switch (code) {
        case 200: return "OK";
        case 204: return "No Content";
        case 400: return "Bad Request";
        case 401: return "Unauthorized";
        case 403: return "Forbidden";
        case 404: return "Not Found";
        case 405: return "Method Not Allowed";
        case 503: return "Service Unavailable";
        default:  return "Error";
    }
}

QByteArray HttpBridge::httpResponse(int status,
                                    const QByteArray &ct,
                                    const QByteArray &body)
{
    QByteArray r;
    r  = "HTTP/1.1 " + QByteArray::number(status) + " " + statusText(status) + "\r\n";
    r += "Access-Control-Allow-Origin: *\r\n";
    r += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n";
    r += "Access-Control-Allow-Headers: Content-Type\r\n";
    if (!ct.isEmpty())
        r += "Content-Type: " + ct + "\r\n";
    r += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
    r += "Connection: close\r\n";
    r += "\r\n";
    r += body;
    return r;
}

QByteArray HttpBridge::jsonOk(const QJsonObject &obj)
{
    return httpResponse(200, "application/json; charset=utf-8",
                        QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

QByteArray HttpBridge::jsonOk(const QVariantMap &map)
{
    return jsonOk(QJsonObject::fromVariantMap(map));
}

QByteArray HttpBridge::jsonErr(const QString &msg, int code)
{
    return httpResponse(code, "application/json; charset=utf-8",
                        QJsonDocument(QJsonObject{{"error", msg}}).toJson(QJsonDocument::Compact));
}

QByteArray HttpBridge::sseHandshake()
{
    return "HTTP/1.1 200 OK\r\n"
           "Content-Type: text/event-stream\r\n"
           "Cache-Control: no-cache\r\n"
           "Access-Control-Allow-Origin: *\r\n"
           "Connection: keep-alive\r\n"
           "\r\n";
}
