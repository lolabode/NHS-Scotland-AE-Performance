/* =====================================================================
   NHS Scotland A&E Performance: 03. Build the star schema
   One fact table (one row per month, hospital and department type)
   and four dimensions: date, health board, hospital, department type.
   ===================================================================== */

USE NHS_AE;
GO

DROP TABLE IF EXISTS dw.fact_ae_monthly;
DROP TABLE IF EXISTS dw.dim_date;
DROP TABLE IF EXISTS dw.dim_hospital;
DROP TABLE IF EXISTS dw.dim_health_board;
DROP TABLE IF EXISTS dw.dim_department_type;
GO

/* ---------- dim_date: one row per month ---------- */
CREATE TABLE dw.dim_date (
    MonthStart      DATE        NOT NULL PRIMARY KEY,
    [Year]          INT         NOT NULL,
    MonthNumber     INT         NOT NULL,
    MonthName       NVARCHAR(10) NOT NULL,
    MonthShort      NVARCHAR(3) NOT NULL,
    YearMonth       NVARCHAR(8) NOT NULL,    -- e.g. 2026-07, sorts correctly
    [Quarter]       NVARCHAR(2) NOT NULL,
    FinancialYear   NVARCHAR(7) NOT NULL,    -- NHS year runs April to March, e.g. 2026/27
    Season          NVARCHAR(10) NOT NULL,   -- Winter = December to March
    IsLatestMonth   BIT         NOT NULL
);

DECLARE @first DATE = (SELECT MIN(MonthStart) FROM clean.ae_monthly);
DECLARE @last  DATE = (SELECT MAX(MonthStart) FROM clean.ae_monthly);

WITH months AS (
    SELECT @first AS MonthStart
    UNION ALL
    SELECT DATEADD(MONTH, 1, MonthStart) FROM months WHERE MonthStart < @last
)
INSERT INTO dw.dim_date
SELECT
    MonthStart,
    YEAR(MonthStart),
    MONTH(MonthStart),
    DATENAME(MONTH, MonthStart),
    LEFT(DATENAME(MONTH, MonthStart), 3),
    FORMAT(MonthStart, 'yyyy-MM'),
    'Q' + CAST(DATEPART(QUARTER, MonthStart) AS NVARCHAR(1)),
    CASE WHEN MONTH(MonthStart) >= 4
         THEN CAST(YEAR(MonthStart) AS NVARCHAR(4)) + '/' + RIGHT(CAST(YEAR(MonthStart) + 1 AS NVARCHAR(4)), 2)
         ELSE CAST(YEAR(MonthStart) - 1 AS NVARCHAR(4)) + '/' + RIGHT(CAST(YEAR(MonthStart) AS NVARCHAR(4)), 2)
    END,
    CASE WHEN MONTH(MonthStart) IN (12, 1, 2, 3) THEN 'Winter'
         WHEN MONTH(MonthStart) IN (4, 5)        THEN 'Spring'
         WHEN MONTH(MonthStart) IN (6, 7, 8)     THEN 'Summer'
         ELSE 'Autumn' END,
    CASE WHEN MonthStart = @last THEN 1 ELSE 0 END
FROM months
OPTION (MAXRECURSION 0);
GO

/* ---------- dim_health_board: the 14 current boards ----------
   Archived codes are left out: the A&E data uses current codes for its
   whole history. */
CREATE TABLE dw.dim_health_board (
    HealthBoardCode  NVARCHAR(9)   NOT NULL PRIMARY KEY,
    HealthBoardName  NVARCHAR(100) NOT NULL,   -- e.g. NHS Fife
    HealthBoardShort NVARCHAR(100) NOT NULL    -- e.g. Fife (for chart labels)
);

INSERT INTO dw.dim_health_board
SELECT
    LTRIM(RTRIM(HB)),
    LTRIM(RTRIM(HBName)),
    REPLACE(LTRIM(RTRIM(HBName)), 'NHS ', '')
FROM stg.health_boards
WHERE NULLIF(LTRIM(RTRIM(HBDateArchived)), '') IS NULL;
GO

/* ---------- dim_department_type ---------- */
CREATE TABLE dw.dim_department_type (
    DepartmentType  NVARCHAR(10)  NOT NULL PRIMARY KEY,
    DepartmentName  NVARCHAR(60)  NOT NULL,
    SortOrder       INT           NOT NULL
);

INSERT INTO dw.dim_department_type VALUES
    ('Type 1', 'Emergency department', 1),
    ('Type 3', 'Minor injury unit or other', 2);
GO

/* ---------- dim_hospital: every site that appears in the A&E data ----------
   Name comes from the current hospitals list first, then the locations
   lookup (closed sites), otherwise it is labelled as not published. */
CREATE TABLE dw.dim_hospital (
    HospitalCode     NVARCHAR(10)  NOT NULL PRIMARY KEY,
    HospitalName     NVARCHAR(200) NOT NULL,
    HealthBoardCode  NVARCHAR(9)   NOT NULL,
    NameSource       NVARCHAR(60)  NOT NULL,
    FirstMonth       DATE          NOT NULL,
    LastMonth        DATE          NOT NULL,
    IsActive         BIT           NOT NULL    -- reported in the latest month
);

DECLARE @latest DATE = (SELECT MAX(MonthStart) FROM clean.ae_monthly);

WITH sites AS (
    SELECT HospitalCode,
           MAX(HealthBoardCode) AS HealthBoardCode,
           MIN(MonthStart)      AS FirstMonth,
           MAX(MonthStart)      AS LastMonth
    FROM clean.ae_monthly
    GROUP BY HospitalCode
)
INSERT INTO dw.dim_hospital
SELECT
    s.HospitalCode,
    COALESCE(LTRIM(RTRIM(h.HospitalName)),
             LTRIM(RTRIM(l.LocationName)),
             'Site ' + s.HospitalCode + ' (name not published)'),
    s.HealthBoardCode,
    CASE WHEN h.HospitalCode IS NOT NULL THEN 'Current hospitals list'
         WHEN l.Location     IS NOT NULL THEN 'Hospital locations lookup (closed site)'
         ELSE 'Not published' END,
    s.FirstMonth,
    s.LastMonth,
    CASE WHEN s.LastMonth = @latest THEN 1 ELSE 0 END
FROM sites s
LEFT JOIN stg.hospitals          h ON LTRIM(RTRIM(h.HospitalCode)) = s.HospitalCode
LEFT JOIN stg.hospital_locations l ON LTRIM(RTRIM(l.Location))     = s.HospitalCode;
GO

/* ---------- fact_ae_monthly ---------- */
CREATE TABLE dw.fact_ae_monthly (
    MonthStart           DATE         NOT NULL REFERENCES dw.dim_date (MonthStart),
    HospitalCode         NVARCHAR(10) NOT NULL REFERENCES dw.dim_hospital (HospitalCode),
    HealthBoardCode      NVARCHAR(9)  NOT NULL REFERENCES dw.dim_health_board (HealthBoardCode),
    DepartmentType       NVARCHAR(10) NOT NULL REFERENCES dw.dim_department_type (DepartmentType),
    Attendances          INT          NOT NULL,
    Within4Hours         INT          NOT NULL,
    Over4Hours           INT          NOT NULL,
    EpisodeAttendances   INT          NULL,   -- NULL = no patient-level data for this site
    EpisodeWithin4Hours  INT          NULL,
    Over8Hours           INT          NULL,
    Over12Hours          INT          NULL,
    HasEpisodeData       BIT          NOT NULL,
    Valid4HourData       BIT          NOT NULL,   -- 0 = source figures are impossible (see script 04)
    DataQualityNote      NVARCHAR(200) NULL,
    CONSTRAINT PK_fact_ae_monthly PRIMARY KEY (MonthStart, HospitalCode, DepartmentType)
);

INSERT INTO dw.fact_ae_monthly
SELECT
    MonthStart, HospitalCode, HealthBoardCode, DepartmentType,
    Attendances, Within4Hours, Over4Hours,
    EpisodeAttendances, EpisodeWithin4Hours, Over8Hours, Over12Hours,
    CASE WHEN EpisodeAttendances IS NULL THEN 0 ELSE 1 END,
    /* Rows with impossible 4-hour figures are kept as published but flagged,
       so Power BI measures can leave them out of percentage calculations. */
    CASE WHEN Within4Hours > Attendances OR Over4Hours < 0 THEN 0 ELSE 1 END,
    CASE WHEN Within4Hours > Attendances OR Over4Hours < 0
         THEN 'Within 4 hours (' + CAST(Within4Hours AS NVARCHAR(10)) + ') exceeds attendances ('
              + CAST(Attendances AS NVARCHAR(10)) + ') in the published data'
    END
FROM clean.ae_monthly;
GO

/* ---------- Summary ---------- */
SELECT 'dw.dim_date'            AS TableName, COUNT(*) AS RowsLoaded, 229   AS Expected FROM dw.dim_date
UNION ALL SELECT 'dw.dim_health_board',    COUNT(*), 14    FROM dw.dim_health_board
UNION ALL SELECT 'dw.dim_department_type', COUNT(*), 2     FROM dw.dim_department_type
UNION ALL SELECT 'dw.dim_hospital',        COUNT(*), 103   FROM dw.dim_hospital
UNION ALL SELECT 'dw.fact_ae_monthly',     COUNT(*), 18899 FROM dw.fact_ae_monthly;

/* Rows flagged as impossible in the published data (expected: 1, W106H May 2025) */
SELECT f.MonthStart, f.HospitalCode, h.HospitalName, f.Attendances, f.Within4Hours, f.DataQualityNote
FROM dw.fact_ae_monthly f
JOIN dw.dim_hospital h ON h.HospitalCode = f.HospitalCode
WHERE f.Valid4HourData = 0;

SELECT NameSource, COUNT(*) AS Sites
FROM dw.dim_hospital
GROUP BY NameSource;
