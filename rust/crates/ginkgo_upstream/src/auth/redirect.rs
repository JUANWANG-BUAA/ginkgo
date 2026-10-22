//! Authentication GET redirect policy. Never rewrite a password POST target.
use crate::{foundation::webvpn, AppError, ErrorCode};

/// UC has been observed returning this exact legacy CAS login endpoint over
/// HTTP. Its HTTPS endpoint exists. Change only the scheme before sending the
/// next GET, retaining the raw query, order, duplicate keys and escape bytes.
/// Every other insecure target fails before a request or cookie is sent.
pub(crate) fn resolve_get(location: &str, base: &str) -> Result<String, AppError> {
    let target = webvpn::resolve_redirect(location, base).ok_or_else(AppError::changed)?;
    let parsed = url::Url::parse(&target).map_err(|_| AppError::changed())?;
    if parsed.scheme() == "https" {
        return Ok(target);
    }
    let legacy = target
        .split_once("://")
        .and_then(|(_, rest)| rest.split_once('/'))
        .is_some_and(|(authority, rest)| {
            authority.eq_ignore_ascii_case("sso.buaa.edu.cn")
                && rest.split(['?', '#']).next() == Some("login")
        });
    if parsed.scheme() == "http" && legacy && parsed.path() == "/login" {
        let (_, rest) = target.split_once(':').ok_or_else(AppError::changed)?;
        return Ok(format!("https:{rest}"));
    }
    Err(AppError::with_detail(
        ErrorCode::ChangedResponse,
        "insecure_redirect",
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn known_cas_upgrade_preserves_raw_query_and_gateway_routes() {
        let target = "http://sso.buaa.edu.cn/login?service=https%3a%2f%2fuc.buaa.edu.cn%2Fcb%3Fx%3Da%252Bb%252Fc%2525&x=&x=2+3#part%2f";
        let secure = target.replacen("http:", "https:", 1);
        for location in [target.to_owned(), webvpn::wrap(target).expect("wrapped")] {
            assert_eq!(
                resolve_get(&location, "https://uc.buaa.edu.cn/").unwrap(),
                secure
            );
        }
        assert_eq!(
            resolve_get("../login?x=%2f", "https://sso.buaa.edu.cn/cas/").unwrap(),
            "https://sso.buaa.edu.cn/login?x=%2f"
        );
    }

    #[test]
    fn only_the_evidenced_exact_authority_and_path_can_upgrade() {
        for target in [
            "http://sso.buaa.edu.cn:80/login",
            "http://sso.buaa.edu.cn:443/login",
            "http://sso.buaa.edu.cn:8080/login",
            "http://sso.buaa.edu.cn/login/",
            "http://sso.buaa.edu.cn/cas/login",
            "http://sso.buaa.edu.cn/other/../login",
            "http://sso.buaa.edu.cn/log%69n",
            "http://sso.buaa.edu.cn./login",
            "http://user:password@sso.buaa.edu.cn/login",
            "http://@sso.buaa.edu.cn/login",
            "http://sso.buaa.edu.cn.evil.example/login",
            "http://uc.buaa.edu.cn/login",
            "javascript:alert(1)",
            "ftp://sso.buaa.edu.cn/login",
        ] {
            assert_eq!(
                resolve_get(target, "https://uc.buaa.edu.cn/")
                    .unwrap_err()
                    .detail
                    .as_deref(),
                Some("insecure_redirect"),
                "must not allow {target}"
            );
        }
    }
}
