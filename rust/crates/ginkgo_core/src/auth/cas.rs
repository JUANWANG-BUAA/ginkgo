//! CAS login-page parsing and form construction (API.md §1.2–§1.5).
//!
//! Pure functions only: no network, cookies, or UI state.
use regex::Regex;
use std::sync::LazyLock;

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
        r#"(?is)<(?:div|span)[^>]*(?:id=["']errorDiv["']|class=["'][^"']*\berrors\b[^"']*["'])[^>]*>([\s\S]*?)</(?:div|span)>"#,
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CaptchaChallenge {
    pub captcha_type: String,
    pub id: String,
    pub image_url: String,
}

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
        image_url: format!("https://sso.buaa.edu.cn/captcha?captchaId={id}"),
        id,
    })
}

pub fn extract_tip_text(html: &str) -> Option<String> {
    first_group(&TIP, html, 1)
        .map(|text| plain_text(&text))
        .filter(|text| !text.is_empty())
}

pub fn extract_error_text(html: &str) -> Option<String> {
    first_group(&ERROR, html, 1)
        .map(|text| plain_text(&text))
        .filter(|text| !text.is_empty())
        .or_else(|| extract_tip_text(html))
}

pub fn is_access_policy_denied(html: &str) -> bool {
    let compact = WHITESPACE.replace_all(html, " ");
    compact.contains("访问策略禁止") || compact.contains("没有权限访问相应的资源")
}

pub fn is_password_expiry_page(html: &str) -> bool {
    extract_execution(html).is_some()
        && (html.contains("continueForm")
            || html.contains("ignoreAndContinue")
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

/// Build the CAS form from the page's hidden inputs. The `+` and `/` in the
/// execution token must be percent-encoded when the body is written.
pub fn login_fields(
    html: &str,
    username: &str,
    password: &str,
    captcha_text: Option<&str>,
) -> Vec<(String, String)> {
    let mut fields: Vec<(String, String)> = Vec::new();
    for tag in INPUT_TAG.find_iter(html).map(|item| item.as_str()) {
        let attributes = parse_attributes(tag);
        let Some(name) = attributes.get("name").filter(|name| !name.is_empty()) else {
            continue;
        };
        let input_type = attributes
            .get("type")
            .map(|value| value.to_ascii_lowercase())
            .unwrap_or_else(|| "text".to_string());
        if input_type == "hidden" || (input_type == "checkbox" && CHECKED.is_match(tag)) {
            let value = attributes
                .get("value")
                .map(|value| decode_entities(value))
                .unwrap_or_default();
            fields.push((name.clone(), value));
        }
    }
    set_field(&mut fields, "username", username);
    set_field(&mut fields, "password", password);
    set_field(&mut fields, "submit", "登录");
    if !fields.iter().any(|(name, _)| name == "_eventId") {
        fields.push(("_eventId".into(), "submit".into()));
    }
    if !fields.iter().any(|(name, _)| name == "type") {
        fields.push(("type".into(), "username_password".into()));
    }
    if let Some(captcha) = captcha_text.filter(|text| !text.is_empty()) {
        set_field(&mut fields, "captcha", captcha);
        set_field(&mut fields, "captchaResponse", captcha);
    }
    fields
}

pub fn form_urlencode(fields: &[(String, String)]) -> String {
    fields
        .iter()
        .map(|(name, value)| format!("{}={}", encode_component(name), encode_component(value)))
        .collect::<Vec<_>>()
        .join("&")
}

fn set_field(fields: &mut Vec<(String, String)>, name: &str, value: &str) {
    fields.retain(|(existing, _)| existing != name);
    fields.push((name.to_string(), value.to_string()));
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
        let fields = login_fields(LOGIN_PAGE, "sy2501001", "pa+ss/word", Some("1234"));
        assert!(fields.contains(&("lt".into(), "LT-fixture".into())));
        assert!(fields.contains(&("remember".into(), "true".into())));
        assert!(fields.contains(&("username".into(), "sy2501001".into())));
        assert!(fields.contains(&("captchaResponse".into(), "1234".into())));
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
