select
    d::date                                   as date_id,
    extract(year from d)::int                 as year,
    extract(quarter from d)::int              as quarter,
    extract(month from d)::int                as month,
    to_char(d, 'Mon')                         as month_name,
    extract(day from d)::int                  as day,
    extract(isodow from d)::int               as iso_day_of_week,
    to_char(d, 'Dy')                          as day_name,
    extract(isodow from d) in (6, 7)          as is_weekend
from generate_series('2019-01-01'::date, '2027-12-31'::date, interval '1 day') as d
