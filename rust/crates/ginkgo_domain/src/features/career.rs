//! Public career-fair values. The school's status string is preserved until
//! its business semantics have separately verified evidence.
use serde::Serialize;

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CareerEvent {
    pub id: String,
    pub title: String,
    pub campus: String,
    pub place: String,
    pub begins_at: String,
    pub ends_at: String,
    pub fair_type: String,
    pub status: String,
    pub url: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CareerEvents {
    pub month: String,
    pub events: Vec<CareerEvent>,
    pub fetched_at: String,
}
