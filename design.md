# Design - Vibe Studio Selfbooth

Locked design system. Future Hallmark runs read this file first; pages defer
to it. Amend intentionally - the file is the rule.

## System
- Genre · editorial
- Macrostructure · Workbench
- Theme · Studio soft editorial
- Axes · light paper / serif display / warm cocoa accent
- Nav · N5 Floating pill
- Footer · Ft5 Statement

## Tokens (canonical · `tokens.css` is the source of truth)
```css
:root {
  --color-paper: oklch(96.5% 0.018 76);
  --color-paper-2: oklch(93.5% 0.022 76);
  --color-paper-3: oklch(89% 0.026 76);
  --color-surface: oklch(98% 0.012 76);
  --color-rule: oklch(78% 0.026 74);
  --color-rule-strong: oklch(65% 0.035 70);
  --color-neutral: oklch(45% 0.035 62);
  --color-muted: oklch(35% 0.035 58);
  --color-ink: oklch(20% 0.035 54);
  --color-accent: oklch(39% 0.09 48);
  --color-accent-ink: oklch(98% 0.012 76);
  --color-focus: oklch(50% 0.16 55);
  --color-price: oklch(48% 0.1 78);
  --color-success: oklch(43% 0.08 135);
  --color-error: oklch(48% 0.16 28);

  --font-display: "Fraunces", ui-serif, Georgia, serif;
  --font-body: "IBM Plex Sans", ui-sans-serif, system-ui, sans-serif;

  /* 4-pt spacing scale: --space-3xs through --space-3xl. See tokens.css. */
  /* Type scale: --text-xs through --text-display. See tokens.css. */

  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-in: cubic-bezier(0.7, 0, 0.84, 0);
  --ease-in-out: cubic-bezier(0.65, 0, 0.35, 1);
  --dur-micro: 120ms;
  --dur-short: 220ms;
  --dur-long: 420ms;

  --radius-sm: 0.75rem;
  --radius-md: 1rem;
  --radius-lg: 1.5rem;
  --radius-xl: 2rem;
  --radius-pill: 999rem;
}
```

## Variants
- App admin Qt (`source/main/admin/qml`) · Workbench dạng sidebar cocoa tối + danh sách + bảng chi tiết.
  Token đổi sang hex trong `Tk.qml` (QML không đọc OKLCH); font nhúng qua qrc.
- App chụp Qt (`source/main/qml`) · màn "Máy ảnh" (`CameraStudioSettings.qml`): combo "Nguồn máy ảnh" có mục
  Hot Folder → hiện ngay bên dưới control phân đoạn `StudioSegmented` (Thư mục ảnh | Fujifilm), ô đường dẫn
  Consolas (như ô LAN) + 1 nút phụ, rồi một dòng gợi ý có chấm trạng thái. Trạng thái nằm ở pill của thẻ "Kết nối".
  Token dùng `Theme.settings*`; khi Hot Folder thì ẩn thẻ phơi sáng và khoá live view ở HDMI/Webcam.
- Màn mở app (`StartupSplash.qml`) · khung dọc 1080×1920 căn giữa như app chính, nền kem (`settingsSurface`,
  hai bên `settingsCanvas`); logo giữa khung, dưới là chữ trạng thái có dấu + % (đồng đậm) và đường kẻ mảnh
  6px chạy màu đồng. Không thêm khẩu hiệu/số liệu.
- Mono · "IBM Plex Mono" — CHỈ cho dữ liệu phải đọc từng ký tự (mã máy, OTP, serial, khoá).
  Không dùng cho tiêu đề hay nội dung.
- Luồng khách (web `/gallery` → `/compose/frames` → `/compose/photos` → `/compose`) · thanh "chặng đường"
  6 bước (`FlowSteps` trong `web/admin/app/compose/flow.tsx`) luôn nằm trên cùng mỗi trang:
  Xem ảnh chụp → Chọn frame → Chọn ảnh → Chỉnh sửa → Tạo ảnh in → In ảnh.
  Bước đã qua là link quay lại; mobile ẩn nhãn, chỉ hiện "Tên bước · x/6".
  CTA chính của mỗi bước nằm trong `.flow-bar` dính đáy màn hình.
  Ít chữ: không đoạn mô tả dưới tiêu đề, không câu hướng dẫn trong công cụ — nhãn ngắn + icon là đủ.
  Đầu mỗi bước (`.compose-header-row`) luôn một hàng: nút quay lại · tiêu đề (+ một dòng phụ) · một nút
  hành động; trên điện thoại nút hành động thu về icon để tiêu đề không xuống dòng.
- Chọn frame · không có khung xem trước; tên + bố cục ("2 nhóm × 4 ô") của frame đang chọn nằm trong
  `.flow-bar` cạnh nút "Chọn ảnh". Lưới co giãn theo số frame:
  1–4 frame (`.is-few`) — mỗi thẻ cao bằng phần màn hình còn trống, giữ đúng tỉ lệ frame, căn giữa
  (1 → 1 cột, 2 → 2 cột, 3–4 → 2 cột trên điện thoại / 3–4 cột desktop);
  từ 5 frame — lưới dày 3 cột trên điện thoại (2 cột dưới 360px).
- Trang có `.flow-bar` (`.has-flow-bar`) luôn cao ít nhất một màn hình: thanh đáy nằm sát đáy kể cả khi ít nội dung.
- Hiệu năng ảnh (luật cứng cho mọi trang khách):
  · Không bao giờ đặt ảnh gốc (≈2.5 MB, 24 MP) vào lưới. Ô ảnh dùng `<Thumb>` (`compose/thumbs.tsx`):
    có thumbnail thật thì hiện luôn; chưa có thì tải gốc MỘT lần, thu nhỏ 720px ngoài màn hình (2 ảnh
    cùng lúc, chỉ khi ô gần tới màn hình) rồi lưu ngược về gallery (`PUT /v1/public/gallery/:t/thumbnails/:id`).
  · Ô chỉnh sửa hiện bản 1600px (`screenCopyFor`); chỉ ảnh in mới đọc ảnh gốc. Frame hiện `preview_url`
    (~1600px, admin tự tạo), chỉ ảnh in đọc PNG gốc.
  · URL ký (signed) ổn định theo giờ → trình duyệt dùng lại cache. Gallery chỉ đọc lại khi máy chụp còn
    gửi ảnh: 4s → giãn dần tới 20s, dừng khi tab ẩn, dừng hẳn sau 6 lần không có ảnh mới / 10 phút;
    ảnh đã hiện giữ nguyên đối tượng (không đổi `src`).
- Ảnh đã ghép · nút thứ 3 cạnh "Tải ảnh lên / Tải tất cả" → `/gallery/composed`: ảnh ghép của máy chụp
  (`kind = collage`) + ảnh in khách tạo ở bước chỉnh sửa (lưu trong trình duyệt, IndexedDB, 7 ngày).
  Ảnh đã ghép LÀ đúng file ảnh in (PNG full-size), không phải bản nén — tải về in lại vẫn nét.
- Thương hiệu (admin → "Thương hiệu") · tên, logo (PNG/JPG/WebP ≤ 2MB, không SVG), 3 màu: nền, chữ, nút.
  `app/brand.tsx` ghi đè token của hệ thống ở `:root`; các sắc trung gian (thẻ, viền, chữ phụ) trộn từ 3 màu
  bằng `color-mix(in oklch, …)`. Chữ trên nút tự chọn tối/sáng theo màu nút. Nền tối → màu trạng thái
  (thành công / lỗi / giá) chuyển sang bản sáng và `color-scheme: dark`. Admin hiện độ tương phản chữ/nền
  (cảnh báo < 4.5:1) và xem trước điện thoại trước khi lưu. Mọi màu mới trong CSS PHẢI dùng token
  (không oklch cứng) để theo được thương hiệu.
  Logo + tên hiện ở: thanh bên admin, đầu trang gallery, đầu trang đặt lịch. Màu áp cho admin + mọi trang khách.
- Đặt lịch · khách: `/booking?studio_id=…`. Chưa đăng nhập → một thẻ 2 tab "Đăng nhập" (chỉ SĐT) /
  "Đăng ký" (họ tên + SĐT); phiên 24h. Đã đăng nhập → dòng tên + SĐT che ("09•• ••• 678") + "Thoát",
  rồi 3 tab: Đặt lịch (phòng → gói → ngày → giờ trống → ghi chú BẮT BUỘC; không hỏi lại tên/SĐT) ·
  Lịch của tôi · Ảnh của tôi.
  Lịch của tôi: lịch sắp tới lên đầu; lịch đã xác nhận hiện thẻ `.play-code` — mã chụp 4 số cỡ lớn (Mono),
  viền nét đứt, "dùng trong ngày dd/mm"; mã đã dùng gạch ngang. Còn lịch chờ → đọc lại mỗi 15s khi tab mở.
  Ảnh của tôi: lưới ảnh bìa buổi chụp (ngày · số ảnh · phòng) → `/gallery?t=…`.
  Admin → "Đặt lịch": dải 7 ngày, danh sách theo ngày, xác nhận / đã chụp / hủy / sửa / thêm lịch tại quầy;
  "Xác nhận" cấp mã chụp 4 số (chip `.booking-play-code` trên hàng lịch, "đã dùng" khi máy đã nhận);
  hủy = thu hồi mã. Tab "Cài đặt & mã QR": bật/tắt, giờ mở–đóng, khung 15/30/60', số ngày cho đặt trước,
  lời nhắn, mã QR trang đặt lịch (luôn đen trên trắng để quét được) tải PNG in được.
- Khóa gallery 24h · phiên chụp bằng mã đặt lịch, quá 24h: gallery thay lưới ảnh bằng thẻ `.gallery-lock`
  (tiêu đề + gợi ý SĐT che + ô SĐT + "Xem ảnh"); ẩn hàng nút và `.flow-bar`. Thương hiệu vẫn hiện.
  Khách vãng lai (không đặt lịch) không bị khóa.
- Thiết bị (admin) · mỗi máy một thẻ: trạng thái (Online / Tạm vắng / Offline) + "Đổi tên" (sửa tại chỗ,
  Enter lưu, Esc hủy); tên lớn = tên studio đặt (`display_name`), không có thì tên cấu hình máy,
  không có nữa thì "Máy chưa đặt tên". KHÔNG bao giờ hiện mã máy (hwid) ở web.
- Xoay / lật ô ảnh · công cụ "Xoay": giữ núm trên vòng xoay và kéo quanh để xoay mọi góc (hít 0/90/180/270
  trong ±4°), nút ±90°, "Lật" (gương ngang), "0°". Ảnh luôn phủ kín ô ở mọi góc; màn hình và ảnh in dùng
  chung phép tính trong `layout.ts`.
- Lưới ảnh khách (gallery + chọn ảnh) · một ô dùng chung `.photo-tile` trong `.photo-grid`:
  2 cột trên điện thoại, 3 từ 720px, 4 từ 1080px; ô 4:5. Chạm ảnh = xem lớn.
  Gallery: hàng nút "Xem" / "Tải" ở đáy mỗi ô; các nút chung (Tải ảnh lên · Tải tất cả) nằm một hàng.
  Chọn ảnh: chọn/bỏ bằng nút trái tim góc trên phải, số trong tim là thứ tự ô.
- Nhóm frame · frame của studio là tờ A4 nhiều thẻ trang trí (khối 2×2, dải 4 ô, dải phim…), nên nhóm do
  ADMIN quyết: mỗi slot lưu `group` trong `slots_json`. Khi tải frame lên, máy gợi ý nhóm
  (`withGroups()` + `gutterProbe()` trong `layout.ts`: cắt tờ theo rãnh trống — rãnh rộng luôn cắt, rãnh
  vừa cắt khi hai bên là bản sao hoặc ảnh có viền thẻ chạy dọc rãnh); admin sửa trong "Nhóm ô" (thư viện
  frame): chọn nhóm → chạm ô; "Nhận lại từ ảnh" dò lại ô + nhóm từ PNG gốc. Tối đa 24 ô/frame.
  Khách thấy đúng nhóm admin lưu, đánh số giống admin; mỗi nhóm hiện cả thẻ trang trí của nó.
  Frame cũ chưa có `group` → khách dùng gợi ý theo hình học. Nhóm giống hệt nhau = `copies`:
  ô trống ở nhóm sau lấy ảnh cùng vị trí của nhóm 1.
- Màn chỉnh sửa (`/compose`) · full màn hình điện thoại (100dvh, không cuộn trang): hàng nhóm ở trên,
  nhóm đang chọn ở giữa (phần còn lại của frame bị phủ mờ), chạm ô để mở ô đó tại chỗ;
  khi mở ô, hàng nhóm ẩn và dock công cụ (Ảnh · Bộ lọc · Zoom · Di chuyển) thay chỗ `.flow-bar`.
- Ghép ảnh vào slot · `web/admin/app/compose/layout.ts` là nguồn duy nhất cho cả xem trước lẫn ảnh in.
  Zoom 100% = phủ vừa ô, luôn giữ tỉ lệ ảnh gốc. Dưới 100%: nền là bản mờ của chính ảnh,
  mép ảnh làm mờ dần (không bao giờ lộ nền trống của slot).

## CTA Voice
- Primary · cocoa fill, cream text, pill radius, 48px minimum height.
- Secondary · typographic underline link, no box fill, same single-line affordance rule.
- Labels · concrete verbs: "Đặt lịch", "Lưu khách", "Xác nhận lịch".

## Motion Stance
- Motion-cut with two primitives only: page reveal and CTA hover lift.
- Animate transform and opacity only.
- Reduced-motion fallback · <=150ms opacity crossfade.

## Component Voice
- Booking surfaces are workbench panels, not marketing cards.
- Keep the receipt visible near choices; totals update silently.
- Photos are placeholders until replaced by real booth assets. Never present stock imagery as final studio proof.
- Headings stay roman; no italic display emphasis.
- Interactive text never wraps on mobile.

## Exports
`tokens.css` is the source of truth in this project. For Tailwind v4 `@theme`,
DTCG `tokens.json`, or shadcn/ui CSS variables, ask to extend `design.md` with
that export format.
