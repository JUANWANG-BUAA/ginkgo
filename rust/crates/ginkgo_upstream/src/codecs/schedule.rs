use crate::{AppError, ErrorCode};
use chrono::NaiveDate;
pub use ginkgo_domain::features::schedule::*;
use serde_json::Value;
use std::collections::HashMap;

pub fn parse_terms(value: Value) -> Result<Vec<Term>, AppError> {
    require_success(&value)?;
    let rows = value
        .get("datas")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut terms: Vec<Term> = rows
        .iter()
        .map(|row| {
            let id = required_string(row, "itemCode")?;
            let name = required_string(row, "itemName")?;
            let selected = row
                .get("selected")
                .and_then(Value::as_bool)
                .ok_or_else(AppError::changed)?;
            Ok(Term { id, name, selected })
        })
        .collect::<Result<_, AppError>>()?;
    let unique = terms
        .iter()
        .map(|term| &term.id)
        .collect::<std::collections::BTreeSet<_>>();
    if unique.len() != terms.len() {
        return Err(AppError::changed());
    }
    terms.sort_by(|left, right| right.id.cmp(&left.id));
    Ok(terms)
}

pub fn parse_weeks(value: Value) -> Result<Vec<Week>, AppError> {
    require_success(&value)?;
    let rows = value
        .get("datas")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut weeks: Vec<Week> = rows
        .iter()
        .map(|row| {
            let number = required_integer(row, "serialNumber")?;
            if number < 1 {
                return Err(AppError::changed());
            }
            let start_date = required_date(row, "startDate")?;
            let end_date = required_date(row, "endDate")?;
            if start_date > end_date {
                return Err(AppError::changed());
            }
            let current = row
                .get("curWeek")
                .and_then(Value::as_bool)
                .ok_or_else(AppError::changed)?;
            Ok(Week {
                number: number as i32,
                start_date,
                end_date,
                current,
            })
        })
        .collect::<Result<_, AppError>>()?;
    let unique = weeks
        .iter()
        .map(|week| week.number)
        .collect::<std::collections::BTreeSet<_>>();
    if unique.len() != weeks.len() {
        return Err(AppError::changed());
    }
    weeks.sort_by_key(|week| week.number);
    Ok(weeks)
}

pub fn parse_undergraduate_courses(value: Value) -> Result<Vec<CourseMeeting>, AppError> {
    require_success(&value)?;
    let rows = value
        .get("datas")
        .and_then(|datas| datas.get("arrangedList"))
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let meetings: Vec<CourseMeeting> = rows
        .iter()
        .enumerate()
        .map(|(index, row)| {
            let name = required_string(row, "courseName")?;
            let day = required_integer(row, "dayOfWeek")?;
            let start_section = required_integer(row, "beginSection")?;
            let end_section = required_integer(row, "endSection")?;
            if !(1..=7).contains(&day)
                || !(1..=14).contains(&start_section)
                || !(1..=14).contains(&end_section)
                || end_section < start_section
            {
                return Err(AppError::changed());
            }
            Ok(CourseMeeting {
                id: format!("u-{index}-{day}-{start_section}"),
                name,
                day: day as i32,
                start_section: start_section as i32,
                end_section: end_section as i32,
                start_time: optional_string(row, "beginTime"),
                end_time: optional_string(row, "endTime"),
                place: optional_string(row, "placeName"),
                teacher: optional_string(row, "weeksAndTeachers"),
                color: optional_string(row, "color"),
            })
        })
        .collect::<Result<_, AppError>>()?;
    Ok(normalize_meetings(meetings))
}

pub fn parse_exams(value: Value) -> Result<Vec<Exam>, AppError> {
    require_success(&value)?;
    let rows = value
        .get("datas")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut exams: Vec<Exam> = rows
        .iter()
        .map(|row| {
            let course_name = required_string(row, "courseName")?;
            let course_no = optional_string(row, "courseNo");
            let exam_date = optional_string(row, "examDate");
            let start_time = optional_string(row, "startTime");
            let task_id = optional_string(row, "taskId");
            let id = task_id.clone().unwrap_or_else(|| {
                format!(
                    "{}:{}:{}",
                    course_no.clone().unwrap_or_default(),
                    exam_date.clone().unwrap_or_default(),
                    course_name
                )
            });
            Ok(Exam {
                id,
                course_name,
                course_no,
                exam_time_description: optional_string(row, "examTimeDescription"),
                exam_date,
                start_time,
                end_time: optional_string(row, "endTime"),
                exam_place: optional_string(row, "examPlace"),
                exam_seat_no: optional_string(row, "examSeatNo"),
                week: optional_integer(row, "week").map(|week| week as i32),
                exam_status: optional_string(row, "examStatus"),
                exam_type: optional_string(row, "examType"),
                task_id,
            })
        })
        .collect::<Result<_, AppError>>()?;
    exams.sort_by(|left, right| {
        left.exam_date
            .clone()
            .unwrap_or_else(|| "9999-99-99".into())
            .cmp(
                &right
                    .exam_date
                    .clone()
                    .unwrap_or_else(|| "9999-99-99".into()),
            )
            .then(
                left.start_time
                    .clone()
                    .unwrap_or_else(|| "99:99".into())
                    .cmp(&right.start_time.clone().unwrap_or_else(|| "99:99".into())),
            )
            .then(left.course_name.cmp(&right.course_name))
    });
    Ok(exams)
}

mod graduate;

pub use graduate::{parse_graduate_courses, parse_graduate_terms, parse_graduate_weeks, parse_graduate_weeks_at};

type SlotMap = HashMap<(String, i64), (Option<i64>, Option<i64>)>;

fn slot_time(slots: &SlotMap, scheme: Option<&str>, section: i64, start: bool) -> Option<String> {
    let scheme = scheme?;
    let (start_at, end_at) = slots.get(&(scheme.to_string(), section))?;
    let value = if start { (*start_at)? } else { (*end_at)? };
    if !(0..=2359).contains(&value) || value % 100 >= 60 {
        return None;
    }
    Some(format!("{:02}:{:02}", value / 100, value % 100))
}

fn normalize_meetings(meetings: Vec<CourseMeeting>) -> Vec<CourseMeeting> {
    let mut result: Vec<CourseMeeting> = Vec::new();
    for meeting in meetings {
        let key = (
            meeting.name.trim().to_string(),
            meeting.day,
            meeting.start_section,
            meeting.end_section,
        );
        if let Some(existing) = result.iter_mut().find(|existing| {
            (
                existing.name.trim(),
                existing.day,
                existing.start_section,
                existing.end_section,
            ) == (key.0.as_str(), key.1, key.2, key.3)
        }) {
            existing.start_time = existing.start_time.clone().or(meeting.start_time);
            existing.end_time = existing.end_time.clone().or(meeting.end_time);
            existing.place = existing.place.clone().or(meeting.place);
            existing.teacher = existing.teacher.clone().or(meeting.teacher);
            existing.color = existing.color.clone().or(meeting.color);
        } else {
            result.push(meeting);
        }
    }
    result.sort_by(|left, right| {
        left.day
            .cmp(&right.day)
            .then(left.start_section.cmp(&right.start_section))
            .then(left.end_section.cmp(&right.end_section))
            .then(left.name.cmp(&right.name))
    });
    merge_adjacent(result)
}

fn merge_adjacent(meetings: Vec<CourseMeeting>) -> Vec<CourseMeeting> {
    let mut result: Vec<CourseMeeting> = Vec::new();
    for meeting in meetings {
        let merge = result.last().is_some_and(|previous| {
            previous.day == meeting.day
                && normalized_name(&previous.name) == normalized_name(&meeting.name)
                && compatible_place(previous.place.as_deref(), meeting.place.as_deref())
                && previous.end_section + 1 == meeting.start_section
        });
        if !merge {
            result.push(meeting);
            continue;
        }
        let previous = result.last_mut().expect("previous meeting");
        let merged = CourseMeeting {
            id: previous.id.clone(),
            name: previous.name.clone(),
            day: previous.day,
            start_section: previous.start_section,
            end_section: meeting.end_section,
            start_time: previous
                .start_time
                .clone()
                .or_else(|| meeting.start_time.clone()),
            end_time: meeting
                .end_time
                .clone()
                .or_else(|| previous.end_time.clone()),
            place: previous
                .place
                .clone()
                .filter(|place| !place.trim().is_empty())
                .or_else(|| meeting.place.clone()),
            teacher: merged_teacher(previous.teacher.as_deref(), meeting.teacher.as_deref()),
            color: previous.color.clone().or_else(|| meeting.color.clone()),
        };
        *result.last_mut().expect("previous meeting") = merged;
    }
    result
}

fn normalized_name(name: &str) -> String {
    name.split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

fn compatible_place(left: Option<&str>, right: Option<&str>) -> bool {
    match (
        left.filter(|value| !value.trim().is_empty()),
        right.filter(|value| !value.trim().is_empty()),
    ) {
        (Some(left), Some(right)) => normalized_name(left) == normalized_name(right),
        _ => true,
    }
}

fn merged_teacher(left: Option<&str>, right: Option<&str>) -> Option<String> {
    let left = left.filter(|value| !value.trim().is_empty());
    let right = right.filter(|value| !value.trim().is_empty());
    match (left, right) {
        (Some(left), Some(right)) if normalized_name(left) != normalized_name(right) => {
            Some(format!("{left} / {right}"))
        }
        (Some(left), _) => Some(left.to_owned()),
        (_, Some(right)) => Some(right.to_owned()),
        _ => None,
    }
}

fn require_success(value: &Value) -> Result<(), AppError> {
    let code = value
        .get("code")
        .and_then(|code| {
            code.as_str()
                .map(str::to_string)
                .or_else(|| code.as_i64().map(|number| number.to_string()))
        })
        .ok_or_else(AppError::changed)?;
    if code == "0" {
        Ok(())
    } else {
        Err(AppError::new(ErrorCode::ServiceUnavailable))
    }
}

fn required_string(row: &Value, key: &str) -> Result<String, AppError> {
    optional_string(row, key)
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(AppError::changed)
}

fn optional_string(row: &Value, key: &str) -> Option<String> {
    match row.get(key)? {
        Value::String(value) => Some(value.clone()),
        Value::Number(number) => Some(number.to_string()),
        _ => None,
    }
}

fn required_integer(row: &Value, key: &str) -> Result<i64, AppError> {
    optional_integer(row, key).ok_or_else(AppError::changed)
}

fn optional_integer(row: &Value, key: &str) -> Option<i64> {
    match row.get(key)? {
        Value::Number(number) => number.as_i64(),
        Value::String(value) => value.parse().ok(),
        _ => None,
    }
}

fn required_date(row: &Value, key: &str) -> Result<NaiveDate, AppError> {
    let raw = required_string(row, key)?;
    NaiveDate::parse_from_str(raw.get(..10).unwrap_or(&raw), "%Y-%m-%d")
        .map_err(|_| AppError::changed())
}

#[cfg(test)]
mod graduate_tests {
    use super::*;
    use serde_json::Value;
    use std::path::Path;

    fn body(name: &str) -> Value {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../../fixtures/schedule")
            .join(name);
        let fixture: Value =
            serde_json::from_str(&std::fs::read_to_string(path).expect("fixture")).expect("json");
        fixture["input"]["body"].clone()
    }

    #[test]
    fn graduate_terms_select_the_newest_term() {
        let terms = parse_graduate_terms(body("graduate-terms-v1.json")).expect("terms");
        assert_eq!(terms.len(), 2);
        assert_eq!(terms[0].id, "20261");
        assert!(terms[0].selected);
        assert!(!terms[1].selected);
    }

    #[test]
    fn graduate_weeks_use_the_first_class_date_and_bitmap_length() {
        let weeks = parse_graduate_weeks_at(
            body("graduate-schedule-v1.json"),
            "20261",
            NaiveDate::from_ymd_opt(2026, 10, 20).expect("date"),
        )
        .expect("weeks");
        assert_eq!(weeks.len(), 30);
        assert_eq!(weeks[6].number, 7);
        assert_eq!(
            weeks[6].start_date,
            NaiveDate::from_ymd_opt(2026, 10, 19).unwrap()
        );
        assert!(weeks[6].current);
        assert!(!weeks[5].current);
    }

    #[test]
    fn graduate_slot_scheme_can_live_only_on_entries() {
        let mut value = body("graduate-schedule-v1.json");
        // Match the real portal hierarchy without using any account data.
        for scheme in value["jcfaList"].as_array_mut().unwrap() {
            let id = scheme["JCFADM"].clone();
            scheme.as_object_mut().unwrap().remove("JCFADM");
            for entry in scheme["skjcList"].as_array_mut().unwrap() {
                entry["JCFADM"] = id.clone();
            }
        }
        let courses = parse_graduate_courses(value, "20261", 7).unwrap();
        assert_eq!(courses.len(), 2);
        assert!(courses
            .iter()
            .all(|c| c.start_time.is_some() && c.end_time.is_some()));
    }

    #[test]
    fn graduate_courses_filter_by_bitmap_and_fill_slot_times() {
        let courses =
            parse_graduate_courses(body("graduate-schedule-v1.json"), "20261", 7).expect("courses");
        assert_eq!(courses.len(), 2);
        assert_eq!(courses[0].name, "高级算法");
        assert_eq!(courses[0].day, 2);
        assert_eq!(courses[0].start_time.as_deref(), Some("08:00"));
        assert_eq!(courses[0].end_time.as_deref(), Some("11:40"));
        assert_eq!(courses[1].start_time.as_deref(), Some("10:00"));
        assert_eq!(courses[1].place.as_deref(), Some("主楼B202"));
    }

    #[test]
    fn graduate_empty_schedule_is_a_valid_empty_week_list() {
        let value = serde_json::json!({
            "code": "1",
            "jgList": [],
            "rwList": [],
            "jcfaList": []
        });
        assert!(parse_graduate_weeks_at(
            value,
            "20261",
            NaiveDate::from_ymd_opt(2026, 10, 20).unwrap()
        )
        .expect("empty")
        .is_empty());
    }
}
