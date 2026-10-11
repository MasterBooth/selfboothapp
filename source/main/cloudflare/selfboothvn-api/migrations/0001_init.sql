-- selfboothvn — schema khởi tạo.
-- Quy ước: id TEXT (UUID v4), thời gian TEXT ISO-8601 UTC ("2026-10-01T08:00:00.000Z"),
-- tiền INTEGER VND, mọi bảng dữ liệu nghiệp vụ có studio_id (tenant).
-- D1 luôn bật kiểm tra khóa ngoại.

-- ── Studio & tài khoản ─────────────────────────────────────────────────────
CREATE TABLE studios (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE TABLE studio_users (
  id             TEXT PRIMARY KEY,
  studio_id      TEXT NOT NULL REFERENCES studios(id),
  email          TEXT NOT NULL UNIQUE,            -- luôn lưu chữ thường, đã trim
  password_hash  TEXT NOT NULL,                   -- pbkdf2_sha256$<iter>$<salt_b64>$<hash_b64>
  role           TEXT NOT NULL DEFAULT 'owner' CHECK (role IN ('owner', 'staff')),
  status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
  created_at     TEXT NOT NULL,
  last_login_at  TEXT
);
CREATE INDEX idx_studio_users_studio ON studio_users(studio_id);

-- Chống dò mật khẩu: khóa 15 phút sau 10 lần sai liên tiếp (theo email).
CREATE TABLE login_attempts (
  email         TEXT PRIMARY KEY,
  fail_count    INTEGER NOT NULL DEFAULT 0,
  locked_until  TEXT,
  updated_at    TEXT NOT NULL
);

-- ── Máy ────────────────────────────────────────────────────────────────────
CREATE TABLE machines (
  id             TEXT PRIMARY KEY,
  hwid           TEXT NOT NULL UNIQUE,
  studio_id      TEXT REFERENCES studios(id),     -- NULL = chưa gắn studio
  device_name    TEXT NOT NULL DEFAULT '',
  app_version    TEXT NOT NULL DEFAULT '',
  status         TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled')),
  first_seen_at  TEXT NOT NULL,
  last_seen_at   TEXT NOT NULL,
  linked_at      TEXT
);
CREATE INDEX idx_machines_studio ON machines(studio_id);

-- Token riêng từng máy, cấp khi studio đăng nhập trên máy. Chỉ lưu SHA-256 (hex).
CREATE TABLE machine_tokens (
  token_hash  TEXT PRIMARY KEY,
  machine_id  TEXT NOT NULL REFERENCES machines(id),
  studio_id   TEXT NOT NULL REFERENCES studios(id),
  user_id     TEXT NOT NULL REFERENCES studio_users(id),
  created_at  TEXT NOT NULL,
  revoked_at  TEXT
);
CREATE INDEX idx_machine_tokens_machine ON machine_tokens(machine_id);

-- ── Phiên chụp & ảnh ───────────────────────────────────────────────────────
CREATE TABLE capture_sessions (
  machine_id       TEXT NOT NULL REFERENCES machines(id),
  session_id       TEXT NOT NULL,                  -- do app sinh: session_YYYYMMDD_HHmmss_XXXX
  studio_id        TEXT NOT NULL REFERENCES studios(id),
  event_id         INTEGER NOT NULL DEFAULT 0,     -- id sự kiện trong DB local của máy
  operation_mode   TEXT NOT NULL DEFAULT '',
  status           TEXT NOT NULL DEFAULT '',
  status_version   INTEGER NOT NULL DEFAULT 0,
  photos_count     INTEGER NOT NULL DEFAULT 0,
  expected_photos  INTEGER NOT NULL DEFAULT 0,
  started_at       TEXT,
  ended_at         TEXT,
  code_use_id      TEXT,                           -- -> package_code_uses.id (nếu vào bằng mã)
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  PRIMARY KEY (machine_id, session_id)
);
CREATE INDEX idx_capture_sessions_studio_time ON capture_sessions(studio_id, started_at);

-- Ghi bởi Worker khi PUT lên R2 thành công (server xác nhận, không tin client).
CREATE TABLE session_photos (
  object_key    TEXT PRIMARY KEY,                  -- studio/<hwid>/<session_id>/...
  studio_id     TEXT NOT NULL REFERENCES studios(id),
  machine_id    TEXT NOT NULL REFERENCES machines(id),
  session_id    TEXT NOT NULL,
  kind          TEXT NOT NULL CHECK (kind IN ('photo', 'manifest', 'collage', 'video', 'other')),
  content_type  TEXT NOT NULL,
  size_bytes    INTEGER NOT NULL,
  uploaded_at   TEXT NOT NULL
);
CREATE INDEX idx_session_photos_session ON session_photos(machine_id, session_id);
CREATE INDEX idx_session_photos_studio_time ON session_photos(studio_id, uploaded_at);

-- ── Mã gói chụp ────────────────────────────────────────────────────────────
CREATE TABLE package_codes (
  id               TEXT PRIMARY KEY,
  studio_id        TEXT NOT NULL REFERENCES studios(id),
  code             TEXT NOT NULL CHECK (length(code) = 4 AND code GLOB '[0-9][0-9][0-9][0-9]'),
  kind             TEXT NOT NULL CHECK (kind IN ('single', 'reusable')),
  minutes          INTEGER NOT NULL CHECK (minutes > 0),
  price_vnd        INTEGER NOT NULL DEFAULT 0 CHECK (price_vnd >= 0),
  status           TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'revoked')),
  valid_from       TEXT,
  valid_until      TEXT,
  note             TEXT NOT NULL DEFAULT '',
  created_at       TEXT NOT NULL,
  used_at          TEXT,
  used_machine_id  TEXT,
  used_session_id  TEXT
);
-- Một mã 4 số chỉ có tối đa một bản ghi đang active trong một studio.
CREATE UNIQUE INDEX uq_package_codes_active ON package_codes(studio_id, code) WHERE status = 'active';
CREATE INDEX idx_package_codes_studio ON package_codes(studio_id, status);

-- Mỗi lần dùng mã. id = use_id do app sinh (UUID) -> gửi lại nhiều lần vẫn chỉ 1 bản ghi.
CREATE TABLE package_code_uses (
  id          TEXT PRIMARY KEY,
  studio_id   TEXT NOT NULL REFERENCES studios(id),
  machine_id  TEXT NOT NULL REFERENCES machines(id),
  code_id     TEXT NOT NULL REFERENCES package_codes(id),
  code        TEXT NOT NULL,
  kind        TEXT NOT NULL,
  session_id  TEXT NOT NULL DEFAULT '',
  minutes     INTEGER NOT NULL,
  price_vnd   INTEGER NOT NULL,
  used_at     TEXT NOT NULL,
  source      TEXT NOT NULL CHECK (source IN ('online', 'offline')),
  created_at  TEXT NOT NULL
);
CREATE INDEX idx_code_uses_studio_time ON package_code_uses(studio_id, used_at);

-- ── Doanh thu ──────────────────────────────────────────────────────────────
-- id = revenue_id do app sinh (sha256 của hwid|eventId|sessionId|source|recorded_at).
CREATE TABLE revenue_records (
  id               TEXT PRIMARY KEY,
  studio_id        TEXT NOT NULL REFERENCES studios(id),
  machine_id       TEXT NOT NULL REFERENCES machines(id),
  session_id       TEXT NOT NULL DEFAULT '',
  event_id         INTEGER NOT NULL DEFAULT 0,
  event_name       TEXT NOT NULL DEFAULT '',
  recorded_at      TEXT NOT NULL,                  -- giờ ghi tại máy
  amount_required  INTEGER NOT NULL DEFAULT 0,
  received_amount  INTEGER NOT NULL DEFAULT 0,
  cash_received    INTEGER NOT NULL DEFAULT 0,
  transfer_amount  INTEGER NOT NULL DEFAULT 0,
  change_amount    INTEGER NOT NULL DEFAULT 0,
  voucher_amount   INTEGER NOT NULL DEFAULT 0,
  print_count      INTEGER NOT NULL DEFAULT 0,
  payment_method   TEXT NOT NULL DEFAULT '',
  source           TEXT NOT NULL DEFAULT 'session',
  note             TEXT NOT NULL DEFAULT '',
  created_at       TEXT NOT NULL                   -- giờ server nhận
);
CREATE INDEX idx_revenue_studio_time ON revenue_records(studio_id, recorded_at);
CREATE INDEX idx_revenue_machine_time ON revenue_records(machine_id, recorded_at);
