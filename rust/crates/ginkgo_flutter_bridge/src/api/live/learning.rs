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
fn response<T: serde::Serialize>(
    result: Result<ginkgo_core::application::DataOutcome<T>, AppError>,
) -> ReadOnlyResponse {
    match result {
        Ok(v) => ReadOnlyResponse {
            payload: serde_json::to_string(&v.data).ok(),
            stale: v.failure.is_some(),
            failure: v.failure.map(|e| e.code.into()),
        },
        Err(e) => ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(e.code.into()),
        },
    }
}
pub(super) async fn courses(expected: String, force: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(async { bounded_read(bound(&expected)?.learning_courses(force)).await }.await)
}
pub(super) async fn announcements(
    expected: String,
    course: String,
    force: bool,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async { bounded_read(bound(&expected)?.course_announcements(&course, force)).await }.await,
    )
}
pub(super) async fn resources(
    expected: String,
    course: String,
    folder: Option<String>,
    page: u32,
    force: bool,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async {
            bounded_read(bound(&expected)?.course_resources(
                &course,
                folder.as_deref(),
                page,
                force,
            ))
            .await
        }
        .await,
    )
}
pub(super) async fn assessments(expected: String, course: String, force: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async { bounded_read(bound(&expected)?.course_assessments(&course, force)).await }.await,
    )
}
pub(super) async fn announcement_detail(
    expected: String,
    course: String,
    id: String,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = async {
        let data = bounded_read(bound(&expected)?.course_announcement_detail(&course, &id)).await?;
        Ok(ginkgo_core::application::DataOutcome {
            data,
            failure: None,
        })
    }
    .await;
    response(result)
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
    let _access = SESSION_ACCESS.read().await;
    download(
        async {
            bounded_read(bound(&expected)?.course_resource_download(
                &course,
                folder.as_deref(),
                page,
                &id,
            ))
            .await
        }
        .await,
    )
}
pub(super) async fn announcement_attachment(
    expected: String,
    course: String,
    id: String,
    file: String,
) -> HomeworkFileDownloadResponse {
    let _access = SESSION_ACCESS.read().await;
    download(
        async {
            bounded_read(bound(&expected)?.course_announcement_attachment(&course, &id, &file))
                .await
        }
        .await,
    )
}

#[cfg(test)]
#[path = "learning_tests.rs"]
mod tests;

pub(super) async fn columns(expected: String, course: String, force: bool) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async { bounded_read(bound(&expected)?.course_learning_columns(&course, force)).await }
            .await,
    )
}
pub(super) async fn capabilities(expected: String, course: String) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async {
            let data =
                bounded_read(bound(&expected)?.course_learning_capabilities(&course)).await?;
            Ok(ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            })
        }
        .await,
    )
}
pub(super) async fn announcements_in(
    expected: String,
    course: String,
    column: String,
    force: bool,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async {
            bounded_read(bound(&expected)?.course_announcements_in(&course, &column, force)).await
        }
        .await,
    )
}
pub(super) async fn assessments_in(
    expected: String,
    course: String,
    column: String,
    force: bool,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async {
            bounded_read(bound(&expected)?.course_assessments_in(&course, &column, force)).await
        }
        .await,
    )
}
pub(super) async fn detail_in(
    expected: String,
    course: String,
    column: String,
    id: String,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async {
            let data = bounded_read(
                bound(&expected)?.course_announcement_detail_in(&course, &column, &id),
            )
            .await?;
            Ok(ginkgo_core::application::DataOutcome {
                data,
                failure: None,
            })
        }
        .await,
    )
}
pub(super) async fn attachment_in(
    expected: String,
    course: String,
    column: String,
    id: String,
    file: String,
) -> HomeworkFileDownloadResponse {
    let _access = SESSION_ACCESS.read().await;
    download(
        async {
            bounded_read(
                bound(&expected)?.course_announcement_attachment_in(&course, &column, &id, &file),
            )
            .await
        }
        .await,
    )
}
pub(super) async fn resources_at(
    expected: String,
    course: String,
    path: Vec<String>,
    page: u32,
    force: bool,
) -> ReadOnlyResponse {
    let _access = SESSION_ACCESS.read().await;
    response(
        async {
            bounded_read(bound(&expected)?.course_resources_at(&course, &path, page, force)).await
        }
        .await,
    )
}
pub(super) async fn download_at(
    expected: String,
    course: String,
    path: Vec<String>,
    page: u32,
    id: String,
) -> HomeworkFileDownloadResponse {
    let _access = SESSION_ACCESS.read().await;
    download(
        async {
            bounded_read(bound(&expected)?.course_resource_download_at(&course, &path, page, &id))
                .await
        }
        .await,
    )
}
