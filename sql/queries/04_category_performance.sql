-- 21. Revenue by category
WITH validated AS(
    SELECT
    oi.product_id,
    SUM(oi.quantity * oi.unit_price) AS product_revenue
    FROM orders o 
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY oi.product_id
),
categories_revenue AS(
    SELECT
    p.category_id,
    SUM(product_revenue) AS categories_revenue
    FROM validated v 
    JOIN products p ON v.product_id = p.product_id
    GROUP BY p.category_id
)
SELECT
c.category_id,
c.category_name,
cr.categories_revenue
FROM categories_revenue cr 
JOIN categories c ON c.category_id = cr.category_id
ORDER BY cr.categories_revenue DESC;

-- 22. Profit by category
WITH validated AS(
    SELECT
    o.order_id
    FROM orders o 
    WHERE o.status = 'completed'
),
profit AS(
    SELECT
    c.category_id,
    c.category_name,
    SUM(oi.quantity * oi.unit_price) AS categories_revenue,
    SUM(oi.quantity * p.cost) AS categories_cost
    FROM validated v 
    JOIN order_items oi ON v.order_id = oi.order_id
    JOIN products p ON p.product_id = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    GROUP BY c.category_id, c.category_name
)
SELECT
p.category_id,
p.category_name,
p.categories_revenue - p.categories_cost AS categories_profit
FROM profit	p 
ORDER BY categories_profit DESC;

-- 23. Top 5 products in each category by revenue
WITH validated AS(
    SELECT
    oi.product_id,
    SUM(oi.quantity * oi.unit_price) AS products_revenue
    FROM orders o 
    JOIN order_items oi	 ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY oi.product_id
),
rn AS(
    SELECT
    p.category_id,
    v.product_id,
    p.product_name,
    v.products_revenue,
    row_number() over(PARTITION BY p.category_id ORDER BY products_revenue DESC) AS rn 
    FROM validated v 
    JOIN products p ON v.product_id = p.product_id
)
SELECT
c.category_id,
c.category_name,
MAX(CASE WHEN r.rn = 1 THEN concat(r.product_id, ' - ', r.product_name) END) AS top_1,
MAX(CASE WHEN r.rn = 2 THEN concat(r.product_id, ' - ', r.product_name) END) AS top_2,
MAX(CASE WHEN r.rn = 3 THEN concat(r.product_id, ' - ', r.product_name) END) AS top_3,
MAX(CASE WHEN r.rn = 4 THEN concat(r.product_id, ' - ', r.product_name) END) AS top_4,
MAX(CASE WHEN r.rn = 5 THEN concat(r.product_id, ' - ', r.product_name) END) AS top_5
FROM rn r
JOIN categories c ON r.category_id = c.category_id
WHERE r.rn <= 5
GROUP BY c.category_id, c.category_name
ORDER BY c.category_id;

-- 24. Category dependency on top products
WITH validated AS(
    SELECT
    oi.product_id,
    SUM(oi.quantity * oi.unit_price) AS prod_rev
    FROM orders o 
    JOIN order_items oi	 ON o.order_id = oi.order_id
    WHERE o.status = 'completed'
    GROUP BY oi.product_id
),
prod_category AS(
    SELECT
    v.*,
    p.category_id,
    SUM(v.prod_rev) over(PARTITION BY p.category_id) AS cate_rev
    FROM validated v
    JOIN products p ON v.product_id = p.product_id
),
ranked AS(
    SELECT
    pc.*,
    round((pc.prod_rev * 100 / pc.cate_rev), 2) AS contribution_rate,
    row_number() over(PARTITION BY pc.category_id ORDER BY prod_rev DESC) AS rn 
    FROM prod_category pc
)
SELECT
r.category_id,
c.category_name, 
COUNT( DISTINCT r.product_id) AS total_product,
MAX(CASE WHEN r.rn = 1 THEN concat(r.contribution_rate, '%') END) AS 'top_1',
MAX(CASE WHEN r.rn = 2 THEN concat(r.contribution_rate, '%') END) AS 'top_2',
MAX(CASE WHEN r.rn = 3 THEN concat(r.contribution_rate, '%') END) AS 'top_3',
MAX(CASE WHEN r.rn = 4 THEN concat(r.contribution_rate, '%') END) AS 'top_4',
MAX(CASE WHEN r.rn = 5 THEN concat(r.contribution_rate, '%') END) AS 'top_5',
concat(ROUND(SUM(CASE WHEN r.rn <= 5 THEN r.contribution_rate ELSE 0 END), 2), '%') AS top_5_total_share
FROM ranked r
JOIN categories c ON r.category_id = c.category_id
GROUP BY r.category_id, c.category_name
ORDER BY r.category_id;

-- 25. Category performance ranking
WITH validated AS (
    SELECT
    o.order_id
    FROM orders o 
    WHERE o.status = 'completed'
),
cate_metrics AS(
    SELECT
    c.category_id,
    c.category_name,
    SUM(oi.quantity) AS quantity_sold,
    COUNT(DISTINCT oi.order_id) AS total_orders,
    SUM(oi.quantity * oi.unit_price) AS cate_rev,
    SUM(oi.quantity * p.cost) AS cate_cost
    FROM validated v 
    JOIN order_items oi	ON oi.order_id = v.order_id
    JOIN products p ON p.product_id = oi.product_id
    JOIN categories c ON c.category_id = p.category_id
    GROUP BY c.category_id, c.category_name
),
category_ranks AS(
    SELECT
    cm.*,
    cm.cate_rev - cm.cate_cost AS cate_profit,
    round((cm.cate_rev - cm.cate_cost) * 1.0 / cm.cate_rev * 100, 2) AS profit_margin,
    row_number() over(ORDER BY (cm.cate_rev - cm.cate_cost) DESC) AS performance_rank
    FROM cate_metrics cm 
)
SELECT
category_id,
category_name,
quantity_sold AS total_quantity_sold,
total_orders,
cate_rev AS category_revenue,
cate_profit AS category_profit,
profit_margin,
performance_rank
FROM category_ranks
ORDER BY performance_rank;
