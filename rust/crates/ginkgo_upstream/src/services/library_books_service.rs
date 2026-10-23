//! Public catalogue reads. No cache, no personal data, no write endpoint:
//! each search is an explicit user action and holdings are fetched on demand.
use super::SchoolClient;
use crate::{
    adapters::library_books_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
};
pub use ginkgo_domain::features::library_books::{BookHolding, BookPage};
use ginkgo_domain::ports::{
    LibraryCatalogSource, DEFAULT_SORT, PAGE_MAX, PAGE_MIN, PAGE_SIZE, QUERY_MAX_CHARS, SORT_FIELDS,
};

impl<T: HttpTransport + Send + Sync, V: CredentialVault> LibraryCatalogSource
    for SchoolClient<T, V>
{
    async fn search_books(
        &self,
        query: String,
        page: i64,
        sort: String,
        descending: bool,
    ) -> Result<BookPage, AppError> {
        let query = query.trim();
        if query.is_empty()
            || query.chars().count() > QUERY_MAX_CHARS
            || !(PAGE_MIN..=PAGE_MAX).contains(&page)
        {
            return Err(AppError::invalid());
        }
        // Only fields that provably reorder live results are forwarded; an
        // unknown value is refused instead of being sent upstream.
        let sort = if sort.trim().is_empty() {
            DEFAULT_SORT.to_string()
        } else {
            sort.trim().to_string()
        };
        if !SORT_FIELDS.contains(&sort.as_str()) {
            return Err(AppError::invalid());
        }
        library_books_http::search(
            &self.session,
            self.preference().into(),
            query,
            page,
            PAGE_SIZE,
            &sort,
            descending,
        )
        .await
    }

    async fn book_holdings(&self, bib_id: String) -> Result<Vec<BookHolding>, AppError> {
        // The identifier is opaque: only its shape is bounded, never reinterpreted.
        let bib_id = bib_id.trim();
        if bib_id.is_empty() || bib_id.len() > 128 || bib_id.chars().any(char::is_control) {
            return Err(AppError::invalid());
        }
        library_books_http::holdings(&self.session, self.preference().into(), bib_id).await
    }
}
