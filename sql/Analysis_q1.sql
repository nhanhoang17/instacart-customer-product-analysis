use analysis;

-- Tìm các sản phẩm đặc trưng trong phân khúc high
with product_count_by_segment AS (
    select cs.customer_segment,pd.product_name,count(*) as purchase_count,rank() over (partition by cs.customer_segment order by count(*) desc) as rank_in_segment    from customer_rfm_segmented as cs
    join orders as os on os.user_id=cs.user_id
    join order_products_prior_final as o2 on os.order_id=o2.order_id
    join products as pd on pd.product_id=o2.product_id
    group by cs.customer_segment,pd.product_name
    
)
select product_name
INTO high_value_exclusive_products
from product_count_by_segment 
where  customer_segment='High-value' and rank_in_segment <= 20

except

select product_name
from product_count_by_segment 
where customer_segment='Medium-value' and rank_in_segment <= 20

except

select product_name
from product_count_by_segment 
where customer_segment='low-value' and rank_in_segment <= 20

select *
from high_value_exclusive_products;


-- Tìm các sản phẩm hay được mua kèm trong phân khúc high
select os.order_id,pr.product_name
into high_value_basket
from customer_rfm_segmented as cs
join orders as os on os.user_id=cs.user_id
join order_products_prior_final as o2 on os.order_id=o2.order_id
join products as pr on o2.product_id= pr.product_id
where cs.customer_segment='High-value'
;

select count(*)
from high_value_basket;

- so sánh tỉ lệ mua các sản phẩm chỉ được mua trong top 20 phân khúc High-value 
with seg_orders as(
select cs.customer_segment, count(distinct os.order_id) as total_order
from customer_rfm_segmented as cs
join orders as os on os.user_id=cs.user_id
join order_products_prior_final as o1 on os.order_id=o1.order_id
group by cs.customer_segment

),
product_orders as(
select cs.customer_segment,pd.product_name,count(distinct os.order_id) as orders_with_product
from customer_rfm_segmented as cs
join orders as os on os.user_id=cs.user_id
join order_products_prior_final as o1 on os.order_id=o1.order_id
join products as pd on pd.product_id=o1.product_id
where pd.product_name in (select product_name  from high_value_exclusive_products)
group by cs.customer_segment,pd.product_name



)
select po.customer_segment,po.product_name,po.orders_with_product,so.total_order, cast(100.0 * po.orders_with_product/so.total_order as decimal(5,2)) as pct_orders
into comparing_high_exclusive_pd
from product_orders as po
join seg_orders as so on so.customer_segment=po.customer_segment
order by po.customer_segment,po.product_name;

select *
from comparing_high_exclusive_pd;

