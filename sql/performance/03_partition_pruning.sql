-- EXPERIMENT 3: partition pruning. raw.yellow_trips is LIST-partitioned by source_month.
-- Look for "Seq Scan on yellow_trips_2024_01" ONLY (other partitions are pruned) in the plan.
explain (analyze, buffers)
select pu_location_id, count(*) as trips
from raw.yellow_trips
where source_month = '2024-01'
group by 1 order by trips desc limit 10;

-- Same logical query on the flat table (scans every month loaded):
explain (analyze, buffers)
select pu_location_id, count(*) as trips
from perf.trips_flat
where source_month = '2024-01'
group by 1 order by trips desc limit 10;

-- Maintenance win: dropping an old month is instant, vs a huge DELETE + VACUUM
-- alter table raw.yellow_trips detach partition raw.yellow_trips_2024_01;
