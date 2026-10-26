//! Small in-memory snapshot cache with TTL and bounded size.
//!
//! This mirrors the Apple "failed refresh keeps the previous snapshot" rule
//! without reading or writing the Swift cache files.
use chrono::{DateTime, Utc};
use std::{
    collections::BTreeMap,
    time::{Duration, Instant, SystemTime},
};

pub(crate) const CACHE_TTL: Duration = Duration::from_secs(300);
const CAPACITY: usize = 32;

pub(crate) struct Timed<T> {
    pub fetched_at: Instant,
    pub timestamp: String,
    pub value: T,
    /// Restored disk values never count as a fresh network/cache success.
    pub restored: bool,
}

pub(crate) struct SnapshotCache<K, V> {
    entries: BTreeMap<K, Timed<V>>,
    /// Latest writer ticket per key, drawn from one monotonic counter. A
    /// request captures its ticket before the network read; only the most
    /// recently issued ticket may insert, so an older response that finishes
    /// later can never replace a newer result. clear() drops the table so
    /// tickets from a cleared generation (for example another account) can no
    /// longer write at all.
    tickets: BTreeMap<K, u64>,
    next_ticket: u64,
}

impl<K: Ord + Clone, V> Default for SnapshotCache<K, V> {
    fn default() -> Self {
        Self {
            entries: BTreeMap::new(),
            tickets: BTreeMap::new(),
            next_ticket: 0,
        }
    }
}

impl<K: Ord + Clone, V> SnapshotCache<K, V> {
    pub fn fresh(&self, key: &K) -> Option<&Timed<V>> {
        self.entries
            .get(key)
            .filter(|entry| !entry.restored && entry.fetched_at.elapsed() < CACHE_TTL)
    }

    pub fn any(&self, key: &K) -> Option<&Timed<V>> {
        self.entries.get(key)
    }

    /// Issue the writer ticket for a new request on this key. Call it before
    /// the network read starts.
    pub fn begin(&mut self, key: &K) -> u64 {
        self.next_ticket = self.next_ticket.wrapping_add(1);
        let ticket = self.next_ticket;
        self.tickets.insert(key.clone(), ticket);
        ticket
    }

    /// Insert only when no newer request for the same key has started. The
    /// returned timestamp describes this response either way; a superseded
    /// caller reports its own result without touching the cached snapshot.
    pub fn insert_if_current(&mut self, key: K, ticket: u64, value: V) -> String {
        let timestamp = now_shanghai();
        if self.tickets.get(&key).copied() == Some(ticket) {
            self.insert_with_timestamp(key, value, timestamp.clone());
        }
        timestamp
    }

    /// Test seeding helper: writes unconditionally, bypassing the ticket rule
    /// that production readers go through.
    #[cfg(test)]
    pub fn insert(&mut self, key: K, value: V) -> String {
        let timestamp = now_shanghai();
        self.insert_with_timestamp(key, value, timestamp.clone());
        timestamp
    }

    fn insert_with_timestamp(&mut self, key: K, value: V, timestamp: String) {
        if self.entries.len() >= CAPACITY && !self.entries.contains_key(&key) {
            if let Some(oldest) = self
                .entries
                .iter()
                .min_by_key(|(_, entry)| entry.fetched_at)
                .map(|(key, _)| key.clone())
            {
                self.entries.remove(&oldest);
            }
        }
        self.entries.insert(
            key,
            Timed {
                fetched_at: Instant::now(),
                timestamp,
                value,
                restored: false,
            },
        );
    }

    pub(super) fn entries(&self) -> impl Iterator<Item = (&K, &Timed<V>)> {
        self.entries.iter()
    }

    /// Rebind only after archive validation and current authenticated-owner checks.
    /// Disk values are fallback-only, never a fresh hit, and preserve source time.
    pub(super) fn restore(&mut self, key: K, value: V, timestamp: String, age: Duration) {
        if age >= CACHE_TTL || self.entries.contains_key(&key) {
            return;
        }
        self.insert_with_timestamp(key.clone(), value, timestamp);
        if let Some(entry) = self.entries.get_mut(&key) {
            entry.fetched_at = Instant::now() - age;
            entry.restored = true;
        }
    }

    pub fn clear(&mut self) {
        self.entries.clear();
        self.tickets.clear();
    }
}

impl<K: Ord + Clone, V: Clone> SnapshotCache<K, V> {
    /// Replace on success, including an empty value, unless a newer request
    /// for the same key started meanwhile. A failed read neither replaces nor
    /// refreshes the age of the fallback snapshot.
    pub fn resolve_current(
        &mut self,
        key: K,
        ticket: u64,
        result: Result<V, crate::AppError>,
    ) -> Result<super::DataOutcome<V>, crate::AppError> {
        match result {
            Ok(data) => {
                self.insert_if_current(key, ticket, data.clone());
                Ok(super::DataOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.any(&key) {
                Some(entry)
                    if entry.restored
                        && (error.code != crate::ErrorCode::ServiceUnavailable
                            || entry.fetched_at.elapsed() >= CACHE_TTL) =>
                {
                    Err(error)
                }
                Some(entry) => Ok(super::DataOutcome {
                    data: entry.value.clone(),
                    failure: Some(error),
                }),
                None => Err(error),
            },
        }
    }
}

pub(crate) fn now_shanghai() -> String {
    let now: DateTime<Utc> = SystemTime::now().into();
    now.with_timezone(&chrono_tz::Asia::Shanghai).to_rfc3339()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_the_latest_issued_ticket_writes_its_key() {
        let mut cache = SnapshotCache::<String, i32>::default();
        let stale = cache.begin(&"scope".to_owned());
        let latest = cache.begin(&"scope".to_owned());
        cache.insert_if_current("scope".into(), latest, 2);
        assert_eq!(cache.any(&"scope".into()).expect("latest result").value, 2);
        // The older request finishing late must neither replace the value nor
        // refresh its age.
        let before = cache
            .any(&"scope".into())
            .map(|entry| entry.timestamp.clone());
        cache.insert_if_current("scope".into(), stale, 1);
        let entry = cache.any(&"scope".into()).expect("kept snapshot");
        assert_eq!(entry.value, 2);
        assert_eq!(Some(&entry.timestamp), before.as_ref());

        // An independent key is unaffected by the other key's tickets.
        let other = cache.begin(&"other".to_owned());
        cache.insert_if_current("other".into(), other, 7);
        assert_eq!(cache.any(&"other".into()).expect("other").value, 7);
    }

    #[test]
    fn clear_also_resets_writer_tickets() {
        let mut cache = SnapshotCache::<String, i32>::default();
        let ticket = cache.begin(&"scope".to_owned());
        cache.clear();
        // Tickets come from one monotonic counter, so a cleared generation's
        // in-flight ticket can never collide with a later request's.
        let fresh = cache.begin(&"scope".to_owned());
        assert_ne!(fresh, ticket);
        cache.insert_if_current("scope".into(), ticket, 1);
        assert!(cache.any(&"scope".into()).is_none());
        cache.insert_if_current("scope".into(), fresh, 1);
        assert_eq!(cache.any(&"scope".into()).expect("current").value, 1);
    }

    #[test]
    fn failed_refresh_retains_value_age_and_error_but_successful_empty_replaces_it() {
        let mut cache = SnapshotCache::<String, Vec<i32>>::default();
        let key = "scope".to_owned();
        cache.insert(key.clone(), vec![7]);
        let entry = cache.entries.get_mut(&key).expect("snapshot");
        entry.fetched_at = Instant::now() - CACHE_TTL;
        let fetched_at = entry.fetched_at;
        let timestamp = entry.timestamp.clone();
        let error = crate::AppError::session_expired();
        let ticket = cache.begin(&key);

        let retained = cache
            .resolve_current(key.clone(), ticket, Err(error.clone()))
            .expect("fallback");
        assert_eq!(retained.data, vec![7]);
        assert_eq!(retained.failure, Some(error.clone()));
        let entry = cache.any(&key).expect("retained snapshot");
        assert_eq!(entry.fetched_at, fetched_at);
        assert_eq!(entry.timestamp, timestamp);
        assert!(cache.fresh(&key).is_none());
        let other_ticket = cache.begin(&"other".to_owned());
        assert_eq!(
            cache
                .resolve_current("other".into(), other_ticket, Err(error.clone()))
                .expect_err("no fallback"),
            error
        );

        let empty = cache
            .resolve_current(key.clone(), ticket, Ok(vec![]))
            .expect("empty success");
        assert!(empty.data.is_empty());
        assert!(empty.failure.is_none());
        assert!(cache
            .fresh(&key)
            .expect("fresh empty snapshot")
            .value
            .is_empty());
    }

    #[test]
    fn expiry_retains_fallback_and_capacity_evicts_oldest_not_lexical_key() {
        let mut cache = SnapshotCache::<String, i32>::default();
        cache.insert("z-oldest".into(), 7);
        let old = cache.entries.get_mut("z-oldest").expect("entry");
        old.fetched_at = Instant::now() - CACHE_TTL;
        let timestamp = old.timestamp.clone();
        assert!(cache.fresh(&"z-oldest".into()).is_none());
        assert_eq!(
            cache.any(&"z-oldest".into()).expect("fallback").timestamp,
            timestamp
        );
        for i in 0..CAPACITY {
            cache.insert(format!("a-{i}"), i as i32);
        }
        assert_eq!(cache.entries.len(), CAPACITY);
        assert!(cache.any(&"z-oldest".into()).is_none());
        cache.insert("a-0".into(), 99);
        assert_eq!(cache.entries.len(), CAPACITY);
        assert_eq!(cache.fresh(&"a-0".into()).expect("replacement").value, 99);
        cache.clear();
        assert!(cache.any(&"a-0".into()).is_none());
    }
}
