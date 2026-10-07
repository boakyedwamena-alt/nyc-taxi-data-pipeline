# Data dictionary

## Sources
| Source | Provider | Grain | Refresh |
|---|---|---|---|
| Yellow taxi trips (Parquet) | NYC Taxi & Limousine Commission | 1 row per trip | monthly, ~2 month lag |
| Taxi zone lookup (CSV) | NYC TLC | 1 row per zone (265) | static |
| Hourly weather | Open-Meteo Historical Weather API | 1 row per hour | on demand |

## marts.fact_trips (grain: one valid trip)
| Column | Type | Description |
|---|---|---|
| trip_id | text | MD5 surrogate key over vendor, timestamps, zones, fare, total, distance |
| pickup_datetime / dropoff_datetime | timestamp | Local NYC time |
| pickup_hour | timestamp | Pickup truncated to hour; joins to `dim_weather.weather_hour` |
| pickup_date | date | Joins to `dim_date.date_id` |
| pickup_zone_id / dropoff_zone_id | int | FK to `dim_zone.zone_id` |
| payment_type_id | int | FK to `dim_payment` |
| passenger_count | int | Driver-entered |
| trip_distance | double | Miles |
| trip_minutes | numeric | Dropoff minus pickup |
| fare_amount, tip_amount, tolls_amount, total_amount | double | USD |
| tip_pct | numeric | tip / fare, **credit-card trips only** (cash tips are not recorded) |
| avg_speed_mph | numeric | distance / duration |
| source_month | text | Lineage: `YYYY-MM` of the source file |

## Validity rules (staging → fact)
A trip is kept only if: fare > 0, total > 0, 0.1 ≤ distance ≤ 200 miles, 1 ≤ duration ≤ 360 min, tip ≤ 2 × fare,
pickup date falls in the file's month, and both zones are present. Rejections are counted per month in
`marts.mart_data_quality`. The breakdown columns in `mart_data_quality` cover only the fare, duration and distance rules; other rules (tip, pickup month, missing zones) are counted in `rejected_rows` but not broken out, and a trip can break 
several rules.

## Dimensions
`dim_date` (calendar 2019-2027), `dim_zone` (borough / zone / service zone), `dim_payment`
(TLC payment codes), `dim_weather` (hourly temperature, precipitation, snowfall, wind + `weather_category`).

## Marts for analytics
`mart_hourly_zone_demand`, `mart_weather_impact`, `mart_monthly_revenue`, `mart_data_quality`.
