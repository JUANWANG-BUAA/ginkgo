# 认证与会话（ginkgo_upstream::auth）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

登录页解析、表单提交、凭据与会话验证。

## cas

- `pub fn extract_execution(html: &str) -> Option<String> { first_group(&EXECUTION, html, 1) }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:41</sub>
- `pub fn extract_login_form_action(html: &str) -> Option<String> { first_group(&FORM_ACTION, html, 1).map(\|action\| decode_entities(action.trim())) }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:45</sub>
- `pub fn detect_captcha(html: &str) -> Option<CaptchaChallenge> { let captcha_type = first_group(&CAPTCHA, html, 1)?; let id = first_group(&CAPTCHA, ht…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:49</sub>
- `pub fn captcha_image_url(id: &str) -> String { let mut url = url::Url::parse("https://sso.buaa.edu.cn/captcha").expect("fixed URL"); url.query_pairs_…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:59</sub>
- `pub fn text_captcha_supported(challenge: &CaptchaChallenge) -> bool { challenge.captcha_type == "local" }` — Only the documented local image/text form is understood. Other challenge  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:67</sub>
- `pub fn extract_tip_text(html: &str) -> Option<String> { first_group(&TIP, html, 1) .map(\|text\| plain_text(&text)) .filter(\|text\| !text.is_empty()) }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:71</sub>
- `pub fn extract_error_text(html: &str) -> Option<String> { first_group(&ERROR, html, 1) .map(\|text\| plain_text(&text)) .filter(\|text\| !text.is_empty()…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:77</sub>
- `pub fn is_access_policy_denied(html: &str) -> bool { let compact = WHITESPACE.replace_all(html, " "); compact.contains("访问策略禁止") \|\| compact.contains(…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:84</sub>
- `pub fn is_password_expiry_page(html: &str) -> bool { extract_execution(html).is_some() && (html.contains("continueForm") \|\| html.contains("ignoreAndC…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:89</sub>
- `pub fn is_login_redirect(final_url: &str, body: &str) -> bool { if final_url.contains("sso.buaa.edu.cn") { return true; } body.chars() .take(5000) .c…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:97</sub>
- `pub fn login_fields( html: &str, username: &str, password: &str, captcha_text: Option<&str>, ) -> Vec<(String, String)> { let mut fields: Vec<(String…` — Build the CAS form from the page's hidden inputs. The `+` and `/` in the  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:109</sub>
- `pub fn form_urlencode(fields: &[(String, String)]) -> String { fields .iter() .map(\|(name, value)\| format!("{}={}", encode_component(name), encode_co…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/cas.rs:149</sub>

## challenge

- `pub(crate) async fn image<T: HttpTransport>( session: &Session<T>, id: &str, ) -> Result<Vec<u8>, AppError> { if id.is_empty() \|\| id.len() > 512 { re…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/challenge.rs:8</sub>

## iclass

- `pub struct IClassSession {` — Short-lived iclass app session. It never leaves Rust and is never logged.  
  <sub>rust/crates/ginkgo_upstream/src/auth/iclass.rs:4</sub>
    - `user_id: String`  <sub>:5</sub>
    - `session_id: String`  <sub>:6</sub>

## login

- `pub async fn fetch_login_page<T: HttpTransport>( session: &Session<T>, ) -> Result<LoginPage, AppError> { let mut url = LOGIN_URL.to_string(); for ho…` — Fetch the CAS login page without automatic redirects.  
  <sub>rust/crates/ginkgo_upstream/src/auth/login.rs:12</sub>
- `pub(crate) async fn follow_redirects_and_check_error<T: HttpTransport>( session: &Session<T>, mut response: HttpResponse, mut current_url: String, ) …` — Follow up to ten redirects, classifying each hop before requesting the  
  <sub>rust/crates/ginkgo_upstream/src/auth/login.rs:60</sub>
- `pub(crate) fn validate_login_action(action: &str) -> Result<(), AppError> { let parsed = url::Url::parse(action).map_err(\|_\| AppError::changed())?; l…` — The password POST target must be the documented CAS endpoint over HTTPS on  
  <sub>rust/crates/ginkgo_upstream/src/auth/login.rs:135</sub>

## mod

- `pub const LOGIN_URL: &str = "https://sso.buaa.edu.cn/login";`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:29</sub>
- `pub const UC_ACTIVATION_URL: &str = "https://uc.buaa.edu.cn/api/login?target=https%3A%2F%2Fuc.buaa.edu.cn%2F%23%2Fuser%2Flogin";`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:30</sub>
- `pub const UC_STATUS_URL: &str = "https://uc.buaa.edu.cn/api/uc/status";`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:32</sub>
- `pub const LOGOUT_URL: &str = "https://sso.buaa.edu.cn/logout";`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:33</sub>
- `pub struct Credentials {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:36</sub>
    - `username: String`  <sub>:37</sub>
    - `password: String`  <sub>:38</sub>
    - `captcha_text: Option<String>`  <sub>:39</sub>
- `pub trait CredentialSource: Send + Sync {` — Read-only credential port used by recovery paths.  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:43</sub>
    - `fn load(&self, account: &str) -> Result<Option<Credentials>, AppError>;`  <sub>:44</sub>
- `pub trait CredentialVault: CredentialSource {` — Platform secure-storage port. Implementations wrap the Android Keystore or  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:49</sub>
    - `fn save(&self, account: &str, credentials: &Credentials) -> Result<(), AppError>;`  <sub>:50</sub>
    - `fn delete(&self, account: &str) -> Result<(), AppError>;`  <sub>:51</sub>
    - `fn accounts(&self) -> Result<Vec<String>, AppError>;`  <sub>:52</sub>
- `pub enum LoginPage {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:58</sub>
- `pub enum LoginResult {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:71</sub>
- `pub async fn login<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, ) -> Result<LoginResult, AppError> { let page = fetch_login_pa…` — Complete the documented CAS → UC chain. A captcha challenge is returned  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:78</sub>
- `pub async fn complete_login<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, page: LoginPage, ) -> Result<LoginResult, AppError> {…` — Finish a login from an already fetched page. Keeping the page lets a  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:89</sub>
- `pub async fn login_with_store<T: HttpTransport, C: CredentialSource + ?Sized>( session: &Session<T>, store: &C, account: &str, ) -> Result<LoginResul…` — Load credentials from the platform vault, then log in. This is the only  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:158</sub>
- `pub async fn establish_webvpn_session<T: HttpTransport>( session: &Session<T>, credentials: &Credentials, ) -> Result<(), AppError> { session.set_rou…` — Explicitly establish a WebVPN session before routed campus traffic. The  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:169</sub>
- `pub async fn logout<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> { let result = session.send(HttpRequest::get(LOGOUT_URL)).await; …` — Logout is best-effort: callers must clear local state even when upstream  
  <sub>rust/crates/ginkgo_upstream/src/auth/mod.rs:186</sub>

## android_vault

- `pub struct AndroidVault;`  
  <sub>rust/crates/ginkgo_upstream/src/auth/platform/android_vault.rs:45</sub>
- `pub fn new() -> Result<Self, AppError> { Ok(Self) }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/platform/android_vault.rs:48</sub>

## keyring_vault

- `pub struct KeyringVault {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/platform/keyring_vault.rs:16</sub>
- `pub fn new() -> Result<Self, AppError> { Ok(Self { index_lock: Mutex::new(()), }) }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/platform/keyring_vault.rs:21</sub>

## mod

- `pub fn platform_vault() -> Result<PlatformVault, AppError> { PlatformVault::new() }` — Build the vault for the current platform. Android's JNI class handle is  
  <sub>rust/crates/ginkgo_upstream/src/auth/platform/mod.rs:25</sub>
- `pub struct UnsupportedVault;`  
  <sub>rust/crates/ginkgo_upstream/src/auth/platform/mod.rs:30</sub>

## redirect

- `pub(crate) fn resolve_get(location: &str, base: &str) -> Result<String, AppError> { let target = webvpn::resolve_redirect(location, base).ok_or_else(…` — UC has been observed returning this exact legacy CAS login endpoint over  
  <sub>rust/crates/ginkgo_upstream/src/auth/redirect.rs:8</sub>

## session

- `pub enum RouteMode {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:16</sub>
- `pub struct Session<T: HttpTransport> {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:22</sub>
- `pub fn new(transport: T) -> Self { Self { transport, route: StdMutex::new(RouteMode::Automatic), direct_jar: Mutex::new(CookieJar::new()), webvpn_jar…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:30</sub>
- `pub fn route(&self) -> RouteMode { *lock_value(&self.route) }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:39</sub>
- `pub fn transport(&self) -> &T { &self.transport }` — Read-only access to the injected transport, used by tests and adapters  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:45</sub>
- `pub fn set_route(&self, mode: RouteMode) { *lock_value(&self.route) = mode; }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:49</sub>
- `pub fn activate_automatic_webvpn_fallback(&self) -> bool { let mut route = lock_value(&self.route); if *route != RouteMode::Automatic { return false;…` — Automatic mode remembers the first confirmed access-policy block and  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:55</sub>
- `pub fn clear_cookies(&self) { self.direct_jar.lock().clear(); self.webvpn_jar.lock().clear(); }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:64</sub>
- `pub fn poison_events(&self) -> u64 { self.direct_jar.poison_count() + self.webvpn_jar.poison_count() }` — How often one of the cookie-jar locks was recovered from a poisoned  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:72</sub>
- `pub fn webvpn_cookie_present(&self) -> bool { !self.webvpn_jar.lock().is_empty() }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:76</sub>
- `pub fn direct_cookie_present(&self) -> bool { !self.direct_jar.lock().is_empty() }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:80</sub>
- `pub async fn send_direct(&self, request: HttpRequest) -> Result<HttpResponse, AppError> { self.send_routed(request, RouteMode::Direct).await }` — CGYY is direct-only. Never mutate the shared route across an await.  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:85</sub>
- `pub(crate) fn cgyy_sso_token(&self) -> Option<String> { let header = self.direct_jar.lock().header_for( "https://cgyy.buaa.edu.cn/venue-zhjs-server/"…` — Rust-only access for CGYY's documented SSO cookie; never bridged to Dart.  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:90</sub>
- `pub async fn send(&self, request: HttpRequest) -> Result<HttpResponse, AppError> { let mode = self.route(); self.send_routed(request, mode).await }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:102</sub>
- `pub async fn send_following_redirects( &self, request: HttpRequest, ) -> Result<HttpResponse, AppError> { if request.method != HttpMethod::Get { retu…` — Follow browser-style redirects for a safe GET. Business systems such as  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:110</sub>
- `pub async fn send_with_fallback(&self, request: HttpRequest) -> Result<HttpResponse, AppError> { let safe_to_retry = request.method == HttpMethod::Ge…` — Send once, then retry a safe GET once through WebVPN when automatic  
  <sub>rust/crates/ginkgo_upstream/src/auth/session.rs:134</sub>

## uc

- `pub async fn activate_uc<T: HttpTransport>(session: &Session<T>) -> Result<(), AppError> { let mut url = UC_ACTIVATION_URL.to_string(); for hop in 0.…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/uc.rs:9</sub>
- `pub async fn validate_session<T: HttpTransport>( session: &Session<T>, ) -> Result<UserProfile, AppError> { let request = HttpRequest::get(UC_STATUS_…` — UC status is the only proof that the login chain produced a usable  
  <sub>rust/crates/ginkgo_upstream/src/auth/uc.rs:34</sub>
- `pub fn parse_uc_status(body: &str) -> Result<UserProfile, AppError> { let status: UcStatus = serde_json::from_str(body).map_err(\|_\| AppError::changed…` — Parse the UC status body. Structure changes are errors, never an implicit  
  <sub>rust/crates/ginkgo_upstream/src/auth/uc.rs:54</sub>

## vault

- `pub struct MemoryVault {`  
  <sub>rust/crates/ginkgo_upstream/src/auth/vault.rs:12</sub>
- `pub fn with(account: &str, credentials: Credentials) -> Self { let vault = Self::default(); vault.entries.lock().insert(account.to_owned(), credentia…`  
  <sub>rust/crates/ginkgo_upstream/src/auth/vault.rs:17</sub>
- `pub fn names(&self) -> Vec<String> { self.entries.lock().keys().cloned().collect() }`  
  <sub>rust/crates/ginkgo_upstream/src/auth/vault.rs:23</sub>
- `pub fn verify_vault_round_trip<V: CredentialVault + ?Sized>( vault: &V, account: &str, secret: &str, ) -> bool { const DIAGNOSTIC_PREFIX: &str = "__g…` — Write, read back and remove one synthetic credential. The reserved prefix  
  <sub>rust/crates/ginkgo_upstream/src/auth/vault.rs:54</sub>
- `pub(crate) fn sanitized(credentials: &Credentials) -> Credentials { Credentials { username: credentials.username.clone(), password: credentials.passw…` — Captcha answers are one-time and must never be persisted.  
  <sub>rust/crates/ginkgo_upstream/src/auth/vault.rs:81</sub>
