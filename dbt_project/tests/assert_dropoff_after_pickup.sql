select trip_id from {{ ref('fact_trips') }} where dropoff_datetime <= pickup_datetime
