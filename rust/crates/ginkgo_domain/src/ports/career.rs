//! Stable public career-fair capability.
use crate::{features::career::CareerEvents, AppError};

#[derive(Debug, Clone)]
pub struct CareerEventsOutcome {
    pub data: CareerEvents,
    pub failure: Option<AppError>,
}

pub trait CareerEventsSource: Send + Sync {
    fn load_career_events(
        &self,
        month: &str,
        force: bool,
    ) -> impl std::future::Future<Output = Result<CareerEventsOutcome, AppError>> + Send;
}
