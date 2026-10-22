# Retail Returns Analysis

SQL analysis of return patterns in a UK online retailer's transaction data.

## The question

What do returns cost this business, and what drives them?

Returns are a direct hit to margin and carry handling costs on top, but most
reporting treats them as a single percentage. That average turned out to hide
more than it showed.

## The data

**Source:** [Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii),
UCI Machine Learning Repository (CC BY 4.0).
Chen, D. (2019). *Online Retail II* [Dataset]. https://doi.org/10.24432/C5CG6D

1,067,371 transactions from a UK-registered online gift-ware retailer,
1 December 2009 to 9 December 2011. Many customers are wholesalers.
Returns are identified by invoice numbers beginning with `C`.

The two source sheets overlap by nine days, so 22,523 duplicate rows are
removed during loading, leaving 1,044,848 transactions for analysis.

**To reproduce:** download the `.xlsx` from the link above, save each sheet
as CSV into `data/`, then run the scripts in `sql/` in order.
The raw data is not committed to this repo.

## Data quality findings

| Issue | Detail | Handling |
|---|---|---|
| Overlapping source sheets | Both Excel sheets cover 1–9 Dec 2010, duplicating 22,523 rows (1,088 invoices, £377,488.45) | Verified identical on row count, invoice count and total value; removed sheet 1's copy |
| Date format corruption | Excel rewrites dates on CSV export, silently swapping day and month | Loaded dates as text, converted explicitly with `TRY_CONVERT(..., 103)`; raw text retained alongside |
| Leading whitespace in descriptions | 2,571 rows across 37 products, e.g. `" WHITE CHERRY LIGHTS"` — splits one product into two groups when aggregating | Trimmed |
| Variant stock codes | `79323P` / `79323W` are colour variants of the same base product | Treated as separate products — colour-level patterns are part of the question, and variants can be rolled up with `LEFT(StockCode, 5)` if needed |
| Split invoices | Same customer, separate invoices seconds apart | Each invoice counted as one order; noted as a limitation |
| Missing customer IDs | 235,287 rows (22.52%) have no customer ID — loaded as empty strings, which hid them from `IS NULL` checks | Converted to NULL; rows kept, since the transactions are real |
| Negative quantity ≠ return | 3,393 negative-quantity rows (15% of all negatives) are stock write-offs — "lost", "damages", "wet" — carrying zero price and no customer ID | Returns defined as invoices starting with `C`; using `Quantity < 0` would overstate returns by 18% |
| Non-product stock codes | Postage, carriage, discounts, bank charges, Amazon fees, manual adjustments and a test product all appear as transaction rows | Excluded from product-level analysis by explicit list; `DCGS*` codes and `PADS` kept, as they are real products |
| No return reason recorded | The data shows *what* was returned, never *why* | Limits the analysis to patterns, not causes |

## Approach

1. `01_create_table.sql` — schema
2. `02_load_data.sql` — source-sheet tagging after import
3. `03_clean_dates.sql` — date conversion
4. `04_data_quality.sql` — investigation queries
5. `05_remove_duplicates.sql` — overlap removal
6. `06_clean_customer_ids.sql` — normalise blank customer IDs to NULL
7. `07_clean_descriptions.sql` — trim whitespace from product descriptions
8. `08_returns_analysis.sql` — return definition, headline rate, anomaly investigation

## Findings

**Returns run at 3.65% of gross sales** — £719,762 returned against £19.7m
over two years.

**But that average is misleading.** Two months stood out: January 2011 at
13.62% and December 2011 at 28.29%. Both turned out to be single
transactions, not trends:

| Month | Product | Units | Value | Order placed | Credited |
|---|---|---|---|---|---|
| Jan 2011 | 23166 — Medium Ceramic Top Storage Jar | 74,215 | £77,184 | 10:01 | 10:17 |
| Dec 2011 | 23843 — Paper Craft, Little Birdie | 80,995 | £168,470 | 09:15 | 09:27 |

Both were orders keyed in and cancelled within twenty minutes — nothing was
shipped or returned. Together they account for £245,654, or 34% of all
recorded returns. Every other transaction for those two products falls
between 48 and 288 units.

**Excluding them, January 2011 corrects to 2.41%** and the monthly rate is
stable between roughly 1.2% and 4% throughout.

[TODO: what actually drives the genuine returns — products, customers,
seasonality]

## Recommendations

[TODO]

## Limitations

- Data is 2009–2011; patterns may not hold today
- No return reasons recorded
- Invoice-level granularity only; no customer demographics
- Data loading used DBeaver's import wizard, so the column mapping is not captured in version control
- 22.5% of transactions have no customer ID, so customer-level analysis covers roughly 77% of the data
- The monthly rate divides each month's returns by that month's sales, but returns relate to earlier sales; month-level figures are therefore approximate
- December 2011 is a partial month — the data ends on the 9th

## Tools

SQL Server 2022 (Docker), DBeaver, Git