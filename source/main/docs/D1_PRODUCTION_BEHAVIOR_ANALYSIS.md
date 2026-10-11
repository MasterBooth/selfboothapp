# D1 PRODUCTION BEHAVIOR ANALYSIS

Phạm vi: toàn bộ repository `c:\Users\LAPTOP117\Desktop\photobooth\source\main`.
Phương pháp: **chỉ đọc mã nguồn, migration, cấu hình**. Không chạy bất kỳ lệnh nào
chạm tới D1 production. Không deploy. Không migration. Không seed.

Ngày lập: 2026-08-03.

---

## 0. CẢNH BÁO ĐẦU TIÊN — DATABASE ID TRONG YÊU CẦU KHÔNG TỒN TẠI TRONG REPO

Yêu cầu nêu:

```text
Database name: photobooth
Database ID:   a69d02e4-8ef3-4cf8-a7d6-fda511e5aef7
```

Kết quả tìm kiếm toàn repository (`a69d02e4`, `photobooth` như database_name):

| Mục | Kết quả |
| --- | --- |
| `a69d02e4-8ef3-4cf8-a7d6-fda511e5aef7` xuất hiện trong repo | **KHÔNG** (0 kết quả) |
| `database_name = "photobooth"` | **KHÔNG** |

Cấu hình D1 thực tế đang được deploy — [cloudflare/worker/wrangler.toml](cloudflare/worker/wrangler.toml):

```toml
name = "boothme-api"
main = "src/index.ts"

[[d1_databases]]
binding       = "DB"
database_name = "boothme_prod"
database_id   = "3d092835-6466-42d8-a885-ee784ddbb442"

[[d1_databases]]
binding       = "MSB_DB"
database_name = "msb_photobooth"
database_id   = "fd5284fa-6102-498f-857e-467892c835dc"
```

**Kết luận:** D1 `photobooth / a69d02e4-…` là database **mới / chưa được đấu nối**,
hoặc thuộc một dự án khác. Toàn bộ phân tích dưới đây nói về hai database đang
chạy production là `boothme_prod` và `msb_photobooth`.

Trạng thái: **CHƯA XÁC ĐỊNH** — cần người vận hành xác nhận D1 mới dùng để làm gì
trước khi có bất kỳ thay đổi nào. Không được tự ý trỏ `wrangler.toml` sang ID mới.

---

## 1. Kiến trúc tổng thể (luồng thực tế đã lần theo)

```text
Qt/QML Desktop App (BOOTHME.exe)
  │
  ├── DatabaseManager  ──────────────► SQLite local  {app}\data\photobooth.db   (NGUỒN VẬN HÀNH)
  ├── S3Uploader       ──────────────► POST /upload/presign ──► AWS S3 (ảnh/video)
  │                                    (offline → staging folder trên đĩa + retry 60s)
  ├── DynamoDBClient   ──────────────┐
  ├── LicenseStore     ──────────────┤ HTTPS REST + Bearer token
  ├── QrLoginManager   ──────────────┤
  └── (HttpBridge :5514 — LOCAL, không chạm cloud)
                                      │
                                      ▼
                    Cloudflare Worker "boothme-api"
                    https://boothme-api.boothstudio2026.workers.dev
                                      │
                    ┌─────────────────┴──────────────────┐
                    ▼                                    ▼
            env.DB = boothme_prod              env.MSB_DB = msb_photobooth
            (3d092835-…)                       (fd5284fa-…)

Web Portal (Vercel: boothme-photobooth.vercel.app) ──► cùng Worker, cùng bearer token
Web Gallery                                        ──► GET /media/* (proxy S3)
```

**Desktop KHÔNG kết nối trực tiếp tới Cloudflare D1.** Mọi truy cập D1 đều đi qua
Worker REST API. Desktop không giữ credential D1 và không giữ AWS secret.

Client chọn database bằng header `x-booth-tenant`
([index.ts:41-44](cloudflare/worker/src/index.ts#L41-L44)):

```ts
const isMsbTenant  = (req) => (req.headers.get("x-booth-tenant") ?? "").toLowerCase() === "msb";
const dbForRequest = (req, env) => isMsbTenant(req) ? env.MSB_DB : env.DB;
```

Tìm kiếm `x-booth-tenant` trong toàn bộ `src/` (C++) → **0 kết quả**.
→ **Desktop app luôn dùng `env.DB` (boothme_prod)**. Chỉ có CMS/portal mới gửi
header MSB. Ngoại lệ: các route `package_code` trong Worker gọi thẳng `env.MSB_DB`
bất kể tenant.

---

## 2. Phân tích chi tiết

### 4.1 Danh sách tất cả kết nối D1

| Thành phần | File | Class/Hàm | D1 binding | Môi trường | Quyền thao tác |
| --- | --- | --- | --- | --- | --- |
| Worker API (mọi route) | [cloudflare/worker/src/index.ts](cloudflare/worker/src/index.ts) | `export default { fetch }` | `DB` | Production (boothme_prod) | SELECT / INSERT / UPDATE / DELETE / BATCH |
| Worker API (route MSB + package_code) | [cloudflare/worker/src/index.ts](cloudflare/worker/src/index.ts) | cùng `fetch` | `MSB_DB` | Production (msb_photobooth) | SELECT / INSERT / UPDATE / DELETE / BATCH |
| Desktop — máy/license | [src/backend/DynamoDBClient.cpp](src/backend/DynamoDBClient.cpp) | `getMachine()`, `registerMachine()`, `claimMachine()` | qua HTTP → `DB` | Production | SELECT / INSERT / UPDATE |
| Desktop — đồng bộ vận hành | [src/backend/DynamoDBClient.cpp](src/backend/DynamoDBClient.cpp) | `syncEventData()`, `syncSessionData()`, `syncRevenueRecord()` | qua HTTP → `DB` | Production | INSERT / UPSERT |
| Desktop — voucher | [src/backend/DynamoDBClient.cpp](src/backend/DynamoDBClient.cpp) | `validateVoucherCloud()`, `redeemVoucherCloud()`, `pushVouchersCloudSync()`, `generateVouchersCloud()`, `fetchVoucherList()`, `deleteVoucherCloud()`, `voucherPresetsCloud()` | qua HTTP → `DB` (+ `MSB_DB` cho package_code) | Production | SELECT / INSERT / UPDATE / DELETE |
| Desktop — gói bán app | [src/backend/LicenseStore.cpp](src/backend/LicenseStore.cpp) | `fetchPlans()`, `createIntent()`, `checkIntent()` | qua HTTP → `DB` | Production | SELECT / INSERT / UPDATE |
| Desktop — QR login | [src/backend/QrLoginManager.cpp](src/backend/QrLoginManager.cpp) | `start()`, `poll()`, `consume()`, `fetchStudioInfo()` | qua HTTP → `DB` | Production | SELECT / INSERT / UPDATE |
| Desktop — upload ảnh | [src/backend/S3Uploader.cpp](src/backend/S3Uploader.cpp) | `dispatch()` → `POST /upload/presign` | qua HTTP → `DB` (chỉ SELECT `machines.activate`) | Production | SELECT |
| Web portal | [web/portal/index.html](web/portal/index.html), [web/portal/config.js](web/portal/config.js) | fetch trực tiếp Worker | qua HTTP → `DB`/`MSB_DB` | Production | toàn quyền |
| Web gallery | [web/gallery/index.html](web/gallery/index.html) | `GET /media/*` | không chạm D1 | Production | — |

**Không có môi trường development riêng.** Chỉ có 1 `wrangler.toml`, không có
`[env.staging]` / `[env.dev]`. `npm run dev` (`wrangler dev`) mặc định dùng D1
local miniflare (có thư mục `.wrangler/state/v3/d1/miniflare-D1DatabaseObject/`),
nhưng `wrangler dev --remote` sẽ chạm **thẳng production**. Rủi ro cao.

---

### 4.2 Danh sách API đang thao tác D1

Xác thực chung: **mọi route đều yêu cầu** `Authorization: Bearer <API_TOKEN>`
([index.ts:76-82](cloudflare/worker/src/index.ts#L76-L82)), ngoại trừ:
* `POST /sepay/webhook` — tự xác thực bằng header `Apikey <sepay_api_key>`;
* `GET /media/*` — **CÔNG KHAI, KHÔNG XÁC THỰC** (proxy đọc S3).

Token production đang nằm plaintext trong [key.json](key.json) (`cloud_api.api_token`)
và trong [web/portal/config.js](web/portal/config.js) — cùng một token, **cấp toàn quyền**.

#### 4.2.1 Route Desktop gọi (quan trọng nhất cho local-first)

| Method | Endpoint | File xử lý | Bảng D1 | Thao tác | Client gọi |
| --- | --- | --- | --- | --- | --- |
| GET | `/machine/:hwid` | index.ts:1103-1116 | `machines`, `studios`, `plans` | SELECT | Desktop (`getMachine`) |
| POST | `/machine/:hwid` | index.ts:1121-1173 | `machines`, `studios`, `app_settings` | SELECT + **INSERT/UPDATE** | Desktop (`registerMachine`) |
| PATCH | `/machine/:hwid` | index.ts:1176-1222 | `machines`, `plans`, `studios` | **UPDATE/INSERT** | Desktop (`claimMachine`) + CMS |
| PUT | `/machine/:hwid/event` | index.ts:1225-1239 | `events` | **UPSERT** | Desktop (`syncEventData`) |
| PUT | `/machine/:hwid/session` | index.ts:1245-1274 | `sessions` | **UPSERT** (guard `status_version`) | Desktop (`syncSessionData`) |
| POST | `/machine/:hwid/revenue` | index.ts:1736-1780 | `revenue` | SELECT + **UPSERT** | Desktop (`syncRevenueRecord`) |
| POST | `/upload/presign` | index.ts:2831-2877 | `machines` | SELECT (`activate`) | Desktop (S3Uploader) |
| GET | `/machine/:hwid/vouchers` | index.ts:1325-1353 | `machines`,`vouchers` \| `package_codes`(MSB_DB) | SELECT | Desktop (`fetchVoucherList`) |
| GET | `/machine/:hwid/vouchers/:code` | index.ts:1375-1417 | `vouchers`,`loyalty_codes`,`package_codes` | SELECT | Desktop (`validateVoucherCloud`) — **BLOCKING** |
| POST | `/machine/:hwid/vouchers/:code/redeem` | index.ts:1472-1534 | `vouchers`/`loyalty_codes`/`package_codes`, `loyalty_redemptions` | **UPDATE + INSERT** | Desktop (`redeemVoucherCloud`) — **BLOCKING** |
| POST | `/machine/:hwid/vouchers` | index.ts:1630-1655 | `vouchers` | **INSERT OR IGNORE (batch)** | Desktop (`pushVouchersCloudSync`) — **BLOCKING** |
| POST | `/machine/:hwid/vouchers/generate` | index.ts:1538-1626 | `vouchers` / `package_codes` | **INSERT OR IGNORE** | Desktop (`generateVouchersCloud`) — **BLOCKING** |
| DELETE | `/machine/:hwid/vouchers/:code` | index.ts:1459-1468 | `vouchers` / `package_codes` | **DELETE** | Desktop (`deleteVoucherCloud`) — **BLOCKING** |
| DELETE | `/machine/:hwid/vouchers` | index.ts:1425-1452 | `vouchers`, `package_codes` | **DELETE hàng loạt** | Desktop (xoá lô) |
| GET | `/machine/:hwid/voucher-notes` | index.ts:1357-1360 | `voucher_notes` | SELECT + **INSERT seed** | Desktop — **BLOCKING** |
| GET | `/machine/:hwid/voucher-prices` | index.ts:1361-1364 | `voucher_prices` | SELECT + **INSERT seed** | Desktop — **BLOCKING** |
| GET | `/machine/:hwid/voucher-durations` | index.ts:1365-1368 | `voucher_durations` | SELECT + **INSERT seed** | Desktop — **BLOCKING** |
| GET | `/machine/:hwid/package-presets` | index.ts:1369-1372 | `package_presets` | SELECT | Desktop |
| GET | `/machine/:hwid/capture-attempts` | index.ts:1280-1292 | `sessions`,`events`,`revenue` | SELECT | Desktop/CMS |
| GET | `/machine/:hwid/studio-info` | index.ts:1966-1991 | `machines`,`studio_staff` | SELECT | Desktop (`fetchStudioInfo`) |
| POST | `/machine/:hwid/qr-session` | index.ts:1915-1936 | `machines`, `qr_login_sessions` | SELECT + **INSERT** | Desktop (QR login) |
| GET | `/machine/:hwid/qr-session/:code` | index.ts:1939-1952 | `qr_login_sessions` | SELECT + **UPDATE (lazy expire)** | Desktop poll |
| POST | `/machine/:hwid/qr-session/:code/consume` | index.ts:1955-1963 | `qr_login_sessions` | **UPDATE** | Desktop |
| GET | `/plans` | index.ts:711-725 | `plans`, `app_settings` | SELECT | Desktop (LicenseStore) |
| POST | `/machine/:hwid/payment-intent` | index.ts:1846-1899 | `plans`,`machines`,`payment_intents`,`app_settings` | SELECT + **INSERT/UPDATE** | Desktop (LicenseStore) |
| GET | `/machine/:hwid/payment-intent/:code` | index.ts:1902-1911 | `payment_intents` | SELECT | Desktop poll |
| GET | `/machine/:hwid/package-checkins/check-phone` | index.ts:1659-1683 | `package_checkins` (MSB_DB) | SELECT | Desktop (MSB) |
| POST | `/machine/:hwid/package-checkins` | index.ts:1703-1733 | `package_checkins`, `package_codes` (MSB_DB) | **INSERT** (không idempotent) | Desktop (MSB) |
| PATCH | `/machine/:hwid/package-checkins/:sid/print-intent` | index.ts:1687-1700 | `package_checkins` (MSB_DB) | **UPDATE** | Desktop (MSB) |

#### 4.2.2 Route quản trị (CMS / Portal / Admin) — desktop KHÔNG gọi

| Method | Endpoint | Bảng | Thao tác |
| --- | --- | --- | --- |
| GET | `/machines?brand=&email=` | `machines` | SELECT |
| GET | `/studio/:studioId` | `studios`,`machines` | SELECT |
| POST | `/portal/google` | `machines`,`studios`,`studio_staff` | SELECT (+ gọi Google tokeninfo) |
| GET | `/portal/qr-session/:code` | `qr_login_sessions`,`machines` | SELECT + UPDATE lazy expire |
| POST | `/portal/qr-session/:code/approve` | `qr_login_sessions` | **UPDATE có điều kiện** |
| GET | `/portal/:email/qr-history` | `qr_login_sessions`,`machines` | SELECT |
| GET | `/portal/:email/revenue` | `revenue`,`machines` | SELECT |
| GET | `/portal/:email/media-sessions` | `sessions`,`machines`,`events` | SELECT |
| GET/POST/DELETE | `/portal/:email/vouchers` | `vouchers` | SELECT / **INSERT** / **DELETE** |
| GET/POST/DELETE | `/portal/:email/loyalty-codes` | `loyalty_codes`,`vouchers` | SELECT / **INSERT** / **UPDATE revoked** |
| GET/POST/DELETE | `/portal/:email/package-presets` | `package_presets` | SELECT / **INSERT** / **DELETE** |
| GET/POST/PATCH/DELETE | `/portal/:email/staff` | `studio_staff` | SELECT / **UPSERT** / **UPDATE** / **DELETE** |
| GET/POST/PATCH/DELETE | `/portal/:email/voucher-notes` | `voucher_notes` | SELECT / **INSERT** / **UPDATE** / **DELETE** |
| GET/POST/DELETE | `/portal/:email/voucher-prices` | `voucher_prices` | SELECT / **INSERT** / **DELETE** |
| GET/POST/DELETE | `/portal/:email/voucher-durations` | `voucher_durations` | SELECT / **INSERT** / **DELETE** |
| GET | `/portal/:email/capture-attempts` | `sessions`,`events`,`revenue`,`machines` | SELECT |
| GET/POST/PATCH | `/plans`, `/plans/:code` | `plans` | SELECT / **UPSERT** / **UPDATE** |
| POST | `/admin/login` | `admin_accounts` (MSB_DB) | SELECT + **INSERT seed** |
| GET/PATCH | `/admin/profile` | `admin_accounts` (MSB_DB) | SELECT / **UPDATE** |
| POST | `/admin/change-password` | `admin_accounts` (MSB_DB) | **UPDATE** |
| GET | `/admin/machines`, `/admin/machine-stats`, `/admin/package-codes`, `/admin/package-checkins` | MSB_DB | SELECT |
| DELETE | `/admin/package-checkins` | `package_checkins`,`package_codes` (MSB_DB) | **DELETE hàng loạt** |
| GET/PATCH | `/admin/settings` | `app_settings` | SELECT / **BATCH UPSERT** |
| GET | `/sales` | `app_sales` | SELECT |
| DELETE | `/machine/:hwid/event/:eventId` | `sessions`,`revenue`,`events` | **DELETE BATCH 3 bảng** |
| POST | `/sepay/webhook` | `app_sales`,`payment_intents`,`machines`,`plans` | SELECT + **BATCH UPDATE/INSERT** |
| GET | `/media/*` | không chạm D1 | proxy S3 |

#### 4.2.3 Chi tiết request/response các route Desktop then chốt

**`GET /machine/:hwid`** — [DynamoDBClient.cpp:79-82](src/backend/DynamoDBClient.cpp#L79-L82)
* Query params: không. Body: không.
* Response: `{success, found, machine:{hwid, sk, device_name, brand, owner_email, owner_name, activate, activated_at, license_start, license_end, registered_at, plan, device_tier, trial_used, studio_id, capabilities}}`
* Cột đọc: toàn bộ `machines.*` + `studios.studio_id` + `plans.capabilities`.
* Transaction: không. Retry: có, tối đa 3 lần (chỉ khi tắt bypass) — [MachineAuthenticator.cpp:426-435](src/backend/MachineAuthenticator.cpp#L426-L435).
* Ghi trùng: không (read-only).

**`POST /machine/:hwid`** — [DynamoDBClient.cpp:84-94](src/backend/DynamoDBClient.cpp#L84-L94)
* Body: `{device_name, owner_email?, owner_name?, brand?}`.
* Nếu HWID chưa có: **INSERT** `machines` với `activate=1`, `plan='trial'`,
  `device_tier='trial'`, `trial_used=1`, `license_end = now + app_settings.trial_days` (mặc định 3 ngày).
  Với tenant MSB: `license_end = now + 120 tháng`, `plan='msb'`, `device_tier='premium'`.
* Nếu HWID đã có: **UPDATE** brand/owner_email/owner_name (COALESCE NULLIF — không ghi đè bằng rỗng),
  **không đụng** activate/license/trial.
* Kèm `ensureStudio()` → **INSERT/UPSERT** bảng `studios`.
* Transaction: không (2 câu lệnh rời).
* Idempotent: **có** (nhánh existing chỉ update, không cấp lại trial).
* Ghi trùng: không tạo dòng trùng (`hwid` là PRIMARY KEY).

**`PUT /machine/:hwid/session`** — [DynamoDBClient.cpp:119-147](src/backend/DynamoDBClient.cpp#L119-L147)
* Body: 15 field vòng đời chụp (xem `syncSessionData`).
* UPSERT theo `PRIMARY KEY (hwid, event_id, session_id)` + guard
  `WHERE excluded.status_version >= COALESCE(sessions.status_version, 0)`.
* Idempotent: **có**. Bản cập nhật đến trễ không ghi đè bản mới.
* Retry: **KHÔNG**. Fire-and-forget.

**`POST /machine/:hwid/revenue`** — [DynamoDBClient.cpp:149-185](src/backend/DynamoDBClient.cpp#L149-L185)
* `revenue_id = SHA256("hwid|event_id|session_id|source|recorded_at")` — tính **cả ở client
  lẫn ở Worker** (`makeRevenueId`, index.ts:46-50) nên hai bên ra cùng giá trị.
* Worker còn dò thêm dòng cũ theo tổ hợp (hwid, event_id, session_id, source, recorded_at)
  để tái dùng `revenue_id` cũ → chống trùng cho dữ liệu legacy.
* `ON CONFLICT(revenue_id) DO UPDATE` → **idempotent**.
* Retry: **KHÔNG**. Fire-and-forget.

**`POST /upload/presign`** — [index.ts:2831-2877](cloudflare/worker/src/index.ts#L2831-L2877)
* Body: `{hwid, event_id, session_id, object_key, content_type}`.
* Kiểm `object_key` an toàn + phải bắt đầu bằng `{hwid}/{event_id}/{session_id}/`.
* **KIỂM TRA D1:** `SELECT activate FROM machines WHERE hwid = ?`;
  nếu không có dòng hoặc `activate != 1` → **HTTP 403 `machine_not_active`**.
* Đây là **cổng khoá duy nhất còn lại do D1 điều khiển** (chi tiết ở mục 4.5).

---

### 4.3 Schema D1 thực tế

Nguồn: [schema.sql](cloudflare/worker/schema.sql) + migrations 001→016 +
[msb_schema.sql](cloudflare/worker/migrations/msb_schema.sql).

> Lưu ý: đây là schema **theo mã nguồn**. Schema thật trên production chưa được
> đọc (yêu cầu chạy `wrangler d1 execute --remote "PRAGMA table_info(...)"`, cần
> phê duyệt thủ công). Nếu có sai lệch giữa file và production thì **CHƯA XÁC ĐỊNH**.

#### DB 1 — `boothme_prod` (binding `DB`)

**`machines`** — tạo bởi `schema.sql`; mở rộng bởi `001_owner.sql`, `003_licensing.sql`.

| Cột | Kiểu | Ràng buộc / Default | Ghi chú |
| --- | --- | --- | --- |
| `hwid` | TEXT | **PRIMARY KEY** | SHA-256(CPUID+MAC+VolumeSerial)[0:16] |
| `sk` | TEXT | DEFAULT `'MACHINE'` | di sản DynamoDB |
| `device_name` | TEXT | | |
| `brand` | TEXT | | tên studio |
| `owner_email` | TEXT | | email Google chủ studio (lowercase) |
| `owner_name` | TEXT | | |
| `activate` | INTEGER | DEFAULT `0` | **0=chưa kích hoạt, 1=đã kích hoạt** |
| `activated_at` | TEXT | | |
| `license_start` | TEXT | | |
| `license_end` | TEXT | | hạn dùng ISO |
| `registered_at` | TEXT | | |
| `plan` | TEXT | | `'trial'` \| mã gói \| NULL |
| `device_tier` | TEXT | | `trial\|event\|studio\|event_studio\|studio_selfbooth\|premium` |
| `trial_used` | INTEGER | DEFAULT `0` | chống reset trial |

Index: `idx_machines_brand (brand)`, `idx_machines_owner (owner_email)`.
Foreign key: **không có** (D1/SQLite không khai báo FK ở đây).
Trigger: **không có**.
Code sử dụng: index.ts (nhiều route), `MachineAuthenticator`, `S3Uploader` (qua presign).

**`studios`** — `002_studios.sql`

| Cột | Kiểu | Ràng buộc |
| --- | --- | --- |
| `studio_id` | INTEGER | **PK AUTOINCREMENT** |
| `owner_email` | TEXT | **UNIQUE** |
| `brand` | TEXT | |
| `name` | TEXT | |
| `created_at` | TEXT | |

Dùng làm tiền tố URL gallery `/{studio_id}/{hwid}/{eventId}/{sessionId}`.

**`events`**

| Cột | Kiểu | Default |
| --- | --- | --- |
| `hwid` | TEXT | PK phần 1 |
| `event_id` | INTEGER | PK phần 2 |
| `event_name` | TEXT | |
| `total_photos_captured` | INTEGER | 0 |
| `prints_cut` | INTEGER | 0 |
| `prints_nocut` | INTEGER | 0 |
| `updated_at` | TEXT | |

PK: `(hwid, event_id)`. Index: `idx_events_hwid (hwid)`.

**`sessions`** — `schema.sql` + `007_capture_attempts.sql`

| Cột | Kiểu | Default | Chủ sở hữu dữ liệu |
| --- | --- | --- | --- |
| `hwid` | TEXT | | PK 1 |
| `event_id` | INTEGER | | PK 2 |
| `session_id` | TEXT | | PK 3 |
| `printer_type` | TEXT | | desktop |
| `photos_captured` | INTEGER | 0 | desktop |
| `prints_cut` / `prints_nocut` / `total_prints` | INTEGER | 0 | desktop |
| `status` | TEXT | | desktop |
| `updated_at` | TEXT | | worker (nowIso) |
| `expected_photos` | INTEGER | 0 | desktop |
| `capture_started_at` | TEXT | | desktop |
| `ended_at` | TEXT | | desktop |
| `status_updated_at` | TEXT | | desktop |
| `failure_code` / `failure_message` | TEXT | | desktop |
| `camera_error_count` | INTEGER | 0 | desktop |
| `had_camera_error` | INTEGER | 0 | desktop |
| `status_version` | INTEGER | 0 | desktop (guard chống ghi đè ngược) |
| `resolution_state` | TEXT | | **web/portal** |
| `resolution_type` | TEXT | | **web/portal** |
| `refund_amount` | INTEGER | 0 | **web/portal** |
| `resolution_note` | TEXT | | **web/portal** |
| `resolved_at` / `resolved_by` | TEXT | | **web/portal** |

PK: `(hwid, event_id, session_id)`. Index: `idx_sessions_hwid_ev (hwid, event_id)`.

**`revenue`** — tái tạo bởi `005_revenue_v2.sql` (DROP + RENAME)

| Cột | Kiểu | Default |
| --- | --- | --- |
| `revenue_id` | TEXT | **PRIMARY KEY** (SHA-256 xác định) |
| `hwid` | TEXT | |
| `event_id` | INTEGER | |
| `event_name` | TEXT | |
| `session_id` | TEXT | |
| `recorded_at` | TEXT | |
| `print_count` | INTEGER | 0 |
| `amount_required` | INTEGER | 0 |
| `cash_received` | INTEGER | 0 |
| `transfer_amount` | INTEGER | 0 |
| `change_amount` | INTEGER | 0 |
| `payment_method` | TEXT | |
| `employee_id` | INTEGER | 0 |
| `shift` | TEXT | `''` |
| `source` | TEXT | `'session'` |
| `received_amount` | INTEGER | 0 |
| `voucher_amount` | INTEGER | 0 |
| `note` | TEXT | `''` |
| `synced_at` | TEXT | |

Index: `idx_revenue_hwid_ev`, `idx_revenue_hwid_time`.

**`plans`** — `code` PK; `name, description, duration_months, price_per_year,
device_tier, capabilities(JSON), is_contact, active, sort, updated_at`.
Seed: `event`, `studio`, `event_studio`, `studio_selfbooth`, `premium`.

**`app_settings`** — `key` PK, `value`, `updated_at`.
Key đã biết: `trial_days`, `sepay_bank`, `sepay_account`, `sepay_holder`,
`sepay_api_key`, `addon_event`, `addon_studio`, `addon_selfbooth`,
`year_discount_pct`, `discount_floor_pct`.

**`payment_intents`** — `code` PK; `hwid, plan_code, amount, years, kind, status, created_at, paid_at, sepay_ref`. Index `idx_intents_hwid`.

**`app_sales`** — `id` PK AUTOINCREMENT; `hwid, owner_email, plan_code, amount, sepay_ref UNIQUE, content, paid_at, created_at`. `sepay_ref UNIQUE` = **cơ chế idempotency cho webhook SePay**.

**`vouchers`** — PK `(owner_email, code)`; 24 cột (xem schema.sql:122-149).
Index `idx_vouchers_owner`, `idx_vouchers_package (package_key, used, created_at)`.

**`loyalty_codes`** — `016`; PK `(owner_email, code)`; `max_uses`, `used_count`, `revoked`.
**`loyalty_redemptions`** — `id` PK AUTOINCREMENT; nhật ký lượt dùng.

**`studio_staff`** — PK `(owner_email, staff_email)`; `staff_name`, `permissions` (JSON array), `created_at`. Index `idx_staff_email`.

**`voucher_notes` / `voucher_prices` / `voucher_durations`** — `id` PK AUTOINCREMENT + `owner_email` + giá trị + `created_at`. Có **seed lazy** ở Worker.

**`qr_login_sessions`** — `012`; `id` PK AUTOINCREMENT, `code` **UNIQUE**,
`hwid`, `owner_email`, `purpose` **CHECK IN ('login','security')**, `status`
DEFAULT `'pending'`, `approver_*`, `created_at`, `approved_at`, `used_at`,
`expires_at` (created_at + 180s). Index `idx_qr_owner`, `idx_qr_hwid`.

**`package_presets`** — `id` PK AUTOINCREMENT; `owner_email, name, price, minutes, prints, active, created_at`.

**`package_checkins`** và **`admin_accounts`** cũng tồn tại trong `schema.sql` của
DB chính (di sản migration 014) nhưng **thực tế được Worker dùng ở `MSB_DB`**.

#### DB 2 — `msb_photobooth` (binding `MSB_DB`)

Bản sao gần như hoàn toàn của DB chính ([msb_schema.sql](cloudflare/worker/migrations/msb_schema.sql)),
`machines.activate` DEFAULT **1** và `trial_used` DEFAULT **1**, cộng thêm:

**`package_codes`** (chỉ có ở MSB_DB)

| Cột | Kiểu | Default |
| --- | --- | --- |
| `code` | TEXT | **PRIMARY KEY** |
| `owner_email` / `machine_hwid` | TEXT | `''` |
| `type` | TEXT | `'package_code'` |
| `package_key` | TEXT | NOT NULL (`discovery\|signature\|elite`) |
| `package_name` | TEXT | NOT NULL |
| `phone` / `session_id` | TEXT | `''` |
| `created_via` | TEXT | `'web'` |
| `created_by` / `created_at` | TEXT | |
| `used` / `revoked` | INTEGER | 0 |
| `used_at`, `redeemed_hwid`, `redeemed_session_id`, `note` | TEXT | |

Index: `idx_package_codes_package`, `idx_package_codes_machine`, `idx_package_codes_owner`.
Tiền tố mã: `DIS####`, `SIG####`, `ELITE####`.

**`package_checkins`** — `id` PK AUTOINCREMENT; `machine_hwid, owner_email,
session_id, package_key, package_label, phone, code, code_source, created_at,
paper_print_requested, cup_print_requested, cloud_synced, cloud_error`.
**Không có UNIQUE constraint** → xem mục rủi ro 4.5.

**`admin_accounts`** — `username` PK; `password_hash` = SHA-256(`salt:password`),
`salt`, `name`, `email`, `created_at`, `updated_at`.
Tài khoản mặc định hard-code trong Worker: `msb.com.vn` / `pbmsb`
([index.ts:2163-2164](cloudflare/worker/src/index.ts#L2163-L2164)).

---

### 4.4 Bản đồ dữ liệu

Phân loại: **A** bắt buộc cho vận hành tại máy · **B** dữ liệu quản trị cloud ·
**C** cần đồng bộ · **D** có thể cache local · **E** chỉ upload nền ·
**F** có thể bỏ · **G** nhạy cảm.

| Bảng D1 | Loại | Lý do | Có bản local tương ứng? |
| --- | --- | --- | --- |
| `machines` | **B + G** | Danh bạ quản trị. HWID + email chủ = PII. Máy **không cần** để chạy. | Có — `machines` (SQLite) |
| `studios` | **B + D** | Chỉ cung cấp `studio_id` cho URL gallery. Đã cache ở `QSettings("BoothOS","Machine")/studio_id`. | Có (QSettings) |
| `events` | **E** | Chỉ để báo cáo web. Nguồn thật là SQLite `events`. | Có — `events` |
| `sessions` | **E** | Báo cáo lượt chụp. Nguồn thật là SQLite `sessions`. | Có — `sessions` |
| `sessions.resolution_*` | **C** | Web ghi → desktop nên đọc về (hiện **chưa** đọc về). | Có cột nhưng chưa sync |
| `revenue` | **E + G** | Doanh thu. Nguồn thật là SQLite `revenue_records`. Dữ liệu tài chính. | Có — `revenue_records` |
| `vouchers` | **C** | Kho mã dùng chung cả studio, nhiều máy. Cần đồng bộ 2 chiều. | Có — `vouchers` (SQLite) |
| `loyalty_codes` / `loyalty_redemptions` | **C** | Mã dùng nhiều lần, đếm lượt tập trung. | **KHÔNG** |
| `voucher_notes/prices/durations` | **D** | Preset dropdown, chỉ đọc. | **KHÔNG** — cần cache |
| `package_presets` | **D** | Preset gói chụp, chỉ đọc. | **KHÔNG** — cần cache |
| `studio_staff` | **C + G** | Danh sách nhân viên → đồng bộ về `employees` local (đã có, xem main.qml `onStudioInfoChanged`). | Có — `employees` |
| `qr_login_sessions` | **B** | Chỉ dùng khi đăng nhập QR (online-only theo bản chất). | Không cần |
| `plans`, `app_settings`, `payment_intents`, `app_sales` | **B + G** | Thương mại bán app. Máy khách **không cần**. | Không cần |
| `package_codes` (MSB) | **C** | Mã gói dùng chung mọi máy MSB. | **KHÔNG** |
| `package_checkins` (MSB) | **E** | Nhật ký check-in để báo cáo. | **KHÔNG** |
| `admin_accounts` (MSB) | **B + G** | Tài khoản admin web. | Không cần |

**Dữ liệu bắt buộc phải có để phần mềm chạy:** không có bảng D1 nào.
Toàn bộ dữ liệu vận hành đã có bản local. (Ngoại lệ: `machines.activate` đang
gián tiếp chặn upload ảnh — mục 4.5.)

**Dữ liệu tuyệt đối không được mất:** `revenue` (doanh thu), `sessions` (lượt chụp),
`vouchers`/`package_codes` đã phát hành cho khách. Cả ba đều có/nên có bản local
làm nguồn chân lý.

**Dữ liệu có thể mất mà không ảnh hưởng vận hành:** `qr_login_sessions`,
`voucher_notes/prices/durations` (có default seed), `app_sales` (kế toán bán app).

---

### 4.5 Các thao tác có nguy cơ ảnh hưởng production

#### R-01 · `GET` nhưng lại **GHI** vào D1 (seed lazy) — RỦI RO TRUNG BÌNH

| Route | Hành vi ẩn |
| --- | --- |
| `GET /portal/:email/voucher-notes`, `GET /machine/:hwid/voucher-notes` | Nếu danh sách rỗng → **INSERT 4 dòng** vào `voucher_notes` ([index.ts:2249-2263](cloudflare/worker/src/index.ts#L2249-L2263)) |
| `GET …/voucher-prices` | Nếu rỗng → **INSERT 5 dòng** `voucher_prices` |
| `GET …/voucher-durations` | Nếu rỗng → **INSERT 3 dòng** `voucher_durations` |
| `GET/PATCH /admin/profile`, `POST /admin/login`, `POST /admin/change-password` | `ensureMsbAdmin()` → **INSERT** `admin_accounts` nếu chưa có ([index.ts:2215-2228](cloudflare/worker/src/index.ts#L2215-L2228)) |

→ **Không thể coi bất kỳ endpoint GET nào là "read-only" một cách an toàn.**
Trong giai đoạn nghiên cứu, nếu cần đọc D1 phải dùng
`wrangler d1 execute --remote --command "SELECT ..."` (chỉ SELECT), **không** gọi
qua Worker.

#### R-02 · `POST /machine/:hwid` tự tạo dòng + cấp trial — RỦI RO TRUNG BÌNH

Chạy mỗi khi một HWID lạ khởi động app ([index.ts:1128-1148](cloudflare/worker/src/index.ts#L1128-L1148)).
Ghi `machines` + `studios`. Với bypass đang bật, desktop **vẫn** gọi route này
best-effort ([MachineAuthenticator.cpp:412](src/backend/MachineAuthenticator.cpp#L412)).
→ Mỗi lần build/test trên máy mới sẽ tạo rác trong bảng `machines` production.

#### R-03 · `POST /machine/:hwid/package-checkins` — **NGUY CƠ GHI TRÙNG** — RỦI RO CAO

[index.ts:1711-1720](cloudflare/worker/src/index.ts#L1711-L1720): `INSERT INTO package_checkins`
thuần, bảng **không có UNIQUE** trên `(machine_hwid, session_id)`, `id` là AUTOINCREMENT.
Nếu client retry hoặc request timeout rồi gửi lại → **tạo bản ghi trùng**, làm sai
thống kê `/admin/machine-stats`.
(Phần `package_codes` kèm theo dùng `INSERT OR IGNORE` nên an toàn.)

#### R-04 · `DELETE` xoá thật, không soft-delete — RỦI RO CAO

| Route | Tác động |
| --- | --- |
| `DELETE /machine/:hwid/event/:eventId` | `batch([DELETE sessions, DELETE revenue, DELETE events])` — **xoá cả doanh thu** ([index.ts:1995-2004](cloudflare/worker/src/index.ts#L1995-L2004)) |
| `DELETE /portal/:email/vouchers` (lô) | `DELETE FROM vouchers` từng mã, kể cả mã đã dùng |
| `DELETE /machine/:hwid/vouchers` (lô) | `DELETE … WHERE code IN (...)` theo lô 100 |
| `DELETE /admin/package-checkins` | Xoá `package_checkins` **và** `package_codes` tương ứng |
| `DELETE /portal/:email/package-presets/:id`, `voucher-notes/:id`, `voucher-prices/:id`, `voucher-durations/:id` | Xoá cứng |

Không có bảng lưu vết xoá. Không có backup tự động.

#### R-05 · `POST /sepay/webhook` — công khai, sửa `machines.activate` — RỦI RO CAO

[index.ts:3019-3088](cloudflare/worker/src/index.ts#L3019-L3088). Không dùng bearer token;
chỉ so `Authorization: Apikey <app_settings.sepay_api_key>`. Nếu key rỗng → mọi
request bị từ chối (an toàn). Nếu key rò rỉ → attacker có thể `UPDATE machines SET
activate=1, plan=…, license_end=…` cho bất kỳ HWID nào.
Idempotency: có, qua `app_sales.sepay_ref UNIQUE` + kiểm tra `SELECT 1 … WHERE sepay_ref = ?`.

#### R-06 · Migration D1 — **không tự chạy**, nhưng nguy hiểm nếu chạy nhầm — RỦI RO CAO

* Worker **không** có code tự chạy migration khi khởi động. ✔
* Migration được áp thủ công bằng `wrangler d1 execute --remote --file=...`.
* `package.json` có script nguy hiểm:
  ```json
  "db:init:remote": "wrangler d1 execute vietbooth --remote --file=./schema.sql"
  ```
  Tên DB `vietbooth` **không khớp** `wrangler.toml` (`boothme_prod`) → chạy sẽ lỗi
  "database not found" (may mắn là an toàn), nhưng nếu ai đó "sửa cho đúng tên"
  rồi chạy thì `schema.sql` sẽ `INSERT OR IGNORE INTO plans` (an toàn) và
  `CREATE TABLE IF NOT EXISTS` (an toàn) — nhưng vẫn không nên chạy.
* **Script cực nguy hiểm nếu chạy nhầm:** `migrations/005_revenue_v2.sql` chứa
  ```sql
  DROP TABLE revenue;
  ALTER TABLE revenue_new RENAME TO revenue;
  ```
  Chạy lại lần 2 trên production sẽ **mất/hỏng toàn bộ bảng doanh thu**.
  `004_plans_v2.sql` chứa `DELETE FROM plans WHERE code IN (...)`.
* Mọi migration `ALTER TABLE … ADD COLUMN` chỉ chạy được 1 lần (D1 không hỗ trợ
  `IF NOT EXISTS`) → chạy lại sẽ lỗi giữa chừng, để lại schema nửa vời.

#### R-07 · **Blocking network trên UI thread** — RỦI RO CAO cho trải nghiệm

[DynamoDBClient::blockingRequest](src/backend/DynamoDBClient.cpp#L189-L243) dùng
`QEventLoop` với `transferTimeout=15s` + guard 16s. Được gọi bởi:
`validateVoucherCloud`, `redeemVoucherCloud`, `deleteVoucherCloud`,
`pushVouchersCloudSync`, `generateVouchersCloud`, `voucherPresetsCloud`
(hàm cuối gọi **3 request nối tiếp → tối đa ~48 giây**).

→ Khi Cloudflare/D1 chậm hoặc mất mạng, giao diện **đứng hình** tới 16–48 giây.
Đây là vi phạm trực tiếp nguyên tắc "cloud không được chặn UI".
Giảm nhẹ hiện tại: `kCodesLocalFirst = true` ([EventManager.cpp:4590](src/backend/EventManager.cpp#L4590))
khiến mã do chính máy tạo được xử lý hoàn toàn local, không gọi cloud. Nhưng mã
do **web** tạo vẫn đi đường blocking.

#### R-08 · **Không có hàng đợi đồng bộ** cho session/event/revenue — RỦI RO CAO (mất dữ liệu cloud)

[DynamoDBClient::sendRequest](src/backend/DynamoDBClient.cpp#L43-L77) là
fire-and-forget. Khi lỗi, `onNetworkReply` chỉ `qCritical()` + `emit operationError`.
**Không retry. Không queue. Không đánh dấu lại.**

SQLite local **đã có cột `sessions.sync_pending`** (migration v23,
[DatabaseManager.cpp:2281](src/backend/DatabaseManager.cpp#L2281)) nhưng
**không có code nào đọc cột này để gửi lại** → cột chết.

→ Mất mạng trong lúc chụp = lượt chụp/doanh thu đó **vĩnh viễn không lên cloud**.
Dữ liệu local vẫn đủ (an toàn cho khách), nhưng dashboard web sẽ thiếu.

#### R-09 · `machines.activate` chặn upload ảnh — RỦI RO CAO

[index.ts:2851-2855](cloudflare/worker/src/index.ts#L2851-L2855):

```ts
const machine = await db.prepare("SELECT activate FROM machines WHERE hwid = ?").bind(hwid).first();
if (!machine || Number(machine.activate ?? 0) !== 1) {
  return json({ success: false, error: "machine_not_active" }, 403);
}
```

→ Nếu admin tắt `activate` trên D1, hoặc máy chưa từng đăng ký thành công, thì
**ảnh không upload được, QR gallery không hoạt động** — dù app vẫn chụp/in bình thường.
Đây là **điểm khoá duy nhất còn lại mà D1 điều khiển được** đối với client.
Ảnh không mất: S3Uploader stage vào thư mục pending và retry mỗi 60s
([S3Uploader.cpp:343-352](src/backend/S3Uploader.cpp#L343-L352)) — nhưng sẽ retry mãi mãi.

#### R-10 · Token production nằm plaintext trong repo — RỦI RO CAO

* [key.json](key.json) — `cloud_api.api_token` + Google `client_secret`.
* [web/portal/config.js](web/portal/config.js) — **cùng token đó**, phục vụ từ web tĩnh
  → bất kỳ ai mở portal đều đọc được token toàn quyền Worker.
* Token này được installer copy vào máy khách ([installer.iss:90](installer.iss#L90)).

Không nằm trong phạm vi nhiệm vụ này, nhưng phải ghi nhận.

#### R-11 · Code chạy khi app khởi động (client) có chạm cloud

| Thứ tự | Hành vi | File | Chặn UI? |
| --- | --- | --- | --- |
| 1 | `DatabaseManager::initialize()` → `createTables()` → **auto-migration SQLite v1→v26** | [main.cpp:175-181](src/main.cpp#L175-L181) | Có (đồng bộ). Thất bại → `return -1`, **app thoát** |
| 2 | `ConfigManager::loadConfig(key.json)` | [main.cpp:186-189](src/main.cpp#L186-L189) | Không chặn (chỉ cảnh báo) |
| 3 | `MachineAuthenticator` ctor → sinh HWID (local, nhanh) | [MachineAuthenticator.cpp:52](src/backend/MachineAuthenticator.cpp#L52) | Không |
| 4 | `GoogleAuthManager::restoreSession()` — đọc QSettings, **không mạng** | [GoogleAuthManager.cpp:153-162](src/backend/GoogleAuthManager.cpp#L153-L162) | Không |
| 5 | `HttpBridge::start(5514)` — local socket | [main.cpp:298](src/main.cpp#L298) | Không |
| 6 | +500 ms sau khi QML nạp: `machineAuth->authenticate()` **nếu** đã có Google session | [main.cpp:403-414](src/main.cpp#L403-L414) | Không (async) |
| 7 | `qrLoginManager.fetchStudioInfo(hwid)` | [main.qml:208](qml/main.qml#L208) | Không (async) |
| 8 | +5 s: `S3Uploader::retryPendingSessions()` | [S3Uploader.cpp:355-358](src/backend/S3Uploader.cpp#L355-L358) | Không (worker thread) |

**Không có code nào tự chạy migration D1 khi Worker khởi động.** ✔
**Không có code nào tự deploy.** ✔

---

## 5. Trả lời trực tiếp 30 câu hỏi nghiên cứu

| # | Câu hỏi | Trả lời |
| --- | --- | --- |
| 1 | Ứng dụng nào kết nối D1 | Chỉ Cloudflare Worker `boothme-api`. Desktop + web portal đi qua Worker. |
| 2 | Client desktop gọi trực tiếp Cloudflare? | **Không** gọi D1 trực tiếp; gọi Worker REST. |
| 3 | Worker hay API trung gian | Worker `boothme-api` là API trung gian duy nhất. |
| 4 | Worker nào binding D1 | `boothme-api` ([wrangler.toml](cloudflare/worker/wrangler.toml)). |
| 5 | Tên binding | `DB` và `MSB_DB`. |
| 6 | Database ID theo môi trường | `DB`=3d092835-…, `MSB_DB`=fd5284fa-…. Chỉ 1 môi trường. |
| 7 | Prod & dev dùng chung? | **Có** — không có env riêng. `wrangler dev --remote` chạm production. |
| 8 | Endpoint đọc | Xem bảng 4.2 (mọi route GET + phần SELECT của route ghi). |
| 9 | Endpoint ghi (INSERT) | `POST /machine/:hwid`, `/…/revenue`, `/…/vouchers*`, `/…/qr-session`, `/…/package-checkins`, `/portal/:email/{vouchers,loyalty-codes,staff,voucher-*,package-presets}`, `POST /plans`, seed lazy trong GET. |
| 10 | Endpoint cập nhật | `PATCH /machine/:hwid`, `PUT /…/event`, `PUT /…/session`, `PATCH /…/capture-attempts/…/resolution`, `POST /…/vouchers/:code/redeem`, `PATCH /plans/:code`, `PATCH /admin/settings`, `POST /sepay/webhook`, lazy-expire QR. |
| 11 | Endpoint xóa | `DELETE /machine/:hwid/event/:eventId`, `DELETE …/vouchers[/:code]`, `DELETE /portal/:email/{vouchers,loyalty-codes,staff,voucher-*,package-presets}`, `DELETE /admin/package-checkins`. |
| 12 | Bảng lưu gì | HWID/License/Thiết bị → `machines`. Người dùng → `studios`, `studio_staff`, `admin_accounts`. Phiên chụp → `sessions`. Doanh thu → `revenue`, `app_sales`. Ảnh → **không lưu D1** (S3 + local FS). Frame → **không lưu D1** (local FS). Cấu hình → `app_settings`, `plans`, `package_presets`, `voucher_*`. Mã kích hoạt → `vouchers`, `loyalty_codes`, `package_codes`, `payment_intents`, `qr_login_sessions`. Trạng thái ứng dụng → `machines.activate/device_tier/plan`. |
| 13 | Dữ liệu bắt buộc để chạy | **Không có** (sau khi bypass). Ngoại lệ gián tiếp: `machines.activate=1` để upload ảnh. |
| 14 | Chỉ phục vụ đồng bộ cloud | `events`, `sessions`, `revenue`, `package_checkins`. |
| 15 | Có thể chuyển về local | `voucher_notes/prices/durations`, `package_presets`, `studio_staff`, `studios.studio_id`. |
| 16 | Cần đồng bộ 2 chiều | `vouchers`, `loyalty_codes`, `package_codes`, `sessions.resolution_*`, `studio_staff`. |
| 17 | Chỉ upload 1 chiều | `events`, `sessions` (trừ resolution), `revenue`, `package_checkins`. |
| 18 | Có thể mất | `qr_login_sessions`, preset voucher (có default), `app_sales`. |
| 19 | Tuyệt đối không mất | `revenue`, `sessions`, `vouchers`/`package_codes` đã phát hành. |
| 20 | Có transaction? | **Không có transaction thật.** Chỉ có `D1.batch()` (atomic trong 1 batch) ở: xoá event, webhook SePay, `PATCH /admin/settings`, seed preset, push voucher, generate package_code. Các route khác chạy nhiều câu lệnh rời rạc → có thể ghi nửa vời. |
| 21 | Có retry? | Chỉ `MachineAuthenticator` (3 lần, và **chỉ khi tắt bypass**) và `S3Uploader` (60s + sự kiện online). **Không có retry cho session/event/revenue/voucher.** |
| 22 | Có queue khi mất mạng? | **Chỉ cho file ảnh** (S3Uploader stage vào thư mục pending). **Không** cho dữ liệu D1. |
| 23 | Có ghi trùng? | Có nguy cơ ở `package_checkins` (R-03). Các bảng khác đều idempotent nhờ PK + UPSERT. |
| 24 | Nguy cơ mất dữ liệu khi timeout? | **Có** — session/event/revenue fire-and-forget, timeout = mất bản đồng bộ vĩnh viễn (dữ liệu local vẫn còn). |
| 25 | Client gửi lại nhiều lần? | Có với `S3Uploader` (đã khử trùng bằng `m_inFlightKeys`) và `MachineAuthenticator` polling 10s khi Pending. |
| 26 | Có idempotency? | Có, dạng "khoá tự nhiên": `revenue_id` SHA-256, PK `(hwid,event_id,session_id)` + `status_version`, `sepay_ref UNIQUE`, `INSERT OR IGNORE` cho voucher, `UPDATE … WHERE used=0` cho redeem. **Không có** `idempotency_key` tường minh, **không có** cho `package_checkins`. |
| 27 | Có backup? | **KHÔNG** — không có script/cron/export nào trong repo. |
| 28 | Có restore? | **KHÔNG**. |
| 29 | Tự đồng bộ schema khi khởi động? | Worker: **không**. Desktop SQLite: **có** — `createTables()` chạy migration v1→v26 mỗi lần mở app. |
| 30 | Code tự chạy migration production? | Worker: **không**. Nguy cơ đến từ script thủ công trong `package.json` (R-06). |

---

## 6. Tóm tắt rủi ro theo mức độ

| Mã | Rủi ro | Mức |
| --- | --- | --- |
| R-09 | `machines.activate` khoá upload ảnh qua `/upload/presign` | 🔴 CAO |
| R-08 | Không có sync queue → mất dữ liệu cloud khi offline | 🔴 CAO |
| R-07 | 6 lời gọi mạng **blocking UI** tới 16–48 s | 🔴 CAO |
| R-06 | `005_revenue_v2.sql` chứa `DROP TABLE revenue` — chạy nhầm = mất doanh thu | 🔴 CAO |
| R-04 | DELETE xoá cứng, không backup, không audit | 🔴 CAO |
| R-05 | Webhook SePay công khai sửa được `machines.activate` | 🔴 CAO |
| R-10 | API token toàn quyền lộ trong `web/portal/config.js` | 🔴 CAO |
| R-03 | `package_checkins` ghi trùng khi retry | 🔴 CAO |
| R-01 | GET có tác dụng phụ ghi D1 (seed lazy) | 🟠 TRUNG BÌNH |
| R-02 | `POST /machine/:hwid` tạo rác `machines` từ máy test | 🟠 TRUNG BÌNH |
| R-11 | Không có auto-migration D1 / auto-deploy | 🟢 THẤP (tốt) |
| — | D1 `photobooth / a69d02e4-…` chưa đấu nối, mục đích **CHƯA XÁC ĐỊNH** | ⚪ CẦN XÁC NHẬN |
