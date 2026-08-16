import streamlit as st
from snowflake.snowpark.context import get_active_session

st.set_page_config(page_title="SNF Care Transition Narrator", page_icon="🏥", layout="wide")

session = get_active_session()

# --- Header ---
st.title("🏥 AI Care Transition Narrator")
st.caption("Skilled Nursing Facility | Powered by Snowflake Cortex AI")

# --- Sidebar: Metrics ---
st.sidebar.header("Portfolio Metrics")
metrics = session.sql("""
    SELECT 
        COUNT(*) as total,
        COUNT_IF(risk_tier = 'HIGH') as high,
        COUNT_IF(risk_tier = 'MEDIUM') as med,
        COUNT_IF(risk_tier = 'LOW') as low
    FROM SNF_AI_HUB.GOLD.transition_narratives
""").collect()[0]

st.sidebar.metric("Total Narratives", metrics['TOTAL'])
st.sidebar.metric("High Risk", metrics['HIGH'], delta=None)
st.sidebar.metric("Medium Risk", metrics['MED'])
st.sidebar.metric("Low Risk", metrics['LOW'])

st.sidebar.divider()
st.sidebar.markdown("**Readmission Stats**")
readmit = session.sql("""
    SELECT 
        COUNT(*) as total_transitions,
        COUNT_IF(readmitted_within_30_days) as readmitted,
        ROUND(COUNT_IF(readmitted_within_30_days)*100.0/COUNT(*),1) as rate
    FROM SNF_AI_HUB.GOLD.care_transitions
""").collect()[0]
st.sidebar.metric("30-Day Readmission Rate", f"{readmit['RATE']}%")
st.sidebar.metric("Total SNF Transitions", f"{readmit['TOTAL_TRANSITIONS']:,}")

# --- Main: Patient Selection ---
st.subheader("Select a Patient Transition")

patients_df = session.sql("""
    SELECT 
        tn.transition_id,
        tn.patient_id,
        pc.patient_name,
        pc.age,
        pc.gender,
        tn.risk_tier,
        tn.generated_at
    FROM SNF_AI_HUB.GOLD.transition_narratives tn
    JOIN SNF_AI_HUB.GOLD.snf_patient_cohort pc ON tn.patient_id = pc.PATIENT_ID
    ORDER BY tn.generated_at DESC
""").to_pandas()

# Filter by risk tier
risk_filter = st.selectbox("Filter by Risk Tier", ["All", "HIGH", "MEDIUM", "LOW"])
if risk_filter != "All":
    patients_df = patients_df[patients_df['RISK_TIER'] == risk_filter]

selected_patient = st.selectbox(
    "Choose a patient",
    patients_df['TRANSITION_ID'].tolist(),
    format_func=lambda x: f"{patients_df[patients_df['TRANSITION_ID']==x]['PATIENT_NAME'].values[0]} (Age {patients_df[patients_df['TRANSITION_ID']==x]['AGE'].values[0]}, {patients_df[patients_df['TRANSITION_ID']==x]['RISK_TIER'].values[0]} risk)"
)

if selected_patient:
    # Fetch full narrative
    narrative = session.sql(f"""
        SELECT tn.*, pc.patient_name, pc.age, pc.gender,
               ct.from_setting, ct.admission_date, ct.discharge_date, ct.length_of_stay, ct.readmitted_within_30_days
        FROM SNF_AI_HUB.GOLD.transition_narratives tn
        JOIN SNF_AI_HUB.GOLD.snf_patient_cohort pc ON tn.patient_id = pc.PATIENT_ID
        JOIN SNF_AI_HUB.GOLD.care_transitions ct ON tn.transition_id = ct.transition_id
        WHERE tn.transition_id = {selected_patient}
    """).collect()[0]

    # Patient header
    col1, col2, col3, col4 = st.columns(4)
    col1.metric("Patient", narrative['PATIENT_NAME'])
    col2.metric("Age / Gender", f"{narrative['AGE']}yo {narrative['GENDER']}")
    col3.metric("Risk Tier", narrative['RISK_TIER'])
    col4.metric("LOS (days)", narrative['LENGTH_OF_STAY'])

    if narrative['READMITTED_WITHIN_30_DAYS']:
        st.error("⚠️ This patient WAS readmitted within 30 days")
    
    st.divider()

    # Tabbed narrative display
    tab1, tab2, tab3, tab4, tab5 = st.tabs([
        "📋 Clinical Handoff", 
        "👨‍👩‍👧 Family Summary", 
        "💊 Medication Review", 
        "⚠️ Risk Factors", 
        "✅ Follow-up Actions"
    ])

    with tab1:
        st.subheader("Clinical Handoff Document")
        st.info(f"**Transition:** {narrative['FROM_SETTING'] or 'Unknown'} → SNF | **Admitted:** {narrative['ADMISSION_DATE']} | **Discharged:** {narrative['DISCHARGE_DATE']}")
        st.markdown(narrative['CLINICAL_HANDOFF'])

    with tab2:
        st.subheader("Patient & Family Summary")
        st.caption("Written at 6th grade reading level for patients and caregivers")
        st.markdown(narrative['FAMILY_SUMMARY'])

    with tab3:
        st.subheader("Medication Reconciliation")
        st.caption("Pharmacist-level review of current medications")
        st.markdown(narrative['MEDICATION_RECONCILIATION'])

    with tab4:
        st.subheader("Readmission Risk Factors")
        st.markdown(narrative['KEY_RISKS'])

    with tab5:
        st.subheader("Follow-up Action Plan")
        st.markdown(narrative['FOLLOW_UP_ACTIONS'])

    st.divider()
    st.caption(f"Generated: {narrative['GENERATED_AT']} | Powered by Snowflake Cortex AI (llama3.1-8b)")
