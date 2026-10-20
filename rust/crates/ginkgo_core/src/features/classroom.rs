use crate::AppError;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::{cmp::Ordering, collections::BTreeMap};
use unicode_normalization::{char::is_combining_mark, UnicodeNormalization};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Room {
    pub id: String,
    pub floorid: String,
    pub name: String,
    pub kxsds: String,
}

impl Room {
    pub fn sections(&self) -> Result<Vec<i32>, AppError> {
        if self.kxsds.trim().is_empty() {
            return Ok(vec![]);
        }
        let mut sections = self
            .kxsds
            .split([',', '，', '、', ' ', '/'])
            .filter(|s| !s.is_empty())
            .map(|s| {
                s.trim()
                    .parse::<i32>()
                    .ok()
                    .filter(|n| (1..=14).contains(n))
                    .ok_or_else(AppError::changed)
            })
            .collect::<Result<Vec<_>, _>>()?;
        if sections.is_empty() {
            return Err(AppError::changed());
        }
        sections.sort_unstable();
        sections.dedup();
        Ok(sections)
    }
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Sort {
    Name,
    Availability,
    Consecutive,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct FilterRequest {
    pub source_rooms: BTreeMap<String, Vec<Room>>,
    pub search: String,
    pub section: i32,
    pub minimum_free_sections: i32,
    pub minimum_consecutive_sections: i32,
    pub building: Option<String>,
    pub sort: Sort,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase")]
pub struct Summary {
    pub room_count: usize,
    pub building_count: usize,
    pub free_slot_count: usize,
}

#[derive(Debug, Clone)]
pub struct RoomResult {
    pub room: Room,
    pub sections: Vec<i32>,
    pub longest_run: usize,
}

impl RoomResult {
    pub fn section_states(&self) -> Vec<(i32, bool)> {
        (1..=14)
            .map(|number| (number, self.sections.contains(&number)))
            .collect()
    }
}

#[derive(Debug, Clone)]
pub struct FilterResult {
    pub buildings: BTreeMap<String, Vec<RoomResult>>,
    pub summary: Summary,
}

#[derive(Deserialize)]
struct UpstreamEnvelope {
    e: i64,
    d: UpstreamPayload,
}

#[derive(Deserialize)]
struct UpstreamPayload {
    list: BTreeMap<String, Vec<Room>>,
}

/// Decode the documented `buaafreeclass/search1` envelope without treating a
/// structural change or a business error as a valid empty result.
pub fn parse_upstream_response(value: Value) -> Result<BTreeMap<String, Vec<Room>>, AppError> {
    let response: UpstreamEnvelope =
        serde_json::from_value(value).map_err(|_| AppError::changed())?;
    if response.e != 0 {
        return Err(AppError::unavailable());
    }
    for rooms in response.d.list.values() {
        for room in rooms {
            if room.id.trim().is_empty() || room.name.trim().is_empty() {
                return Err(AppError::changed());
            }
            room.sections()?;
        }
    }
    Ok(response.d.list)
}

pub fn room_ids_by_building(rooms: &BTreeMap<String, Vec<Room>>) -> BTreeMap<String, Vec<String>> {
    rooms
        .iter()
        .map(|(building, rooms)| {
            (
                building.clone(),
                rooms.iter().map(|room| room.id.clone()).collect(),
            )
        })
        .collect()
}

pub fn normalize(value: &str) -> String {
    value
        .nfd()
        .filter(|c| !is_combining_mark(*c))
        .flat_map(char::to_lowercase)
        .filter(|c| c.is_alphanumeric())
        .collect()
}

/// Numeric runs sort naturally (e.g. room 2 before room 10), with stable ID ties.
fn natural_cmp(a: &str, b: &str) -> Ordering {
    let a: Vec<_> = normalize(a).chars().collect();
    let b: Vec<_> = normalize(b).chars().collect();
    let (mut i, mut j) = (0, 0);
    while i < a.len() && j < b.len() {
        let ordering = if a[i].is_ascii_digit() && b[j].is_ascii_digit() {
            let (start_i, start_j) = (i, j);
            while i < a.len() && a[i].is_ascii_digit() {
                i += 1;
            }
            while j < b.len() && b[j].is_ascii_digit() {
                j += 1;
            }
            let left = &a[start_i..i];
            let right = &b[start_j..j];
            let left = &left[left.iter().position(|c| *c != '0').unwrap_or(left.len())..];
            let right = &right[right.iter().position(|c| *c != '0').unwrap_or(right.len())..];
            left.len().cmp(&right.len()).then_with(|| left.cmp(right))
        } else {
            let ordering = a[i].cmp(&b[j]);
            i += 1;
            j += 1;
            ordering
        };
        if ordering != Ordering::Equal {
            return ordering;
        }
    }
    (a.len() - i).cmp(&(b.len() - j))
}

pub fn filter(request: FilterRequest) -> Result<FilterResult, AppError> {
    if !(0..=14).contains(&request.section)
        || !(0..=14).contains(&request.minimum_free_sections)
        || !(0..=14).contains(&request.minimum_consecutive_sections)
    {
        return Err(AppError::invalid());
    }
    let search = normalize(request.search.trim());
    let mut buildings = BTreeMap::new();
    let mut summary = Summary::default();
    for (building, rooms) in request.source_rooms {
        // Validate the entire response, including rooms hidden by a filter.
        let parsed = rooms
            .into_iter()
            .map(|room| {
                let sections = room.sections()?;
                let (mut longest_run, mut run, mut previous) = (0, 0, 0);
                for &section in &sections {
                    run = if section == previous + 1 { run + 1 } else { 1 };
                    longest_run = longest_run.max(run);
                    previous = section;
                }
                Ok(RoomResult {
                    room,
                    sections,
                    longest_run,
                })
            })
            .collect::<Result<Vec<_>, AppError>>()?;
        if request
            .building
            .as_ref()
            .is_some_and(|selected| selected != &building)
        {
            continue;
        }
        let matches_building = normalize(&building).contains(&search);
        let mut matches: Vec<_> = parsed
            .into_iter()
            .filter(|r| {
                (search.is_empty() || matches_building || normalize(&r.room.name).contains(&search))
                    && (request.section == 0 || r.sections.contains(&request.section))
                    && r.sections.len() >= request.minimum_free_sections as usize
                    && r.longest_run >= request.minimum_consecutive_sections as usize
            })
            .collect();
        matches.sort_by(|a, b| {
            let rank = match request.sort {
                Sort::Name => Ordering::Equal,
                Sort::Availability => b.sections.len().cmp(&a.sections.len()),
                Sort::Consecutive => b.longest_run.cmp(&a.longest_run),
            };
            rank.then_with(|| natural_cmp(&a.room.name, &b.room.name))
                .then_with(|| a.room.id.cmp(&b.room.id))
        });
        if matches.is_empty() {
            continue;
        }
        summary.room_count += matches.len();
        summary.building_count += 1;
        summary.free_slot_count += matches.iter().map(|r| r.sections.len()).sum::<usize>();
        buildings.insert(building, matches);
    }
    Ok(FilterResult { buildings, summary })
}
