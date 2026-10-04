-- Demand by pickup zone and hour of day (feeds the "peak demand" dashboard page).
select
    z.zone_id,
    z.borough,
    z.zone_name,
    extract(hour from f.pickup_datetime)::int  as hour_of_day,
    d.is_weekend,
    count(*)                                   as trips,
    round(avg(f.fare_amount)::numeric, 2)      as avg_fare,
    round(avg(f.trip_distance)::numeric, 2)    as avg_distance_miles
from {{ ref('fact_trips') }} f
join {{ ref('dim_zone') }} z on z.zone_id = f.pickup_zone_id
join {{ ref('dim_date') }} d on d.date_id = f.pickup_date
group by 1, 2, 3, 4, 5
