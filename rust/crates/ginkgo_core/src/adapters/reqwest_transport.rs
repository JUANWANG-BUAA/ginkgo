//! Production HTTP transport. Redirects stay manual so the authentication
//! chain can inspect every hop; cookies are injected by `auth::session`.
use crate::foundation::http::{
    HttpMethod, HttpRequest, HttpResponse, HttpTransport, TransportError,
};
use reqwest::{redirect::Policy, Client, Method};
use std::{collections::BTreeMap, future::Future, time::Duration};
use tokio::runtime::{Builder, Runtime};

const USER_AGENT: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";

pub struct ReqwestTransport {
    client: Client,
    runtime: Runtime,
}

impl ReqwestTransport {
    pub fn new() -> Result<Self, TransportError> {
        let client = Client::builder()
            .redirect(Policy::none())
            .timeout(Duration::from_secs(30))
            .user_agent(USER_AGENT)
            .build()
            .map_err(|_| TransportError::Unavailable)?;
        let runtime = Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .map_err(|_| TransportError::Unavailable)?;
        Ok(Self { client, runtime })
    }
}

impl HttpTransport for ReqwestTransport {
    fn send(
        &self,
        request: HttpRequest,
    ) -> impl Future<Output = Result<HttpResponse, TransportError>> + Send {
        let client = self.client.clone();
        let handle = self.runtime.handle().clone();
        async move {
            handle
                .spawn(execute(client, request))
                .await
                .map_err(|_| TransportError::Unavailable)?
        }
    }
}

async fn execute(client: Client, request: HttpRequest) -> Result<HttpResponse, TransportError> {
    let method = match request.method {
        HttpMethod::Get => Method::GET,
        HttpMethod::Post => Method::POST,
    };
    let mut builder = client.request(method, &request.url);
    for (name, value) in &request.headers {
        builder = builder.header(name, value);
    }
    if let Some(body) = request.body {
        builder = builder.body(body);
    }
    let response = builder
        .send()
        .await
        .map_err(|_| TransportError::Unavailable)?;
    let status = response.status().as_u16();
    let final_url = response.url().to_string();
    let mut headers = BTreeMap::new();
    let mut set_cookies = Vec::new();
    for (name, value) in response.headers() {
        let name = name.as_str().to_ascii_lowercase();
        let Ok(value) = value.to_str() else {
            continue;
        };
        if name == "set-cookie" {
            set_cookies.push(value.to_string());
        } else {
            headers.insert(name, value.to_string());
        }
    }
    let body = response
        .bytes()
        .await
        .map_err(|_| TransportError::Unavailable)?;
    Ok(HttpResponse {
        status,
        final_url,
        headers,
        set_cookies,
        body: String::from_utf8_lossy(&body).into_owned(),
    })
}
