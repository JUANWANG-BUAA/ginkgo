use serde::Serialize;

#[derive(Clone, Debug, Serialize)]
pub struct Notice {
    pub title: String,
    pub summary: String,
    pub published_at: String,
    pub url: String,
}
