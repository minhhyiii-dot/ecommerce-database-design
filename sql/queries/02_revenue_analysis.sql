-- 6. Total realized revenue
SELECT
SUM(p.paid_amount) AS total_realized_revenue
FROM payments p 
WHERE p.payment_status = 'completed';

-- 7. Monthly  trend
SELECT
date_format(o.order_date, '%Y-%m-01') AS month,
SUM(o.total_amount) AS total_revenue,
AVG(o.total_amount) AS avg_revenue
FROM orders o 
WHERE o.status = 'completed'
GROUP BY date_format(o.order_date, '%Y-%m-01');

-- 8. Revenue by payment method
SELECT
p.payment_method,
SUM(o.total_amount) AS revenue
FROM orders o 
JOIN payments p ON p.order_id = o.order_id
WHERE o.status = 'completed'
GROUP BY p.payment_method;
