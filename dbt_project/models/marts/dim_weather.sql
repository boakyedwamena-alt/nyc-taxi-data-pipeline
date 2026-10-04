select
    weather_hour,
    temperature_c,
    precipitation_mm,
    snowfall_cm,
    wind_speed_kmh,
    case
        when snowfall_cm > 0         then 'Snow'
        when precipitation_mm >= 0.1 then 'Rain'
        when temperature_c >= 30     then 'Hot (30C+)'
        when temperature_c <= 0      then 'Freezing (0C-)'
        else 'Mild / dry'
    end as weather_category
from {{ ref('stg_weather') }}
