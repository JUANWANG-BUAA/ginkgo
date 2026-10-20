//! Real read-only classroom use case with the mirror's five-minute snapshot.
use super::session_service::SessionService;
use crate::{
    adapters::classroom_http::query_classrooms,
    auth::CredentialVault,
    features::classroom::{self, FilterRequest, FilterResult, Room, Sort},
    foundation::http::HttpTransport,
    AppError,
};
use chrono::NaiveDate;
use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClassroomQueryInput {
    pub campus: i32,
    pub date: String,
    pub force_refresh: bool,
    pub search: String,
    pub section: i32,
    pub minimum_free_sections: i32,
    pub minimum_consecutive_sections: i32,
    pub building: Option<String>,
    pub sort: Sort,
}

#[derive(Debug)]
pub struct ClassroomOutcome {
    pub result: FilterResult,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_classrooms(
        &self,
        input: &ClassroomQueryInput,
    ) -> Result<ClassroomOutcome, AppError> {
        self.current_account()?;
        validate(input)?;
        let key = (input.campus, input.date.clone());

        if !input.force_refresh {
            let cached = self.classrooms.lock().expect("classroom cache");
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
                    .classrooms
                    .lock()
                    .expect("classroom cache")
                    .insert(key, rooms.clone());
                Ok(ClassroomOutcome {
                    result: filter(rooms, input)?,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.classrooms.lock().expect("classroom cache");
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
