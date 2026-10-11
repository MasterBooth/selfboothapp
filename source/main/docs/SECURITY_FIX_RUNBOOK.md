# Runbook — Vá phân quyền portal & cắt chi phí hạ tầng

Ngày: 2026-08-06. Áp dụng cho stack **LaMoment** (`lamoment-api` + `web-lamoment`).

Mã đã sửa xong và qua kiểm thử. Tài liệu này là phần **phải làm bằng tay**:
xoay bí mật, thứ tự deploy, và cách xác minh.

> ⚠️ Đọc hết mục 1 và mục 2 trước khi gõ lệnh đầu tiên. Deploy sai thứ tự sẽ
> khoá portal ra ngoài khoảng vài phút.

---

## 0. Tóm tắt những gì đã đổi trong mã

| File | Thay đổi |
|---|---|
| `cloudflare/worker/src/portalAuth.ts` | **Mới.** Verify Google id_token bằng JWKS, phát/kiểm session JWT, cổng phân quyền |
| `cloudflare/worker/src/index.ts` | Cổng bearer nhận 2 loại người gọi; `/portal/google` thành route công khai; `/machines` cần token quản trị; QR approve lấy danh tính từ phiên; media proxy có cache |
| `cloudflare/worker/wrangler.lamoment.toml` | Thêm `PORTAL_STRICT_AUTH = "1"` |
| `cloudflare/worker/test/portal-auth.test.mjs` | **Mới.** 38 test cho logic phân quyền |
| `web-lamoment/portal/config.js` | **Gỡ `apiToken`** |
| `web-lamoment/portal/portal.js` | Dùng `session_token`; xử lý 401; bỏ autoplay video |
| `web-lamoment/wrangler.toml`, `_headers`, `_redirects`, `.assetsignore` | **Mới.** Hạ tầng thay Vercel |
| `main/vercel token.txt` | **Đã xoá** |

Chạy lại kiểm thử bất cứ lúc nào:

```bash
cd cloudflare/worker
npm run typecheck
npm test
```

---

## 1. Xoay bí mật — LÀM TRƯỚC TIÊN

Ba giá trị dưới đây đã nằm trong thư mục mã nguồn ở dạng chữ thường và phải
coi như đã lộ.

### 1.1 Token tài khoản Vercel — thu hồi ngay

File `main/vercel token.txt` chứa token bắt đầu bằng `vcp_3C9zsfpu…`. Token
này cho **toàn quyền** trên tài khoản: deploy, xoá project, đọc mọi biến môi
trường. File đã bị xoá nhưng **xoá file không thu hồi token**.

→ https://vercel.com/account/tokens → xoá token đó.

### 1.2 API_TOKEN của Worker

Giá trị `VkPvQDfc…` đã được phát công khai qua `portal/config.js` suốt thời
gian vừa qua. Sinh giá trị mới:

```bash
# Sinh 32 byte ngẫu nhiên
node -e "console.log(require('crypto').randomBytes(32).toString('base64url'))"

cd cloudflare/worker
npx wrangler secret put API_TOKEN --config wrangler.lamoment.toml
```

⚠️ **Đổi API_TOKEN sẽ làm mọi máy chụp ngoài hiện trường mất kết nối** cho tới
khi `key.json` trên từng máy được cập nhật (`cloud_api.api_token`). Cân nhắc
làm bước này cùng đợt cập nhật app, hoặc chấp nhận đi cập nhật từng máy.

Nếu chưa làm ngay được: các bước còn lại **vẫn có tác dụng**. Token cũ dù lộ
cũng không còn đọc được `/portal/*` sau khi bật `PORTAL_STRICT_AUTH`, cũng
không đọc được `/machines`. Đây là lý do thiết kế theo hướng đó.

### 1.3 Hai secret mới

```bash
cd cloudflare/worker

# Token quản trị: dùng cho /machines (danh sách toàn bộ máy) và /activation/*
npx wrangler secret put ADMIN_API_TOKEN  --config wrangler.lamoment.toml

# Khoá ký phiên đăng nhập portal
npx wrangler secret put PORTAL_JWT_SECRET --config wrangler.lamoment.toml
```

`PORTAL_JWT_SECRET` không bắt buộc — nếu thiếu, Worker dẫn xuất tạm từ
`API_TOKEN`. Nhưng nên đặt: hai khoá đó phải độc lập để xoay cái này không
làm lộ cái kia. **Đổi `PORTAL_JWT_SECRET` sẽ đăng xuất mọi người khỏi portal**
(đúng như mong đợi — đó là nút "đá tất cả ra ngoài").

---

## 2. Deploy — đúng thứ tự này

`PORTAL_STRICT_AUTH` hiện đang là `"1"` trong `wrangler.lamoment.toml`. Nếu
deploy Worker trước khi web mới lên, portal cũ (còn dùng `apiToken`) sẽ bị
chặn ngay lập tức.

```bash
# ── B1. Deploy Worker, tạm TẮT chế độ nghiêm ngặt ────────────────────────
cd cloudflare/worker
# Sửa wrangler.lamoment.toml:  PORTAL_STRICT_AUTH = ""
npx wrangler deploy --config wrangler.lamoment.toml

# ── B2. Deploy web mới (portal đã dùng session_token) ────────────────────
cd ../../web-lamoment
npx vercel --prod          # hoặc npx wrangler deploy, xem mục 3

# ── B3. Đăng nhập thử portal. Phải vào được, thấy đúng dữ liệu studio.

# ── B4. Bật chế độ nghiêm ngặt ───────────────────────────────────────────
cd ../cloudflare/worker
# Sửa lại:  PORTAL_STRICT_AUTH = "1"
npx wrangler deploy --config wrangler.lamoment.toml
```

**Không đụng tới `boothme-api`** (`wrangler.toml`) — nó dùng chung
`src/index.ts` nhưng không có `PORTAL_STRICT_AUTH`, nên CMS `cms-vietbooth`
chạy y như cũ.

### Xác minh sau khi deploy

```bash
API=https://lamoment-api.boothstudio2026.workers.dev
# Token cũ — lấy từ key.json, đừng chép vào file nào khác
OLD=$(node -p "require('./key.json').cloud_api.api_token")

# 1. Token cũ không còn liệt kê được máy của mọi studio  → mong đợi 403
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $OLD" "$API/machines"

# 2. Token cũ không còn đọc được doanh thu studio khác   → mong đợi 401
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $OLD" "$API/portal/bat-ky@email.com/revenue"

# 3. config.js không còn bí mật nào                       → không có "apiToken"
curl -s https://lamoment.vercel.app/portal/config.js | grep -c apiToken   # → 0

# 4. Ảnh vẫn xem được (route công khai, không đổi)        → mong đợi 200
curl -s -o /dev/null -w "%{http_code}\n" "$API/media/<hwid>/<event>/<session>/collage.jpg"
```

### Kiểm thử phân quyền bằng tay

1. Thêm một nhân viên thật, chỉ tick **"Xem và lọc doanh thu"**.
2. Đăng nhập bằng tài khoản đó → chỉ thấy mục Doanh thu.
3. Mở F12 → Console, thử leo thang như bản cũ:
   ```js
   s = JSON.parse(localStorage.booth_portal_session); s.role = "owner";
   localStorage.booth_portal_session = JSON.stringify(s); location.reload();
   ```
   Giao diện sẽ hiện đủ mục (vì `role` chỉ điều khiển giao diện), nhưng **mọi
   lời gọi API đều trả 403** — vai trò thật nằm trong chữ ký của
   `session_token`, sửa localStorage không đụng tới được.
4. Bỏ tick quyền của nhân viên đó ở tab khác → họ bị chặn ở **request kế
   tiếp**, không phải chờ hết phiên.

---

## 3. Rời Vercel sang Cloudflare

Lý do: trang chỉ có ~20 file tĩnh và cố ý không để byte ảnh nào đi qua nó,
nên nó chưa dùng hết thứ gì của Vercel. Nhưng tài khoản đang ở gói **Hobby**,
mà Hobby **cấm dùng cho mục đích thương mại** — đường hợp lệ duy nhất là Pro
$20/ghế/tháng. Trên Cloudflare, request tới file tĩnh miễn phí và không giới
hạn.

```bash
cd web-lamoment
npx wrangler deploy
```

`wrangler.toml`, `_headers`, `_redirects`, `.assetsignore` đã viết sẵn —
tương đương từng mục của `vercel.json`.

Sau khi đổi tên miền, **phải cập nhật ba nơi**, thiếu chỗ nào portal cũng hỏng:

1. `PORTAL_BASE_URL` trong `wrangler.lamoment.toml` — Worker nhúng giá trị này
   vào mã QR mở khoá máy.
2. **Authorized JavaScript origins** của Google OAuth client trong Google
   Cloud Console. Thiếu bước này → mọi lượt đăng nhập báo lỗi origin.
3. Đường dẫn gallery máy chụp sinh ra: `S3Uploader::buildSessionUrl`.

Giữ project Vercel chạy song song vài ngày rồi mới xoá — mã QR đã in ra trên
giấy vẫn đang trỏ về tên miền cũ.

---

## 4. Chi phí ảnh — việc còn lại

### 4.1 Gắn custom domain cho Worker ← **quan trọng**

`handleMediaGet` giờ đã cache đúng cách, nhưng **Cache API là no-op trên
`*.workers.dev`** (Cloudflare không cho dùng chung cache ở cấp zone). Nhánh
cache chỉ thực sự chạy khi Worker có tên miền riêng.

→ Cloudflare Dashboard → Worker `lamoment-api` → Settings → Domains & Routes →
Add Custom Domain (ví dụ `api.lamoment.vn`). Rồi cập nhật `apiBaseUrl` trong
`portal/config.js` và `publicBaseUrl` trong `gallery/config.js`.

Trước khi có domain, phần đã thu được vẫn đáng kể: header đổi từ
`max-age=300` sang `max-age=31536000, immutable`, nên khách xem lại album
không kéo byte từ S3 nữa; và video ở portal thôi tải trọn mỗi lần mở session.

Kiểm tra cache đã chạy chưa:

```bash
curl -sI "https://api.lamoment.vn/media/<key>" | grep -i x-lm-cache
# lần 1 → MISS, lần 2 → HIT
```

### 4.2 Sinh thumbnail lúc upload — chưa làm

`portal.js` và `gallery.js` đang dùng **ảnh gốc làm thumbnail**. Mở một
session trong portal kéo về ~10MB chỉ để hiển thị một lưới ảnh nhỏ.

Việc cần làm nằm ở phía C++ (`S3Uploader` / `EventManager`): lúc upload, sinh
thêm `photos/thumb_<tên>.jpg` cạnh ảnh gốc (~150KB), rồi cho lưới ảnh dùng
`thumb_`, chỉ lightbox mới tải bản đầy đủ. Ước tính giảm ~90% băng thông lưới.

Chưa làm vì nằm ngoài phạm vi web/worker, và cần quyết định kích thước cạnh
dài + mức nén.

### 4.3 Cân nhắc chuyển S3 → Cloudflare R2

Egress S3 ở `ap-southeast-1` là **$0,12/GB**; R2 là **$0**, lưu trữ cũng rẻ
hơn ($0,015 vs $0,023/GB). R2 tương thích API S3 nên `presignS3PutUrl` /
`presignS3GetUrl` chỉ cần đổi endpoint, và có thể chuyển dần (ghi mới vào R2,
đọc thiếu thì fallback S3).

Sau khi có 4.1 + 4.2 thì mức tiết kiệm của bước này nhỏ hơn nhiều — làm sau,
đừng làm trước.

---

## 5. Việc còn nợ (đã ghi trong `cloudflare/worker/README.md`)

- **`key.json` mang `api_token` chung tới mọi máy khách.** Installer đóng gói
  file này, nên mỗi studio đều cầm bearer token master trên ổ đĩa. Hướng vá:
  token riêng cho từng máy, phát lúc kích hoạt, gắn với HWID.
  *(Ghi chú: `client_secret` trong cùng file thuộc OAuth client loại Desktop
  app — theo RFC 8252 loại secret này không được coi là bí mật và Google bắt
  buộc phải có nó cho luồng loopback. Đây **không** phải lỗ hổng, đừng xoá.)*
- **`/media/*` công khai hoàn toàn** — ai biết `hwid/event_id/session_id` đều
  đọc được ảnh khách. Hướng vá: mã QR mang thêm token HMAC có hạn.
- **`LICENSE_PUBLIC_KEYS` vẫn là khoá dev** (`dev-2026-01`).
- **`GoogleAuthManager` chưa dùng PKCE** cho luồng loopback trên máy chụp.

---

## 6. Quay lui

Không có migration cơ sở dữ liệu nào, nên quay lui chỉ là deploy lại bản
trước:

```bash
npx wrangler rollback --config wrangler.lamoment.toml
```

Nếu chỉ muốn tạm mở cổng mà không quay lui mã: đặt `PORTAL_STRICT_AUTH = ""`
rồi deploy. Portal cũ sẽ chạy lại được — kèm theo mọi lỗ hổng của nó.
