#include "RelayController.h"
#include "EventManager.h"

#include <QCoreApplication>
#include <QProcess>
#include <QFileInfo>
#include <QDir>
#include <QDebug>
#include <algorithm>

// CREATE_NO_WINDOW = 0x08000000 — dung de helper console khong nhay cua so den.
// (Khong include <windows.h> de tranh xung dot ten voi Qt.)
static const unsigned long kCreateNoWindow = 0x08000000;

RelayController::RelayController(EventManager *eventManager, QObject *parent)
    : QObject(parent), m_em(eventManager)
{
    if (m_em) {
        m_enabled = m_em->getAppSetting("relay_enabled", "true") == "true";
        m_serial  = m_em->getAppSetting("relay_selected_serial", "");
    }

    // Da bat tu truoc -> tu quet & ket noi khi khoi dong (bat dong bo).
    if (m_enabled)
        QMetaObject::invokeMethod(this, "scanAndConnect", Qt::QueuedConnection);
}

QString RelayController::helperPath() const
{
    return QDir(QCoreApplication::applicationDirPath()).filePath("relay/RelayCli.exe");
}

void RelayController::setEnabled(bool on)
{
    if (m_enabled == on)
        return;
    m_enabled = on;
    if (m_em)
        m_em->setAppSetting("relay_enabled", on ? "true" : "false");
    emit enabledChanged();

    if (on) {
        scanAndConnect();
    } else {
        // Tat tinh nang -> tat luon relay dang bat cho an toan.
        if (m_connected)
            runSet(false);
        m_connected = false;
        emit connectedChanged();
    }
}

void RelayController::scanAndConnect()
{
    if (m_scanning)
        return;

    const QString helper = helperPath();
    if (!QFileInfo::exists(helper)) {
        emit error(QStringLiteral("Khong tim thay helper relay: ") + helper);
        emit scanFinished(false, QStringLiteral("Khong tim thay RelayCli.exe"));
        return;
    }

    m_scanning = true;
    emit scanningChanged();

    QProcess *proc = new QProcess(this);
#ifdef Q_OS_WIN
    proc->setCreateProcessArgumentsModifier(
        [](QProcess::CreateProcessArguments *args) { args->flags |= kCreateNoWindow; });
#endif

    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError) {
        m_scanning = false;
        emit scanningChanged();
        emit scanFinished(false, QStringLiteral("Khong chay duoc helper relay"));
        proc->deleteLater();
    });

    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [this, proc](int, QProcess::ExitStatus) {
        const QString out = QString::fromUtf8(proc->readAllStandardOutput());
        proc->deleteLater();

        QStringList serials;
        QMap<QString, int> channels;
        const QStringList lines = out.split('\n', Qt::SkipEmptyParts);
        for (const QString &line : lines) {
            const QStringList parts = line.split('\t');
            if (parts.isEmpty())
                continue;
            const QString serial = parts.at(0).trimmed();
            if (serial.isEmpty())
                continue;
            int ch = (parts.size() > 1) ? parts.at(1).trimmed().toInt() : 0;
            serials << serial;
            channels.insert(serial, ch);
        }

        m_devices = serials;
        m_deviceChannels = channels;
        emit devicesChanged();

        // Giu serial cu neu con cam; neu khong, tu chon thiet bi dau tien.
        if (!m_serial.isEmpty() && serials.contains(m_serial)) {
            // giu nguyen
        } else if (!serials.isEmpty()) {
            m_serial = serials.first();
            if (m_em)
                m_em->setAppSetting("relay_selected_serial", m_serial);
        } else {
            m_serial.clear();
        }

        m_channelCount = m_deviceChannels.value(m_serial, 0);
        emit channelsChanged();

        m_connected = !m_serial.isEmpty();
        emit connectedChanged();

        m_scanning = false;
        emit scanningChanged();

        if (m_connected)
            emit scanFinished(true, m_serial);
        else
            emit scanFinished(false, QStringLiteral("Khong tim thay thiet bi relay"));
    });

    proc->start(helper, QStringList() << QStringLiteral("list"));
}

void RelayController::selectDevice(const QString &serial)
{
    if (serial.isEmpty() || serial == m_serial)
        return;
    m_serial = serial;
    if (m_em)
        m_em->setAppSetting("relay_selected_serial", serial);
    m_channelCount = m_deviceChannels.value(serial, m_channelCount);
    emit channelsChanged();
    m_connected = m_devices.contains(serial);
    emit connectedChanged();
}

QString RelayController::channelName(int ch) const
{
    const QString def = QStringLiteral("Relay %1").arg(ch);
    if (!m_em)
        return def;
    return m_em->getAppSetting(QStringLiteral("relay_channel_name_%1").arg(ch), def);
}

void RelayController::setChannelName(int ch, const QString &name)
{
    if (!m_em)
        return;
    const QString val = name.trimmed().isEmpty() ? QStringLiteral("Relay %1").arg(ch)
                                                  : name.trimmed();
    m_em->setAppSetting(QStringLiteral("relay_channel_name_%1").arg(ch), val);
}

QList<int> RelayController::activeChannels() const
{
    QList<int> out;
    const QString csv = m_em ? m_em->getAppSetting("relay_active_channels", "") : QString();
    const QStringList parts = csv.split(',', Qt::SkipEmptyParts);
    for (const QString &p : parts) {
        bool ok = false;
        int v = p.trimmed().toInt(&ok);
        if (ok && v > 0 && !out.contains(v))
            out.append(v);
    }
    return out;
}

bool RelayController::isChannelActive(int ch) const
{
    return activeChannels().contains(ch);
}

void RelayController::setChannelActive(int ch, bool on)
{
    if (!m_em)
        return;
    QList<int> chans = activeChannels();
    chans.removeAll(ch);
    if (on)
        chans.append(ch);
    std::sort(chans.begin(), chans.end());

    QStringList parts;
    for (int c : chans)
        parts << QString::number(c);
    m_em->setAppSetting("relay_active_channels", parts.join(','));
    emit channelsChanged();
}

void RelayController::activateSelected()
{
    if (!m_enabled || !m_connected || m_serial.isEmpty())
        return;
    if (activeChannels().isEmpty())
        return;
    runSet(true);
}

void RelayController::deactivateSelected()
{
    if (!m_enabled || m_serial.isEmpty())
        return;
    if (activeChannels().isEmpty())
        return;
    runSet(false);
}

void RelayController::runSet(bool on)
{
    const QString helper = helperPath();
    if (!QFileInfo::exists(helper)) {
        emit error(QStringLiteral("Khong tim thay helper relay: ") + helper);
        return;
    }

    QStringList parts;
    for (int c : activeChannels())
        parts << QString::number(c);
    if (parts.isEmpty())
        return;

    QProcess *proc = new QProcess(this);
#ifdef Q_OS_WIN
    proc->setCreateProcessArgumentsModifier(
        [](QProcess::CreateProcessArguments *args) { args->flags |= kCreateNoWindow; });
#endif
    connect(proc, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, [proc](int code, QProcess::ExitStatus) {
        if (code != 0)
            qWarning() << "[RelayController] RelayCli set exit code" << code;
        proc->deleteLater();
    });
    connect(proc, &QProcess::errorOccurred, this, [this, proc](QProcess::ProcessError) {
        emit error(QStringLiteral("Khong chay duoc helper relay"));
        proc->deleteLater();
    });

    // Fire-and-forget: khong block UI thread; thao tac relay rat nhanh.
    proc->start(helper, QStringList()
                << QStringLiteral("set") << m_serial
                << (on ? QStringLiteral("on") : QStringLiteral("off"))
                << parts.join(','));
}
