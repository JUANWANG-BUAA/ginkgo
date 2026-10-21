//! Coarse outcomes for user-confirmed, single-attempt upstream mutations.
//! No raw server text, identifiers or credentials cross this boundary.
use serde::Serialize;
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub enum MutationState {
    Accepted,
    Rejected,
    Uncertain,
    NotSubmitted,
}
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct MutationOutcome {
    pub state: MutationState,
    pub message: String,
}
impl MutationOutcome {
    pub fn new(state: MutationState, message: &str) -> Self {
        Self {
            state,
            message: message.into(),
        }
    }
    pub fn uncertain() -> Self {
        Self::new(
            MutationState::Uncertain,
            "提交结果待确认，请刷新状态核实，勿重复提交",
        )
    }
    pub fn not_submitted(message: &str) -> Self {
        Self::new(MutationState::NotSubmitted, message)
    }
}
