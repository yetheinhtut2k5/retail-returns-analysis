-- =============================================================
-- Trim whitespace from product descriptions
-- =============================================================

-- 2,571 rows across 37 products carry leading or trailing spaces
-- (e.g. " WHITE CHERRY LIGHTS"). SQL treats these as different
-- strings, so one product splits into two groups when aggregating
-- and totals come out wrong.
--
-- The WHERE clause isn't strictly required — TRIM leaves clean
-- values unchanged — but it limits the update to the 2,571 affected
-- rows rather than rewriting all 1,044,848.

UPDATE transactions
SET Description = TRIM(Description)
WHERE Description <> TRIM(Description);
-- Result: 2571 rows updated


-- Verify: should return zero
SELECT 
	COUNT(*) AS rows_still_untrimmed
FROM transactions
WHERE Description <> TRIM(Description);
-- Result: 0