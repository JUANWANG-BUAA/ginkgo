//! Public shuttle timetable values (API §6C). Only the official published
//! timetable is modelled: no live seat counts, no ticket purchase.
use serde::Serialize;

/// One scheduled departure.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ShuttleRun {
    /// Published sequence number ("班次").
    pub index: String,
    /// Published departure time exactly as printed.
    pub time: String,
    /// Published seat count ("可乘人数"); empty when the table has none.
    pub capacity: String,
}

/// One direction pair under a validity label such as "星期一至星期五".
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ShuttleSection {
    pub label: String,
    pub left: Vec<ShuttleRun>,
    pub right: Vec<ShuttleRun>,
}

/// One published table: two directions plus their dated sections.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ShuttleTable {
    pub left: String,
    pub right: String,
    pub sections: Vec<ShuttleSection>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ShuttleTimetable {
    pub tables: Vec<ShuttleTable>,
    /// Official page the data was read from, for traceability.
    pub source: String,
}
