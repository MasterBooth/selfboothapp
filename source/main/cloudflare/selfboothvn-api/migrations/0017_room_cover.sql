-- Cover photo of each studio room, shown on the guest booking page.
-- cover_object_key: the file the admin uploaded, kept as is.
-- cover_display_key: the copy guests load (long side ≈1600 px, made by the admin's browser),
-- so a phone does not download a multi-megabyte camera file per room.
ALTER TABLE studio_rooms ADD COLUMN cover_object_key TEXT;
ALTER TABLE studio_rooms ADD COLUMN cover_display_key TEXT;
