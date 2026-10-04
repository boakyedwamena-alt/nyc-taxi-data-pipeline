-- Does weather change demand or tipping?  Aggregate to hours first, then compare by weather.
with hourly as (

    select
        pickup_hour,
        count(*)                              as trips,
        avg(tip_pct)                          as avg_tip_pct,
        avg(fare_amount)                      as avg_fare
    from {{ ref('fact_trips') }}
    group by 1

)

select
    w.weather_category,
    count(*)                                           as hours_observed,
    round(avg(h.trips)::numeric, 0)                    as avg_trips_per_hour,
    round((avg(h.avg_tip_pct) * 100)::numeric, 2)      as avg_tip_pct,
    round(avg(h.avg_fare)::numeric, 2)                 as avg_fare
from hourly h
join {{ ref('dim_weather') }} w on w.weather_hour = h.pickup_hour
group by 1
