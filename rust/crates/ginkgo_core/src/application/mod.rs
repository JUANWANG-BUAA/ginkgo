//! Application facade over replaceable business ports. No school session/HTTP dependency.
use crate::{
    features::{
        library::{LibraryArea, LibrarySeat, LibrarySlot},
        mutation::MutationOutcome,
        schedule::Term,
    },
    AppError,
};
pub use ginkgo_domain::ports::*;
mod bykc_projection;
pub use bykc_projection::{project_catalog, BykcCatalogView};
pub mod tasks_service;

pub struct Workspace<U> {
    upstream: U,
}
impl<U> Workspace<U> {
    pub fn new(upstream: U) -> Self {
        Self { upstream }
    }
}

mod academic;
mod bykc;
mod cgyy;
mod checkin;
mod classroom;
mod graduate;
mod homework;
mod library;
mod library_books;
mod library_stats;
mod notices;
mod session;
