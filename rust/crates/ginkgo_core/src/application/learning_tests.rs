use super::*;
use std::sync::Mutex;
#[derive(Default)]
struct LearningStub {
    calls: Mutex<Vec<String>>,
}
impl LearningStub {
    fn record(&self, s: String) {
        self.calls.lock().unwrap().push(s);
    }
}
impl LearningCourseSource for LearningStub {
    async fn learning_courses(
        &self,
        force: bool,
    ) -> Result<DataOutcome<Vec<LearningCourse>>, AppError> {
        self.record(format!("courses:{force}"));
        Ok(DataOutcome {
            data: vec![],
            failure: None,
        })
    }
}
impl CourseAnnouncementSource for LearningStub {
    async fn course_announcements(
        &self,
        c: &str,
        f: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        self.record(format!("announcements:{c}:{f}"));
        Ok(DataOutcome {
            data: vec![CourseAnnouncement {
                id: "old".into(),
                title: "old".into(),
                published_at: None,
            }],
            failure: Some(AppError::changed()),
        })
    }
    async fn course_announcement_detail(
        &self,
        c: &str,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        self.record(format!("detail:{c}:{id}"));
        Err(AppError::session_expired())
    }
    async fn course_announcement_attachment(
        &self,
        c: &str,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        self.record(format!("attachment:{c}:{id}:{file}"));
        Ok(LearningDownload {
            name: "fixture".into(),
            bytes: vec![1, 2],
        })
    }
}
impl CourseResourceSource for LearningStub {
    async fn course_resources(
        &self,
        c: &str,
        folder: Option<&str>,
        page: u32,
        force: bool,
    ) -> Result<DataOutcome<CourseResourcePage>, AppError> {
        self.record(format!("resources:{c}:{folder:?}:{page}:{force}"));
        Ok(DataOutcome {
            data: CourseResourcePage {
                page,
                has_next: false,
                items: vec![],
            },
            failure: None,
        })
    }
    async fn course_resource_download(
        &self,
        c: &str,
        folder: Option<&str>,
        page: u32,
        id: &str,
    ) -> Result<LearningDownload, AppError> {
        self.record(format!("download:{c}:{folder:?}:{page}:{id}"));
        Err(AppError::invalid())
    }
}
impl CourseAssessmentSource for LearningStub {
    async fn course_assessments(
        &self,
        c: &str,
        f: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        self.record(format!("assessments:{c}:{f}"));
        Err(AppError::unavailable())
    }
}
#[tokio::test]
async fn learning_facade_preserves_empty_stale_failure_and_opaque_query_context() {
    let workspace = Workspace::new(LearningStub::default());
    let c = workspace.learning_courses(true).await.unwrap();
    assert!(c.data.is_empty());
    assert!(c.failure.is_none());
    let n = workspace
        .course_announcements("course", false)
        .await
        .unwrap();
    assert_eq!(n.data[0].id, "old");
    assert_eq!(
        n.failure.unwrap().code,
        ginkgo_domain::ErrorCode::ChangedResponse
    );
    assert_eq!(
        workspace
            .course_announcement_detail("course", "n")
            .await
            .unwrap_err()
            .code,
        ginkgo_domain::ErrorCode::SessionExpired
    );
    assert_eq!(
        workspace
            .course_announcement_attachment("course", "n", "f")
            .await
            .unwrap()
            .bytes,
        vec![1, 2]
    );
    let r = workspace
        .course_resources("course", Some("folder"), 2, true)
        .await
        .unwrap();
    assert_eq!(r.data.page, 2);
    assert!(r.data.items.is_empty());
    assert!(workspace
        .course_resource_download("course", Some("folder"), 2, "file")
        .await
        .is_err());
    assert!(workspace.course_assessments("course", true).await.is_err());
    assert_eq!(
        *workspace.upstream.calls.lock().unwrap(),
        [
            "courses:true",
            "announcements:course:false",
            "detail:course:n",
            "attachment:course:n:f",
            "resources:course:Some(\"folder\"):2:true",
            "download:course:Some(\"folder\"):2:file",
            "assessments:course:true"
        ]
    );
}

impl CourseLearningContextSource for LearningStub {
    async fn course_learning_columns(
        &self,
        c: &str,
        f: bool,
    ) -> Result<DataOutcome<Vec<LearningColumn>>, AppError> {
        self.record(format!("columns:{c}:{f}"));
        Ok(DataOutcome {
            data: vec![LearningColumn {
                id: "col".into(),
                name: "synthetic".into(),
                kind: LearningColumnKind::Announcement,
            }],
            failure: None,
        })
    }
    async fn course_announcements_in(
        &self,
        c: &str,
        col: &str,
        f: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        self.record(format!("scoped:{col}"));
        self.course_announcements(c, f).await
    }
    async fn course_announcement_detail_in(
        &self,
        c: &str,
        col: &str,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        self.record(format!("scoped:{col}"));
        self.course_announcement_detail(c, id).await
    }
    async fn course_announcement_attachment_in(
        &self,
        c: &str,
        col: &str,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        self.record(format!("scoped:{col}"));
        self.course_announcement_attachment(c, id, file).await
    }
    async fn course_assessments_in(
        &self,
        c: &str,
        col: &str,
        f: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        self.record(format!("scoped:{col}"));
        self.course_assessments(c, f).await
    }
    async fn course_resources_at(
        &self,
        c: &str,
        path: &[String],
        page: u32,
        f: bool,
    ) -> Result<DataOutcome<CourseResourcePage>, AppError> {
        self.record(format!("path:{path:?}"));
        self.course_resources(c, path.last().map(String::as_str), page, f)
            .await
    }
    async fn course_resource_download_at(
        &self,
        c: &str,
        path: &[String],
        page: u32,
        id: &str,
    ) -> Result<LearningDownload, AppError> {
        self.record(format!("path:{path:?}"));
        self.course_resource_download(c, path.last().map(String::as_str), page, id)
            .await
    }
    async fn course_learning_capabilities(
        &self,
        c: &str,
    ) -> Result<LearningCapabilities, AppError> {
        self.record(format!("health:{c}"));
        Ok(LearningCapabilities::default())
    }
}
#[tokio::test]
async fn learning_context_facade_preserves_explicit_selection_path_and_passive_unknown() {
    let w = Workspace::new(LearningStub::default());
    assert_eq!(
        w.course_learning_columns("c", true).await.unwrap().data[0].id,
        "col"
    );
    assert!(w
        .course_announcements_in("c", "n", false)
        .await
        .unwrap()
        .failure
        .is_some());
    assert!(w
        .course_announcement_detail_in("c", "n", "notice")
        .await
        .is_err());
    assert_eq!(
        w.course_announcement_attachment_in("c", "n", "notice", "f")
            .await
            .unwrap()
            .bytes,
        vec![1, 2]
    );
    assert!(w.course_assessments_in("c", "q", false).await.is_err());
    assert_eq!(
        w.course_resources_at("c", &["root".into(), "child".into()], 3, true)
            .await
            .unwrap()
            .data
            .page,
        3
    );
    assert!(w
        .course_resource_download_at("c", &[], 1, "file")
        .await
        .is_err());
    assert_eq!(
        w.course_learning_capabilities("c").await.unwrap().resources,
        LearningCapabilityState::Unknown
    );
    assert_eq!(
        *w.upstream.calls.lock().unwrap(),
        [
            "columns:c:true",
            "scoped:n",
            "announcements:c:false",
            "scoped:n",
            "detail:c:notice",
            "scoped:n",
            "attachment:c:notice:f",
            "scoped:q",
            "assessments:c:false",
            "path:[\"root\", \"child\"]",
            "resources:c:Some(\"child\"):3:true",
            "path:[]",
            "download:c:None:1:file",
            "health:c"
        ]
    );
}
