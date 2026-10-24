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
| Write-offs counted as sales | Those same negative rows were initially summed into units sold, inflating every product return rate | Sales counted as positive non-credit rows only |
| Non-product stock codes | Postage, carriage, discounts, bank charges, Amazon fees, manual adjustments and a test product all appear as transaction rows | Excluded from product-level analysis by explicit list; `DCGS*` codes and `PADS` kept, as they are real products |
| No return reason recorded | The data shows *what* was returned, never *why* | Limits the analysis to patterns, not causes |

## Approach

1. `01_create_table.sql` — schema
2. `02_load_data.sql` — source-sheet tagging after import
3. `03_clean_dates.sql` — date conversion
4. `04_data_quality.sql` — investigation queries
5. `05_remove_duplicates.sql` — overlap removal
6. `06_clean_customer_ids.sql` — normalize blank customer IDs to NULL
7. `07_clean_descriptions.sql` — trim whitespace from product descriptions
8. `08_returns_analysis.sql` — return definition, headline rate, anomaly investigation
9. `09_return_drivers.sql` — product, order and customer-level drivers
10. `10_export_for_tableau.sql` — transaction-level extract for the dashboard

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

**What drives the genuine returns is customers, not products.** The products
with the highest return rates turned out to be one wholesale order being
reversed, not items people dislike:

| Product | Units sold | Units returned | Rate | Driven by |
|---|---|---|---|---|
| 23113 — Pantry Chopping Board | 1,154 | 946 | 82% | One customer returned all 942 they bought |
| 16043 — Pop Art Push Down Rubber | 2,145 | 984 | 46% | One customer returned all 960 they bought |

Below those, 24 products cluster between 45% and 50% — too tight to be
separate quality problems, and worth under £50 each.

**Whole-order reversals account for 23% of returned value** (£109,124 of
£467,393, across 3,052 of 15,011 customer-product pairs). Real, but not the
main driver — three quarters of returned value is partial returns.

**Returns are concentrated in a small number of accounts.** Ten customers
out of roughly 5,900 account for 28.8% of all returned value (£134,609).
Within that group, two very different patterns:

| Customer | Bought | Returned | Rate |
|---|---|---|---|
| 14277 | £16,817 | £12,829 | 76% |
| 12454 | £16,460 | £12,361 | 75% |
| 15749 | £44,534 | £22,998 | 52% |
| 14646 | £526,752 | £3,549 | 0.7% |
| 14156 | £303,256 | £5,295 | 1.8% |

The first three return most of what they buy. The last two are among the
largest accounts in the business and return almost nothing.

## Recommendations

**Review the handful of accounts returning over 50%.** Three customers
return between 52% and 76% of everything they buy, costing roughly £48,000
in returned value plus handling both ways. Worth understanding before
renewing terms — whether that's sampling before bulk orders, minimum order
quantities, or a restocking charge.

**Separate cancellations from returns in reporting.** Two orders reversed
within twenty minutes accounted for 34% of recorded returns. Until an order
cancelled before dispatch is distinguished from goods coming back, the
returns figure is not measurable.

**Stop reporting stock write-offs as returns.** 3,393 damage and loss
adjustments carry negative quantities and would be counted as customer
returns by any query filtering on quantity alone.

**Don't chase product quality on this evidence.** No product shows a return
pattern spread across many customers, which is what a genuine quality
problem looks like. The high rates are single orders.

## Limitations

- Data is 2009–2011; patterns may not hold today
- No return reasons recorded
- Invoice-level granularity only; no customer demographics
- Data loading used DBeaver's import wizard, so the column mapping is not captured in version control
- 22.5% of transactions have no customer ID, so customer-level analysis covers roughly 77% of the data
- The monthly rate divides each month's returns by that month's sales, but returns relate to earlier sales; month-level figures are therefore approximate
- December 2011 is a partial month — the data ends on the 9th
- The 1,000-unit threshold for product return rates is a judgement call; a different cut-off would change which products appear

## Tools

SQL Server 2022 (Docker), DBeaver, Tableau Public, Git