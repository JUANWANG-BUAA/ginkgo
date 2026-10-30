//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_homework(force_refresh: bool) -> crate::api::mirror::HomeworkResponse {
    use crate::api::mirror::{HomeworkItem, HomeworkResponse, HomeworkStatus};
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_homework(force_refresh)).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(outcome) => HomeworkResponse {
            fetched_at: Some(outcome.fetched_at),
            roles_complete: Some(outcome.data.roles_complete),
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
            fetched_at: None,
            roles_complete: None,
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
    let result = match service() {
        Ok(service) => {
            with_session_read(|| service.load_homework_detail(&assignment_id, force_refresh)).await
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
fn outcome<T>(result: Result<T, AppError>) -> (Option<T>, Option<FailureCode>) {
    match result {
        Ok(value) => (Some(value), None),
        Err(error) => (None, Some(error.code.into())),
    }
}

fn workspace_dto(workspace: ginkgo_core::application::HomeworkWorkspace) -> HomeworkWorkspaceDto {
    HomeworkWorkspaceDto {
        assignment_id: workspace.assignment_id,
        allowed_methods: workspace.allowed_methods,
        allowed_extensions: workspace.allowed_extensions,
        submission_limit: workspace.submission_limit,
        submitted_count: workspace.submitted_count,
        returned: workspace.returned,
        submitted_text: workspace.submitted_text,
        feedback: workspace.feedback,
        attachments: workspace
            .attachments
            .into_iter()
            .map(|a| HomeworkAttachmentDto {
                id: a.id,
                name: a.name,
                kind: a.kind,
            })
            .collect(),
        can_submit_file: workspace.can_submit_file,
        blocked_reason: workspace.blocked_reason,
        // The 20 MB cap upstream guarantees the widening is lossless.
        file_limit_bytes: i64::try_from(workspace.file_limit_bytes).unwrap_or(i64::MAX),
    }
}

fn capability_dto(
    evidence: ginkgo_core::application::HomeworkCapabilityEvidence,
) -> HomeworkCapabilityEvidenceDto {
    HomeworkCapabilityEvidenceDto {
        capability: evidence.capability,
        state: match evidence.state {
            ginkgo_core::application::HomeworkCapabilityState::Available => {
                HomeworkCapabilityStateDto::Available
            }
            ginkgo_core::application::HomeworkCapabilityState::Unknown => {
                HomeworkCapabilityStateDto::Unknown
            }
            ginkgo_core::application::HomeworkCapabilityState::Unsupported => {
                HomeworkCapabilityStateDto::Unsupported
            }
            ginkgo_core::application::HomeworkCapabilityState::ProtocolChanged => {
                HomeworkCapabilityStateDto::ProtocolChanged
            }
            ginkgo_core::application::HomeworkCapabilityState::TempUnavailable => {
                HomeworkCapabilityStateDto::TempUnavailable
            }
            ginkgo_core::application::HomeworkCapabilityState::AuthRequired => {
                HomeworkCapabilityStateDto::AuthRequired
            }
        },
        reason: evidence.reason,
        evidence: evidence.evidence,
    }
}
pub(super) async fn file_workspace(expected: String, id: String) -> HomeworkFileWorkspaceResponse {
    file_workspace_response(
        with_session_read(|| async {
            let s = bound_service(&expected)?;
            s.homework_workspace(&id).await
        })
        .await,
    )
}

fn file_workspace_response(
    result: Result<ginkgo_core::application::HomeworkWorkspace, AppError>,
) -> HomeworkFileWorkspaceResponse {
    let (data, failure) = outcome(result);
    HomeworkFileWorkspaceResponse {
        data: data.map(workspace_dto),
        failure,
    }
}
pub(super) async fn upload_file(
    expected: String,
    id: String,
    name: String,
    bytes: Vec<u8>,
) -> HomeworkUploadResponse {
    let Ok(_write) = FILE_WRITE.try_lock() else {
        // A second upload while one is in flight is a local backstop.
        return HomeworkUploadResponse {
            data: None,
            failure: Some(FailureCode::InvalidRequest),
        };
    };
    upload_response(
        with_session_read_in(std::time::Duration::from_secs(180), || async {
            let s = bound_service(&expected)?;
            s.upload_homework_file(&id, &name, bytes).await
        })
        .await,
    )
}

fn upload_response(
    result: Result<ginkgo_core::application::HomeworkUploadReceipt, AppError>,
) -> HomeworkUploadResponse {
    let (data, failure) = outcome(result);
    HomeworkUploadResponse {
        data: data.map(|receipt| HomeworkUploadReceiptDto {
            handle: receipt.handle,
            file_name: receipt.file_name,
            // The 20 MB cap upstream guarantees the widening is lossless.
            size: i64::try_from(receipt.size).unwrap_or(i64::MAX),
        }),
        failure,
    }
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
    let outcome = with_session_submit(|| async {
        match bound_service(&expected) {
            Ok(s) => {
                if reconcile {
                    s.reconcile_homework_file(&handle).await
                } else {
                    s.submit_homework_file(&handle, confirmed).await
                }
            }
            Err(_) => ginkgo_core::features::mutation::MutationOutcome::not_submitted(
                "账号已变化，未提交",
            ),
        }
    })
    .await;
    mutation_response(
        outcome.unwrap_or_else(ginkgo_core::features::mutation::MutationOutcome::uncertain),
    )
}
pub(super) async fn download_file(
    expected: String,
    id: String,
    attachment: String,
) -> HomeworkFileDownloadResponse {
    let result = with_session_read(|| async {
        let s = bound_service(&expected)?;
        s.download_homework_file(&id, &attachment).await
    })
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

pub(super) async fn configure_recovery(expected: String, root: String) -> HomeworkRecoveryResponse {
    let _write = FILE_WRITE.lock().await;
    let (data, failure) = outcome(
        with_session_read(|| async {
            let s = bound_service(&expected)?;
            s.configure_homework_recovery(&root)
        })
        .await,
    );
    HomeworkRecoveryResponse {
        configured: data.map(|()| true),
        failure,
    }
}
pub(super) async fn pending_submissions(
    expected: String,
    assignment: Option<String>,
) -> HomeworkPendingResponse {
    let (data, failure) = outcome(
        with_session_read(|| async {
            let s = bound_service(&expected)?;
            let mut items = s.pending_homework_submissions().await?;
            if let Some(id) = assignment {
                items.retain(|item| item.assignment_id == id);
            }
            Ok(items)
        })
        .await,
    );
    HomeworkPendingResponse {
        data: data.map(|items| {
            items
                .into_iter()
                .map(|item| HomeworkPendingSubmissionDto {
                    handle: item.handle,
                    assignment_id: item.assignment_id,
                    file_name: item.file_name,
                    size: i64::try_from(item.size).unwrap_or(i64::MAX),
                })
                .collect()
        }),
        failure,
    }
}
pub(super) async fn capabilities(expected: String, id: String) -> HomeworkCapabilitiesResponse {
    capabilities_response(
        with_session_read(|| async {
            let s = bound_service(&expected)?;
            Ok(s.homework_capabilities(&id).await)
        })
        .await,
    )
}

fn capabilities_response(
    result: Result<Vec<ginkgo_core::application::HomeworkCapabilityEvidence>, AppError>,
) -> HomeworkCapabilitiesResponse {
    let (data, failure) = outcome(result);
    HomeworkCapabilitiesResponse {
        data: data.map(|rows| rows.into_iter().map(capability_dto).collect()),
        failure,
    }
}

#[cfg(test)]
mod homework_file_tests {
    use super::*;

    #[test]
    fn workspace_keeps_undisclosed_counts_absent_and_attachments_typed() {
        use ginkgo_core::application::{
            HomeworkAttachment, HomeworkCapabilityEvidence, HomeworkCapabilityState,
            HomeworkWorkspace,
        };
        let response = file_workspace_response(Ok(HomeworkWorkspace {
            assignment_id: "syn-1".into(),
            allowed_methods: vec!["file".into()],
            allowed_extensions: vec!["pdf".into()],
            submission_limit: None,
            submitted_count: None,
            returned: false,
            submitted_text: None,
            feedback: None,
            attachments: vec![HomeworkAttachment {
                id: "teacher".into(),
                name: "合成作业要求.txt".into(),
                kind: "teacher".into(),
            }],
            can_submit_file: true,
            blocked_reason: None,
            file_limit_bytes: 20 * 1024 * 1024,
        }))
        .data
        .expect("workspace");
        assert_eq!(response.assignment_id, "syn-1");
        assert_eq!(response.allowed_methods, vec!["file".to_string()]);
        // The school stayed silent on limits and counts: absent, not zero.
        assert!(response.submission_limit.is_none());
        assert!(response.submitted_count.is_none());
        assert_eq!(response.attachments[0].name, "合成作业要求.txt");
        assert!(response.can_submit_file);

        // Capability evidence keeps its diagnostic wording verbatim.
        let capabilities = capabilities_response(Ok(vec![HomeworkCapabilityEvidence {
            capability: "fileSubmit".into(),
            state: HomeworkCapabilityState::Unknown,
            reason: "此适配器未提供作业能力诊断".into(),
            evidence: "adapterNotProvided".into(),
        }]))
        .data
        .expect("capabilities");
        let evidence = &capabilities[0];
        assert_eq!(evidence.reason, "此适配器未提供作业能力诊断");
        assert_eq!(evidence.evidence, "adapterNotProvided");
    }

    #[test]
    fn upload_receipt_crosses_with_a_lossless_size() {
        use ginkgo_core::application::HomeworkUploadReceipt;
        let response = upload_response(Ok(HomeworkUploadReceipt {
            handle: "handle-1".into(),
            file_name: "合成.pdf".into(),
            size: 20 * 1024 * 1024,
        }))
        .data
        .expect("receipt");
        assert_eq!(
            (&*response.handle, &*response.file_name),
            ("handle-1", "合成.pdf")
        );
        assert_eq!(response.size, 20 * 1024 * 1024);
    }
}
