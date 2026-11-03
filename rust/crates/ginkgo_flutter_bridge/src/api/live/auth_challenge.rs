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

/// Empty challenge fields with no failure mean there is no pending challenge.
pub async fn load_gateway_challenge(
    expected_account: String,
    expected_id: Option<String>,
    refresh: bool,
) -> LoginChallengeResponse {
    let result = with_session_write(|| async {
        gateway_owner(&expected_account)?
            .gateway_challenge(expected_id.as_deref(), refresh)
            .await
    })
    .await;
    match result {
        Ok(Some(data)) => LoginChallengeResponse {
            challenge_id: Some(data.challenge_id),
            challenge_type: Some(data.challenge_type),
            text_supported: data.text_supported,
            image: data.image,
            failure: None,
        },
        Ok(None) => LoginChallengeResponse {
            challenge_id: None,
            challenge_type: None,
            text_supported: false,
            image: vec![],
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

pub struct GatewayVerificationResponse {
    pub verified: bool,
    pub failure: Option<FailureCode>,
}

/// One explicit answer, bound to the current challenge; never retried here.
pub async fn resume_gateway_login(
    expected_account: String,
    expected_id: String,
    answer: String,
) -> GatewayVerificationResponse {
    let result = with_session_write(|| async {
        gateway_owner(&expected_account)?
            .resume_gateway_login(&expected_id, &answer)
            .await
    })
    .await;
    match result {
        Ok(()) => GatewayVerificationResponse {
            verified: true,
            failure: None,
        },
        Err(error) => GatewayVerificationResponse {
            verified: false,
            failure: failure(&error).0,
        },
    }
}

fn gateway_owner(expected: &str) -> Result<&'static LiveService, AppError> {
    if expected.is_empty() {
        return Err(AppError::session_expired());
    }
    let service = service()?;
    if service.status().account.as_deref() != Some(expected) {
        return Err(AppError::session_expired());
    }
    Ok(service)
}

#[cfg(test)]
mod gateway_boundary_tests {
    use super::*;

    #[tokio::test]
    async fn absent_account_capability_rejects_before_authentication() {
        let _serial = runtime::TEST_GATE.lock().await;
        let image = load_gateway_challenge(String::new(), None, false).await;
        assert!(image.failure.is_some());
        assert!(image.challenge_id.is_none());
        assert!(image.image.is_empty());
        let result = resume_gateway_login(String::new(), "old-id".into(), "answer".into()).await;
        assert!(!result.verified);
        assert!(result.failure.is_some());
    }
}
