# Data Cleaning Rules

These rules are applied in the Silver layer of the pipeline (airline_pipeline.sql).

## Rules and Reasons

| Problem | Example | What I did | Why |
|---|---|---|---|
| Duplicate flights | Same flight_id appears twice | SELECT DISTINCT | Duplicates make flights, passengers and revenue look bigger than they are |
| Extra spaces and mixed case | " sky jet", "DELHI" | INITCAP(TRIM(column)) | Same airline or city must not appear as different values in reports |
| Blank airline or delay reason | airline is empty | Replaced with "Unknown" | Keeps the row and its revenue in reports |
| Blank delay minutes | delay_minutes is empty | TIMESTAMPDIFF(MINUTE, scheduled_departure, actual_departure) | The value can be calculated from the two departure times |
| Blank ticket revenue | ticket_revenue is empty | passengers x avg_fare | The value can be calculated from other columns |
| Blank aircraft ID | aircraft_id is empty | No change | Revenue is still valid, so the row is kept |
| Passengers more than seats | 215 passengers on 180 seats | Removed from clean table, saved in rejected table | A flight cannot carry more passengers than seats |
| Negative average fare | avg_fare = -6400 | Removed from clean table, saved in rejected table | A ticket price cannot be negative |

## Delay Category

| delay_minutes | delay_category |
|---|---|
| 15 or less (including negative) | On Time |
| 16 to 60 | Minor Delay |
| More than 60 | Major Delay |

A negative delay is not bad data. It means the flight left early, so it counts as On Time.

## Data Quality Checks (Expectations)

- valid_passengers: passengers BETWEEN 0 AND seat_capacity (ON VIOLATION DROP ROW)
- valid_fare: avg_fare >= 0 (ON VIOLATION DROP ROW)

## Reconciliation

| Item | Rows |
|---|---|
| Bronze rows | 1,365 |
| Clean rows | 1,321 |
| Rejected rows | 19 |
| Duplicates removed | 25 |

1,321 + 19 + 25 = 1,365. No row was lost.

## Why Bronze keeps raw data

Bronze keeps the original file as it is, so the data can always be checked again or reprocessed if a cleaning rule changes.
