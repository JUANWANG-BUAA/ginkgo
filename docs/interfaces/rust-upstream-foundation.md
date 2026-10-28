# 上游基础能力（ginkgo_upstream）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
HTTP 传输、Cookie、路由与错误映射。

## endpoints

- `pub(crate) const HOMEWORK_PORTAL: &str = "https://spoc.buaa.edu.cn/spocnew/";` — Official browser destinations supplied by the school integration.
  <sub>const · rust/crates/ginkgo_upstream/src/endpoints.rs:2</sub>
- `pub(crate) static NOTICE_PAGE: LazyLock<url::Url> = LazyLock::new(\|\| { url::Url::parse( … ews.buaa.edu.cn/tzgg.htm").expect("constant notice URL") });`
  <sub>static · rust/crates/ginkgo_upstream/src/endpoints.rs:5</sub>

## cookie

- `pub struct Cookie`
  <sub>struct · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:10</sub>
    - `name: String`  <sub>:11</sub>
    - `value: String`  <sub>:12</sub>
    - `domain: String`  <sub>:13</sub>
    - `host_only: bool`  <sub>:14</sub>
    - `path: String`  <sub>:15</sub>
    - `secure: bool`  <sub>:16</sub>
    - `http_only: bool`  <sub>:17</sub>
    - `expires_at_ms: Option<i64>`  <sub>:18</sub>
- `pub fn is_expired(&self, now_ms: i64) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:24</sub>
- `pub struct CookieJar`
  <sub>struct · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:49</sub>
- `pub fn new() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:55</sub>
- `pub fn now_ms() -> i64 {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:59</sub>
- `pub fn store(&mut self, request_url: &str, header: &str, now_ms: i64) {…}` — Store one `Set-Cookie` header received for `request_url`.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:67</sub>
- `pub fn header_for(&mut self, url: &str, now_ms: i64) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:172</sub>
- `pub fn cookie_value(&self, name: &str) -> Option<&str> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:200</sub>
- `pub fn contains(&self, name: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:207</sub>
- `pub fn len(&self) -> usize {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:211</sub>
- `pub fn is_empty(&self) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:215</sub>
- `pub fn clear(&mut self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/cookie.rs:219</sub>

## http

- `pub enum HttpMethod`
  <sub>enum · rust/crates/ginkgo_upstream/src/foundation/http.rs:6</sub>
- `pub struct HttpRequest`
  <sub>struct · rust/crates/ginkgo_upstream/src/foundation/http.rs:12</sub>
    - `method: HttpMethod`  <sub>:13</sub>
    - `url: String`  <sub>:14</sub>
    - `headers: BTreeMap<String, String>`  <sub>:15</sub>
    - `body: Option<String>`  <sub>:16</sub>
    - `binary_body: Option<Vec<u8>>` — Raw bounded bytes, exclusive with body; routing must not re-encode them.  <sub>:18</sub>
    - `binary_response: bool` — Return exact attachment bytes instead of lossy text. No redirect following.  <sub>:20</sub>
    - `response_limit: Option<usize>`  <sub>:21</sub>
- `pub fn new(method: HttpMethod, url: impl Into<String>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:25</sub>
- `pub fn get(url: impl Into<String>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:37</sub>
- `pub fn post_form(url: impl Into<String>, body: impl Into<String>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:41</sub>
- `pub fn header(mut self, name: &str, value: &str) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:51</sub>
- `pub fn header_value(&self, name: &str) -> Option<&str> {…}` — Case-insensitive header lookup, matching HTTP semantics.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:57</sub>
- `pub struct HttpResponse`
  <sub>struct · rust/crates/ginkgo_upstream/src/foundation/http.rs:66</sub>
    - `status: u16`  <sub>:67</sub>
    - `final_url: String` — URL of the response after any transport-level redirect handling.  <sub>:69</sub>
    - `headers: BTreeMap<String, String>` — Lowercase header names. Repeated headers keep the last value.  <sub>:71</sub>
    - `set_cookies: Vec<String>` — Raw `Set-Cookie` header values in arrival order.  <sub>:73</sub>
    - `body: String`  <sub>:74</sub>
    - `bytes: Option<Vec<u8>>`  <sub>:75</sub>
- `pub fn new(status: u16, final_url: impl Into<String>, body: impl Into<String>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:79</sub>
- `pub fn with_header(mut self, name: &str, value: &str) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:90</sub>
- `pub fn with_set_cookie(mut self, value: impl Into<String>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:95</sub>
- `pub fn header(&self, name: &str) -> Option<&str> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/http.rs:100</sub>
- `pub enum TransportError`
  <sub>enum · rust/crates/ginkgo_upstream/src/foundation/http.rs:108</sub>
- `pub trait HttpTransport`
  <sub>trait · rust/crates/ginkgo_upstream/src/foundation/http.rs:112</sub>
    - `fn send( &self, request: HttpRequest, ) -> Future<Result<HttpResponse, TransportError>>;`  <sub>:113</sub>

## mutex

- `pub fn poison_events() -> u64 {…}` — How many poisoned locks were recovered across this crate.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:34</sub>
- `pub struct Guard<'a, T>` — Guard returned by [`Mutex::lock`].
  <sub>struct · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:42</sub>
- `pub fn was_poisoned(&self) -> bool {…}` — Whether this guard was acquired from a poisoned lock.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:52</sub>
- `pub struct Mutex<T>` — A `std::sync::Mutex` that recovers from poisoning without losing data.
  <sub>struct · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:71</sub>
- `pub const fn new(value: T) -> Self { Self { inner: StdMutex::new(value), poison_count: AtomicU64::new(0), } }`
  <sub>const · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:77</sub>
- `pub fn lock(&self) -> Guard<'_, T> {…}` — Acquire the lock.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:89</sub>
- `pub fn poison_count(&self) -> u64 {…}` — How often this lock was recovered from a poisoned state.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:109</sub>
- `pub fn was_poisoned(&self) -> bool {…}` — Whether this lock was ever recovered from a poisoned state.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:114</sub>
- `pub fn lock_value<T: Copy>(mutex: &StdMutex<T>) -> MutexGuard<'_, T> {…}` — Preserve a single Copy value (used for route enums) after poisoning.
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/mutex.rs:128</sub>

## webvpn

- `pub const GATEWAY_HOST: &str = "d.buaa.edu.cn";`
  <sub>const · rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:8</sub>
- `pub fn should_route(url: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:14</sub>
- `pub fn wrap(upstream: &str) -> Result<String, WebVpnError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:25</sub>
- `pub fn unwrap(gateway: &str) -> String {…}` — Unwrap a gateway URL. Gateway-owned paths that cannot be decoded are kept
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:56</sub>
- `pub fn resolve_redirect(location: &str, base: &str) -> Option<String> {…}` — Resolve a `Location` value that may be absolute, gateway-relative, or
  <sub>fn · rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:103</sub>
- `pub enum WebVpnError`
  <sub>enum · rust/crates/ginkgo_upstream/src/foundation/webvpn.rs:192</sub>

## test_support

- `pub struct MockTransport`
  <sub>struct · rust/crates/ginkgo_upstream/src/test_support.rs:9</sub>
- `pub fn with_responses(responses: Vec<HttpResponse>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/test_support.rs:20</sub>
- `pub fn with_results(results: Vec<Result<HttpResponse, TransportError>>) -> Self {…}` — Scripted results let a test inject a transport failure inside an
  <sub>fn · rust/crates/ginkgo_upstream/src/test_support.rs:26</sub>
- `pub fn requests(&self) -> Vec<HttpRequest> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/test_support.rs:37</sub>
- `pub fn request_count(&self) -> usize {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/test_support.rs:41</sub>
