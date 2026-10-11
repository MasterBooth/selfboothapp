#include "DatabaseManager.h"
#include <QDebug>
#include <QDir>
#include <QFile>
#include <QSet>
#include <QSqlError>
#include <QSqlQuery>
#include <QSqlRecord>
#include <QTextStream>
#include <QVariant>

DatabaseManager::DatabaseManager(QObject *parent) : QObject(parent) {}

DatabaseManager::~DatabaseManager() {
  if (m_database.isOpen()) {
    m_database.close();
  }
}

bool DatabaseManager::initialize(const QString &dbPath) {
  m_database = QSqlDatabase::addDatabase("QSQLITE");
  m_database.setDatabaseName(dbPath);

  if (!m_database.open()) {
    qCritical() << "Failed to open database:" << m_database.lastError().text();
    return false;
  }

  // Độ tin cậy khi đọc/ghi đồng thời: kết nối QSQLITE dùng chung này bị nhiều
  // nguồn chạm (timer trạng thái máy in, đồng bộ cloud…). Không có busy_timeout,
  // một SELECT (vd getEvent) có thể exec()==false ngay khi DB đang bị ghi → trả
  // rỗng → header nhấp nháy "Chưa chọn sự kiện". busy_timeout khiến SELECT CHỜ
  // thay vì fail; WAL cho phép đọc song song với ghi.
  {
    QSqlQuery pragma(m_database);
    if (!pragma.exec("PRAGMA busy_timeout=5000"))
      qWarning() << "[DB] Failed to set busy_timeout:" << pragma.lastError().text();
    if (!pragma.exec("PRAGMA journal_mode=WAL"))
      qWarning() << "[DB] Failed to set WAL journal mode:" << pragma.lastError().text();
  }

  qDebug() << "Database opened successfully:" << dbPath;
  return createTables();
}

bool DatabaseManager::createTables() {
  // Create schema_version table first (for migration tracking)
  QString createSchemaVersionQuery = R"(
        CREATE TABLE IF NOT EXISTS schema_version (
            version INTEGER PRIMARY KEY,
            applied_at TEXT NOT NULL
        )
    )";

  QSqlQuery query(m_database);
  if (!query.exec(createSchemaVersionQuery)) {
    qCritical() << "Failed to create schema_version table:" << query.lastError().text();
    return false;
  }

  // Create base tables
  QString createTableQuery = R"(
        CREATE TABLE IF NOT EXISTS events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            location TEXT,
            event_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            capture_mode TEXT DEFAULT 'photo',
            digital_props INTEGER DEFAULT 0,
            beauty_filter INTEGER DEFAULT 0,
            watermark INTEGER DEFAULT 1,
            post_processing INTEGER DEFAULT 0,
            thumbnail_path TEXT,
            raw_path TEXT,
            final_path TEXT,
            start_message TEXT,
            selected_layout TEXT
        )
    )";

  if (!query.exec(createTableQuery)) {
    qCritical() << "Failed to create table:" << query.lastError().text();
    return false;
  }

  // Try to add columns if they don't exist (migration)
  // These will fail silently if column already exists (or we ignore the error)
  query.exec("ALTER TABLE events ADD COLUMN capture_mode TEXT DEFAULT 'photo'");
  query.exec("ALTER TABLE events ADD COLUMN digital_props INTEGER DEFAULT 0");
  query.exec("ALTER TABLE events ADD COLUMN beauty_filter INTEGER DEFAULT 0");
  query.exec("ALTER TABLE events ADD COLUMN watermark INTEGER DEFAULT 1");
  query.exec("ALTER TABLE events ADD COLUMN post_processing INTEGER DEFAULT 0");
  query.exec("ALTER TABLE events ADD COLUMN thumbnail_path TEXT");
  query.exec("ALTER TABLE events ADD COLUMN raw_path TEXT");
  query.exec("ALTER TABLE events ADD COLUMN final_path TEXT");
  query.exec("ALTER TABLE events ADD COLUMN start_message TEXT");
  query.exec("ALTER TABLE events ADD COLUMN selected_layout TEXT");
  query.exec("ALTER TABLE events ADD COLUMN countdown_duration INTEGER DEFAULT 3");
  query.exec("ALTER TABLE events ADD COLUMN shot_interval INTEGER DEFAULT 2000");
  query.exec("ALTER TABLE events ADD COLUMN auto_cut INTEGER DEFAULT 0");
  query.exec("ALTER TABLE events ADD COLUMN mirror_mode INTEGER DEFAULT 0");

  qDebug() << "Base tables created successfully";

  // Create Photos Table
  QString createPhotosTableQuery = R"(
        CREATE TABLE IF NOT EXISTS photos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            type TEXT DEFAULT 'original',
            created_at TEXT NOT NULL,
            FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
        )
    )";

  if (!query.exec(createPhotosTableQuery)) {
      qCritical() << "Failed to create photos table:" << query.lastError().text();
      return false;
  }

  // Create Printer Settings Table
  QString createPrinterSettingsTableQuery = R"(
      CREATE TABLE IF NOT EXISTS printer_settings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          event_id INTEGER DEFAULT -1,
          printer_name TEXT DEFAULT 'DS-RX1',
          print_copies INTEGER DEFAULT 1,
          print_mode TEXT DEFAULT 'Color',
          resolution TEXT DEFAULT '300dpi',
          cut_mode INTEGER DEFAULT 1,
          UNIQUE(event_id)
      )
  )";

  if (!query.exec(createPrinterSettingsTableQuery)) {
      qCritical() << "Failed to create printer_settings table:" << query.lastError().text();
      return false;
  }

  qDebug() << "Printer settings table created successfully";

  // Run migration system
  int currentVersion = getSchemaVersion();
  qDebug() << "Current schema version:" << currentVersion;

  if (currentVersion < 1) {
    qDebug() << "Applying migration v1...";
    if (!applyMigration_v1()) {
      return false;
    }
  }

  if (currentVersion < 2) {
    qDebug() << "Applying migration v2...";
    if (!applyMigration_v2()) {
      return false;
    }
  }

  if (currentVersion < 3) {
    qDebug() << "Applying migration v3: background settings";
    if (!applyMigration_v3()) {
      return false;
    }
  }

  if (currentVersion < 4) {
    qDebug() << "Applying migration v4: app settings table";
    if (!applyMigration_v4()) {
      return false;
    }
  }

  if (currentVersion < 5) {
    qDebug() << "Applying migration v5: live view overlay setting";
    if (!applyMigration_v5()) {
      return false;
    }
  }

  if (currentVersion < 6) {
    qDebug() << "Applying migration v6: separate countdown timings for first/next shots";
    if (!applyMigration_v6()) {
      return false;
    }
  }

  if (currentVersion < 7) {
    qDebug() << "Applying migration v7: manual shooting mode";
    if (!applyMigration_v7()) {
      return false;
    }
  }

  if (currentVersion < 8) {
    qDebug() << "Applying migration v8: live view background setting";
    if (!applyMigration_v8()) {
      return false;
    }
  }

  if (currentVersion < 9) {
    qDebug() << "Applying migration v9: add session_id to photos table";
    if (!applyMigration_v9()) {
      return false;
    }
  }

  if (currentVersion < 10) {
    qDebug() << "Applying migration v10: pose_guide setting";
    if (!applyMigration_v10()) {
      return false;
    }
  }

  if (currentVersion < 11) {
    qDebug() << "Applying migration v11: print_count tracking";
    if (!applyMigration_v11()) {
      return false;
    }
  }

  if (currentVersion < 12) {
    qDebug() << "Applying migration v12: print_count_cut / print_count_nocut tracking";
    if (!applyMigration_v12()) {
      return false;
    }
  }

  if (currentVersion < 13) {
    qDebug() << "Applying migration v13: users table";
    if (!applyMigration_v13()) {
      return false;
    }
  }

  if (currentVersion < 14) {
    qDebug() << "Applying migration v14: vouchers table";
    if (!applyMigration_v14()) {
      return false;
    }
  }

  if (currentVersion < 15) {
    qDebug() << "Applying migration v15: revenue_records table";
    if (!applyMigration_v15()) {
      return false;
    }
  }

  if (currentVersion < 16) {
    qDebug() << "Applying migration v16: employees table";
    if (!applyMigration_v16()) {
      return false;
    }
  }

  if (currentVersion < 17) {
    qDebug() << "Applying migration v17: employee/validity columns";
    if (!applyMigration_v17()) {
      return false;
    }
  }

  if (currentVersion < 18) {
    qDebug() << "Applying migration v18: voucher shift column";
    if (!applyMigration_v18()) {
      return false;
    }
  }

  if (currentVersion < 19) {
    qDebug() << "Applying migration v19: revenue shift/source/received columns";
    if (!applyMigration_v19()) {
      return false;
    }
  }

  if (currentVersion < 20) {
    qDebug() << "Applying migration v20: revenue note column";
    if (!applyMigration_v20()) {
      return false;
    }
  }

  if (currentVersion < 21) {
    qDebug() << "Applying migration v21: revenue voucher amount column";
    if (!applyMigration_v21()) {
      return false;
    }
  }

  if (currentVersion < 22) {
    qDebug() << "Applying migration v22: event_settings table";
    if (!applyMigration_v22()) {
      return false;
    }
  }

  if (currentVersion < 23) {
    qDebug() << "Applying migration v23: capture attempt lifecycle";
    if (!applyMigration_v23()) return false;
  }

  if (currentVersion < 24) {
    qDebug() << "Applying migration v24: voucher cloud provenance/sync";
    if (!applyMigration_v24()) return false;
  }

  if (currentVersion < 25) {
    qDebug() << "Applying migration v25: voucher note column";
    if (!applyMigration_v25()) return false;
  }

  if (currentVersion < 26) {
    qDebug() << "Applying migration v26: voucher package columns";
    if (!applyMigration_v26()) return false;
  }

  if (currentVersion < 27) {
    qDebug() << "Applying migration v27: voucher usage counters";
    if (!applyMigration_v27()) return false;
  }
  if (currentVersion < 28) {
    qDebug() << "Applying migration v28: durable upload_assets queue";
    if (!applyMigration_v28()) return false;
  }

  // Hàng đợi đồng bộ lên API selfboothvn (phiên, doanh thu, lượt dùng mã).
  // status: pending | failed (lỗi nghiệp vụ 4xx, không tự gửi lại).
  {
    QSqlQuery q(m_database);
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS cloud_outbox (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        kind        TEXT NOT NULL,
        dedupe_key  TEXT NOT NULL UNIQUE,
        method      TEXT NOT NULL,
        path        TEXT NOT NULL,
        payload     TEXT NOT NULL,
        status      TEXT NOT NULL DEFAULT 'pending',
        attempts    INTEGER NOT NULL DEFAULT 0,
        last_error  TEXT DEFAULT '',
        created_at  TEXT NOT NULL,
        updated_at  TEXT NOT NULL
    ))")) {
      qCritical() << "[DB] Failsafe: failed to ensure cloud_outbox table:" << q.lastError().text();
    }
  }

  {
    QSqlQuery q(m_database);
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS upload_assets (
        asset_id        TEXT PRIMARY KEY,
        session_id      TEXT NOT NULL,
        kind            TEXT NOT NULL,
        local_path      TEXT NOT NULL,
        file_name       TEXT NOT NULL,
        content_type    TEXT NOT NULL,
        size_bytes      INTEGER DEFAULT 0,
        checksum_sha256 TEXT DEFAULT '',
        photo_index     INTEGER DEFAULT 0,
        object_key      TEXT DEFAULT '',
        upload_url      TEXT DEFAULT '',
        expires_at      TEXT DEFAULT '',
        status          TEXT NOT NULL DEFAULT 'pending',
        attempts        INTEGER NOT NULL DEFAULT 0,
        next_retry_at   TEXT DEFAULT '',
        last_error      TEXT DEFAULT '',
        created_at      TEXT NOT NULL,
        updated_at      TEXT NOT NULL,
        confirmed_at    TEXT DEFAULT ''
    ))")) {
      qCritical() << "[DB] Failsafe: failed to ensure upload_assets table:" << q.lastError().text();
    }
    q.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_upload_assets_object_key ON upload_assets(object_key) WHERE object_key <> ''");
    q.exec("CREATE INDEX IF NOT EXISTS idx_upload_assets_status_retry ON upload_assets(status, next_retry_at)");
    q.exec("CREATE INDEX IF NOT EXISTS idx_upload_assets_session ON upload_assets(session_id, photo_index)");
    q.exec("UPDATE upload_assets SET status = 'uploaded', updated_at = datetime('now') "
           "WHERE status IN ('uploading','preparing') AND COALESCE(object_key,'') <> ''");
    q.exec("UPDATE upload_assets SET status = 'pending', updated_at = datetime('now') "
           "WHERE status IN ('uploading','preparing') AND COALESCE(object_key,'') = ''");
  }

  // Failsafe: ensure users table exists regardless of migration state.
  // This handles cases where schema_version was recorded as 13 but the
  // table was never actually created (e.g. DB restored from older backup).
  {
    QSqlQuery q(m_database);
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name TEXT NOT NULL,
        phone TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_login TEXT
    ))")) {
      qCritical() << "[DB] Failsafe: failed to ensure users table:" << q.lastError().text();
    }
  }

  // Failsafe: ensure vouchers table exists (with v17 columns for fresh DBs).
  {
    QSqlQuery q(m_database);
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS vouchers (
        code           TEXT PRIMARY KEY,
        type           TEXT NOT NULL,
        value          INTEGER NOT NULL,
        used           INTEGER DEFAULT 0,
        used_at        TEXT,
        session_id     TEXT,
        created_at     TEXT NOT NULL,
        employee_id    INTEGER DEFAULT 0,
        valid_from     TEXT DEFAULT '',
        valid_until    TEXT DEFAULT '',
        used_by_emp_id INTEGER DEFAULT 0,
        paid_amount    INTEGER DEFAULT 0,
        shift          TEXT DEFAULT '',
        created_via    TEXT DEFAULT 'desktop',
        synced         INTEGER DEFAULT 0,
        note           TEXT DEFAULT '',
        package_minutes INTEGER DEFAULT 0,
        package_prints  INTEGER DEFAULT 1,
        package_name    TEXT DEFAULT '',
        usage_limit     INTEGER DEFAULT 1,
        use_count       INTEGER DEFAULT 0
    ))")) {
      qCritical() << "[DB] Failsafe: failed to ensure vouchers table:" << q.lastError().text();
    }
  }

  // Failsafe: ensure revenue_records table exists (with v17 column for fresh DBs).
  {
    QSqlQuery q(m_database);
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS revenue_records (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        event_id        INTEGER NOT NULL,
        event_name      TEXT NOT NULL,
        session_id      TEXT,
        recorded_at     TEXT NOT NULL,
        print_count     INTEGER DEFAULT 0,
        amount_required INTEGER DEFAULT 0,
        cash_received   INTEGER DEFAULT 0,
        transfer_amount INTEGER DEFAULT 0,
        change_amount   INTEGER DEFAULT 0,
        payment_method  TEXT NOT NULL,
        employee_id     INTEGER DEFAULT 0,
        shift           TEXT DEFAULT '',
        source          TEXT DEFAULT 'session',
        received_amount INTEGER DEFAULT 0,
        voucher_amount  INTEGER DEFAULT 0,
        note            TEXT DEFAULT ''
    ))")) {
      qCritical() << "[DB] Failsafe: failed to ensure revenue_records table:" << q.lastError().text();
    }
  }

  // Failsafe: ensure employees table exists.
  {
    QSqlQuery q(m_database);
    if (!q.exec(R"(CREATE TABLE IF NOT EXISTS employees (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name  TEXT NOT NULL,
        prefix     TEXT NOT NULL UNIQUE,
        pass_hash  TEXT NOT NULL,
        created_at TEXT NOT NULL,
        active     INTEGER DEFAULT 1
    ))")) {
      qCritical() << "[DB] Failsafe: failed to ensure employees table:" << q.lastError().text();
    }
  }

  qDebug() << "All migrations applied successfully";
  return true;
}


bool DatabaseManager::addPhoto(const Photo &photo) {
    QSqlQuery query(m_database);
    query.prepare(R"(
        INSERT INTO photos (event_id, file_path, type, session_id, created_at)
        VALUES (:event_id, :file_path, :type, :session_id, :created_at)
    )");
    query.bindValue(":event_id",  photo.eventId);
    query.bindValue(":file_path", photo.filePath);
    query.bindValue(":type",      photo.type);
    query.bindValue(":session_id", photo.sessionId.isEmpty() ? QVariant(QVariant::String) : photo.sessionId);
    query.bindValue(":created_at", QDateTime::currentDateTime().toString(Qt::ISODate));

    if (!query.exec()) {
        qCritical() << "Failed to add photo:" << query.lastError().text();
        return false;
    }
    return true;
}


QList<Photo> DatabaseManager::getPhotosForEvent(int eventId) {
    QList<Photo> photos;
    QSqlQuery query(m_database);
    query.prepare("SELECT * FROM photos WHERE event_id = :event_id ORDER BY created_at DESC");
    query.bindValue(":event_id", eventId);

    if (query.exec()) {
        while (query.next()) {
            Photo photo;
            photo.id        = query.value("id").toInt();
            photo.eventId   = query.value("event_id").toInt();
            photo.filePath  = query.value("file_path").toString();
            photo.sessionId = query.value("session_id").toString();
            photo.type      = query.value("type").toString();
            photo.createdAt = QDateTime::fromString(query.value("created_at").toString(), Qt::ISODate);
            photos.append(photo);
        }
    }
    return photos;
}


// Helper for basic SQL escaping
static QString sqlStr(const QString &val) {
    if (val.isNull()) return "NULL";
    QString tmp = val;
    return "'" + tmp.replace("'", "''") + "'";
}

static QString sqlInt(int val) {
    return QString::number(val);
}

int DatabaseManager::createEvent(const Event &event) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        INSERT INTO events (name, location, event_date, created_at, updated_at,
                           capture_mode, digital_props, beauty_filter, watermark,
                           post_processing, thumbnail_path, raw_path, final_path, start_message, selected_layout,
                            countdown_duration, first_shot_countdown, next_shot_countdown, shot_interval, auto_cut, mirror_mode, live_view_overlay,
                            landing_background, mode_selection_background, shooting_mode, manual_photo_count, live_view_background, pose_guide)
        VALUES (:name, :location, :event_date, :created_at, :updated_at,
                :capture_mode, :digital_props, :beauty_filter, :watermark,
                :post_processing, :thumbnail_path, :raw_path, :final_path, :start_message, :selected_layout,
                :countdown_duration, :first_shot_countdown, :next_shot_countdown, :shot_interval, :auto_cut, :mirror_mode, :live_view_overlay,
                :landing_background, :mode_selection_background, :shooting_mode, :manual_photo_count, :live_view_background, :pose_guide)
    )");

  query.bindValue(":name", event.name);
  query.bindValue(":location", event.location);
  query.bindValue(":event_date", event.eventDate.toString(Qt::ISODate));
  query.bindValue(":created_at", QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":capture_mode", event.captureMode);
  query.bindValue(":digital_props", event.digitalProps ? 1 : 0);
  query.bindValue(":beauty_filter", event.beautyFilter ? 1 : 0);
  query.bindValue(":watermark", event.watermark ? 1 : 0);
  query.bindValue(":post_processing", event.postProcessing ? 1 : 0);
  query.bindValue(":thumbnail_path", event.thumbnailPath);
  query.bindValue(":raw_path", event.rawPath);
  query.bindValue(":final_path", event.finalPath);
  query.bindValue(":start_message", event.startScreenMessage);
  query.bindValue(":selected_layout", event.selectedLayout);
  query.bindValue(":countdown_duration", event.countdownDuration);
  query.bindValue(":first_shot_countdown", event.firstShotCountdown);
  query.bindValue(":next_shot_countdown", event.nextShotCountdown);
  query.bindValue(":shot_interval", event.shotInterval);
  query.bindValue(":auto_cut", event.autoCut ? 1 : 0);
  query.bindValue(":mirror_mode", event.mirrorMode ? 1 : 0);
  query.bindValue(":live_view_overlay", event.liveViewOverlay ? 1 : 0);
  query.bindValue(":landing_background", event.landingBackground);
  query.bindValue(":mode_selection_background", event.modeSelectionBackground);
  query.bindValue(":shooting_mode", event.shootingMode);
  query.bindValue(":manual_photo_count", event.manualPhotoCount);
  query.bindValue(":live_view_background", event.liveViewBackground ? 1 : 0);
  query.bindValue(":pose_guide",           event.poseGuide           ? 1 : 0);

  if (!query.exec()) {
    qCritical() << "Failed to create event:" << query.lastError().text();
    return -1;
  }

  return query.lastInsertId().toInt();
}

bool DatabaseManager::updateEvent(const Event &event) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        UPDATE events SET
            name = :name,
            location = :location,
            event_date = :event_date,
            updated_at = :updated_at,
            capture_mode = :capture_mode,
            digital_props = :digital_props,
            beauty_filter = :beauty_filter,
            watermark = :watermark,
            post_processing = :post_processing,
            thumbnail_path = :thumbnail_path,
            raw_path = :raw_path,
            final_path = :final_path,
            start_message = :start_message,
            selected_layout = :selected_layout,
            countdown_duration = :countdown_duration,
            first_shot_countdown = :first_shot_countdown,
            next_shot_countdown = :next_shot_countdown,
            shot_interval = :shot_interval,
            auto_cut = :auto_cut,
            mirror_mode = :mirror_mode,
            live_view_overlay = :live_view_overlay,
            landing_background = :landing_background,
            mode_selection_background = :mode_selection_background,
            shooting_mode = :shooting_mode,
            manual_photo_count = :manual_photo_count,
            live_view_background = :live_view_background,
            pose_guide = :pose_guide
        WHERE id = :id
    )");

  query.bindValue(":id", event.id);
  query.bindValue(":name", event.name);
  query.bindValue(":location", event.location);
  query.bindValue(":event_date", event.eventDate.toString(Qt::ISODate));
  query.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":capture_mode", event.captureMode);
  query.bindValue(":digital_props", event.digitalProps ? 1 : 0);
  query.bindValue(":beauty_filter", event.beautyFilter ? 1 : 0);
  query.bindValue(":watermark", event.watermark ? 1 : 0);
  query.bindValue(":post_processing", event.postProcessing ? 1 : 0);
  query.bindValue(":thumbnail_path", event.thumbnailPath);
  query.bindValue(":raw_path", event.rawPath);
  query.bindValue(":final_path", event.finalPath);
  query.bindValue(":start_message", event.startScreenMessage);
  query.bindValue(":selected_layout", event.selectedLayout);
  query.bindValue(":countdown_duration", event.countdownDuration);
  query.bindValue(":first_shot_countdown", event.firstShotCountdown);
  query.bindValue(":next_shot_countdown", event.nextShotCountdown);
  query.bindValue(":shot_interval", event.shotInterval);
  query.bindValue(":auto_cut", event.autoCut ? 1 : 0);
  query.bindValue(":mirror_mode", event.mirrorMode ? 1 : 0);
  query.bindValue(":live_view_overlay", event.liveViewOverlay ? 1 : 0);
  query.bindValue(":landing_background", event.landingBackground);
  query.bindValue(":mode_selection_background", event.modeSelectionBackground);
  query.bindValue(":shooting_mode", event.shootingMode);
  query.bindValue(":manual_photo_count", event.manualPhotoCount);
  query.bindValue(":live_view_background", event.liveViewBackground ? 1 : 0);
  query.bindValue(":pose_guide",           event.poseGuide           ? 1 : 0);

  if (!query.exec()) {
    qCritical() << "Failed to update event ID" << event.id << ":" << query.lastError().text();
    return false;
  }

  qDebug() << "Successfully updated event ID" << event.id << "Layout:" << event.selectedLayout;
  return true;
}

bool DatabaseManager::deleteEvent(int eventId) {
  QSqlQuery query(m_database);
  query.prepare("DELETE FROM events WHERE id = :id");
  query.bindValue(":id", eventId);

  if (!query.exec()) {
    qCritical() << "Failed to delete event:" << query.lastError().text();
    return false;
  }

  return true;
}

Event DatabaseManager::getEvent(int eventId) {
  Event event;
  QSqlQuery query(m_database);
  query.prepare("SELECT * FROM events WHERE id = :id");
  query.bindValue(":id", eventId);

  bool ok = query.exec();
  // Chẩn đoán "Chưa chọn sự kiện": nếu một eventId hợp lệ (>0) mà truy vấn thất
  // bại hoặc không có hàng, ghi cảnh báo để xác nhận đây là nguyên nhân (tranh
  // chấp DB / id sai) thay vì đoán mò.
  if (eventId > 0 && !ok)
    qWarning() << "[DB] getEvent exec FAILED for id" << eventId << ":" << query.lastError().text();

  if (ok && query.next()) {
    event.id = query.value("id").toInt();
    event.name = query.value("name").toString();
    event.location = query.value("location").toString();
    event.eventDate = QDateTime::fromString(
        query.value("event_date").toString(), Qt::ISODate);
    event.createdAt = QDateTime::fromString(
        query.value("created_at").toString(), Qt::ISODate);
    event.updatedAt = QDateTime::fromString(
        query.value("updated_at").toString(), Qt::ISODate);
    event.captureMode = query.value("capture_mode").toString();
    event.digitalProps = query.value("digital_props").toBool();
    event.beautyFilter = query.value("beauty_filter").toBool();
    event.watermark = query.value("watermark").toBool();
    event.postProcessing = query.value("post_processing").toBool();
    event.thumbnailPath = query.value("thumbnail_path").toString();
    event.rawPath = query.value("raw_path").toString();
     event.finalPath = query.value("final_path").toString();
     event.startScreenMessage = query.value("start_message").toString();
     event.selectedLayout = query.value("selected_layout").toString();
     event.countdownDuration = query.value("countdown_duration").toInt();
     event.firstShotCountdown = query.value("first_shot_countdown").toInt();
     event.nextShotCountdown = query.value("next_shot_countdown").toInt();
     event.shotInterval = query.value("shot_interval").toInt();
     event.autoCut = query.value("auto_cut").toBool();
     event.mirrorMode = query.value("mirror_mode").toBool();
     event.liveViewOverlay = query.value("live_view_overlay").toBool();
     event.landingBackground = query.value("landing_background").toString();
     event.modeSelectionBackground = query.value("mode_selection_background").toString();
     event.shootingMode = query.value("shooting_mode").toInt();
     event.manualPhotoCount = query.value("manual_photo_count").toInt();
     event.liveViewBackground = query.value("live_view_background").toBool();
     event.poseGuide           = query.value("pose_guide").toBool();

     // Sanitize values that may have been stored as garbage from uninitialized struct fields
     if (event.firstShotCountdown < 0 || event.firstShotCountdown > 60) event.firstShotCountdown = 3;
     if (event.nextShotCountdown < 0 || event.nextShotCountdown > 60) event.nextShotCountdown = 3;
     if (event.shotInterval < 0 || event.shotInterval > 60000) event.shotInterval = 2000;
     if (event.shootingMode < 0 || event.shootingMode > 2) event.shootingMode = 0;
     if (event.manualPhotoCount < 0 || event.manualPhotoCount > 20) event.manualPhotoCount = 0;
     if (event.countdownDuration < 0 || event.countdownDuration > 60) event.countdownDuration = 3;
  }

  // eventId hợp lệ mà không dựng được event (id==0) → truy vấn ok nhưng không có
  // hàng: ghi cảnh báo để phân biệt với trường hợp exec-fail ở trên.
  if (eventId > 0 && event.id == 0 && ok)
    qWarning() << "[DB] getEvent: no row for valid id" << eventId;

  return event;
}

QList<Event> DatabaseManager::getAllEvents() {
  QList<Event> events;
  QSqlQuery query("SELECT * FROM events ORDER BY updated_at DESC", m_database);

  while (query.next()) {
    Event event;
    event.id = query.value("id").toInt();
    event.name = query.value("name").toString();
    event.location = query.value("location").toString();
    event.eventDate = QDateTime::fromString(
        query.value("event_date").toString(), Qt::ISODate);
    event.createdAt = QDateTime::fromString(
        query.value("created_at").toString(), Qt::ISODate);
    event.updatedAt = QDateTime::fromString(
        query.value("updated_at").toString(), Qt::ISODate);
    event.captureMode = query.value("capture_mode").toString();
    event.digitalProps = query.value("digital_props").toBool();
    event.beautyFilter = query.value("beauty_filter").toBool();
    event.watermark = query.value("watermark").toBool();
    event.postProcessing = query.value("post_processing").toBool();
    event.thumbnailPath = query.value("thumbnail_path").toString();
    event.rawPath = query.value("raw_path").toString();
    event.finalPath = query.value("final_path").toString();
    event.startScreenMessage = query.value("start_message").toString();
    event.selectedLayout = query.value("selected_layout").toString();
    event.countdownDuration = query.value("countdown_duration").toInt();
    event.firstShotCountdown = query.value("first_shot_countdown").toInt();
    event.nextShotCountdown = query.value("next_shot_countdown").toInt();
    event.shotInterval = query.value("shot_interval").toInt();
    event.autoCut = query.value("auto_cut").toBool();
    event.mirrorMode = query.value("mirror_mode").toBool();
    event.landingBackground = query.value("landing_background").toString();
    event.modeSelectionBackground = query.value("mode_selection_background").toString();
    event.shootingMode = query.value("shooting_mode").toInt();
    event.manualPhotoCount = query.value("manual_photo_count").toInt();
    event.liveViewBackground = query.value("live_view_background").toBool();
    event.poseGuide           = query.value("pose_guide").toBool();

    // Sanitize garbage values
    if (event.firstShotCountdown < 0 || event.firstShotCountdown > 60) event.firstShotCountdown = 3;
    if (event.nextShotCountdown < 0 || event.nextShotCountdown > 60) event.nextShotCountdown = 3;
    if (event.shotInterval < 0 || event.shotInterval > 60000) event.shotInterval = 2000;
    if (event.shootingMode < 0 || event.shootingMode > 2) event.shootingMode = 0;
    if (event.manualPhotoCount < 0 || event.manualPhotoCount > 20) event.manualPhotoCount = 0;
    if (event.countdownDuration < 0 || event.countdownDuration > 60) event.countdownDuration = 3;

    events.append(event);
  }

  return events;
}

QList<Event> DatabaseManager::searchEvents(const QString &query) {
  QList<Event> events;
  QSqlQuery sqlQuery(m_database);
  sqlQuery.prepare("SELECT * FROM events WHERE name LIKE :query OR location "
                   "LIKE :query ORDER BY updated_at DESC");
  sqlQuery.bindValue(":query", "%" + query + "%");

  if (sqlQuery.exec()) {
    while (sqlQuery.next()) {
      Event event;
      event.id = sqlQuery.value("id").toInt();
      event.name = sqlQuery.value("name").toString();
      event.location = sqlQuery.value("location").toString();
      event.eventDate = QDateTime::fromString(
          sqlQuery.value("event_date").toString(), Qt::ISODate);
      event.createdAt = QDateTime::fromString(
          sqlQuery.value("created_at").toString(), Qt::ISODate);
      event.updatedAt = QDateTime::fromString(
          sqlQuery.value("updated_at").toString(), Qt::ISODate);
      event.captureMode = sqlQuery.value("capture_mode").toString();
      event.digitalProps = sqlQuery.value("digital_props").toBool();
      event.beautyFilter = sqlQuery.value("beauty_filter").toBool();
      event.watermark = sqlQuery.value("watermark").toBool();
      event.postProcessing = sqlQuery.value("post_processing").toBool();
      event.thumbnailPath = sqlQuery.value("thumbnail_path").toString();
      event.rawPath = sqlQuery.value("raw_path").toString();
      event.finalPath = sqlQuery.value("final_path").toString();
      event.startScreenMessage = sqlQuery.value("start_message").toString();
      event.selectedLayout = sqlQuery.value("selected_layout").toString();
      event.countdownDuration = sqlQuery.value("countdown_duration").toInt();
      event.firstShotCountdown = sqlQuery.value("first_shot_countdown").toInt();
      event.nextShotCountdown = sqlQuery.value("next_shot_countdown").toInt();
      event.shotInterval = sqlQuery.value("shot_interval").toInt();
      event.autoCut = sqlQuery.value("auto_cut").toBool();
      event.mirrorMode = sqlQuery.value("mirror_mode").toBool();
      event.landingBackground = sqlQuery.value("landing_background").toString();
      event.modeSelectionBackground = sqlQuery.value("mode_selection_background").toString();
      event.shootingMode = sqlQuery.value("shooting_mode").toInt();
      event.manualPhotoCount = sqlQuery.value("manual_photo_count").toInt();
      event.liveViewBackground = sqlQuery.value("live_view_background").toBool();
      event.poseGuide           = sqlQuery.value("pose_guide").toBool();

      // Sanitize garbage values
      if (event.firstShotCountdown < 0 || event.firstShotCountdown > 60) event.firstShotCountdown = 3;
      if (event.nextShotCountdown < 0 || event.nextShotCountdown > 60) event.nextShotCountdown = 3;
      if (event.shotInterval < 0 || event.shotInterval > 60000) event.shotInterval = 2000;
      if (event.shootingMode < 0 || event.shootingMode > 2) event.shootingMode = 0;
      if (event.manualPhotoCount < 0 || event.manualPhotoCount > 20) event.manualPhotoCount = 0;
      if (event.countdownDuration < 0 || event.countdownDuration > 60) event.countdownDuration = 3;

      events.append(event);
    }
  }

  return events;
}

bool DatabaseManager::duplicateEvent(int eventId) {
  Event original = getEvent(eventId);
  if (original.id == 0)
    return false;

  original.name += " (Copy)";
  original.id = 0; // Will be auto-generated

  return createEvent(original) > 0;
}

// ============= Migration System =============

int DatabaseManager::getSchemaVersion() {
  QSqlQuery query(m_database);
  query.prepare("SELECT version FROM schema_version WHERE version = (SELECT MAX(version) FROM schema_version)");

  if (query.exec() && query.next()) {
    return query.value("version").toInt();
  }

  // No version found, return 0 (fresh database)
  return 0;
}

bool DatabaseManager::setSchemaVersion(int version) {
  QSqlQuery query(m_database);
  query.prepare("INSERT INTO schema_version (version, applied_at) VALUES (:version, :applied_at)");
  query.bindValue(":version", version);
  query.bindValue(":applied_at", QDateTime::currentDateTime().toString(Qt::ISODate));

  if (!query.exec()) {
    qCritical() << "Failed to set schema version:" << query.lastError().text();
    return false;
  }

  return true;
}

bool DatabaseManager::applyMigration_v1() {
  // Create machines table
  QString createMachinesQuery = R"(
        CREATE TABLE IF NOT EXISTS machines (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hwid TEXT NOT NULL UNIQUE,
            first_seen TEXT NOT NULL,
            last_validated TEXT,
            auth_status TEXT DEFAULT 'pending',
            device_name TEXT,
            created_at TEXT NOT NULL
        )
    )";

  QSqlQuery query(m_database);
  if (!query.exec(createMachinesQuery)) {
    qCritical() << "Failed to create machines table:" << query.lastError().text();
    return false;
  }

  // Create sessions table
  QString createSessionsQuery = R"(
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            session_id TEXT NOT NULL UNIQUE,
            event_id INTEGER NOT NULL,
            hwid TEXT NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT,
            photo_count INTEGER DEFAULT 0,
            status TEXT DEFAULT 'active',
            FOREIGN KEY (event_id) REFERENCES events (id) ON DELETE CASCADE
        )
    )";

  if (!query.exec(createSessionsQuery)) {
    qCritical() << "Failed to create sessions table:" << query.lastError().text();
    return false;
  }

  return setSchemaVersion(1);
}

bool DatabaseManager::applyMigration_v2() {
  QSqlQuery query(m_database);

  // Create upload_queue table
  QString createUploadQueueQuery = R"(
        CREATE TABLE IF NOT EXISTS upload_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            photo_id INTEGER NOT NULL,
            session_id TEXT NOT NULL,
            s3_path TEXT NOT NULL,
            local_path TEXT NOT NULL,
            upload_status TEXT DEFAULT 'pending',
            retry_count INTEGER DEFAULT 0,
            last_attempt TEXT,
            error_message TEXT,
            uploaded_at TEXT,
            FOREIGN KEY (photo_id) REFERENCES photos (id) ON DELETE CASCADE
        )
    )";

  if (!query.exec(createUploadQueueQuery)) {
    qCritical() << "Failed to create upload_queue table:" << query.lastError().text();
    return false;
  }

  // Add columns to photos table if they don't exist
  query.exec("ALTER TABLE photos ADD COLUMN session_id TEXT");
  query.exec("ALTER TABLE photos ADD COLUMN upload_status TEXT DEFAULT 'pending'");

  return setSchemaVersion(2);
}

bool DatabaseManager::applyMigration_v3() {
  QSqlQuery query(m_database);

  // Add background columns to events table
  if (!query.exec("ALTER TABLE events ADD COLUMN landing_background TEXT")) {
    qWarning() << "Failed to add landing_background column:" << query.lastError().text();
    return false;
  }

  if (!query.exec("ALTER TABLE events ADD COLUMN mode_selection_background TEXT")) {
    qWarning() << "Failed to add mode_selection_background column:" << query.lastError().text();
    return false;
  }

  qDebug() << "Background columns added successfully";
  return setSchemaVersion(3);
}

bool DatabaseManager::applyMigration_v4() {
  QSqlQuery query(m_database);

  // Create app_settings table for global settings
  QString createSettingsQuery = R"(
        CREATE TABLE IF NOT EXISTS app_settings (
            key TEXT PRIMARY KEY,
            value TEXT,
            updated_at TEXT NOT NULL
        )
    )";

  if (!query.exec(createSettingsQuery)) {
    qCritical() << "Failed to create app_settings table:" << query.lastError().text();
    return false;
  }

  qDebug() << "App settings table created successfully";
  return setSchemaVersion(4);
}

bool DatabaseManager::applyMigration_v5() {
  QSqlQuery query(m_database);

  // Add live_view_overlay column to events table
  if (!query.exec("ALTER TABLE events ADD COLUMN live_view_overlay INTEGER DEFAULT 0")) {
    qWarning() << "Failed to add live_view_overlay column:" << query.lastError().text();
    return false;
  }

  qDebug() << "Live view overlay column added successfully";
  return setSchemaVersion(5);
}

bool DatabaseManager::applyMigration_v6() {
  QSqlQuery query(m_database);

  // Add first_shot_countdown column to events table
  if (!query.exec("ALTER TABLE events ADD COLUMN first_shot_countdown INTEGER DEFAULT 3")) {
    qWarning() << "Failed to add first_shot_countdown column:" << query.lastError().text();
    return false;
  }

  // Add next_shot_countdown column to events table
  if (!query.exec("ALTER TABLE events ADD COLUMN next_shot_countdown INTEGER DEFAULT 3")) {
    qWarning() << "Failed to add next_shot_countdown column:" << query.lastError().text();
    return false;
  }

  // Migrate existing countdown_duration values to both new fields for backwards compatibility
  query.exec(R"(
    UPDATE events 
    SET first_shot_countdown = COALESCE(countdown_duration, 3),
        next_shot_countdown = COALESCE(countdown_duration, 3)
    WHERE first_shot_countdown IS NULL OR next_shot_countdown IS NULL
  )");

  qDebug() << "Separate countdown timing columns added successfully";
  return setSchemaVersion(6);
}

bool DatabaseManager::applyMigration_v7() {
  QSqlQuery query(m_database);

  // Add shooting_mode column (0=Auto, 1=Manual)
  if (!query.exec("ALTER TABLE events ADD COLUMN shooting_mode INTEGER DEFAULT 0")) {
    qWarning() << "Failed to add shooting_mode column:" << query.lastError().text();
    return false;
  }

  // Add manual_photo_count column (default 0, will use layout count if 0/Auto)
  if (!query.exec("ALTER TABLE events ADD COLUMN manual_photo_count INTEGER DEFAULT 0")) {
    qWarning() << "Failed to add manual_photo_count column:" << query.lastError().text();
    return false;
  }

  qDebug() << "Manual shooting mode columns added successfully";
  return setSchemaVersion(7);
}

bool DatabaseManager::applyMigration_v8() {
  QSqlQuery query(m_database);

  // Add live_view_background column (default 0 = disabled)
  if (!query.exec("ALTER TABLE events ADD COLUMN live_view_background INTEGER DEFAULT 0")) {
    qWarning() << "Failed to add live_view_background column:" << query.lastError().text();
    return false;
  }

  qDebug() << "Live view background column added successfully";
  return setSchemaVersion(8);
}

bool DatabaseManager::applyMigration_v9() {
  QSqlQuery query(m_database);

  // Add session_id to photos so we can build per-session QR links from gallery
  // Silently skip if the column already exists (e.g. migration v2 may have added it)
  if (!query.exec("ALTER TABLE photos ADD COLUMN session_id TEXT")) {
    QString err = query.lastError().text();
    // SQLite raises "duplicate column name" – safe to ignore
    if (!err.contains("duplicate column", Qt::CaseInsensitive)) {
      qWarning() << "Failed to add session_id column to photos:" << err;
      return false;
    }
    qDebug() << "session_id column already exists in photos, skipping";
  } else {
    qDebug() << "session_id column added to photos table";
  }

  return setSchemaVersion(9);
}

bool DatabaseManager::applyMigration_v10() {
  QSqlQuery query(m_database);

  // Add pose_guide column (default 0 = disabled)
  if (!query.exec("ALTER TABLE events ADD COLUMN pose_guide INTEGER DEFAULT 0")) {
    QString err = query.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive)) {
      qWarning() << "Failed to add pose_guide column:" << err;
      return false;
    }
    qDebug() << "pose_guide column already exists, skipping";
  } else {
    qDebug() << "pose_guide column added to events table";
  }

  return setSchemaVersion(10);
}

bool DatabaseManager::applyMigration_v11() {
  QSqlQuery query(m_database);

  // Add print_count column to events table (default 0)
  if (!query.exec("ALTER TABLE events ADD COLUMN print_count INTEGER DEFAULT 0")) {
    QString err = query.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive)) {
      qWarning() << "Failed to add print_count column:" << err;
      return false;
    }
    qDebug() << "print_count column already exists, skipping";
  } else {
    qDebug() << "print_count column added to events table";
  }

  return setSchemaVersion(11);
}

bool DatabaseManager::applyMigration_v12() {
  QSqlQuery query(m_database);

  // Add print_count_cut column (ảnh cắt đôi)
  if (!query.exec("ALTER TABLE events ADD COLUMN print_count_cut INTEGER DEFAULT 0")) {
    QString err = query.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive)) {
      qWarning() << "Failed to add print_count_cut column:" << err;
      return false;
    }
    qDebug() << "print_count_cut column already exists, skipping";
  } else {
    qDebug() << "print_count_cut column added to events table";
  }

  // Add print_count_nocut column (ảnh nguyên tờ)
  if (!query.exec("ALTER TABLE events ADD COLUMN print_count_nocut INTEGER DEFAULT 0")) {
    QString err = query.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive)) {
      qWarning() << "Failed to add print_count_nocut column:" << err;
      return false;
    }
    qDebug() << "print_count_nocut column already exists, skipping";
  } else {
    qDebug() << "print_count_nocut column added to events table";
  }

  return setSchemaVersion(12);
}

bool DatabaseManager::applyMigration_v13() {
  QSqlQuery query(m_database);
  QString createUsersQuery = R"(
      CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          full_name TEXT NOT NULL,
          phone TEXT NOT NULL UNIQUE,
          password_hash TEXT NOT NULL,
          created_at TEXT NOT NULL,
          last_login TEXT
      )
  )";
  if (!query.exec(createUsersQuery)) {
    qCritical() << "Failed to create users table:" << query.lastError().text();
    return false;
  }
  qDebug() << "Users table created successfully";
  return setSchemaVersion(13);
}

bool DatabaseManager::applyMigration_v14() {
  QSqlQuery query(m_database);
  if (!query.exec(R"(
      CREATE TABLE IF NOT EXISTS vouchers (
          code       TEXT PRIMARY KEY,
          type       TEXT NOT NULL,
          value      INTEGER NOT NULL,
          used       INTEGER DEFAULT 0,
          used_at    TEXT,
          session_id TEXT,
          created_at TEXT NOT NULL
      )
  )")) {
    qCritical() << "Failed to create vouchers table:" << query.lastError().text();
    return false;
  }
  qDebug() << "Vouchers table created successfully";
  return setSchemaVersion(14);
}

// ============= Voucher Operations =============

bool DatabaseManager::insertVoucher(const QString &code, const QString &type, int value,
                                    int employeeId, const QString &validFrom,
                                    const QString &validUntil, const QString &shift,
                                    const QString &note, int packageMinutes,
                                    int packagePrints, const QString &packageName,
                                    int usageLimit) {
  QSqlQuery query(m_database);
  query.prepare(R"(
      INSERT OR IGNORE INTO vouchers
        (code, type, value, used, created_at, employee_id, valid_from, valid_until,
         shift, note, package_minutes, package_prints, package_name, usage_limit, use_count)
      VALUES
        (:code, :type, :value, 0, :created_at, :employee_id, :valid_from, :valid_until,
         :shift, :note, :package_minutes, :package_prints, :package_name, :usage_limit, 0)
  )");
  query.bindValue(":code",        code.toUpper());
  query.bindValue(":type",        type);
  query.bindValue(":value",       value);
  query.bindValue(":created_at",  QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":employee_id", employeeId);
  query.bindValue(":valid_from",  validFrom);
  query.bindValue(":valid_until", validUntil);
  query.bindValue(":shift",       shift);
  query.bindValue(":note",        note);
  query.bindValue(":package_minutes", qMax(0, packageMinutes));
  query.bindValue(":package_prints",  qMax(1, packagePrints));
  query.bindValue(":package_name",    packageName);
  query.bindValue(":usage_limit",     qMax(1, usageLimit));
  if (!query.exec()) {
    qWarning() << "insertVoucher failed:" << query.lastError().text();
    return false;
  }
  return query.numRowsAffected() > 0;
}

bool DatabaseManager::markVoucherUsed(const QString &code, const QString &sessionId,
                                      int usedByEmpId, int paidAmount) {
  QSqlQuery query(m_database);
  query.prepare(R"(
      UPDATE vouchers
      SET use_count = COALESCE(use_count, 0) + 1,
          used = CASE
                   WHEN COALESCE(use_count, 0) + 1 >= COALESCE(usage_limit, 1) THEN 1
                   ELSE 0
                 END,
          used_at = :used_at,
          session_id = :session_id,
          used_by_emp_id = :emp,
          paid_amount = :paid
      WHERE code = :code
        AND COALESCE(use_count, 0) < COALESCE(usage_limit, 1)
  )");
  query.bindValue(":used_at",    QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":session_id", sessionId);
  query.bindValue(":emp",        usedByEmpId);
  query.bindValue(":paid",       paidAmount);
  query.bindValue(":code",       code.toUpper());
  if (!query.exec()) {
    qWarning() << "markVoucherUsed failed:" << query.lastError().text();
    return false;
  }
  return query.numRowsAffected() > 0;
}

QVariantMap DatabaseManager::getVoucher(const QString &code) {
  QSqlQuery query(m_database);
  query.prepare("SELECT code, type, value, used, used_at, session_id, created_at, "
                "employee_id, valid_from, valid_until, used_by_emp_id, paid_amount, "
                "COALESCE(package_minutes,0) AS package_minutes, "
                "COALESCE(package_prints,1) AS package_prints, "
                "COALESCE(package_name,'') AS package_name, "
                "COALESCE(usage_limit,1) AS usage_limit, "
                "COALESCE(use_count, CASE WHEN used = 1 THEN 1 ELSE 0 END) AS use_count, "
                "COALESCE(created_via,'desktop') AS created_via, "
                "COALESCE(synced,0) AS synced "
                "FROM vouchers WHERE code = :code");
  query.bindValue(":code", code.toUpper());
  QVariantMap result;
  if (query.exec() && query.next()) {
    result["code"]           = query.value("code").toString();
    result["type"]           = query.value("type").toString();
    result["value"]          = query.value("value").toInt();
    result["used"]           = query.value("used").toInt() == 1;
    result["used_at"]        = query.value("used_at").toString();
    result["session_id"]     = query.value("session_id").toString();
    result["created_at"]     = query.value("created_at").toString();
    result["employee_id"]    = query.value("employee_id").toInt();
    result["valid_from"]     = query.value("valid_from").toString();
    result["valid_until"]    = query.value("valid_until").toString();
    result["used_by_emp_id"] = query.value("used_by_emp_id").toInt();
    result["paid_amount"]    = query.value("paid_amount").toInt();
    result["package_minutes"] = query.value("package_minutes").toInt();
    result["package_prints"]  = query.value("package_prints").toInt();
    result["package_name"]    = query.value("package_name").toString();
    result["usage_limit"]     = query.value("usage_limit").toInt();
    result["use_count"]       = query.value("use_count").toInt();
    // synced=0 → mã chỉ nằm ở máy này (chưa/không bao giờ đẩy lên kho studio).
    result["created_via"]    = query.value("created_via").toString();
    result["synced"]         = query.value("synced").toInt() == 1;
    result["found"]          = true;
  } else {
    result["found"] = false;
  }
  return result;
}

QVariantList DatabaseManager::getVouchers(const QString &filter, int employeeId,
                                          const QString &codeKind) {
  QSqlQuery query(m_database);
  QString sql = "SELECT code, type, value, used, used_at, created_at, "
                "employee_id, valid_from, valid_until, paid_amount, shift, "
                "COALESCE(package_minutes,0) AS package_minutes, "
                "COALESCE(package_prints,1) AS package_prints, "
                "COALESCE(package_name,'') AS package_name, "
                "COALESCE(usage_limit,1) AS usage_limit, "
                "COALESCE(use_count, CASE WHEN used = 1 THEN 1 ELSE 0 END) AS use_count, "
                "COALESCE(created_via,'desktop') AS created_via, COALESCE(synced,0) AS synced, "
                "COALESCE(note,'') AS note "
                "FROM vouchers";
  QStringList where;
  if (filter == "unused") where << "used = 0";
  else if (filter == "used") where << "used = 1";
  if (employeeId >= 0) where << "employee_id = :emp";
  if (codeKind == "cash_code")
    where << "type = 'cash_code'";
  else if (codeKind == "package_code")
    where << "type = 'package_code'";
  else if (codeKind == "voucher")
    where << "type <> 'cash_code' AND type <> 'package_code'";
  if (!where.isEmpty()) sql += " WHERE " + where.join(" AND ");
  sql += " ORDER BY created_at DESC";
  query.prepare(sql);
  if (employeeId >= 0) query.bindValue(":emp", employeeId);
  QVariantList list;
  if (query.exec()) {
    while (query.next()) {
      QVariantMap row;
      row["code"]        = query.value("code").toString();
      row["type"]        = query.value("type").toString();
      row["value"]       = query.value("value").toInt();
      row["used"]        = query.value("used").toInt() == 1;
      row["used_at"]     = query.value("used_at").toString();
      row["created_at"]  = query.value("created_at").toString();
      row["employee_id"] = query.value("employee_id").toInt();
      row["valid_from"]  = query.value("valid_from").toString();
      row["valid_until"] = query.value("valid_until").toString();
      row["paid_amount"] = query.value("paid_amount").toInt();
      row["shift"]       = query.value("shift").toString();
      row["package_minutes"] = query.value("package_minutes").toInt();
      row["package_prints"]  = query.value("package_prints").toInt();
      row["package_name"]    = query.value("package_name").toString();
      row["usage_limit"]     = query.value("usage_limit").toInt();
      row["use_count"]       = query.value("use_count").toInt();
      row["created_via"] = query.value("created_via").toString();
      row["synced"]      = query.value("synced").toInt() == 1;
      row["note"]        = query.value("note").toString();
      list.append(row);
    }
  }
  return list;
}

bool DatabaseManager::deleteVoucher(const QString &code) {
  QSqlQuery query(m_database);
  query.prepare("DELETE FROM vouchers WHERE code = :code");
  query.bindValue(":code", code.toUpper());
  if (!query.exec()) {
    qWarning() << "deleteVoucher failed:" << query.lastError().text();
    return false;
  }
  return query.numRowsAffected() > 0;
}

int DatabaseManager::getVoucherCount(const QString &filter, int employeeId,
                                     const QString &codeKind) {
  QSqlQuery query(m_database);
  QString sql = "SELECT COUNT(*) FROM vouchers";
  QStringList where;
  if (filter == "unused") where << "used = 0";
  else if (filter == "used") where << "used = 1";
  if (employeeId >= 0) where << "employee_id = :emp";
  if (codeKind == "cash_code")
    where << "type = 'cash_code'";
  else if (codeKind == "package_code")
    where << "type = 'package_code'";
  else if (codeKind == "voucher")
    where << "type <> 'cash_code' AND type <> 'package_code'";
  if (!where.isEmpty()) sql += " WHERE " + where.join(" AND ");
  query.prepare(sql);
  if (employeeId >= 0) query.bindValue(":emp", employeeId);
  if (query.exec() && query.next())
    return query.value(0).toInt();
  return 0;
}

QVariantList DatabaseManager::getUnsyncedVouchers() {
  QVariantList list;
  QSqlQuery query(m_database);
  query.prepare("SELECT code, type, value, valid_from, valid_until, shift, "
                "employee_id, created_at, COALESCE(note,'') AS note "
                "FROM vouchers WHERE COALESCE(synced,0) = 0");
  if (!query.exec()) {
    qWarning() << "getUnsyncedVouchers failed:" << query.lastError().text();
    return list;
  }
  while (query.next()) {
    QVariantMap row;
    row["code"]        = query.value("code").toString();
    row["type"]        = query.value("type").toString();
    row["value"]       = query.value("value").toInt();
    row["valid_from"]  = query.value("valid_from").toString();
    row["valid_until"] = query.value("valid_until").toString();
    row["shift"]       = query.value("shift").toString();
    row["employee_id"] = query.value("employee_id").toInt();
    row["created_at"]  = query.value("created_at").toString();
    row["note"]        = query.value("note").toString();
    list << row;
  }
  return list;
}

bool DatabaseManager::markVouchersSynced(const QStringList &codes) {
  if (codes.isEmpty()) return true;
  QSqlQuery query(m_database);
  query.prepare("UPDATE vouchers SET synced = 1 WHERE code = :code");
  for (const QString &c : codes) {
    query.bindValue(":code", c.toUpper());
    if (!query.exec())
      qWarning() << "markVouchersSynced failed for" << c << ":" << query.lastError().text();
  }
  return true;
}

// ============= Cloud outbox =============

bool DatabaseManager::outboxEnqueue(const QString &kind, const QString &dedupeKey,
                                    const QString &method, const QString &path,
                                    const QByteArray &payload, bool replace) {
  const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
  QSqlQuery query(m_database);
  // replace: cập nhật payload + đưa về pending (phiên có trạng thái mới hơn).
  // Không replace: giữ bản cũ (bản ghi bất biến như doanh thu / lượt dùng mã).
  query.prepare(replace
      ? "INSERT INTO cloud_outbox (kind, dedupe_key, method, path, payload, created_at, updated_at) "
        "VALUES (:kind, :key, :method, :path, :payload, :now, :now) "
        "ON CONFLICT(dedupe_key) DO UPDATE SET method = excluded.method, path = excluded.path, "
        "payload = excluded.payload, status = 'pending', attempts = 0, last_error = '', "
        "updated_at = excluded.updated_at"
      : "INSERT OR IGNORE INTO cloud_outbox (kind, dedupe_key, method, path, payload, created_at, updated_at) "
        "VALUES (:kind, :key, :method, :path, :payload, :now, :now)");
  query.bindValue(":kind", kind);
  query.bindValue(":key", dedupeKey);
  query.bindValue(":method", method);
  query.bindValue(":path", path);
  query.bindValue(":payload", QString::fromUtf8(payload));
  query.bindValue(":now", now);
  if (!query.exec()) {
    qCritical() << "[DB] outboxEnqueue failed:" << dedupeKey << query.lastError().text();
    return false;
  }
  return true;
}

QVariantList DatabaseManager::outboxPending(int limit) {
  QVariantList list;
  QSqlQuery query(m_database);
  query.prepare("SELECT id, kind, method, path, payload FROM cloud_outbox "
                "WHERE status = 'pending' ORDER BY id LIMIT :limit");
  query.bindValue(":limit", limit);
  if (!query.exec()) {
    qWarning() << "[DB] outboxPending failed:" << query.lastError().text();
    return list;
  }
  while (query.next()) {
    QVariantMap row;
    row["id"]      = query.value("id").toLongLong();
    row["kind"]    = query.value("kind").toString();
    row["method"]  = query.value("method").toString();
    row["path"]    = query.value("path").toString();
    row["payload"] = query.value("payload").toString();
    list << row;
  }
  return list;
}

bool DatabaseManager::outboxRemove(qint64 id) {
  QSqlQuery query(m_database);
  query.prepare("DELETE FROM cloud_outbox WHERE id = :id");
  query.bindValue(":id", id);
  return query.exec();
}

bool DatabaseManager::outboxMarkFailed(qint64 id, const QString &error, bool permanent) {
  QSqlQuery query(m_database);
  query.prepare("UPDATE cloud_outbox SET attempts = attempts + 1, last_error = :err, "
                "status = CASE WHEN :permanent = 1 THEN 'failed' ELSE status END, "
                "updated_at = :now WHERE id = :id");
  query.bindValue(":err", error.left(500));
  query.bindValue(":permanent", permanent ? 1 : 0);
  query.bindValue(":now", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  query.bindValue(":id", id);
  return query.exec();
}

// ============= User Account Operations =============

bool DatabaseManager::registerUser(const QString &fullName, const QString &phone, const QString &passwordHash) {
  QSqlQuery query(m_database);
  if (!query.prepare("INSERT INTO users (full_name, phone, password_hash, created_at) VALUES (?, ?, ?, ?)")) {
    qCritical() << "[DB] registerUser PREPARE failed:" << query.lastError().text();
    return false;
  }
  query.addBindValue(fullName);
  query.addBindValue(phone);
  query.addBindValue(passwordHash);
  query.addBindValue(QDateTime::currentDateTime().toString(Qt::ISODate));
  if (!query.exec()) {
    qCritical() << "[DB] registerUser EXEC failed:"
                << query.lastError().text()
                << "| driverText:" << query.lastError().driverText()
                << "| nativeCode:"  << query.lastError().nativeErrorCode();
    return false;
  }
  qCritical() << "[DB] registerUser OK — phone:" << phone << "name:" << fullName;
  return true;
}

bool DatabaseManager::getUserByPhone(const QString &phone, UserAccount &user) {
  QSqlQuery query(m_database);
  query.prepare("SELECT * FROM users WHERE phone = :phone");
  query.bindValue(":phone", phone);
  if (query.exec() && query.next()) {
    user.id           = query.value("id").toInt();
    user.fullName     = query.value("full_name").toString();
    user.phone        = query.value("phone").toString();
    user.passwordHash = query.value("password_hash").toString();
    user.createdAt    = QDateTime::fromString(query.value("created_at").toString(), Qt::ISODate);
    user.lastLogin    = QDateTime::fromString(query.value("last_login").toString(), Qt::ISODate);
    return true;
  }
  return false;
}

bool DatabaseManager::getUserByName(const QString &fullName, UserAccount &user) {
  QSqlQuery query(m_database);
  query.prepare("SELECT * FROM users WHERE full_name = :name LIMIT 1");
  query.bindValue(":name", fullName);
  if (query.exec() && query.next()) {
    user.id           = query.value("id").toInt();
    user.fullName     = query.value("full_name").toString();
    user.phone        = query.value("phone").toString();
    user.passwordHash = query.value("password_hash").toString();
    user.createdAt    = QDateTime::fromString(query.value("created_at").toString(), Qt::ISODate);
    user.lastLogin    = QDateTime::fromString(query.value("last_login").toString(), Qt::ISODate);
    return true;
  }
  return false;
}

bool DatabaseManager::updateLastLogin(const QString &phone) {
  QSqlQuery query(m_database);
  query.prepare("UPDATE users SET last_login = :at WHERE phone = :phone");
  query.bindValue(":at",    QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":phone", phone);
  return query.exec();
}

bool DatabaseManager::userPhoneExists(const QString &phone) {
  QSqlQuery query(m_database);
  query.prepare("SELECT COUNT(*) FROM users WHERE phone = :phone");
  query.bindValue(":phone", phone);
  if (query.exec() && query.next())
    return query.value(0).toInt() > 0;
  return false;
}

// ============= Print Tracking Operations =============

bool DatabaseManager::incrementPrintCount(int eventId, int copies, bool cutMode) {
  if (eventId <= 0 || copies <= 0) {
    return false;
  }

  QSqlQuery query(m_database);
  // Cập nhật cả tổng lẫn cột phân loại cut/nocut
  if (cutMode) {
    query.prepare("UPDATE events SET print_count = print_count + :c, "
                  "print_count_cut = print_count_cut + :c2 WHERE id = :id");
  } else {
    query.prepare("UPDATE events SET print_count = print_count + :c, "
                  "print_count_nocut = print_count_nocut + :c2 WHERE id = :id");
  }
  query.bindValue(":c",  copies);
  query.bindValue(":c2", copies);
  query.bindValue(":id", eventId);

  if (!query.exec()) {
    qWarning() << "Failed to increment print count:" << query.lastError().text();
    return false;
  }

  qDebug() << "Print count incremented for event" << eventId << "by" << copies
           << (cutMode ? "(cut)" : "(no-cut)");
  return true;
}

int DatabaseManager::getPrintCount(int eventId) const {
  if (eventId <= 0) {
    return 0;
  }

  QSqlQuery query(m_database);
  query.prepare("SELECT print_count FROM events WHERE id = :id");
  query.bindValue(":id", eventId);

  if (query.exec() && query.next()) {
    return query.value(0).toInt();
  }

  qWarning() << "Failed to get print count for event" << eventId;
  return 0;
}

int DatabaseManager::getCutPrintCount(int eventId) const {
  if (eventId <= 0) return 0;
  QSqlQuery query(m_database);
  query.prepare("SELECT print_count_cut FROM events WHERE id = :id");
  query.bindValue(":id", eventId);
  if (query.exec() && query.next()) return query.value(0).toInt();
  return 0;
}

int DatabaseManager::getNoCutPrintCount(int eventId) const {
  if (eventId <= 0) return 0;
  QSqlQuery query(m_database);
  query.prepare("SELECT print_count_nocut FROM events WHERE id = :id");
  query.bindValue(":id", eventId);
  if (query.exec() && query.next()) return query.value(0).toInt();
  return 0;
}

int DatabaseManager::getOriginalPhotoCount(int eventId) const {
  if (eventId <= 0) return 0;
  QSqlQuery query(m_database);
  query.prepare("SELECT COUNT(*) FROM photos WHERE event_id = :id AND type = 'original'");
  query.bindValue(":id", eventId);
  if (query.exec() && query.next()) return query.value(0).toInt();
  return 0;
}

int DatabaseManager::getSessionCount(int eventId) const {
  if (eventId <= 0) return 0;
  QSqlQuery query(m_database);
  query.prepare("SELECT COUNT(*) FROM sessions WHERE event_id = :id");
  query.bindValue(":id", eventId);
  if (query.exec() && query.next()) return query.value(0).toInt();
  return 0;
}

int DatabaseManager::getTotalEventCount() const {
  QSqlQuery query(m_database);
  if (query.exec("SELECT COUNT(*) FROM events") && query.next())
    return query.value(0).toInt();
  return 0;
}



bool DatabaseManager::addMachine(const QString &hwid, const QString &deviceName) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        INSERT OR IGNORE INTO machines (hwid, first_seen, device_name, created_at, auth_status)
        VALUES (:hwid, :first_seen, :device_name, :created_at, 'pending')
    )");
  query.bindValue(":hwid", hwid);
  query.bindValue(":first_seen", QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":device_name", deviceName);
  query.bindValue(":created_at", QDateTime::currentDateTime().toString(Qt::ISODate));

  if (!query.exec()) {
    qCritical() << "Failed to add machine:" << query.lastError().text();
    return false;
  }

  qDebug() << "Machine added with HWID:" << hwid;
  return true;
}

bool DatabaseManager::updateMachineAuthStatus(const QString &hwid, const QString &status) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        UPDATE machines SET auth_status = :status, last_validated = :last_validated
        WHERE hwid = :hwid
    )");
  query.bindValue(":status", status);
  query.bindValue(":last_validated", QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":hwid", hwid);

  if (!query.exec()) {
    qCritical() << "Failed to update machine auth status:" << query.lastError().text();
    return false;
  }

  return true;
}

QString DatabaseManager::getMachineHWID() {
  QSqlQuery query(m_database);
  query.prepare("SELECT hwid FROM machines LIMIT 1");

  if (query.exec() && query.next()) {
    return query.value("hwid").toString();
  }

  return "";
}

QString DatabaseManager::getMachineAuthStatus(const QString &hwid) {
  QSqlQuery query(m_database);
  query.prepare("SELECT auth_status FROM machines WHERE hwid = :hwid");
  query.bindValue(":hwid", hwid);

  if (query.exec() && query.next()) {
    return query.value("auth_status").toString();
  }

  return "unknown";
}

// ============= Session Operations =============

bool DatabaseManager::createSession(const QString &sessionId, int eventId, const QString &hwid) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        INSERT INTO sessions (session_id, event_id, hwid, started_at, status,
                              status_updated_at, status_version, sync_pending)
        VALUES (:session_id, :event_id, :hwid, :started_at, 'PREPARED',
                :started_at, 1, 1)
    )");
  query.bindValue(":session_id", sessionId);
  query.bindValue(":event_id", eventId);
  query.bindValue(":hwid", hwid);
  query.bindValue(":started_at", QDateTime::currentDateTime().toString(Qt::ISODate));

  if (!query.exec()) {
    qCritical() << "Failed to create session:" << query.lastError().text();
    return false;
  }

  qDebug() << "Session created:" << sessionId;
  return true;
}

bool DatabaseManager::endSession(const QString &sessionId) {
  const QVariantMap info = getSessionInfo(sessionId);
  const int expected = info.value("expected_photos").toInt();
  QSqlQuery count(m_database);
  // Một file chỉ tính một lần: ảnh được ghi khi chụp rồi ghi lại lúc lưu phiên, có khi
  // khác dấu gạch chéo / hoa thường trong đường dẫn.
  count.prepare("SELECT COUNT(DISTINCT LOWER(REPLACE(file_path, '\\', '/'))) FROM photos "
                "WHERE session_id = :sid AND type = 'original'");
  count.bindValue(":sid", sessionId);
  int actual = 0;
  if (count.exec() && count.next()) actual = count.value(0).toInt();
  const QString finalStatus = (expected > 0 && actual < expected) ? "PARTIAL" : "COMPLETED";
  return updateSessionState(sessionId, finalStatus, expected, actual);
}

bool DatabaseManager::updateSessionState(const QString &sessionId, const QString &status,
                                         int expectedPhotos, int capturedPhotos,
                                         const QString &failureCode,
                                         const QString &failureMessage) {
  const QString normalized = status.trimmed().toUpper();
  const QString now = QDateTime::currentDateTime().toString(Qt::ISODate);
  const bool starts = normalized == "CAPTURING";
  const bool ends = normalized == "COMPLETED" || normalized == "PARTIAL" ||
                    normalized == "CAMERA_ERROR" || normalized == "APP_INTERRUPTED" ||
                    normalized == "CANCELLED";
  const bool cameraError = normalized == "CAMERA_ERROR";
  const bool needsResolution = normalized == "PARTIAL" || normalized == "CAMERA_ERROR" ||
                               normalized == "APP_INTERRUPTED" || normalized == "CANCELLED";
  QSqlQuery q(m_database);
  q.prepare(R"(
    UPDATE sessions SET status=:status,
      expected_photos=CASE WHEN :expected >= 0 THEN :expected ELSE expected_photos END,
      photo_count=CASE WHEN :captured >= 0 THEN :captured ELSE photo_count END,
      capture_started_at=CASE WHEN :starts=1 THEN COALESCE(capture_started_at,:now) ELSE capture_started_at END,
      ended_at=CASE WHEN :ends=1 THEN :now WHEN :starts=1 THEN NULL ELSE ended_at END,
      failure_code=CASE WHEN :failure_code<>'' THEN :failure_code WHEN :starts=1 THEN '' ELSE failure_code END,
      failure_message=CASE WHEN :failure_message<>'' THEN :failure_message WHEN :starts=1 THEN '' ELSE failure_message END,
      camera_error_count=camera_error_count + :camera_error,
      had_camera_error=CASE WHEN :camera_error=1 THEN 1 ELSE had_camera_error END,
      resolution_state=CASE WHEN :needs_resolution=1 AND resolution_state<>'RESOLVED' THEN 'PENDING'
                            WHEN :starts=1 THEN 'NOT_REQUIRED' ELSE resolution_state END,
      status_updated_at=:now, status_version=status_version+1, sync_pending=1
    WHERE session_id=:sid
  )");
  q.bindValue(":status", normalized);
  q.bindValue(":expected", expectedPhotos);
  q.bindValue(":captured", capturedPhotos);
  q.bindValue(":starts", starts ? 1 : 0);
  q.bindValue(":ends", ends ? 1 : 0);
  q.bindValue(":now", now);
  q.bindValue(":failure_code", failureCode);
  q.bindValue(":failure_message", failureMessage);
  q.bindValue(":camera_error", cameraError ? 1 : 0);
  q.bindValue(":needs_resolution", needsResolution ? 1 : 0);
  q.bindValue(":sid", sessionId);
  if (!q.exec()) {
    qWarning() << "updateSessionState failed:" << q.lastError().text();
    return false;
  }
  return q.numRowsAffected() > 0;
}

bool DatabaseManager::markSessionPaid(const QString &sessionId) {
  QSqlQuery q(m_database);
  q.prepare(R"(UPDATE sessions SET status=CASE WHEN status='PREPARED' THEN 'WAITING_CAPTURE' ELSE status END,
              status_updated_at=:now, status_version=status_version+1, sync_pending=1 WHERE session_id=:sid)");
  q.bindValue(":now", QDateTime::currentDateTime().toString(Qt::ISODate));
  q.bindValue(":sid", sessionId);
  return q.exec() && q.numRowsAffected() > 0;
}

bool DatabaseManager::resolveCaptureAttempt(const QString &sessionId, const QString &resolutionType,
                                            int refundAmount, const QString &note,
                                            const QString &resolvedBy) {
  QSqlQuery gross(m_database);
  gross.prepare(R"(SELECT COALESCE(SUM(received_amount),0) FROM revenue_records
                    WHERE session_id=:sid AND COALESCE(source,'session')='session')");
  gross.bindValue(":sid", sessionId);
  int received = 0;
  if (gross.exec() && gross.next()) received = gross.value(0).toInt();
  if (refundAmount < 0 || refundAmount > received) return false;
  QSqlQuery q(m_database);
  q.prepare(R"(UPDATE sessions SET resolution_state='RESOLVED', resolution_type=:type,
              refund_amount=:refund, resolution_note=:note, resolved_at=:at, resolved_by=:by,
              sync_pending=1 WHERE session_id=:sid)");
  q.bindValue(":type", resolutionType.trimmed().toUpper());
  q.bindValue(":refund", refundAmount);
  q.bindValue(":note", note);
  q.bindValue(":at", QDateTime::currentDateTime().toString(Qt::ISODate));
  q.bindValue(":by", resolvedBy);
  q.bindValue(":sid", sessionId);
  return q.exec() && q.numRowsAffected() > 0;
}

int DatabaseManager::recoverInterruptedSessions() {
  QSqlQuery q(m_database);
  q.prepare(R"(UPDATE sessions SET status='APP_INTERRUPTED', ended_at=:now,
              failure_code='APP_RESTART', failure_message='Ứng dụng bị đóng trước khi lượt chụp hoàn tất',
              resolution_state='PENDING', status_updated_at=:now,
              status_version=status_version+1, sync_pending=1
              WHERE status IN ('WAITING_CAPTURE','CAPTURING'))");
  q.bindValue(":now", QDateTime::currentDateTime().toString(Qt::ISODate));
  return q.exec() ? q.numRowsAffected() : 0;
}

bool DatabaseManager::addPhotoToSession(int photoId, const QString &sessionId) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        UPDATE photos SET session_id = :session_id
        WHERE id = :photo_id
    )");
  query.bindValue(":session_id", sessionId);
  query.bindValue(":photo_id", photoId);

  if (!query.exec()) {
    qCritical() << "Failed to add photo to session:" << query.lastError().text();
    return false;
  }

  // Increment photo count in session
  query.prepare("UPDATE sessions SET photo_count = photo_count + 1 WHERE session_id = :session_id");
  query.bindValue(":session_id", sessionId);
  query.exec();

  return true;
}

QVariantMap DatabaseManager::getSessionInfo(const QString &sessionId) {
  QVariantMap sessionInfo;
  QSqlQuery query(m_database);
  query.prepare(R"(
        SELECT session_id, event_id, hwid, started_at, ended_at, photo_count, status,
               expected_photos, capture_started_at, status_updated_at, failure_code,
               failure_message, camera_error_count, had_camera_error, status_version,
               resolution_state, resolution_type, refund_amount, resolution_note,
               resolved_at, resolved_by, sync_pending
        FROM sessions
        WHERE session_id = :session_id
    )");
  query.bindValue(":session_id", sessionId);

  if (query.exec() && query.next()) {
    sessionInfo["session_id"] = query.value("session_id").toString();
    sessionInfo["event_id"] = query.value("event_id").toInt();
    sessionInfo["hwid"] = query.value("hwid").toString();
    sessionInfo["started_at"] = query.value("started_at").toString();
    sessionInfo["ended_at"] = query.value("ended_at").toString();
    sessionInfo["photo_count"] = query.value("photo_count").toInt();
    sessionInfo["status"] = query.value("status").toString();
    sessionInfo["expected_photos"] = query.value("expected_photos").toInt();
    sessionInfo["capture_started_at"] = query.value("capture_started_at").toString();
    sessionInfo["status_updated_at"] = query.value("status_updated_at").toString();
    sessionInfo["failure_code"] = query.value("failure_code").toString();
    sessionInfo["failure_message"] = query.value("failure_message").toString();
    sessionInfo["camera_error_count"] = query.value("camera_error_count").toInt();
    sessionInfo["had_camera_error"] = query.value("had_camera_error").toInt() == 1;
    sessionInfo["status_version"] = query.value("status_version").toInt();
    sessionInfo["resolution_state"] = query.value("resolution_state").toString();
    sessionInfo["resolution_type"] = query.value("resolution_type").toString();
    sessionInfo["refund_amount"] = query.value("refund_amount").toInt();
    sessionInfo["resolution_note"] = query.value("resolution_note").toString();
    sessionInfo["resolved_at"] = query.value("resolved_at").toString();
    sessionInfo["resolved_by"] = query.value("resolved_by").toString();
    sessionInfo["sync_pending"] = query.value("sync_pending").toInt() == 1;
  }

  return sessionInfo;
}

QStringList DatabaseManager::getSessionOriginalPhotos(const QString &sessionId) {
  QStringList paths;
  if (sessionId.isEmpty()) return paths;
  QSqlQuery query(m_database);
  query.prepare(R"(
        SELECT file_path FROM photos
        WHERE session_id = :sid AND type = 'original'
        ORDER BY created_at ASC, id ASC
    )");
  query.bindValue(":sid", sessionId);
  if (query.exec()) {
    // Phiên cũ có thể đã ghi một ảnh hai lần (lúc chụp và lúc lưu phiên): giữ lần đầu.
    QSet<QString> seen;
    while (query.next()) {
      const QString path = query.value("file_path").toString();
      const QString key = QDir::fromNativeSeparators(path).toLower();
      if (seen.contains(key)) continue;
      seen.insert(key);
      paths.append(path);
    }
  } else {
    qWarning() << "getSessionOriginalPhotos failed:" << query.lastError().text();
  }
  return paths;
}

QVariantList DatabaseManager::getRecentSessions(int eventId, int limit) {
  QVariantList result;
  QSqlQuery query(m_database);
  // Chỉ lấy session ĐÃ có ít nhất 1 ảnh gốc (quầy thu ngân chỉ quan tâm session có ảnh).
  query.prepare(R"(
        SELECT s.session_id AS sid,
               COALESCE(s.capture_started_at, s.started_at) AS ts,
               (SELECT COUNT(*) FROM photos p
                  WHERE p.session_id = s.session_id AND p.type = 'original') AS cnt,
               (SELECT p2.file_path FROM photos p2
                  WHERE p2.session_id = s.session_id AND p2.type = 'original'
                  ORDER BY p2.created_at ASC, p2.id ASC LIMIT 1) AS first_photo
        FROM sessions s
        WHERE s.event_id = :eid
        ORDER BY ts DESC
        LIMIT :lim
    )");
  query.bindValue(":eid", eventId);
  query.bindValue(":lim", limit > 0 ? limit : 50);
  if (query.exec()) {
    while (query.next()) {
      const int cnt = query.value("cnt").toInt();
      if (cnt <= 0) continue;  // bỏ session chưa có ảnh gốc
      QVariantMap m;
      m["sessionId"]  = query.value("sid").toString();
      m["startedAt"]  = query.value("ts").toString();
      m["photoCount"] = cnt;
      m["firstPhoto"] = query.value("first_photo").toString();
      result.append(m);
    }
  } else {
    qWarning() << "getRecentSessions failed:" << query.lastError().text();
  }
  return result;
}

QVariantList DatabaseManager::getCaptureAttempts(int employeeId) {
  QString sql = R"(
    WITH pay AS (
      SELECT session_id, event_id,
             SUM(received_amount) gross_received,
             GROUP_CONCAT(DISTINCT payment_method) payment_methods,
             MIN(recorded_at) paid_at,
             MIN(employee_id) employee_id
      FROM revenue_records
      WHERE COALESCE(source,'session')='session' AND COALESCE(session_id,'')<>''
      GROUP BY session_id, event_id
    )
    SELECT s.session_id, s.event_id, COALESCE(e.name,'') event_name, s.hwid,
           s.started_at, s.capture_started_at, s.ended_at, s.status_updated_at,
           s.status, s.expected_photos, s.photo_count photos_captured,
           s.failure_code, s.failure_message, s.camera_error_count, s.had_camera_error,
           s.resolution_state, s.resolution_type, s.refund_amount, s.resolution_note,
           s.resolved_at, s.resolved_by, s.status_version,
           COALESCE(p.gross_received,0) gross_received,
           COALESCE(p.gross_received,0)-COALESCE(s.refund_amount,0) net_received,
           COALESCE(p.payment_methods,'free') payment_methods,
           COALESCE(p.paid_at,'') paid_at, COALESCE(p.employee_id,0) employee_id
    FROM sessions s
    LEFT JOIN events e ON e.id=s.event_id
    LEFT JOIN pay p ON p.session_id=s.session_id AND p.event_id=s.event_id
    WHERE (s.status<>'PREPARED' OR p.session_id IS NOT NULL)
  )";
  if (employeeId >= 0) sql += " AND COALESCE(p.employee_id,0)=:emp";
  sql += " ORDER BY COALESCE(s.capture_started_at,p.paid_at,s.started_at) DESC";

  QSqlQuery q(m_database);
  q.prepare(sql);
  if (employeeId >= 0) q.bindValue(":emp", employeeId);
  QVariantList out;
  if (!q.exec()) {
    qWarning() << "getCaptureAttempts failed:" << q.lastError().text();
    return out;
  }
  while (q.next()) {
    QVariantMap r;
    const QSqlRecord rec = q.record();
    for (int i = 0; i < rec.count(); ++i) r[rec.fieldName(i)] = q.value(i);
    const QString st = r.value("status").toString();
    const bool failed = st == "PARTIAL" || st == "CAMERA_ERROR" ||
                        st == "APP_INTERRUPTED" || st == "CANCELLED";
    r["payment_status"] = r.value("gross_received").toInt() > 0 ? "PAID" : "FREE";
    r["needs_attention"] = failed && r.value("resolution_state").toString() != "RESOLVED";
    out.append(r);
  }
  return out;
}

bool DatabaseManager::exportCaptureAttemptsToCSV(const QString &filePath, int employeeId) {
  QFile file(filePath);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
  QTextStream out(&file);
  out.setEncoding(QStringConverter::Utf8);
  out << "\xEF\xBB\xBF";
  out << "Session,Sự Kiện,Bắt Đầu,Kết Thúc,Trạng Thái,Ảnh Dự Kiến,Ảnh Thực Tế,Thanh Toán,Đã Thu,Đã Hoàn,Doanh Thu Ròng,Mã Lỗi,Lỗi,Xử Lý,Ghi Chú,Người Xử Lý\n";
  auto esc = [](QString s) { s.replace('"', "\"\""); return "\"" + s + "\""; };
  const QVariantList rows = getCaptureAttempts(employeeId);
  for (const QVariant &v : rows) {
    const QVariantMap r = v.toMap();
    out << esc(r.value("session_id").toString()) << ','
        << esc(r.value("event_name").toString()) << ','
        << esc(r.value("capture_started_at").toString()) << ','
        << esc(r.value("ended_at").toString()) << ','
        << esc(r.value("status").toString()) << ','
        << r.value("expected_photos").toInt() << ',' << r.value("photos_captured").toInt() << ','
        << esc(r.value("payment_methods").toString()) << ','
        << r.value("gross_received").toInt() << ',' << r.value("refund_amount").toInt() << ','
        << r.value("net_received").toInt() << ',' << esc(r.value("failure_code").toString()) << ','
        << esc(r.value("failure_message").toString()) << ',' << esc(r.value("resolution_type").toString()) << ','
        << esc(r.value("resolution_note").toString()) << ',' << esc(r.value("resolved_by").toString()) << '\n';
  }
  return true;
}

// ============= Upload Queue Operations =============

bool DatabaseManager::addToUploadQueue(int photoId, const QString &sessionId,
                                       const QString &s3Path, const QString &localPath) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        INSERT INTO upload_queue (photo_id, session_id, s3_path, local_path, upload_status)
        VALUES (:photo_id, :session_id, :s3_path, :local_path, 'pending')
    )");
  query.bindValue(":photo_id", photoId);
  query.bindValue(":session_id", sessionId);
  query.bindValue(":s3_path", s3Path);
  query.bindValue(":local_path", localPath);

  if (!query.exec()) {
    qCritical() << "Failed to add to upload queue:" << query.lastError().text();
    return false;
  }

  return true;
}

bool DatabaseManager::updateUploadStatus(int queueId, const QString &status) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        UPDATE upload_queue SET upload_status = :status, last_attempt = :last_attempt
        WHERE id = :id
    )");
  query.bindValue(":status", status);
  query.bindValue(":last_attempt", QDateTime::currentDateTime().toString(Qt::ISODate));
  query.bindValue(":id", queueId);

  if (status == "completed") {
    query.prepare(R"(
        UPDATE upload_queue SET uploaded_at = :uploaded_at, upload_status = :status
        WHERE id = :id
    )");
    query.bindValue(":uploaded_at", QDateTime::currentDateTime().toString(Qt::ISODate));
    query.bindValue(":status", status);
    query.bindValue(":id", queueId);
  }

  if (!query.exec()) {
    qCritical() << "Failed to update upload status:" << query.lastError().text();
    return false;
  }

  return true;
}

QList<QVariantMap> DatabaseManager::getPendingUploads() {
  QList<QVariantMap> uploads;
  QSqlQuery query(m_database);
  query.prepare(R"(
        SELECT id, photo_id, session_id, s3_path, local_path, retry_count
        FROM upload_queue
        WHERE upload_status = 'pending' OR upload_status = 'failed'
        ORDER BY last_attempt ASC, id ASC
    )");

  if (query.exec()) {
    while (query.next()) {
      QVariantMap upload;
      upload["id"] = query.value("id").toInt();
      upload["photo_id"] = query.value("photo_id").toInt();
      upload["session_id"] = query.value("session_id").toString();
      upload["s3_path"] = query.value("s3_path").toString();
      upload["local_path"] = query.value("local_path").toString();
      upload["retry_count"] = query.value("retry_count").toInt();
      uploads.append(upload);
    }
  }

  return uploads;
}

bool DatabaseManager::upsertUploadAsset(const UploadAsset &asset) {
  if (asset.assetId.isEmpty() || asset.sessionId.isEmpty() || asset.localPath.isEmpty())
    return false;
  const QString now = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
  QSqlQuery query(m_database);
  query.prepare(R"(
      INSERT INTO upload_assets (
          asset_id, session_id, kind, local_path, file_name, content_type,
          size_bytes, checksum_sha256, photo_index, object_key, status,
          attempts, next_retry_at, created_at, updated_at
      ) VALUES (
          :asset_id, :session_id, :kind, :local_path, :file_name, :content_type,
          :size_bytes, :checksum_sha256, :photo_index, :object_key, 'pending',
          0, '', :now, :now
      )
      ON CONFLICT(asset_id) DO UPDATE SET
          session_id = excluded.session_id,
          kind = excluded.kind,
          local_path = excluded.local_path,
          file_name = excluded.file_name,
          content_type = excluded.content_type,
          photo_index = excluded.photo_index,
          updated_at = excluded.updated_at
      WHERE upload_assets.status <> 'confirmed'
  )");
  query.bindValue(":asset_id", asset.assetId);
  query.bindValue(":session_id", asset.sessionId);
  query.bindValue(":kind", asset.kind);
  query.bindValue(":local_path", asset.localPath);
  query.bindValue(":file_name", asset.fileName);
  query.bindValue(":content_type", asset.contentType);
  query.bindValue(":size_bytes", asset.sizeBytes);
  query.bindValue(":checksum_sha256", asset.checksumSha256);
  query.bindValue(":photo_index", asset.photoIndex);
  query.bindValue(":object_key", asset.objectKey);
  query.bindValue(":now", now);
  if (!query.exec()) {
    qCritical() << "[DB] upsertUploadAsset failed:" << asset.assetId << query.lastError().text();
    return false;
  }
  return true;
}

QString DatabaseManager::getUploadAssetStatus(const QString &assetId) {
  QSqlQuery query(m_database);
  query.prepare("SELECT status FROM upload_assets WHERE asset_id = :asset_id");
  query.bindValue(":asset_id", assetId);
  if (!query.exec() || !query.next()) return QString();
  return query.value(0).toString();
}

QStringList DatabaseManager::uploadAssetIdsForSession(const QString &sessionId, const QString &kind) {
  QStringList ids;
  QSqlQuery query(m_database);
  query.prepare("SELECT asset_id FROM upload_assets WHERE session_id = :sid AND kind = :kind "
                "ORDER BY photo_index ASC, created_at ASC");
  query.bindValue(":sid", sessionId);
  query.bindValue(":kind", kind);
  if (!query.exec()) {
    qWarning() << "[DB] uploadAssetIdsForSession failed:" << query.lastError().text();
    return ids;
  }
  while (query.next())
    ids << query.value(0).toString();
  return ids;
}

QVariantList DatabaseManager::pendingUploadAssets(int limit) {
  QVariantList list;
  QSqlQuery query(m_database);
  query.prepare(R"(
      SELECT asset_id, session_id, kind, local_path, file_name, content_type,
             size_bytes, checksum_sha256, photo_index, object_key, upload_url,
             expires_at, status, attempts, last_error
        FROM upload_assets
       WHERE (status IN ('pending','retry','uploaded','preparing','uploading')
              OR (status = 'failed' AND last_error LIKE '%404%'))
         AND (COALESCE(next_retry_at, '') = '' OR next_retry_at <= :now)
       -- Bản xem nhỏ (thumbnail, rồi preview) đi trước ảnh gốc ~20 MB: khách thấy đủ
       -- ảnh trên web trong vài giây dù ảnh gốc còn đang lên.
       ORDER BY CASE status WHEN 'uploaded' THEN 0 ELSE 1 END,
                CASE kind WHEN 'thumbnail' THEN 0 WHEN 'preview' THEN 1 ELSE 2 END,
                updated_at ASC
       LIMIT :limit
  )");
  query.bindValue(":now", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  query.bindValue(":limit", limit);
  if (!query.exec()) {
    qWarning() << "[DB] pendingUploadAssets failed:" << query.lastError().text();
    return list;
  }
  while (query.next()) {
    QVariantMap row;
    row["asset_id"] = query.value("asset_id").toString();
    row["session_id"] = query.value("session_id").toString();
    row["kind"] = query.value("kind").toString();
    row["local_path"] = query.value("local_path").toString();
    row["file_name"] = query.value("file_name").toString();
    row["content_type"] = query.value("content_type").toString();
    row["size_bytes"] = query.value("size_bytes").toLongLong();
    row["checksum_sha256"] = query.value("checksum_sha256").toString();
    row["photo_index"] = query.value("photo_index").toInt();
    row["object_key"] = query.value("object_key").toString();
    row["upload_url"] = query.value("upload_url").toString();
    row["expires_at"] = query.value("expires_at").toString();
    row["status"] = query.value("status").toString();
    row["attempts"] = query.value("attempts").toInt();
    row["last_error"] = query.value("last_error").toString();
    list << row;
  }
  return list;
}

bool DatabaseManager::updateUploadAssetPrepared(const QString &assetId, qint64 sizeBytes,
                                                const QString &checksumSha256,
                                                const QString &objectKey,
                                                const QString &uploadUrl,
                                                const QString &expiresAt) {
  QSqlQuery query(m_database);
  query.prepare(R"(
      UPDATE upload_assets
         SET size_bytes = :size_bytes, checksum_sha256 = :checksum,
             object_key = :object_key, upload_url = :upload_url,
             expires_at = :expires_at, status = 'uploading',
             last_error = '', updated_at = :now
       WHERE asset_id = :asset_id AND status <> 'confirmed'
  )");
  query.bindValue(":size_bytes", sizeBytes);
  query.bindValue(":checksum", checksumSha256);
  query.bindValue(":object_key", objectKey);
  query.bindValue(":upload_url", uploadUrl);
  query.bindValue(":expires_at", expiresAt);
  query.bindValue(":now", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  query.bindValue(":asset_id", assetId);
  return query.exec();
}

bool DatabaseManager::updateUploadAssetStatus(const QString &assetId, const QString &status,
                                              const QString &error) {
  QSqlQuery query(m_database);
  query.prepare(R"(
      UPDATE upload_assets
         SET status = :status, last_error = :error, updated_at = :now
       WHERE asset_id = :asset_id AND status <> 'confirmed'
  )");
  query.bindValue(":status", status);
  query.bindValue(":error", error.left(500));
  query.bindValue(":now", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  query.bindValue(":asset_id", assetId);
  return query.exec();
}

bool DatabaseManager::markUploadAssetRetry(const QString &assetId, const QString &error,
                                           int delaySeconds) {
  const QString nextRetry = QDateTime::currentDateTimeUtc()
      .addSecs(qMax(1, delaySeconds))
      .toString(Qt::ISODateWithMs);
  QSqlQuery query(m_database);
  query.prepare(R"(
      UPDATE upload_assets
         SET status = 'retry', attempts = attempts + 1,
             next_retry_at = :next_retry_at, last_error = :error, updated_at = :now
       WHERE asset_id = :asset_id AND status <> 'confirmed'
  )");
  query.bindValue(":next_retry_at", nextRetry);
  query.bindValue(":error", error.left(500));
  query.bindValue(":now", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  query.bindValue(":asset_id", assetId);
  return query.exec();
}

bool DatabaseManager::markUploadAssetConfirmed(const QString &assetId, qint64 sizeBytes,
                                               const QString &objectKey) {
  QSqlQuery query(m_database);
  query.prepare(R"(
      UPDATE upload_assets
         SET status = 'confirmed', size_bytes = CASE WHEN :size_bytes > 0 THEN :size_bytes ELSE size_bytes END,
             object_key = CASE WHEN :object_key <> '' THEN :object_key ELSE object_key END,
             upload_url = '', next_retry_at = '', last_error = '',
             confirmed_at = :now, updated_at = :now
       WHERE asset_id = :asset_id
  )");
  query.bindValue(":size_bytes", sizeBytes);
  query.bindValue(":object_key", objectKey);
  query.bindValue(":now", QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs));
  query.bindValue(":asset_id", assetId);
  return query.exec();
}

int DatabaseManager::uploadAssetPendingCount() const {
  QSqlQuery query(m_database);
  if (!query.exec("SELECT COUNT(*) FROM upload_assets WHERE status <> 'confirmed'")) {
    qWarning() << "[DB] uploadAssetPendingCount failed:" << query.lastError().text();
    return 0;
  }
  return query.next() ? query.value(0).toInt() : 0;
}

// ============= App Settings Operations =============

// Load the whole app_settings table into memory once. The table is tiny
// (a few dozen rows), so this single query replaces one query per getSetting().
// Caller must hold m_settingsMutex.
void DatabaseManager::loadSettingsCache() {
  m_settingsCache.clear();
  QSqlQuery query(m_database);
  if (query.exec("SELECT key, value FROM app_settings")) {
    while (query.next())
      m_settingsCache.insert(query.value(0).toString(),
                             query.value(1).toString());
  } else {
    qWarning() << "loadSettingsCache: failed to read app_settings:"
               << query.lastError().text();
  }
  m_settingsCacheLoaded = true;
  qDebug() << "Settings cache loaded:" << m_settingsCache.size() << "entries";
}

bool DatabaseManager::setSetting(const QString &key, const QString &value) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        INSERT OR REPLACE INTO app_settings (key, value, updated_at)
        VALUES (:key, :value, :updated_at)
    )");
  query.bindValue(":key", key);
  query.bindValue(":value", value);
  query.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));

  if (!query.exec()) {
    qCritical() << "Failed to set setting:" << key << query.lastError().text();
    return false;
  }

  // Write-through: keep the in-memory cache consistent with the DB.
  {
    QMutexLocker lock(&m_settingsMutex);
    if (!m_settingsCacheLoaded) loadSettingsCache();
    m_settingsCache.insert(key, value);
  }

  qDebug() << "Setting saved:" << key << "=" << value;
  return true;
}

QString DatabaseManager::getSetting(const QString &key, const QString &defaultValue) {
  QMutexLocker lock(&m_settingsMutex);
  if (!m_settingsCacheLoaded) loadSettingsCache();

  auto it = m_settingsCache.constFind(key);
  return (it != m_settingsCache.constEnd()) ? it.value() : defaultValue;
}

// ============= Per-Event Settings Operations =============

QString DatabaseManager::eventSettingCacheKey(int eventId, const QString &key) {
  return QString::number(eventId) + QChar(0x1f) + key;
}

// Sentinel meaning "no per-event override exists"; lets callers fall back to the
// global app_settings value rather than to a fixed default.
const QString DatabaseManager::kEventSettingAbsent =
    QStringLiteral(" __EVENT_SETTING_ABSENT__ ");

bool DatabaseManager::setEventSetting(int eventId, const QString &key,
                                      const QString &value) {
  QSqlQuery query(m_database);
  query.prepare(R"(
        INSERT OR REPLACE INTO event_settings (event_id, key, value, updated_at)
        VALUES (:event_id, :key, :value, :updated_at)
    )");
  query.bindValue(":event_id", eventId);
  query.bindValue(":key", key);
  query.bindValue(":value", value);
  query.bindValue(":updated_at", QDateTime::currentDateTime().toString(Qt::ISODate));

  if (!query.exec()) {
    qCritical() << "Failed to set event setting:" << eventId << key
                << query.lastError().text();
    return false;
  }

  // Write-through: keep the in-memory cache consistent with the DB.
  {
    QMutexLocker lock(&m_settingsMutex);
    m_eventSettingsCache.insert(eventSettingCacheKey(eventId, key), value);
  }
  return true;
}

QString DatabaseManager::getEventSettingRaw(int eventId, const QString &key) {
  const QString cacheKey = eventSettingCacheKey(eventId, key);

  QMutexLocker lock(&m_settingsMutex);
  auto it = m_eventSettingsCache.constFind(cacheKey);
  if (it != m_eventSettingsCache.constEnd())
    return it.value();

  // Cache miss: read once from DB, cache the resolved value (including the
  // "absent" sentinel) so repeated QML binding reads stay off SQLite.
  QSqlQuery query(m_database);
  query.prepare("SELECT value FROM event_settings WHERE event_id = :event_id AND key = :key");
  query.bindValue(":event_id", eventId);
  query.bindValue(":key", key);

  QString resolved = kEventSettingAbsent;
  if (query.exec() && query.next())
    resolved = query.value(0).toString();

  m_eventSettingsCache.insert(cacheKey, resolved);
  return resolved;
}

bool DatabaseManager::copyEventSettings(int sourceEventId, int targetEventId) {
  if (sourceEventId <= 0 || targetEventId <= 0)
    return false;

  QSqlQuery query(m_database);
  query.prepare("SELECT key, value FROM event_settings WHERE event_id = :event_id");
  query.bindValue(":event_id", sourceEventId);
  if (!query.exec()) {
    qCritical() << "Failed to read source event settings:" << sourceEventId
                << query.lastError().text();
    return false;
  }

  while (query.next()) {
    const QString key = query.value(0).toString();
    const QString value = query.value(1).toString();
    if (!setEventSetting(targetEventId, key, value))
      return false;
  }

  return true;
}

bool DatabaseManager::copyPrinterSettings(int sourceEventId, int targetEventId) {
  if (sourceEventId <= 0 || targetEventId <= 0)
    return false;

  QSqlQuery readQuery(m_database);
  readQuery.prepare("SELECT printer_name, print_copies, print_mode, resolution, cut_mode "
                    "FROM printer_settings WHERE event_id = :event_id");
  readQuery.bindValue(":event_id", sourceEventId);
  if (!readQuery.exec()) {
    qCritical() << "Failed to read source printer settings:" << sourceEventId
                << readQuery.lastError().text();
    return false;
  }

  if (!readQuery.next())
    return true;

  QSqlQuery writeQuery(m_database);
  writeQuery.prepare("INSERT OR REPLACE INTO printer_settings "
                     "(event_id, printer_name, print_copies, print_mode, resolution, cut_mode) "
                     "VALUES (:event_id, :printer_name, :print_copies, :print_mode, :resolution, :cut_mode)");
  writeQuery.bindValue(":event_id", targetEventId);
  writeQuery.bindValue(":printer_name", readQuery.value("printer_name"));
  writeQuery.bindValue(":print_copies", readQuery.value("print_copies"));
  writeQuery.bindValue(":print_mode", readQuery.value("print_mode"));
  writeQuery.bindValue(":resolution", readQuery.value("resolution"));
  writeQuery.bindValue(":cut_mode", readQuery.value("cut_mode"));

  if (!writeQuery.exec()) {
    qCritical() << "Failed to copy printer settings from" << sourceEventId
                << "to" << targetEventId << ":" << writeQuery.lastError().text();
    return false;
  }

  return true;
}

// ============= Migration v15 =============

bool DatabaseManager::applyMigration_v15() {
  QSqlQuery query(m_database);
  if (!query.exec(R"(
      CREATE TABLE IF NOT EXISTS revenue_records (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          event_id        INTEGER NOT NULL,
          event_name      TEXT NOT NULL,
          session_id      TEXT,
          recorded_at     TEXT NOT NULL,
          print_count     INTEGER DEFAULT 0,
          amount_required INTEGER DEFAULT 0,
          cash_received   INTEGER DEFAULT 0,
          transfer_amount INTEGER DEFAULT 0,
          change_amount   INTEGER DEFAULT 0,
          payment_method  TEXT NOT NULL
      )
  )")) {
    qCritical() << "Failed to create revenue_records table:" << query.lastError().text();
    return false;
  }
  qDebug() << "Revenue records table created successfully";
  return setSchemaVersion(15);
}

bool DatabaseManager::applyMigration_v16() {
  QSqlQuery query(m_database);
  if (!query.exec(R"(
      CREATE TABLE IF NOT EXISTS employees (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          full_name  TEXT NOT NULL,
          prefix     TEXT NOT NULL UNIQUE,
          pass_hash  TEXT NOT NULL,
          created_at TEXT NOT NULL,
          active     INTEGER DEFAULT 1
      )
  )")) {
    qCritical() << "Failed to create employees table:" << query.lastError().text();
    return false;
  }
  qDebug() << "Employees table created successfully";
  return setSchemaVersion(16);
}

bool DatabaseManager::applyMigration_v17() {
  // Add columns to vouchers + revenue_records. ALTER TABLE ADD COLUMN may fail
  // on a fresh DB where the failsafe block already created the full schema —
  // that's fine, we ignore "duplicate column" errors.
  const QStringList stmts = {
    "ALTER TABLE vouchers ADD COLUMN employee_id INTEGER DEFAULT 0",
    "ALTER TABLE vouchers ADD COLUMN valid_from TEXT DEFAULT ''",
    "ALTER TABLE vouchers ADD COLUMN valid_until TEXT DEFAULT ''",
    "ALTER TABLE vouchers ADD COLUMN used_by_emp_id INTEGER DEFAULT 0",
    "ALTER TABLE vouchers ADD COLUMN paid_amount INTEGER DEFAULT 0",
    "ALTER TABLE vouchers ADD COLUMN shift TEXT DEFAULT ''",
    "ALTER TABLE revenue_records ADD COLUMN employee_id INTEGER DEFAULT 0"
  };
  for (const QString &s : stmts) {
    QSqlQuery q(m_database);
    if (!q.exec(s)) {
      // Ignore "duplicate column name" — column already present.
      const QString err = q.lastError().text();
      if (!err.contains("duplicate column", Qt::CaseInsensitive))
        qWarning() << "[DB] v17 column add note:" << s << "->" << err;
    }
  }
  qDebug() << "Migration v17 (employee/validity columns) applied";
  return setSchemaVersion(17);
}

bool DatabaseManager::applyMigration_v18() {
  // Thêm cột "shift" (tên ca làm việc) vào vouchers — idempotent.
  QSqlQuery q(m_database);
  if (!q.exec("ALTER TABLE vouchers ADD COLUMN shift TEXT DEFAULT ''")) {
    const QString err = q.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive))
      qWarning() << "[DB] v18 add shift column note:" << err;
  }
  qDebug() << "Migration v18 (voucher shift column) applied";
  return setSchemaVersion(18);
}

bool DatabaseManager::applyMigration_v19() {
  // Thêm cột shift / source / received_amount vào revenue_records — idempotent.
  const QStringList stmts = {
    "ALTER TABLE revenue_records ADD COLUMN shift TEXT DEFAULT ''",
    "ALTER TABLE revenue_records ADD COLUMN source TEXT DEFAULT 'session'",
    "ALTER TABLE revenue_records ADD COLUMN received_amount INTEGER DEFAULT 0"
  };
  for (const QString &s : stmts) {
    QSqlQuery q(m_database);
    if (!q.exec(s)) {
      const QString err = q.lastError().text();
      if (!err.contains("duplicate column", Qt::CaseInsensitive))
        qWarning() << "[DB] v19 column add note:" << s << "->" << err;
    }
  }
  qDebug() << "Migration v19 (revenue shift/source/received columns) applied";
  return setSchemaVersion(19);
}

bool DatabaseManager::applyMigration_v20() {
  // Thêm cột note (ghi chú, vd mã voucher) vào revenue_records — idempotent.
  QSqlQuery q(m_database);
  if (!q.exec("ALTER TABLE revenue_records ADD COLUMN note TEXT DEFAULT ''")) {
    const QString err = q.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive))
      qWarning() << "[DB] v20 add note column note:" << err;
  }
  qDebug() << "Migration v20 (revenue note column) applied";
  return setSchemaVersion(20);
}

bool DatabaseManager::applyMigration_v21() {
  // Thêm cột voucher_amount để ghi riêng giá trị voucher kể cả khi thanh toán hỗn hợp.
  QSqlQuery q(m_database);
  if (!q.exec("ALTER TABLE revenue_records ADD COLUMN voucher_amount INTEGER DEFAULT 0")) {
    const QString err = q.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive))
      qWarning() << "[DB] v21 add voucher_amount column:" << err;
  }
  qDebug() << "Migration v21 (revenue voucher_amount column) applied";
  return setSchemaVersion(21);
}

bool DatabaseManager::applyMigration_v22() {
  // Bảng lưu phần ghi đè cài đặt theo từng sự kiện. Mỗi (event_id, key) là một
  // override; key chưa có row sẽ fallback về app_settings (global) ở tầng trên.
  QSqlQuery q(m_database);
  if (!q.exec(R"(
      CREATE TABLE IF NOT EXISTS event_settings (
          event_id   INTEGER NOT NULL,
          key        TEXT NOT NULL,
          value      TEXT,
          updated_at TEXT NOT NULL,
          PRIMARY KEY (event_id, key)
      )
  )")) {
    qCritical() << "[DB] v22 create event_settings failed:" << q.lastError().text();
    return false;
  }
  qDebug() << "Migration v22 (event_settings table) applied";
  return setSchemaVersion(22);
}

bool DatabaseManager::applyMigration_v23() {
  QSqlQuery q(m_database);
  const QStringList alters = {
    "ALTER TABLE sessions ADD COLUMN expected_photos INTEGER DEFAULT 0",
    "ALTER TABLE sessions ADD COLUMN capture_started_at TEXT",
    "ALTER TABLE sessions ADD COLUMN status_updated_at TEXT",
    "ALTER TABLE sessions ADD COLUMN failure_code TEXT DEFAULT ''",
    "ALTER TABLE sessions ADD COLUMN failure_message TEXT DEFAULT ''",
    "ALTER TABLE sessions ADD COLUMN camera_error_count INTEGER DEFAULT 0",
    "ALTER TABLE sessions ADD COLUMN had_camera_error INTEGER DEFAULT 0",
    "ALTER TABLE sessions ADD COLUMN status_version INTEGER DEFAULT 1",
    "ALTER TABLE sessions ADD COLUMN sync_pending INTEGER DEFAULT 1",
    "ALTER TABLE sessions ADD COLUMN resolution_state TEXT DEFAULT 'NOT_REQUIRED'",
    "ALTER TABLE sessions ADD COLUMN resolution_type TEXT DEFAULT ''",
    "ALTER TABLE sessions ADD COLUMN refund_amount INTEGER DEFAULT 0",
    "ALTER TABLE sessions ADD COLUMN resolution_note TEXT DEFAULT ''",
    "ALTER TABLE sessions ADD COLUMN resolved_at TEXT",
    "ALTER TABLE sessions ADD COLUMN resolved_by TEXT DEFAULT ''"
  };
  for (const QString &sql : alters) q.exec(sql); // duplicate-column is safe on upgraded DBs

  const QString now = QDateTime::currentDateTime().toString(Qt::ISODate);
  q.prepare(R"(
    UPDATE sessions SET
      status = CASE
        WHEN UPPER(status) = 'COMPLETED' AND EXISTS(
          SELECT 1 FROM photos p WHERE p.session_id = sessions.session_id
        ) THEN 'COMPLETED'
        ELSE 'LEGACY_UNKNOWN'
      END,
      photo_count = (SELECT COUNT(*) FROM photos p WHERE p.session_id = sessions.session_id),
      status_updated_at = COALESCE(ended_at, started_at, :now),
      sync_pending = 1
    WHERE status_updated_at IS NULL
  )");
  q.bindValue(":now", now);
  if (!q.exec()) {
    qCritical() << "[DB] v23 backfill failed:" << q.lastError().text();
    return false;
  }
  return setSchemaVersion(23);
}

bool DatabaseManager::applyMigration_v24() {
  // Voucher: nguồn tạo (created_via) + cờ đã đẩy lên cloud (synced).
  // Mã cũ chưa có trên cloud → synced=0 để lần tạo/đồng bộ kế tiếp đẩy lên.
  QSqlQuery q(m_database);
  const QStringList alters = {
    "ALTER TABLE vouchers ADD COLUMN created_via TEXT DEFAULT 'desktop'",
    "ALTER TABLE vouchers ADD COLUMN synced INTEGER DEFAULT 0"
  };
  for (const QString &sql : alters) q.exec(sql); // duplicate-column is safe on upgraded DBs
  return setSchemaVersion(24);
}

bool DatabaseManager::applyMigration_v25() {
  // Voucher: cột ghi chú (lý do phát hành), đồng nhất với web + cloud.
  QSqlQuery q(m_database);
  if (!q.exec("ALTER TABLE vouchers ADD COLUMN note TEXT DEFAULT ''")) {
    const QString err = q.lastError().text();
    if (!err.contains("duplicate column", Qt::CaseInsensitive))
      qWarning() << "[DB] v25 add voucher note column:" << err;
  }
  return setSchemaVersion(25);
}

bool DatabaseManager::applyMigration_v26() {
  // Mã gói chụp trả trước (type='package_code'): thời gian gói (phút), số bản in,
  // tên gói. Mã do web/portal tạo; các cột này chỉ có giá trị cho row đã sync về.
  QSqlQuery q(m_database);
  const QStringList alters = {
    "ALTER TABLE vouchers ADD COLUMN package_minutes INTEGER DEFAULT 0",
    "ALTER TABLE vouchers ADD COLUMN package_prints INTEGER DEFAULT 1",
    "ALTER TABLE vouchers ADD COLUMN package_name TEXT DEFAULT ''"
  };
  for (const QString &sql : alters) {
    if (!q.exec(sql)) {
      const QString err = q.lastError().text();
      if (!err.contains("duplicate column", Qt::CaseInsensitive))
        qWarning() << "[DB] v26 add package column note:" << sql << "->" << err;
    }
  }
  qDebug() << "Migration v26 (voucher package columns) applied";
  return setSchemaVersion(26);
}

bool DatabaseManager::applyMigration_v27() {
  // Local package codes can be reusable. Existing voucher/cash rows remain 1-use.
  QSqlQuery q(m_database);
  const QStringList alters = {
    "ALTER TABLE vouchers ADD COLUMN usage_limit INTEGER DEFAULT 1",
    "ALTER TABLE vouchers ADD COLUMN use_count INTEGER DEFAULT 0"
  };
  for (const QString &sql : alters) {
    if (!q.exec(sql)) {
      const QString err = q.lastError().text();
      if (!err.contains("duplicate column", Qt::CaseInsensitive))
        qWarning() << "[DB] v27 add usage column:" << sql << "->" << err;
    }
  }
  if (!q.exec("UPDATE vouchers SET use_count = 1 WHERE used = 1 AND COALESCE(use_count,0) = 0")) {
    qWarning() << "[DB] v27 backfill use_count:" << q.lastError().text();
  }
  qDebug() << "Migration v27 (voucher usage counters) applied";
  return setSchemaVersion(27);
}

bool DatabaseManager::applyMigration_v28() {
  QSqlQuery q(m_database);
  if (!q.exec(R"(CREATE TABLE IF NOT EXISTS upload_assets (
      asset_id        TEXT PRIMARY KEY,
      session_id      TEXT NOT NULL,
      kind            TEXT NOT NULL,
      local_path      TEXT NOT NULL,
      file_name       TEXT NOT NULL,
      content_type    TEXT NOT NULL,
      size_bytes      INTEGER DEFAULT 0,
      checksum_sha256 TEXT DEFAULT '',
      photo_index     INTEGER DEFAULT 0,
      object_key      TEXT DEFAULT '',
      upload_url      TEXT DEFAULT '',
      expires_at      TEXT DEFAULT '',
      status          TEXT NOT NULL DEFAULT 'pending',
      attempts        INTEGER NOT NULL DEFAULT 0,
      next_retry_at   TEXT DEFAULT '',
      last_error      TEXT DEFAULT '',
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL,
      confirmed_at    TEXT DEFAULT ''
  ))")) {
    qCritical() << "[DB] v28 create upload_assets failed:" << q.lastError().text();
    return false;
  }
  q.exec("CREATE UNIQUE INDEX IF NOT EXISTS idx_upload_assets_object_key ON upload_assets(object_key) WHERE object_key <> ''");
  q.exec("CREATE INDEX IF NOT EXISTS idx_upload_assets_status_retry ON upload_assets(status, next_retry_at)");
  q.exec("CREATE INDEX IF NOT EXISTS idx_upload_assets_session ON upload_assets(session_id, photo_index)");
  q.exec("UPDATE upload_assets SET status = 'uploaded', updated_at = datetime('now') "
         "WHERE status IN ('uploading','preparing') AND COALESCE(object_key,'') <> ''");
  q.exec("UPDATE upload_assets SET status = 'pending', updated_at = datetime('now') "
         "WHERE status IN ('uploading','preparing') AND COALESCE(object_key,'') = ''");
  qDebug() << "Migration v28 (durable upload assets) applied";
  return setSchemaVersion(28);
}

// ============= Employee Account Operations =============

int DatabaseManager::createEmployee(const QString &fullName, const QString &prefix,
                                    const QString &passHash) {
  QSqlQuery query(m_database);
  query.prepare(R"(
      INSERT INTO employees (full_name, prefix, pass_hash, created_at, active)
      VALUES (:name, :prefix, :hash, :at, 1)
  )");
  query.bindValue(":name",   fullName);
  query.bindValue(":prefix", prefix.toUpper());
  query.bindValue(":hash",   passHash);
  query.bindValue(":at",     QDateTime::currentDateTime().toString(Qt::ISODate));
  if (!query.exec()) {
    qWarning() << "createEmployee failed:" << query.lastError().text();
    return -1;
  }
  return query.lastInsertId().toInt();
}

bool DatabaseManager::updateEmployeePassword(int id, const QString &passHash) {
  QSqlQuery query(m_database);
  query.prepare("UPDATE employees SET pass_hash = :hash WHERE id = :id");
  query.bindValue(":hash", passHash);
  query.bindValue(":id",   id);
  if (!query.exec()) {
    qWarning() << "updateEmployeePassword failed:" << query.lastError().text();
    return false;
  }
  return query.numRowsAffected() > 0;
}

bool DatabaseManager::updateEmployeeName(int id, const QString &fullName) {
  QSqlQuery query(m_database);
  query.prepare("UPDATE employees SET full_name = :name WHERE id = :id");
  query.bindValue(":name", fullName);
  query.bindValue(":id",   id);
  if (!query.exec()) {
    qWarning() << "updateEmployeeName failed:" << query.lastError().text();
    return false;
  }
  return query.numRowsAffected() > 0;
}

bool DatabaseManager::deleteEmployee(int id) {
  QSqlQuery query(m_database);
  query.prepare("DELETE FROM employees WHERE id = :id");
  query.bindValue(":id", id);
  if (!query.exec()) {
    qWarning() << "deleteEmployee failed:" << query.lastError().text();
    return false;
  }
  return query.numRowsAffected() > 0;
}

QVariantList DatabaseManager::getEmployees() {
  QSqlQuery query(m_database);
  QVariantList list;
  if (query.exec("SELECT id, full_name, prefix, created_at, active FROM employees ORDER BY id ASC")) {
    while (query.next()) {
      QVariantMap row;
      row["id"]         = query.value("id").toInt();
      row["full_name"]  = query.value("full_name").toString();
      row["prefix"]     = query.value("prefix").toString();
      row["created_at"] = query.value("created_at").toString();
      row["active"]     = query.value("active").toInt() == 1;
      list.append(row);
    }
  } else {
    qWarning() << "getEmployees failed:" << query.lastError().text();
  }
  return list;
}

QVariantMap DatabaseManager::getEmployee(int id) {
  QSqlQuery query(m_database);
  query.prepare("SELECT id, full_name, prefix, pass_hash, created_at, active FROM employees WHERE id = :id");
  query.bindValue(":id", id);
  QVariantMap result;
  if (query.exec() && query.next()) {
    result["id"]         = query.value("id").toInt();
    result["full_name"]  = query.value("full_name").toString();
    result["prefix"]     = query.value("prefix").toString();
    result["pass_hash"]  = query.value("pass_hash").toString();
    result["created_at"] = query.value("created_at").toString();
    result["active"]     = query.value("active").toInt() == 1;
    result["found"]      = true;
  } else {
    result["found"] = false;
  }
  return result;
}

QVariantMap DatabaseManager::getEmployeeByName(const QString &fullName) {
  QSqlQuery query(m_database);
  query.prepare("SELECT id, full_name, prefix, pass_hash, created_at, active FROM employees WHERE full_name = :name LIMIT 1");
  query.bindValue(":name", fullName);
  QVariantMap result;
  if (query.exec() && query.next()) {
    result["id"]         = query.value("id").toInt();
    result["full_name"]  = query.value("full_name").toString();
    result["prefix"]     = query.value("prefix").toString();
    result["pass_hash"]  = query.value("pass_hash").toString();
    result["created_at"] = query.value("created_at").toString();
    result["active"]     = query.value("active").toInt() == 1;
    result["found"]      = true;
  } else {
    result["found"] = false;
  }
  return result;
}

bool DatabaseManager::employeePrefixExists(const QString &prefix) {
  QSqlQuery query(m_database);
  query.prepare("SELECT COUNT(*) FROM employees WHERE prefix = :prefix");
  query.bindValue(":prefix", prefix.toUpper());
  if (query.exec() && query.next())
    return query.value(0).toInt() > 0;
  return false;
}

// ============= Revenue Record Operations =============

bool DatabaseManager::logRevenueRecord(const RevenueRecord &rec) {
  QSqlQuery query(m_database);
  query.prepare(R"(
    INSERT INTO revenue_records
      (event_id, event_name, session_id, recorded_at, print_count,
       amount_required, cash_received, transfer_amount, change_amount, payment_method,
       employee_id, shift, source, received_amount, voucher_amount, note)
    VALUES
      (:event_id, :event_name, :session_id, :recorded_at, :print_count,
       :amount_required, :cash_received, :transfer_amount, :change_amount, :payment_method,
       :employee_id, :shift, :source, :received_amount, :voucher_amount, :note)
  )");
  query.bindValue(":event_id",        rec.eventId);
  query.bindValue(":event_name",      rec.eventName);
  query.bindValue(":session_id",      rec.sessionId);
  query.bindValue(":recorded_at",     rec.recordedAt.isEmpty()
                                      ? QDateTime::currentDateTime().toString(Qt::ISODate)
                                      : rec.recordedAt);
  query.bindValue(":print_count",     rec.printCount);
  query.bindValue(":amount_required", rec.amountRequired);
  query.bindValue(":cash_received",   rec.cashReceived);
  query.bindValue(":transfer_amount", rec.transferAmount);
  query.bindValue(":change_amount",   rec.changeAmount);
  query.bindValue(":payment_method",  rec.paymentMethod);
  query.bindValue(":employee_id",     rec.employeeId);
  query.bindValue(":shift",           rec.shift);
  query.bindValue(":source",          rec.source.isEmpty() ? "session" : rec.source);
  query.bindValue(":received_amount", rec.receivedAmount);
  query.bindValue(":voucher_amount",  rec.voucherAmount);
  query.bindValue(":note",            rec.note);
  if (!query.exec()) {
    qWarning() << "logRevenueRecord failed:" << query.lastError().text();
    return false;
  }
  return true;
}

QVariantList DatabaseManager::getRevenueRecords(const QString &sortBy, int employeeId) {
  QSqlQuery query(m_database);
  QString orderClause;
  if (sortBy == "cash")
    orderClause = " ORDER BY cash_received DESC, recorded_at DESC";
  else if (sortBy == "transfer")
    orderClause = " ORDER BY transfer_amount DESC, recorded_at DESC";
  else
    orderClause = " ORDER BY recorded_at DESC";

  QString sql = R"(
    SELECT r.id, r.event_id, r.event_name, r.session_id, r.recorded_at,
           r.print_count, r.amount_required, r.cash_received, r.transfer_amount,
           r.change_amount, r.payment_method, r.employee_id, r.shift, r.source,
           r.received_amount, r.voucher_amount, r.note,
           s.status AS capture_status, s.failure_code, s.failure_message,
           s.had_camera_error, s.photo_count AS photos_captured, s.expected_photos
    FROM revenue_records r
    LEFT JOIN sessions s ON s.session_id = r.session_id AND s.event_id = r.event_id
  )";
  if (employeeId >= 0) sql += " WHERE r.employee_id = :emp";
  sql += orderClause;

  query.prepare(sql);
  if (employeeId >= 0) query.bindValue(":emp", employeeId);

  QVariantList list;
  if (query.exec()) {
    while (query.next()) {
      QVariantMap row;
      row["id"]              = query.value("id").toInt();
      row["event_id"]        = query.value("event_id").toInt();
      row["event_name"]      = query.value("event_name").toString();
      row["session_id"]      = query.value("session_id").toString();
      row["recorded_at"]     = query.value("recorded_at").toString();
      row["print_count"]     = query.value("print_count").toInt();
      row["amount_required"] = query.value("amount_required").toInt();
      row["cash_received"]   = query.value("cash_received").toInt();
      row["transfer_amount"] = query.value("transfer_amount").toInt();
      row["change_amount"]   = query.value("change_amount").toInt();
      row["payment_method"]  = query.value("payment_method").toString();
      row["employee_id"]     = query.value("employee_id").toInt();
      row["shift"]           = query.value("shift").toString();
      row["source"]          = query.value("source").toString();
      row["received_amount"] = query.value("received_amount").toInt();
      row["voucher_amount"]  = query.value("voucher_amount").toInt();
      row["note"]            = query.value("note").toString();
      // Thông tin lượt chụp gắn với giao dịch (nếu có phiên tương ứng) — để báo
      // cáo doanh thu hiển thị phiên "đã thu tiền nhưng chụp lỗi".
      row["capture_status"]  = query.value("capture_status").toString();
      row["failure_code"]    = query.value("failure_code").toString();
      row["failure_message"] = query.value("failure_message").toString();
      row["had_camera_error"] = query.value("had_camera_error").toInt();
      row["photos_captured"] = query.value("photos_captured").toInt();
      row["expected_photos"] = query.value("expected_photos").toInt();
      list.append(row);
    }
  } else {
    qWarning() << "getRevenueRecords failed:" << query.lastError().text();
  }
  return list;
}

bool DatabaseManager::clearRevenueRecords() {
  QSqlQuery query(m_database);
  if (!query.exec("DELETE FROM revenue_records")) {
    qWarning() << "clearRevenueRecords failed:" << query.lastError().text();
    return false;
  }
  return true;
}

QVariantMap DatabaseManager::getRevenueSummary(int employeeId) {
  QSqlQuery query(m_database);
  QVariantMap summary;
  summary["total_revenue"]  = 0;
  summary["total_cash"]     = 0;
  summary["total_transfer"] = 0;
  summary["total_change"]   = 0;
  summary["total_received"] = 0;
  summary["total_voucher"]  = 0;
  summary["record_count"]   = 0;

  QString sql = R"(
      SELECT COUNT(*) as cnt,
             SUM(amount_required) as total_rev,
             SUM(cash_received)   as total_cash,
             SUM(transfer_amount) as total_transfer,
             SUM(change_amount)   as total_change,
             SUM(received_amount) as total_received,
             SUM(voucher_amount)  as total_voucher
      FROM revenue_records
  )";
  if (employeeId >= 0) sql += " WHERE employee_id = :emp";
  query.prepare(sql);
  if (employeeId >= 0) query.bindValue(":emp", employeeId);

  if (query.exec() && query.next()) {
    summary["record_count"]   = query.value("cnt").toInt();
    summary["total_revenue"]  = query.value("total_rev").toInt();
    summary["total_cash"]     = query.value("total_cash").toInt();
    summary["total_transfer"] = query.value("total_transfer").toInt();
    summary["total_change"]   = query.value("total_change").toInt();
    summary["total_received"] = query.value("total_received").toInt();
    summary["total_voucher"]  = query.value("total_voucher").toInt();
  }
  return summary;
}

bool DatabaseManager::exportRevenueToCSV(const QString &filePath) {
  QSqlQuery query(m_database);
  if (!query.exec(R"(
    SELECT r.event_name, r.session_id, r.recorded_at, r.print_count,
           r.amount_required, r.cash_received, r.transfer_amount, r.change_amount,
           r.payment_method, COALESCE(e.full_name, '') AS emp_name,
           r.shift, r.source, r.received_amount, r.voucher_amount, r.note,
           s.status AS capture_status, s.failure_code, s.failure_message
    FROM revenue_records r
    LEFT JOIN employees e ON e.id = r.employee_id
    LEFT JOIN sessions s ON s.session_id = r.session_id AND s.event_id = r.event_id
    ORDER BY r.recorded_at DESC
  )")) {
    qWarning() << "exportRevenueToCSV query failed:" << query.lastError().text();
    return false;
  }

  QFile file(filePath);
  if (!file.open(QIODevice::WriteOnly | QIODevice::Text)) {
    qWarning() << "exportRevenueToCSV: cannot open file:" << filePath;
    return false;
  }

  QTextStream out(&file);
  out.setEncoding(QStringConverter::Utf8);
  // BOM for Excel UTF-8 recognition
  out << "\xEF\xBB\xBF";
  out << "Sự Kiện,Session,Thời Gian,Nhân Viên,Ca,Loại,Số Ảnh In,Tiền Cần TT,Tiền Mặt,Chuyển Khoản,Voucher,Thực Nhận,Tiền Thừa,Phương Thức,Ghi Chú,Trạng Thái Chụp,Mã Lỗi,Lỗi\n";

  while (query.next()) {
    auto escape = [](QString s) -> QString {
      s.replace("\"", "\"\"");
      return "\"" + s + "\"";
    };
    const QString method = query.value("payment_method").toString();
    const bool isReprint = query.value("source").toString() == "reprint";
    const QString src = isReprint ? "In lại" : "Phiên mới";
    const int voucherAmt = query.value("voucher_amount").toInt();
    // Phiên in lại không gắn trạng thái lỗi của lượt chụp gốc.
    const QString captureStatus = isReprint ? QString() : query.value("capture_status").toString();
    const QString failureCode   = isReprint ? QString() : query.value("failure_code").toString();
    const QString failureMsg    = isReprint ? QString() : query.value("failure_message").toString();
    out << escape(query.value("event_name").toString()) << ","
        << escape(query.value("session_id").toString()) << ","
        << escape(query.value("recorded_at").toString()) << ","
        << escape(query.value("emp_name").toString()) << ","
        << escape(query.value("shift").toString()) << ","
        << escape(src) << ","
        << query.value("print_count").toInt() << ","
        << query.value("amount_required").toInt() << ","
        << query.value("cash_received").toInt() << ","
        << query.value("transfer_amount").toInt() << ","
        << voucherAmt << ","
        << query.value("received_amount").toInt() << ","
        << query.value("change_amount").toInt() << ","
        << escape(method) << ","
        << escape(query.value("note").toString()) << ","
        << escape(captureStatus) << ","
        << escape(failureCode) << ","
        << escape(failureMsg) << "\n";
  }

  file.close();
  return true;
}
