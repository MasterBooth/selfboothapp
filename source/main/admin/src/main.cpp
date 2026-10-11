// ─────────────────────────────────────────────────────────────────────────────
// BOOTHME_ADMIN — công cụ cấp giấy phép.
//
// Đây là app DUY NHẤT giữ khoá ký. Không cài lên máy booth, không đưa cho khách.
// Bản build BOOTHME của khách chỉ có khoá công khai nên không ký được gì.
//
// Luồng: mở khoá sổ → xem danh sách máy đang chờ → đối chiếu đơn hàng →
//        chọn hạng + thời hạn → KÝ TẠI MÁY NÀY → nộp blob đã ký lên Worker.
//
// Worker và D1 không bao giờ thấy khoá private; chúng chỉ lưu và phát lại blob.
// ─────────────────────────────────────────────────────────────────────────────
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QQuickStyle>

#include "LicenseSigner.h"
#include "AdminApi.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    // Style native của Windows không cho tuỳ biến nền control (ô nhập, nút): dùng
    // Basic để giao diện theo đúng design.md trên mọi máy.
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    app.setApplicationName(QStringLiteral("BOOTHME Admin"));
    app.setOrganizationName(QStringLiteral("BoothOS"));

    LicenseSigner signer;
    AdminApi api;

    // Không chặn khởi động nếu thiếu cấu hình — màn hình sẽ báo và cho nhập tay.
    QString cfgErr;
    if (!api.loadConfig(&cfgErr))
        qWarning() << "[Admin]" << cfgErr;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("signer"), &signer);
    engine.rootContext()->setContextProperty(QStringLiteral("api"), &api);

    engine.load(QUrl(QStringLiteral("qrc:/admin/Main.qml")));
    if (engine.rootObjects().isEmpty()) return -1;

    return app.exec();
}
