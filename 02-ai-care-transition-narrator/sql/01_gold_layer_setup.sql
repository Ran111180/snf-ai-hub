-- ============================================================
-- SNF AI HUB - AI Care Transition Narrator
-- Step 1: GOLD Layer Setup
-- ============================================================
-- Creates the analytical schema and core tables for the
-- care transition narrator product.
-- ============================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;

-- Create project database/schema
CREATE DATABASE IF NOT EXISTS SNF_AI_HUB;
CREATE SCHEMA IF NOT EXISTS SNF_AI_HUB.GOLD;
USE SCHEMA SNF_AI_HUB.GOLD;

-- Source reference
-- All source data: SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER

-- ============================================================
-- TABLE 1: SNF Patient Cohort
-- All patients who have had at least one SNF encounter
-- ============================================================
CREATE OR REPLACE TABLE snf_patient_cohort AS
SELECT
    p.PATIENT_ID,
    p.FIRST || ' ' || p.LAST AS patient_name,
    p.BIRTHDATE,
    DATEDIFF(year, p.BIRTHDATE, CURRENT_DATE()) AS age,
    p.GENDER,
    p.RACE,
    p.ETHNICITY,
    p.MARITAL,
    p.CITY,
    p.STATE,
    p.ZIP,
    p.INCOME,
    p.HEALTHCARE_EXPENSES,
    p.HEALTHCARE_COVERAGE,
    p.DEATHDATE,
    COUNT(DISTINCT e.ENCOUNTER_ID) AS total_snf_encounters,
    MIN(e.ENCOUNTER_START) AS first_snf_admission,
    MAX(e.ENCOUNTER_START) AS last_snf_admission,
    AVG(DATEDIFF(day, e.ENCOUNTER_START, e.ENCOUNTER_STOP)) AS avg_snf_los_days,
    SUM(e.TOTAL_CLAIM_COST) AS total_snf_cost
FROM SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.PATIENTS p
JOIN SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.ENCOUNTERS e
    ON p.PATIENT_ID = e.PATIENT_ID
    AND e.ENCOUNTERCLASS = 'snf'
GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15;

-- ============================================================
-- TABLE 2: Care Transitions (the core event table)
-- Each row = one transition between care settings
-- ============================================================
CREATE OR REPLACE TABLE care_transitions AS
WITH encounter_sequence AS (
    SELECT
        PATIENT_ID,
        ENCOUNTER_ID,
        ENCOUNTERCLASS,
        ENCOUNTER_START,
        ENCOUNTER_STOP,
        TOTAL_CLAIM_COST,
        PAYER_COVERAGE,
        ORGANIZATION_ID,
        PROVIDER_ID,
        DESCRIPTION,
        REASONDESCRIPTION,
        LAG(ENCOUNTER_ID) OVER (PARTITION BY PATIENT_ID ORDER BY ENCOUNTER_START) AS prev_encounter_id,
        LAG(ENCOUNTERCLASS) OVER (PARTITION BY PATIENT_ID ORDER BY ENCOUNTER_START) AS prev_setting,
        LAG(ENCOUNTER_STOP) OVER (PARTITION BY PATIENT_ID ORDER BY ENCOUNTER_START) AS prev_discharge,
        LEAD(ENCOUNTER_ID) OVER (PARTITION BY PATIENT_ID ORDER BY ENCOUNTER_START) AS next_encounter_id,
        LEAD(ENCOUNTERCLASS) OVER (PARTITION BY PATIENT_ID ORDER BY ENCOUNTER_START) AS next_setting,
        LEAD(ENCOUNTER_START) OVER (PARTITION BY PATIENT_ID ORDER BY ENCOUNTER_START) AS next_admission
    FROM SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.ENCOUNTERS
    WHERE PATIENT_ID IN (SELECT PATIENT_ID FROM snf_patient_cohort)
      AND ENCOUNTERCLASS IN ('inpatient', 'snf', 'emergency', 'home', 'hospice')
)
SELECT
    ROW_NUMBER() OVER (ORDER BY ENCOUNTER_START) AS transition_id,
    PATIENT_ID,
    -- Current encounter
    ENCOUNTER_ID,
    ENCOUNTERCLASS AS current_setting,
    ENCOUNTER_START AS admission_date,
    ENCOUNTER_STOP AS discharge_date,
    DATEDIFF(day, ENCOUNTER_START, ENCOUNTER_STOP) AS length_of_stay,
    TOTAL_CLAIM_COST,
    ORGANIZATION_ID,
    DESCRIPTION AS encounter_reason,
    REASONDESCRIPTION AS reason_detail,
    -- Transition FROM (previous)
    prev_encounter_id,
    prev_setting AS from_setting,
    prev_discharge AS from_discharge_date,
    DATEDIFF(day, prev_discharge, ENCOUNTER_START) AS days_between_settings,
    -- Transition TO (next)
    next_encounter_id,
    next_setting AS to_setting,
    next_admission AS to_admission_date,
    DATEDIFF(day, ENCOUNTER_STOP, next_admission) AS days_to_next_encounter,
    -- Readmission flag
    CASE
        WHEN next_setting IN ('inpatient', 'emergency')
         AND DATEDIFF(day, ENCOUNTER_STOP, next_admission) <= 30
        THEN TRUE ELSE FALSE
    END AS readmitted_within_30_days
FROM encounter_sequence
WHERE ENCOUNTERCLASS = 'snf';  -- Focus on SNF encounters as the transition point

-- ============================================================
-- TABLE 3: Patient Profile at Transition Time
-- Snapshot of patient's clinical state at time of each transition
-- ============================================================
CREATE OR REPLACE TABLE transition_patient_profiles AS
SELECT
    t.transition_id,
    t.PATIENT_ID,
    t.admission_date,
    t.discharge_date,
    t.current_setting,
    t.from_setting,
    t.readmitted_within_30_days,
    -- Active conditions at time of transition
    (SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'condition', c.DESCRIPTION,
        'code', c.CODE,
        'started', c.CONDITION_START::VARCHAR
    ))
    FROM SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.CONDITIONS c
    WHERE c.PATIENT_ID = t.PATIENT_ID
      AND c.CONDITION_START <= t.discharge_date
      AND (c.CONDITION_STOP IS NULL OR c.CONDITION_STOP >= t.admission_date)
    ) AS active_conditions,
    -- Current medications
    (SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'medication', m.DESCRIPTION,
        'code', m.CODE,
        'started', m.START::VARCHAR,
        'reason', m.REASONDESCRIPTION
    ))
    FROM SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.MEDICATIONS m
    WHERE m.PATIENT_ID = t.PATIENT_ID
      AND m.START <= t.discharge_date
      AND (m.STOP IS NULL OR m.STOP >= t.admission_date)
    ) AS active_medications,
    -- Allergies
    (SELECT ARRAY_AGG(OBJECT_CONSTRUCT(
        'allergy', a.DESCRIPTION,
        'code', a.CODE,
        'category', a.CATEGORY,
        'severity', a.SEVERITY
    ))
    FROM SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.ALLERGIES a
    WHERE a.PATIENT_ID = t.PATIENT_ID
      AND a.START <= t.discharge_date
      AND (a.STOP IS NULL OR a.STOP >= t.admission_date)
    ) AS allergies
FROM care_transitions t
LIMIT 5000;  -- Start with subset for development; remove limit for production
