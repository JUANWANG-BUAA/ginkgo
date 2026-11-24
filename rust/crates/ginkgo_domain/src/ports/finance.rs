use crate::{features::finance::FinanceIncomeReport, AppError};

pub trait FinanceIncomeSource: Send + Sync {
    fn finance_incomes(
        &self,
    ) -> impl std::future::Future<Output = Result<FinanceIncomeReport, AppError>> + Send;
}
