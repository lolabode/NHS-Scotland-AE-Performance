# How to run the SQL scripts

**Database:** SQL Server 2022 Express, using SSMS.

## Before you start

1. Create the folder `C:\nhs_ae\data\`
2. Put these files in it:
   - `monthly_ae_activity_202607.csv`
   - `hospitals.csv`
   - `hb14_hb19.csv`
   - `sct-annual-2023-locations-lookup.csv` (optional)

## Run order

Open each script in SSMS (**File > Open > File**), then press **F5** to run it.

| Script | What it does | What you should see |
|---|---|---|
| 00_create_database.sql | Creates the NHS_AE database and schemas | "Database NHS_AE ... ready" |
| 01_load_staging.sql | Loads the raw CSV files as text | 39905, 244 and 18 rows |
| 01b_load_hospital_locations_optional.sql | Adds names for closed sites (optional) | About 300 rows |
| 02_clean.sql | Keeps category "All", combines the duplicate, turns blanks into NULL | 18899 clean rows, 1 duplicate combined |
| 03_star_schema.sql | Builds the fact table and four dimensions | 229 / 14 / 2 / 103 / 18899 rows |
| 04_data_quality_checks.sql | Runs 11 checks | 10 PASS, 1 FLAGGED |
| 05_validate_against_published.sql | Checks the latest month | July 2026: 69.1% all sites, 65.0% Type 1, 92.7% Type 3 |

## If a load fails with "Cannot bulk load ... Operating system error 5 (Access is denied)"

SQL Server can't read the folder. Either:
- right-click `C:\nhs_ae\data` > **Properties > Security**, and give **Users** read access, or
- in SSMS, right-click the **NHS_AE** database > **Tasks > Import Flat File**, and import each CSV into the matching table name (for example `ae_activity`, schema `stg`). Then carry on from script 02.

## Known issue in the published data

May 2025, St Brendan's Hospital, Barra (W106H): 96 patients within 4 hours out of 69 attendances.
The row is kept as published but flagged (`Valid4HourData = 0`) and left out of percentage calculations.
