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

-- 3. Same 5-8 pm comparison split by month, so seasonal demand differences are removed
with h as (
    select pickup_hour, count(*) as trips
    from marts.fact_trips
    group by 1
)
select
    to_char(w.weather_hour, 'YYYY-MM') as month,
    w.weather_category,
    count(*) as hours,
    round(avg(h.trips)) as avg_trips_5_to_8pm
from h
join marts.dim_weather w on w.weather_hour = h.pickup_hour
where extract(hour from h.pickup_hour) between 17 and 19
group by 1, 2
order by 1, 2;

-- 4. Rainy 5-8 pm evenings, one row per day, with weekend flag
with h as (
    select pickup_hour, count(*) as trips
    from marts.fact_trips
    group by 1
)
select
    h.pickup_hour::date as day,
    dd.is_weekend,
    count(*) as rain_hours,
    round(avg(h.trips)) as avg_trips
from h
join marts.dim_weather w on w.weather_hour = h.pickup_hour
join marts.dim_date dd on dd.date_id = h.pickup_hour::date
where w.weather_category = 'Rain'
  and extract(hour from h.pickup_hour) between 17 and 19
group by 1, 2
order by 1;

-- 5. Weekday-only 5-8 pm comparison by month and weather type
with h as (
    select pickup_hour, count(*) as trips
    from marts.fact_trips
    group by 1
)
select
    to_char(w.weather_hour, 'YYYY-MM') as month,
    w.weather_category,
    count(*) as hours,
    round(avg(h.trips)) as avg_trips
from h
join marts.dim_weather w on w.weather_hour = h.pickup_hour
join marts.dim_date dd on dd.date_id = h.pickup_hour::date
where not dd.is_weekend
  and extract(hour from h.pickup_hour) between 17 and 19
group by 1, 2
order by 1, 2;

-- 6. Freezing hours by month (do freezing hours cluster in the quieter months?)
select
    to_char(weather_hour, 'YYYY-MM') as month,
    count(*) filter (where weather_category = 'Freezing (0C-)') as freezing_hours,
    count(*) as hours
from marts.dim_weather
group by 1
order by 1;
