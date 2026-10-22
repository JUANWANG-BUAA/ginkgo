//! User-confirmed CGYY workflow. No session/reservation/captcha secrets in DTOs.
use serde::{Deserialize, Serialize};

#[derive(Clone, Deserialize)]
pub struct BookingRequest {
    pub site_id: i64,
    pub date: String,
    pub space_id: i64,
    pub time_ids: Vec<i64>,
    pub phone: String,
    pub theme: String,
    pub purpose_type: i64,
    pub joiner_num: i64,
    pub activity_content: String,
    pub joiners: String,
    pub philosophy: bool,
    pub off_school: bool,
}
#[derive(Deserialize)]
#[serde(tag = "action", rename_all = "camelCase")]
pub enum CgyyCommand {
    Options { site_id: i64, date: String },
    Prepare { booking: BookingRequest },
    Submit { challenge_id: String, x: i32 },
    Cancel { order_id: i64 },
    Status,
    Review,
    Acknowledge { review_id: String },
}
#[derive(Serialize)]
pub struct BookingChoice {
    pub space_id: i64,
    pub space_name: String,
    pub time_id: i64,
    pub time: String,
}
#[derive(Serialize)]
pub struct Purpose {
    pub id: i64,
    pub name: String,
}
#[derive(Serialize)]
pub struct BookingOptions {
    pub choices: Vec<BookingChoice>,
    pub purposes: Vec<Purpose>,
}
#[derive(Serialize)]
pub struct BookingChallenge {
    pub id: String,
    pub background: String,
    pub jigsaw: String,
}
#[derive(Serialize)]
pub struct BookingReview {
    pub id: String,
    pub orders: Vec<super::cgyy::Order>,
}
#[derive(Serialize)]
pub struct CgyyActionResult {
    pub state: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub options: Option<BookingOptions>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub challenge: Option<BookingChallenge>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub review: Option<BookingReview>,
}
impl CgyyActionResult {
    pub fn message(state: &str, message: &str) -> Self {
        Self {
            state: state.into(),
            message: message.into(),
            options: None,
            challenge: None,
            review: None,
        }
    }
}
