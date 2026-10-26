//! Business ports are independent of HTTP, school schemas, credentials and platform adapters.
mod academic;
pub use academic::*;
mod classroom;
pub use classroom::*;
mod checkin;
pub use checkin::*;
mod library;
pub use library::*;
mod session;
pub use session::*;
mod bykc;
pub use bykc::*;
mod graduate;
pub use graduate::*;
mod homework;
pub use homework::*;
mod notices;
pub use notices::*;
mod cgyy;
pub use cgyy::*;
mod library_stats;
pub use library_stats::*;
mod library_loans;
pub use library_loans::*;
mod library_books;
pub use library_books::*;
mod shuttle;
pub use shuttle::*;
mod outcome;
pub use outcome::*;

mod homework_submission;
pub use homework_submission::*;

mod learning;
pub use learning::*;
mod query_snapshots;
pub use query_snapshots::*;
