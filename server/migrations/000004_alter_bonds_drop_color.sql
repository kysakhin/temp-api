-- Color is now managed at the wishlist_bond level, not the bond level.
ALTER TABLE bonds DROP COLUMN IF EXISTS color;
