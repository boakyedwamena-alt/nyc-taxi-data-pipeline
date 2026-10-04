-- EXPERIMENT 1: baseline. An unpartitioned, unindexed copy of the raw trips.
-- Run:  make psql   then   \i /path/or paste.   Adjust dates to months you have loaded.
create schema if not exists perf;
drop table if exists perf.trips_flat;
create table perf.trips_flat as select * from raw.yellow_trips;
analyze perf.trips_flat;

-- Q1: pickups per zone for one day  -> record "Execution Time" in docs/benchmarks.md
explain (analyze, buffers)
select pu_location_id, count(*) as trips, round(avg(fare_amount)::numeric, 2) as avg_fare
from perf.trips_flat
where pickup_datetime >= '2024-01-15' and pickup_datetime < '2024-01-16'
group by 1
order by trips desc
limit 10;
