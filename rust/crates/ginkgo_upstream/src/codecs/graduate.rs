//! Graduate execution report projection, API.md §7.4. Never serialize raw student records.
use crate::{AppError, ErrorCode};
pub use ginkgo_domain::features::graduate::*;
use serde_json::Value;
fn credit(value: &Value) -> Option<f64> {
    let number = value
        .as_f64()
        .or_else(|| value.as_str()?.trim().parse().ok())?;
    (number.is_finite() && number >= 0.0).then_some(number)
}
fn progress(required: &Value, earned: &Value, pending: &Value) -> CreditProgress {
    CreditProgress {
        required: credit(required),
        earned: credit(earned),
        pending: credit(pending),
    }
}
fn text(v: &Value) -> Option<String> {
    match v {
        Value::String(s) if !s.trim().is_empty() => Some(s.trim().to_owned()),
        Value::Number(n) => Some(n.to_string()),
        _ => None,
    }
}
fn number(v: &Value) -> String {
    text(v).unwrap_or_else(|| "未确认".into())
}
fn credits(row: &Value) -> String {
    format!(
        "要求 {} · 已获 {} · 待考核 {} 学分",
        number(&row["yqxf"]),
        number(&row["yhxf"]),
        number(&row["dkhxf"])
    )
}
fn courses(value: &Value) -> Result<Vec<ReadRow>, AppError> {
    value
        .as_array()
        .ok_or_else(AppError::changed)?
        .iter()
        .map(|course| {
            let title = text(&course["kcmc"]).ok_or_else(AppError::changed)?;
            let completed = course.get("sfwc").ok_or_else(AppError::changed)?;
            let status = match completed {
                Value::Bool(true) => "已完成",
                Value::Bool(false) => "未完成",
                Value::String(s) if s == "1" || s == "true" => "已完成",
                Value::String(s) if s == "0" || s == "false" => "未完成",
                Value::Number(n) if n.as_i64() == Some(1) => "已完成",
                Value::Number(n) if n.as_i64() == Some(0) => "未完成",
                _ => "待确认",
            };
            let mut detail = format!("{} 学分 · {status}", number(&course["xf"]));
            for key in ["cjxsz", "xnxqmc", "kksx"] {
                if let Some(v) = text(&course[key]) {
                    detail.push_str(&format!(" · {v}"));
                }
            }
            Ok(ReadRow {
                is_course: true,
                credit: credit(&course["xf"]),
                semester: text(&course["xnxqmc"]),
                title,
                detail,
                completed: match status {
                    "已完成" => Some(true),
                    "未完成" => Some(false),
                    _ => None,
                },
            })
        })
        .collect()
}
pub fn parse_execution(envelope: &Value) -> Result<Vec<ReadSection>, AppError> {
    let code = text(&envelope["code"]).ok_or_else(AppError::changed)?;
    if code != "1" {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    let root = envelope.get("datas").unwrap_or(envelope);
    let raw = match &root["zxbg"] {
        Value::String(s) => serde_json::from_str::<Value>(s).map_err(|_| AppError::changed())?,
        v => v.clone(),
    };
    let categories = raw.as_array().ok_or_else(AppError::changed)?;
    let mut sections = vec![ReadSection {
        title: "培养方案执行报告".into(),
        progress: Some(progress(
            &root["fa"]["ZDXF"],
            &root["yhpyfaxf"],
            &root["dkhxf"],
        )),
        rows: vec![
            ReadRow {
                is_course: false,
                completed: None,
                credit: None,
                semester: None,
                title: "总学分要求".into(),
                detail: number(&root["fa"]["ZDXF"]),
            },
            ReadRow {
                is_course: false,
                completed: None,
                credit: None,
                semester: None,
                title: "方案已认定学分".into(),
                detail: number(&root["yhpyfaxf"]),
            },
            ReadRow {
                is_course: false,
                completed: None,
                credit: None,
                semester: None,
                title: "全校累计已修学分".into(),
                detail: number(&root["yxxf"]),
            },
            ReadRow {
                is_course: false,
                completed: None,
                credit: None,
                semester: None,
                title: "待考核学分".into(),
                detail: number(&root["dkhxf"]),
            },
        ],
    }];
    for category in categories {
        let title = text(&category["kclbmc"]).ok_or_else(AppError::changed)?;
        let mut rows = vec![ReadRow {
            is_course: false,
            completed: None,
            credit: None,
            semester: None,
            title: "类别要求与进度".into(),
            detail: credits(category),
        }];
        if let Some(note) = text(&category["kclbhbzyq"]) {
            rows.push(ReadRow {
                is_course: false,
                completed: None,
                credit: None,
                semester: None,
                title: "合并组说明".into(),
                detail: note,
            });
        }
        rows.extend(courses(&category["kcList"])?);
        sections.push(ReadSection {
            title: title.clone(),
            progress: Some(progress(
                &category["yqxf"],
                &category["yhxf"],
                &category["dkhxf"],
            )),
            rows,
        });
        for group in category["dxzList"]
            .as_array()
            .ok_or_else(AppError::changed)?
        {
            let name = text(&group["dxzmc"]).ok_or_else(AppError::changed)?;
            let mut rows = vec![ReadRow {
                is_course: false,
                completed: None,
                credit: None,
                semester: None,
                title: "课组要求与进度".into(),
                detail: credits(group),
            }];
            rows.extend(courses(&group["kcList"])?);
            sections.push(ReadSection {
                title: format!("{title} · {name}"),
                progress: Some(progress(&group["yqxf"], &group["yhxf"], &group["dkhxf"])),
                rows,
            });
        }
    }
    Ok(sections)
}

pub fn parse_status(value: &Value) -> Result<ReadSection, AppError> {
    let row = value["datas"]["xsjcxxcx"]["rows"]
        .as_array()
        .and_then(|rows| rows.first())
        .ok_or_else(AppError::changed)?;
    let fields = [
        ("学院", "YXDM_DISPLAY"),
        ("专业", "ZYDM_DISPLAY"),
        ("年级", "NJDM_DISPLAY"),
        ("培养层次", "PYCCDM_DISPLAY"),
        ("学籍状态", "XJZTDM_DISPLAY"),
        ("班级", "BJMC"),
        ("校区", "XQDM_DISPLAY"),
        ("学习方式", "XXFSDM_DISPLAY"),
        ("入学日期", "RDRQ"),
        ("预计毕业", "SJBYSJ"),
    ];
    Ok(ReadSection {
        title: "学籍信息".into(),
        progress: None,
        rows: fields
            .into_iter()
            .filter_map(|(label, key)| {
                text(&row[key]).map(|detail| ReadRow {
                    is_course: false,
                    completed: None,
                    credit: None,
                    semester: None,
                    title: label.into(),
                    detail,
                })
            })
            .collect(),
    })
}
pub fn parse_plan(header: &Value, pool: &Value) -> Result<Vec<ReadSection>, AppError> {
    let row = header["datas"]["facx"]["rows"]
        .as_array()
        .and_then(|rows| rows.first())
        .ok_or_else(AppError::changed)?;
    let mut sections = vec![ReadSection {
        title: "培养方案".into(),
        progress: None,
        rows: vec![ReadRow {
            is_course: false,
            completed: None,
            credit: None,
            semester: None,
            title: text(&row["MC"]).unwrap_or_else(|| "方案名称未确认".into()),
            detail: format!(
                "最低总学分 {} · 学位课学分 {}",
                number(&row["ZDXF"]),
                number(&row["XWKZDXF"])
            ),
        }],
    }];
    let rows = pool["datas"]["pyfakcxxcx"]["rows"]
        .as_array()
        .ok_or_else(AppError::changed)?
        .iter()
        .map(|course| {
            Ok(ReadRow {
                is_course: true,
                completed: None,
                credit: credit(&course["XF"]),
                semester: text(&course["KKXQDM_DISPLAY"]),
                title: text(&course["KCMC"]).ok_or_else(AppError::changed)?,
                detail: format!(
                    "{} 学分 · {} · {}",
                    number(&course["XF"]),
                    number(&course["KCLBLXMC"]),
                    number(&course["KKXQDM_DISPLAY"])
                ),
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    sections.push(ReadSection {
        title: "计划课程池（不等于毕业学分要求）".into(),
        progress: None,
        rows,
    });
    Ok(sections)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn unknown_course_results_stay_courses_and_metadata_stays_separate() {
        let sections = parse_execution(&json!({
            "code": 1,
            "zxbg": [{
                "kclbmc": "合成类别",
                "kcList": [{"kcmc": "状态未知课程", "xf": 2, "sfwc": "unknown", "xnxqmc": "合成学期", "privateField": "discard"}],
                "dxzList": []
            }]
        }))
        .expect("valid report with unknown completion");
        assert!(!sections[0].rows[0].is_course);
        let row = &sections[1].rows[1];
        assert!(row.is_course);
        assert_eq!(row.completed, None);
        let encoded = serde_json::to_value(row).expect("course projection");
        assert_eq!(encoded["isCourse"], true);
        assert_eq!(encoded["credit"], 2.0);
        assert_eq!(encoded["semester"], "合成学期");
        assert!(encoded.get("privateField").is_none());
        assert!(encoded.get("completed").is_none());
    }

    #[test]
    fn plan_pool_does_not_infer_completion_or_requirements() {
        let sections = parse_plan(
            &json!({"datas":{"facx":{"rows":[{"MC":"合成方案"}]}}}),
            &json!({"datas":{"pyfakcxxcx":{"rows":[{"KCMC":"合成课程","XF":2,"KKXQDM_DISPLAY":"合成学期"}]}}}),
        )
        .expect("valid pool");
        assert!(!sections[0].rows[0].is_course);
        assert!(sections[1].rows[0].is_course);
        assert_eq!(sections[1].rows[0].completed, None);
        assert_eq!(sections[1].rows[0].credit, Some(2.0));
        assert_eq!(sections[1].rows[0].semester.as_deref(), Some("合成学期"));
        assert!(sections[1].progress.is_none());
    }

    #[test]
    fn optional_course_credit_does_not_infer_missing_or_negative_numbers() {
        let rows = courses(&json!([
            {"kcmc": "缺失", "sfwc": null},
            {"kcmc": "负值", "xf": -1, "sfwc": null},
            {"kcmc": "文字", "xf": "未确定", "sfwc": null},
            {"kcmc": "零值", "xf": "0", "sfwc": null}
        ]))
        .expect("valid course rows");
        for row in &rows[..3] {
            let encoded = serde_json::to_value(row).expect("projection");
            assert!(encoded.get("credit").is_none());
            assert!(encoded.get("semester").is_none());
        }
        assert_eq!(rows[3].credit, Some(0.0));
    }
}
