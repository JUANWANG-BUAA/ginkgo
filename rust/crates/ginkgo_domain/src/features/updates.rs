use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSummary {
    pub current: String,
    pub latest: Option<String>,
    pub available: bool,
    pub page_url: Option<String>,
    pub notes: Option<String>,
    pub apk_available: bool,
    /// Present only when GitHub supplies a complete, verifiable arm64 asset.
    pub download: Option<AndroidDownload>,
}
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct AndroidDownload {
    pub version: String,
    pub name: String,
    pub url: String,
    pub api_url: String,
    pub size: u64,
    pub sha256: String,
}
