select
    t.transaction_id,
    t.client_id,
    t.asset_ticker,
    t.operation,
    t.quantity,
    t.unit_price,
    t.gross_amount,
    {{ signed_measure('t.operation', 't.quantity') }} as signed_quantity,
    {{ signed_measure('t.operation', 't.gross_amount') }} as signed_amount,
    t.transaction_date
from {{ ref('stg_transactions') }} as t
inner join {{ ref('stg_clients') }} as c
    on t.client_id = c.client_id
