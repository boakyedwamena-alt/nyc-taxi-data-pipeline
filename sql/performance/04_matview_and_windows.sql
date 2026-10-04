-- EXPERIMENT 4: materialized view vs querying the fact table, plus window functions / CTEs.

-- 4a. Pre-aggregate daily KPIs per zone
create materialized view if not exists marts.mv_daily_zone_kpis as
select pickup_date, pickup_zone_id, count(*) as trips,
       sum(total_amount) as revenue, avg(tip_pct) as avg_tip_pct
from marts.fact_trips
group by 1, 2;
create unique index if not exists idx_mv_daily_zone on marts.mv_daily_zone_kpis (pickup_date, pickup_zone_id);
-- refresh without blocking readers:
refresh materialized view concurrently marts.mv_daily_zone_kpis;

explain (analyze) select * from marts.mv_daily_zone_kpis where pickup_date = '2024-01-15';
explain (analyze) select pickup_date, pickup_zone_id, count(*) from marts.fact_trips
 where pickup_date = '2024-01-15' group by 1, 2;

-- 4b. Top 3 pickup zones per borough per day (CTE + RANK window function)
with daily as (
    select k.pickup_date, z.borough, z.zone_name, k.trips
    from marts.mv_daily_zone_kpis k
    join marts.dim_zone z on z.zone_id = k.pickup_zone_id
), ranked as (
    select *, rank() over (partition by pickup_date, borough order by trips desc) as rnk
    from daily
)
select * from ranked where rnk <= 3 order by pickup_date, borough, rnk;

-- 4c. 7-day moving average of daily trips (frame clause)
select pickup_date,
       sum(trips) as trips,
       round(avg(sum(trips)) over (order by pickup_date rows between 6 preceding and current row), 0) as trips_7d_avg
from marts.mv_daily_zone_kpis
group by pickup_date
order by pickup_date;
