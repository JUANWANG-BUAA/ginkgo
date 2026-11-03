# 认证与会话（ginkgo_upstream::auth）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
登录页解析、表单提交、凭据与会话验证。

## 目录

- [cas](#cas) (14)
- [challenge](#challenge) (1)
- [iclass](#iclass) (1)
- [login](#login) (4)
- [mod](#mod) (13)
- [android_vault](#androidvault) (2)
- [keyring_vault](#keyringvault) (2)
- [mod](#mod) (2)
- [redirect](#redirect) (3)
- [automatic_route](#automaticroute) (9)
- [session](#session) (30)
- [uc](#uc) (5)
- [vault](#vault) (5)

## cas

- `pub fn extract_execution(html: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:43</sub>
- `pub fn extract_login_form_action(html: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:47</sub>
- `pub fn detect_captcha(html: &str) -> Option<CaptchaChallenge> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:51</sub>
- `pub fn captcha_image_url(id: &str) -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:61</sub>
- `pub fn text_captcha_supported(challenge: &CaptchaChallenge) -> bool {…}` — Only the documented local image/text form is understood. Other challenge
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:72</sub>
- `pub fn extract_tip_text(html: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:76</sub>
- `pub fn extract_error_text(html: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:80</sub>
- `pub fn is_access_policy_denied(html: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:84</sub>
- `pub fn is_password_expiry_page(html: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:89</sub>
- `pub fn is_login_redirect(final_url: &str, body: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:98</sub>
- `pub fn module_refusal(final_url: &str, body: &str) -> AppError {…}` — Classify a module answer that is not the expected payload.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:116</sub>
- `pub fn login_fields( html: &str, username: &str, password: &str, captcha_text: Option<&str>, ) -> Vec<(String, String)> {…}` — Follow UBAA's normal-form input selection and eight-field captcha branch.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:126</sub>
- `pub(crate) fn captcha_login_fields( username: &str, password: &str, execution: &str, captcha: &str, ) -> Vec<(String, String)> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:198</sub>
- `pub fn form_urlencode(fields: &[(String, String)]) -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:219</sub>

## challenge

- `pub(crate) async fn image<T: HttpTransport>( session: &Session<T>, id: &str, ) -> Result<Vec<u8>, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/challenge.rs:8</sub>

## iclass

- `pub struct IClassSession` — Short-lived iclass app session. It never leaves Rust and is never logged.
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/iclass.rs:4</sub>
    - `user_id: String`  <sub>:5</sub>
    - `session_id: String`  <sub>:6</sub>

## login

- `pub async fn fetch_login_page<T: HttpTransport>( session: &Session<T>, ) -> Result<LoginPage, AppError> {…}` — Fetch the CAS login page without automatic redirects.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:9</sub>
- `pub(super) async fn fetch_login_page_with_execution<T: HttpTransport>( session: &Session<T>, supplied_execution: Option<&str>, ) -> Result<LoginPage, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:15</sub>
- `pub(crate) async fn follow_redirects_and_check_error<T: HttpTransport>( session: &Session<T>, mut response: HttpResponse, mut current_url: String, ) -> Result<(), AppError> {…}` — Consume the submitted CAS chain before UC activation. Match UBAA's order:
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:45</sub>
- `pub(crate) fn validate_login_action(action: &str) -> Result<(), AppError> {…}` — Password-expiry execution tokens may only return to CAS over HTTPS on the
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:127</sub>

## mod

- `pub const LOGIN_URL: &str = "https://sso.buaa.edu.cn/login";`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/mod.rs:30</sub>
- `pub const UC_ACTIVATION_URL: &str = "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin";`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/mod.rs:31</sub>
- `pub const UC_STATUS_URL: &str = "https://uc.buaa.edu.cn/api/uc/status";`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/mod.rs:33</sub>
- `pub struct Credentials`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/mod.rs:36</sub>
    - `username: String`  <sub>:37</sub>
    - `password: String`  <sub>:38</sub>
    - `captcha_text: Option<String>`  <sub>:39</sub>
- `pub trait CredentialSource: Send + Sync` — Read-only credential port used by recovery paths.
  <sub>trait · rust/crates/ginkgo_upstream/src/auth/mod.rs:43</sub>
    - `fn load(&self, account: &str) -> Result<Option<Credentials>, AppError>;`  <sub>:44</sub>
- `pub trait CredentialVault: CredentialSource + 'static` — Platform secure-storage port. Implementations wrap the Android Keystore or
  <sub>trait · rust/crates/ginkgo_upstream/src/auth/mod.rs:49</sub>
    - `fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError>;`  <sub>:50</sub>
    - `fn delete(&self, account: &str) -> Result<(), AppError>;`  <sub>:51</sub>
    - `fn accounts(&self) -> Result<Vec<String>, AppError>;`  <sub>:52</sub>
    - `fn save_session(&self, _session: &PersistedSession) -> Result<(), AppError> {…}` — Session cookies use a separate encrypted record from optional saved  <sub>:56</sub>
    - `fn load_session(&self) -> Result<Option<PersistedSession>, AppError> {…}`  <sub>:59</sub>
    - `fn delete_session(&self) -> Result<(), AppError> {…}`  <sub>:62</sub>
    - `fn has_session(&self) -> Result<bool, AppError> {…}`  <sub>:65</sub>
- `pub enum LoginPage`
  <sub>enum · rust/crates/ginkgo_upstream/src/auth/mod.rs:73</sub>
- `pub enum LoginResult`
  <sub>enum · rust/crates/ginkgo_upstream/src/auth/mod.rs:84</sub>
- `pub async fn login<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, ) -> Result<LoginResult, AppError> {…}` — Complete the documented CAS → UC chain. A captcha challenge is returned
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:96</sub>
- `pub async fn complete_login<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, page: LoginPage, ) -> Result<LoginResult, AppError> {…}` — Resume a prepared login. UBAA fetches the login endpoint again before a
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:106</sub>
- `pub(crate) fn directory_unavailable(error: &AppError) -> bool {…}` — Transient reachability failures may preserve an already verified identity.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:224</sub>
- `pub async fn login_with_store<T: HttpTransport, C: CredentialSource + ?Sized>( session: &Session<T>, store: &C, account: &str, ) -> Result<LoginResult, AppError> {…}` — Load credentials from the platform vault, then log in. This is the only
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:233</sub>
- `pub async fn establish_webvpn_session<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, ) -> Result<(), AppError> {…}` — Explicitly establish a WebVPN session before routed campus traffic. The
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:244</sub>

## android_vault

- `pub struct AndroidVault;`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/platform/android_vault.rs:47</sub>
- `pub fn new() -> Result<Self, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/platform/android_vault.rs:50</sub>

## keyring_vault

- `pub struct KeyringVault`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/platform/keyring_vault.rs:16</sub>
- `pub fn new() -> Result<Self, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/platform/keyring_vault.rs:21</sub>

## mod

- `pub fn platform_vault() -> Result<PlatformVault, AppError> {…}` — Build the vault for the current platform. Android's JNI class handle is
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/platform/mod.rs:25</sub>
- `pub struct UnsupportedVault;`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/platform/mod.rs:30</sub>

## redirect

- `pub(crate) fn resolve_get(location: &str, base: &str) -> Result<String, AppError> {…}` — UC has been observed returning this exact legacy CAS login endpoint over
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/redirect.rs:8</sub>
- `pub(crate) fn resolve_navigation_get(location: &str, base: &str) -> Result<String, AppError> {…}` — Navigation itself does not classify CAS error queries. UBAA checks them
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/redirect.rs:16</sub>
- `pub(crate) fn reject_reported_error(target: &str) -> Result<(), AppError> {…}` — A reported authentication error is not a successful service redirect.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/redirect.rs:42</sub>

## automatic_route

- `pub(super) type VerifiedRouteHandler = dyn Fn(&str, u64, &UserProfile) -> bool + Send + Sync;`
  <sub>type · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:10</sub>
- `pub(super) struct AutomaticRouteOwner`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:13</sub>
- `pub(super) struct AutomaticRouteState`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:19</sub>
    - `epoch: u64`  <sub>:20</sub>
    - `webvpn_revision: u64`  <sub>:21</sub>
- `pub fn revoke(&mut self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:28</sub>
- `pub(super) fn can_migrate( request: &HttpRequest, response: &Result<HttpResponse, AppError>, ) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:35</sub>
- `pub(crate) fn set_verified_route_handler( &self, handler: impl Fn(&str, u64, &UserProfile) -> bool + Send + Sync + 'static, ) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:73</sub>
- `pub(crate) fn allow_automatic_business_route(&self, account: String, generation: u64) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:80</sub>
- `pub(super) fn route_attempt(&self) -> (RouteMode, u64, Option<AutomaticRouteOwner>) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:93</sub>
- `pub(super) async fn verified_business_fallback( &self, request: HttpRequest, attempted_epoch: u64, owner: AutomaticRouteOwner, ) -> Result<HttpResponse, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session/automatic_route.rs:98</sub>

## session

- `pub(crate) type CookiePersistFuture = Pin<Box<dyn Future<Output = ()> + Send>>;`
  <sub>type · rust/crates/ginkgo_upstream/src/auth/session.rs:20</sub>
- `pub enum RouteMode`
  <sub>enum · rust/crates/ginkgo_upstream/src/auth/session.rs:27</sub>
- `pub struct SessionCookies` — Rust-only snapshot of the isolated cookie jars. It is serialized only into
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session.rs:37</sub>
    - `direct: CookieJar`  <sub>:38</sub>
    - `webvpn: CookieJar`  <sub>:39</sub>
- `pub struct PersistedSession` — Encrypted, bounded restore record. A short hard lifetime prevents session
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session.rs:46</sub>
    - `schema_version: u8`  <sub>:47</sub>
    - `account: String`  <sub>:48</sub>
    - `profile_name: String`  <sub>:49</sub>
    - `route: RouteMode` — Actual authenticated route, independent from the UI's automatic choice.  <sub>:51</sub>
    - `saved_at_ms: i64`  <sub>:52</sub>
    - `cookies: SessionCookies`  <sub>:53</sub>
- `pub const MAX_AGE_MS: i64 = 24 * 60 * 60 * 1000;`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/session.rs:57</sub>
- `pub fn new( account: String, profile_name: String, route: RouteMode, cookies: SessionCookies, ) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:59</sub>
- `pub fn is_usable_for(&self, route: RouteMode, now_ms: i64) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:75</sub>
- `pub struct Session<T: HttpTransport>`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session.rs:92</sub>
- `pub(crate) struct RoutedTransport<'a, T>(&'a T);` — An authentication transaction may use a fixed route without changing the
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session.rs:105</sub>
- `pub fn new(transport: T) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:138</sub>
- `pub fn route(&self) -> RouteMode {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:151</sub>
- `pub fn transport(&self) -> &T {…}` — Read-only access to the injected transport, used by tests and adapters
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:157</sub>
- `pub fn set_route(&self, mode: RouteMode) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:161</sub>
- `pub(crate) fn pin_route(&self) -> RouteMode {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:170</sub>
- `pub(crate) fn routed(&self, mode: RouteMode) -> Session<RoutedTransport<'_, T>> where`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:180</sub>
- `pub fn activate_automatic_webvpn_fallback(&self) -> bool {…}` — Automatic route selection is available before the CAS form is pinned.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:203</sub>
- `pub fn clear_cookies(&self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:214</sub>
- `pub fn cookie_snapshot(&self) -> SessionCookies {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:221</sub>
- `pub fn restore_cookies(&self, cookies: SessionCookies) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:228</sub>
- `pub(crate) fn set_cookie_persistor( &self, persistor: impl Fn(SessionCookies) -> Option<CookiePersistFuture> + Send + Sync + 'static, ) {…}` — Install an owner-aware persistence callback. Public reads create an
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:237</sub>
- `pub fn poison_events(&self) -> u64 {…}` — How often one of the cookie-jar locks was recovered from a poisoned
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:265</sub>
- `pub fn webvpn_cookie_present(&self) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:269</sub>
- `pub fn direct_cookie_present(&self) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:273</sub>
- `pub async fn send_direct(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {…}` — CGYY is direct-only. Never mutate the shared route across an await.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:278</sub>
- `pub(crate) fn cgyy_sso_token(&self) -> Option<String> {…}` — Rust-only access for CGYY's documented SSO cookie; never bridged to Dart.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:283</sub>
- `pub async fn send(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:295</sub>
- `pub async fn send_following_redirects( &self, request: HttpRequest, ) -> Result<HttpResponse, AppError> {…}` — Follow browser-style redirects for a safe GET. Business systems such as
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:303</sub>
- `pub async fn send_anonymous( &self, request: HttpRequest, _preference: RouteMode, ) -> Result<HttpResponse, AppError>` — Make an anonymous request without exposing or modifying the signed-in
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:340</sub>
- `pub async fn send_with_fallback(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {…}` — Send once, then retry a safe GET once through WebVPN when automatic
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:355</sub>
- `pub async fn send_auth(&self, mut request: HttpRequest) -> Result<HttpResponse, AppError> {…}` — Authentication GETs may probe WebVPN once after a direct failure.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:387</sub>

## uc

- `pub async fn activate_uc<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:9</sub>
- `pub async fn validate_session<T: HttpTransport>( session: &Session<T>, ) -> Result<UserProfile, AppError> {…}` — UC status is the only proof that the login chain produced a usable
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:31</sub>
- `pub(super) fn status_request() -> HttpRequest {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:37</sub>
- `pub(super) fn validate_response(response: HttpResponse) -> Result<UserProfile, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:46</sub>
- `pub fn parse_uc_status(body: &str) -> Result<UserProfile, AppError> {…}` — Parse the UC status body. Structure changes are errors, never an implicit
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:60</sub>

## vault

- `pub struct MemoryVault`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/vault.rs:12</sub>
- `pub fn with(account: &str, credentials: Credentials) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:18</sub>
- `pub fn names(&self) -> Vec<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:24</sub>
- `pub fn verify_vault_round_trip<V: CredentialVault + ?Sized>( vault: &V, account: &str, secret: &str, ) -> bool {…}` — Write, read back and remove one synthetic credential. The reserved prefix
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:73</sub>
- `pub(crate) fn sanitized(credentials: &Credentials) -> Credentials {…}` — Captcha answers are one-time and must never be persisted.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:100</sub>
