-- Support desktop-local package codes in the web revenue view.
ALTER TABLE package_code_uses ADD COLUMN package_name TEXT NOT NULL DEFAULT '';
ALTER TABLE package_code_uses ADD COLUMN room_name TEXT NOT NULL DEFAULT '';
ALTER TABLE revenue_records ADD COLUMN code_use_id TEXT;
