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
fn details(row: &serde_json::Value) -> Result<Option<CourseDetails>, AppError> {
    use serde_json::Value;
    let keys = [
        "courseStartDate",
        "courseEndDate",
        "courseSelectStartDate",
        "courseSelectEndDate",
        "courseCancelEndDate",
        "courseMaxCount",
        "courseCurrentCount",
        "courseCampusList",
        "courseCampus",
        "courseDesc",
        "selected",
        "courseSignConfig",
    ];
    if !keys.iter().any(|key| row.get(key).is_some()) {
        return Ok(None);
    }
    let text = |key: &str| -> Result<Option<String>, AppError> {
        match row.get(key) {
            None | Some(Value::Null) => Ok(None),
            Some(Value::String(s)) => Ok(Some(s.trim().to_owned()).filter(|s| !s.is_empty())),
            _ => Err(AppError::changed()),
        }
    };
    let number = |key: &str| -> Result<Option<i64>, AppError> {
        match row.get(key) {
            None | Some(Value::Null) => Ok(None),
            Some(v) => v
                .as_i64()
                .or_else(|| v.as_str()?.parse().ok())
                .filter(|n| *n >= 0)
                .map(Some)
                .ok_or_else(AppError::changed),
        }
    };
    let mut campuses = std::collections::BTreeSet::new();
    if let Some(value) = row.get("courseCampusList").filter(|v| !v.is_null()) {
        for value in value.as_array().ok_or_else(AppError::changed)? {
            let name = value.as_str().ok_or_else(AppError::changed)?.trim();
            if !name.is_empty() {
                campuses.insert(name.to_owned());
            }
        }
    }
    if let Some(name) = text("courseCampus")? {
        campuses.insert(name);
    }
    let selected = match row.get("selected") {
        None | Some(Value::Null) => None,
        Some(Value::Bool(value)) => Some(*value),
        Some(v) => match v
            .as_str()
            .map(str::to_owned)
            .or_else(|| v.as_i64().map(|n| n.to_string()))
            .as_deref()
        {
            Some("true" | "1") => Some(true),
            Some("false" | "0") => Some(false),
            _ => return Err(AppError::changed()),
        },
    };
    Ok(Some(CourseDetails {
        start: text("courseStartDate")?,
        end: text("courseEndDate")?,
        select_start: text("courseSelectStartDate")?,
        select_end: text("courseSelectEndDate")?,
        cancel_end: text("courseCancelEndDate")?,
        capacity: number("courseMaxCount")?,
        enrolled: number("courseCurrentCount")?,
        campuses: campuses.into_iter().collect(),
        summary: text("courseDesc")?,
        selected,
        has_sign_config: if row.get("courseSignConfig").is_some() {
            Some(text("courseSignConfig")?.is_some())
        } else {
            None
        },
    }))
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

pub fn parse_catalog(
    config: &serde_json::Value,
    pages: &[serde_json::Value],
) -> Result<Catalog, AppError> {
    use serde_json::Value;
    let string = |row: &Value, key: &str| {
        row.get(key).and_then(|v| {
            v.as_str()
                .map(str::to_owned)
                .or_else(|| v.as_i64().map(|n| n.to_string()))
        })
    };
    let rows = config["semester"]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let mut terms = Vec::new();
    for row in rows {
        terms.push(Semester {
            id: string(row, "id").ok_or_else(AppError::changed)?,
            name: string(row, "semesterName")
                .filter(|s| !s.trim().is_empty())
                .ok_or_else(AppError::changed)?,
            start: string(row, "semesterStartDate"),
            end: string(row, "semesterEndDate"),
        });
    }
    let mut courses = Vec::new();
    let mut ids = std::collections::BTreeSet::new();
    for page in pages {
        let rows = page["content"].as_array().ok_or_else(AppError::changed)?;
        for row in rows {
            let id = string(row, "id")
                .and_then(|v| v.parse::<i64>().ok())
                .ok_or_else(AppError::changed)?;
            if !ids.insert(id) {
                return Err(AppError::changed());
            }
            courses.push(Course {
                details: details(row)?,
                id,
                name: string(row, "courseName")
                    .filter(|s| !s.trim().is_empty())
                    .ok_or_else(AppError::changed)?,
                teacher: string(row, "courseTeacher"),
                position: string(row, "coursePosition"),
                category: row["courseNewKind1"]["kindName"]
                    .as_str()
                    .map(str::to_owned)
                    .or_else(|| string(row, "courseKind1")),
                subcategory: row["courseNewKind2"]["kindName"]
                    .as_str()
                    .map(str::to_owned)
                    .or_else(|| string(row, "courseKind2")),
            });
        }
    }
    Ok(Catalog { terms, courses })
}
