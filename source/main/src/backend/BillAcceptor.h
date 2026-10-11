#pragma once
#include <QObject>
#include <QTimer>
#include <QStringList>
#include <windows.h>

// ICT106 General Protocol bill acceptor driver (Windows HANDLE serial, no Qt SerialPort)
class BillAcceptor : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool    connected      READ isConnected      NOTIFY connectedChanged)
    Q_PROPERTY(bool    running        READ isRunning        NOTIFY runningChanged)
    Q_PROPERTY(bool    reconnecting   READ isReconnecting   NOTIFY reconnectingChanged)
    Q_PROPERTY(int     receivedAmount READ receivedAmount   NOTIFY receivedAmountChanged)
    Q_PROPERTY(QString portName       READ portName         NOTIFY portNameChanged)

public:
    explicit BillAcceptor(QObject *parent = nullptr);
    ~BillAcceptor();

    bool    isConnected()    const { return m_connected; }
    bool    isRunning()      const { return m_running; }
    bool    isReconnecting() const { return m_reconnecting; }
    int     receivedAmount() const { return m_receivedAmount; }
    QString portName()       const { return m_portName; }

    static int denominationValue(quint8 billType);

    Q_INVOKABLE bool        openPort(const QString &portName);
    Q_INVOKABLE void        closePort();
    Q_INVOKABLE void        tryReconnect();
    Q_INVOKABLE void        startSession(int requiredAmount);
    Q_INVOKABLE void        stopSession();
    Q_INVOKABLE void        resetAmount();
    Q_INVOKABLE static QStringList availablePorts();

signals:
    void connectedChanged();
    void runningChanged();
    void reconnectingChanged();
    void receivedAmountChanged();
    void portNameChanged();
    void billAccepted(int denomination, int totalReceived);
    void paymentComplete(int totalReceived);
    void errorOccurred(const QString &message);

private slots:
    void onPollTimer();
    void attemptReconnect();

private:
    bool openPortImpl(const QString &portName, bool emitErrors);
    bool writeByteToPort(quint8 byte);
    void handleEscrow(quint8 billType);
    void processReadBuffer(const QByteArray &data);
    void handlePortLoss(const QString &reason);
    void setConnected(bool v);
    void setRunning(bool v);
    void setReconnecting(bool v);

    HANDLE   m_hPort           = INVALID_HANDLE_VALUE;
    QTimer  *m_pollTimer       = nullptr;
    QTimer  *m_reconnectTimer  = nullptr;

    bool     m_connected       = false;
    bool     m_running         = false;
    bool     m_reconnecting    = false;
    bool     m_powerAcked      = false;
    bool     m_sessionPending  = false; // session was active when port was lost
    QString  m_portName;

    int      m_receivedAmount  = 0;
    int      m_requiredAmount  = 0;
    int      m_writeFailCount  = 0;
    qint64   m_lastRxTime      = 0;     // ms timestamp of last received byte (watchdog)
};
