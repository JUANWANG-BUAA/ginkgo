//! Synthetic campus use cases. Fixtures and response decoding never live in FFI.
use crate::AppError;

pub fn load_demo_bykc() -> Result<crate::codecs::bykc::Catalog, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/bykc/catalog-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    crate::codecs::bykc::parse_catalog(
        &fixture["input"]["config"],
        fixture["input"]["pages"]
            .as_array()
            .ok_or_else(AppError::changed)?,
    )
}

pub fn load_demo_bykc_chosen() -> Result<crate::codecs::bykc::ChosenCourses, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/bykc/chosen-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let courses = crate::codecs::bykc::parse_chosen(&fixture["input"])?;
    Ok(crate::codecs::bykc::ChosenCourses {
        term: Some(crate::codecs::bykc::Semester {
            id: "1".into(),
            name: "合成学期".into(),
            start: Some("2026-09-01 00:00:00".into()),
            end: Some("2027-01-31 23:59:59".into()),
        }),
        courses: Some(courses),
    })
}

pub fn load_demo_bykc_statistics() -> Result<crate::codecs::bykc::LearningStatistics, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/bykc/statistics-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    crate::codecs::bykc::parse_statistics(&fixture["input"])
}

pub fn load_demo_graduate() -> Result<crate::codecs::graduate::AcademicData, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/graduate/execution-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    Ok(crate::codecs::graduate::AcademicData {
        sections: crate::codecs::graduate::parse_execution(&fixture["input"])?,
        notice: None,
    })
}

pub fn load_demo_notices() -> Result<Vec<crate::codecs::notices::Notice>, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/notices/normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    crate::codecs::notices::parse(
        fixture["input"]["html"]
            .as_str()
            .ok_or_else(AppError::changed)?,
    )
}

pub fn load_demo_cgyy(kind: String) -> Result<serde_json::Value, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(match kind.as_str() {
        "venues" => include_str!("../../../../../fixtures/cgyy/venues-normal-v1.json"),
        "day" => include_str!("../../../../../fixtures/cgyy/day-normal-v1.json"),
        "orders" => include_str!("../../../../../fixtures/cgyy/orders-normal-v1.json"),
        "order" => include_str!("../../../../../fixtures/cgyy/order-detail-normal-v1.json"),
        "lockCode" => include_str!("../../../../../fixtures/cgyy/lock-code-normal-v1.json"),
        _ => return Err(AppError::invalid()),
    })
    .map_err(|_| AppError::changed())?;
    crate::services::execute_contract(&format!("cgyy.{kind}"), 1, fixture["input"].clone())
}

pub fn graduate_status() -> Result<crate::codecs::graduate::AcademicData, AppError> {
    let status = serde_json::json!({"datas":{"xsjcxxcx":{"rows":[{
        "YXDM_DISPLAY":"合成学院", "ZYDM_DISPLAY":"合成专业", "NJDM_DISPLAY":"2026级", "XJZTDM_DISPLAY":"在读"
    }]}}});
    Ok(crate::codecs::graduate::AcademicData {
        sections: vec![crate::codecs::graduate::parse_status(&status)?],
        notice: None,
    })
}
pub fn library_history(page: i32) -> Result<crate::codecs::library::LibraryHistoryPage, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/library/history-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let mut data = crate::codecs::library::parse_history(&fixture["input"]["data"], 1, 40)?;
    if page != 1 {
        data.bookings.clear();
    }
    data.page = page;
    data.page_size = 40;
    data.total = Some(2);
    data.has_next = false;
    Ok(data)
}
pub fn library_stats() -> Result<Vec<crate::codecs::library_stats::CampusStats>, AppError> {
    let fixture: serde_json::Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/library/stats-normal-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    crate::codecs::library_stats::parse(
        fixture["input"]["html"]
            .as_str()
            .ok_or_else(AppError::changed)?,
    )
}
