//! Public OPAC catalogue values (API §6.1). Read-only, no personal data.
use serde::Serialize;

/// One catalogue search hit. Fields the school reports as strings, arrays or
/// numbers are flattened to text here; unknown values stay empty instead of
/// being guessed, and identifiers are never converted into each other.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct BookHit {
    pub bib_id: String,
    pub title: String,
    pub author: String,
    pub publisher: String,
    pub year: String,
    /// Search returns an array, other sources a string; both join with " · ".
    pub callno: String,
    pub isbn: String,
    /// Reported copy availability, or `None` when the source stays silent.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub items_available: Option<i64>,
    /// Reported total copy count, or `None`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub item_count: Option<i64>,
}

/// One bounded page of hits. `total` keeps the school's own value while
/// `truncated` says whether this page exhausted it.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct BookPage {
    pub page: i64,
    pub page_size: i64,
    pub total: i64,
    pub actual_total: i64,
    pub items: Vec<BookHit>,
    /// True when the school reported more matches than this page returned.
    pub has_more: bool,
}

/// One physical copy. Status stays the school's own text; it is never turned
/// into a local "available" boolean.
#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub struct BookHolding {
    pub call_no: String,
    pub bar_code: String,
    pub library: String,
    pub location: String,
    pub status: String,
}
