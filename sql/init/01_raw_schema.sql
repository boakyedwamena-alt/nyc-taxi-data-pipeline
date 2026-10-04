-- Raw layer: data exactly as ingested, plus lineage columns.
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS marts;

-- Trips are LIST-partitioned by source month (one partition per monthly file).
-- Re-loading a month = truncate that partition, then COPY (idempotent + fast).
CREATE TABLE IF NOT EXISTS raw.yellow_trips (
    vendor_id              integer,
    pickup_datetime        timestamp,
    dropoff_datetime       timestamp,
    passenger_count        integer,
    trip_distance          double precision,
    rate_code_id           integer,
    store_and_fwd_flag     text,
    pu_location_id         integer,
    do_location_id         integer,
    payment_type           integer,
    fare_amount            double precision,
    extra                  double precision,
    mta_tax                double precision,
    tip_amount             double precision,
    tolls_amount           double precision,
    improvement_surcharge  double precision,
    total_amount           double precision,
    congestion_surcharge   double precision,
    airport_fee            double precision,
    source_month           text NOT NULL,
    loaded_at              timestamptz NOT NULL DEFAULT now()
) PARTITION BY LIST (source_month);

CREATE TABLE IF NOT EXISTS raw.taxi_zones (
    location_id   integer PRIMARY KEY,
    borough       text,
    zone          text,
    service_zone  text
);

CREATE TABLE IF NOT EXISTS raw.weather_hourly (
    obs_time         timestamp NOT NULL,
    temperature_c    double precision,
    precipitation_mm double precision,
    snowfall_cm      double precision,
    wind_speed_kmh   double precision,
    source_month     text NOT NULL,
    loaded_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_weather_obs_time ON raw.weather_hourly (obs_time);

-- Pipeline run log (simple observability)
CREATE TABLE IF NOT EXISTS raw.ingestion_log (
    id          bigserial PRIMARY KEY,
    dataset     text NOT NULL,
    source_month text,
    rows_loaded bigint,
    loaded_at   timestamptz NOT NULL DEFAULT now()
);
