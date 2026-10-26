//! Bounded schema decoders. Missing collections are errors, not empty success.
use crate::AppError;
use serde_json::Value;
pub mod announcements;
pub mod assessments;
pub mod resources;
pub fn optional(v: &Value, k: &str) -> Result<Option<String>, AppError> {
    match v.get(k) {
        None | Some(Value::Null) => Ok(None),
        Some(Value::String(s)) => Ok((!s.trim().is_empty()).then(|| s.clone())),
        Some(Value::Number(n)) => Ok(Some(n.to_string())),
        _ => Err(AppError::changed()),
    }
}
pub fn required(v: &Value, k: &str) -> Result<String, AppError> {
    optional(v, k)?.ok_or_else(AppError::changed)
}
pub fn rows(v: &Value) -> Result<&Vec<Value>, AppError> {
    let rows = v.as_array().ok_or_else(AppError::changed)?;
    if rows.len() > 500 {
        return Err(AppError::changed());
    }
    Ok(rows)
}
/// Verified student kinds only; titles never determine dispatch.
pub fn columns(v: &Value) -> Result<Vec<ginkgo_domain::ports::LearningColumn>, AppError> {
    use ginkgo_domain::ports::{LearningColumn, LearningColumnKind};
    fn walk(
        v: &Value,
        parent: Option<&str>,
        depth: usize,
        budget: &mut usize,
        ids: &mut std::collections::BTreeSet<String>,
        found: &mut Vec<LearningColumn>,
    ) -> Result<(), AppError> {
        if depth > 8 {
            return Err(AppError::changed());
        }
        for node in rows(v)? {
            if *budget == 0 {
                return Err(AppError::changed());
            }
            *budget -= 1;
            let kind = required(node, "lmlxdm")?;
            let business_kind = match (parent, kind.as_str()) {
                (Some("0"), "01") => Some(LearningColumnKind::Announcement),
                (Some("3"), "32") => Some(LearningColumnKind::Assessment),
                _ => None,
            };
            if let Some(kind) = business_kind {
                let id = required(node, "id")?;
                if id.len() > 256 || !ids.insert(id.clone()) {
                    return Err(AppError::changed());
                }
                let fallback = match kind {
                    LearningColumnKind::Announcement => "课程公告",
                    LearningColumnKind::Assessment => "课程测验",
                };
                found.push(LearningColumn {
                    id,
                    name: optional(node, "lmmc2")?.unwrap_or_else(|| fallback.into()),
                    kind,
                });
            }
            match node.get("children") {
                None | Some(Value::Null) => {}
                Some(children) => walk(children, Some(&kind), depth + 1, budget, ids, found)?,
            }
        }
        Ok(())
    }
    let mut found = Vec::new();
    walk(
        v,
        None,
        0,
        &mut 500,
        &mut std::collections::BTreeSet::new(),
        &mut found,
    )?;
    Ok(found)
}
pub fn column(v: &Value, parent_kind: &str, child_kind: &str) -> Result<String, AppError> {
    use ginkgo_domain::ports::LearningColumnKind;
    let wanted = match (parent_kind, child_kind) {
        ("0", "01") => LearningColumnKind::Announcement,
        ("3", "32") => LearningColumnKind::Assessment,
        _ => return Err(AppError::changed()),
    };
    let found: Vec<_> = columns(v)?
        .into_iter()
        .filter(|c| c.kind == wanted)
        .collect();
    if found.len() != 1 {
        return Err(AppError::changed());
    }
    Ok(found[0].id.clone())
}

pub fn course_url(_id: &str) -> String {
    // Course deep-link/history-mode availability has not been verified.
    "https://spoc.buaa.edu.cn/spocnew/".into()
}
pub fn courses(v: &Value) -> Result<Vec<ginkgo_domain::ports::LearningCourse>, AppError> {
    rows(&v["list"])?
        .iter()
        .map(|r| {
            let id = required(r, "kcid")?;
            Ok(ginkgo_domain::ports::LearningCourse {
                id: id.clone(),
                name: required(r, "kcmc")?,
                teacher: None,
                term: optional(r, "xnxq")?,
                source_url: course_url(&id),
            })
        })
        .collect()
}

#[cfg(test)]
mod tests;
