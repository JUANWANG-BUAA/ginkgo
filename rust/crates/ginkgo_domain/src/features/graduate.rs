use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReadRow {
    pub title: String,
    pub detail: String,
    /// Explicitly distinguishes a course with an unknown result from report metadata.
    #[serde(default, rename = "isCourse", skip_serializing_if = "is_false")]
    pub is_course: bool,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub completed: Option<bool>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub credit: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub semester: Option<String>,
}
fn is_false(value: &bool) -> bool {
    !value
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReadSection {
    pub title: String,
    pub rows: Vec<ReadRow>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub progress: Option<CreditProgress>,
}
/// Requirement and officially recognized credits; pending never reduces the gap.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreditProgress {
    pub required: Option<f64>,
    pub earned: Option<f64>,
    pub pending: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AcademicData {
    pub sections: Vec<ReadSection>,
    pub notice: Option<String>,
}
