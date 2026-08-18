/*
OLIST E Commerse Data Exploration 
Skills used: Joins, CTE's, Temp Tables, Windows Functions, Aggregate Functions, Creating Views, Converting Data Types
*/


/* some basic exploration to understand data */

/* Looking at Order Count with thir order status */
select 
	order_status,
	count(*) as total_orders
from orders 
group by  order_status

--------------------------------------------------------------------------------------------------------------------------

/* checking data range minimum date maximum date for which we have this data

select 
   min(order_purchase_timestamp) AS first_order,
   max(order_purchase_timestamp) AS last_order
from orders

/* so we have data of 2016  to 2018 */

--------------------------------------------------------------------------------------------------------------------------

/* finding total unique customers, sellers and products */

select 
	(select count(distinct customer_id) from customers) AS total_customers,
	(select count(distinct seller_id) from sellers) AS total_sellers,
	(select count(distinct product_id) from products) AS total_products


/* here i use subquery in select to find all */

--------------------------------------------------------------------------------------------------------------------------

/* lets find avg delay in deliveries of orders */

select 
	avg(datediff(day,order_purchase_timestamp,order_delivered_customer_date)) as avg_actual_delivery_days,
	avg(datediff(day,order_purchase_timestamp,order_estimated_delivery_date)) as avg_estimated_delivery_days,
	avg(datediff(day,order_estimated_delivery_date,order_delivered_customer_date)) as av_delay_days
from orders
where order_status = 'delivered'

/* avg_delay_days is negative that means delivery is on avg done before the estimated delivery date */

--------------------------------------------------------------------------------------------------------------------------


/* finding states with highest percentage of late delivery thatn estimated delivery date */


select 
	c.customer_state,
	count(*) as total_orders,
	sum(case when o.order_delivered_customer_date > o.order_estimated_delivery_date then 1 else 0 end) as late_orders,
	round(sum(case when o.order_delivered_customer_date > o.order_estimated_delivery_date then 1 else 0 end)*100.0/count(*),2) as late_order_pct
from orders o
join customers c on o.customer_id = c.customer_id

where o.order_status = 'delivered'
group by c.customer_state
order by late_order_pct desc

--------------------------------------------------------------------------------------------------------------------------

/* now lets find out how delay in delivery impact review score */
/* skills used : cte, group by, order by,joins,  date functions */ , 


with delivery_delay as (
	select 
	order_id,
	datediff(day, o.order_estimated_delivery_date,o.order_delivered_customer_date) as delay_days
	from orders as o
	where o.order_status = 'delivered'

)

select
	case
		when dd.delay_days <=0 then 'on time / early'
		when dd.delay_days between 1 and 7 then 'late'
		else 'very late'
	end as delivery_catagory,
	round(avg(cast(r.review_score as float)),2) as avg_review_score,
	count(*) as total_orders

from delivery_delay dd

inner join order_reviews r on  dd.order_id = r.order_id

group by 
	case
		when dd.delay_days <=0 then 'on time / early'
		when dd.delay_days between 1 and 7 then 'late'
		else 'very late'
	end
order by avg_review_score desc


/* so the result tells us on time delivery have 4.29 avg score and very late orders have 1.71 avg score we can see that it havily impact order reviews */

--------------------------------------------------------------------------------------------------------------------------


/* lets do the rfm analysis of customers how much they are spending , how recent they ordered and how frequently they orders and then devide them in segments according to the rfm scores */

with customer_rfm AS (
select 
	c.customer_unique_id,
	datediff(day, max(o.order_purchase_timestamp), (select max(order_purchase_timestamp) from orders)) as recency_days,
	count(distinct o.order_id) as frequency,
	sum(it.price) as monetory

from orders o
inner join customers c
on o.customer_id = c.customer_id
inner join order_items it
on o.order_id = it.order_id
where o.order_status = 'delivered'
group by c.customer_unique_id
),
rfm_scores as (

select 
	*,
	ntile(5) over(order by recency_days desc) as r_score,
	ntile(5) over(order by frequency asc) as f_score,
	ntile(5) over(order by monetory asc) as m_score
	
from customer_rfm
),
segmented as (
	select 
		*,
		case 
			when r_score >= 4 and f_score >=4 and m_score >=4 then 'most active customer(all time)'
			when r_score >=3 and f_score >=3 then 'loyal customer'
			when  r_score >=5 and f_score <=2 then 'new customer'
			when r_score <=2 and f_score >=3 then 'inactive old customer'
			when r_score <=2 and f_score <=2 then 'least interested customers'
			else 'regular'
		end as customer_segment
	from rfm_scores)

select 
	customer_segment,
	count(*) as total_customers,
	round(avg(monetory),2) as avg_score,
	sum(monetory) as total_revenue_contribution
from segmented
group by customer_segment
order by total_revenue_contribution desc

--------------------------------------------------------------------------------------------------------------------------

/* lets take a look at sellers proformance find out the sellers with highest revenue and also find out the avg review they gets from customres and find if there are relationship between both */

with seller_revenue as (
	select
		oi.seller_id,
		count(distinct oi.order_id) as total_orders,
		sum(oi.price) as total_revenue,
		round(avg(oi.price),2) as avg_price

	from order_items oi
	join orders o on oi.order_id = o.order_id

	where o.order_status = 'delivered'
	group by oi.seller_id
	),
seller_reviews as (
	select 
		oi.seller_id,
		avg(cast(r.review_score as float)) as avg_review_score

	from order_items oi
	join order_reviews r on oi.order_id = r.order_id
	group by oi.seller_id
	)

select 
	sm.seller_id,
	sm.total_revenue,
	sm.total_orders,
	round(sr.avg_review_score,2) as avg_review_score
from seller_revenue sm
join seller_reviews sr on sm.seller_id = sr.seller_id

order by sm.total_revenue desc


--------------------------------------------------------------------------------------------------------------------------


/* payment methods analysis */

select 
	payment_type,
	count(*) as total_transactions,
	count(*)*100.0/sum(count(*)) over()  as percentage,
	sum(payment_value) as total_value

from order_payments
group by payment_type
order by total_transactions desc

/* so 73 percent people used credit card for payment */

----------------------------------------------------------------------------------------------------------------------------
/* avg reviews comparison with payment type */

use olist;

with order_payment_type as (

select 
	distinct order_id,
	payment_type
from order_payments
)

select

	p.payment_type,
	count(*) as total_transations,
	avg(cast(review_score as float)) as avg_review_score
from order_payment_type p
join order_reviews r
on p.order_id = r.order_id
group by p.payment_type


-------------------------------------------------------------------------------------------------------------------------

/* worst and best categories according to their avg reviews */

use olist;

select 
	p.category_name,
	count(*) as total_reviws,
	avg(cast(r.review_score as float)) as avg_review_score

from order_reviews as r
join orders o on r.order_id = o.order_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
group by p.category_name
having count(*)> 30
order by avg_review_score asc

------------------------------------------------------------------------------------------------------------------------

/* creating view to store data for later visulalization */


create view categories_reviews as (
select 
	p.category_name,
	count(*) as total_reviws,
	avg(cast(r.review_score as float)) as avg_review_score

from order_reviews as r
join orders o on r.order_id = o.order_id
join order_items oi on o.order_id = oi.order_id
join products p on oi.product_id = p.product_id
group by p.category_name
having count(*)> 30

)


------------------------------------------------------------------------------------------------------------------------
