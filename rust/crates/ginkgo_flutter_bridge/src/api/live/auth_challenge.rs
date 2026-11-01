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

pub struct GatewayChallengeResponse {
    pub challenge_id: Option<String>,
    pub challenge_type: Option<String>,
    pub text_supported: bool,
    pub image: Vec<u8>,
    pub failure: Option<FailureCode>,
}

/// The WebVPN gateway's pending challenge. `challenge_id: None` with no
/// failure means the gateway is not asking for anything right now.
pub async fn load_gateway_challenge() -> GatewayChallengeResponse {
    let result = match service() {
        Ok(service) => with_session_write(|| service.gateway_challenge()).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(Some(data)) => GatewayChallengeResponse {
            challenge_id: Some(data.challenge_id),
            challenge_type: Some(data.challenge_type),
            text_supported: data.text_supported,
            image: data.image,
            failure: None,
        },
        Ok(None) => GatewayChallengeResponse {
            challenge_id: None,
            challenge_type: None,
            text_supported: false,
            image: vec![],
            failure: None,
        },
        Err(error) => GatewayChallengeResponse {
            challenge_id: None,
            challenge_type: None,
            text_supported: false,
            image: vec![],
            failure: failure(&error).0,
        },
    }
}

pub struct GatewaySubmitResponse {
    pub solved: bool,
    pub failure: Option<FailureCode>,
}

/// Submit the user's answer once. Nothing retries it; a rejected answer keeps
/// the challenge so the user can look at a fresh image.
pub async fn submit_gateway_challenge(answer: String) -> GatewaySubmitResponse {
    let result = match service() {
        Ok(service) => with_session_write(|| service.resume_gateway_login(&answer)).await,
        Err(error) => Err(error),
    };
    match result {
        Ok(()) => GatewaySubmitResponse {
            solved: true,
            failure: None,
        },
        Err(error) => GatewaySubmitResponse {
            solved: false,
            failure: failure(&error).0,
        },
    }
}
