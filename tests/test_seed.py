"""Offline checks for generated synthetic data; these do not replace MySQL integration."""
import ast
from collections import Counter
from pathlib import Path
import re
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SyntheticSeedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        subprocess.run([sys.executable, str(ROOT / "scripts/generate_seed.py")], check=True, capture_output=True)
        cls.seed = (ROOT / "generated/seed.sql").read_text(encoding="utf-8")
        cls.rows = {}
        pattern = r"INSERT INTO (\w+)\s*\([^;]*?\)\s*VALUES \((.*?)\);"
        for table, values in re.findall(pattern, cls.seed, flags=re.S):
            # Seed strings use SQL doubled apostrophes. No execute/eval or production input.
            values = re.sub(r"'((?:[^']|'')*)'", lambda match: repr(match[1].replace("''", "'").replace(chr(92) * 2, chr(92))), values)
            cls.rows.setdefault(table, []).append(ast.literal_eval("(" + values + ",)"))

    def test_expected_rows_and_safe_demo_identities(self):
        counts = {table: len(rows) for table, rows in self.rows.items()}
        self.assertEqual(counts, {"customers": 1200, "categories": 15, "products": 250,
                                  "orders": 8000, "order_items": counts["order_items"],
                                  "payments": 8000, "reviews": 5000})
        self.assertGreaterEqual(counts["order_items"], 8000)
        self.assertLessEqual(counts["order_items"], 32000)
        self.assertTrue(all(row[1].endswith("@example.org") for row in self.rows["customers"]))

    def test_seed_foreign_keys_and_order_totals(self):
        subtotals = Counter()
        for order_id, product_id, quantity, price in self.rows["order_items"]:
            self.assertTrue(1 <= order_id <= 8000)
            self.assertTrue(1 <= product_id <= 250)
            self.assertTrue(1 <= quantity <= 3)
            subtotals[order_id] += quantity * price
        totals = {int(order): float(total) for total, order in
                  re.findall(r"UPDATE orders SET total_amount=([0-9.]+) WHERE order_id=(\d+);", self.seed)}
        for order_id, row in enumerate(self.rows["orders"], 1):
            self.assertTrue(1 <= row[0] <= 1200)
            self.assertLessEqual(len(row[3]), 100)
            self.assertAlmostEqual(totals[order_id], subtotals[order_id] + row[4], places=2)
        for order_id, method, status, paid, date in self.rows["payments"]:
            self.assertTrue(1 <= order_id <= 8000)
            self.assertAlmostEqual(paid, totals[order_id] if status == "completed" else 0, places=2)

    def test_reviews_reference_purchases_and_valid_ratings(self):
        purchasers = {(self.rows["orders"][order_id - 1][0], product_id)
                      for order_id, product_id, quantity, price in self.rows["order_items"]
                      if self.rows["orders"][order_id - 1][2] in {"paid", "shipped", "delivered", "completed"}}
        seen = set()
        for product, customer, rating, review_date in self.rows["reviews"]:
            self.assertIn((customer, product), purchasers)
            self.assertNotIn((customer, product), seen)
            self.assertTrue(1 <= rating <= 5)
            seen.add((customer, product))

if __name__ == "__main__":
    unittest.main()
