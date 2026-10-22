use crate::AppError;
pub use ginkgo_domain::features::bykc::*;

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
fn optional_integer(row: &serde_json::Value, key: &str) -> Result<Option<i64>, AppError> {
    match row.get(key) {
        None | Some(serde_json::Value::Null) => Ok(None),
        Some(value) => value
            .as_i64()
            .or_else(|| value.as_str()?.parse().ok())
            .map(Some)
            .ok_or_else(AppError::changed),
    }
}

/// BykcClient.chosenCourses / EDUCATION-DATA-MAP §2.3. Reject a partial or
/// changed response so it cannot replace the last complete account snapshot.
pub fn parse_chosen(data: &serde_json::Value) -> Result<Vec<ChosenCourse>, AppError> {
    let rows = data["courseList"]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let mut ids = std::collections::BTreeSet::new();
    rows.iter()
        .map(|row| {
            let id = optional_integer(row, "id")?.ok_or_else(AppError::changed)?;
            if !ids.insert(id) {
                return Err(AppError::changed());
            }
            let mut catalog = parse_catalog(
                &serde_json::json!({"semester": []}),
                &[serde_json::json!({"content": [row["courseInfo"]]})],
            )?;
            let course = catalog.courses.pop().ok_or_else(AppError::changed)?;
            let selected_at = match row.get("selectDate") {
                None | Some(serde_json::Value::Null) => None,
                Some(serde_json::Value::String(text)) => {
                    Some(text.trim().to_owned()).filter(|v| !v.is_empty())
                }
                _ => return Err(AppError::changed()),
            };
            Ok(ChosenCourse {
                id,
                course,
                selected_at,
                checkin: optional_integer(row, "checkin")?,
                passed: optional_integer(row, "pass")?,
                score: optional_integer(row, "score")?,
            })
        })
        .collect()
}

/// BykcClient.statistics / EDUCATION-DATA-MAP §2.3. Counts remain exact,
/// including over-completion and zero requirements; presentation caps the bar.
pub fn parse_statistics(data: &serde_json::Value) -> Result<LearningStatistics, AppError> {
    let statistical = data["statistical"]
        .as_object()
        .ok_or_else(AppError::changed)?;
    let count = |row: &serde_json::Value, key: &str| -> Result<i64, AppError> {
        optional_integer(row, key)?
            .filter(|n| *n >= 0)
            .ok_or_else(AppError::changed)
    };
    let mut entries = Vec::new();
    for (category, subcategories) in statistical {
        let category = category
            .rsplit('|')
            .next()
            .filter(|v| !v.trim().is_empty())
            .ok_or_else(AppError::changed)?;
        for (subcategory, row) in subcategories.as_object().ok_or_else(AppError::changed)? {
            let subcategory = subcategory
                .rsplit('|')
                .next()
                .filter(|v| !v.trim().is_empty())
                .ok_or_else(AppError::changed)?;
            entries.push(StatisticsEntry {
                category: category.to_owned(),
                subcategory: subcategory.to_owned(),
                required: count(row, "assessmentCount")?,
                completed: count(row, "completeAssessmentCount")?,
            });
        }
    }
    entries.sort_by(|a, b| {
        a.category
            .cmp(&b.category)
            .then_with(|| a.subcategory.cmp(&b.subcategory))
    });
    let valid_course_count = optional_integer(data, "validCount")?;
    if valid_course_count.is_some_and(|n| n < 0) {
        return Err(AppError::changed());
    }
    Ok(LearningStatistics {
        valid_course_count,
        entries,
    })
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
