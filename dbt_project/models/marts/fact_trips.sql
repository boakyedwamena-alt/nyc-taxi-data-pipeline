{{
    config(
        materialized='incremental',
        unique_key='trip_id',
        incremental_strategy='delete+insert',
        on_schema_change='sync_all_columns',
        post_hook=[
            "create index if not exists idx_fact_trips_trip_id on {{ this }} (trip_id)",
            "create index if not exists idx_fact_trips_pickup_hour on {{ this }} (pickup_hour)",
            "create index if not exists idx_fact_trips_zone_date on {{ this }} (pickup_zone_id, pickup_date)"
        ]
    )
}}

-- Incremental: re-process the latest loaded month and any newer months; dedupe on trip_id.
with ranked as (

    select
        *,
        row_number() over (partition by trip_id order by pickup_datetime) as rn
    from {{ ref('stg_yellow_trips') }}
    where is_valid
    {% if is_incremental() %}
      and source_month >= (select max(source_month) from {{ this }})
    {% endif %}

)

select
    trip_id,
    pickup_datetime,
    dropoff_datetime,
    date_trunc('hour', pickup_datetime)                          as pickup_hour,
    pickup_datetime::date                                        as pickup_date,
    pickup_zone_id,
    dropoff_zone_id,
    payment_type_id,
    passenger_count,
    trip_distance,
    trip_minutes,
    fare_amount,
    tip_amount,
    tolls_amount,
    total_amount,
    case when payment_type_id = 1 and fare_amount > 0
         then round((tip_amount / fare_amount)::numeric, 4) end  as tip_pct,
    round((trip_distance / nullif(trip_minutes / 60.0, 0))::numeric, 1) as avg_speed_mph,
    source_month
from ranked
where rn = 1
