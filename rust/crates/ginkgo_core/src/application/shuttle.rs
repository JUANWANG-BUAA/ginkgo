//! Public shuttle timetable command: read-only, no identity, no writes.
use super::*;
use crate::features::shuttle::ShuttleTimetable;

impl<U: ShuttleSource> Workspace<U> {
    pub async fn load_shuttle_timetable(&self) -> Result<ShuttleTimetable, AppError> {
        self.upstream.load_shuttle_timetable().await
    }
}
