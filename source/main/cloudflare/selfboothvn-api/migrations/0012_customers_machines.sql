-- Machine name chosen by the studio in the web admin. The desktop app reports its own
-- config name in device_name on every login; display_name is never overwritten by it.
ALTER TABLE machines ADD COLUMN display_name TEXT NOT NULL DEFAULT '';

-- Guests who book online. They sign in with their phone number only (studio's choice);
-- sessions last 24 hours, then the phone number is asked again.
CREATE TABLE IF NOT EXISTS studio_customers (
  id            TEXT PRIMARY KEY,
  studio_id     TEXT NOT NULL REFERENCES studios(id),
  name          TEXT NOT NULL,
  phone         TEXT NOT NULL,
  created_at    TEXT NOT NULL,
  last_login_at TEXT
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_studio_customers_phone ON studio_customers(studio_id, phone);

CREATE TABLE IF NOT EXISTS customer_sessions (
  token_hash  TEXT PRIMARY KEY,
  customer_id TEXT NOT NULL REFERENCES studio_customers(id),
  studio_id   TEXT NOT NULL REFERENCES studios(id),
  created_at  TEXT NOT NULL,
  expires_at  TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_customer_sessions_customer ON customer_sessions(customer_id);

-- Phone-only sign-in is guessable: failed attempts are counted per IP and throttled.
CREATE TABLE IF NOT EXISTS customer_login_attempts (
  ip           TEXT NOT NULL,
  attempted_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_customer_login_attempts_ip ON customer_login_attempts(ip, attempted_at);

-- A booking belongs to a customer account; once staff confirm it, code_id points at the
-- single-use 4-digit package code the guest types at the booth.
ALTER TABLE studio_bookings ADD COLUMN customer_id TEXT;
ALTER TABLE studio_bookings ADD COLUMN code_id TEXT;
CREATE INDEX IF NOT EXISTS idx_studio_bookings_customer ON studio_bookings(customer_id, booking_date);
CREATE INDEX IF NOT EXISTS idx_studio_bookings_code ON studio_bookings(code_id);
