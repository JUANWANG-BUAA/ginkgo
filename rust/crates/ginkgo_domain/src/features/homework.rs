use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum HomeworkStatus {
    Pending,
    Submitted,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkItem {
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub course_role: Option<String>,
    pub id: String,
    pub course_id: Option<String>,
    pub course_name: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub teacher_name: Option<String>,
    pub title: String,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub status: HomeworkStatus,
    pub status_detail: Option<String>,
    pub score: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkPage {
    pub page_num: i32,
    pub pages: Option<i32>,
    pub has_next: Option<bool>,
    pub items: Vec<HomeworkItem>,
}

#[derive(Debug, Clone)]
pub struct HomeworkData {
    pub term_code: String,
    pub term_name: String,
    pub items: Vec<HomeworkItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct HomeworkDetail {
    /// Validated browser destination supplied by the provider, independent of the UI.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub source_url: Option<String>,
    pub content: Option<String>,
    pub published_at: Option<String>,
    pub due_at: Option<String>,
    pub score: Option<String>,
    pub status: HomeworkStatus,
    pub status_detail: Option<String>,
    pub submitted_at: Option<String>,
}
