//! Application rules depend only on domain values and business ports.
pub mod application;
pub use ginkgo_domain::{features, foundation, session, AppError, ErrorCode};
mod tasks_store;
