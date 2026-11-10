use analysis;


select *
from order_products_prior_final;

-- Tính rfm cho từng user_id và cho vào bảng tạm:

WITH customer_rfm_raw AS (
select os.user_id,
(select TOP 1 o2.days_since_prior_order
from orders as o2
where o2.user_id=os.user_id
order by o2.order_number desc
) as r_u
,count(Distinct os.order_id) as f_u,count(op.product_id)*1.0/count(distinct os.order_id) as m_u
from orders as os
join order_products_prior_final as op on os.order_id=op.order_id
group by os.user_id
),
customer_rfm_scored AS (
-- dùng Ntile để chia các hạng mức người dùng dụa vào rfm
        select user_id,r_u,f_u,m_u,
        NTILE(3) OVER (ORDER BY r_u ASC)  AS r_score,
        NTILE(3) OVER (ORDER BY f_u DESC) AS f_score,
        NTILE(3) OVER (ORDER BY m_u DESC) AS m_score
        FROM customer_rfm_raw
)
select user_id,r_u,f_u,m_u,
r_score,f_score,m_score,(r_score+f_score+m_score) as total_score,
case
    when (r_score+f_score+m_score)<=4 then 'High-value'
    when (r_score+f_score+m_score)<=6 then 'Medium-value'
    else 'low-value'
end as customer_segment
into customer_rfm_segmented
from customer_rfm_scored;





select *
from customer_rfm_segmented;

SELECT customer_segment, COUNT(*) AS so_luong
FROM customer_rfm_segmented
GROUP BY customer_segment;




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

-- Tìm sản phẩm có tỷ lệ order thấp nhất:
select pd.product_name,count(*) as total_purchase,sum(o2.reordered) as total_reordered,cast(sum(cast(o2.reordered as int))as float) / count(*) as reorder_rate
from products as pd
join order_products_prior_final as o2 on o2.product_id=pd.product_id
join orders as o1 on o1.order_id=o2.order_id
group by pd.product_name
having count(*)>=50
order by reorder_rate asc
;


-- tạo bảng gồm các đơn hàng có chứa các sản phẩm có tỉ lệ reordered thấp.

with low_reordered_product as(
select pd.product_name,count(*) as total_purchase,sum(o2.reordered) as total_reordered,cast(sum(cast(o2.reordered as int))as float) / count(*) as reorder_rate
from products as pd
join order_products_prior_final as o2 on o2.product_id=pd.product_id
join orders as o1 on o1.order_id=o2.order_id
group by pd.product_name
having count(*)>=50 and (cast(sum(cast(o2.reordered as int))as float) / count(*))<0.05
),
relevant_orders as (
select distinct op.order_id
from order_products_prior_final as op
join products as pd on op.product_id=pd.product_id
where pd.product_name in (select product_name from low_reordered_product)
)
select op.order_id,pd.product_name
into low_reordered_basket 
from order_products_prior_final as op
join products as pd on op.product_id=pd.product_id
where op.order_id in (select order_id from relevant_orders)

select *
from low_reordered_basket;

-- so sánh tỉ lệ mua các sản phẩm chỉ được mua trong top 20 phân khúc High-value 
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


--tạo bảng gồm các sản phẩm có tỉ lệ reordered thấp.
select pd.product_name,count(*) as total_purchase,sum(o2.reordered) as total_reordered,cast(sum(cast(o2.reordered as int))as float) / count(*) as reorder_rate
into low_reordered_products
from products as pd
join order_products_prior_final as o2 on o2.product_id=pd.product_id
join orders as o1 on o1.order_id=o2.order_id
group by pd.product_name
having count(*)>=50 and (cast(sum(cast(o2.reordered as int))as float) / count(*))<0.05

select *
from low_reordered_products;