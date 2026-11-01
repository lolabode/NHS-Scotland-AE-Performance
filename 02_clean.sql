/* =====================================================================
   NHS Scotland A&E Performance: 02. Clean and type the data
   Fixes applied:
     1. Keep attendance category 'All' only (Unplanned + New planned),
        to avoid double counting
     2. Add together duplicate rows (G405H, May 2015) so each site has
        one row per month and department type
     3. Store 'z' quality flags and blanks as NULL, never as 0
     4. Convert Month (YYYYMM) into a proper date
   ===================================================================== */

USE NHS_AE;
GO

/* Turns blanks into NULL first, so an empty value never becomes 0.
   Works whether a column arrived as text or as a number. */
DROP TABLE IF EXISTS clean.ae_monthly;

SELECT
    DATEFROMPARTS(CAST(LEFT(Month, 4) AS INT), CAST(RIGHT(Month, 2) AS INT), 1) AS MonthStart,
    LTRIM(RTRIM(HBT))               AS HealthBoardCode,
    LTRIM(RTRIM(TreatmentLocation)) AS HospitalCode,
    LTRIM(RTRIM(DepartmentType))    AS DepartmentType,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberOfAttendancesAll     AS NVARCHAR(50)))), '') AS INT)) AS Attendances,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberWithin4HoursAll      AS NVARCHAR(50)))), '') AS INT)) AS Within4Hours,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberOver4HoursAll        AS NVARCHAR(50)))), '') AS INT)) AS Over4Hours,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberOfAttendancesEpisode AS NVARCHAR(50)))), '') AS INT)) AS EpisodeAttendances,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberWithin4HoursEpisode  AS NVARCHAR(50)))), '') AS INT)) AS EpisodeWithin4Hours,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberOver8HoursEpisode    AS NVARCHAR(50)))), '') AS INT)) AS Over8Hours,
    SUM(TRY_CAST(NULLIF(LTRIM(RTRIM(CAST(NumberOver12HoursEpisode   AS NVARCHAR(50)))), '') AS INT)) AS Over12Hours,
    COUNT(*) AS SourceRows   -- 2 means duplicate rows were combined
INTO clean.ae_monthly
FROM stg.ae_activity
WHERE LTRIM(RTRIM(AttendanceCategory)) = 'All'
GROUP BY Month, HBT, TreatmentLocation, DepartmentType;
GO

/* ---------- What the cleaning did ---------- */
SELECT
    (SELECT COUNT(*) FROM stg.ae_activity)                                  AS RawRows,
    (SELECT COUNT(*) FROM stg.ae_activity WHERE AttendanceCategory = 'All') AS RawRowsCategoryAll,
    (SELECT COUNT(*) FROM clean.ae_monthly)                                 AS CleanRows,          -- expected 18899
    (SELECT COUNT(*) FROM clean.ae_monthly WHERE SourceRows > 1)            AS DuplicatesCombined, -- expected 1
    (SELECT SUM(CAST(Attendances AS BIGINT)) FROM clean.ae_monthly)         AS TotalAttendances;   -- expected 30459624

/* The duplicate that was combined */
SELECT * FROM clean.ae_monthly WHERE SourceRows > 1;
