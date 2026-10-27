//! CGYY writes (API §6B; Swift CgyyClient / UBAA LocalCgyyApi).
//! All POSTs are single-attempt. Captcha is completed manually, not bypassed.
use super::SchoolClient;
use crate::{
    adapters::cgyy_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
    ErrorCode,
};
use ginkgo_domain::{features::cgyy_booking::*, ports::CgyyMutationSource};
use serde_json::Value;
use std::{
    collections::BTreeMap,
    time::{Duration, Instant},
};

const REVIEW_TTL: Duration = Duration::from_secs(120);

mod protocol;
use protocol::{
    base_form, choices, data, encrypt, fallback_purposes, number, protocol_point, purposes,
    selections, text, trade_matches, validate,
};

#[derive(Default)]
pub(crate) struct BookingSafety {
    pub(crate) pending: bool,
    pub(crate) review: Option<ReviewCredential>,
}
pub(crate) struct ReviewCredential {
    pub(crate) id: String,
    pub(crate) created: Instant,
    generation: u64,
}
#[derive(Clone)]
pub(super) struct BookingOwner {
    pub(super) account: String,
    pub(super) generation: u64,
}

pub(crate) struct BookingContext {
    id: String,
    owner: BookingOwner,
    booking: BookingRequest,
    /// Signed `reservationOrderJson` produced from the prepare-day response.
    selections: String,
    /// Day `token` (order token) that the draft and captcha were built with.
    reservation_token: String,
    /// Draft `weekStartDate` taken from the day response; empty means omit.
    week_start: String,
    /// Draft trade number, kept only to compare the submit response.
    trade_no: String,
    captcha_token: String,
    secret: String,
    created: Instant,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    pub(super) fn booking_owner(&self) -> Result<BookingOwner, AppError> {
        let identity = self.identity.lock();
        Ok(BookingOwner {
            account: identity
                .authenticated
                .as_ref()
                .ok_or_else(AppError::session_expired)?
                .account
                .clone(),
            generation: identity.generation,
        })
    }
    pub(super) fn check_booking_owner(&self, owner: &BookingOwner) -> Result<(), AppError> {
        let identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|u| u.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        Ok(())
    }
    fn booking_pending(&self, owner: &BookingOwner) -> bool {
        self.cgyy_safety
            .lock()
            .get(&owner.account)
            .is_some_and(|s| s.pending)
    }
    fn set_booking_pending(&self, owner: &BookingOwner, pending: bool) -> Result<(), AppError> {
        let identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|u| u.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        let mut safety = self.cgyy_safety.lock();
        let state = safety.entry(owner.account.clone()).or_default();
        state.pending = pending;
        state.review = None;
        // Invalidate before dispatch too: cancellation/drop cannot retain stale snapshots.
        if pending {
            self.snapshots.cgyy.lock().clear();
        }
        Ok(())
    }
    // Only explicit reads use this uncached path. Mutation prechecks and POSTs
    // deliberately retain their single-attempt policy.
    pub(super) async fn load_booking_read(
        &self,
        owner: &BookingOwner,
        kind: &str,
        site: i64,
        date: &str,
    ) -> Result<(Value, String), AppError> {
        if !matches!(kind, "orders" | "day" | "order" | "lockCode") {
            return Err(AppError::invalid());
        }
        for renew in [false, true] {
            self.check_booking_owner(owner)?;
            let token = self.cgyy_token(renew).await;
            self.check_booking_owner(owner)?;
            let token = token?;
            let result = cgyy_http::load(&self.session, kind, site, date, Some(&token)).await;
            self.check_booking_owner(owner)?;
            if result
                .as_ref()
                .is_err_and(|error| error.code == ErrorCode::SessionExpired)
            {
                let mut identity = self.identity.lock();
                // An old account's late 401 must not invalidate the new token.
                if identity.generation != owner.generation
                    || !identity
                        .authenticated
                        .as_ref()
                        .is_some_and(|user| user.account == owner.account)
                {
                    return Err(AppError::session_expired());
                }
                if identity.cgyy_token.as_deref() == Some(token.as_str()) {
                    identity.cgyy_token = None;
                }
                if !renew {
                    continue;
                }
            }
            return result.map(|value| (value, token));
        }
        // The second pass always returns above; a loop exit would be protocol
        // drift and must fail closed rather than abort the FFI process.
        Err(AppError::changed())
    }
    async fn review_booking(&self, owner: &BookingOwner) -> Result<CgyyActionResult, AppError> {
        self.check_booking_owner(owner)?;
        self.cgyy_safety
            .lock()
            .entry(owner.account.clone())
            .or_default()
            .review = None;
        // Bypass snapshots: failed refresh/fallback must never mint an acknowledgement.
        let (value, _) = self.load_booking_read(owner, "orders", 0, "").await?;
        let orders = crate::codecs::cgyy::orders(&value)?;
        let identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|u| u.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        let id = format!("{:032x}", rand::random::<u128>());
        self.cgyy_safety
            .lock()
            .entry(owner.account.clone())
            .or_default()
            .review = Some(ReviewCredential {
            id: id.clone(),
            created: Instant::now(),
            generation: owner.generation,
        });
        let mut result = CgyyActionResult::message(
            "reviewRequired",
            "请核对以下最近的有界分页预约（最多 20 条）；列表未覆盖全部历史，请必要时到学校页面核实",
        );
        result.review = Some(BookingReview { id, orders });
        Ok(result)
    }
    fn acknowledge_booking(
        &self,
        owner: &BookingOwner,
        id: &str,
    ) -> Result<CgyyActionResult, AppError> {
        let identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|u| u.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        let mut safety = self.cgyy_safety.lock();
        let state = safety.entry(owner.account.clone()).or_default();
        if !state.review.as_ref().is_some_and(|r| {
            r.id == id && r.generation == owner.generation && r.created.elapsed() < REVIEW_TTL
        }) {
            return Err(AppError::invalid());
        }
        state.review = None;
        state.pending = false;
        Ok(CgyyActionResult::message(
            "reviewed",
            "已确认核对；请勿重复预约",
        ))
    }
    async fn booking_options(
        &self,
        owner: &BookingOwner,
        site_id: i64,
        date: &str,
    ) -> Result<CgyyActionResult, AppError> {
        if site_id <= 0 || chrono::NaiveDate::parse_from_str(date, "%Y-%m-%d").is_err() {
            return Err(AppError::invalid());
        }
        let (day, token) = self.load_booking_read(owner, "day", site_id, date).await?;
        let codes = cgyy_http::business(&self.session, "/api/codes", BTreeMap::new(), &token).await;
        self.check_booking_owner(owner)?;
        let (purposes, uses_fallback_purposes) = match codes {
            Ok(codes) => match data(&codes) {
                Ok(data) => {
                    let purposes = purposes(data);
                    if purposes.is_empty() {
                        (fallback_purposes(), true)
                    } else {
                        (purposes, false)
                    }
                }
                Err(_) => (fallback_purposes(), true),
            },
            Err(error)
                if matches!(
                    error.code,
                    ErrorCode::SessionExpired
                        | ErrorCode::CaptchaRequired
                        | ErrorCode::InvalidCredentials
                ) =>
            {
                return Err(error);
            }
            Err(_) => (fallback_purposes(), true),
        };
        let mut result = CgyyActionResult::message("options", "请填写用途并选择空闲时段");
        result.options = Some(BookingOptions {
            choices: choices(&day, date)?,
            purposes,
            uses_fallback_purposes,
        });
        Ok(result)
    }
    async fn prepare_booking(
        &self,
        owner: &BookingOwner,
        booking: BookingRequest,
    ) -> Result<CgyyActionResult, AppError> {
        validate(&booking)?;
        let token = self.cgyy_token(false).await?;
        self.check_booking_owner(owner)?;
        let day = cgyy_http::load(
            &self.session,
            "day",
            booking.site_id,
            &booking.date,
            Some(&token),
        )
        .await?;
        let selected = selections(&day, &booking)?;
        let reservation_token = text(&data(&day)?["token"])
            .ok_or_else(AppError::changed)?
            .to_owned();
        let week_start = crate::codecs::cgyy::week_start(&day).unwrap_or_default();
        self.check_booking_owner(owner)?;
        let mut context = BookingContext {
            owner: owner.clone(),
            id: format!("{:032x}", rand::random::<u128>()),
            booking,
            selections: selected,
            reservation_token,
            week_start,
            trade_no: String::new(),
            captcha_token: String::new(),
            secret: String::new(),
            created: Instant::now(),
        };
        // Before the first POST, require review on interruption/unknown result.
        self.set_booking_pending(owner, true)?;
        let draft = cgyy_http::business(
            &self.session,
            "/api/reservation/order/info",
            base_form(&context),
            &token,
        )
        .await;
        let draft = match draft {
            Ok(draft) => draft,
            Err(error) => return Ok(self.booking_failure(owner, error)),
        };
        // The draft response is consumed rather than discarded: its trade
        // number is kept for the submit comparison. Its own `token` must not
        // replace the day order token, which is what the captcha chain binds.
        context.trade_no = text(&data(&draft)?["tradeNo"])
            .unwrap_or_default()
            .to_owned();
        self.check_booking_owner(owner)?;
        let timestamp = chrono::DateTime::parse_from_rfc3339(&super::cache::now_shanghai())
            .map_err(|_| AppError::unavailable())?
            .timestamp_millis()
            .to_string();
        let captcha = cgyy_http::business(
            &self.session,
            "/api/captcha/get",
            BTreeMap::from([
                ("captchaType".into(), "blockPuzzle".into()),
                ("clientUid".into(), format!("slider-{timestamp}")),
                ("ts".into(), timestamp),
            ]),
            &token,
        )
        .await?;
        let root = data(&captcha)?;
        if root["success"] != true {
            return Err(AppError::new(ErrorCode::CaptchaRequired));
        }
        let rep = &root["repData"];
        context.captcha_token = text(&rep["token"]).ok_or_else(AppError::changed)?.into();
        context.secret = text(&rep["secretKey"])
            .filter(|key| [16, 24, 32].contains(&key.len()))
            .ok_or_else(AppError::changed)?
            .into();
        let challenge = BookingChallenge {
            id: context.id.clone(),
            background: text(&rep["originalImageBase64"])
                .ok_or_else(AppError::changed)?
                .into(),
            jigsaw: text(&rep["jigsawImageBase64"])
                .ok_or_else(AppError::changed)?
                .into(),
        };
        {
            let mut identity = self.identity.lock();
            if identity.generation != owner.generation {
                return Err(AppError::session_expired());
            }
            identity.cgyy_booking = Some(context);
        }
        self.set_booking_pending(owner, false)?;
        let mut result = CgyyActionResult::message("challenge", "请手动拖动拼图完成学校验证");
        result.challenge = Some(challenge);
        Ok(result)
    }
    fn booking_failure(&self, owner: &BookingOwner, error: AppError) -> CgyyActionResult {
        // No verified upstream rejection codes exist in §6B. Never turn a generic
        // BusinessRejected, authentication error, 5xx or parse error into unlock.
        self.snapshots.cgyy.lock().clear();
        let mut identity = self.identity.lock();
        if identity.generation == owner.generation {
            identity.cgyy_booking = None;
            if error.code == ErrorCode::SessionExpired {
                identity.cgyy_token = None;
            }
        }
        CgyyActionResult::message("uncertain", "结果待核实，请先回查我的预约，勿重复提交")
    }
    async fn submit_booking(
        &self,
        owner: &BookingOwner,
        id: &str,
        x: f64,
        width: Option<f64>,
    ) -> Result<CgyyActionResult, AppError> {
        // Consume before awaiting. Repeated callbacks cannot replay this challenge.
        let context = self
            .identity
            .lock()
            .cgyy_booking
            .take()
            .ok_or_else(AppError::invalid)?;
        self.check_booking_owner(&context.owner)?;
        if context.id != id || context.created.elapsed() > Duration::from_secs(120) {
            return Err(AppError::invalid());
        }
        // The upstream coordinate is `310 * offset / width`, never raw device
        // pixels. `width` absent means the caller already normalised.
        let x = protocol_point(x, width)?;
        let token = self.cgyy_token(false).await?;
        let point = format!("{{\"x\":{x},\"y\":5}}");
        self.set_booking_pending(owner, true)?;
        let checked = cgyy_http::business(
            &self.session,
            "/api/captcha/check",
            BTreeMap::from([
                ("pointJson".into(), encrypt(&point, &context.secret)?),
                ("token".into(), context.captcha_token.clone()),
            ]),
            &token,
        )
        .await;
        let checked = match checked {
            Ok(v) => v,
            Err(e) => return Ok(self.booking_failure(owner, e)),
        };
        self.check_booking_owner(owner)?;
        if data(&checked)?["success"] == false {
            self.set_booking_pending(owner, false)?;
            return Ok(CgyyActionResult::message(
                "rejected",
                "拼图验证未通过，请返回后重新准备；未提交预约",
            ));
        }
        if data(&checked)?["success"] != true {
            return Ok(self.booking_failure(owner, AppError::changed()));
        }
        let latest = cgyy_http::load(
            &self.session,
            "day",
            context.booking.site_id,
            &context.booking.date,
            Some(&token),
        )
        .await?;
        self.check_booking_owner(owner)?;
        let selected = match selections(&latest, &context.booking) {
            Ok(selected) => selected,
            Err(error) if error.code == ErrorCode::BusinessRejected => String::new(),
            Err(error) => return Ok(self.booking_failure(owner, error)),
        };
        if selected != context.selections {
            self.set_booking_pending(owner, false)?;
            return Ok(CgyyActionResult::message(
                "notSubmitted",
                "所选空档已变化，请重新选择；未提交预约",
            ));
        }
        // The re-check is kept, but a rotated day order token means the draft,
        // captcha and this read no longer share one chain. Submitting with the
        // old token would be a doomed write and swapping it silently would be
        // unverified, so stop before any POST.
        if text(&data(&latest)?["token"]).is_some_and(|t| t != context.reservation_token) {
            self.set_booking_pending(owner, false)?;
            return Ok(CgyyActionResult::message(
                "notSubmitted",
                "学校已刷新本次预约令牌，请返回后重新准备；未提交预约",
            ));
        }
        let mut form = base_form(&context);
        let b = &context.booking;
        form.extend(BTreeMap::from([
            ("phone".into(), b.phone.clone()),
            ("theme".into(), b.theme.clone()),
            ("purposeType".into(), b.purpose_type.to_string()),
            ("joinerNum".into(), b.joiner_num.to_string()),
            ("activityContent".into(), b.activity_content.clone()),
            ("joiners".into(), b.joiners.clone()),
            (
                "isPhilosophySocialSciences".into(),
                if b.philosophy { "1" } else { "0" }.into(),
            ),
            (
                "isOffSchoolJoiner".into(),
                if b.off_school { "1" } else { "0" }.into(),
            ),
            (
                "captchaVerification".into(),
                encrypt(
                    &format!("{}---{point}", context.captcha_token),
                    &context.secret,
                )?,
            ),
        ]));
        self.set_booking_pending(owner, true)?;
        let response =
            match cgyy_http::business(&self.session, "/api/reservation/order/submit", form, &token)
                .await
            {
                Ok(response) => response,
                Err(error) => return Ok(self.booking_failure(owner, error)),
            };
        self.snapshots.cgyy.lock().clear();
        self.check_booking_owner(owner)?;
        let body = data(&response)?;
        let order_id = number(&body["orderInfo"]["id"]);
        let response_trade = text(&body["tradeNo"])
            .or_else(|| text(&body["orderInfo"]["tradeNo"]))
            .unwrap_or_default();
        let readback = cgyy_http::load(&self.session, "orders", 0, "", Some(&token)).await;
        // Identity is checked on the visible row, not inferred from a response id
        // alone: the row must carry the requested reservation date and, when the
        // draft or the response names a trade number, the same one.
        if let (Some(id), Ok(readback)) = (order_id, readback) {
            self.check_booking_owner(owner)?;
            let root = data(&readback)?;
            let matched = root["content"]
                .as_array()
                .or_else(|| root["list"].as_array())
                .is_some_and(|rows| {
                    rows.iter().any(|row| {
                        number(&row["id"]) == Some(id)
                            && text(&row["reservationDate"]) == Some(context.booking.date.as_str())
                            && trade_matches(&context.trade_no, response_trade, row)
                    })
                });
            if matched {
                self.set_booking_pending(owner, false)?;
                return Ok(CgyyActionResult::message(
                    "accepted",
                    "已查回本次预约记录，请在我的预约查看审批状态",
                ));
            }
        }
        Ok(CgyyActionResult::message(
            "uncertain",
            "学校已受理，请到我的预约核对，确认前暂停再次提交",
        ))
    }
    async fn cancel_booking(
        &self,
        owner: &BookingOwner,
        order_id: i64,
    ) -> Result<CgyyActionResult, AppError> {
        if order_id <= 0 {
            return Err(AppError::invalid());
        }
        let token = self.cgyy_token(false).await?;
        self.check_booking_owner(owner)?;
        let value = cgyy_http::load(&self.session, "orders", 0, "", Some(&token)).await?;
        let rows = data(&value)?["content"]
            .as_array()
            .or_else(|| data(&value).ok()?["list"].as_array())
            .ok_or_else(AppError::changed)?;
        let row = rows
            .iter()
            .find(|r| number(&r["id"]) == Some(order_id))
            .ok_or_else(AppError::invalid)?;
        let start = text(&row["reservationStartDate"])
            .and_then(|s| chrono::NaiveDateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S").ok());
        let now = chrono::DateTime::parse_from_rfc3339(&super::cache::now_shanghai())
            .map_err(|_| AppError::unavailable())?
            .naive_local();
        if !matches!(number(&row["orderStatus"]), Some(1 | 3))
            || number(&row["checkStatus"]).is_none_or(|s| !(0..=6).contains(&s))
            || start.is_none_or(|start| now >= start - chrono::Duration::hours(4))
        {
            return Ok(CgyyActionResult::message(
                "notSubmitted",
                "当前订单不可取消或已进入开始前 4 小时，未发送请求",
            ));
        }
        self.set_booking_pending(owner, true)?;
        if let Err(error) = cgyy_http::business(
            &self.session,
            &format!("/api/orders/new/cancel/{order_id}"),
            BTreeMap::new(),
            &token,
        )
        .await
        {
            return Ok(self.booking_failure(owner, error));
        }
        self.snapshots.cgyy.lock().clear();
        self.check_booking_owner(owner)?;
        if let Ok(value) = cgyy_http::load(&self.session, "orders", 0, "", Some(&token)).await {
            self.check_booking_owner(owner)?;
            let root = data(&value)?;
            if root["content"]
                .as_array()
                .or_else(|| root["list"].as_array())
                .is_some_and(|rows| {
                    rows.iter().any(|r| {
                        number(&r["id"]) == Some(order_id) && number(&r["orderStatus"]) == Some(2)
                    })
                })
            {
                self.set_booking_pending(owner, false)?;
                return Ok(CgyyActionResult::message("accepted", "已查回取消状态"));
            }
        }
        Ok(CgyyActionResult::message(
            "uncertain",
            "取消结果待核实，请在我的预约回查，勿重复提交",
        ))
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> CgyyMutationSource for SchoolClient<T, V> {
    async fn execute_cgyy(&self, command: CgyyCommand) -> Result<CgyyActionResult, AppError> {
        // Defensive service single-flight; bridge already serializes writes globally.
        let _gate = self
            .cgyy_mutation_gate
            .try_lock()
            .map_err(|_| AppError::invalid())?;
        let owner = self.booking_owner()?;
        match command {
            CgyyCommand::Status => {
                return Ok(CgyyActionResult::message(
                    if self.booking_pending(&owner) {
                        "uncertain"
                    } else {
                        "ready"
                    },
                    "预约写入保护状态",
                ))
            }
            CgyyCommand::Review => return self.review_booking(&owner).await,
            CgyyCommand::Acknowledge { review_id } => {
                return self.acknowledge_booking(&owner, &review_id)
            }
            _ => {}
        }
        if self.booking_pending(&owner) && !matches!(command, CgyyCommand::Options { .. }) {
            return Ok(CgyyActionResult::message(
                "uncertain",
                "请先回查上次结果，并手动确认已核对",
            ));
        }
        let result = match command {
            CgyyCommand::Options { site_id, date } => {
                self.booking_options(&owner, site_id, &date).await
            }
            CgyyCommand::Prepare { booking } => self.prepare_booking(&owner, booking).await,
            CgyyCommand::Submit {
                challenge_id,
                x,
                width,
            } => self.submit_booking(&owner, &challenge_id, x, width).await,
            CgyyCommand::Cancel { order_id } => self.cancel_booking(&owner, order_id).await,
            // Statically unreachable today; a future CgyyCommand variant must fail
            // closed instead of aborting the FFI process.
            _ => Err(AppError::changed()),
        };
        // Parse/readback errors after dispatch still preserve pending and invalidate.
        self.check_booking_owner(&owner)?;
        match result {
            Err(error) if self.booking_pending(&owner) => Ok(self.booking_failure(&owner, error)),
            result => result,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    #[test]
    fn ecb_matches_apple_vector() {
        // AES-128-ECB + PKCS7, independently generated with OpenSSL.
        assert_eq!(
            encrypt("{\"x\":100,\"y\":5}", "1234567890123456").expect("fixture"),
            "Q9KXFiX1zm8xCJfXAD2a+A=="
        );
    }
    #[test]
    fn missing_or_occupied_cells_never_become_choices() {
        let mut value = json!({"code":200,"data":{"spaceTimeInfo":[{"id":1,"beginTime":"08:00","endTime":"09:00"}],"reservationDateSpaceInfo":{"2026-10-20":[{"id":1,"spaceName":"合成空间","1":{"reservationStatus":1}}]}}});
        assert_eq!(choices(&value, "2026-10-20").expect("fixture").len(), 1);
        value["data"]["reservationDateSpaceInfo"]["2026-10-20"][0]["1"]["takeUp"] = json!(true);
        assert!(choices(&value, "2026-10-20").expect("fixture").is_empty());
        assert!(choices(&value, "2026-10-21").is_err());
    }
    fn context(week_start: &str) -> BookingContext {
        BookingContext {
            id: "fixture".into(),
            owner: BookingOwner {
                account: "synthetic".into(),
                generation: 1,
            },
            booking: BookingRequest {
                site_id: 1,
                date: "2026-10-25".into(),
                space_id: 1,
                time_ids: vec![1],
                phone: "13800000000".into(),
                theme: "合成活动".into(),
                purpose_type: 1,
                joiner_num: 2,
                activity_content: "合成测试".into(),
                joiners: "合成人员".into(),
                philosophy: false,
                off_school: false,
            },
            selections: "[{\"spaceId\":1,\"timeId\":1,\"venueSpaceGroupId\":null}]".into(),
            reservation_token: "A".into(),
            week_start: week_start.into(),
            trade_no: String::new(),
            captcha_token: String::new(),
            secret: String::new(),
            created: Instant::now(),
        }
    }
    #[test]
    fn draft_form_omits_a_missing_week_start_instead_of_guessing() {
        let present = base_form(&context("2026-10-19"));
        assert_eq!(
            present.get("weekStartDate").map(String::as_str),
            Some("2026-10-19")
        );
        // The requested date is not a substitute for the day-advertised anchor.
        let missing = base_form(&context(""));
        assert!(!missing.contains_key("weekStartDate"));
        assert_eq!(
            missing.get("reservationDate").map(String::as_str),
            Some("2026-10-25")
        );
        assert_eq!(missing.get("token").map(String::as_str), Some("A"));
    }
    #[test]
    fn captcha_coordinates_are_normalised_to_the_protocol_range() {
        // Official: x = 310 * offset / width, fractional results allowed.
        assert_eq!(protocol_point(165.0, Some(330.0)).expect("half"), "155");
        assert_eq!(protocol_point(100.0, Some(320.0)).expect("scaled"), "96.88");
        // Already normalised values pass through unchanged.
        assert_eq!(protocol_point(155.0, None).expect("protocol"), "155");
        // Out-of-range, zero and non-finite inputs never reach the wire.
        for (offset, width) in [
            (0.0, None),
            (-1.0, None),
            (1.0, Some(0.0)),
            (1.0, Some(-330.0)),
            (f64::NAN, None),
            (f64::INFINITY, None),
            (1000.0, Some(1.0)),
            (310.1, None),
        ] {
            assert!(protocol_point(offset, width).is_err(), "{offset}/{width:?}");
        }
    }
}
