//! Official browser destinations supplied by the school integration.
pub(crate) const HOMEWORK_PORTAL: &str = "https://spoc.buaa.edu.cn/spocnew/";

use std::sync::LazyLock;
pub(crate) static NOTICE_PAGE: LazyLock<url::Url> = LazyLock::new(|| {
    url::Url::parse("https://news.buaa.edu.cn/tzgg.htm").expect("constant notice URL")
});
