# SAFE MIGRATION PLAN

Kế hoạch triển khai an toàn từ hệ thống hiện tại sang kiến trúc local-first,
**không gián đoạn production, không thay đổi D1 tự động**.

Ngày lập: 2026-08-03.

---

## 0. Quy tắc bất di bất dịch cho toàn bộ kế hoạch

```text
KHÔNG ghi/sửa/xoá dữ liệu D1 production.
KHÔNG thay đổi schema D1.
KHÔNG chạy migration D1.
KHÔNG chạy seed / cleanup.
KHÔNG deploy Cloudflare Worker.
KHÔNG deploy Vercel.
KHÔNG thay đổi biến môi trường production.
KHÔNG rotate secret.
KHÔNG thay đổi endpoint đang hoạt động.
KHÔNG bật auto update.
KHÔNG tự động commit/push.
```

Mọi bước có dấu ⛔ dưới đây **bắt buộc dừng lại chờ phê duyệt thủ công**.

---

## PHASE 1 — CHỈ NGHIÊN CỨU ✅ HOÀN THÀNH

| Việc | Trạng thái | Đầu ra |
| --- | --- | --- |
| Bản đồ toàn bộ D1 | ✅ | [D1_PRODUCTION_BEHAVIOR_ANALYSIS.md](D1_PRODUCTION_BEHAVIOR_ANALYSIS.md) |
| Bản đồ cơ chế license | ✅ | [CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md](CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md) |
| Bản đồ auto update | ✅ | [AUTO_UPDATE_AND_PRODUCTION_RISK_ANALYSIS.md](AUTO_UPDATE_AND_PRODUCTION_RISK_ANALYSIS.md) |
| Bản đồ dữ liệu local hiện có | ✅ | [LOCAL_DATABASE_SCHEMA_PROPOSAL.md](LOCAL_DATABASE_SCHEMA_PROPOSAL.md) §1 |
| Không sửa code | ✅ | 0 file mã nguồn bị thay đổi |
| Không ghi D1 | ✅ | 0 lệnh chạm D1 |
| Không deploy | ✅ | |

### Việc còn tồn đọng của Phase 1 — cần phê duyệt thủ công

| ⛔ | Việc | Lệnh đề xuất (CHỈ ĐỌC) |
| --- | --- | --- |
| ⛔ P1-A | Xác nhận D1 `photobooth / a69d02e4-…` dùng để làm gì | Hỏi người vận hành. **Không** tự trỏ `wrangler.toml` sang ID này |
| ⛔ P1-B | Đọc schema thật của production để đối chiếu với file `.sql` | `npx wrangler d1 execute boothme_prod --remote --command "SELECT name,sql FROM sqlite_master WHERE type='table'"` |
| ⛔ P1-C | Đếm số dòng từng bảng để ước lượng khối lượng | `… --command "SELECT COUNT(*) FROM machines"` (lặp cho từng bảng) |
| ⛔ P1-D | Xác nhận migration nào đã áp | Suy từ kết quả P1-B (có cột `package_key`? có bảng `loyalty_codes`?) |

> Cả 4 lệnh trên chỉ `SELECT`, không thay đổi dữ liệu. Vẫn cần phê duyệt vì
> `--remote` chạm production.
> **Tuyệt đối không** gọi qua Worker để "đọc" — nhiều route GET có tác dụng phụ ghi
> (xem R-01 trong báo cáo D1).

---

## PHASE 2 — THIẾT KẾ ✅ HOÀN THÀNH

9 tài liệu trong `docs/`:

```text
docs/D1_PRODUCTION_BEHAVIOR_ANALYSIS.md         ✅
docs/CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md  ✅
docs/AUTO_UPDATE_AND_PRODUCTION_RISK_ANALYSIS.md ✅
docs/LOCAL_FIRST_ARCHITECTURE.md                ✅
docs/LOCAL_DATABASE_SCHEMA_PROPOSAL.md          ✅
docs/CLOUD_SYNC_DESIGN.md                       ✅
docs/SAFE_MIGRATION_PLAN.md                     ✅ (tài liệu này)
docs/ROLLBACK_PLAN.md                           ✅
docs/TEST_PLAN.md                               ✅
```

⛔ **Cổng phê duyệt 2:** người chịu trách nhiệm đọc và ký nhận 9 tài liệu trước khi
sang Phase 3.

---

## PHASE 3 — NHÁNH PHÁT TRIỂN RIÊNG

### 3.1 Vấn đề: thư mục hiện tại KHÔNG phải git repository

Kiểm tra: `c:\Users\LAPTOP117\Desktop\photobooth\source\main` — **không có `.git`**.

→ **Không có lịch sử phiên bản. Không rollback được bằng git. Đây là rủi ro cao nhất
của toàn bộ dự án.**

### 3.2 Việc bắt buộc trước khi sửa bất kỳ dòng code nào

| Bước | Việc | Ghi chú |
| --- | --- | --- |
| 3.2.1 | **Sao lưu toàn bộ thư mục nguồn** ra ổ khác + ổ ngoài | `main-backup-2026-08-03.zip`, loại trừ `build_studio3`, `node_modules`, `installer-output` |
| 3.2.2 | ⛔ Khởi tạo git repository | `git init` — cần phê duyệt vì tạo file mới |
| 3.2.3 | Tạo `.gitignore` | Loại trừ: `build_studio3/`, `node_modules/`, `installer-output/`, `*.log`, `data/*.db`, `.wrangler/`, `.vercel/` |
| 3.2.4 | ⛔ **`key.json` chứa secret** — thêm vào `.gitignore`, commit `key.example.json` thay thế | Token + Google client_secret không được vào git |
| 3.2.5 | Commit đầu tiên: `chore: import production source as-is` | Mốc rollback |
| 3.2.6 | Tạo nhánh làm việc | `git checkout -b feature/remove-client-activation-local-first` |

### 3.3 Quy ước nhánh

```text
main / master                                    ← bản đang chạy production
feature/remove-client-activation-local-first     ← Phase 4
feature/local-sqlite-sync-infra                  ← Phase 5
feature/cloud-sync-queue                         ← Phase 6
```

**Không commit trực tiếp vào nhánh production.**
Mỗi phase = 1 nhánh, merge vào `main` chỉ sau khi kiểm thử xong.

### 3.4 Ghi nhận phiên bản build

Hiện `main.cpp` không set version. Thêm ngay ở Phase 4:

```cpp
QGuiApplication app(argc, argv);
app.setApplicationName("BOOTHME");
app.setApplicationVersion("2.4.0-localfirst.1");   // đồng bộ với installer.iss
qDebug() << "[SYS] App version:" << app.applicationVersion()
         << "| build:" << __DATE__ << __TIME__;
```

Để log của máy khách cho biết chính xác đang chạy bản nào.

---

## PHASE 4 — TẮT XÁC THỰC BẰNG FEATURE FLAG

Mục tiêu: **mở app → dùng ngay, không cần mạng.**

### 4.1 Thay đổi tối thiểu (5 file)

| # | File | Thay đổi | Dòng |
| --- | --- | --- | --- |
| 1 | `src/backend/AppFeatureFlags.h` | **TẠO MỚI** — 3 hằng số | ~20 |
| 2 | `src/main.cpp` | `#include "backend/AppFeatureFlags.h"` | +1 |
| 3 | `src/main.cpp` | Thêm `kRequireGoogleLoginAtStartup &&` vào điều kiện `needGoogleLogin` ([main.cpp:407](src/main.cpp#L407)) | 1 |
| 4 | `src/main.cpp` | `setContextProperty("requireGoogleLoginAtStartup", kRequireGoogleLoginAtStartup)` | +1 |
| 5 | `src/main.cpp` | Set application version (§3.4) | +3 |
| 6 | `qml/ptb_main.qml` | Thêm cờ vào 2 điều kiện (dòng 171, 531) | 2 |
| 7 | `qml/selfbooth_main.qml` | Thêm cờ vào 2 điều kiện (dòng 93, 162) | 2 |

**Tổng: ~30 dòng, 4 file (1 mới).**

Chi tiết mã ở [CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md](CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md) §5.

### 4.2 Cân nhắc: dời `authenticate()` lên sớm

Hiện `machineAuth->authenticate()` chạy **500 ms sau khi QML nạp**
([main.cpp:403](src/main.cpp#L403)). Trong 500 ms đó `capabilities` rỗng →
nếu QML gọi `hasCapability()` sớm sẽ nhận `false`.

**Khuyến nghị:** gọi ngay sau khi tạo object ([main.cpp:192](src/main.cpp#L192)).
Với bypass, hàm này hoàn toàn local (ghi SQLite + set caps), tốn < 5 ms.

⚠️ Đây là thay đổi thứ tự khởi động — **phải kiểm thử kỹ**, xếp vào nhóm rủi ro
trung bình. Nếu muốn tối giản rủi ro Phase 4, có thể bỏ qua bước này và chỉ làm §4.1.

### 4.3 KHÔNG làm trong Phase 4

```text
✗ Không xoá code license cũ
✗ Không xoá GoogleLoginScreen.qml
✗ Không xoá authPopup
✗ Không sửa MachineAuthenticator.cpp
✗ Không sửa DynamoDBClient
✗ Không sửa Worker
✗ Không sửa D1
✗ Không sửa key.json
✗ Không đụng cơ chế upload S3
```

### 4.4 Điều kiện chấp nhận Phase 4

| # | Tiêu chí | Cách kiểm |
| --- | --- | --- |
| A4-1 | Máy **chưa từng đăng nhập Google**, **không có mạng** → mở app vào thẳng giao diện chính | Xoá `HKCU\Software\BoothOS\GoogleAuth`, rút mạng, chạy app |
| A4-2 | Không hiện màn hình đăng nhập Google | Quan sát |
| A4-3 | Không hiện popup "Xác thực máy" | Quan sát |
| A4-4 | Khởi chạy được sự kiện, không hiện "nâng cấp gói" | Bấm vào 1 sự kiện |
| A4-5 | Chụp → ghép → in → lưu doanh thu bình thường khi không mạng | Chạy 1 phiên đầy đủ |
| A4-6 | Cắm mạng lại → ảnh trong `pending/` tự upload | Chờ ≤ 60 s, kiểm S3 |
| A4-7 | Thời gian từ double-click tới giao diện chính không tăng quá 10% so với bản cũ | Đo bằng log timestamp |
| A4-8 | Log không có `qCritical` mới | Xem `logs\` |

### 4.5 Quy trình phát hành Phase 4

```text
1. Build:  .\build-ptb.ps1 -Clean           (ghi lại commit hash)
2. ⚠ Kiểm tra installer.iss dòng 14: BuildDir phải khớp thư mục build thật
     (hiện là build_studio2, script build ra build_studio3 → PHẢI SỬA)
3. iscc installer.iss
4. Cài trên MÁY TEST (không phải máy khách) → chạy toàn bộ A4-1..A4-8
5. ⛔ Cổng phê duyệt 4a
6. Cài trên 1 MÁY PRODUCTION ít quan trọng nhất
   - Backup trước: {app}\data\photobooth.db, {app}\key.json, toàn bộ {app}
   - Cài ngoài giờ hoạt động (CloseApplications=yes sẽ đóng app đang chạy)
   - Sau cài: khôi phục key.json từ backup (installer ghi đè!)
7. Theo dõi 48 giờ: log, doanh thu, số ảnh upload
8. ⛔ Cổng phê duyệt 4b
9. Triển khai phần còn lại theo nhóm 3–5 máy, cách nhau ≥ 24 h
```

---

## PHASE 5 — BỔ SUNG HẠ TẦNG SQLITE LOCAL

### 5.1 Nội dung

| # | Việc | Rủi ro |
| --- | --- | --- |
| 5.1.1 | Backup tự động `photobooth.db` trước khi chạy migration | 🟢 |
| 5.1.2 | `PRAGMA quick_check` khi khởi động + xử lý DB hỏng | 🟡 |
| 5.1.3 | `DatabaseManager::initialize()` fallback thay vì `return -1` | 🟡 |
| 5.1.4 | Migration v27: `sync_queue`, `sync_state`, `error_logs`, `print_jobs`, `cloud_cache` + cột `uuid` | 🟡 |
| 5.1.5 | Backfill `uuid` cho `revenue_records`, `photos` theo lô | 🟡 |
| 5.1.6 | Bật `PRAGMA journal_mode = WAL` | 🟠 |
| 5.1.7 | Sửa `installer.iss` `Excludes` thêm `*.db-wal`, `*.db-shm` | 🟠 **bắt buộc đi kèm 5.1.6** |
| 5.1.8 | Ghi `error_logs` từ Logger + các component chính | 🟢 |

### 5.2 Nguyên tắc migration local

```text
CHỈ THÊM. Không sửa. Không xoá. Không đổi tên.
Mọi CREATE dùng IF NOT EXISTS.
Mọi ALTER ADD COLUMN bỏ qua lỗi "duplicate column".
Backfill chạy theo lô, có thể tiếp tục nếu bị ngắt giữa chừng.
setSchemaVersion() chỉ gọi khi TẤT CẢ bước thành công.
```

### 5.3 Chạy song song, chưa thay thế D1

Phase 5 **chỉ tạo hạ tầng**. `sync_queue` được ghi vào nhưng **chưa có worker đọc**
(worker ở Phase 6). Luồng `DynamoDBClient` cũ **vẫn chạy song song**.

→ Nếu Phase 5 có vấn đề, chỉ cần không dùng bảng mới; hành vi hệ thống không đổi.

### 5.4 So sánh dữ liệu local ↔ cloud (bắt buộc trước Phase 6)

Trên máy test, sau 1 tuần vận hành:

| Đối chiếu | Local | Cloud | Chấp nhận |
| --- | --- | --- | --- |
| Số phiên chụp | `SELECT COUNT(*) FROM sessions WHERE status != 'PREPARED'` | `GET /machine/:hwid/capture-attempts` | Lệch ≤ 2% (do fire-and-forget mất) |
| Tổng doanh thu | `SELECT SUM(received_amount) FROM revenue_records` | `GET /machine/:hwid/revenue` → `summary.total_received` | Lệch ≤ 2% |
| Số ảnh | `SELECT COUNT(*) FROM photos` | đếm object S3 theo prefix | Lệch ≤ 1% |
| Số voucher | `SELECT COUNT(*) FROM vouchers` | `GET /machine/:hwid/vouchers` | Lệch do `kCodesLocalFirst` là bình thường |

**Ghi lại con số lệch làm baseline.** Sau Phase 6, lệch phải về ~0%.

### 5.5 Điều kiện chấp nhận Phase 5

| # | Tiêu chí |
| --- | --- |
| A5-1 | Nâng cấp từ DB v26 → v27 thành công trên bản sao DB thật của khách |
| A5-2 | File backup `photobooth.db.bak-v26-*` được tạo trước migration |
| A5-3 | Ngắt điện giữa lúc migration → mở lại chạy tiếp được, không mất dữ liệu |
| A5-4 | DB cố tình làm hỏng (ghi rác vào file) → app vẫn mở, tạo DB mới, ghi `error_logs` |
| A5-5 | 5 bảng mới tồn tại, đúng cột, đúng index |
| A5-6 | `uuid` được backfill 100% cho `revenue_records` |
| A5-7 | WAL bật, file `.db-wal` xuất hiện, mất điện đột ngột không hỏng DB (10 lần thử) |
| A5-8 | Hiệu năng không giảm: thời gian lưu 1 phiên không tăng > 20% |

⛔ **Cổng phê duyệt 5.**

---

## PHASE 6 — SYNC QUEUE

### 6.1 Nội dung

| # | Việc |
| --- | --- |
| 6.1.1 | Viết `CloudSyncService` (thread nền, backoff + jitter, concurrency 2) |
| 6.1.2 | Chuyển `syncSessionToCloud` → `enqueue("session", …)` |
| 6.1.3 | Chuyển `syncEventToCloud` → `enqueue("event", …)` |
| 6.1.4 | Chuyển `logRevenue` → `enqueue("revenue", …)` **trong cùng transaction** |
| 6.1.5 | Chuyển voucher push/delete sang queue |
| 6.1.6 | Hạ timeout `validateVoucherCloud` xuống 3 s, `redeemVoucherCloud` 5 s |
| 6.1.7 | Thay `voucherPresetsCloud` blocking bằng `cloud_cache` + refresh nền |
| 6.1.8 | Pull `sessions.resolution_*` từ cloud về local |
| 6.1.9 | Xử lý `package_checkins` at-most-once (xác minh bằng `check-phone` trước khi retry) |
| 6.1.10 | Chỉ báo trạng thái đồng bộ trên UI quản trị |
| 6.1.11 | Khôi phục `PROCESSING` → `PENDING` khi khởi động |
| 6.1.12 | Dọn `sync_queue` SYNCED > 7 ngày, `error_logs` theo chính sách |

### 6.2 Chuyển đổi tăng dần (giảm rủi ro)

Không chuyển tất cả cùng lúc. Thứ tự:

```text
Bước 1: chỉ 'revenue'   → theo dõi 3 ngày
Bước 2: thêm 'session'  → theo dõi 3 ngày
Bước 3: thêm 'event'    → theo dõi 3 ngày
Bước 4: thêm 'voucher'  → theo dõi 3 ngày
Bước 5: giảm timeout blocking
```

Dùng cờ trong `AppFeatureFlags.h` để bật/tắt từng loại:

```cpp
constexpr bool kSyncQueueRevenue = true;
constexpr bool kSyncQueueSession = false;   // bật ở bước 2
constexpr bool kSyncQueueEvent   = false;
constexpr bool kSyncQueueVoucher = false;
```

Khi cờ = false, giữ nguyên đường fire-and-forget cũ. **Không chạy cả hai đường
cùng lúc cho cùng một loại dữ liệu** (sẽ gửi trùng — tuy idempotent nhưng lãng phí).

### 6.3 Điều kiện chấp nhận Phase 6

| # | Tiêu chí |
| --- | --- |
| A6-1 | Offline 24 h, chụp 50 phiên → cắm mạng → 100% lên cloud trong 10 phút |
| A6-2 | Số dòng `revenue` trên cloud **bằng đúng** số dòng `revenue_records` local |
| A6-3 | Không có bản ghi trùng trên cloud (kiểm bằng `COUNT(*)` vs `COUNT(DISTINCT revenue_id)`) |
| A6-4 | Tắt app đột ngột khi đang đồng bộ → mở lại tiếp tục, không mất, không trùng |
| A6-5 | Worker trả 500 liên tục → UI không đứng, app vẫn chụp/in bình thường |
| A6-6 | Worker trả 401 → dữ liệu giữ lại, không bị `FAILED` |
| A6-7 | Thao tác validate voucher (mã web) không làm UI đứng quá 3 s |
| A6-8 | Mở tab quản lý mã: preset hiện **ngay lập tức** từ cache |
| A6-9 | CPU của tiến trình khi idle với 1000 mục PENDING < 3% |
| A6-10 | Chụp ảnh trong lúc đang đồng bộ 500 mục: không có frame drop, không delay shutter |

⛔ **Cổng phê duyệt 6.**

---

## PHASE 7 — KIỂM THỬ MẤT KẾT NỐI

Toàn bộ 30 kịch bản ở [TEST_PLAN.md](TEST_PLAN.md).

Môi trường: máy test riêng, **không phải máy khách**, dùng bản sao DB thật.

⛔ **Cổng phê duyệt 7.**

---

## PHASE 8 — PHÁT HÀNH THỦ CÔNG

### 8.1 Chuẩn bị

| # | Việc |
| --- | --- |
| 8.1.1 | Sửa `installer.iss` dòng 14: `BuildDir` khớp thư mục build thật |
| 8.1.2 | Tăng `AppVersion` trong `installer.iss` + `setApplicationVersion` trong `main.cpp` (phải khớp) |
| 8.1.3 | **Giải quyết vấn đề `key.json` bị ghi đè** — xem 8.2 |
| 8.1.4 | Giữ nguyên file setup bản cũ ở nơi an toàn, đặt tên rõ ràng |
| 8.1.5 | Viết checklist cài đặt 1 trang cho kỹ thuật viên |

### 8.2 Vấn đề `key.json` (bắt buộc xử lý)

[installer.iss:90](installer.iss#L90) ghi đè `key.json` bằng bản trong build.
Nếu máy khách có cấu hình riêng (endpoint khác, tên máy khác) → **mất**.

Hai lựa chọn:

| Lựa chọn | Cách làm | Đánh giá |
| --- | --- | --- |
| **8.2.A** (khuyến nghị) | Đổi flag dòng 90 thành `onlyifdoesntexist` như dòng 104 | Cài mới vẫn có key.json; cài đè giữ nguyên của khách |
| 8.2.B | Kỹ thuật viên backup + khôi phục tay mỗi lần cài | Dễ quên, rủi ro cao |

Nếu chọn 8.2.A, phải có quy trình riêng khi **cần** cập nhật `key.json`
(ví dụ khi rotate token): xoá file rồi cài lại, hoặc sửa tay.

### 8.3 Trình tự triển khai

```text
Giai đoạn 1 — MÁY TEST (không phục vụ khách)
  ├─ Cài bản mới
  ├─ Chạy toàn bộ TEST_PLAN.md
  ├─ Theo dõi log 72 giờ
  └─ ⛔ Cổng phê duyệt 8a

Giai đoạn 2 — 1 MÁY PRODUCTION (chọn máy ít doanh thu nhất)
  ├─ Backup: {app}\data\photobooth.db, {app}\key.json, toàn bộ {app}
  ├─ Ghi lại: số phiên, tổng doanh thu, số ảnh trước khi cài
  ├─ Cài NGOÀI GIỜ HOẠT ĐỘNG
  ├─ Kiểm ngay: mở app < 30 s, chụp thử 1 phiên, in thử 1 ảnh
  ├─ Theo dõi 7 ngày: log, doanh thu local vs cloud, số ảnh pending
  └─ ⛔ Cổng phê duyệt 8b

Giai đoạn 3 — NHÓM 3 MÁY
  ├─ Cùng quy trình
  ├─ Theo dõi 5 ngày
  └─ ⛔ Cổng phê duyệt 8c

Giai đoạn 4 — TOÀN BỘ
  └─ Theo nhóm 5 máy, cách nhau ≥ 24 giờ
```

### 8.4 Checklist mỗi lần cài (in ra cho kỹ thuật viên)

```text
TRƯỚC KHI CÀI
[ ] Máy không đang phục vụ khách
[ ] Copy {app}\data\photobooth.db  → USB
[ ] Copy {app}\key.json            → USB
[ ] Copy toàn bộ {app}             → USB (nếu đủ dung lượng)
[ ] Chụp màn hình: tổng doanh thu hôm nay, số phiên
[ ] Ghi lại số file trong {app}\pending_uploads
[ ] File setup bản CŨ có sẵn trên USB để rollback

CÀI
[ ] Đóng BOOTHME.exe
[ ] Chạy setup với quyền admin
[ ] Chờ hoàn tất, KHÔNG tick "Launch" ngay

SAU KHI CÀI
[ ] Kiểm tra {app}\key.json còn đúng (so với bản backup)
[ ] Kiểm tra {app}\data\photobooth.db còn đúng kích thước
[ ] Mở app, bấm đồng hồ: phải vào giao diện chính < 30 giây
[ ] Rút mạng → mở lại app → vẫn vào được giao diện chính
[ ] Cắm mạng lại
[ ] Chụp thử 1 phiên đầy đủ (chụp → ghép → in → thanh toán)
[ ] Kiểm doanh thu hôm nay khớp với ảnh chụp màn hình trước khi cài
[ ] Kiểm {app}\logs không có dòng CRITICAL mới
[ ] Ghi vào nhật ký triển khai: máy nào, giờ nào, phiên bản nào, ai cài
```

### 8.5 Tiêu chí dừng triển khai ngay lập tức

Nếu gặp **bất kỳ** điều nào sau, dừng và rollback:

```text
✗ App không mở được
✗ Mất dữ liệu doanh thu hoặc phiên chụp
✗ Không chụp được / không in được
✗ Thời gian mở app > 60 giây
✗ Có dòng CRITICAL trong log
✗ DB local bị hỏng
✗ Doanh thu cloud tăng bất thường (dấu hiệu ghi trùng)
```

Quy trình rollback: [ROLLBACK_PLAN.md](ROLLBACK_PLAN.md).

---

## PHASE 9 (SAU CÙNG, CHỈ KHI ĐÃ ỔN ĐỊNH ≥ 1 THÁNG)

⛔ Toàn bộ Phase 9 cần phê duyệt riêng, **có thể ảnh hưởng production**.

| # | Việc | Ảnh hưởng |
| --- | --- | --- |
| 9.1 | Bỏ kiểm `machines.activate` ở `/upload/presign` | **Deploy Worker** |
| 9.2 | Thêm `UNIQUE INDEX` cho `package_checkins(machine_hwid, session_id)` | **Migration D1** |
| 9.3 | Đổi `INSERT` → `INSERT OR IGNORE` cho `package_checkins` | **Deploy Worker** |
| 9.4 | Bỏ token khỏi `web/portal/config.js`, chuyển sang server-side proxy | **Deploy Vercel + Worker** |
| 9.5 | Xoá `authPopup`, `LicenseStore`, timer license (Phương án B) | Chỉ client |
| 9.6 | Xoá bảng `upload_queue` (code chết) | Chỉ client |
| 9.7 | Dựng môi trường staging D1 riêng (`[env.staging]` trong wrangler.toml) | Tạo D1 mới |

Với 9.7: **đây là nơi D1 `photobooth / a69d02e4-…` có thể dùng làm staging** —
nhưng phải được người vận hành xác nhận trước.

---

## Bảng theo dõi tiến độ

| Phase | Nội dung | Trạng thái | Cổng phê duyệt |
| --- | --- | --- | --- |
| 1 | Nghiên cứu | ✅ Hoàn thành | ⛔ P1-A..D còn tồn đọng |
| 2 | Thiết kế (9 tài liệu) | ✅ Hoàn thành | ⛔ Cổng 2 |
| 3 | Git + nhánh riêng | ⏳ Chờ | ⛔ 3.2.2, 3.2.4 |
| 4 | Feature flag tắt xác thực | ⏳ Chờ | ⛔ 4a, 4b |
| 5 | Hạ tầng SQLite local | ⏳ Chờ | ⛔ Cổng 5 |
| 6 | Sync queue | ⏳ Chờ | ⛔ Cổng 6 |
| 7 | Kiểm thử mất kết nối | ⏳ Chờ | ⛔ Cổng 7 |
| 8 | Phát hành thủ công | ⏳ Chờ | ⛔ 8a, 8b, 8c |
| 9 | Dọn dẹp + thay đổi cloud | ⏳ Chờ | ⛔ riêng từng mục |
