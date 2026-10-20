//! buaascore grade response and term-code rules (API.md §4).
use crate::{AppError, ErrorCode};
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GradeCourse {
    pub id: String,
    pub name: String,
    pub code: Option<String>,
    pub credit: Option<f64>,
    pub score: String,
    pub score_value: Option<f64>,
    pub score_type: Option<String>,
    pub course_type: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GradeSummary {
    pub course_count: i32,
    pub credit_total: f64,
    pub weighted_average: Option<f64>,
    pub grade_point_average: Option<f64>,
}

pub fn term_parts(code: &str) -> Result<(String, String), AppError> {
    let code = code.trim();
    let parts: Vec<&str> = code.split('-').collect();
    if parts.len() == 3 && parts[0].len() == 4 && parts[1].len() == 4 {
        let start: i32 = parts[0].parse().map_err(|_| AppError::invalid())?;
        let end: i32 = parts[1].parse().map_err(|_| AppError::invalid())?;
        if end != start + 1 || !matches!(parts[2], "1" | "2" | "3") {
            return Err(AppError::invalid());
        }
        return Ok((format!("{start}-{end}"), parts[2].to_string()));
    }
    if code.len() == 5 && matches!(code.as_bytes()[4], b'1' | b'2' | b'3') {
        let start: i32 = code[..4].parse().map_err(|_| AppError::invalid())?;
        return Ok((format!("{start}-{}", start + 1), code[4..].to_string()));
    }
    Err(AppError::invalid())
}

pub fn parse_courses(value: Value) -> Result<Vec<GradeCourse>, AppError> {
    let status = value
        .get("e")
        .and_then(Value::as_i64)
        .ok_or_else(AppError::changed)?;
    if status != 0 {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    let rows = value
        .get("d")
        .and_then(Value::as_object)
        .ok_or_else(AppError::changed)?;
    let mut courses = rows
        .iter()
        .map(|(id, row)| {
            if !row.is_object() {
                return Err(AppError::changed());
            }
            let name = text(row.get("kcmc"))
                .filter(|name| !name.trim().is_empty())
                .ok_or_else(AppError::changed)?;
            if row.get("kccj").is_none() || row.get("xf").is_none() {
                return Err(AppError::changed());
            }
            let score_text = text(row.get("kccj")).unwrap_or_else(|| "未发布".into());
            let score_value = score_text.parse::<f64>().ok();
            let credit = match row.get("xf") {
                None | Some(Value::Null) => None,
                Some(value) => {
                    let raw = text(Some(value)).ok_or_else(AppError::changed)?;
                    if raw.is_empty() {
                        None
                    } else {
                        let credit: f64 = raw.parse().map_err(|_| AppError::changed())?;
                        if !credit.is_finite() || credit < 0.0 {
                            return Err(AppError::changed());
                        }
                        Some(credit)
                    }
                }
            };
            Ok(GradeCourse {
                id: id.clone(),
                name,
                code: text(row.get("kch")),
                credit,
                score: score_text,
                score_value,
                score_type: text(row.get("fslx")),
                course_type: text(row.get("kclx")),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    courses.sort_by(|left, right| left.name.cmp(&right.name));
    Ok(courses)
}

pub fn summarize(courses: &[GradeCourse]) -> GradeSummary {
    let credit_total = courses.iter().filter_map(|course| course.credit).sum();
    let mut weighted = 0.0;
    let mut weighted_credit = 0.0;
    let mut points = 0.0;
    let mut point_credit = 0.0;
    for course in courses {
        let (Some(score), Some(credit)) = (course.score_value, course.credit) else {
            continue;
        };
        if !score.is_finite() || !(0.0..=100.0).contains(&score) || credit <= 0.0 {
            continue;
        }
        if course
            .score_type
            .as_deref()
            .is_some_and(|kind| !kind.is_empty() && kind != "百分制")
        {
            continue;
        }
        weighted += score * credit;
        weighted_credit += credit;
        let point = if score < 60.0 {
            0.0
        } else {
            4.0 - 3.0 * (100.0 - score).powi(2) / 1600.0
        };
        points += point * credit;
        point_credit += credit;
    }
    GradeSummary {
        course_count: courses.len() as i32,
        credit_total,
        weighted_average: (weighted_credit > 0.0).then(|| weighted / weighted_credit),
        grade_point_average: (point_credit > 0.0).then(|| points / point_credit),
    }
}

fn text(value: Option<&Value>) -> Option<String> {
    match value? {
        Value::String(text) => Some(text.clone()),
        Value::Number(number) => Some(number.to_string()),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn term_codes_accept_undergraduate_and_graduate_forms() {
        assert_eq!(
            term_parts("2025-2026-1").expect("undergraduate"),
            ("2025-2026".into(), "1".into())
        );
        assert_eq!(
            term_parts("20252").expect("graduate"),
            ("2025-2026".into(), "2".into())
        );
        assert_eq!(
            term_parts("2025-2027-1").expect_err("gap").code,
            ErrorCode::InvalidRequest
        );
        assert_eq!(
            term_parts("2025-2026-4").expect_err("semester").code,
            ErrorCode::InvalidRequest
        );
    }

    #[test]
    fn parser_tolerates_numeric_and_string_fields() {
        let courses = parse_courses(json!({
            "e": 0,
            "d": {
                "a": {"kcmc": "算法设计与分析", "kch": "CS101", "xf": "4.0", "kccj": 92, "fslx": "百分制"},
                "b": {"kcmc": "操作系统", "xf": 3, "kccj": "88"}
            }
        }))
        .expect("courses");
        assert_eq!(courses.len(), 2);
        let algorithm = courses
            .iter()
            .find(|course| course.name == "算法设计与分析")
            .expect("algorithm course");
        assert_eq!(algorithm.score, "92");
        assert_eq!(algorithm.credit, Some(4.0));
        let summary = summarize(&courses);
        assert!((summary.credit_total - 7.0).abs() < 0.001);
        assert!(summary.weighted_average.is_some());
    }
}
