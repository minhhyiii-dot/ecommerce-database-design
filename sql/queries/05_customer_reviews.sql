-- 26. Top 10 customers by total spending
WITH validated AS(
    SELECT
    o.customer_id,
    SUM(p.paid_amount) AS total_spending,
    COUNT(DISTINCT o.order_id) AS total_orders
    FROM orders o  
    JOIN payments p ON p.order_id = o.order_id
    WHERE o.status = 'completed'
    AND p.payment_status = 'completed'
    GROUP BY o.customer_id
)
SELECT
c.customer_id,
c.full_name,
v.total_spending,
v.total_orders
FROM validated v 
JOIN customers c ON v.customer_id = c.customer_id
ORDER BY v.total_spending DESC
LIMIT 10;

-- 27. Customer spending by status
WITH validated AS(
    SELECT
    c.customer_id,
    o.order_id,
    c.status,
    o.total_amount
    FROM orders o 
    JOIN customers c ON c.customer_id = o.customer_id
    WHERE o.status = 'completed'
)
SELECT 
v.status,
COUNT(DISTINCT v.customer_id) AS total_customer,
COUNT(DISTINCT v.order_id) AS total_orders,
SUM(v.total_amount) AS total_revenue
FROM validated v 
GROUP BY v.status;

-- 28. Product Performance Score
WITH validated AS(
    SELECT
    o.order_id,
    oi.product_id,
    oi.quantity,
    oi.unit_price
    FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
),
product_rev AS(
    SELECT
    v.product_id,
    SUM(v.quantity * v.unit_price) AS product_rev,
    AVG(SUM(v.quantity * v.unit_price)) over() AS avg_product_rev
    FROM validated v 
    GROUP BY v.product_id
),
rating AS(
    SELECT
    pr.*,
    AVG(r.rating) AS avg_product_rate,
    AVG(AVG(r.rating)) over() AS avg_rate
    FROM product_rev pr 
    JOIN reviews r ON r.product_id = pr.product_id
    GROUP BY pr.product_id, pr.product_rev, pr.avg_product_rev
)
SELECT
product_id,
product_rev,
avg_product_rate,
CASE
WHEN product_rev > avg_product_rev AND avg_product_rate >= avg_rate THEN 'Star'
WHEN product_rev > avg_product_rev AND avg_product_rate < avg_rate THEN 'Risky Bestsellers'
WHEN product_rev < avg_product_rev AND avg_product_rate >= avg_rate THEN 'Hidden Gems'
ELSE 'Underperformers'
END AS segments
FROM rating
ORDER BY product_id;
