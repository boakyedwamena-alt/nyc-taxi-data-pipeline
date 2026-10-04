"""Ingest NYC TLC yellow taxi trips, taxi zones and hourly weather into PostgreSQL (raw schema).

Usage:
    python -m ingestion.ingest --month 2024-01
    python -m ingestion.ingest --month 2024-01 --dataset trips
Every load is idempotent: re-running a month replaces that month's data.
"""
from __future__ import annotations

import argparse
import calendar
import io
import logging
import os
import re
from pathlib import Path

import pandas as pd
import psycopg2
import pyarrow.parquet as pq
import requests

log = logging.getLogger("ingestion")

TRIP_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/yellow_tripdata_{month}.parquet"
ZONE_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"
WEATHER_URL = "https://archive-api.open-meteo.com/v1/archive"
NYC_LAT, NYC_LON = 40.7128, -74.0060

DATA_DIR = Path(os.getenv("DATA_DIR", "data"))
MONTH_RE = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")

# source parquet column (lower-cased) -> raw table column
COLUMN_MAP = {
    "vendorid": "vendor_id",
    "tpep_pickup_datetime": "pickup_datetime",
    "tpep_dropoff_datetime": "dropoff_datetime",
    "passenger_count": "passenger_count",
    "trip_distance": "trip_distance",
    "ratecodeid": "rate_code_id",
    "store_and_fwd_flag": "store_and_fwd_flag",
    "pulocationid": "pu_location_id",
    "dolocationid": "do_location_id",
    "payment_type": "payment_type",
    "fare_amount": "fare_amount",
    "extra": "extra",
    "mta_tax": "mta_tax",
    "tip_amount": "tip_amount",
    "tolls_amount": "tolls_amount",
    "improvement_surcharge": "improvement_surcharge",
    "total_amount": "total_amount",
    "congestion_surcharge": "congestion_surcharge",
    "airport_fee": "airport_fee",
}
TARGET_COLS = [*COLUMN_MAP.values(), "source_month"]
INT_COLS = [
    "vendor_id", "passenger_count", "rate_code_id", "pu_location_id",
    "do_location_id", "payment_type",
]  # fmt: skip


# ---------- helpers ----------
def validate_month(month: str) -> str:
    if not MONTH_RE.match(month):
        raise ValueError(f"Invalid month '{month}', expected YYYY-MM")
    return month


def month_bounds(month: str) -> tuple[str, str]:
    year, mon = map(int, validate_month(month).split("-"))
    last_day = calendar.monthrange(year, mon)[1]
    return f"{month}-01", f"{month}-{last_day:02d}"


def trip_url(month: str) -> str:
    return TRIP_URL.format(month=validate_month(month))


def get_conn():
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "localhost"),
        port=os.getenv("POSTGRES_PORT", "5432"),
        dbname=os.getenv("POSTGRES_DB", "taxi"),
        user=os.getenv("POSTGRES_USER", "taxi"),
        password=os.getenv("POSTGRES_PASSWORD", "taxi"),
    )


def download(url: str, dest: Path) -> Path:
    """Stream a file to disk; skip if it is already cached."""
    if dest.exists() and dest.stat().st_size > 0:
        log.info("Using cached file %s", dest)
        return dest
    dest.parent.mkdir(parents=True, exist_ok=True)
    log.info("Downloading %s", url)
    tmp = dest.with_suffix(dest.suffix + ".part")
    with requests.get(url, stream=True, timeout=60) as resp:
        resp.raise_for_status()
        with open(tmp, "wb") as fh:
            for chunk in resp.iter_content(chunk_size=1 << 20):
                fh.write(chunk)
    tmp.rename(dest)
    return dest


def copy_df(cur, df: pd.DataFrame, table: str, columns: list[str]) -> int:
    buf = io.StringIO()
    df[columns].to_csv(buf, index=False, header=False)
    buf.seek(0)
    cols = ", ".join(columns)
    cur.copy_expert(f"COPY {table} ({cols}) FROM STDIN WITH (FORMAT csv)", buf)
    return len(df)


def log_run(cur, dataset: str, month: str | None, rows: int) -> None:
    cur.execute(
        "INSERT INTO raw.ingestion_log (dataset, source_month, rows_loaded) VALUES (%s, %s, %s)",
        (dataset, month, rows),
    )


# ---------- loaders ----------
def load_trips(month: str, batch_size: int = 500_000) -> int:
    validate_month(month)
    path = download(trip_url(month), DATA_DIR / f"yellow_tripdata_{month}.parquet")
    pf = pq.ParquetFile(path)
    available = {name.lower(): name for name in pf.schema_arrow.names}
    wanted = [available[c] for c in COLUMN_MAP if c in available]
    partition = f"raw.yellow_trips_{month.replace('-', '_')}"

    total = 0
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:  # one transaction: all-or-nothing per month
            cur.execute(
                f"CREATE TABLE IF NOT EXISTS {partition} "
                f"PARTITION OF raw.yellow_trips FOR VALUES IN ('{month}')"
            )
            cur.execute(f"TRUNCATE {partition}")  # idempotent reload
            for batch in pf.iter_batches(batch_size=batch_size, columns=wanted):
                df = batch.to_pandas()
                df.columns = [c.lower() for c in df.columns]
                df = df.rename(columns=COLUMN_MAP)
                for col in TARGET_COLS:
                    if col not in df.columns:
                        df[col] = pd.NA  # older/newer files may lack some columns
                for col in INT_COLS:
                    df[col] = pd.to_numeric(df[col], errors="coerce").round().astype("Int64")
                df["source_month"] = month
                total += copy_df(cur, df, partition, TARGET_COLS)
                log.info("trips %s: %s rows loaded so far", month, f"{total:,}")
            log_run(cur, "yellow_trips", month, total)
    finally:
        conn.close()
    return total


def load_zones() -> int:
    path = download(ZONE_URL, DATA_DIR / "taxi_zone_lookup.csv")
    df = pd.read_csv(path).rename(
        columns={"LocationID": "location_id", "Borough": "borough", "Zone": "zone",
                 "service_zone": "service_zone"}
    )  # fmt: skip
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("TRUNCATE raw.taxi_zones")
            n = copy_df(cur, df, "raw.taxi_zones", list(df.columns))
            log_run(cur, "taxi_zones", None, n)
    finally:
        conn.close()
    log.info("zones: %s rows loaded", n)
    return n


def load_weather(month: str) -> int:
    start, end = month_bounds(month)
    params = {
        "latitude": NYC_LAT,
        "longitude": NYC_LON,
        "start_date": start,
        "end_date": end,
        "hourly": "temperature_2m,precipitation,snowfall,wind_speed_10m",
        "timezone": "America/New_York",  # TLC timestamps are local time
    }
    resp = requests.get(WEATHER_URL, params=params, timeout=60)
    resp.raise_for_status()
    hourly = resp.json()["hourly"]
    df = pd.DataFrame(
        {
            "obs_time": pd.to_datetime(hourly["time"]),
            "temperature_c": hourly["temperature_2m"],
            "precipitation_mm": hourly["precipitation"],
            "snowfall_cm": hourly["snowfall"],
            "wind_speed_kmh": hourly["wind_speed_10m"],
            "source_month": month,
        }
    )
    conn = get_conn()
    try:
        with conn, conn.cursor() as cur:
            cur.execute("DELETE FROM raw.weather_hourly WHERE source_month = %s", (month,))
            n = copy_df(cur, df, "raw.weather_hourly", list(df.columns))
            log_run(cur, "weather_hourly", month, n)
    finally:
        conn.close()
    log.info("weather %s: %s rows loaded", month, f"{n:,}")
    return n


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--month", required=True, help="YYYY-MM")
    parser.add_argument(
        "--dataset", choices=["all", "trips", "zones", "weather"], default="all"
    )
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    validate_month(args.month)
    if args.dataset in ("all", "zones"):
        load_zones()
    if args.dataset in ("all", "weather"):
        load_weather(args.month)
    if args.dataset in ("all", "trips"):
        load_trips(args.month)


if __name__ == "__main__":
    main()
