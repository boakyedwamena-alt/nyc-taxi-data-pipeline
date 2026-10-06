-- Investigation: what drove the increase in trips from February to March 2024?
-- Always compare per-day figures, because February 2024 has 29 days and March has 31.

-- A. Monthly profile: volume, fare, distance, duration, passengers
select
    source_month,
    count(*) as trips,
    count(distinct pickup_date) as days,
    round(count(*)::numeric / count(distinct pickup_date)) as trips_per_day,
    round(avg(fare_amount)::numeric, 2) as avg_fare,
    round(avg(trip_distance)::numeric, 2) as avg_miles,
    round(avg(trip_minutes)::numeric, 1) as avg_minutes,
    round(avg(passenger_count)::numeric, 2) as avg_passengers
from marts.fact_trips
group by 1
order by 1;

-- B. Weekday vs weekend growth
select
    f.source_month,
    d.is_weekend,
    round(count(*)::numeric / count(distinct f.pickup_date)) as trips_per_day
from marts.fact_trips f
join marts.dim_date d on d.date_id = f.pickup_date
group by 1, 2
order by 1, 2;

-- C. Zones that added the most trips per day, February to March
with z as (
    select pickup_zone_id, source_month,
           count(*)::numeric / count(distinct pickup_date) as per_day
    from marts.fact_trips
    where source_month in ('2024-02', '2024-03')
    group by 1, 2
), p as (
    select pickup_zone_id,
           max(per_day) filter (where source_month = '2024-02') as feb,
           max(per_day) filter (where source_month = '2024-03') as mar
    from z
    group by 1
)
select d.borough, d.zone_name, round(feb) as feb_per_day,
       round(mar) as mar_per_day, round(mar - feb) as added
from p
join marts.dim_zone d on d.zone_id = p.pickup_zone_id
order by mar - feb desc nulls last
limit 10;

-- D. Weekly trips: sudden step or gradual rise?
select date_trunc('week', pickup_date)::date as week_start, count(*) as trips
from marts.fact_trips
where pickup_date between '2024-02-01' and '2024-03-31'
group by 1
order by 1;

-- E. Monthly weather context
select
    to_char(weather_hour, 'YYYY-MM') as month,
    round(avg(temperature_c)::numeric, 1) as avg_temp_c,
    round(sum(precipitation_mm)::numeric) as total_rain_mm,
    round(sum(snowfall_cm)::numeric) as total_snow_cm
from marts.dim_weather
group by 1
order by 1;

-- F. Within-month correlation between daily temperature and weekday trips.
-- Deviations from each month's mean remove the seasonal trend, isolating the weather effect.
with d as (
    select f.pickup_date as dt, count(*) as trips
    from marts.fact_trips f
    join marts.dim_date dd on dd.date_id = f.pickup_date
    where not dd.is_weekend
    group by 1
), w as (
    select weather_hour::date as dt, avg(temperature_c) as temp
    from marts.dim_weather
    group by 1
), j as (
    select
        d.dt,
        d.trips - avg(d.trips) over (partition by date_trunc('month', d.dt)) as trips_dev,
        w.temp - avg(w.temp) over (partition by date_trunc('month', d.dt)) as temp_dev
    from d
    join w on w.dt = d.dt
)
select round(corr(trips_dev, temp_dev)::numeric, 2) as within_month_corr, count(*) as days
from j;
