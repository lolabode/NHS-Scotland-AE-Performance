/* =====================================================================
   NHS Scotland A&E Performance: 01b. OPTIONAL extra hospital names
   Adds names for closed sites that are not in the current hospitals list.
   Only run this if you downloaded sct-annual-2023-locations-lookup.csv
   into C:\nhs_ae\data\
   ===================================================================== */

USE NHS_AE;
GO

TRUNCATE TABLE stg.hospital_locations;

BULK INSERT stg.hospital_locations
FROM 'C:\nhs_ae\data\sct-annual-2023-locations-lookup.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"',
      FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);

SELECT COUNT(*) AS RowsLoaded FROM stg.hospital_locations;
