//! Minimal HTTP request/response model. Transports are injected so the
//! authentication state machine can be exercised without a network.
use std::{collections::BTreeMap, future::Future};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HttpMethod {
    Get,
    Post,
}

#[derive(Clone, PartialEq, Eq)]
pub struct HttpRequest {
    pub method: HttpMethod,
    pub url: String,
    pub headers: BTreeMap<String, String>,
    pub body: Option<String>,
    /// Raw bounded bytes, exclusive with body; routing must not re-encode them.
    pub binary_body: Option<Vec<u8>>,
    /// Return exact attachment bytes instead of lossy text. No redirect following.
    pub binary_response: bool,
    pub response_limit: Option<usize>,
}

impl HttpRequest {
    pub fn new(method: HttpMethod, url: impl Into<String>) -> Self {
        Self {
            method,
            url: url.into(),
            headers: BTreeMap::new(),
            body: None,
            binary_body: None,
            binary_response: false,
            response_limit: None,
        }
    }

    pub fn get(url: impl Into<String>) -> Self {
        Self::new(HttpMethod::Get, url)
    }

    pub fn post_form(url: impl Into<String>, body: impl Into<String>) -> Self {
        let mut request = Self::new(HttpMethod::Post, url);
        request.body = Some(body.into());
        request.headers.insert(
            "Content-Type".into(),
            "application/x-www-form-urlencoded".into(),
        );
        request
    }

    pub fn header(mut self, name: &str, value: &str) -> Self {
        self.headers.insert(name.into(), value.into());
        self
    }

    /// Case-insensitive header lookup, matching HTTP semantics.
    pub fn header_value(&self, name: &str) -> Option<&str> {
        self.headers
            .iter()
            .find(|(key, _)| key.eq_ignore_ascii_case(name))
            .map(|(_, value)| value.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HttpResponse {
    pub status: u16,
    /// URL of the response after any transport-level redirect handling.
    pub final_url: String,
    /// Lowercase header names. Repeated headers keep the last value.
    pub headers: BTreeMap<String, String>,
    /// Raw `Set-Cookie` header values in arrival order.
    pub set_cookies: Vec<String>,
    pub body: String,
    pub bytes: Option<Vec<u8>>,
}

impl HttpResponse {
    pub fn new(status: u16, final_url: impl Into<String>, body: impl Into<String>) -> Self {
        Self {
            status,
            final_url: final_url.into(),
            headers: BTreeMap::new(),
            set_cookies: Vec::new(),
            body: body.into(),
            bytes: None,
        }
    }

    pub fn with_header(mut self, name: &str, value: &str) -> Self {
        self.headers.insert(name.to_ascii_lowercase(), value.into());
        self
    }

    pub fn with_set_cookie(mut self, value: impl Into<String>) -> Self {
        self.set_cookies.push(value.into());
        self
    }

    pub fn header(&self, name: &str) -> Option<&str> {
        self.headers
            .get(&name.to_ascii_lowercase())
            .map(String::as_str)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransportError {
    /// No response ever arrived: name resolution, TCP connect, TLS handshake
    /// or the request deadline failed. Rerouting through the school gateway
    /// cannot repair this, and the copy must not blame the school.
    Unreachable,
    /// The transport could not be used, or the server answered and the
    /// exchange still could not be completed (client construction, response
    /// over the size limit, body truncated, task aborted).
    Unavailable,
}

impl From<TransportError> for crate::AppError {
    fn from(error: TransportError) -> Self {
        match error {
            TransportError::Unreachable => Self::network_unreachable(),
            TransportError::Unavailable => Self::unavailable(),
        }
    }
}

pub trait HttpTransport {
    fn send(
        &self,
        request: HttpRequest,
    ) -> impl Future<Output = Result<HttpResponse, TransportError>> + Send;
}

// Multipart bodies may contain private homework; never derive Debug over them.
impl std::fmt::Debug for HttpRequest {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("HttpRequest")
            .field("method", &self.method)
            .field("body_bytes", &self.body.as_ref().map(String::len))
            .field("binary_bytes", &self.binary_body.as_ref().map(Vec::len))
            .finish_non_exhaustive()
    }
}
