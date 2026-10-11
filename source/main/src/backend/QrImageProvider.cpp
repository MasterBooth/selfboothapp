#include "QrImageProvider.h"
#include "qrcodegen.hpp"

#include <QImage>
#include <QPainter>
#include <QUrl>
#include <QDebug>
#include <stdexcept>

QImage generateQrImage(const QString &data, int pixelSize) {
    if (data.isEmpty()) {
        QImage img(pixelSize, pixelSize, QImage::Format_RGB32);
        img.fill(Qt::white);
        return img;
    }

    try {
        auto qr = qrcodegen::QrCode::encodeText(
            data.toUtf8().constData(),
            qrcodegen::QrCode::Ecc::MEDIUM);

        const int modules = qr.getSize();
        const int border  = 2;          // quiet zone in modules
        const int total   = modules + border * 2;
        const int px      = qMax(1, pixelSize);
        const float scale = static_cast<float>(px) / static_cast<float>(total);
        const int modulePixels = qMax(1, static_cast<int>(scale));

        QImage img(px, px, QImage::Format_RGB32);
        img.fill(Qt::white);

        QPainter p(&img);
        p.setPen(Qt::NoPen);
        p.setBrush(Qt::black);

        for (int y = 0; y < modules; y++) {
            for (int x = 0; x < modules; x++) {
                if (qr.getModule(x, y)) {
                    int px0 = qRound((border + x) * scale);
                    int py0 = qRound((border + y) * scale);
                    p.drawRect(px0, py0, modulePixels, modulePixels);
                }
            }
        }
        p.end();
        return img;

    } catch (const std::exception &e) {
        qWarning() << "[QrImageProvider] QR generation failed:" << e.what();
        QImage img(pixelSize, pixelSize, QImage::Format_RGB32);
        img.fill(Qt::white);
        return img;
    }
}

QrImageProvider::QrImageProvider()
    : QQuickImageProvider(QQuickImageProvider::Image) {}

QImage QrImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize) {
    const QString data = QUrl::fromPercentEncoding(id.toUtf8());
    const int px = (requestedSize.isValid() && requestedSize.width() > 0)
                   ? requestedSize.width() : 400;
    QImage img = generateQrImage(data, px);
    if (size)
        *size = img.size();
    return img;
}
