use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TodayCourse {
    pub name: String,
    pub place: Option<String>,
    pub time: Option<String>,
    pub short_name: Option<String>,
}
