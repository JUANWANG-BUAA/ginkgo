//! Business mapping and lifecycle gates only.
use super::*;

fn bound(expected: &str) -> Result<&'static LiveService, AppError> {
    // Reject an absent account capability before creating the native runtime.
    // Invalid reads must not initialize real networking or platform storage.
    if expected.is_empty() {
        return Err(AppError::session_expired());
    }
    let s = service()?;
    if s.status().account.as_deref() != Some(expected) {
        return Err(AppError::session_expired());
    }
    Ok(s)
}

/// Splits a data outcome into its typed value and boundary failure. A failure
/// may accompany data only when it is a previous successful snapshot.
fn outcome<D>(
    result: Result<ginkgo_core::application::DataOutcome<D>, AppError>,
) -> (Option<D>, Option<FailureCode>) {
    match result {
        Ok(v) => (Some(v.data), v.failure.map(|e| e.code.into())),
        Err(e) => (None, Some(e.code.into())),
    }
}

pub(super) async fn courses(expected: String, force: bool) -> LearningCoursesResponse {
    let (data, failure) = outcome(
        with_session_read(|| async { bound(&expected)?.learning_courses(force).await }).await,
    );
    LearningCoursesResponse {
        data: data.map(|courses| {
            courses
                .into_iter()
                .map(|course| LearningCourseDto {
                    id: course.id,
                    name: course.name,
                    teacher: course.teacher,
                    term: course.term,
                    source_url: course.source_url,
                })
                .collect()
        }),
        failure,
    }
}

pub(super) async fn announcements(
    expected: String,
    course: String,
    force: bool,
) -> CourseAnnouncementsResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            bound(&expected)?.course_announcements(&course, force).await
        })
        .await,
    );
    CourseAnnouncementsResponse {
        data: data.map(|rows| {
            rows.into_iter()
                .map(|row| CourseAnnouncementDto {
                    id: row.id,
                    title: row.title,
                    published_at: row.published_at,
                })
                .collect()
        }),
        failure,
    }
}

pub(super) async fn resources(
    expected: String,
    course: String,
    folder: Option<String>,
    page: u32,
    force: bool,
) -> CourseResourcePageResponse {
    resources_response(
        with_session_read(|| async {
            bound(&expected)?
                .course_resources(&course, folder.as_deref(), page, force)
                .await
        })
        .await,
    )
}

fn resources_response(
    result: Result<
        ginkgo_core::application::DataOutcome<ginkgo_core::application::CourseResourcePage>,
        AppError,
    >,
) -> CourseResourcePageResponse {
    let (data, failure) = outcome(result);
    CourseResourcePageResponse {
        data: data.map(resource_page_dto),
        failure,
    }
}

pub(super) async fn assessments(
    expected: String,
    course: String,
    force: bool,
) -> CourseAssessmentsResponse {
    let (data, failure) = outcome(
        with_session_read(|| async { bound(&expected)?.course_assessments(&course, force).await })
            .await,
    );
    CourseAssessmentsResponse {
        data: data.map(|rows| {
            rows.into_iter()
                .map(|row| CourseAssessmentDto {
                    id: row.id,
                    title: row.title,
                    starts_at: row.starts_at,
                    due_at: row.due_at,
                    score: row.score,
                    source_url: row.source_url,
                })
                .collect()
        }),
        failure,
    }
}

pub(super) async fn announcement_detail(
    expected: String,
    course: String,
    id: String,
) -> CourseAnnouncementDetailResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            let data = bound(&expected)?
                .course_announcement_detail(&course, &id)
                .await?;
            Ok(ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            })
        })
        .await,
    );
    CourseAnnouncementDetailResponse {
        data: data.map(detail_dto),
        failure,
    }
}

fn download(
    result: Result<ginkgo_core::application::LearningDownload, AppError>,
) -> HomeworkFileDownloadResponse {
    match result {
        Ok(file) => HomeworkFileDownloadResponse {
            name: Some(file.name),
            bytes: Some(file.bytes),
            failure: None,
        },
        Err(e) => HomeworkFileDownloadResponse {
            name: None,
            bytes: None,
            failure: Some(e.code.into()),
        },
    }
}

pub(super) async fn resource_download(
    expected: String,
    course: String,
    folder: Option<String>,
    page: u32,
    id: String,
) -> HomeworkFileDownloadResponse {
    download(
        with_session_read(|| async {
            bound(&expected)?
                .course_resource_download(&course, folder.as_deref(), page, &id)
                .await
        })
        .await,
    )
}

pub(super) async fn announcement_attachment(
    expected: String,
    course: String,
    id: String,
    file: String,
) -> HomeworkFileDownloadResponse {
    download(
        with_session_read(|| async {
            bound(&expected)?
                .course_announcement_attachment(&course, &id, &file)
                .await
        })
        .await,
    )
}

pub(super) async fn columns(
    expected: String,
    course: String,
    force: bool,
) -> LearningColumnsResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            bound(&expected)?
                .course_learning_columns(&course, force)
                .await
        })
        .await,
    );
    LearningColumnsResponse {
        data: data.map(|rows| {
            rows.into_iter()
                .map(|row| LearningColumnDto {
                    id: row.id,
                    name: row.name,
                    kind: match row.kind {
                        ginkgo_core::application::LearningColumnKind::Announcement => {
                            LearningColumnKindDto::Announcement
                        }
                        ginkgo_core::application::LearningColumnKind::Assessment => {
                            LearningColumnKindDto::Assessment
                        }
                    },
                })
                .collect()
        }),
        failure,
    }
}

pub(super) async fn capabilities(expected: String, course: String) -> LearningCapabilitiesResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            let data = bound(&expected)?
                .course_learning_capabilities(&course)
                .await?;
            Ok(ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            })
        })
        .await,
    );
    LearningCapabilitiesResponse {
        data: data.map(capability_dto),
        failure,
    }
}

pub(super) async fn announcements_in(
    expected: String,
    course: String,
    column: String,
    force: bool,
) -> CourseAnnouncementsResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            bound(&expected)?
                .course_announcements_in(&course, &column, force)
                .await
        })
        .await,
    );
    CourseAnnouncementsResponse {
        data: data.map(|rows| {
            rows.into_iter()
                .map(|row| CourseAnnouncementDto {
                    id: row.id,
                    title: row.title,
                    published_at: row.published_at,
                })
                .collect()
        }),
        failure,
    }
}

pub(super) async fn assessments_in(
    expected: String,
    course: String,
    column: String,
    force: bool,
) -> CourseAssessmentsResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            bound(&expected)?
                .course_assessments_in(&course, &column, force)
                .await
        })
        .await,
    );
    CourseAssessmentsResponse {
        data: data.map(|rows| {
            rows.into_iter()
                .map(|row| CourseAssessmentDto {
                    id: row.id,
                    title: row.title,
                    starts_at: row.starts_at,
                    due_at: row.due_at,
                    score: row.score,
                    source_url: row.source_url,
                })
                .collect()
        }),
        failure,
    }
}

pub(super) async fn detail_in(
    expected: String,
    course: String,
    column: String,
    id: String,
) -> CourseAnnouncementDetailResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            let data = bound(&expected)?
                .course_announcement_detail_in(&course, &column, &id)
                .await?;
            Ok(ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            })
        })
        .await,
    );
    CourseAnnouncementDetailResponse {
        data: data.map(detail_dto),
        failure,
    }
}

pub(super) async fn attachment_in(
    expected: String,
    course: String,
    column: String,
    id: String,
    file: String,
) -> HomeworkFileDownloadResponse {
    download(
        with_session_read(|| async {
            bound(&expected)?
                .course_announcement_attachment_in(&course, &column, &id, &file)
                .await
        })
        .await,
    )
}

pub(super) async fn resources_at(
    expected: String,
    course: String,
    path: Vec<String>,
    page: u32,
    force: bool,
) -> CourseResourcePageResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            bound(&expected)?
                .course_resources_at(&course, &path, page, force)
                .await
        })
        .await,
    );
    CourseResourcePageResponse {
        data: data.map(resource_page_dto),
        failure,
    }
}

pub(super) async fn download_at(
    expected: String,
    course: String,
    path: Vec<String>,
    page: u32,
    id: String,
) -> HomeworkFileDownloadResponse {
    download(
        with_session_read(|| async {
            bound(&expected)?
                .course_resource_download_at(&course, &path, page, &id)
                .await
        })
        .await,
    )
}

fn resource_page_dto(page: ginkgo_core::application::CourseResourcePage) -> CourseResourcePageDto {
    CourseResourcePageDto {
        page: page.page,
        has_next: page.has_next,
        items: page
            .items
            .into_iter()
            .map(|item| CourseResourceDto {
                id: item.id,
                name: item.name,
                folder: item.folder,
                downloadable: item.downloadable,
                updated_at: item.updated_at,
                extension: item.extension,
            })
            .collect(),
    }
}

fn detail_dto(
    detail: ginkgo_core::application::CourseAnnouncementDetail,
) -> CourseAnnouncementDetailDto {
    CourseAnnouncementDetailDto {
        id: detail.id,
        title: detail.title,
        content: detail.content,
        attachments: detail
            .attachments
            .into_iter()
            .map(|a| LearningAttachmentDto {
                id: a.id,
                name: a.name,
            })
            .collect(),
    }
}

fn capability_dto(caps: ginkgo_core::application::LearningCapabilities) -> LearningCapabilitiesDto {
    fn state(
        value: ginkgo_core::application::LearningCapabilityState,
    ) -> LearningCapabilityStateDto {
        match value {
            ginkgo_core::application::LearningCapabilityState::Unknown => {
                LearningCapabilityStateDto::Unknown
            }
            ginkgo_core::application::LearningCapabilityState::Available => {
                LearningCapabilityStateDto::Available
            }
            ginkgo_core::application::LearningCapabilityState::AuthRequired => {
                LearningCapabilityStateDto::AuthRequired
            }
            ginkgo_core::application::LearningCapabilityState::TemporarilyUnavailable => {
                LearningCapabilityStateDto::TemporarilyUnavailable
            }
            ginkgo_core::application::LearningCapabilityState::ProtocolChanged => {
                LearningCapabilityStateDto::ProtocolChanged
            }
            ginkgo_core::application::LearningCapabilityState::AccessDenied => {
                LearningCapabilityStateDto::AccessDenied
            }
        }
    }
    LearningCapabilitiesDto {
        columns: state(caps.columns),
        announcements: state(caps.announcements),
        resources: state(caps.resources),
        assessments: state(caps.assessments),
        resource_download: state(caps.resource_download),
        announcement_download: state(caps.announcement_download),
    }
}

#[cfg(test)]
#[path = "learning_tests.rs"]
mod tests;
