#ifndef PRINTERCONFIG_H
#define PRINTERCONFIG_H

#include <QObject>
#include <QString>
#include <QStringList>

class DatabaseManager;  // Forward declaration

/**
 * @class PrinterConfig
 * @brief Manages printer settings and persistence
 *
 * Handles all printer configuration including:
 * - Selected printer name
 * - Print copies count
 * - Print mode (Color/BlackWhite)
 * - Resolution (300/600 dpi)
 * - Cut mode (cut/no-cut for 2-image per sheet)
 *
 * Settings can be saved/loaded per-event or globally.
 */
class PrinterConfig : public QObject {
    Q_OBJECT

    Q_PROPERTY(QString selectedPrinter READ selectedPrinter WRITE setSelectedPrinter NOTIFY selectedPrinterChanged)
    Q_PROPERTY(int printCopies READ printCopies WRITE setPrintCopies NOTIFY printCopiesChanged)
    Q_PROPERTY(QString printMode READ printMode WRITE setPrintMode NOTIFY printModeChanged)
    Q_PROPERTY(QString resolution READ resolution WRITE setResolution NOTIFY resolutionChanged)
    Q_PROPERTY(bool cutMode READ cutMode WRITE setCutMode NOTIFY cutModeChanged)

public:
    explicit PrinterConfig(QObject *parent = nullptr);
    ~PrinterConfig();

    // Property getters
    QString selectedPrinter() const { return m_selectedPrinter; }
    int printCopies() const { return m_printCopies; }
    QString printMode() const { return m_printMode; }
    QString resolution() const { return m_resolution; }
    bool cutMode() const { return m_cutMode; }

    // Property setters
    void setSelectedPrinter(const QString &printer);
    void setPrintCopies(int copies);
    void setPrintMode(const QString &mode);
    void setResolution(const QString &res);
    void setCutMode(bool enabled);

    // Persistence methods (Q_INVOKABLE for QML)
    Q_INVOKABLE void saveToDatabase(int eventId = -1);  // -1 for global settings
    Q_INVOKABLE void loadFromDatabase(int eventId = -1);
    Q_INVOKABLE void saveGlobal() { saveToDatabase(-1); }
    Q_INVOKABLE void loadGlobal() { loadFromDatabase(-1); }

    // Utility methods
    Q_INVOKABLE void resetToDefaults();
    Q_INVOKABLE QString toString() const;

    // Set database manager reference (called from main.cpp)
    void setDatabaseManager(DatabaseManager *db) { m_database = db; }

signals:
    void selectedPrinterChanged(QString printer);
    void printCopiesChanged(int copies);
    void printModeChanged(QString mode);
    void resolutionChanged(QString resolution);
    void cutModeChanged(bool enabled);
    void settingsLoaded(bool success, QString message);
    void settingsSaved(bool success, QString message);

private:
    QString m_selectedPrinter = "DS-RX1";
    int m_printCopies = 1;
    QString m_printMode = "Color";        // "Color" or "BlackWhite"
    QString m_resolution = "600dpi";      // "300dpi", "600dpi"
    bool m_cutMode = true;                // true = cut (2 images per sheet), false = no-cut

    DatabaseManager *m_database = nullptr;  // Set from main.cpp
};

#endif // PRINTERCONFIG_H
