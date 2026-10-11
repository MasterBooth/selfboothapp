#include "ConfigManager.h"
#include "DatabaseManager.h"
#include "AppPaths.h"
#include "PrinterConfig.h"
#include "PrinterManager.h"
#include "StudioAccount.h"
#include "PrintJobClient.h"

#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSysInfo>
#include <QCryptographicHash>
#include <QHostInfo>
#include <QDir>

static QString printStationHwid()
{
    QByteArray seed = QSysInfo::machineUniqueId();
    if (seed.isEmpty()) seed = QHostInfo::localHostName().toUtf8();
    if (seed.isEmpty()) seed = QSysInfo::prettyProductName().toUtf8();
    const QByteArray hash = QCryptographicHash::hash(seed, QCryptographicHash::Sha256).toHex();
    return QStringLiteral("ps_%1").arg(QString::fromLatin1(hash.left(24)));
}

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("BoothPrintStation"));
    QCoreApplication::setOrganizationName(QStringLiteral("BoothOS"));
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    ConfigManager *config = ConfigManager::instance();
    config->loadConfig(AppPaths::instance().getConfigPath());

    DatabaseManager database;
    database.initialize(QDir(QCoreApplication::applicationDirPath()).filePath(QStringLiteral("data/printstation_settings.db")));

    PrinterConfig printerConfig;
    printerConfig.setDatabaseManager(&database);
    printerConfig.loadGlobal();

    PrinterManager printerManager;
    printerManager.setPrinterConfig(&printerConfig);
    printerManager.setListAllWindowsPrinters(true);

    StudioAccount studioAccount(config, printStationHwid(), &app);
    studioAccount.restore();
    studioAccount.registerMachine();

    PrintJobClient printJobs(config, &app);
    QObject::connect(&studioAccount, &StudioAccount::signedIn, &printJobs, [&printJobs]() {
        printJobs.start();
    });
    QObject::connect(&studioAccount, &StudioAccount::signedOut, &printJobs, &PrintJobClient::stop);
    if (studioAccount.loggedIn()) printJobs.start();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("studioAccount"), &studioAccount);
    engine.rootContext()->setContextProperty(QStringLiteral("printerConfig"), &printerConfig);
    engine.rootContext()->setContextProperty(QStringLiteral("printerManager"), &printerManager);
    engine.rootContext()->setContextProperty(QStringLiteral("printJobs"), &printJobs);
    engine.rootContext()->setContextProperty(QStringLiteral("printStationHwid"), printStationHwid());

    const QUrl url(QStringLiteral("qrc:/printstation/Main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) QCoreApplication::exit(-1);
        }, Qt::QueuedConnection);
    engine.load(url);
    return app.exec();
}
