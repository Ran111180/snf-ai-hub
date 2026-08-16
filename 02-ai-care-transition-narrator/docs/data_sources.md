# Data Sources & Acquisition Strategy

## Overview

This document outlines where to get real CMS/healthcare data (free and paid) to power the Referral Intelligence Engine and Denial Prediction system.

---

## Free Public Data Sources (Available Now)

### 1. CMS PDPM Rate Tables (Reimbursement Rates)
**What:** Exact dollar amounts Medicare pays SNFs per patient per day, broken down by component (PT, OT, SLP, Nursing, NTA).

**URL:** https://www.cms.gov/medicare/payment/prospective-payment-systems/skilled-nursing-facility-snf/pdpm-payment-rates

**Format:** CSV/Excel, updated annually (FY2025 rates available)

**What you get:**
- Per-diem rates by PDPM classification group
- Urban vs Rural adjustments
- Wage index by geographic area
- Component rates (Physical Therapy, Nursing, Non-Therapy Ancillaries)

**Use in our product:** Calculate exact expected revenue per patient based on their PDPM group assignment.

---

### 2. CMS Skilled Nursing Facility Quality Reporting (Star Ratings)
**What:** Every SNF in the US rated 1-5 stars on quality measures, staffing, and health inspections.

**URL:** https://data.cms.gov/provider-data/dataset/4pq5-n9py

**Format:** CSV download, updated monthly

**Fields include:**
- Facility name, address, phone, ownership type
- Overall star rating (1-5)
- Health inspection rating
- Staffing rating
- Quality measures rating
- Number of certified beds
- Average daily census
- Ownership type (for-profit, non-profit, government)

**Use in our product:** Benchmark facility against competitors, identify market position.

---

### 3. CMS SNF Provider Data (Utilization & Cost)
**What:** Actual utilization data per SNF — number of stays, average LOS, costs, by diagnosis.

**URL:** https://data.cms.gov/provider-summary-by-type-of-service/medicare-physician-other-practitioners/medicare-provider-utilization-and-payment-data-physician-and-other-supplier

**SNF-specific:** https://data.cms.gov/provider-data/dataset/ijh5-nb2v (SNF utilization data)

**What you get:**
- Number of Medicare beneficiaries per facility
- Total days of care provided
- Medicare payments per facility
- Charges submitted vs amounts paid (denial signal!)

---

### 4. CMS Minimum Data Set (MDS) Public Quality Measures
**What:** Aggregated quality outcomes per SNF (falls, pressure ulcers, UTIs, antipsychotic use).

**URL:** https://data.cms.gov/provider-data/dataset/djen-97ju

**Fields include:**
- Percentage of residents with pressure ulcers
- Percentage who fall with major injury
- Percentage with UTI
- Percentage receiving antipsychotic medication
- Percentage who self-report moderate to severe pain
- Re-hospitalization rates

**Use in our product:** Compare predicted patient outcomes against facility's actual track record.

---

### 5. CMS Survey & Deficiency Data (Inspection Results)
**What:** Every CMS inspection finding for every SNF — what they got cited for.

**URL:** https://data.cms.gov/provider-data/dataset/r5ix-sfxw (Health Deficiencies)

**What you get:**
- Deficiency code (F-Tag)
- Severity level (isolated, pattern, widespread)
- Date of survey
- Scope and severity grid
- Whether deficiency was corrected

**Use in our product:** CMS Survey Readiness Engine (Product #1 from our portfolio).

---

### 6. Medicare Claims Data (Limited Data Set — Research)
**What:** Actual Medicare claims at patient level (de-identified).

**Access:** CMS Research Data Assistance Center (ResDAC) — requires Data Use Agreement

**URL:** https://resdac.org/

**What you get:** Actual claims, denial codes, dates of service, diagnosis codes, reimbursement amounts. This is the GOLD standard for denial prediction modeling.

**Caveat:** Requires formal application and $$ (fee per file). Used by research institutions and companies like Optum.

---

### 7. Snowflake Marketplace (Easiest for Us)
**What:** Pre-packaged healthcare datasets available directly in Snowflake.

**Relevant listings:**
- **Definitive Healthcare** — Hospital/SNF provider attributes, market intelligence
- **IQVIA** — Claims data, market access
- **Komodo Health** — Patient-level claims across payers
- **Datavant** — De-identified patient data

**Advantage:** Zero-copy sharing into our Snowflake account. No ETL needed. Query immediately.

---

## Free Data We Can Download TODAY

| Dataset | URL | Size | Format | Relevance |
|---------|-----|------|--------|-----------|
| SNF Star Ratings | data.cms.gov/provider-data/dataset/4pq5-n9py | ~15K rows | CSV | Facility benchmarking |
| SNF Deficiencies | data.cms.gov/provider-data/dataset/r5ix-sfxw | ~200K rows | CSV | Survey readiness |
| SNF Quality Measures | data.cms.gov/provider-data/dataset/djen-97ju | ~15K rows | CSV | Outcome benchmarks |
| PDPM Rate Tables | cms.gov/medicare/payment (PDPM section) | Small | Excel | Revenue calculation |
| SNF Utilization | data.cms.gov/provider-data/dataset/ijh5-nb2v | ~15K rows | CSV | Market analysis |
| ICD-10 Code Mapping | cms.gov/medicare/coding | ~70K rows | CSV | Diagnosis-to-PDPM mapping |

---

## Architecture: How Real Data Would Flow

```
FREE CMS DATA (download CSV)          SNOWFLAKE MARKETPLACE
├── Star Ratings                       ├── Definitive Healthcare
├── PDPM Rate Tables                   ├── Claims Data (if budget allows)
├── Quality Measures                   └── Market Intelligence
├── Deficiency Data
└── ICD-10 Mappings
        │                                       │
        ▼                                       ▼
┌─────────────────────────────────────────────────────────┐
│              SNOWFLAKE: SNF_AI_HUB                       │
├─────────────────────────────────────────────────────────┤
│  RAW LAYER (loaded from CSV / Marketplace share)         │
│  • cms_star_ratings                                      │
│  • cms_pdpm_rates                                        │
│  • cms_quality_measures                                  │
│  • cms_deficiencies                                      │
│  • icd10_pdpm_mapping                                    │
├─────────────────────────────────────────────────────────┤
│  ANALYTICS LAYER (joins with our synthetic patient data)│
│  • Expected revenue per diagnosis (PDPM rates × LOS)    │
│  • Facility benchmark comparison                        │
│  • Denial risk scoring (claims patterns)                │
│  • Market competition analysis                          │
├─────────────────────────────────────────────────────────┤
│  AI LAYER (Cortex AI)                                    │
│  • CLASSIFICATION: Denial probability                   │
│  • FORECAST: Expected LOS per diagnosis                 │
│  • AI_COMPLETE: Documentation to prevent denial         │
│  • ANOMALY_DETECTION: Unusual claim patterns            │
└─────────────────────────────────────────────────────────┘
```

---

## Denial Prediction Model (The Novel Part)

### What We Can Build With Current Data

From our CLAIMS table, we have:
- `STATUS1`, `STATUS2`, `STATUSP` — claim payment status
- `OUTSTANDING1`, `OUTSTANDING2`, `OUTSTANDINGP` — unpaid amounts
- `LASTBILLEDDATE1/2/P` — when last billed (repeated billing = denial/appeal)
- `HEALTHCARECLAIMTYPEID1/2` — claim type

**Signal for denial:** If OUTSTANDING > 0 and LASTBILLEDDATE is significantly after SERVICEDATE, that claim was likely denied or delayed.

### What We'd Build:

```sql
-- Identify denied/delayed claims (proxy from our data)
-- Claims where outstanding > 0 long after service = denial signal
SELECT 
    cl.ENCOUNTER_ID,
    e.ENCOUNTERCLASS,
    p.NAME as payer,
    cl.STATUS1,
    cl.OUTSTANDING1,
    cl.SERVICEDATE,
    cl.LASTBILLEDDATE1,
    DATEDIFF(day, cl.SERVICEDATE, cl.LASTBILLEDDATE1) as days_to_payment,
    CASE 
        WHEN cl.OUTSTANDING1 > 0 AND DATEDIFF(day, cl.SERVICEDATE, cl.LASTBILLEDDATE1) > 60 
        THEN 'LIKELY_DENIED'
        WHEN cl.OUTSTANDING1 > 0 
        THEN 'PENDING'
        ELSE 'PAID'
    END as payment_status_inferred
FROM claims cl
JOIN encounters e ON cl.ENCOUNTER_ID = e.ENCOUNTER_ID
JOIN payers p ON e.PAYER_ID = p.PAYER_ID
WHERE e.ENCOUNTERCLASS = 'snf';
```

### Use Cases We Can Demonstrate:

1. **Payer Denial Risk Score:** "Humana denies 22% of SNF hip fracture claims after day 14"
2. **Documentation Alert:** "Submit continued stay review by Day 12 to prevent denial"
3. **Revenue at Risk:** "Based on payer patterns, $4,200 of this stay's revenue is at risk of denial"
4. **Appeal Success Prediction:** "Similar denials were overturned 67% of the time with updated documentation"

---

## Next Steps (Prioritized)

### Immediate (This Session):
1. Download CMS Star Ratings CSV and load into Snowflake
2. Analyze our CLAIMS table for denial patterns
3. Build denial risk scoring using claim status patterns

### Short-term (Next Session):
4. Download PDPM rate tables, load into Snowflake
5. Build accurate revenue calculator using real PDPM rates
6. Add denial prediction alerts to the UI

### Medium-term (If Pursuing as Real Product):
7. Apply for CMS ResDAC data access (real claims)
8. Explore Snowflake Marketplace for commercial healthcare data
9. Build API integration for real-time insurance eligibility (270/271)
10. Partner with an EHR vendor (PointClickCare) for live data feed
