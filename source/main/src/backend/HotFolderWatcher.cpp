#include "HotFolderWatcher.h"
#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QFileInfo>
#include <QImageReader>

namespace {
constexpr int kArmedPollMs   = 400;    // quét khi đang chụp — độ trễ nhận ảnh ~0.4-0.8s
constexpr int kIdlePollMs    = 2000;   // chỉ dò thư mục còn tồn tại
constexpr int kStableMs      = 300;    // kích thước giữ nguyên ít nhất chừng này
constexpr int kGiveUpMs      = 15000;  // file ghi mãi không xong → bỏ qua
constexpr int kDebounceMs    = 120;

bool isJpegName(const QString &name)
{
    const QString lower = name.toLower();
    return lower.endsWith(".jpg") || lower.endsWith(".jpeg");
}
} // namespace

HotFolderWatcher::HotFolderWatcher(QObject *parent)
    : QObject(parent)
{
    m_pollTimer.setSingleShot(false);
    connect(&m_pollTimer, &QTimer::timeout, this, &HotFolderWatcher::scan);

    m_debounce.setSingleShot(true);
    m_debounce.setInterval(kDebounceMs);
    connect(&m_debounce, &QTimer::timeout, this, &HotFolderWatcher::scan);

    connect(&m_fsw, &QFileSystemWatcher::directoryChanged,
            this, &HotFolderWatcher::scheduleScan);
}

bool HotFolderWatcher::start(const QString &dir)
{
    // Cùng thư mục đang theo dõi → giữ nguyên trạng thái (không mất file đang chờ).
    if (m_started && QDir::cleanPath(dir) == m_dir) {
        updatePresence();
        return m_dirPresent;
    }

    stop();
    m_dir = QDir::cleanPath(dir);
    m_started = !m_dir.isEmpty();
    if (!m_started)
        return false;

    updatePresence();
    updatePollInterval();
    m_pollTimer.start();
    qDebug() << "HotFolderWatcher: watching" << m_dir << "| present:" << m_dirPresent;
    return m_dirPresent;
}

void HotFolderWatcher::stop()
{
    const bool wasWatching = isWatching();
    m_pollTimer.stop();
    m_debounce.stop();
    if (!m_fsw.directories().isEmpty())
        m_fsw.removePaths(m_fsw.directories());
    m_started = false;
    m_dirPresent = false;
    m_pending.clear();
    if (wasWatching)
        emit watchingChanged(false);
}

void HotFolderWatcher::setArmed(bool armed)
{
    if (m_armed == armed)
        return;
    m_armed = armed;
    m_pending.clear();
    m_handled.clear();
    m_baseline.clear();

    if (armed) {
        // Ảnh đã có trong thư mục trước khi phiên bắt đầu → bỏ qua.
        const QStringList existing = listJpegs(false);
        for (const QString &name : existing)
            m_baseline.insert(name);
        qDebug() << "HotFolderWatcher: armed |" << m_baseline.size()
                 << "existing file(s) ignored";
    } else {
        qDebug() << "HotFolderWatcher: disarmed";
    }
    updatePollInterval();
}

void HotFolderWatcher::scheduleScan()
{
    if (m_started)
        m_debounce.start();
}

void HotFolderWatcher::updatePresence()
{
    const bool present = m_started && QFileInfo(m_dir).isDir();
    if (present && !m_fsw.directories().contains(m_dir))
        m_fsw.addPath(m_dir);
    if (present == m_dirPresent)
        return;

    m_dirPresent = present;
    if (present && m_armed) {
        // Thư mục vừa xuất hiện / vừa đổi giữa phiên: ảnh đang có sẵn trong đó
        // không phải ảnh của phiên này → đưa vào baseline.
        m_pending.clear();
        m_handled.clear();
        m_baseline.clear();
        const QStringList existing = listJpegs(false);
        for (const QString &name : existing)
            m_baseline.insert(name);
    }
    qDebug() << "HotFolderWatcher: folder" << m_dir << (present ? "available" : "missing");
    emit watchingChanged(isWatching());
}

void HotFolderWatcher::updatePollInterval()
{
    m_pollTimer.setInterval(m_armed ? kArmedPollMs : kIdlePollMs);
}

QStringList HotFolderWatcher::listJpegs(bool sortByTime) const
{
    QDir dir(m_dir);
    if (m_dir.isEmpty() || !dir.exists())
        return {};

    const QDir::SortFlags sort = sortByTime ? (QDir::Time | QDir::Reversed) : QDir::NoSort;
    const QStringList names = dir.entryList({ "*.jpg", "*.jpeg" }, QDir::Files, sort);
    QStringList result;
    result.reserve(names.size());
    for (const QString &name : names) {
        if (isJpegName(name))
            result.append(name);
    }
    return result;
}

void HotFolderWatcher::scan()
{
    if (!m_started)
        return;

    updatePresence();
    if (!m_dirPresent || !m_armed)
        return;

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const QDir dir(m_dir);
    // Cũ nhất trước → thứ tự _photo_NNN khớp thứ tự chụp.
    const QStringList names = listJpegs(true);

    for (const QString &name : names) {
        if (m_baseline.contains(name) || m_handled.contains(name))
            continue;

        const QString path = dir.absoluteFilePath(name);
        const qint64 size = QFileInfo(path).size();

        auto it = m_pending.find(name);
        if (it == m_pending.end()) {
            Pending p;
            p.size = size;
            p.firstSeenMs = now;
            p.lastChangeMs = now;
            m_pending.insert(name, p);
            continue;
        }

        if (size != it->size) {
            it->size = size;
            it->lastChangeMs = now;
        } else if (size > 0 && now - it->lastChangeMs >= kStableMs) {
            QImageReader reader(path);
            if (reader.canRead()) {
                m_pending.erase(it);
                m_handled.insert(name);
                qDebug() << "HotFolderWatcher: new photo" << path << "|" << size << "bytes";
                emit fileReady(path);
                continue;
            }
        }

        if (now - it->firstSeenMs > kGiveUpMs) {
            qWarning() << "HotFolderWatcher: file never became readable, skipping" << path;
            m_pending.remove(name);
            m_handled.insert(name);
        }
    }

    // File đang chờ mà đã biến mất (bị phần mềm khác xoá/đổi tên) → bỏ khỏi hàng chờ.
    for (auto it = m_pending.begin(); it != m_pending.end();) {
        if (!names.contains(it.key()))
            it = m_pending.erase(it);
        else
            ++it;
    }
}
