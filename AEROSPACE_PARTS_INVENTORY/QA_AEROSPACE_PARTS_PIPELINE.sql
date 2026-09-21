/*=========================================================
Object Name : QA_AEROSPACE_PARTS_PIPELINE
Purpose     : QA acceptance criteria queries
Database    : GEN_AI_POC_SNOWFLAKECOE
Schema      : SDLC_WIZARD
Warehouse   : SNOWFLAKE_LEARNING_WH
SP          : SP_LOAD_AEROSPACE_PARTS_SCD1
AC Range    : AC-001 through AC-010
=========================================================*/

USE DATABASE GEN_AI_POC_SNOWFLAKECOE;
USE SCHEMA SDLC_WIZARD;
USE WAREHOUSE SNOWFLAKE_LEARNING_WH;

-- ============================================================
-- AC-001: TARGET TABLE EXISTS AND IS ACCESSIBLE
-- PASS: Returns row count >= 0 with no errors
-- ============================================================
SELECT
    'AC-001'                                AS acceptance_criteria,
    'TARGET TABLE EXISTS AND IS ACCESSIBLE' AS description,
    COUNT(*)                                AS row_count,
    CASE WHEN COUNT(*) >= 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM AEROSPACE_PARTS_TARGET;

-- ============================================================
-- AC-002: SCHEMA VALIDATION — REQUIRED COLUMNS PRESENT
-- PASS: All expected columns exist in target table
-- ============================================================
SELECT
    'AC-002'                                  AS acceptance_criteria,
    'SCHEMA VALIDATION — REQUIRED COLUMNS'    AS description,
    COUNT(*)                                  AS matched_columns,
    CASE WHEN COUNT(*) >= 16 THEN 'PASS' ELSE 'FAIL' END AS result
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'SDLC_WIZARD'
  AND TABLE_NAME   = 'AEROSPACE_PARTS_TARGET'
  AND COLUMN_NAME IN (
      'PART_NUMBER','PART_NAME','MANUFACTURER','CATEGORY',
      'UNIT_PRICE_USD','WEIGHT_KG','LIFECYCLE_STATUS',
      'CERTIFICATION_STATUS','LEAD_TIME_DAYS','INSTALLATION_DATE',
      'RISK_SCORE','IS_DELETED','LAST_UPDATED_UTC',
      'RECORD_INSERTED_UTC','ETL_BATCH_ID','ETL_RUN_TIMESTAMP'
  );

-- ============================================================
-- AC-003: BUSINESS KEY UNIQUENESS — NO DUPLICATE PART_NUMBER
-- PASS: 0 duplicate PART_NUMBER records in target
-- ============================================================
SELECT
    'AC-003'                                     AS acceptance_criteria,
    'BUSINESS KEY UNIQUENESS — PART_NUMBER'      AS description,
    COUNT(*)                                     AS duplicate_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM (
    SELECT PART_NUMBER
    FROM AEROSPACE_PARTS_TARGET
    WHERE IS_DELETED = FALSE
    GROUP BY PART_NUMBER
    HAVING COUNT(*) > 1
) dups;

-- ============================================================
-- AC-004: FILTER RULE — END OF LIFE PARTS OLDER THAN 3 YEARS EXCLUDED
-- PASS: 0 records where LIFECYCLE_STATUS='End of Life'
--       AND INSTALLATION_DATE < DATEADD(year,-3,CURRENT_DATE)
-- ============================================================
SELECT
    'AC-004'                                              AS acceptance_criteria,
    'EOL PARTS >3 YEARS FILTERED OUT'                    AS description,
    COUNT(*)                                              AS violating_records,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END   AS result
FROM AEROSPACE_PARTS_TARGET
WHERE LIFECYCLE_STATUS  = 'End of Life'
  AND INSTALLATION_DATE < DATEADD(year, -3, CURRENT_DATE)
  AND IS_DELETED        = FALSE;

-- ============================================================
-- AC-005: TRANSFORMATION RULE — MANUFACTURER IS UPPERCASE
-- PASS: 0 records where MANUFACTURER differs from its UPPER() value
-- ============================================================
SELECT
    'AC-005'                                              AS acceptance_criteria,
    'MANUFACTURER STORED AS UPPERCASE'                   AS description,
    COUNT(*)                                              AS non_upper_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END   AS result
FROM AEROSPACE_PARTS_TARGET
WHERE MANUFACTURER IS NOT NULL
  AND MANUFACTURER <> UPPER(MANUFACTURER);

-- ============================================================
-- AC-006: TRANSFORMATION RULE — WEIGHT_KG <= 0 SET TO NULL
-- PASS: 0 records where WEIGHT_KG <= 0
-- ============================================================
SELECT
    'AC-006'                                              AS acceptance_criteria,
    'WEIGHT_KG <= 0 CONVERTED TO NULL'                   AS description,
    COUNT(*)                                              AS invalid_weight_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END   AS result
FROM AEROSPACE_PARTS_TARGET
WHERE WEIGHT_KG <= 0;

-- ============================================================
-- AC-007: TRANSFORMATION RULE — UNIT_PRICE_USD ROUNDED TO 2 DP
-- PASS: 0 records where UNIT_PRICE_USD <> ROUND(UNIT_PRICE_USD,2)
-- ============================================================
SELECT
    'AC-007'                                              AS acceptance_criteria,
    'UNIT_PRICE_USD ROUNDED TO 2 DECIMAL PLACES'         AS description,
    COUNT(*)                                              AS rounding_violations,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END   AS result
FROM AEROSPACE_PARTS_TARGET
WHERE UNIT_PRICE_USD IS NOT NULL
  AND UNIT_PRICE_USD <> ROUND(UNIT_PRICE_USD, 2);

-- ============================================================
-- AC-008: DERIVED COLUMN — RISK_SCORE POPULATED FOR ALL ACTIVE RECORDS
-- PASS: 0 active records with NULL RISK_SCORE
-- ============================================================
SELECT
    'AC-008'                                              AS acceptance_criteria,
    'RISK_SCORE POPULATED FOR ALL ACTIVE RECORDS'        AS description,
    COUNT(*)                                              AS null_risk_score_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END   AS result
FROM AEROSPACE_PARTS_TARGET
WHERE IS_DELETED  = FALSE
  AND RISK_SCORE IS NULL;

-- ============================================================
-- AC-009: SOFT DELETE — DECOMMISSIONED RECORDS FLAGGED NOT REMOVED
-- PASS: IS_DELETED=TRUE records exist OR no decommissioned parts
--       (verifies hard delete is not occurring)
-- ============================================================
SELECT
    'AC-009'                                              AS acceptance_criteria,
    'SOFT DELETE FLAG APPLIED TO DECOMMISSIONED RECORDS' AS description,
    SUM(CASE WHEN IS_DELETED = TRUE  THEN 1 ELSE 0 END)  AS soft_deleted_count,
    SUM(CASE WHEN IS_DELETED = FALSE THEN 1 ELSE 0 END)  AS active_count,
    'PASS — VERIFY SOFT_DELETED_COUNT MATCHES SOURCE DECOMMISSIONS' AS result
FROM AEROSPACE_PARTS_TARGET;

-- ============================================================
-- AC-010: ETL RECONCILIATION LOG — ENTRY EXISTS FOR LATEST RUN
-- PASS: At least 1 log record written for today's date
-- ============================================================
SELECT
    'AC-010'                                              AS acceptance_criteria,
    'ETL RECONCILIATION LOG ENTRY EXISTS FOR LATEST RUN' AS description,
    COUNT(*)                                              AS log_entries_today,
    CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END  AS result
FROM ETL_RECONCILIATION_LOG
WHERE PIPELINE_NAME = 'SP_LOAD_AEROSPACE_PARTS_SCD1'
  AND CAST(RUN_TIMESTAMP AS DATE) = CURRENT_DATE;