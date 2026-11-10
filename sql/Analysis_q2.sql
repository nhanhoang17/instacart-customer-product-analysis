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