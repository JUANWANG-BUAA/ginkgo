//! Minimal HTTP request/response model. Transports are injected so the
//! authentication state machine can be exercised without a network.
use std::{collections::BTreeMap, future::Future};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HttpMethod {
    Get,
    Post,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HttpRequest {
    pub method: HttpMethod,
    pub url: String,
    pub headers: BTreeMap<String, String>,
    pub body: Option<String>,
}

impl HttpRequest {
    pub fn new(method: HttpMethod, url: impl Into<String>) -> Self {
        Self {
            method,
            url: url.into(),
            headers: BTreeMap::new(),
            body: None,
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
}

impl HttpResponse {
    pub fn new(status: u16, final_url: impl Into<String>, body: impl Into<String>) -> Self {
        Self {
            status,
            final_url: final_url.into(),
            headers: BTreeMap::new(),
            set_cookies: Vec::new(),
            body: body.into(),
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
    Unavailable,
}

pub trait HttpTransport {
    fn send(
        &self,
        request: HttpRequest,
    ) -> impl Future<Output = Result<HttpResponse, TransportError>> + Send;
}
