use crate::AppError;
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Term {
    pub id: String,
    pub name: String,
    pub selected: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Week {
    pub number: i32,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub current: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseMeeting {
    pub id: String,
    pub name: String,
    pub day: i32,
    pub start_section: i32,
    pub end_section: i32,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub place: Option<String>,
    pub teacher: Option<String>,
    pub color: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Exam {
    pub id: String,
    pub course_name: String,
    pub course_no: Option<String>,
    pub exam_time_description: Option<String>,
    pub exam_date: Option<String>,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub exam_place: Option<String>,
    pub exam_seat_no: Option<String>,
    pub week: Option<i32>,
    pub exam_status: Option<String>,
    pub exam_type: Option<String>,
    pub task_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Course {
    pub id: String,
    pub name: String,
    pub day: i32,
    pub start_section: i32,
    pub end_section: i32,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    #[serde(rename = "termID")]
    pub term_id: String,
    pub week_number: i32,
    pub courses: Vec<Course>,
    pub term_courses: Option<BTreeMap<String, Vec<Course>>>,
}
#[derive(Debug, Deserialize)]
pub struct MergeRequest {
    pub previous: Option<Snapshot>,
    pub fetched: Snapshot,
}

impl Snapshot {
    fn validate(&self) -> Result<(), AppError> {
        if self.term_id.is_empty() || self.week_number < 1 {
            return Err(AppError::invalid());
        }
        for course in self.courses.iter().chain(
            self.term_courses
                .iter()
                .flat_map(|weeks| weeks.values().flatten()),
        ) {
            if !(1..=7).contains(&course.day)
                || !(1..=14).contains(&course.start_section)
                || course.end_section < course.start_section
                || course.end_section > 14
            {
                return Err(AppError::invalid());
            }
        }
        if self.term_courses.as_ref().is_some_and(|weeks| {
            weeks
                .keys()
                .any(|key| key.parse::<i32>().map_or(true, |n| n < 1))
        }) {
            return Err(AppError::invalid());
        }
        Ok(())
    }
    pub fn select_week(&self, week: i32) -> Option<Self> {
        let courses = self.term_courses.as_ref()?.get(&week.to_string())?.clone();
        Some(Self {
            week_number: week,
            courses,
            ..self.clone()
        })
    }
}

pub fn retain_weeks(request: MergeRequest) -> Result<Snapshot, AppError> {
    let mut fetched = request.fetched;
    fetched.validate()?;
    if let Some(previous) = &request.previous {
        previous.validate()?;
    }
    if fetched.term_courses.is_some() {
        return Ok(fetched);
    }
    let mut weeks = BTreeMap::new();
    if let Some(previous) = request
        .previous
        .filter(|old| old.term_id == fetched.term_id)
    {
        weeks = previous.term_courses.unwrap_or_default();
        weeks.insert(previous.week_number.to_string(), previous.courses);
    }
    weeks.insert(fetched.week_number.to_string(), fetched.courses.clone());
    fetched.term_courses = Some(weeks);
    Ok(fetched)
}

// ---- Undergraduate schedule (BYXT, API.md §2) ----
