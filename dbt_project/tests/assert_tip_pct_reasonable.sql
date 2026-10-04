-- Outlier guard: tips above 200% of the fare are almost certainly data errors.
select trip_id from {{ ref('fact_trips') }} where tip_pct > 2
