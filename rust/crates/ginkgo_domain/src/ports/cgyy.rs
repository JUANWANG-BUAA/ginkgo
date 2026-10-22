//! Stable cgyy business capability and values.
use super::DataOutcome;
use crate::AppError;
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CgyyQuery {
    Venues,
    Day { site_id: i64, date: String },
    Orders,
}

#[derive(Clone, serde::Serialize)]
#[serde(untagged)]
pub enum CgyyData {
    Venues(Vec<crate::features::cgyy::Site>),
    Day(crate::features::cgyy::Day),
    Orders(Vec<crate::features::cgyy::Order>),
}

pub trait CgyySource: Send + Sync {
    fn load_cgyy(
        &self,
        query: CgyyQuery,
        force: bool,
    ) -> impl std::future::Future<Output = Result<CgyyOutcome, AppError>> + Send;
}

pub type CgyyOutcome = DataOutcome<CgyyData>;

pub trait CgyyMutationSource: Send + Sync {
    fn execute_cgyy(
        &self,
        command: crate::features::cgyy_booking::CgyyCommand,
    ) -> impl std::future::Future<
        Output = Result<crate::features::cgyy_booking::CgyyActionResult, AppError>,
    > + Send;
}
