import pytest

from ingestion.ingest import month_bounds, trip_url, validate_month


def test_validate_month_ok():
    assert validate_month("2024-01") == "2024-01"


@pytest.mark.parametrize("bad", ["2024-13", "24-01", "2024-1", "2024-01; DROP TABLE x", ""])
def test_validate_month_rejects(bad):
    with pytest.raises(ValueError):
        validate_month(bad)


def test_month_bounds_leap_year():
    assert month_bounds("2024-02") == ("2024-02-01", "2024-02-29")


def test_trip_url():
    assert trip_url("2024-03").endswith("yellow_tripdata_2024-03.parquet")
