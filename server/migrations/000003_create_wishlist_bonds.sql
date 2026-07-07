CREATE TABLE IF NOT EXISTS wishlist_bonds (
    wishlist_id UUID         NOT NULL REFERENCES wishlists(id),
    bond_isin   VARCHAR(12)  NOT NULL REFERENCES bonds(isin),
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),

    PRIMARY KEY (wishlist_id, bond_isin)
);

-- Index for fast lookup of bonds by wishlist ordered by insertion time.
CREATE INDEX IF NOT EXISTS idx_wishlist_bonds_wishlist_id_created_at
    ON wishlist_bonds (wishlist_id, created_at DESC);
