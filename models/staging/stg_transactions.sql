with typed as (
    select
        cast(transaction_id as varchar) as transaction_id,
        nullif(trim(cast(client_id as varchar)), '') as client_id,
        nullif(trim(cast(asset_ticker as varchar)), '') as asset_ticker,
        upper(trim(cast(operation as varchar))) as operation,
        try_cast(quantity as integer) as quantity,
        try_cast(unit_price as decimal(18, 2)) as unit_price,
        try_cast(transaction_date as date) as transaction_date
    from {{ ref('transactions') }}
),

valid as (
    select
        transaction_id,
        client_id,
        asset_ticker,
        operation,
        quantity,
        unit_price,
        quantity * unit_price as gross_amount,
        transaction_date
    from typed
    where nullif(trim(transaction_id), '') is not null
        and client_id is not null
        and asset_ticker is not null
        and operation in ('BUY', 'SELL')
        and quantity > 0
        and unit_price > 0
        and transaction_date is not null
),

deduped as (
    select
        *,
        row_number() over (
            partition by
                client_id,
                asset_ticker,
                operation,
                quantity,
                unit_price,
                transaction_date
            order by transaction_id
        ) as _rn
    from valid
)

select
    transaction_id,
    client_id,
    asset_ticker,
    operation,
    quantity,
    unit_price,
    gross_amount,
    transaction_date
from deduped
where _rn = 1
