//! Transient authentication challenge mapping; no URLs accepted from Flutter.
use super::*;

pub struct LoginChallengeResponse {
    pub challenge_id: Option<String>,
    pub challenge_type: Option<String>,
    pub text_supported: bool,
    pub image: Vec<u8>,
    pub failure: Option<FailureCode>,
}

pub async fn load_login_challenge(
    expected_id: Option<String>,
    refresh: bool,
) -> LoginChallengeResponse {
    let result = match service() {
        Ok(service) => {
            with_session_write(|| service.login_challenge(expected_id.as_deref(), refresh)).await
        }
        Err(error) => Err(error),
    };
    match result {
        Ok(data) => LoginChallengeResponse {
            challenge_id: Some(data.challenge_id),
            challenge_type: Some(data.challenge_type),
            text_supported: data.text_supported,
            image: data.image,
            failure: None,
        },
        Err(error) => LoginChallengeResponse {
            challenge_id: None,
            challenge_type: None,
            text_supported: false,
            image: vec![],
            failure: failure(&error).0,
        },
    }
}
