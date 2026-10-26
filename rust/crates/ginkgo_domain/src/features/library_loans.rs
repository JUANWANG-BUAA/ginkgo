//! Private, read-only loans. Dates and status remain school-provided text.
use serde::{Deserialize, Serialize};
#[derive(Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LibraryLoan {
    pub id: String,
    pub title: Option<String>,
    pub author: Option<String>,
    pub call_number: Option<String>,
    pub borrowed_at: Option<String>,
    pub due_at: Option<String>,
}
#[derive(Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct LibraryLoanPage {
    pub items: Vec<LibraryLoan>,
    pub page: u32,
    pub total: u32,
    pub has_more: bool,
}
