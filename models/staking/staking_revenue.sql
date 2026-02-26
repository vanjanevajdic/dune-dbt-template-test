{{ config(
    alias = 'staking_revenue',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date', 'fee_source']
) }}

with
{% if is_incremental() %}
cutoff as (
    select date_add('day', -{{ var('lookback_days') }}, max(date)) as d
    from {{ this }}
),
{% endif %}
native_scope as (
    select date, amount_sol
    from {{ ref('staking_native') }}
    {% if is_incremental() %}
    where date >= (select d from cutoff)
    {% endif %}
),
jito_scope as (
    select date, amount_sol
    from {{ ref('staking_jito') }}
    {% if is_incremental() %}
    where date >= (select d from cutoff)
    {% endif %}
),
staking_raw as (
    select date, 'native' as fee_source, amount_sol
    from native_scope
    union all
    select date, 'jito' as fee_source, amount_sol
    from jito_scope
),
prices as (
    select
        timestamp as date,
        avg(price) as price
    from prices.day
    where
        blockchain = 'solana'
        and symbol = 'SOL'
        {% if is_incremental() %}
        and timestamp >= (select d from cutoff)
        {% endif %}
    group by timestamp
)
select
    s.date,
    'staking' as fee_type,
    s.fee_source,
    'sol' as token,
    p.price as usd_price,
    s.amount_sol as amount,
    s.amount_sol * p.price as usd_amount
from staking_raw s
left join prices p on p.date = s.date
