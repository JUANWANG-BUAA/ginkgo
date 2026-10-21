//! WebVPN gateway URL codec, ported from the Apple router so both clients
//! speak the same `d.buaa.edu.cn` URL shape.
use aes::Aes128;
use cfb_mode::{Decryptor, Encryptor};
use cipher::{AsyncStreamCipher, KeyIvInit};
use url::Url;

pub const GATEWAY_HOST: &str = "d.buaa.edu.cn";
const KEY: &[u8; 16] = b"wrdvpnisthebest!";

type Aes128CfbEnc = Encryptor<Aes128>;
type Aes128CfbDec = Decryptor<Aes128>;

pub fn should_route(url: &str) -> bool {
    let Ok(url) = Url::parse(url) else {
        return false;
    };
    let Some(host) = url.host_str() else {
        return false;
    };
    let host = host.to_ascii_lowercase();
    (host == "buaa.edu.cn" || host.ends_with(".buaa.edu.cn")) && host != GATEWAY_HOST
}

pub fn wrap(upstream: &str) -> Result<String, WebVpnError> {
    let url = Url::parse(upstream).map_err(|_| WebVpnError::InvalidUrl)?;
    let host = url.host_str().ok_or(WebVpnError::InvalidUrl)?;
    if host.eq_ignore_ascii_case(GATEWAY_HOST) {
        return Ok(upstream.to_string());
    }

    let protocol = match (url.scheme(), url.port()) {
        ("http", None | Some(80)) => "http".to_string(),
        ("https", None | Some(443)) => "https".to_string(),
        (scheme, Some(port)) => format!("{scheme}-{port}"),
        (scheme, None) => scheme.to_string(),
    };
    let encoded_host = encrypt_host(host)?;
    let mut wrapped = format!(
        "https://{GATEWAY_HOST}/{protocol}/{encoded_host}{}",
        url.path()
    );
    if let Some(query) = url.query() {
        wrapped.push('?');
        wrapped.push_str(query);
    }
    if let Some(fragment) = url.fragment() {
        wrapped.push('#');
        wrapped.push_str(fragment);
    }
    Ok(wrapped)
}

/// Unwrap a gateway URL. Gateway-owned paths that cannot be decoded are kept
/// intact, mirroring the Apple implementation.
pub fn unwrap(gateway: &str) -> String {
    let Ok(url) = Url::parse(gateway) else {
        return gateway.to_string();
    };
    if !url
        .host_str()
        .is_some_and(|host| host.eq_ignore_ascii_case(GATEWAY_HOST))
    {
        return gateway.to_string();
    }
    let Some(segments) = url
        .path_segments()
        .map(|segments| segments.collect::<Vec<_>>())
    else {
        return gateway.to_string();
    };
    if segments.len() < 2 {
        return gateway.to_string();
    }
    let Some((scheme, port)) = parse_protocol(segments[0]) else {
        return gateway.to_string();
    };
    let Some(host) = decrypt_host(segments[1]) else {
        return gateway.to_string();
    };

    let prefix = format!("/{}/{}", segments[0], segments[1]);
    let remainder = url.path().strip_prefix(&prefix).unwrap_or("");
    let mut upstream = format!("{scheme}://{host}");
    if let Some(port) = port {
        upstream.push(':');
        upstream.push_str(&port.to_string());
    }
    upstream.push_str(remainder);
    if let Some(query) = url.query() {
        upstream.push('?');
        upstream.push_str(query);
    }
    if let Some(fragment) = url.fragment() {
        upstream.push('#');
        upstream.push_str(fragment);
    }
    upstream
}

/// Resolve a `Location` value that may be absolute, gateway-relative, or
/// relative to the current upstream URL.
pub fn resolve_redirect(location: &str, base: &str) -> Option<String> {
    let location = location.trim();
    if location.is_empty() {
        return None;
    }
    if Url::parse(location).is_ok() {
        return Some(unwrap(location));
    }
    if [
        "/https/", "/http/", "/https-", "/http-", "/wss/", "/ws/", "/wss-", "/ws-",
    ]
    .iter()
    .any(|prefix| location.starts_with(prefix))
    {
        return Some(unwrap(&format!("https://{GATEWAY_HOST}{location}")));
    }
    Url::parse(base)
        .ok()?
        .join(location)
        .ok()
        .map(|url| url.to_string())
}

fn parse_protocol(segment: &str) -> Option<(&str, Option<u16>)> {
    match segment.split_once('-') {
        Some((scheme, port)) if ["http", "https", "ws", "wss"].contains(&scheme) => {
            Some((scheme, Some(port.parse().ok()?)))
        }
        None if ["http", "https", "ws", "wss"].contains(&segment) => Some((segment, None)),
        _ => None,
    }
}

fn encrypt_host(host: &str) -> Result<String, WebVpnError> {
    let mut buffer = host.as_bytes().to_vec();
    let remainder = buffer.len() % 16;
    if remainder != 0 {
        buffer.resize(buffer.len() + 16 - remainder, 0);
    }
    let cipher = Aes128CfbEnc::new(KEY.into(), KEY.into());
    cipher.encrypt(&mut buffer);
    buffer.truncate(host.len());
    Ok(format!("{}{}", hex(KEY), hex(&buffer)))
}

fn decrypt_host(encoded: &str) -> Option<String> {
    if encoded.len() < 32 || !encoded.len().is_multiple_of(2) {
        return None;
    }
    let iv = unhex(&encoded[..32])?;
    if iv.len() != 16 {
        return None;
    }
    let ciphertext = unhex(&encoded[32..])?;
    let host_length = ciphertext.len();
    if host_length == 0 || host_length > 253 {
        return None;
    }
    let mut buffer = ciphertext;
    let remainder = buffer.len() % 16;
    if remainder != 0 {
        buffer.resize(buffer.len() + 16 - remainder, 0);
    }
    let cipher = Aes128CfbDec::new(KEY.into(), iv.as_slice().into());
    cipher.decrypt(&mut buffer);
    buffer.truncate(host_length);
    let host = String::from_utf8(buffer).ok()?;
    if host.is_empty() {
        None
    } else {
        Some(host)
    }
}

fn hex(bytes: &[u8]) -> String {
    bytes.iter().map(|byte| format!("{byte:02x}")).collect()
}

fn unhex(text: &str) -> Option<Vec<u8>> {
    if !text.len().is_multiple_of(2) {
        return None;
    }
    (0..text.len())
        .step_by(2)
        .map(|index| u8::from_str_radix(&text[index..index + 2], 16).ok())
        .collect()
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum WebVpnError {
    InvalidUrl,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn matches_ubaa_host_codec_vector() {
        let upstream = "http://i.buaa.edu.cn/web/#/login?type=0&token=fixture-token";
        let wrapped = wrap(upstream).expect("wraps");
        assert_eq!(
            wrapped,
            "https://d.buaa.edu.cn/http/77726476706e69737468656265737421f9b94389263126557a1dc7af96/web/#/login?type=0&token=fixture-token"
        );
        assert_eq!(unwrap(&wrapped), upstream);
    }

    #[test]
    fn encodes_custom_port_and_resolves_gateway_redirects() {
        let upstream = "https://iclass.buaa.edu.cn:8346/?type=jumpMyCenter";
        let wrapped = wrap(upstream).expect("wraps");
        assert!(wrapped.starts_with("https://d.buaa.edu.cn/https-8346/"));
        assert_eq!(unwrap(&wrapped), upstream);

        let login = "https://iclass.buaa.edu.cn:8346/?loginName=abc%2Bdef%2Fghi%3D#/MyCenter";
        let wrapped_login = wrap(login).expect("wraps");
        assert_eq!(
            resolve_redirect(&wrapped_login, upstream).as_deref(),
            Some(login)
        );
    }

    #[test]
    fn gateway_owned_paths_survive_undecodable_redirects() {
        let gateway = "https://d.buaa.edu.cn/login?next=%2Fportal";
        assert_eq!(unwrap(gateway), gateway);
        assert_eq!(
            resolve_redirect(gateway, "https://iclass.buaa.edu.cn:8346/").as_deref(),
            Some(gateway)
        );
    }

    #[test]
    fn only_campus_hosts_are_routed() {
        assert!(should_route("https://uc.buaa.edu.cn/api/uc/status"));
        assert!(should_route("https://buaa.edu.cn/"));
        assert!(!should_route("https://d.buaa.edu.cn/login"));
        assert!(!should_route("https://github.com/JUANWANG-BUAA/ginkgo"));
    }
}
