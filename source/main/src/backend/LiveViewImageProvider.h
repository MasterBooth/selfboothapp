#pragma once

#include <QImage>
#include <QReadWriteLock>
#include <QQuickImageProvider>

/*
 * LiveViewImageProvider — stores a pre-decoded QImage ready for instant retrieval.
 *
 * Design rationale:
 *   JPEG decoding happens on the decode thread (in decodeLoop) before setImage()
 *   is called.  requestImage() therefore only needs to copy an already-decoded
 *   QImage, which is O(1) thanks to Qt's implicit sharing.
 *
 *   QReadWriteLock replaces QMutex: multiple simultaneous reads don't block each
 *   other. Write lock is taken only when a new frame is stored (~25x per sec).
 *
 *   Because requestImage() is near-instant, the QML Image item can safely use
 *   asynchronous:false — there is no render-thread stall.
 */
class LiveViewImageProvider : public QQuickImageProvider {
public:
    LiveViewImageProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

    // -----------------------------------------------------------------------
    // Called from the decode thread after the JPEG has been decoded.
    // QImage is implicitly shared so the assignment is O(1).
    // -----------------------------------------------------------------------
    void setImage(QImage &&image) {
        QWriteLocker locker(&m_lock);
        m_image = std::move(image);
    }

    void setImage(const QImage &image) {
        QWriteLocker locker(&m_lock);
        m_image = image;
    }

    void updateImage(QImage &&image)       { setImage(std::move(image)); }
    void updateImage(const QImage &image)  { setImage(image); }

    // -----------------------------------------------------------------------
    // Called by Qt on the render thread (asynchronous:false).
    // Returns the pre-decoded QImage — no JPEG decode here, so it is instant.
    // -----------------------------------------------------------------------
    QImage requestImage(const QString &id, QSize *size,
                        const QSize &requestedSize) override {
        Q_UNUSED(id);
        Q_UNUSED(requestedSize);

        QReadLocker locker(&m_lock);

        if (m_image.isNull()) {
            if (size) *size = QSize(1, 1);
            return QImage(1, 1, QImage::Format_ARGB32);
        }

        if (size) *size = m_image.size();
        return m_image;   // implicit share — O(1), no pixel copy
    }

private:
    QImage         m_image;
    QReadWriteLock m_lock;
};
