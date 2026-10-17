SELECT sourcesheet, 
MIN(InvoiceDateTime), 
MAX(InvoiceDateTime)
FROM transactions 
GROUP BY sourcesheet;


-- =============================================================
-- Data quality investigation
-- Online Retail II — checking what's wrong before analysing
-- =============================================================

-- The two source sheets overlap: sheet 1 runs to 2010-12-09 and
-- sheet 2 starts at 2010-12-01, so nine days appear twice.
-- Step 1: how many rows sit in the overlapping window, per sheet?

SELECT
    sourcesheet,
    COUNT(*) AS row_count
FROM transactions
WHERE InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10'
GROUP BY sourcesheet;
-- Result: 22,523 rows in each sheet.



-- Matching row counts alone don't prove the rows are the same rows.
-- Step 2: compare two independent fingerprints — the number of
-- distinct invoices, and the total value of the window.
SELECT
    sourcesheet,
    COUNT(DISTINCT Invoice) AS invoice_count,
    SUM(Quantity * Price)   AS total_value
FROM transactions
WHERE InvoiceDateTime >= '2010-12-01'
  AND InvoiceDateTime <  '2010-12-10'
GROUP BY sourcesheet;
-- Result: 1,088 invoices and 377,488.45 in both sheets.
-- Identical on all three measures — confirmed duplicates.