//! Public catalogue business capability. Anonymous reads only: no loans,
//! renewal, reservation or any other personal/write endpoint.
use crate::{
    features::library_books::{BookHolding, BookPage},
    AppError,
};

pub trait LibraryCatalogSource: Send + Sync {
    /// `sort` is one of [`SORT_FIELDS`]; `descending` maps to `sortType`.
    fn search_books(
        &self,
        query: String,
        page: i64,
        sort: String,
        descending: bool,
    ) -> impl std::future::Future<Output = Result<BookPage, AppError>> + Send;

    fn book_holdings(
        &self,
        bib_id: String,
    ) -> impl std::future::Future<Output = Result<Vec<BookHolding>, AppError>> + Send;
}

/// Caller-supplied search bounds. The service clamps instead of trusting the
/// bridge, and rejects an empty query without contacting the school.
pub const QUERY_MAX_CHARS: usize = 80;
pub const PAGE_MIN: i64 = 1;
pub const PAGE_MAX: i64 = 100;
pub const PAGE_SIZE: i64 = 20;

/// Sort fields confirmed against the live endpoint (2026-10-23): each one
/// reorders real results in both directions, so no value is guessed.
pub const SORT_FIELDS: [&str; 3] = ["relevance", "pub_year", "title"];
pub const DEFAULT_SORT: &str = "relevance";
