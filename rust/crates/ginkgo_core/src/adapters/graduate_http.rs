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
    let execution = path.ends_with("zxbg/loadXspyfazxbgInfo.do");
    let rejected_code = value.get("code").is_some_and(|code| {
        let code = code
            .as_str()
            .map(str::to_owned)
            .unwrap_or_else(|| code.to_string());
        code != if execution { "1" } else { "0" }
    });
    if value["success"] == false || rejected_code {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    Ok(value)
}
async fn get<T: HttpTransport>(session: &Session<T>, path: &str) -> Result<Value, AppError> {
    let app = path.split('/').next().ok_or_else(AppError::invalid)?;
    let response = session
        .send_following_redirects(
            HttpRequest::get(format!("{BASE}/{path}"))
                .header("Referer", &format!("{BASE}/{app}/*default/index.do")),
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
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}
pub async fn load_status<T: HttpTransport>(
    session: &Session<T>,
    account: &str,
) -> Result<AcademicData, AppError> {
    activate(session, "wdxjappbuaa").await?;
    let form = account_form(account);
    let status = post(session, "wdxjappbuaa/modules/wdxj/xsjcxxcx.do", &form).await?;
    Ok(AcademicData {
        sections: vec![graduate::parse_status(&status)?],
        notice: None,
    })
}

fn account_form(account: &str) -> String {
    url::form_urlencoded::Serializer::new(String::new())
        .append_pair("XH", account)
        .finish()
}

async fn activate<T: HttpTransport>(session: &Session<T>, app: &str) -> Result<(), AppError> {
    let response = session
        .send_following_redirects(HttpRequest::get(format!("{BASE}/{app}/*default/index.do")))
        .await?;
    if matches!(response.status, 401 | 403)
        || cas::is_login_redirect(&response.final_url, &response.body)
    {
        return Err(AppError::session_expired());
    }
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    Ok(())
}

pub async fn load_report<T: HttpTransport>(
    session: &Session<T>,
    account: &str,
) -> Result<AcademicData, AppError> {
    activate(session, "wdpyfazxbgappbuaa").await?;
    let form = account_form(account);
    let mut sections = Vec::new();
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

/// API.md §7.4 / EDUCATION-DATA-MAP §4.2; native loadPlan:87–154.
/// Kept independent of the execution report so chapters never delay first paint.
pub async fn load_plan<T: HttpTransport>(
    session: &Session<T>,
    account: &str,
) -> Result<AcademicData, AppError> {
    activate(session, "wdpyfaappbuaa").await?;
    let mapping = post(
        session,
        "wdpyfaappbuaa/modules/pyfaxq/gjxhcxdyfadm.do",
        &account_form(account),
    )
    .await?;
    let rows = mapping["datas"]["gjxhcxdyfadm"]["rows"]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let Some(row) = rows.first() else {
        return Ok(AcademicData {
            sections: vec![],
            notice: None,
        });
    };
    let code = row["FADM"]
        .as_str()
        .filter(|code| !code.trim().is_empty())
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
    let query = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("DM", code)
        .finish();
    let chapters = get(
        session,
        &format!("wdpyfaappbuaa/modules/pyfaxq/gjfadmhqdydpyfanr.do?{query}"),
    )
    .await?;
    let setting = serde_json::json!([{"name":"FADM","value":code}]).to_string();
    let form = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("setting", &setting)
        .finish();
    let pool = post(session, "wdpyfaappbuaa/modules/pyfaxq/pyfakcxxcx.do", &form).await?;
    Ok(AcademicData {
        sections: graduate::parse_full_plan(&header, &chapters, &pool)?,
        notice: None,
    })
}
