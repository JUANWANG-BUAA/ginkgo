//! School protocol adapters, authentication, transport and response codecs.
//! Depends only on domain values; never on application orchestration or Flutter.
pub mod adapters;
pub mod auth;
pub mod codecs;
pub mod foundation;
pub use ginkgo_domain::{AppError, ErrorCode};
#[cfg(any(test, feature = "test-support"))]
#[doc(hidden)]
pub mod test_support;

pub mod services;

mod endpoints;
