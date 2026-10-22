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
            service
                .load_homework_detail(&assignment_id, force_refresh)
                .await
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
