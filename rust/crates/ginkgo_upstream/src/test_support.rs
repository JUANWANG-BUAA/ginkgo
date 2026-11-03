//! Shared test doubles for adapters. Compiled only under `cfg(test)`.
use crate::foundation::http::{HttpRequest, HttpResponse, HttpTransport, TransportError};
use std::{
    collections::VecDeque,
    sync::{Arc, Mutex},
};

#[derive(Clone, Default)]
pub struct MockTransport {
    state: Arc<MockState>,
}

#[derive(Default)]
struct MockState {
    responses: Mutex<VecDeque<Result<HttpResponse, TransportError>>>,
    requests: Mutex<Vec<HttpRequest>>,
}

impl MockTransport {
    pub fn with_responses(responses: Vec<HttpResponse>) -> Self {
        Self::with_results(responses.into_iter().map(Ok).collect())
    }

    /// Scripted results let a test inject a transport failure inside an
    /// otherwise successful chain (route fallback, retry boundaries).
    pub fn with_results(results: Vec<Result<HttpResponse, TransportError>>) -> Self {
        let transport = Self::default();
        transport
            .state
            .responses
            .lock()
            .expect("response lock")
            .extend(results);
        transport
    }

    pub fn requests(&self) -> Vec<HttpRequest> {
        self.state.requests.lock().expect("request lock").clone()
    }

    pub fn request_count(&self) -> usize {
        self.state.requests.lock().expect("request lock").len()
    }
}

impl HttpTransport for MockTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.state
            .requests
            .lock()
            .expect("request lock")
            .push(request);
        self.state
            .responses
            .lock()
            .expect("response lock")
            .pop_front()
            .unwrap_or(Err(TransportError::Unavailable))
    }
}

type TranscriptStep = (HttpRequest, Result<HttpResponse, TransportError>);

/// A protocol transcript: wrong requests fail before they can consume the
/// next response. Every header/body in these transcripts is synthetic.
#[derive(Clone)]
pub struct TranscriptTransport {
    steps: Arc<Mutex<VecDeque<TranscriptStep>>>,
    requests: Arc<Mutex<Vec<HttpRequest>>>,
}

impl TranscriptTransport {
    pub fn new(steps: Vec<TranscriptStep>) -> Self {
        Self {
            steps: Arc::new(Mutex::new(steps.into())),
            requests: Arc::default(),
        }
    }

    pub fn assert_finished(&self) {
        assert!(
            self.steps.lock().unwrap().is_empty(),
            "unconsumed protocol steps"
        );
    }

    pub fn requests(&self) -> Vec<HttpRequest> {
        self.requests.lock().unwrap().clone()
    }
}

impl HttpTransport for TranscriptTransport {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        let (expected, response) =
            self.steps.lock().unwrap().pop_front().unwrap_or_else(|| {
                panic!("unexpected request {:?} {}", request.method, request.url)
            });
        assert_eq!(
            request.method, expected.method,
            "method for {}",
            expected.url
        );
        assert_eq!(request.url, expected.url, "request target");
        assert_eq!(
            request.headers, expected.headers,
            "headers for {}",
            expected.url
        );
        assert_eq!(request.body, expected.body, "form for {}", expected.url);
        assert_eq!(request.binary_body, expected.binary_body);
        assert_eq!(request.binary_response, expected.binary_response);
        assert_eq!(request.response_limit, expected.response_limit);
        self.requests.lock().unwrap().push(request);
        response
    }
}
