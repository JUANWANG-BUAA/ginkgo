//! API.md §7.4 / GraduateAcademicClient.swift, whitelist projection only.
use crate::{
    auth::{cas, session::Session},
    features::graduate::{self, AcademicData},
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
use serde_json::Value;
const BASE: &str = "https://gsmis.buaa.edu.cn/gsapp/sys";
async fn post<T: HttpTransport>(
    session: &Session<T>,
    path: &str,
    form: &str,
) -> Result<Value, AppError> {
    let app = path.split('/').next().ok_or_else(AppError::invalid)?;
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(format!("{BASE}/{path}"), form)
                .header("Referer", &format!("{BASE}/{app}/*default/index.do"))
                .header("X-Requested-With", "XMLHttpRequest"),
        )
        .await?;
    if matches!(response.status, 401 | 403)
        || cas::is_login_redirect(&response.final_url, &response.body)
    {
        return Err(AppError::session_expired());
    }
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    let value: Value = serde_json::from_str(&response.body).map_err(|_| AppError::changed())?;
    if value["success"] == false {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    Ok(value)
}
async fn get<T: HttpTransport>(session: &Session<T>, path: &str) -> Result<Value, AppError> {
    let response = session
        .send_following_redirects(HttpRequest::get(format!("{BASE}/{path}")))
        .await?;
    if cas::is_login_redirect(&response.final_url, &response.body) {
        return Err(AppError::session_expired());
    }
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}
pub async fn load<T: HttpTransport>(
    session: &Session<T>,
    account: &str,
) -> Result<AcademicData, AppError> {
    for app in ["wdxjappbuaa", "wdpyfazxbgappbuaa"] {
        session
            .send_following_redirects(HttpRequest::get(format!("{BASE}/{app}/*default/index.do")))
            .await?;
    }
    let form = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("XH", account)
        .finish();
    let status = post(session, "wdxjappbuaa/modules/wdxj/xsjcxxcx.do", &form).await?;
    let mut sections = vec![graduate::parse_status(&status)?];
    let execution = post(
        session,
        "wdpyfazxbgappbuaa/zxbg/loadXspyfazxbgInfo.do",
        "isShowSszxbg=0",
    )
    .await
    .and_then(|v| graduate::parse_execution(&v));
    let mut notice = None;
    match execution {
        Ok(report) => sections.extend(report),
        Err(error) if error.code == ErrorCode::SessionExpired => return Err(error),
        Err(_) => {
            notice =
                Some("执行报告暂不可用，以下仅显示方案头部与计划课程池，不推断类别学分。".into());
            session
                .send_following_redirects(HttpRequest::get(format!(
                    "{BASE}/wdpyfaappbuaa/*default/index.do"
                )))
                .await?;
            let mapping = post(
                session,
                "wdpyfaappbuaa/modules/pyfaxq/gjxhcxdyfadm.do",
                &form,
            )
            .await?;
            let code = mapping["datas"]["gjxhcxdyfadm"]["rows"]
                .as_array()
                .and_then(|r| r.first())
                .and_then(|r| r["FADM"].as_str())
                .ok_or_else(AppError::changed)?;
            let query = url::form_urlencoded::Serializer::new(String::new())
                .append_pair("DM", code)
                .append_pair("EN", "zh")
                .finish();
            let header = get(
                session,
                &format!("wdpyfaappbuaa/modules/pyfaxq/facx.do?{query}"),
            )
            .await?;
            let setting = serde_json::json!([{"name":"FADM","value":code}]).to_string();
            let form = url::form_urlencoded::Serializer::new(String::new())
                .append_pair("setting", &setting)
                .finish();
            let pool = post(session, "wdpyfaappbuaa/modules/pyfaxq/pyfakcxxcx.do", &form).await?;
            sections.extend(graduate::parse_plan(&header, &pool)?);
        }
    }
    Ok(AcademicData { sections, notice })
}
