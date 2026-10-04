-- Audit table: how many raw rows were rejected per month, and why.
select
    source_month,
    count(*)                                                    as raw_rows,
    count(*) filter (where is_valid)                            as valid_rows,
    count(*) filter (where not is_valid)                        as rejected_rows,
    round(100.0 * count(*) filter (where not is_valid) / count(*), 2) as rejected_pct,
    count(*) filter (where fare_amount <= 0)                    as non_positive_fare,
    count(*) filter (where trip_minutes not between 1 and 360)  as bad_duration,
    count(*) filter (where trip_distance not between 0.1 and 200) as bad_distance
from {{ ref('stg_yellow_trips') }}
group by 1
