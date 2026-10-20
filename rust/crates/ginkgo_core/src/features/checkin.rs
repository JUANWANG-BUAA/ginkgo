//! iclass check-in read-only domain rules (API.md §7.2).
//!
//! Only the documented read path lives here: app login fields, the day's
//! course list, sign-status normalization and the duplicate/conflict rule.
//! Signing itself is deliberately absent until writes are reviewed.
use crate::{AppError, ErrorCode};
use serde::Deserialize;
use serde_json::{json, Value};
use std::fmt;

/// Short-lived iclass app session. It never leaves Rust and is never logged.
#[derive(Clone, PartialEq, Eq)]
pub struct IClassSession {
    pub user_id: String,
    pub session_id: String,
}

impl fmt::Debug for IClassSession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("IClassSession { user_id: <redacted>, session_id: <redacted> }")
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CheckInStatus {
    NotSigned,
    Signed,
    /// Upstream returned a value outside the documented 0/1 pair.
    Unknown,
}

impl CheckInStatus {
    pub fn name(self) -> &'static str {
        match self {
            Self::NotSigned => "notSigned",
            Self::Signed => "signed",
            Self::Unknown => "unknown",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckInCourse {
    pub id: String,
    pub course_id: Option<String>,
    pub course_num: Option<String>,
    pub course_name: String,
    pub begins_at: String,
    pub ends_at: String,
    pub status: CheckInStatus,
    pub teacher_name: Option<String>,
    pub classroom_name: Option<String>,
    pub merged_record_count: usize,
    pub conflicting: bool,
}

/// iclass answers 200 on business outcomes, so STATUS decides success.
/// Documented success is "0"; 200/success are tolerated because the upstream
/// has already been observed returning them for sibling endpoints.
fn is_success(status: &str) -> bool {
    matches!(
        status.to_ascii_lowercase().as_str(),
        "0" | "200" | "success"
    )
}

fn status_text(value: Option<&Value>) -> Option<String> {
    match value? {
        Value::String(text) => {
            let text = text.trim();
            (!text.is_empty()).then(|| text.to_owned())
        }
        Value::Number(number) => Some(number.to_string()),
        _ => None,
    }
}

fn text(row: &Value, key: &str) -> Option<String> {
    status_text(row.get(key))
}

fn rejected_detail(stage: &str, status: &str) -> String {
    let safe: String = status
        .chars()
        .filter(|ch| ch.is_ascii_alphanumeric() || *ch == '_' || *ch == '-')
        .take(16)
        .collect();
    if safe.is_empty() {
        format!("iclass_{stage}")
    } else {
        format!("iclass_{stage}_status_{safe}")
    }
}

pub fn parse_app_login(value: &Value) -> Result<IClassSession, AppError> {
    let status = status_text(value.get("STATUS")).ok_or_else(AppError::changed)?;
    if !is_success(&status) {
        return Err(AppError::with_detail(
            ErrorCode::BusinessRejected,
            rejected_detail("app_login", &status),
        ));
    }
    let result = value
        .get("result")
        .and_then(Value::as_object)
        .ok_or_else(AppError::changed)?;
    let user_id = result
        .get("id")
        .and_then(|value| status_text(Some(value)))
        .ok_or_else(AppError::changed)?;
    let session_id = result
        .get("sessionId")
        .and_then(|value| status_text(Some(value)))
        .ok_or_else(AppError::changed)?;
    Ok(IClassSession {
        user_id,
        session_id,
    })
}

/// Parse the day's course list. STATUS == "2" is upstream's documented
/// "no classes today"; every other non-success status is a business rejection,
/// not an empty list.
pub fn parse_course_schedule(value: &Value) -> Result<Vec<CheckInCourse>, AppError> {
    let status = status_text(value.get("STATUS")).ok_or_else(AppError::changed)?;
    if status == "2" {
        return Ok(Vec::new());
    }
    if !is_success(&status) {
        return Err(AppError::with_detail(
            ErrorCode::BusinessRejected,
            rejected_detail("course_schedule", &status),
        ));
    }
    let rows = value
        .get("result")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let candidates = rows
        .iter()
        .map(parse_candidate)
        .collect::<Result<Vec<_>, AppError>>()?;
    Ok(merge_candidates(candidates))
}

#[derive(Debug, Clone)]
struct Candidate {
    id: String,
    course_id: Option<String>,
    course_num: Option<String>,
    course_name: String,
    begins_at: String,
    ends_at: String,
    status: CheckInStatus,
    teacher_name: Option<String>,
    classroom_name: Option<String>,
}

fn parse_candidate(record: &Value) -> Result<Candidate, AppError> {
    let id = text(record, "id").ok_or_else(AppError::changed)?;
    let course_name = text(record, "courseName").ok_or_else(AppError::changed)?;
    let begins_at = text(record, "classBeginTime").ok_or_else(AppError::changed)?;
    let ends_at = text(record, "classEndTime").ok_or_else(AppError::changed)?;
    let raw_status = record
        .get("signStatus")
        .and_then(|value| status_text(Some(value)))
        .ok_or_else(AppError::changed)?;
    let status = match raw_status.parse::<i64>() {
        Ok(0) => CheckInStatus::NotSigned,
        Ok(1) => CheckInStatus::Signed,
        _ => CheckInStatus::Unknown,
    };
    Ok(Candidate {
        id,
        course_id: text(record, "courseId"),
        course_num: text(record, "courseNum"),
        course_name,
        begins_at,
        ends_at,
        status,
        teacher_name: text(record, "teacherName"),
        classroom_name: text(record, "classroomName"),
    })
}

/// Apple rule: records that share an id OR the same visible session are the
/// same course. A group whose session key or sign status disagrees becomes
/// "待确认" so no caller can mistake it for a single signable row.
fn merge_candidates(candidates: Vec<Candidate>) -> Vec<CheckInCourse> {
    let count = candidates.len();
    let mut parents: Vec<usize> = (0..count).collect();
    let mut first_by_id: Vec<(String, usize)> = Vec::new();
    let mut first_by_session: Vec<(String, usize)> = Vec::new();
    for (index, candidate) in candidates.iter().enumerate() {
        if let Some((_, first)) = first_by_id.iter().find(|(id, _)| *id == candidate.id) {
            union(&mut parents, index, *first);
        } else {
            first_by_id.push((candidate.id.clone(), index));
        }
        let key = session_key(candidate);
        if let Some((_, first)) = first_by_session.iter().find(|(other, _)| *other == key) {
            union(&mut parents, index, *first);
        } else {
            first_by_session.push((key, index));
        }
    }

    let roots: Vec<usize> = (0..count).map(|index| find(&mut parents, index)).collect();
    let mut groups: Vec<(usize, Vec<usize>)> = Vec::new();
    for (index, root) in roots.iter().enumerate() {
        match groups.iter_mut().find(|(group_root, _)| group_root == root) {
            Some((_, group)) => group.push(index),
            None => groups.push((*root, vec![index])),
        }
    }
    let groups: Vec<Vec<usize>> = groups.into_iter().map(|(_, group)| group).collect();

    let mut items: Vec<CheckInCourse> = groups
        .into_iter()
        .map(|indices| {
            let first = &candidates[indices[0]];
            let first_key = session_key(first);
            let conflicting = indices
                .iter()
                .any(|index| session_key(&candidates[*index]) != first_key)
                || indices
                    .iter()
                    .any(|index| candidates[*index].status != first.status);
            let mut ids: Vec<String> = indices
                .iter()
                .map(|index| candidates[*index].id.clone())
                .collect();
            ids.sort();
            ids.dedup();
            CheckInCourse {
                id: ids.first().cloned().unwrap_or_else(|| first.id.clone()),
                course_id: first.course_id.clone(),
                course_num: first.course_num.clone(),
                course_name: first.course_name.clone(),
                begins_at: first.begins_at.clone(),
                ends_at: first.ends_at.clone(),
                status: if conflicting {
                    CheckInStatus::Unknown
                } else {
                    first.status
                },
                teacher_name: first.teacher_name.clone(),
                classroom_name: first.classroom_name.clone(),
                merged_record_count: indices.len(),
                conflicting,
            }
        })
        .collect();
    items.sort_by(|left, right| {
        left.begins_at
            .cmp(&right.begins_at)
            .then(left.course_name.cmp(&right.course_name))
            .then(left.id.cmp(&right.id))
    });
    items
}

fn find(parents: &mut [usize], mut index: usize) -> usize {
    while parents[index] != index {
        parents[index] = parents[parents[index]];
        index = parents[index];
    }
    index
}

fn union(parents: &mut [usize], left: usize, right: usize) {
    let left_root = find(parents, left);
    let right_root = find(parents, right);
    if left_root != right_root {
        parents[right_root] = left_root;
    }
}

fn session_key(candidate: &Candidate) -> String {
    [
        normalized(&candidate.course_name),
        normalized(&candidate.begins_at),
        normalized(&candidate.ends_at),
    ]
    .join("|")
}

fn normalized(value: &str) -> String {
    value
        .replace('：', ":")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_lowercase()
}

/// The only field borrowed from the SSO landing URL. It is used once for the
/// app-login query and never stored, logged or sent to Dart.
pub fn login_name_from_url(url: &str) -> Option<String> {
    let url = url::Url::parse(url).ok()?;
    url.query_pairs()
        .find(|(key, _)| key.eq_ignore_ascii_case("loginName"))
        .map(|(_, value)| value.trim().to_owned())
        .filter(|value| !value.is_empty())
}

/// Compact shape shared with the fixture contracts.
pub fn summary(courses: &[CheckInCourse]) -> Value {
    json!({
        "courses": courses.iter().map(|course| json!({
            "id": course.id,
            "courseName": course.course_name,
            "beginsAt": course.begins_at,
            "endsAt": course.ends_at,
            "status": course.status.name(),
            "teacherName": course.teacher_name,
            "classroomName": course.classroom_name,
            "mergedRecordCount": course.merged_record_count,
            "conflicting": course.conflicting,
        })).collect::<Vec<_>>(),
    })
}

#[derive(Deserialize)]
pub struct DayInput {
    pub body: Value,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn app_login_accepts_string_and_numeric_status_and_redacts_debug() {
        let session = parse_app_login(&json!({
            "STATUS": "0",
            "result": {"id": 1001, "sessionId": "fixture-session"}
        }))
        .expect("login");
        assert_eq!(session.user_id, "1001");
        assert_eq!(session.session_id, "fixture-session");
        assert!(!format!("{session:?}").contains("fixture-session"));
    }

    #[test]
    fn rejected_app_login_is_not_a_structure_change() {
        let error = parse_app_login(&json!({"STATUS": 1, "ERRMSG": "denied"})).expect_err("denied");
        assert_eq!(error.code, ErrorCode::BusinessRejected);
        assert_eq!(error.detail.as_deref(), Some("iclass_app_login_status_1"));
    }

    #[test]
    fn status_two_is_an_empty_day_and_other_rejections_stay_errors() {
        assert!(parse_course_schedule(&json!({"STATUS": "2"}))
            .expect("empty")
            .is_empty());
        assert_eq!(
            parse_course_schedule(&json!({"STATUS": 3}))
                .expect_err("rejected")
                .code,
            ErrorCode::BusinessRejected
        );
        assert_eq!(
            parse_course_schedule(&json!({"result": []}))
                .expect_err("missing status")
                .code,
            ErrorCode::ChangedResponse
        );
    }

    #[test]
    fn duplicate_records_merge_and_disagreeing_status_becomes_unknown() {
        let courses = parse_course_schedule(&json!({
            "STATUS": 0,
            "result": [
                {"id": "1", "courseName": "高等数学", "classBeginTime": "08:00", "classEndTime": "09:35", "signStatus": 0},
                {"id": "1", "courseName": "高等数学", "classBeginTime": "08:00", "classEndTime": "09:35", "signStatus": 0},
                {"id": "2", "courseName": "大学物理", "classBeginTime": "10:00", "classEndTime": "11:35", "signStatus": 1},
                {"id": "3", "courseName": "大学物理", "classBeginTime": "10:00", "classEndTime": "11:35", "signStatus": 0}
            ]
        }))
        .expect("courses");
        assert_eq!(courses.len(), 2);
        assert_eq!(courses[0].merged_record_count, 2);
        assert_eq!(courses[0].status, CheckInStatus::NotSigned);
        assert_eq!(courses[1].id, "2");
        assert_eq!(courses[1].status, CheckInStatus::Unknown);
        assert!(courses[1].conflicting);
    }

    #[test]
    fn unknown_sign_status_is_kept_as_unknown() {
        let courses = parse_course_schedule(&json!({
            "STATUS": "0",
            "result": [{"id": "9", "courseName": "英语", "classBeginTime": "08:00", "classEndTime": "09:35", "signStatus": "9"}]
        }))
        .expect("courses");
        assert_eq!(courses[0].status, CheckInStatus::Unknown);
    }

    #[test]
    fn login_name_is_read_from_the_query_only() {
        let url = "https://iclass.buaa.edu.cn:8346/?loginName=abc%2Bdef%2Fghi%3D#/MyCenter";
        assert_eq!(login_name_from_url(url).as_deref(), Some("abc+def/ghi="));
        assert!(login_name_from_url("https://iclass.buaa.edu.cn:8346/#/MyCenter").is_none());
    }
}
