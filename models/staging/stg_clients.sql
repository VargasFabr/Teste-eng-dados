with typed as (
    select
        nullif(trim(cast(client_id as varchar)), '') as client_id,
        cast(name as varchar) as client_name,
        nullif(trim(cast(city as varchar)), '') as city,
        nullif(trim(cast(state as varchar)), '') as state,
        try_cast(created_at as date) as created_at
    from {{ ref('clients') }}
),

ranked as (
    select
        *,
        row_number() over (
            partition by client_id
            order by
                case when city is null then 1 else 0 end,
                created_at
        ) as _rn
    from typed
    where client_id is not null
)

select
    client_id,
    client_name,
    city,
    state,
    created_at
from ranked
where _rn = 1
