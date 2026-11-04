use super::*;

pub(super) async fn read(owner: String, checkin: bool, homework: bool) -> BackgroundReminderRead {
    let result = bounded_session(async move {
        if !checkin && !homework {
            return Err(AppError::invalid());
        }
        let service = {
            // Snapshot capture must not overlap a sign-in/out. Once copied,
            // network work owns no foreground identity or platform vault.
            // Skip a busy foreground transaction instead of queuing behind it.
            let _snapshot = SESSION_ACCESS
                .try_read()
                .map_err(|_| AppError::unavailable())?;
            tokio::task::spawn_blocking(move || ginkgo_runtime::create_background_service(&owner))
                .await
                .map_err(|_| AppError::credential_store())??
        };
        if !matches!(service.restore().await?, SessionOutcome::SignedIn { .. }) {
            // Background session cannot restore, but foreground session may still be valid.
            // Return unavailable (retry later) instead of session_expired (requires re-login).
            return Err(AppError::unavailable());
        }
        let account = service.status().account;
        let checkin = if checkin {
            Some(match service.load_checkin(false).await {
                Ok(value) => checkin_response(value),
                Err(error) => checkin_failure(error.code.into(), None),
            })
        } else {
            None
        };
        let homework = if homework {
            Some(super::homework::homework_response(
                service.load_homework(false).await,
            ))
        } else {
            None
        };
        Ok(BackgroundReminderRead {
            account,
            checkin,
            homework,
            failure: None,
        })
    })
    .await;
    result.unwrap_or_else(|error| BackgroundReminderRead {
        account: None,
        checkin: None,
        homework: None,
        failure: Some(error.code.into()),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[tokio::test]
    async fn background_skips_a_foreground_identity_transaction_without_loading_vault() {
        let _serial = TEST_GATE.lock().await;
        let _busy = SESSION_ACCESS.write().await;
        let result = read("synthetic-owner".into(), true, true).await;
        assert!(matches!(
            result.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
        assert!(result.account.is_none());
    }
}

    #[tokio::test]
    async fn background_failure_does_not_require_foreground_re_login() {
        // Background session failure (unavailable) should not trigger session_expired,
        // which would force foreground user to re-login even if their session is valid.
        let _serial = TEST_GATE.lock().await;
        let _busy = SESSION_ACCESS.write().await;
        let result = read("synthetic-owner".into(), true, true).await;
        // After change: should be ServiceUnavailable, not SessionExpired
        assert!(matches!(
            result.failure,
            Some(FailureCode::ServiceUnavailable)
        ));
    }
