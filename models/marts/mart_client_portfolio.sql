select
    client_id,
    asset_ticker,
    sum(case when operation = 'BUY' then quantity else 0 end) as buy_quantity,
    sum(case when operation = 'SELL' then quantity else 0 end) as sell_quantity,
    sum(case when operation = 'BUY' then gross_amount else 0 end) as buy_amount,
    sum(case when operation = 'SELL' then gross_amount else 0 end) as sell_amount,
    sum(signed_quantity) as net_quantity,
    sum(signed_amount) as net_amount
from {{ ref('int_transactions') }}
group by client_id, asset_ticker
