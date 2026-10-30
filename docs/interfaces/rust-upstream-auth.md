# 认证与会话（ginkgo_upstream::auth）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
登录页解析、表单提交、凭据与会话验证。

## 目录

- [cas](#cas) (13)
- [challenge](#challenge) (1)
- [iclass](#iclass) (1)
- [login](#login) (3)
- [mod](#mod) (12)
- [android_vault](#androidvault) (2)
- [keyring_vault](#keyringvault) (2)
- [mod](#mod) (2)
- [redirect](#redirect) (1)
- [session](#session) (17)
- [uc](#uc) (3)
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
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:69</sub>
- `pub fn extract_tip_text(html: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:73</sub>
- `pub fn extract_error_text(html: &str) -> Option<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:79</sub>
- `pub fn is_access_policy_denied(html: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:86</sub>
- `pub fn is_password_expiry_page(html: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:91</sub>
- `pub fn is_login_redirect(final_url: &str, body: &str) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:99</sub>
- `pub fn module_refusal(final_url: &str, body: &str) -> AppError {…}` — Classify a module answer that is not the expected payload.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:117</sub>
- `pub fn login_fields( html: &str, username: &str, password: &str, captcha_text: Option<&str>, ) -> Vec<(String, String)> {…}` — Build the CAS form from the page's hidden inputs. The `+` and `/` in the
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:127</sub>
- `pub fn form_urlencode(fields: &[(String, String)]) -> String {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/cas.rs:167</sub>

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
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:12</sub>
- `pub(crate) async fn follow_redirects_and_check_error<T: HttpTransport>( session: &Session<T>, mut response: HttpResponse, mut current_url: String, ) -> Result<(), AppError> {…}` — Follow up to ten redirects, classifying each hop before requesting the
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:60</sub>
- `pub(crate) fn validate_login_action(action: &str) -> Result<(), AppError> {…}` — The password POST target must be the documented CAS endpoint over HTTPS on
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/login.rs:135</sub>

## mod

- `pub const LOGIN_URL: &str = "https://sso.buaa.edu.cn/login";`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/mod.rs:29</sub>
- `pub const UC_ACTIVATION_URL: &str = "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin";`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/mod.rs:30</sub>
- `pub const UC_STATUS_URL: &str = "https://uc.buaa.edu.cn/api/uc/status";`
  <sub>const · rust/crates/ginkgo_upstream/src/auth/mod.rs:32</sub>
- `pub struct Credentials`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/mod.rs:35</sub>
    - `username: String`  <sub>:36</sub>
    - `password: String`  <sub>:37</sub>
    - `captcha_text: Option<String>`  <sub>:38</sub>
- `pub trait CredentialSource: Send + Sync` — Read-only credential port used by recovery paths.
  <sub>trait · rust/crates/ginkgo_upstream/src/auth/mod.rs:42</sub>
    - `fn load(&self, account: &str) -> Result<Option<Credentials>, AppError>;`  <sub>:43</sub>
- `pub trait CredentialVault: CredentialSource` — Platform secure-storage port. Implementations wrap the Android Keystore or
  <sub>trait · rust/crates/ginkgo_upstream/src/auth/mod.rs:48</sub>
    - `fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError>;`  <sub>:49</sub>
    - `fn delete(&self, account: &str) -> Result<(), AppError>;`  <sub>:50</sub>
    - `fn accounts(&self) -> Result<Vec<String>, AppError>;`  <sub>:51</sub>
- `pub enum LoginPage`
  <sub>enum · rust/crates/ginkgo_upstream/src/auth/mod.rs:57</sub>
- `pub enum LoginResult`
  <sub>enum · rust/crates/ginkgo_upstream/src/auth/mod.rs:70</sub>
- `pub async fn login<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, ) -> Result<LoginResult, AppError> {…}` — Complete the documented CAS → UC chain. A captcha challenge is returned
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:77</sub>
- `pub async fn complete_login<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, page: LoginPage, ) -> Result<LoginResult, AppError> {…}` — Finish a login from an already fetched page. Keeping the page lets a
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:88</sub>
- `pub async fn login_with_store<T: HttpTransport, C: CredentialSource + ?Sized>( session: &Session<T>, store: &C, account: &str, ) -> Result<LoginResult, AppError> {…}` — Load credentials from the platform vault, then log in. This is the only
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:157</sub>
- `pub async fn establish_webvpn_session<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, ) -> Result<(), AppError> {…}` — Explicitly establish a WebVPN session before routed campus traffic. The
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/mod.rs:168</sub>

## android_vault

- `pub struct AndroidVault;`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/platform/android_vault.rs:45</sub>
- `pub fn new() -> Result<Self, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/platform/android_vault.rs:48</sub>

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

## session

- `pub enum RouteMode`
  <sub>enum · rust/crates/ginkgo_upstream/src/auth/session.rs:16</sub>
- `pub struct Session<T: HttpTransport>`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/session.rs:22</sub>
- `pub fn new(transport: T) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:51</sub>
- `pub fn route(&self) -> RouteMode {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:60</sub>
- `pub fn transport(&self) -> &T {…}` — Read-only access to the injected transport, used by tests and adapters
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:66</sub>
- `pub fn set_route(&self, mode: RouteMode) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:70</sub>
- `pub fn activate_automatic_webvpn_fallback(&self) -> bool {…}` — Automatic mode remembers the first confirmed access-policy block and
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:76</sub>
- `pub fn clear_cookies(&self) {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:85</sub>
- `pub fn poison_events(&self) -> u64 {…}` — How often one of the cookie-jar locks was recovered from a poisoned
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:93</sub>
- `pub fn webvpn_cookie_present(&self) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:97</sub>
- `pub fn direct_cookie_present(&self) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:101</sub>
- `pub async fn send_direct(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {…}` — CGYY is direct-only. Never mutate the shared route across an await.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:106</sub>
- `pub(crate) fn cgyy_sso_token(&self) -> Option<String> {…}` — Rust-only access for CGYY's documented SSO cookie; never bridged to Dart.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:111</sub>
- `pub async fn send(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:123</sub>
- `pub async fn send_following_redirects( &self, request: HttpRequest, ) -> Result<HttpResponse, AppError> {…}` — Follow browser-style redirects for a safe GET. Business systems such as
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:131</sub>
- `pub async fn send_anonymous( &self, request: HttpRequest, preference: RouteMode, ) -> Result<HttpResponse, AppError>` — Make an anonymous request without exposing or modifying the signed-in
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:156</sub>
- `pub async fn send_with_fallback(&self, request: HttpRequest) -> Result<HttpResponse, AppError> {…}` — Send once, then retry a safe GET once through WebVPN when automatic
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/session.rs:177</sub>

## uc

- `pub async fn activate_uc<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:9</sub>
- `pub async fn validate_session<T: HttpTransport>( session: &Session<T>, ) -> Result<UserProfile, AppError> {…}` — UC status is the only proof that the login chain produced a usable
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:34</sub>
- `pub fn parse_uc_status(body: &str) -> Result<UserProfile, AppError> {…}` — Parse the UC status body. Structure changes are errors, never an implicit
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/uc.rs:54</sub>

## vault

- `pub struct MemoryVault`
  <sub>struct · rust/crates/ginkgo_upstream/src/auth/vault.rs:12</sub>
- `pub fn with(account: &str, credentials: Credentials) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:17</sub>
- `pub fn names(&self) -> Vec<String> {…}`
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:23</sub>
- `pub fn verify_vault_round_trip<V: CredentialVault + ?Sized>( vault: &V, account: &str, secret: &str, ) -> bool {…}` — Write, read back and remove one synthetic credential. The reserved prefix
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:54</sub>
- `pub(crate) fn sanitized(credentials: &Credentials) -> Credentials {…}` — Captcha answers are one-time and must never be persisted.
  <sub>fn · rust/crates/ginkgo_upstream/src/auth/vault.rs:81</sub>
