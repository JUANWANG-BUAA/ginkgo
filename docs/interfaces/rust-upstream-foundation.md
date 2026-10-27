# 上游基础能力（ginkgo_upstream）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

HTTP 传输、Cookie、路由与错误映射。

## endpoints

- `pub(crate) const HOMEWORK_PORTAL: &str = "https://spoc.buaa.edu.cn/spocnew/";` — Official browser destinations supplied by the school integration.  
  <sub>rust/crates/ginkgo_upstream/src/endpoints.rs:2</sub>
- `pub(crate) static NOTICE_PAGE: LazyLock<url::Url> = LazyLock::new(\|\| { url::Url::parse("https://news.buaa.edu.cn/tzgg.htm").expect("constant notice U…`  
  <sub>rust/crates/ginkgo_upstream/src/endpoints.rs:5</sub>

## cookie

- `pub struct Cookie {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:10</sub>
    - `name: String`  <sub>:11</sub>
    - `value: String`  <sub>:12</sub>
    - `domain: String`  <sub>:13</sub>
    - `host_only: bool`  <sub>:14</sub>
    - `path: String`  <sub>:15</sub>
    - `secure: bool`  <sub>:16</sub>
    - `http_only: bool`  <sub>:17</sub>
    - `expires_at_ms: Option<i64>`  <sub>:18</sub>
- `pub fn is_expired(&self, now_ms: i64) -> bool { self.expires_at_ms.is_some_and(\|expires\| expires <= now_ms) }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:24</sub>
- `pub struct CookieJar {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:49</sub>
- `pub fn new() -> Self { Self::default() }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:55</sub>
- `pub fn now_ms() -> i64 { SystemTime::now() .duration_since(UNIX_EPOCH) .map(\|duration\| duration.as_millis() as i64) .unwrap_or(0) }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:59</sub>
- `pub fn store(&mut self, request_url: &str, header: &str, now_ms: i64) { let Ok(url) = Url::parse(request_url) else { return; }; let Some(host) = url.…` — Store one `Set-Cookie` header received for `request_url`.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:67</sub>
- `pub fn header_for(&mut self, url: &str, now_ms: i64) -> Option<String> { let parsed = Url::parse(url).ok()?; self.cookies.retain(\|cookie\| !cookie.is_…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:172</sub>
- `pub fn cookie_value(&self, name: &str) -> Option<&str> { self.cookies .iter() .find(\|cookie\| cookie.name == name) .map(\|cookie\| cookie.value.as_str()…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:200</sub>
- `pub fn contains(&self, name: &str) -> bool { self.cookies.iter().any(\|cookie\| cookie.name == name) }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:207</sub>
- `pub fn len(&self) -> usize { self.cookies.len() }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:211</sub>
- `pub fn is_empty(&self) -> bool { self.cookies.is_empty() }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:215</sub>
- `pub fn clear(&mut self) { self.cookies.clear(); }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/cookie.rs:219</sub>

## http

- `pub enum HttpMethod {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:6</sub>
- `pub struct HttpRequest {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:12</sub>
    - `method: HttpMethod`  <sub>:13</sub>
    - `url: String`  <sub>:14</sub>
    - `headers: BTreeMap<String, String>`  <sub>:15</sub>
    - `body: Option<String>`  <sub>:16</sub>
    - `binary_body: Option<Vec<u8>>` — Raw bounded bytes, exclusive with body; routing must not re-encode them.  <sub>:18</sub>
    - `binary_response: bool` — Return exact attachment bytes instead of lossy text. No redirect following.  <sub>:20</sub>
    - `response_limit: Option<usize>`  <sub>:21</sub>
- `pub fn new(method: HttpMethod, url: impl Into<String>) -> Self { Self { method, url: url.into(), headers: BTreeMap::new(), body: None, binary_body: N…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:25</sub>
- `pub fn get(url: impl Into<String>) -> Self { Self::new(HttpMethod::Get, url) }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:37</sub>
- `pub fn post_form(url: impl Into<String>, body: impl Into<String>) -> Self { let mut request = Self::new(HttpMethod::Post, url); request.body = Some(b…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:41</sub>
- `pub fn header(mut self, name: &str, value: &str) -> Self { self.headers.insert(name.into(), value.into()); self }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:51</sub>
- `pub fn header_value(&self, name: &str) -> Option<&str> { self.headers .iter() .find(\|(key, _)\| key.eq_ignore_ascii_case(name)) .map(\|(_, value)\| valu…` — Case-insensitive header lookup, matching HTTP semantics.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:57</sub>
- `pub struct HttpResponse {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:66</sub>
    - `status: u16`  <sub>:67</sub>
    - `final_url: String` — URL of the response after any transport-level redirect handling.  <sub>:69</sub>
    - `headers: BTreeMap<String, String>` — Lowercase header names. Repeated headers keep the last value.  <sub>:71</sub>
    - `set_cookies: Vec<String>` — Raw `Set-Cookie` header values in arrival order.  <sub>:73</sub>
    - `body: String`  <sub>:74</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:75</sub>
- `pub fn new(status: u16, final_url: impl Into<String>, body: impl Into<String>) -> Self { Self { status, final_url: final_url.into(), headers: BTreeMa…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:79</sub>
- `pub fn with_header(mut self, name: &str, value: &str) -> Self { self.headers.insert(name.to_ascii_lowercase(), value.into()); self }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:90</sub>
- `pub fn with_set_cookie(mut self, value: impl Into<String>) -> Self { self.set_cookies.push(value.into()); self }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:95</sub>
- `pub fn header(&self, name: &str) -> Option<&str> { self.headers .get(&name.to_ascii_lowercase()) .map(String::as_str) }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:100</sub>
- `pub enum TransportError {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:108</sub>
- `pub trait HttpTransport {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/http.rs:112</sub>
    - `fn send( &self, request: HttpRequest, ) -> impl Future<Output = Result<HttpResponse, TransportError>> + Send;`  <sub>:113</sub>

## mutex

- `pub fn poison_events() -> u64 { POISON_EVENTS.load(Ordering::Relaxed) }` — How many poisoned locks were recovered across this crate.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:34</sub>
- `pub struct Guard<'a, T> {` — Guard returned by [`Mutex::lock`].  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:42</sub>
- `pub fn was_poisoned(&self) -> bool { self.poisoned }` — Whether this guard was acquired from a poisoned lock.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:52</sub>
- `pub struct Mutex<T> {` — A `std::sync::Mutex` that recovers from poisoning without losing data.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:71</sub>
- `pub const fn new(value: T) -> Self { Self { inner: StdMutex::new(value), poison_count: AtomicU64::new(0), } }`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:77</sub>
- `pub fn lock(&self) -> Guard<'_, T> { match self.inner.lock() { Ok(guard) => Guard { inner: guard, poisoned: false, }, Err(poisoned) => { let guard = …` — Acquire the lock.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:89</sub>
- `pub fn poison_count(&self) -> u64 { self.poison_count.load(Ordering::Relaxed) }` — How often this lock was recovered from a poisoned state.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:109</sub>
- `pub fn was_poisoned(&self) -> bool { self.poison_count() > 0 }` — Whether this lock was ever recovered from a poisoned state.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:114</sub>
- `pub fn lock_value<T: Copy>(mutex: &StdMutex<T>) -> MutexGuard<'_, T> { mutex.lock().unwrap_or_else(\|poisoned\| { let guard = poisoned.into_inner(); mu…` — Preserve a single Copy value (used for route enums) after poisoning.  
  <sub>rust/crates/ginkgo_upstream/src/foundation/mutex.rs:128</sub>

## webvpn

- `pub const GATEWAY_HOST: &str = "d.buaa.edu.cn";`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:8</sub>
- `pub fn should_route(url: &str) -> bool { let Ok(url) = Url::parse(url) else { return false; }; let Some(host) = url.host_str() else { return false; }…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:14</sub>
- `pub fn wrap(upstream: &str) -> Result<String, WebVpnError> { let url = Url::parse(upstream).map_err(\|_\| WebVpnError::InvalidUrl)?; let host = url.hos…`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:25</sub>
- `pub fn unwrap(gateway: &str) -> String { let Ok(url) = Url::parse(gateway) else { return gateway.to_string(); }; if !url .host_str() .is_some_and(\|ho…` — Unwrap a gateway URL. Gateway-owned paths that cannot be decoded are kept  
  <sub>rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:56</sub>
- `pub fn resolve_redirect(location: &str, base: &str) -> Option<String> { let location = location.trim(); if location.is_empty() { return None; } if Ur…` — Resolve a `Location` value that may be absolute, gateway-relative, or  
  <sub>rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:103</sub>
- `pub enum WebVpnError {`  
  <sub>rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:192</sub>

## test_support

- `pub struct MockTransport {`  
  <sub>rust/crates/ginkgo_upstream/src/test_support.rs:9</sub>
- `pub fn with_responses(responses: Vec<HttpResponse>) -> Self { Self::with_results(responses.into_iter().map(Ok).collect()) }`  
  <sub>rust/crates/ginkgo_upstream/src/test_support.rs:20</sub>
- `pub fn with_results(results: Vec<Result<HttpResponse, TransportError>>) -> Self { let transport = Self::default(); transport .state .responses .lock(…` — Scripted results let a test inject a transport failure inside an  
  <sub>rust/crates/ginkgo_upstream/src/test_support.rs:26</sub>
- `pub fn requests(&self) -> Vec<HttpRequest> { self.state.requests.lock().expect("request lock").clone() }`  
  <sub>rust/crates/ginkgo_upstream/src/test_support.rs:37</sub>
- `pub fn request_count(&self) -> usize { self.state.requests.lock().expect("request lock").len() }`  
  <sub>rust/crates/ginkgo_upstream/src/test_support.rs:41</sub>
