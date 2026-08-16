import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="SNF Care Transition Narrator", page_icon="🏥", layout="wide")

session = get_active_session()

# --- Header ---
st.title("🏥 AI Care Transition Narrator")
st.caption("Skilled Nursing Facility | Powered by Snowflake Cortex AI | Human-in-the-Loop Approval")

# --- Sidebar: Metrics ---
st.sidebar.header("Dashboard Metrics")
metrics = session.sql("""
    SELECT 
        COUNT(*) as total,
        COUNT_IF(risk_tier = 'HIGH') as high,
        COUNT_IF(risk_tier = 'MEDIUM') as med,
        COUNT_IF(risk_tier = 'LOW') as low
    FROM SNF_AI_HUB.GOLD.transition_narratives
""").collect()[0]

st.sidebar.metric("Total Narratives", metrics['TOTAL'])

# Approval stats
approval_stats = session.sql("""
    SELECT status, COUNT(*) as cnt 
    FROM SNF_AI_HUB.GOLD.narrative_approvals GROUP BY status
""").to_pandas()

st.sidebar.divider()
st.sidebar.markdown("**Approval Pipeline**")
for _, row in approval_stats.iterrows():
    icon = {"DRAFT": "⚪", "IN_REVIEW": "🟡", "APPROVED": "🟢", "REJECTED": "🔴", "SENT": "📤"}.get(row['STATUS'], "⚪")
    st.sidebar.markdown(f"{icon} **{row['STATUS']}**: {row['CNT']}")

st.sidebar.divider()
readmit = session.sql("""
    SELECT ROUND(COUNT_IF(readmitted_within_30_days)*100.0/COUNT(*),1) as rate
    FROM SNF_AI_HUB.GOLD.care_transitions
""").collect()[0]
st.sidebar.metric("30-Day Readmission Rate", f"{readmit['RATE']}%")

# --- Main Tabs ---
main_tab1, main_tab2, main_tab3 = st.tabs(["📋 Review Queue", "📄 Patient Narratives", "📊 Quality Metrics"])

# ===== TAB 1: REVIEW QUEUE (Doctor's View) =====
with main_tab1:
    st.subheader("Clinician Review Queue")
    st.caption("Documents awaiting your review and approval")

    queue_df = session.sql("""
        SELECT 
            na.transition_id,
            na.status,
            na.assigned_to,
            na.assigned_role,
            tn.risk_tier,
            pc.patient_name,
            pc.age,
            pc.gender,
            ct.from_setting,
            ct.length_of_stay,
            na.assigned_at
        FROM SNF_AI_HUB.GOLD.narrative_approvals na
        JOIN SNF_AI_HUB.GOLD.transition_narratives tn ON na.transition_id = tn.transition_id
        JOIN SNF_AI_HUB.GOLD.snf_patient_cohort pc ON tn.patient_id = pc.PATIENT_ID
        JOIN SNF_AI_HUB.GOLD.care_transitions ct ON na.transition_id = ct.transition_id
        ORDER BY 
            CASE na.status WHEN 'IN_REVIEW' THEN 1 WHEN 'DRAFT' THEN 2 WHEN 'REJECTED' THEN 3 ELSE 4 END,
            CASE tn.risk_tier WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END
    """).to_pandas()

    # Filter
    status_filter = st.selectbox("Filter by Status", ["All", "IN_REVIEW", "APPROVED", "REJECTED"])
    if status_filter != "All":
        queue_df = queue_df[queue_df['STATUS'] == status_filter]

    st.dataframe(queue_df, use_container_width=True, hide_index=True)

    # Approval action
    st.divider()
    st.subheader("Take Action")
    pending = queue_df[queue_df['STATUS'] == 'IN_REVIEW']
    if len(pending) > 0:
        selected_tid = st.selectbox("Select transition to review",
            pending['TRANSITION_ID'].tolist(),
            format_func=lambda x: f"{pending[pending['TRANSITION_ID']==x]['PATIENT_NAME'].values[0]} ({pending[pending['TRANSITION_ID']==x]['RISK_TIER'].values[0]} risk)"
        )

        action = st.radio("Action", ["Approve as-is", "Approve with notes", "Reject & request regeneration"])
        notes = st.text_area("Review Notes (optional)")

        if st.button("Submit Decision", type="primary"):
            if "Approve" in action:
                session.sql(f"""
                    UPDATE SNF_AI_HUB.GOLD.narrative_approvals
                    SET status = 'APPROVED', reviewed_at = CURRENT_TIMESTAMP(),
                        reviewer_name = assigned_to, review_notes = '{notes}',
                        approved_at = CURRENT_TIMESTAMP(),
                        approval_expiry = DATEADD(hour, 72, CURRENT_TIMESTAMP()),
                        last_modified = CURRENT_TIMESTAMP()
                    WHERE transition_id = {selected_tid}
                """).collect()
                st.success(f"Approved transition {selected_tid}")
            else:
                session.sql(f"""
                    UPDATE SNF_AI_HUB.GOLD.narrative_approvals
                    SET status = 'REJECTED', reviewed_at = CURRENT_TIMESTAMP(),
                        rejected_at = CURRENT_TIMESTAMP(),
                        rejection_reason = '{notes}',
                        regeneration_requested = TRUE,
                        last_modified = CURRENT_TIMESTAMP()
                    WHERE transition_id = {selected_tid}
                """).collect()
                st.warning(f"Rejected transition {selected_tid} — flagged for regeneration")
            st.rerun()
    else:
        st.info("No documents pending review.")

# ===== TAB 2: PATIENT NARRATIVES =====
with main_tab2:
    st.subheader("Generated Transition Documents")

    patients_df = session.sql("""
        SELECT tn.transition_id, tn.patient_id, pc.patient_name, pc.age, pc.gender,
               tn.risk_tier, na.status as approval_status, na.assigned_to
        FROM SNF_AI_HUB.GOLD.transition_narratives tn
        JOIN SNF_AI_HUB.GOLD.snf_patient_cohort pc ON tn.patient_id = pc.PATIENT_ID
        LEFT JOIN SNF_AI_HUB.GOLD.narrative_approvals na ON tn.transition_id = na.transition_id
        ORDER BY tn.generated_at DESC
    """).to_pandas()

    selected_patient = st.selectbox("Choose a patient", patients_df['TRANSITION_ID'].tolist(),
        format_func=lambda x: f"{patients_df[patients_df['TRANSITION_ID']==x]['PATIENT_NAME'].values[0]} | {patients_df[patients_df['TRANSITION_ID']==x]['RISK_TIER'].values[0]} | {patients_df[patients_df['TRANSITION_ID']==x]['APPROVAL_STATUS'].values[0]}",
        key="patient_select_tab2"
    )

    if selected_patient:
        narrative = session.sql(f"""
            SELECT tn.*, pc.patient_name, pc.age, pc.gender,
                   ct.from_setting, ct.admission_date, ct.discharge_date, ct.length_of_stay, ct.readmitted_within_30_days,
                   na.status as approval_status, na.reviewer_name, na.approved_at
            FROM SNF_AI_HUB.GOLD.transition_narratives tn
            JOIN SNF_AI_HUB.GOLD.snf_patient_cohort pc ON tn.patient_id = pc.PATIENT_ID
            JOIN SNF_AI_HUB.GOLD.care_transitions ct ON tn.transition_id = ct.transition_id
            LEFT JOIN SNF_AI_HUB.GOLD.narrative_approvals na ON tn.transition_id = na.transition_id
            WHERE tn.transition_id = {selected_patient}
        """).collect()[0]

        # Status banner
        status = narrative['APPROVAL_STATUS']
        if status == 'APPROVED':
            st.success(f"✅ APPROVED by {narrative['REVIEWER_NAME']} on {narrative['APPROVED_AT']}")
        elif status == 'REJECTED':
            st.error("🔴 REJECTED — awaiting regeneration")
        elif status == 'IN_REVIEW':
            st.warning("🟡 IN REVIEW — awaiting clinician approval")
        else:
            st.info("⚪ DRAFT — not yet assigned for review")

        # Patient info
        col1, col2, col3, col4 = st.columns(4)
        col1.metric("Patient", narrative['PATIENT_NAME'])
        col2.metric("Age / Gender", f"{narrative['AGE']}yo {narrative['GENDER']}")
        col3.metric("Risk Tier", narrative['RISK_TIER'])
        col4.metric("LOS (days)", narrative['LENGTH_OF_STAY'])

        if narrative['READMITTED_WITHIN_30_DAYS']:
            st.error("⚠️ This patient WAS readmitted within 30 days")

        # Narrative tabs
        tab1, tab2, tab3, tab4, tab5 = st.tabs(["📋 Clinical Handoff", "👨‍👩‍👧 Family Summary", "💊 Medications", "⚠️ Risks", "✅ Follow-ups"])
        with tab1:
            st.markdown(narrative['CLINICAL_HANDOFF'])
        with tab2:
            st.markdown(narrative['FAMILY_SUMMARY'])
        with tab3:
            st.markdown(narrative['MEDICATION_RECONCILIATION'])
        with tab4:
            st.markdown(narrative['KEY_RISKS'])
        with tab5:
            st.markdown(narrative['FOLLOW_UP_ACTIONS'])

        # Disclaimer
        st.divider()
        st.caption("⚠️ AI-GENERATED DOCUMENT — Requires clinical review before use. Model: Snowflake Cortex llama3.1-8b")

# ===== TAB 3: QUALITY METRICS =====
with main_tab3:
    st.subheader("Quality & Approval Metrics")

    col1, col2, col3 = st.columns(3)

    approval_rate = session.sql("""
        SELECT 
            ROUND(COUNT_IF(status='APPROVED')*100.0/NULLIF(COUNT(*),0),1) as rate
        FROM SNF_AI_HUB.GOLD.narrative_approvals
    """).collect()[0]
    col1.metric("Approval Rate", f"{approval_rate['RATE'] or 0}%")

    rejection_rate = session.sql("""
        SELECT 
            ROUND(COUNT_IF(status='REJECTED')*100.0/NULLIF(COUNT(*),0),1) as rate
        FROM SNF_AI_HUB.GOLD.narrative_approvals
    """).collect()[0]
    col2.metric("Rejection Rate", f"{rejection_rate['RATE'] or 0}%")

    edit_rate = session.sql("""
        SELECT COUNT(*) as edits FROM SNF_AI_HUB.GOLD.narrative_edits
    """).collect()[0]
    col3.metric("Total Edits by Clinicians", edit_rate['EDITS'])

    # Audit trail
    st.divider()
    st.subheader("Recent Audit Trail")
    audit = session.sql("""
        SELECT action, actor, actor_role, action_timestamp, details
        FROM SNF_AI_HUB.GOLD.narrative_audit_log
        ORDER BY action_timestamp DESC LIMIT 20
    """).to_pandas()
    st.dataframe(audit, use_container_width=True, hide_index=True)
