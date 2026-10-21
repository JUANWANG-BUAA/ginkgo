//! Graduate execution report projection, API.md §7.4. Never serialize raw student records.
use crate::{AppError, ErrorCode};
use serde::{Deserialize, Serialize};
use serde_json::Value;
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReadRow {
    pub title: String,
    pub detail: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub completed: Option<bool>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReadSection {
    pub title: String,
    pub rows: Vec<ReadRow>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub progress: Option<CreditProgress>,
}
/// Requirement and officially recognized credits; pending never reduces the gap.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CreditProgress {
    pub required: Option<f64>,
    pub earned: Option<f64>,
    pub pending: Option<f64>,
}
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
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AcademicData {
    pub sections: Vec<ReadSection>,
    pub notice: Option<String>,
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
                completed: None,
                title: "总学分要求".into(),
                detail: number(&root["fa"]["ZDXF"]),
            },
            ReadRow {
                completed: None,
                title: "方案已认定学分".into(),
                detail: number(&root["yhpyfaxf"]),
            },
            ReadRow {
                completed: None,
                title: "全校累计已修学分".into(),
                detail: number(&root["yxxf"]),
            },
            ReadRow {
                completed: None,
                title: "待考核学分".into(),
                detail: number(&root["dkhxf"]),
            },
        ],
    }];
    for category in categories {
        let title = text(&category["kclbmc"]).ok_or_else(AppError::changed)?;
        let mut rows = vec![ReadRow {
            completed: None,
            title: "类别要求与进度".into(),
            detail: credits(category),
        }];
        if let Some(note) = text(&category["kclbhbzyq"]) {
            rows.push(ReadRow {
                completed: None,
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
                completed: None,
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
                    completed: None,
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
            completed: None,
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
                completed: None,
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
