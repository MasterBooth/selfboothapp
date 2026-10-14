-- Framing the admin chose for the room cover: JSON {"x","y","w","h"}, fractions of the
-- original photo. The guest copy (cover_display_key) is that region at 3:2; keeping the
-- numbers lets the admin reopen the editor where they left it, on the untouched original.
ALTER TABLE studio_rooms ADD COLUMN cover_crop TEXT;
