-- 1. Count records in each table
SELECT
'customers' AS table_name,
COUNT(c.customer_id) AS total
FROM customers c 

UNION ALL

SELECT
'products' AS table_name,
COUNT(p.product_id) AS total
FROM products p 

UNION ALL

SELECT
'orders' AS table_name,
COUNT(o.order_id) AS total
FROM orders o 

UNION ALL

SELECT
'order_items' AS table_name,
COUNT(oi.order_item_id) AS total
FROM order_items oi	 

UNION ALL

SELECT
'payments' AS table_name,
COUNT(pa.payment_id) AS total
FROM payments pa  

UNION ALL

SELECT
'categories' AS table_name,
COUNT(ca.category_id) AS total
FROM categories ca 

UNION ALL

SELECT
'reviews' AS table_name,
COUNT(r.review_id) AS total
FROM reviews r;

-- 2. Completed orders
SELECT
orders.order_id
FROM orders 
WHERE orders.status = 'completed';

-- 3. Orders by status
SELECT
o.status,
COUNT(o.order_id) AS total
FROM orders o 
GROUP BY o.status;

-- 4. Order date range
SELECT
MIN(o.order_date) AS first_order,
MAX(o.order_date) AS last_order
FROM orders o;

-- 5. Customer with no reviews
SELECT
c.customer_id,
c.full_name,
c.status
FROM customers c
WHERE NOT EXISTS (
    SELECT
    *
    FROM reviews r 
    WHERE r.customer_id = c.customer_id
)
ORDER BY c.customer_id;
