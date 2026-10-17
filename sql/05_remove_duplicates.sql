-- =============================================================
-- Remove duplicate rows from the overlapping source sheets
-- =============================================================

-- The two Excel sheets both cover 2010-12-01 to 2010-12-09.
-- 04_data_quality.sql confirmed the copies are identical
-- (22,523 rows, 1,088 invoices, 377,488.45 total in each).
--
-- Keeping sheet 2's copy: those nine days sit inside a full
-- year of data there, rather than at the truncated edge of sheet 1.

DELETE FROM transactions
WHERE sourcesheet = '2009_2010'
  AND InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10';
-- Expect: 22,523 rows deleted.


-- Verify: total should be 1,044,846 (1,067,369 - 22,523)
SELECT COUNT(*) AS total_rows FROM transactions;


-- Verify: only sheet 2 should now appear in the overlap window
SELECT 
	sourcesheet, 
	COUNT(*) AS row_count
FROM transactions
WHERE InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10'
GROUP BY sourcesheet;