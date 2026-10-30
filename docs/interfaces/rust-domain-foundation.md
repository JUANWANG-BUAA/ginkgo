# 领域基础类型（ginkgo_domain）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
错误分类、序列化信封与共享值。

## school_time

- `pub struct DayRequest`
  <sub>struct · rust/crates/ginkgo_domain/src/foundation/school_time.rs:6</sub>
    - `instant: String`  <sub>:7</sub>
- `pub struct SchoolDay`
  <sub>struct · rust/crates/ginkgo_domain/src/foundation/school_time.rs:12</sub>
    - `time_zone: String`  <sub>:13</sub>
    - `local_date: String`  <sub>:14</sub>
    - `minutes_since_midnight: u32`  <sub>:15</sub>
- `pub fn beijing_day(instant: &str) -> Result<SchoolDay, AppError> {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/foundation/school_time.rs:18</sub>
- `pub fn school_instant(date: Option<&str>, raw: &str) -> Option<DateTime<Utc>> {…}` — The instant of a school wall time.
  <sub>fn · rust/crates/ginkgo_domain/src/foundation/school_time.rs:33</sub>

## lib

- `pub enum ErrorCode`
  <sub>enum · rust/crates/ginkgo_domain/src/lib.rs:9</sub>
- `pub struct AppError`
  <sub>struct · rust/crates/ginkgo_domain/src/lib.rs:42</sub>
    - `code: ErrorCode`  <sub>:43</sub>
    - `detail: Option<String>` — Optional upstream-provided text (already stripped of markup). Callers  <sub>:47</sub>
- `pub fn new(code: ErrorCode) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:51</sub>
- `pub fn with_detail(code: ErrorCode, detail: impl Into<String>) -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:54</sub>
- `pub fn invalid() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:60</sub>
- `pub fn changed() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:63</sub>
- `pub fn session_expired() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:66</sub>
- `pub fn module_auth_required() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:69</sub>
- `pub fn unavailable() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:72</sub>
- `pub fn network_unreachable() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:75</sub>
- `pub fn allows_stale_snapshot(&self) -> bool {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:78</sub>
- `pub fn credential_store() -> Self {…}`
  <sub>fn · rust/crates/ginkgo_domain/src/lib.rs:84</sub>

## session

- `pub struct UserProfile` — Public authentication values. No login-page, cookie or token representation.
  <sub>struct · rust/crates/ginkgo_domain/src/session.rs:3</sub>
    - `school_id: String`  <sub>:4</sub>
    - `name: String`  <sub>:5</sub>
- `pub struct CaptchaChallenge`
  <sub>struct · rust/crates/ginkgo_domain/src/session.rs:9</sub>
    - `captcha_type: String`  <sub>:10</sub>
    - `id: String`  <sub>:11</sub>
    - `image_url: String`  <sub>:12</sub>
