{{ config(
    alias = 'unified_revenue',
    materialized = 'table'
) }}

select date, fee_source, token, usd_price, amount, usd_amount
from {{ ref('product_revenue_by_source_and_token') }}
union
select date, fee_source, token, usd_price, amount, usd_amount
from {{ ref('staking_revenue') }}
