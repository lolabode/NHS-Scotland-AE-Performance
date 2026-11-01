/* =====================================================================
   NHS Scotland A&E Performance: 04. Data quality checks
   Run after every load. Every row should show PASS, apart from known
   issues in the published data, which show FLAGGED and are excluded from
   percentage calculations (Valid4HourData = 0).
   ===================================================================== */

USE NHS_AE;
GO

WITH checks AS (

    SELECT 1 AS CheckNo, 'No duplicate rows (month, hospital, department type)' AS CheckName,
           (SELECT COUNT(*) FROM (
                SELECT MonthStart, HospitalCode, DepartmentType
                FROM dw.fact_ae_monthly
                GROUP BY MonthStart, HospitalCode, DepartmentType
                HAVING COUNT(*) > 1) d) AS Problems

    UNION ALL
    SELECT 2, 'Within 4 hours + over 4 hours = total attendances',
           (SELECT COUNT(*) FROM dw.fact_ae_monthly
            WHERE Within4Hours + Over4Hours <> Attendances)

    UNION ALL
    SELECT 3, 'Within 4 hours is never more than total attendances (unflagged rows)',
           (SELECT COUNT(*) FROM dw.fact_ae_monthly WHERE Within4Hours > Attendances AND Valid4HourData = 1)

    UNION ALL
    SELECT 4, 'No negative values',
           (SELECT COUNT(*) FROM dw.fact_ae_monthly
            WHERE Valid4HourData = 1
              AND (Attendances < 0 OR Within4Hours < 0 OR Over4Hours < 0
                   OR Over8Hours < 0 OR Over12Hours < 0))

    UNION ALL
    SELECT 5, 'Over 12 hours is never more than over 8 hours',
           (SELECT COUNT(*) FROM dw.fact_ae_monthly WHERE Over12Hours > Over8Hours)

    UNION ALL
    SELECT 6, 'Every hospital has a name',
           (SELECT COUNT(*) FROM dw.dim_hospital WHERE HospitalName IS NULL OR HospitalName = '')

    UNION ALL
    SELECT 7, 'Every hospital belongs to a known health board',
           (SELECT COUNT(*) FROM dw.dim_hospital h
            LEFT JOIN dw.dim_health_board b ON b.HealthBoardCode = h.HealthBoardCode
            WHERE b.HealthBoardCode IS NULL)

    UNION ALL
    SELECT 8, 'No month missing between first and latest month',
           (SELECT DATEDIFF(MONTH, MIN(MonthStart), MAX(MonthStart)) + 1
                   - COUNT(DISTINCT MonthStart) FROM dw.fact_ae_monthly)

    UNION ALL
    SELECT 9, '''z'' flags stored as NULL, not 0',
           (SELECT COUNT(*) FROM dw.fact_ae_monthly f
            JOIN stg.ae_activity s
              ON DATEFROMPARTS(CAST(LEFT(s.Month, 4) AS INT), CAST(RIGHT(s.Month, 2) AS INT), 1) = f.MonthStart
             AND s.TreatmentLocation = f.HospitalCode
             AND s.DepartmentType    = f.DepartmentType
             AND s.AttendanceCategory = 'All'
            WHERE s.NumberOfAttendancesEpisodeQF = 'z' AND f.EpisodeAttendances IS NOT NULL)

    UNION ALL
    SELECT 10, 'Total attendances match the raw file',
           ABS((SELECT SUM(CAST(Attendances AS BIGINT)) FROM dw.fact_ae_monthly)
             - (SELECT SUM(CAST(TRY_CAST(NumberOfAttendancesAll AS INT) AS BIGINT))
                FROM stg.ae_activity WHERE AttendanceCategory = 'All'))

    UNION ALL
    SELECT 11, 'Known issues in the published data (flagged, excluded from percentages)',
           (SELECT COUNT(*) FROM dw.fact_ae_monthly WHERE Valid4HourData = 0)
)
SELECT CheckNo, CheckName, Problems,
       CASE WHEN Problems = 0 THEN 'PASS'
            WHEN CheckNo = 11 THEN 'FLAGGED'
            ELSE 'FAIL' END AS Result
FROM checks
ORDER BY CheckNo;

/* Details of flagged rows */
SELECT MonthStart, HospitalCode, Attendances, Within4Hours, Over4Hours, DataQualityNote
FROM dw.fact_ae_monthly
WHERE Valid4HourData = 0;
