-- Studio rooms and sellable packages managed from the web admin.
CREATE TABLE studio_rooms (
  id          TEXT PRIMARY KEY,
  studio_id   TEXT NOT NULL REFERENCES studios(id),
  name        TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  capacity    TEXT NOT NULL DEFAULT '',
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX idx_studio_rooms_studio ON studio_rooms(studio_id, status);

CREATE TABLE studio_packages (
  id          TEXT PRIMARY KEY,
  studio_id   TEXT NOT NULL REFERENCES studios(id),
  room_id     TEXT NOT NULL REFERENCES studio_rooms(id),
  name        TEXT NOT NULL,
  minutes     INTEGER NOT NULL CHECK (minutes > 0),
  price_vnd   INTEGER NOT NULL DEFAULT 0 CHECK (price_vnd >= 0),
  description TEXT NOT NULL DEFAULT '',
  status      TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
CREATE INDEX idx_studio_packages_room ON studio_packages(studio_id, room_id, status);

ALTER TABLE package_codes ADD COLUMN room_id TEXT;
ALTER TABLE package_codes ADD COLUMN package_id TEXT;
CREATE INDEX idx_package_codes_package ON package_codes(studio_id, package_id, status);
