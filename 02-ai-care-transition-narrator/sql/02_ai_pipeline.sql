-- ============================================================
-- SNF AI HUB - AI Care Transition Narrator
-- Step 2: Cortex AI Pipeline
-- ============================================================
-- Generates transition narratives using Snowflake Cortex AI
-- ============================================================

USE ROLE DATA_ENGINEER;
USE WAREHOUSE TASK_WH;
USE SCHEMA SNF_AI_HUB.GOLD;

-- ============================================================
-- STEP 1: Create the AI-generated transition documents table
-- ============================================================
CREATE OR REPLACE TABLE transition_narratives (
    transition_id INT,
    patient_id INT,
    generated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    risk_tier VARCHAR(10),          -- HIGH / MEDIUM / LOW
    clinical_handoff TEXT,          -- Provider-facing narrative
    family_summary TEXT,            -- Patient/family-facing summary
    medication_reconciliation TEXT, -- Medication review
    key_risks TEXT,                 -- Top risk factors identified
    follow_up_actions TEXT          -- Recommended follow-ups
);

-- ============================================================
-- STEP 2: Generate narratives for a sample of transitions
-- (Demonstrating the AI pipeline)
-- ============================================================

-- First, let's generate for a few patients to demonstrate
INSERT INTO transition_narratives (transition_id, patient_id, risk_tier, clinical_handoff, family_summary, medication_reconciliation, key_risks, follow_up_actions)
WITH sample_transitions AS (
    SELECT
        tp.transition_id,
        tp.PATIENT_ID,
        tp.admission_date,
        tp.discharge_date,
        tp.from_setting,
        tp.current_setting,
        tp.readmitted_within_30_days,
        tp.active_conditions,
        tp.active_medications,
        tp.allergies,
        pc.patient_name,
        pc.age,
        pc.gender
    FROM transition_patient_profiles tp
    JOIN snf_patient_cohort pc ON tp.PATIENT_ID = pc.PATIENT_ID
    WHERE tp.active_conditions IS NOT NULL
      AND ARRAY_SIZE(tp.active_conditions) > 0
    LIMIT 10  -- Generate for 10 patients to start
)
SELECT
    transition_id,
    PATIENT_ID,

    -- RISK CLASSIFICATION
    SNOWFLAKE.CORTEX.AI_CLASSIFY(
        'Patient: ' || age || ' year old ' || gender ||
        '. Conditions: ' || active_conditions::VARCHAR ||
        '. Medications: ' || COALESCE(active_medications::VARCHAR, 'None') ||
        '. Previously readmitted: ' || readmitted_within_30_days::VARCHAR,
        ['HIGH - Multiple comorbidities, medication complexity, or prior readmission',
         'MEDIUM - Some risk factors but manageable with standard follow-up',
         'LOW - Stable patient with straightforward discharge']
    ):label::VARCHAR AS risk_tier,

    -- CLINICAL HANDOFF NARRATIVE (Provider-facing)
    SNOWFLAKE.CORTEX.AI_COMPLETE('llama3.1-8b',
        'You are a clinical documentation specialist at a Skilled Nursing Facility. Generate a structured clinical handoff document for the receiving care team.

Patient: ' || patient_name || ', ' || age || ' year old ' || gender || '
Transition: ' || COALESCE(from_setting, 'Unknown') || ' → ' || current_setting || '
Admission: ' || admission_date::VARCHAR || ' | Discharge: ' || discharge_date::VARCHAR || '

Active Conditions: ' || COALESCE(active_conditions::VARCHAR, 'None documented') || '

Current Medications: ' || COALESCE(active_medications::VARCHAR, 'None documented') || '

Allergies: ' || COALESCE(allergies::VARCHAR, 'No known allergies') || '

Generate a clinical handoff with these sections:
1. CLINICAL SUMMARY (2-3 sentences about current status)
2. ACTIVE DIAGNOSES (prioritized list)
3. CRITICAL MEDICATIONS (with any interactions to watch)
4. PRECAUTIONS & ALERTS
5. PENDING ITEMS (labs, consults, follow-ups needed)

Be concise, factual, and clinically precise.'
    ) AS clinical_handoff,

    -- PATIENT/FAMILY SUMMARY (Plain English)
    SNOWFLAKE.CORTEX.AI_COMPLETE('llama3.1-8b',
        'You are a patient care coordinator. Write a simple, caring summary for the patient''s family about their transition from ' || COALESCE(from_setting, 'hospital') || ' to ' || current_setting || '.

Patient: ' || patient_name || ', ' || age || ' years old
Conditions being managed: ' || COALESCE(active_conditions::VARCHAR, 'General care') || '
Medications: ' || COALESCE(active_medications::VARCHAR, 'As prescribed') || '

Write in plain English (6th grade reading level). Include:
1. What happened and where they are now
2. What conditions are being treated
3. Medications they are taking and why
4. Warning signs to watch for (when to call the nurse)
5. What to expect in the coming days

Be warm, reassuring, but honest. Use short sentences.'
    ) AS family_summary,

    -- MEDICATION RECONCILIATION
    SNOWFLAKE.CORTEX.AI_COMPLETE('llama3.1-8b',
        'You are a clinical pharmacist reviewing medications for a care transition.

Patient: ' || patient_name || ', ' || age || ' year old ' || gender || '
Conditions: ' || COALESCE(active_conditions::VARCHAR, 'Not specified') || '
Current Medications: ' || COALESCE(active_medications::VARCHAR, 'None listed') || '
Allergies: ' || COALESCE(allergies::VARCHAR, 'NKDA') || '

Review and provide:
1. MEDICATION LIST (organized by condition)
2. POTENTIAL INTERACTIONS (any concerns between meds)
3. ALLERGY CONFLICTS (any medication vs allergy issues)
4. MONITORING NEEDED (labs, vitals to track)
5. RECOMMENDATIONS (changes, additions, or removals to consider)

Be specific and evidence-based.'
    ) AS medication_reconciliation,

    -- KEY RISKS
    SNOWFLAKE.CORTEX.AI_COMPLETE('llama3.1-8b',
        'Identify the top 3-5 risk factors for hospital readmission for this patient:
Age: ' || age || ', Gender: ' || gender || '
Conditions: ' || COALESCE(active_conditions::VARCHAR, 'None') || '
Medications: ' || COALESCE(active_medications::VARCHAR, 'None') || '
Prior readmission: ' || readmitted_within_30_days::VARCHAR || '

List each risk factor with a brief explanation of why it increases readmission risk. Be specific to THIS patient, not generic.'
    ) AS key_risks,

    -- FOLLOW-UP ACTIONS
    SNOWFLAKE.CORTEX.AI_COMPLETE('llama3.1-8b',
        'Generate specific follow-up actions for the care team managing this patient post-discharge:
Patient: ' || patient_name || ', ' || age || 'yo ' || gender || '
Setting: ' || current_setting || '
Conditions: ' || COALESCE(active_conditions::VARCHAR, 'General') || '
Medications: ' || COALESCE(active_medications::VARCHAR, 'Standard') || '

Provide actionable follow-up items:
1. Within 24 hours (immediate)
2. Within 7 days (first week)
3. Within 30 days (month)
Include specific appointments, labs, assessments needed. Format as a checklist.'
    ) AS follow_up_actions

FROM sample_transitions;

-- ============================================================
-- STEP 3: Verify the generated narratives
-- ============================================================
SELECT
    transition_id,
    patient_id,
    risk_tier,
    LEFT(clinical_handoff, 200) AS handoff_preview,
    LEFT(family_summary, 200) AS family_preview,
    generated_at
FROM transition_narratives
ORDER BY generated_at DESC
LIMIT 10;

-- ============================================================
-- STEP 4: Full narrative for one patient (detailed view)
-- ============================================================
SELECT *
FROM transition_narratives
WHERE transition_id = (SELECT MIN(transition_id) FROM transition_narratives);
