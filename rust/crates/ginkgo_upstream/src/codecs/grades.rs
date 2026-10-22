//! buaascore grade response and term-code rules (API.md §4).
use crate::{AppError, ErrorCode};
pub use ginkgo_domain::features::grades::*;
use serde_json::Value;

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
