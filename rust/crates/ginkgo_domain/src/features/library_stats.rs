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
