use crate::{features::network_account::NetworkAccountReport, AppError};

pub trait NetworkAccountSource: Send + Sync {
    fn network_account(
        &self,
    ) -> impl std::future::Future<Output = Result<NetworkAccountReport, AppError>> + Send;
}
