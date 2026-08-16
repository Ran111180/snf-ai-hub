# PDPM Revenue Optimizer

## Problem Statement

Skilled Nursing Facilities using Medicare's Patient-Driven Payment Model (PDPM) systematically **undercode patients** on MDS assessments, leaving $1,500-$6,000 per patient on the table. For a 50-facility chain with 5,000 Medicare admissions/year, this represents **$3-5 million in lost annual revenue** that the facility is clinically entitled to but fails to capture.

## Why This Happens

1. **MDS Coordinators are overwhelmed** — 87+ items to code per patient, time pressure
2. **Comorbidities get missed** — patient has 8 conditions but only 3 get coded on MDS
3. **NTA services aren't captured** — IV medications, wound care, injections qualify for higher rates but go undocumented
4. **No feedback loop** — coders never learn they missed revenue because no one checks
5. **Conservative coding culture** — fear of audits makes staff code LOW rather than risk coding HIGH

## What This Product Does

Takes a patient's clinical profile (conditions, medications, procedures) and:

1. **Classifies** into optimal PDPM components using AI analysis of clinical data
2. **Compares** the AI-recommended rate vs the actual billed rate
3. **Identifies the gap** — which specific conditions/services are being missed
4. **Generates documentation** — exact MDS language needed to support the higher classification
5. **Quantifies revenue impact** — per patient, per facility, per chain

## PDPM Components (How Payment is Determined)

```
Daily Rate = PT + OT + SLP + Nursing + NTA + Non-Case-Mix

NURSING COMPONENT (biggest opportunity):
├── Clinical Category (primary diagnosis group)
├── + Comorbidity Count (0, 1, 2+)
├── = Nursing Classification (A through E)
└── Higher classification = $50-150 MORE per day

NTA COMPONENT (Non-Therapy Ancillaries):
├── Extensive Services (IV, ventilator, dialysis, chemo, radiation, wound care, blood transfusion)
├── + Special Treatments count
├── = NTA Classification (A through F)  
└── Higher classification = $30-100 MORE per day

PT/OT/SLP COMPONENTS:
├── Functional Status (Section GG scores)
├── + Cognitive Status
├── = Therapy Classification
└── Based on how much help patient needs with ADLs
```

## Revenue Impact Model

| Scenario | Per Patient | Per Facility (500 admits/yr) | Per Chain (50 facilities) |
|----------|------------|----------------------------|--------------------------|
| Catch 1 missed comorbidity | +$1,500 | +$225,000 | +$11.25M |
| Catch 1 missed NTA service | +$2,000 | +$300,000 | +$15M |
| Full optimization (avg gap) | +$2,500 | +$375,000 | +$18.75M |

Conservative estimate (30% of patients undercoded by 1 component):
- 500 admissions × 30% = 150 undercoded patients
- 150 × $2,000 avg gap = **$300,000/year per facility**
- × 50 facilities = **$15 million/year for the chain**

## Technical Architecture

```
Patient Clinical Data (Conditions + Medications + Procedures)
    │
    ▼
┌─────────────────────────────────────────────┐
│  PDPM CLASSIFICATION ENGINE (Snowflake)      │
│                                              │
│  1. Map conditions → PDPM Clinical Category  │
│  2. Count qualifying comorbidities           │
│  3. Identify NTA-qualifying services         │
│  4. Calculate OPTIMAL daily rate             │
│  5. Compare vs ACTUAL billed rate            │
│  6. Flag undercoded patients (gap > $100/day)│
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  CORTEX AI (Documentation Generator)         │
│                                              │
│  For each flagged patient:                   │
│  - Explain WHY higher classification applies │
│  - Generate MDS-supporting language          │
│  - Cite specific conditions/meds as evidence │
└─────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────┐
│  REVENUE DASHBOARD (Next.js)                 │
│                                              │
│  - Facility-level revenue leakage summary    │
│  - Patient-level recommendations             │
│  - AI documentation generator                │
│  - Accept/Dismiss/Flag workflow              │
└─────────────────────────────────────────────┘
```

## Compliance & Legal

- This tool identifies LEGITIMATE undercoding only
- It does NOT recommend overcoding or upcoding (fraud)
- All recommendations are backed by clinical documentation in the patient record
- Matches CMS guidelines for PDPM classification
- Audit-safe: every recommendation includes the clinical evidence
