-- EXPERIMENT 2: indexing strategy on the flat table (compare with Experiment 1).

-- 2a. B-tree on the filter column
create index idx_flat_pickup_btree on perf.trips_flat (pickup_datetime);
analyze perf.trips_flat;
explain (analyze, buffers)
select pu_location_id, count(*) as trips, round(avg(fare_amount)::numeric, 2) as avg_fare
from perf.trips_flat
where pickup_datetime >= '2024-01-15' and pickup_datetime < '2024-01-16'
group by 1 order by trips desc limit 10;

-- 2b. BRIN: tiny index that works well because rows are roughly time-ordered on disk
drop index perf.idx_flat_pickup_btree;
create index idx_flat_pickup_brin on perf.trips_flat using brin (pickup_datetime);
analyze perf.trips_flat;
explain (analyze, buffers)
select pu_location_id, count(*) as trips, round(avg(fare_amount)::numeric, 2) as avg_fare
from perf.trips_flat
where pickup_datetime >= '2024-01-15' and pickup_datetime < '2024-01-16'
group by 1 order by trips desc limit 10;

-- 2c. Compare index sizes (a key trade-off: speed vs storage / write cost)
select indexrelname, pg_size_pretty(pg_relation_size(indexrelid)) as size
from pg_stat_user_indexes where schemaname = 'perf';

-- 2d. Covering index -> index-only scan for a zone-level aggregate
create index idx_flat_zone_cover on perf.trips_flat (pu_location_id) include (fare_amount);
vacuum analyze perf.trips_flat;
explain (analyze, buffers)
select pu_location_id, avg(fare_amount) from perf.trips_flat group by 1;
