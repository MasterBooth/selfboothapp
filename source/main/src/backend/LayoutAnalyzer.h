#ifndef LAYOUTANALYZER_H
#define LAYOUTANALYZER_H

#include <QObject>
#include <QImage>
#include <QJsonArray>
#include <QJsonObject>
#include <QRect>
#include <QList>

/**
 * @brief Analyzes PNG templates to detect transparent photo slots
 */
class LayoutAnalyzer : public QObject
{
    Q_OBJECT

public:
    explicit LayoutAnalyzer(QObject *parent = nullptr);

    // Structure to hold slot info
    struct Slot {
        int id;
        QRect rect;
    };

    /**
     * @brief Processes a PNG file to find transparent slots
     * @param pngPath Path to the PNG file
     * @param jsonPath Output path for the JSON metadata
     * @param dpi Target DPI setting (e.g., "300dpi", "600dpi")
     * @return true if successful
     */
    bool processLayout(const QString &pngPath, const QString &jsonPath,
                       const QString &dpi = "300dpi",
                       const QString &printerHint = QString());

    // Structure to hold target dimensions
    struct TargetSize {
        int width;
        int height;
    };

    /**
     * @brief Checks if layout size is valid for given DPI (within ±20% tolerance)
     * @param layoutSize Current layout size
     * @param dpi Target DPI setting
     * @param printerHint Optional printer name (e.g. "QW410") to select correct target
     * @return true if layout is within valid range
     */
    bool isLayoutValidForDPI(const QSize &layoutSize, const QString &dpi,
                             const QString &printerHint = QString());

    /**
     * @brief Calculates target size based on orientation and DPI (legacy, uses only orientation)
     * @param orientation "portrait" or "landscape"
     * @param dpi Target DPI setting
     * @return Target dimensions
     */
    TargetSize getTargetSize(const QString &orientation, const QString &dpi);

    /**
     * @brief Calculates target size by detecting paper type from actual aspect ratio.
     *
     * For RX1/620S (default):
     *   <= 0.45  → 2x6" strip    (ratio ~0.33)
     *   <= 1.10  → 4x6" portrait (ratio ~0.67)
     *   >  1.10  → 6x4" landscape
     *
     * For QW410 (printerHint contains "QW410"/"410"):
     *   Always → 5x10" strip @300dpi = 600×1200
     *
     * @param actualSize Actual pixel dimensions of the layout PNG
     * @param dpi Target DPI ("300dpi" or "600dpi")
     * @param printerHint Optional printer name to select correct target
     * @return Target dimensions for this paper type at the requested DPI
     */
    TargetSize getTargetSizeByAspect(const QSize &actualSize, const QString &dpi,
                                     const QString &printerHint = QString());

    /**
     * @brief Resizes layout to target size while preserving alpha channel
     * @param original Original image
     * @param targetSize Target dimensions
     * @return Resized image
     */
    QImage resizeLayout(const QImage &original, const QSize &targetSize);

    /**
     * @brief Determines orientation from image size
     * @param size Image dimensions
     * @return "portrait" or "landscape"
     */
    QString getOrientation(const QSize &size);

private:
    // Helper to find connected components in alpha channel
    QList<QRect> findTransparentSlots(const QImage &image);
};

#endif // LAYOUTANALYZER_H
