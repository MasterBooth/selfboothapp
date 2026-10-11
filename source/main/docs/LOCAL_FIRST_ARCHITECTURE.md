# LOCAL-FIRST ARCHITECTURE

Nguyên tắc: **Local là nguồn vận hành chính. Cloud là nơi đồng bộ và quản trị từ xa.
Cloud không có quyền khoá phần mềm.**

Ngày lập: 2026-08-03.

---

## 1. Kiến trúc mục tiêu

```text
┌──────────────────────────────────────────────────────────────────────────┐
│  BOOTHME.exe (Qt/QML, Windows)                                           │
│                                                                          │
│  Khởi động:                                                              │
│    1. Load key.json (lỗi → vẫn chạy, chỉ tắt tính năng cloud)            │
│    2. Mở SQLite local (lỗi → fallback/tạo mới, KHÔNG thoát)             │
│    3. Sinh HWID (local, CPUID+MAC+VolumeSerial)                          │
│    4. Cấp đủ capabilities tại chỗ                                        │
│    5. Khởi tạo camera / máy in / bill acceptor / relay                    │
│    6. Mở giao diện chính              ◄── KHÔNG CHỜ MẠNG, KHÔNG CHỜ D1   │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ TẦNG VẬN HÀNH (LOCAL AUTHORITATIVE)                                │  │
│  │  SQLite {app}\data\photobooth.db                                   │  │
│  │   events · sessions · photos · revenue_records · vouchers          │  │
│  │   employees · app_settings · event_settings · printer_settings     │  │
│  │  Filesystem                                                        │  │
│  │   Pictures\Photobooth\Events\<event>\{Originals,Final,Layouts}     │  │
│  │   {app}\filters, {app}\stickers, {app}\pending_uploads             │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                              │ ghi xong = XONG                           │
│                              ▼                                           │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │ TẦNG ĐỒNG BỘ (MỚI — Phase 6)                                       │  │
│  │  sync_queue · sync_state · error_logs   (SQLite, cùng file)        │  │
│  │  CloudSyncService (thread nền, backoff + jitter, idempotency_key)  │  │
│  │  S3Uploader        (đã có: staging folder + retry 60s)             │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                              │ best-effort, KHÔNG chặn UI                │
└──────────────────────────────┼───────────────────────────────────────────┘
                               ▼
              Cloudflare Worker "boothme-api"  ──►  D1 (boothme_prod / msb_photobooth)
                               │                    AWS S3 (ảnh/video)
                               ▼
              Web Portal (Vercel) · Web Gallery · CMS
              → chỉ đọc báo cáo, quản trị từ xa
              → KHÔNG có quyền chặn app khởi động/chụp/in
```

---

## 2. Nguyên tắc thiết kế (bất biến)

| # | Nguyên tắc | Kiểm chứng |
| --- | --- | --- |
| P1 | Không có nhánh code nào thoát app vì lý do cloud/license | Grep `exit(`/`quit(` không được xuất hiện trong `MachineAuthenticator`, `DynamoDBClient`, `LicenseStore` |
| P2 | Không có lời gọi mạng đồng bộ (blocking) trên UI thread | `blockingRequest` phải bị loại bỏ hoặc chuyển sang thread nền |
| P3 | Mọi thao tác nghiệp vụ hoàn thành khi **SQLite commit xong**, không chờ cloud | Ghi local trước, enqueue sau |
| P4 | Cloud lỗi = `switchToOfflineMode()`, không phải `closeApplication()` | Xem mục 5 |
| P5 | ID của mọi bản ghi tạo tại máy là **UUID sinh tại local**, không dùng AUTOINCREMENT của D1 | Xem mục 6 |
| P6 | Mỗi sự kiện đồng bộ có `event_id` / `idempotency_key` duy nhất | Xem [CLOUD_SYNC_DESIGN.md](CLOUD_SYNC_DESIGN.md) |
| P7 | Đồng hồ máy khách **không đáng tin** → không dùng `updated_at` đơn thuần để giải quyết xung đột | Xem mục 7 |
| P8 | Cloud chỉ được ghi đè local ở những trường cloud làm chủ (đã liệt kê rõ) | Xem mục 4 |

### Mẫu code chuẩn

```cpp
// ❌ CẤM
if (!cloudAvailable) { closeApplication(); }
if (!licenseActiveFromD1) { disableApplication(); }

// ✅ ĐÚNG
if (!cloudAvailable) {
    switchToOfflineMode();      // chỉ đổi cờ hiển thị + tạm dừng sync worker
    keepCoreFeaturesRunning();  // camera/in/lưu vẫn chạy bình thường
    enqueuePendingSync();       // ghi vào sync_queue, xử lý sau
}
```

---

## 3. Trạng thái hiện tại so với mục tiêu

| Thành phần | Hiện tại | Mục tiêu | Khoảng cách |
| --- | --- | --- | --- |
| Mở app không cần license | ✅ `kBypassMachineAuth=true` | ✅ | Không |
| Mở app không cần Internet | ❌ cổng Google ở PTB/SELFBOOTH build | ✅ | **Phase 4** |
| Capabilities không phụ thuộc mạng | ⚠️ cần `authenticate()` chạy | ✅ | **Phase 4** |
| Chụp/ghép/in offline | ✅ hoàn toàn local | ✅ | Không |
| Lưu ảnh offline | ✅ filesystem local | ✅ | Không |
| Ghi doanh thu offline | ✅ SQLite `revenue_records` | ✅ | Không |
| Voucher offline | ✅ `kCodesLocalFirst=true` cho mã tạo tại máy | ⚠️ mã web vẫn blocking | **Phase 6** |
| Upload ảnh offline | ✅ staging folder + retry 60 s | ✅ | Không (nhưng phụ thuộc `activate=1`) |
| Đồng bộ session/event/revenue | ❌ fire-and-forget, mất khi offline | ✅ sync_queue | **Phase 6** |
| Không chặn UI khi cloud lỗi | ❌ 6 hàm blocking 16–48 s | ✅ | **Phase 6** |
| Backup/restore local | ❌ không có | ✅ | **Phase 5** |
| Nhật ký lỗi có cấu trúc | ⚠️ chỉ file log text | ✅ `error_logs` | **Phase 5** |

---

## 4. Phân loại nguồn dữ liệu

### 4.1 LOCAL AUTHORITATIVE — local quyết định, cloud chỉ nhận bản sao

| Quyết định | Nguồn chân lý | Bảng/nơi lưu |
| --- | --- | --- |
| Có cho mở phần mềm hay không | **LOCAL** (luôn cho) | không cần dữ liệu |
| Có thể chụp hay không | **LOCAL** | trạng thái camera + `app_settings` |
| Có thể in hay không | **LOCAL** | `printer_settings` + trạng thái máy in |
| Trạng thái phiên hiện tại | **LOCAL** | `sessions` |
| Trạng thái ảnh hiện tại | **LOCAL** | `photos` + filesystem |
| Trạng thái print job | **LOCAL** | (đề xuất bảng `print_jobs`) |
| Doanh thu phát sinh tại máy | **LOCAL** | `revenue_records` |
| Ca làm việc hiện tại | **LOCAL** | (đề xuất `work_shifts`) + `app_settings` |
| Cấu hình camera/máy in/frame/filter | **LOCAL** | `app_settings`, `event_settings`, `printer_settings`, filesystem |
| Giá dịch vụ | **LOCAL** | `app_settings` |
| Nhân viên đang đăng nhập | **LOCAL** | `employees` + phiên trong RAM |

**Cloud không bao giờ được ghi đè các mục này.**

### 4.2 CLOUD AUTHORITATIVE — cloud quyết định, local chỉ đọc

| Dữ liệu | Bảng D1 | Local dùng làm gì |
| --- | --- | --- |
| Tài khoản quản trị web | `admin_accounts` (MSB_DB) | không dùng |
| Báo cáo tổng hợp nhiều máy/chi nhánh | `revenue`, `sessions`, `events` | không dùng |
| `studio_id` (tiền tố URL gallery) | `studios` | cache vào QSettings, chỉ để dựng URL |
| Danh sách nhân viên studio | `studio_staff` | đồng bộ về `employees` local (đã có) |
| Xử lý sự cố lượt chụp (`resolution_*`) | `sessions.resolution_*` | **nên** kéo về để hiển thị, hiện chưa |
| Preset ghi chú/giá/thời hạn voucher | `voucher_notes/prices/durations` | cache local, hiển thị dropdown |
| Preset gói chụp | `package_presets` | cache local |
| Gói bán app, thanh toán | `plans`, `payment_intents`, `app_sales` | chỉ hiển thị màn mua gói |

**Nguyên tắc:** dữ liệu cloud-authoritative chỉ được dùng để **hiển thị và làm phong phú**,
không bao giờ để **chặn** thao tác vận hành.

### 4.3 ĐỒNG BỘ HAI CHIỀU — chỉ dùng khi thật sự cần

Chỉ 3 nhóm được phép hai chiều:

| Dữ liệu | Vì sao cần 2 chiều | Quy tắc conflict |
| --- | --- | --- |
| `vouchers` / mã tiền mặt | Kho dùng chung nhiều máy + web | **Cloud wins cho trạng thái `used`** (redeem là UPDATE atomic ở cloud). **Local wins cho mã do máy tạo chưa sync** (`synced=0`). Đây chính là `kCodesLocalFirst` hiện tại. |
| `loyalty_codes` (đếm lượt) | Đếm lượt phải tập trung | **Cloud wins tuyệt đối.** Offline → không cho dùng mã loyalty, hiển thị "cần mạng". |
| `studio_staff` ↔ `employees` | Chủ thêm nhân viên trên web, máy phải thấy | **Cloud wins cho danh sách**; **local wins cho mật khẩu/PIN cục bộ** |
| `sessions.resolution_*` | Web ghi xử lý sự cố | **Cloud wins** (chỉ web mới ghi cột này) |

**Không dùng `updated_at` đơn thuần** để so sánh — đồng hồ máy khách có thể sai
(máy photobooth thường không có NTP, có máy tắt nguồn đột ngột làm lệch RTC).

Cơ chế thay thế: **version number đơn điệu tăng do local giữ** — chính là mô hình
`sessions.status_version` đang dùng:

```sql
ON CONFLICT(...) DO UPDATE SET ...
WHERE excluded.status_version >= COALESCE(sessions.status_version, 0)
```

Áp dụng mô hình này cho mọi entity đồng bộ 2 chiều.

---

## 5. Chế độ offline

### 5.1 Định nghĩa "cloud khả dụng"

```text
cloudAvailable = (đã cấu hình key.json)
              && (QNetworkInformation reachability == Online)
              && (lần gọi Worker gần nhất không lỗi mạng trong N phút)
```

Hiện tại `S3Uploader` đã theo dõi `QNetworkInformation::reachabilityChanged`
([S3Uploader.cpp:322-340](src/backend/S3Uploader.cpp#L322-L340)). Phase 6 nên
gom thành một `NetworkStateMonitor` dùng chung cho `CloudSyncService`.

### 5.2 Ma trận sự cố → hành vi bắt buộc

| Sự cố | Hành vi bắt buộc |
| --- | --- |
| Mất Internet | Offline mode. Chụp/in/lưu/doanh thu bình thường. Enqueue sync. |
| Cloudflare Worker lỗi 500 | Coi như cloud lỗi. Enqueue + backoff. **Không** hiện popup lỗi cho khách. |
| Worker lỗi 401 (token sai/rotate) | Enqueue + backoff dài (30 min). Ghi `error_logs` mức CRITICAL để kỹ thuật viên biết. **Không** chặn vận hành. |
| D1 lỗi / timeout | Như trên. |
| DNS không phân giải | Như mất Internet. |
| API timeout | Huỷ request, enqueue, backoff. **Không** giữ UI. |
| Server maintenance | Như cloud lỗi. |
| Cloudflare giới hạn request (429) | Backoff dài hơn (× 4), giảm concurrency về 1. |
| Endpoint bị thay đổi (404) | Ghi `error_logs`, backoff dài. Không chặn. |
| Upload S3 thất bại | Đã có: stage vào `pending/` + retry. Giữ nguyên. |

### 5.3 Chức năng phải hoạt động khi cloud lỗi

```text
✅ Mở phần mềm
✅ Chọn frame / layout
✅ Chụp ảnh
✅ Ghép ảnh (ImageCompositor)
✅ Áp dụng filter / sticker
✅ In ảnh (PrinterManager)
✅ Lưu ảnh vào filesystem
✅ Tạo phiên (SessionManager)
✅ Lưu doanh thu local (revenue_records)
✅ Quản lý ca local
✅ Xem lịch sử local (getCaptureAttempts, getRevenueRecords)
✅ Tạo & dùng mã voucher do máy này tạo (kCodesLocalFirst)
✅ Đăng nhập nhân viên bằng PIN local
✅ Quầy thu ngân LAN (HttpBridge :5514)
```

### 5.4 Chức năng được phép chờ đồng bộ

```text
⏳ Xem doanh thu từ xa (portal)
⏳ Đồng bộ ảnh lên S3 / gallery QR
⏳ Báo lỗi lên web
⏳ Dashboard online
⏳ Quản lý từ xa
⏳ Mã voucher do WEB tạo (cần cloud để validate/redeem đúng)
⏳ Mã loyalty (đếm lượt tập trung)
⏳ Đăng nhập QR từ portal
⏳ Mua/gia hạn gói qua SePay
```

### 5.5 Hiển thị cho người vận hành

Một chỉ báo duy nhất, không gây hoảng loạn cho khách:

| Trạng thái | Hiển thị | Nơi hiển thị |
| --- | --- | --- |
| Online, hàng đợi rỗng | (không hiển thị gì) | — |
| Online, đang đồng bộ N mục | chấm xanh + "Đang đồng bộ N" | góc màn hình quản trị |
| Offline, hàng đợi N mục | chấm vàng + "Ngoại tuyến · N mục chờ" | góc màn hình quản trị |
| Có mục FAILED | chấm đỏ + "N mục lỗi — xem Nhật ký" | màn hình quản trị |

**Không hiển thị lỗi mạng trên màn hình khách chụp.**

---

## 6. Định danh — UUID sinh tại local

| Entity | ID hiện tại | ID mục tiêu |
| --- | --- | --- |
| Session | `session_id` TEXT (đã do local sinh) | ✅ giữ nguyên, đảm bảo là UUIDv4 |
| Revenue | SQLite `id` INTEGER AUTOINCREMENT; cloud dùng `revenue_id` SHA-256 dẫn xuất | ⚠️ Thêm cột `uuid TEXT` sinh tại local, dùng làm khoá đồng bộ |
| Photo | SQLite `id` INTEGER AUTOINCREMENT | ⚠️ Thêm `uuid TEXT` |
| Print job | chưa có bảng | ✅ `uuid TEXT` ngay từ đầu |
| Voucher | `code` (4 số) — **có thể trùng giữa các studio** nhưng PK cloud là `(owner_email, code)` | ✅ đủ dùng |
| Sync event | chưa có | ✅ `event_id TEXT` = UUIDv4 |

**Cấm dùng `last_insert_rowid()` của D1 làm định danh cho dữ liệu tạo từ máy khách.**
Kiểm tra: `POST /portal/:email/voucher-notes` trả `res.meta?.last_row_id` — chỉ dùng
cho preset do web tạo, chấp nhận được.

---

## 7. Quy tắc xử lý xung đột

| Entity | Quy tắc | Lý do |
| --- | --- | --- |
| `sessions` | **Version number** (`status_version` tăng đơn điệu tại local) | Đã có sẵn, đã kiểm chứng |
| `revenue` | **Idempotent upsert** theo `revenue_id`, không có xung đột thật | Bản ghi bất biến sau khi tạo |
| `events` | **Last write wins từ local** (chỉ máy đó ghi) | 1 máy = 1 chuỗi event_id |
| `vouchers.used` | **Cloud wins** (redeem là `UPDATE … WHERE used=0` atomic) | Chống dùng 2 lần trên 2 máy |
| `vouchers` mới tạo local (`synced=0`) | **Local wins**, cloud không biết mã này | `kCodesLocalFirst` |
| `sessions.resolution_*` | **Cloud wins** | Chỉ web ghi |
| `studio_staff` → `employees` | **Cloud wins cho danh sách**, local wins cho PIN | |
| `app_settings` | **Local wins tuyệt đối** | Cấu hình máy là của máy |
| Xung đột không giải quyết được | **Manual resolution** — ghi vào `error_logs`, hiển thị trong màn hình quản trị | Không tự động chọn bừa |

**Cấm:** dùng `MAX(updated_at)` để phân xử. Đồng hồ máy khách không đáng tin.

Nếu bắt buộc phải so thời gian, dùng **thời gian server** (`nowIso()` do Worker sinh,
lưu vào cột riêng `server_updated_at`) chứ không dùng thời gian client.

---

## 8. Ranh giới trách nhiệm

| Thành phần | ĐƯỢC quyết định | KHÔNG được quyết định |
| --- | --- | --- |
| SQLite local | App có chạy, chụp được, in được, doanh thu, phiên | Báo cáo nhiều máy |
| Filesystem local | Ảnh gốc, ảnh ghép, video, frame, filter | — |
| `CloudSyncService` | Khi nào gửi, gửi lại bao nhiêu lần | Không được chặn UI, không được huỷ dữ liệu local |
| `S3Uploader` | Khi nào upload | Không được xoá file local trước khi upload thành công |
| Cloudflare Worker | Kho voucher dùng chung, báo cáo tổng hợp, quản trị | **Không được khoá app** |
| D1 | Lưu trữ bản sao + dữ liệu quản trị | **Không được là điều kiện để app chạy** |
| Web Portal | Xem báo cáo, quản trị mã, phân quyền nhân viên | Không được xoá dữ liệu local |

---

## 9. Danh sách công việc để đạt kiến trúc mục tiêu

| # | Công việc | Phase | Tài liệu chi tiết |
| --- | --- | --- | --- |
| 1 | Tắt cổng Google bằng feature flag | 4 | [CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md](CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md) §5 A.3 |
| 2 | Gọi `authenticate()` sớm, không phụ thuộc Google | 4 | cùng tài liệu §5 A.2 |
| 3 | `DatabaseManager::initialize()` fallback thay vì `return -1` | 5 | mục 6.1 |
| 4 | Backup SQLite trước migration | 5 | [SAFE_MIGRATION_PLAN.md](SAFE_MIGRATION_PLAN.md) |
| 5 | Thêm bảng `sync_queue`, `sync_state`, `error_logs`, `print_jobs`, `work_shifts` | 5 | [LOCAL_DATABASE_SCHEMA_PROPOSAL.md](LOCAL_DATABASE_SCHEMA_PROPOSAL.md) |
| 6 | Thêm cột `uuid` cho `revenue_records`, `photos` | 5 | cùng tài liệu |
| 7 | Viết `CloudSyncService` + backoff + idempotency | 6 | [CLOUD_SYNC_DESIGN.md](CLOUD_SYNC_DESIGN.md) |
| 8 | Chuyển 6 hàm `blockingRequest` sang async | 6 | cùng tài liệu §6 |
| 9 | Cấp phát `sync_queue` cho session/event/revenue thay fire-and-forget | 6 | cùng tài liệu §3 |
| 10 | Kéo `sessions.resolution_*` từ cloud về local | 6 | cùng tài liệu §7 |
| 11 | Cache preset voucher/package về local | 6 | cùng tài liệu §7 |
| 12 | Chỉ báo trạng thái đồng bộ trên UI quản trị | 6 | mục 5.5 |
| 13 | Kiểm thử mất kết nối đầy đủ | 7 | [TEST_PLAN.md](TEST_PLAN.md) |
| 14 | (Chờ phê duyệt) Bỏ kiểm `activate` ở `/upload/presign` | sau 7 | cần deploy Worker |
