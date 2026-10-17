-- =============================================================
-- Normalise missing customer IDs
-- =============================================================

-- Blank CSV fields loaded as empty strings rather than NULLs,
-- which hid them from IS NULL checks. An absent customer ID means
-- the sale wasn't tied to an account — the transaction is real, so
-- the rows are kept, but the value is unknown and NULL says so.

UPDATE transactions
SET CustomerID = NULL
WHERE CustomerID = '';
-- Expect: [row count from the query above]

-- Verify: IS NULL should now return the same figure
SELECT COUNT(*) AS missing_customer
FROM transactions
WHERE CustomerID IS NULL;