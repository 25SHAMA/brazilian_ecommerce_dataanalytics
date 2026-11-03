select * from olist.dim_customer; -- customer_unique_id
select * from olist.dim_date; -- date , year , month_number, month_name , quarter , day , day_of_Wwee, day_of_week_number
select * from olist.dim_product; --product_id,product_category_name , product_category_name_english , product_name_length , 
									-- product_description_length , product_photos_qty , product_weight_g , product_length_cm , product_height_cm, product_widht_cm
select * from olist.dim_seller; --seller_id , seller_zip_code_prefix , seller_city , seller_state
select * from olist.fact_order_items; -- order_id , order_item_id , product_id , seller_id , shipping_limit_date , price, freight_value , customer_unique_id , ite_count
select * from olist.fact_orders; -- order_id , customer_id , order_status , order_purchase_timestamp , order_approved_at,
								--order_delivered_carrier_date , order_delivered_customer_date , order_estimated_delivery_date , 
								-- customer_unique_id , customer_zip_code_prefix , customer_city , customer_state , order_count
select * from olist.fact_payments; -- order_id , payment_sequential, payment_type , payment_installments, payment_value , customer_unique_id
select * from olist.fact_reviews; -- review_id , order_id , review_score , review_comment_title , review_comment_message

-- Analysis 1 — Overall delivery performance
-- Business question: How well is Olist meeting its estimated delivery dates?
with delivery_analysis_performance as (
    select
        order_id,
        order_delivered_customer_date::DATE as actual_date,
        order_estimated_delivery_date::DATE as estimated_date,
        case
            when order_delivered_customer_date::DATE <= order_estimated_delivery_date::DATE then 'On Time'
            else 'Late'
        end as delivery_status,
        greatest( order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE, 0) as delay_days
    from olist.fact_orders
    where order_status = 'delivered'
      and order_delivered_customer_date is not null
      and order_estimated_delivery_date is not null
)
select
    count(*) as total_delivered_orders,
    count(*) filter (where delivery_status = 'On Time') as on_time_orders,
    count(*) filter (where delivery_status = 'Late') as late_orders,
    round( count(*) filter (where delivery_status = 'On Time') * 100.0 / count(*) ,2) as on_time_percentage,
    round(count(*) filter (where delivery_status = 'Late') * 100.0 / count(*), 2) as late_percentage,
    round(avg(delay_days) filter (where delivery_status = 'Late'), 2) as average_delay_days,
    max(delay_days) AS maximum_delay_days
from delivery_analysis_performance;

-- Analysis 2 — Delivery delay distribution
-- Business question: How severe are Olist's delivery delays?
with delay_delivery_distribution as
	(select
	        order_id,
	        order_delivered_customer_date::DATE as actual_date,
	        order_estimated_delivery_date::DATE as estimated_date,
	        case
	            when order_delivered_customer_date::DATE <= order_estimated_delivery_date::DATE then 'On Time'
	            else 'Late'
	        end as delivery_status ,
			order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE as no_of_days
	from olist.fact_orders
	where order_status = 'delivered'
),
no_of_days_late as(
	select order_id , actual_date , estimated_date , delivery_status , no_of_days ,
			case 
				when no_of_days between 1 and 3 then '1-3 days late'
				when no_of_days between 4 and 7 then '4-7 days late'
				when no_of_days between 8 and 14 then '8-14 days late'
				else '15 or more days late'
			end as days_late
	from delay_delivery_distribution
	where delivery_status = 'Late' and no_of_days > 0
)
select days_late ,
		count(*) as late_orders_count,
		round(count(*) * 100.0 / sum (count(*)) OVER (), 2) as percentage_of_late_orders
from no_of_days_late
group by days_late
order by late_orders_count desc

-- Analysis 3 — Monthly delivery performance
-- Business question: Is delivery performance improving or worsening over time?
with monthly_delivery_performance as(
	select
	       DATE_TRUNC('month', order_purchase_timestamp)::DATE as order_month,
	       order_id,
	       order_delivered_customer_date::DATE as actual_date,
	       order_estimated_delivery_date::DATE as estimated_date
	from olist.fact_orders
	where order_status = 'delivered'
	     and order_delivered_customer_date IS NOT NULL
	     and order_estimated_delivery_date IS NOT NULL
)
select 
		to_char(order_month,'yyyy-mm') as order_year_month,
		count(*) as total_delivered_orders,
		count(*) filter(where actual_date > estimated_date) as late_order_count,
		count(*) filter(where actual_date <= estimated_date) as on_time_order_count,
		round(count(*) filter(where actual_date > estimated_date) * 100.0 / count(*),2) as late_delivery_percentage,
		ROUND(avg(actual_date - estimated_date) filter (where actual_date > estimated_date), 2) as average_delay_days
from monthly_delivery_performance
group by to_char(order_month,'yyyy-mm')
order by to_char(order_month,'yyyy-mm')

-- Analysis 4 — Customer satisfaction: On-time vs late delivery
-- Business question: Do late deliveries result in lower customer review scores?
with customer_satisfaction as (
	 select
	       o.order_id,
	       case
	           when o.order_delivered_customer_date::DATE <= o.order_estimated_delivery_date::DATE then 'On Time'
	           else 'Late'
	       end as delivery_status,
	       r.review_score
	 from olist.fact_orders o
	 join olist.fact_reviews r on o.order_id = r.order_id
	 where o.order_status = 'delivered'
	     and o.order_delivered_customer_date is not null
	     and o.order_estimated_delivery_date is not null
	     and r.review_score is not null
)
select delivery_status,
		count(*) as total_count,
		round(avg(review_score),2) as avg_review_score,
		count(*) filter(where review_score <= 2) as negative_review,
		count(*) filter(where review_score > 3) as positive_review,
		round(count(*) filter(where review_score <= 2) * 100.0 / count(*),2) as negative_review_percentage,
		round(count(*) filter(where review_score >3 ) * 100.0 / count(*),2) as positive_review_percentage
from customer_satisfaction
group by delivery_status
order by delivery_status

-- Analysis 5 — Overall review score distribution
-- Business question: What is the overall customer satisfaction level?
select review_score,
		count(*) as total_review_count,
		round(count(*) * 100.0 / sum(count(*)) over(),2) as pct_reviews
from olist.fact_reviews
group by review_score
order by review_score

-- Analysis 6 — State-wise delivery performance
-- Business question: Which Brazilian states experience the most delivery problems?
with state_wise_delivery as(
	select order_id,
			customer_state as state,
			order_delivered_customer_date::DATE as actual_date,
			order_estimated_delivery_date::DATE as estimated_date,
			case
				when order_delivered_customer_date::DATE <= order_estimated_delivery_date ::DATE then 'On-Time'
				else 'Late'
			end as delivery_status,
			order_delivered_customer_date::DATE - order_estimated_delivery_date ::DATE as no_of_days
	from olist.fact_orders
	WHERE order_status = 'delivered'
	  and order_delivered_customer_date is not null
	  and order_estimated_delivery_date is not null
)
select state,
		count(*) as total_order_count,
		count(case when delivery_status = 'Late' then 1 end) as late_order_count,
		round(count(case when delivery_status = 'Late' then 1 end) * 100.0 / count(*) ,2) as late_delivery_percentage,
		round(avg(no_of_days) filter ( where actual_date > estimated_date),2) as average_delay_days
from state_wise_delivery
group by state
order by late_delivery_percentage desc

-- Analysis 7 — Seller-wise delivery performance
-- Business question: Are certain sellers associated with more delivery delays?
with seller_delivery as (
    select
        oi.seller_id,
        oi.order_id,
        o.order_delivered_customer_date::DATE as actual_date,
        o.order_estimated_delivery_date::DATE as estimated_date
    from olist.fact_order_items oi
    inner join olist.fact_orders o on oi.order_id = o.order_id
    where o.order_status = 'delivered'
      and o.order_delivered_customer_date is not null
      and o.order_estimated_delivery_date is not null
)
select
    sd.seller_id,
    ds.seller_state,
    count(*) as total_order_items,
    count(*) filter (where sd.actual_date > sd.estimated_date) as late_order_items,
    round(count(*) filter (where sd.actual_date > sd.estimated_date) * 100.0 / count(*), 2) as late_percentage,
    round(avg(sd.actual_date - sd.estimated_date) filter (where sd.actual_date > sd.estimated_date), 2) as average_delay_days
from seller_delivery sd
left join olist.dim_seller ds
    on sd.seller_id = ds.seller_id
group by sd.seller_id, ds.seller_state
having count(*) >= 20
order by late_percentage desc;

-- Analysis 8 — Product category delivery performance
-- Business question: Are certain product categories associated with more delivery delays?
with product_category_delivery as (
	select 
		p.product_category_name_english as product_category,
		order_delivered_customer_date::DATE as actual_date,
		order_estimated_delivery_date::DATE as estimated_date,
		case
			when order_delivered_customer_date::DATE <= order_estimated_delivery_date::DATE then 'On-Time'
			else 'Late'
		end as delivery_status,
		greatest( order_delivered_customer_date::DATE - order_estimated_delivery_date::DATE, 0) as delay_days
	from olist.fact_orders o
	join olist.fact_order_items oi on o.order_id = oi.order_id
	join olist.dim_product p on p.product_id = oi.product_id
	where o.order_status = 'delivered'
			and o.order_delivered_customer_date is not null
			and o.order_estimated_delivery_date is not null
)
select product_category,
		count(*) as total_ordered_items,
		count(*) filter(where delivery_status = 'Late') as late_order_items,
		round(count(*) filter(where delivery_status = 'Late') * 100.0 / count(*),2) as late_order_pct,
		round(avg(delay_days),2) as avg_delay_days
from product_category_delivery
group by product_category
having count(*) >= 50
order by late_order_pct desc;

-- Analysis 9 — Actual delivery time analysis
-- Business question: How long does Olist actually take to deliver an order after purchase?
select 
		count(*) as total_delivered_orders,
		round(avg(order_delivered_customer_date::DATE - order_purchase_timestamp::DATE),2) as avg_delivery_duration,
		percentile_cont(0.5) within group(order by (order_delivered_customer_date::DATE - order_purchase_timestamp::DATE)) as median_delivery_days,
		min(order_delivered_customer_date::DATE - order_purchase_timestamp::DATE) as min_delivery_duration,
		max(order_delivered_customer_date::DATE - order_purchase_timestamp::DATE) as max_delivery_duration,
		percentile_cont(0.9) within group(order by (order_delivered_customer_date::DATE - order_purchase_timestamp::DATE)) as pct_90_delivery_days
from olist.fact_orders
where order_status = 'delivered' and order_delivered_customer_date is not null

-- Analysis 10 — Delivery delays and business impact
-- Business question: How large is the difference in customer satisfaction between late and on-time deliveries, 
-- and how much delivery-related negative feedback does Olist receive?
with order_delivery_status as( 
	select order_id,
			case
				when order_delivered_customer_date::DATE <= order_estimated_delivery_date::DATE then 'On-Time'
				else 'Late'
			end as delivery_status
	from olist.fact_orders
	where order_status = 'delivered'
				and order_delivered_customer_date is not null
				and order_estimated_delivery_date is not null
),
review_analysis as(
	select 
		od.delivery_status,
		r.order_id,
		r.review_score
	from order_delivery_status od
    inner join olist.fact_reviews r
        on od.order_id = r.order_id
    where r.review_score is not null
),
summary as (
    select delivery_status,
        count(*) AS total_reviews,
        ROUND(avg(review_score), 2) as average_score,
        count(*) filter (where review_score <= 2) as negative_reviews,
        round(
            count(*) filter (where review_score <= 2) * 100.0 / count(*), 2) as negative_review_percentage
    from review_analysis
    group by delivery_status
)
select *
from summary
order by delivery_status;