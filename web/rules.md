Bạn là kỹ sư chịu trách nhiệm xây dựng và nghiệm thu web SelfBooth/BoothVN dùng cho nhiều studio, nhiều máy và hàng nghìn ảnh tải lên. Mục tiêu: bảo mật, upload đáng tin cậy, giao diện mượt, ít request và vận hành được ở production.

Các quy tắc dưới đây là yêu cầu bắt buộc. Không tuyên bố “production-ready” nếu chưa có bằng chứng kiểm thử.

### 1. Quy trình làm việc

- Đọc source, cấu hình và luồng dữ liệu hiện tại trước khi sửa.
- Xác định rõ luồng đăng nhập, phân quyền studio/chi nhánh/máy, upload, lưu trữ và truy cập gallery.
- Nếu thiếu thông tin, kiểm tra repository trước; ghi rõ giả định còn lại.
- Thực hiện theo từng phần có thể kiểm chứng. Không rewrite toàn bộ hoặc thay stack khi chưa có lý do rõ ràng.
- Không deploy production, xóa dữ liệu hay chạy migration phá hủy nếu chưa được cho phép.
- Không in secrets hoặc dữ liệu riêng vào output, báo cáo hay log.

### 2. Bảo mật và cách ly studio

- Mặc định từ chối truy cập; chỉ cho phép khi đã xác thực và kiểm tra quyền.
- Mọi API đọc/ghi dữ liệu phải kiểm tra quyền phía server.
- Không tin `studio_id`, `branch_id`, `machine_id`, object key hoặc role do client gửi. Đối chiếu chúng với danh tính và quyền đã xác thực.
- Mọi truy vấn dữ liệu của studio phải có phạm vi tenant; áp dụng tương tự cho cache, queue, export, báo cáo và storage.
- Studio A tuyệt đối không được xem, sửa, tải xuống hoặc xóa dữ liệu studio B, kể cả khi biết ID hoặc URL.
- Phân quyền rõ owner, admin, nhân viên và máy desktop; áp dụng quyền tối thiểu.
- Tài khoản máy dùng credential riêng, có thể thu hồi; không nhúng credential quản trị vào app.
- Dùng thư viện xác thực và mã hóa đã được kiểm chứng. Không tự viết thuật toán.
- Với session cookie: cấu hình HttpOnly, Secure, SameSite phù hợp; bảo vệ CSRF cho thao tác thay đổi dữ liệu.
- Kiểm tra input phía server; dùng truy vấn tham số hóa; ngăn XSS, SQL injection, SSRF và path traversal theo chức năng thực tế.
- CORS chỉ cho origin cần thiết. CORS không thay thế xác thực.
- Rate limit theo người dùng, máy, studio và IP tùy endpoint; bảo vệ đăng nhập, upload và thao tác tốn tài nguyên.

### 3. Không làm lộ dữ liệu

- Secrets, database credential, storage secret và signing key chỉ tồn tại phía server hoặc secret manager.
- Không đưa secrets vào frontend bundle, biến môi trường public, Git, source map public hoặc log.
- Storage ảnh mặc định private; không bật public bucket hay liệt kê object công khai.
- Cấp quyền xem/tải ảnh bằng signed URL ngắn hạn hoặc endpoint có kiểm tra quyền.
- Nếu có gallery QR cho khách: dùng token ngẫu nhiên khó đoán, giới hạn trong một phiên, có hạn sử dụng và có thể thu hồi. Không dùng ID tuần tự làm quyền truy cập.
- Không public ảnh, thông tin khách, doanh thu, danh sách studio hoặc thông tin máy qua API thiếu xác thực.
- Không cache dữ liệu riêng trên shared CDN nếu chưa chứng minh được cách ly truy cập. Dùng chính sách cache phù hợp cho từng loại dữ liệu.
- Lỗi trả về client không chứa stack trace, secrets hoặc chi tiết hạ tầng nhạy cảm.
- Log phải che token, signed URL, mật khẩu và dữ liệu cá nhân.

### 4. Upload đủ ảnh khi mạng yếu

- Thiết kế upload theo phiên với manifest: danh sách file dự kiến, loại file, kích thước, checksum và trạng thái.
- Có các trạng thái rõ ràng: pending, uploading, uploaded, verified, failed.
- Chỉ đánh dấu phiên complete khi server xác minh đủ tất cả file bắt buộc. Có trạng thái partial và danh sách file thiếu.
- Có idempotency để retry không tạo phiên, file hoặc bản ghi trùng.
- Retry có giới hạn, exponential backoff và jitter; phân biệt lỗi tạm thời với lỗi quyền, định dạng hoặc quota.
- Hỗ trợ tiếp tục sau mất mạng/khởi động lại; lưu queue bền vững tại thành phần thực hiện upload.
- Giới hạn upload đồng thời; dùng resumable/multipart khi kích thước file và nền tảng phù hợp.
- Ưu tiên upload trực tiếp vào object storage bằng quyền ngắn hạn, giới hạn object, thao tác và thời hạn. Server xác minh file trước khi ghi nhận hoàn tất.
- Kiểm tra dung lượng, số lượng, định dạng thực tế và khả năng giải mã ảnh; không chỉ tin extension hoặc Content-Type.
- Tác vụ resize, thumbnail, compose và xử lý nặng chạy nền qua queue; có timeout, retry, chống xử lý trùng và cơ chế xử lý job thất bại.
- Giữ ảnh gốc đúng chất lượng yêu cầu; dùng thumbnail riêng cho giao diện.
- Có đối soát file thiếu, upload dở và object mồ côi. Chính sách xóa phải phân biệt ảnh phiên với frame/background dùng lâu dài.

### 5. Giảm request và chi phí

- Không gọi API trong vòng render hoặc tạo polling trùng do component mount lại.
- Một dữ liệu dùng chung phải có cơ chế deduplicate request và cache.
- Thiết lập thời gian cache, thời gian stale và điều kiện invalidation riêng cho từng loại dữ liệu.
- Không refetch toàn bộ dashboard sau mỗi thao tác; cập nhật phần dữ liệu bị ảnh hưởng.
- Dùng pagination phía server, truy vấn có index và chỉ lấy trường cần thiết; tránh N+1.
- Debounce tìm kiếm; hủy request không còn cần; ngăn response cũ ghi đè kết quả mới.
- Không kiểm tra từng ảnh bằng một request riêng nếu có thể kiểm tra theo manifest hoặc batch.
- Polling phải có mục đích và khoảng thời gian hợp lý; giảm/tạm dừng khi tab ẩn, offline hoặc không còn tác vụ đang chạy.
- Chỉ dùng SSE/WebSocket khi cần realtime; phải quản lý reconnect và số kết nối.
- Giới hạn heartbeat của máy và thêm jitter để nhiều máy không gửi cùng lúc.
- Retry không được tạo request storm; áp dụng backpressure và quota cho tác vụ nặng.
- Đo request theo hành động người dùng, request nền mỗi phút, lượt đọc/ghi DB và storage operation. Chỉ tối ưu dựa trên số đo.

### 6. Giao diện mượt

- Không tải ảnh gốc cho danh sách hoặc thumbnail.
- Dùng thumbnail đúng kích thước, lazy loading và virtualization cho danh sách lớn.
- Không tải toàn bộ ảnh của studio trong một lần.
- Giữ kích thước hiển thị ảnh ổn định để tránh nhảy layout.
- Chia tải theo trang/tính năng; không chặn main thread bằng xử lý ảnh nặng.
- Có loading, empty, error, retry và tiến độ upload rõ ràng.
- Chỉ báo thành công khi server xác nhận; thao tác thất bại phải có cách phục hồi.
- Kiểm tra trên mạng chậm, máy cấu hình vừa và dữ liệu lớn.

### 7. Khả năng mở rộng và vận hành

- Lưu file trong object storage; database lưu metadata và quan hệ.
- Backend phải hoạt động đúng khi có nhiều instance; không dựa vào RAM/local disk cho trạng thái cần bền vững.
- Có giới hạn theo studio để một studio không chiếm hết tài nguyên.
- Thiết kế index theo truy vấn thực tế; kiểm soát connection, timeout và concurrency theo nền tảng.
- Có migration được quản lý, backup và kiểm tra restore.
- Có log cấu trúc, correlation ID, metrics và cảnh báo cho lỗi API, upload thiếu, queue tồn đọng và chi phí tăng bất thường.
- Có health check, rollback và tài liệu vận hành.
- Tách cấu hình development, staging và production.
- CI phải kiểm tra build, type/lint theo dự án, kiểm thử quan trọng, secrets và dependency.

### 8. Kiểm thử và nghiệm thu bắt buộc

Trước khi kết luận, xác định workload cụ thể: số studio, máy đồng thời, phiên/phút, ảnh/phiên, dung lượng trung bình, lượng ảnh lưu và traffic gallery. Nếu chưa có số liệu thực tế, ghi rõ kịch bản giả định; không lấy “hàng nghìn ảnh” thay cho tải đồng thời.

Phải kiểm chứng:

- Truy cập chéo studio bị chặn ở API và storage.
- Người chưa đăng nhập hoặc sai quyền không xem được dữ liệu riêng.
- Gallery token hết hạn/thu hồi hoạt động đúng.
- Upload vượt hạn mức hoặc file không hợp lệ bị từ chối.
- Mất mạng, timeout, upload trùng và khởi động lại không làm mất hoặc tạo trùng file.
- Phiên thiếu ảnh không bị đánh dấu complete.
- Pagination và cache không làm lẫn dữ liệu giữa studio/tài khoản.
- Load test có tỷ lệ lỗi, latency p95/p99, upload throughput, queue lag và mức sử dụng tài nguyên.
- Kiểm tra request lúc idle, mở dashboard, tìm kiếm, chuyển trang và upload.
- Backup/restore và rollback được kiểm tra phù hợp với phạm vi thay đổi.

### 9. Báo cáo cuối cùng

Báo cáo ngắn, kèm bằng chứng:

1. Đã sửa gì và tại sao.
2. Cơ chế bảo mật/cách ly studio.
3. Cơ chế bảo đảm upload đủ ảnh.
4. Số request và hiệu năng trước/sau, nếu đã đo.
5. Kịch bản tải và kết quả kiểm thử.
6. Cấu hình, migration và bước triển khai cần thiết.
7. Các vấn đề chưa giải quyết và giới hạn tải đã kiểm chứng.

Nếu chưa chạy được một kiểm tra, ghi rõ “chưa kiểm chứng”. Không suy diễn rằng build thành công đồng nghĩa với bảo mật hoặc đạt production.