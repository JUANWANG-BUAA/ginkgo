//! Fixed-origin transient CAS image read. Never accepts a caller URL or follows redirects.
use super::{cas, session::Session};
use crate::{
    foundation::http::{HttpRequest, HttpTransport},
    AppError,
};

pub(crate) async fn image<T: HttpTransport>(
    session: &Session<T>,
    id: &str,
) -> Result<Vec<u8>, AppError> {
    if id.is_empty() || id.len() > 512 {
        return Err(AppError::invalid());
    }
    let mut request = HttpRequest::get(cas::captcha_image_url(id))
        .header("Accept", "image/jpeg")
        .header("Cache-Control", "no-cache");
    request.binary_response = true;
    request.response_limit = Some(1024 * 1024);
    let response = session.send(request).await?;
    if response.status != 200 {
        return Err(AppError::unavailable());
    }
    let bytes = response.bytes.ok_or_else(AppError::changed)?;
    if bytes.len() > 1024 * 1024
        || bytes.len() < 4
        || !bytes.starts_with(&[0xff, 0xd8, 0xff])
        || !bytes.ends_with(&[0xff, 0xd9])
    {
        return Err(AppError::changed());
    }
    Ok(bytes)
}

#[cfg(test)]
#[path = "challenge_tests.rs"]
mod tests;
