FROM apache/airflow:2.9.3-python3.11
USER root
RUN python -m venv /opt/dbt_venv \
    && /opt/dbt_venv/bin/pip install --no-cache-dir dbt-core==1.8.8 dbt-postgres==1.8.2 \
    && chown -R airflow /opt/dbt_venv
USER airflow
RUN pip install --no-cache-dir pyarrow requests
