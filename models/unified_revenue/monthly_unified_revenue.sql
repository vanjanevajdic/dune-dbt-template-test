{{ config(
    alias = 'monthly_unified_revenue',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['aggregated_date']
) }}

{{ aggregate_revenue_by_period('month') }}
