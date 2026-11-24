//! On-demand read-only student income query through an isolated narrow port.
use super::*;
pub use ginkgo_domain::features::finance::{FinanceIncomeEntry, FinanceIncomeReport};

impl<U: FinanceIncomeSource> Workspace<U> {
    pub async fn load_finance_incomes(&self) -> Result<FinanceIncomeReport, AppError> {
        self.upstream.finance_incomes().await
    }
}
