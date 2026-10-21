//! Deterministic in-process cookie jar.
//!
//! CAS login depends on `CASTGC` and UC cookies staying inside Rust; the UI
//! never sees or forwards them. This jar implements the RFC 6265 subset the
//! campus hosts need: domain/path/secure matching, `Max-Age` and `Expires`.
use std::time::{SystemTime, UNIX_EPOCH};
use url::Url;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Cookie {
    pub name: String,
    pub value: String,
    pub domain: String,
    pub host_only: bool,
    pub path: String,
    pub secure: bool,
    pub http_only: bool,
    pub expires_at_ms: Option<i64>,
    created_at_ms: i64,
    sequence: u64,
}

impl Cookie {
    pub fn is_expired(&self, now_ms: i64) -> bool {
        self.expires_at_ms.is_some_and(|expires| expires <= now_ms)
    }

    fn matches(&self, url: &Url, now_ms: i64) -> bool {
        if self.is_expired(now_ms) {
            return false;
        }
        if self.secure && url.scheme() != "https" {
            return false;
        }
        let Some(host) = url.host_str() else {
            return false;
        };
        let host = host.to_ascii_lowercase();
        let domain_matches = if self.host_only {
            host == self.domain
        } else {
            host == self.domain || host.ends_with(&format!(".{}", self.domain))
        };
        domain_matches && path_matches(url.path(), &self.path)
    }
}

#[derive(Debug, Default, Clone)]
pub struct CookieJar {
    cookies: Vec<Cookie>,
    sequence: u64,
}

impl CookieJar {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn now_ms() -> i64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|duration| duration.as_millis() as i64)
            .unwrap_or(0)
    }

    /// Store one `Set-Cookie` header received for `request_url`.
    pub fn store(&mut self, request_url: &str, header: &str, now_ms: i64) {
        let Ok(url) = Url::parse(request_url) else {
            return;
        };
        let Some(host) = url.host_str().map(str::to_ascii_lowercase) else {
            return;
        };

        let mut parts = header.split(';');
        let Some((name, value)) = parts.next().and_then(|pair| pair.split_once('=')) else {
            return;
        };
        let name = name.trim();
        let value = value.trim();
        if name.is_empty() || name.bytes().any(|byte| byte <= 0x20 || byte >= 0x7f) {
            return;
        }

        let mut domain_attribute: Option<String> = None;
        let mut path_attribute: Option<String> = None;
        let mut max_age: Option<i64> = None;
        let mut expires: Option<i64> = None;
        let mut secure = false;
        let mut http_only = false;

        for attribute in parts {
            let attribute = attribute.trim();
            let (key, value) = match attribute.split_once('=') {
                Some((key, value)) => (key.trim(), value.trim()),
                None => (attribute, ""),
            };
            match key.to_ascii_lowercase().as_str() {
                "domain" => {
                    let candidate = value.trim_start_matches('.').to_ascii_lowercase();
                    if !candidate.is_empty()
                        && (host == candidate || host.ends_with(&format!(".{candidate}")))
                    {
                        domain_attribute = Some(candidate);
                    }
                }
                "path" => {
                    if value.starts_with('/') {
                        path_attribute = Some(value.to_string());
                    }
                }
                "max-age" => {
                    if let Ok(seconds) = value.parse::<i64>() {
                        max_age = Some(seconds);
                    }
                }
                "expires" => {
                    if let Ok(time) = httpdate::parse_http_date(value) {
                        expires = time
                            .duration_since(UNIX_EPOCH)
                            .ok()
                            .map(|duration| duration.as_millis() as i64);
                    }
                }
                "secure" => secure = true,
                "httponly" => http_only = true,
                _ => {}
            }
        }

        let domain = domain_attribute.clone().unwrap_or_else(|| host.clone());
        let path = path_attribute.unwrap_or_else(|| default_path(url.path()));
        let expires_at_ms = match max_age {
            Some(seconds) if seconds <= 0 => Some(now_ms - 1),
            Some(seconds) => Some(now_ms.saturating_add(seconds.saturating_mul(1000))),
            None => expires,
        };

        let cookie = Cookie {
            name: name.to_string(),
            value: value.to_string(),
            domain,
            host_only: domain_attribute.is_none(),
            path,
            secure,
            http_only,
            expires_at_ms,
            created_at_ms: now_ms,
            sequence: self.sequence,
        };
        self.sequence = self.sequence.wrapping_add(1);

        if cookie.is_expired(now_ms) {
            self.cookies.retain(|existing| {
                !(existing.name == cookie.name
                    && existing.domain == cookie.domain
                    && existing.path == cookie.path)
            });
            return;
        }
        if let Some(existing) = self.cookies.iter_mut().find(|existing| {
            existing.name == cookie.name
                && existing.domain == cookie.domain
                && existing.path == cookie.path
        }) {
            *existing = cookie;
        } else {
            self.cookies.push(cookie);
        }
    }

    pub fn header_for(&mut self, url: &str, now_ms: i64) -> Option<String> {
        let parsed = Url::parse(url).ok()?;
        self.cookies.retain(|cookie| !cookie.is_expired(now_ms));
        let mut matched: Vec<&Cookie> = self
            .cookies
            .iter()
            .filter(|cookie| cookie.matches(&parsed, now_ms))
            .collect();
        matched.sort_by(|left, right| {
            right
                .path
                .len()
                .cmp(&left.path.len())
                .then(left.created_at_ms.cmp(&right.created_at_ms))
                .then(left.sequence.cmp(&right.sequence))
        });
        if matched.is_empty() {
            return None;
        }
        Some(
            matched
                .into_iter()
                .map(|cookie| format!("{}={}", cookie.name, cookie.value))
                .collect::<Vec<_>>()
                .join("; "),
        )
    }

    pub fn cookie_value(&self, name: &str) -> Option<&str> {
        self.cookies
            .iter()
            .find(|cookie| cookie.name == name)
            .map(|cookie| cookie.value.as_str())
    }

    pub fn contains(&self, name: &str) -> bool {
        self.cookies.iter().any(|cookie| cookie.name == name)
    }

    pub fn len(&self) -> usize {
        self.cookies.len()
    }

    pub fn is_empty(&self) -> bool {
        self.cookies.is_empty()
    }

    pub fn clear(&mut self) {
        self.cookies.clear();
    }
}

fn default_path(request_path: &str) -> String {
    match request_path.rfind('/') {
        Some(0) | None => "/".to_string(),
        Some(index) => request_path[..index].to_string(),
    }
}

fn path_matches(request_path: &str, cookie_path: &str) -> bool {
    if request_path == cookie_path {
        return true;
    }
    if !request_path.starts_with(cookie_path) {
        return false;
    }
    cookie_path.ends_with('/')
        || request_path
            .as_bytes()
            .get(cookie_path.len())
            .is_some_and(|byte| *byte == b'/')
}

#[cfg(test)]
mod tests {
    use super::*;

    const NOON: i64 = 1_790_000_000_000;

    #[test]
    fn host_only_cookie_is_scoped_to_exact_host_and_path() {
        let mut jar = CookieJar::new();
        jar.store(
            "https://sso.buaa.edu.cn/login",
            "CASTGC=TGT-fixture; Path=/; Secure; HttpOnly",
            NOON,
        );
        assert_eq!(
            jar.header_for("https://sso.buaa.edu.cn/cas/login", NOON)
                .as_deref(),
            Some("CASTGC=TGT-fixture")
        );
        assert!(jar
            .header_for("https://app.buaa.edu.cn/buaafreeclass", NOON)
            .is_none());
        assert!(jar
            .header_for("http://sso.buaa.edu.cn/login", NOON)
            .is_none());
    }

    #[test]
    fn domain_cookie_reaches_subdomains_and_respects_path_depth() {
        let mut jar = CookieJar::new();
        jar.store(
            "https://app.buaa.edu.cn/a_buaa/api/cas/index",
            "SESSION=abc; Domain=.buaa.edu.cn; Path=/buaafreeclass",
            NOON,
        );
        assert_eq!(
            jar.header_for("https://app.buaa.edu.cn/buaafreeclass/wap", NOON)
                .as_deref(),
            Some("SESSION=abc")
        );
        assert!(jar
            .header_for("https://uc.buaa.edu.cn/api/uc/status", NOON)
            .is_none());
        jar.store(
            "https://app.buaa.edu.cn/",
            "GLOBAL=root; Domain=buaa.edu.cn; Path=/",
            NOON,
        );
        assert_eq!(
            jar.header_for("https://uc.buaa.edu.cn/api/uc/status", NOON)
                .as_deref(),
            Some("GLOBAL=root")
        );
        assert_eq!(
            jar.header_for("https://app.buaa.edu.cn/buaafreeclass/x", NOON)
                .as_deref(),
            Some("SESSION=abc; GLOBAL=root")
        );
    }

    #[test]
    fn max_age_and_expiry_remove_cookies() {
        let mut jar = CookieJar::new();
        jar.store("https://sso.buaa.edu.cn/login", "SHORT=1; Max-Age=60", NOON);
        jar.store(
            "https://sso.buaa.edu.cn/login",
            "LONG=2; Max-Age=3600",
            NOON,
        );
        assert_eq!(
            jar.header_for("https://sso.buaa.edu.cn/", NOON + 90_000)
                .as_deref(),
            Some("LONG=2")
        );
        jar.store(
            "https://sso.buaa.edu.cn/login",
            "LONG=gone; Max-Age=0",
            NOON + 100_000,
        );
        assert!(jar.is_empty());
    }

    #[test]
    fn malformed_headers_are_ignored_without_panicking() {
        let mut jar = CookieJar::new();
        for header in [
            "",
            "no-equals",
            "=empty-name",
            "name=; Domain=evil.example",
            "name=value; Path=not-rooted",
        ] {
            jar.store("https://sso.buaa.edu.cn/login", header, NOON);
        }
        // The dotted-domain cookie is rejected because it does not match the
        // request host; the unrooted path cookie falls back to `/`.
        assert_eq!(
            jar.header_for("https://sso.buaa.edu.cn/login", NOON)
                .as_deref(),
            Some("name=value")
        );
    }
}
