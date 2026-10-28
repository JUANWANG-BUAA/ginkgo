use crate::{features::campus_card::CampusCardBalance, AppError};

pub trait CampusCardBalanceSource: Send + Sync {
    fn campus_card_balance(
        &self,
    ) -> impl std::future::Future<Output = Result<CampusCardBalance, AppError>> + Send;
}
