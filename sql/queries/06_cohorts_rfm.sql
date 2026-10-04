-- 29. Customer cohort retention analysis
WITH order_month AS(
    SELECT DISTINCT
    o.customer_id,
    cast(date_format(o.order_date, '%Y-%m-01') AS date) AS order_month
    FROM orders o 
    WHERE o.status = 'completed'
),
first_purchase AS(
    SELECT
    om.customer_id,
    MIN(om.order_month) AS cohort_month
    FROM order_month om
    GROUP BY om.customer_id
),
cohort_activity AS(
    SELECT
    om.customer_id,
    fp.cohort_month,
    om.order_month
    FROM order_month om 
    JOIN first_purchase fp ON om.customer_id = fp.customer_id
),
active_customers AS(
    SELECT
    ca.cohort_month,
    ca.order_month,
    COUNT(DISTINCT ca.customer_id) AS active_customers
    FROM cohort_activity ca 
    GROUP BY ca.cohort_month, ca.order_month
),
cohort_size AS(
    SELECT
    fp.cohort_month,
    COUNT(DISTINCT fp.customer_id) AS cohort_size
    FROM first_purchase fp
    GROUP BY fp.cohort_month
)
SELECT
ac.cohort_month,
timestampdiff(month, ac.cohort_month, ac.order_month) AS month_numbers,
round((ac.active_customers * 1.0 / cs.cohort_size * 100), 2) AS retention_rate
FROM active_customers ac 
JOIN cohort_size cs ON ac.cohort_month = cs.cohort_month
ORDER BY ac.cohort_month, month_numbers;

-- 30. RFM customer segmentation
WITH validated AS(
    SELECT
    o.customer_id,
    o.order_id,
    o.total_amount AS order_total
    FROM orders o 
    WHERE o.status = 'completed'
),
last_order AS(
    SELECT 
    v.customer_id,
    MAX(o.order_date) AS last_order_date
    FROM validated v
    JOIN orders o ON o.order_id = v.order_id
    GROUP BY v.customer_id
),
calculate AS(
    SELECT 
    v.customer_id,
    SUM(v.order_total) AS monetary,
    COUNT(DISTINCT v.order_id) AS frequency
    FROM validated v
    GROUP BY v.customer_id
),
recency AS(
    SELECT 
    lo.customer_id,
    timestampdiff(day, lo.last_order_date, (SELECT MAX(order_date) FROM orders)) AS recency
    FROM last_order lo
),
pct_ranking AS(
    SELECT
    c.customer_id, 
    r.recency, 
    c.frequency, 
    c.monetary,
    percent_rank() over(ORDER BY r.recency DESC) AS pct_recency,
    percent_rank() over(ORDER BY c.frequency ASC) AS pct_frequency,
    percent_rank() over(ORDER BY c.monetary ASC) AS pct_monetary
    FROM calculate c 
    JOIN recency r ON c.customer_id = r.customer_id
),
scoring AS(
    SELECT 
    pr.*,
    CASE 
    WHEN pct_recency <= 0.2 THEN 1
    WHEN pct_recency <= 0.4 THEN 2
    WHEN pct_recency <= 0.6 THEN 3
    WHEN pct_recency <= 0.8 THEN 4
    ELSE 5 
    END AS r_score,
    CASE 
    WHEN pct_frequency <= 0.2 THEN 1
    WHEN pct_frequency <= 0.4 THEN 2
    WHEN pct_frequency <= 0.6 THEN 3
    WHEN pct_frequency <= 0.8 THEN 4
    ELSE 5 
    END AS f_score,
    CASE 
    WHEN pct_monetary <= 0.2 THEN 1
    WHEN pct_monetary <= 0.4 THEN 2
    WHEN pct_monetary <= 0.6 THEN 3
    WHEN pct_monetary <= 0.8 THEN 4
    ELSE 5 
    END AS m_score
    FROM pct_ranking pr
),
segment AS(
SELECT
s.*,
SUM(s.frequency) OVER() AS all_order,
SUM(s.monetary) OVER() AS all_revenue,
COUNT(s.customer_id) OVER() AS all_customer,
CASE
WHEN r_score = 5 AND f_score = 5 AND m_score = 5 THEN 'Champion'
WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'VIP'
WHEN f_score >= 4 AND m_score >= 4 THEN 'Loyal'
WHEN m_score >= 4 THEN 'Big Spender'
WHEN r_score >= 3 AND f_score >= 3 THEN 'Potential Loyalist'
WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customer'
WHEN r_score <= 2 AND f_score >= 3 THEN 'At Risk'
WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost'
ELSE 'General'
END AS RFM_segment
FROM scoring s
),
all_segment AS(
    SELECT 'Champion' AS RFM_segment UNION ALL
    SELECT 'VIP' UNION ALL
    SELECT 'Loyal' UNION ALL
    SELECT 'Big Spender' UNION ALL
    SELECT 'Potential Loyalist' UNION ALL
    SELECT 'New Customer' UNION ALL
    SELECT 'At Risk' UNION ALL
    SELECT 'Lost' UNION ALL
    SELECT 'General'
)
SELECT
    als.RFM_segment,
    COUNT(DISTINCT s.customer_id) AS total_customer,
    SUM(s.frequency) AS total_order,
    SUM(s.monetary) AS total_revenue,
    round((COUNT(DISTINCT s.customer_id) * 1.0 / MAX(s.all_customer)), 2) * 100 AS pct_customer,
    round(((SUM(s.frequency) * 1.0 / MAX(s.all_order)) * 100), 2) AS pct_orders,
    round(((SUM(s.monetary) * 1.0 / MAX(s.all_revenue)) * 100), 2) AS pct_revenue
FROM all_segment als
LEFT JOIN segment s ON s.RFM_segment = als.RFM_segment
GROUP BY als.RFM_segment
ORDER BY FIELD(als.RFM_segment, 'Champion', 'VIP', 'Loyal', 'Big Spender', 'Potential Loyalist','New Customer','At Risk', 'Lost', 'General');
