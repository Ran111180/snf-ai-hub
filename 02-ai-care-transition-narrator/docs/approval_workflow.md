# Doctor Review & Approval Workflow

## Overview

No AI-generated transition document goes to a patient or next care setting without clinician review and explicit approval. This is non-negotiable in healthcare AI.

---

## Workflow States

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌───────────┐
│  DRAFT   │────▶│  IN_REVIEW   │────▶│   APPROVED   │────▶│  SENT     │
│(AI-gen)  │     │(assigned MD) │     │(MD signed)   │     │(delivered)│
└──────────┘     └──────┬───────┘     └──────────────┘     └───────────┘
                        │
                        ▼
                 ┌──────────────┐
                 │   REJECTED   │──── (goes back to AI for regeneration
                 │(needs rework)│      or manual override by MD)
                 └──────────────┘
```

### State Definitions

| State | Who Sees It | What Happens |
|-------|-------------|--------------|
| `DRAFT` | System only | AI just generated it. No human has seen it. Quality checks running. |
| `IN_REVIEW` | Assigned clinician | Doctor/NP opens it in dashboard, reads, can edit any section. |
| `APPROVED` | Care team, patient (if family summary) | Clinician digitally signed. Locked from further edits. |
| `REJECTED` | System + assigned clinician | Clinician flagged issues. Goes back for regeneration or manual rewrite. |
| `SENT` | External recipients | Document transmitted to next care setting / patient portal. |

---

## Who Can Review & Approve

| Role | Can View | Can Edit | Can Approve | Can Send |
|------|----------|----------|-------------|----------|
| AI System | Generate | No | No | No |
| RN (Registered Nurse) | Yes | Yes (clinical notes) | No (flag for MD) | No |
| NP (Nurse Practitioner) | Yes | Yes | Yes (clinical handoff) | Yes |
| MD (Physician) | Yes | Yes | Yes (all documents) | Yes |
| Medical Director | Yes | Yes | Yes + override rejected | Yes |
| Care Coordinator | Yes (family summary only) | Yes (family summary) | No | Yes (family only, after MD approves clinical) |
| Patient/Family | Approved family summary only | No | No | N/A |

---

## Database Schema for Approval Workflow

```sql
-- Approval tracking table
CREATE TABLE SNF_AI_HUB.GOLD.narrative_approvals (
    approval_id INT AUTOINCREMENT,
    transition_id INT NOT NULL,
    
    -- Current state
    status VARCHAR(20) DEFAULT 'DRAFT',  -- DRAFT, IN_REVIEW, APPROVED, REJECTED, SENT
    
    -- Assignment
    assigned_to VARCHAR(200),            -- Clinician username/ID
    assigned_role VARCHAR(50),           -- MD, NP, RN, COORDINATOR
    assigned_at TIMESTAMP,
    
    -- Review details
    reviewed_at TIMESTAMP,
    reviewer_name VARCHAR(200),
    reviewer_credentials VARCHAR(50),    -- MD, DO, NP, PA
    review_notes TEXT,                   -- Clinician's comments
    
    -- Edits tracking
    sections_edited ARRAY,               -- ['clinical_handoff', 'family_summary']
    edit_reason TEXT,                     -- Why edits were made
    
    -- Approval
    approved_at TIMESTAMP,
    digital_signature VARCHAR(500),      -- Hash of reviewer + timestamp + content
    approval_expiry TIMESTAMP,           -- Approved docs expire after 72 hours if not sent
    
    -- Rejection
    rejected_at TIMESTAMP,
    rejection_reason TEXT,
    regeneration_requested BOOLEAN DEFAULT FALSE,
    
    -- Sending
    sent_at TIMESTAMP,
    sent_to VARCHAR(500),                -- Receiving facility/patient portal
    send_method VARCHAR(50),             -- FHIR, DIRECT_MESSAGE, FAX, PORTAL
    
    -- Audit
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    last_modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
);

-- Edited versions table (tracks what the doctor changed)
CREATE TABLE SNF_AI_HUB.GOLD.narrative_edits (
    edit_id INT AUTOINCREMENT,
    transition_id INT,
    section_name VARCHAR(50),            -- clinical_handoff, family_summary, etc.
    original_text TEXT,                  -- What AI generated
    edited_text TEXT,                    -- What clinician changed it to
    edited_by VARCHAR(200),
    edited_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    edit_type VARCHAR(20)               -- CORRECTION, ADDITION, REMOVAL, REWRITE
);

-- Audit log (every action on every document)
CREATE TABLE SNF_AI_HUB.GOLD.narrative_audit_log (
    log_id INT AUTOINCREMENT,
    transition_id INT,
    action VARCHAR(50),                  -- GENERATED, ASSIGNED, VIEWED, EDITED, APPROVED, REJECTED, SENT
    actor VARCHAR(200),
    actor_role VARCHAR(50),
    action_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP(),
    details TEXT                          -- JSON with additional context
);
```

---

## How It Works in the Streamlit App

### Doctor's View (after login):

```
┌─────────────────────────────────────────────────────────────┐
│  📋 My Review Queue                              [3 pending] │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  🔴 HIGH RISK | Toshia Kunze, 96yo F                        │
│     Generated: 2 hours ago | From: ER → SNF                │
│     [Review Now]                                            │
│                                                              │
│  🟡 MEDIUM | Keli Hirthe, 50yo F                            │
│     Generated: 3 hours ago | From: Inpatient → SNF         │
│     [Review Now]                                            │
│                                                              │
│  🟢 LOW | James Wilson, 45yo M                              │
│     Generated: 5 hours ago | From: Inpatient → SNF         │
│     [Review Now]                                            │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Review Screen:

```
┌─────────────────────────────────────────────────────────────┐
│  Patient: Toshia Kunze, 96yo F | Risk: HIGH                │
│  Transition: Emergency → SNF | LOS: 22 days                │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  [Tab: Clinical Handoff] [Family Summary] [Meds] [Risks]   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AI-Generated Text (editable):                       │   │
│  │                                                       │   │
│  │  **Summary:** Toshia Kunze is a 96-year-old female   │   │
│  │  transferring from ER to SNF after a fall resulting  │   │
│  │  in forearm fracture and pathological fracture...    │   │
│  │                                                       │   │
│  │  [Edit ✏️] [Looks Good ✓]                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ⚠️ System Flags:                                           │
│  - Patient has 5+ active conditions (complex case)          │
│  - Osteoporosis + Naproxen: GI bleeding risk noted         │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Review Notes (optional):                            │   │
│  │  [___________________________________________]       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  [🔴 Reject & Regenerate]  [🟡 Approve with Edits]  [🟢 Approve as-is]   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Approval Routing Logic

```
IF risk_tier = 'HIGH':
    → Route to MD/Medical Director (must be physician)
    → Auto-escalate if not reviewed within 4 hours

IF risk_tier = 'MEDIUM':
    → Route to NP or MD
    → Auto-escalate if not reviewed within 8 hours

IF risk_tier = 'LOW':
    → Route to NP or RN (RN can flag for MD if unsure)
    → Auto-escalate if not reviewed within 12 hours

IF quality_check = 'FAILED':
    → Route directly to Medical Director
    → Block sending until MD explicitly approves
```

---

## Edit Tracking (What Changed)

When a doctor edits an AI-generated section:
1. Original AI text is preserved in `narrative_edits.original_text`
2. Doctor's version saved in `narrative_edits.edited_text`
3. Diff is available for quality improvement (learn from corrections)
4. Over time: if doctors consistently edit the same pattern, we retune the prompts

```sql
-- Example: Find most commonly edited sections (prompt improvement signal)
SELECT 
    section_name,
    COUNT(*) as times_edited,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM narrative_approvals WHERE status = 'APPROVED'), 1) as edit_rate_pct
FROM SNF_AI_HUB.GOLD.narrative_edits
GROUP BY section_name
ORDER BY times_edited DESC;

-- If edit rate > 30% for a section → prompts need improvement
```

---

## Digital Signature & Legal Compliance

```sql
-- When doctor approves, generate a digital signature
UPDATE narrative_approvals
SET 
    status = 'APPROVED',
    approved_at = CURRENT_TIMESTAMP(),
    digital_signature = SHA2(
        reviewer_name || '|' || 
        transition_id::VARCHAR || '|' || 
        CURRENT_TIMESTAMP()::VARCHAR || '|' ||
        (SELECT clinical_handoff FROM transition_narratives WHERE transition_id = :tid)
    ),
    approval_expiry = DATEADD(hour, 72, CURRENT_TIMESTAMP())
WHERE transition_id = :tid;
```

The digital signature proves:
- WHO approved (reviewer_name)
- WHAT they approved (content hash)
- WHEN they approved (timestamp)
- Content hasn't been tampered with after approval (hash verification)

---

## Expiry & Re-review

- Approved documents expire after **72 hours** if not sent
- If patient's conditions change (new encounter, new medication), document is auto-invalidated
- Monthly spot-check: random 10% of approved docs reviewed by Medical Director for quality
