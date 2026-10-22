use crate::AppError;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Course {
    pub id: i64,
    pub name: String,
    pub teacher: Option<String>,
    pub position: Option<String>,
    pub category: Option<String>,
    pub subcategory: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub details: Option<CourseDetails>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseDetails {
    pub start: Option<String>,
    pub end: Option<String>,
    pub select_start: Option<String>,
    pub select_end: Option<String>,
    pub cancel_end: Option<String>,
    pub capacity: Option<i64>,
    pub enrolled: Option<i64>,
    pub campuses: Vec<String>,
    pub summary: Option<String>,
    pub selected: Option<bool>,
    pub has_sign_config: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(tag = "kind", content = "value", rename_all = "snake_case")]
pub enum Category {
    All,
    Named(String),
    Unclassified,
}
#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Filter {
    pub search_text: String,
    pub category: Category,
}
#[derive(Debug, Deserialize)]
pub struct Request {
    pub courses: Vec<Course>,
    pub filter: Filter,
}
#[derive(Debug, Serialize)]
pub struct Count {
    pub category: Category,
    pub count: usize,
}
#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ResultSet {
    #[serde(rename = "matchingCourseIDs")]
    pub matching_course_ids: Vec<i64>,
    pub category_counts: Vec<Count>,
}

fn category(course: &Course) -> Category {
    [&course.subcategory, &course.category]
        .into_iter()
        .filter_map(|s| s.as_ref())
        .map(|s| s.trim())
        .find(|s| !s.is_empty())
        .map_or(Category::Unclassified, |s| Category::Named(s.into()))
}

pub fn filter(request: Request) -> Result<ResultSet, AppError> {
    if matches!(&request.filter.category, Category::Named(s) if s.trim().is_empty()) {
        return Err(AppError::invalid());
    }
    let search = request.filter.search_text.trim().to_lowercase();
    let mut counts = BTreeMap::<Category, usize>::new();
    let mut matching_course_ids = vec![];
    for course in request.courses {
        let category = category(&course);
        *counts.entry(category.clone()).or_default() += 1;
        if request.filter.category != Category::All && request.filter.category != category {
            continue;
        }
        if search.is_empty()
            || [
                Some(&course.name),
                course.teacher.as_ref(),
                course.position.as_ref(),
            ]
            .into_iter()
            .flatten()
            .any(|s| s.to_lowercase().contains(&search))
        {
            matching_course_ids.push(course.id);
        }
    }
    let mut category_counts: Vec<_> = counts
        .into_iter()
        .map(|(category, count)| Count { category, count })
        .collect();
    category_counts.sort_by(|a, b| {
        b.count
            .cmp(&a.count)
            .then_with(|| a.category.cmp(&b.category))
    });
    Ok(ResultSet {
        matching_course_ids,
        category_counts,
    })
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Catalog {
    pub terms: Vec<Semester>,
    pub courses: Vec<Course>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Semester {
    pub id: String,
    pub name: String,
    pub start: Option<String>,
    pub end: Option<String>,
}

/// A chosen-record ID is distinct from its nested course ID. Only fields shown
/// by the native client leave this boundary; sign configuration and homework
/// payloads are deliberately omitted.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChosenCourse {
    pub id: i64,
    pub course: Course,
    pub selected_at: Option<String>,
    pub checkin: Option<i64>,
    pub passed: Option<i64>,
    pub score: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChosenCourses {
    pub term: Option<Semester>,
    /// None means no valid semester range was available, not zero selections.
    pub courses: Option<Vec<ChosenCourse>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StatisticsEntry {
    pub category: String,
    pub subcategory: String,
    pub required: i64,
    pub completed: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LearningStatistics {
    pub valid_course_count: Option<i64>,
    pub entries: Vec<StatisticsEntry>,
}

fn semester_date(value: &str) -> Option<chrono::DateTime<chrono_tz::Tz>> {
    use chrono::{NaiveDate, NaiveDateTime, TimeZone};
    let zone = chrono_tz::Asia::Shanghai;
    if let Ok(date) = chrono::DateTime::parse_from_rfc3339(value) {
        return Some(date.with_timezone(&zone));
    }
    ["%Y-%m-%d %H:%M:%S%.f", "%Y-%m-%dT%H:%M:%S%.f"]
        .iter()
        .find_map(|format| NaiveDateTime::parse_from_str(value, format).ok())
        .or_else(|| {
            NaiveDate::parse_from_str(value, "%Y-%m-%d")
                .ok()?
                .and_hms_opt(0, 0, 0)
        })
        .and_then(|date| zone.from_local_datetime(&date).single())
}

/// Same active-first, latest-end fallback as BykcSemesterPolicy.swift. Naive
/// school timestamps are interpreted in Beijing independently of device locale.
///
/// ```
/// use ginkgo_domain::features::bykc::{current_semester, Semester};
/// let terms = vec![Semester {
///     id: "1".into(), name: "Synthetic term".into(),
///     start: Some("2026-09-01 00:00:00".into()),
///     end: Some("2027-01-31 23:59:59".into()),
/// }];
/// let active = current_semester(&terms, "2026-08-31T16:00:00Z")?;
/// assert_eq!(active.map(|term| term.id), Some("1".into()));
/// # Ok::<(), ginkgo_domain::AppError>(())
/// ```
pub fn current_semester(terms: &[Semester], instant: &str) -> Result<Option<Semester>, AppError> {
    let now = chrono::DateTime::parse_from_rfc3339(instant).map_err(|_| AppError::invalid())?;
    Ok(terms
        .iter()
        .find(|term| {
            term.start
                .as_deref()
                .and_then(semester_date)
                .is_some_and(|start| {
                    term.end
                        .as_deref()
                        .and_then(semester_date)
                        .is_some_and(|end| start <= now && now <= end)
                })
        })
        .or_else(|| {
            terms
                .iter()
                .max_by_key(|term| term.end.as_deref().and_then(semester_date))
        })
        .cloned())
}

pub fn semester_range(term: &Semester) -> Option<(String, String)> {
    let start = semester_date(term.start.as_deref()?)?;
    let end = semester_date(term.end.as_deref()?)?;
    (start <= end).then(|| {
        (
            start.format("%Y-%m-%d %H:%M:%S").to_string(),
            end.format("%Y-%m-%d %H:%M:%S").to_string(),
        )
    })
}
