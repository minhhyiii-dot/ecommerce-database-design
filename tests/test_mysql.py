"""End-to-end coursework checks against an ephemeral, network-isolated MySQL 8 container."""
from pathlib import Path
import json
import subprocess
import sys
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]

def command(*args, data=None, timeout=120):
    result = subprocess.run(args, input=data, capture_output=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout.decode("utf-8", errors="replace").strip()


def main():
    try:
        command("docker", "info", "--format", "{{.ServerVersion}}", timeout=20)
    except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        print("MySQL integration NOT RUN: Docker engine is unavailable.", file=sys.stderr)
        print(str(exc), file=sys.stderr)
        return 2

    container = "ecommerce-db-test-" + uuid.uuid4().hex[:12]
    created = False
    try:
        # No published ports, external network, host database, or persistent volume.
        created = True  # Also clean up if Docker creates the container before a run timeout.
        command("docker", "run", "--detach", "--name", container,
                "--network", "none", "--tmpfs", "/var/lib/mysql",
                "-e", "MYSQL_ALLOW_EMPTY_PASSWORD=yes",
                "-e", "MYSQL_DATABASE=ecommerce_coursework", "mysql:8.0", timeout=300)
        created = True
        deadline = time.monotonic() + 90
        while True:
            try:
                command("docker", "exec", container, "mysqladmin", "ping", "--host=127.0.0.1", "-uroot", "--silent", timeout=5)
                break
            except (RuntimeError, subprocess.TimeoutExpired):
                if time.monotonic() >= deadline:
                    raise RuntimeError("MySQL did not become ready within 90 seconds")
                time.sleep(1)

        def sql(text):
            return command("docker", "exec", "-i", container, "mysql", "-uroot",
                           "--batch", "--skip-column-names", "--default-character-set=utf8mb4",
                           "ecommerce_coursework", data=text.encode("utf-8"))

        sql((ROOT / "sql/01_schema.sql").read_text(encoding="utf-8"))
        command(sys.executable, str(ROOT / "scripts/generate_seed.py"))
        sql((ROOT / "generated/seed.sql").read_text(encoding="utf-8"))
        assert sql("SELECT COUNT(*) FROM customers;") == "1200"
        assert sql("SELECT COUNT(*) FROM categories;") == "15"
        assert sql("SELECT COUNT(*) FROM products;") == "250"
        assert sql("SELECT COUNT(*) FROM orders;") == "8000"
        assert sql("SELECT COUNT(*) FROM payments;") == "8000"
        assert sql("SELECT COUNT(*) FROM reviews;") == "5000"
        assert sql("SELECT COUNT(*) FROM customers WHERE email NOT LIKE '%@example.org';") == "0"
        assert sql("SELECT COUNT(*) FROM orders o WHERE ABS(o.total_amount - o.shipping_fee - "
                   "(SELECT SUM(quantity * unit_price) FROM order_items oi WHERE oi.order_id = o.order_id)) > 0.005;") == "0"
        assert sql("SELECT COUNT(*) FROM reviews r WHERE NOT EXISTS (SELECT 1 FROM order_items oi "
                   "JOIN orders o ON o.order_id = oi.order_id WHERE o.customer_id = r.customer_id "
                   "AND oi.product_id = r.product_id AND o.status IN ('paid','shipped','delivered','completed'));") == "0"
        sql((ROOT / "sql/02_triggers.sql").read_text(encoding="utf-8"))
        assert sql("SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = DATABASE();") == "3"
        assert "ONLY_FULL_GROUP_BY" in sql("SELECT @@SESSION.sql_mode;")
        query_outputs = {}
        for path in sorted((ROOT / "sql/queries").glob("*.sql")):
            output = sql(path.read_text(encoding="utf-8"))
            assert output, "Expected populated query output for " + path.name
            query_outputs[path.name] = len(output.splitlines())

        # Two inserts, one partial deletion, one final deletion. Roll back all fixture rows.
        fixture = """
START TRANSACTION;
INSERT INTO categories(category_name) VALUES ('Trigger fixture');
SET @category = LAST_INSERT_ID();
INSERT INTO products(product_name,category_id,stock_quantity,price,cost)
VALUES ('Trigger fixture product',@category,25,20,10);
SET @product = LAST_INSERT_ID();
INSERT INTO orders(customer_id,order_date,status,shipping_address,shipping_fee,total_amount)
VALUES (1,NOW(),'pending','Synthetic fixture',5,5);
SET @order = LAST_INSERT_ID();
INSERT INTO order_items(order_id,product_id,quantity,unit_price) VALUES (@order,@product,2,20);
SET @first_item = LAST_INSERT_ID();
SELECT CONCAT((SELECT stock_quantity FROM products WHERE product_id=@product),':',
              (SELECT total_amount FROM orders WHERE order_id=@order));
INSERT INTO order_items(order_id,product_id,quantity,unit_price) VALUES (@order,@product,3,12);
SET @second_item = LAST_INSERT_ID();
SELECT CONCAT((SELECT stock_quantity FROM products WHERE product_id=@product),':',
              (SELECT total_amount FROM orders WHERE order_id=@order));
DELETE FROM order_items WHERE order_item_id=@first_item;
SELECT CONCAT((SELECT stock_quantity FROM products WHERE product_id=@product),':',
              (SELECT total_amount FROM orders WHERE order_id=@order));
DELETE FROM order_items WHERE order_item_id=@second_item;
SELECT CONCAT((SELECT stock_quantity FROM products WHERE product_id=@product),':',
              (SELECT total_amount FROM orders WHERE order_id=@order));
ROLLBACK;
"""
        assert sql(fixture).splitlines() == ["23:45.00", "20:81.00", "22:41.00", "25:5.00"]
        print(json.dumps({"mysql_integration": "passed", "queries": query_outputs,
                          "checks": ["seed_counts", "reserved_demo_emails", "stored_order_totals",
                                     "review_purchase_pairs", "strict_sql_mode", "three_triggers",
                                     "twenty_queries", "insert_delete_inventory_and_totals"]}, indent=2))
        return 0
    except (AssertionError, OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
        print("MySQL integration FAILED: " + str(exc), file=sys.stderr)
        return 1
    finally:
        if created:
            # Exact unique name created above, not a wildcard or existing user container.
            try:
                command("docker", "rm", "--force", container, timeout=30)
            except (OSError, subprocess.TimeoutExpired, RuntimeError) as exc:
                print("Cleanup warning for this test container " + container + ": " + str(exc), file=sys.stderr)

if __name__ == "__main__":
    raise SystemExit(main())
