//! Public news list projection, ported from CampusNoticeParser.
use crate::AppError;
use regex::Regex;
use serde::Serialize;
#[derive(Clone, Debug, Serialize)]
pub struct Notice {
    pub title: String,
    pub summary: String,
    pub published_at: String,
    pub url: String,
}
fn capture(pattern: &str, text: &str) -> Option<String> {
    Regex::new(pattern)
        .ok()?
        .captures(text)?
        .get(1)
        .map(|m| m.as_str().to_owned())
}
fn plain(text: &str) -> String {
    Regex::new("<[^>]*>")
        .expect("constant regex")
        .replace_all(text, "")
        .replace("&amp;", "&")
        .replace("&nbsp;", " ")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .trim()
        .to_owned()
}
pub fn parse(html: &str) -> Result<Vec<Notice>, AppError> {
    let base = url::Url::parse("https://news.buaa.edu.cn/tzgg.htm").expect("constant URL");
    let rows = Regex::new(r"(?is)<li\b[^>]*>(.*?)</li>").expect("constant regex");
    let mut result = Vec::new();
    let mut seen = std::collections::HashSet::new();
    for row in rows.captures_iter(html) {
        let row = &row[1];
        let Some(title) = capture(r"(?is)<h3\b[^>]*>(.*?)</h3>", row) else {
            continue;
        };
        let raw =
            capture(r#"(?is)<a\b[^>]*href=["']([^"']+)["']"#, row).ok_or_else(AppError::changed)?;
        let link = base.join(&plain(&raw)).map_err(|_| AppError::changed())?;
        if link.host_str() != base.host_str() {
            continue;
        }
        if link.scheme() != "https" {
            return Err(AppError::changed());
        }
        let date = capture(
            r#"(?is)<div\b[^>]*class=["'][^"']*pub_date[^"']*["'][^>]*>(.*?)</div>"#,
            row,
        )
        .ok_or_else(AppError::changed)?;
        let day = capture(r"(?is)<b\b[^>]*>(\d{1,2})</b>", &date).ok_or_else(AppError::changed)?;
        let ym = capture(r"(?is)<span\b[^>]*>(\d{4}\.\d{1,2})</span>", &date)
            .ok_or_else(AppError::changed)?;
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
            summary: plain(&capture(r"(?is)<p\b[^>]*>(.*?)</p>", row).unwrap_or_default()),
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
