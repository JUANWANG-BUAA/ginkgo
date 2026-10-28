//! Stable public career-fair capability.
use crate::{features::career::CareerEvents, AppError};

pub type CareerEventsOutcome = super::ReadSnapshot<CareerEvents>;

pub trait CareerEventsSource: Send + Sync {
    fn load_career_events(
        &self,
        month: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<CareerEventsOutcome, AppError>> + Send;
}
