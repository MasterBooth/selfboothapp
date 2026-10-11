-- Thumbnail of each frame (≈720 px long side, WebP, transparency kept) for the guest's
-- frame picker grid: a phone decodes a dozen of them without stutter. The preview
-- (≈1600 px) stays the editor's screen copy; the full-size PNG stays the print source.
ALTER TABLE studio_frames ADD COLUMN thumb_object_key TEXT;
