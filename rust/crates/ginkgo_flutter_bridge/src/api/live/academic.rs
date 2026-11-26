//! Feature implementation behind the stable live API.
use super::*;

static SCHEDULE_READ_GATE: tokio::sync::Mutex<()> = tokio::sync::Mutex::const_new(());

/// Coalesces fast concurrent startup reads (`today` + default `schedule`) within
/// a short window so healthy requests share one cache fill, without letting a
/// stalled upstream lock both pages out for the full 45s read budget.
async fn try_coalesce_schedule() -> Option<tokio::sync::MutexGuard<'static, ()>> {
    tokio::time::timeout(std::time::Duration::from_secs(3), SCHEDULE_READ_GATE.lock())
        .await
        .ok()
}

pub(super) async fn load_schedule(
    term_id: Option<String>,
    week: Option<i32>,
    force_refresh: bool,
) -> ScheduleResponse {
    let Ok(service) = service() else {
        return schedule_failure(FailureCode::CredentialStore, None);
    };
    let share_cold_default = !force_refresh && term_id.is_none() && week.is_none();
    let input = ScheduleQueryInput {
        term_id,
        week,
        force_refresh,
    };
    match with_session_read(|| async {
        let _coalesce = if share_cold_default {
            try_coalesce_schedule().await
        } else {
            None
        };
        service.load_schedule(&input).await
    })
    .await
    {
        Ok(outcome) => schedule_response(outcome),
        Err(error) => schedule_failure(error.code.clone().into(), error.detail),
    }
}

pub(super) async fn load_today(force_refresh: bool) -> TodayResponse {
    let Ok(service) = service() else {
        return TodayResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match with_session_read(|| async {
        let _coalesce = if !force_refresh {
            try_coalesce_schedule().await
        } else {
            None
        };
        service.load_today(force_refresh).await
    })
    .await
    {
        Ok(outcome) => today_response(outcome),
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            TodayResponse {
                date: String::new(),
                courses: vec![],
                fetched_at: None,
                failure,
                failure_detail,
            }
        }
    }
}

pub(super) async fn load_checkin_today(force_refresh: bool) -> CheckInResponse {
    let Ok(service) = service() else {
        return checkin_failure(FailureCode::CredentialStore, None);
    };
    match with_module_read(ModuleAccess::CheckIn, || {
        service.load_checkin(force_refresh)
    })
    .await
    {
        Ok(outcome) => checkin_response(outcome),
        Err(error) => checkin_failure(error.code.clone().into(), error.detail),
    }
}

pub(super) async fn load_grade_terms() -> GradeTermsResponse {
    let service = match service() {
        Ok(service) => service,
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            return GradeTermsResponse {
                terms: vec![],
                failure,
                failure_detail,
            };
        }
    };
    match with_session_read(|| service.load_grade_terms()).await {
        Ok(terms) => GradeTermsResponse {
            terms: terms
                .into_iter()
                .map(|term| ScheduleTerm {
                    id: term.id,
                    name: term.name,
                    selected: term.selected,
                })
                .collect(),
            failure: None,
            failure_detail: None,
        },
        Err(error) => {
            let (failure, failure_detail) = failure(&error);
            GradeTermsResponse {
                terms: vec![],
                failure,
                failure_detail,
            }
        }
    }
}

pub(super) async fn load_grades(term_code: Option<String>, force_refresh: bool) -> GradeResponse {
    let Ok(service) = service() else {
        return grade_failure(FailureCode::CredentialStore, None);
    };
    match with_session_read(|| service.load_grades(term_code.as_deref(), force_refresh)).await {
        Ok(outcome) => grade_response(outcome),
        Err(error) => grade_failure(error.code.clone().into(), error.detail),
    }
}
