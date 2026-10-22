use crate::AppError;
pub use ginkgo_domain::features::classroom::*;
use serde::Deserialize;
use serde_json::Value;
use std::collections::BTreeMap;

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
