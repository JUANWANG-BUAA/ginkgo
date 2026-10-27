//! Synthetic SPOC homework page compiled from the shared fixture.
use crate::{
    codecs::homework::{self, HomeworkPage},
    AppError,
};
use serde_json::Value;

pub struct DemoHomework {
    pub term_name: String,
    pub term_code: String,
    pub page: HomeworkPage,
}

pub fn load() -> Result<DemoHomework, AppError> {
    let fixture: Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/homework/spoc-page-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let body = fixture
        .get("input")
        .and_then(|input| input.get("body"))
        .cloned()
        .ok_or_else(AppError::changed)?;
    let context: Value = serde_json::from_str(include_str!(
        "../../../../../fixtures/homework/course-context-v1.json"
    ))
    .map_err(|_| AppError::changed())?;
    let mut page = homework::parse_page(body)?;
    homework::apply_course_context(&mut page.items, &context["input"]["courses"])?;
    Ok(DemoHomework {
        term_name: "2026-2027学年第1学期".into(),
        term_code: "2026-2027-1".into(),
        page,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn demo_homework_matches_fixture() {
        let homework = load().expect("homework");
        assert_eq!(homework.term_code, "2026-2027-1");
        assert_eq!(homework.page.items.len(), 2);
        assert_eq!(homework.page.items[0].title, "作业一");
    }
}
