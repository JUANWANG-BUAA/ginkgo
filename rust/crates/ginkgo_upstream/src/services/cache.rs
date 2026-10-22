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
}

pub(crate) struct SnapshotCache<K, V> {
    entries: BTreeMap<K, Timed<V>>,
}

impl<K: Ord + Clone, V> Default for SnapshotCache<K, V> {
    fn default() -> Self {
        Self {
            entries: BTreeMap::new(),
        }
    }
}

impl<K: Ord + Clone, V> SnapshotCache<K, V> {
    pub fn fresh(&self, key: &K) -> Option<&Timed<V>> {
        self.entries
            .get(key)
            .filter(|entry| entry.fetched_at.elapsed() < CACHE_TTL)
    }

    pub fn any(&self, key: &K) -> Option<&Timed<V>> {
        self.entries.get(key)
    }

    pub fn insert(&mut self, key: K, value: V) -> String {
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
        let timestamp = now_shanghai();
        self.entries.insert(
            key,
            Timed {
                fetched_at: Instant::now(),
                timestamp: timestamp.clone(),
                value,
            },
        );
        timestamp
    }

    pub fn clear(&mut self) {
        self.entries.clear();
    }
}

impl<K: Ord + Clone, V: Clone> SnapshotCache<K, V> {
    /// Replace on success, including an empty value. A failed read neither
    /// replaces nor refreshes the age of the fallback snapshot.
    pub fn resolve(
        &mut self,
        key: K,
        result: Result<V, crate::AppError>,
    ) -> Result<super::DataOutcome<V>, crate::AppError> {
        match result {
            Ok(data) => {
                self.insert(key, data.clone());
                Ok(super::DataOutcome {
                    data,
                    failure: None,
                })
            }
            Err(error) => match self.any(&key) {
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
    fn failed_refresh_retains_value_age_and_error_but_successful_empty_replaces_it() {
        let mut cache = SnapshotCache::<String, Vec<i32>>::default();
        let key = "scope".to_owned();
        cache.insert(key.clone(), vec![7]);
        let entry = cache.entries.get_mut(&key).expect("snapshot");
        entry.fetched_at = Instant::now() - CACHE_TTL;
        let fetched_at = entry.fetched_at;
        let timestamp = entry.timestamp.clone();
        let error = crate::AppError::session_expired();

        let retained = cache
            .resolve(key.clone(), Err(error.clone()))
            .expect("fallback");
        assert_eq!(retained.data, vec![7]);
        assert_eq!(retained.failure, Some(error.clone()));
        let entry = cache.any(&key).expect("retained snapshot");
        assert_eq!(entry.fetched_at, fetched_at);
        assert_eq!(entry.timestamp, timestamp);
        assert!(cache.fresh(&key).is_none());
        assert_eq!(
            cache
                .resolve("other".into(), Err(error.clone()))
                .expect_err("no fallback"),
            error
        );

        let empty = cache
            .resolve(key.clone(), Ok(vec![]))
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
