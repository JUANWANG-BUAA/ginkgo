//! Real read-only classroom use case with the mirror's five-minute snapshot.
use super::session_service::SchoolClient;
use crate::{
    adapters::classroom_http::query_classrooms,
    auth::CredentialVault,
    features::classroom::{self, FilterRequest, FilterResult, Room},
    foundation::http::HttpTransport,
    AppError,
};
use chrono::NaiveDate;
use ginkgo_domain::ports::*;
use std::collections::BTreeMap;

pub use ginkgo_domain::ports::ClassroomQueryInput;

pub use ginkgo_domain::ports::ClassroomOutcome;

fn validate(input: &ClassroomQueryInput) -> Result<(), AppError> {
    if !(1..=3).contains(&input.campus)
        || NaiveDate::parse_from_str(&input.date, "%Y-%m-%d").is_err()
        || !(0..=14).contains(&input.section)
        || !(0..=14).contains(&input.minimum_free_sections)
        || !(0..=14).contains(&input.minimum_consecutive_sections)
    {
        return Err(AppError::invalid());
    }
    Ok(())
}

fn filter(
    rooms: BTreeMap<String, Vec<Room>>,
    input: &ClassroomQueryInput,
) -> Result<FilterResult, AppError> {
    classroom::filter(FilterRequest {
        source_rooms: rooms,
        search: input.search.clone(),
        section: input.section,
        minimum_free_sections: input.minimum_free_sections,
        minimum_consecutive_sections: input.minimum_consecutive_sections,
        building: input
            .building
            .clone()
            .map(|building| building.trim().to_owned())
            .filter(|building| !building.is_empty()),
        sort: input.sort,
    })
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> ClassroomSource for SchoolClient<T, V> {
    async fn load_classrooms(
        &self,
        input: &ClassroomQueryInput,
    ) -> Result<ClassroomOutcome, AppError> {
        self.current_account()?;
        validate(input)?;
        let key = (input.campus, input.date.clone());

        if !input.force_refresh {
            let cached = self.snapshots.classrooms.lock();
            if let Some(entry) = cached.fresh(&key) {
                return Ok(ClassroomOutcome {
                    result: filter(entry.value.clone(), input)?,
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let ticket = self.snapshots.classrooms.lock().begin(&key);
        let fetched = match query_classrooms(&self.session, input.campus, &input.date).await {
            Err(error) if error.code == crate::ErrorCode::SessionExpired => {
                match self.silent_login().await {
                    Ok(()) => query_classrooms(&self.session, input.campus, &input.date).await,
                    Err(error) => Err(error),
                }
            }
            other => other,
        };

        match fetched {
            Ok(rooms) => {
                let timestamp = self
                    .snapshots
                    .classrooms
                    .lock()
                    .insert_if_current(key, ticket, rooms.clone());
                Ok(ClassroomOutcome {
                    result: filter(rooms, input)?,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.snapshots.classrooms.lock();
                match cached.any(&key) {
                    Some(entry) => Ok(ClassroomOutcome {
                        result: filter(entry.value.clone(), input)?,
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}
