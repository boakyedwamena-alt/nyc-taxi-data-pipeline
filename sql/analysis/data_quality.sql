-- What kinds of bad distances were rejected? (reads the staging layer, which keeps all raw rows)
select
    source_month,
    count(*) filter (where trip_distance < 0) as negative,
    count(*) filter (where trip_distance = 0) as zero_miles,
    count(*) filter (where trip_distance > 0 and trip_distance < 0.1) as under_0_1_miles,
    count(*) filter (where trip_distance > 200) as over_200_miles
from staging.stg_yellow_trips
group by 1
order by 1;

-- Do zero-mile trips look like real paid trips?
select
    count(*) as zero_mile_trips,
    count(*) filter (where fare_amount > 0) as with_positive_fare,
    round(avg(fare_amount) filter (where fare_amount > 0)::numeric, 2) as avg_fare_when_positive,
    round(avg(trip_minutes)::numeric, 1) as avg_minutes
from staging.stg_yellow_trips
where trip_distance = 0;
