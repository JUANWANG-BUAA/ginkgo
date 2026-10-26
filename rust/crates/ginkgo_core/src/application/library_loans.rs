//! Private reads through a dedicated business port, never public holdings.
use super::*;
pub use ginkgo_domain::features::library_loans::{LibraryLoan, LibraryLoanPage};
impl<U: LibraryLoansSource> Workspace<U> {
    pub async fn load_library_loans(&self, page: u32) -> Result<LibraryLoanPage, AppError> {
        if !(1..=100).contains(&page) {
            return Err(AppError::invalid());
        }
        self.upstream.library_loans(page).await
    }
}
