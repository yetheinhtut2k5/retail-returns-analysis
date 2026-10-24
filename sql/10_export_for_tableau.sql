-- =============================================================
-- Transaction-level extract for Tableau
-- =============================================================

-- Tableau Public cannot connect to a database, so the dashboard
-- is built from a CSV. Business logic stays here rather than in
-- Tableau calculated fields: a .twbx is a binary, so any rule
-- defined inside it is invisible to anyone reading this repo.
--
-- Transaction-level rather than pre-aggregated, so the dashboard
-- can slice by month, country and customer rather than only
-- showing what was calculated up front.
--
-- Exported via DBeaver: right-click the results grid →
-- Export resultset → CSV → data/returns_extract.csv (UTF-8).

SELECT
    Invoice,
    StockCode,
    Description,
    Quantity,
    Price,
    Quantity * Price AS line_value,
    InvoiceDateTime,
    CustomerID,
    Country,
    CASE WHEN Invoice LIKE 'C%' THEN 'Return' ELSE 'Sale' END AS transaction_type
FROM transactions
WHERE StockCode NOT IN            -- fees, postage, adjustments, test product
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
  AND Invoice NOT IN              -- the two same-day cancelled orders
        ('541431','C541433','581483','C581484')
  AND NOT (Invoice NOT LIKE 'C%'  -- stock write-offs: damage, loss, mis-invoicing
           AND Quantity < 0);


-- Row count check before exporting
SELECT COUNT(*) FROM transactions
WHERE StockCode NOT IN
        ('POST','DOT','C2','C3','D','S','M','B','CRUK',
         'BANK CHARGES','ADJUST','ADJUST2','AMAZONFEE','TEST001')
  AND Invoice NOT IN ('541431','C541433','581483','C581484')
  AND NOT (Invoice NOT LIKE 'C%' AND Quantity < 0);
-- Result: 1,035,742 of 1,044,848 — 9,106 rows excluded
-- (3,393 write-offs, 4 cancellation rows, the rest non-product lines).