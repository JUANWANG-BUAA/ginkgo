//! Stable academic business capability and values.
use crate::{
    features::{
        grades::{GradeCourse, GradeSummary},
        schedule::{CourseMeeting, Exam, Term, Week},
        today::TodayCourse,
    },
    AppError,
};
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ScheduleData {
    pub terms: Vec<Term>,
    pub weeks: Vec<Week>,
    pub term_id: String,
    pub week_number: i32,
    pub courses: Vec<CourseMeeting>,
    pub exams: Vec<Exam>,
}

pub struct ScheduleQueryInput {
    pub term_id: Option<String>,
    pub week: Option<i32>,
    pub force_refresh: bool,
}

pub type ScheduleOutcome = super::ReadSnapshot<ScheduleData>;

#[derive(Debug, PartialEq, Eq)]
pub struct TodayOutcome {
    pub date: String,
    pub courses: Vec<TodayCourse>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

#[derive(Clone)]
pub struct GradeData {
    pub term_id: String,
    pub courses: Vec<GradeCourse>,
}

pub struct GradeOutcome {
    pub term_id: String,
    pub courses: Vec<GradeCourse>,
    pub summary: GradeSummary,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

pub trait ScheduleSource: Send + Sync {
    fn load_schedule(
        &self,
        input: &ScheduleQueryInput,
    ) -> impl std::future::Future<Output = Result<ScheduleOutcome, AppError>> + Send;
}

pub trait TodaySource: Send + Sync {
    fn load_today(
        &self,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<TodayOutcome, AppError>> + Send;
}

pub trait GradeSource: Send + Sync {
    fn load_grades(
        &self,
        term_code: Option<&str>,
        force_refresh: bool,
    ) -> impl std::future::Future<Output = Result<GradeOutcome, AppError>> + Send;
    fn load_grade_terms(
        &self,
    ) -> impl std::future::Future<Output = Result<Vec<Term>, AppError>> + Send;
}
