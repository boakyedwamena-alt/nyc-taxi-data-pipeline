"""Streamlit dashboard over the marts layer."""
import os

import altair as alt
import pandas as pd
import streamlit as st
from sqlalchemy import create_engine

st.set_page_config(page_title="NYC Taxi Analytics", layout="wide")


@st.cache_resource
def engine():
    url = "postgresql+psycopg2://{u}:{p}@{h}:{port}/{db}".format(
        u=os.getenv("POSTGRES_USER", "taxi"),
        p=os.getenv("POSTGRES_PASSWORD", "taxi"),
        h=os.getenv("POSTGRES_HOST", "localhost"),
        port=os.getenv("POSTGRES_PORT", "5432"),
        db=os.getenv("POSTGRES_DB", "taxi"),
    )
    return create_engine(url)


@st.cache_data(ttl=300)
def q(sql: str) -> pd.DataFrame:
    return pd.read_sql(sql, engine())


st.title("NYC Yellow Taxi: demand, weather and fares")

try:
    kpi = q(
        "select count(*) trips, sum(total_amount) revenue, avg(fare_amount) fare "
        "from marts.fact_trips"
    ).iloc[0]
except Exception:
    st.error("Marts not found. Run the pipeline first: `make pipeline MONTH=2024-01`")
    st.stop()

c1, c2, c3 = st.columns(3)
c1.metric("Trips", f"{int(kpi.trips):,}")
c2.metric("Revenue", f"${kpi.revenue:,.0f}")
c3.metric("Avg fare", f"${kpi.fare:,.2f}")

st.subheader("1. When is demand highest? (average trips per day, by hour)")
st.caption(
    "Each point is the total for that hour divided by the number of weekdays "
    "(or weekend days) in the data, so the two lines can be compared fairly."
)
hourly = q("""
    select extract(hour from f.pickup_datetime)::int as hour_of_day,
           case when d.is_weekend then 'Weekend' else 'Weekday' end as day_type,
           (count(*)::numeric / count(distinct f.pickup_date))::float as avg_trips_per_day
    from marts.fact_trips f
    join marts.dim_date d on d.date_id = f.pickup_date
    group by 1, 2
    order by 1""")
st.line_chart(hourly.pivot(index="hour_of_day", columns="day_type", values="avg_trips_per_day"))

st.subheader("2. Which zones have the most pickups?")
zones = q("""
    select borough || ' - ' || zone_name as zone, sum(trips)::bigint as trips
    from marts.mart_hourly_zone_demand
    group by 1
    order by 2 desc
    limit 15""")
zone_chart = (
    alt.Chart(zones)
    .mark_bar()
    .encode(
        x=alt.X("trips:Q", title="Pickups"),
        y=alt.Y("zone:N", sort="-x", title=None, axis=alt.Axis(labelLimit=320)),
        tooltip=["zone", "trips"],
    )
    .properties(height=450)
)
st.altair_chart(zone_chart, use_container_width=True)

st.subheader("3. How does weather affect demand and tipping?")
weather = q("select * from marts.mart_weather_impact order by avg_trips_per_hour desc")
a, b = st.columns(2)
a.caption("Average trips per hour")
a.bar_chart(weather.set_index("weather_category")["avg_trips_per_hour"])
b.caption("Average card tip (% of fare)")
b.bar_chart(weather.set_index("weather_category")["avg_tip_pct"])

st.subheader("4. Monthly revenue trend")
monthly = q("select * from marts.mart_monthly_revenue order by source_month")
st.line_chart(monthly.set_index("source_month")[["revenue", "revenue_3m_avg"]])

st.subheader("5. Data quality: rows rejected per month")
st.dataframe(
    q("select * from marts.mart_data_quality order by source_month"),
    use_container_width=True,
)
