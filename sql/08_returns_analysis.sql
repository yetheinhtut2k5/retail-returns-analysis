-- =============================================================
-- Returns analysis — defining what counts as a return
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
-- no customer ID — stock write-offs, not returns.
--
-- DEFINITION ADOPTED: a return is an invoice beginning with 'C'.
-- Using Quantity < 0 instead would overstate customer returns by 18%.


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
-- Non-products: POST, DOT, C2, C3, D, S, M, B, CRUK, BANK CHARGES,
-- ADJUST, ADJUST2, AMAZONFEE, TEST001 ("This is a test product").
-- NOT excluded: the DCGS* codes are real house-brand products, and
-- PADS is a genuine item despite the odd code — a pattern filter
-- alone would have dropped both.