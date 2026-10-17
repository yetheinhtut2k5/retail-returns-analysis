-- =============================================================
-- Remove duplicate rows from the overlapping source sheets
-- =============================================================

-- The two source sheets both cover 2010-12-01 to 2010-12-09.
-- 04_data_quality.sql confirmed the copies are identical:
-- 22,523 rows, 1,088 invoices, 377,488.45 total in each.
--
-- Sheet 2's copy is kept — those nine days sit inside a full year
-- of data there, rather than at the truncated edge of sheet 1.

DELETE FROM transactions
WHERE sourcesheet = '2009_2010'
  AND InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10';
-- Result: 22,523 rows deleted.


-- Verify: 1,067,371 - 22,523 = 1,044,848
SELECT COUNT(*) AS total_rows FROM transactions;
-- Result: 1,044,848.


-- Verify: only sheet 2 should remain in the overlap window
SELECT
    sourcesheet,
    COUNT(*) AS row_count
FROM transactions
WHERE InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10'
GROUP BY sourcesheet;
-- Result: 2010_2011 only, 22,523 rows.