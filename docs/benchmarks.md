# Performance benchmarks

Environment: Windows 11 Pro, Intel Core i5-8265U (4 cores), 8 GB RAM, Docker Desktop 4.93, PostgreSQL 16 (Docker), 12.5M trip rows (Jan-Apr 2024).
Timings are "Execution Time" from `EXPLAIN (ANALYZE, BUFFERS)`; each query was run once.

| # | Experiment | Query | Time (ms) | Result |
|---|-----------|-------|-----------|--------|
| 1 | Baseline: plain table, no index | Pickups by zone, one day | 16,446 | full table scan |
| 2a | B-tree index on pickup_datetime | same | 237 | 69x faster than baseline |
| 2b | BRIN index on pickup_datetime | same | 771 | 21x faster than baseline |
| 3a | List-partitioned table | Trips by zone, one month | 2,046 | 1.9x faster than 3b |
| 3b | Plain table | same | 3,961 | |
| 4a | Materialized view | Daily KPIs, one day | 0.18 | ~9,500x faster than 4b |
| 4b | Live query on fact table | same | 1,682 | |

## Takeaways
- A B-tree index on the filter column cut a one-day query from 16.4 s to 0.24 s (69x).
  BRIN also helped but was about 3x slower than B-tree here. A likely reason is that rows
  inside each monthly file are not perfectly sorted by pickup time, which BRIN relies on.
- Partitioning by month let Postgres skip the other months and read only one, making the
  query 1.9x faster. It also makes loading and dropping a month cheap, which is why the
  ingestion reloads a single partition.
- A materialized view turned a 1.7 s aggregation into a 0.18 ms lookup. The trade-off is
  that the view must be refreshed after each load and can be out of date between refreshes.
- Limitations: single runs on one machine, so the first query includes cold-cache effects.
  Treat the ratios as indicative, not exact.