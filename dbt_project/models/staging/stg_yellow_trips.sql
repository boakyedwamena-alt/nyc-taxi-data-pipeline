-- Typed, renamed trips + derived metrics + a validity flag.
-- Invalid rows are flagged (not silently dropped) so rejection rates stay auditable.
with typed as (

    select
        md5(concat_ws('|', vendor_id, pickup_datetime, dropoff_datetime,
                      pu_location_id, do_location_id, fare_amount, total_amount,
                      trip_distance))                                  as trip_id,
        vendor_id,
        pickup_datetime,
        dropoff_datetime,
        passenger_count,
        trip_distance,
        pu_location_id                                                 as pickup_zone_id,
        do_location_id                                                 as dropoff_zone_id,
        coalesce(payment_type, 5)                                      as payment_type_id,
        fare_amount,
        tip_amount,
        tolls_amount,
        total_amount,
        coalesce(congestion_surcharge, 0)                              as congestion_surcharge,
        coalesce(airport_fee, 0)                                       as airport_fee,
        round((extract(epoch from (dropoff_datetime - pickup_datetime)) / 60.0)::numeric, 2)
                                                                       as trip_minutes,
        source_month
    from {{ source('raw', 'yellow_trips') }}

)

select
    *,
    coalesce(
        fare_amount > 0
        and total_amount > 0
        and trip_distance between 0.1 and 200
        and trip_minutes between 1 and 360
        and tip_amount <= 2 * fare_amount
        and to_char(pickup_datetime, 'YYYY-MM') = source_month
        and pickup_zone_id is not null
        and dropoff_zone_id is not null,
        false
    ) as is_valid
from typed
