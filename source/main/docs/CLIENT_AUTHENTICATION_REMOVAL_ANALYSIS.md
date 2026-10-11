# CLIENT AUTHENTICATION REMOVAL ANALYSIS

Mục tiêu: **mở phần mềm → dùng ngay**. Không license, không activate, không HWID
approval, không phụ thuộc Internet/D1 để vào giao diện chính.

Ngày lập: 2026-08-03. Phương pháp: chỉ đọc mã nguồn.

---

## 1. KẾT LUẬN NGẮN

> **Cơ chế xác thực license/HWID trên máy khách ĐÃ ĐƯỢC VÔ HIỆU HOÁ SẴN TRONG MÃ NGUỒN
> bằng feature flag `kBypassMachineAuth = true`.**
> Phương án A mà yêu cầu đề ra **đã tồn tại** ở tầng license.

Tuy nhiên vẫn còn **4 cổng chặn thực tế** khiến "mở là dùng ngay" chưa đúng 100%:

| # | Cổng chặn | Mức | Phụ thuộc Internet? |
| --- | --- | --- | --- |
| **B-01** | **Cổng đăng nhập Google bắt buộc** ở build PHOTOBOOTH_ONLY / SELFBOOTH_ONLY | 🔴 CHẶN HOÀN TOÀN | **CÓ** — cần trình duyệt + OAuth |
| **B-02** | Build đầy đủ (`main.qml`): Google chưa đăng nhập → `authenticate()` **không bao giờ chạy** → `capabilities` rỗng → mọi sự kiện bị chặn bởi "nâng cấp gói" | 🔴 CHẶN CHỨC NĂNG | **CÓ** |
| **B-03** | `machines.activate != 1` → `POST /upload/presign` trả 403 → **không upload được ảnh, QR gallery hỏng** | 🟠 CHẶN TÍNH NĂNG | **CÓ** |
| **B-04** | Dialog đăng nhập nhân viên (`login_required=true`, mặc định) | 🟢 LOCAL, không chặn thật | Không |

Ngoài ra `DatabaseManager::initialize()` thất bại → `return -1` (app thoát) — đây là
phụ thuộc **local**, chấp nhận được, nhưng nên xử lý mềm hơn (xem mục 6).

---

## 2. Nghiên cứu cơ chế xác thực cũ (13 câu hỏi)

### 2.1 File nào tạo HWID

[src/backend/MachineAuthenticator.cpp](src/backend/MachineAuthenticator.cpp)

| Hàm | Dòng | Nội dung |
| --- | --- | --- |
| `MachineAuthenticator::getCPUInfo()` | 88-117 | `__cpuid(1)` → EDX, hex hoa |
| `MachineAuthenticator::getMACAddress()` | 119-138 | MAC đầu tiên non-loopback + IsUp, bỏ `:` |
| `MachineAuthenticator::getVolumeSerialNumber()` | 140-155 | `GetVolumeInformation("C:\\")` → serial hex hoa |
| `MachineAuthenticator::generateHWID()` | 157-181 | `SHA256(cpu+mac+volume).toHex().toUpper().left(16)` |

HWID được sinh **ngay trong constructor** (dòng 52), không chờ mạng.
HWID vẫn cần thiết cho: đường dẫn S3/gallery, doanh thu theo máy, QR login,
kho voucher theo studio. **Không được xoá HWID**, chỉ bỏ phần *kiểm tra quyền*.

### 2.2 File nào gọi API xác thực

| File | Hàm | Endpoint |
| --- | --- | --- |
| [DynamoDBClient.cpp:79-82](src/backend/DynamoDBClient.cpp#L79-L82) | `getMachine(hwid)` | `GET /machine/:hwid` |
| [DynamoDBClient.cpp:84-94](src/backend/DynamoDBClient.cpp#L84-L94) | `registerMachine(...)` | `POST /machine/:hwid` |
| [DynamoDBClient.cpp:96-105](src/backend/DynamoDBClient.cpp#L96-L105) | `claimMachine(...)` | `PATCH /machine/:hwid` |

### 2.3 Endpoint nào kiểm tra license

`GET /machine/:hwid` ([index.ts:1103-1116](cloudflare/worker/src/index.ts#L1103-L1116)).
Trả về `activate`, `license_end`, `plan`, `device_tier`, `capabilities`.
Worker **không tự chặn** — nó chỉ trả dữ liệu; quyết định chặn nằm ở client.

Ngoại lệ: `POST /upload/presign` **có tự chặn** ở phía Worker
([index.ts:2851-2855](cloudflare/worker/src/index.ts#L2851-L2855)) → B-03.

### 2.4 Bảng D1 chứa trạng thái

`machines` trong D1 `boothme_prod` (và `msb_photobooth`):
`activate`, `activated_at`, `license_start`, `license_end`, `plan`, `device_tier`, `trial_used`.

### 2.5 Hàm nào quyết định cho mở giao diện chính

**Hiện tại: KHÔNG CÓ.** Giao diện chính (`engine.load(url)` tại
[main.cpp:475](src/main.cpp#L475)) được nạp **vô điều kiện**, trước cả khi
`authenticate()` chạy. Không có bất kỳ nhánh nào chặn `engine.load()`.

Nhưng: quyền **dùng** giao diện phụ thuộc `machineAuth.capabilities`:

* [main.qml:252](qml/main.qml#L252), [273](qml/main.qml#L273), [372](qml/main.qml#L372),
  [392](qml/main.qml#L392), [588](qml/main.qml#L588), [622](qml/main.qml#L622) —
  `if (!machineAuth.canUseOperationMode(mode)) { root.showUpgradeNotice(); return }`
* Tương tự trong [ptb_main.qml](qml/ptb_main.qml) và [selfbooth_main.qml](qml/selfbooth_main.qml).

`canUseOperationMode()` ([MachineAuthenticator.h:68-73](src/backend/MachineAuthenticator.h#L68-L73))
đọc `m_caps`, mặc định **rỗng → false** (fail-closed).
`m_caps` chỉ được gán trong `authenticate()` (nhánh bypass) hoặc `onMachineFound()`.

→ **Nếu `authenticate()` không chạy, mọi chế độ vận hành đều bị chặn.** Đây chính là B-02.

### 2.6 Hàm nào hiển thị màn hình activate

| Màn hình | File | Điều kiện hiện |
| --- | --- | --- |
| `authPopup` "Xác thực máy" | [main.qml:749-922](qml/main.qml#L749-L922), [ptb_main.qml:711](qml/ptb_main.qml#L711), [selfbooth_main.qml:641](qml/selfbooth_main.qml#L641) | `onAuthenticationCompleted(false)` → `authPopup.open()` |
| `upgradeNoticePopup` / `entitlementNotice` "nâng cấp gói" | main.qml:654, ptb_main.qml:703, selfbooth_main.qml:239 | `showUpgradeNotice()` khi thiếu capability |
| `GoogleLoginScreen` | [qml/pages/GoogleLoginScreen.qml](qml/pages/GoogleLoginScreen.qml) | ptb_main.qml:171, selfbooth_main.qml:93 |
| `LicenseUpgradePanel` (mua gói SePay) | [qml/components/LicenseUpgradePanel.qml](qml/components/LicenseUpgradePanel.qml) | người dùng chủ động mở |

**Với `kBypassMachineAuth = true`**, `authenticate()` luôn `emit authenticationCompleted(true)`
([MachineAuthenticator.cpp:251](src/backend/MachineAuthenticator.cpp#L251)) → `authPopup`
không bao giờ mở, `showUpgradeNotice` không bao giờ kích hoạt (caps đầy đủ).
→ Điều kiện tiên quyết: **`authenticate()` phải được gọi**.

### 2.7 Hàm nào khóa chức năng

`MachineAuthenticator::hasCapability(key)` — [MachineAuthenticator.h:65-67](src/backend/MachineAuthenticator.h#L65-L67):

```cpp
Q_INVOKABLE bool hasCapability(const QString &key) const {
    return m_caps.value(key, false).toBool();   // fail-closed
}
```

### 2.8 Hàm nào thoát ứng dụng khi xác thực thất bại

**KHÔNG CÓ.** Không tồn tại `QCoreApplication::exit()` / `quit()` nào gắn với license.
Điểm thoát duy nhất khi khởi động là DB local lỗi:
[main.cpp:177-180](src/main.cpp#L177-L180) `if (!databaseManager.initialize(dbPath)) return -1;`
và lỗi nạp QML gốc ([main.cpp:390-392](src/main.cpp#L390-L392)).

### 2.9 Có timer kiểm tra license định kỳ không

**Có 2 timer, cả hai đều bị vô hiệu khi bypass:**

| Timer | Chu kỳ | File | Trạng thái khi bypass |
| --- | --- | --- | --- |
| `m_pollingTimer` | 10 s | [MachineAuthenticator.cpp:62-67](src/backend/MachineAuthenticator.cpp#L62-L67) | Chỉ chạy khi `status == Pending`. Bypass không bao giờ vào Pending → **không chạy** |
| `m_expirationCheckTimer` | 60 s | [MachineAuthenticator.cpp:70-82](src/backend/MachineAuthenticator.cpp#L70-L82) | Chỉ `start()` ở nhánh non-bypass (dòng 364, 369) → **không chạy** |

Timer khác (không phải license): `S3Uploader::m_retryTimer` 60 s, `QrLoginManager::m_pollTimer`.

### 2.10 Có code deactivate từ xa không

**Có, ở tầng dữ liệu, nhưng client hiện bỏ qua:**
`PATCH /machine/:hwid {activate:false}` từ CMS → `machines.activate = 0`.
Client với bypass **không đọc cờ này nữa** ([MachineAuthenticator.cpp:317-320](src/backend/MachineAuthenticator.cpp#L317-L320)):

```cpp
if (kBypassMachineAuth) {
    qDebug() << "Machine auth bypassed; ignoring server activate/license state for" << hwid;
    return;
}
```

**NHƯNG** Worker vẫn dùng `activate` để chặn `/upload/presign` → deactivate từ xa
**vẫn khoá được upload ảnh** (B-03).

### 2.11 Có file local lưu trạng thái license không

| Nơi lưu | Nội dung | File |
| --- | --- | --- |
| SQLite `machines.auth_status` | `'pending'` / `'authenticated'` | [DatabaseManager.cpp:817-826](src/backend/DatabaseManager.cpp#L817-L826) — chỉ để hiển thị, **không dùng để chặn** |
| `QSettings("BoothOS","Machine")` key `studio_id` | studio_id cache | [MachineAuthenticator.cpp:46](src/backend/MachineAuthenticator.cpp#L46) |
| `QSettings("BoothOS","GoogleAuth")` | `email`, `displayName`, `studioName` | [GoogleAuthManager.cpp:164-170](src/backend/GoogleAuthManager.cpp#L164-L170) |

**Không có file license ký số, không có cache `license_end` để bypass offline** —
comment tại [MachineAuthenticator.cpp:352-355](src/backend/MachineAuthenticator.cpp#L352-L355)
nói rõ cache này đã bị bỏ.

### 2.12 Có cập nhật license tự động không

Có, qua `POST /sepay/webhook` → `UPDATE machines SET activate=1, plan, license_end`
([index.ts:3077-3080](cloudflare/worker/src/index.ts#L3077-L3080)).
Chạy **phía server**, kích hoạt bởi ngân hàng, không phải client. Client chỉ poll
`GET /machine/:hwid/payment-intent/:code` để biết đã thanh toán.

### 2.13 Có updater liên quan license không

**KHÔNG.** Xem [AUTO_UPDATE_AND_PRODUCTION_RISK_ANALYSIS.md](AUTO_UPDATE_AND_PRODUCTION_RISK_ANALYSIS.md).

---

## 3. Luồng khởi động hiện tại (đã lần theo mã)

```text
main()  [src/main.cpp]
 ├─ 112  Logger::initialize()
 ├─ 121  disableUsbSelectiveSuspend()          (powercfg, detached)
 ├─ 162  splashEngine.load(StartupSplash.qml)
 ├─ 175  DatabaseManager databaseManager
 ├─ 177  databaseManager.initialize(dbPath)    ── THẤT BẠI → return -1  ⚠ điểm thoát duy nhất
 │        └─ createTables() → migration SQLite v1..v26  (đồng bộ, LOCAL)
 ├─ 186  ConfigManager::loadConfig(key.json)   (thất bại chỉ cảnh báo)
 ├─ 192  new MachineAuthenticator(&db)
 │        └─ ctor: QSettings studio_id + generateHWID()  (LOCAL, nhanh)
 │        └─ ctor: new DynamoDBClient(...)     (chưa gửi request)
 ├─ 196  new GoogleAuthManager  → configure() nếu client_id hợp lệ
 ├─ 204  googleAuth->restoreSession()          (QSettings, KHÔNG mạng)
 ├─ 209  new LicenseStore / 212 QrLoginManager (chưa gửi request)
 ├─ 220  EventManager eventManager(&db)        → new DynamoDBClient thứ 2
 ├─ 235  CameraController / 238 S3Uploader / 240 PrinterManager / ...
 ├─ 249  billAcceptor auto-connect (COM port từ DB)
 ├─ 298  httpBridge.start(5514)                (LOCAL)
 ├─ 325  QQmlApplicationEngine engine
 ├─ 475  engine.load(main.qml | ptb_main.qml | selfbooth_main.qml)   ◄── GIAO DIỆN MỞ VÔ ĐIỀU KIỆN
 └─ 477  app.exec()

      objectCreated → +500 ms →  [main.cpp:403-414]
         needGoogleLogin = googleAuth->configured() && googleAuth->email().isEmpty()
         ├─ TRUE  → KHÔNG gọi authenticate()   ⚠⚠ B-02
         └─ FALSE → machineAuth->authenticate()
                     └─ bypass: caps đầy đủ, status=Authenticated, emit(true)
                        + checkMachineOnDynamoDB()  (best-effort, lỗi bị nuốt)
```

### Luồng QML sau khi nạp

| Build | File | Cổng chặn |
| --- | --- | --- |
| Đầy đủ (mặc định) | `main.qml` | Không có GoogleLoginScreen. `login_required` → dialog nhân viên (local). **Nhưng** capabilities rỗng nếu chưa Google → mọi `_launchEvent` bị `showUpgradeNotice()` chặn. |
| `PHOTOBOOTH_ONLY` (build-ptb.ps1) | `ptb_main.qml:171` | `if (googleAuth.configured && !googleAuth.isLoggedIn) → push(GoogleLoginScreen); return` — **CHẶN CỨNG** |
| `SELFBOOTH_ONLY` | `selfbooth_main.qml:93` | Tương tự — **CHẶN CỨNG** |

`googleAuth.configured` = true vì [key.json](key.json) có `client_id` hợp lệ
(không bắt đầu bằng `REPLACE`) — [main.cpp:198](src/main.cpp#L198).

---

## 4. So sánh: yêu cầu vs. thực trạng

| Yêu cầu "không được có" | Thực trạng | Đạt? |
| --- | --- | --- |
| Yêu cầu License key | Không có màn nhập license key ở luồng khởi động | ✅ |
| Yêu cầu Activation code | Không | ✅ |
| Yêu cầu Mã 4 số | Mã 4 số là **voucher/khuyến mãi**, không phải kích hoạt | ✅ |
| Yêu cầu HWID approval | Bypass bật → không chờ duyệt | ✅ |
| Yêu cầu Server approval | Bypass bật | ✅ |
| Yêu cầu D1 approval | Bypass bật (nhưng còn `/upload/presign`) | ⚠️ **một phần** |
| Kiểm tra `active` | Bỏ qua ở client ([MachineAuthenticator.cpp:317](src/backend/MachineAuthenticator.cpp#L317)); Worker **vẫn kiểm** ở presign | ⚠️ **một phần** |
| Kiểm tra `activated` / `deactivated` | Bỏ qua ở client | ✅ |
| Kiểm tra `expires_at` để cho mở app | `m_licenseEndDate` đặt rỗng, timer không chạy | ✅ |
| Kết nối Internet để mở giao diện chính | **CÒN** — cổng Google ở 2 build; capabilities ở build đầy đủ | ❌ **CHƯA ĐẠT** |

---

## 5. Hai phương án (theo yêu cầu mục 5.3)

### PHƯƠNG ÁN A — Feature flag (KHUYẾN NGHỊ, triển khai trước)

Giữ nguyên toàn bộ module license/Google/QR. Chỉ **thêm cờ** để bỏ các cổng chặn
còn lại. Không xoá code. Không đụng D1.

#### A.1 — Thêm cờ tập trung (file mới, không sửa file cũ)

Tạo `src/backend/AppFeatureFlags.h`:

```cpp
#ifndef APPFEATUREFLAGS_H
#define APPFEATUREFLAGS_H

// ─────────────────────────────────────────────────────────────────────────────
// Cờ vô hiệu hoá xác thực khi mở phần mềm. Tất cả mặc định = "không chặn".
// Đặt về giá trị đối lập để quay lại hành vi cũ (rollback không cần build lại
// nếu dùng biến môi trường ở A.5).
// ─────────────────────────────────────────────────────────────────────────────

// false → KHÔNG bắt đăng nhập Google trước khi vào giao diện chính.
//         Người dùng vẫn đăng nhập được thủ công trong Cài đặt.
constexpr bool kRequireGoogleLoginAtStartup = false;

// true  → luôn cấp đủ capabilities tại chỗ ngay khi app khởi động, không chờ
//         mạng, không phụ thuộc thứ tự Google login.
constexpr bool kGrantAllCapabilitiesLocally = true;

// false → không hiện popup "Xác thực máy" trong mọi trường hợp.
constexpr bool kShowMachineAuthPopup = false;

#endif // APPFEATUREFLAGS_H
```

#### A.2 — Sửa `src/main.cpp` (2 dòng)

| Vị trí | Hiện tại | Thay bằng |
| --- | --- | --- |
| [main.cpp:407-414](src/main.cpp#L407-L414) | `const bool needGoogleLogin = googleAuth && googleAuth->configured() && googleAuth->email().isEmpty(); if (needGoogleLogin) { … } else { machineAuth->authenticate(); }` | `const bool needGoogleLogin = kRequireGoogleLoginAtStartup && googleAuth && googleAuth->configured() && googleAuth->email().isEmpty();` — phần còn lại giữ nguyên |

→ `authenticate()` **luôn chạy** → bypass cấp đủ caps → B-02 biến mất.

Bổ sung an toàn hơn (khuyến nghị): gọi `machineAuth->authenticate()` **ngay tại
[main.cpp:192](src/main.cpp#L192)** sau khi tạo object, thay vì chờ 500 ms sau QML.
Với bypass, hàm này hoàn toàn local (chỉ ghi SQLite + set caps) nên không tốn thời gian.
Như vậy giao diện có caps đúng **ngay từ frame đầu tiên**, không còn cửa sổ 500 ms
mà `hasCapability()` trả false.

#### A.3 — Sửa QML gate Google (2 file, mỗi file 1 điều kiện)

Cần expose cờ ra QML. Thêm vào `main.cpp` cạnh các `setContextProperty` khác
([main.cpp:362](src/main.cpp#L362)):

```cpp
engine.rootContext()->setContextProperty("requireGoogleLoginAtStartup",
                                         kRequireGoogleLoginAtStartup);
```

| File | Dòng | Sửa |
| --- | --- | --- |
| [qml/ptb_main.qml:171](qml/ptb_main.qml#L171) | `if (googleAuth.configured && !googleAuth.isLoggedIn) {` | `if (requireGoogleLoginAtStartup && googleAuth.configured && !googleAuth.isLoggedIn) {` |
| [qml/ptb_main.qml:531](qml/ptb_main.qml#L531) | `if (googleAuth.configured && !googleAuth.isLoggedIn)` (Connections onAuthStateChanged) | thêm `requireGoogleLoginAtStartup &&` |
| [qml/selfbooth_main.qml:93](qml/selfbooth_main.qml#L93) | như trên | như trên |
| [qml/selfbooth_main.qml:162](qml/selfbooth_main.qml#L162) | như trên | như trên |

**Không xoá** `GoogleLoginScreen.qml`, không xoá `googleLoginComponent` — vẫn cần
cho nút "Đăng nhập Google" trong Cài đặt ([SettingsPage.qml:2455](qml/pages/SettingsPage.qml#L2455)).

#### A.4 — Xử lý B-03 (upload presign) — **không sửa Worker trong Phase 4**

Đây là thay đổi phía server, nằm ngoài phạm vi "không thay đổi production".
Ba lựa chọn, xếp theo mức an toàn:

| Lựa chọn | Nội dung | Ảnh hưởng production |
| --- | --- | --- |
| **A.4.1 (khuyến nghị Phase 4)** | Không đụng gì. Chấp nhận: nếu máy chưa đăng ký/`activate=0` thì ảnh nằm ở thư mục pending và retry. Ghi log rõ ràng cho vận hành. | Không |
| A.4.2 (Phase 6+) | Sửa Worker: bỏ điều kiện `activate`, chỉ giữ kiểm tra `object_key` prefix. | **Cần deploy Worker** — phải phê duyệt thủ công |
| A.4.3 (Phase 6+) | Sửa Worker: `activate=0` vẫn cho presign nhưng ghi cờ cảnh báo. | Cần deploy |

Thực tế hiện tại: `POST /machine/:hwid` **tự đặt `activate=1`** cho máy mới
([index.ts:1138](cloudflare/worker/src/index.ts#L1138)), và bypass vẫn gọi
`registerMachine()` best-effort → máy mới cài xong, có mạng 1 lần là đủ.
Chỉ hỏng khi admin **chủ động** tắt `activate`.

#### A.5 — (Tuỳ chọn) đọc cờ từ file cấu hình thay vì hằng số

Cho phép rollback **không cần build lại**. Thêm vào [key.json](key.json):

```json
{
  "startup": {
    "require_license_activation": false,
    "require_google_login": false
  }
}
```

đọc trong `ConfigManager`. Đánh đổi: file JSON bị sửa được ở máy khách → chỉ nên
dùng nếu chấp nhận rủi ro đó. **Khuyến nghị Phase 4 dùng hằng số compile-time**
(giống `kBypassMachineAuth` hiện tại) để hành vi tất định.

#### A.6 — Bảng file cần sửa (Phương án A)

| File | Loại thay đổi | Số dòng | Rủi ro |
| --- | --- | --- | --- |
| `src/backend/AppFeatureFlags.h` | **TẠO MỚI** | ~20 | 🟢 Không |
| `src/main.cpp` | Sửa 1 điều kiện + thêm 1 `setContextProperty` (+ tuỳ chọn dời `authenticate()` lên sớm) | 2–4 | 🟢 Thấp |
| `qml/ptb_main.qml` | Thêm điều kiện cờ ở 2 chỗ | 2 | 🟢 Thấp |
| `qml/selfbooth_main.qml` | Thêm điều kiện cờ ở 2 chỗ | 2 | 🟢 Thấp |
| `CMakeLists.txt` | Không cần (header-only, cùng thư mục backend) | 0 | 🟢 Không |

**File GIỮ NGUYÊN, KHÔNG ĐƯỢC CHẠM trong Phase 4:**

| File | Lý do |
| --- | --- |
| `src/backend/MachineAuthenticator.cpp/.h` | Đã bypass sẵn; sửa thêm dễ gây hồi quy |
| `src/backend/DynamoDBClient.cpp/.h` | HWID/S3/voucher/doanh thu vẫn dùng |
| `src/backend/GoogleAuthManager.cpp/.h` | Cần cho đăng nhập thủ công trong Cài đặt |
| `src/backend/LicenseStore.cpp/.h` | Màn mua gói vẫn dùng |
| `src/backend/QrLoginManager.cpp/.h` | Đăng nhập QR + `fetchStudioInfo` |
| `qml/pages/GoogleLoginScreen.qml` | Vẫn gọi từ Cài đặt |
| `qml/components/LicenseUpgradePanel.qml` | Bán gói |
| `cloudflare/worker/**` | **TUYỆT ĐỐI KHÔNG** trong Phase 4 |
| `cloudflare/worker/migrations/**` | **TUYỆT ĐỐI KHÔNG** |
| `key.json` (giá trị token/secret) | Không rotate, không sửa endpoint |

#### A.7 — Rollback Phương án A

1. Đặt lại `kRequireGoogleLoginAtStartup = true`, `kGrantAllCapabilitiesLocally = false`.
2. Build lại, cài đè bằng installer.
3. Không có thay đổi dữ liệu nào cần hoàn tác (D1 và SQLite không đổi schema).

**Thời gian rollback: 1 lần build + 1 lần cài. Không mất dữ liệu.**

#### A.8 — Rủi ro Phương án A

| Rủi ro | Mức | Giảm nhẹ |
| --- | --- | --- |
| Máy chưa từng đăng nhập Google → `owner_email` rỗng → `studio_id` = 0 → URL gallery không có tiền tố studio | 🟠 | Trang gallery định vị theo `hwid` nên vẫn xem được ([S3Uploader.h:50-53](src/backend/S3Uploader.h#L50-L53)). Nhắc chủ studio đăng nhập trong Cài đặt sau. |
| Máy chưa gắn `owner_email` → route voucher trả `machine_unclaimed` | 🟠 | `kCodesLocalFirst=true` đã cho phép tạo/dùng mã hoàn toàn local. |
| Không còn ai kiểm soát được máy hết hạn | 🟡 | Đúng theo yêu cầu nghiệp vụ mới ("cài trực tiếp cho khách"). |
| Cửa sổ 500 ms caps rỗng nếu không dời `authenticate()` lên sớm | 🟡 | Dời lên `main.cpp:192` như A.2. |

---

### PHƯƠNG ÁN B — Loại bỏ hoàn toàn module license

**KHÔNG khuyến nghị ở giai đoạn này.** Chỉ làm sau khi Phase 5–7 hoàn tất và
đã chạy ổn định tối thiểu 1 tháng trên production.

#### B.1 — Phạm vi xoá

| Thành phần | Hành động | Cản trở |
| --- | --- | --- |
| `MachineAuthenticator` | **KHÔNG xoá được nguyên khối** — còn cung cấp `hwid()` và `studioId()` cho `S3Uploader`, `EventManager`, `QrLoginManager`, `HttpBridge`. Phải tách thành `MachineIdentity` (chỉ HWID + studio_id). | 🔴 Cao |
| `authPopup` trong 3 file QML | Xoá được | 🟢 |
| `upgradeNoticePopup` / `entitlementNotice` | Xoá được nếu bỏ luôn `canUseOperationMode` | 🟠 |
| `LicenseStore` + `LicenseUpgradePanel.qml` | Xoá được **nếu** ngừng bán gói qua app | 🟠 Quyết định kinh doanh |
| `GoogleAuthManager` + `GoogleLoginScreen.qml` | **KHÔNG nên xoá** — `owner_email` là khoá gom nhóm cho toàn bộ voucher/portal/doanh thu | 🔴 Cao |
| Endpoint Worker `/plans`, `/machine/:hwid/payment-intent`, `/sepay/webhook` | Xoá được sau khi client ngừng gọi | 🟠 Cần deploy |
| Cột D1 `machines.activate/license_*/plan/device_tier/trial_used` | **KHÔNG xoá** — `/upload/presign` và CMS đang đọc | 🔴 Cao |
| Bảng D1 `plans`, `payment_intents`, `app_sales` | Chỉ xoá sau khi xác nhận không còn báo cáo tài chính nào cần | 🔴 Cao |

#### B.2 — Rủi ro Phương án B

| Rủi ro | Mức |
| --- | --- |
| Xoá nhầm code đang dùng cho chức năng khác (HWID, studio_id, owner_email) | 🔴 CAO |
| Cần deploy Worker → ảnh hưởng mọi máy production cùng lúc | 🔴 CAO |
| Không rollback được phần đã xoá bảng D1 | 🔴 CAO |
| Máy khách cũ (chưa cập nhật) gọi endpoint đã xoá → lỗi | 🔴 CAO |
| Mất lịch sử doanh thu bán app | 🟠 |

#### B.3 — Rollback Phương án B

Chỉ rollback được phần client (git revert + build lại).
Phần D1 (xoá cột/bảng) **không rollback được nếu không có backup** — mà hiện tại
**không có cơ chế backup nào** (xem R-27 trong báo cáo D1).

---

## 6. Đề xuất bổ sung ngoài phạm vi license (nên gộp vào Phase 4)

### 6.1 — DB local lỗi không nên làm app thoát

[main.cpp:177-180](src/main.cpp#L177-L180):

```cpp
if (!databaseManager.initialize(dbPath)) {
    qCritical() << "Failed to initialize database at:" << dbPath;
    return -1;                       // ← app thoát, màn hình đen, khách không biết vì sao
}
```

Đề xuất (Phase 5, khi làm local-first):
1. Thử `dbPath` chính.
2. Thất bại → thử `%LOCALAPPDATA%\BOOTHME\photobooth.db`.
3. Vẫn thất bại → đổi tên file hỏng thành `photobooth.db.corrupt-<timestamp>` và
   tạo DB mới trống.
4. Vẫn thất bại → mở giao diện ở **chế độ giảm thiểu** kèm thông báo tiếng Việt,
   thay vì thoát im lặng.

### 6.2 — Bỏ blocking network khỏi UI thread

Xem R-07 trong [D1_PRODUCTION_BEHAVIOR_ANALYSIS.md](D1_PRODUCTION_BEHAVIOR_ANALYSIS.md).
6 hàm `blockingRequest` có thể treo UI 16–48 s. Thuộc Phase 6
(thiết kế ở [CLOUD_SYNC_DESIGN.md](CLOUD_SYNC_DESIGN.md)).

---

## 7. Danh sách thay đổi đề xuất — phân loại

### KEEP (giữ nguyên, đang đúng)

* `kBypassMachineAuth = true` — [MachineAuthenticator.cpp:26](src/backend/MachineAuthenticator.cpp#L26)
* `kCodesLocalFirst = true` — [EventManager.cpp:4590](src/backend/EventManager.cpp#L4590)
* `generateHWID()` và mọi nơi dùng HWID làm định danh
* `S3Uploader` staging + retry offline
* `revenue_id` SHA-256 idempotent
* `sessions.status_version` guard
* Không có auto-update, không có auto-migration D1

### DISABLE (tắt bằng cờ, không xoá) — Phase 4

* Cổng Google ở `ptb_main.qml:171`, `selfbooth_main.qml:93` (+2 Connections)
* Điều kiện hoãn `authenticate()` ở `main.cpp:407`
* `authPopup` (sẽ tự không mở khi bypass, thêm cờ `kShowMachineAuthPopup=false` cho chắc)

### REFACTOR — Phase 5–6

* Dời `machineAuth->authenticate()` lên ngay sau khi tạo object (`main.cpp:192`)
* `DatabaseManager::initialize()` fallback thay vì `return -1`
* 6 hàm `blockingRequest` → async + hàng đợi
* Tách `MachineAuthenticator` → `MachineIdentity` (HWID/studio_id) + `LicenseGate` (đã tắt)

### CREATE — Phase 5–6

* `src/backend/AppFeatureFlags.h`
* Bảng SQLite `sync_queue`, `sync_state`, `error_logs` (xem [LOCAL_DATABASE_SCHEMA_PROPOSAL.md](LOCAL_DATABASE_SCHEMA_PROPOSAL.md))
* `CloudSyncService` (xem [CLOUD_SYNC_DESIGN.md](CLOUD_SYNC_DESIGN.md))
* Script backup/restore SQLite local

### REMOVE LATER (chỉ sau khi ổn định ≥ 1 tháng)

* `authPopup` trong 3 file QML
* `LicenseStore` + `LicenseUpgradePanel.qml` (nếu ngừng bán gói qua app)
* `m_pollingTimer`, `m_expirationCheckTimer`
* Bảng `upload_queue` trong SQLite — **code chết**, được tạo ở migration v2 nhưng
  `addToUploadQueue()`/`getPendingUploads()`/`updateUploadStatus()` **không có caller nào**

### DO NOT TOUCH (tuyệt đối không chạm trong mọi Phase trước khi được phê duyệt)

* `cloudflare/worker/src/index.ts`
* `cloudflare/worker/wrangler.toml`
* `cloudflare/worker/migrations/**` — đặc biệt `005_revenue_v2.sql` (`DROP TABLE revenue`)
* `cloudflare/worker/package.json` script `db:init:remote`
* D1 `boothme_prod` (3d092835-…) và `msb_photobooth` (fd5284fa-…)
* D1 `photobooth` (a69d02e4-…) — mục đích **CHƯA XÁC ĐỊNH**
* Secret Worker: `API_TOKEN`, `AWS_*`, `GOOGLE_WEB_CLIENT_ID`
* `web/.vercel/project.json`, `web/vercel.json`
* `key.json` (giá trị token/secret/endpoint)
