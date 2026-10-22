use std::fmt;
/// Short-lived iclass app session. It never leaves Rust and is never logged.
#[derive(Clone, PartialEq, Eq)]
pub struct IClassSession {
    pub user_id: String,
    pub session_id: String,
}

impl fmt::Debug for IClassSession {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("IClassSession { user_id: <redacted>, session_id: <redacted> }")
    }
}
