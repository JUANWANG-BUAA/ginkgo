//! Platform-independent learning queries; each capability can be implemented independently.
use super::DataOutcome;
use crate::AppError;
use serde::{Deserialize, Serialize};
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LearningCourse {
    pub id: String,
    pub name: String,
    pub teacher: Option<String>,
    pub term: Option<String>,
    pub source_url: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseAnnouncement {
    pub id: String,
    pub title: String,
    pub published_at: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LearningAttachment {
    pub id: String,
    pub name: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseAnnouncementDetail {
    pub id: String,
    pub title: String,
    pub content: Option<String>,
    pub attachments: Vec<LearningAttachment>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseResource {
    pub id: String,
    pub name: String,
    pub folder: bool,
    pub downloadable: bool,
    pub updated_at: Option<String>,
    pub extension: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseResourcePage {
    pub items: Vec<CourseResource>,
    pub page: u32,
    pub has_next: bool,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct CourseAssessment {
    pub id: String,
    pub title: String,
    pub starts_at: Option<String>,
    pub due_at: Option<String>,
    pub score: Option<String>,
    pub source_url: String,
}
pub struct LearningDownload {
    pub name: String,
    pub bytes: Vec<u8>,
}
pub trait LearningCourseSource: Send + Sync {
    fn learning_courses(
        &self,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<Vec<LearningCourse>>, AppError>> + Send;
}
pub trait CourseAnnouncementSource: Send + Sync {
    fn course_announcements(
        &self,
        course: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<Vec<CourseAnnouncement>>, AppError>> + Send;
    fn course_announcement_detail(
        &self,
        course: &str,
        id: &str,
    ) -> impl std::future::Future<Output = Result<CourseAnnouncementDetail, AppError>> + Send;
    fn course_announcement_attachment(
        &self,
        course: &str,
        id: &str,
        file: &str,
    ) -> impl std::future::Future<Output = Result<LearningDownload, AppError>> + Send;
}
pub trait CourseResourceSource: Send + Sync {
    fn course_resources(
        &self,
        course: &str,
        folder: Option<&str>,
        page: u32,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<CourseResourcePage>, AppError>> + Send;
    fn course_resource_download(
        &self,
        course: &str,
        folder: Option<&str>,
        page: u32,
        id: &str,
    ) -> impl std::future::Future<Output = Result<LearningDownload, AppError>> + Send;
}
pub trait CourseAssessmentSource: Send + Sync {
    fn course_assessments(
        &self,
        course: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<Vec<CourseAssessment>>, AppError>> + Send;
}

/// Opaque course-owned context, never a school endpoint or editable type code.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum LearningColumnKind {
    Announcement,
    Assessment,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LearningColumn {
    pub id: String,
    pub name: String,
    pub kind: LearningColumnKind,
}
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub enum LearningCapabilityState {
    #[default]
    Unknown,
    Available,
    AuthRequired,
    TemporarilyUnavailable,
    ProtocolChanged,
    AccessDenied,
}
/// Last actual authorized read result in the current identity/cache epoch.
/// Unknown means unobserved, not unsupported. Empty successful reads are available.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct LearningCapabilities {
    pub columns: LearningCapabilityState,
    pub announcements: LearningCapabilityState,
    pub resources: LearningCapabilityState,
    pub assessments: LearningCapabilityState,
    pub resource_download: LearningCapabilityState,
    pub announcement_download: LearningCapabilityState,
}
/// Additional contextual queries; original independent source traits remain compatible.
pub trait CourseLearningContextSource: Send + Sync {
    fn course_learning_columns(
        &self,
        course: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<Vec<LearningColumn>>, AppError>> + Send;
    fn course_announcements_in(
        &self,
        course: &str,
        column: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<Vec<CourseAnnouncement>>, AppError>> + Send;
    fn course_announcement_detail_in(
        &self,
        course: &str,
        column: &str,
        id: &str,
    ) -> impl std::future::Future<Output = Result<CourseAnnouncementDetail, AppError>> + Send;
    fn course_announcement_attachment_in(
        &self,
        course: &str,
        column: &str,
        id: &str,
        file: &str,
    ) -> impl std::future::Future<Output = Result<LearningDownload, AppError>> + Send;
    fn course_assessments_in(
        &self,
        course: &str,
        column: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<Vec<CourseAssessment>>, AppError>> + Send;
    fn course_resources_at(
        &self,
        course: &str,
        path: &[String],
        page: u32,
        force: bool,
    ) -> impl std::future::Future<Output = Result<DataOutcome<CourseResourcePage>, AppError>> + Send;
    fn course_resource_download_at(
        &self,
        course: &str,
        path: &[String],
        page: u32,
        id: &str,
    ) -> impl std::future::Future<Output = Result<LearningDownload, AppError>> + Send;
    fn course_learning_capabilities(
        &self,
        course: &str,
    ) -> impl std::future::Future<Output = Result<LearningCapabilities, AppError>> + Send;
}
