{{ config(
    alias = 'staking_jito',
    materialized = 'view'
) }}

with api_response as (
    select
        cast(json_extract_scalar(data, '$.epoch') as integer) as epoch,
        cast(json_extract_scalar(data, '$.mev_commission_bps') as double) as mev_commission_bps,
        cast(json_extract_scalar(data, '$.mev_rewards') as double) as mev_rewards,
        cast(json_extract_scalar(data, '$.priority_fee_commission_bps') as double) as priority_fee_commission_bps,
        cast(json_extract_scalar(data, '$.priority_fee_rewards') as double) as priority_fee_rewards
    from unnest(
        cast(
            json_parse(http_get('https://kobe.mainnet.jito.network/api/v1/validators/EXhYxF25PJEHb3v5G1HY8Jn8Jm7bRjJtaxEghGrUuhQw'))
            as array(json)
        )
    ) as data(data)
),
epoch_info as (
    select epoch, date
    from {{ ref('epoch_info') }}
)
select
    ei.date,
    sum(
        (api.mev_rewards * api.mev_commission_bps / 10000) / power(10, 9)
    ) as amount_sol
from api_response api
join epoch_info ei on ei.epoch = api.epoch
group by ei.date
