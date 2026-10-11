# CLOUD SYNC DESIGN

Thiết kế `CloudSyncService` — tầng đồng bộ nền giữa SQLite local và
Cloudflare Worker + D1.

Ràng buộc tuyệt đối:
* **Không chặn UI.** Không chặn chụp. Không chặn in. Không làm treo phần mềm.
* **Không tạo dữ liệu trùng** trên cloud.
* **Resume được** sau khi app restart hoặc mất điện.
* **Không sửa Worker/D1** trong giai đoạn đầu — thiết kế phải chạy được với API hiện tại.

Ngày lập: 2026-08-03.

---

## 1. Vấn đề đang có (bằng chứng)

| # | Vấn đề | Bằng chứng |
| --- | --- | --- |
| S-1 | Session/Event/Revenue gửi **fire-and-forget**, lỗi là mất vĩnh viễn bản đồng bộ | [DynamoDBClient::sendRequest](src/backend/DynamoDBClient.cpp#L43-L77) — `onNetworkReply` chỉ `qCritical()` + `emit operationError` |
| S-2 | Không có hàng đợi cho dữ liệu D1 | Không tồn tại bảng/lớp nào |
| S-3 | `sessions.sync_pending` là cột chết | Tạo ở v23, set=1 ở 3 nơi, **không nơi nào đọc** |
| S-4 | 6 hàm gọi mạng **blocking UI thread** 16–48 s | [blockingRequest](src/backend/DynamoDBClient.cpp#L189-L243), gọi bởi `validateVoucherCloud`, `redeemVoucherCloud`, `deleteVoucherCloud`, `pushVouchersCloudSync`, `generateVouchersCloud`, `voucherPresetsCloud` (3 request nối tiếp) |
| S-5 | `package_checkins` có thể ghi trùng khi retry | [index.ts:1711](cloudflare/worker/src/index.ts#L1711) — `INSERT` thuần, không UNIQUE |
| S-6 | Không kéo `sessions.resolution_*` từ cloud về | Không có route/`GET` nào được client gọi để đọc lại |
| S-7 | Preset voucher phải gọi cloud mỗi lần mở tab | `voucherPresetsCloud()` blocking |

Điểm sáng đã có, **giữ nguyên**:
* `revenue_id` SHA-256 xác định → upsert idempotent.
* `sessions.status_version` guard → chống ghi đè ngược.
* `INSERT OR IGNORE` cho voucher; `UPDATE … WHERE used=0` cho redeem.
* `app_sales.sepay_ref UNIQUE` cho webhook.
* `S3Uploader` staging + retry 60 s + khử trùng `m_inFlightKeys`.

---

## 2. Kiến trúc `CloudSyncService`

```text
                  ┌──────────────── Main / UI thread ────────────────┐
                  │  EventManager / SessionManager / PrinterManager   │
                  │        │ ghi SQLite (transaction)                 │
                  │        ├─► INSERT INTO <bảng nghiệp vụ>           │
                  │        └─► INSERT INTO sync_queue (cùng txn)      │  ◄── ATOMIC
                  │        emit syncQueued()                          │
                  └───────────────────┬──────────────────────────────┘
                                      │ (queued connection, không chờ)
                  ┌───────────────────▼──────────────────────────────┐
                  │  CloudSyncService  (QThread riêng)                │
                  │   ├ NetworkStateMonitor (QNetworkInformation)     │
                  │   ├ tick timer 5 s                                │
                  │   ├ SELECT … WHERE status IN ('PENDING')          │
                  │   │      AND (next_retry_at IS NULL                │
                  │   │           OR next_retry_at <= now)             │
                  │   │      ORDER BY created_at LIMIT batch           │
                  │   ├ tối đa 2 request đồng thời                     │
                  │   ├ QNetworkAccessManager riêng (async, 15 s)      │
                  │   └ cập nhật status/attempt_count/next_retry_at    │
                  └───────────────────┬──────────────────────────────┘
                                      ▼
                        Cloudflare Worker → D1
```

**Nguyên tắc then chốt:** ghi bảng nghiệp vụ và ghi `sync_queue` nằm **trong cùng
một transaction SQLite**. Nếu app chết giữa chừng, hoặc cả hai cùng có, hoặc cả hai
cùng không. Không bao giờ có trạng thái "đã lưu doanh thu nhưng không có mục đồng bộ".

```cpp
// Mẫu bắt buộc
m_database.transaction();
bool ok = logRevenueRecordInternal(rec);          // INSERT revenue_records
ok = ok && enqueueSyncEvent("revenue", rec.uuid,  // INSERT sync_queue
                            "CREATE", payloadJson);
if (ok) m_database.commit(); else m_database.rollback();
```

---

## 3. Sự kiện đồng bộ

Cấu trúc bản ghi (khớp yêu cầu mục 7.3, xem DDL ở
[LOCAL_DATABASE_SCHEMA_PROPOSAL.md](LOCAL_DATABASE_SCHEMA_PROPOSAL.md#31-sync_queue)):

```text
event_id        UUIDv4 sinh tại local  ← idempotency key
entity_type     session | event | revenue | voucher | package_checkin
entity_id       khoá nghiệp vụ
operation       CREATE | UPDATE | DELETE
payload         JSON body gửi lên Worker
payload_hash    SHA-256(payload)
created_at
attempt_count
next_retry_at
status          PENDING | PROCESSING | RETRY | SYNCED | FAILED
last_error
synced_at
entity_version  số tăng đơn điệu trong phạm vi entity
```

### 3.1 Ánh xạ sự kiện → endpoint

| entity_type | operation | Endpoint | Idempotency có sẵn ở Worker |
| --- | --- | --- | --- |
| `event` | CREATE/UPDATE | `PUT /machine/:hwid/event` | ✅ `ON CONFLICT(hwid,event_id) DO UPDATE` |
| `session` | CREATE/UPDATE | `PUT /machine/:hwid/session` | ✅ upsert + `status_version` guard |
| `revenue` | CREATE | `POST /machine/:hwid/revenue` | ✅ `ON CONFLICT(revenue_id) DO UPDATE` + dò dòng cũ |
| `voucher` | CREATE (push lô) | `POST /machine/:hwid/vouchers` | ✅ `INSERT OR IGNORE` batch |
| `voucher` | UPDATE (redeem) | `POST /machine/:hwid/vouchers/:code/redeem` | ✅ `UPDATE … WHERE used=0` |
| `voucher` | DELETE | `DELETE /machine/:hwid/vouchers/:code` | ✅ DELETE idempotent |
| `package_checkin` | CREATE | `POST /machine/:hwid/package-checkins` | ❌ **KHÔNG** — xem 3.2 |

### 3.2 Xử lý `package_checkins` (S-5) — không sửa Worker

Vì `INSERT` ở Worker không idempotent, client phải tự đảm bảo **at-most-once**:

1. Trước khi gửi, gọi
   `GET /machine/:hwid/package-checkins/check-phone?package_key=…&phone=…`
   — route này chỉ SELECT, an toàn để gọi lại.
2. Nếu trả `status = "phone_used"` và `existing.session_id` khớp `session_id` của
   mình → coi như **đã gửi thành công**, đánh `SYNCED`, không gửi lại.
3. Chỉ retry khi lỗi mạng thật (không nhận được response). Nếu nhận được 5xx
   (server đã nhận request) → chuyển sang bước xác minh ở (1) trước khi retry.
4. Giới hạn cứng `attempt_count <= 3` cho entity này, sau đó `FAILED` + ghi
   `error_logs` CRITICAL để người vận hành đối soát tay.

Về lâu dài (sau khi được phê duyệt deploy Worker): thêm
`CREATE UNIQUE INDEX idx_checkins_machine_session ON package_checkins(machine_hwid, session_id)`
và đổi `INSERT` → `INSERT OR IGNORE`. **Không làm trong Phase 4–7.**

---

## 4. Chính sách retry

### 4.1 Thang thời gian (theo yêu cầu mục 7.5)

| Lần thử | Độ trễ cơ sở |
| --- | --- |
| 1 | 5 giây |
| 2 | 15 giây |
| 3 | 1 phút |
| 4 | 5 phút |
| 5 | 15 phút |
| ≥ 6 | 30 phút |

```cpp
// Bảng tra cứu — rõ ràng hơn công thức mũ, khớp đúng yêu cầu.
static constexpr int kBackoffSeconds[] = { 5, 15, 60, 300, 900 };
static constexpr int kBackoffSteadySeconds = 1800;

static int baseDelaySeconds(int attemptCount) {
    const int n = sizeof(kBackoffSeconds) / sizeof(kBackoffSeconds[0]);
    return (attemptCount < n) ? kBackoffSeconds[attemptCount] : kBackoffSteadySeconds;
}
```

### 4.2 Jitter

Bắt buộc, để nhiều máy trong cùng studio không cùng lúc dội request khi mạng phục hồi:

```cpp
// Full jitter: delay thực = random[0.5×base, 1.5×base]
static int jitteredDelay(int baseSec) {
    const int span = baseSec / 2;                       // ±50%
    return baseSec - span + QRandomGenerator::global()->bounded(2 * span + 1);
}
```

`next_retry_at = now + jitteredDelay(baseDelaySeconds(attempt_count))`.

### 4.3 Phân loại lỗi → hành động

| Kết quả | Hành động | Lý do |
| --- | --- | --- |
| HTTP 2xx | `SYNCED`, `synced_at = now` | Thành công |
| Lỗi mạng (`statusCode == 0`) | `RETRY`, `attempt_count++` | Có thể phục hồi |
| HTTP 408 / 429 / 5xx | `RETRY`, `attempt_count++`. Với 429: nhân delay × 4, hạ concurrency về 1 | Server quá tải/tạm lỗi |
| HTTP 401 / 403 | `RETRY` với delay tối thiểu **30 phút**, ghi `error_logs` CRITICAL | Token sai/rotate — retry nhanh vô ích, nhưng đừng bỏ dữ liệu |
| HTTP 400 / 404 / 409 (nghiệp vụ) | `FAILED`, ghi `error_logs` ERROR | Gửi lại cũng vẫn lỗi |
| `attempt_count > 20` | `FAILED` | Ngưỡng cứng |

**Quan trọng:** 401/403 **không** được chuyển `FAILED` — nếu admin đổi token rồi
cập nhật `key.json`, dữ liệu tồn đọng phải tự đi tiếp.

### 4.4 Giới hạn tài nguyên

| Tham số | Giá trị | Lý do |
| --- | --- | --- |
| Số request đồng thời | **2** | Cloudflare Worker có giới hạn subrequest; 2 là đủ, không gây burst |
| Kích thước lô mỗi tick | **20** mục | Tránh quét bảng lớn |
| Chu kỳ tick | **5 giây** | Đủ nhanh cho cảm giác "gần realtime", đủ chậm để không tốn CPU |
| Timeout mỗi request | **15 giây** (`setTransferTimeout`) | Khớp cấu hình hiện tại |
| Thread | **1 QThread riêng** cho `CloudSyncService` | Không đụng UI thread |
| Tạm dừng khi | đang chụp (`CameraController::isCapturing`) hoặc đang in | Ưu tiên tuyệt đối cho nghiệp vụ |

### 4.5 Ưu tiên hàng đợi

Khi có nhiều mục chờ, gửi theo thứ tự:

```text
1. revenue          (tiền — quan trọng nhất)
2. session          (lượt chụp)
3. event            (tổng hợp)
4. voucher          (mã)
5. package_checkin  (nhật ký)
```

Trong cùng `entity_type`: `ORDER BY created_at ASC` (FIFO).
Trong cùng `entity_id`: chỉ gửi mục có `entity_version` cao nhất, đánh
`SYNCED` (bỏ qua) cho các version thấp hơn — **không gửi lịch sử vô ích**.

---

## 5. Chống gửi trùng (idempotency)

### 5.1 Ba lớp bảo vệ

**Lớp 1 — ID sinh tại local (P5 của kiến trúc):**

| Dữ liệu | ID | Sinh ở |
| --- | --- | --- |
| `session_id` | UUID | local (đã có) |
| `revenue.uuid` | UUID | local (đề xuất migration v27) |
| `revenue_id` (khoá cloud) | SHA-256 xác định | tính được ở cả 2 phía |
| `event_id` của sync_queue | UUIDv4 | local |
| `print_jobs.uuid` | UUID | local |

**Cấm dùng `last_insert_rowid()` của D1 làm định danh dữ liệu tạo từ máy khách.**

**Lớp 2 — khoá tự nhiên + UPSERT ở Worker (đã có, giữ nguyên):**
`ON CONFLICT DO UPDATE`, `INSERT OR IGNORE`, `UPDATE … WHERE used=0`,
`sepay_ref UNIQUE`, `status_version` guard.

**Lớp 3 — khử trùng ở hàng đợi:**

```sql
-- Trước khi INSERT vào sync_queue: nếu đã có mục cùng entity + cùng payload_hash
-- và chưa gửi thành công → không thêm mục mới, chỉ tăng entity_version.
SELECT event_id FROM sync_queue
 WHERE entity_type = ? AND entity_id = ? AND payload_hash = ?
   AND status IN ('PENDING','PROCESSING','RETRY')
 LIMIT 1;
```

Với `UPDATE` liên tục (ví dụ session đổi trạng thái nhiều lần), thay vì xếp N mục,
**thay thế mục PENDING cũ**:

```sql
UPDATE sync_queue
   SET payload = ?, payload_hash = ?, entity_version = entity_version + 1,
       created_at = ?, attempt_count = 0, next_retry_at = NULL, status = 'PENDING'
 WHERE entity_type = ? AND entity_id = ? AND status = 'PENDING';
```

Chỉ áp dụng cho entity **có thể gộp** (`session`, `event`). Không gộp `revenue`
và `voucher` (mỗi bản ghi là sự kiện độc lập).

### 5.2 Header idempotency (chuẩn bị cho tương lai)

Gửi kèm mọi request:

```http
X-Idempotency-Key: <sync_queue.event_id>
```

Worker hiện **bỏ qua** header này (không đọc) → an toàn, không phá gì. Khi được
phê duyệt deploy Worker, có thể thêm bảng `idempotency_keys` phía cloud để chặn
tuyệt đối. Client không cần sửa lại.

---

## 6. Loại bỏ blocking network khỏi UI thread (S-4)

### 6.1 Hiện trạng

| Hàm | Thời gian xấu nhất | Gọi từ |
| --- | --- | --- |
| `validateVoucherCloud` | 16 s | [EventManager.cpp:4716](src/backend/EventManager.cpp#L4716), 5074, 5174 |
| `redeemVoucherCloud` | 16 s | 4826, 5157, 5251 |
| `deleteVoucherCloud` | 16 s | 4956 |
| `pushVouchersCloudSync` | 16 s | 4693 (đã bị `kCodesLocalFirst` chặn) |
| `generateVouchersCloud` | 16 s | 4866 (đã bị `kCodesLocalFirst` chặn) |
| `voucherPresetsCloud` | **48 s** (3 request nối tiếp) | 4926 |

### 6.2 Chiến lược thay thế

| Hàm | Giải pháp | Phase |
| --- | --- | --- |
| `voucherPresetsCloud` | Đọc từ `cloud_cache` **ngay lập tức**. Kích hoạt refresh nền, cập nhật UI khi có kết quả. Lần đầu chưa có cache → dùng default cứng (giống seed của Worker: 4 ghi chú, 5 mức giá, 3 mốc thời gian) | 6 |
| `validateVoucherCloud` | Giữ đồng bộ nhưng **hạ timeout xuống 3 giây**. Quá 3 s → fallback local ngay. Nhân viên không chờ quá 3 s. | 6 |
| `redeemVoucherCloud` | Giữ đồng bộ, timeout 5 s. Nếu timeout: **không** fallback local âm thầm (nguy cơ dùng 2 lần trên 2 máy) — hiện thông báo "Không xác nhận được mã, thử lại hoặc dùng tiền mặt". | 6 |
| `deleteVoucherCloud` | Chuyển hoàn toàn sang `sync_queue` (`operation='DELETE'`). Xoá local ngay, cloud theo sau. Đã có sẵn bản async `deleteVoucherCloudAsync`. | 6 |
| `pushVouchersCloudSync` | Chuyển sang `sync_queue`. | 6 |
| `generateVouchersCloud` | Đã bị `kCodesLocalFirst` vô hiệu. Nếu bật lại thì phải async. | 6 |

**Tại sao không async hoá tất cả:** validate/redeem voucher là thao tác **đồng bộ
về mặt nghiệp vụ** — nhân viên đứng chờ để biết mã có dùng được không. Async ở đây
sẽ làm UX tệ hơn. Giải pháp đúng là **giảm timeout**, không phải đổi mô hình.

Sửa cụ thể trong `blockingRequest`: thêm tham số `timeoutMs`:

```cpp
QVariantMap blockingRequest(const QString &verb, const QString &path,
                            const QJsonObject &payload,
                            int timeoutMs = 15000);   // ← mới
```

và trong thân hàm: `req.setTransferTimeout(timeoutMs); guard.start(timeoutMs + 1000);`

---

## 7. Đồng bộ chiều CLOUD → LOCAL (pull)

Hiện chỉ có 2 luồng pull: `GET /machine/:hwid` (best-effort, lấy `studio_id`) và
`fetchStudioInfo` (nhân viên). Bổ sung:

| Dữ liệu | Endpoint | Tần suất | Đích local | Conflict |
| --- | --- | --- | --- | --- |
| `sessions.resolution_*` | `GET /machine/:hwid/capture-attempts` | 5 phút + khi mở màn Lịch sử | `sessions.resolution_*` | **Cloud wins** (chỉ web ghi) |
| Preset voucher (3 loại) | `GET /machine/:hwid/voucher-{notes,prices,durations}` | 1 h + khi mở tab | `cloud_cache` | Cloud wins |
| Preset gói chụp | `GET /machine/:hwid/package-presets` | 1 h | `cloud_cache` | Cloud wins |
| Nhân viên studio | `GET /machine/:hwid/studio-info` | khi khởi động + 1 h | `employees` | Cloud wins cho danh sách, local wins cho PIN |
| Danh sách voucher | `GET /machine/:hwid/vouchers` | 30 s khi mở màn quản lý mã | hiển thị + merge mã local | Đã có (`mergeLocalCodesIntoCloudList`) |
| `studio_id` | `GET /machine/:hwid` | khởi động | QSettings | Cloud wins |

**Tất cả pull đều async, đều có cache local, đều không chặn.**
Ghi `sync_state.cursor` để biết lần kéo gần nhất.

---

## 8. Xử lý crash và mất điện

### 8.1 Khi khởi động

```cpp
// 1. Kiểm tra toàn vẹn DB
//    PRAGMA quick_check  → không "ok" thì đổi tên + tạo mới + error_logs CRITICAL

// 2. Giải phóng mục kẹt PROCESSING (app chết giữa lúc gửi)
//    Không biết request đã tới server chưa → gửi lại là an toàn vì mọi endpoint
//    đều idempotent (trừ package_checkin, xem §3.2).
UPDATE sync_queue
   SET status = 'PENDING', next_retry_at = NULL
 WHERE status = 'PROCESSING';

// 3. Khôi phục phiên chụp dở dang (đã có sẵn)
//    DatabaseManager::recoverInterruptedSessions()  → status = 'APP_INTERRUPTED'
//    Sau đó enqueue lại các session này.

// 4. Đưa print_jobs kẹt 'PRINTING' về trạng thái cần xác nhận thủ công.

// 5. Dọn dẹp (tối đa 1 lần/ngày)
DELETE FROM sync_queue
 WHERE status = 'SYNCED' AND synced_at < datetime('now','-7 days');
```

### 8.2 Thứ tự ghi an toàn cho ảnh

Ràng buộc: **không được có metadata trỏ vào file chưa tồn tại, và không được có
file mồ côi không ai biết**.

```text
1. Camera trả ảnh → ghi file tạm  <name>.part
2. fsync + rename  <name>.part → <name>.jpg        (rename là atomic trên NTFS)
3. BEGIN TRANSACTION
     INSERT INTO photos (file_path, session_id, uuid, ...)
     INSERT INTO sync_queue (...)   -- nếu cần đồng bộ metadata
   COMMIT
4. S3Uploader.dispatch()  → upload hoặc stage vào pending/
```

Nếu chết sau bước 2, trước bước 3: có file mồ côi.
→ Khi khởi động, quét thư mục `Originals/` của event đang mở, so với bảng `photos`,
bổ sung metadata thiếu (ghi `error_logs` WARN).

Nếu chết sau bước 3, trước bước 4: metadata có, chưa upload.
→ `S3Uploader::retryPendingSessions()` sau 5 s đã xử lý (đã có).

**Không bao giờ xoá file local sau khi upload thành công** — file local là bản gốc.

### 8.3 Mất điện khi SQLite đang ghi

* Bật `PRAGMA journal_mode = WAL` + giữ `synchronous = FULL`.
* SQLite tự phục hồi từ WAL khi mở lại.
* `PRAGMA quick_check` khi khởi động để phát hiện hỏng nặng.
* Có backup: `{app}\data\backups\photobooth.db.bak-<timestamp>` (7 bản gần nhất).

⚠️ Nếu bật WAL, **phải** cập nhật [installer.iss:101](installer.iss#L101) thêm
`data\photobooth.db-wal` và `data\photobooth.db-shm` vào `Excludes`, nếu không
installer sẽ ghi đè WAL và làm hỏng DB của khách.

---

## 9. Ổ đĩa hết dung lượng

| Ngưỡng | Hành động |
| --- | --- |
| Còn < 5 GB | Cảnh báo trên màn hình quản trị (không hiện cho khách) |
| Còn < 2 GB | Cảnh báo mạnh + dừng ghi video, chỉ giữ ảnh tĩnh |
| Còn < 500 MB | Dừng nhận phiên mới, hiện "Máy tạm ngưng — liên hệ nhân viên". **Vẫn không thoát app.** |
| Ghi SQLite lỗi `SQLITE_FULL` | Ghi `error_logs`, giữ thao tác trong RAM, hiện cảnh báo, thử lại sau 30 s |

Kiểm tra bằng `QStorageInfo::bytesAvailable()` mỗi 5 phút và trước mỗi phiên.

---

## 10. Giao diện lớp `CloudSyncService` (thiết kế, chưa triển khai)

```cpp
// src/backend/CloudSyncService.h  — TẠO MỚI ở Phase 6
class CloudSyncService : public QObject {
    Q_OBJECT
    Q_PROPERTY(int  pendingCount READ pendingCount NOTIFY stateChanged)
    Q_PROPERTY(int  failedCount  READ failedCount  NOTIFY stateChanged)
    Q_PROPERTY(bool online       READ online       NOTIFY stateChanged)
    Q_PROPERTY(bool syncing      READ syncing      NOTIFY stateChanged)

public:
    explicit CloudSyncService(DatabaseManager *db, ConfigManager *cfg,
                              QObject *parent = nullptr);

    // Gọi từ UI thread. CHỈ ghi vào sync_queue rồi trả về ngay — không mạng.
    // Phải được gọi TRONG transaction của caller.
    bool enqueue(const QString &entityType, const QString &entityId,
                 const QString &operation,  const QJsonObject &payload);

    // Tạm dừng khi đang chụp/in — bảo vệ nghiệp vụ.
    Q_INVOKABLE void pause();
    Q_INVOKABLE void resume();

    // Người vận hành bấm "thử lại" cho các mục FAILED.
    Q_INVOKABLE void retryFailed();

    int  pendingCount() const;
    int  failedCount()  const;
    bool online()  const;
    bool syncing() const;

signals:
    void stateChanged();
    void itemSynced(const QString &entityType, const QString &entityId);
    void itemFailed(const QString &entityType, const QString &entityId,
                    const QString &error);

private:
    void tick();                                    // chạy trên thread nền
    void dispatchOne(const SyncItem &item);
    void onReply(const QString &eventId, int httpStatus,
                 int netError, const QByteArray &body);
    void scheduleRetry(const QString &eventId, int attemptCount, int httpStatus);

    QThread                m_thread;
    DatabaseManager       *m_db;
    ConfigManager         *m_cfg;
    QNetworkAccessManager *m_nam;      // sống trên m_thread
    QTimer                *m_tick;     // 5 s
    int                    m_inFlight = 0;
    static constexpr int   kMaxConcurrent = 2;
    static constexpr int   kBatchSize     = 20;
    bool                   m_paused = false;
};
```

Đăng ký cho QML trong `main.cpp`:

```cpp
engine.rootContext()->setContextProperty("cloudSync", cloudSyncService);
```

---

## 11. Điểm tích hợp — thay thế lời gọi hiện tại

| Vị trí hiện tại | Hiện làm | Thay bằng |
| --- | --- | --- |
| [EventManager.cpp:352](src/backend/EventManager.cpp#L352) `syncSessionToCloud()` | `m_dynamoClient->syncSessionData(...)` | `m_sync->enqueue("session", sessionId, "UPDATE", payload)` |
| [EventManager.cpp:4170](src/backend/EventManager.cpp#L4170) | `m_dynamoClient->syncEventData(...)` | `m_sync->enqueue("event", QString::number(eventId), "UPDATE", payload)` |
| [EventManager.cpp:5336](src/backend/EventManager.cpp#L5336) `logRevenue()` | `m_dynamoClient->syncRevenueRecord(...)` | `m_sync->enqueue("revenue", rec.uuid, "CREATE", payload)` — **trong cùng transaction với `logRevenueRecord`** |
| [EventManager.cpp:4693](src/backend/EventManager.cpp#L4693) `syncPendingVouchers()` | `pushVouchersCloudSync` blocking | `enqueue("voucher", code, "CREATE", …)` cho từng mã |
| [EventManager.cpp:4956](src/backend/EventManager.cpp#L4956) | `deleteVoucherCloud` blocking | `enqueue("voucher", code, "DELETE", {})` |
| [EventManager.cpp:4926](src/backend/EventManager.cpp#L4926) | `voucherPresetsCloud` blocking 48 s | Đọc `cloud_cache` + refresh nền |

**Giữ nguyên `DynamoDBClient` làm tầng vận chuyển.** `CloudSyncService` gọi lại
chính các hàm đó (hoặc dùng chung `buildRequest`), không viết lại HTTP từ đầu.
Điều này giảm rủi ro hồi quy.

---

## 12. Quan sát và vận hành

| Chỉ số | Nguồn | Hiển thị |
| --- | --- | --- |
| Số mục PENDING/RETRY | `SELECT COUNT(*) FROM sync_queue WHERE status IN ('PENDING','RETRY')` | Chấm trạng thái góc màn quản trị |
| Số mục FAILED | `… WHERE status='FAILED'` | Chấm đỏ + link tới Nhật ký |
| Mục cũ nhất chưa gửi | `MIN(created_at) WHERE status != 'SYNCED'` | "Chậm nhất: N giờ" |
| Lần đồng bộ thành công gần nhất | `sync_state.last_success_at` | |
| Số ảnh chờ upload | `S3Uploader::pendingCount()` (đã có) | |
| Lỗi gần đây | `error_logs` 50 dòng mới nhất | Màn hình Nhật ký (mới) |

Xuất CSV `sync_queue` + `error_logs` để hỗ trợ kỹ thuật từ xa
(theo mẫu `exportRevenueToCSV` / `exportCaptureAttemptsToCSV` đã có).

---

## 13. Những gì KHÔNG làm

| Không làm | Lý do |
| --- | --- |
| Không sửa `cloudflare/worker/src/index.ts` trong Phase 4–7 | Ảnh hưởng mọi máy production cùng lúc |
| Không thêm bảng/cột vào D1 | Cần migration production |
| Không đổi endpoint, không đổi hình dạng payload | Máy khách cũ vẫn phải chạy được |
| Không xoá `DynamoDBClient` | Vẫn là tầng vận chuyển |
| Không đồng bộ 2 chiều cho `app_settings` | Cấu hình máy là của máy |
| Không tự động resolve conflict bằng `updated_at` | Đồng hồ máy khách không tin cậy |
| Không xoá file ảnh local sau khi upload | File local là bản gốc |
| Không chặn UI để chờ đồng bộ | Nguyên tắc bất biến |
| Không đưa `sync_queue` vào cùng transaction với thao tác **dài** (ghép ảnh, in) | Giữ transaction ngắn |
