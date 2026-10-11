#pragma once

#include <QQuickImageProvider>

// Image provider for the "qr" scheme: image://qr/<url-encoded-data>
// Generates QR codes locally using the nayuki QR Code Generator library.
// No network call — synchronous and instant.
class QrImageProvider : public QQuickImageProvider {
public:
    QrImageProvider();

    // id = percent-encoded QR data string; size defaults to 400×400.
    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;
};

// Standalone helper for C++ code (EventManager overlay functions).
QImage generateQrImage(const QString &data, int pixelSize = 400);
