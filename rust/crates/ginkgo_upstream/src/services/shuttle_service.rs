//! Official shuttle timetable read. No cache, no identity, no ticketing.
use super::SchoolClient;
use crate::{
    adapters::shuttle_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
};
pub use ginkgo_domain::features::shuttle::ShuttleTimetable;
use ginkgo_domain::ports::ShuttleSource;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> ShuttleSource for SchoolClient<T, V> {
    async fn load_shuttle_timetable(&self) -> Result<ShuttleTimetable, AppError> {
        shuttle_http::load(&self.session, self.preference().into()).await
    }
}
