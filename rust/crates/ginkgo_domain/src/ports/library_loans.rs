//! No renewal, reminder, disk storage or public catalogue substitution.
use crate::{features::library_loans::LibraryLoanPage, AppError};
pub trait LibraryLoansSource: Send + Sync {
    fn library_loans(
        &self,
        page: u32,
    ) -> impl std::future::Future<Output = Result<LibraryLoanPage, AppError>> + Send;
}
