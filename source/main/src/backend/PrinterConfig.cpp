#include "PrinterConfig.h"
#include "DatabaseManager.h"
#include <QDebug>
#include <QSqlQuery>
#include <QSqlError>
#include <QVariant>

namespace {
bool isSupportedDnpPrinter(const QString &printer)
{
    QString name = printer.trimmed();
    return name.contains("RX1", Qt::CaseInsensitive)
        || name.contains("DS-RX1", Qt::CaseInsensitive)
        || name.contains("DS620", Qt::CaseInsensitive)
        || name.contains("DS-620", Qt::CaseInsensitive);
}

QString normalizeSupportedDnpPrinter(const QString &printer)
{
    return isSupportedDnpPrinter(printer) ? printer.trimmed() : QStringLiteral("DS-RX1");
}
}

PrinterConfig::PrinterConfig(QObject *parent)
    : QObject(parent)
{
    qDebug() << "[PrinterConfig] Initialized with defaults";
}

PrinterConfig::~PrinterConfig()
{
}

void PrinterConfig::setSelectedPrinter(const QString &printer)
{
    QString normalized = normalizeSupportedDnpPrinter(printer);
    if (m_selectedPrinter != normalized) {
        if (normalized != printer.trimmed()) {
            qWarning() << "[PrinterConfig] Unsupported printer requested:" << printer
                       << "-> forcing DNP printer:" << normalized;
        }
        m_selectedPrinter = normalized;
        qDebug() << "[PrinterConfig] Selected printer:" << normalized;
        emit selectedPrinterChanged(normalized);
    }
}

void PrinterConfig::setPrintCopies(int copies)
{
    // Clamp between 1 and 10
    int clamped = qMax(1, qMin(10, copies));
    if (m_printCopies != clamped) {
        m_printCopies = clamped;
        qDebug() << "[PrinterConfig] Print copies:" << clamped;
        emit printCopiesChanged(clamped);
    }
}

void PrinterConfig::setPrintMode(const QString &mode)
{
    if (mode != "Color" && mode != "BlackWhite") {
        qWarning() << "[PrinterConfig] Invalid print mode:" << mode << ", using Color";
        return;
    }
    if (m_printMode != mode) {
        m_printMode = mode;
        qDebug() << "[PrinterConfig] Print mode:" << mode;
        emit printModeChanged(mode);
    }
}

void PrinterConfig::setResolution(const QString &res)
{
    qDebug() << "=========================================";
    qDebug() << "[PrinterConfig] setResolution() called with:" << res;
    qDebug() << "[PrinterConfig] Current resolution:" << m_resolution;

    if (res != "300dpi" && res != "600dpi") {
        qWarning() << "[PrinterConfig] *** INVALID RESOLUTION:" << res << "*** (must be 300dpi or 600dpi)";
        qDebug() << "=========================================";
        return;
    }

    if (m_resolution != res) {
        m_resolution = res;
        qDebug() << "[PrinterConfig] *** RESOLUTION CHANGED FROM" << m_resolution << "TO" << res << "***";
        qDebug() << "[PrinterConfig] *** EMITTING resolutionChanged SIGNAL ***";
        emit resolutionChanged(res);
        qDebug() << "=========================================";
    } else {
        qDebug() << "[PrinterConfig] Resolution unchanged, not emitting signal";
        qDebug() << "=========================================";
    }
}

void PrinterConfig::setCutMode(bool enabled)
{
    if (m_cutMode != enabled) {
        m_cutMode = enabled;
        qDebug() << "[PrinterConfig] Cut mode:" << (enabled ? "ON (2 images/sheet)" : "OFF (full sheet)");
        emit cutModeChanged(enabled);
    }
}

void PrinterConfig::saveToDatabase(int eventId)
{
    try {
        if (!m_database) {
            emit settingsSaved(false, "Database manager not available");
            return;
        }

        QSqlQuery query;
        query.prepare("INSERT OR REPLACE INTO printer_settings "
                      "(event_id, printer_name, print_copies, print_mode, resolution, cut_mode) "
                      "VALUES (:event_id, :printer, :copies, :mode, :resolution, :cut_mode)");

        query.bindValue(":event_id", eventId);
        query.bindValue(":printer", m_selectedPrinter);
        query.bindValue(":copies", m_printCopies);
        query.bindValue(":mode", m_printMode);
        query.bindValue(":resolution", m_resolution);
        query.bindValue(":cut_mode", m_cutMode ? 1 : 0);

        if (query.exec()) {
            QString eventStr = (eventId == -1) ? "Global" : QString::number(eventId);
            QString message = QString("Printer settings saved (%1)").arg(eventStr);
            qDebug() << "[PrinterConfig]" << message;
            emit settingsSaved(true, message);
        } else {
            QString error = query.lastError().text();
            qWarning() << "[PrinterConfig] Save failed:" << error;
            emit settingsSaved(false, error);
        }
    } catch (const std::exception &e) {
        QString error = QString::fromStdString(std::string(e.what()));
        qWarning() << "[PrinterConfig] Exception during save:" << error;
        emit settingsSaved(false, error);
    }
}

void PrinterConfig::loadFromDatabase(int eventId)
{
    try {
        if (!m_database) {
            emit settingsLoaded(false, "Database manager not available");
            return;
        }

        QSqlQuery query;
        query.prepare("SELECT * FROM printer_settings WHERE event_id = :event_id");
        query.bindValue(":event_id", eventId);

        if (query.exec()) {
            if (query.next()) {
                // Load settings silently (don't emit signals to avoid property change cascades)
                m_selectedPrinter = normalizeSupportedDnpPrinter(query.value("printer_name").toString());
                m_printCopies = query.value("print_copies").toInt();
                m_printMode = query.value("print_mode").toString();
                m_resolution = query.value("resolution").toString();
                m_cutMode = query.value("cut_mode").toInt() == 1;

                QString eventStr = (eventId == -1) ? "Global" : QString::number(eventId);
                QString message = QString("Printer settings loaded (%1)").arg(eventStr);
                qDebug() << "[PrinterConfig]" << message;
                qDebug() << "  Printer:" << m_selectedPrinter;
                qDebug() << "  Copies:" << m_printCopies;
                qDebug() << "  Mode:" << m_printMode;
                qDebug() << "  Resolution:" << m_resolution;
                qDebug() << "  Cut Mode:" << (m_cutMode ? "ON" : "OFF");

                emit settingsLoaded(true, message);
            } else if (eventId != -1) {
                // Sự kiện chưa có cấu hình riêng → fallback về cấu hình global (-1),
                // giữ mô hình "global làm mặc định" cho mọi sự kiện chưa tuỳ chỉnh.
                qDebug() << "[PrinterConfig] No per-event settings for" << eventId
                         << "→ falling back to Global";
                loadFromDatabase(-1);
            } else {
                // No settings found, use defaults
                QString message = QString("No saved settings found, using defaults (Global)");
                qDebug() << "[PrinterConfig]" << message;
                emit settingsLoaded(true, message);
            }
        } else {
            QString error = query.lastError().text();
            qWarning() << "[PrinterConfig] Load failed:" << error;
            emit settingsLoaded(false, error);
        }
    } catch (const std::exception &e) {
        QString error = QString::fromStdString(std::string(e.what()));
        qWarning() << "[PrinterConfig] Exception during load:" << error;
        emit settingsLoaded(false, error);
    }
}

void PrinterConfig::resetToDefaults()
{
    setSelectedPrinter("DS-RX1");
    setPrintCopies(1);
    setPrintMode("Color");
    setResolution("600dpi");
    setCutMode(true);

    qDebug() << "[PrinterConfig] Reset to defaults";
}

QString PrinterConfig::toString() const
{
    return QString("PrinterConfig{printer=%1, copies=%2, mode=%3, resolution=%4, cutMode=%5}")
        .arg(m_selectedPrinter)
        .arg(m_printCopies)
        .arg(m_printMode)
        .arg(m_resolution)
        .arg(m_cutMode ? "ON" : "OFF");
}
