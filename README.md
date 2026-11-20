# Airline Flight Operations Analytics Platform

An end-to-end data engineering project built on **Databricks** using **Lakeflow Spark Declarative Pipelines** and the **Medallion Architecture** (Bronze, Silver, Gold). It turns a messy airline flights CSV into clean, trusted summary tables and a 3-page dashboard.

## Business Problem

An airline operations team exports every domestic flight to a CSV file. The file has problems: extra spaces, mixed capital letters, blank values, duplicate flights, flights with more passengers than seats, and negative fares. Managers need reliable reports on flights, passengers, revenue, load factor and delays.

## Tech Stack

- Databricks (Free Edition)
- Unity Catalog (Catalog, Schema, Volume)
- Lakeflow Spark Declarative Pipelines (SQL)
- Databricks AI/BI Dashboard
- SQL

## Dataset

- File: airline_flights_raw.csv (synthetic dataset)
- 1,365 rows and 20 columns
- Domestic flights in 2025
- Grain: one row = one flight on one day (flight_id is unique)

## Architecture

Source CSV (Unity Catalog Volume) -> Bronze -> Silver -> Gold -> Dashboard

| Layer | Table | Purpose |
|---|---|---|
| Bronze | bronze_airline_flights | Raw data with file name and load time |
| Silver | silver_flights_clean | Cleaned flights with delay_category |
| Silver | silver_flights_rejected | Bad flights with a reject reason |
| Gold | gold_monthly_flights | Monthly flights, passengers, load factor, revenue |
| Gold | gold_airline_summary | Airline load factor, on-time %, average delay |
| Gold | gold_route_summary | Route wise flights, passengers, revenue |
| Gold | gold_delay_summary | Flights and average delay by category and reason |
| Gold | gold_data_quality | Data problem counts and reconciliation check |

## Data Cleaning Rules

- Duplicate flights: removed using SELECT DISTINCT
- Extra spaces and mixed case: fixed using TRIM and INITCAP
- Blank airline or delay reason: replaced with "Unknown"
- Blank delay minutes: calculated using TIMESTAMPDIFF
- Blank ticket revenue: calculated as passengers x avg_fare
- Passengers more than seats, or negative fare: removed from clean table and saved in the rejected table with a reason
- Delay category: On Time (15 minutes or less), Minor Delay (16 to 60), Major Delay (more than 60)

See cleaning_rules.md for details.

## Results

| Check | Value |
|---|---|
| Bronze rows | 1,365 |
| Clean flights | 1,321 |
| Rejected flights | 19 |
| Duplicates removed | 25 |
| Reconciliation | 1,365 = 1,321 + 19 + 25 (Passed) |
| Total passengers | 172,030 |
| Delayed flights | 419 |

## Dashboard

The AI/BI dashboard has 3 pages:

1. **Overview**: Total Flights, Passengers, Ticket Revenue, Delayed Flights, revenue by month, on-time % by airline, month filter
2. **Airlines, Routes & Delays**: airline performance table, top 10 routes by revenue, flights by delay category, delayed flights by reason
3. **Data Quality**: Bronze, clean, rejected and duplicate counts, reconciliation status, data quality issues chart

## Screenshots

Screenshots of the pipeline, tables and dashboard are in the Screenshots folder.

## How to Run

1. Create a catalog, schema and volume in Databricks (aviation_catalog, flights, raw_files).
2. Upload airline_flights_raw.csv into the volume.
3. Create an ETL pipeline and set the default catalog to aviation_catalog and schema to flights.
4. Add airline_pipeline.sql from this repo to the pipeline.
5. Click Run pipeline and check that gold_data_quality shows reconciliation_passed = Yes.
6. Create a dashboard on the Gold tables.

Tanuja Mane
