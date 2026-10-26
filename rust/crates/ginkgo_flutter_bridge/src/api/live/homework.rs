//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_homework(force_refresh: bool) -> crate::api::mirror::HomeworkResponse {
    let _access = SESSION_ACCESS.read().await;
    use crate::api::mirror::{HomeworkItem, HomeworkResponse, HomeworkStatus};
    let result = match service() {
        Ok(service) => bounded_read(service.load_homework(force_refresh)).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => HomeworkResponse {
            term_name: outcome.data.term_name,
            term_code: outcome.data.term_code,
            items: outcome
                .data
                .items
                .into_iter()
                .map(|item| HomeworkItem {
                    course_role: item.course_role,
                    id: item.id,
                    course_id: item.course_id,
                    course_name: item.course_name,
                    teacher_name: item.teacher_name,
                    title: item.title,
                    published_at: item.published_at,
                    due_at: item.due_at,
                    status: match item.status {
                        ginkgo_core::features::homework::HomeworkStatus::Pending => {
                            HomeworkStatus::Pending
                        }
                        ginkgo_core::features::homework::HomeworkStatus::Submitted => {
                            HomeworkStatus::Submitted
                        }
                        ginkgo_core::features::homework::HomeworkStatus::Unknown => {
                            HomeworkStatus::Unknown
                        }
                    },
                    status_detail: item.status_detail,
                    score: item.score,
                })
                .collect(),
            failure_detail: None,
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => HomeworkResponse {
            term_name: String::new(),
            term_code: String::new(),
            items: vec![],
            failure_detail: None,
            failure: Some(error.code.into()),
        },
    }
}

pub(super) async fn load_homework_detail(
    assignment_id: String,
    force_refresh: bool,
) -> HomeworkDetailResponse {
    let _access = SESSION_ACCESS.read().await;
    let result = match service() {
        Ok(service) => {
            bounded_read(service.load_homework_detail(&assignment_id, force_refresh)).await
        }
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => HomeworkDetailResponse {
            source_url: outcome.data.source_url,
            content: outcome.data.content,
            published_at: outcome.data.published_at,
            due_at: outcome.data.due_at,
            score: outcome.data.score,
            submitted_at: outcome.data.submitted_at,
            status: match outcome.data.status {
                ginkgo_core::features::homework::HomeworkStatus::Pending => "待完成".into(),
                ginkgo_core::features::homework::HomeworkStatus::Submitted => "已提交".into(),
                ginkgo_core::features::homework::HomeworkStatus::Unknown => "待确认".into(),
            },
            stale: outcome.failure.is_some(),
            failure: outcome.failure.map(|e| e.code.into()),
        },
        Err(error) => HomeworkDetailResponse {
            source_url: None,
            content: None,
            published_at: None,
            due_at: None,
            score: None,
            submitted_at: None,
            status: "待确认".into(),
            stale: false,
            failure: Some(error.code.into()),
        },
    }
}

static FILE_WRITE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());
fn bound_service(expected: &str) -> Result<&'static LiveService, AppError> {
    let service = service()?;
    if expected.trim().is_empty() || service.status().account.as_deref() != Some(expected) {
        return Err(AppError::session_expired());
    }
    Ok(service)
}
fn file_response<T: serde::Serialize>(result: Result<T, AppError>) -> ReadOnlyResponse {
    match result {
        Ok(value) => ReadOnlyResponse {
            payload: serde_json::to_string(&value).ok(),
            stale: false,
            failure: None,
        },
        Err(error) => ReadOnlyResponse {
            payload: None,
            stale: false,
            failure: Some(error.code.into()),
        },
    }
}
pub(super) async fn file_workspace(expected: String, id: String) -> ReadOnlyResponse {
    let _session = SESSION_ACCESS.read().await;
    file_response(match bound_service(&expected) {
        Ok(s) => bounded_read(s.homework_workspace(&id)).await,
        Err(e) => Err(e),
    })
}
pub(super) async fn upload_file(
    expected: String,
    id: String,
    name: String,
    bytes: Vec<u8>,
) -> ReadOnlyResponse {
    let Ok(_write) = FILE_WRITE.try_lock() else {
        return file_response::<u8>(Err(AppError::invalid()));
    };
    let _session = SESSION_ACCESS.read().await;
    let result = async {
        let s = bound_service(&expected)?;
        tokio::time::timeout(
            std::time::Duration::from_secs(180),
            s.upload_homework_file(&id, &name, bytes),
        )
        .await
        .map_err(|_| AppError::unavailable())?
    }
    .await;
    file_response(result)
}
pub(super) async fn submit_file(
    expected: String,
    handle: String,
    confirmed: bool,
    reconcile: bool,
) -> MutationResponse {
    let Ok(_write) = FILE_WRITE.try_lock() else {
        return MutationResponse {
            state: "notSubmitted".into(),
            message: "作业操作处理中，请勿重复提交".into(),
        };
    };
    let _session = SESSION_ACCESS.read().await;
    let Ok(s) = bound_service(&expected) else {
        return MutationResponse {
            state: "notSubmitted".into(),
            message: "账号已变化，未提交".into(),
        };
    };
    let outcome = if reconcile {
        bounded_submit(s.reconcile_homework_file(&handle)).await
    } else {
        bounded_submit(s.submit_homework_file(&handle, confirmed)).await
    };
    mutation_response(
        outcome.unwrap_or_else(ginkgo_core::features::mutation::MutationOutcome::uncertain),
    )
}
pub(super) async fn download_file(
    expected: String,
    id: String,
    attachment: String,
) -> HomeworkFileDownloadResponse {
    let _session = SESSION_ACCESS.read().await;
    let result = async {
        let s = bound_service(&expected)?;
        bounded_read(s.download_homework_file(&id, &attachment)).await
    }
    .await;
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

pub(super) async fn configure_recovery(expected: String, root: String) -> ReadOnlyResponse {
    let _write = FILE_WRITE.lock().await;
    let _session = SESSION_ACCESS.read().await;
    file_response(bound_service(&expected).and_then(|s| s.configure_homework_recovery(&root)))
}
pub(super) async fn pending_submissions(
    expected: String,
    assignment: Option<String>,
) -> ReadOnlyResponse {
    let _session = SESSION_ACCESS.read().await;
    file_response(
        async {
            let mut items =
                bounded_read(bound_service(&expected)?.pending_homework_submissions()).await?;
            if let Some(id) = assignment {
                items.retain(|item| item.assignment_id == id);
            }
            Ok(items)
        }
        .await,
    )
}
pub(super) async fn capabilities(expected: String, id: String) -> ReadOnlyResponse {
    let _session = SESSION_ACCESS.read().await;
    file_response(
        async {
            bounded_read(async { Ok(bound_service(&expected)?.homework_capabilities(&id).await) })
                .await
        }
        .await,
    )
}
