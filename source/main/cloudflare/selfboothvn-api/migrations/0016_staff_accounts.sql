-- Staff accounts of a studio. A staff member is a studio_users row with role 'staff', so
-- web_sessions, password hashing and the login lockout work unchanged.
--
-- Staff sign in at /staff with a username unique within their studio. studio_users.email
-- stays NOT NULL UNIQUE: for staff it holds the internal login key
-- 'staff:<studio_id>:<username>' (never shown; also the login_attempts key).
-- permissions: JSON array of action codes (see src/permissions.ts); owners have them all.
ALTER TABLE studio_users ADD COLUMN username TEXT;
ALTER TABLE studio_users ADD COLUMN display_name TEXT NOT NULL DEFAULT '';
ALTER TABLE studio_users ADD COLUMN permissions TEXT NOT NULL DEFAULT '[]';
ALTER TABLE studio_users ADD COLUMN created_by TEXT;
ALTER TABLE studio_users ADD COLUMN updated_at TEXT;
ALTER TABLE studio_users ADD COLUMN deleted_at TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_studio_users_username
  ON studio_users(studio_id, username) WHERE username IS NOT NULL;
