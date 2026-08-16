# SNF AI Hub — Skilled Nursing Facility Intelligence Platform

**Production-ready AI products for Skilled Nursing Facilities built on Snowflake Cortex AI**

Powered by: Snowflake Cortex AI (LLMs, ML models, embeddings) + Synthetic Healthcare Data

## Data Source

```
Database: SYNTHETIC_HEALTHCARE_DATA_CLINICAL_AND_CLAIMS
Schema:   SILVER
```

| Table | Rows | Description |
|-------|------|-------------|
| PATIENTS | 1.4M | Demographics, income, location, birth/death dates |
| ENCOUNTERS | 64.5M | All visits (ambulatory, inpatient, SNF, ER, home, hospice) |
| CONDITIONS | 38.5M | Diagnoses with start/stop dates, ICD codes |
| CLAIMS | 124M | Medical claims with up to 8 diagnoses per claim |
| CLAIMS_TX | 887M | Claim transactions (line items) |
| MEDICATIONS | 59.6M | Prescriptions with start/stop, dosage |
| OBSERVATIONS | 763M | Vitals, lab results, assessments |
| PROCEDURES | 148.5M | All procedures performed |
| ALLERGIES | 1.3M | Patient allergies |
| CARE_PLANS | 3.9M | Active care plans |
| IMMUNIZATIONS | 11.5M | Vaccination records |
| DEVICES | 5.7M | Medical devices assigned |
| ORGANIZATIONS | 4K | Facilities/providers |
| PROVIDERS | 4K | Individual providers |
| PAYERS | 120 | Insurance payers |
| PAYER_TRANSITIONS | 6M | Insurance changes over time |

**SNF-specific stats:** 106K SNF encounters, 102K unique SNF patients, avg LOS 19.7 days, avg cost $16.8K/stay, 25K hospital-to-SNF transitions, ~1K 30-day readmissions.

---

## Product Portfolio (4 AI Products)

### 01 — CMS Survey Readiness Engine
**Problem:** SNFs get surprise CMS inspections. Deficiencies = fines, star rating drops, closure. Today it's reactive — consultants charge $50K+ per mock survey.

**Solution:** AI continuously monitors patient data against CMS F-Tag requirements and produces a daily "Survey Readiness Score" with specific deficiency risks and plain-English fixes.

**Cortex AI:** AI_COMPLETE (regulation interpretation, narrative recommendations), AI_CLASSIFY (deficiency risk scoring), FORECAST (compliance trend prediction)

**Status:** Planning

---

### 02 — AI Care Transition Narrator ← ACTIVE BUILD
**Problem:** When patients move Hospital → SNF → Home, handoff communication is terrible (faxes, incomplete records). 20% of adverse events post-discharge are from poor handoffs. This causes preventable readmissions ($17B/year problem).

**Solution:** For each patient transition, AI generates a comprehensive narrative handoff document — medications reconciled, risks flagged, follow-ups scheduled, plus a family-friendly plain-English summary.

**What makes it novel:** Not prediction (everyone does that). It's **generation** — the AI writes the document that prevents the bad outcome. LLMs enable this; traditional ML couldn't.

**Cortex AI:** AI_COMPLETE (narrative generation, medication reconciliation), AI_SUMMARIZE (condense encounter history), AI_CLASSIFY (risk tier), AI_EXTRACT (structured data from conditions), FORECAST (LOS prediction)

**Status:** In Development

---

### 03 — Conversational SNF Intelligence Agent
**Problem:** SNF administrators (non-technical) wait days for IT reports. They can't self-serve analytics. No "talk to your data" product exists for the SNF vertical.

**Solution:** Natural language interface — DONs and administrators ASK questions in plain English. "How many falls this month?" "Which patients are high-cost risk?" AI answers with data, charts, and recommendations.

**Cortex AI:** Cortex Analyst (semantic view, natural language → SQL), AI_COMPLETE (insight narratives), Cortex Search (documentation lookup)

**Status:** Planning

---

### 04 — PDPM Revenue Optimization AI
**Problem:** PDPM (Patient-Driven Payment Model) determines SNF reimbursement. Most facilities UNDER-CLASSIFY patients and lose 8-15% revenue. Existing tools show dashboards but don't tell you what to do differently or write supporting documentation.

**Solution:** AI analyzes each patient's clinical profile, identifies where classification is LOWER than supported by data, and generates the specific documentation narrative needed to justify the correct (higher) classification.

**Cortex AI:** AI_COMPLETE (documentation generation), AI_EXTRACT (clinical data → classification criteria), AI_CLASSIFY (PDPM component scoring), FORECAST (revenue impact projection)

**Status:** Planning

---

## Tech Stack

- **Snowflake** — Data warehouse, Cortex AI, Dynamic Tables, Streams, Tasks
- **Cortex AI** — LLM (AI_COMPLETE), ML (FORECAST, CLASSIFICATION, ANOMALY_DETECTION)
- **Streamlit in Snowflake** — Frontend dashboards
- **Python** — UDFs, data processing
- **GitHub Actions** — CI/CD

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  SNOWFLAKE PLATFORM                       │
├──────────────┬──────────────────┬────────────────────────┤
│ SILVER Layer │  GOLD Layer      │  AI/ML Layer           │
│ (Raw Data)   │  (Transformed)   │  (Cortex AI)           │
│              │                  │                        │
│ • Patients   │  • SNF Cohorts   │  • AI_COMPLETE         │
│ • Encounters │  • Risk Scores   │  • AI_CLASSIFY         │
│ • Conditions │  • Transitions   │  • AI_SUMMARIZE        │
│ • Claims     │  • Metrics       │  • FORECAST            │
│ • Meds       │  • Timelines     │  • ANOMALY_DETECTION   │
├──────────────┴──────────────────┴────────────────────────┤
│               STREAMLIT DASHBOARDS                        │
│  • Transition Narrator  • Survey Readiness  • Agent      │
└─────────────────────────────────────────────────────────┘
```

## Author

**Ranga Naik K** — Data Engineer | Snowflake + Healthcare AI

---

*Built with Snowflake Cortex AI on synthetic healthcare data, August 2026*
