{{ config(
    alias = 'staking_revenue',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date']
) }}

with
n_scope as (
    select date, amount_sol
    from {{ ref('staking_native') }}
    {% if is_incremental() %}
    where date >= (select date_add('day', -{{ var('lookback_days') }}, max(date)) from {{ this }})
    {% endif %}
),
j_scope as (
    select date, amount_sol
    from {{ ref('staking_jito') }}
    {% if is_incremental() %}
    where date >= (select date_add('day', -{{ var('lookback_days') }}, max(date)) from {{ this }})
    {% endif %}
),
staking_raw as (
    select
        coalesce(n.date, j.date) as date,
        coalesce(n.amount_sol, 0) + coalesce(j.amount_sol, 0) as amount
    from n_scope n
    full outer join j_scope j on j.date = n.date
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
        and timestamp >= (
            select date_add('day', -{{ var('lookback_days') }}, max(date))
            from {{ this }}
        )
        {% endif %}
    group by 1
)
select
    s.date,
    'staking' as fee_source,
    'sol' as token,
    p.price as usd_price,
    s.amount,
    s.amount * p.price as usd_amount
from staking_raw s
left join prices p on p.date = s.date
