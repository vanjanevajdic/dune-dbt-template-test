{{ 
    config(
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['date', 'fee_source', 'token']
    ) 
}}


with
prices as (
    select
        timestamp as date,
        lower(symbol) as token,
        avg(price) as price
    from prices.day
    where
        blockchain = 'solana'
        and symbol in ('SOL', 'WETH')
        and timestamp >= timestamp '{{ var("start_date") }}'
        {% if is_incremental() %}
        and timestamp >= (
            select date_add('day', -{{ var("lookback_days") }}, max(date))
            from {{ this }}
        )
        {% endif %}
    group by 1, 2
),
mapping(address, fee_source, token) as (
    values
        ('3hVztnGsAWjBs8uKAA4eZ1PSXjun74AAp11BdmeTMgXy', 'swap', 'usdc'),
        ('595S5w2SypCZ9c7ELkzp1LUQXG2sMg64d6xLLPrSiyJc', 'swap', 'wsol'),
        ('E8ehoZBHw4C7CAaDi5FrLk6nzgBaMNPyW6FZsRq3Tnqc', 'swap', 'weth'),
        ('BEochrdGhm5pcKVF73DURYrGo1DLzxq6bBcUBphQR64d', 'swap_okx', 'sol'),
        ('AZhGu7kfjbQfcZZWfYv4PicgM5KzvLPnSYNU71azG4J6', 'swap_okx', 'usdc'),
        ('9HwskvHcuTTLZd2B85F81q24Bv6E3Sk6rmZMBAJ6PpZG', 'swap_okx', 'wsol'),
        ('MhjVAk6qoWp3wirworqRi6YmBh54ZffYMSoYvZwMsTT', 'limit_order', 'usdc'),
        ('CrjqJupka2obZTzMuELd8ks4JqKDW7TzifrqRyBbzzjE', 'limit_order', 'wsol'),
        ('GHTBuM2wLKvw7ZTsJfZiHoWfdbPsUadgM1dtVhQiQWG8', 'bridge', 'usdc'),
        ('pJjzLvBrMhmyU9mu3ERn7DbMuwwizAch6HXK9wnHqk8', 'bridge', 'sol'),
        ('4dNMXwbUtKYspnD7tdHLwiVnBNoVZW7QdSwbTKREXVMv', 'bonfida', 'usdc'),
        ('2GVfr38GBK2XHd8wQmCMZgvRDnrV9qG9i59u7a44wBWL', 'instant_unstake', 'sol'),
        ('5PxxoU93A4KLr23rXvYrYMFZDAw5DY8XZiyX6NsW7Hkk', 'instant_unstake_rfq', 'sol'),
        ('7YEpZWGgQNWudS67wRYxC87YVXz6yDajrs6CVTVFbxQB', 'nft_instant_sell', 'sol'),
        ('FejFMFmfbJr7NPnNmCb6vFGrMZnzxeeMS1g8sFksFirm', 'solscout', 'sol'),
        ('6d9zMJ5j6VK9ZLjHWQswq9DrvWTnfe9YeqEempd9fzpj', 'solscout', 'sol'),
        ('39LjEaG6LUaRCddeXx1NYS8Djy58VVEtVhynLQ4Q4nfz', 'solscout', 'sol'),
        ('HdKmzpebfWMRCtyfWo2Fpt7PmMRR6cg5Fq3352JaHM6z', 'solscout', 'sol'),
        ('AviyuP6C5ag7wGshX9vQo5VPgtrRHfSCQA5inWUu6mVd', 'solscout', 'sol'),
        ('6ijs7wp1AVJHY7fA1jt2vqHRZ3u6QSce36o2hXp1Fmky', 'solscout', 'sol'),
        ('GWGAtRPdEFhWZkU1Yg33GKrQcTZEME4AB5cP98K94y1T', 'solscout', 'sol'),
        ('8W5zkeWVs6rWAicSaK7ixuUcDpXmjm5V4tPBPcsPPCyN', 'solscout', 'sol'),
        ('DaWsHBBT7GLCQ9PmsjFroCZT7urcEiPxykByC9tuv1Ry', 'solscout', 'sol'),
        ('Bjp2t7xg73yo5N7Do6zCMGKyKaKp62QnZsYmbSprrk5v', 'solscout', 'sol')
),
fees_raw as (
    select
        date_trunc('day', a.block_time) as date,
        m.fee_source,
        m.token,
        case
            when m.fee_source = 'instant_unstake_rfq' and a.balance_change < 0
                then (abs(a.balance_change) / power(10, 9)) * 2.0 / 98.0
            when m.fee_source = 'instant_unstake_rfq'
                then 0
            when m.token = 'sol'
                then a.balance_change / power(10, 9)
            else a.token_balance_change
        end as raw_amount
    from solana.account_activity a
    join mapping m on a.address = m.address
    where
        a.block_time >= timestamp '{{ var("start_date") }}'
        {% if is_incremental() %}
        and a.block_time >= (
            select date_add('day', -{{ var("lookback_days") }}, max(date))
            from {{ this }}
        )
        {% endif %}
        and a.tx_success = true
        and not (
            m.token = 'weth'
            and a.block_time >= timestamp '2024-03-11 00:00:00'
        )
        and (
            (m.token != 'sol' and a.token_balance_change > 0)
            or (m.token = 'sol' and a.balance_change > 0)
            or (m.fee_source = 'instant_unstake_rfq' and a.balance_change < 0)
        )
)
select
    f.date,
    f.fee_source,
    f.token,
    p.price as usd_price,
    sum(f.raw_amount) as amount,
    case
        when f.token = 'usdc' then sum(f.raw_amount)
        else sum(f.raw_amount) * p.price
    end as usd_amount
from fees_raw f
left join prices p
    on (
        (f.token = p.token)
        or (f.token = 'wsol' and p.token = 'sol')
    )
    and f.date = p.date
group by 1, 2, 3, 4