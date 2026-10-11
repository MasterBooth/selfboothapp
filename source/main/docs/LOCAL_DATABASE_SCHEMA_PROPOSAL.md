# LOCAL DATABASE SCHEMA PROPOSAL

Đối tượng: SQLite local `{app}\data\photobooth.db`
(đường dẫn từ [AppPaths::getDatabasePath()](src/backend/AppPaths.h#L40)).

Nguyên tắc: **không tạo schema mới khi chưa đối chiếu schema D1 production**.
Tài liệu này đối chiếu song song 3 cột: schema local hiện có → schema D1 → đề xuất.

Ngày lập: 2026-08-03.

---

## 1. SCHEMA LOCAL HIỆN CÓ (đã xác minh trong mã nguồn)

Nguồn: [DatabaseManager.cpp](src/backend/DatabaseManager.cpp), migration v1→v26.
Phiên bản schema hiện tại: **26** (`schema_version.version`).

| # | Bảng | Tạo ở | Trạng thái sử dụng |
| --- | --- | --- | --- |
| 1 | `schema_version` | createTables():47 | ✅ dùng |
| 2 | `events` | createTables():61 | ✅ dùng |
| 3 | `photos` | createTables():107 | ✅ dùng |
| 4 | `printer_settings` | createTables():124 | ✅ dùng |
| 5 | `machines` | v1:817 | ✅ dùng (chỉ ghi trạng thái, không dùng để chặn) |
| 6 | `sessions` | v1:836 + v23 | ✅ dùng |
| 7 | `upload_queue` | v2:862 | ❌ **CODE CHẾT** — `addToUploadQueue()`/`getPendingUploads()`/`updateUploadStatus()` khai báo ở [DatabaseManager.h:149-152](src/backend/DatabaseManager.h#L149-L152) nhưng **không có caller nào** trong toàn repo |
| 8 | `app_settings` | v4:912 | ✅ dùng (có cache RAM) |
| 9 | `users` | v13:1089 | ✅ dùng (`UserAuthManager`) |
| 10 | `vouchers` | v14:1109 + v17,18,24,25,26 | ✅ dùng |
| 11 | `revenue_records` | v15:2129 + v17,19,20,21 | ✅ dùng |
| 12 | `employees` | v16:2153 | ✅ dùng |
| 13 | `event_settings` | v22:2255 | ✅ dùng |

### 1.1 Chi tiết cột

**`events`** (createTables + 14 ALTER)

| Cột | Kiểu | Default |
| --- | --- | --- |
| `id` | INTEGER | PK AUTOINCREMENT |
| `name` | TEXT | NOT NULL |
| `location`, `event_date` | TEXT | |
| `created_at`, `updated_at` | TEXT | NOT NULL |
| `capture_mode` | TEXT | `'photo'` |
| `digital_props`, `beauty_filter`, `post_processing` | INTEGER | 0 |
| `watermark` | INTEGER | 1 |
| `thumbnail_path`, `raw_path`, `final_path`, `start_message`, `selected_layout` | TEXT | |
| `countdown_duration` | INTEGER | 3 |
| `shot_interval` | INTEGER | 2000 |
| `auto_cut`, `mirror_mode` | INTEGER | 0 |
| `landing_background`, `mode_selection_background` | TEXT | (v3) |
| `live_view_overlay` | INTEGER | 0 (v5) |
| `first_shot_countdown`, `next_shot_countdown` | INTEGER | 3 (v6) |
| `shooting_mode`, `manual_photo_count` | INTEGER | 0 (v7) |
| `live_view_background` | INTEGER | 0 (v8) |
| `pose_guide` | INTEGER | 0 (v10) |
| `print_count` | INTEGER | 0 (v11) |
| `print_count_cut`, `print_count_nocut` | INTEGER | 0 (v12) |

**`photos`**: `id` PK, `event_id` NOT NULL (FK→events ON DELETE CASCADE),
`file_path` NOT NULL, `type` DEFAULT `'original'`, `created_at` NOT NULL,
`session_id` TEXT (v2/v9), `upload_status` TEXT DEFAULT `'pending'` (v2).

**`sessions`** (v1 + v23): `id` PK, `session_id` **UNIQUE** NOT NULL,
`event_id` NOT NULL (FK), `hwid` NOT NULL, `started_at` NOT NULL, `ended_at`,
`photo_count` DEFAULT 0, `status` DEFAULT `'active'`,
+ v23: `expected_photos`, `capture_started_at`, `status_updated_at`,
`failure_code`, `failure_message`, `camera_error_count`, `had_camera_error`,
`status_version` DEFAULT 1, **`sync_pending` DEFAULT 1**, `resolution_state`
DEFAULT `'NOT_REQUIRED'`, `resolution_type`, `refund_amount`, `resolution_note`,
`resolved_at`, `resolved_by`.

> ⚠️ **`sync_pending` là cột chết** — được tạo và được set = 1 ở nhiều nơi
> ([DatabaseManager.cpp:1557,1613,1637](src/backend/DatabaseManager.cpp#L1557))
> nhưng **không có code nào đọc để gửi lại**.

**`revenue_records`** (v15 + v17,19,20,21): `id` PK AUTOINCREMENT, `event_id`
NOT NULL, `event_name` NOT NULL, `session_id`, `recorded_at` NOT NULL,
`print_count`, `amount_required`, `cash_received`, `transfer_amount`,
`change_amount`, `payment_method` NOT NULL, `employee_id` DEFAULT 0,
`shift` DEFAULT `''`, `source` DEFAULT `'session'`, `received_amount` DEFAULT 0,
`note` DEFAULT `''`, `voucher_amount` DEFAULT 0.

**`vouchers`** (v14 + v17,18,24,25,26): `code` **PK**, `type` NOT NULL,
`value` NOT NULL, `used` DEFAULT 0, `used_at`, `session_id`, `created_at` NOT NULL,
`employee_id` DEFAULT 0, `valid_from`/`valid_until` DEFAULT `''`,
`used_by_emp_id` DEFAULT 0, `paid_amount` DEFAULT 0, `shift` DEFAULT `''`,
`created_via` DEFAULT `'desktop'`, **`synced` DEFAULT 0**, `note` DEFAULT `''`,
`package_minutes` DEFAULT 0, `package_prints` DEFAULT 1, `package_name` DEFAULT `''`.

**`employees`**: `id` PK, `full_name` NOT NULL, `prefix` **UNIQUE** NOT NULL,
`pass_hash` NOT NULL, `created_at` NOT NULL, `active` DEFAULT 1.

**`users`**: `id` PK, `full_name` NOT NULL, `phone` **UNIQUE** NOT NULL,
`password_hash` NOT NULL, `created_at` NOT NULL, `last_login`.

**`machines`**: `id` PK, `hwid` **UNIQUE** NOT NULL, `first_seen` NOT NULL,
`last_validated`, `auth_status` DEFAULT `'pending'`, `device_name`, `created_at` NOT NULL.

**`event_settings`**: PK `(event_id, key)`, `value`, `updated_at` NOT NULL.

**`app_settings`**: `key` PK, `value`, `updated_at` NOT NULL.

**`printer_settings`**: `id` PK, `event_id` DEFAULT -1 **UNIQUE**, `printer_name`
DEFAULT `'DS-RX1'`, `print_copies` DEFAULT 1, `print_mode` DEFAULT `'Color'`,
`resolution` DEFAULT `'300dpi'`, `cut_mode` DEFAULT 1.

**`upload_queue`** (không dùng): `id` PK, `photo_id` NOT NULL (FK), `session_id`
NOT NULL, `s3_path` NOT NULL, `local_path` NOT NULL, `upload_status` DEFAULT
`'pending'`, `retry_count` DEFAULT 0, `last_attempt`, `error_message`, `uploaded_at`.

### 1.2 Dữ liệu KHÔNG nằm trong SQLite

| Dữ liệu | Nơi lưu thực tế |
| --- | --- |
| Ảnh gốc | `Pictures\Photobooth\Events\<event>\Originals\` |
| Ảnh ghép | `…\Final\` |
| Layout/frame | `…\Layouts\` + `{app}\` |
| Filter | `{app}\filters\` ([FilterManager](src/backend/FilterManager.cpp)) |
| Sticker | `{app}\stickers\` ([StickerManager](src/backend/StickerManager.cpp)) |
| Ảnh chờ upload | `{rawPath}\pending\<sessionId>\` hoặc `{app}\pending_uploads\<hwid>\<eventId>\<sessionId>\` |
| Log | `%LOCALAPPDATA%\…\logs\` ([Logger](src/backend/Logger.cpp)) |
| Google session | `QSettings("BoothOS","GoogleAuth")` |
| studio_id | `QSettings("BoothOS","Machine")` |
| Cấu hình cloud | `{app}\key.json` |

---

## 2. ĐỐI CHIẾU: bảng đề xuất trong yêu cầu vs. thực tế

| Bảng yêu cầu | Đã có? | Bảng local tương ứng | Kết luận |
| --- | --- | --- | --- |
| `app_settings` | ✅ | `app_settings` | **KEEP** |
| `camera_settings` | ⚠️ | key trong `app_settings` (`live_view_max_width`, `live_view_target_fps`, `fuji_live_view_size`, `fuji_live_view_quality`, `mirror_mode`…) | **KEEP as-is** — tách bảng riêng không đem lại lợi ích, chỉ tăng rủi ro migration |
| `printer_settings` | ✅ | `printer_settings` | **KEEP** |
| `frames` | ❌ | filesystem `Layouts\` + `events.selected_layout` | **KHÔNG TẠO** — file lớn, filesystem là đúng chỗ. Có thể thêm bảng index sau nếu cần tìm kiếm |
| `filters` | ❌ | filesystem `{app}\filters\` | **KHÔNG TẠO** — cùng lý do |
| `employees` | ✅ | `employees` | **KEEP** |
| `work_shifts` | ❌ | suy ra theo giờ (`EventManager::resolveShift`) + `revenue_records.shift` | **TẠO MỚI** (ưu tiên thấp) |
| `shooting_sessions` | ✅ | `sessions` | **KEEP** (đổi tên = rủi ro không cần thiết) |
| `orders` | ❌ | gộp trong `revenue_records` | **KHÔNG TẠO** — mô hình 1 phiên = 1 giao dịch, tách ra sẽ phải viết lại toàn bộ luồng thanh toán |
| `payments` | ⚠️ | `revenue_records` | **KEEP as-is** |
| `session_images` | ✅ | `photos` (có `session_id`) | **KEEP** |
| `print_jobs` | ❌ | chỉ có bộ đếm `events.print_count*` | **TẠO MỚI** ⭐ |
| `upload_jobs` | ⚠️ | `upload_queue` (chết) + thư mục pending | **TÁI SỬ DỤNG** `upload_queue` hoặc thay bằng `sync_queue` |
| `sync_queue` | ❌ | không có | **TẠO MỚI** ⭐⭐⭐ |
| `sync_state` | ❌ | không có | **TẠO MỚI** ⭐⭐⭐ |
| `error_logs` | ❌ | chỉ file log text | **TẠO MỚI** ⭐⭐ |

---

## 3. ĐỀ XUẤT MIGRATION v27 — hạ tầng đồng bộ (BẮT BUỘC cho Phase 6)

> Nguyên tắc: **chỉ thêm bảng mới và cột mới. Không sửa, không xoá, không đổi tên
> bất kỳ bảng/cột nào đang có.** Rollback = bỏ qua bảng mới, dữ liệu cũ nguyên vẹn.

### 3.1 `sync_queue` — hàng đợi sự kiện chờ đẩy lên cloud

```sql
CREATE TABLE IF NOT EXISTS sync_queue (
    -- Định danh sự kiện: UUIDv4 sinh TẠI LOCAL. Đây là idempotency key gửi lên cloud.
    event_id        TEXT PRIMARY KEY,

    -- Loại thực thể: 'session' | 'event' | 'revenue' | 'voucher' | 'package_checkin'
    entity_type     TEXT NOT NULL,
    -- Khoá nghiệp vụ của thực thể (session_id, revenue uuid, voucher code, ...)
    entity_id       TEXT NOT NULL,
    -- 'CREATE' | 'UPDATE' | 'DELETE'
    operation       TEXT NOT NULL,

    -- Payload JSON đúng hình dạng body mà Worker mong đợi.
    payload         TEXT NOT NULL,
    -- SHA-256 của payload — dùng để khử trùng khi cùng entity được enqueue nhiều lần.
    payload_hash    TEXT NOT NULL,

    created_at      TEXT NOT NULL,          -- ISO-8601 local
    attempt_count   INTEGER NOT NULL DEFAULT 0,
    next_retry_at   TEXT,                   -- ISO-8601; NULL = gửi ngay
    -- PENDING | PROCESSING | RETRY | SYNCED | FAILED
    status          TEXT NOT NULL DEFAULT 'PENDING',
    last_error      TEXT DEFAULT '',
    synced_at       TEXT,

    -- Thứ tự gửi trong cùng entity (tăng đơn điệu). Bản cũ đến muộn bị bỏ qua.
    entity_version  INTEGER NOT NULL DEFAULT 1
);

-- Truy vấn nóng: "lấy N mục đến hạn gửi".
CREATE INDEX IF NOT EXISTS idx_sync_queue_due
    ON sync_queue (status, next_retry_at);
-- Khử trùng / tra cứu theo thực thể.
CREATE INDEX IF NOT EXISTS idx_sync_queue_entity
    ON sync_queue (entity_type, entity_id, entity_version);
-- Dọn dẹp bản ghi đã SYNCED cũ.
CREATE INDEX IF NOT EXISTS idx_sync_queue_synced
    ON sync_queue (status, synced_at);
```

**Trạng thái hợp lệ và chuyển tiếp:**

```text
PENDING ──(worker nhận)──► PROCESSING ──(2xx)──────► SYNCED
                                │
                                ├─(lỗi mạng/5xx)──► RETRY ──(đến hạn)──► PENDING
                                │
                                └─(4xx nghiệp vụ, hoặc attempt_count > 20)──► FAILED
```

* `PROCESSING` phải có timeout: nếu app crash giữa chừng, khi khởi động lại
  `UPDATE sync_queue SET status='PENDING' WHERE status='PROCESSING'`.
* `FAILED` **không tự xoá** — giữ để kỹ thuật viên xem, có nút "thử lại" thủ công.

### 3.2 `sync_state` — con trỏ đồng bộ theo từng loại dữ liệu

```sql
CREATE TABLE IF NOT EXISTS sync_state (
    scope            TEXT PRIMARY KEY,   -- 'session' | 'revenue' | 'voucher_pull' | 'preset_pull' | ...
    direction        TEXT NOT NULL,      -- 'PUSH' | 'PULL'
    last_success_at  TEXT,               -- lần đồng bộ thành công gần nhất
    last_attempt_at  TEXT,
    last_error       TEXT DEFAULT '',
    -- Con trỏ để kéo dữ liệu cloud → local (cursor/etag/timestamp server)
    cursor           TEXT DEFAULT '',
    -- Số mục còn chờ (cache, để UI không phải COUNT(*) liên tục)
    pending_count    INTEGER NOT NULL DEFAULT 0,
    updated_at       TEXT NOT NULL
);
```

### 3.3 `error_logs` — nhật ký lỗi có cấu trúc

```sql
CREATE TABLE IF NOT EXISTS error_logs (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at  TEXT NOT NULL,
    -- INFO | WARN | ERROR | CRITICAL
    severity    TEXT NOT NULL,
    -- 'camera' | 'printer' | 'sync' | 'upload' | 'db' | 'payment' | 'app'
    component   TEXT NOT NULL,
    code        TEXT DEFAULT '',        -- mã lỗi ổn định để thống kê
    message     TEXT NOT NULL,
    -- JSON: {session_id, event_id, hwid, http_status, endpoint, ...}
    context     TEXT DEFAULT '',
    session_id  TEXT DEFAULT '',
    event_id    INTEGER DEFAULT 0,
    -- Đã đẩy lên cloud chưa (nếu bật báo lỗi từ xa)
    synced      INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_error_logs_time     ON error_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_sev      ON error_logs (severity, created_at);
CREATE INDEX IF NOT EXISTS idx_error_logs_session  ON error_logs (session_id);
```

Chính sách giữ: xoá bản ghi `severity IN ('INFO','WARN')` cũ hơn 30 ngày;
`ERROR`/`CRITICAL` giữ 180 ngày. Chạy khi khởi động, giới hạn 1 lần/ngày.

### 3.4 `print_jobs` — theo dõi từng lệnh in

```sql
CREATE TABLE IF NOT EXISTS print_jobs (
    uuid            TEXT PRIMARY KEY,       -- UUIDv4 sinh tại local
    session_id      TEXT NOT NULL,
    event_id        INTEGER NOT NULL,
    file_path       TEXT NOT NULL,          -- ảnh gửi đi in
    printer_name    TEXT DEFAULT '',
    copies          INTEGER NOT NULL DEFAULT 1,
    cut_mode        INTEGER NOT NULL DEFAULT 1,   -- 1 = cắt, 0 = không cắt
    -- QUEUED | PRINTING | DONE | FAILED | CANCELLED
    status          TEXT NOT NULL DEFAULT 'QUEUED',
    submitted_at    TEXT NOT NULL,
    finished_at     TEXT,
    error_code      TEXT DEFAULT '',        -- mã DNS Status API (xem DNPStatusCodes.h)
    error_message   TEXT DEFAULT '',
    retry_count     INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_print_jobs_session ON print_jobs (session_id);
CREATE INDEX IF NOT EXISTS idx_print_jobs_status  ON print_jobs (status, submitted_at);
```

Lợi ích: khi mất điện giữa lúc in, khởi động lại biết lệnh nào `PRINTING` dở dang
để hỏi nhân viên "đã ra ảnh chưa?" thay vì im lặng mất.

### 3.5 Cột `uuid` cho các bảng tạo dữ liệu tại máy

```sql
-- Doanh thu: khoá đồng bộ ổn định, độc lập với AUTOINCREMENT.
ALTER TABLE revenue_records ADD COLUMN uuid TEXT DEFAULT '';
-- Ảnh: để đối chiếu với object key trên S3.
ALTER TABLE photos          ADD COLUMN uuid TEXT DEFAULT '';
```

Backfill trong cùng migration:

```sql
-- Sinh uuid xác định cho dữ liệu cũ (không random, để chạy lại vẫn ra cùng kết quả).
-- Thực hiện bằng C++ (SQLite không có hàm hash sẵn):
--   uuid = lower(hex(sha256("rev|" || id || "|" || recorded_at)))  → 32 ký tự đầu
UPDATE revenue_records SET uuid = :computed WHERE id = :id AND (uuid IS NULL OR uuid = '');
```

Không đặt UNIQUE ngay ở migration đầu (dữ liệu cũ có thể trùng). Sau khi backfill
xong và xác nhận không trùng, migration v28 mới thêm:

```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_revenue_uuid ON revenue_records (uuid) WHERE uuid <> '';
```

### 3.6 `work_shifts` (ưu tiên thấp — Phase 6+)

```sql
CREATE TABLE IF NOT EXISTS work_shifts (
    uuid         TEXT PRIMARY KEY,
    name         TEXT NOT NULL,          -- 'Ca sáng' | 'Ca chiều' | ...
    employee_id  INTEGER NOT NULL DEFAULT 0,
    opened_at    TEXT NOT NULL,
    closed_at    TEXT,
    opening_cash INTEGER NOT NULL DEFAULT 0,
    closing_cash INTEGER NOT NULL DEFAULT 0,
    note         TEXT DEFAULT ''
);
CREATE INDEX IF NOT EXISTS idx_work_shifts_open ON work_shifts (closed_at, opened_at);
```

Chỉ tạo khi có yêu cầu nghiệp vụ rõ ràng về đối soát tiền mặt đầu/cuối ca.
Hiện tại `shift` đang được suy theo giờ và lưu chuỗi trong `revenue_records.shift`
— đủ dùng cho báo cáo.

### 3.7 Cache dữ liệu cloud-authoritative (Phase 6)

```sql
-- Preset do chủ studio cấu hình trên web. Cache để dùng offline.
CREATE TABLE IF NOT EXISTS cloud_cache (
    scope       TEXT NOT NULL,     -- 'voucher_notes'|'voucher_prices'|'voucher_durations'|'package_presets'|'studio_staff'
    item_key    TEXT NOT NULL,     -- id hoặc khoá tự nhiên bên cloud
    payload     TEXT NOT NULL,     -- JSON nguyên bản
    fetched_at  TEXT NOT NULL,
    PRIMARY KEY (scope, item_key)
);
```

Thay cho việc gọi `voucherPresetsCloud()` blocking mỗi lần mở tab.

---

## 4. Migration v27 — mã C++ đề xuất (CHƯA TRIỂN KHAI, chỉ thiết kế)

Thêm vào [DatabaseManager.h](src/backend/DatabaseManager.h) sau dòng 260:

```cpp
  bool applyMigration_v27();  // Sync infrastructure: sync_queue, sync_state, error_logs,
                              // print_jobs, cloud_cache + uuid columns
```

Thêm vào `createTables()` sau khối v26:

```cpp
  if (currentVersion < 27) {
    qDebug() << "Applying migration v27: sync infrastructure";
    if (!applyMigration_v27()) return false;
  }
```

Thân hàm tuân thủ mẫu đã dùng ở v17/v19/v23 (bỏ qua lỗi "duplicate column"):

```cpp
bool DatabaseManager::applyMigration_v27() {
  QSqlQuery q(m_database);

  // Bảng mới — CREATE TABLE IF NOT EXISTS nên idempotent.
  const QStringList creates = { /* sync_queue, sync_state, error_logs, print_jobs, cloud_cache + index */ };
  for (const QString &sql : creates) {
    if (!q.exec(sql)) {
      qCritical() << "[DB] v27 create failed:" << q.lastError().text();
      return false;                    // bảng mới bắt buộc phải tạo được
    }
  }

  // Cột mới — có thể đã tồn tại nếu migration chạy dở lần trước.
  const QStringList alters = {
    "ALTER TABLE revenue_records ADD COLUMN uuid TEXT DEFAULT ''",
    "ALTER TABLE photos ADD COLUMN uuid TEXT DEFAULT ''"
  };
  for (const QString &sql : alters) {
    if (!q.exec(sql)) {
      const QString err = q.lastError().text();
      if (!err.contains("duplicate column", Qt::CaseInsensitive))
        qWarning() << "[DB] v27 column add note:" << sql << "->" << err;
    }
  }

  // Backfill uuid cho dữ liệu cũ — chạy theo lô, có thể tiếp tục nếu bị ngắt.
  backfillRevenueUuids();

  return setSchemaVersion(27);
}
```

**Bắt buộc trước khi chạy v27 (xem [SAFE_MIGRATION_PLAN.md](SAFE_MIGRATION_PLAN.md)):**
copy `photobooth.db` → `photobooth.db.bak-v26-<timestamp>`.

---

## 5. Đối chiếu local ↔ D1 (quan trọng cho thiết kế sync)

| Thực thể | Bảng local | Bảng D1 | Khoá local | Khoá D1 | Ánh xạ |
| --- | --- | --- | --- | --- | --- |
| Sự kiện | `events` | `events` | `id` INTEGER | `(hwid, event_id)` | `event_id = events.id` |
| Phiên chụp | `sessions` | `sessions` | `session_id` UNIQUE | `(hwid, event_id, session_id)` | 1-1 |
| Doanh thu | `revenue_records` | `revenue` | `id` (đề xuất `uuid`) | `revenue_id` (SHA-256) | dẫn xuất, xem dưới |
| Ảnh | `photos` | *(không có)* | `id` | — | metadata chỉ ở local; file lên S3 |
| Voucher | `vouchers` | `vouchers` | `code` | `(owner_email, code)` | `owner_email` từ `machines.owner_email` trên cloud |
| Nhân viên | `employees` | `studio_staff` | `id`/`prefix` | `(owner_email, staff_email)` | ánh xạ qua email |
| Cấu hình | `app_settings` | *(không đồng bộ)* | `key` | — | thuần local |
| Máy | `machines` | `machines` | `hwid` UNIQUE | `hwid` PK | 1-1 |

### Công thức `revenue_id` (đã dùng, giữ nguyên)

```text
revenue_id = SHA256_hex("{hwid}|{event_id}|{session_id}|{source}|{recorded_at}")
```

Tính ở cả hai phía:
* Client: [DynamoDBClient.cpp:158-165](src/backend/DynamoDBClient.cpp#L158-L165)
* Worker: [index.ts:46-50](cloudflare/worker/src/index.ts#L46-L50)

Cột `revenue_records.uuid` đề xuất **không thay thế** `revenue_id` mà bổ sung:
`uuid` là khoá nội bộ ổn định (dùng cho `sync_queue.entity_id`), `revenue_id` là
khoá cloud.

### Ánh xạ trạng thái session

| Local `sessions.status` | D1 `sessions.status` | Ghi chú |
| --- | --- | --- |
| `active` | không gửi (bỏ qua nếu `PREPARED`) | [EventManager.cpp:348](src/backend/EventManager.cpp#L348) |
| `COMPLETED` | `COMPLETED` | |
| `PARTIAL` / `CAMERA_ERROR` / `APP_INTERRUPTED` / `CANCELLED` | như vậy | Worker suy `needs_attention` |
| `LEGACY_UNKNOWN` | `LEGACY_UNKNOWN` | dữ liệu trước v23 |

---

## 6. Chính sách vận hành SQLite local

| Hạng mục | Hiện tại | Đề xuất |
| --- | --- | --- |
| Journal mode | mặc định (`DELETE`) | **`PRAGMA journal_mode = WAL`** — chịu mất điện tốt hơn, cho phép đọc song song với ghi |
| Synchronous | mặc định (`FULL`) | Giữ **`FULL`** (an toàn mất điện) hoặc `NORMAL` nếu dùng WAL |
| Foreign keys | không bật | Cân nhắc `PRAGMA foreign_keys = ON` — **kiểm thử kỹ**, có thể phá code hiện tại |
| Kích thước | không giới hạn | Cảnh báo khi > 500 MB; dọn `error_logs` và `sync_queue` SYNCED cũ |
| Backup | **không có** | Copy file khi khởi động (nếu bản gần nhất > 24 h), giữ 7 bản, thư mục `{app}\data\backups\` |
| Kiểm tra toàn vẹn | không có | `PRAGMA quick_check` khi khởi động; lỗi → đổi tên file hỏng + tạo mới + ghi `error_logs` |
| Vacuum | không có | `PRAGMA incremental_vacuum` sau khi dọn log, tối đa 1 lần/tuần |

**Lưu ý về WAL:** WAL tạo thêm 2 file `.db-wal` và `.db-shm`. Phải cập nhật
`installer.iss` (`Excludes` dòng 101) để loại trừ luôn `data\photobooth.db-wal`
và `data\photobooth.db-shm`, nếu không installer sẽ ghi đè WAL và làm hỏng DB khách.

---

## 7. Bảng KHÔNG được đụng tới

| Bảng | Lý do |
| --- | --- |
| `events`, `photos`, `sessions`, `revenue_records`, `vouchers`, `employees`, `users`, `app_settings`, `event_settings`, `printer_settings`, `machines` | Đang chứa dữ liệu production của khách. Chỉ được **thêm cột**, không sửa/xoá/đổi tên |
| `schema_version` | Cơ chế migration phụ thuộc hoàn toàn vào bảng này |
| `upload_queue` | Code chết nhưng **không xoá trong Phase 5** — chỉ đánh dấu REMOVE LATER sau khi xác nhận không có bản build nào ngoài kia còn dùng |

---

## 8. Thứ tự triển khai

| Bước | Nội dung | Phase | Rủi ro |
| --- | --- | --- | --- |
| 1 | Thêm backup tự động trước migration | 5 | 🟢 |
| 2 | Thêm `PRAGMA quick_check` + fallback khi DB hỏng | 5 | 🟢 |
| 3 | Migration v27: tạo 5 bảng mới + 2 cột `uuid` | 5 | 🟡 (chỉ thêm) |
| 4 | Backfill `uuid` theo lô | 5 | 🟡 |
| 5 | Bật WAL (kèm sửa `installer.iss`) | 5 | 🟠 (cần kiểm thử mất điện) |
| 6 | Viết `CloudSyncService` dùng `sync_queue` | 6 | 🟡 |
| 7 | Ghi `error_logs` từ mọi component | 6 | 🟢 |
| 8 | `print_jobs` trong `PrinterManager` | 6 | 🟡 |
| 9 | Migration v28: UNIQUE index cho `uuid` | 6 | 🟡 |
| 10 | `cloud_cache` cho preset | 6 | 🟢 |
| 11 | `work_shifts` | sau 7 | 🟢 |
