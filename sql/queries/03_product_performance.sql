-- 16. Top 10 products by revenue
WITH validate AS(
    SELECT
    oi.product_id,
    SUM(oi.quantity * oi.unit_price) AS product_revenue
    FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY oi.product_id
)
SELECT
row_number() over(ORDER BY v.product_revenue DESC) AS top,
p.product_id,
p.product_name,
v.product_revenue
FROM validate v 
JOIN products p ON v.product_id = p.product_id
ORDER BY top
LIMIT 10;

-- 17. Top 10 products by quantity sold
WITH validate AS(
    SELECT
    oi.product_id,
    SUM(oi.quantity) AS total_quantity_sold
    FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY oi.product_id
)
SELECT
row_number() over(ORDER BY v.total_quantity_sold DESC) AS top,
v.total_quantity_sold,
p.product_id,
p.product_name
FROM validate v 
JOIN products p ON v.product_id = p.product_id
ORDER BY top
LIMIT 10;
