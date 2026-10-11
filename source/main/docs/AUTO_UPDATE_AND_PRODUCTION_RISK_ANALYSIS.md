# AUTO UPDATE AND PRODUCTION RISK ANALYSIS

Ngày lập: 2026-08-03. Phương pháp: chỉ đọc mã nguồn, script build, script installer.

---

## 1. KẾT LUẬN

> **Phần mềm KHÔNG có auto-updater dưới bất kỳ hình thức nào.**
> Mọi bản cập nhật đều phải build thủ công và cài thủ công qua Inno Setup.

Đây là trạng thái **đúng với yêu cầu**. Không cần tắt gì thêm ở khía cạnh này.

---

## 2. Kiểm tra từng hạng mục (theo mục 6 của yêu cầu)

| Hạng mục | Có? | Bằng chứng |
| --- | --- | --- |
| Auto updater | **KHÔNG** | Không có class/file nào tên `*Updater*`. Tìm `autoUpdate\|auto_update\|checkForUpdate\|updateChecker` trong `src/**`, `qml/**` → 0 kết quả nghiệp vụ |
| Update checker | **KHÔNG** | Không có request nào tới endpoint version/release |
| Download bản mới | **KHÔNG** | Không có `QNetworkAccessManager` nào tải `.exe`/`.zip`. Các QNAM trong repo: `DynamoDBClient`, `LicenseStore`, `QrLoginManager`, `GoogleAuthManager`, `S3Uploader` — tất cả chỉ gọi Worker/Google/S3 |
| Tự thay EXE | **KHÔNG** | Không có `QFile::rename`/`copy` nào nhắm vào `applicationFilePath()` |
| Tự cập nhật cấu hình | **KHÔNG** | `key.json` chỉ được **đọc** ([ConfigManager.cpp:161-166](src/backend/ConfigManager.cpp#L161-L166)). Không có code ghi lại `key.json` |
| Tự cập nhật database | **CÓ — nhưng chỉ SQLite local** | Xem mục 3 |
| Tự cập nhật schema | **CÓ — chỉ SQLite local**; D1 **KHÔNG** | Xem mục 3 và 4 |
| Tự chạy migration | **CÓ — chỉ SQLite local**; D1 **KHÔNG** | Xem mục 3 và 4 |
| Tự tải file từ server | **KHÔNG** (chỉ upload lên S3, không tải về) | `S3Uploader` chỉ PUT |
| Tự thay endpoint | **KHÔNG** | `cloudApiBaseUrl` đọc 1 lần từ `key.json`, không có code ghi đè |
| Tự thay Worker URL | **KHÔNG** | Như trên |

Tìm kiếm đã thực hiện trên `*.cpp, *.h, *.qml, *.json, *.iss, *.txt, *.ps1, *.ts`
(loại trừ `node_modules`), từ khoá: `autoUpdate`, `auto_update`, `checkForUpdate`,
`updateChecker`, `installer`, `Setup.exe`, `releases/`, `update_url`, `app_version`,
`APP_VERSION`, `latest`, `version.json`.

Kết quả duy nhất liên quan: `installer.iss`, `installer_assets/README.txt`,
`build-ptb.ps1` — đều là **build/cài thủ công**.

---

## 3. Auto-migration SQLite LOCAL (có, và chạy mỗi lần mở app)

### 3.1 Cơ chế

[src/main.cpp:177](src/main.cpp#L177) → `DatabaseManager::initialize()` →
[DatabaseManager::createTables()](src/backend/DatabaseManager.cpp#L44).

```text
createTables()
 ├─ CREATE TABLE IF NOT EXISTS schema_version
 ├─ CREATE TABLE IF NOT EXISTS events            (+ 14 × ALTER TABLE ADD COLUMN, lỗi bị nuốt)
 ├─ CREATE TABLE IF NOT EXISTS photos
 ├─ CREATE TABLE IF NOT EXISTS printer_settings
 ├─ currentVersion = getSchemaVersion()
 ├─ if (currentVersion < 1)  applyMigration_v1()
 ├─ …
 └─ if (currentVersion < 26) applyMigration_v26()
```

26 migration, mỗi migration kết thúc bằng `setSchemaVersion(n)`.
Có thêm khối "failsafe" ([DatabaseManager.cpp:321-406](src/backend/DatabaseManager.cpp#L321-L406))
tạo lại `users`, `vouchers`, `revenue_records`, `employees` nếu thiếu.

### 3.2 Danh sách migration local

| v | Nội dung | Bảng/cột |
| --- | --- | --- |
| 1 | Tạo `machines`, `sessions` | |
| 2 | Tạo `upload_queue`; `photos.session_id`, `photos.upload_status` | |
| 3 | `events.landing_background`, `events.mode_selection_background` | |
| 4 | Tạo `app_settings` | |
| 5–12 | Cột `events`: `live_view_overlay`, `first/next_shot_countdown`, `shooting_mode`, `manual_photo_count`, `live_view_background`, `pose_guide`, `print_count`, `print_count_cut/nocut`; `photos.session_id` | |
| 13 | Tạo `users` | |
| 14 | Tạo `vouchers` | |
| 15 | Tạo `revenue_records` | |
| 16 | Tạo `employees` | |
| 17 | Cột nhân viên/hiệu lực cho `vouchers` + `revenue_records` | |
| 18 | `vouchers.shift` | |
| 19 | `revenue_records.shift/source/received_amount` | |
| 20 | `revenue_records.note` | |
| 21 | `revenue_records.voucher_amount` | |
| 22 | Tạo `event_settings` | |
| 23 | 15 cột vòng đời chụp cho `sessions` (gồm **`sync_pending`**) + UPDATE backfill | |
| 24 | `vouchers.created_via`, `vouchers.synced` | |
| 25 | `vouchers.note` | |
| 26 | `vouchers.package_minutes/package_prints/package_name` | |

### 3.3 Rủi ro của auto-migration local

| Rủi ro | Mức | Ghi chú |
| --- | --- | --- |
| Migration v23 chạy `UPDATE sessions SET status = … WHERE status_updated_at IS NULL` — **ghi đè dữ liệu** trên DB khách | 🟠 TRUNG BÌNH | Đã chạy ở mọi máy production hiện tại; chỉ ảnh hưởng lần nâng cấp đầu |
| Migration thất bại giữa chừng → `setSchemaVersion()` không chạy → lần mở sau chạy lại từ đầu | 🟠 TRUNG BÌNH | Các `ALTER TABLE ADD COLUMN` bỏ qua lỗi "duplicate column" nên phần lớn idempotent |
| `createTables()` trả false → **`main()` return -1, app thoát không giải thích** | 🔴 CAO | Xem mục 6.1 của [CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md](CLIENT_AUTHENTICATION_REMOVAL_ANALYSIS.md) |
| Không có backup trước migration | 🔴 CAO | Nếu migration hỏng DB, không có bản sao |
| Không thể hạ cấp (downgrade) schema | 🟠 TRUNG BÌNH | Cài lại EXE cũ trên DB v26 có thể lỗi cột không tồn tại |

**Đề xuất (Phase 5):** trước khi chạy migration, copy `photobooth.db` →
`photobooth.db.bak-v<current>-<timestamp>`, giữ tối đa 3 bản.

---

## 4. Auto-migration D1 — KHÔNG CÓ (tốt)

Đã kiểm tra toàn bộ [cloudflare/worker/src/index.ts](cloudflare/worker/src/index.ts) (2907 dòng):

* Không có `CREATE TABLE` nào trong runtime Worker.
* Không có `ALTER TABLE` nào trong runtime Worker.
* Không có `DROP TABLE` nào trong runtime Worker.
* Không có handler `scheduled` (cron trigger).
* Không có logic "khởi động Worker" — Worker là stateless, chỉ có `fetch()`.

**Nhưng Worker CÓ ghi dữ liệu ngoài ý muốn trong các route GET** (seed lazy) — chi tiết
ở mục R-01 của [D1_PRODUCTION_BEHAVIOR_ANALYSIS.md](D1_PRODUCTION_BEHAVIOR_ANALYSIS.md).

---

## 5. Script nguy hiểm nếu chạy nhầm

| Script / lệnh | Nguy cơ | Mức |
| --- | --- | --- |
| `cloudflare/worker/migrations/005_revenue_v2.sql` | `DROP TABLE revenue;` — chạy lần 2 = **mất toàn bộ doanh thu cloud** | 🔴 CAO NHẤT |
| `cloudflare/worker/migrations/004_plans_v2.sql` | `DELETE FROM plans WHERE code IN (…)` + `INSERT OR REPLACE` ghi đè giá gói | 🔴 CAO |
| `npm run db:init:remote` (package.json:9) | `wrangler d1 execute vietbooth --remote --file=./schema.sql`. Tên DB `vietbooth` **không tồn tại** trong `wrangler.toml` → hiện tại lệnh sẽ lỗi. Nếu ai đó "sửa cho đúng" thành `boothme_prod` rồi chạy: `CREATE TABLE IF NOT EXISTS` an toàn, nhưng `INSERT OR IGNORE INTO plans` sẽ thêm lại 5 gói mặc định | 🟠 TRUNG BÌNH |
| `npm run db:init` (local miniflare) | An toàn (không `--remote`) | 🟢 |
| `npm run deploy` (`wrangler deploy`) | **Deploy Worker lên production ngay lập tức**, không có staging, không có canary | 🔴 CAO |
| `npx wrangler dev --remote` | Chạm **thẳng D1 production** từ máy dev | 🔴 CAO |
| `npx wrangler secret put API_TOKEN` | Rotate token → **mọi máy khách mất kết nối** cho tới khi cập nhật `key.json` | 🔴 CAO |
| Mọi migration `001`–`016` | D1 không có `ADD COLUMN IF NOT EXISTS` → chạy lần 2 lỗi giữa chừng, để lại schema nửa vời | 🟠 TRUNG BÌNH |
| `scripts/disable-usb-power-saving.ps1` | Chỉ sửa power plan Windows, an toàn | 🟢 |
| `build-ptb.ps1 -Clean` | Xoá thư mục build local | 🟢 |

### 5.1 Không có cơ chế theo dõi migration nào đã áp

D1 không có bảng `_migrations` trong repo này. Không có cách biết chắc migration
nào đã chạy trên production ngoài việc **đọc schema thật**
(`PRAGMA table_info(...)` qua `wrangler d1 execute --remote --command`, chỉ SELECT).

→ Trạng thái áp dụng migration trên production: **CHƯA XÁC ĐỊNH**.

---

## 6. Quy trình phát hành hiện tại (thủ công 100%)

```text
1. build-ptb.ps1              → cmake configure + build
                                 -DPHOTOBOOTH_ONLY=ON, -DUSE_DUAL_SDK=ON
                                 output: build_studio3\bin\Release\BOOTHME.exe
2. (windeployqt chạy trong CMake, gom Qt DLL + plugin)
3. iscc installer.iss          → installer-output\BOOTHME-Setup-2.3-Fuji.exe
4. Copy file setup sang máy khách, chạy tay (cần quyền admin)
```

### 6.1 Hành vi installer đáng lưu ý — [installer.iss](installer.iss)

| Dòng | Hành vi | Đánh giá |
| --- | --- | --- |
| 14 | `BuildDir = build_studio2\bin\Release` | ⚠️ **KHÔNG khớp** `build-ptb.ps1` (dùng `build_studio3`). Dễ đóng gói nhầm bản cũ |
| 54-85 | `[InstallDelete]` xoá 30 mục — gồm cả thư mục `qml`, `platforms`, `tls`, `relay`, `CrAdapter` | 🟠 Nếu cài đè thất bại giữa chừng → app hỏng, không tự phục hồi |
| 90 | Ghi đè `key.json` bằng bản trong build | 🔴 **Cấu hình riêng của khách (nếu có) bị mất** |
| 101 | `Excludes: …,logs\*,captures\*,pending_uploads\*,data\photobooth.db` | ✅ Giữ ảnh chờ upload và log |
| 104 | `data\photobooth.db` — `onlyifdoesntexist` | ✅ **Không ghi đè DB khách** |
| 45 | `CloseApplications=yes` | ⚠️ Đóng app đang chạy — nếu đang chụp/in sẽ mất phiên |
| 40 | `PrivilegesRequired=admin` | |
| 127-129 | Tự chạy app sau cài (`postinstall`) | |
| 141-155 | `PatchLinkRunAsAdmin` — sửa byte 22 của shortcut để chạy as-admin | ⚠️ Thao tác nhị phân thô, không kiểm tra định dạng .lnk |
| 157-178 | `VerifyKeyJson` — cảnh báo nếu thiếu `s3_settings`/`cloud_api` | ✅ |
| 180-202 | `VerifyRequiredRuntime` — kiểm 12 DLL bắt buộc | ✅ |

### 6.2 Rủi ro phát hành

| Rủi ro | Mức | Giảm nhẹ |
| --- | --- | --- |
| `installer.iss` trỏ `build_studio2` nhưng script build ra `build_studio3` | 🔴 CAO | **Sửa `installer.iss` dòng 14** hoặc luôn kiểm tra timestamp `BOOTHME.exe` trước khi `iscc` |
| `key.json` bị ghi đè khi nâng cấp | 🔴 CAO | Backup `key.json` của khách trước khi cài; hoặc đổi flag thành `onlyifdoesntexist` |
| Không có số phiên bản trong EXE để đối chiếu | 🟠 | `AppVersion=2.3` chỉ trong installer, không có `QCoreApplication::setApplicationVersion()` trong `main.cpp` |
| `CloseApplications=yes` giết app giữa phiên chụp | 🟠 | Chỉ cài ngoài giờ hoạt động |
| Không có rollback installer | 🔴 CAO | Phải giữ file setup bản cũ (xem [ROLLBACK_PLAN.md](ROLLBACK_PLAN.md)) |
| Cài đè xoá thư mục `qml`, `platforms` trước khi copy → nếu treo giữa chừng, app không chạy | 🟠 | Backup toàn bộ thư mục `{app}` trước khi cài |

---

## 7. Chính sách bắt buộc trong giai đoạn này

```text
KHÔNG bật auto update.
KHÔNG tự động phát hành bản mới.
KHÔNG tự động cập nhật máy khách.
KHÔNG chạy `npm run deploy`.
KHÔNG chạy `wrangler dev --remote`.
KHÔNG chạy bất kỳ file trong cloudflare/worker/migrations/.
KHÔNG chạy `npm run db:init:remote`.
KHÔNG rotate API_TOKEN.
```

Mọi bản cập nhật phải qua đủ 8 bước (theo yêu cầu mục 6):

1. Build thủ công bằng `build-ptb.ps1` (ghi lại commit hash + timestamp).
2. Kiểm thử trên máy development.
3. Kiểm thử trên database local (bản sao DB thật của 1 máy khách).
4. Kiểm thử trên môi trường staging — **hiện chưa có, cần dựng** (xem [SAFE_MIGRATION_PLAN.md](SAFE_MIGRATION_PLAN.md)).
5. Backup: `{app}\data\photobooth.db`, `{app}\key.json`, toàn bộ `{app}` nếu đủ dung lượng.
6. Kế hoạch rollback: giữ file setup bản cũ + bản sao thư mục `{app}` ([ROLLBACK_PLAN.md](ROLLBACK_PLAN.md)).
7. Phê duyệt thủ công (người chịu trách nhiệm ký nhận).
8. Cài thủ công theo nhóm: 1 máy test → theo dõi 48 h → 1 máy production → theo dõi 1 tuần → phần còn lại.

---

## 8. Bảng tóm tắt rủi ro tài liệu này

| Mã | Rủi ro | Mức |
| --- | --- | --- |
| U-01 | `installer.iss` đóng gói từ `build_studio2` trong khi build ra `build_studio3` | 🔴 CAO |
| U-02 | Installer ghi đè `key.json` của khách | 🔴 CAO |
| U-03 | `005_revenue_v2.sql` chứa `DROP TABLE revenue` | 🔴 CAO |
| U-04 | `npm run deploy` deploy thẳng production, không staging | 🔴 CAO |
| U-05 | `wrangler dev --remote` chạm D1 production từ máy dev | 🔴 CAO |
| U-06 | Không có backup SQLite trước auto-migration | 🔴 CAO |
| U-07 | `createTables()` lỗi → app thoát `return -1` | 🔴 CAO |
| U-08 | Không biết migration D1 nào đã áp (không có bảng theo dõi) | 🟠 TRUNG BÌNH |
| U-09 | `CloseApplications=yes` giết app giữa phiên | 🟠 TRUNG BÌNH |
| U-10 | Không có version string trong EXE | 🟠 TRUNG BÌNH |
| — | **Không có auto-update** | 🟢 ĐÚNG YÊU CẦU |
| — | **Không có auto-migration D1** | 🟢 ĐÚNG YÊU CẦU |
| — | Installer giữ `photobooth.db` và `pending_uploads` | 🟢 ĐÚNG YÊU CẦU |
