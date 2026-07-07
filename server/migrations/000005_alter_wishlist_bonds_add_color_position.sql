-- Color is now per wishlist-bond entry (user can assign a color per bond per wishlist).
-- Position controls the display order of bonds within a wishlist (frontend can reorder).
ALTER TABLE wishlist_bonds
    ADD COLUMN IF NOT EXISTS color    VARCHAR(7),
    ADD COLUMN IF NOT EXISTS position INT NOT NULL DEFAULT 0;
