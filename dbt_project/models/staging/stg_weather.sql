select distinct on (obs_time)
    obs_time          as weather_hour,
    temperature_c,
    precipitation_mm,
    snowfall_cm,
    wind_speed_kmh
from {{ source('raw', 'weather_hourly') }}
order by obs_time, loaded_at desc
