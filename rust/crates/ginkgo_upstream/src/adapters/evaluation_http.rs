//! API.md §6J read-only SPOC teaching evaluation status adapter (`spoc.buaa.edu.cn/pjxt`).
//!
//! Strictly read-only: physically omits `getQuestionnaireTopic` and `submitSaveEvaluation`.
use crate::{
    auth::{cas, session::Session},
    codecs::evaluation,
    foundation::{
        http::{HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError, ErrorCode,
};
use ginkgo_domain::features::evaluation::TeachingEvaluationReport;
use serde_json::Value;
use std::collections::HashSet;

pub const PJXT_ROOT: &str = "https://spoc.buaa.edu.cn/pjxt/";
pub const CAS_START: &str = "https://spoc.buaa.edu.cn/pjxt/cas";
pub const TASKS_URL: &str =
    "https://spoc.buaa.edu.cn/pjxt/personnelEvaluation/listObtainPersonnelEvaluationTasks";
pub const QUESTIONNAIRES_URL: &str =
    "https://spoc.buaa.edu.cn/pjxt/evaluationMethodSix/getQuestionnaireListToTask";
pub const REVIEWS_URL: &str =
    "https://spoc.buaa.edu.cn/pjxt/evaluationMethodSix/getRequiredReviewsData";

const RESPONSE_LIMIT: usize = 2 * 1024 * 1024;
const MAX_QUESTIONNAIRES: usize = 20;
const DESKTOP_UA: &str = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36 Edg/130.0.0.0";

fn is_gateway_login_url(raw: &str) -> bool {
    url::Url::parse(raw).is_ok_and(|url| {
        url.host_str()
            .is_some_and(|h| h.eq_ignore_ascii_case(webvpn::GATEWAY_HOST))
            && url.path().trim_end_matches('/').ends_with("/login")
    })
}

fn check_gateway_response(response: &HttpResponse) -> Result<(), AppError> {
    if is_gateway_login_url(&response.final_url) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    if matches!(response.status, 301 | 302 | 303 | 307 | 308) {
        if let Some(location) = response.header("location") {
            if is_gateway_login_url(location.trim()) {
                return Err(AppError::with_detail(
                    ErrorCode::AccessPolicyDenied,
                    "webvpn_login_required",
                ));
            }
        }
    }
    Ok(())
}

fn resolve_pjxt_redirect(location: &str, base: &str) -> Result<url::Url, AppError> {
    let resolved = webvpn::resolve_redirect(location, base).ok_or_else(AppError::changed)?;
    if is_gateway_login_url(&resolved) {
        return Err(AppError::with_detail(
            ErrorCode::AccessPolicyDenied,
            "webvpn_login_required",
        ));
    }
    let mut parsed = url::Url::parse(&resolved).map_err(|_| AppError::changed())?;
    if !parsed.username().is_empty() || parsed.password().is_some() {
        return Err(AppError::changed());
    }
    let valid_port = match parsed.scheme() {
        "https" => parsed.port_or_known_default() == Some(443),
        "http" => {
            matches!(
                parsed.host_str(),
                Some("spoc.buaa.edu.cn" | "sso.buaa.edu.cn")
            ) && parsed.port_or_known_default() == Some(80)
        }
        _ => false,
    };
    if !valid_port {
        return Err(AppError::changed());
    }
    let allowed = match parsed.host_str() {
        Some("sso.buaa.edu.cn") => parsed.path() == "/login",
        Some("spoc.buaa.edu.cn") => true,
        _ => false,
    };
    if !allowed {
        return Err(AppError::changed());
    }
    if parsed.scheme() == "http" {
        parsed
            .set_scheme("https")
            .map_err(|()| AppError::changed())?;
        parsed.set_port(None).map_err(|()| AppError::changed())?;
    }
    Ok(parsed)
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum BootstrapOutcome {
    Ready,
    NoEvaluationAccount,
}

pub(crate) async fn bootstrap<T: HttpTransport>(
    session: &Session<T>,
) -> Result<BootstrapOutcome, AppError> {
    let mut current = CAS_START.to_owned();
    let mut saw_cas_ticket = false;
    for _ in 0..10 {
        if current.contains("ticket=") {
            saw_cas_ticket = true;
        }
        let mut req = HttpRequest::get(&current)
            .header("User-Agent", DESKTOP_UA)
            .header("Accept", "text/html,application/xhtml+xml,*/*;q=0.8");
        req.response_limit = Some(RESPONSE_LIMIT);
        let resp = session.send_with_fallback(req).await?;
        check_gateway_response(&resp)?;
        if matches!(resp.status, 301 | 302 | 303 | 307 | 308) {
            let location = resp.header("location").ok_or_else(AppError::changed)?;
            let next = resolve_pjxt_redirect(location, &resp.final_url)?;
            if next.path() == "/pjxt/authentication/require" {
                return Ok(BootstrapOutcome::NoEvaluationAccount);
            }
            current = next.into();
            continue;
        }
        if resp.status == 401 {
            return Err(AppError::session_expired());
        }
        if resp.status == 403 {
            return Err(AppError::module_auth_required());
        }
        let landed = url::Url::parse(&resp.final_url).map_err(|_| AppError::changed())?;
        if landed.host_str() == Some("sso.buaa.edu.cn")
            || cas::is_login_redirect(&resp.final_url, &resp.body)
        {
            return Err(AppError::session_expired());
        }
        if landed.host_str() == Some("spoc.buaa.edu.cn")
            && (landed.path() == "/pjxt/authentication/require"
                || resp.body.contains("/pjxt/authentication/require")
                || (saw_cas_ticket && (500..600).contains(&resp.status)))
        {
            return Ok(BootstrapOutcome::NoEvaluationAccount);
        }
        if !matches!(resp.status, 200 | 404) {
            return Err(AppError::unavailable());
        }
        if landed.host_str() == Some("spoc.buaa.edu.cn") {
            return Ok(BootstrapOutcome::Ready);
        }
        return Err(AppError::changed());
    }
    Err(AppError::new(ErrorCode::RedirectLimit))
}

async fn pjxt_json_get<T: HttpTransport>(
    session: &Session<T>,
    url: &str,
) -> Result<Value, AppError> {
    let mut req = HttpRequest::get(url)
        .header("User-Agent", DESKTOP_UA)
        .header("Accept", "application/json, text/plain, */*");
    req.response_limit = Some(RESPONSE_LIMIT);
    let resp = session.send_with_fallback(req).await?;
    check_gateway_response(&resp)?;
    if matches!(resp.status, 301 | 302 | 303 | 307 | 308) || resp.status == 401 {
        if let Some(loc) = resp.header("location") {
            if loc.contains("/pjxt/authentication/require") {
                return Err(AppError::with_detail(
                    ErrorCode::ServiceUnavailable,
                    "pjxt_no_account",
                ));
            }
        }
        return Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "pjxt_login_required",
        ));
    }
    if resp.status == 403 {
        return Err(AppError::module_auth_required());
    }
    if resp.status != 200 {
        return Err(AppError::unavailable());
    }
    let final_url = url::Url::parse(&resp.final_url).map_err(|_| AppError::changed())?;
    if final_url.host_str() != Some("spoc.buaa.edu.cn")
        || cas::is_login_redirect(&resp.final_url, &resp.body)
    {
        return Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "pjxt_login_required",
        ));
    }
    serde_json::from_str(&resp.body).map_err(|_| AppError::changed())
}

pub(crate) async fn load<T: HttpTransport>(
    session: &Session<T>,
    account: &str,
    check_owner: impl Fn() -> Result<(), AppError>,
) -> Result<TeachingEvaluationReport, AppError> {
    let trimmed_account = account.trim();
    if trimmed_account.is_empty() {
        return Err(AppError::session_expired());
    }
    check_owner()?;
    if bootstrap(session).await? == BootstrapOutcome::NoEvaluationAccount {
        return Ok(TeachingEvaluationReport {
            task_id: None,
            task_name: None,
            term: None,
            courses: Vec::new(),
        });
    }
    check_owner()?;

    let mut tasks_url = url::Url::parse(TASKS_URL).map_err(|_| AppError::changed())?;
    tasks_url
        .query_pairs_mut()
        .append_pair("yhdm", trimmed_account)
        .append_pair("pageNum", "1")
        .append_pair("pageSize", "10");
    let tasks_res = pjxt_json_get(session, tasks_url.as_str())
        .await
        .and_then(|val| evaluation::parse_tasks(&val));
    let meta = match tasks_res {
        Ok(meta) => meta,
        Err(err) if err.detail.as_deref() == Some("pjxt_no_account") => {
            return Ok(TeachingEvaluationReport {
                task_id: None,
                task_name: None,
                term: None,
                courses: Vec::new(),
            });
        }
        Err(err) if err.code == ErrorCode::ServiceUnavailable => {
            check_owner()?;
            let mut session_tasks_url =
                url::Url::parse(TASKS_URL).map_err(|_| AppError::changed())?;
            session_tasks_url
                .query_pairs_mut()
                .append_pair("yhdm", "")
                .append_pair("pageNum", "1")
                .append_pair("pageSize", "10");
            match pjxt_json_get(session, session_tasks_url.as_str())
                .await
                .and_then(|val| evaluation::parse_tasks(&val))
            {
                Ok(meta) => meta,
                Err(e) if e.detail.as_deref() == Some("pjxt_no_account") => {
                    return Ok(TeachingEvaluationReport {
                        task_id: None,
                        task_name: None,
                        term: None,
                        courses: Vec::new(),
                    });
                }
                Err(e) => return Err(e),
            }
        }
        Err(err) => return Err(err),
    };
    check_owner()?;

    let Some(meta) = meta else {
        return Ok(TeachingEvaluationReport {
            task_id: None,
            task_name: None,
            term: None,
            courses: Vec::new(),
        });
    };

    let mut q_url = url::Url::parse(QUESTIONNAIRES_URL).map_err(|_| AppError::changed())?;
    q_url.query_pairs_mut().append_pair("rwid", &meta.task_id);
    let q_val = pjxt_json_get(session, q_url.as_str()).await?;
    check_owner()?;

    let questionnaires = evaluation::parse_questionnaires(&q_val)?;
    if questionnaires.len() > MAX_QUESTIONNAIRES {
        return Err(AppError::changed());
    }

    let mut courses = Vec::new();
    let mut seen_ids = HashSet::new();
    for q in &questionnaires {
        check_owner()?;
        let mut r_url = url::Url::parse(REVIEWS_URL).map_err(|_| AppError::changed())?;
        {
            let mut pairs = r_url.query_pairs_mut();
            pairs.append_pair("wjid", &q.id);
            if let Some(term) = meta.term.as_deref() {
                pairs.append_pair("xnxq", term);
            }
        }
        let batch_res = pjxt_json_get(session, r_url.as_str())
            .await
            .and_then(|val| evaluation::parse_required_reviews(&val, &q.id, q.name.as_deref()));
        let batch = match batch_res {
            Ok(items) if !items.is_empty() || meta.term.is_none() => items,
            _ => {
                check_owner()?;
                let mut plain_url =
                    url::Url::parse(REVIEWS_URL).map_err(|_| AppError::changed())?;
                plain_url.query_pairs_mut().append_pair("wjid", &q.id);
                let r_val = pjxt_json_get(session, plain_url.as_str()).await?;
                evaluation::parse_required_reviews(&r_val, &q.id, q.name.as_deref())?
            }
        };
        check_owner()?;
        for item in batch {
            if seen_ids.insert(item.id.clone()) {
                courses.push(item);
            }
        }
    }

    Ok(TeachingEvaluationReport {
        task_id: Some(meta.task_id),
        task_name: meta.task_name,
        term: meta.term,
        courses,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::MockTransport;
    use ginkgo_domain::features::evaluation::EvaluationCourseStatus;
    use serde_json::json;

    #[tokio::test]
    async fn follows_pjxt_cas_and_passes_mandatory_xnxq_to_required_reviews() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, CAS_START, "")
                .with_header("Location", "http://spoc.buaa.edu.cn/pjxt/cas?ticket=ST-9"),
            HttpResponse::new(404, "https://spoc.buaa.edu.cn/pjxt/cas?ticket=ST-9", "<html>spa route</html>"),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/pjxt/personnelEvaluation/listObtainPersonnelEvaluationTasks?yhdm=sy2501001&pageNum=1&pageSize=10",
                json!({
                    "code": "200",
                    "result": {
                        "list": [{
                            "rwid": "RW1",
                            "rwmc": "2026秋季评教",
                            "rwxnxq": "2026-20271"
                        }]
                    }
                })
                .to_string(),
            ),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/pjxt/evaluationMethodSix/getQuestionnaireListToTask?rwid=RW1",
                json!({
                    "code": "200",
                    "result": [{"wjid": "WJ1", "wjmc": "理论课"}]
                })
                .to_string(),
            ),
            HttpResponse::new(
                200,
                "https://spoc.buaa.edu.cn/pjxt/evaluationMethodSix/getRequiredReviewsData?wjid=WJ1&xnxq=2026-20271",
                json!({
                    "code": "200",
                    "result": [{
                        "rwid": "RW1",
                        "wjid": "WJ1",
                        "rwh": "1",
                        "kcdm": "C01",
                        "kcmc": "编译原理",
                        "bpdm": "T01",
                        "bpmc": "李文",
                        "ypjcs": 0
                    }]
                })
                .to_string(),
            ),
        ]);
        let session = Session::new(transport.clone());
        let report = load(&session, "sy2501001", || Ok(()))
            .await
            .expect("loaded");
        assert_eq!(report.term.as_deref(), Some("2026-20271"));
        assert_eq!(report.courses.len(), 1);
        assert_eq!(report.courses[0].status, EvaluationCourseStatus::Pending);

        let requests = transport.requests();
        assert!(requests[4].url.contains("xnxq=2026-20271"));
        for req in requests {
            assert_eq!(req.method, crate::foundation::http::HttpMethod::Get);
            assert!(req.header_value("X-Requested-With").is_none());
        }
    }

    #[tokio::test]
    async fn graduate_authentication_require_after_cas_ticket_returns_empty_report_not_error() {
        let transport = MockTransport::with_responses(vec![
            HttpResponse::new(302, CAS_START, "").with_header(
                "Location",
                "https://spoc.buaa.edu.cn/pjxt/cas?ticket=ST-grad",
            ),
            HttpResponse::new(302, "https://spoc.buaa.edu.cn/pjxt/cas?ticket=ST-grad", "")
                .with_header(
                    "Location",
                    "https://spoc.buaa.edu.cn/pjxt/authentication/require",
                ),
        ]);
        let session = Session::new(transport);
        let report = load(&session, "SY2501001", || Ok(()))
            .await
            .expect("empty evaluation report");
        assert!(report.task_id.is_none());
        assert!(report.courses.is_empty());
    }

    #[tokio::test]
    async fn pre_ticket_gateway_502_still_propagates_service_unavailable() {
        let transport =
            MockTransport::with_responses(vec![HttpResponse::new(502, CAS_START, "Bad Gateway")]);
        let session = Session::new(transport);
        let err = load(&session, "SY2501001", || Ok(())).await.unwrap_err();
        assert_eq!(err.code, ErrorCode::ServiceUnavailable);
    }
}
