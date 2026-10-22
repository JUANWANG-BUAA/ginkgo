use crate::AppError;
use serde::{Deserialize, Serialize};

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
