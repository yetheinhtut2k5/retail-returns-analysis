-- =============================================================
-- Return drivers — products, orders, customers
-- =============================================================


-- 1. Which products have the highest return rate?
-- Ranking by value returned just finds bestsellers. The useful
-- measure is the rate: returned units as a share of units sold.
--
-- Descriptions vary slightly across rows for the same StockCode,
-- so grouping is on StockCode alone with one picked for display.
--
-- Products below 1,000 units sold are excluded: one that sold 3
-- and had 2 returned is noise, not a 67% return rate.
--
-- units_sold counts only positive non-credit rows. An earlier
-- version summed all non-credit rows, which silently included the
-- stock write-offs as negative sales and inflated every rate.
WITH product_totals AS (
    SELECT
        StockCode,
        MAX(Description) AS description,
        SUM(CASE WHEN Invoice NOT LIKE 'C%' AND Quantity > 0 THEN Quantity ELSE 0 END) AS units_sold,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity ELSE 0 END))                 AS units_returned,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity * Price ELSE 0 END))         AS value_returned
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
      AND Invoice NOT IN ('541431','C541433','581483','C581484')
    GROUP BY StockCode
)
SELECT TOP 25
    StockCode,
    description,
    units_sold,
    units_returned,
    value_returned,
    CAST(100.0 * units_returned / units_sold AS decimal(5,2)) AS return_rate_pct
FROM product_totals
WHERE units_sold >= 1000
ORDER BY return_rate_pct DESC;
-- Result: 23113 (PANTRY CHOPPING BOARD) leads at 81.98% — 946 of
-- 1,154 units, £4,803 returned. Everything below it clusters
-- between 45% and 50%, which is too tight to be 24 separate
-- quality problems. Values are also trivial: the next worst
-- offender returned £45 of boxes.


-- 2. Is the cluster driven by one customer per product?
-- Testing 16043 (POP ART PUSH DOWN RUBBER, 45.87%).
SELECT
    CustomerID,
    SUM(CASE WHEN Invoice NOT LIKE 'C%' AND Quantity > 0 THEN Quantity ELSE 0 END) AS units_bought,
    ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity ELSE 0 END))                 AS units_returned
FROM transactions
WHERE StockCode = '16043'
GROUP BY CustomerID
ORDER BY units_returned DESC;
-- Result: customer 14277 bought 960 and returned all 960. One
-- other customer returned 24 of 48. Every other buyer returned
-- nothing. The "product return rate" is one order being reversed.


-- 3. Same test on the highest-rate product
SELECT
    CustomerID,
    SUM(CASE WHEN Invoice NOT LIKE 'C%' AND Quantity > 0 THEN Quantity ELSE 0 END) AS units_bought,
    ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity ELSE 0 END))                 AS units_returned
FROM transactions
WHERE StockCode = '23113'
GROUP BY CustomerID
ORDER BY units_returned DESC;
-- Result: customer 17450 bought 942 and returned all 942. Every
-- other buyer bought between 1 and 6 units. Same shape.


-- 4. Cancellation or genuine return?
SELECT Invoice, InvoiceDateTime, Quantity, Price
FROM transactions
WHERE StockCode = '23113' AND CustomerID = '17450'
ORDER BY InvoiceDateTime;
-- Result:
--   567377   20 Sep 2011 09:55   +186
--   567423   20 Sep 2011 11:05   +756
--   C567527  21 Sep 2011 09:16   -756   (1 day later)
--   C568832  29 Sep 2011 11:35   -186   (9 days later)
-- Unlike the January and December anomalies — reversed within
-- twenty minutes — these are days apart. Goods were shipped,
-- received and sent back. Two separate orders, both fully returned.


-- =============================================================
-- 5. How much of the returned value is whole orders coming back?
-- =============================================================

-- For each customer-product pair, compare units bought with units
-- returned. Where they match exactly, the customer returned
-- everything they ever bought of that product.
--
-- Rows without a customer ID are excluded — a return can't be
-- paired to a buyer without one.
WITH pair_totals AS (
    SELECT
        CustomerID,
        StockCode,
        SUM(CASE WHEN Invoice NOT LIKE 'C%' AND Quantity > 0 THEN Quantity ELSE 0 END) AS units_bought,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity ELSE 0 END))                 AS units_returned,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%' THEN Quantity * Price ELSE 0 END))         AS value_returned
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
      AND Invoice NOT IN ('541431','C541433','581483','C581484')
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID, StockCode
),
summary AS (
    SELECT
        SUM(value_returned) AS total_returned,
        SUM(CASE WHEN units_returned = units_bought AND units_returned > 0
                 THEN value_returned ELSE 0 END) AS full_reversal_value,
        SUM(CASE WHEN units_returned = units_bought AND units_returned > 0
                 THEN 1 ELSE 0 END)              AS full_reversal_pairs,
        SUM(CASE WHEN units_returned > 0 THEN 1 ELSE 0 END) AS pairs_with_returns
    FROM pair_totals
)
SELECT
    total_returned,
    full_reversal_value,
    full_reversal_pairs,
    pairs_with_returns,
    CAST(100.0 * full_reversal_value / total_returned AS decimal(5,2)) AS pct_of_returned_value
FROM summary;
-- Result: £109,124 of £467,393 — 23.35% — across 3,052 of 15,011
-- customer-product pairs. Significant, but not the main driver:
-- three quarters of returned value is partial returns.
--
-- Note: £467,393 here vs the £719,762 headline in 08. The gap is
-- the two excluded anomalies (£245,654) plus returns with no
-- customer ID (~£6,700).


-- =============================================================
-- 6. Are returns concentrated in a few customers?
-- =============================================================

WITH customer_totals AS (
    SELECT
        CustomerID,
        SUM(CASE WHEN Invoice NOT LIKE 'C%' AND Quantity > 0
                 THEN Quantity * Price ELSE 0 END)  AS value_bought,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%'
                 THEN Quantity * Price ELSE 0 END)) AS value_returned
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
      AND Invoice NOT IN ('541431','C541433','581483','C581484')
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
)
SELECT TOP 25
    CustomerID,
    value_bought,
    value_returned,
    CAST(100.0 * value_returned / value_bought AS decimal(6,2)) AS return_rate_pct
FROM customer_totals
WHERE value_bought >= 1000
ORDER BY value_returned DESC;
-- Result: two distinct groups.
--   Habitual returners — 14277 (76%), 12454 (75%), 15749 (52%)
--   Large accounts with incidental reversals — 14646 (0.67% on
--   £527k), 14156 (1.75% on £303k)
-- Customer 17450, who returned 942 chopping boards, sits at 4.55%
-- overall: whole-order reversals are not confined to bad accounts.


-- 7. What share of returned value comes from the top 10 customers?
WITH customer_totals AS (
    SELECT
        CustomerID,
        ABS(SUM(CASE WHEN Invoice LIKE 'C%'
                 THEN Quantity * Price ELSE 0 END)) AS value_returned
    FROM transactions
    WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
      AND Invoice NOT IN ('541431','C541433','581483','C581484')
      AND CustomerID IS NOT NULL
    GROUP BY CustomerID
),
ranked AS (
    SELECT
        value_returned,
        ROW_NUMBER() OVER (ORDER BY value_returned DESC) AS rn
    FROM customer_totals
)
SELECT
    SUM(value_returned)                                    AS total_returned,
    SUM(CASE WHEN rn <= 10 THEN value_returned ELSE 0 END) AS top10_returned,
    CAST(100.0 * SUM(CASE WHEN rn <= 10 THEN value_returned ELSE 0 END)
         / SUM(value_returned) AS decimal(5,2))            AS top10_pct
FROM ranked;
-- Result: £134,609 of £467,393 — 28.8% of returned value comes
-- from 10 customers out of roughly 5,900.