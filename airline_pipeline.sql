CREATE OR REFRESH STREAMING TABLE bronze_airline_flights AS
SELECT *,
       _metadata.file_name AS source_file,
       current_timestamp() AS loaded_at
FROM STREAM read_files('/Volumes/aviation_catalog/flights/raw_files/',
                       format => 'csv', header => true);


CREATE OR REFRESH MATERIALIZED VIEW silver_flights_clean (
  CONSTRAINT valid_passengers EXPECT (passengers BETWEEN 0 AND seat_capacity) ON VIOLATION DROP ROW,
  CONSTRAINT valid_fare       EXPECT (avg_fare >= 0)                          ON VIOLATION DROP ROW
) AS
WITH cleaned AS (
  SELECT DISTINCT
    TRIM(flight_id)                                              AS flight_id,
    TRIM(flight_number)                                          AS flight_number,
    COALESCE(NULLIF(INITCAP(TRIM(airline)), ''), 'Unknown')      AS airline,
    TRIM(aircraft_id)                                            AS aircraft_id,
    TRIM(aircraft_type)                                          AS aircraft_type,
    CAST(flight_date AS DATE)                                    AS flight_date,
    TRIM(day_of_week)                                            AS day_of_week,
    INITCAP(TRIM(origin_city))                                   AS origin_city,
    INITCAP(TRIM(destination_city))                              AS destination_city,
    TRIM(origin_region)                                          AS origin_region,
    CAST(distance_km AS INT)                                     AS distance_km,
    CAST(scheduled_departure AS TIMESTAMP)                       AS scheduled_departure,
    CAST(actual_departure AS TIMESTAMP)                          AS actual_departure,
    COALESCE(CAST(delay_minutes AS INT),
             TIMESTAMPDIFF(MINUTE,
                           CAST(scheduled_departure AS TIMESTAMP),
                           CAST(actual_departure AS TIMESTAMP))) AS delay_minutes,
    COALESCE(NULLIF(INITCAP(TRIM(delay_reason)), ''), 'Unknown') AS delay_reason,
    CAST(seat_capacity AS INT)                                   AS seat_capacity,
    CAST(passengers AS INT)                                      AS passengers,
    CAST(avg_fare AS DOUBLE)                                     AS avg_fare,
    COALESCE(CAST(ticket_revenue AS DOUBLE),
             CAST(passengers AS INT) * CAST(avg_fare AS DOUBLE)) AS ticket_revenue,
    CAST(fuel_cost AS DOUBLE)                                    AS fuel_cost
  FROM bronze_airline_flights
)
SELECT *,
       CASE WHEN delay_minutes <= 15 THEN 'On Time'
            WHEN delay_minutes <= 60 THEN 'Minor Delay'
            ELSE 'Major Delay' END AS delay_category
FROM cleaned;

CREATE OR REFRESH MATERIALIZED VIEW silver_flights_rejected AS
SELECT DISTINCT
  TRIM(flight_id)                                         AS flight_id,
  COALESCE(NULLIF(INITCAP(TRIM(airline)), ''), 'Unknown') AS airline,
  INITCAP(TRIM(origin_city))                              AS origin_city,
  INITCAP(TRIM(destination_city))                         AS destination_city,
  CAST(flight_date AS DATE)                               AS flight_date,
  CAST(seat_capacity AS INT)                              AS seat_capacity,
  CAST(passengers AS INT)                                 AS passengers,
  CAST(avg_fare AS DOUBLE)                                AS avg_fare,
  CASE WHEN CAST(passengers AS INT) > CAST(seat_capacity AS INT) THEN 'Passengers more than seats'
       WHEN CAST(passengers AS INT) < 0 THEN 'Passengers are negative'
       ELSE 'Average fare is negative' END                AS reject_reason
FROM bronze_airline_flights
WHERE CAST(passengers AS INT) > CAST(seat_capacity AS INT)
   OR CAST(passengers AS INT) < 0
   OR CAST(avg_fare AS DOUBLE) < 0;

   CREATE OR REFRESH MATERIALIZED VIEW gold_monthly_flights AS
SELECT DATE_TRUNC('MONTH', flight_date)                                AS flight_month,
       COUNT(*)                                                        AS flights,
       SUM(passengers)                                                 AS passengers,
       SUM(seat_capacity)                                              AS seats,
       ROUND(SUM(passengers) * 100.0 / SUM(seat_capacity), 1)          AS load_factor_pct,
       SUM(ticket_revenue)                                             AS ticket_revenue,
       SUM(fuel_cost)                                                  AS fuel_cost,
       SUM(CASE WHEN delay_category <> 'On Time' THEN 1 ELSE 0 END)    AS delayed_flights
FROM silver_flights_clean
GROUP BY DATE_TRUNC('MONTH', flight_date);

CREATE OR REFRESH MATERIALIZED VIEW gold_airline_summary AS
SELECT airline,
       COUNT(*)                                                           AS flights,
       SUM(passengers)                                                    AS passengers,
       SUM(ticket_revenue)                                                AS ticket_revenue,
       ROUND(SUM(passengers) * 100.0 / SUM(seat_capacity), 1)             AS load_factor_pct,
       ROUND(SUM(CASE WHEN delay_category = 'On Time' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS on_time_pct,
       ROUND(AVG(delay_minutes), 1)                                       AS avg_delay_minutes
FROM silver_flights_clean
GROUP BY airline;

CREATE OR REFRESH MATERIALIZED VIEW gold_route_summary AS
SELECT origin_city,
       destination_city,
       COUNT(*)                                                    AS flights,
       SUM(passengers)                                             AS passengers,
       SUM(ticket_revenue)                                         AS ticket_revenue,
       ROUND(SUM(passengers) * 100.0 / SUM(seat_capacity), 1)      AS load_factor_pct
FROM silver_flights_clean
GROUP BY origin_city, destination_city;

CREATE OR REFRESH MATERIALIZED VIEW gold_delay_summary AS
SELECT delay_category,
       delay_reason,
       COUNT(*)                         AS flights,
       ROUND(AVG(delay_minutes), 1)     AS avg_delay_minutes
FROM silver_flights_clean
GROUP BY delay_category, delay_reason;

CREATE OR REFRESH MATERIALIZED VIEW gold_data_quality AS
WITH q AS (
  SELECT
    COUNT(*)                                                                   AS bronze_rows,
    COUNT(*) - COUNT(DISTINCT flight_id)                                       AS duplicate_rows,
    COUNT(DISTINCT CASE WHEN CAST(passengers AS INT) > CAST(seat_capacity AS INT) THEN flight_id END) AS overbooked_rows,
    COUNT(DISTINCT CASE WHEN CAST(avg_fare AS DOUBLE) < 0 THEN flight_id END)  AS negative_fare_rows,
    COUNT(DISTINCT CASE WHEN airline IS NULL OR TRIM(airline) = '' THEN flight_id END)             AS missing_airline_rows,
    COUNT(DISTINCT CASE WHEN delay_minutes IS NULL THEN flight_id END)         AS missing_delay_rows,
    COUNT(DISTINCT CASE WHEN ticket_revenue IS NULL THEN flight_id END)        AS missing_revenue_rows,
    COUNT(DISTINCT CASE WHEN delay_reason IS NULL OR TRIM(delay_reason) = '' THEN flight_id END)   AS missing_reason_rows,
    (SELECT COUNT(*) FROM silver_flights_clean)                                AS clean_rows,
    (SELECT COUNT(*) FROM silver_flights_rejected)                             AS rejected_rows
  FROM bronze_airline_flights
)
SELECT *,
       CASE WHEN bronze_rows = clean_rows + rejected_rows + duplicate_rows
            THEN 'Yes' ELSE 'No' END AS reconciliation_passed
FROM q;

                       
