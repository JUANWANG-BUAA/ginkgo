//! Real read-only classroom use case with the mirror's five-minute snapshot.
use super::session_service::SchoolClient;
use crate::{
    adapters::classroom_http::query_classrooms,
    auth::CredentialVault,
    codecs::classroom::{self, FilterRequest, FilterResult, Room},
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
        let account = self.current_account()?;
        validate(input)?;
        let key = (input.campus, input.date.clone());

        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.classrooms,
            key,
            input.force_refresh,
            async {
                match query_classrooms(&self.session, input.campus, &input.date).await {
                    Err(error) if error.code == crate::ErrorCode::SessionExpired => {
                        match self.silent_login().await {
                            Ok(()) => {
                                query_classrooms(&self.session, input.campus, &input.date).await
                            }
                            Err(error) => Err(error),
                        }
                    }
                    other => other,
                }
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(ClassroomOutcome {
            result: filter(snapshot.data, input)?,
            fetched_at: snapshot.fetched_at,
            from_cache: snapshot.from_cache,
            stale: snapshot.stale,
            failure: snapshot.failure,
        })
    }
}
