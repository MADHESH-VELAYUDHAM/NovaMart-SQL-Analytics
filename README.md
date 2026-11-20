About the project
NovaMart is a retail business database with 10 million sales records across stores, customers and products. I analysed it in MySQL to answer real business questions on revenue, customer value and retention.

Dataset

fact_sales: about 1 crore (10M) transactions (2023 to 2026)
dim_customer: customer details and signup dates
dim_store: store and region details
Indexes created on date, customer, product, store and order status to keep queries fast at this size.

Case Study 1: Sales Performance

Yearly revenue for 2023 to 2026
Revenue and % share by region
Month-over-month revenue growth using LAG()

Case Study 2: RFM Customer Segmentation

Recency, Frequency and Monetary values per customer
1 to 5 scoring using NTILE(5)
Segments: Champions, Loyal, At-Risk, Lost, Others
Revenue contribution (%) of each segment

Case Study 3: Cohort Retention

New customers per signup month
Month 1 retention % for each signup cohort using PERIOD_DIFF()

SQL concepts used: CTEs, window functions (LAG, NTILE, SUM() OVER), joins, CASE logic, date functions, aggregation, indexing.

Resume bullets (each within 4 lines)

NovaMart Retail Analytics | MySQL, SQL, CTEs, Window Functions | github.com/MADHESH-VELAYUDHAM/NovaMart-SQL-Analytics
• Analysed a 1 crore (10M) row retail database in MySQL, using indexing and CTEs to answer revenue, regional share and month-over-month growth questions.
• Built RFM customer segmentation (NTILE scoring) and Month 1 cohort retention analysis using window functions and PERIOD_DIFF.

Don’t add result numbers to the resume until you have run the final queries and checked them. Only add the figures you actually get. When all 6 case studies are done, change “3” to “6” in the README and add Product Analysis, Funnel/Sessions and Data Quality.

Fix these in your file before uploading

Q4: order by Monetary_or_total_spending limit 20 is ascending, so it shows your lowest 20 customers. Add desc to get the top 20.
Q5: ntile(5) over(order by Recency_days) gives score 5 to the customers with the most days since purchase, which is the wrong direction. Use order by Recency_days desc as you did in Q6, so fewer days means a higher score.
Q6 and Q8: these are fine. In Q6, At_risk uses F_score >= 3, but Q5 used >= 2, so the segment counts in the two questions won’t match. Use the same rule in both.
Spelling: champines, cohart and rentation will look unprofessional in a portfolio. Rename them to champions, cohort and retained_customers.
