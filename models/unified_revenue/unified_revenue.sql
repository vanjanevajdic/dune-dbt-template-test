{{ config(
    alias = 'unified_revenue',
    materialized = 'table'
) }}

select date, fee_type, fee_source, token, usd_price, amount, usd_amount
from {{ ref('product_revenue') }}
union
select date, fee_type, fee_source, token, usd_price, amount, usd_amount
from {{ ref('staking_revenue') }}
