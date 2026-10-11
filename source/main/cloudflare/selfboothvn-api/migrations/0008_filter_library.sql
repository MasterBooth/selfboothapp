-- Studio colour-filter library. Each filter is a 3D LUT (.cube) plus a small
-- thumbnail, both stored in R2. Column names match the desktop FilterSyncManager
-- job payload (cube_object_key / thumbnail_object_key) so booths can sync later.

CREATE TABLE IF NOT EXISTS studio_filters (
  id                   TEXT PRIMARY KEY,
  studio_id            TEXT NOT NULL REFERENCES studios(id),
  name                 TEXT NOT NULL,
  cube_object_key      TEXT NOT NULL UNIQUE,
  cube_size_bytes      INTEGER NOT NULL DEFAULT 0,
  lut_size             INTEGER NOT NULL DEFAULT 0,
  thumbnail_object_key TEXT,
  sort_order           INTEGER NOT NULL DEFAULT 0,
  status               TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
  created_at           TEXT NOT NULL,
  updated_at           TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_studio_filters_studio_status
  ON studio_filters(studio_id, status, sort_order, created_at);
