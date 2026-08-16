# Competitive Landscape & Market Context

## Who's Doing What in US Healthcare AI

| Company | What They Do | Their Strength | Gap We Fill |
|---------|-------------|---------------|-------------|
| **Jvion** (Lightbeam Health) | Readmission risk scoring, patient vectors | Risk prediction at scale | They PREDICT risk but don't GENERATE the handoff document that prevents it |
| **Pieces Technologies** | Clinical AI documentation assistant | Inpatient clinical notes from EHR data | Focused on inpatient acute care, NOT SNF-specific transitions |
| **Regard** | Auto-diagnosis suggestion engine | Finds missed diagnoses in charts | No transition narrative generation, no family-facing output |
| **Abridge** | AI clinical note-taking from audio | Real-time transcription + summarization | Audio-based (needs mic), not structured data → narrative |
| **PointClickCare** | SNF EHR platform (market leader, 70% of US SNFs) | Has ALL the data, dominant market position | NO AI narrative generation layer — still manual discharge summaries |
| **MatrixCare** (ResMed) | SNF EHR + post-acute platform | Strong in home health + SNF | Basic reporting, no LLM-powered document generation |
| **Netsmart** | Behavioral health + post-acute EHR | Strong in behavioral/mental health SNFs | Limited AI capabilities, no transition narratives |
| **WellSky** | Post-acute analytics + care coordination | Cross-continuum visibility | Analytics/dashboards but not AI-generated clinical documents |
| **Innovaccer** | Health cloud data platform | Data unification across settings | Infrastructure layer, not clinical document generation |
| **Curation Health** | AI for risk adjustment documentation | Captures missed diagnoses for HCC coding | Revenue focus, not care transition quality |

## Key Regulatory Context

| Regulation | What It Means | How It Affects This Product |
|-----------|--------------|---------------------------|
| **CMS IMPACT Act** | Requires standardized patient assessment data across post-acute settings | Transition documents must follow standardized formats |
| **TEFCA (2026)** | Trusted Exchange Framework — facilities MUST share health data electronically | Creates MANDATE for structured transition documents |
| **CMS Interoperability Rules** | Patients have right to their health data in computable format | Family-friendly summaries align with patient access rights |
| **21st Century Cures Act** | Information blocking is illegal — can't withhold patient data | AI-generated summaries support anti-blocking compliance |
| **SNF VBP Program** | Value-Based Purchasing ties payment to readmission rates | Direct financial incentive to prevent readmissions via better handoffs |
| **HIPAA** | PHI must be protected in transit, storage, and processing | All AI outputs containing PHI need access controls + audit |

## Market Size

- **15,000+** Skilled Nursing Facilities in the US
- **1.3 million** SNF beds
- **$17 billion/year** cost of preventable readmissions
- **~25%** national SNF 30-day readmission rate (CMS target: reduce below 20%)
- **$200K+** average CMS penalty per facility for high readmission rates
