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

pub(crate) fn now_shanghai() -> String {
    let now: DateTime<Utc> = SystemTime::now().into();
    now.with_timezone(&chrono_tz::Asia::Shanghai).to_rfc3339()
}

#[cfg(test)]
mod tests {
    use super::*;

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
