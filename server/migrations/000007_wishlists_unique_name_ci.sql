-- Unique wishlist names, case-insensitive (e.g. "top bonds" == "Top Bonds")

-- 1. Unique index on the lower-cased name so the DB enforces the constraint.
CREATE UNIQUE INDEX IF NOT EXISTS wishlists_name_lower_idx
    ON wishlists (lower(name));

-- 2. Helper function: raise an error when a duplicate (case-insensitive) name
--    is about to be inserted or updated.
CREATE OR REPLACE FUNCTION wishlists_check_name_unique()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM   wishlists
        WHERE  lower(name) = lower(NEW.name)
          AND  id <> NEW.id          -- exclude the row being updated
    ) THEN
        RAISE EXCEPTION
            'A wishlist named "%" already exists (names are case-insensitive).',
            NEW.name
            USING ERRCODE = 'unique_violation';
    END IF;
    RETURN NEW;
END;
$$;

-- 3. Trigger that fires the function before every INSERT or UPDATE.
DROP TRIGGER IF EXISTS trg_wishlists_unique_name ON wishlists;

CREATE TRIGGER trg_wishlists_unique_name
    BEFORE INSERT OR UPDATE OF name ON wishlists
    FOR EACH ROW
    EXECUTE FUNCTION wishlists_check_name_unique();
