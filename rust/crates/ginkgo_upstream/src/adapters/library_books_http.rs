//! Public OPAC catalogue HTTP (API §6.1). Anonymous reads on an isolated
//! cookie jar: searching a book must not carry the signed-in library session.
use crate::{
    auth::session::{RouteMode, Session},
    codecs::library_books,
    features::library_books::{BookHolding, BookPage},
    foundation::http::{HttpMethod, HttpRequest, HttpResponse, HttpTransport, TransportError},
    AppError,
};
use serde_json::json;

pub const BASE: &str = "https://space.lib.buaa.edu.cn/meta-local";
const HOST: &str = "space.lib.buaa.edu.cn";

/// Borrow the transport, not the signed-in session's cookie jars.
struct PublicTransport<'a, T>(&'a T);
impl<T: HttpTransport + Sync> HttpTransport for PublicTransport<'_, T> {
    async fn send(&self, request: HttpRequest) -> Result<HttpResponse, TransportError> {
        self.0.send(request).await
    }
}

fn check(response: &HttpResponse, path: &str) -> Result<(), AppError> {
    let parsed = url::Url::parse(&response.final_url).map_err(|_| AppError::changed())?;
    if response.status != 200
        || parsed.scheme() != "https"
        || parsed.host_str() != Some(HOST)
        || !parsed.path().starts_with(path)
    {
        return Err(AppError::unavailable());
    }
    Ok(())
}

fn body(response: &HttpResponse) -> Result<serde_json::Value, AppError> {
    serde_json::from_str(&response.body).map_err(|_| AppError::changed())
}

pub fn search_body(query: &str, page: i64, page_size: i64) -> serde_json::Value {
    // Official SearchParam shape: a single "all" term with operator "*".
    json!({
        "page": page,
        "pageSize": page_size,
        "indexName": "idx.opac",
        "sortField": "relevance",
        "sortType": "desc",
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
) -> Result<BookPage, AppError> {
    let isolated = Session::new(PublicTransport(shared.transport()));
    // Start from the user preference, not a transient fallback state.
    isolated.set_route(preference);
    let mut request = HttpRequest::new(
        HttpMethod::Post,
        format!("{BASE}/opac/search?coverFirst=false&disable_facet=false"),
    )
    .header("Accept", "application/json, text/plain, */*")
    .header("Content-Type", "application/json")
    .header("Referer", "https://space.lib.buaa.edu.cn/")
    .header("User-Agent", "Ginkgo/1.0");
    request.body = Some(search_body(query, page, page_size).to_string());
    let response = isolated.send_following_redirects(request).await?;
    check(&response, "/meta-local/opac/search")?;
    library_books::page(&body(&response)?, page, page_size)
}

pub async fn holdings<T: HttpTransport + Sync>(
    shared: &Session<T>,
    preference: RouteMode,
    bib_id: &str,
) -> Result<Vec<BookHolding>, AppError> {
    let encoded = url::form_urlencoded::byte_serialize(bib_id.as_bytes()).collect::<String>();
    let isolated = Session::new(PublicTransport(shared.transport()));
    isolated.set_route(preference);
    let response = isolated
        .send_following_redirects(
            HttpRequest::get(format!(
                "{BASE}/opac/bibs/{encoded}/holdings?isMobile=0&relateStat=1"
            ))
            .header("Accept", "application/json, text/plain, */*")
            .header("Referer", "https://space.lib.buaa.edu.cn/")
            .header("User-Agent", "Ginkgo/1.0"),
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
        let body = search_body("合成词", 2, 20);
        assert_eq!(body["page"], 2);
        assert_eq!(body["pageSize"], 20);
        assert_eq!(body["indexName"], "idx.opac");
        assert_eq!(body["queryFieldList"][0]["field"], "all");
        assert_eq!(body["queryFieldList"][0]["values"][0], "合成词");
        assert_eq!(body["filterFieldList"], json!([]));
    }
}
