# 02 — AI Care Transition Narrator

## Problem Statement
When patients transition between care settings (Hospital → SNF → Home), communication failures cause:
- 20% of adverse events post-discharge (WHO data)
- 30-day readmission rates costing $17B/year in the US
- Medication errors from incomplete reconciliation
- Missing follow-up appointments
- Family/caregiver confusion about care plan

Current state: Faxes, incomplete discharge summaries, no structured handoff.

## Solution
An AI-powered system that **generates comprehensive transition narratives** for every patient handoff:

1. **Clinical Handoff Document** (provider-facing): Complete medical summary, active conditions, medication reconciliation, pending results, risk flags
2. **Care Coordination Brief** (care team): Action items, follow-up schedule, escalation triggers
3. **Patient/Family Summary** (plain English): What happened, what to watch for, when to call doctor, medication schedule

## What Makes This Novel
- Not PREDICTION (everyone does readmission scores)
- It's GENERATION — the AI writes the actual document that prevents the bad outcome
- LLMs enable this; traditional ML could never generate coherent clinical narratives
- Combines structured data analysis + natural language generation in one pipeline

## Data Flow

```
PATIENTS + ENCOUNTERS + CONDITIONS + MEDICATIONS + ALLERGIES + OBSERVATIONS
    │
    ▼
┌─────────────────────────────────────────┐
│  GOLD LAYER: Patient Transition Profile │
│  • Full encounter timeline              │
│  • Active conditions at transition      │
│  • Current medications                  │
│  • Allergies                            │
│  • Recent observations/vitals           │
│  • Risk factors (prior readmissions)    │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  CORTEX AI PIPELINE                     │
│  1. AI_CLASSIFY → Risk tier (High/Med/Low)
│  2. AI_COMPLETE → Clinical narrative     │
│  3. AI_COMPLETE → Family-friendly summary│
│  4. AI_SUMMARIZE → Condition history     │
│  5. FORECAST → Expected LOS/cost        │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  OUTPUT: Transition Documents           │
│  • Provider Handoff (structured)        │
│  • Care Coordination Brief              │
│  • Patient/Family Summary               │
│  • Risk Score + Explanation             │
└─────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────┐
│  STREAMLIT DASHBOARD                    │
│  • Search by patient                    │
│  • Generate transition document         │
│  • View facility-level metrics          │
│  • Export PDF-ready format              │
└─────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Data Foundation (GOLD Layer)
- [ ] Create SNF patient cohort (patients with SNF encounters)
- [ ] Build patient transition timeline (encounter sequences)
- [ ] Create "transition event" table (Hospital→SNF, SNF→Home transitions)
- [ ] Aggregate patient profile at time of each transition (conditions, meds, allergies, vitals)

### Phase 2: AI Pipeline
- [ ] Risk classification (predict readmission risk tier using patient profile)
- [ ] Clinical narrative generation (AI_COMPLETE with structured prompt)
- [ ] Medication reconciliation narrative (flag conflicts, missing meds)
- [ ] Patient-friendly summary generation
- [ ] LOS/cost forecasting per transition

### Phase 3: Product Interface
- [ ] Streamlit app: patient search, transition document viewer
- [ ] Real-time generation (select patient → generate document on demand)
- [ ] Batch generation (nightly for all new transitions)
- [ ] Export/download capability

### Phase 4: Quality & Monitoring
- [ ] Evaluate narrative quality (clinical accuracy, completeness)
- [ ] Track readmission rates for patients WITH vs WITHOUT transition documents
- [ ] Dashboard: facility-level metrics (transitions/day, risk distribution, compliance)

## Cortex AI Functions Used

| Function | Purpose |
|----------|---------|
| AI_COMPLETE | Generate clinical narratives, family summaries, medication reconciliation |
| AI_CLASSIFY | Categorize transition risk (HIGH/MEDIUM/LOW) |
| AI_SUMMARIZE | Condense long encounter histories into key points |
| AI_EXTRACT | Pull structured data from condition descriptions |
| FORECAST | Predict expected LOS and cost for incoming SNF patients |
| ANOMALY_DETECTION | Flag unusual patterns (unexpected medication combinations) |

## Files Structure
```
02-ai-care-transition-narrator/
├── sql/
│   ├── 01_gold_layer_setup.sql        # Create GOLD schema and tables
│   ├── 02_patient_transitions.sql     # Build transition events
│   ├── 03_patient_profiles.sql        # Aggregate profile at transition time
│   ├── 04_ai_pipeline.sql             # Cortex AI calls for narrative generation
│   └── 05_metrics.sql                 # Monitoring and quality queries
├── streamlit/
│   └── app.py                         # Streamlit dashboard
├── prompts/
│   ├── clinical_handoff.md            # Prompt template for provider narrative
│   ├── family_summary.md              # Prompt template for patient/family
│   └── medication_reconciliation.md   # Prompt for med reconciliation
└── README.md                          # This file
```
