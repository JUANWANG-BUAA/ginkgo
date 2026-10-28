//! Public OPAC catalogue HTTP (API §6.1). Anonymous reads never send or retain
//! cookies from either the public site or the signed-in library session.
use crate::{
    auth::session::{RouteMode, Session},
    codecs::library_books,
    codecs::library_books::{BookHolding, BookPage},
    foundation::http::{HttpMethod, HttpRequest, HttpResponse, HttpTransport},
    AppError,
};
use serde_json::json;

pub const BASE: &str = "https://space.lib.buaa.edu.cn/meta-local";
const HOST: &str = "space.lib.buaa.edu.cn";

fn check(response: &HttpResponse, path: &str) -> Result<(), AppError> {
    // The detail stays coarse (status + which check failed) so the diagnostic
    // panel can distinguish "blocked/redirected" from "changed response"
    // without logging the URL, query or any personal context.
    let parsed = url::Url::parse(&response.final_url).map_err(|_| AppError::changed())?;
    if response.status != 200 {
        return Err(AppError::with_detail(
            crate::ErrorCode::ServiceUnavailable,
            format!("lib_catalog_http_{}", response.status),
        ));
    }
    if parsed.scheme() != "https" || parsed.host_str() != Some(HOST) {
        return Err(AppError::with_detail(
            crate::ErrorCode::ServiceUnavailable,
            "lib_catalog_foreign_host",
        ));
    }
    if !parsed.path().starts_with(path) {
        return Err(AppError::with_detail(
            crate::ErrorCode::ServiceUnavailable,
            "lib_catalog_path_changed",
        ));
    }
    Ok(())
}

fn body(response: &HttpResponse) -> Result<serde_json::Value, AppError> {
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}

pub fn search_body(
    query: &str,
    page: i64,
    page_size: i64,
    sort: &str,
    descending: bool,
) -> serde_json::Value {
    // Official SearchParam shape: a single "all" term with operator "*".
    json!({
        "page": page,
        "pageSize": page_size,
        "indexName": "idx.opac",
        "sortField": sort,
        "sortType": if descending { "desc" } else { "asc" },
        "collapseField": "groupId",
        "queryFieldList": [{
            "logic": 0,
            "field": "all",
            "values": [query],
            "operator": "*"
        }],
        "filterFieldList": []
    })
}

pub async fn search<T: HttpTransport + Sync>(
    shared: &Session<T>,
    preference: RouteMode,
    query: &str,
    page: i64,
    page_size: i64,
    sort: &str,
    descending: bool,
) -> Result<BookPage, AppError> {
    let mut request = HttpRequest::new(
        HttpMethod::Post,
        format!("{BASE}/opac/search?coverFirst=false&disable_facet=false"),
    )
    .header("Accept", "application/json, text/plain, */*")
    .header("Content-Type", "application/json")
    .header("Referer", "https://space.lib.buaa.edu.cn/")
    .header("User-Agent", "Ginkgo/1.0");
    request.body = Some(search_body(query, page, page_size, sort, descending).to_string());
    let response = shared.send_anonymous(request, preference).await?;
    check(&response, "/meta-local/opac/search")?;
    library_books::page(&body(&response)?, page, page_size)
}

pub async fn holdings<T: HttpTransport + Sync>(
    shared: &Session<T>,
    preference: RouteMode,
    bib_id: &str,
) -> Result<Vec<BookHolding>, AppError> {
    let encoded = url::form_urlencoded::byte_serialize(bib_id.as_bytes()).collect::<String>();
    let response = shared
        .send_anonymous(
            HttpRequest::get(format!(
                "{BASE}/opac/bibs/{encoded}/holdings?isMobile=0&relateStat=1"
            ))
            .header("Accept", "application/json, text/plain, */*")
            .header("Referer", "https://space.lib.buaa.edu.cn/")
            .header("User-Agent", "Ginkgo/1.0"),
            preference,
        )
        .await?;
    check(&response, "/meta-local/opac/bibs/")?;
    library_books::holdings(&body(&response)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn search_body_matches_the_documented_shape() {
        let body = search_body("合成词", 2, 20, "relevance", true);
        assert_eq!(body["page"], 2);
        assert_eq!(body["pageSize"], 20);
        assert_eq!(body["indexName"], "idx.opac");
        assert_eq!(body["queryFieldList"][0]["field"], "all");
        assert_eq!(body["queryFieldList"][0]["values"][0], "合成词");
        assert_eq!(body["filterFieldList"], json!([]));
        assert_eq!(body["sortField"], "relevance");
        assert_eq!(body["sortType"], "desc");
        // Both directions of every whitelisted field travel verbatim.
        let by_year = search_body("合成词", 1, 20, "pub_year", false);
        assert_eq!(by_year["sortField"], "pub_year");
        assert_eq!(by_year["sortType"], "asc");
    }
}
