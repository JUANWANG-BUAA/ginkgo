use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
pub struct Site {
    pub id: i64,
    pub name: String,
    pub venue: String,
    pub campus: String,
    pub seats: Option<i64>,
    pub open_start: String,
    pub open_end: String,
}
#[derive(Clone, Debug, Serialize)]
pub struct Slot {
    pub time: String,
    pub status: String,
}
#[derive(Clone, Debug, Serialize)]
pub struct Space {
    pub name: String,
    pub slots: Vec<Slot>,
}
#[derive(Clone, Debug, Serialize)]
pub struct Day {
    pub site_id: i64,
    pub date: String,
    pub dates: Vec<String>,
    pub spaces: Vec<Space>,
}
#[derive(Clone, Debug, Serialize)]
pub struct Order {
    pub id: i64,
    pub place: String,
    pub date: String,
    pub time: String,
    pub status: String,
}
