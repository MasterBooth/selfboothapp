-- Giấy phép máy ký số + mã kích hoạt OTP 4 số.
--
-- Worker KHÔNG giữ khoá ký: token license / phiếu thu hồi do app BOOTHME_ADMIN ký,
-- Worker chỉ xác minh chữ ký (LICENSE_PUBLIC_KEYS) rồi lưu và phát lại. Máy booth
-- tự xác minh lần nữa bằng khoá công khai biên dịch cứng, nên lộ D1 cũng không tạo
-- được giấy phép giả hay khoá được máy.

-- Máy đang chờ cấp phép (máy tự gửi sau khi đăng nhập studio).
CREATE TABLE IF NOT EXISTS license_requests (
  hwid          TEXT PRIMARY KEY,
  machine_id    TEXT NOT NULL REFERENCES machines(id),
  studio_id     TEXT REFERENCES studios(id),
  requested_at  TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

-- Mọi token đã cấp. Mỗi hwid có tối đa 1 bản 'active'.
CREATE TABLE IF NOT EXISTS licenses (
  serial       TEXT PRIMARY KEY,
  hwid         TEXT NOT NULL,
  machine_id   TEXT REFERENCES machines(id),
  token        TEXT NOT NULL,
  device_tier  TEXT NOT NULL DEFAULT '',
  not_after    TEXT,                               -- NULL = vô thời hạn
  issued_at    TEXT NOT NULL,
  status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'superseded', 'revoked')),
  approver     TEXT NOT NULL DEFAULT '',
  created_at   TEXT NOT NULL,
  revoked_at   TEXT
);
CREATE INDEX IF NOT EXISTS idx_licenses_hwid_status ON licenses(hwid, status);
CREATE UNIQUE INDEX IF NOT EXISTS uq_licenses_active_hwid ON licenses(hwid) WHERE status = 'active';

-- Phiếu thu hồi đã ký. KHÔNG BAO GIỜ xoá (kể cả khi xoá máy): máy offline lâu
-- ngày quay lại vẫn phải nhận được phiếu.
CREATE TABLE IF NOT EXISTS license_revocations (
  serial      TEXT PRIMARY KEY,
  hwid        TEXT NOT NULL,
  token       TEXT NOT NULL,
  created_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_license_revocations_hwid ON license_revocations(hwid);

-- Mã kích hoạt 4 số: gắn hwid, hạn 24 giờ, dùng 1 lần, sai 5 lần thì khoá.
CREATE TABLE IF NOT EXISTS license_otps (
  id          TEXT PRIMARY KEY,
  hwid        TEXT NOT NULL,
  serial      TEXT NOT NULL REFERENCES licenses(serial),
  code        TEXT NOT NULL CHECK (length(code) = 4 AND code GLOB '[0-9][0-9][0-9][0-9]'),
  expires_at  TEXT NOT NULL,
  attempts    INTEGER NOT NULL DEFAULT 0,
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'locked', 'cancelled')),
  created_at  TEXT NOT NULL,
  used_at     TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_license_otps_active_hwid ON license_otps(hwid) WHERE status = 'active';
