# Sửa lỗi in cắt DS-RX1 — nhật ký thay đổi & checklist nghiệm thu

Chuẩn tham chiếu: [`DNP_RX1_CUT_PRINT_SPEC.md`](DNP_RX1_CUT_PRINT_SPEC.md)
Trạng thái: **đã code + build sạch + test số học PASS** — **CHƯA nghiệm thu trên máy in thật**.

---

## 1. Bằng chứng dẫn tới thay đổi

Đo các file **thực sự đã gửi driver** trong `Pictures\Photobooth\Events\1\printout\`:

```
print_CUT_20260802_020235_149_4sheets.jpg   2362 x 3543   aspect 0.6667
print_CUT_20260802_020747_763_9sheets.jpg   2500 x 3600   aspect 0.6944
print_CUT_20260802_022028_476_1sheets.jpg   2500 x 3600   aspect 0.6944
print_CUT_20260802_091728_430_1sheets.jpg   2500 x 3600   aspect 0.6944
print_CUT_20260802_095059_268_1sheets.jpg   2362 x 3543   aspect 0.6667
print_CUT_20260802_095627_117_1sheets.jpg   2500 x 3600   aspect 0.6944
```

Cùng một sự kiện, cùng một ngày, **hai hình học canvas xen kẽ nhau**, và **cả hai đều
sai** so với chuẩn DNP (`2480 × 3688`, aspect `0.67245`).

---

## 2. Thay đổi theo từng file

### 2.1 `src/backend/ImageCompositor.h` / `.cpp`

| Thay đổi | Lý do / nguồn |
|---|---|
| Thêm `struct DnpCutSheet` + `cutSheetPortrait()` / `cutSheetLandscape()` | Một nguồn số liệu duy nhất, lấy từ `Generating_OutputImage_E.pdf` §3 |
| Thêm `enum CutBleedMode` + `buildCutSheet()` — **đường DUY NHẤT** đặt ảnh lên tấm cắt | Trước đây 4 bản sao logic đặt ảnh nằm rải rác; chính đó là gốc của E1 |
| `fill` dùng scale COVER + clip theo ô; `safe` dùng CONTAIN | Cho phép so sánh hai cách xử lý rìa trên cùng một bản build |
| `composeWithCut()` RX1: canvas `2500×3600` → **`2480×3688`** (@600dpi) hoặc **`1240×1844`** (@300dpi) | Tỉ lệ cũ 0.6944 lệch 3.2% so với media thật |
| Bỏ 3 tham số `rx1CanvasW/H/SafeW` (không caller nào truyền) | Số liệu nay do `DnpCutSheet` quyết định |
| `composeWithCutHorizontal()`: dùng `cutSheetLandscape()` thay margin cứng 71/20/48 | Cùng lý do |
| Đặt strip theo **đối xứng gương** (`insetNear`/`insetFar`) | INV-6 — chia nguyên `slack/2` làm lệch 1px khi `slack` lẻ |
| Thêm cảnh báo runtime khi tâm nội dung ≠ đường cắt | Bắt hồi quy ngay trong log |
| **Xoá** `composePrintSheetV()` | Dead code mang hình học sai (71/20/48) |

### 2.2 `src/backend/EventManager.cpp` — `composeCutCanvas()`

| Thay đổi | Lý do |
|---|---|
| Dùng chung `ImageCompositor::cutSheet*()` | Hai đường ghép (có filter / không filter) nay ra **cùng một hình học** |
| **Bỏ crop lệch** `srcSafeRect(71, 20, W-95, H-40)` | Cắt 71px bên trái nhưng chỉ 24px bên phải → hai strip thành ảnh soi gương của nhau |
| Đặt strip theo đối xứng gương | INV-6 |
| Xoá hằng `outerMarginX=71 / outerMarginY=20` | Không còn dùng |

### 2.3 `src/backend/PrinterManager.h` / `.cpp`

| Thay đổi | Nguồn |
|---|---|
| Thêm `ExBorder=3`, `DM_BORDER_OFF/ON` | `PrintSettings_E.pdf` §2(2), §4 |
| Gộp ghi vùng private vào `writeDevmodePrivateInt()`, **đọc lại để xác nhận** | Trước đây ghi xong không kiểm tra |
| `modifyDevmodeCut()` thất bại → **cảnh báo rõ** thay vì im lặng | Thất bại âm thầm ⇒ job chạy theo cấu hình cắt cũ của driver |
| Thêm `dnpEnumeratePapers()` + `isCut4x6PaperName()` | `Paper.vb::GetPaperSizeInfo()`, `Form1.vb:430` |
| **Đặt `dmPaperSize`** về `(6x4)` / `PR (4x6)` khi cắt; `dmFields \|= DM_PAPERSIZE`; **xoá** `DM_PAPERLENGTH\|DM_PAPERWIDTH` | `Devmode.vb::PrintSetting()`. 2inch-cut chỉ hiệu lực trên các khổ này |
| **Đặt `OemBorder = 0`** khi cắt | Bật Border ⇒ driver trừ viền vào ảnh ⇒ lệch tâm |
| **Bỏ hard-code "driver đảo hướng"** → tạo DC, đọc canvas thật, lật `dmOrientation` và dựng lại DC nếu lệch | `DriverPrintDirection_E.pdf` §2/§3.2: hai họ media có hướng NGƯỢC nhau |
| `StretchDIBits` vẽ tại **`(-PHYSICALOFFSETX, -PHYSICALOFFSETY)`** | Gốc printer DC là góc vùng in được, không phải góc giấy |
| Đồng bộ toàn bộ vào `tryPrintOnePrinterSilent()` | Nhánh auto-scan phải ra cùng kết quả |
| Log thêm: `dmPaperSize`, `dmFormName`, `dmFields`, `ExDevTop`, `OemBorder`, `OemCut2inch` (đọc lại), dest rect | Chẩn đoán sau khi triển khai |

### 2.4 QML — đồng bộ cờ cắt

Điều kiện GHÉP ảnh ở `EventManager` là `event.autoCut && printerConfig.cutMode`,
nhưng cờ gửi driver lại chỉ lấy `autoCut` ⇒ có thể ghép strip đơn rồi vẫn bảo máy cắt.

| File | Thay đổi |
|---|---|
| `ResultScreen.qml` | thêm `canCut = autoCut && printerConfig.cutMode`; `selectedCutMode` mặc định theo `canCut`; chặn bật cắt khi `!canCut` |
| `FilterScreen.qml` | như trên |
| `BoothSession.qml:1416` | `prePaymentCutMode: false` (hard-code) → `autoCut && printerConfig.cutMode` |
| `BoothSession.qml:1642` | `!!autoCut` → `!!autoCut && printerConfig.cutMode` |

---

## 3. Kết quả kiểm thử đã chạy được (không cần máy in)

| Hạng mục | Kết quả |
|---|---|
| Build `BOOTHME` (CMake Release, Qt 6.10.3, VS 2026) | ✅ thành công, không lỗi/cảnh báo mới |
| `qmllint` 3 file QML đã sửa | ✅ không lỗi cú pháp |
| Test số học bất biến (13 kích thước strip × 2 hướng) | ✅ 20/20 PASS, `mid == cutLine` chính xác tuyệt đối |
| Đối chiếu tỉ lệ canvas với bảng DNP | ✅ `0.67245` khớp cả 300dpi và 600dpi |

Kịch bản test số học: `scratchpad/verify_cut_geometry.py` (sao chép nguyên văn phép
toán số nguyên của C++ để bắt lỗi làm tròn — chính nó đã phát hiện lỗi lệch 1px và
dẫn tới INV-6).

---

## 4. Checklist nghiệm thu trên máy booth

### 4.0 So sánh hai chế độ rìa ảnh (`fill` vs `safe`)

Vào **Cài đặt → Máy in**, dưới ô "Chế độ cắt" có công tắc **"Rìa ảnh khi in cắt"**.
Mặc định `fill` (tràn mép) — khớp cách các cửa hàng khác vẫn làm.

- [ ] Để `fill`, in 1 tờ. File tương ứng trong `printout/` có tên `print_CUT_..._fill_...jpg`.
- [ ] Gạt sang `safe`, in 1 tờ nữa → `print_CUT_..._safe_...jpg`.
- [ ] So hai tờ:
      - `fill` — hoạ tiết chạy sát mép, không có sọc nền, nhưng rìa ngoài cùng bị mất ~1.7mm.
      - `safe` — thiết kế còn nguyên vẹn, nhưng có thể thấy sọc nền mỏng ở mép nếu giấy lệch.
- [ ] **Cả hai tờ phải cắt đều như nhau.** Nếu một chế độ cắt đều mà chế độ kia lệch
      thì vấn đề KHÔNG nằm ở bleed — quay lại mục 4.2 đọc log.

Chọn xong thì để nguyên chế độ đó; giá trị lưu machine-global, không đổi theo sự kiện.

### 4.1 Kiểm tra tĩnh — không cần in (5 phút)

- [ ] Chạy vài phiên **có filter** và vài phiên **không filter**, cùng layout, cùng cấu hình.
- [ ] Mở `Pictures\Photobooth\Events\<event>\printout\` — **mọi** file `print_CUT_*.jpg`
      (cùng một chế độ rìa) phải có **cùng một kích thước**: `2480×3688` (hoặc `1240×1844`).
      → Nếu còn thấy `2500×3600` hay `2362×3543`: bản build cũ chưa được thay.
- [ ] Mở 1 file, đo bằng mắt: hai nửa giống hệt nhau, lề trắng ngoài trái = ngoài phải.

### 4.2 Đọc log — không cần in

Mở `<thư mục exe>\logs\app.log`, tìm khối `PRINT JOB DIAGNOSTIC LOG`:

- [ ] `Canvas (PHYSICALWIDTH x HEIGHT)` = `1240 x 1844` (@300dpi) — nếu khác, khổ giấy driver sai.
- [ ] `DEVMODE PaperSize` hiển thị `"(6x4)"` hoặc `"PR (4x6)"`.
- [ ] `DNP private DEVMODE: ExDevTop=... OemBorder=0 OemCut2inch=1` — **phải đọc lại được đúng giá trị**.
- [ ] `dmFields ... PAPERLENGTH: -  PAPERWIDTH: -` (đã xoá, không còn `SET(!)`).
- [ ] `✓ Aspect ratios match` — **không** còn `⚠ ASPECT RATIO MISMATCH`.
- [ ] Nếu thấy `Hướng canvas KHÔNG khớp ảnh → lật dmOrientation`: bình thường, nghĩa là
      máy đang dùng họ media `PR (4x6)` và code đã tự sửa. Canvas sau khi lật phải đúng.
- [ ] **Không** có dòng `*** KHÔNG TÌM THẤY vùng private DEVMODE ***`.

### 4.3 In thử (1 tờ)

- [ ] In 1 tờ chế độ cắt. Đo bằng thước: hai mảnh phải **bằng nhau ±1mm**.
- [ ] Nội dung ảnh trên mỗi mảnh phải căn giữa, lề trắng hai bên bằng nhau.
- [ ] In tiếp 2 tờ nữa **cùng file, cùng cấu hình** → vị trí cắt phải giống nhau.
      Nếu vẫn trôi giữa các tờ ⇒ lúc đó mới nghi cơ khí/media.

### 4.4 Hồi quy chế độ KHÔNG cắt (quan trọng — đang chạy tốt)

- [ ] In 1 tờ **không cắt** → so với bản in cũ: kích thước và bố cục **không được đổi**.
- [ ] Xác nhận trong log: khi `Cut Mode: OFF` thì `DEVMODE PaperSize` ghi
      *"(giữ nguyên của driver)"* — code **không** đụng khổ giấy ở nhánh này.
- [ ] Nếu log cho `Physical Offset: 0 x 0` thì việc bù offset là no-op ⇒ nhánh không cắt
      chắc chắn không đổi. Nếu offset **khác 0**, bản in không cắt sẽ dịch nhẹ
      (đúng hơn trước, nhưng khác trước) → cần xác nhận bằng mắt.

---

## 5. Rủi ro còn lại / việc chưa làm

| # | Vấn đề | Mức | Ghi chú |
|---|---|---|---|
| R1 | `LayoutAnalyzer::getTargetSizeByAspect()` vẫn dùng `591×1772` / `1181×3543` thay vì `600×1800` / `1200×3600` | Thấp | Lệch 1.5%, code mới scale về đúng nên **vô hại về hình học**, chỉ hơi mất nét. **Cố ý chưa sửa**: hàm này ghi đè trực tiếp file PNG layout trên máy production và sẽ làm lệch toạ độ slot trong JSON đã sinh. |
| R2 | Bù `PHYSICALOFFSET` áp dụng cho **cả** nhánh không cắt | Trung bình | No-op khi offset = 0 (borderless — trường hợp thường gặp của DNP). Xem mục 4.4. |
| R3 | Chưa test trên máy in thật | Cao | Toàn bộ checklist mục 4 chưa chạy. |
| R4 | `printImageWithSettings()` vẫn bỏ qua tham số `paperSize` và `matteFinish` | Thấp | Tham số chết từ trước, không liên quan lỗi cắt. Có thể nối `matteFinish` vào `OemOvercoatFinish` (private offset 27) sau. |
| R5 | Nhánh QW410 chưa đụng tới | Thấp | Ngoài phạm vi; máy hiện dùng là DS-RX1. |
| R6 | In lại từ Gallery dùng `quality` theo `printerConfig.resolution` (600) còn phiên chụp dùng 300 | Thấp | Canvas driver khác nhau nhưng tỉ lệ giống nhau ⇒ không gây lệch cắt. Nên thống nhất sau. |
