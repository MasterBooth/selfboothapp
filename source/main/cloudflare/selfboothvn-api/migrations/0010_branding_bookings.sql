-- Studio branding for the guest pages and the admin: name, logo and the three colours
-- the whole palette is derived from. Empty colour = keep the built-in theme.
CREATE TABLE IF NOT EXISTS studio_branding (
  studio_id       TEXT PRIMARY KEY REFERENCES studios(id),
  brand_name      TEXT NOT NULL DEFAULT '',
  logo_object_key TEXT,
  bg_color        TEXT NOT NULL DEFAULT '',
  text_color      TEXT NOT NULL DEFAULT '',
  accent_color    TEXT NOT NULL DEFAULT '',
  updated_at      TEXT NOT NULL
);

-- Bookings made on the public booking page (or by staff in the admin).
-- Date and minutes are studio local time (Asia/Ho_Chi_Minh).
CREATE TABLE IF NOT EXISTS studio_bookings (
  id             TEXT PRIMARY KEY,
  studio_id      TEXT NOT NULL REFERENCES studios(id),
  code           TEXT NOT NULL,
  room_id        TEXT NOT NULL,
  package_id     TEXT,
  booking_date   TEXT NOT NULL,
  start_minute   INTEGER NOT NULL CHECK (start_minute >= 0 AND start_minute < 1440),
  end_minute     INTEGER NOT NULL CHECK (end_minute > start_minute AND end_minute <= 1440),
  customer_name  TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  note           TEXT NOT NULL DEFAULT '',
  price_vnd      INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'done', 'cancelled')),
  source         TEXT NOT NULL DEFAULT 'web' CHECK (source IN ('web', 'admin')),
  created_at     TEXT NOT NULL,
  updated_at     TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_studio_bookings_day ON studio_bookings(studio_id, booking_date, room_id, status);
CREATE UNIQUE INDEX IF NOT EXISTS idx_studio_bookings_code ON studio_bookings(studio_id, code);

CREATE TABLE IF NOT EXISTS studio_booking_settings (
  studio_id    TEXT PRIMARY KEY REFERENCES studios(id),
  enabled      INTEGER NOT NULL DEFAULT 1,
  open_minute  INTEGER NOT NULL DEFAULT 540,
  close_minute INTEGER NOT NULL DEFAULT 1260,
  slot_minutes INTEGER NOT NULL DEFAULT 30,
  days_ahead   INTEGER NOT NULL DEFAULT 30,
  notice       TEXT NOT NULL DEFAULT '',
  updated_at   TEXT NOT NULL
);
