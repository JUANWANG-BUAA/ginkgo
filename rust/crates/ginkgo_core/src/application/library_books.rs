//! Public catalogue commands depend only on the anonymous read port.
use super::*;
use crate::features::library_books::{BookHolding, BookPage};

impl<U: LibraryCatalogSource> Workspace<U> {
    pub async fn search_library_books(
        &self,
        query: String,
        page: i64,
    ) -> Result<BookPage, AppError> {
        self.upstream.search_books(query, page).await
    }

    pub async fn load_book_holdings(&self, bib_id: String) -> Result<Vec<BookHolding>, AppError> {
        self.upstream.book_holdings(bib_id).await
    }
}
