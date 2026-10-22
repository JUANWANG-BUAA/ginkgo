use serde::Serialize;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryVenue {
    pub id: String,
    pub name: String,
    pub free: i32,
    pub total: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryArea {
    pub id: String,
    pub name: String,
    pub free: i32,
    pub total: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibrarySlot {
    /// Composite key: day + "/" + upstream segment id.
    pub id: String,
    pub day: String,
    pub start: String,
    pub end: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibrarySeat {
    pub id: String,
    pub name: String,
    pub status_name: String,
    pub available: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryBooking {
    pub id: String,
    /// Pre-composed display title (space/area/seat), never a member identity.
    pub title: String,
    pub area_name: String,
    pub seat_number: String,
    pub day: String,
    pub start_time: String,
    pub end_time: String,
    pub status: String,
    pub status_name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub booking_type: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub can_cancel: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flag_in: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flag_out: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flag_leave: Option<bool>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryHistoryPage {
    pub bookings: Vec<LibraryBooking>,
    pub page: i32,
    pub page_size: i32,
    pub total: Option<i64>,
    pub has_next: bool,
}

pub fn current_actions(booking: &LibraryBooking) -> Vec<String> {
    let now: chrono::DateTime<chrono::Utc> = std::time::SystemTime::now().into();
    let now = now.with_timezone(&chrono_tz::Asia::Shanghai).naive_local();
    ["signin", "leave", "checkout", "cancel"]
        .into_iter()
        .filter(|action| booking.allows(action, now))
        .map(str::to_owned)
        .collect()
}

impl LibraryBooking {
    pub fn active_at(&self, now: chrono::NaiveDateTime) -> bool {
        if ["6", "8"].contains(&self.status.trim())
            || ["取消", "结束", "已完成", "过期", "失效"]
                .iter()
                .any(|s| self.status_name.contains(s))
        {
            return false;
        }
        let end = format!("{} {}", self.day, self.end_time);
        ["%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"]
            .iter()
            .find_map(|format| chrono::NaiveDateTime::parse_from_str(&end, format).ok())
            .is_some_and(|end| end > now)
    }
    pub fn allows(&self, action: &str, now: chrono::NaiveDateTime) -> bool {
        if !self.active_at(now) {
            return false;
        }
        if action == "cancel" {
            return self.can_cancel != Some(false);
        }
        if !matches!(self.booking_type, None | Some(1)) {
            return false;
        }
        match action {
            "signin" => self.flag_in == Some(true) || self.flag_leave == Some(true),
            "leave" => self.flag_out == Some(true) && self.flag_leave != Some(true),
            "checkout" => self.flag_out == Some(true) || self.flag_leave == Some(true),
            _ => false,
        }
    }
}
