#pragma once

#include <QObject>
#include <QTcpServer>
#include <QTcpSocket>
#include <QJsonObject>
#include <QMap>
#include <QList>

class CameraController;
class EventManager;
class SessionManager;

/**
 * @brief Local HTTP bridge — cho phép Python (hoặc bất kỳ HTTP client nào)
 *        điều khiển Canon EDSDK backend qua localhost.
 *
 * Mặc định port 5514 (tương tự pattern DigiCamControl ở port 5513).
 *
 * ── Endpoints ─────────────────────────────────────────────────────────────
 *  GET  /api/status
 *
 *  Camera:
 *  GET  /api/camera                    – trạng thái (connected, fps, model…)
 *  POST /api/camera/connect            – connectToServer()
 *  POST /api/camera/live-view/start    – startLiveView()
 *  POST /api/camera/live-view/stop     – stopLiveView()
 *  POST /api/camera/capture            – takePicture()
 *  GET  /api/camera/frame              – latest live-view JPEG (binary)
 *  GET  /api/camera/properties         – tất cả giá trị + danh sách tuỳ chọn
 *  POST /api/camera/iso        {"value":"…"}
 *  POST /api/camera/aperture   {"value":"…"}
 *  POST /api/camera/shutter    {"value":"…"}
 *  POST /api/camera/wb         {"value":"…"}
 *  POST /api/camera/ev         {"value":"…"}
 *  POST /api/camera/color-temperature {"value":"5600"}
 *  POST /api/camera/af         {"enabled":true/false}
 *  POST /api/camera/mirror     {"enabled":true/false}
 *
 *  Events (sự kiện):
 *  GET  /api/events
 *  POST /api/events                    – {"name","location","date"}
 *  GET  /api/events/{id}
 *  GET  /api/events/{id}/photos
 *
 *  Sessions:
 *  POST /api/sessions                  – {"eventId":1,"hwid":"…"}
 *  GET  /api/sessions/{id}
 *  GET  /api/sessions/{id}/photos
 *
 *  App settings:
 *  GET  /api/settings/{key}
 *  POST /api/settings/{key}            – {"value":"…"}
 *
 *  Server-Sent Events (push từ C++ → Python):
 *  GET  /api/stream                    – text/event-stream
 *       Sự kiện: imageCaptured, cameraError, liveViewStarted, liveViewStopped
 * ──────────────────────────────────────────────────────────────────────────
 */
class HttpBridge : public QObject {
    Q_OBJECT

public:
    explicit HttpBridge(QObject *parent = nullptr);
    ~HttpBridge() override;

    void setCameraController(CameraController *ctrl) { m_camera   = ctrl; }
    void setEventManager(EventManager *mgr)          { m_events   = mgr;  }
    void setSessionManager(SessionManager *sm)       { m_sessions = sm;   }

    // lan = true → bind 0.0.0.0 (truy cập từ máy khác trong LAN, vd quầy thu ngân).
    //       false → chỉ localhost (giữ hành vi Python SDK).
    bool    start(quint16 port = 5514, bool lan = false);
    void    stop();
    quint16 port() const;

    // PIN/token cho quầy thu ngân LAN. Rỗng = không yêu cầu (LAN mở). Client loopback
    // (Python SDK) luôn được miễn token.
    void setPickupToken(const QString &token) { m_pickupToken = token; }

    // Gửi sự kiện JSON tới tất cả SSE subscriber đang kết nối.
    // type: "imageCaptured" | "cameraError" | "liveViewStarted" | "liveViewStopped"
    void pushEvent(const QString &type, const QJsonObject &data = {});

private slots:
    void onNewConnection();
    void onClientData();
    void onClientDisconnected();

private:
    // ── HTTP parsing ─────────────────────────────────────────────────────────
    struct Request {
        QString method;
        QString path;
        QString query;   // phần sau '?' (chưa decode) — dùng cho token/path/limit
        QMap<QString, QString> headers;
        QByteArray body;
    };

    enum ParseState { WantHeaders, WantBody, Done };

    struct ClientState {
        QByteArray buf;
        Request    req;
        ParseState state = WantHeaders;
        bool       fromLoopback = false;  // true = client localhost (Python SDK) → miễn token
    };

    bool tryParse(ClientState &cs);

    // ── Routing ───────────────────────────────────────────────────────────────
    QByteArray dispatch(const Request &req, bool fromLoopback);
    QByteArray routeCamera(const QString &sub, const QString &method, const QJsonObject &body);
    QByteArray routeEvents(const QString &sub, const QString &method, const QJsonObject &body);
    QByteArray routeSessions(const QString &sub, const QString &method, const QJsonObject &body);
    QByteArray routeSettings(const QString &sub, const QString &method, const QJsonObject &body);

    // Quầy thu ngân LAN
    bool       authOk(const Request &req, bool fromLoopback) const;  // kiểm token cho client LAN
    QByteArray routeFile(const QString &query);                      // trả byte ảnh gốc (guard thư mục)
    QByteArray serveStatic(const QString &name);                     // trang gallery tĩnh (Qt resource)

    // ── Response helpers ──────────────────────────────────────────────────────
    QByteArray httpResponse(int status, const QByteArray &contentType, const QByteArray &body);
    QByteArray jsonOk(const QJsonObject &obj);
    QByteArray jsonOk(const QVariantMap &map);
    QByteArray jsonErr(const QString &msg, int code = 400);
    QByteArray sseHandshake();

    QTcpServer       *m_server   = nullptr;
    CameraController *m_camera   = nullptr;
    EventManager     *m_events   = nullptr;
    SessionManager   *m_sessions = nullptr;

    QMap<QTcpSocket*, ClientState> m_clients;
    QList<QTcpSocket*>             m_sseClients;

    bool     m_lanEnabled  = false;   // đang bind LAN?
    QString  m_pickupToken;           // PIN/token quầy thu ngân (rỗng = không yêu cầu)
};
