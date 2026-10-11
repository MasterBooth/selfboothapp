# API mà app desktop (BOOTHME) đang gọi

> **Đã thay thế (2026-10-01):** hợp đồng hiện hành là API `/v1` trên D1 và R2 `selfboothvn`, xem [D1_REPORT.md](D1_REPORT.md). Tài liệu dưới đây mô tả API của Worker cũ (đã xóa) và chỉ giữ lại để tham khảo.

Tài liệu này mô tả hợp đồng API mà app desktop hiện đang dùng với Worker `lamoment-api` (Cloudflare Worker + D1 + R2). Web mới dùng nó để quyết định giữ nguyên các route này hay định nghĩa API mới, ví dụ `/api/v1`. Nếu chọn API mới, app phải được sửa lại theo, nên cần có tài liệu của API mới trước khi sửa app.

Nguồn: `source/main/src/backend/*.cpp`, cập nhật 2026-10-01.

## 1. Cấu hình phía app (`key.json` cạnh exe)

| Trường | Dùng cho |
|---|---|
| `cloud_api.base_url` | Gốc URL của mọi route bên dưới |
| `cloud_api.api_token` | Header `Authorization: Bearer <api_token>`. Mọi request của app đều gửi header này |
| `r2_settings.bucket_name`, `account_id`, `public_base_url` | Gửi kèm khi xin presign (chỉ để tham khảo). URL ảnh công khai = `public_base_url/<object key>` |
| `web.gallery_base_url` (tùy chọn) | Gốc link gallery trong QR. Không có thì dùng `https://lamoment.vercel.app/gallery` |

App **không** giữ key R2. Mọi thao tác ghi vào R2 đều dùng presigned URL do server cấp.

## 2. Upload ảnh và video

### `POST /upload/presign`
Request (JSON):
```json
{
  "object_key": "studio/<hwid>/<sessionId>/<file>",
  "content_type": "image/jpeg",
  "bucket": "...", "region": "...", "public_base_url": "...",
  "hwid": "<hwid>", "session_id": "<sessionId>"
}
```
Response 2xx: `{ "upload_url": "<presigned PUT>", "public_url": "<url công khai>" }`. App bắt buộc phải nhận được cả hai trường.

Sau đó app gửi `PUT <upload_url>` với header `Content-Type` giống `content_type` ở trên và body là toàn bộ file (timeout 60 giây).

Cách app xử lý lỗi:
- HTTP 0 hoặc lỗi mạng: app lưu file vào hàng đợi offline và thử lại sau.
- 4xx/5xx: lỗi cứng, app không tự retry.

Worker hiện tại kiểm tra các điều sau:
- `object_key` phải bắt đầu bằng `studio/hwid/sessionId/`.
- Worker cũ còn yêu cầu máy có `activate = 1`. Worker `selfboothvn-api` hiện chỉ kiểm tra token.
- URL PUT có hạn 900 giây.

### Định dạng object key
| Loại | Key |
|---|---|
| Ảnh gốc | `studio/<hwid>/<sessionId>/photos/<NNN>_<tên file>` (NNN là số thứ tự 3 chữ số, bắt đầu từ 001) |
| Ảnh ghép | `studio/<hwid>/<sessionId>/collage.<ext>` |
| Video | `studio/<hwid>/<sessionId>/video.<ext>` |
| Manifest | `studio/<hwid>/<sessionId>/photos.json` (có ghi `eventId`) |

Cập nhật 2026-10-01: key không còn `eventId`. Tất cả nằm dưới thư mục gốc cố định `studio/`, sau đó là từng máy (`hwid`), rồi từng phiên. Worker `selfboothvn-api` kiểm tra prefix `studio/<hwid>/<sessionId>/`. Link QR gallery chưa đổi, sẽ quyết khi làm web.

Content-type theo đuôi file: jpg/jpeg `image/jpeg`, png `image/png`, webp `image/webp`, mp4 `video/mp4`, mov `video/quicktime`, json `application/json`. Các đuôi khác gửi `application/octet-stream`.

### `GET /media/<object key>`
Dùng để xem ảnh công khai (gallery và portal). Route này phải hỗ trợ header `Range` để tua video.

### `POST /shared-moments/consent`
Body: `{ hwid, event_id, session_id, allowed: bool, gallery_url }`. App chỉ đọc HTTP status.

### Link QR gallery
`<gallery_base_url>/<studioId>/<hwid>/<eventId>/<sessionId>`. Nếu chưa biết `studioId` thì dùng `0`.

## 3. Máy, sự kiện, phiên, doanh thu (`DynamoDBClient.cpp`)

| Method | Route | Body / ghi chú |
|---|---|---|
| GET | `/machine/{hwid}` | Đọc thông tin máy |
| POST | `/machine/{hwid}` | Đăng ký máy: `device_name`, `owner_email?`, `owner_name?`, `brand?` |
| PATCH | `/machine/{hwid}` | Gán chủ máy: `owner_email?`, `owner_name?`, `brand?` |
| PUT | `/machine/{hwid}/event` | `event_id, event_name, total_photos_captured, prints_cut, prints_nocut` |
| PUT | `/machine/{hwid}/session` | `event_id, session_id, printer_type, photos_captured, prints_cut, prints_nocut, total_prints, status, expected_photos, capture_started_at, ended_at, status_updated_at, failure_code, failure_message, camera_error_count, had_camera_error, status_version` |
| POST | `/machine/{hwid}/revenue` | `revenue_id` (sha256 của `hwid\|eventId\|sessionId\|source\|recorded_at`, dùng làm khóa idempotency), `event_id, event_name, session_id, recorded_at, print_count, amount_required, cash_received, transfer_amount, change_amount, payment_method, employee_id, shift, source, received_amount, voucher_amount, note` |

Mode3 ghi doanh thu 0đ với `payment_method = "prepaid_code"` và `note = "Mode3 code: <mã> (<n> phut)"` mỗi lần nhập mã hợp lệ.

## 4. Voucher và mã (`DynamoDBClient.cpp`)

App gọi phần lớn các route dưới đây theo kiểu đồng bộ (chờ kết quả, timeout 16 giây). Khi gặp lỗi mạng (HTTP 0), app chuyển sang dùng dữ liệu local.

| Method | Route | Ghi chú |
|---|---|---|
| GET | `/machine/{hwid}/vouchers/{code}` | Kiểm tra mã. App đọc `valid, type, value, package_minutes, package_prints, package_name`. `type = "package_code"` là mã gói chụp |
| POST | `/machine/{hwid}/vouchers/{code}/redeem` | Body `session_id, emp_id, paid_amount`. App đọc `success` |
| DELETE | `/machine/{hwid}/vouchers/{code}` | Xóa mã |
| POST | `/machine/{hwid}/vouchers` | Đẩy mã tạo tại máy lên: `{ vouchers: [...] }` |
| POST | `/machine/{hwid}/vouchers/generate` | Body `type, value, count, valid_from, valid_until, note, created_by` |
| GET | `/machine/{hwid}/vouchers[?status=unused\|used]` | Danh sách mã |
| GET | `/machine/{hwid}/voucher-notes`, `/voucher-prices`, `/voucher-durations` | App đọc trường `data` (mảng) |

Mode3 hiện dùng hai mã cố định `0000` và `9999`, kiểm tra ngay trong app và **không** gọi các route này.

## 5. Kích hoạt, license, đăng nhập QR

| Method | Route | Nguồn |
|---|---|---|
| POST | `/activation/request` | `ActivationClient.cpp` |
| GET | `/activation/status?hwid=&code=` | `ActivationClient.cpp` |
| GET | `/license/latest?hwid=` | `ActivationClient.cpp` |
| GET | `/plans` | `LicenseStore.cpp` |
| POST | `/machine/{hwid}/payment-intent` | `LicenseStore.cpp` |
| GET | `/machine/{hwid}/payment-intent/{code}` | `LicenseStore.cpp` |
| POST | `/machine/{hwid}/qr-session` | `QrLoginManager.cpp` |
| GET | `/machine/{hwid}/qr-session/{code}` | `QrLoginManager.cpp` |
| POST | `/machine/{hwid}/qr-session/{code}/consume` | `QrLoginManager.cpp` |
| GET | `/machine/{hwid}/studio-info` | `QrLoginManager.cpp` |

## 6. Đồng bộ nội dung từ web xuống máy (polling)

Mỗi loại dùng cùng một mẫu: app gọi `GET .../<loại>-jobs?status=pending`, tải file theo URL có trong job, rồi gọi `PATCH .../<loại>-jobs/{id}` để báo trạng thái.

| Loại | Route | Nguồn |
|---|---|---|
| Frame | `/machine/{hwid}/frame-jobs` | `FrameSyncManager.cpp` |
| Filter | `/machine/{hwid}/filter-jobs` | `FilterSyncManager.cpp` |
| Background | `/machine/{hwid}/background-jobs` | `BackgroundSyncManager.cpp` |
| Thanh toán | `/machine/{hwid}/payment-jobs` | `PaymentSyncManager.cpp` |

Trường chi tiết trong job và body của lệnh PATCH nằm trong từng file nguồn ở bảng trên.

## 7. Những điểm web mới cần quyết định

1. **Giữ các route trên hay chuyển sang `/api/v1`?** Nếu chuyển, cần có tài liệu API mới để sửa app. App có khoảng 10 client cần đổi.
2. **Xác thực máy.** Hiện mọi máy dùng chung một `api_token`, và Worker kiểm tra quyền theo `hwid`. `tech.md` yêu cầu không coi HWID là bằng chứng quyền truy cập, nên cơ chế này có thể phải đổi.
3. **Upload.** `tech.md` yêu cầu có manifest, server xác minh object sau khi upload, và chống ghi trùng. Luồng hiện tại chỉ có presign rồi PUT, chưa có bước báo hoàn tất.
4. **Database.** `tech.md` ghi PostgreSQL, nhưng môi trường test dự kiến dùng D1. Cần thống nhất trước khi viết API.
