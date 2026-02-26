{{ config(
    alias = 'unified_revenue',
    materialized = 'table'
) }}

with base as (
    select date, fee_type, token, usd_price, amount, usd_amount
    from {{ ref('product_revenue') }}
    union all
    select date, fee_type, token, usd_price, amount, usd_amount
    from {{ ref('staking_revenue') }}
),
aggregated as (
    select
        date,
        fee_type,
        sum(case when token in ('sol', 'wsol') then amount else 0 end) as sol_amount,
        max(case when token in ('sol', 'wsol') then usd_price end) as sol_price_usd,
        sum(case when token in ('sol', 'wsol') then usd_amount else 0 end) as sol_amount_usd,
        sum(case when token = 'usdc' then amount else 0 end) as usdc_amount,
        sum(usd_amount) as total_usd_amount 
    from base
    group by date, fee_type
)
select
    date,
    fee_type as type,
    sol_amount,
    sol_price_usd,
    sol_amount_usd,
    usdc_amount,
    total_usd_amount
from aggregated
