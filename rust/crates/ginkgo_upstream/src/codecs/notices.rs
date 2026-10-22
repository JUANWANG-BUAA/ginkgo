//! Public news list projection, ported from CampusNoticeParser.
use crate::AppError;
pub use ginkgo_domain::features::notices::*;
use regex::Regex;
use std::sync::LazyLock;
static TITLE: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?is)<h3\b[^>]*>(.*?)</h3>").expect("constant regex"));
static LINK: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r#"(?is)<a\b[^>]*href=["']([^"']+)["']"#).expect("constant regex"));
static PUBLICATION_DATE: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r#"(?is)<div\b[^>]*class=["'][^"']*pub_date[^"']*["'][^>]*>(.*?)</div>"#)
        .expect("constant regex")
});
static DAY: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?is)<b\b[^>]*>(\d{1,2})</b>").expect("constant regex"));
static YEAR_MONTH: LazyLock<Regex> = LazyLock::new(|| {
    Regex::new(r"(?is)<span\b[^>]*>(\d{4}\.\d{1,2})</span>").expect("constant regex")
});
static SUMMARY: LazyLock<Regex> =
    LazyLock::new(|| Regex::new(r"(?is)<p\b[^>]*>(.*?)</p>").expect("constant regex"));
fn capture(pattern: &Regex, text: &str) -> Option<String> {
    pattern
        .captures(text)?
        .get(1)
        .map(|m| m.as_str().to_owned())
}
fn plain(text: &str) -> String {
    TAGS.replace_all(text, "")
        .replace("&amp;", "&")
        .replace("&nbsp;", " ")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .trim()
        .to_owned()
}
static TAGS: LazyLock<Regex> = LazyLock::new(|| Regex::new("<[^>]*>").expect("constant regex"));

pub fn parse(html: &str) -> Result<Vec<Notice>, AppError> {
    let base = &*crate::endpoints::NOTICE_PAGE;
    static ROWS: LazyLock<Regex> =
        LazyLock::new(|| Regex::new(r"(?is)<li\b[^>]*>(.*?)</li>").expect("constant regex"));
    let mut result = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for row in ROWS.captures_iter(html) {
        let row = &row[1];
        let Some(title) = capture(&TITLE, row) else {
            continue;
        };
        let raw = capture(&LINK, row).ok_or_else(AppError::changed)?;
        let link = base.join(&plain(&raw)).map_err(|_| AppError::changed())?;
        if link.host_str() != base.host_str() {
            continue;
        }
        if link.scheme() != "https" {
            return Err(AppError::changed());
        }
        let date = capture(&PUBLICATION_DATE, row).ok_or_else(AppError::changed)?;
        let day = capture(&DAY, &date).ok_or_else(AppError::changed)?;
        let ym = capture(&YEAR_MONTH, &date).ok_or_else(AppError::changed)?;
        let (year, month) = ym.split_once('.').ok_or_else(AppError::changed)?;
        let parsed = chrono::NaiveDate::from_ymd_opt(
            year.parse().map_err(|_| AppError::changed())?,
            month.parse().map_err(|_| AppError::changed())?,
            day.parse().map_err(|_| AppError::changed())?,
        )
        .ok_or_else(AppError::changed)?;
        let title = plain(&title);
        if title.is_empty() || !seen.insert(link.to_string()) {
            return Err(AppError::changed());
        }
        result.push(Notice {
            title,
            summary: plain(&capture(&SUMMARY, row).unwrap_or_default()),
            published_at: parsed.to_string(),
            url: link.to_string(),
        });
    }
    // Existing source has no confirmed upstream empty marker. Fail closed on blank/drift.
    if result.is_empty() {
        return Err(AppError::changed());
    }
    result.truncate(5);
    Ok(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn only_validated_official_https_destinations_leave_the_provider() {
        let html = |link: &str| {
            format!(
                r#"<li><a href="{link}"><h3>合成通知</h3></a><div class="pub_date"><b>22</b><span>2026.10</span></div><p>合成摘要</p></li>"#
            )
        };
        let result = parse(&html("/info/1001/123.htm")).expect("official destination");
        assert_eq!(result[0].url, "https://news.buaa.edu.cn/info/1001/123.htm");
        assert!(parse(&html("https://other.invalid/info/123.htm")).is_err());
        assert!(parse(&html("http://news.buaa.edu.cn/info/1001/123.htm")).is_err());
    }
}
