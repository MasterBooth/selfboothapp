-- Web admin sessions. Browser sessions are separate from desktop machine tokens.
-- Only token hashes are stored; the raw cookie value is never persisted.
CREATE TABLE web_sessions (
  token_hash  TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES studio_users(id),
  studio_id   TEXT NOT NULL REFERENCES studios(id),
  created_at  TEXT NOT NULL,
  expires_at  TEXT NOT NULL,
  revoked_at  TEXT
);

CREATE INDEX idx_web_sessions_user ON web_sessions(user_id, revoked_at);
CREATE INDEX idx_web_sessions_studio ON web_sessions(studio_id, revoked_at);
CREATE INDEX idx_web_sessions_expires ON web_sessions(expires_at);
