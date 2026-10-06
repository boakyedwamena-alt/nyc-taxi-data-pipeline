# NYC Taxi: Advanced Database & Data Engineering Pipeline
![CI](https://github.com/boakyedwamena-alt/nyc-taxi-data-pipeline/actions/workflows/ci.yml/badge.svg)

An end-to-end ELT pipeline that ingests public NYC taxi trips and weather data into PostgreSQL,
models them into a tested star schema with dbt, orchestrates everything with Airflow, and serves
insights through a Streamlit dashboard. The repo also documents the database performance work
(partitioning, indexing, materialized views) with `EXPLAIN ANALYZE` evidence.

> **Skills demonstrated:** Python ingestion · PostgreSQL (partitioning, indexing, window functions, CTEs,
> materialized views) · dimensional modelling · dbt (incremental models, tests) · Airflow ·
> Docker Compose · data quality · CI/CD (GitHub Actions) · analytics & storytelling

## Business questions
1. When and where is taxi demand highest?
2. How do rain, snow and temperature affect demand and tipping?
3. How are fares and revenue trending month over month?
4. How much raw data is invalid, and why?

## Key findings

![Dashboard](docs/dashboard.png)

Based on 12.57M valid yellow-taxi trips, January to April 2024.

- **Demand peaks in the evening.** Weekdays average 7,894 trips in the 6 pm hour, the busiest
  of the day. Weekends peak at 6,425 trips in the 5 pm hour, so the weekend peak is about 19%
  lower than the weekday peak. Figures are averaged per day, so weekdays are not inflated by
  there being more of them.
- **Pickups are concentrated in a few zones.** The top five zones (Midtown Center, Upper East
  Side South, Upper East Side North, JFK Airport and Midtown East) account for about 22% of all
  trips, and four of the five are in Manhattan. JFK is the only non-Manhattan zone in the top five.
- **Freezing hours and snow had fewer trips; rain did not.** Average trips per hour were 4,687
  in mild/dry weather, 4,743 in rain (about the same), 3,824 in snow (-18%) and 2,923 in freezing
  hours (-38%). Card tips stayed at about 24-25% of the fare in every category, so weather made
  no visible difference to tipping.
- **Revenue grew from winter into spring.** Monthly revenue was $78.0M in January and $78.6M in
  February, then jumped 21% to $95.3M in March and reached $95.7M in April. Trips rose about 19%
  from February to March, and the average fare rose from $18.46 to $19.43 over the four months.
- **About 3.8% of raw rows were rejected as invalid.** Rejection stayed between 3.3% and 4.4% each
  month. Among the most common problems were zero or negative fares and impossible trip durations.
  A tip-outlier test also caught 620 January trips with tips above 200% of the fare, which led
  to a new validation rule.

**Caveats:** this is four months of data, so the seasonal findings are indicative only. Weather
comes from a single point for all of NYC. Freezing hours probably fall mostly at night, so
part of the drop is likely the time of day and not the cold. Snow covers only 81 hours. The
analysis shows association, not cause.

## Business insights and recommendations

What the findings suggest for a taxi operator or fleet manager. These are hypotheses to test,
not proven causes (four months, one city, one weather point).

| Insight | Evidence | Suggested action |
|---|---|---|
| Demand is highest on weekday evenings | Weekdays average 7,894 trips in the 6 pm hour; weekends peak at 6,425 at 5 pm | Schedule the largest share of driver shifts for 5-7 pm on weekdays, and keep a smaller, earlier peak in mind for weekends |
| Demand is concentrated in a few zones | The top 5 zones make up about 22% of all trips; 4 of 5 are in Manhattan, and JFK is the only exception | Position vehicles and dispatch effort around Midtown, the Upper East Side and JFK first |
| Freezing weather and snow reduce trips; rain does not | 2,923 trips per hour when freezing (-38%) and 3,824 in snow (-18%), against 4,687 in mild weather; rain 4,743 | Plan for lower demand on freezing and snowy days. This data gives no reason to cut supply on rainy days |
| Revenue growth is mostly more trips, not higher fares | Trips per day rose about 11% from February to March (99,600 to 110,500) while the average fare rose about 4% ($18.39 to $19.13) | Treat volume as the main revenue driver and check what drove the March increase before forecasting from it |
| About 3.8% of reported trips are invalid | 500k of 13.1M raw rows rejected; zero or negative fares and impossible durations were among the causes | Validate fare and trip duration at the point of recording, so revenue figures are not distorted by bad records |

**Next questions worth testing:** average fare by zone (is JFK more valuable per trip?), demand
by hour in freezing weather separated from night-time, and whether the March jump repeats in
other years.

## Architecture

```mermaid
flowchart LR
    A[NYC TLC Parquet<br/>trip records] --> I
    B[TLC zone lookup CSV] --> I
    C[Open-Meteo<br/>weather API] --> I
    I[Python ingestion<br/>idempotent, batched COPY] --> R[(raw schema<br/>partitioned by month)]
    R --> S[dbt staging<br/>typing, flags, dedupe]
    S --> M[(marts schema<br/>star schema + analytics marts)]
    M --> D[Streamlit dashboard]
    AF{{Airflow DAG<br/>ingest → dbt run → dbt test}} -.orchestrates.-> I
    AF -.-> S
    CI[GitHub Actions<br/>ruff · pytest · dbt build] -.validates.-> S
```

Layers: **raw** (as loaded + lineage columns) → **staging** (typed views, validity flag) →
**marts** (`fact_trips`, `dim_*`, analytics marts). ERD: [docs/erd.md](docs/erd.md) ·
Data dictionary: [docs/data_dictionary.md](docs/data_dictionary.md).

Orchestration: the Airflow DAG runs ingest, then `dbt run`, then `dbt test`. Runs complete in roughly 40 minutes to 2 hours on an 8 GB laptop.

![Airflow DAG runs](docs/airflow_dag.png)

## Quick start

Requirements: Docker Desktop.

```bash
git clone https://github.com/boakyedwamena-alt/nyc-taxi-data-pipeline.git
cd nyc-taxi-data-pipeline
make up                         # Postgres + Airflow + dashboard
make pipeline MONTH=2024-01     # ingest -> dbt run -> dbt test
```

No `.env` file is needed: the Docker setup has working defaults. Copy `.env.example` to `.env` only if you want to change the database credentials.

**On Windows without `make`**, run these instead:

```bash
docker compose up -d --build
docker compose exec -T airflow python -m ingestion.ingest --month 2024-01
docker compose exec -T airflow bash -c "cd /opt/airflow/dbt_project && /opt/dbt_venv/bin/dbt run --profiles-dir ."
docker compose exec -T airflow bash -c "cd /opt/airflow/dbt_project && /opt/dbt_venv/bin/dbt test --profiles-dir ."
```

Once the containers have started, open these addresses **on your own machine** (they only work
while the project is running locally in Docker, because `localhost` means your own computer):

| Service | Address | Login |
|---|---|---|
| Dashboard | `http://localhost:8501` | none |
| Airflow | `http://localhost:8080` | admin / admin |
| Postgres | `localhost:5432` | taxi / taxi |

**Not running it yourself?** The dashboard and Airflow screenshots in this README show the
pipeline working: [dashboard](docs/dashboard.png) and [Airflow runs](docs/airflow_dag.png).

Load more months for richer trends: `make ingest MONTH=2024-02`, then `make dbt-run dbt-test`.
Or trigger the DAG for a given month from your terminal:

```bash
docker compose exec -T airflow bash -c "airflow dags trigger nyc_taxi_pipeline --conf '{\"month\": \"2024-02\"}'"
```

## Design decisions
- **Idempotent loads:** each month is a Postgres list partition; reloading truncates only that
  partition inside one transaction, so reruns never duplicate rows and failures roll back cleanly.
- **Fast ingestion:** the Parquet file is streamed in batches and loaded with `COPY`, not row inserts.
- **Auditable cleaning:** invalid trips are *flagged* in staging and counted in `mart_data_quality`
  instead of silently dropped.
- **Incremental fact table:** `fact_trips` uses dbt `delete+insert` on `trip_id`, reprocessing only the latest month onward.
- **Weather source:** Open-Meteo (no API key needed) in NYC local time to match TLC timestamps.
  Note: one weather point for the whole city is an approximation.

## Data quality
dbt tests: unique / not-null keys, accepted values, referential integrity (fact → every dimension) and
custom tests (no non-positive fares, dropoff after pickup, tip outlier guard). Run: `make dbt-test`.

## Performance work

Measured on an 8 GB Windows laptop with 12.5M trip rows (single runs, so ratios are indicative).
Full queries and caveats: [sql/performance](sql/performance) and [docs/benchmarks.md](docs/benchmarks.md).

| Technique | Query | Before | After |
|---|---|---|---|
| B-tree index | Pickups by zone, one day | 16,446 ms | 237 ms (69x faster) |
| BRIN index | Same query | 16,446 ms | 771 ms (21x faster) |
| Month partitioning | Trips by zone, one month | 3,961 ms (plain table) | 2,046 ms (1.9x faster) |
| Materialized view | Daily KPIs, one day | 1,682 ms | 0.18 ms |


## Repo layout
```
ingestion/        Python loaders (trips, zones, weather)
airflow/          Dockerfile + DAG
dbt_project/      staging, marts, macros, tests
sql/init/         DDL run on first container start
sql/performance/  partitioning / indexing / matview experiments
dashboard/        Streamlit app
docs/             ERD, data dictionary, benchmarks
tests/            pytest unit tests
.github/          CI workflow
```

## Development
```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
ruff check . && pytest -q
```

## Possible extensions
Green taxi / FHV data, dbt snapshots, Great Expectations, a cloud warehouse port (BigQuery / Snowflake), dbt docs on GitHub Pages.

Data: NYC TLC Trip Record Data and Open-Meteo (see their terms). Licence: MIT.
