use crate::ErrorCode;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PortalMetricValue {
    pub value: String,
    pub unit: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetworkTrafficProduct {
    pub product_name: Option<String>,
    pub used_text: String,
    pub free_remaining_text: String,
    pub paid_remaining_text: String,
    pub package_count: u32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NetworkAccountReport {
    pub net_fee_minor: Option<i64>,
    pub net_fee_failure: Option<ErrorCode>,
    pub unreturned_books: Option<PortalMetricValue>,
    pub unread_mail: Option<PortalMetricValue>,
    pub cloud_drive_free: Option<PortalMetricValue>,
    pub portal_failure: Option<ErrorCode>,
    pub traffic_products: Vec<NetworkTrafficProduct>,
    pub traffic_failure: Option<ErrorCode>,
    pub fetched_at: String,
}
