//! BYKC read-only catalog, API.md §7.3 / EDUCATION-DATA-MAP §2.
use crate::{
    auth::session::Session,
    features::bykc::{self, Catalog},
    foundation::http::{HttpRequest, HttpTransport},
    AppError, ErrorCode,
};
use aes::{
    cipher::{BlockDecrypt, BlockEncrypt, KeyInit},
    Aes128,
};
use base64::{engine::general_purpose::STANDARD, Engine};
use rand::{rngs::OsRng, Rng};
use rsa::{pkcs8::DecodePublicKey, Pkcs1v15Encrypt, RsaPublicKey};
use serde_json::{json, Value};
use sha1::{Digest, Sha1};
const BASE: &str = "https://bykc.buaa.edu.cn/sscv";
// Same public key as BykcCrypto in BykcClient.swift. Public protocol data.
const PUBLIC_KEY: &str = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDlHMQ3B5GsWnCe7Nlo1YiG/YmHdlOiKOST5aRm4iaqYSvhvWmwcigoyWTM+8bv2+sf6nQBRDWTY4KmNV7DBk1eDnTIQo6ENA31k5/tYCLEXgjPbEjCK9spiyB62fCT6cqOhbamJB0lcDJRO6Vo1m3dy+fD0jbxfDVBBNtyltIsDQIDAQAB";

async fn request<T: HttpTransport>(
    session: &Session<T>,
    token: &str,
    api: &str,
    payload: Value,
) -> Result<Value, AppError> {
    let plain = serde_json::to_vec(&payload).map_err(|_| AppError::invalid())?;
    let alphabet = b"ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678";
    let mut key = [0u8; 16];
    for item in &mut key {
        *item = alphabet[OsRng.gen_range(0..alphabet.len())];
    }
    let cipher = Aes128::new((&key).into());
    let mut encrypted = plain.clone();
    let padding = 16 - encrypted.len() % 16;
    encrypted.extend(std::iter::repeat_n(padding as u8, padding));
    for block in encrypted.chunks_mut(16) {
        cipher.encrypt_block(aes::Block::from_mut_slice(block));
    }
    let der = STANDARD
        .decode(PUBLIC_KEY)
        .map_err(|_| AppError::changed())?;
    let public = RsaPublicKey::from_public_key_der(&der).map_err(|_| AppError::changed())?;
    let digest = format!("{:x}", Sha1::digest(&plain));
    let ak = STANDARD.encode(
        public
            .encrypt(&mut OsRng, Pkcs1v15Encrypt, &key)
            .map_err(|_| AppError::changed())?,
    );
    let sk = STANDARD.encode(
        public
            .encrypt(&mut OsRng, Pkcs1v15Encrypt, digest.as_bytes())
            .map_err(|_| AppError::changed())?,
    );
    let ts = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map_err(|_| AppError::changed())?
        .as_millis()
        .to_string();
    let response = session
        .send_with_fallback(
            HttpRequest::post_form(format!("{BASE}/{api}"), STANDARD.encode(encrypted))
                .header("Content-Type", "application/json; charset=UTF-8")
                .header("Accept", "application/json")
                .header("Referer", "https://bykc.buaa.edu.cn/system/course-select")
                .header("Origin", "https://bykc.buaa.edu.cn")
                .header("auth_token", token)
                .header("authtoken", token)
                .header("ak", &ak)
                .header("sk", &sk)
                .header("ts", &ts),
        )
        .await?;
    if matches!(response.status, 401 | 403)
        || crate::auth::cas::is_login_redirect(&response.final_url, &response.body)
    {
        return Err(AppError::session_expired());
    }
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    let text = serde_json::from_str::<String>(&response.body)
        .unwrap_or_else(|_| response.body.trim().to_owned());
    let mut decrypted = STANDARD.decode(text).map_err(|_| AppError::changed())?;
    if decrypted.is_empty() || decrypted.len() % 16 != 0 {
        return Err(AppError::changed());
    }
    for block in decrypted.chunks_mut(16) {
        cipher.decrypt_block(aes::Block::from_mut_slice(block));
    }
    let pad = usize::from(*decrypted.last().ok_or_else(AppError::changed)?);
    if !(1..=16).contains(&pad)
        || !decrypted[decrypted.len() - pad..]
            .iter()
            .all(|b| usize::from(*b) == pad)
    {
        return Err(AppError::changed());
    }
    decrypted.truncate(decrypted.len() - pad);
    let envelope: Value = serde_json::from_slice(&decrypted).map_err(|_| AppError::changed())?;
    decode_envelope(&envelope)
}

pub fn decode_envelope(envelope: &Value) -> Result<Value, AppError> {
    let status = envelope["status"]
        .as_str()
        .map(str::to_owned)
        .or_else(|| envelope["status"].as_i64().map(|v| v.to_string()))
        .ok_or_else(AppError::changed)?;
    if status != "0" {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    envelope
        .get("data")
        .filter(|v| v.is_object())
        .cloned()
        .ok_or_else(AppError::changed)
}

pub async fn load<T: HttpTransport>(session: &Session<T>) -> Result<Catalog, AppError> {
    let response = session
        .send_following_redirects(HttpRequest::get(format!("{BASE}/cas/login")))
        .await?;
    let url = url::Url::parse(&response.final_url).map_err(|_| AppError::changed())?;
    let token = url
        .query_pairs()
        .find(|(k, v)| k == "token" && !v.is_empty())
        .map(|(_, v)| v.into_owned())
        .ok_or_else(AppError::session_expired)?;
    let config = request(session, &token, "getAllConfig", json!({})).await?;
    let mut pages = Vec::new();
    for page in 1..=20 {
        let data = request(
            session,
            &token,
            "queryStudentSemesterCourseByPage",
            json!({"pageNumber":page,"pageSize":100}),
        )
        .await?;
        let total = data["totalPages"]
            .as_i64()
            .or_else(|| data["totalPages"].as_str()?.parse().ok())
            .filter(|v| *v >= 0)
            .ok_or_else(AppError::changed)?;
        pages.push(data);
        if page >= total {
            return bykc::parse_catalog(&config, &pages);
        }
    }
    Err(AppError::changed())
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn protocol_public_key_and_ecb_roundtrip_are_valid() {
        let der = STANDARD.decode(PUBLIC_KEY).expect("public key base64");
        let key = RsaPublicKey::from_public_key_der(&der).expect("protocol public key");
        assert!(key
            .encrypt(&mut OsRng, Pkcs1v15Encrypt, b"abcdefghijklmnop")
            .is_ok());
        let aes = Aes128::new(b"abcdefghijklmnop".into());
        let mut block = aes::Block::from(*b"1234567890123456");
        let plain = block;
        aes.encrypt_block(&mut block);
        aes.decrypt_block(&mut block);
        assert_eq!(plain, block);
    }
}
