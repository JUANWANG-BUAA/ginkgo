//! Android releases have an independent version line from macOS.
use crate::AppError;
pub use ginkgo_domain::features::updates::*;
use semver::Version;
use serde::Deserialize;

pub const REPOSITORY: &str = "https://github.com/JUANWANG-BUAA/ginkgo";
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
    id: Option<u64>,
    digest: Option<String>,
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
        ) {
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
        download: None,
    };
    if let Some((version, release)) = candidates.into_iter().next() {
        summary.available = version.cmp_precedence(&current_version).is_gt();
        summary.latest = Some(version.to_string());
        summary.apk_available = release.assets.iter().any(|a| {
            a.name.ends_with("-android-arm64.apk")
                && a.size > 0
                && trusted_url(
                    &a.browser_download_url,
                    "/JUANWANG-BUAA/ginkgo/releases/download/android-v",
                )
        });
        let expected_name = format!("Ginkgo-{version}-android-arm64.apk");
        let expected_url =
            format!("{REPOSITORY}/releases/download/android-v{version}/{expected_name}");
        summary.download = release.assets.iter().find_map(|asset| {
            let digest = asset.digest.as_deref()?.strip_prefix("sha256:")?;
            let id = asset.id.filter(|id| *id > 0)?;
            if asset.name != expected_name
                || asset.browser_download_url != expected_url
                || !(1..=268_435_456).contains(&asset.size)
                || digest.len() != 64
                || !digest.bytes().all(|byte| byte.is_ascii_hexdigit())
            {
                return None;
            }
            Some(AndroidDownload {
                version: version.to_string(),
                name: asset.name.clone(),
                url: expected_url.clone(),
                api_url: format!(
                    "https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases/assets/{id}"
                ),
                size: asset.size,
                sha256: digest.to_ascii_lowercase(),
            })
        });
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
    fn in_app_download_requires_exact_release_asset_and_digest() {
        let fixture: serde_json::Value = serde_json::from_str(include_str!(
            "../../../../../fixtures/updates/releases-v1.json"
        ))
        .unwrap();
        let mut releases = fixture["input"]["releases"].clone();
        let asset = &mut releases[2]["assets"][0];
        asset["id"] = serde_json::json!(123);
        asset["digest"] = serde_json::json!(format!("sha256:{}", "a".repeat(64)));
        let result = parse(&releases.to_string(), "0.1.0-alpha.1").unwrap();
        assert_eq!(result.download.unwrap().sha256, "a".repeat(64));
        for (key, value) in [
            ("digest", serde_json::json!("sha256:123")),
            ("id", serde_json::json!(0)),
            ("size", serde_json::json!(268_435_457)),
            ("name", serde_json::json!("unrelated-android-arm64.apk")),
            ("browser_download_url", serde_json::json!(
                "https://github.com/JUANWANG-BUAA/ginkgo/releases/download/android-v0.1.0-alpha.2/Ginkgo-0.1.0-alpha.10-android-arm64.apk"
            )),
        ] {
            let mut invalid = releases.clone();
            invalid[2]["assets"][0][key] = value;
            assert!(parse(&invalid.to_string(), "0.1.0-alpha.1").unwrap().download.is_none());
        }
    }
}
