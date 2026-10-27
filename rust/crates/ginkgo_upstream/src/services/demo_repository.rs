//! In-memory synthetic repository for UI acceptance, separate from real account storage.
use super::ClassroomFixture;
use crate::{
    codecs::classroom::{self, FilterRequest, FilterResult},
    foundation::school_time,
    AppError,
};
use chrono::{DateTime, NaiveDate, Utc};
use std::{
    collections::BTreeMap,
    time::{Duration, Instant, SystemTime},
};

#[derive(Default)]
pub struct DemoRepository {
    entries: BTreeMap<(i32, String), (Instant, String)>,
}

pub struct DemoQueryResult {
    pub result: FilterResult,
    pub fetched_at: String,
    pub from_cache: bool,
}

impl DemoRepository {
    pub fn query(
        &mut self,
        campus: i32,
        date: &str,
        force: bool,
        mut filter: FilterRequest,
    ) -> Result<DemoQueryResult, AppError> {
        if !(1..=3).contains(&campus) || NaiveDate::parse_from_str(date, "%Y-%m-%d").is_err() {
            return Err(AppError::invalid());
        }
        let fixture: ClassroomFixture = serde_json::from_str(include_str!(
            "../../../../../fixtures/classroom/filter-v1.json"
        ))
        .map_err(|_| AppError::changed())?;
        // Synthetic catalog metadata, not a rule about real school building names.
        filter.source_rooms = fixture
            .input
            .source_rooms
            .into_iter()
            .filter(|(building, _)| match campus {
                1 => building == "主楼",
                2 => building == "沙河主楼",
                _ => false,
            })
            .collect();
        let result = classroom::filter(filter)?;
        let key = (campus, date.to_owned());
        let from_cache = !force
            && self
                .entries
                .get(&key)
                .is_some_and(|(at, _)| at.elapsed() < Duration::from_secs(300));
        if !from_cache {
            let now: DateTime<Utc> = SystemTime::now().into();
            self.entries.insert(
                key.clone(),
                (
                    Instant::now(),
                    now.with_timezone(&chrono_tz::Asia::Shanghai).to_rfc3339(),
                ),
            );
        }
        // Bound synthetic session memory; this never writes a Swift cache file.
        if self.entries.len() > 32 {
            let oldest = self
                .entries
                .iter()
                .min_by_key(|(_, (instant, _))| *instant)
                .map(|(key, _)| key.clone());
            if let Some(oldest) = oldest {
                self.entries.remove(&oldest);
            }
        }
        let fetched_at = self
            .entries
            .get(&key)
            .map(|(_, at)| at.clone())
            .ok_or_else(AppError::changed)?;
        Ok(DemoQueryResult {
            result,
            fetched_at,
            from_cache,
        })
    }
}

pub fn query_dates(instant: &str) -> Result<(String, String), AppError> {
    let day = school_time::beijing_day(instant)?;
    let date =
        NaiveDate::parse_from_str(&day.local_date, "%Y-%m-%d").map_err(|_| AppError::invalid())?;
    let tomorrow = date.succ_opt().ok_or_else(AppError::invalid)?;
    Ok((date.to_string(), tomorrow.to_string()))
}

#[cfg(test)]
mod tests {
    use super::*;
    fn filter() -> FilterRequest {
        let fixture: ClassroomFixture = serde_json::from_str(include_str!(
            "../../../../../fixtures/classroom/filter-v1.json"
        ))
        .expect("shared fixture");
        let mut filter = fixture.input;
        filter.minimum_free_sections = 0;
        filter
    }
    #[test]
    fn query_scopes_and_empty_campus_are_distinct() {
        let mut repository = DemoRepository::default();
        for (campus, count) in [(1, 3), (2, 2), (3, 0)] {
            let result = repository
                .query(campus, "2026-10-20", false, filter())
                .expect("valid scope");
            assert_eq!(result.result.summary.room_count, count);
            assert!(!result.from_cache);
        }
        assert!(repository.query(0, "2026-10-20", false, filter()).is_err());
        assert!(repository.query(1, "not-a-date", false, filter()).is_err());
    }
    #[test]
    fn cache_ttl_force_refresh_and_date_isolation() {
        let mut repository = DemoRepository::default();
        repository
            .query(1, "2026-10-20", false, filter())
            .expect("first query");
        assert!(
            repository
                .query(1, "2026-10-20", false, filter())
                .expect("cached")
                .from_cache
        );
        assert!(
            !repository
                .query(1, "2026-10-21", false, filter())
                .expect("other date")
                .from_cache
        );
        assert!(
            !repository
                .query(1, "2026-10-20", true, filter())
                .expect("forced")
                .from_cache
        );
        let entry = repository
            .entries
            .get_mut(&(1, "2026-10-20".into()))
            .expect("entry");
        entry.0 = Instant::now() - Duration::from_secs(301);
        assert!(
            !repository
                .query(1, "2026-10-20", false, filter())
                .expect("expired")
                .from_cache
        );
    }
    #[test]
    fn local_filter_reuses_timestamp_and_errors_do_not_poison_cache() {
        let mut repository = DemoRepository::default();
        let first = repository
            .query(1, "2026-10-20", false, filter())
            .expect("first query");
        let mut changed = filter();
        changed.search = "101".into();
        let next = repository
            .query(1, "2026-10-20", false, changed)
            .expect("filter");
        assert_eq!(next.fetched_at, first.fetched_at);
        assert_eq!(next.result.summary.room_count, 1);
        let mut invalid = filter();
        invalid.section = 15;
        assert!(repository.query(1, "2026-10-20", false, invalid).is_err());
        assert!(
            repository
                .query(1, "2026-10-20", false, filter())
                .expect("recover")
                .from_cache
        );
    }
    #[test]
    fn query_dates_use_beijing_midnight_and_validate_input() {
        assert_eq!(
            query_dates("2026-12-31T16:30:00Z").expect("dates"),
            ("2027-01-01".into(), "2027-01-02".into())
        );
        assert!(query_dates("2026-10-20").is_err());
    }
}
