-- Small preview of each frame PNG (≈1600 px long side, transparency kept) for guest
-- screens. The full-size PNG (often 4–5 MB, 4419×6250) stays the print source.
ALTER TABLE studio_frames ADD COLUMN preview_object_key TEXT;
