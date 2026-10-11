#ifndef SECURESTORE_H
#define SECURESTORE_H

#include <QString>

class SecureStore
{
public:
    static bool saveToken(const QString &scope, const QString &token, QString *error = nullptr);
    static QString loadToken(const QString &scope, QString *error = nullptr);
    static bool deleteToken(const QString &scope, QString *error = nullptr);

private:
    static QString tokenPath(const QString &scope);
};

#endif // SECURESTORE_H
