{{
    config(
        alias = 'product_revenue',
        materialized = 'incremental',
        incremental_strategy = 'merge',
        unique_key = ['date', 'fee_type', 'fee_source', 'token']
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
mapping(address, fee_type, fee_source, token) as (
    values
        ('3hVztnGsAWjBs8uKAA4eZ1PSXjun74AAp11BdmeTMgXy', 'swap', 'unknown', 'usdc'),
        ('595S5w2SypCZ9c7ELkzp1LUQXG2sMg64d6xLLPrSiyJc', 'swap', 'unknown', 'wsol'),
        ('E8ehoZBHw4C7CAaDi5FrLk6nzgBaMNPyW6FZsRq3Tnqc', 'swap', 'unknown', 'weth'),
        ('BEochrdGhm5pcKVF73DURYrGo1DLzxq6bBcUBphQR64d', 'swap', 'okx', 'sol'),
        ('AZhGu7kfjbQfcZZWfYv4PicgM5KzvLPnSYNU71azG4J6', 'swap', 'okx', 'usdc'),
        ('9HwskvHcuTTLZd2B85F81q24Bv6E3Sk6rmZMBAJ6PpZG', 'swap', 'okx', 'wsol'),
        ('MhjVAk6qoWp3wirworqRi6YmBh54ZffYMSoYvZwMsTT', 'limit_order', 'unknown', 'usdc'),
        ('CrjqJupka2obZTzMuELd8ks4JqKDW7TzifrqRyBbzzjE', 'limit_order', 'unknown', 'wsol'),
        ('GHTBuM2wLKvw7ZTsJfZiHoWfdbPsUadgM1dtVhQiQWG8', 'bridge', 'unknown', 'usdc'),
        ('pJjzLvBrMhmyU9mu3ERn7DbMuwwizAch6HXK9wnHqk8', 'bridge', 'unknown', 'sol'),
        ('4dNMXwbUtKYspnD7tdHLwiVnBNoVZW7QdSwbTKREXVMv', 'bonfida', 'unknown', 'usdc'),
        ('2GVfr38GBK2XHd8wQmCMZgvRDnrV9qG9i59u7a44wBWL', 'instant_unstake', 'external', 'sol'),
        ('5PxxoU93A4KLr23rXvYrYMFZDAw5DY8XZiyX6NsW7Hkk', 'instant_unstake', 'rfq', 'sol'),
        ('7YEpZWGgQNWudS67wRYxC87YVXz6yDajrs6CVTVFbxQB', 'nft_instant_sell', 'unknown', 'sol'),
        ('FejFMFmfbJr7NPnNmCb6vFGrMZnzxeeMS1g8sFksFirm', 'solscout', 'unknown', 'sol'),
        ('6d9zMJ5j6VK9ZLjHWQswq9DrvWTnfe9YeqEempd9fzpj', 'solscout', 'unknown', 'sol'),
        ('39LjEaG6LUaRCddeXx1NYS8Djy58VVEtVhynLQ4Q4nfz', 'solscout', 'unknown', 'sol'),
        ('HdKmzpebfWMRCtyfWo2Fpt7PmMRR6cg5Fq3352JaHM6z', 'solscout', 'unknown', 'sol'),
        ('AviyuP6C5ag7wGshX9vQo5VPgtrRHfSCQA5inWUu6mVd', 'solscout', 'unknown', 'sol'),
        ('6ijs7wp1AVJHY7fA1jt2vqHRZ3u6QSce36o2hXp1Fmky', 'solscout', 'unknown', 'sol'),
        ('GWGAtRPdEFhWZkU1Yg33GKrQcTZEME4AB5cP98K94y1T', 'solscout', 'unknown', 'sol'),
        ('8W5zkeWVs6rWAicSaK7ixuUcDpXmjm5V4tPBPcsPPCyN', 'solscout', 'unknown', 'sol'),
        ('DaWsHBBT7GLCQ9PmsjFroCZT7urcEiPxykByC9tuv1Ry', 'solscout', 'unknown', 'sol'),
        ('Bjp2t7xg73yo5N7Do6zCMGKyKaKp62QnZsYmbSprrk5v', 'solscout', 'unknown', 'sol')
),
fees_raw as (
    select
        date_trunc('day', a.block_time) as date,
        m.fee_type,
        m.fee_source,
        m.token,
        case
            when m.fee_type = 'instant_unstake' and m.fee_source = 'rfq' and a.balance_change < 0
                then (abs(a.balance_change) / power(10, 9)) * 2.0 / 98.0
            when m.fee_type = 'instant_unstake' and m.fee_source = 'rfq'
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
            or (m.fee_type = 'instant_unstake' and m.fee_source = 'rfq' and a.balance_change < 0)
        )
)
select
    f.date,
    f.fee_type,
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
group by 1, 2, 3, 4, 5
