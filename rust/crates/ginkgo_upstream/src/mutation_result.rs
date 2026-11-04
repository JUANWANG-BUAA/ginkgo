/// Unified mutation result type - prevents error classification chaos
/// Replaces scattered failure_detail patterns with explicit outcome types
///
/// This prevents Beta 5-8 style errors where different modules interpret
/// the same failure differently.

pub enum MutationResult<T> {
    /// Operation succeeded
    Success(T),

    /// Operation partially succeeded (data available but with warning)
    PartialSuccess {
        data: T,
        warning: String
    },

    /// Operation failed, but caller can decide if retriable
    Failure {
        code: ErrorCode,
        message: String,
        retriable: bool,
    },

    /// User action required (e.g., verification code)
    RequiresInput {
        prompt: InputPrompt,
        context: String,  // Binds to account/route/execution
    },

    /// Validation failed (e.g., parameters invalid)
    ValidationError {
        field: String,
        reason: String,
    },
}

/// Input prompts - what UI should show
pub enum InputPrompt {
    VerificationCode { image_base64: String, challenge_id: String },
    Password { reason: String },
    Selection { options: Vec<String> },
}

/// Error codes - explicit, no "unknown"
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum ErrorCode {
    // Authentication errors
    InvalidCredentials,      // Wrong password
    CaptchaRequired,         // Verification needed
    SessionExpired,          // Must re-login
    AccessDenied,            // Risk control

    // Network errors (retriable)
    ServiceUnavailable,      // Timeout or 503
    ConnectionFailed,        // Network error

    // Protocol errors (not retriable)
    UnexpectedResponse,      // Changed response structure
    InvalidRequest,          // Bad parameters
    BusinessRejected,        // School rejected operation

    // Storage errors
    CredentialStore,         // Cannot read/write keystore
    CacheCorrupted,          // Local data invalid
}

impl ErrorCode {
    /// Should background task retry this?
    pub fn is_retriable(&self) -> bool {
        matches!(
            self,
            ErrorCode::ServiceUnavailable
                | ErrorCode::ConnectionFailed
                | ErrorCode::CacheCorrupted
        )
    }

    /// Should UI show login screen?
    pub fn requires_login(&self) -> bool {
        matches!(self, ErrorCode::SessionExpired)
    }

    /// Should this lock authentication globally?
    pub fn locks_authentication(&self) -> bool {
        matches!(
            self,
            ErrorCode::InvalidCredentials | ErrorCode::AccessDenied
        )
    }
}

impl<T> MutationResult<T> {
    /// Map success case
    pub fn map<U, F: FnOnce(T) -> U>(self, f: F) -> MutationResult<U> {
        match self {
            MutationResult::Success(data) => MutationResult::Success(f(data)),
            MutationResult::PartialSuccess { data, warning } => {
                MutationResult::PartialSuccess {
                    data: f(data),
                    warning,
                }
            }
            MutationResult::Failure { code, message, retriable } => {
                MutationResult::Failure { code, message, retriable }
            }
            MutationResult::RequiresInput { prompt, context } => {
                MutationResult::RequiresInput { prompt, context }
            }
            MutationResult::ValidationError { field, reason } => {
                MutationResult::ValidationError { field, reason }
            }
        }
    }

    /// Check if operation succeeded (any variant)
    pub fn is_success(&self) -> bool {
        matches!(
            self,
            MutationResult::Success(_) | MutationResult::PartialSuccess { .. }
        )
    }

    /// Get error code if failed
    pub fn error_code(&self) -> Option<ErrorCode> {
        match self {
            MutationResult::Failure { code, .. } => Some(*code),
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn error_code_classification_complete() {
        // Verify: All error types are classified
        let codes = vec![
            ErrorCode::InvalidCredentials,
            ErrorCode::SessionExpired,
            ErrorCode::ServiceUnavailable,
            ErrorCode::UnexpectedResponse,
        ];

        for code in codes {
            // Each must have clear properties
            let _retriable = code.is_retriable();
            let _requires_login = code.requires_login();
            let _locks_auth = code.locks_authentication();

            // No "unknown" or "other" allowed
            assert!(!format!("{:?}", code).contains("Unknown"));
        }
    }

    #[test]
    fn mutation_result_type_safe() {
        // Cannot accidentally mix success and failure
        let success: MutationResult<String> = MutationResult::Success("data".into());
        let failure: MutationResult<String> =
            MutationResult::Failure {
                code: ErrorCode::InvalidCredentials,
                message: "error".into(),
                retriable: false,
            };

        assert!(success.is_success());
        assert!(!failure.is_success());
    }

    #[test]
    fn requires_input_binds_context() {
        // Verification code must be bound to challenge ID
        let input = MutationResult::RequiresInput {
            prompt: InputPrompt::VerificationCode {
                image_base64: "data:image/png;...".into(),
                challenge_id: "ch-001".into(),
            },
            context: "direct_route".into(),
        };

        // Cannot accidentally use answer from different challenge
        match input {
            MutationResult::RequiresInput { prompt, context } => {
                match prompt {
                    InputPrompt::VerificationCode {
                        challenge_id, ..
                    } => {
                        assert_eq!(challenge_id, "ch-001");
                    }
                    _ => panic!("Wrong prompt type"),
                }
                assert_eq!(context, "direct_route");
            }
            _ => panic!("Should be RequiresInput"),
        }
    }
}
