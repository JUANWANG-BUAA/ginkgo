use crate::{AppError, ErrorCode};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

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
    result
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
