/* =====================================================================
   NHS Scotland A&E Performance: 00. Create the database
   Creates the database and three schemas:
     stg   = raw files exactly as downloaded (all text)
     clean = typed and cleaned data
     dw    = star schema used by Power BI
   ===================================================================== */

IF DB_ID('NHS_AE') IS NULL
    CREATE DATABASE NHS_AE;
GO

USE NHS_AE;
GO

IF SCHEMA_ID('stg')   IS NULL EXEC('CREATE SCHEMA stg');
IF SCHEMA_ID('clean') IS NULL EXEC('CREATE SCHEMA clean');
IF SCHEMA_ID('dw')    IS NULL EXEC('CREATE SCHEMA dw');
GO

PRINT 'Database NHS_AE and schemas stg, clean, dw are ready.';
