//! Learning facade: no HTTP or provider schema.
use super::*;
impl<U: LearningCourseSource> Workspace<U> {
    pub async fn learning_courses(
        &self,
        force: bool,
    ) -> Result<DataOutcome<Vec<LearningCourse>>, AppError> {
        self.upstream.learning_courses(force).await
    }
}
impl<U: CourseAnnouncementSource> Workspace<U> {
    pub async fn course_announcements(
        &self,
        course: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        self.upstream.course_announcements(course, force).await
    }
    pub async fn course_announcement_detail(
        &self,
        course: &str,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        self.upstream.course_announcement_detail(course, id).await
    }
    pub async fn course_announcement_attachment(
        &self,
        course: &str,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        self.upstream
            .course_announcement_attachment(course, id, file)
            .await
    }
}
impl<U: CourseResourceSource> Workspace<U> {
    pub async fn course_resources(
        &self,
        course: &str,
        folder: Option<&str>,
        page: u32,
        force: bool,
    ) -> Result<DataOutcome<CourseResourcePage>, AppError> {
        self.upstream
            .course_resources(course, folder, page, force)
            .await
    }
    pub async fn course_resource_download(
        &self,
        course: &str,
        folder: Option<&str>,
        page: u32,
        id: &str,
    ) -> Result<LearningDownload, AppError> {
        self.upstream
            .course_resource_download(course, folder, page, id)
            .await
    }
}
impl<U: CourseAssessmentSource> Workspace<U> {
    pub async fn course_assessments(
        &self,
        course: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        self.upstream.course_assessments(course, force).await
    }
}

impl<U: CourseLearningContextSource> Workspace<U> {
    pub async fn course_learning_columns(
        &self,
        course: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<LearningColumn>>, AppError> {
        self.upstream.course_learning_columns(course, force).await
    }
    pub async fn course_announcements_in(
        &self,
        course: &str,
        column: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        self.upstream
            .course_announcements_in(course, column, force)
            .await
    }
    pub async fn course_announcement_detail_in(
        &self,
        course: &str,
        column: &str,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        self.upstream
            .course_announcement_detail_in(course, column, id)
            .await
    }
    pub async fn course_announcement_attachment_in(
        &self,
        course: &str,
        column: &str,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        self.upstream
            .course_announcement_attachment_in(course, column, id, file)
            .await
    }
    pub async fn course_assessments_in(
        &self,
        course: &str,
        column: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        self.upstream
            .course_assessments_in(course, column, force)
            .await
    }
    pub async fn course_resources_at(
        &self,
        course: &str,
        path: &[String],
        page: u32,
        force: bool,
    ) -> Result<DataOutcome<CourseResourcePage>, AppError> {
        self.upstream
            .course_resources_at(course, path, page, force)
            .await
    }
    pub async fn course_resource_download_at(
        &self,
        course: &str,
        path: &[String],
        page: u32,
        id: &str,
    ) -> Result<LearningDownload, AppError> {
        self.upstream
            .course_resource_download_at(course, path, page, id)
            .await
    }
    pub async fn course_learning_capabilities(
        &self,
        course: &str,
    ) -> Result<LearningCapabilities, AppError> {
        self.upstream.course_learning_capabilities(course).await
    }
}

#[cfg(test)]
#[path = "learning_tests.rs"]
mod tests;
