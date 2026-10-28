//! Anonymous read of the university's public academic-culture list.
use crate::{
    auth::session::Session,
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
use ginkgo_domain::features::campus_activities::{CampusActivities, CampusActivity};
use regex::Regex;
use std::{
    sync::LazyLock,
    time::{SystemTime, UNIX_EPOCH},
};

const BASE: &str = "https://www.buaa.edu.cn";

fn shanghai_timestamp() -> String {
    let now = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    chrono::DateTime::from_timestamp(now.as_secs() as i64, 0)
        .unwrap_or_default()
        .with_timezone(&chrono_tz::Asia::Shanghai)
        .format("%Y-%m-%dT%H:%M:%S%:z")
        .to_string()
}

static ITEM: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?is)<li\s+id="line_u\d+_(\d+)">.*?<a\s+href="([^"]+)">.*?<h4>(.*?)</h4>.*?<h3>(.*?)</h3>.*?<p\s+class="sj"><span[^>]*>(.*?)</span>(.*?)</p>.*?<p\s+class="dz">(.*?)</p>"#)
        .expect("activity item regex")
});
static TOTAL_PAGES: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"/([0-9]+)页").expect("total pages regex"));
static TAG: LazyLock<Regex> = LazyLock::new(|| Regex::new(r"(?s)<[^>]+>").expect("tag regex"));

fn text(value: &str) -> String {
    let plain = TAG.replace_all(value.trim(), "");
    plain
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

pub fn validate_page(page: i32) -> Result<(), AppError> {
    if !(1..=200).contains(&page) {
        return Err(AppError::invalid());
    }
    Ok(())
}

fn validate_response(response: &crate::foundation::http::HttpResponse) -> Result<(), AppError> {
    let final_host = url::Url::parse(&response.final_url)
        .ok()
        .and_then(|url| url.host_str().map(str::to_owned));
    if response.status != 200 || final_host.as_deref() != Some("www.buaa.edu.cn") {
        return Err(AppError::with_detail(
            ErrorCode::ServiceUnavailable,
            format!("activities_http_{}", response.status),
        ));
    }
    Ok(())
}

pub async fn load<T: HttpTransport + Sync>(
    session: &Session<T>,
    page: i32,
) -> Result<CampusActivities, AppError> {
    validate_page(page)?;
    let preference = session.route();
    let mut response = session
        .send_anonymous(
            HttpRequest::get(format!("{BASE}/index/xswh1.htm"))
                .header("Accept", "text/html")
                .header("User-Agent", "Ginkgo/1.0"),
            preference,
        )
        .await?;
    validate_response(&response)?;
    if page > 1 {
        let total = TOTAL_PAGES
            .captures(&response.body)
            .and_then(|capture| capture[1].parse::<i32>().ok())
            .ok_or_else(AppError::changed)?;
        if page > total {
            return Err(AppError::invalid());
        }
        response = session
            .send_anonymous(
                HttpRequest::get(format!("{BASE}/index/xswh1/{}.htm", total + 1 - page))
                    .header("Accept", "text/html")
                    .header("User-Agent", "Ginkgo/1.0"),
                preference,
            )
            .await?;
        validate_response(&response)?;
    }
    let mut activities = Vec::new();
    let mut ids = std::collections::BTreeSet::new();
    for capture in ITEM.captures_iter(&response.body) {
        let numeric = capture[1].to_owned();
        let id = format!("xswh:{numeric}");
        let title = text(&capture[4]);
        if title.is_empty() || !ids.insert(id.clone()) {
            return Err(AppError::changed());
        }
        activities.push(CampusActivity {
            id,
            title,
            category: text(&capture[3]),
            published_at: text(&capture[5]),
            activity_time: text(&capture[6]),
            place: text(&capture[7]),
            url: absolute_url(capture[2].trim()),
        });
    }
    if activities.is_empty() {
        return Err(AppError::changed());
    }
    Ok(CampusActivities {
        page,
        activities,
        fetched_at: shanghai_timestamp(),
    })
}

fn absolute_url(value: &str) -> String {
    if value.starts_with('/') {
        format!("{BASE}{value}")
    } else if value.starts_with("../") {
        format!("{BASE}/{}", value.trim_start_matches("../"))
    } else {
        value.to_owned()
    }
}

#[cfg(test)]
mod tests {
    use super::validate_page;

    #[test]
    fn activity_page_is_bounded() {
        assert!(validate_page(1).is_ok());
        assert!(validate_page(0).is_err());
    }
}
