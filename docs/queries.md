# Analytics query catalog

Only queries that had SQL in the coursework notes are included. Planned/empty sections,
Obsidian image embeds and duplicate notes were removed; this is not a claim that all
30 planned exercises were completed.

| File | Included questions |
|---|---|
| `01_dataset_overview.sql` | Row counts, completed orders, order statuses, date range, customers without reviews |
| `02_revenue_analysis.sql` | Realized payment revenue, monthly completed-order revenue/AOV, revenue by payment method |
| `03_product_performance.sql` | Top 10 products by revenue and by units |
| `04_category_performance.sql` | Revenue, estimated profit, top products, dependency share, category ranking |
| `05_customer_reviews.sql` | Top spenders, customer-status revenue, revenue/rating product segments |
| `06_cohorts_rfm.sql` | Cohort retention and RFM segment summary |

## Definitions

Payment-realized revenue means `payments.payment_status = 'completed'` and sums
`paid_amount`. Most other queries use `orders.status = 'completed'`; consequently
these two totals measure different populations. Product/category revenue excludes
shipping; order-level monetary measures include shipping. This difference is intentional.

Cohorts start at the first completed purchase month; retention measures repeat purchase
activity, not account login activity. RFM uses the latest date in the generated orders
as its reference date and percentile cutoffs, so it can be rerun without today's date.

The product performance score uses the mean of product-level ratings as its rating
benchmark and excludes products without reviews. The label is rule based, not ML.
Current product cost is used to estimate profit. Rankings break equal values in an
unspecified order unless the query explicitly includes a second sort key.

## Publication repairs

For MySQL 8 with `ONLY_FULL_GROUP_BY` enabled, the product-score aggregation groups
all carried revenue fields, and RFM denominators use aggregate values. The category
ranking CTE was renamed from `rank` to avoid the reserved keyword. Query statements
now have semicolons; the schema and the meaning of the completed exercises are retained.

Queries requiring order/payment joins may multiply amounts if users create multiple
payment rows for an order; the supplied generator uses one. RFM percentage columns
for absent segments may be NULL. These are learning examples rather than production
financial reporting rules.
