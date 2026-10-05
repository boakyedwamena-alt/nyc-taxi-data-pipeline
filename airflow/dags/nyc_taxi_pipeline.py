"""Monthly pipeline: ingest (zones, weather, trips) -> dbt run -> dbt test.

TLC publishes with a ~2 month lag, so the scheduled run processes data_interval_start - 2 months.
Backfill / override a month:  airflow dags trigger nyc_taxi_pipeline --conf '{"month": "2024-01"}'
"""
from __future__ import annotations

from datetime import datetime, timedelta

from airflow.operators.bash import BashOperator

from airflow import DAG

MONTH = (
    "{{ dag_run.conf.get('month') or "
    "(data_interval_start - macros.dateutil.relativedelta.relativedelta(months=2))"
    ".strftime('%Y-%m') }}"
)
DBT = "cd /opt/airflow/dbt_project && /opt/dbt_venv/bin/dbt"

default_args = {
    "owner": "data-eng",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}

with DAG(
    dag_id="nyc_taxi_pipeline",
    description="NYC taxi ELT: raw ingestion -> dbt staging/marts -> data tests",
    start_date=datetime(2024, 1, 1),
    schedule="@monthly",
    catchup=False,
    default_args=default_args,
    tags=["portfolio", "dbt", "postgres"],
) as dag:
    ingest_zones = BashOperator(
        task_id="ingest_zones",
        bash_command="python -m ingestion.ingest --month " + MONTH + " --dataset zones",
    )
    ingest_weather = BashOperator(
        task_id="ingest_weather",
        bash_command="python -m ingestion.ingest --month " + MONTH + " --dataset weather",
    )
    ingest_trips = BashOperator(
        task_id="ingest_trips",
        bash_command="python -m ingestion.ingest --month " + MONTH + " --dataset trips",
    )
    dbt_run = BashOperator(task_id="dbt_run", bash_command=f"{DBT} run --profiles-dir .")
    dbt_test = BashOperator(task_id="dbt_test", bash_command=f"{DBT} test --profiles-dir .")

    [ingest_zones, ingest_weather, ingest_trips] >> dbt_run >> dbt_test
