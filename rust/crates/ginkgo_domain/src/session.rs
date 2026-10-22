//! Public authentication values. No login-page, cookie or token representation.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserProfile {
    pub school_id: String,
    pub name: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CaptchaChallenge {
    pub captcha_type: String,
    pub id: String,
    pub image_url: String,
}
