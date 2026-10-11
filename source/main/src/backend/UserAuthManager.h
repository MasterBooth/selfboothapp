#ifndef USERAUTHMANAGER_H
#define USERAUTHMANAGER_H

#include <QObject>
#include <QString>

class DatabaseManager;

/**
 * @class UserAuthManager
 * @brief Manages user registration, login, logout and session persistence.
 *
 * Users register with full name, phone, and a 6-digit password.
 * Login is accepted by phone OR full name + password.
 * Session is persisted in QSettings so users stay logged in across restarts.
 * Passwords are stored as SHA-256 hashes — never in plain text.
 */
class UserAuthManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool   isLoggedIn READ isLoggedIn NOTIFY authStateChanged)
    Q_PROPERTY(QString userName  READ userName   NOTIFY authStateChanged)
    Q_PROPERTY(QString userPhone READ userPhone  NOTIFY authStateChanged)

public:
    explicit UserAuthManager(DatabaseManager *db, QObject *parent = nullptr);

    bool    isLoggedIn() const { return m_loggedIn; }
    QString userName()   const { return m_userName;  }
    QString userPhone()  const { return m_userPhone;  }

    /**
     * Register a new user.
     * @return "" on success, localised error message on failure.
     */
    Q_INVOKABLE QString registerUser(const QString &fullName,
                                     const QString &phone,
                                     const QString &password);

    /**
     * Login with name or phone + password.
     * @return "" on success, localised error message on failure.
     */
    Q_INVOKABLE QString loginUser(const QString &nameOrPhone,
                                  const QString &password);

    /** Log out the current user and clear persisted session. */
    Q_INVOKABLE void logout();

    /**
     * Restore a previously saved session from QSettings.
     * Call this on application startup.
     * @return true if a valid session was restored.
     */
    Q_INVOKABLE bool restoreSession();

signals:
    void authStateChanged();

private:
    DatabaseManager *m_db;
    bool    m_loggedIn = false;
    QString m_userName;
    QString m_userPhone;

    QString hashPassword(const QString &password) const;
    void    saveSession();
    void    clearSession();
};

#endif // USERAUTHMANAGER_H
