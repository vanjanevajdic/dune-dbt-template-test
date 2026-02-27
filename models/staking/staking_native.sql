{{ config(
    alias = 'staking_native',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['date']
) }}

select
    date_trunc('day', block_time) as date,
    sum(lamports) / power(10, 9) as amount_sol
from {{ source('solana', 'rewards') }}
where
    recipient in (
        '722RdWmHC5TGXBjTejzNjbc8xEiduVDLqZvoUGz6Xzbp', -- solflare validator identity key
        'EXhYxF25PJEHb3v5G1HY8Jn8Jm7bRjJtaxEghGrUuhQw' -- solflare validator vote key
    )
    and reward_type in ('Fee', 'Rent', 'Voting')
    and block_time >= timestamp '{{ var("start_date") }}'
    {% if is_incremental() %}
    and block_time >= (
        select date_add('day', -{{ var('lookback_days') }}, max(date))
        from {{ this }}
    )
    {% endif %}
group by date_trunc('day', block_time)
