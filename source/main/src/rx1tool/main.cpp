#include "Rx1ToolPrinterBackend.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setOrganizationName(QStringLiteral("Tivasolutions"));
    app.setApplicationName(QStringLiteral("RX1 Print Tool"));
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    Rx1ToolPrinterBackend printerBackend;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("rx1Printer"), &printerBackend);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(-1); },
                     Qt::QueuedConnection);
    engine.load(QUrl(QStringLiteral("qrc:/rx1tool/Main.qml")));

    return app.exec();
}
