{% macro aggregate_revenue_by_period(period) %}
select
    date_trunc('{{ period }}', date) as aggregated_date,
    sum(case when token in ('sol', 'wsol') then amount else 0 end) as sol_amount,
    sum(case when token = 'weth' then amount else 0 end) as eth_amount,
    sum(case when token in ('sol', 'wsol') then usd_amount else 0 end) as sol_usd_amount,
    sum(case when token = 'weth' then usd_amount else 0 end) as eth_usd_amount,
    sum(case when token = 'usdc' then usd_amount else 0 end) as usdc_amount,
    sum(usd_amount) as total_usd_amount
from {{ ref('daily_revenue_by_source_and_token') }}
{% if is_incremental() %}
where
    date >= (
        select date_trunc('{{ period }}', date_add('day', -{{ var('lookback_days') }}, max(aggregated_date)))
        from {{ this }}
    )
{% endif %}
group by
    date_trunc('{{ period }}', date)
{% endmacro %}
