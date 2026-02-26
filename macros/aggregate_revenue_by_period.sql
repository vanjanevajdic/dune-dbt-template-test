{% macro aggregate_revenue_by_period(period) %}
select
    date_trunc('{{ period }}', date) as aggregated_date,
    sum(sol_amount) as sol_amount,
    sum(sol_amount_usd) as sol_usd_amount,
    sum(usdc_amount) as usdc_amount,
    sum(total_usd_amount) as total_usd_amount
from {{ ref('unified_revenue') }}
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
