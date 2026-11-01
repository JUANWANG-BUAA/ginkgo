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
    if bytes.len() > 1024 * 1024 || !is_displayable_image(&bytes) {
        return Err(AppError::changed());
    }
    Ok(bytes)
}

/// Only the magic numbers matter: the bytes go straight to the image widget.
/// JPEG is the documented form; the same endpoint also serves PNG.
fn is_displayable_image(bytes: &[u8]) -> bool {
    const JPEG_START: [u8; 3] = [0xff, 0xd8, 0xff];
    const JPEG_END: [u8; 2] = [0xff, 0xd9];
    const PNG_START: [u8; 8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
    const PNG_END: [u8; 8] = [0x49, 0x45, 0x4e, 0x44, 0xae, 0x42, 0x60, 0x82];
    if bytes.len() >= 4 && bytes.starts_with(&JPEG_START) && bytes.ends_with(&JPEG_END) {
        return true;
    }
    bytes.len() >= 16 && bytes.starts_with(&PNG_START) && bytes.ends_with(&PNG_END)
}

#[cfg(test)]
#[path = "challenge_tests.rs"]
mod tests;
