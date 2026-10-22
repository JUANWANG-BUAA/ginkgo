#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CheckInStatus {
    NotSigned,
    Signed,
    /// Upstream returned a value outside the documented 0/1 pair.
    Unknown,
}

impl CheckInStatus {
    pub fn name(self) -> &'static str {
        match self {
            Self::NotSigned => "notSigned",
            Self::Signed => "signed",
            Self::Unknown => "unknown",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CheckInCourse {
    pub id: String,
    pub course_id: Option<String>,
    pub course_num: Option<String>,
    pub course_name: String,
    pub begins_at: String,
    pub ends_at: String,
    pub status: CheckInStatus,
    pub teacher_name: Option<String>,
    pub classroom_name: Option<String>,
    pub merged_record_count: usize,
    pub conflicting: bool,
    pub sign_in_allowed: bool,
}
