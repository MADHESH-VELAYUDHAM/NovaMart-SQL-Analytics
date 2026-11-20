USE novamart;
SHOW TABLES;
USE novamart;
SELECT COUNT(*) FROM fact_sales;
SHOW INDEX FROM fact_sales;

CREATE INDEX ix_fs_date ON fact_sales (sale_date);
CREATE INDEX ix_fs_cust_date ON fact_sales (customer_id, sale_date);
CREATE INDEX ix_fs_prod ON fact_sales (product_id);
CREATE INDEX ix_fs_store ON fact_sales (store_id, sale_date);
CREATE INDEX ix_fs_status ON fact_sales (order_status);

-- Q1 What is the total revenue for each year (2023 to 2026)?--
select * from fact_sales
limit 10;
select 
year(sale_date) as perticlar_year,
round(sum(net_amount),2) as total_sales
from fact_sales
where order_status='completed'
group by year(sale_date)
order by year(sale_date);

/* Q2 What is the revenue of each region (South, West, North, 
East), and what % share of total revenue does each hold? Use completed orders only. 
The result should have 4 rows (region, revenue, pct_share),
sorted with the highest-revenue region on top.*/

select 
s.region,
round(sum(f.net_amount),2) as total_revenue,
round(sum(f.net_amount)*100/sum(sum(f.net_amount)) over(),2) as region_percentage
from fact_sales as f
inner join dim_store as s
on s.store_id=f.store_id
where order_status='completed'
group by s.region
order by total_revenue desc;

/* Q3 What is the revenue for each month (e.g. 2025-01, 2025-02), 
and by what % did it grow or fall compared to the previous month?*/

with monthly_sales as (
select
date_format(sale_date,"%Y-%m") as sales_month,
round(sum(net_amount),2) as revenue
from fact_sales
where order_status='completed'
group by date_format(sale_date,"%Y-%m")
)
select 
sales_month,
revenue,
lag(revenue) over (order by sales_month) as previous_month_revenue,
round((revenue - lag(revenue) over (order by sales_month)) * 100/lag(revenue) over (order by sales_month),2) as grouth_precentage
from monthly_sales
order by sales_month;

/* Q4 For each customer, calculate Recency (days since their last purchase), 
Frequency (number of orders), and Monetary (total spend). Use completed orders only. Columns: customer_id, 
recency_days, frequency, monetary. Use 2026-06-30 as the reference date (the last date in the data). 
Show only the top 20 customers by monetary value */

SELECT 
customer_id,
datediff("2026-06-30",max(sale_date)) as Recency_days,
count(*) as freqency,
round(sum(net_amount),2) as Monetary_or_total_spending
from fact_sales
where order_status="completed"
group by customer_id
order by Monetary_or_total_spending
limit 20;

/* Give each of R, F, and M a score from 1 to 5 using NTILE(5),
 where 5 is best. Note: for Recency, fewer days = best (5). 
Then use the scores to classify customers into Champions,
 Loyal, At-Risk, and Lost. Show how many customers are in each segment.*/
 
with RFM as (
SELECT 
customer_id,
datediff("2026-06-30",max(sale_date)) as Recency_days,
count(*) as freqency,
round(sum(net_amount),2) as Monetary_or_total_spending
from fact_sales
where order_status="completed"
group by customer_id),

RFM_score as (
select 
customer_id,
Recency_days,
freqency,
Monetary_or_total_spending,
ntile(5) over(order by Recency_days) as R_score,
ntile(5) over(order by freqency) as F_score,
ntile(5) over(order by Monetary_or_total_spending) as M_score
from RFM
),
segments as (
select customer_id,
case
when R_score >=4 and F_score >=4 and M_score>=4 then "champines"
when F_score >=4 then "loyal"
when R_score <=2 and F_score >=2 then "At_risk"
when R_score <=2 and F_score <=2 then "lost"
else "Others"
end as segment
from RFM_SCORE)

SELECT segment,
COUNT(*) AS TOTAL_CUSTOMERS
FROM segments
GROUP BY segment
ORDER BY TOTAL_CUSTOMERS DESC;


/*  Q6 Using the Q5 segments (Champions, Loyal, At-Risk, Lost, Others), 
what % of total revenue does each segment contribute? Columns: segment, 
customers, revenue, revenue_pct. Sort with the highest-revenue segment on top. Use completed orders only*/

with RFM as (
SELECT 
customer_id,
datediff("2026-06-30",max(sale_date)) as Recency_days,
count(*) as freqency,
round(sum(net_amount),2) as Monetary_or_total_spending
from fact_sales
where order_status="completed"
group by customer_id),

RFM_score as (
select 
customer_id,
Recency_days,
freqency,
Monetary_or_total_spending,
ntile(5) over(order by Recency_days desc) as R_score,
ntile(5) over(order by freqency) as F_score,
ntile(5) over(order by Monetary_or_total_spending) as M_score
from RFM
),
segments as (
select customer_id,
Monetary_or_total_spending,
case
when R_score >=4 and F_score >=4 and M_score>=4 then "champines"
when F_score >=4 then "loyal"
when R_score <=2 and F_score >=3 then "At_risk"
when R_score <=2 and F_score <=2 then "lost"
else "Others"
end as segment
from RFM_SCORE)

SELECT segment,
COUNT(*) AS TOTAL_CUSTOMERS,
round(sum(Monetary_or_total_spending),2) as revenue,
round(sum(Monetary_or_total_spending)*100/sum(sum(Monetary_or_total_spending))over(),2) as revenue_pct
FROM segments
GROUP BY segment
ORDER BY TOTAL_CUSTOMERS DESC;

/* Q7 How many customers signed up in each month (e.g. 2023-01, 2023-02)?
 Use the dim_customer table. Columns: signup_month, new_customers. Sort by month.*/
 select
 date_format(signup_date,"%Y-%m") as signup_month,
count(*) as new_customers
 from dim_customer
 group by date_format(signup_date,"%Y-%m")
 order by date_format(signup_date,"%Y-%m");
 
 
 /*Q8  For each signup-month cohort, find how many customers made at least one purchase in the month
 immediately after their signup month (Month 1 retention). Output columns: signup_month, 
 cohort_size, retained_customers, retention_pct (rounded to 2 decimals). Sort by signup month*/

 with mad as (
 select 
 distinct(customer_id),
 signup_date
 from dim_customer) 
 
 select 
 date_format(signup_date,"%Y%m")
 as cohart_month,
 
 count(distinct(m.customer_id)) as cohart_size,
 
 count(distinct( case
 when PERIOD_DIFF(
    DATE_FORMAT(s.sale_date, '%Y%m'),
    DATE_FORMAT(m.signup_date, '%Y%m')
)= 1
 then m.customer_id
 end)) as rentation,
 
 round(100*count(distinct(case
 when PERIOD_DIFF(
    DATE_FORMAT(s.sale_date, '%Y%m'),
    DATE_FORMAT(m.signup_date, '%Y%m')
)= 1
 then m.customer_id
 end))/COUNT(DISTINCT m.customer_id),2) as cohart_pct
 
 from mad as m
 left join fact_sales as s
 on m.customer_id=s.customer_id
 group by date_format(signup_date,"%Y%m");
 
 