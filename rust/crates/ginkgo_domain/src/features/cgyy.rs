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
    #[serde(skip_serializing_if = "Option::is_none")]
    pub order_status: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub check_status: Option<i64>,
    pub can_cancel: bool,
    pub id: i64,
    pub place: String,
    pub date: String,
    pub time: String,
    pub status: String,
}

#[derive(Clone, Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CgyyLockCode {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub qr_code: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub due_date: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub trade_no: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub venue_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub site_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub space_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub order_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reservation_date: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reservation_date_detail: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reservation_start_date: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reservation_end_date: Option<String>,
}
