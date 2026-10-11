-- Print Station queue: guest web creates jobs, authenticated desktop machines claim
-- and report final print status. Studio scope always comes from gallery/machine auth.

CREATE TABLE IF NOT EXISTS print_jobs (
  id                 TEXT PRIMARY KEY,
  studio_id          TEXT NOT NULL REFERENCES studios(id),
  machine_id         TEXT REFERENCES machines(id),
  session_machine_id TEXT NOT NULL REFERENCES machines(id),
  session_id         TEXT NOT NULL,
  gallery_token      TEXT NOT NULL,
  object_key         TEXT NOT NULL,
  file_name          TEXT NOT NULL DEFAULT '',
  content_type       TEXT NOT NULL,
  size_bytes         INTEGER NOT NULL DEFAULT 0,
  status             TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'claimed', 'printing', 'printed', 'failed', 'cancelled')),
  copies             INTEGER NOT NULL DEFAULT 1,
  orientation        TEXT NOT NULL DEFAULT 'auto'
    CHECK (orientation IN ('auto', 'portrait', 'landscape')),
  printer_name       TEXT NOT NULL DEFAULT '',
  requested_at       TEXT NOT NULL,
  claimed_at         TEXT,
  printed_at         TEXT,
  failed_at          TEXT,
  error_code         TEXT NOT NULL DEFAULT '',
  error_message      TEXT NOT NULL DEFAULT ''
);

CREATE INDEX IF NOT EXISTS idx_print_jobs_studio_status_time
  ON print_jobs(studio_id, status, requested_at);
CREATE INDEX IF NOT EXISTS idx_print_jobs_machine_time
  ON print_jobs(machine_id, requested_at);
CREATE INDEX IF NOT EXISTS idx_print_jobs_session
  ON print_jobs(session_machine_id, session_id, requested_at);
