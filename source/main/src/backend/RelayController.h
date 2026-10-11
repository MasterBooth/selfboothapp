#ifndef RELAYCONTROLLER_H
#define RELAYCONTROLLER_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QList>
#include <QMap>

class EventManager;

/**
 * @brief Dieu khien USB Relay tu app Qt 64-bit.
 *
 * DLL relay (usb_relay_device.dll) la 32-bit nen KHONG the nap vao tien trinh
 * 64-bit. Lop nay goi helper 32-bit "relay/RelayCli.exe" qua QProcess de:
 *   - quet & ket noi (lenh "list")
 *   - bat/tat cac kenh (lenh "set <serial> on|off <csv>")
 *
 * Cau hinh luu qua EventManager (SQLite app_settings): relay_enabled,
 * relay_selected_serial, relay_active_channels (CSV), relay_channel_name_<n>.
 */
class RelayController : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool enabled READ enabled NOTIFY enabledChanged)
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString currentSerial READ currentSerial NOTIFY connectedChanged)
    Q_PROPERTY(QStringList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(int channelCount READ channelCount NOTIFY channelsChanged)

public:
    explicit RelayController(EventManager *eventManager, QObject *parent = nullptr);

    bool enabled() const { return m_enabled; }
    bool scanning() const { return m_scanning; }
    bool connected() const { return m_connected; }
    QString currentSerial() const { return m_serial; }
    QStringList devices() const { return m_devices; }
    int channelCount() const { return m_channelCount; }

    // Bat/tat tinh nang relay (luu cai dat). Khi bat se tu quet & ket noi.
    Q_INVOKABLE void setEnabled(bool on);

    // Quet thiet bi qua helper (bat dong bo). Phat scanFinished(ok, message).
    Q_INVOKABLE void scanAndConnect();

    // Chon thiet bi theo serial (luu cai dat, cap nhat so kenh).
    Q_INVOKABLE void selectDevice(const QString &serial);

    // Ten hien thi cua 1 kenh (mac dinh "Relay <ch>").
    Q_INVOKABLE QString channelName(int ch) const;
    Q_INVOKABLE void setChannelName(int ch, const QString &name);

    // Kenh co duoc chon dung khi chup hay khong.
    Q_INVOKABLE bool isChannelActive(int ch) const;
    Q_INVOKABLE void setChannelActive(int ch, bool on);

    // Bat/tat cac kenh da chon (goi tu CaptureScreen). No-op neu chua bat/ket noi.
    Q_INVOKABLE void activateSelected();
    Q_INVOKABLE void deactivateSelected();

signals:
    void enabledChanged();
    void scanningChanged();
    void connectedChanged();
    void devicesChanged();
    void channelsChanged();
    void scanFinished(bool ok, const QString &message);
    void error(const QString &message);

private:
    QString helperPath() const;
    QList<int> activeChannels() const;
    void runSet(bool on);

    EventManager *m_em = nullptr;
    bool m_enabled = false;
    bool m_scanning = false;
    bool m_connected = false;
    QString m_serial;
    QStringList m_devices;
    int m_channelCount = 0;
    QMap<QString, int> m_deviceChannels;   // serial -> so kenh (tu lan quet gan nhat)
};

#endif // RELAYCONTROLLER_H
