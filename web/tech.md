# TECHNICAL RULES — SELFBOOTH / BOOTHVN

## 1. Stack và phạm vi

- Hệ thống mới sử dụng Next.js App Router + TypeScript strict.
- UI sử dụng Tailwind CSS + shadcn/ui.
- Dữ liệu tương tác phía client sử dụng TanStack Query.
- Database sử dụng PostgreSQL; chọn một ORM tương thích và dùng thống nhất.
- Ảnh/file lưu trong Cloudflare R2 private; database chỉ lưu metadata.
- Tác vụ xử lý nền sử dụng queue và worker.
- Nếu repository hiện tại dùng stack khác, báo cáo mức tương thích và kế hoạch thay đổi trước. Không tự migrate hoặc rewrite.
- Chọn phiên bản stable còn được hỗ trợ, kiểm tra tương thích runtime và khóa dependency bằng lockfile.
- Không thêm Redis, microservices hoặc thư viện mới khi chưa có nhu cầu cụ thể.

## 2. Kiến trúc

- Bắt đầu bằng modular monolith: một backend chia module theo nghiệp vụ.
- Web và app desktop dùng chung lớp nghiệp vụ/API; không triển khai hai bộ quy tắc khác nhau.
- API cho app desktop phải có version, ví dụ `/api/v1`.
- Server Actions chỉ dùng cho thao tác của web phù hợp; không dùng làm API tích hợp cho desktop.
- Tách worker xử lý ảnh khỏi request web. Queue chỉ truyền ID/object key và metadata cần thiết, không truyền toàn bộ file ảnh.

Cấu trúc tham khảo:

```text
src/
  app/                  # Route, layout, page và API handler
  modules/
    auth/
    studios/
    branches/
    staff/
    machines/
    sessions/
    uploads/
    gallery/
    frames/
    billing/
    reports/
  components/ui/        # Thành phần UI dùng chung
  server/
    db/
    storage/
    queue/
    auth/
  lib/                  # Tiện ích dùng chung có phạm vi rõ ràng
workers/                # Consumer và xử lý nền
```

- Mỗi module giữ schema validation, service, repository và UI liên quan khi cần.
- Route/API handler chỉ xác thực, validate, gọi service và định dạng response.
- Không đặt nghiệp vụ hoặc truy vấn database trực tiếp trong component.
- Không tạo nhiều lớp chỉ để chuyển tiếp lời gọi; tổ chức theo độ phức tạp thực tế.

## 3. Quy tắc Next.js

- Mặc định dùng Server Components; chỉ thêm `"use client"` khi cần tương tác hoặc API trình duyệt.
- Module database, storage credentials và signing phải được đánh dấu server-only.
- Không đưa secrets vào biến `NEXT_PUBLIC_*`.
- Không dùng middleware làm lớp kiểm tra quyền duy nhất. Kiểm tra quyền trong service/API xử lý dữ liệu.
- Khai báo rõ chính sách cache cho dữ liệu nhạy cảm; không phụ thuộc vào mặc định của framework.
- Dữ liệu riêng không được đưa vào static generation hoặc shared cache thiếu phạm vi tenant.
- Không fetch HTTP về API của chính ứng dụng từ Server Component khi có thể gọi trực tiếp service phía server.
- Kiểm tra thư viện với runtime triển khai; không giả định package Node.js chạy được trên mọi nền tảng.

## 4. TypeScript và API contract

- Bật strict mode. Không dùng `any`, `@ts-ignore` hoặc type assertion để bỏ qua lỗi chưa hiểu rõ.
- Validate dữ liệu tại mọi ranh giới: request, environment, webhook, queue message và response từ dịch vụ ngoài.
- Dùng một thư viện schema validation thống nhất.
- API có error code ổn định, request ID và HTTP status phù hợp.
- Không trả nguyên database model ra client; dùng DTO chỉ chứa trường cần thiết.
- Quy định timestamp UTC; chuyển timezone tại lớp hiển thị/báo cáo.
- Tiền lưu bằng số nguyên theo đơn vị nhỏ nhất hoặc decimal phù hợp; không dùng floating point.
- Các thao tác có thể retry phải có idempotency và ràng buộc uniqueness phía database.

## 5. Database nhiều studio

- Dữ liệu thuộc studio phải có tenant key và quan hệ sở hữu rõ ràng.
- Repository của dữ liệu studio phải nhận tenant context đã xác thực; không cung cấp truy vấn không scope cho luồng thông thường.
- Unique constraint, foreign key và index phải tính đến phạm vi tenant.
- Dùng transaction cho thay đổi cần tính nhất quán; không giữ transaction mở trong lúc upload hoặc gọi dịch vụ ngoài.
- Dùng pagination có giới hạn; ưu tiên cursor cho danh sách lớn thường xuyên thay đổi.
- Không dùng `SELECT *`, truy vấn không giới hạn hoặc N+1 trong đường chạy chính.
- Dùng connection pooling phù hợp với môi trường triển khai.
- Migration phải được commit và có kế hoạch triển khai/khôi phục. Không chạy schema reset trên production.
- Nếu dùng PostgreSQL RLS, cấu hình và kiểm thử tenant context với connection pool; RLS bổ sung cho phân quyền ứng dụng.

## 6. Storage và upload

- Object key được server cấp, có namespace rõ studio/phiên/loại file.
- Tách namespace ảnh phiên khỏi frame, background và tài nguyên dài hạn để áp dụng lifecycle đúng.
- Không dùng object key hoặc HWID như bằng chứng quyền truy cập.
- Upload trực tiếp vào R2 qua quyền ngắn hạn; không đưa R2 secret cho client.
- Không chuyển toàn bộ ảnh qua Next.js server nếu không có lý do cần thiết.
- Manifest upload ghi nhận file dự kiến, kích thước, checksum phù hợp, trạng thái và object key.
- Không coi storage ETag luôn là checksum nội dung.
- Sau upload, server xác minh object trước khi xác nhận hoàn tất.
- Queue upload có retry/backoff, concurrency giới hạn, resume và chống trùng.
- Giữ ảnh gốc theo chính sách chất lượng; tạo thumbnail riêng. Không âm thầm nén ảnh gốc hoặc frame.
- Tác vụ ảnh phải giới hạn cả kích thước file, số pixel, bộ nhớ và thời gian xử lý.

## 7. Cache và request

- Mỗi tài nguyên có một chiến lược lấy dữ liệu rõ ràng; tránh Server Component và client cùng fetch trùng khi khởi tạo.
- Query key phải chứa tenant và các tham số ảnh hưởng đến kết quả.
- Xóa cache dữ liệu riêng khi logout hoặc đổi tài khoản; cách ly cache khi chuyển studio.
- Thiết lập stale time và refetch theo nghiệp vụ; không áp dụng một cấu hình cho tất cả API.
- Mutation chỉ invalidate dữ liệu bị ảnh hưởng.
- Không polling toàn bộ dashboard. Polling chỉ hoạt động khi có trạng thái cần theo dõi và dừng khi tác vụ hoàn tất.
- Dùng batch endpoint cho kiểm tra nhiều file/trạng thái khi phù hợp.
- Cache phía server phải có tenant scope, TTL và invalidation rõ ràng.
- Không dùng cache làm nguồn dữ liệu duy nhất cho doanh thu, quyền truy cập hoặc trạng thái upload.

## 8. Queue và tính nhất quán

- Giả định job có thể được giao nhiều lần; consumer phải idempotent.
- Chỉ acknowledge sau khi xử lý thành công.
- Có giới hạn retry, dead-letter queue và cách replay có kiểm soát.
- Trạng thái job bền vững phải lưu ngoài RAM.
- Với thao tác vừa ghi database vừa phát job, dùng transactional outbox hoặc cơ chế tương đương để tránh mất job.
- Giới hạn tài nguyên và mức đồng thời theo studio.
- Công cụ xử lý ảnh phải chạy trên worker/runtime phù hợp; kiểm tra thực tế trước khi chọn.

## 9. UI và hiệu năng

- Gallery dùng thumbnail, lazy loading và pagination; virtualization khi danh sách đủ lớn.
- Không tải trước toàn bộ ảnh gốc hoặc toàn bộ phiên của studio.
- Ảnh phải có kích thước hiển thị ổn định.
- Hủy request không còn cần và xử lý response đến sai thứ tự.
- Component có loading, empty, error và retry phù hợp.
- Không chạy xử lý ảnh nặng trên main thread.
- Thiết lập performance budget cho trang chính dựa trên thiết bị, mạng và dữ liệu mục tiêu; báo cáo kết quả đo.

## 10. Kiểm thử và bàn giao

- Kiểm thử ưu tiên: cách ly tenant, phân quyền, session, upload partial/retry, idempotency, cache sau đổi studio và migration.
- Có integration test cho luồng database/storage/queue quan trọng.
- Có E2E cho đăng nhập, tạo phiên, upload và mở gallery.
- Load test phải ghi rõ workload, giới hạn hạ tầng và kết quả; không suy ra sức tải từ số lượng file lưu.
- CI chạy build, typecheck, lint và các test liên quan.
- Mọi thay đổi phải ghi rõ cấu hình/env/migration cần thêm.
- Không để TODO trong đường chạy quan trọng mà vẫn tuyên bố hoàn tất.
- Không tuyên bố đạt production khi chưa kiểm chứng bảo mật, upload reliability, tải đồng thời và khả năng phục hồi.