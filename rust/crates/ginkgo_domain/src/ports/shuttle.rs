//! Public shuttle timetable capability. The published page is the only source;
//! live availability and ticketing stay out until they have captured evidence.
use crate::{features::shuttle::ShuttleTimetable, AppError};

pub trait ShuttleSource: Send + Sync {
    fn load_shuttle_timetable(
        &self,
    ) -> impl std::future::Future<Output = Result<ShuttleTimetable, AppError>> + Send;
}
