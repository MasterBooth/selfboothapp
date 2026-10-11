-- Studio frame library. Frames are transparent PNG overlays stored in R2; slots
-- are detected from transparent punched holes client-side and stored as
-- normalized rectangles for future composition.

CREATE TABLE IF NOT EXISTS studio_frames (
  id           TEXT PRIMARY KEY,
  studio_id    TEXT NOT NULL REFERENCES studios(id),
  name         TEXT NOT NULL,
  object_key   TEXT NOT NULL UNIQUE,
  content_type TEXT NOT NULL DEFAULT 'image/png',
  size_bytes   INTEGER NOT NULL DEFAULT 0,
  width        INTEGER NOT NULL DEFAULT 0,
  height       INTEGER NOT NULL DEFAULT 0,
  slots_json   TEXT NOT NULL DEFAULT '[]',
  slot_count   INTEGER NOT NULL DEFAULT 0,
  status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at   TEXT NOT NULL,
  updated_at   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_studio_frames_studio_status
  ON studio_frames(studio_id, status, created_at);
