# TEST PLAN

30 kịch bản bắt buộc theo mục 11 của yêu cầu, cộng các bài kiểm thử bổ sung.

Môi trường: **máy test riêng**, dùng **bản sao** DB thật của khách. Không kiểm thử
trên máy đang phục vụ khách. Không kiểm thử ghi lên D1 production trừ khi được
phê duyệt (dùng HWID test riêng, dễ nhận diện, ví dụ `TEST0000TEST0000`).

Ngày lập: 2026-08-03.

---

## 0. Chuẩn bị môi trường

### 0.1 Công cụ giả lập sự cố

| Sự cố | Cách giả lập |
| --- | --- |
| Mất Internet | Vô hiệu network adapter (`Disable-NetAdapter`) |
| Mất Internet (mềm) | `S3Uploader::setSimulateOffline(true)` — đã có sẵn ([S3Uploader.h:70](src/backend/S3Uploader.h#L70)) |
| DNS lỗi | Trỏ `boothme-api.boothstudio2026.workers.dev` → `127.0.0.1` trong `C:\Windows\System32\drivers\etc\hosts` |
| Worker 500 / 401 / timeout | Proxy local (mitmproxy / Fiddler) chặn và trả mã lỗi tuỳ ý |
| Cloudflare gián đoạn | Chặn dải IP Cloudflare bằng Windows Firewall |
| Mất điện | Rút nguồn thật (máy test không dùng UPS) hoặc `Stop-Process -Force` cho mô phỏng crash |
| Ổ đĩa đầy | Tạo file lớn chiếm chỗ (`fsutil file createnew filler.bin <bytes>`) |
| SQLite hỏng | Ghi rác vào giữa file `.db` bằng hex editor |

### 0.2 Dữ liệu cần ghi lại trước mỗi bài

```text
Phiên bản app:              (từ log "[SYS] App version")
schema_version:             SELECT version FROM schema_version ORDER BY version DESC LIMIT 1
Số phiên:                   SELECT COUNT(*) FROM sessions
Tổng doanh thu:             SELECT SUM(received_amount) FROM revenue_records
Số ảnh:                     SELECT COUNT(*) FROM photos
Số mục chờ đồng bộ:         SELECT COUNT(*) FROM sync_queue WHERE status != 'SYNCED'
Số file pending upload:     đếm file trong pending_uploads/
```

---

## 1. NHÓM A — MẤT KẾT NỐI (bài 1–10)

### A-01 · Máy không có Internet khi mở app

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Network adapter tắt. `HKCU\Software\BoothOS\GoogleAuth` đã xoá (chưa từng đăng nhập). |
| **Thao tác** | Mở BOOTHME.exe, bấm đồng hồ. |
| **Kỳ vọng** | Giao diện chính hiện ra < 30 giây. Không màn hình đăng nhập Google. Không popup "Xác thực máy". Không thông báo lỗi mạng cho khách. Chọn được sự kiện, chụp được. |
| **Không được** | Thoát app. Đứng hình. Hiện "Máy chưa được kích hoạt". Hiện "nâng cấp gói". |
| **Phase** | 4 |

### A-02 · D1 không phản hồi

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Có mạng. Proxy giữ request tới `/machine/*` không trả lời (treo). |
| **Thao tác** | Mở app, chạy 1 phiên chụp đầy đủ. |
| **Kỳ vọng** | App mở bình thường. Chụp/ghép/in/lưu doanh thu bình thường. Sau 15 s request tự huỷ, ghi `error_logs`. Mục vào `sync_queue` trạng thái RETRY. |
| **Không được** | UI đứng > 3 giây tại bất kỳ thời điểm nào. |
| **Phase** | 4 (mở app), 6 (queue) |

### A-03 · Worker trả lỗi 500

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Proxy trả `500 Internal Server Error` cho mọi request. |
| **Thao tác** | Chạy 5 phiên chụp có thanh toán. |
| **Kỳ vọng** | 5 phiên lưu đủ vào SQLite. 5 mục doanh thu + 5 mục session trong `sync_queue` trạng thái RETRY. `attempt_count` tăng theo thang 5s→15s→60s→5m→15m→30m. Không popup lỗi cho khách. |
| **Kiểm** | `SELECT status, attempt_count, next_retry_at FROM sync_queue` |
| **Phase** | 6 |

### A-04 · Worker trả lỗi 401

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Sửa `key.json` → `api_token` sai. Hoặc proxy trả 401. |
| **Thao tác** | Mở app, chạy 3 phiên. |
| **Kỳ vọng** | App mở bình thường, chạy bình thường. Mục trong `sync_queue` giữ trạng thái RETRY với `next_retry_at` ≥ 30 phút. Ghi `error_logs` mức CRITICAL. **KHÔNG** chuyển FAILED. |
| **Tiếp theo** | Sửa lại `api_token` đúng → khởi động lại → 3 mục phải tự đồng bộ trong 5 phút. |
| **Phase** | 6 |

### A-05 · Request timeout

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Proxy giữ kết nối mở, không trả dữ liệu. |
| **Thao tác** | Validate 1 mã voucher **do web tạo** (không phải mã local). |
| **Kỳ vọng** | UI chờ tối đa **3 giây** rồi fallback local, hiện kết quả. |
| **Trước Phase 6** | Chờ tới 16 giây (hành vi hiện tại — ghi nhận làm baseline). |
| **Phase** | 6 |

### A-06 · DNS không phân giải được

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | `hosts`: `127.0.0.1 boothme-api.boothstudio2026.workers.dev` |
| **Thao tác** | Mở app, chạy 1 phiên, upload ảnh. |
| **Kỳ vọng** | Như A-02. Ảnh vào thư mục `pending/`. `S3Uploader::pendingCount()` tăng. |
| **Phase** | 4, 6 |

### A-07 · Cloudflare bị gián đoạn

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Firewall chặn dải IP Cloudflare (104.16.0.0/12, 172.64.0.0/13). |
| **Thao tác** | Vận hành liên tục 2 giờ, 20 phiên. |
| **Kỳ vọng** | 20 phiên đủ trong SQLite. 20+ mục trong `sync_queue`. Bỏ chặn → tất cả đồng bộ trong 10 phút, không trùng. |
| **Kiểm** | `SELECT COUNT(*) FROM revenue` trên cloud phải = 20 (không phải 21 hay 40). |
| **Phase** | 6 |

### A-08 · Client đang chụp thì mất mạng

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Đang trong luồng chụp (giữa ảnh 2 và 3 của phiên 4 ảnh). |
| **Thao tác** | Tắt network adapter. |
| **Kỳ vọng** | Chụp tiếp ảnh 3, 4 bình thường. Ghép ảnh, in, lưu bình thường. Không hiện lỗi cho khách. |
| **Không được** | Dừng phiên. Mất ảnh đã chụp. Đứng hình. |
| **Phase** | 4 |

### A-09 · Client đang in thì mất mạng

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Lệnh in đã gửi tới máy in, đang ra giấy. |
| **Thao tác** | Tắt network adapter. |
| **Kỳ vọng** | In xong bình thường. `print_jobs` chuyển DONE. Doanh thu ghi local. |
| **Phase** | 4, 5 |

### A-10 · Client đang upload thì mất mạng

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Đang upload ảnh phiên vừa xong lên S3. |
| **Thao tác** | Tắt network adapter giữa chừng. |
| **Kỳ vọng** | File chưa upload xong được stage vào `pending/`. `m_inFlightKeys` được dọn. Cắm mạng lại → upload tiếp trong ≤ 60 s. Không upload trùng (kiểm S3: 1 object/1 ảnh). |
| **Phase** | Đã có sẵn — kiểm chứng lại |

---

## 2. NHÓM B — CRASH / MẤT ĐIỆN (bài 11–14)

### B-11 · App bị tắt đột ngột

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | `Stop-Process -Name BOOTHME -Force` giữa phiên chụp. |
| **Kỳ vọng** | Mở lại: `recoverInterruptedSessions()` đánh phiên dở thành `APP_INTERRUPTED`. Ảnh đã chụp còn trên đĩa. `sync_queue` mục `PROCESSING` chuyển về `PENDING`. |
| **Kiểm** | `SELECT status FROM sessions ORDER BY id DESC LIMIT 1` = `APP_INTERRUPTED`. `SELECT COUNT(*) FROM sync_queue WHERE status='PROCESSING'` = 0. |
| **Phase** | 6 |

### B-12 · Windows bị mất điện

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Rút nguồn khi app đang chạy idle. Lặp 5 lần. |
| **Kỳ vọng** | Mỗi lần mở lại: DB mở được, `PRAGMA quick_check` trả `ok`, không mất dữ liệu đã commit. |
| **Phase** | 5 |

### B-13 · SQLite đang ghi thì mất điện

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Rút nguồn ngay khi bấm "Thanh toán" (đang INSERT `revenue_records` + `sync_queue`). Lặp 10 lần. |
| **Kỳ vọng** | Với WAL + `synchronous=FULL`: hoặc **cả hai** bản ghi có, hoặc **cả hai** không có. Không bao giờ có doanh thu mà thiếu mục đồng bộ, hoặc ngược lại. DB không hỏng. |
| **Kiểm** | `SELECT r.uuid FROM revenue_records r LEFT JOIN sync_queue q ON q.entity_id=r.uuid WHERE q.event_id IS NULL AND r.uuid<>''` → phải rỗng. |
| **Phase** | 5, 6 |

### B-14 · Mở lại app sau crash

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Sau B-11/B-12/B-13, mở app. |
| **Kỳ vọng** | Mở < 30 s. Không màn hình lỗi. Ghi `error_logs` mức WARN ghi nhận lần khởi động sau crash. Ảnh mồ côi (có file, thiếu metadata) được phát hiện và bổ sung metadata. |
| **Phase** | 5, 6 |

---

## 3. NHÓM C — ĐỒNG BỘ VÀ TRÙNG LẶP (bài 15–18)

### C-15 · Sync lại request cũ

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Offline 3 ngày, chạy 30 phiên. Cắm mạng. |
| **Kỳ vọng** | 30 phiên + 30 doanh thu lên cloud trong ≤ 10 phút. Gửi theo thứ tự ưu tiên: revenue → session → event → voucher. |
| **Kiểm** | Cloud: `COUNT(*) FROM revenue WHERE hwid='TEST...'` = 30. Local `sync_queue`: 0 mục ≠ SYNCED. |
| **Phase** | 6 |

### C-16 · Hai request cùng một `event_id`

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Gửi thủ công 2 lần cùng 1 mục `sync_queue` (giả lập bằng cách reset `status` về PENDING sau khi đã SYNCED). |
| **Kỳ vọng** | Cloud không tạo bản ghi trùng — `revenue_id` PK, `sessions` PK, `INSERT OR IGNORE` cho voucher. |
| **Kiểm** | `SELECT COUNT(*) c, COUNT(DISTINCT revenue_id) d FROM revenue` → `c = d`. |
| **Ngoại lệ** | `package_checkins` — kiểm riêng ở C-16b. |
| **Phase** | 6 |

### C-16b · `package_checkins` gửi lại (rủi ro cao nhất)

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Giả lập: request gửi đi, server nhận và INSERT, nhưng response bị mất (proxy cắt). Client retry. |
| **Kỳ vọng** | Client gọi `check-phone` trước khi retry, thấy `phone_used` với `session_id` khớp → đánh SYNCED, **không gửi lại**. |
| **Kiểm** | Cloud `MSB_DB`: `SELECT machine_hwid, session_id, COUNT(*) FROM package_checkins GROUP BY 1,2 HAVING COUNT(*)>1` → rỗng. |
| **Phase** | 6 |

### C-17 · Dữ liệu local và cloud khác nhau

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Trên portal, đánh dấu 1 lượt chụp là "đã hoàn tiền" (`resolution_type='REFUNDED'`). Local chưa biết. |
| **Kỳ vọng** | Sau ≤ 5 phút (hoặc khi mở màn Lịch sử), local kéo về và hiển thị. **Cloud wins** cho cột `resolution_*`. |
| **Không được** | Local ghi đè ngược lên cloud. Local đổi `status` kỹ thuật của phiên. |
| **Phase** | 6 |

### C-18 · D1 trả dữ liệu cũ

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Gửi session với `status_version = 5`, sau đó gửi lại bản `status_version = 3` (giả lập gói tin đến trễ). |
| **Kỳ vọng** | Cloud giữ nguyên bản v5. Guard `WHERE excluded.status_version >= COALESCE(sessions.status_version, 0)` hoạt động. |
| **Kiểm** | `SELECT status, status_version FROM sessions WHERE session_id='...'` trên cloud = v5. |
| **Phase** | Đã có sẵn — kiểm chứng lại |

---

## 4. NHÓM D — BỎ XÁC THỰC (bài 19–22) ⭐ QUAN TRỌNG NHẤT

### D-19 · App không gọi license API nhưng vẫn mở bình thường

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Chặn hoàn toàn `GET /machine/*` bằng proxy (trả 404). |
| **Thao tác** | Mở app, dùng đầy đủ chức năng. |
| **Kỳ vọng** | Mở bình thường. Chụp/ghép/in/thanh toán bình thường. Không popup. |
| **Phase** | 4 |

### D-20 · D1 có `active = false` nhưng app vẫn mở bình thường

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | ⛔ Cần phê duyệt: đặt `activate=0` cho **HWID test** trên D1 (không phải máy khách). Hoặc dùng proxy trả `{"success":true,"found":true,"machine":{"activate":false,...}}`. |
| **Thao tác** | Mở app, dùng đầy đủ chức năng. |
| **Kỳ vọng** | Mở bình thường. Chụp/in bình thường. Log ghi `Machine auth bypassed; ignoring server activate/license state`. |
| **Lưu ý đã biết** | Upload ảnh sẽ trả 403 `machine_not_active` → ảnh nằm ở `pending/`. **Đây là hành vi hiện tại, được ghi nhận, chưa sửa trong Phase 4–8.** Phải kiểm: retry không gây CPU cao, không đầy đĩa. |
| **Phase** | 4 |

### D-21 · D1 không có HWID của máy nhưng app vẫn mở bình thường

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Proxy trả `{"success":true,"found":false}` cho `GET /machine/*`; chặn `POST /machine/*`. |
| **Thao tác** | Mở app, dùng đầy đủ chức năng. |
| **Kỳ vọng** | Mở bình thường. `studio_id` = 0 → URL gallery không có tiền tố studio nhưng vẫn định vị được theo `hwid`. |
| **Phase** | 4 |

### D-22 · Endpoint activate bị xóa nhưng app vẫn sử dụng được

| Mục | Nội dung |
| --- | --- |
| **Điều kiện** | Proxy trả 404 cho tất cả `/machine/*`, `/plans`, `/portal/*`. |
| **Thao tác** | Vận hành 1 ngày đầy đủ. |
| **Kỳ vọng** | Toàn bộ chức năng cốt lõi hoạt động. Chỉ mất: gallery QR, danh sách mã từ web, thông tin studio. |
| **Phase** | 4 |

---

## 5. NHÓM E — HỎNG DỮ LIỆU / TÀI NGUYÊN (bài 23–27)

### E-23 · File config local bị thiếu

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Xoá `{app}\key.json`, mở app. |
| **Kỳ vọng** | App mở bình thường. Ghi `error_logs` mức ERROR. Tính năng cloud tắt (không upload, không voucher cloud). **Chụp/in/lưu doanh thu vẫn hoạt động.** |
| **Hiện tại** | [main.cpp:187-189](src/main.cpp#L187-L189) chỉ `qCritical()` rồi chạy tiếp — ✅ đúng. Cần kiểm chứng `S3Uploader::loadCredentials()` không crash. |
| **Phase** | 4 |

### E-23b · `key.json` sai định dạng JSON

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Ghi rác vào `key.json`, mở app. |
| **Kỳ vọng** | Như E-23. Không crash. |
| **Phase** | 4 |

### E-24 · SQLite local bị hỏng

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Ghi rác vào giữa `photobooth.db` bằng hex editor. Mở app. |
| **Kỳ vọng** | `PRAGMA quick_check` phát hiện. Đổi tên thành `photobooth.db.corrupt-<ts>`. Khôi phục từ `data\backups\` nếu có, không thì tạo DB mới trống. **App mở được, hiện thông báo tiếng Việt rõ ràng.** |
| **Hiện tại** | `return -1` → app thoát im lặng. ❌ **PHẢI SỬA ở Phase 5.** |
| **Phase** | 5 |

### E-25 · Ổ đĩa hết dung lượng

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Chiếm hết ổ đĩa còn < 100 MB. Chạy 1 phiên chụp. |
| **Kỳ vọng** | Cảnh báo trên màn hình quản trị (không phải màn khách). Từ chối phiên mới với thông báo rõ ràng. **Không crash. Không hỏng DB.** Lỗi `SQLITE_FULL` được bắt và ghi log. |
| **Phase** | 6 |

### E-26 · Ảnh được lưu nhưng metadata chưa ghi

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Kill process ngay sau khi file `.jpg` xuất hiện, trước khi `INSERT INTO photos`. |
| **Kỳ vọng** | Mở lại: quét thư mục `Originals/` của event đang mở, phát hiện file không có trong `photos`, bổ sung metadata, ghi `error_logs` WARN. |
| **Phase** | 6 |

### E-27 · Metadata được ghi nhưng ảnh chưa lưu

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Xoá tay 1 file ảnh trong `Originals/` sau khi đã có bản ghi `photos`. Mở gallery. |
| **Kỳ vọng** | Gallery hiện placeholder hoặc bỏ qua ảnh đó, **không crash**. Ghi `error_logs` WARN. Không xoá bản ghi metadata (có thể ảnh đã lên S3). |
| **Phase** | 6 |

---

## 6. NHÓM F — TRÙNG LẶP VÀ ĐỒNG BỘ DÀI HẠN (bài 28–30)

### F-28 · Upload ảnh trùng

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Kích hoạt `retryPendingSessions()` 5 lần liên tiếp trong khi 1 file đang upload. |
| **Kỳ vọng** | `m_inFlightKeys` chặn enqueue trùng. S3 chỉ có 1 object cho mỗi `s3Key`. |
| **Kiểm** | Đếm object S3 theo prefix = số ảnh local. |
| **Phase** | Đã có sẵn — kiểm chứng lại |

### F-29 · Doanh thu upload trùng

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Gửi cùng 1 bản ghi doanh thu 10 lần liên tiếp (reset `sync_queue.status` về PENDING sau mỗi lần SYNCED). |
| **Kỳ vọng** | Cloud chỉ có **1** dòng. `revenue_id` giống nhau cả 10 lần → `ON CONFLICT DO UPDATE`. |
| **Kiểm** | `SELECT COUNT(*) FROM revenue WHERE session_id='<test>'` = 1. |
| **Phase** | 6 |

### F-30 · Đồng bộ lại sau nhiều ngày offline

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Offline 7 ngày (chỉnh đồng hồ hệ thống hoặc chặn mạng thật). Chạy 200 phiên, 200 doanh thu, 50 voucher. Cắm mạng. |
| **Kỳ vọng** | Toàn bộ ~450 mục đồng bộ trong ≤ 30 phút. Không mất mục nào. Không trùng. UI không đứng. Chụp được bình thường **trong lúc đang đồng bộ**. |
| **Kiểm** | Local `sync_queue`: 0 mục ≠ SYNCED. Cloud: 200 revenue, 200 session. CPU < 10% trong lúc đồng bộ. |
| **Phase** | 6, 7 |

---

## 7. NHÓM G — HIỆU NĂNG VÀ HỒI QUY (bổ sung)

### G-31 · Thời gian khởi động

| Mục | Nội dung |
| --- | --- |
| **Đo** | Từ double-click tới khi giao diện chính nhận thao tác. Đo 10 lần, lấy trung vị. |
| **Baseline** | Đo trên bản hiện tại **trước** khi sửa gì. |
| **Kỳ vọng** | Sau Phase 4/5/6, không tăng quá 10% so với baseline. Offline không chậm hơn online quá 2 s. |

### G-32 · Không ảnh hưởng luồng chụp

| Mục | Nội dung |
| --- | --- |
| **Thao tác** | Chạy 20 phiên liên tiếp trong khi `sync_queue` có 500 mục PENDING và đang gửi. |
| **Kỳ vọng** | Độ trễ shutter không tăng. Live view không giật. Thời gian ghép ảnh không tăng. |

### G-33 · Hồi quy chức năng cốt lõi

Chạy sau **mỗi** phase:

```text
[ ] Mở app
[ ] Chọn/tạo sự kiện
[ ] Chọn layout/frame
[ ] Live view hiển thị
[ ] Chụp 4 ảnh
[ ] Áp dụng filter
[ ] Áp dụng sticker
[ ] Ghép ảnh
[ ] Xem trước
[ ] In (cut và no-cut)
[ ] Thanh toán tiền mặt
[ ] Thanh toán chuyển khoản
[ ] Áp dụng voucher (mã tạo tại máy)
[ ] Tạo mã voucher mới
[ ] Xem lịch sử lượt chụp
[ ] Xem báo cáo doanh thu
[ ] Xuất CSV doanh thu
[ ] Đăng nhập/đăng xuất nhân viên
[ ] Đổi cấu hình trong Cài đặt
[ ] Quầy thu ngân LAN (nếu bật)
[ ] Bill acceptor (nếu có)
[ ] Relay/đèn (nếu có)
[ ] Tạo video/GIF (nếu bật)
[ ] QR gallery (khi có mạng)
```

### G-34 · Kiểm thử rollback

Toàn bộ R-1 → R-9 trong [ROLLBACK_PLAN.md](ROLLBACK_PLAN.md) §7.

---

## 8. Ma trận bài kiểm thử theo Phase

| Phase | Bài bắt buộc trước khi phê duyệt |
| --- | --- |
| **4** | A-01, A-02, A-06, A-08, A-09, D-19, D-20, D-21, D-22, E-23, E-23b, G-31, G-33 |
| **5** | B-12, B-13, E-24, G-31, G-33, R-2, R-3, R-4 |
| **6** | A-03, A-04, A-05, A-07, A-10, B-11, B-13, B-14, C-15, C-16, C-16b, C-17, C-18, E-25, E-26, E-27, F-28, F-29, F-30, G-32, G-33 |
| **7** | **Toàn bộ 30 bài + G-31..G-34** |
| **8** | G-33 trên từng máy sau khi cài (checklist rút gọn) |

---

## 9. Mẫu ghi kết quả

```text
┌──────────────────────────────────────────────────────────────┐
│ Mã bài:            A-01                                      │
│ Ngày giờ:          2026-__-__ __:__                          │
│ Người thực hiện:                                             │
│ Phiên bản app:                                               │
│ schema_version:                                              │
│ Máy test:                                                    │
├──────────────────────────────────────────────────────────────┤
│ Điều kiện đã thiết lập:                                      │
│                                                              │
│ Thao tác đã làm:                                             │
│                                                              │
│ Kết quả quan sát:                                            │
│                                                              │
│ Số liệu trước/sau (phiên, doanh thu, ảnh, sync_queue):       │
│                                                              │
│ ĐẠT / KHÔNG ĐẠT:                                             │
│ Nếu KHÔNG ĐẠT — mô tả sai khác:                              │
│ File log đính kèm:                                           │
└──────────────────────────────────────────────────────────────┘
```

---

## 10. Tiêu chí chấp nhận tổng thể (trước Phase 8)

```text
[ ] 30/30 bài NHÓM A–F: ĐẠT
[ ] G-31: thời gian khởi động không tăng > 10%
[ ] G-32: không ảnh hưởng luồng chụp
[ ] G-33: 24/24 mục hồi quy ĐẠT
[ ] G-34: 9/9 bài rollback ĐẠT
[ ] Không có dòng CRITICAL nào trong log ngoài các trường hợp cố ý giả lập
[ ] Chênh lệch dữ liệu local vs cloud sau 7 ngày vận hành: 0%
[ ] Không có bản ghi trùng trên D1
[ ] Đã export D1 làm backup trước khi triển khai
[ ] Đã có file setup bản cũ lưu trữ để rollback
[ ] installer.iss đã sửa BuildDir và xử lý key.json
[ ] Người phê duyệt đã ký nhận
```
