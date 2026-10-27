//! 研究生教务（GSMIS）课表解析。
//!
//! GSMIS 与本科教务的响应形状不同：学期码为 5 位、周次需从教学班首次上课日
//! 反推，课程行以周次位图 `ZCBH` 过滤。共用辅助留在父模块。

use super::{
    normalize_meetings, optional_integer, optional_string, required_string, slot_time, SlotMap,
};
use crate::{AppError, ErrorCode};
use chrono::{Datelike, Duration, NaiveDate, Weekday};
use ginkgo_domain::features::schedule::{CourseMeeting, Term, Week};
use serde_json::Value;
use std::collections::HashMap;

/// GSMIS terms (`20261` form). GSMIS does not return a selected flag; the
/// newest term is selected, matching the Apple client.
pub fn parse_graduate_terms(value: Value) -> Result<Vec<Term>, AppError> {
    let code = optional_string(&value, "code").ok_or_else(AppError::changed)?;
    if code != "0" {
        return Err(AppError::new(ErrorCode::ServiceUnavailable));
    }
    let rows = value
        .get("datas")
        .and_then(|datas| datas.get("kfdxnxqcx"))
        .and_then(|table| table.get("rows"))
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut terms = rows
        .iter()
        .map(|row| {
            let id = required_string(row, "XNXQDM")?;
            if !valid_graduate_term(&id) {
                return Err(AppError::changed());
            }
            Ok(Term {
                id,
                name: required_string(row, "XNXQDM_DISPLAY")?,
                selected: false,
            })
        })
        .collect::<Result<Vec<_>, AppError>>()?;
    terms.sort_by(|left, right| right.id.cmp(&left.id));
    let unique = terms
        .iter()
        .map(|term| &term.id)
        .collect::<std::collections::BTreeSet<_>>();
    if unique.len() != terms.len() {
        return Err(AppError::changed());
    }
    for (index, term) in terms.iter_mut().enumerate() {
        term.selected = index == 0;
    }
    Ok(terms)
}

/// GSMIS weeks are not returned directly: the term start is inferred from each
/// teaching class's first class date minus its earliest weekday/week offset.
pub fn parse_graduate_weeks(value: Value, term_id: &str) -> Result<Vec<Week>, AppError> {
    let now: chrono::DateTime<chrono::Utc> = std::time::SystemTime::now().into();
    let today = now.with_timezone(&chrono_tz::Asia::Shanghai).date_naive();
    parse_graduate_weeks_at(value, term_id, today)
}

pub fn parse_graduate_weeks_at(
    value: Value,
    term_id: &str,
    today: NaiveDate,
) -> Result<Vec<Week>, AppError> {
    let code = optional_string(&value, "code").ok_or_else(AppError::changed)?;
    if code != "1" {
        return Err(AppError::changed());
    }
    let rows = value
        .get("jgList")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let tasks = value
        .get("rwList")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    if rows.is_empty() && tasks.is_empty() {
        return Ok(vec![]);
    }
    let term_tasks = tasks
        .iter()
        .filter(|task| optional_string(task, "XNXQDM").as_deref() == Some(term_id))
        .collect::<Vec<_>>();
    if term_tasks.is_empty() {
        return Err(AppError::changed());
    }

    let mut starts = Vec::new();
    for task in term_tasks {
        let Some(class_id) = optional_string(task, "BJDM").filter(|id| !id.is_empty()) else {
            continue;
        };
        let Some(first_date) = optional_string(task, "SCSKRQ").and_then(|raw| {
            NaiveDate::parse_from_str(raw.get(..10).unwrap_or(&raw), "%Y-%m-%d").ok()
        }) else {
            continue;
        };
        let class_rows = rows
            .iter()
            .filter(|row| optional_string(row, "BJDM").as_deref() == Some(class_id.as_str()))
            .collect::<Vec<_>>();
        if class_rows.is_empty() {
            continue;
        }
        let offset = class_rows
            .iter()
            .filter_map(|row| {
                let day = optional_integer(row, "XQ")?;
                if !(1..=7).contains(&day) {
                    return None;
                }
                let bitmap = optional_string(row, "ZCBH")?;
                if bitmap.is_empty() || !bitmap.bytes().all(|byte| matches!(byte, b'0' | b'1')) {
                    return None;
                }
                let first = bitmap.find('1')? as i64;
                Some(first * 7 + day - 1)
            })
            .min();
        let Some(offset) = offset else {
            continue;
        };
        starts.push(first_date - Duration::days(offset));
    }
    let Some(start) = starts.first().copied() else {
        return Err(AppError::changed());
    };
    if starts.iter().any(|candidate| *candidate != start) || start.weekday() != Weekday::Mon {
        return Err(AppError::changed());
    }

    let count = rows
        .iter()
        .filter_map(|row| optional_string(row, "ZCBH"))
        .filter(|bitmap| {
            !bitmap.is_empty() && bitmap.bytes().all(|byte| matches!(byte, b'0' | b'1'))
        })
        .map(|bitmap| bitmap.len())
        .max()
        .ok_or_else(AppError::changed)?;
    if count == 0 {
        return Err(AppError::changed());
    }
    let current_start = today - Duration::days(today.weekday().num_days_from_monday() as i64);
    Ok((1..=count as i32)
        .map(|number| {
            let start_date = start + Duration::days((number - 1) as i64 * 7);
            let end_date = start_date + Duration::days(6);
            Week {
                number,
                start_date,
                end_date,
                current: start_date == current_start,
            }
        })
        .collect())
}

/// Parse one week from the all-term GSMIS response. Courses are filtered by the
/// `ZCBH` week bitmap and adjacent sections are merged.
pub fn parse_graduate_courses(
    value: Value,
    term_id: &str,
    week: i32,
) -> Result<Vec<CourseMeeting>, AppError> {
    if week < 1 {
        return Err(AppError::changed());
    }
    let code = optional_string(&value, "code").ok_or_else(AppError::changed)?;
    if code != "1" {
        return Err(AppError::changed());
    }
    let rows = value
        .get("jgList")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let schemes = value
        .get("jcfaList")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut slots: SlotMap = HashMap::new();
    for scheme in schemes {
        let entries = scheme
            .get("skjcList")
            .and_then(Value::as_array)
            .ok_or_else(AppError::changed)?;
        for entry in entries {
            // GSMIS carries JCFADM on individual slots; outer scheme metadata
            // is optional. Match the row's own scheme first (Apple parser).
            let Some(scheme_id) =
                optional_string(entry, "JCFADM").or_else(|| optional_string(scheme, "JCFADM"))
            else {
                continue;
            };
            let section = optional_integer(entry, "DM").ok_or_else(AppError::changed)?;
            slots.insert(
                (scheme_id.clone(), section),
                (
                    optional_integer(entry, "KSSJ"),
                    optional_integer(entry, "JSSJ"),
                ),
            );
        }
    }

    let mut meetings = Vec::new();
    for (index, row) in rows.iter().enumerate() {
        let bitmap = optional_string(row, "ZCBH").ok_or_else(AppError::changed)?;
        if bitmap.is_empty() || !bitmap.bytes().all(|byte| matches!(byte, b'0' | b'1')) {
            return Err(AppError::changed());
        }
        if bitmap.as_bytes().get(week as usize - 1) != Some(&b'1') {
            continue;
        }
        if optional_string(row, "XNXQDM")
            .as_deref()
            .is_some_and(|row_term| row_term != term_id)
        {
            return Err(AppError::changed());
        }
        let name = required_string(row, "KCMC")?;
        let day = optional_integer(row, "XQ").ok_or_else(AppError::changed)?;
        let start_section = optional_integer(row, "KSJCDM").ok_or_else(AppError::changed)?;
        let end_section = optional_integer(row, "JSJCDM").ok_or_else(AppError::changed)?;
        if !(1..=7).contains(&day)
            || !(1..=14).contains(&start_section)
            || end_section < start_section
        {
            return Err(AppError::changed());
        }
        let scheme = optional_string(row, "JCFADM");
        meetings.push(CourseMeeting {
            id: format!("g-{index}-{day}-{start_section}"),
            name,
            day: day as i32,
            start_section: start_section as i32,
            end_section: end_section as i32,
            start_time: slot_time(&slots, scheme.as_deref(), start_section, true),
            end_time: slot_time(&slots, scheme.as_deref(), end_section, false),
            place: optional_string(row, "JASMC"),
            teacher: optional_string(row, "JGJSXM"),
            color: None,
        });
    }
    Ok(normalize_meetings(meetings))
}

fn valid_graduate_term(code: &str) -> bool {
    code.len() == 5
        && code.as_bytes()[..4].iter().all(u8::is_ascii_digit)
        && matches!(code.as_bytes()[4], b'1' | b'2' | b'3')
}
