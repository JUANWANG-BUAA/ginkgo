//! Verified public help destinations; no login or upstream requests.

pub fn official_url(id: &str) -> Option<String> {
    let url = match id {
        "official-print-guide" => "https://nic.buaa.edu.cn/info/1044/3785.htm",
        "official-housing-guide" => "https://xszx.buaa.edu.cn/info/1173/1393.htm",
        "official-career" => "https://career.buaa.edu.cn/frontpage/buaa/html/index.html",
        "official-lectures" => "https://www.buaa.edu.cn/index/xswh1.htm",
        "official-network-guide" => "https://nic.buaa.edu.cn/fwzn.htm",
        _ => return None,
    };
    Some(url.to_owned())
}

#[cfg(test)]
mod tests {
    use super::official_url;

    #[test]
    fn only_known_official_services_have_https_destinations() {
        for id in [
            "official-print-guide",
            "official-housing-guide",
            "official-career",
            "official-lectures",
            "official-network-guide",
        ] {
            let url = official_url(id).expect("known destination");
            assert!(url.starts_with("https://"));
            assert!(url::Url::parse(&url)
                .unwrap()
                .host_str()
                .unwrap()
                .ends_with(".buaa.edu.cn"));
        }
        assert_eq!(official_url("unknown"), None);
    }
}
