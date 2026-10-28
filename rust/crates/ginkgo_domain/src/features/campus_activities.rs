//! Public campus cultural activities. Published dates and displayed event
//! wording are preserved separately; neither is interpreted as a deadline.
use serde::Serialize;

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CampusActivity {
    pub id: String,
    pub title: String,
    pub category: String,
    pub published_at: String,
    pub activity_time: String,
    pub place: String,
    pub url: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CampusActivities {
    pub page: i32,
    pub activities: Vec<CampusActivity>,
    pub fetched_at: String,
}
