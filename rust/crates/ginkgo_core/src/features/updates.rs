//! Android releases have an independent version line from macOS.
use crate::AppError;
use semver::Version;
use serde::{Deserialize, Serialize};

pub const REPOSITORY: &str = "https://github.com/JUANWANG-BUAA/ginkgo";
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct UpdateSummary {
    pub current: String,
    pub latest: Option<String>,
    pub available: bool,
    pub page_url: Option<String>,
    pub notes: Option<String>,
    pub apk_available: bool,
    pub download_url: Option<String>,
}
#[derive(Deserialize)]
struct Release {
    tag_name: String,
    html_url: String,
    draft: bool,
    prerelease: bool,
    body: Option<String>,
    assets: Vec<Asset>,
}
#[derive(Deserialize)]
struct Asset {
    name: String,
    browser_download_url: String,
    size: u64,
}
fn trusted_url(value: &str, path: &str) -> bool {
    url::Url::parse(value).is_ok_and(|u| {
        u.scheme() == "https"
            && u.host_str() == Some("github.com")
            && u.username().is_empty()
            && u.password().is_none()
            && u.port().is_none()
            && u.path().starts_with(path)
            && u.query().is_none()
            && u.fragment().is_none()
    })
}
pub fn parse(body: &str, current: &str) -> Result<UpdateSummary, AppError> {
    let current_version = Version::parse(current).map_err(|_| AppError::invalid())?;
    let releases: Vec<Release> = serde_json::from_str(body).map_err(|_| AppError::changed())?;
    let mut candidates = Vec::new();
    for release in releases {
        if release.draft {
            continue;
        }
        let Some(tag) = release.tag_name.strip_prefix("android-v") else {
            continue;
        };
        let version = Version::parse(tag).map_err(|_| AppError::changed())?;
        if current_version.pre.is_empty() && (release.prerelease || !version.pre.is_empty()) {
            continue;
        }
        if !trusted_url(
            &release.html_url,
            "/JUANWANG-BUAA/ginkgo/releases/tag/android-v",
        ) || release.html_url != format!("{REPOSITORY}/releases/tag/{}", release.tag_name)
        {
            return Err(AppError::changed());
        }
        candidates.push((version, release));
    }
    candidates.sort_by(|a, b| b.0.cmp_precedence(&a.0));
    let mut summary = UpdateSummary {
        current: current.into(),
        latest: None,
        available: false,
        page_url: None,
        notes: None,
        apk_available: false,
        download_url: None,
    };
    if let Some((version, release)) = candidates.into_iter().next() {
        summary.available = version.cmp_precedence(&current_version).is_gt();
        summary.latest = Some(version.to_string());
        let expected_name = format!("Ginkgo-{version}-android-arm64.apk");
        let expected_url = format!(
            "{REPOSITORY}/releases/download/{}/{}",
            release.tag_name, expected_name
        );
        summary.download_url = release
            .assets
            .iter()
            .find(|asset| {
                asset.name == expected_name
                    && asset.size > 0
                    && asset.browser_download_url == expected_url
                    && trusted_url(
                        &asset.browser_download_url,
                        "/JUANWANG-BUAA/ginkgo/releases/download/android-v",
                    )
            })
            .map(|asset| asset.browser_download_url.clone());
        summary.apk_available = summary.download_url.is_some();
        summary.page_url = Some(release.html_url);
        summary.notes = release.body;
    }
    Ok(summary)
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn android_versions_assets_and_channels_are_independent() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../../fixtures/updates/releases-v1.json"
        ))
        .unwrap();
        let json = fixture["input"]["releases"].to_string();
        let body = json.as_str();
        let result = parse(body, "0.1.0-alpha.2").unwrap();
        assert_eq!(result.latest.as_deref(), Some("0.1.0-alpha.10"));
        assert!(result.available && result.apk_available);
        assert!(!parse(body, "0.1.0-alpha.10+999").unwrap().available);
        assert!(parse(body, "0.1.0").unwrap().latest.is_none());
        assert!(parse("[]", "0.1.0").unwrap().latest.is_none());
        assert!(parse("{}", "0.1.0").is_err());
        assert!(parse(body, "wrong").is_err());
        let spoof = body.replace("https://github.com/", "https://github.com.evil.example/");
        assert!(parse(&spoof, "0.1.0-alpha.1").is_err());
        let missing = body.replace("-android-arm64.apk", ".dmg");
        assert!(!parse(&missing, "0.1.0-alpha.1").unwrap().apk_available);
    }
    #[test]
    fn download_must_match_release_tag_filename_and_repository() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../../fixtures/updates/releases-v1.json"
        ))
        .expect("fixture");
        let releases = fixture["input"]["releases"].clone();
        let parsed = parse(&releases.to_string(), "0.1.0-alpha.1").expect("release");
        assert_eq!(parsed.download_url.as_deref(), Some("https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.10/Ginkgo-0.1.0-alpha.10-android-arm64.apk"));
        for path in [
            "https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.2/Ginkgo-0.1.0-alpha.10-android-arm64.apk",
            "https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.10/Other-android-arm64.apk",
            "https://github.com/other/ginkgo/releases/download/android-v0.1.0-alpha.10/Ginkgo-0.1.0-alpha.10-android-arm64.apk",
            "https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.10/Ginkgo-0.1.0-alpha.10-android-arm64.apk?redirect=1",
        ] {
            let mut changed = releases.clone();
            changed[2]["assets"][0]["browser_download_url"] = serde_json::json!(path);
            let parsed = parse(&changed.to_string(), "0.1.0-alpha.1").expect("missing compatible asset");
            assert!(!parsed.apk_available);
            assert!(parsed.download_url.is_none());
        }
        let mut changed = releases.clone();
        changed[2]["html_url"] = changed[1]["html_url"].clone();
        assert!(parse(&changed.to_string(), "0.1.0-alpha.1").is_err());
        let mut changed = releases;
        changed[2]["assets"][0]["size"] = serde_json::json!(0);
        assert!(parse(&changed.to_string(), "0.1.0-alpha.1")
            .expect("empty asset")
            .download_url
            .is_none());
    }
}
