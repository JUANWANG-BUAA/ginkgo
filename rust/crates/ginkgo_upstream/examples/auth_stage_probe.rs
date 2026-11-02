//! Explicit, single-submit CAS/UC diagnosis. Output is restricted to metadata.
//! Never prints URLs, form values, cookies, profiles, or free-form error text.
use ginkgo_upstream::{
    adapters::reqwest_transport::ReqwestTransport,
    auth::{
        self, cas,
        session::{RouteMode, Session},
        Credentials, LoginPage, LoginResult,
    },
    foundation::{
        http::{HttpRequest, HttpResponse, HttpTransport, TransportError},
        webvpn,
    },
};
use serde_json::{json, Value};
use std::{
    io::{self, BufRead, IsTerminal, Write},
    path::PathBuf,
    time::{Duration, Instant},
};

fn hints(text: &str) -> Vec<&'static str> {
    [
        ("username", "用户名"),
        ("account", "账号"),
        ("account_alt", "账户"),
        ("password", "密码"),
        ("captcha", "验证码"),
        ("incorrect", "错误"),
        ("incorrect_alt", "有误"),
        ("incorrect_other", "不正确"),
        ("expired", "过期"),
        ("invalid", "失效"),
        ("locked", "锁定"),
        ("frequency", "频繁"),
        ("attempt_count", "次数"),
        ("security", "安全"),
        ("policy", "策略"),
        ("denied", "禁止"),
        ("failed", "失败"),
        ("not_found", "不存在"),
        ("verify", "校验"),
        ("binding", "绑定"),
    ]
    .into_iter()
    .filter_map(|(tag, word)| text.contains(word).then_some(tag))
    .chain(english_hints(text))
    .collect()
}

fn english_hints(text: &str) -> Vec<&'static str> {
    let words: Vec<_> = text
        .split(|c: char| !c.is_ascii_alphanumeric())
        .filter(|word| !word.is_empty())
        .map(str::to_ascii_lowercase)
        .collect();
    [
        ("en_invalid", "invalid"),
        ("en_credentials", "credentials"),
        ("en_authentication", "authentication"),
        ("en_failed", "failed"),
        ("en_password", "password"),
        ("en_username", "username"),
        ("en_captcha", "captcha"),
        ("en_error", "error"),
        ("en_expired", "expired"),
        ("en_locked", "locked"),
        ("en_denied", "denied"),
        ("en_unauthorized", "unauthorized"),
        ("en_execution", "execution"),
        ("en_flow", "flow"),
        ("en_session", "session"),
        ("en_decode", "decode"),
        ("en_decrypt", "decrypt"),
        ("en_csrf", "csrf"),
        ("en_required", "required"),
        ("en_missing", "missing"),
        ("en_blocked", "blocked"),
        ("en_disabled", "disabled"),
        ("en_request", "request"),
        ("en_malformed", "malformed"),
        ("en_risky", "risky"),
        ("en_account", "account"),
        ("en_unknown", "unknown"),
        ("en_exception", "exception"),
    ]
    .into_iter()
    .filter_map(|(tag, word)| words.iter().any(|actual| actual == word).then_some(tag))
    .collect()
}

fn role(raw: &str) -> &'static str {
    let logical = webvpn::unwrap(raw);
    let Ok(url) = url::Url::parse(&logical) else {
        return "invalid";
    };
    match (url.host_str().unwrap_or_default(), url.path()) {
        ("sso.buaa.edu.cn", "/login") => "cas_login",
        ("sso.buaa.edu.cn", "/captcha") => "cas_captcha",
        ("d.buaa.edu.cn", "/login") => "gateway_login",
        ("d.buaa.edu.cn", _) => "gateway",
        ("uc.buaa.edu.cn", "/api/uc/status") => "uc_status",
        ("uc.buaa.edu.cn", _) => "uc_activation",
        _ => "other",
    }
}

fn response_metadata(response: &HttpResponse) -> Value {
    let tip = cas::extract_error_text(&response.body);
    let next = response.header("location").and_then(|location| {
        url::Url::parse(&response.final_url)
            .ok()?
            .join(location)
            .ok()
    });
    json!({
        "status": response.status,
        "next": next.as_ref().map(|url| role(url.as_str())),
        "execution": cas::extract_execution(&response.body).is_some(),
        "captcha": cas::detect_captcha(&response.body).is_some(),
        "error_present": tip.is_some(),
        "error_hints": hints(tip.as_deref().unwrap_or_default()),
        "unclassified_tip": tip.as_deref().is_some_and(|text| hints(text).is_empty()),
        "set_cookie_count": response.set_cookies.len(),
    })
}

struct Trace(ReqwestTransport);
impl HttpTransport for Trace {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        let stage = role(&request.url);
        let method = match request.method {
            ginkgo_upstream::foundation::http::HttpMethod::Get => "GET",
            _ => "POST",
        };
        let cookie = request.header_value("cookie").is_some();
        let start = Instant::now();
        let result = self.0.send(request).await;
        let outcome = match &result {
            Ok(response) => response_metadata(response),
            Err(TransportError::Unreachable) => json!({"transport": "unreachable"}),
            Err(TransportError::Unavailable) => json!({"transport": "unavailable"}),
        };
        println!(
            "{}",
            json!({"stage":stage,"method":method,"cookie":cookie,"ms":start.elapsed().as_millis(),"outcome":outcome})
        );
        result
    }
}

/// Compare values in memory using synthetic credentials, not real inputs.
fn captcha_form_matches_ubaa(html: &str, execution: &str) -> bool {
    let mut actual = cas::login_fields(
        html,
        "synthetic-user",
        "synthetic-password",
        Some("synthetic-answer"),
    );
    actual.retain(|(key, _)| key != "execution");
    actual.push(("execution".into(), execution.into()));
    let mut expected: Vec<(String, String)> = [
        ("username", "synthetic-user"),
        ("password", "synthetic-password"),
        ("captcha", "synthetic-answer"),
        ("captchaResponse", "synthetic-answer"),
        ("execution", execution),
        ("_eventId", "submit"),
        ("submit", "登录"),
        ("type", "username_password"),
    ]
    .into_iter()
    .map(|(key, value)| (key.into(), value.into()))
    .collect();
    actual.sort();
    expected.sort();
    actual == expected
}

struct CaptchaFile(PathBuf);
impl Drop for CaptchaFile {
    fn drop(&mut self) {
        let _ = std::fs::remove_file(&self.0);
    }
}

fn private_line() -> io::Result<String> {
    let mut line = String::new();
    // Bounded input; never include the rejected value in an error.
    use std::io::Read;
    io::stdin().lock().take(4097).read_line(&mut line)?;
    if line.len() > 4096 || !line.ends_with('\n') {
        return Err(io::Error::other("invalid private input"));
    }
    Ok(line.trim_end_matches(['\r', '\n']).to_owned())
}

async fn probe(session: &Session<Trace>, submit: bool, image_path: Option<PathBuf>) {
    let page = match auth::fetch_login_page(session).await {
        Ok(page) => page,
        Err(error) => {
            println!(
                "{}",
                json!({"result":format!("{:?}",error.code),"error_hints":hints(error.detail.as_deref().unwrap_or_default())})
            );
            return;
        }
    };
    let mut image_guard = None;
    if let LoginPage::Form {
        execution,
        captcha,
        html,
        action_url,
    } = &page
    {
        println!(
            "{}",
            json!({"form_action":role(action_url),"captcha_form_matches_ubaa":captcha.as_ref().map(|_|captcha_form_matches_ubaa(html,execution))})
        );
        if let Some(challenge) = captcha {
            let mut request = HttpRequest::get(&challenge.image_url);
            request.binary_response = true;
            request.response_limit = Some(1024 * 1024);
            let image = match session.send(request).await {
                Ok(response) if response.status == 200 => response.bytes.unwrap_or_default(),
                _ => {
                    println!("{}", json!({"result":"captcha_fetch_failed"}));
                    return;
                }
            };
            if !image.starts_with(b"\x89PNG\r\n\x1a\n") && !image.starts_with(b"\xff\xd8\xff") {
                println!("{}", json!({"result":"invalid_captcha_image"}));
                return;
            }
            if let Some(path) = image_path {
                if !path.is_absolute() {
                    println!("{}", json!({"result":"absolute_image_path_required"}));
                    return;
                }
                let mut options = std::fs::OpenOptions::new();
                options.write(true).create_new(true);
                #[cfg(unix)]
                {
                    use std::os::unix::fs::OpenOptionsExt;
                    options.mode(0o600);
                }
                match options.open(&path) {
                    Ok(mut file) => {
                        image_guard = Some(CaptchaFile(path));
                        if file.write_all(&image).is_err() {
                            println!("{}", json!({"result":"image_write_failed"}));
                            return;
                        }
                    }
                    Err(_) => {
                        println!("{}", json!({"result":"image_create_failed"}));
                        return;
                    }
                }
                println!("{}", json!({"captcha_image_ready":true}));
            } else if submit {
                println!("{}", json!({"result":"captcha_image_path_required"}));
                return;
            }
        }
    }
    if !submit {
        println!("{}", json!({"result":"anonymous_only"}));
        return;
    }
    if io::stdin().is_terminal() {
        println!("{}", json!({"result":"private_pipe_required"}));
        return;
    }
    println!("{}", json!({"awaiting_private_input":true}));
    let _ = io::stdout().flush();
    let (sender, receiver) = tokio::sync::oneshot::channel();
    std::thread::spawn(move || {
        let _ = sender.send((private_line(), private_line(), private_line()));
    });
    let Ok((Ok(username), Ok(password), Ok(answer))) = receiver.await else {
        println!("{}", json!({"result":"invalid_private_input"}));
        return;
    };
    let credentials = Credentials {
        username,
        password,
        captcha_text: (!answer.is_empty()).then_some(answer),
    };
    match auth::complete_login(session, &credentials, page).await {
        Ok(LoginResult::SignedIn(_)) => println!("{}", json!({"result":"SignedIn"})),
        Ok(LoginResult::CaptchaRequired { .. }) => {
            println!("{}", json!({"result":"CaptchaRequired"}))
        }
        Err(error) => println!(
            "{}",
            json!({"result":format!("{:?}",error.code),"error_hints":hints(error.detail.as_deref().unwrap_or_default())})
        ),
    }
    drop(image_guard);
}

fn main() {
    if std::env::var("GINKGO_MANUAL_LIVE_NETWORK").as_deref() != Ok("1") {
        println!("{}", json!({"result":"live_opt_in_required"}));
        return;
    }
    let args: Vec<_> = std::env::args().collect();
    let image_path = args
        .windows(2)
        .find(|pair| pair[0] == "--captcha-file")
        .map(|pair| PathBuf::from(&pair[1]));
    let transport = match ReqwestTransport::new() {
        Ok(value) => value,
        Err(_) => {
            println!("{}", json!({"result":"transport_unavailable"}));
            return;
        }
    };
    let session = Session::new(Trace(transport));
    session.set_route(if args.iter().any(|arg| arg == "--webvpn") {
        RouteMode::WebVpn
    } else {
        RouteMode::Direct
    });
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("probe runtime");
    let result = runtime.block_on(async {
        tokio::time::timeout(Duration::from_secs(180), async {
            probe(
                &session,
                args.iter().any(|arg| arg == "--submit"),
                image_path,
            )
            .await;
        })
        .await
    });
    if result.is_err() {
        println!("{}", json!({"result":"timeout"}));
    }
    session.clear_cookies();
    println!("{}", json!({"cleanup":"memory_cookies_cleared"}));
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn metadata_never_contains_response_values_or_error_text() {
        let response = HttpResponse::new(401,"https://sso.buaa.edu.cn/login?ticket=PRIVATE-TICKET",r#"<div id="errorDiv">PRIVATE-PERSON 的密码有误 PRIVATE-SECRET</div><input name="execution" value="PRIVATE-EXECUTION">"#)
            .with_set_cookie("cookie=PRIVATE-COOKIE")
            .with_header("location","https://uc.buaa.edu.cn/?ticket=PRIVATE-TICKET");
        let output = response_metadata(&response).to_string();
        assert!(!output.contains("PRIVATE"));
        assert!(!output.contains("密码"));
        assert_eq!(
            response_metadata(&response)["error_hints"],
            json!(["password", "incorrect_alt"])
        );
    }
    #[test]
    fn english_hints_are_case_insensitive_and_unknown_tips_remain_visible() {
        assert_eq!(
            hints("INVALID credentials. PRIVATE-SECRET"),
            vec!["en_invalid", "en_credentials"]
        );
        let response = HttpResponse::new(
            401,
            "https://sso.buaa.edu.cn/login",
            r#"<div id="errorDiv">自定义提示</div>"#,
        );
        assert_eq!(response_metadata(&response)["unclassified_tip"], true);
        assert!(!response_metadata(&response)
            .to_string()
            .contains("自定义提示"));
    }

    #[test]
    fn captcha_comparison_detects_extra_hidden_parameters_and_type_drift() {
        let form = r#"<input type="hidden" name="execution" value="synthetic"><input type="hidden" name="type" value="username_password">"#;
        assert!(captcha_form_matches_ubaa(form, "synthetic"));
        assert!(!captcha_form_matches_ubaa(
            &form.replace("username_password", "other"),
            "synthetic"
        ));
        assert!(!captcha_form_matches_ubaa(
            &format!(r#"{form}<input type="hidden" name="extra" value="secret">"#),
            "synthetic"
        ));
    }
}
