-- Window-function showcase: month-over-month change and 3-month rolling average.
with monthly as (

    select
        source_month,
        count(*)                       as trips,
        sum(total_amount)              as revenue,
        avg(fare_amount)               as avg_fare
    from {{ ref('fact_trips') }}
    group by 1

)

select
    source_month,
    trips,
    round(revenue::numeric, 0)                                                   as revenue,
    round(avg_fare::numeric, 2)                                                  as avg_fare,
    round((((revenue / nullif(lag(revenue) over w, 0)) - 1) * 100)::numeric, 2)  as revenue_mom_pct,
    round(avg(revenue) over (order by source_month rows between 2 preceding and current row)::numeric, 0)
                                                                                 as revenue_3m_avg
from monthly
window w as (order by source_month)
