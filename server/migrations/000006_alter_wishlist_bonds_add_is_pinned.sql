-- Pinned bonds always appear first within a wishlist regardless of sort mode.
ALTER TABLE wishlist_bonds
    ADD COLUMN IF NOT EXISTS is_pinned BOOLEAN NOT NULL DEFAULT FALSE;

-- Index to make the ORDER BY is_pinned DESC, ... queries fast.
CREATE INDEX IF NOT EXISTS idx_wishlist_bonds_is_pinned
    ON wishlist_bonds (wishlist_id, is_pinned DESC);
