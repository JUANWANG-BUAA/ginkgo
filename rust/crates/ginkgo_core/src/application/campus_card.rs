use super::*;

impl<U: CampusCardBalanceSource> Workspace<U> {
    pub async fn campus_card_balance(
        &self,
    ) -> Result<ginkgo_domain::features::campus_card::CampusCardBalance, AppError> {
        self.upstream.campus_card_balance().await
    }
}
