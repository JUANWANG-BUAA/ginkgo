//! Opt-in encrypted snapshot envelope rules. No filesystem or cryptography here.
//!
//! Encoded bytes MUST only be passed to an approved secure-blob adapter, never a
//! plaintext file/preferences store. This module is not installed by default.
//! A random session nonce prevents process-local generation counters colliding
//! after restart. Cross-session adoption is deliberately unsupported.
use crate::AppError;
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;

pub const SNAPSHOT_TTL_MS: i64 = 300_000;
pub const MAX_SNAPSHOT_BYTES: usize = 512 * 1024;
const MAX_PAYLOAD_BYTES: usize = 128 * 1024;
const MAX_ENTRIES: usize = 32;
const SCHEMA: u32 = 1;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SnapshotScope {
    /// SHA-256 identity digest, not an encryption mechanism.
    pub account_digest: String,
    pub generation: u64,
    pub epoch: u64,
    /// Cryptographically random 128-bit nonce; renewed on every session boundary.
    pub session_nonce: String,
}
impl SnapshotScope {
    fn valid(&self) -> bool {
        hex(&self.account_digest, 64) && hex(&self.session_nonce, 32)
    }
}
fn hex(value: &str, length: usize) -> bool {
    value.len() == length
        && value
            .bytes()
            .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Entry {
    /// Time of the actual successful source/cache insertion, never persistence time.
    fetched_at_ms: i64,
    payload: Value,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Envelope {
    schema: u32,
    scope: SnapshotScope,
    entries: BTreeMap<String, Entry>,
}
/// Returned values remain stale/failure-qualified at the application boundary.
pub struct SnapshotFallback {
    pub payload: Value,
    pub fetched_at_ms: i64,
    pub failure: AppError,
}
/// Caller serializes access and holds the identity lock while committing or
/// clearing. Tickets never survive clear, decode, or a session change.
pub struct SnapshotBook {
    envelope: Envelope,
    tickets: BTreeMap<String, u64>,
    next_ticket: u64,
}
impl SnapshotBook {
    pub fn new(scope: SnapshotScope) -> Result<Self, AppError> {
        if !scope.valid() {
            return Err(AppError::invalid());
        }
        Ok(Self {
            envelope: Envelope {
                schema: SCHEMA,
                scope,
                entries: BTreeMap::new(),
            },
            tickets: BTreeMap::new(),
            next_ticket: 0,
        })
    }
    /// Query must be a digest of canonical module/query coordinates, not a URL,
    /// account name, credential, or arbitrary filesystem path.
    pub fn begin(&mut self, scope: &SnapshotScope, query_digest: &str) -> Result<u64, AppError> {
        self.check_scope(scope)?;
        if !hex(query_digest, 64) {
            return Err(AppError::invalid());
        }
        if self.tickets.len() >= MAX_ENTRIES && !self.tickets.contains_key(query_digest) {
            return Err(AppError::unavailable());
        }
        self.next_ticket = self
            .next_ticket
            .checked_add(1)
            .ok_or_else(AppError::unavailable)?;
        self.tickets.insert(query_digest.into(), self.next_ticket);
        Ok(self.next_ticket)
    }
    /// No failure overload: failed reads cannot refresh the timestamp or replace
    /// a successful snapshot. A confirmed empty payload is a normal success.
    pub fn commit_success(
        &mut self,
        scope: &SnapshotScope,
        query_digest: &str,
        ticket: u64,
        fetched_at_ms: i64,
        now_ms: i64,
        payload: Value,
    ) -> Result<bool, AppError> {
        self.check_scope(scope)?;
        if self.tickets.get(query_digest) != Some(&ticket) {
            return Ok(false);
        }
        if !in_ttl(fetched_at_ms, now_ms)
            || serde_json::to_vec(&payload)
                .map_err(|_| AppError::invalid())?
                .len()
                > MAX_PAYLOAD_BYTES
        {
            return Err(AppError::invalid());
        }
        let previous = self.envelope.entries.insert(
            query_digest.into(),
            Entry {
                fetched_at_ms,
                payload,
            },
        );
        if self.encode().is_err() {
            match previous {
                Some(previous) => {
                    self.envelope.entries.insert(query_digest.into(), previous);
                }
                None => {
                    self.envelope.entries.remove(query_digest);
                }
            }
            return Err(AppError::unavailable());
        }
        Ok(true)
    }
    pub fn fallback(
        &self,
        scope: &SnapshotScope,
        query_digest: &str,
        now_ms: i64,
        failure: AppError,
    ) -> Result<Option<SnapshotFallback>, AppError> {
        self.check_scope(scope)?;
        // Authentication/protocol/access failures must not become offline success.
        if !failure.allows_stale_snapshot() {
            return Err(failure);
        }
        Ok(self
            .envelope
            .entries
            .get(query_digest)
            .filter(|entry| in_ttl(entry.fetched_at_ms, now_ms))
            .map(|entry| SnapshotFallback {
                payload: entry.payload.clone(),
                fetched_at_ms: entry.fetched_at_ms,
                failure,
            }))
    }
    /// Only transient plaintext bytes in memory. The caller must encrypt the
    /// complete envelope before any persistent write and must not log them.
    pub fn encode(&self) -> Result<Vec<u8>, AppError> {
        if self.envelope.entries.len() > MAX_ENTRIES {
            return Err(AppError::invalid());
        }
        let bytes = serde_json::to_vec(&self.envelope).map_err(|_| AppError::invalid())?;
        if bytes.len() > MAX_SNAPSHOT_BYTES {
            return Err(AppError::invalid());
        }
        Ok(bytes)
    }
    pub fn decode(bytes: &[u8], scope: &SnapshotScope, now_ms: i64) -> Result<Self, AppError> {
        if bytes.len() > MAX_SNAPSHOT_BYTES {
            return Err(AppError::invalid());
        }
        let envelope: Envelope = serde_json::from_slice(bytes).map_err(|_| AppError::changed())?;
        if envelope.schema != SCHEMA
            || !envelope.scope.valid()
            || &envelope.scope != scope
            || envelope.entries.len() > MAX_ENTRIES
        {
            return Err(AppError::changed());
        }
        // Only this encoder's canonical representation is accepted. Duplicate
        // members/trailing junk/unknown schema and noncanonical input fail closed.
        if serde_json::to_vec(&envelope).map_err(|_| AppError::changed())? != bytes {
            return Err(AppError::changed());
        }
        for (key, entry) in &envelope.entries {
            if !hex(key, 64)
                || !in_ttl(entry.fetched_at_ms, now_ms)
                || serde_json::to_vec(&entry.payload)
                    .map_err(|_| AppError::changed())?
                    .len()
                    > MAX_PAYLOAD_BYTES
            {
                return Err(AppError::changed());
            }
        }
        Ok(Self {
            envelope,
            tickets: BTreeMap::new(),
            next_ticket: 0,
        })
    }
    pub fn clear(&mut self, next_scope: SnapshotScope) -> Result<(), AppError> {
        if !next_scope.valid() || next_scope == self.envelope.scope {
            return Err(AppError::invalid());
        }
        self.envelope.scope = next_scope;
        self.envelope.entries.clear();
        self.tickets.clear();
        // Keep the counter so old in-flight tickets cannot match later tickets.
        Ok(())
    }
    fn check_scope(&self, scope: &SnapshotScope) -> Result<(), AppError> {
        if &self.envelope.scope != scope {
            return Err(AppError::session_expired());
        }
        Ok(())
    }
}
fn in_ttl(fetched_at_ms: i64, now_ms: i64) -> bool {
    fetched_at_ms > 0
        && now_ms
            .checked_sub(fetched_at_ms)
            .is_some_and(|age| (0..SNAPSHOT_TTL_MS).contains(&age))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ErrorCode;
    use serde_json::json;
    fn scope() -> SnapshotScope {
        SnapshotScope {
            account_digest: "a".repeat(64),
            generation: 1,
            epoch: 0,
            session_nonce: "b".repeat(32),
        }
    }
    fn key() -> String {
        "c".repeat(64)
    }
    #[test]
    fn roundtrip_preserves_source_time_and_success_empty_replaces() {
        let s = scope();
        let mut book = SnapshotBook::new(s.clone()).unwrap();
        let t = book.begin(&s, &key()).unwrap();
        book.commit_success(&s, &key(), t, 1000, 1001, json!(["course"]))
            .unwrap();
        let copy = SnapshotBook::decode(&book.encode().unwrap(), &s, 2000).unwrap();
        let old = copy
            .fallback(&s, &key(), 2000, AppError::unavailable())
            .unwrap()
            .unwrap();
        assert_eq!(old.fetched_at_ms, 1000);
        assert_eq!(old.failure.code, ErrorCode::ServiceUnavailable);
        let t = book.begin(&s, &key()).unwrap();
        book.commit_success(&s, &key(), t, 2000, 2000, json!([]))
            .unwrap();
        assert_eq!(
            book.fallback(&s, &key(), 2001, AppError::unavailable())
                .unwrap()
                .unwrap()
                .payload,
            json!([])
        );
    }
    #[test]
    fn network_unreachable_uses_valid_snapshot_but_auth_failure_does_not() {
        let s = scope();
        let mut book = SnapshotBook::new(s.clone()).unwrap();
        let ticket = book.begin(&s, &key()).unwrap();
        book.commit_success(&s, &key(), ticket, 1000, 1001, json!(["course"]))
            .unwrap();
        let copy = SnapshotBook::decode(&book.encode().unwrap(), &s, 2000).unwrap();

        let old = copy
            .fallback(&s, &key(), 2000, AppError::network_unreachable())
            .unwrap()
            .unwrap();
        assert_eq!(old.fetched_at_ms, 1000);
        assert_eq!(old.failure.code, ErrorCode::NetworkUnreachable);
        assert!(copy
            .fallback(&s, &key(), 2000, AppError::session_expired())
            .is_err());
    }

    #[test]
    fn newest_request_wins_and_clear_rejects_a_b_a_late_results() {
        let s = scope();
        let mut book = SnapshotBook::new(s.clone()).unwrap();
        let old = book.begin(&s, &key()).unwrap();
        let new = book.begin(&s, &key()).unwrap();
        assert!(!book
            .commit_success(&s, &key(), old, 1000, 1000, json!([1]))
            .unwrap());
        assert!(book
            .commit_success(&s, &key(), new, 1000, 1000, json!([2]))
            .unwrap());
        let mut next = s.clone();
        next.epoch += 1;
        book.clear(next.clone()).unwrap();
        let t = book.begin(&next, &key()).unwrap();
        assert_ne!(t, old);
        assert_eq!(
            book.commit_success(&s, &key(), old, 1000, 1000, json!([]))
                .unwrap_err()
                .code,
            ErrorCode::SessionExpired
        );
        assert!(book
            .fallback(&next, &key(), 1000, AppError::unavailable())
            .unwrap()
            .is_none());
    }
    #[test]
    fn nonce_generation_account_and_epoch_are_all_owned() {
        let s = scope();
        let book = SnapshotBook::new(s.clone()).unwrap();
        let bytes = book.encode().unwrap();
        for field in 0..4 {
            let mut wrong = s.clone();
            match field {
                0 => wrong.account_digest = "d".repeat(64),
                1 => wrong.generation += 1,
                2 => wrong.epoch += 1,
                _ => wrong.session_nonce = "e".repeat(32),
            }
            assert!(SnapshotBook::decode(&bytes, &wrong, 1000).is_err());
        }
    }
    #[test]
    fn ttl_future_clock_and_session_expired_never_fallback() {
        let s = scope();
        let mut book = SnapshotBook::new(s.clone()).unwrap();
        let t = book.begin(&s, &key()).unwrap();
        assert!(book
            .commit_success(&s, &key(), t, 2000, 1000, json!([]))
            .is_err());
        book.commit_success(&s, &key(), t, 1000, 1000, json!([]))
            .unwrap();
        assert!(book
            .fallback(&s, &key(), 1000 + SNAPSHOT_TTL_MS, AppError::unavailable())
            .unwrap()
            .is_none());
        assert!(book
            .fallback(&s, &key(), 999, AppError::unavailable())
            .unwrap()
            .is_none());
        for failure in [
            AppError::session_expired(),
            AppError::changed(),
            AppError::new(ErrorCode::AccessPolicyDenied),
        ] {
            assert!(book.fallback(&s, &key(), 1001, failure).is_err());
        }
    }
    #[test]
    fn corrupt_schema_oversize_and_duplicate_member_are_rejected() {
        let s = scope();
        let book = SnapshotBook::new(s.clone()).unwrap();
        let bytes = book.encode().unwrap();
        let mut value: Value = serde_json::from_slice(&bytes).unwrap();
        value["schema"] = json!(2);
        assert!(SnapshotBook::decode(&serde_json::to_vec(&value).unwrap(), &s, 1000).is_err());
        assert!(SnapshotBook::decode(&vec![0; MAX_SNAPSHOT_BYTES + 1], &s, 1000).is_err());
        let duplicate = String::from_utf8(bytes)
            .unwrap()
            .replace("\"schema\":1", "\"schema\":1,\"schema\":1");
        assert!(SnapshotBook::decode(duplicate.as_bytes(), &s, 1000).is_err());
    }
}
