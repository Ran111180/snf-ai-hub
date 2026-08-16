-- ============================================================
-- PDPM REVENUE OPTIMIZER - V2 & V3: AI Clinical Note Analysis
-- ============================================================
-- V1: Structured data comparison (CONDITIONS vs MDS) — SQL rules
-- V2: AI reads unstructured clinical notes → extracts missed diagnoses
-- V3: AI processes hospital discharge PDFs → finds gaps vs SNF coding
-- ============================================================

USE SCHEMA SNF_AI_HUB.PDPM;

-- ============================================================
-- V2: UNSTRUCTURED CLINICAL NOTE ANALYSIS
-- Input: Free-text physician/nursing notes from EHR
-- Output: PDPM-qualifying conditions not captured on MDS
-- ============================================================

-- Example: Real clinical note → AI extracts missed conditions
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
'You are a clinical coder extracting PDPM-qualifying diagnoses from a physician progress note.

PHYSICIAN PROGRESS NOTE:
"Patient Margaret Wilson, 82yo female, post-surgical day 5 following right hip ORIF. 
Continues to require mod assist x2 for transfers. Pain managed with scheduled Tylenol 
and PRN oxycodone 5mg PO q6h. Weight 198 lbs, BMI 32.4. Blood sugar this AM 187 - 
adjusted insulin sliding scale. Noted increased BUN 34/Cr 1.8 consistent with her 
known Stage 3 CKD. DEXA from last year confirms osteoporosis T-score -3.2. 
Patient reports feeling down, PHQ-9 score 12 (moderate depression). 
Chronic low back pain continues, uses heating pad. BP 158/92 on current regimen.
O2 sat 93% on RA, likely related to her obesity hypoventilation. Uses CPAP at night.
Has documented allergy to penicillin (anaphylaxis). Fall risk: HIGH per Morse scale."

CURRENT MDS DIAGNOSIS LIST (what is already coded):
1. Hip fracture (S72.001A)
2. Essential hypertension (I10)
3. Type 2 diabetes (E11.9)

TASK: Extract ALL PDPM-qualifying conditions mentioned in this note that are NOT 
already on the MDS list. For each, provide:
- Condition name and ICD-10 code
- Where in the note it was found (quote the text)
- PDPM component affected (Nursing comorbidity or NTA)
- Revenue impact if added to MDS

Format as structured list.') as v2_extracted_conditions;

-- ============================================================
-- V3: HOSPITAL DISCHARGE PDF ANALYSIS
-- Step 1: In production, use AI_PARSE_DOCUMENT to extract text from PDF
-- Step 2: AI_EXTRACT/AI_COMPLETE to find structured diagnoses
-- Step 3: Compare against SNF MDS coding
-- ============================================================

-- Production pipeline would be:
-- 
-- CREATE TABLE discharge_pdfs (
--     patient_id INT,
--     pdf_file VARCHAR,  -- path on stage
--     extracted_text TEXT,  -- from AI_PARSE_DOCUMENT
--     extracted_diagnoses VARIANT  -- from AI_EXTRACT
-- );
--
-- -- Step 1: Extract text from PDF
-- INSERT INTO discharge_pdfs (patient_id, pdf_file, extracted_text)
-- SELECT 
--     patient_id,
--     file_path,
--     SNOWFLAKE.CORTEX.AI_PARSE_DOCUMENT(@pdf_stage, file_path, 'text')
-- FROM incoming_referrals;
--
-- -- Step 2: Extract structured diagnoses from text
-- UPDATE discharge_pdfs
-- SET extracted_diagnoses = SNOWFLAKE.CORTEX.AI_EXTRACT(
--     extracted_text,
--     ['diagnosis_name', 'icd10_code', 'category']
-- );

-- Demo: Simulated discharge summary analysis
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b',
'You are a SNF admissions AI. Compare a hospital discharge summary against SNF MDS coding.

HOSPITAL DISCHARGE SUMMARY:
PRINCIPAL DIAGNOSIS: Right hip fracture s/p ORIF (S72.141A)
SECONDARY DIAGNOSES:
- Type 2 diabetes with CKD (E11.22)
- CKD Stage 3b (N18.32)
- Osteoporosis with fracture (M80.08XA)
- Major depression, moderate (F33.1)
- Morbid obesity BMI 38.2 (E66.01)
- Chronic pain (G89.29)
- Sleep apnea (G47.33)
- Iron deficiency anemia (D50.9)
PROCEDURES: Blood transfusion 2u PRBCs, IV Cefazolin x48hrs
MEDICATIONS: Insulin subQ daily, Enoxaparin subQ daily, Oxycodone PRN

SNF MDS (currently coded):
- Hip fracture ✓
- Hypertension ✓ 
- Diabetes (generic E11.9) ✓
- NTA: None coded

Find ALL revenue gaps. Calculate total daily gap and 21-day projected recovery.
List specific ICD-10 codes and MDS sections to update.') as v3_discharge_analysis;

-- ============================================================
-- PRODUCTION TABLE: Store AI analysis results
-- ============================================================
CREATE TABLE IF NOT EXISTS SNF_AI_HUB.PDPM.ai_coding_recommendations (
    recommendation_id INT AUTOINCREMENT,
    patient_id INT,
    encounter_id INT,
    analysis_type VARCHAR(10),  -- V1, V2, or V3
    source_document TEXT,       -- The text that was analyzed
    missed_conditions VARIANT,  -- Array of extracted conditions
    current_mds_codes VARIANT,  -- What's currently on MDS
    recommended_additions VARIANT, -- What should be added
    daily_revenue_gap FLOAT,
    total_revenue_opportunity FLOAT,
    ai_justification TEXT,     -- Full AI-generated recommendation
    status VARCHAR(20) DEFAULT 'PENDING',  -- PENDING, ACCEPTED, DISMISSED
    reviewed_by VARCHAR(200),
    reviewed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);
