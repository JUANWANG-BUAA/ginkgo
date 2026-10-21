//! Local-only tasks. Dates are local calendar days, never a network workflow.
use crate::AppError;
use serde::{Deserialize, Serialize};
#[derive(Clone, Debug, Serialize, Deserialize, PartialEq, Eq)]
#[serde(deny_unknown_fields)]
pub struct Task {
    pub id: String,
    pub title: String,
    pub due: String,
    pub completed: bool,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Document {
    pub version: u32,
    pub tasks: Vec<Task>,
}
pub fn validate(title: &str, due: &str) -> Result<(), AppError> {
    if title.trim().is_empty()
        || title.chars().count() > 500
        || chrono::NaiveDate::parse_from_str(due, "%Y-%m-%d").is_err()
    {
        return Err(AppError::invalid());
    }
    Ok(())
}
pub fn parse(value: serde_json::Value) -> Result<Vec<Task>, AppError> {
    let document: Document = serde_json::from_value(value).map_err(|_| AppError::changed())?;
    if document.version != 1 {
        return Err(AppError::changed());
    }
    let mut ids = std::collections::HashSet::new();
    for task in &document.tasks {
        validate(&task.title, &task.due).map_err(|_| AppError::changed())?;
        if task.id.is_empty() || !ids.insert(&task.id) {
            return Err(AppError::changed());
        }
    }
    Ok(document.tasks)
}
