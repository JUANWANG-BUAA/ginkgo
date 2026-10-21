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
