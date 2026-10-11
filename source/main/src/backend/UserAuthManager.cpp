#include "UserAuthManager.h"
#include "DatabaseManager.h"
#include <QCryptographicHash>
#include <QSettings>
#include <QDebug>
#include <QRegularExpression>

// QSettings keys
static const char *kSettingsGroup   = "userAuth";
static const char *kKeyPhone        = "userAuth/phone";
static const char *kKeyName         = "userAuth/name";

UserAuthManager::UserAuthManager(DatabaseManager *db, QObject *parent)
    : QObject(parent)
    , m_db(db)
{
}

// ─── Private helpers ──────────────────────────────────────────────────────────

QString UserAuthManager::hashPassword(const QString &password) const {
    return QCryptographicHash::hash(password.toUtf8(), QCryptographicHash::Sha256)
               .toHex().toUpper();
}

void UserAuthManager::saveSession() {
    QSettings s;
    s.setValue(kKeyPhone, m_userPhone);
    s.setValue(kKeyName,  m_userName);
    s.sync();
}

void UserAuthManager::clearSession() {
    QSettings s;
    s.remove(kSettingsGroup);
    s.sync();
}

// ─── Public API ──────────────────────────────────────────────────────────────

QString UserAuthManager::registerUser(const QString &fullName,
                                      const QString &phone,
                                      const QString &password)
{
    // ── Validate name ──
    QString name = fullName.trimmed();
    if (name.isEmpty())
        return "Vui lòng nhập họ và tên.";
    if (name.length() < 2)
        return "Họ và tên phải có ít nhất 2 ký tự.";

    // ── Validate phone (Vietnamese: 10 digits, starts with 0) ──
    static QRegularExpression phoneRx("^0[0-9]{9}$");
    if (!phoneRx.match(phone.trimmed()).hasMatch())
        return "Số điện thoại không hợp lệ (10 chữ số, bắt đầu bằng 0).";

    // ── Validate password (exactly 6 digits) ──
    static QRegularExpression pinRx("^[0-9]{6}$");
    if (!pinRx.match(password).hasMatch())
        return "Mật khẩu phải gồm đúng 6 chữ số.";

    // ── Check duplicate phone ──
    if (m_db->userPhoneExists(phone.trimmed())) {
        return "Số điện thoại này đã được đăng ký.";
    }

    // ── Store ──
    if (!m_db->registerUser(name, phone.trimmed(), hashPassword(password))) {
        return "Đăng ký thất bại. Vui lòng thử lại.";
    }

    qDebug() << "[UserAuth] Registered:" << name << phone.trimmed();

    // Auto-login after registration
    m_loggedIn = true;
    m_userName  = name;
    m_userPhone = phone.trimmed();
    m_db->updateLastLogin(m_userPhone);
    saveSession();
    emit authStateChanged();
    return "";
}

QString UserAuthManager::loginUser(const QString &nameOrPhone,
                                   const QString &password)
{
    if (nameOrPhone.trimmed().isEmpty())
        return "Vui lòng nhập tên hoặc số điện thoại.";
    if (password.isEmpty())
        return "Vui lòng nhập mật khẩu.";

    UserAccount user;
    bool found = false;

    // Try phone lookup first (all digits, likely a phone number)
    static QRegularExpression digitRx("^[0-9]+$");
    if (digitRx.match(nameOrPhone.trimmed()).hasMatch()) {
        found = m_db->getUserByPhone(nameOrPhone.trimmed(), user);
    }
    // Then try name
    if (!found) {
        found = m_db->getUserByName(nameOrPhone.trimmed(), user);
    }
    // Fallback: try phone even if it looked like a name
    if (!found) {
        found = m_db->getUserByPhone(nameOrPhone.trimmed(), user);
    }

    if (!found)
        return "Không tìm thấy tài khoản với tên hoặc số điện thoại này.";

    if (user.passwordHash != hashPassword(password))
        return "Mật khẩu không đúng.";

    m_loggedIn  = true;
    m_userName  = user.fullName;
    m_userPhone = user.phone;
    m_db->updateLastLogin(m_userPhone);
    saveSession();
    emit authStateChanged();

    qDebug() << "[UserAuth] Logged in:" << m_userName << m_userPhone;
    return "";
}

void UserAuthManager::logout() {
    qDebug() << "[UserAuth] Logout:" << m_userName;
    m_loggedIn  = false;
    m_userName.clear();
    m_userPhone.clear();
    clearSession();
    emit authStateChanged();
}

bool UserAuthManager::restoreSession() {
    QSettings s;
    QString phone = s.value(kKeyPhone).toString();
    QString name  = s.value(kKeyName).toString();

    if (phone.isEmpty() || name.isEmpty())
        return false;

    // Verify user still exists in DB
    UserAccount user;
    if (!m_db->getUserByPhone(phone, user)) {
        clearSession();
        return false;
    }

    m_loggedIn  = true;
    m_userName  = user.fullName;   // Use DB value (authoritative)
    m_userPhone = user.phone;
    emit authStateChanged();

    qDebug() << "[UserAuth] Session restored:" << m_userName << m_userPhone;
    return true;
}
