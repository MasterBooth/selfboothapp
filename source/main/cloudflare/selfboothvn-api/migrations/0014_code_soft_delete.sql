-- Codes deleted from the web admin are hidden, not removed: package_code_uses
-- (revenue) and studio_bookings still point at them.
ALTER TABLE package_codes ADD COLUMN deleted_at TEXT;
