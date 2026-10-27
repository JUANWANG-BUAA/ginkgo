# 领域基础类型（ginkgo_domain）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

错误分类、序列化信封与共享值。

## school_time

- `pub struct DayRequest {`  
  <sub>rust/crates/ginkgo_domain/src/foundation/school_time.rs:6</sub>
    - `instant: String`  <sub>:7</sub>
- `pub struct SchoolDay {`  
  <sub>rust/crates/ginkgo_domain/src/foundation/school_time.rs:12</sub>
    - `time_zone: String`  <sub>:13</sub>
    - `local_date: String`  <sub>:14</sub>
    - `minutes_since_midnight: u32`  <sub>:15</sub>
- `pub fn beijing_day(instant: &str) -> Result<SchoolDay, AppError> { let instant = DateTime::parse_from_rfc3339(instant).map_err(\|_\| AppError::invalid(…`  
  <sub>rust/crates/ginkgo_domain/src/foundation/school_time.rs:18</sub>

## snapshot_persistence

- `pub const SNAPSHOT_TTL_MS: i64 = 300_000;`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:12</sub>
- `pub const MAX_SNAPSHOT_BYTES: usize = 512 * 1024;`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:13</sub>
- `pub struct SnapshotScope {`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:20</sub>
    - `account_digest: String` — SHA-256 identity digest, not an encryption mechanism.  <sub>:22</sub>
    - `generation: u64`  <sub>:23</sub>
    - `epoch: u64`  <sub>:24</sub>
    - `session_nonce: String` — Cryptographically random 128-bit nonce; renewed on every session boundary.  <sub>:26</sub>
- `pub struct SnapshotFallback {` — Returned values remain stale/failure-qualified at the application boundary.  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:54</sub>
    - `payload: Value`  <sub>:55</sub>
    - `fetched_at_ms: i64`  <sub>:56</sub>
    - `failure: AppError`  <sub>:57</sub>
- `pub struct SnapshotBook {` — Caller serializes access and holds the identity lock while committing or  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:61</sub>
- `pub fn new(scope: SnapshotScope) -> Result<Self, AppError> { if !scope.valid() { return Err(AppError::invalid()); } Ok(Self { envelope: Envelope { sc…`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:67</sub>
- `pub fn begin(&mut self, scope: &SnapshotScope, query_digest: &str) -> Result<u64, AppError> { self.check_scope(scope)?; if !hex(query_digest, 64) { r…` — Query must be a digest of canonical module/query coordinates, not a URL,  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:83</sub>
- `pub fn commit_success( &mut self, scope: &SnapshotScope, query_digest: &str, ticket: u64, fetched_at_ms: i64, now_ms: i64, payload: Value, ) -> Resul…` — No failure overload: failed reads cannot refresh the timestamp or replace  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:100</sub>
- `pub fn fallback( &self, scope: &SnapshotScope, query_digest: &str, now_ms: i64, failure: AppError, ) -> Result<Option<SnapshotFallback>, AppError> { …`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:141</sub>
- `pub fn encode(&self) -> Result<Vec<u8>, AppError> { if self.envelope.entries.len() > MAX_ENTRIES { return Err(AppError::invalid()); } let bytes = ser…` — Only transient plaintext bytes in memory. The caller must encrypt the  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:166</sub>
- `pub fn decode(bytes: &[u8], scope: &SnapshotScope, now_ms: i64) -> Result<Self, AppError> { if bytes.len() > MAX_SNAPSHOT_BYTES { return Err(AppError…`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:176</sub>
- `pub fn clear(&mut self, next_scope: SnapshotScope) -> Result<(), AppError> { if !next_scope.valid() \|\| next_scope == self.envelope.scope { return Err…`  
  <sub>rust/crates/ginkgo_domain/src/foundation/snapshot_persistence.rs:210</sub>

## lib

- `pub enum ErrorCode {`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:9</sub>
- `pub struct AppError {`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:29</sub>
    - `code: ErrorCode`  <sub>:30</sub>
    - `detail: Option<String>` — Optional upstream-provided text (already stripped of markup). Callers  <sub>:34</sub>
- `pub fn new(code: ErrorCode) -> Self { Self { code, detail: None } }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:38</sub>
- `pub fn with_detail(code: ErrorCode, detail: impl Into<String>) -> Self { Self { code, detail: Some(detail.into()), } }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:41</sub>
- `pub fn invalid() -> Self { Self::new(ErrorCode::InvalidRequest) }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:47</sub>
- `pub fn changed() -> Self { Self::new(ErrorCode::ChangedResponse) }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:50</sub>
- `pub fn session_expired() -> Self { Self::new(ErrorCode::SessionExpired) }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:53</sub>
- `pub fn unavailable() -> Self { Self::new(ErrorCode::ServiceUnavailable) }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:56</sub>
- `pub fn credential_store() -> Self { Self::new(ErrorCode::CredentialStore) }`  
  <sub>rust/crates/ginkgo_domain/src/lib.rs:59</sub>

## session

- `pub struct UserProfile {` — Public authentication values. No login-page, cookie or token representation.  
  <sub>rust/crates/ginkgo_domain/src/session.rs:3</sub>
    - `school_id: String`  <sub>:4</sub>
    - `name: String`  <sub>:5</sub>
- `pub struct CaptchaChallenge {`  
  <sub>rust/crates/ginkgo_domain/src/session.rs:9</sub>
    - `captcha_type: String`  <sub>:10</sub>
    - `id: String`  <sub>:11</sub>
    - `image_url: String`  <sub>:12</sub>
