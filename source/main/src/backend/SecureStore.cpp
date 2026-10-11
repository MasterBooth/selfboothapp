#include "SecureStore.h"

#include <QDir>
#include <QFile>
#include <QRegularExpression>
#include <QStandardPaths>

#ifdef Q_OS_WIN
#  include <windows.h>
#  include <dpapi.h>
#endif

QString SecureStore::tokenPath(const QString &scope)
{
    QString safe = scope;
    safe.replace(QRegularExpression(QStringLiteral("[^A-Za-z0-9._-]")), QStringLiteral("_"));
    if (safe.isEmpty())
        safe = QStringLiteral("default");

    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    const QString dir = QDir(base).filePath(QStringLiteral("secure"));
    QDir().mkpath(dir);
    return QDir(dir).filePath(safe + QStringLiteral(".bin"));
}

bool SecureStore::saveToken(const QString &scope, const QString &token, QString *error)
{
    const QString path = tokenPath(scope);
    if (token.isEmpty())
        return deleteToken(scope, error);

#ifdef Q_OS_WIN
    const QByteArray plain = token.toUtf8();
    DATA_BLOB in;
    in.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(plain.constData()));
    in.cbData = static_cast<DWORD>(plain.size());

    const QByteArray entropy = QStringLiteral("BOOTHME:%1").arg(scope).toUtf8();
    DATA_BLOB entropyBlob;
    entropyBlob.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(entropy.constData()));
    entropyBlob.cbData = static_cast<DWORD>(entropy.size());

    DATA_BLOB out;
    if (!CryptProtectData(&in, L"BOOTHME machine token", &entropyBlob, nullptr, nullptr, 0, &out)) {
        if (error) *error = QStringLiteral("CryptProtectData failed");
        return false;
    }

    QByteArray protectedBytes(reinterpret_cast<const char *>(out.pbData), static_cast<int>(out.cbData));
    LocalFree(out.pbData);
#else
    QByteArray protectedBytes = token.toUtf8();
#endif

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (error) *error = QStringLiteral("Cannot write secure token file");
        return false;
    }
    file.write(protectedBytes);
    return true;
}

QString SecureStore::loadToken(const QString &scope, QString *error)
{
    QFile file(tokenPath(scope));
    if (!file.exists())
        return QString();
    if (!file.open(QIODevice::ReadOnly)) {
        if (error) *error = QStringLiteral("Cannot read secure token file");
        return QString();
    }
    const QByteArray protectedBytes = file.readAll();
    if (protectedBytes.isEmpty())
        return QString();

#ifdef Q_OS_WIN
    DATA_BLOB in;
    in.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(protectedBytes.constData()));
    in.cbData = static_cast<DWORD>(protectedBytes.size());

    const QByteArray entropy = QStringLiteral("BOOTHME:%1").arg(scope).toUtf8();
    DATA_BLOB entropyBlob;
    entropyBlob.pbData = reinterpret_cast<BYTE *>(const_cast<char *>(entropy.constData()));
    entropyBlob.cbData = static_cast<DWORD>(entropy.size());

    DATA_BLOB out;
    if (!CryptUnprotectData(&in, nullptr, &entropyBlob, nullptr, nullptr, 0, &out)) {
        if (error) *error = QStringLiteral("CryptUnprotectData failed");
        return QString();
    }

    QByteArray plain(reinterpret_cast<const char *>(out.pbData), static_cast<int>(out.cbData));
    LocalFree(out.pbData);
    return QString::fromUtf8(plain);
#else
    return QString::fromUtf8(protectedBytes);
#endif
}

bool SecureStore::deleteToken(const QString &scope, QString *error)
{
    QFile file(tokenPath(scope));
    if (!file.exists())
        return true;
    if (!file.remove()) {
        if (error) *error = QStringLiteral("Cannot delete secure token file");
        return false;
    }
    return true;
}
