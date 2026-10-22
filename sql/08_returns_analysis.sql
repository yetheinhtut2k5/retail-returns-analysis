-- =============================================================
-- Returns analysis
-- Online Retail II — what returns cost the business, and why
-- =============================================================


-- 1. Do the two return signals agree?
-- Returns can be spotted two ways: a 'C' invoice prefix, or a
-- negative quantity. If they disagree, the definition matters.
SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN Invoice LIKE 'C%' AND Quantity <  0 THEN 1 ELSE 0 END) AS c_and_negative,
    SUM(CASE WHEN Invoice LIKE 'C%' AND Quantity >= 0 THEN 1 ELSE 0 END) AS c_but_not_negative,
    SUM(CASE WHEN Invoice NOT LIKE 'C%' AND Quantity < 0 THEN 1 ELSE 0 END) AS negative_but_not_c
FROM transactions;
-- Result: 19,164 agree | 1 C invoice not negative | 3,393 negative
-- without a C prefix. The two signals are not interchangeable.


-- 2. What are the 3,393 non-C negatives?
SELECT TOP 30 Invoice, StockCode, Description, Quantity, Price, CustomerID
FROM transactions
WHERE Invoice NOT LIKE 'C%' AND Quantity < 0;
-- Descriptions include "lost", "damages", "wet", "sold as gold",
-- "invcd as 84879?" — warehouse notes, not customer returns.


-- 3. Confirming the write-off signature across all 3,393
SELECT
    COUNT(*) AS total,
    SUM(CASE WHEN Price = 0 THEN 1 ELSE 0 END)          AS zero_price,
    SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS no_customer
FROM transactions
WHERE Invoice NOT LIKE 'C%' AND Quantity < 0;
-- Result: 3,393 / 3,393 / 3,393. Every one carries zero price and
-- no customer ID — stock write-offs, not customer returns.
--
-- DEFINITION ADOPTED: a return is an invoice beginning with 'C'.
-- Using Quantity < 0 instead would overstate returns by 18%.


-- 4. The single C invoice with positive quantity
SELECT * FROM transactions
WHERE Invoice LIKE 'C%' AND Quantity >= 0;
-- Result: C496350, StockCode 'M' ("Manual"), £373.57, no customer.
-- A hand-keyed accounting credit. One row; left as is.


-- 5. Non-product stock codes
-- The table is a ledger of invoice lines, not a product catalogue:
-- postage, discounts, fees and adjustments all appear as rows.
SELECT StockCode, Description, COUNT(*) AS row_count
FROM transactions
WHERE StockCode NOT LIKE '[0-9][0-9][0-9][0-9][0-9]%'
GROUP BY StockCode, Description
ORDER BY COUNT(*) DESC;
-- Excluded: POST, DOT, C2, C3, D, S, M, B, CRUK, BANK CHARGES,
-- ADJUST, ADJUST2, AMAZONFEE, TEST001 ("This is a test product").
-- NOT excluded: the DCGS* codes are real house-brand products and
-- PADS is a genuine item — a pattern filter would have dropped both.


-- =============================================================
-- 6. Headline: how much is returned?
-- =============================================================

-- Returns carry negative quantity, so their value sums negative;
-- ABS() flips it for reporting. Non-product lines are excluded so
-- the rate reflects merchandise only.
WITH totals AS (
    SELECT
        SUM(CASE WHEN Invoice NOT LIKE 'C%' THEN Quantity * Price ELSE 0 END) AS gross_sales,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity * Price ELSE 0 END)) AS returned_value
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
)
SELECT
    gross_sales,
    returned_value,
    gross_sales - returned_value AS net_sales,
    CAST(100.0 * returned_value / gross_sales AS decimal(5,2)) AS return_rate_pct
FROM totals;
-- Result: £19,702,711.61 gross | £719,762.50 returned | 3.65%.


-- =============================================================
-- 7. Is that rate steady?
-- =============================================================

-- An average hides everything. Same calculation by month.
WITH totals AS (
    SELECT
        DATEFROMPARTS(YEAR(InvoiceDateTime), MONTH(InvoiceDateTime), 1) AS month,
        SUM(CASE WHEN Invoice NOT LIKE 'C%' THEN Quantity * Price ELSE 0 END) AS gross_sales,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity * Price ELSE 0 END)) AS returned_value
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
    GROUP BY DATEFROMPARTS(YEAR(InvoiceDateTime), MONTH(InvoiceDateTime), 1)
)
SELECT
    month,
    gross_sales,
    returned_value,
    gross_sales - returned_value AS net_sales,
    CAST(100.0 * returned_value / gross_sales AS decimal(5,2)) AS return_rate_pct
FROM totals
ORDER BY month;
-- Result: most months sit between 1.2% and 3%. Two outliers:
-- January 2011 at 13.62% and December 2011 at 28.29%.


-- =============================================================
-- 8. Investigating the January 2011 spike
-- =============================================================

SELECT TOP 20
    StockCode, Description,
    SUM(Quantity) AS units_returned,
    ABS(SUM(Quantity * Price)) AS value_returned
FROM transactions
WHERE Invoice LIKE 'C%'
  AND InvoiceDateTime >= '2011-01-01'
  AND InvoiceDateTime <  '2011-02-01'
  AND StockCode NOT IN
      ('POST','DOT','C2','C3','D','S','M','B','CRUK',
       'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
GROUP BY StockCode, Description
ORDER BY value_returned DESC;
-- Result: StockCode 23166 (MEDIUM CERAMIC TOP STORAGE JAR) accounts
-- for 84% of the month — 74,215 units, £77,183.60. The next largest
-- return that month is £1,058.


-- 9. Is that return genuine?
-- 74,215 units is three orders of magnitude above every other
-- transaction for this product.
SELECT Invoice, InvoiceDateTime, Quantity, Price, CustomerID, Country
FROM transactions
WHERE StockCode = '23166'
ORDER BY ABS(Quantity) DESC;
-- Result:
--   541431   2011-01-18 10:01   +74,215   customer 12346
--   C541433  2011-01-18 10:17   -74,215   customer 12346
-- Sixteen minutes apart. Nothing ships and comes back in that time:
-- this is an order keyed in and immediately cancelled. Every other
-- transaction for this product is between 48 and 288 units.


-- =============================================================
-- 10. Investigating the December 2011 spike
-- =============================================================

-- Note: December 2011 is a partial month — the data ends on the 9th.
SELECT TOP 20
    StockCode, Description,
    SUM(Quantity) AS units_returned,
    ABS(SUM(Quantity * Price)) AS value_returned
FROM transactions
WHERE Invoice LIKE 'C%'
  AND InvoiceDateTime >= '2011-12-01'
  AND StockCode NOT IN
      ('POST','DOT','C2','C3','D','S','M','B','CRUK',
       'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
GROUP BY StockCode, Description
ORDER BY value_returned DESC;
-- Result: StockCode 23843 dominates the month.


-- 11. Same pattern?
SELECT Invoice, InvoiceDateTime, Quantity, Price, CustomerID, Country
FROM transactions
WHERE StockCode = '23843'
ORDER BY ABS(Quantity) DESC;
-- Result:
--   581483   2011-12-09 09:15   +80,995   customer 16446
--   C581484  2011-12-09 09:27   -80,995   customer 16446
-- Twelve minutes apart, £168,469.60 — 97% of December's returns.
-- Identical signature to the January case.


-- =============================================================
-- 12. Are there others? Checking systematically
-- =============================================================

-- Two found by eye is not a finding until it's been checked
-- properly. Matching every credit back to a sale of the same
-- product, same customer, same quantity, reversed within an hour.
SELECT
    r.Invoice AS credit_invoice,
    s.Invoice AS sale_invoice,
    r.StockCode,
    r.CustomerID,
    ABS(r.Quantity) AS units,
    DATEDIFF(MINUTE, s.InvoiceDateTime, r.InvoiceDateTime) AS minutes_apart,
    ABS(r.Quantity * r.Price) AS value_returned
FROM transactions r
JOIN transactions s
  ON  s.StockCode  = r.StockCode
  AND s.CustomerID = r.CustomerID
  AND s.Quantity   = -r.Quantity
  AND s.Invoice NOT LIKE 'C%'
  AND s.InvoiceDateTime <= r.InvoiceDateTime
  AND DATEDIFF(MINUTE, s.InvoiceDateTime, r.InvoiceDateTime) <= 60
WHERE r.Invoice LIKE 'C%'
ORDER BY value_returned DESC;


-- =============================================================
-- 13. Corrected monthly return rate
-- =============================================================

-- Both sides of each cancellation are removed, not just the credit:
-- the phantom sale would otherwise stay in the denominator.
WITH totals AS (
    SELECT
        DATEFROMPARTS(YEAR(InvoiceDateTime), MONTH(InvoiceDateTime), 1) AS month,
        SUM(CASE WHEN Invoice NOT LIKE 'C%' THEN Quantity * Price ELSE 0 END) AS gross_sales,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity * Price ELSE 0 END)) AS returned_value
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
      AND Invoice NOT IN ('541431','C541433','581483','C581484')
    GROUP BY DATEFROMPARTS(YEAR(InvoiceDateTime), MONTH(InvoiceDateTime), 1)
)
SELECT
    month,
    gross_sales,
    returned_value,
    gross_sales - returned_value AS net_sales,
    CAST(100.0 * returned_value / gross_sales AS decimal(5,2)) AS return_rate_pct
FROM totals
ORDER BY month;
-- Result: January 2011 corrects to 2.41%. 
-- LIMITATION: this divides each month's returns by that month's
-- sales, but a return always relates to an earlier sale. The rate
-- is therefore approximate at month level, and December 2011 is
-- further distorted by being a partial month (data ends on the 9th).