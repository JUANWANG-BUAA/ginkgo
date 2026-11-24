//! On-demand read-only portal metrics & campus network traffic through an isolated narrow port.
use super::*;
pub use ginkgo_domain::features::network_account::{
    NetworkAccountReport, NetworkTrafficProduct, PortalMetricValue,
};

impl<U: NetworkAccountSource> Workspace<U> {
    pub async fn load_network_account(&self) -> Result<NetworkAccountReport, AppError> {
        self.upstream.network_account().await
    }
}
