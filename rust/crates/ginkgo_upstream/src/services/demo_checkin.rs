//! Synthetic iclass day compiled from the shared fixture.
use crate::{
    codecs::checkin::{self, CheckInCourse},
    AppError,
};
use serde_json::Value;

pub struct DemoCheckIn {
    pub date: String,
    pub courses: Vec<CheckInCourse>,
}

pub fn load() -> Result<DemoCheckIn, AppError> {
    let fixture: Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/checkin/course-schedule-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let body = fixture
        .get("input")
        .and_then(|input| input.get("body"))
        .cloned()
        .ok_or_else(AppError::changed)?;
    Ok(DemoCheckIn {
        date: "2026-10-20".into(),
        courses: checkin::parse_course_schedule(&body)?,
    })
}

pub fn prepare_qr(
    course_id: &str,
) -> Result<ginkgo_domain::features::checkin::CheckInQrTicket, AppError> {
    use ginkgo_domain::features::checkin::{encode_qr_matrix, CheckInQrTicket};
    let course_id = course_id.trim();
    if course_id.is_empty() {
        return Err(AppError::invalid());
    }
    let payload = format!("ginkgo-demo-checkin:{course_id}");
    let (matrix_size, modules) = encode_qr_matrix(&payload).map_err(|()| AppError::invalid())?;
    Ok(CheckInQrTicket {
        course_id: course_id.to_owned(),
        fetched_at: "2026-10-20T08:00:00+08:00".into(),
        refresh_seconds: 4,
        matrix_size,
        modules,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_checkin_matches_fixture() {
        let day = load().expect("checkin");
        assert_eq!(day.date, "2026-10-20");
        assert_eq!(day.courses.len(), 2);
        assert_eq!(day.courses[0].course_name, "高等数学");
    }
}
