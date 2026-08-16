-- ============================================================
-- SNF AI HUB - AI Care Transition Narrator
-- Step 3: Metrics & Monitoring
-- ============================================================

USE SCHEMA SNF_AI_HUB.GOLD;

-- ============================================================
-- METRIC 1: Transition Volume by Type
-- ============================================================
SELECT
    from_setting || ' → ' || current_setting AS transition_path,
    COUNT(*) AS transition_count,
    AVG(length_of_stay) AS avg_los_days,
    AVG(TOTAL_CLAIM_COST) AS avg_cost,
    SUM(CASE WHEN readmitted_within_30_days THEN 1 ELSE 0 END) AS readmissions,
    ROUND(SUM(CASE WHEN readmitted_within_30_days THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS readmission_rate_pct
FROM care_transitions
WHERE from_setting IS NOT NULL
GROUP BY 1
ORDER BY transition_count DESC;

-- ============================================================
-- METRIC 2: Risk Tier Distribution
-- ============================================================
SELECT
    risk_tier,
    COUNT(*) AS patient_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct
FROM transition_narratives
GROUP BY risk_tier
ORDER BY patient_count DESC;

-- ============================================================
-- METRIC 3: Readmission Rate by Risk Tier
-- ============================================================
SELECT
    tn.risk_tier,
    COUNT(*) AS transitions,
    SUM(CASE WHEN ct.readmitted_within_30_days THEN 1 ELSE 0 END) AS readmissions,
    ROUND(SUM(CASE WHEN ct.readmitted_within_30_days THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS readmission_rate_pct
FROM transition_narratives tn
JOIN care_transitions ct ON tn.transition_id = ct.transition_id
GROUP BY tn.risk_tier
ORDER BY readmission_rate_pct DESC;

-- ============================================================
-- METRIC 4: Cost Savings Potential
-- (If readmissions prevented = avg readmission cost saved)
-- ============================================================
WITH readmission_costs AS (
    SELECT
        ct.transition_id,
        ct.PATIENT_ID,
        ct.readmitted_within_30_days,
        next_enc.TOTAL_CLAIM_COST AS readmission_cost
    FROM care_transitions ct
    LEFT JOIN SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS.SILVER.ENCOUNTERS next_enc
        ON ct.next_encounter_id = next_enc.ENCOUNTER_ID
    WHERE ct.readmitted_within_30_days = TRUE
)
SELECT
    COUNT(*) AS total_readmissions,
    ROUND(AVG(readmission_cost), 2) AS avg_readmission_cost,
    ROUND(SUM(readmission_cost), 2) AS total_readmission_cost,
    ROUND(SUM(readmission_cost) * 0.20, 2) AS potential_savings_20pct_reduction
FROM readmission_costs;

-- ============================================================
-- METRIC 5: Narrative Generation Stats
-- ============================================================
SELECT
    COUNT(*) AS total_narratives_generated,
    MIN(generated_at) AS earliest_generation,
    MAX(generated_at) AS latest_generation,
    COUNT_IF(clinical_handoff IS NOT NULL) AS with_clinical_handoff,
    COUNT_IF(family_summary IS NOT NULL) AS with_family_summary,
    COUNT_IF(medication_reconciliation IS NOT NULL) AS with_med_reconciliation
FROM transition_narratives;
