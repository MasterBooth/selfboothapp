# SPEC — Hình học tấm in & chế độ cắt DNP DS-RX1

> **Nguồn duy nhất được chấp nhận:** tài liệu hãng trong
> `Status API/Window SDK/DS-RX1 CyStat SDK v1.43 (1)/DS-RX1 CyStat SDK v1.43/E/`
> Mọi con số trong code phải truy ngược được về mục dưới đây.
> Không dùng số "ước lượng theo inch × DPI".

---

## 1. Kích thước ảnh output chính thức

Nguồn: `ReferenceMaterial/Generating_OutputImage_E.pdf` §3 bảng *Reference image size*
và `ReferenceMaterial/DriverPrintDirection_E.pdf` §4 *Image Size* (hai bảng trùng khớp).

| Media | Orientation | inch | mm | 300×300 | 300×600 | 600×600 |
|---|---|---|---|---|---|---|
| `(6x4)` / `(6x4) x 2` | Portrait | 6 × 4 | 156.1 × 105.0 | **1844 × 1240** | 1844 × 2480 | **3688 × 2480** |
| `(6x4)` / `(6x4) x 2` | Landscape | 4 × 6 | 105.1 × 156.1 | **1240 × 1844** | 2480 × 1844 | **2480 × 3688** |
| `PR (4x6)` / `PR (4x6) x 2` | Portrait | 4 × 6 | 105.1 × 156.1 | **1240 × 1844** | 2480 × 1844 | **2480 × 3688** |
| `PR (4x6)` / `PR (4x6) x 2` | Landscape | 6 × 4 | 156.1 × 105.0 | **1844 × 1240** | 1844 × 2480 | **3688 × 2480** |
| `(6x8)` | Portrait | 6 × 8 | 156.1 × 206.2 | 1844 × 2436 | 1844 × 4872 | 3688 × 4872 |

### 1.1 Vùng in LỚN HƠN giấy (bleed)

> *"(\*) The print area size is set larger than the actual paper size
> (1.5mm larger top, bottom, 2.0mm larger left, right)."*
> — `Generating_OutputImage_E.pdf`, chú thích bảng

Suy ra cho khổ 4×6 (giấy thật 101.6 × 152.4 mm):

| Trục | Canvas @300dpi | Giấy thật @300dpi | Bleed mỗi cạnh |
|---|---|---|---|
| Cạnh 4″ (trục dao cắt) | **1240** | 1200 | **20 px** (1.69 mm) |
| Cạnh 6″ (chiều dài strip) | **1844** | 1800 | **22 px** (1.86 mm) |

@600×600 dpi nhân đôi: canvas **2480 × 3688**, giấy **2400 × 3600**, bleed **40 / 44**.

> ⚠️ Đây là lý do canvas KHÔNG có tỉ lệ 2:3. Tỉ lệ đúng của canvas 4×6 portrait là
> `1240 / 1844 = 0.67245`, **không phải** `0.6667`, càng không phải `0.6944`.

---

## 2. Hình học tấm in chế độ CẮT (2 strip 2×6)

2inch-cut xẻ tờ 6×4 thành **hai mảnh 6″ × 2″**. Dao cắt đi qua **tâm vật lý của cạnh 4″**.

Vậy trong canvas *portrait* `1240 (W) × 1844 (H)`:

```
       ┌── bleedX=20 ──┐                       ┌── bleedX=20 ──┐
       │               │                       │               │
   0  20             620          (tâm)      1220            1240   ← trục X (cạnh 4", dao cắt)
   ├───┼───────────────┼───────────────────────┼───────────────┼──►
   │ b │   STRIP 1     │       STRIP 2         │ b │
   │   │   600 px      │       600 px          │   │
   │   │   = 2.0"      │       = 2.0"          │   │

   trục Y: 0 ─ bleedY=22 ─ [ nội dung 1800 px = 6.0" ] ─ bleedY=22 ─ 1844
```

**Bất biến bắt buộc:**

| # | Bất biến |
|---|---|
| INV-1 | `canvasW = contentW + 2 × bleedX`, `canvasH = contentH + 2 × bleedY` |
| INV-2 | Đường cắt = `canvasW / 2` = `bleedX + contentW/2` (⇒ nội dung phải đối xứng tuyệt đối qua tâm) |
| INV-3 | Strip 1 chiếm `[bleedX, bleedX + contentW/2]`, Strip 2 chiếm `[bleedX + contentW/2, bleedX + contentW]` |
| INV-4 | Hai strip là **cùng một ảnh nguồn, cùng kích thước đích**, không crop lệch bên nào |
| INV-5 | Lề trên = lề dưới = `bleedY` |
| INV-6 | Khi strip không lấp kín nửa của nó, phần dư phải chia **đối xứng gương** quanh đường cắt |

### 2.0 Hai chế độ xử lý bleed

Vùng in lớn hơn giấy nên phần rìa **luôn rơi ra ngoài giấy**. Có hai cách dùng nó,
chọn bằng app setting `cut_bleed_mode` (machine-global, mặc định `fill`):

| | `fill` — FillToEdge (tràn mép) | `safe` — SafeMargin (hiện đủ) |
|---|---|---|
| Ô của 1 strip | `canvasW/2 × canvasH` | `contentW/2 × contentH` |
| Scale | **COVER** = `max(sx, sy)`, xén phần thừa | **CONTAIN** = `min(sx, sy)`, chừa màu nền |
| Kết quả trên giấy | phủ kín mép, không bao giờ lộ sọc nền | giữ trọn hoạ tiết sát mép |
| Đánh đổi | mất ~1.7mm rìa ngoài cùng của thiết kế | giấy lệch cơ khí có thể lộ sọc nền |
| Tương đương | cách các phần mềm photobooth khác vẫn làm | — |

> **Cả hai đều cho đường cắt tại `canvasW/2` như nhau.** Chế độ bleed **không**
> ảnh hưởng tới việc cắt đều — nó chỉ quyết định phần rìa.
> Điều kiện duy nhất để cắt đều là hai ô đối xứng qua đường cắt (INV-2).

### 2.0.1 Công thức đặt strip (bắt buộc dùng chung cho mọi đường ghép)

```cpp
const int slack = stacked ? (cellH - dH) : (cellW - dW);

// slack ≥ 0 (CONTAIN/safe): còn chỗ trống → chia ĐỐI XỨNG GƯƠNG
// slack < 0 (COVER/fill)  : ảnh tràn ra  → DÙNG CHUNG offset cho cả hai ô
const int insetNear = (slack >= 0) ? (slack + 1) / 2 : slack / 2;
const int insetFar  = (slack >= 0) ? (slack / 2)     : slack / 2;
```

Kèm **clip theo từng ô** (`setClipRect`) — ở chế độ COVER ảnh tràn ra ngoài ô,
không clip thì strip này đè sang nửa kia và phá đối xứng quanh đường cắt.

> ⚠️ Khi `slack ≥ 0`, **không được** dùng chung `inset = slack/2` cho cả hai strip:
> lúc `slack` lẻ, chia nguyên làm lề ngoài trái/phải lệch 1px và tâm nội dung rời
> khỏi đường cắt → vi phạm INV-2.
> Ngược lại khi `slack < 0` thì **phải** dùng chung offset, để hai strip bị xén y
> hệt nhau ⇒ hai ảnh in ra giống hệt nhau.
>
> Đã kiểm chứng bằng bộ test số học trên toàn dải kích thước strip thực tế,
> cả hai chế độ, cả hai hướng cắt.

**Cài đặt duy nhất được phép:** `ImageCompositor::buildCutSheet()`.
Mọi nơi cần tấm cắt phải gọi hàm này — trước đây `composeWithCut()` và
`composeCutCanvas()` tự cài đặt riêng nên cùng một phiên chụp lại in ra hai bố cục
khác nhau tuỳ user có áp filter hay không.

### 2.1 Bộ số chuẩn hoá theo DPI

| Tên | 300×300 | 600×600 |
|---|---|---|
| `canvasW × canvasH` (portrait) | 1240 × 1844 | 2480 × 3688 |
| `contentW × contentH` | 1200 × 1800 | 2400 × 3600 |
| `bleedX / bleedY` | 20 / 22 | 40 / 44 |
| 1 strip 2×6 (usable) | 600 × 1800 | 1200 × 3600 |

Khổ landscape (cắt ngang, 2 strip 6×2 xếp chồng): hoán vị W↔H và bleedX↔bleedY.

---

## 3. Hướng in — hai họ media NGƯỢC NHAU

Nguồn: `DriverPrintDirection_E.pdf` §2, §3.2 và bảng §4.

> *"Compared with the compatible media types, the new media type has a different
> Print Orientation in the driver settings."*
> *"The image height x width sizes for the compatible and new media types are opposite."*

| Ảnh gốc | Media | `dmOrientation` cần đặt |
|---|---|---|
| Portrait | `(5x3.5)` `(6x4)` `(6x4) x 2` — **DS40 compatible** | `DM_LANDSCAPE` (2) |
| Portrait | `PR (3.5x5)` `PR (4x6)` `PR (4x6) x 2` — **RX1 new** | `DM_PORTRAIT` (1) |
| Landscape | compatible | `DM_PORTRAIT` (1) |
| Landscape | new | `DM_LANDSCAPE` (2) |

**Hệ quả cho code:** KHÔNG được hard-code "driver bị đảo hướng". Cách đúng và bền vững:

```
1. đặt dmOrientation theo phỏng đoán
2. CreateDC → đọc PHYSICALWIDTH/PHYSICALHEIGHT
3. nếu hướng canvas ≠ hướng ảnh  →  lật dmOrientation, DeleteDC, CreateDC lại
4. (chỉ lặp tối đa 1 lần)
```
Cách này đúng cho **cả hai** họ media mà không cần biết đang dùng họ nào.

---

## 4. Private DEVMODE (vùng riêng của DNP)

Nguồn: `Print Settings Sample/Doc/PrintSettings_E.pdf` §2(2), §4
và `Print Settings Sample/VB.NET PrintSettings_Sample/Devmode.vb`.

Vùng private nằm **ngay sau** public DEVMODEW. Vị trí thay đổi theo máy ⇒ phải dò
chuỗi `"MSFT"` (`EX_DEV_SIGN = 0x4D534654`).

```
ExDevTop = (chỉ số int chứa "MSFT") - 1     // vì OemExStrSize ở offset 0, OemExSign ở offset 1
```

| Offset (int, từ `ExDevTop`) | Thành viên | Giá trị |
|---|---|---|
| 0 | `OemExStrSize` | kích thước vùng private |
| 1 | `OemExSign` | `"MSFT"` |
| 2 | `OemExVer` | version |
| **3** | `OemBorder` | **0 = No border, 1 = Border** |
| 4 | `OemColorAdjustment` | 0/1 |
| 5 | `OemSharpness` | 0..10 |
| 27 | `OemOvercoatFinish` | 0 = Glossy, 1 = Matte |
| 29 | `OemPrintRetry` | 0/1 |
| **30** | `OemCut2inch` | **0 = Normal cut, 1 = 2inch cut** |

> `PrintSettings_E.pdf` §4: *"Border → 0 No / 1 Yes"*, *"2inch Cut → 0 Normal cut / 1 2inch cut"*.
> `Generating_OutputImage_E.pdf`: *"When set to Border, the border is subtracted from
> the image pixel sizes shown above."* ⇒ **muốn dùng đủ 1240×1844 thì `OemBorder` phải = 0.**

### 4.1 Public DEVMODE bắt buộc

Theo `Devmode.vb::PrintSetting()` — bản mẫu của hãng:

```vb
dmw.dmPaperSize    = <số hiệu khổ>            ' BẮT BUỘC
dmw.dmOrientation  = <1|2>
dmw.dmPrintQuality = 300 | 600                ' X-axis resolution (đơn vị DPI thật)
dmw.dmYResolution  = 300 | 600                ' Y-axis (chiều feed giấy)
dmw.dmFields  = dmw.dmFields Or DM_PAPERSIZE Or DM_PRINTQUALITY Or DM_YRESOLUTION _
                             Or DM_ORIENTATION Or DM_ICMMETHOD
dmw.dmFields  = dmw.dmFields And Not DM_PAPERLENGTH And Not DM_PAPERWIDTH   ' BẮT BUỘC XOÁ
```

### 4.2 Điều kiện để 2inch-cut có hiệu lực

`Print Settings Sample/VB.NET PrintSettings_Sample/Form1.vb:430`

```vb
If ComboPaperSize.Text = "(6x4)" Or "PR (4x6)" Or "(6x8)" Then
    ComboCut2inch.Enabled = True
Else
    ComboCut2inch.SelectedIndex = DM_CUT2INCH_OFF   ' driver vô hiệu hoá cắt
End If
```

⇒ **`OemCut2inch = 1` chỉ có tác dụng khi `dmPaperSize` là `(6x4)`, `PR (4x6)` hoặc `(6x8)`.**
Nếu ứng dụng không set `dmPaperSize`, khổ giấy là giá trị mặc định của spooler Windows —
di sản của lần chỉnh Printer Preferences gần nhất ⇒ cắt có thể bị driver bỏ qua im lặng.

### 4.3 KHÔNG nhầm với "2-image layout multi-cut"

`ReferenceMaterial/DualImage_E.pdf`: chế độ 2-image layout (2 trang / 1 lần in) chỉ dùng
được với media **6x8 hoặc 5x7**, và tương ứng khổ `(6x4) x 2` / `PR (4x6) x 2`
(`Paper.vb::MultiCutNum()` → `MultiCut = 2`). Đây là cơ chế **khác** 2inch-cut.
Ứng dụng photobooth dùng 2inch-cut, **không** dùng multi-cut.

---

## 5. Ánh xạ bitmap → trang in (GDI)

- Gốc toạ độ của printer DC = góc trên-trái **vùng in được**, lệch `PHYSICALOFFSETX/Y`
  so với góc **trang vật lý**.
- Muốn phủ đúng toàn trang vật lý, destination rect phải là:

```cpp
StretchDIBits(hdc,
              -GetDeviceCaps(hdc, PHYSICALOFFSETX),
              -GetDeviceCaps(hdc, PHYSICALOFFSETY),
              GetDeviceCaps(hdc, PHYSICALWIDTH),
              GetDeviceCaps(hdc, PHYSICALHEIGHT),
              ...);
```

- Khi driver ở chế độ borderless, `PHYSICALOFFSET* = 0` ⇒ biểu thức trên là **no-op**.
- Vẽ tại `(0,0)` với kích thước `PHYSICAL*` (code cũ) làm nội dung **dịch phải/xuống
  đúng `PHYSICALOFFSET`** và bị xén ở mép phải/dưới ⇒ tâm nội dung không còn trùng tâm
  giấy ⇒ **dao cắt ở giữa giấy sẽ chia hai phần không đều**.

---

## 6. Bảng tra nhanh cho reviewer

| Câu hỏi | Đáp án chuẩn | Nguồn |
|---|---|---|
| Canvas 4×6 portrait @300dpi? | 1240 × 1844 | Gen §3 bảng |
| Canvas 4×6 portrait @600dpi? | 2480 × 3688 | Gen §3 bảng |
| Tỉ lệ canvas 4×6 portrait? | 0.67245 | tính từ bảng |
| Vùng giấy thật bên trong canvas? | 1200 × 1800 (@300) | Gen §3 chú thích (\*) |
| Bleed? | 20 px trục 4″, 22 px trục 6″ (@300) | Gen §3 chú thích (\*) |
| Dao cắt ở đâu? | tâm cạnh 4″ = canvasW/2 | DualImage §2 + định nghĩa 2inch cut |
| Bật cắt bằng gì? | `OemCut2inch` = private int offset 30 | PrintSettings §2(2), §4 |
| Cắt yêu cầu khổ nào? | `(6x4)`, `PR (4x6)`, `(6x8)` | Form1.vb:430 |
| Border phải đặt gì? | `OemBorder = 0` | PrintSettings §4 + Gen §3 |
| dmPrintQuality nhận gì? | 300 hoặc 600 (DPI thật) | PrintSettings §4 |
| Hướng in? | phụ thuộc họ media, phải dò lại canvas | DriverPrintDirection §3.2 |
