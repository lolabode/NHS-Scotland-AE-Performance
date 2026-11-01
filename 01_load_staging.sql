/* =====================================================================
   NHS Scotland A&E Performance: 01. Load the raw files into staging
   Every column is loaded as text so nothing is lost or converted wrongly.
   Typing and cleaning happen in script 02.

   BEFORE RUNNING: put the CSV files in C:\nhs_ae\data\
     monthly_ae_activity_202607.csv
     hospitals.csv
     hb14_hb19.csv
   ===================================================================== */

USE NHS_AE;
GO

/* ---------- Monthly A&E activity ---------- */
DROP TABLE IF EXISTS stg.ae_activity;
CREATE TABLE stg.ae_activity (
    Month                             NVARCHAR(10),
    Country                           NVARCHAR(20),
    HBT                               NVARCHAR(20),
    TreatmentLocation                 NVARCHAR(20),
    DepartmentType                    NVARCHAR(20),
    AttendanceCategory                NVARCHAR(30),
    NumberOfAttendancesAll            NVARCHAR(20),
    NumberWithin4HoursAll             NVARCHAR(20),
    NumberOver4HoursAll               NVARCHAR(20),
    PercentageWithin4HoursAll         NVARCHAR(20),
    NumberOfAttendancesEpisode        NVARCHAR(20),
    NumberOfAttendancesEpisodeQF      NVARCHAR(5),
    NumberWithin4HoursEpisode         NVARCHAR(20),
    NumberWithin4HoursEpisodeQF       NVARCHAR(5),
    NumberOver4HoursEpisode           NVARCHAR(20),
    NumberOver4HoursEpisodeQF         NVARCHAR(5),
    PercentageWithin4HoursEpisode     NVARCHAR(20),
    PercentageWithin4HoursEpisodeQF   NVARCHAR(5),
    NumberOver8HoursEpisode           NVARCHAR(20),
    NumberOver8HoursEpisodeQF         NVARCHAR(5),
    PercentageOver8HoursEpisode       NVARCHAR(20),
    PercentageOver8HoursEpisodeQF     NVARCHAR(5),
    NumberOver12HoursEpisode          NVARCHAR(20),
    NumberOver12HoursEpisodeQF        NVARCHAR(5),
    PercentageOver12HoursEpisode      NVARCHAR(20),
    PercentageOver12HoursEpisodeQF    NVARCHAR(5)
);

BULK INSERT stg.ae_activity
FROM 'C:\nhs_ae\data\monthly_ae_activity_202607.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
      FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

/* ---------- Current NHS hospitals ---------- */
DROP TABLE IF EXISTS stg.hospitals;
CREATE TABLE stg.hospitals (
    HospitalCode      NVARCHAR(20),
    HospitalName      NVARCHAR(200),
    AddressLine1      NVARCHAR(200),
    AddressLine2      NVARCHAR(200),
    AddressLine2QF    NVARCHAR(5),
    AddressLine3      NVARCHAR(200),
    AddressLine3QF    NVARCHAR(5),
    AddressLine4      NVARCHAR(200),
    AddressLine4QF    NVARCHAR(5),
    Postcode          NVARCHAR(20),
    HealthBoard       NVARCHAR(20),
    HSCP              NVARCHAR(20),
    CouncilArea       NVARCHAR(20),
    IntermediateZone  NVARCHAR(20),
    DataZone          NVARCHAR(20)
);

BULK INSERT stg.hospitals
FROM 'C:\nhs_ae\data\hospitals.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
      FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

/* ---------- Health boards ---------- */
DROP TABLE IF EXISTS stg.health_boards;
CREATE TABLE stg.health_boards (
    HB              NVARCHAR(20),
    HBName          NVARCHAR(100),
    HBDateEnacted   NVARCHAR(20),
    HBDateArchived  NVARCHAR(20),
    Country         NVARCHAR(20)
);

BULK INSERT stg.health_boards
FROM 'C:\nhs_ae\data\hb14_hb19.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
      FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

/* ---------- Hospital locations incl. closed sites (optional) ----------
   Created empty here so later scripts work even if you skip script 01b. */
DROP TABLE IF EXISTS stg.hospital_locations;
CREATE TABLE stg.hospital_locations (
    Location      NVARCHAR(20),
    LocationName  NVARCHAR(200),
    Address1      NVARCHAR(200),
    Address2      NVARCHAR(200),
    Address3      NVARCHAR(200),
    Address4      NVARCHAR(200),
    Postcode      NVARCHAR(20),
    StartDate     NVARCHAR(20),
    EndDate       NVARCHAR(20),
    HB            NVARCHAR(20),
    HBQF          NVARCHAR(5),
    CA            NVARCHAR(20),
    CAQF          NVARCHAR(5),
    HSCP          NVARCHAR(20),
    HSCPQF        NVARCHAR(5),
    DataZone      NVARCHAR(20),
    DataZoneQF    NVARCHAR(5),
    IntZone       NVARCHAR(20),
    IntZoneQF     NVARCHAR(5)
);
GO

/* ---------- Row counts: compare with the expected values ---------- */
SELECT 'stg.ae_activity'   AS TableName, COUNT(*) AS RowsLoaded, 39905 AS Expected FROM stg.ae_activity
UNION ALL
SELECT 'stg.hospitals',    COUNT(*), 244 FROM stg.hospitals
UNION ALL
SELECT 'stg.health_boards', COUNT(*), 18 FROM stg.health_boards;
