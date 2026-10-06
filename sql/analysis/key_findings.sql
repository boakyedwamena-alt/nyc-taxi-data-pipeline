-- Queries behind the "Key findings" section of the README.
-- Run with: docker compose exec -T postgres psql -U taxi -d taxi -f /path/or/paste

-- 1. Busiest two hours, averaged per day (weekday vs weekend)
select *
from (
    select
        d.is_weekend,
        extract(hour from f.pickup_datetime)::int as hr,
        round(count(*)::numeric / count(distinct f.pickup_date)) as avg_trips_per_day,
        row_number() over (
            partition by d.is_weekend
            order by count(*)::numeric / count(distinct f.pickup_date) desc
        ) as rn
    from marts.fact_trips f
    join marts.dim_date d on d.date_id = f.pickup_date
    group by 1, 2
) t
where rn <= 2
order by is_weekend, rn;

-- 2. Top 5 pickup zones
select borough, zone_name, sum(trips) as trips
from marts.mart_hourly_zone_demand
group by 1, 2
order by 3 desc
limit 5;

-- 3. Weather impact on demand and tipping
select * from marts.mart_weather_impact order by avg_trips_per_hour desc;

-- 4. Monthly revenue with month-over-month change
select source_month, trips, revenue, avg_fare, revenue_mom_pct
from marts.mart_monthly_revenue
order by 1;

-- 5. Rows rejected by the validity rules
select * from marts.mart_data_quality order by source_month;

-- 6. Early-morning demand (midnight to 4 am), weekday vs weekend, averaged per day
select
    extract(hour from f.pickup_datetime)::int as hr,
    d.is_weekend,
    round(count(*)::numeric / count(distinct f.pickup_date)) as avg_trips_per_day
from marts.fact_trips f
join marts.dim_date d on d.date_id = f.pickup_date
where extract(hour from f.pickup_datetime) in (0, 1, 2, 3)
group by 1, 2
order by 1, 2;
