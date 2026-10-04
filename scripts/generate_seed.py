"""Synthetic coursework data; import before installing order-item triggers."""
import random
from pathlib import Path
from faker import Faker

fake = Faker()
Faker.seed(42)
random.seed(42)

# =============================
# CONFIG - SCHEMA V2
# =============================

NUM_CUSTOMERS = 1200
NUM_CATEGORIES = 15
NUM_PRODUCTS = 250
NUM_ORDERS = 8000
NUM_REVIEWS = 5000

OUTPUT_FILE = Path(__file__).resolve().parents[1] / "generated" / "seed.sql"
OUTPUT_FILE.parent.mkdir(parents=True, exist_ok=True)


def sql_string(value):
    return str(value).replace("\\", "\\\\").replace("'", "''")


def write(line):
    output_file.write(line + "\n")


with OUTPUT_FILE.open("w", encoding="utf-8") as output_file:
    # =============================
    # CUSTOMERS
    # =============================

    write("-- INSERT CUSTOMERS")

    for _ in range(NUM_CUSTOMERS):
        name = sql_string(fake.name())
        email = f"customer-{_ + 1}@example.org"
        signup = fake.date_between(start_date="-2y", end_date="today")
        dob = fake.date_between(start_date="-40y", end_date="-18y")
        city = sql_string(fake.city())
        status = random.choices(
            ["active", "inactive", "banned"],
            weights=[0.78, 0.15, 0.07],
        )[0]

        write(
            f"""INSERT INTO customers
(full_name,email,signup_date,date_of_birth,city,status)
VALUES ('{name}','{email}','{signup}','{dob}','{city}','{status}');"""
        )

    # =============================
    # CATEGORIES
    # =============================

    write("\n-- INSERT CATEGORIES")

    for i in range(1, NUM_CATEGORIES + 1):
        write(f"INSERT INTO categories (category_name) VALUES ('Category_{i}');")

    # =============================
    # PRODUCTS
    # =============================

    write("\n-- INSERT PRODUCTS")

    product_prices = {}

    for i in range(1, NUM_PRODUCTS + 1):
        name = f"{sql_string(fake.unique.word().capitalize())} Product {i}"
        category_id = random.randint(1, NUM_CATEGORIES)
        stock_quantity = 0 if i in {17, 143} else random.randint(1, 500)
        price = round(random.uniform(10, 500), 2)
        product_prices[i] = price
        cost = round(price * random.uniform(0.5, 0.9), 2)
        created = fake.date_time_between(start_date="-2y", end_date="now")
        is_active = random.choices([1, 0], weights=[0.88, 0.12])[0]

        write(
            f"""INSERT INTO products
(product_name,category_id,stock_quantity,price,cost,created_at,is_active)
VALUES ('{name}',{category_id},{stock_quantity},{price},{cost},'{created}',{is_active});"""
        )

    # =============================
    # ORDERS + ORDER ITEMS + PAYMENTS
    # =============================

    write("\n-- INSERT ORDERS")

    purchased_items = {}

    for i in range(NUM_ORDERS):
        order_id = i + 1
        customer_id = random.randint(1, NUM_CUSTOMERS)
        order_date = fake.date_time_between(start_date="-1y", end_date="now")
        status = random.choices(
            ["pending", "paid", "shipped", "delivered", "completed", "cancelled", "refunded"],
            weights=[0.07, 0.14, 0.12, 0.18, 0.37, 0.08, 0.04],
        )[0]
        shipping_address = sql_string(fake.address().replace("\n", ", "))
        shipping_fee = round(random.uniform(2, 20), 2)
        total_amount = 0

        write(
            f"""INSERT INTO orders
(customer_id,order_date,status,shipping_address,shipping_fee,total_amount)
VALUES ({customer_id},'{order_date}','{status}','{shipping_address}',{shipping_fee},0);"""
        )

        num_items = random.randint(1, 4)

        for _ in range(num_items):
            product_id = random.randint(1, NUM_PRODUCTS)
            quantity = random.randint(1, 3)
            unit_price = product_prices[product_id]

            total_amount += quantity * unit_price

            write(
                f"""INSERT INTO order_items
(order_id,product_id,quantity,unit_price)
VALUES ({order_id},{product_id},{quantity},{unit_price});"""
            )

            if status in {"paid", "shipped", "delivered", "completed"}:
                key = (customer_id, product_id)
                purchased_items[key] = max(order_date, purchased_items.get(key, order_date))

        total_amount += shipping_fee
        total_amount = round(total_amount, 2)

        write(f"UPDATE orders SET total_amount={total_amount} WHERE order_id={order_id};")

        if status == "pending":
            payment_status = "pending"
        elif status in {"cancelled", "refunded"}:
            payment_status = "failed"
        else:
            payment_status = "completed"

        if payment_status == "completed":
            paid_amount = total_amount
        elif payment_status == "pending":
            paid_amount = 0
        else:
            paid_amount = 0

        payment_method = random.choice(["card", "ewallet", "cod", "bank_transfer"])

        write(
            f"""INSERT INTO payments
(order_id,payment_method,payment_status,paid_amount,payment_date)
VALUES ({order_id},'{payment_method}','{payment_status}',{round(paid_amount, 2)},'{order_date}');"""
        )

    # =============================
    # REVIEWS
    # =============================

    write("\n-- INSERT REVIEWS")

    review_candidates = list(purchased_items.items())
    review_sample = random.sample(review_candidates, min(NUM_REVIEWS, len(review_candidates)))

    for (customer_id, product_id), purchase_date in review_sample:
        rating = round(random.randint(1, 5) + random.choice([0, 0.5]), 1)

        if rating > 5:
            rating = 5.0

        review_date = fake.date_time_between(start_date=purchase_date, end_date="now")

        write(
            f"""INSERT INTO reviews
(product_id,customer_id,rating,review_date)
VALUES ({product_id},{customer_id},{rating},'{review_date}');"""
        )

print(f"Done. File {OUTPUT_FILE.name} created.")
