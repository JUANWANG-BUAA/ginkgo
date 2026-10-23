//! Production HTTP transport. Redirects stay manual so the authentication
//! chain can inspect every hop; cookies are injected by `auth::session`.
use crate::foundation::http::{
    HttpMethod, HttpRequest, HttpResponse, HttpTransport, TransportError,
};
use reqwest::{redirect::Policy, Client, Method};
use std::{collections::BTreeMap, future::Future, time::Duration};
use tokio::runtime::{Builder, Runtime};

const USER_AGENT: &str = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15";

/// The public catalogue host answers with an **incomplete chain**: it sends only
/// `CN=*.lib.buaa.edu.cn` and omits the issuing intermediate, which macOS and
/// browsers repair through AIA but a strict rustls client cannot (API §6.1).
///
/// The documented GlobalSign intermediate is therefore added **only to that
/// host's own client**. No other origin is verified against it, the built-in
/// trust store is untouched, and deleting this constant plus the certificate
/// asset reverts the behaviour completely.
const INCOMPLETE_CHAIN_HOST: &str = "space.lib.buaa.edu.cn";
const INCOMPLETE_CHAIN_INTERMEDIATE: &[u8] =
    include_bytes!("../../../../certs/globalsign_gcc_r3_dv_tls_ca_2020.pem");

fn builder() -> reqwest::ClientBuilder {
    Client::builder()
        .redirect(Policy::none())
        // Bound unreachable DNS/TCP/TLS before a safe read can route-fallback.
        .connect_timeout(Duration::from_secs(6))
        .timeout(Duration::from_secs(30))
        .user_agent(USER_AGENT)
}

pub struct ReqwestTransport {
    client: Client,
    /// Only used for [`INCOMPLETE_CHAIN_HOST`]; every other host uses `client`.
    scoped_client: Option<Client>,
    runtime: Runtime,
}

impl ReqwestTransport {
    pub fn new() -> Result<Self, TransportError> {
        let client = builder().build().map_err(|_| TransportError::Unavailable)?;
        let scoped_client = reqwest::Certificate::from_pem(INCOMPLETE_CHAIN_INTERMEDIATE)
            .ok()
            .and_then(|anchor| builder().add_root_certificate(anchor).build().ok());
        let runtime = Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .build()
            .map_err(|_| TransportError::Unavailable)?;
        Ok(Self {
            client,
            scoped_client,
            runtime,
        })
    }

    /// Extra trust never leaks: an unrelated host always gets the default client.
    fn client_for(&self, url: &str) -> Client {
        let is_scoped = url::Url::parse(url)
            .ok()
            .and_then(|parsed| parsed.host_str().map(str::to_owned))
            .is_some_and(|host| host.eq_ignore_ascii_case(INCOMPLETE_CHAIN_HOST));
        match (is_scoped, self.scoped_client.as_ref()) {
            (true, Some(scoped)) => scoped.clone(),
            _ => self.client.clone(),
        }
    }
}

impl HttpTransport for ReqwestTransport {
    fn send(
        &self,
        request: HttpRequest,
    ) -> impl Future<Output = Result<HttpResponse, TransportError>> + Send {
        let client = self.client_for(&request.url);
        let handle = self.runtime.handle().clone();
        async move {
            let task = handle.spawn(execute(client, request));
            // Dropping a timed-out read must also stop its HTTP task, otherwise
            // repeated refreshes accumulate orphan work on the private runtime.
            let _abort = AbortOnDrop(task.abort_handle());
            task.await.map_err(|_| TransportError::Unavailable)?
        }
    }
}

struct AbortOnDrop(tokio::task::AbortHandle);
impl Drop for AbortOnDrop {
    fn drop(&mut self) {
        self.0.abort();
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
