#include "BillAcceptor.h"
#include <QDebug>
#include <QDateTime>

namespace ICT106 {
    static constexpr quint8 PWR_ON_1    = 0x80;
    static constexpr quint8 PWR_ON_2    = 0x8F;
    static constexpr quint8 BILL_VALID  = 0x81;
    static constexpr quint8 STATUS_REQ  = 0x0C;
    static constexpr quint8 BILL_MIN    = 0x40;
    static constexpr quint8 BILL_MAX    = 0x45;
    static constexpr quint8 CMD_ACCEPT  = 0x02;
    static constexpr quint8 CMD_REJECT  = 0x0F;
    static constexpr quint8 CMD_ENABLE  = 0x3E;
    static constexpr quint8 CMD_DISABLE = 0x5E;

    // VND denominations: index 0 = 0x40 (1st bill type)
    static const int DENOM[] = { 10000, 20000, 50000, 100000, 200000, 500000 };

    static constexpr int WRITE_FAIL_THRESHOLD = 3;    // consecutive write fails → port loss
    static constexpr int WATCHDOG_MS          = 30000; // no RX during active session → port loss
    static constexpr int RECONNECT_MS         = 4000;  // retry interval after disconnect
}

// ── Constructor / Destructor ──────────────────────────────────────────────────

BillAcceptor::BillAcceptor(QObject *parent) : QObject(parent) {
    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(150);
    connect(m_pollTimer, &QTimer::timeout, this, &BillAcceptor::onPollTimer);

    m_reconnectTimer = new QTimer(this);
    m_reconnectTimer->setSingleShot(true);
    m_reconnectTimer->setInterval(ICT106::RECONNECT_MS);
    connect(m_reconnectTimer, &QTimer::timeout, this, &BillAcceptor::attemptReconnect);
}

BillAcceptor::~BillAcceptor() {
    m_reconnectTimer->stop();
    closePort();
}

// ── Static helpers ────────────────────────────────────────────────────────────

int BillAcceptor::denominationValue(quint8 billType) {
    int idx = billType - ICT106::BILL_MIN;
    if (idx >= 0 && idx < 6) return ICT106::DENOM[idx];
    return 0;
}

QStringList BillAcceptor::availablePorts() {
    QStringList list;
    TCHAR target[256];
    for (int i = 1; i <= 256; i++) {
        QString name = QString("COM%1").arg(i);
        if (QueryDosDeviceW(reinterpret_cast<LPCWSTR>(name.utf16()), target, 256) != 0)
            list << name;
    }
    return list;
}

// ── Port management ───────────────────────────────────────────────────────────

bool BillAcceptor::openPort(const QString &portName) {
    return openPortImpl(portName, /*emitErrors=*/true);
}

bool BillAcceptor::openPortImpl(const QString &portName, bool emitErrors) {
    // Close existing handle if any (e.g. switching ports from Settings)
    if (m_hPort != INVALID_HANDLE_VALUE) {
        m_pollTimer->stop();
        DWORD w = 0;
        quint8 dis = ICT106::CMD_DISABLE;
        WriteFile(m_hPort, &dis, 1, &w, nullptr);
        CloseHandle(m_hPort);
        m_hPort = INVALID_HANDLE_VALUE;
        // Reset state NOW — if the new port fails to open the object must
        // not remain "connected" with a stopped timer and no valid handle.
        m_powerAcked     = false;
        m_sessionPending = m_running;
        setRunning(false);
        setConnected(false);
    }

    // Windows requires \\.\COMx for port numbers above 9
    QString fullName = "\\\\.\\" + portName;
    m_hPort = CreateFileW(
        reinterpret_cast<LPCWSTR>(fullName.utf16()),
        GENERIC_READ | GENERIC_WRITE,
        0, nullptr, OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL, nullptr);

    if (m_hPort == INVALID_HANDLE_VALUE) {
        QString err = QString("Không thể mở %1 (error %2)").arg(portName).arg(GetLastError());
        qWarning() << "[BillAcceptor]" << err;
        if (emitErrors) emit errorOccurred(err);
        return false;
    }

    // Configure DCB: 9600 8E1
    DCB dcb = {};
    dcb.DCBlength = sizeof(DCB);
    if (!GetCommState(m_hPort, &dcb)) {
        CloseHandle(m_hPort); m_hPort = INVALID_HANDLE_VALUE;
        if (emitErrors) emit errorOccurred("GetCommState thất bại");
        return false;
    }
    dcb.BaudRate = CBR_9600;
    dcb.ByteSize = 8;
    dcb.Parity   = EVENPARITY;
    dcb.StopBits = ONESTOPBIT;
    dcb.fParity  = TRUE;
    if (!SetCommState(m_hPort, &dcb)) {
        CloseHandle(m_hPort); m_hPort = INVALID_HANDLE_VALUE;
        if (emitErrors) emit errorOccurred("SetCommState thất bại");
        return false;
    }

    // Non-blocking reads: return immediately with whatever is in the buffer
    COMMTIMEOUTS to = {};
    to.ReadIntervalTimeout         = MAXDWORD;
    to.ReadTotalTimeoutMultiplier  = 0;
    to.ReadTotalTimeoutConstant    = 0;
    to.WriteTotalTimeoutMultiplier = 0;
    to.WriteTotalTimeoutConstant   = 50;
    if (!SetCommTimeouts(m_hPort, &to)) {
        CloseHandle(m_hPort); m_hPort = INVALID_HANDLE_VALUE;
        if (emitErrors) emit errorOccurred("SetCommTimeouts thất bại");
        return false;
    }

    // Flush stale hardware buffers before starting
    PurgeComm(m_hPort, PURGE_RXCLEAR | PURGE_TXCLEAR);

    m_portName      = portName;
    m_powerAcked    = false;
    m_writeFailCount = 0;
    m_lastRxTime    = QDateTime::currentMSecsSinceEpoch();

    setConnected(true);
    setReconnecting(false);
    m_pollTimer->start();
    emit portNameChanged();
    qDebug() << "[BillAcceptor] Opened" << portName;
    return true;
}

void BillAcceptor::closePort() {
    // Intentional close from user/Settings — stop reconnect attempts
    m_reconnectTimer->stop();
    m_pollTimer->stop();
    if (m_hPort != INVALID_HANDLE_VALUE) {
        DWORD w = 0; quint8 dis = ICT106::CMD_DISABLE;
        WriteFile(m_hPort, &dis, 1, &w, nullptr);
        CloseHandle(m_hPort);
        m_hPort = INVALID_HANDLE_VALUE;
    }
    m_powerAcked     = false;
    m_sessionPending = false;
    m_receivedAmount = 0;
    emit receivedAmountChanged();
    setConnected(false);
    setReconnecting(false);
    setRunning(false);
}

// ── Session control ───────────────────────────────────────────────────────────

void BillAcceptor::startSession(int requiredAmount) {
    if (!m_connected) return;
    m_requiredAmount  = requiredAmount;
    m_receivedAmount  = 0;
    m_sessionPending  = false;
    m_writeFailCount  = 0;
    // Reset power-ack so we can re-handshake if device auto-resets after the
    // previous CMD_DISABLE (ICT106 devices commonly send a fresh 0x8F after
    // being inhibited; without this reset we would silently skip the ACK).
    m_powerAcked      = false;
    emit receivedAmountChanged();
    // Flush RX to discard any stale bytes from previous session
    if (m_hPort != INVALID_HANDLE_VALUE)
        PurgeComm(m_hPort, PURGE_RXCLEAR);
    writeByteToPort(ICT106::CMD_ENABLE);
    setRunning(true);
    m_lastRxTime = QDateTime::currentMSecsSinceEpoch();
    qDebug() << "[BillAcceptor] Session started, required:" << requiredAmount;
}

void BillAcceptor::stopSession() {
    m_sessionPending = false;
    if (!m_connected) { setRunning(false); return; }
    writeByteToPort(ICT106::CMD_DISABLE);
    // Reset amount so stale value never bleeds into the next session's isDone binding
    m_receivedAmount = 0;
    emit receivedAmountChanged();
    setRunning(false);
}

void BillAcceptor::resetAmount() {
    m_receivedAmount = 0;
    emit receivedAmountChanged();
}

// ── Serial I/O ────────────────────────────────────────────────────────────────

bool BillAcceptor::writeByteToPort(quint8 byte) {
    if (m_hPort == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    if (!WriteFile(m_hPort, &byte, 1, &written, nullptr) || written == 0) {
        m_writeFailCount++;
        qWarning() << "[BillAcceptor] WriteFile failed (count:" << m_writeFailCount
                   << "error:" << GetLastError() << ")";
        return false;
    }
    m_writeFailCount = 0;
    return true;
}

void BillAcceptor::onPollTimer() {
    if (m_hPort == INVALID_HANDLE_VALUE) return;

    // ── 1. Detect accumulated write failures ──────────────────────────────────
    if (m_writeFailCount >= ICT106::WRITE_FAIL_THRESHOLD) {
        handlePortLoss(QString("WriteFile failed %1 times").arg(m_writeFailCount));
        return;
    }

    // ── 2. Clear Windows COM error state (prevents ReadFile getting stuck) ────
    DWORD comErr = 0;
    COMSTAT cs   = {};
    ClearCommError(m_hPort, &comErr, &cs);
    if (comErr != 0)
        qWarning() << "[BillAcceptor] ClearCommError flags:" << Qt::hex << comErr;

    // ── 3. Non-blocking read — drain all available bytes ─────────────────────
    char buf[64];
    DWORD bytesRead = 0;
    QByteArray data;
    while (ReadFile(m_hPort, buf, sizeof(buf), &bytesRead, nullptr) && bytesRead > 0)
        data.append(buf, static_cast<int>(bytesRead));

    if (!data.isEmpty()) {
        m_lastRxTime     = QDateTime::currentMSecsSinceEpoch();
        m_writeFailCount = 0;
        processReadBuffer(data);
    }

    // ── 4. Keepalive: poll device status every tick ───────────────────────────
    // Also send STATUS_REQ while running even if powerAcked was just reset,
    // so the device stays responsive while it sends its fresh power-up bytes.
    if (m_powerAcked || m_running)
        writeByteToPort(ICT106::STATUS_REQ);

    // ── 5. Watchdog: no RX during active session → device dead ───────────────
    if (m_running && m_lastRxTime > 0) {
        qint64 silentMs = QDateTime::currentMSecsSinceEpoch() - m_lastRxTime;
        if (silentMs > ICT106::WATCHDOG_MS) {
            handlePortLoss(QString("Watchdog: no data for %1 ms during session").arg(silentMs));
        }
    }
}

void BillAcceptor::processReadBuffer(const QByteArray &data) {
    for (int i = 0; i < data.size(); i++) {
        quint8 b = static_cast<quint8>(data[i]);

        // ── Power-up handshake ────────────────────────────────────────────────
        if (b == ICT106::PWR_ON_1) continue;

        if (b == ICT106::PWR_ON_2) {
            // Always ACK power-up: device may re-send 0x8F after CMD_DISABLE
            // (common ICT106 behaviour — it resets between sessions).
            writeByteToPort(ICT106::CMD_ACCEPT); // 0x02 = power-up ACK
            if (!m_powerAcked) {
                m_powerAcked = true;
                qDebug() << "[BillAcceptor] Power-up ACK sent";
            } else {
                qDebug() << "[BillAcceptor] Device re-init after session, re-ACK sent";
            }

            // Resume / re-enable session if one is pending or already running
            if (m_sessionPending) {
                m_sessionPending = false;
                writeByteToPort(ICT106::CMD_ENABLE);
                setRunning(true);
                qDebug() << "[BillAcceptor] Session resumed after reconnect,"
                         << "received so far:" << m_receivedAmount;
            } else if (m_running) {
                // Device reset after startSession() was already called — re-enable
                writeByteToPort(ICT106::CMD_ENABLE);
                qDebug() << "[BillAcceptor] Re-enabled after device reset during active session";
            }
            continue;
        }

        // ── Bill validated (next byte = denomination) ─────────────────────────
        if (b == ICT106::BILL_VALID) continue;

        // ── Denomination byte → escrow decision ───────────────────────────────
        if (b >= ICT106::BILL_MIN && b <= ICT106::BILL_MAX) {
            handleEscrow(b);
            continue;
        }

        // ── Device status / error bytes (Section 3.3) ────────────────────────
        switch (b) {
        case 0x20:
            qWarning() << "[BillAcceptor] Motor Failure";
            emit errorOccurred("Lỗi motor máy đọc tiền — kiểm tra thiết bị");
            break;
        case 0x22:
            qWarning() << "[BillAcceptor] Bill Jam";
            emit errorOccurred("Tiền bị kẹt — vui lòng gỡ tờ tiền và thử lại");
            break;
        case 0x24:
            qWarning() << "[BillAcceptor] Stacker Open";
            emit errorOccurred("Khay chứa tiền đang mở — vui lòng đóng lại");
            break;
        case 0x25:
            qWarning() << "[BillAcceptor] Sensor Problem";
            emit errorOccurred("Cảm biến máy đọc lỗi — kiểm tra thiết bị");
            break;
        case 0x28:
            qWarning() << "[BillAcceptor] Stacker Problem";
            emit errorOccurred("Lỗi khay chứa tiền — kiểm tra thiết bị");
            break;
        case 0xA1:
            // Device itself reports communication failure → treat as port loss
            qWarning() << "[BillAcceptor] Device reported Communication Failure (0xA1)";
            m_writeFailCount = ICT106::WRITE_FAIL_THRESHOLD; // trigger reconnect on next tick
            break;
        // Informational — log only
        case 0x21: qDebug() << "[BillAcceptor] Checksum Error (internal)"; break;
        case 0x23: qDebug() << "[BillAcceptor] Bill Remove"; break;
        case 0x29: qDebug() << "[BillAcceptor] Bill Rejected by device"; break;
        case 0x2A: qWarning() << "[BillAcceptor] Invalid Command sent"; break;
        case 0x3E: qDebug() << "[BillAcceptor] Device: Enable status"; break;
        case 0x5E: qDebug() << "[BillAcceptor] Device: Inhibit status"; break;
        case 0x71: qDebug() << "[BillAcceptor] Device: Busy"; break;
        case 0x83: qDebug() << "[BillAcceptor] Stack finish (jam recovery)"; break;
        default:   break;
        }
    }
}

void BillAcceptor::handleEscrow(quint8 billType) {
    int value = denominationValue(billType);
    qDebug() << "[BillAcceptor] Escrow" << Qt::hex << billType
             << Qt::dec << value << "VND";

    if (value <= 0 || !m_running) {
        writeByteToPort(ICT106::CMD_REJECT);
        return;
    }

    writeByteToPort(ICT106::CMD_ACCEPT);
    m_receivedAmount += value;
    emit receivedAmountChanged();
    emit billAccepted(value, m_receivedAmount);

    if (m_requiredAmount > 0 && m_receivedAmount >= m_requiredAmount) {
        writeByteToPort(ICT106::CMD_DISABLE);
        setRunning(false);
        m_sessionPending = false;
        emit paymentComplete(m_receivedAmount);
        qDebug() << "[BillAcceptor] Payment complete, total:" << m_receivedAmount;
    }
}

// ── Reconnect logic ───────────────────────────────────────────────────────────

void BillAcceptor::tryReconnect() {
    if (m_connected) return;
    if (m_portName.isEmpty()) return;
    qDebug() << "[BillAcceptor] tryReconnect() triggered from UI on" << m_portName;
    m_reconnectTimer->stop(); // avoid racing with the auto-reconnect timer
    if (!openPortImpl(m_portName, /*emitErrors=*/true))
        m_reconnectTimer->start(); // fall back to periodic retry if immediate attempt fails
}

void BillAcceptor::handlePortLoss(const QString &reason) {
    if (!m_connected) return; // already handling a loss

    qWarning() << "[BillAcceptor] Port loss:" << reason;

    m_pollTimer->stop();
    if (m_hPort != INVALID_HANDLE_VALUE) {
        CloseHandle(m_hPort); // don't try to write DISABLE — port is broken
        m_hPort = INVALID_HANDLE_VALUE;
    }

    // Remember if a session was active so we can resume after reconnect
    m_sessionPending = m_running;
    m_powerAcked     = false;
    m_writeFailCount = 0;

    setRunning(false);
    setConnected(false);
    setReconnecting(true);

    emit errorOccurred("Mất kết nối đầu đọc tiền — đang thử kết nối lại...");

    if (!m_portName.isEmpty())
        m_reconnectTimer->start();
}

void BillAcceptor::attemptReconnect() {
    if (m_connected) return;

    qDebug() << "[BillAcceptor] Attempting reconnect on" << m_portName;

    if (openPortImpl(m_portName, /*emitErrors=*/false)) {
        qDebug() << "[BillAcceptor] Reconnected on" << m_portName;
        // Session resume is handled in processReadBuffer after power-up ACK
    } else {
        qWarning() << "[BillAcceptor] Reconnect failed, retry in"
                   << ICT106::RECONNECT_MS << "ms";
        m_reconnectTimer->start();
    }
}

// ── Property setters ──────────────────────────────────────────────────────────

void BillAcceptor::setConnected(bool v) {
    if (m_connected == v) return;
    m_connected = v;
    emit connectedChanged();
}

void BillAcceptor::setRunning(bool v) {
    if (m_running == v) return;
    m_running = v;
    emit runningChanged();
}

void BillAcceptor::setReconnecting(bool v) {
    if (m_reconnecting == v) return;
    m_reconnecting = v;
    emit reconnectingChanged();
}
