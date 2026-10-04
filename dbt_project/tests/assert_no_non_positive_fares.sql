-- Fails if any invalid fare slipped into the fact table.
select trip_id from {{ ref('fact_trips') }} where fare_amount <= 0 or total_amount <= 0
