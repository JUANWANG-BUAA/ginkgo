//! Public library occupancy and facility counts, API.md §5.5.
use crate::AppError;
use regex::Regex;
use serde::Serialize;

#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
pub struct CountPair {
    pub available: i32,
    pub total: i32,
}
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct ReadingRoom {
    pub name: String,
    pub people: i32,
}
#[derive(Clone, Debug, Serialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct CampusStats {
    pub id: String,
    pub name: String,
    pub people: i32,
    pub reading_rooms: Vec<ReadingRoom>,
    pub seats: Option<CountPair>,
    pub study_rooms: Option<CountPair>,
    pub lockers: Option<CountPair>,
}
fn integer(value: &str) -> Result<i32, AppError> {
    value.parse().map_err(|_| AppError::changed())
}
fn pair(name: &str, unit: &str, items: &[String]) -> Result<Option<CountPair>, AppError> {
    let relevant: Vec<_> = items.iter().filter(|item| item.contains(name)).collect();
    if relevant.is_empty() {
        return Ok(None);
    }
    let pattern = Regex::new(&format!(
        r"{}\s*空闲\s*(\d+)\s*{}\s*/\s*总计\s*(\d+)\s*{}",
        regex::escape(name),
        regex::escape(unit),
        regex::escape(unit)
    ))
    .map_err(|_| AppError::changed())?;
    for item in relevant {
        if let Some(captures) = pattern.captures(item) {
            let available = integer(&captures[1])?;
            let total = integer(&captures[2])?;
            if available > total {
                return Err(AppError::changed());
            }
            return Ok(Some(CountPair { available, total }));
        }
    }
    Err(AppError::changed())
}
pub fn parse(html: &str) -> Result<Vec<CampusStats>, AppError> {
    let campuses = Regex::new(
        r#"(?is)<img\b[^>]*\bsrc=["'][^"']*/more/custom/t_(xylxq|shxq)\.png[^"']*["'][^>]*>"#,
    )
    .expect("constant regex");
    let list = Regex::new(r"(?is)<li\b[^>]*>(.*?)</li>").expect("constant regex");
    let tags = Regex::new(r"(?is)<[^>]*>").expect("constant regex");
    let people_pattern = Regex::new(r"图书馆\s*(\d+)\s*人").expect("constant regex");
    let rooms = Regex::new(r"(特色阅览室.*?)\s*(\d+)\s*人").expect("constant regex");
    let headings: Vec<_> = campuses.captures_iter(html).collect();
    if headings.len() != 2 {
        return Err(AppError::changed());
    }
    let mut result = Vec::new();
    for (index, heading) in headings.iter().enumerate() {
        let id = &heading[1];
        if result.iter().any(|campus: &CampusStats| campus.id == id) {
            return Err(AppError::changed());
        }
        let begin = heading.get(0).ok_or_else(AppError::changed)?.start();
        let end = headings
            .get(index + 1)
            .and_then(|h| h.get(0))
            .map_or(html.len(), |m| m.start());
        let items: Vec<String> = list
            .captures_iter(&html[begin..end])
            .map(|m| {
                tags.replace_all(&m[1], "")
                    .replace("&nbsp;", " ")
                    .replace("&#160;", " ")
                    .replace("&amp;", "&")
                    .trim()
                    .to_owned()
            })
            .collect();
        let people = items
            .iter()
            .find_map(|item| people_pattern.captures(item))
            .ok_or_else(AppError::changed)?;
        let reading_rooms = items
            .iter()
            .filter(|item| item.starts_with("特色阅览室"))
            .map(|item| {
                let captures = rooms.captures(item).ok_or_else(AppError::changed)?;
                Ok(ReadingRoom {
                    name: captures[1].trim().to_owned(),
                    people: integer(&captures[2])?,
                })
            })
            .collect::<Result<Vec<_>, AppError>>()?;
        result.push(CampusStats {
            id: id.to_owned(),
            name: if id == "xylxq" {
                "学院路校区"
            } else {
                "沙河校区"
            }
            .into(),
            people: integer(&people[1])?,
            reading_rooms,
            seats: pair("预约座位", "座", &items)?,
            study_rooms: pair("研讨间", "间", &items)?,
            lockers: pair("寄存柜", "个", &items)?,
        });
    }
    Ok(result)
}
