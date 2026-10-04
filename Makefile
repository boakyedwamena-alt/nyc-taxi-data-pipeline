MONTH ?= 2024-01
EXEC = docker compose exec -T airflow

.PHONY: up down ingest dbt-run dbt-test pipeline lint test psql
up:            ## start Postgres, Airflow and the dashboard
	docker compose up -d --build
down:
	docker compose down
ingest:        ## make ingest MONTH=2024-01
	$(EXEC) python -m ingestion.ingest --month $(MONTH)
dbt-run:
	$(EXEC) bash -c "cd /opt/airflow/dbt_project && /opt/dbt_venv/bin/dbt run --profiles-dir ."
dbt-test:
	$(EXEC) bash -c "cd /opt/airflow/dbt_project && /opt/dbt_venv/bin/dbt test --profiles-dir ."
pipeline: ingest dbt-run dbt-test
lint:
	ruff check .
test:
	pytest -q
psql:
	docker compose exec postgres psql -U taxi -d taxi
