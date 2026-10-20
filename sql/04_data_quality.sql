-- =============================================================
-- Data quality investigation
-- Online Retail II — what's wrong with the data before analysing
-- =============================================================


-- 1. Date coverage by source sheet
-- The dataset ships as two Excel sheets. Checking their ranges
-- revealed a nine-day overlap (1-9 Dec 2010).
SELECT
    sourcesheet,
    MIN(InvoiceDateTime) AS first_transaction,
    MAX(InvoiceDateTime) AS last_transaction
FROM transactions
GROUP BY sourcesheet;
-- Result: sheet 1 runs 2009-12-01 to 2010-12-09,
--         sheet 2 runs 2010-12-01 to 2011-12-09.


-- 2. Size of the overlap
SELECT
    sourcesheet,
    COUNT(*) AS row_count
FROM transactions
WHERE InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10'
GROUP BY sourcesheet;
-- Result: 22,523 rows in each sheet.


-- 3. Confirming the overlap is a true duplicate
-- Matching row counts alone prove nothing — two different sets of
-- 22,523 rows would look the same. Comparing distinct invoices and
-- total value gives two independent fingerprints.
SELECT
    sourcesheet,
    COUNT(DISTINCT Invoice) AS invoice_count,
    SUM(Quantity * Price)   AS total_value
FROM transactions
WHERE InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10'
GROUP BY sourcesheet;
-- Result: 1,088 invoices and 377,488.45 in both.
-- Identical on all three measures — confirmed duplicates.
-- Removed in 05_remove_duplicates.sql.


-- 4. Nulls, negatives and non-positive prices
-- Counting before deciding: a negative quantity is a return, not
-- an error, and deleting rows costs real data.
SELECT
    COUNT(*)                                            AS total_rows,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS missing_customer,
    SUM(CASE WHEN Quantity < 0       THEN 1 ELSE 0 END) AS negative_quantity,
    SUM(CASE WHEN Price <= 0         THEN 1 ELSE 0 END) AS zero_or_negative_price
FROM transactions;
-- Result: 1,044,848 rows | 0 missing customers | 22,557 negative
-- quantities | 6,047 non-positive prices.
-- The zero is wrong. UCI documents a substantial share of rows
-- without a customer ID. Blank CSV fields load as empty strings,
-- not NULLs, so IS NULL never matches them.


-- 5. Locating the missing customer IDs
-- Wrapping the value in brackets makes empty strings visible —
-- '[]' is blank, '[12345]' is a real ID.
SELECT TOP 10
    '[' + CustomerID + ']' AS customer_id,
    COUNT(*)               AS row_count
FROM transactions
GROUP BY CustomerID
ORDER BY COUNT(*) DESC;
-- Result: 235,287 for total


-- 6. How many rows are affected
SELECT
    COUNT(*) AS blank_customer_rows,
    CAST(100.0 * COUNT(*) / (SELECT COUNT(*) FROM transactions)
         AS decimal(5,2)) AS pct_of_total
FROM transactions
WHERE CustomerID = '';
-- Result: 22.52%


--7a. Whitespace in product descriptions
-- Leading or trailing spaces split one product into two groups
-- when aggregating, so totals silently come out wrong.
SELECT 
	COUNT(*)
FROM transactions
WHERE Description <> TRIM(Description)


-- 7b. How many product descriptions are affected, not just rows
SELECT COUNT(DISTINCT TRIM(Description)) AS affected_products
FROM transactions
WHERE Description <> TRIM(Description);