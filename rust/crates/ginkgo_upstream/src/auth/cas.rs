//! CAS login-page parsing and form construction (API.md §1.2–§1.5).
//!
//! Pure functions only: no network, cookies, or UI state.
use regex::Regex;
use std::sync::LazyLock;

use crate::AppError;

static EXECUTION: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<input[^>]*name=["']execution["'][^>]*value=["']([^"']+)["'][^>]*>"#)
        .expect("execution regex")
});
static CAPTCHA: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"config\.captcha\s*=\s*\{\s*type:\s*['"]([^'"]+)['"],\s*id:\s*['"]([^'"]+)['"]"#)
        .expect("captcha regex")
});
static TIP: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?is)<div[^>]*class=["'][^"']*tip-text[^"']*["'][^>]*>([\s\S]*?)</div>"#)
        .expect("tip regex")
});
static ERROR: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(
        r#"(?is)<(?:div|span|p)[^>]*(?:id=["']errorDiv["']|class=["'][^"']*\berrors\b[^"']*["'])[^>]*>([\s\S]*?)</(?:div|span|p)>"#,
    )
    .expect("error regex")
});
static FORM_ACTION: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)<form\b[^>]*action=["']([^"']+)["'][^>]*>"#).expect("form action regex")
});
static INPUT_TAG: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?i)<input\b[^>]*>"#).expect("input regex"));
static ATTRIBUTE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?i)([\w:-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#).expect("attribute regex")
});
static CHECKED: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?i)\bchecked\b"#).expect("checked regex"));
static TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r#"(?s)<[^>]+>"#).expect("tag regex"));
static WHITESPACE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"\s+").expect("whitespace regex"));

pub use ginkgo_domain::session::CaptchaChallenge;

pub fn extract_execution(html: &str) -> Option<String> {
    first_group(&EXECUTION, html, 1)
}

pub fn extract_login_form_action(html: &str) -> Option<String> {
    first_group(&FORM_ACTION, html, 1).map(|action| decode_entities(action.trim()))
}

pub fn detect_captcha(html: &str) -> Option<CaptchaChallenge> {
    let captcha_type = first_group(&CAPTCHA, html, 1)?;
    let id = first_group(&CAPTCHA, html, 2)?;
    Some(CaptchaChallenge {
        captcha_type,
        image_url: captcha_image_url(&id),
        id,
    })
}

pub fn captcha_image_url(id: &str) -> String {
    let mut url = url::Url::parse("https://sso.buaa.edu.cn/captcha").expect("fixed URL");
    url.query_pairs_mut().append_pair("captchaId", id);
    url.into()
}

/// Only the documented local image/text form is understood. Other challenge
/// interaction protocols must not be guessed from a free-form type string.
/// The `type` string is informational: every advertised challenge is served
/// by the same image endpoint and answered with the same two text fields
/// (API §1.3). A whitelist of one value refused challenges the school serves.
pub fn text_captcha_supported(challenge: &CaptchaChallenge) -> bool {
    !challenge.id.is_empty()
}

pub fn extract_tip_text(html: &str) -> Option<String> {
    first_nonempty_text(&TIP, html)
}

pub fn extract_error_text(html: &str) -> Option<String> {
    first_nonempty_text(&ERROR, html).or_else(|| extract_tip_text(html))
}

pub fn is_access_policy_denied(html: &str) -> bool {
    let compact = WHITESPACE.replace_all(html, " ");
    compact.contains("访问策略禁止") || compact.contains("没有权限访问相应的资源")
}

pub fn is_password_expiry_page(html: &str) -> bool {
    let ascii_lower = html.to_ascii_lowercase();
    extract_execution(html).is_some_and(|value| !value.trim().is_empty())
        && (ascii_lower.contains("continueform")
            || ascii_lower.contains("ignoreandcontinue")
            || html.contains("账号存在安全风险")
            || html.contains("密码过期"))
}

pub fn is_login_redirect(final_url: &str, body: &str) -> bool {
    if final_url.contains("sso.buaa.edu.cn") {
        return true;
    }
    body.chars()
        .take(5000)
        .collect::<String>()
        .contains(r#"name="execution""#)
}

/// Classify a module answer that is not the expected payload.
///
/// A CAS login page means the shared school session is gone: every module
/// that relies on it fails as well, and the user has to log in again. Any
/// other refusal is the module asking for its own token again, which leaves
/// the shared session — and every other module — untouched. Reporting that
/// as a global expiry sends the user to re-authenticate a session that is
/// still working.
pub fn module_refusal(final_url: &str, body: &str) -> AppError {
    if is_login_redirect(final_url, body) {
        AppError::session_expired()
    } else {
        AppError::module_auth_required()
    }
}

/// Follow UBAA's normal-form input selection and eight-field captcha branch.
/// The `+` and `/` in execution/password values are encoded by form_urlencode.
pub fn login_fields(
    html: &str,
    username: &str,
    password: &str,
    captcha_text: Option<&str>,
) -> Vec<(String, String)> {
    if let Some(captcha) = captcha_text.filter(|text| !text.trim().is_empty()) {
        return captcha_login_fields(
            username,
            password,
            &extract_execution(html).unwrap_or_default(),
            captcha,
        );
    }
    let mut fields: Vec<(String, String)> = Vec::new();
    let mut present = std::collections::BTreeSet::new();
    for tag in INPUT_TAG.find_iter(html).map(|item| item.as_str()) {
        let attributes = parse_attributes(tag);
        let Some(name) = attributes
            .get("name")
            .map(|name| name.trim())
            .filter(|name| !name.is_empty())
        else {
            continue;
        };
        if matches!(name, "username" | "password") {
            continue;
        }
        let input_type = attributes
            .get("type")
            .map(|value| value.trim().to_ascii_lowercase())
            .unwrap_or_else(|| "text".to_string());
        if matches!(input_type.as_str(), "submit" | "button" | "image") {
            continue;
        }
        present.insert(name.to_owned());
        let value = attributes
            .get("value")
            .map(|value| decode_entities(value))
            .unwrap_or_default();
        if input_type == "checkbox" {
            if CHECKED.is_match(tag) {
                fields.push((
                    name.to_owned(),
                    if value.trim().is_empty() {
                        "on".into()
                    } else {
                        value
                    },
                ));
            }
        } else if input_type == "hidden" || !value.trim().is_empty() {
            fields.push((name.to_owned(), value));
        }
    }
    fields.extend([
        ("username".into(), username.into()),
        ("password".into(), password.into()),
        ("submit".into(), "登录".into()),
    ]);
    if !present.contains("_eventId") {
        fields.push(("_eventId".into(), "submit".into()));
    }
    if !present.contains("execution") {
        fields.push(("execution".into(), String::new()));
    }
    if !present.contains("type") {
        fields.push(("type".into(), "username_password".into()));
    }
    fields
}

pub(crate) fn captcha_login_fields(
    username: &str,
    password: &str,
    execution: &str,
    captcha: &str,
) -> Vec<(String, String)> {
    [
        ("username", username),
        ("password", password),
        ("captcha", captcha),
        ("captchaResponse", captcha),
        ("execution", execution),
        ("_eventId", "submit"),
        ("submit", "登录"),
        ("type", "username_password"),
    ]
    .into_iter()
    .map(|(key, value)| (key.to_owned(), value.to_owned()))
    .collect()
}

pub fn form_urlencode(fields: &[(String, String)]) -> String {
    fields
        .iter()
        .map(|(name, value)| format!("{}={}", encode_component(name), encode_component(value)))
        .collect::<Vec<_>>()
        .join("&")
}

fn parse_attributes(tag: &str) -> std::collections::BTreeMap<String, String> {
    ATTRIBUTE
        .captures_iter(tag)
        .filter_map(|captures| {
            let name = captures.get(1)?.as_str().to_ascii_lowercase();
            let value = (2..=4)
                .find_map(|index| captures.get(index))
                .map(|value| value.as_str().to_string())
                .unwrap_or_default();
            Some((name, value))
        })
        .collect()
}

fn first_group(regex: &Regex, text: &str, group: usize) -> Option<String> {
    regex
        .captures(text)
        .and_then(|captures| captures.get(group))
        .map(|value| value.as_str().to_string())
}

fn first_nonempty_text(regex: &Regex, html: &str) -> Option<String> {
    regex
        .captures_iter(html)
        .filter_map(|capture| capture.get(1).map(|text| plain_text(text.as_str())))
        .find(|text| !text.is_empty())
}

fn plain_text(fragment: &str) -> String {
    let without_tags = TAG.replace_all(fragment, " ");
    WHITESPACE
        .replace_all(&decode_entities(&without_tags), " ")
        .trim()
        .to_string()
}

fn decode_entities(text: &str) -> String {
    let mut decoded = text
        .replace("&nbsp;", " ")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&apos;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&amp;", "&");
    while let Some(start) = decoded.find("&#") {
        let Some(end_offset) = decoded[start..].find(';') else {
            break;
        };
        let end = start + end_offset;
        let digits = &decoded[start + 2..end];
        let value = digits
            .strip_prefix('x')
            .or_else(|| digits.strip_prefix('X'))
            .and_then(|hex| u32::from_str_radix(hex, 16).ok())
            .or_else(|| digits.parse::<u32>().ok())
            .and_then(char::from_u32);
        match value {
            Some(character) => decoded.replace_range(start..=end, &character.to_string()),
            None => break,
        }
    }
    decoded
}

fn encode_component(value: &str) -> String {
    let mut encoded = String::with_capacity(value.len());
    for byte in value.bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' | b'-' | b'.' | b'_' | b'*' => {
                encoded.push(byte as char)
            }
            b' ' => encoded.push('+'),
            _ => encoded.push_str(&format!("%{byte:02X}")),
        }
    }
    encoded
}

#[cfg(test)]
mod tests {
    use super::*;

    const LOGIN_PAGE: &str = r#"
        <html><body>
        <form id="fm1" action="/login?service=fixture" method="post">
          <input type="hidden" name="execution" value="eyJhbGciOiJIUzI1NiJ9.a+b/c=" />
          <input type="hidden" name="lt" value="LT-fixture" />
          <input type="checkbox" name="remember" value="true" checked />
          <input type="text" name="username" value="" />
          <input type="password" name="password" value="" />
        </form>
        </body></html>
    "#;

    #[test]
    fn parses_execution_action_and_captcha() {
        assert_eq!(
            extract_execution(LOGIN_PAGE).as_deref(),
            Some("eyJhbGciOiJIUzI1NiJ9.a+b/c=")
        );
        assert_eq!(
            extract_login_form_action(LOGIN_PAGE).as_deref(),
            Some("/login?service=fixture")
        );
        assert!(detect_captcha(LOGIN_PAGE).is_none());

        let captcha_page = r#"<script>config.captcha = { type: 'slider', id: 'cap-1' };</script>"#;
        let challenge = detect_captcha(captcha_page).expect("captcha");
        assert_eq!(challenge.captcha_type, "slider");
        assert_eq!(
            challenge.image_url,
            "https://sso.buaa.edu.cn/captcha?captchaId=cap-1"
        );
    }

    #[test]
    fn builds_fields_and_encodes_plus_and_slash() {
        let fields = login_fields(LOGIN_PAGE, "sy2501001", "pa+ss/word", None);
        assert!(fields.contains(&("lt".into(), "LT-fixture".into())));
        assert!(fields.contains(&("remember".into(), "true".into())));
        assert!(fields.contains(&("username".into(), "sy2501001".into())));
        assert!(fields.contains(&("_eventId".into(), "submit".into())));
        assert!(fields.contains(&("type".into(), "username_password".into())));

        let body = form_urlencode(&fields);
        assert!(body.contains("execution=eyJhbGciOiJIUzI1NiJ9.a%2Bb%2Fc%3D"));
        assert!(body.contains("password=pa%2Bss%2Fword"));
        assert!(!body.contains("password=pa+ss"));
    }

    #[test]
    fn extracts_tips_errors_and_policy_pages() {
        let tip = r#"<div class="tip-text">账号已锁定，请 <b>稍后</b> 重试</div>"#;
        assert_eq!(
            extract_tip_text(tip).as_deref(),
            Some("账号已锁定，请 稍后 重试")
        );
        let error = r#"<div id="errorDiv">用户名或密码错误</div>"#;
        assert_eq!(
            extract_error_text(error).as_deref(),
            Some("用户名或密码错误")
        );
        assert!(is_access_policy_denied(
            "访问策略禁止 没有权限访问相应的资源"
        ));
        assert!(!is_access_policy_denied("普通 403"));
    }

    #[test]
    fn detects_password_expiry_only_with_execution() {
        let expiry = r#"<input name="execution" value="abc" /><form id="continueForm">
          <input type="hidden" name="_eventId" value="ignoreAndContinue" /></form>"#;
        assert!(is_password_expiry_page(expiry));
        assert!(!is_password_expiry_page("<p>密码过期</p>"));
    }
}

#[cfg(test)]
mod error_selection_regressions {
    use super::*;
    #[test]
    fn error_selection_skips_empty_placeholders_and_supports_ubaa_paragraph_shape() {
        for body in [
            r#"<div id="errorDiv"></div><span class="errors">合成拒绝</span>"#,
            r#"<p class="errors">合成拒绝</p>"#,
            r#"<div class="tip-text"> </div><div class="tip-text">合成拒绝</div>"#,
        ] {
            assert_eq!(extract_error_text(body).as_deref(), Some("合成拒绝"));
        }
    }
}

#[cfg(test)]
mod reference_vectors {
    use super::*;

    #[derive(serde::Deserialize)]
    struct Vector {
        id: String,
        html: String,
        captcha: Option<String>,
        fields: Vec<(String, String)>,
    }

    #[derive(serde::Deserialize)]
    struct Vectors {
        cases: Vec<Vector>,
    }

    // Expected values are checked independently by executing the pinned UBAA
    // Kotlin parser with scripts/check-ubaa-cas-parity.py, never generated here.
    #[test]
    fn ubaa_cas_oracle_matches_field_multisets_and_encoding() {
        let vectors: Vectors =
            serde_json::from_str(include_str!("../../tests/data/ubaa-cas.json")).unwrap();
        for vector in vectors.cases {
            let mut actual = login_fields(
                &vector.html,
                "sy2501001",
                "pa+ss/word",
                vector.captcha.as_deref(),
            );
            let body = form_urlencode(&actual);
            let mut decoded: Vec<_> = url::form_urlencoded::parse(body.as_bytes())
                .into_owned()
                .collect();
            decoded.sort();
            actual.sort();
            let mut expected = vector.fields;
            expected.sort();
            assert_eq!(actual, expected, "UBAA field multiset: {}", vector.id);
            assert_eq!(decoded, expected, "wire encoding: {}", vector.id);
        }
    }
}
