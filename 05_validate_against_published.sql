/* =====================================================================
   NHS Scotland A&E Performance: 05. Validate against published figures
   Percentages are always calculated from summed counts, never averaged,
   and leave out rows flagged as impossible (Valid4HourData = 0).

   Expected for July 2026 (from the source file):
     All A&E sites   69.1%
     Type 1 (EDs)    65.0%
     Type 3 (MIUs)   92.7%
   Compare these with the figures Public Health Scotland publishes for
   the same month (acceptance test in the requirements).
   ===================================================================== */

USE NHS_AE;
GO

DECLARE @latest DATE = (SELECT MAX(MonthStart) FROM dw.fact_ae_monthly);

/* Latest month: Scotland by department type and in total */
SELECT
    COALESCE(d.DepartmentName, 'All A&E sites')                AS DepartmentType,
    SUM(f.Attendances)                                         AS Attendances,
    SUM(f.Within4Hours)                                        AS Within4Hours,
    CAST(100.0 * SUM(f.Within4Hours) / SUM(f.Attendances) AS DECIMAL(5,1)) AS PctWithin4Hours
FROM dw.fact_ae_monthly f
JOIN dw.dim_department_type d ON d.DepartmentType = f.DepartmentType
WHERE f.MonthStart = @latest AND f.Valid4HourData = 1
GROUP BY ROLLUP (d.DepartmentName);

/* Last 12 months: Scotland trend, all sites */
SELECT
    dd.YearMonth,
    SUM(f.Attendances) AS Attendances,
    CAST(100.0 * SUM(f.Within4Hours) / SUM(f.Attendances) AS DECIMAL(5,1)) AS PctWithin4Hours
FROM dw.fact_ae_monthly f
JOIN dw.dim_date dd ON dd.MonthStart = f.MonthStart
WHERE f.MonthStart > DATEADD(MONTH, -12, @latest) AND f.Valid4HourData = 1
GROUP BY dd.YearMonth
ORDER BY dd.YearMonth;
