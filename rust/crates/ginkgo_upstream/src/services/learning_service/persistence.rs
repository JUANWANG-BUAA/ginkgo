//! Explicitly opted-in, encrypted-by-host learning archives. No private loans,
//! credentials, protocol auth, downloaded bytes or reader profile are archived.
use super::*;
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sha1::{Digest, Sha1};
use std::time::{Duration, SystemTime};
const LIMIT: usize = 512 * 1024;
const MAX_ROWS: usize = 32;
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Row<V> {
    query: String,
    timestamp: String,
    value: V,
}
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Archive {
    schema: u32,
    account_digest: String,
    route: String,
    courses: Vec<Row<Vec<LearningCourse>>>,
    columns: Vec<Row<Vec<LearningColumn>>>,
    announcements: Vec<Row<Vec<CourseAnnouncement>>>,
    resources: Vec<Row<CourseResourcePage>>,
    assessments: Vec<Row<Vec<CourseAssessment>>>,
}
fn digest(account: &str) -> String {
    format!("{:x}", Sha1::digest(account.as_bytes()))
}
fn age(timestamp: &str) -> Result<Duration, AppError> {
    let fetched = DateTime::parse_from_rfc3339(timestamp).map_err(|_| AppError::changed())?;
    let now: DateTime<Utc> = SystemTime::now().into();
    let millis = now
        .timestamp_millis()
        .checked_sub(fetched.timestamp_millis())
        .ok_or_else(AppError::changed)?;
    if !(0..300_000).contains(&millis) {
        return Err(AppError::changed());
    }
    Ok(Duration::from_millis(millis as u64))
}
fn rows<V: Clone>(cache: &Mutex<SnapshotCache<String, V>>, owner: &(String, u64)) -> Vec<Row<V>> {
    cache
        .lock()
        .entries()
        .filter_map(|(key, timed)| {
            let (entry_owner, query): ((String, u64), String) = serde_json::from_str(key).ok()?;
            if &entry_owner != owner || age(&timed.timestamp).is_err() {
                return None;
            }
            Some(Row {
                query,
                timestamp: timed.timestamp.clone(),
                value: timed.value.clone(),
            })
        })
        .collect()
}
fn validate<V>(rows: &[Row<V>]) -> Result<(), AppError> {
    if rows.len() > MAX_ROWS {
        return Err(AppError::changed());
    }
    let mut keys = std::collections::BTreeSet::new();
    for row in rows {
        if row.query.len() > 4096 || !keys.insert(&row.query) {
            return Err(AppError::changed());
        }
        age(&row.timestamp)?;
    }
    Ok(())
}
fn restore<V>(
    cache: &Mutex<SnapshotCache<String, V>>,
    rows: Vec<Row<V>>,
    owner: &(String, u64),
) -> u32 {
    let mut cache = cache.lock();
    let mut count = 0;
    for row in rows {
        // Repeat age check after full validation; a clock/TTL boundary cannot panic.
        if let (Ok(age), Ok(key)) = (
            age(&row.timestamp),
            serde_json::to_string(&(owner, &row.query)),
        ) {
            cache.restore(key, row.value, row.timestamp, age);
            count += 1;
        }
    }
    count
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> LearningSnapshotSource
    for SchoolClient<T, V>
{
    fn export_learning_snapshots(&self) -> Result<Vec<u8>, AppError> {
        let identity = self.identity.lock();
        let user = identity
            .authenticated
            .as_ref()
            .ok_or_else(AppError::session_expired)?;
        let owner = (user.account.clone(), identity.generation);
        let s = &self.snapshots.learning;
        let archive = Archive {
            schema: 1,
            account_digest: digest(&owner.0),
            route: format!("{:?}", self.preference()),
            courses: rows(&s.courses, &owner),
            columns: rows(&s.columns, &owner),
            announcements: rows(&s.announcements, &owner),
            resources: rows(&s.resources, &owner),
            assessments: rows(&s.assessments, &owner),
        };
        let bytes = serde_json::to_vec(&archive).map_err(|_| AppError::changed())?;
        if bytes.len() > LIMIT {
            return Err(AppError::invalid());
        }
        Ok(bytes)
    }
    fn import_learning_snapshots(&self, bytes: &[u8]) -> Result<u32, AppError> {
        if bytes.len() > LIMIT {
            return Err(AppError::invalid());
        }
        let a: Archive = serde_json::from_slice(bytes).map_err(|_| AppError::changed())?;
        let identity = self.identity.lock();
        let user = identity
            .authenticated
            .as_ref()
            .ok_or_else(AppError::session_expired)?;
        if a.schema != 1
            || a.account_digest != digest(&user.account)
            || a.route != format!("{:?}", self.preference())
            || serde_json::to_vec(&a).map_err(|_| AppError::changed())? != bytes
        {
            return Err(AppError::changed());
        }
        validate(&a.courses)?;
        validate(&a.columns)?;
        validate(&a.announcements)?;
        validate(&a.resources)?;
        validate(&a.assessments)?;
        let owner = (user.account.clone(), identity.generation);
        let s = &self.snapshots.learning;
        Ok(restore(&s.courses, a.courses, &owner)
            + restore(&s.columns, a.columns, &owner)
            + restore(&s.announcements, a.announcements, &owner)
            + restore(&s.resources, a.resources, &owner)
            + restore(&s.assessments, a.assessments, &owner))
    }
}
#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        auth::{session::Session, vault::MemoryVault, UserProfile},
        test_support::MockTransport,
    };
    fn client() -> SchoolClient<MockTransport, MemoryVault> {
        let c = SchoolClient::new(
            Session::new(MockTransport::with_responses(vec![])),
            MemoryVault::default(),
        );
        c.set_authenticated(
            "sy2501001".into(),
            UserProfile {
                school_id: "sy2501001".into(),
                name: "李文".into(),
            },
        );
        c
    }
    fn seed(c: &SchoolClient<MockTransport, MemoryVault>, value: Vec<LearningCourse>) {
        let key = serde_json::to_string(&(c.learning_owner().unwrap(), "student")).unwrap();
        c.snapshots.learning.courses.lock().insert(key, value);
    }
    #[test]
    fn restart_rebind_preserves_timestamp_and_is_fallback_only() {
        let first = client();
        seed(&first, vec![]);
        let bytes = first.export_learning_snapshots().unwrap();
        let next = client();
        assert_eq!(next.import_learning_snapshots(&bytes).unwrap(), 1);
        assert_eq!(next.export_learning_snapshots().unwrap(), bytes);
        let key = serde_json::to_string(&(next.learning_owner().unwrap(), "student")).unwrap();
        let mut cache = next.snapshots.learning.courses.lock();
        assert!(cache.fresh(&key).is_none());
        let t = cache.begin(&key);
        let out = cache
            .resolve_current(key.clone(), t, Err(AppError::unavailable()))
            .unwrap();
        assert!(out.data.is_empty());
        assert!(out.failure.is_some());
        assert!(cache
            .resolve_current(key, t, Err(AppError::changed()))
            .is_err());
    }
    #[test]
    fn foreign_account_schema_expired_clock_and_corruption_fail_closed() {
        let c = client();
        seed(&c, vec![]);
        let bytes = c.export_learning_snapshots().unwrap();
        for mutate in 0..4 {
            let mut v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
            match mutate {
                0 => v["account_digest"] = "other".into(),
                1 => v["schema"] = 2.into(),
                2 => v["courses"][0]["timestamp"] = "2000-01-01T00:00:00+08:00".into(),
                _ => v["courses"][0]["timestamp"] = "2999-01-01T00:00:00+08:00".into(),
            }
            assert!(client()
                .import_learning_snapshots(&serde_json::to_vec(&v).unwrap())
                .is_err());
        }
        assert!(client().import_learning_snapshots(b"bad").is_err());
    }
}
