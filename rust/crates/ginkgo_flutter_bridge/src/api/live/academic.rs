//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_schedule(
    term_id: Option<String>,
    week: Option<i32>,
    force_refresh: bool,
) -> ScheduleResponse {
    let _access = SESSION_ACCESS.read().await;
    let Ok(service) = service() else {
        return schedule_failure(FailureCode::CredentialStore, None);
    };
    match bounded_read(service.load_schedule(&ScheduleQueryInput {
        term_id,
        week,
        force_refresh,
    }))
    .await
    {
        Ok(outcome) => schedule_response(outcome),
        Err(error) => schedule_failure(error.code.clone().into(), error.detail),
    }
}

pub(super) async fn load_today(force_refresh: bool) -> TodayResponse {
    let _access = SESSION_ACCESS.read().await;
    let Ok(service) = service() else {
        return TodayResponse {
            date: String::new(),
            courses: vec![],
            fetched_at: None,
            failure: Some(FailureCode::CredentialStore),
            failure_detail: None,
        };
    };
    match bounded_read(service.load_today(force_refresh)).await {
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
    let _access = SESSION_ACCESS.read().await;
    let _module = CHECKIN_ACCESS.read().await;
    let Ok(service) = service() else {
        return checkin_failure(FailureCode::CredentialStore, None);
    };
    match bounded_read(service.load_checkin(force_refresh)).await {
        Ok(outcome) => checkin_response(outcome),
        Err(error) => checkin_failure(error.code.clone().into(), error.detail),
    }
}

pub(super) async fn load_grade_terms() -> GradeTermsResponse {
    let _access = SESSION_ACCESS.read().await;
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
    match bounded_read(service.load_grade_terms()).await {
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
    let _access = SESSION_ACCESS.read().await;
    let Ok(service) = service() else {
        return grade_failure(FailureCode::CredentialStore, None);
    };
    match bounded_read(service.load_grades(term_code.as_deref(), force_refresh)).await {
        Ok(outcome) => grade_response(outcome),
        Err(error) => grade_failure(error.code.clone().into(), error.detail),
    }
}
