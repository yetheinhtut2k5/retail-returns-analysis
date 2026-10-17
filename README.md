# Retail Returns Analysis

SQL analysis of return patterns in a UK online retailer's transaction data.

## The question

What do returns cost this business, and what drives them?

[One line on why — e.g. returns are a direct hit to margin and an operational
cost, but most reporting treats them as noise.]

## The data

**Source:** [Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii),
UCI Machine Learning Repository (CC BY 4.0).
Chen, D. (2019). *Online Retail II* [Dataset]. https://doi.org/10.24432/C5CG6D

1,067,371 transactions from a UK-registered online gift-ware retailer,
1 December 2009 to 9 December 2011. Many customers are wholesalers.
Returns are identified by invoice numbers beginning with `c`.

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
| Leading whitespace in descriptions | e.g. `" WHITE CHERRY LIGHTS"` — breaks grouping and joins | [TODO: count affected rows] |
| Variant stock codes | `79323P` / `79323W` are colour variants of the same base product | [TODO: decide whether to treat as one product or many — document the choice] |
| Split invoices | Same customer, separate invoices seconds apart | Each invoice counted as one order; noted as a limitation |
| Missing customer IDs | [TODO: count] | [TODO] |
| No return reason recorded | The data shows *what* was returned, never *why* | Limits the analysis to patterns, not causes |

## Approach

1. `01_create_table.sql` — schema
2. `02_load_data.sql` — source-sheet tagging after import
3. `03_clean_dates.sql` — date conversion
4. `04_data_quality.sql` — investigation queries
5. `05_remove_duplicates.sql` — overlap removal

## Findings

[TODO — the analysis]

## Recommendations

[TODO — what you'd tell the business to do]

## Limitations

- Data is 2009–2011; patterns may not hold today
- No return reasons recorded
- Invoice-level granularity only; no customer demographics
- Data loading used DBeaver's import wizard, so the column mapping is not
  captured in version control

## Tools

SQL Server 2022 (Docker), DBeaver, Git