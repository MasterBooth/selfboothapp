# Báo cáo D1 `selfboothvn` + API `/v1` — cho agents làm web

Cập nhật: 2026-10-01. Nguồn chuẩn:
- Schema: `source/main/cloudflare/selfboothvn-api/migrations/0001_init.sql`
- API: `source/main/cloudflare/selfboothvn-api/src/*.ts`

Web **dùng chung** D1 và R2 này với app desktop. Không đổi tên cột hay ý nghĩa dữ liệu khi chưa cập nhật app.

## 1. Hạ tầng

| Thành phần | Giá trị |
|---|---|
| Worker API | `selfboothvn-api`, URL `https://selfboothvn-api.thientiva.workers.dev` |
| D1 | `selfboothvn`, id `1d7d57db-5739-4810-b912-94339fb2968a`, binding `DB` |
| R2 | bucket `selfboothvn` (private), binding `MEDIA` |
| Gói Workers | Paid (bắt buộc, vì hash mật khẩu PBKDF2 100 000 vòng) |
| Migration | `npx wrangler d1 migrations apply selfboothvn --remote` (thư mục `migrations/`) |

Secret của Worker (không ghi trong repo): `API_TOKEN` (token bootstrap, trùng `cloud_api.api_token` trong `key.json` của app), `ADMIN_API_TOKEN`, `UPLOAD_SIGNING_SECRET`.

## 2. Quy ước dữ liệu

- `id`: TEXT, UUID v4.
- Thời gian: TEXT ISO-8601 UTC, ví dụ `2026-10-01T08:00:00.000Z`. **Ngoại lệ:** `revenue_records.recorded_at` là giờ ghi tại máy, lấy nguyên chuỗi app gửi (giờ địa phương, không có múi giờ).
- Tiền: INTEGER VND.
- Tenant: mọi bảng nghiệp vụ có `studio_id`. **Mọi truy vấn của web phải lọc theo `studio_id` của người đang đăng nhập.**
- Email: luôn lưu chữ thường, đã trim.
- `session_id` do app sinh (`session_YYYYMMDD_HHmmss_XXXX`) và chỉ duy nhất **trong một máy**. Khóa của phiên là `(machine_id, session_id)`.

## 3. Bảng

| Bảng | Khóa | Nội dung chính |
|---|---|---|
| `studios` | `id` | `name`, `status` (`active` \| `suspended`) |
| `studio_users` | `id`; `email` UNIQUE | `studio_id`, `password_hash`, `role` (`owner` \| `staff`), `status` (`active` \| `disabled`), `last_login_at` |
| `login_attempts` | `email` | `fail_count`, `locked_until`: khóa 15 phút sau 10 lần sai liên tiếp |
| `machines` | `id`; `hwid` UNIQUE | `studio_id` (NULL = chưa gắn), `device_name`, `app_version`, `status`, `first_seen_at`, `last_seen_at`, `linked_at` |
| `machine_tokens` | `token_hash` (SHA-256 hex) | `machine_id`, `studio_id`, `user_id`, `revoked_at` |
| `capture_sessions` | `(machine_id, session_id)` | `studio_id`, `event_id` (id sự kiện trong DB local của máy), `operation_mode`, `status`, `status_version`, `photos_count`, `expected_photos`, `started_at`, `ended_at`, `code_use_id` |
| `session_photos` | `object_key` | `studio_id`, `machine_id`, `session_id`, `kind` (`photo` \| `manifest` \| `collage` \| `video` \| `other`), `content_type`, `size_bytes`, `uploaded_at` |
| `package_codes` | `id`; UNIQUE `(studio_id, code)` khi `status='active'` | `code` (4 số, TEXT, giữ số 0 đầu), `kind` (`single` \| `reusable`), `minutes`, `price_vnd`, `status` (`active` \| `used` \| `revoked`), `valid_from`, `valid_until`, `note`, `used_at`, `used_machine_id`, `used_session_id` |
| `package_code_uses` | `id` (= `use_id` do app sinh) | `code_id`, `code`, `kind`, `machine_id`, `session_id`, `minutes`, `price_vnd`, `used_at`, `source` (`online` \| `offline`) |
| `revenue_records` | `id` (= `revenue_id` do app sinh, sha256 hex) | `machine_id`, `session_id`, `event_id`, `event_name`, `recorded_at`, `amount_required`, `received_amount`, `cash_received`, `transfer_amount`, `change_amount`, `voucher_amount`, `print_count`, `payment_method`, `source`, `note` |

Quan hệ: `studios` 1–n `studio_users`, `machines`, `package_codes`, `capture_sessions`, `session_photos`, `revenue_records`. Phiên nối với ảnh qua `(machine_id, session_id)`, với doanh thu qua `(machine_id, session_id)`, và với lượt dùng mã qua `capture_sessions.code_use_id = package_code_uses.id`.

Số liệu hay dùng:
- **Doanh thu:** tổng `received_amount` theo `studio_id` và khoảng `recorded_at`. Mã gói ghi `payment_method = 'prepaid_code'`, `amount_required = received_amount = price_vnd`.
- **Lượt dùng mã:** đếm `package_code_uses`.
- **Số ảnh:** `session_photos` với `kind = 'photo'`.

## 4. Mật khẩu

- Định dạng lưu: `pbkdf2_sha256$<iterations>$<salt_base64>$<hash_base64>`.
- Tham số: PBKDF2-HMAC-SHA256, salt 16 byte, 100 000 vòng, khóa 32 byte, base64 chuẩn (có padding).
- Tối thiểu 8 ký tự, tối đa 128.
- Web **phải** hash và verify đúng định dạng này (tham khảo `src/password.ts`). Không lưu mật khẩu dạng chữ thường. Không đổi định dạng khi chưa có cơ chế nâng cấp hash.
- Khi email không tồn tại, vẫn chạy một lần derive giả để thời gian phản hồi không làm lộ email nào đã đăng ký.

## 5. Mô hình xác thực

| Loại token | Ai dùng | Phạm vi |
|---|---|---|
| Bootstrap (`API_TOKEN`) | App desktop | Chỉ dùng cho `POST /v1/machines/register`, `/v1/studios/register`, `/v1/auth/login`. Token này nằm trong `key.json` ở mọi máy, nên **coi như công khai** và không được mở thêm quyền đọc dữ liệu cho nó. |
| Máy (`mt_…`) | App desktop | Cấp khi studio đăng nhập trên máy, mỗi máy một token. Server lấy `hwid`, `machine_id`, `studio_id` **từ token**, không tin giá trị trong body. Đăng nhập lại trên máy sẽ thu hồi token cũ. Máy chuyển sang studio khác thì token cũ hết hiệu lực. |
| Admin (`ADMIN_API_TOKEN`) | Vận hành (trước khi có web) | `/v1/admin/*`: tạo và thu hồi mã, xem danh sách studio. |

**Web chưa có phiên đăng nhập.** Web cần tự làm, đề xuất:
- Bảng `web_sessions(token_hash PK, user_id, studio_id, created_at, expires_at, revoked_at)`.
- Cookie `HttpOnly`, `Secure`, `SameSite=Lax`.
- Dùng lại `studio_users` và `login_attempts`.

Không cấp token máy cho trình duyệt.

## 6. R2

- Bố cục key: `studio/<hwid>/<session_id>/photos/<NNN>_<tên file>`, `.../photos.json` (manifest: `sessionId`, `eventId`, `hwid`, `photoCount`, `photos[]`), và `.../collage.<ext>`, `.../video.<ext>` (mode1/mode2).
- Thư mục gốc `studio/` là **cố định**, không phải id của studio. Muốn biết ảnh thuộc studio nào thì tra `session_photos.studio_id`, không suy ra từ key.
- Xem ảnh: `GET /media/<object_key>` là công khai, hỗ trợ `Range`, `cache-control: immutable`. Gallery chỉ nên đưa ra link của phiên mà khách được phép xem.

## 7. API `/v1`

Lỗi luôn có dạng `{ "success": false, "error": "<mã ổn định>", "message"?: "<tiếng Việt>" }`. Thành công có `"success": true`.

### Tài khoản và máy
| Method | Route | Auth | Body | Trả về |
|---|---|---|---|---|
| POST | `/v1/machines/register` | bootstrap | `hwid, device_name?, app_version?` | `machine_id, studio: null\|{id,name}` |
| POST | `/v1/studios/register` | bootstrap | `hwid, studio_name, email, password` | 201 `token, studio, user, machine_id`. Lỗi: `email_taken` 409, `password_too_short`, `invalid_email`, `studio_name_required` 400 |
| POST | `/v1/auth/login` | bootstrap | `hwid, email, password` | `token, studio, user, machine_id`. Lỗi: `invalid_credentials` 401, `login_locked` 429, `user_disabled` / `studio_suspended` / `machine_disabled` 403 |
| POST | `/v1/auth/logout` | máy | — | thu hồi token hiện tại |
| GET | `/v1/machine/me` | máy | — | `machine, studio, user` |

`hwid`: 8–128 ký tự `[A-Za-z0-9._-]`.

### Dữ liệu từ máy
| Method | Route | Body | Ghi chú |
|---|---|---|---|
| POST | `/v1/uploads/presign` | `object_key, content_type` | key phải là `studio/<hwid của token>/<session_id>/…`, nếu không trả 403 `object_key_prefix_mismatch`. Trả về `upload_url` (hạn 15 phút) và `public_url` |
| PUT | `/upload/object?key&exp&ct&m&s&sig` | nội dung file | có chữ ký HMAC, bắt buộc có `Content-Type` và `Content-Length`. Ghi vào R2 rồi upsert `session_photos` |
| PUT | `/v1/machine/sessions/{session_id}` | `event_id, operation_mode, status, status_version, photos_count, expected_photos, started_at?, ended_at?, code_use_id?` | upsert; bản có `status_version` nhỏ hơn bản đang lưu bị bỏ qua (`applied:false`) |
| POST | `/v1/machine/revenue` | `revenue_id (64 hex), recorded_at, session_id, event_id, event_name, amount_required, received_amount, cash_received, transfer_amount, change_amount, voucher_amount, print_count, payment_method, source, note` | INSERT OR IGNORE; trả về `inserted` |
| POST | `/v1/machine/codes/redeem` | `code, session_id, use_id` | trả về `use_id, code_id, kind, minutes, price_vnd`. Lỗi: `code_invalid` 404, `code_used` 409, `code_expired` / `code_not_yet_valid` 410. Gửi lại cùng `use_id` trả về đúng kết quả cũ |
| POST | `/v1/machine/codes/uses` | `uses:[{use_id, code, session_id, used_at}]` (tối đa 100) | lượt dùng mã **dùng lại** mà app nhận khi mất mạng |
| GET | `/v1/machine/codes/reusable` | — | danh sách mã dùng lại đang active, app cache để dùng khi offline |

### Admin
| Method | Route | Body |
|---|---|---|
| GET | `/v1/admin/studios` | — |
| POST | `/v1/admin/studios/{studio_id}/codes` | `kind, minutes, price_vnd, code? , count? (1..100, khi không có code), valid_from?, valid_until?, note?` |
| GET | `/v1/admin/studios/{studio_id}/codes?status=` | — |
| POST | `/v1/admin/codes/{id}/revoke` | — |

Ví dụ tạo mã (PowerShell, token admin lưu ở `%USERPROFILE%\.selfboothvn\admin_token.txt`):
```powershell
$t = Get-Content "$env:USERPROFILE\.selfboothvn\admin_token.txt" -Raw
Invoke-RestMethod -Method Post "https://selfboothvn-api.thientiva.workers.dev/v1/admin/studios/<studio_id>/codes" `
  -Headers @{ Authorization = "Bearer $t" } -ContentType "application/json" `
  -Body '{"kind":"reusable","code":"0000","minutes":1,"price_vnd":50000}'
```

## 8. Luồng dữ liệu của app

1. Lần chạy đầu: app gọi `machines/register`, rồi **bắt buộc** hiện màn đăng nhập hoặc đăng ký studio. Đăng nhập xong app nhận token máy và lưu vào QSettings `BoothOS/Studio`.
2. Chụp (mode3):
   - Khách nhập mã 4 số, bấm Next, app gọi `codes/redeem`.
   - Nếu mất mạng: app chỉ nhận mã **dùng lại** có trong cache, rồi đẩy lượt dùng lên `codes/uses` khi có mạng.
   - Mã dùng 1 lần luôn cần có mạng.
3. App ghi doanh thu bằng `price_vnd` của mã và gắn `code_use_id` vào phiên.
4. Ảnh: presign rồi PUT, Worker ghi `session_photos`. Chưa đăng nhập hoặc mất mạng thì file nằm chờ trên máy, đăng nhập hoặc có mạng lại thì tự đẩy lên.
5. Phiên và doanh thu đi qua hàng đợi bền `cloud_outbox` (SQLite của máy). Gửi lặp an toàn vì server idempotent. Lỗi 4xx được đánh dấu `failed` trên máy và không gửi lại.

## 9. Việc web cần làm và điểm cần lưu ý

- Phiên đăng nhập web (mục 5), trang đăng ký/đăng nhập dùng chung `studio_users`.
- Quản lý mã gói theo studio. Có thể gọi thẳng D1 hoặc làm route mới có kiểm tra phiên web. **Không** đưa `ADMIN_API_TOKEN` ra trình duyệt.
- Báo cáo doanh thu, phiên, ảnh theo studio (mục 3).
- Gallery cho khách: link QR của app hiện vẫn là `https://lamoment.vercel.app/gallery/<studioId>/<hwid>/<eventId>/<sessionId>` (web cũ đã xóa). Khi có web mới, đổi `web.gallery_base_url` trong `key.json`. Định dạng đường dẫn cần thống nhất lại với app, vì `studioId` trong link hiện là số, không phải UUID của `studios`.

## 10. Chưa làm

- License và cưỡng chế bản quyền: app đang tự kích hoạt (bypass).
- Tài khoản nhân viên (`role = 'staff'`): đã có cột nhưng chưa có luồng tạo.
- Đổi hoặc quên mật khẩu, xác minh email.
- Xóa hoặc hết hạn dữ liệu (ảnh R2, bản ghi), xuất báo cáo.
- Các route cũ app còn gọi nhưng Worker mới **không có**, nên hiện đang trả 404 và chỉ tạo log lỗi, không chặn app: đồng bộ sự kiện `/machine/{hwid}/event`, voucher/mã kiểu cũ `/machine/{hwid}/vouchers*`, kích hoạt/license, QR login, đồng bộ frame/filter/background/payment-jobs, `/shared-moments/consent`.
