//! Cookie-owning HTTP session. Direct and WebVPN cookies are isolated so a
//! gateway login can never overwrite or leak a campus session.
use super::cas;
use crate::{
    foundation::{
        cookie::CookieJar,
        http::{HttpMethod, HttpRequest, HttpResponse, HttpTransport},
        webvpn,
    },
    AppError,
};
use std::sync::Mutex;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RouteMode {
    Automatic,
    Direct,
    WebVpn,
}

pub struct Session<T: HttpTransport> {
    transport: T,
    route: Mutex<RouteMode>,
    direct_jar: Mutex<CookieJar>,
    webvpn_jar: Mutex<CookieJar>,
}

impl<T: HttpTransport> Session<T> {
    pub fn new(transport: T) -> Self {
        Self {
            transport,
            route: Mutex::new(RouteMode::Automatic),
            direct_jar: Mutex::new(CookieJar::new()),
            webvpn_jar: Mutex::new(CookieJar::new()),
        }
    }

    pub fn route(&self) -> RouteMode {
        *self.route.lock().expect("route lock")
    }

    /// Read-only access to the injected transport, used by tests and adapters
    /// that need transport-specific capabilities.
    pub fn transport(&self) -> &T {
        &self.transport
    }

    pub fn set_route(&self, mode: RouteMode) {
        *self.route.lock().expect("route lock") = mode;
    }

    /// Automatic mode remembers the first confirmed access-policy block and
    /// switches to WebVPN for the rest of the session, matching the Apple app.
    pub fn activate_automatic_webvpn_fallback(&self) -> bool {
        let mut route = self.route.lock().expect("route lock");
        if *route != RouteMode::Automatic {
            return false;
        }
        *route = RouteMode::WebVpn;
        true
    }

    pub fn clear_cookies(&self) {
        self.direct_jar.lock().expect("direct jar").clear();
        self.webvpn_jar.lock().expect("webvpn jar").clear();
    }

    pub fn webvpn_cookie_present(&self) -> bool {
        !self.webvpn_jar.lock().expect("webvpn jar").is_empty()
    }

    pub fn direct_cookie_present(&self) -> bool {
        !self.direct_jar.lock().expect("direct jar").is_empty()
    }

    /// CGYY is direct-only. Never mutate the shared route across an await.
    pub async fn send_direct(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {
        self.send_routed(request, RouteMode::Direct).await
    }

    /// Rust-only access for CGYY's documented SSO cookie; never bridged to Dart.
    pub(crate) fn cgyy_sso_token(&self) -> Option<String> {
        let header = self.direct_jar.lock().expect("direct jar").header_for(
            "https://cgyy.buaa.edu.cn/venue-zhjs-server/",
            CookieJar::now_ms(),
        )?;
        header.split(';').map(str::trim).find_map(|part| {
            part.strip_prefix("sso_buaa_zhjs_token=")
                .filter(|v| !v.is_empty())
                .map(str::to_owned)
        })
    }

    pub async fn send(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {
        let mode = self.route();
        self.send_routed(request, mode).await
    }

    /// Follow browser-style redirects for a safe GET. Business systems such as
    /// BYXT/GSMIS activate their own session by redirecting through SSO; the
    /// authentication chain itself still uses manual hops.
    pub async fn send_following_redirects(
        &self,
        request: HttpRequest,
    ) -> Result<HttpResponse, AppError> {
        if request.method != HttpMethod::Get {
            return self.send_with_fallback(request).await;
        }
        let mut current = request;
        for _ in 0..10 {
            let response = self.send_with_fallback(current).await?;
            if !(300..400).contains(&response.status) {
                return Ok(response);
            }
            let Some(location) = response.header("location") else {
                return Ok(response);
            };
            let next = webvpn::resolve_redirect(location, &response.final_url)
                .ok_or_else(AppError::changed)?;
            current = HttpRequest::get(next);
        }
        Err(AppError::new(crate::ErrorCode::RedirectLimit))
    }

    /// Send once, then retry a safe GET once through WebVPN when automatic
    /// mode sees a school access-policy block. POST bodies are never replayed.
    pub async fn send_with_fallback(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {
        let safe_to_retry = request.method == HttpMethod::Get;
        let response = self.send(request.clone()).await;
        let should_fallback = match &response {
            Ok(response) => response.status == 483 || cas::is_access_policy_denied(&response.body),
            Err(_) => safe_to_retry,
        };
        if !should_fallback || !self.activate_automatic_webvpn_fallback() || !safe_to_retry {
            return response;
        }
        self.send_routed(request, RouteMode::WebVpn).await
    }

    async fn send_routed(
        &self,
        mut request: HttpRequest,
        mode: RouteMode,
    ) -> Result<HttpResponse, AppError> {
        let campus_or_gateway = mode == RouteMode::WebVpn
            && (webvpn::should_route(&request.url) || is_gateway(&request.url));
        if mode == RouteMode::WebVpn && webvpn::should_route(&request.url) {
            request.url = webvpn::wrap(&request.url).map_err(|_| AppError::invalid())?;
        }
        request.headers.remove("Cookie");

        let now = CookieJar::now_ms();
        let cookie_header = if campus_or_gateway {
            self.webvpn_jar
                .lock()
                .expect("webvpn jar")
                .header_for(&request.url, now)
        } else {
            self.direct_jar
                .lock()
                .expect("direct jar")
                .header_for(&request.url, now)
        };
        if let Some(cookie) = cookie_header {
            request.headers.insert("Cookie".into(), cookie);
        }

        let request_url = request.url.clone();
        let response = self
            .transport
            .send(request)
            .await
            .map_err(|_| AppError::unavailable())?;
        let jar = if campus_or_gateway {
            &self.webvpn_jar
        } else {
            &self.direct_jar
        };
        let mut jar = jar.lock().expect("cookie jar");
        for header in &response.set_cookies {
            jar.store(&request_url, header, now);
        }
        // The gateway speaks gateway-shaped URLs while callers reason about the
        // upstream service. Normalize exactly like the Apple router: final URL
        // unwrapped, Location resolved back to the upstream service.
        Ok(if campus_or_gateway {
            normalize_gateway_response(response)
        } else {
            response
        })
    }
}

fn normalize_gateway_response(mut response: HttpResponse) -> HttpResponse {
    response.final_url = webvpn::unwrap(&response.final_url);
    if let Some(location) = response.headers.get("location").cloned() {
        if let Some(resolved) = webvpn::resolve_redirect(&location, &response.final_url) {
            // Gateway-owned pages (/login, /faq) have no upstream equivalent.
            if !is_gateway(&resolved) {
                response.headers.insert("location".into(), resolved);
            }
        }
    }
    response
}

fn is_gateway(url: &str) -> bool {
    url::Url::parse(url)
        .ok()
        .and_then(|url| url.host_str().map(str::to_ascii_lowercase))
        .is_some_and(|host| host == webvpn::GATEWAY_HOST)
}
