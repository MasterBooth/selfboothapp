-- Durable per-photo upload contract for desktop -> R2 -> gallery/admin.
-- Asset rows are prepared before upload and become visible to gallery only after commit.

CREATE TABLE IF NOT EXISTS session_assets (
  asset_id         TEXT NOT NULL,
  machine_id       TEXT NOT NULL REFERENCES machines(id),
  session_id       TEXT NOT NULL,
  studio_id        TEXT NOT NULL REFERENCES studios(id),
  object_key       TEXT NOT NULL UNIQUE,
  kind             TEXT NOT NULL CHECK (kind IN ('photo', 'collage', 'video', 'manifest', 'thumbnail', 'preview', 'other')),
  file_name        TEXT NOT NULL DEFAULT '',
  content_type     TEXT NOT NULL,
  size_bytes       INTEGER NOT NULL,
  checksum_sha256  TEXT NOT NULL DEFAULT '',
  photo_index      INTEGER NOT NULL DEFAULT 0,
  status           TEXT NOT NULL DEFAULT 'prepared' CHECK (status IN ('prepared', 'uploaded', 'committed', 'failed')),
  upload_expires_at TEXT,
  uploaded_size_bytes INTEGER,
  r2_checksum_sha256 TEXT NOT NULL DEFAULT '',
  uploaded_at      TEXT,
  committed_at     TEXT,
  error_code       TEXT NOT NULL DEFAULT '',
  created_at       TEXT NOT NULL,
  updated_at       TEXT NOT NULL,
  PRIMARY KEY (machine_id, session_id, asset_id),
  FOREIGN KEY (machine_id, session_id) REFERENCES capture_sessions(machine_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_session_assets_studio_session
  ON session_assets(studio_id, machine_id, session_id, status, photo_index);
CREATE INDEX IF NOT EXISTS idx_session_assets_studio_time
  ON session_assets(studio_id, committed_at);
CREATE INDEX IF NOT EXISTS idx_session_assets_status
  ON session_assets(status, updated_at);

CREATE TABLE IF NOT EXISTS session_expected_assets (
  machine_id   TEXT NOT NULL,
  session_id   TEXT NOT NULL,
  asset_id     TEXT NOT NULL,
  studio_id    TEXT NOT NULL REFERENCES studios(id),
  expected_at  TEXT NOT NULL,
  PRIMARY KEY (machine_id, session_id, asset_id),
  FOREIGN KEY (machine_id, session_id) REFERENCES capture_sessions(machine_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_session_expected_assets_studio_session
  ON session_expected_assets(studio_id, machine_id, session_id);

ALTER TABLE capture_sessions ADD COLUMN expected_asset_ids TEXT NOT NULL DEFAULT '[]';
ALTER TABLE capture_sessions ADD COLUMN asset_sync_status TEXT NOT NULL DEFAULT 'unknown';
ALTER TABLE capture_sessions ADD COLUMN finalized_at TEXT;
ALTER TABLE capture_sessions ADD COLUMN gallery_token TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_capture_sessions_gallery_token
  ON capture_sessions(gallery_token);
CREATE INDEX IF NOT EXISTS idx_capture_sessions_studio_sync
  ON capture_sessions(studio_id, asset_sync_status, updated_at);
