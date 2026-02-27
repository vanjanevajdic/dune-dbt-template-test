{{ config(
    alias = 'epoch_info',
    materialized = 'incremental',
    incremental_strategy = 'merge',
    unique_key = ['epoch']
) }}

-- Epoch numbering: full refresh uses offset + row_number(); incremental continues from max(epoch).
-- staking_epoch_offset: Solana epoch of the first Voting reward in the data (default 132; override in dbt_project vars or --vars).
{% set epoch_offset = var('staking_epoch_offset', 132) %}

with voting_rewards as (
    select block_time
    from {{ source('solana', 'rewards') }}
    where reward_type = 'Voting'
    {% if is_incremental() %}
        and block_time > (select max(epoch_end_time) from {{ this }})
    {% endif %}
    group by block_time
),
numbered as (
    select
        block_time,
        row_number() over (order by block_time asc) as rn
    from voting_rewards
)
select
    {% if is_incremental() %}
    (select coalesce(max(epoch), 0) from {{ this }}) + rn as epoch,
    {% else %}
    {{ epoch_offset }} + rn as epoch,
    {% endif %}
    block_time as epoch_end_time,
    date_trunc('day', block_time) as date
from numbered
order by block_time asc
