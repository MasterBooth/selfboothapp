# ROLLBACK PLAN

Kế hoạch quay lui cho từng phase. Nguyên tắc: **mọi thay đổi phải quay lui được
trong ≤ 30 phút mà không mất dữ liệu khách hàng.**

Ngày lập: 2026-08-03.

---

## 0. Cảnh báo về khả năng rollback hiện tại

| Hạng mục | Rollback được? | Ghi chú |
| --- | --- | --- |
| Mã nguồn | ❌ **KHÔNG** — thư mục **không phải git repository** | Rủi ro cao nhất. Phải xử lý ở Phase 3 |
| EXE trên máy khách | ⚠️ Chỉ khi giữ file setup bản cũ | Hiện chưa có quy trình lưu trữ |
| SQLite local | ⚠️ Chỉ khi có backup thủ công | Chưa có backup tự động |
| Schema SQLite local | ❌ Không downgrade được | Migration chỉ đi tiến |
| D1 production | ❌ **KHÔNG** — không có backup, không có export | Rủi ro cực cao |
| Worker | ⚠️ `wrangler rollback` (giữ 10 bản gần nhất) | Chưa kiểm chứng |
| `key.json` trên máy khách | ⚠️ Chỉ khi backup trước khi cài | Installer ghi đè |

**Kết luận: trước khi làm bất kỳ Phase nào, phải thiết lập cơ chế backup.**

---

## 1. Chuẩn bị bắt buộc (làm TRƯỚC Phase 3)

### 1.1 Backup mã nguồn

```powershell
# Sao lưu toàn bộ thư mục nguồn, loại trừ build artifacts
$src  = "c:\Users\LAPTOP117\Desktop\photobooth\source\main"
$dest = "D:\backup\photobooth-source-2026-08-03.zip"
$exclude = @("build_studio3","node_modules","installer-output",".wrangler",".vercel")
# (dùng Compress-Archive hoặc 7z với tham số loại trừ tương ứng)
```

Lưu **2 bản**: 1 ổ khác trên cùng máy, 1 ổ ngoài / cloud storage.

### 1.2 Khởi tạo git (⛔ cần phê duyệt)

```bash
git init
# .gitignore phải có: build_studio3/ node_modules/ installer-output/
#                     .wrangler/ .vercel/ *.log data/*.db key.json
git add -A
git commit -m "chore: import production source as-is (pre-localfirst baseline)"
git tag baseline-2026-08-03
```

Từ đây rollback mã nguồn = `git checkout baseline-2026-08-03`.

### 1.3 Kho lưu file setup

```text
D:\releases\
  BOOTHME-Setup-2.3-Fuji.exe              ← bản đang chạy production (GIỮ VĨNH VIỄN)
  BOOTHME-Setup-2.4.0-localfirst.1.exe    ← bản Phase 4
  BOOTHME-Setup-2.5.0-syncqueue.1.exe     ← bản Phase 6
  MANIFEST.txt                            ← phiên bản nào cài ở máy nào, ngày nào
```

**Không bao giờ xoá file setup của bản đã từng chạy production.**

### 1.4 Backup SQLite của từng máy khách

Trước mỗi lần cài, kỹ thuật viên copy:

```text
{app}\data\photobooth.db   → USB\<tên-máy>\<ngày>\photobooth.db
{app}\key.json             → USB\<tên-máy>\<ngày>\key.json
```

Nếu đủ dung lượng, copy cả thư mục `{app}`.

### 1.5 ⛔ Export D1 production (cần phê duyệt)

Hiện **không có backup D1 nào**. Đề xuất trước Phase 4:

```bash
# CHỈ ĐỌC — xuất toàn bộ database ra file .sql
npx wrangler d1 export boothme_prod --remote --output=d1-boothme_prod-2026-08-03.sql
npx wrangler d1 export msb_photobooth --remote --output=d1-msb-2026-08-03.sql
```

Lệnh `d1 export` chỉ đọc, không thay đổi dữ liệu. Nhưng vẫn cần phê duyệt vì
`--remote` và vì file xuất ra **chứa dữ liệu cá nhân** (email, số điện thoại) —
phải lưu ở nơi an toàn, mã hoá nếu có thể.

Nên chạy định kỳ hàng tuần kể cả khi không có thay đổi nào.

---

## 2. Rollback theo từng Phase

### PHASE 4 — Feature flag tắt xác thực

**Điều gì có thể sai:** app không mở, capabilities sai, không chụp được.

**Dữ liệu bị ảnh hưởng:** không có. Phase 4 không đụng schema, không đụng D1.

#### Rollback mức 1 — đảo cờ (5 phút + thời gian build)

```cpp
// src/backend/AppFeatureFlags.h
constexpr bool kRequireGoogleLoginAtStartup = true;   // ← đảo lại
constexpr bool kGrantAllCapabilitiesLocally = false;  // ← đảo lại
```

Build → đóng gói → cài đè. Hành vi quay về hệt bản cũ.

#### Rollback mức 2 — cài lại bản cũ (15 phút/máy)

```text
1. Đóng BOOTHME.exe
2. Chạy D:\releases\BOOTHME-Setup-2.3-Fuji.exe
3. Khôi phục key.json từ USB (installer ghi đè!)
4. Kiểm tra photobooth.db còn nguyên (installer dùng onlyifdoesntexist → an toàn)
5. Mở app, chụp thử 1 phiên
```

⚠️ **Lưu ý:** nếu đã chạy Phase 5 (schema v27) thì **không thể** rollback về EXE
bản 2.3 — bản cũ không biết bảng mới nhưng vẫn chạy được (SQLite bỏ qua bảng lạ).
Rủi ro thực tế: thấp. Nhưng phải kiểm thử.

#### Rollback mã nguồn

```bash
git checkout baseline-2026-08-03
# hoặc
git revert <commit-phase-4>
```

---

### PHASE 5 — Hạ tầng SQLite local

**Điều gì có thể sai:** migration v27 lỗi, DB hỏng, WAL gây vấn đề, hiệu năng giảm.

**Dữ liệu bị ảnh hưởng:** schema local (chỉ thêm bảng/cột), file WAL.

#### Rollback mức 1 — tắt tính năng, giữ schema

```cpp
constexpr bool kUseWalMode      = false;   // tắt WAL
constexpr bool kWriteErrorLogs  = false;   // ngừng ghi error_logs
```

Bảng mới vẫn tồn tại nhưng không được dùng → vô hại.
Trước khi tắt WAL, phải `PRAGMA journal_mode = DELETE` và checkpoint:

```sql
PRAGMA wal_checkpoint(TRUNCATE);
PRAGMA journal_mode = DELETE;
```

Nếu không checkpoint, dữ liệu trong `.db-wal` sẽ mất.

#### Rollback mức 2 — khôi phục DB từ backup

```powershell
# Trên máy khách
Stop-Process -Name BOOTHME -ErrorAction SilentlyContinue
$app = "C:\Program Files\BOOTHME"
Copy-Item "$app\data\photobooth.db"      "$app\data\photobooth.db.failed-$(Get-Date -f yyyyMMdd-HHmmss)"
Remove-Item "$app\data\photobooth.db-wal","$app\data\photobooth.db-shm" -ErrorAction SilentlyContinue
Copy-Item "$app\data\backups\photobooth.db.bak-v26-<timestamp>" "$app\data\photobooth.db"
```

⚠️ **Mất mọi dữ liệu phát sinh sau thời điểm backup.** Phải cân nhắc:
nếu backup từ 3 ngày trước thì mất 3 ngày doanh thu. Ưu tiên rollback mức 1.

#### Rollback schema — KHÔNG CÓ

SQLite không hỗ trợ `DROP COLUMN` an toàn trên bản cũ, và `schema_version` chỉ
đi tiến. Đây là lý do **migration v27 chỉ được THÊM, không được sửa/xoá**:
nếu chỉ thêm thì bản EXE cũ vẫn chạy được trên DB mới.

**Kiểm chứng bắt buộc trong Phase 5 (test A5-9):**
cài EXE bản 2.3 (cũ) lên máy có DB v27 → app phải mở và chạy bình thường.

---

### PHASE 6 — Sync queue

**Điều gì có thể sai:** gửi trùng lên cloud, UI đứng, CPU cao, dữ liệu kẹt.

**Dữ liệu bị ảnh hưởng:** D1 production (có thể có bản ghi trùng).

#### Rollback mức 1 — tắt từng loại bằng cờ (khuyến nghị)

```cpp
constexpr bool kSyncQueueRevenue = false;   // quay về fire-and-forget
constexpr bool kSyncQueueSession = false;
constexpr bool kSyncQueueEvent   = false;
constexpr bool kSyncQueueVoucher = false;
```

Mục còn trong `sync_queue` **không bị mất** — vẫn nằm đó, có thể bật lại sau.

#### Rollback mức 2 — tạm dừng sync worker, giữ hàng đợi

```cpp
cloudSync->pause();     // Q_INVOKABLE, gọi được từ QML/màn hình quản trị
```

Dữ liệu tiếp tục được enqueue nhưng không gửi. Bật lại bằng `resume()`.

#### Rollback mức 3 — cài lại EXE bản Phase 5

`sync_queue` giữ nguyên dữ liệu, chỉ không có worker đọc. Vô hại.

#### Nếu đã gửi trùng lên D1 — xử lý (⛔ cần phê duyệt)

Nhờ thiết kế idempotent, khả năng trùng rất thấp. Nếu vẫn xảy ra:

```sql
-- CHỈ ĐỌC — phát hiện trùng
SELECT revenue_id, COUNT(*) c FROM revenue GROUP BY revenue_id HAVING c > 1;
SELECT hwid, event_id, session_id, COUNT(*) c FROM sessions
 GROUP BY hwid, event_id, session_id HAVING c > 1;
SELECT machine_hwid, session_id, COUNT(*) c FROM package_checkins
 GROUP BY machine_hwid, session_id HAVING c > 1;   -- ← khả năng cao nhất
```

`revenue` và `sessions` có PRIMARY KEY nên **không thể** trùng.
Chỉ `package_checkins` (AUTOINCREMENT, không UNIQUE) mới có nguy cơ.

Xoá trùng (⛔ **thay đổi production — cần phê duyệt riêng, phải export trước**):

```sql
-- Giữ dòng có id nhỏ nhất trong mỗi nhóm
DELETE FROM package_checkins
 WHERE id NOT IN (
   SELECT MIN(id) FROM package_checkins GROUP BY machine_hwid, session_id
 );
```

**Không tự động chạy. Không chạy nếu chưa export D1.**

---

### PHASE 8 — Phát hành

#### Rollback 1 máy (15 phút)

```text
1. Đóng BOOTHME.exe
2. Chạy file setup bản CŨ từ D:\releases\
3. Khôi phục key.json từ USB
4. Kiểm photobooth.db: kích thước, số dòng revenue_records
5. Mở app → chụp thử 1 phiên → in thử 1 ảnh
6. Ghi vào nhật ký triển khai: máy nào, lý do rollback, giờ nào
```

#### Rollback nhiều máy

Làm tuần tự, **không song song** — để nếu quy trình rollback có vấn đề thì phát hiện
sớm ở máy đầu tiên.

#### Nếu DB local hỏng sau khi cài

```text
1. Đổi tên photobooth.db → photobooth.db.corrupt-<timestamp>  (GIỮ LẠI, đừng xoá)
2. Khôi phục từ {app}\data\backups\ bản mới nhất
3. Nếu không có backup → khôi phục từ USB
4. Nếu vẫn không có → tạo DB mới trống (app tự tạo), CHẤP NHẬN MẤT DỮ LIỆU LOCAL
   nhưng dữ liệu đã đồng bộ lên cloud vẫn còn — có thể đối chiếu qua portal
5. Gửi file .corrupt cho kỹ thuật để phân tích
```

---

## 3. Rollback Cloudflare Worker (chỉ khi Phase 9)

**Chưa áp dụng cho Phase 1–8** vì không deploy Worker.

Nếu Phase 9 deploy và có vấn đề:

```bash
npx wrangler deployments list          # xem các bản đã deploy
npx wrangler rollback [deployment-id]  # quay lại bản trước
```

Cloudflare giữ lịch sử deployment (thường 10 bản gần nhất).
**Rollback Worker KHÔNG rollback được thay đổi dữ liệu D1** — nếu bản lỗi đã ghi
sai dữ liệu, phải khôi phục từ export.

⚠️ Sau khi rollback Worker: nếu bản lỗi đã thêm cột D1 mà bản cũ không biết →
bản cũ vẫn chạy được (SQLite bỏ qua cột thừa). Nhưng nếu bản lỗi **xoá** cột →
bản cũ sẽ hỏng. Đây là lý do **không bao giờ xoá cột D1**.

---

## 4. Rollback D1 (trường hợp xấu nhất)

**Hiện tại: KHÔNG THỰC HIỆN ĐƯỢC.** Không có backup.

Sau khi thiết lập export định kỳ (§1.5):

```bash
# ⛔⛔ CỰC KỲ NGUY HIỂM — CHỈ KHI ĐÃ MẤT DỮ LIỆU VÀ CÓ PHÊ DUYỆT BẰNG VĂN BẢN
# Không import đè lên DB đang chạy. Quy trình đúng:
# 1. Tạo D1 MỚI
npx wrangler d1 create boothme_restore_20260803
# 2. Import bản export vào D1 MỚI
npx wrangler d1 execute boothme_restore_20260803 --remote --file=d1-boothme_prod-2026-08-03.sql
# 3. Kiểm tra dữ liệu trong D1 mới
# 4. Đổi binding trong wrangler.toml sang D1 mới
# 5. Deploy Worker
# 6. Giữ D1 cũ ít nhất 30 ngày trước khi xoá
```

**Tuyệt đối không** `d1 execute --remote --file=` lên database đang chạy production.

---

## 5. Ma trận quyết định rollback

| Triệu chứng | Mức độ | Hành động | Thời gian |
| --- | --- | --- | --- |
| App không mở được | 🔴 Khẩn cấp | Cài lại bản cũ ngay | 15 phút |
| Không chụp / không in được | 🔴 Khẩn cấp | Cài lại bản cũ ngay | 15 phút |
| Mất dữ liệu doanh thu | 🔴 Khẩn cấp | Khôi phục DB từ backup + cài bản cũ | 30 phút |
| DB local hỏng | 🔴 Khẩn cấp | §2 Phase 8 "Nếu DB local hỏng" | 30 phút |
| Mở app > 60 giây | 🟠 Cao | Đảo cờ, build lại | 1 giờ |
| UI đứng khi mất mạng | 🟠 Cao | `cloudSync->pause()` + đảo cờ | 30 phút |
| Dữ liệu không lên cloud | 🟡 Trung bình | Điều tra `sync_queue`/`error_logs`, chưa cần rollback | — |
| Có bản ghi trùng trên cloud | 🟡 Trung bình | Tắt cờ sync loại đó, điều tra | 30 phút |
| CPU cao khi idle | 🟡 Trung bình | `pause()`, điều chỉnh chu kỳ tick | 1 giờ |
| Log có WARN mới | 🟢 Thấp | Ghi nhận, theo dõi | — |

---

## 6. Liên lạc khi rollback

| Vai trò | Trách nhiệm |
| --- | --- |
| Kỹ thuật viên tại chỗ | Thực hiện rollback theo checklist, ghi nhật ký |
| Người phê duyệt | Quyết định rollback toàn hệ thống hay chỉ 1 máy |
| Người phát triển | Phân tích nguyên nhân, chuẩn bị bản sửa |

Nhật ký rollback (bắt buộc ghi):

```text
Ngày giờ:
Máy:
Phiên bản đang chạy:
Phiên bản quay về:
Triệu chứng:
Hành động đã làm:
Dữ liệu có mất không? Mất bao nhiêu?
File log/DB hỏng đã lưu ở đâu:
Người thực hiện:
Người phê duyệt:
```

---

## 7. Kiểm thử rollback (bắt buộc trước Phase 8)

Không được coi kế hoạch rollback là "có sẵn" mà chưa thử.

| # | Bài kiểm thử | Tiêu chí đạt |
| --- | --- | --- |
| R-1 | Cài bản mới → cài đè bản cũ → mở app | App chạy bình thường, dữ liệu còn nguyên |
| R-2 | Cài EXE bản 2.3 (cũ) lên DB schema v27 | App mở được, không crash |
| R-3 | Khôi phục `photobooth.db` từ backup | Số dòng `revenue_records` khớp bản backup |
| R-4 | Tắt WAL sau khi đã bật (có checkpoint) | Không mất dữ liệu trong `.db-wal` |
| R-5 | Đảo cờ Phase 4 → build → cài | Màn hình đăng nhập Google xuất hiện trở lại |
| R-6 | `cloudSync->pause()` khi đang có 100 mục PENDING | Dừng gửi, hàng đợi giữ nguyên |
| R-7 | `resume()` sau khi pause 1 giờ | Gửi tiếp đủ 100 mục, không trùng |
| R-8 | Xoá `key.json` → mở app | App vẫn mở, chỉ tắt tính năng cloud (không crash) |
| R-9 | Khôi phục `key.json` sau khi installer ghi đè | Kết nối cloud hoạt động lại |

Kết quả từng bài phải được ghi lại kèm ngày giờ và người thực hiện.
