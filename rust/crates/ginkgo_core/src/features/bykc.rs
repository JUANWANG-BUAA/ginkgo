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
