# E-commerce Database Design & Analytics

A university database coursework project covering relational design, synthetic data,
SQL analytics and trigger-based order/inventory updates. The database models customers,
products, categories, orders, line items, payments and reviews.

**Stack:** MySQL 8, SQL (CTEs and window functions), Python, Faker.

## My contribution

I designed the ERD and relational schema, implemented the SQL queries and triggers,
and prepared the synthetic data generation workflow. This was a team coursework
submission; the other members handled the report, slides and presentation.

This public version selects the completed technical work. It excludes student
identifiers, group-report documents, editor settings, duplicate SQL dumps and unfinished
exercise outlines. Source notes were converted into runnable SQL; targeted MySQL 8
strict-mode repairs are documented in [the query catalog](docs/queries.md).

## What is included

- Seven-table relational schema with primary/foreign keys and basic uniqueness constraints.
- Synthetic generator: 1,200 customers, 15 categories, 250 products, 8,000 orders,
  one payment per order, 1–4 line items per order and 5,000 purchase-linked reviews.
- Three order-item triggers demonstrating stock decrement/restoration and stored order-total recalculation.
- 20 completed analytics queries: dataset overview, revenue, product/category rankings,
  customer/review segments, cohort retention and RFM.
- [ERD and design notes](docs/design.md), [query definitions](docs/queries.md),
  offline seed checks and an isolated MySQL integration runner.

## Repository layout

```text
sql/
  01_schema.sql           canonical schema
  02_triggers.sql         install after historical seed import
  queries/               six SQL files with completed questions
scripts/generate_seed.py synthetic seed generator
docs/                    ERD, design limits and metric definitions
tests/                   offline generator checks and Docker/MySQL integration
requirements.txt         pinned generator dependencies
```

## Run locally

Requirements: Python 3.10+ and MySQL 8.0. The analytics SQL uses CTEs and window
functions and is written for MySQL, not PostgreSQL or SQLite.

1. Create a virtual environment and install the generator dependencies:

   ```sh
   python -m venv .venv
   # Windows PowerShell:
   .\.venv\Scripts\Activate.ps1
   # macOS/Linux alternative:
   # source .venv/bin/activate
   python -m pip install -r requirements.txt
   python scripts/generate_seed.py
   ```

   The output is `generated/seed.sql`, which is intentionally ignored by Git. Names,
   addresses and records are generated; emails use the reserved `example.org` domain.
   Both random generators use seed 42. Dates are relative to the execution date, so
   identical seeds do not promise byte-identical output on different days or Faker versions.

2. Start the MySQL client **from the repository root**, using your own local credentials:

   ```sh
   mysql --default-character-set=utf8mb4 -u root -p
   ```

   Inside the client, create an empty database and run the files in this order:

   ```sql
   CREATE DATABASE ecommerce_coursework CHARACTER SET utf8mb4;
   USE ecommerce_coursework;
   SOURCE sql/01_schema.sql;
   SOURCE generated/seed.sql;
   SOURCE sql/02_triggers.sql;
   SOURCE sql/queries/01_dataset_overview.sql;
   SOURCE sql/queries/02_revenue_analysis.sql;
   SOURCE sql/queries/03_product_performance.sql;
   SOURCE sql/queries/04_category_performance.sql;
   SOURCE sql/queries/05_customer_reviews.sql;
   SOURCE sql/queries/06_cohorts_rfm.sql;
   ```

   Use a new empty database for each full import. Generated IDs assume an empty schema.
   **Import the historical seed before installing triggers.** The generator already
   calculates stored order totals; installing triggers first would also subtract
   historical line items from the demo stock snapshots.

## Tests and verification status

```sh
python -m unittest discover -s tests -p test_seed.py -v
python tests/test_mysql.py
```

The offline suite passed: row counts/reserved demo emails, foreign-key ranges,
order/payment totals, shipping-address lengths and review/purchase consistency.

**MySQL runtime has not yet been verified.** Docker Desktop on the preparation machine
failed during startup, so the integration runner exited before creating a database.
No claim is made that the SQL/trigger runtime checks passed. The runner is included to
make that verification repeatable on a working Docker installation.

With Docker available, the integration runner creates a uniquely named MySQL 8.0
container with no exposed ports, external network or persistent database volume. It
imports schema → generated seed → triggers, runs all query files with strict grouping
enabled, and checks inventory/order-total changes across two inserts and two deletes.
Its synthetic fixture is rolled back, and only its own container is removed. It uses
an empty password only inside that temporary, network-isolated container. The first
run may download the `mysql:8.0` image; offline checks do not require Docker.

## Interpretation and limits

This is a learning project. Revenue definitions differ between payment-realized revenue
and completed-order revenue; item revenue excludes shipping. Profit uses current product
cost rather than a historical cost ledger. See [the metric notes](docs/queries.md).

The triggers handle inserts/deletes only. There is no stock-availability guard,
order-item update synchronization, cancellation/refund inventory reversal or payment
reconciliation mechanism. Most domain ranges have no CHECK constraint. The design is
intended to demonstrate relational and SQL concepts, not operate a live shop.

## References

- [MySQL 8 handling of GROUP BY](https://dev.mysql.com/doc/refman/8.0/en/group-by-handling.html)
- [MySQL 8 trigger syntax](https://dev.mysql.com/doc/refman/8.0/en/trigger-syntax.html)
- [Faker package](https://pypi.org/project/Faker/)
