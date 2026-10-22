//! Today's teaching schedule (API.md §2.5).
use crate::AppError;
pub use ginkgo_domain::features::today::*;
use serde_json::Value;

pub fn parse_courses(value: Value) -> Result<Vec<TodayCourse>, AppError> {
    let code = value
        .get("code")
        .and_then(|code| {
            code.as_str()
                .map(str::to_string)
                .or_else(|| code.as_i64().map(|number| number.to_string()))
        })
        .ok_or_else(AppError::changed)?;
    if code != "0" {
        return Err(AppError::unavailable());
    }
    let rows = value
        .get("datas")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut courses = rows
        .iter()
        .map(|row| {
            let name = optional_string(row, "bizName")
                .filter(|name| !name.trim().is_empty())
                .ok_or_else(AppError::changed)?;
            Ok(TodayCourse {
                name,
                place: optional_string(row, "place"),
                time: optional_string(row, "time"),
                short_name: optional_string(row, "shortName"),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    courses.sort_by(|left, right| {
        left.time
            .clone()
            .unwrap_or_default()
            .cmp(&right.time.clone().unwrap_or_default())
            .then(left.name.cmp(&right.name))
    });
    Ok(courses)
}

fn optional_string(row: &Value, key: &str) -> Option<String> {
    match row.get(key)? {
        Value::String(value) => Some(value.clone()),
        Value::Number(number) => Some(number.to_string()),
        _ => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_and_sorts_today_courses() {
        let courses = parse_courses(json!({
            "code": "0",
            "datas": [
                {"bizName": "操作系统", "place": "主楼B202", "time": "10:00-11:35", "shortName": "OS"},
                {"bizName": "算法设计与分析", "place": "新主楼A101", "time": "08:00-09:35", "shortName": "算法"}
            ]
        }))
        .expect("today");
        assert_eq!(courses[0].name, "算法设计与分析");
        assert_eq!(courses.len(), 2);
    }
}
