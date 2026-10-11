# Thư viện nhúng — Monocypher

## Nguồn gốc

| | |
| --- | --- |
| Dự án | [Monocypher](https://monocypher.org) — LoupVaillant/Monocypher |
| Phiên bản ghim | **tag `4.0.2`** |
| Ngày tải | 2026-08-05 |
| Giấy phép | Song song **BSD 2-Clause** hoặc **CC-0** (chọn một) — xem đầu mỗi file |

Tải trực tiếp từ `raw.githubusercontent.com` tại đúng tag trên, không qua trung gian:

```
src/monocypher.c                   → monocypher.c
src/monocypher.h                   → monocypher.h
src/optional/monocypher-ed25519.c  → monocypher-ed25519.c
src/optional/monocypher-ed25519.h  → monocypher-ed25519.h
```

## SHA-256 (đối chiếu khi nâng cấp)

```
02174117935699d418443c75a558a287deb06ef8cf7c1adced61d9047d2f323d  monocypher.c
fcaf6ed771358bb4f40fba016f6518ae86ec02b1b877d2cc35ad92d3a26fd7b3  monocypher.h
97d581639dfa72be08a6d57deb7d79b736be001cb416819cab196d22559d242b  monocypher-ed25519.c
3a3035181f991a158d0e1c7567258f0bae8ba0f1f23c5512b4a1db1b3c9730ce  monocypher-ed25519.h
```

Đối chiếu lại bất cứ lúc nào:

```powershell
Get-FileHash src\backend\vendor\*.c, src\backend\vendor\*.h -Algorithm SHA256
```

> Chuỗi `Monocypher version __git__` ở đầu file là biến thay thế lúc đóng gói bản
> phát hành; bản tải thẳng từ git giữ nguyên placeholder. Phiên bản thật là tag
> đã ghim ở trên, và các mã băm bên trên mới là thứ dùng để đối chiếu.

## Vì sao nhúng thay vì liên kết OpenSSL

Dự án chỉ `find_package(Qt6 …)` ([CMakeLists.txt:41](../../../CMakeLists.txt)), **không có
OpenSSL**. Trong `src/` chỉ có `QCryptographicHash` (SHA-256) và
`QMessageAuthenticationCode` (HMAC-SHA256) — không có API bất đối xứng nào.

Nhúng bốn file này:

- Không thêm DLL phải đóng gói trong `installer.iss`.
- Cho đúng **Ed25519 chuẩn RFC 8032**, nên Cloudflare Worker verify được bằng
  `crypto.subtle` và app admin ký được bằng cùng mã nguồn.
- Kèm sẵn **Argon2i** + **XChaCha20-Poly1305** để mã hoá khoá ký của admin bằng
  mật khẩu — không phải tìm thư viện thứ hai.

Repo đã có tiền lệ nhúng thư viện một file: `src/backend/qrcodegen.{cpp,hpp}`.

## Các hàm được dùng

| Hàm | Dùng ở đâu |
| --- | --- |
| `crypto_ed25519_check` | **BOOTHME** — xác minh chữ ký license |
| `crypto_ed25519_sign` | **BOOTHME_ADMIN** — ký license |
| `crypto_ed25519_key_pair` | **BOOTHME_ADMIN** — sinh cặp khoá |
| `crypto_argon2` | **BOOTHME_ADMIN** — dẫn xuất khoá từ mật khẩu |
| `crypto_aead_lock` / `crypto_aead_unlock` | **BOOTHME_ADMIN** — mã hoá tệp khoá ký |
| `crypto_wipe` | Cả hai — xoá vùng nhớ nhạy cảm |

App booth **chỉ** dùng `crypto_ed25519_check`: nó xác minh chứ không bao giờ ký,
nên khoá ký private không cần và không được có mặt trong bản build khách hàng.

## Lưu ý biên dịch

`project()` ở `CMakeLists.txt:2` đã được bổ sung ngôn ngữ `C` (trước đây chỉ có
`CXX`) để MSVC biên dịch được bốn file này ở chế độ C99. Không sửa nội dung file
gốc — nâng cấp bằng cách tải lại đúng quy trình trên rồi cập nhật mã băm.
