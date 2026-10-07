-- Does weather affect demand once time of day is held constant?

-- 1. Share of each weather type's hours that fall between midnight and 6 am
select
    weather_category,
    count(*) as hours,
    round(100.0 * count(*) filter (where extract(hour from weather_hour) < 6) / count(*), 1)
        as pct_hours_midnight_to_6am
from marts.dim_weather
group by 1
order by 1;

-- 2. Average trips per hour for 5-8 pm hours only, by weather type
with h as (
    select pickup_hour, count(*) as trips
    from marts.fact_trips
    group by 1
)
select
    w.weather_category,
    count(*) as hours,
    round(avg(h.trips)) as avg_trips_5_to_8pm
from h
join marts.dim_weather w on w.weather_hour = h.pickup_hour
where extract(hour from h.pickup_hour) between 17 and 19
group by 1
order by 1;
