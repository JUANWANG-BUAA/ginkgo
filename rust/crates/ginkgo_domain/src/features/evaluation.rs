#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EvaluationCourseStatus {
    Pending,
    Completed,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EvaluationCourseItem {
    pub id: String,
    pub course_name: String,
    pub teacher_name: Option<String>,
    pub questionnaire_name: Option<String>,
    pub category: Option<String>,
    pub status: EvaluationCourseStatus,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TeachingEvaluationReport {
    pub task_id: Option<String>,
    pub task_name: Option<String>,
    pub term: Option<String>,
    pub courses: Vec<EvaluationCourseItem>,
}
