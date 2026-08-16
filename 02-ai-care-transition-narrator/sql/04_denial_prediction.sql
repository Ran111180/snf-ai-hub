-- ============================================================
-- DENIAL PREDICTION & ALERT SYSTEM
-- SNF AI Hub - Referral Intelligence Engine
-- ============================================================
-- This SQL creates the denial prediction infrastructure:
-- 1. Historical denial rates by payer
-- 2. Day-of-stay based alert rules (when denials typically hit)
-- 3. Active alert view (which patients need action NOW)
-- 4. AI-generated denial prevention documentation
-- ============================================================

USE SCHEMA SNF_AI_HUB.REFERRAL_INTEL;

-- ============================================================
-- Key Data Points (from real analysis):
--
-- PAYER DENIAL RATES:
-- Aetna:               76% denial rate (HIGHEST RISK)
-- Humana:              74% denial rate
-- Blue Cross:          67.6%
-- Cigna:               65.2%
-- Medicare:            50.5% (partial denials)
-- UnitedHealthcare:    48.6%
-- Anthem:              48.3%
-- Medicaid:            0.5% (safest)
-- Dual Eligible:       0.6%
-- ============================================================

-- View: Referral Scorecard (combines all intelligence)
-- Already created: SNF_AI_HUB.REFERRAL_INTEL.referral_scorecard_data

-- Table: Denial Alert Rules (payer-specific triggers)
-- Already created: SNF_AI_HUB.REFERRAL_INTEL.denial_alert_rules

-- View: Active Denial Alerts (for current patients)
-- Already created: SNF_AI_HUB.REFERRAL_INTEL.active_denial_alerts

-- ============================================================
-- QUERY: Generate denial prevention letter for specific patient
-- ============================================================
-- Replace patient details with actual patient data:

-- SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
--     'You are a utilization review specialist at a Skilled Nursing Facility.
--      Generate a Continued Stay Review letter to prevent insurance denial.
--      Patient: [NAME] ([PAYER])
--      Day of Stay: [DAY]
--      Diagnosis: [DIAGNOSIS]
--      Situation: [CONTEXT FROM ALERT RULE]
--      Write clinical justification (200 words) to prevent denial.')
-- AS denial_prevention_letter;

-- ============================================================
-- QUERY: Revenue at risk calculation
-- ============================================================
SELECT
    payer_name,
    total_encounters,
    ROUND(denial_rate_pct * total_charged / 10000, 0) as estimated_annual_denials_dollars,
    pct_lines_denied,
    ROUND(total_outstanding, 0) as current_outstanding
FROM SNF_AI_HUB.REFERRAL_INTEL.denial_risk_by_payer_diagnosis
WHERE payer_name != 'NO_INSURANCE'
ORDER BY denial_rate_pct DESC;

-- ============================================================
-- QUERY: CMS National Benchmarks
-- ============================================================
SELECT 
    state,
    COUNT(*) as facilities,
    ROUND(AVG(overall_rating), 1) as avg_stars,
    ROUND(AVG(payment_denials), 2) as avg_denials,
    SUM(payment_denials) as total_denials
FROM SNF_AI_HUB.CMS_DATA.snf_star_ratings
GROUP BY state
ORDER BY total_denials DESC
LIMIT 20;
