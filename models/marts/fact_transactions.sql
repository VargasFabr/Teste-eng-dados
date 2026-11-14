{{
    config(
        materialized='incremental',
        unique_key='transaction_id',
        incremental_strategy='delete+insert'
    )
}}

select
    transaction_id,
    client_id,
    asset_ticker,
    operation,
    quantity,
    unit_price,
    gross_amount,
    signed_quantity,
    signed_amount,
    transaction_date
from {{ ref('int_transactions') }}
{% if is_incremental() %}
where transaction_date > (select max(transaction_date) from {{ this }})
{% endif %}
