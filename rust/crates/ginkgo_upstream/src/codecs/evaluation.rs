//! API.md §6J read-only SPOC teaching evaluation status decoder (`spoc.buaa.edu.cn/pjxt`).
//! Strictly read-only: never decodes question options or submits evaluation forms.
use crate::{AppError, ErrorCode};
use ginkgo_domain::features::evaluation::{EvaluationCourseItem, EvaluationCourseStatus};
use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EvaluationTaskMeta {
    pub task_id: String,
    pub task_name: Option<String>,
    pub term: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EvaluationQuestionnaire {
    pub id: String,
    pub name: Option<String>,
}

fn pjxt_result(value: &Value) -> Result<&Value, AppError> {
    if let Some(content) = value.get("content").and_then(Value::as_object) {
        if let Some(status) = content.get("status").and_then(Value::as_i64) {
            if status == 401 || status == 403 {
                return Err(AppError::module_auth_required());
            }
            if status >= 400 {
                return Err(AppError::unavailable());
            }
        }
    }
    let ok = match value.get("code") {
        Some(Value::Number(n)) => n.as_i64().is_some_and(|c| c == 0 || c == 200),
        Some(Value::String(s)) => matches!(
            s.trim().to_ascii_lowercase().as_str(),
            "0" | "200" | "success"
        ),
        _ => return Err(AppError::changed()),
    };
    if !ok {
        let num_code = value
            .get("code")
            .and_then(|c| c.as_i64().or_else(|| c.as_str()?.trim().parse().ok()));
        if matches!(num_code, Some(401 | 403)) {
            return Err(AppError::module_auth_required());
        }
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    value
        .get("result")
        .or_else(|| value.get("content"))
        .filter(|r| !r.is_null())
        .ok_or_else(AppError::changed)
}

fn scalar_string(obj: &serde_json::Map<String, Value>, key: &str) -> Option<String> {
    match obj.get(key)? {
        Value::String(s) => {
            let trimmed = s.trim();
            (!trimmed.is_empty()).then(|| trimmed.to_owned())
        }
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}

pub fn parse_tasks(value: &Value) -> Result<Option<EvaluationTaskMeta>, AppError> {
    let result = pjxt_result(value)?;
    let list = if let Some(arr) = result.as_array() {
        arr
    } else if let Some(arr) = result.get("list").and_then(Value::as_array) {
        arr
    } else {
        return Err(AppError::changed());
    };
    let Some(first) = list.first() else {
        return Ok(None);
    };
    let obj = first.as_object().ok_or_else(AppError::changed)?;
    let task_id = scalar_string(obj, "rwid").ok_or_else(AppError::changed)?;
    let term = scalar_string(obj, "rwxnxq").or_else(|| scalar_string(obj, "xnxq"));
    let task_name = scalar_string(obj, "rwmc");
    Ok(Some(EvaluationTaskMeta {
        task_id,
        task_name,
        term,
    }))
}

pub fn parse_questionnaires(value: &Value) -> Result<Vec<EvaluationQuestionnaire>, AppError> {
    let result = pjxt_result(value)?;
    let list = if let Some(arr) = result.as_array() {
        arr
    } else if let Some(arr) = result.get("list").and_then(Value::as_array) {
        arr
    } else {
        return Err(AppError::changed());
    };
    let mut seen = std::collections::HashSet::new();
    let mut out = Vec::with_capacity(list.len());
    for item in list {
        let obj = item.as_object().ok_or_else(AppError::changed)?;
        let id = scalar_string(obj, "wjid").ok_or_else(AppError::changed)?;
        if seen.insert(id.clone()) {
            out.push(EvaluationQuestionnaire {
                id,
                name: scalar_string(obj, "wjmc"),
            });
        }
    }
    Ok(out)
}

pub fn parse_required_reviews(
    value: &Value,
    questionnaire_id: &str,
    questionnaire_name: Option<&str>,
) -> Result<Vec<EvaluationCourseItem>, AppError> {
    let result = pjxt_result(value)?;
    let list = if let Some(arr) = result.as_array() {
        arr
    } else if let Some(arr) = result.get("list").and_then(Value::as_array) {
        arr
    } else {
        return Err(AppError::changed());
    };
    let mut items = Vec::with_capacity(list.len());

    for (idx, row) in list.iter().enumerate() {
        let obj = row.as_object().ok_or_else(AppError::changed)?;
        let course_name = scalar_string(obj, "kcmc").ok_or_else(AppError::changed)?;
        let teacher_name = scalar_string(obj, "bpmc")
            .or_else(|| scalar_string(obj, "bprm"))
            .or_else(|| scalar_string(obj, "jsxm"));
        let q_name = scalar_string(obj, "wjmc").or_else(|| questionnaire_name.map(str::to_owned));
        let category = scalar_string(obj, "kcdlmc");

        let status = parse_status_field(obj);

        let id = scalar_string(obj, "id").unwrap_or_else(|| {
            let wjid = scalar_string(obj, "wjid").unwrap_or_else(|| questionnaire_id.to_owned());
            let rwh = scalar_string(obj, "rwh").unwrap_or_default();
            let kcdm = scalar_string(obj, "kcdm").unwrap_or_else(|| course_name.clone());
            let bpdm = scalar_string(obj, "bpdm")
                .or_else(|| teacher_name.clone())
                .unwrap_or_else(|| idx.to_string());
            format!("{wjid}:{rwh}:{kcdm}:{bpdm}")
        });

        items.push(EvaluationCourseItem {
            id,
            course_name,
            teacher_name,
            questionnaire_name: q_name,
            category,
            status,
        });
    }
    Ok(items)
}

fn parse_status_field(obj: &serde_json::Map<String, Value>) -> EvaluationCourseStatus {
    // Primary field in `getRequiredReviewsData`: `ypjcs` (evaluated count >= 1 => Completed, 0 => Pending).
    // Also supports `ypjzt` / `sfyp` ("1"/1 => Completed, "0"/0 => Pending).
    for key in ["ypjcs", "ypjzt", "sfyp"] {
        let Some(val) = obj.get(key) else {
            continue;
        };
        match val {
            Value::Number(n) => {
                if let Some(i) = n.as_i64() {
                    return if i >= 1 {
                        EvaluationCourseStatus::Completed
                    } else if i == 0 {
                        EvaluationCourseStatus::Pending
                    } else {
                        EvaluationCourseStatus::Unknown
                    };
                }
            }
            Value::String(s) => match s.trim() {
                "0" => return EvaluationCourseStatus::Pending,
                s_num if s_num.parse::<i64>().is_ok_and(|n| n >= 1) => {
                    return EvaluationCourseStatus::Completed;
                }
                _ => return EvaluationCourseStatus::Unknown,
            },
            Value::Bool(b) => {
                return if *b {
                    EvaluationCourseStatus::Completed
                } else {
                    EvaluationCourseStatus::Pending
                };
            }
            _ => {}
        }
    }
    EvaluationCourseStatus::Unknown
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_tasks_questionnaires_and_course_status_variants() {
        let empty =
            parse_tasks(&json!({"code": "200", "result": {"list": []}})).expect("empty tasks list");
        assert!(empty.is_none());

        let task = parse_tasks(&json!({
            "code": "200",
            "result": {
                "list": [{
                    "rwid": "RW-2026-1",
                    "rwmc": "2026秋季学期课程评教",
                    "rwxnxq": "2026-20271"
                }]
            }
        }))
        .expect("task ok")
        .expect("present");
        assert_eq!(task.task_id, "RW-2026-1");
        assert_eq!(task.term.as_deref(), Some("2026-20271"));

        let qs = parse_questionnaires(&json!({
            "code": 200,
            "result": [
                {"wjid": "WJ-1", "wjmc": "理论课"},
                {"wjid": "WJ-1", "wjmc": "理论课"},
                {"wjid": "WJ-2", "wjmc": "实践课"}
            ]
        }))
        .expect("questionnaires");
        assert_eq!(qs.len(), 2);

        let reviews = parse_required_reviews(
            &json!({
                "code": "200",
                "result": [
                    {
                        "rwid": "RW-2026-1",
                        "wjid": "WJ-1",
                        "rwh": "R1",
                        "kcdm": "B101",
                        "kcmc": "高级算法设计",
                        "bpdm": "T01",
                        "bpmc": "李文",
                        "ypjcs": 1,
                        "kcdlmc": "理论课"
                    },
                    {
                        "rwid": "RW-2026-1",
                        "wjid": "WJ-1",
                        "rwh": "R2",
                        "kcdm": "B102",
                        "kcmc": "分布式系统",
                        "bpdm": "T02",
                        "bpmc": "张敏",
                        "ypjcs": 0
                    }
                ]
            }),
            "WJ-1",
            Some("理论课问卷"),
        )
        .expect("reviews");
        assert_eq!(reviews.len(), 2);
        assert_eq!(reviews[0].status, EvaluationCourseStatus::Completed);
        assert_eq!(reviews[0].teacher_name.as_deref(), Some("李文"));
        assert_eq!(reviews[1].status, EvaluationCourseStatus::Pending);
        assert_eq!(reviews[1].questionnaire_name.as_deref(), Some("理论课问卷"));
    }

    #[test]
    fn rejects_spring_error_wrapped_in_200_and_missing_task_id() {
        let disguised_500 = json!({
            "code": 200,
            "msg": null,
            "content": {"status": 500, "error": "Internal Server Error"}
        });
        assert_eq!(
            parse_tasks(&disguised_500).unwrap_err().code,
            ErrorCode::ServiceUnavailable
        );

        let optional_term = json!({
            "code": "200",
            "result": {"list": [{"rwid": "RW-1"}]}
        });
        assert_eq!(parse_tasks(&optional_term).unwrap().unwrap().term, None);

        let missing_id = json!({
            "code": "200",
            "result": {"list": [{"rwmc": "无ID任务"}]}
        });
        assert_eq!(
            parse_tasks(&missing_id).unwrap_err().code,
            ErrorCode::ChangedResponse
        );
    }
}
