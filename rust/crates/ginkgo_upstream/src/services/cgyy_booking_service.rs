//! CGYY writes (API §6B; Swift CgyyClient / UBAA LocalCgyyApi).
//! All POSTs are single-attempt. Captcha is completed manually, not bypassed.
use super::SchoolClient;
use crate::{
    adapters::cgyy_http, auth::CredentialVault, foundation::http::HttpTransport, AppError,
    ErrorCode,
};
use ginkgo_domain::{features::cgyy_booking::*, ports::CgyyMutationSource};
use serde_json::{json, Value};
use std::{
    collections::BTreeMap,
    time::{Duration, Instant},
};

pub(crate) struct BookingContext {
    id: String,
    booking: BookingRequest,
    selections: String,
    reservation_token: String,
    captcha_token: String,
    secret: String,
    created: Instant,
}
fn number(v: &Value) -> Option<i64> {
    crate::features::cgyy::number(v)
}
fn text(v: &Value) -> Option<&str> {
    v.as_str().filter(|s| !s.is_empty())
}
fn data(value: &Value) -> Result<&Value, AppError> {
    crate::features::cgyy::envelope(value)
}

fn validate(booking: &BookingRequest) -> Result<(), AppError> {
    if booking.site_id <= 0
        || booking.space_id <= 0
        || booking.time_ids.is_empty()
        || booking.time_ids.len() > 12
        || booking.time_ids.iter().any(|id| *id <= 0)
        || booking
            .time_ids
            .iter()
            .collect::<std::collections::HashSet<_>>()
            .len()
            != booking.time_ids.len()
        || booking.phone.len() != 11
        || !booking.phone.bytes().all(|c| c.is_ascii_digit())
        || booking.joiner_num < 1
        || booking.joiner_num > 100
        || booking.purpose_type <= 0
        || [
            booking.theme.as_str(),
            &booking.activity_content,
            &booking.joiners,
        ]
        .iter()
        .any(|s| s.trim().is_empty() || s.len() > 8000)
        || chrono::NaiveDate::parse_from_str(&booking.date, "%Y-%m-%d").is_err()
    {
        return Err(AppError::invalid());
    }
    Ok(())
}
fn choices(value: &Value, date: &str) -> Result<Vec<BookingChoice>, AppError> {
    // Reuse strict read parser's availability semantics; never infer missing cells.
    let parsed = crate::features::cgyy::day(value, 1, date)?;
    let root = data(value)?;
    let rows = root["reservationDateSpaceInfo"][date]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let times = root["spaceTimeInfo"]
        .as_array()
        .ok_or_else(AppError::changed)?;
    let mut output = Vec::new();
    for (index, space) in parsed.spaces.iter().enumerate() {
        let id = number(&rows[index]["id"])
            .or_else(|| number(&rows[index]["spaceId"]))
            .filter(|id| *id > 0)
            .ok_or_else(AppError::changed)?;
        for (index, slot) in space.slots.iter().enumerate() {
            if slot.status == "空闲" {
                output.push(BookingChoice {
                    space_id: id,
                    space_name: space.name.clone(),
                    time_id: number(&times[index]["id"]).ok_or_else(AppError::changed)?,
                    time: slot.time.clone(),
                });
            }
        }
    }
    Ok(output)
}
fn selections(value: &Value, booking: &BookingRequest) -> Result<String, AppError> {
    let available = choices(value, &booking.date)?;
    if !booking.time_ids.iter().all(|id| {
        available
            .iter()
            .any(|c| c.space_id == booking.space_id && c.time_id == *id)
    }) {
        return Err(AppError::new(ErrorCode::BusinessRejected));
    }
    let root = data(value)?;
    let row = root["reservationDateSpaceInfo"][&booking.date]
        .as_array()
        .ok_or_else(AppError::changed)?
        .iter()
        .find(|r| number(&r["id"]).or_else(|| number(&r["spaceId"])) == Some(booking.space_id))
        .ok_or_else(AppError::changed)?;
    let group = number(&row["venueSpaceGroupId"]);
    let items: Vec<Value> = booking
        .time_ids
        .iter()
        .map(|id| json!({"spaceId": booking.space_id, "timeId": id, "venueSpaceGroupId": group}))
        .collect();
    serde_json::to_string(&items).map_err(|_| AppError::invalid())
}
fn purposes(value: &Value) -> Vec<Purpose> {
    fn visit(value: &Value, result: &mut BTreeMap<i64, String>) {
        match value {
            Value::Array(items) => {
                for item in items {
                    visit(item, result);
                }
            }
            Value::Object(items) => {
                if let Some(name) = text(&value["name"]).filter(|n| n.contains('类')) {
                    if let Some(id) = number(&value["key"])
                        .or_else(|| number(&value["value"]))
                        .or_else(|| number(&value["id"]))
                    {
                        result.entry(id).or_insert_with(|| name.into());
                    }
                }
                for item in items.values() {
                    visit(item, result);
                }
            }
            _ => {}
        }
    }
    let mut result = BTreeMap::new();
    visit(value, &mut result);
    result
        .into_iter()
        .map(|(id, name)| Purpose { id, name })
        .collect()
}
fn base_form(context: &BookingContext) -> BTreeMap<String, String> {
    BTreeMap::from([
        ("venueSiteId".into(), context.booking.site_id.to_string()),
        ("reservationDate".into(), context.booking.date.clone()),
        ("weekStartDate".into(), context.booking.date.clone()),
        ("reservationOrderJson".into(), context.selections.clone()),
        ("token".into(), context.reservation_token.clone()),
    ])
}
fn encrypt(text: &str, secret: &str) -> Result<String, AppError> {
    use aes::{Aes128, Aes192, Aes256};
    use base64::Engine;
    use cipher::{BlockEncrypt, KeyInit};
    let mut bytes = text.as_bytes().to_vec();
    let padding = 16 - bytes.len() % 16;
    bytes.resize(bytes.len() + padding, padding as u8);
    macro_rules! encrypt_blocks {
        ($cipher:ty) => {{
            let cipher =
                <$cipher>::new_from_slice(secret.as_bytes()).map_err(|_| AppError::changed())?;
            for chunk in bytes.chunks_exact_mut(16) {
                cipher.encrypt_block(cipher::generic_array::GenericArray::from_mut_slice(chunk));
            }
        }};
    }
    match secret.len() {
        16 => encrypt_blocks!(Aes128),
        24 => encrypt_blocks!(Aes192),
        32 => encrypt_blocks!(Aes256),
        _ => return Err(AppError::changed()),
    }
    Ok(base64::engine::general_purpose::STANDARD.encode(bytes))
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn booking_options(
        &self,
        site_id: i64,
        date: &str,
    ) -> Result<CgyyActionResult, AppError> {
        if site_id <= 0 || chrono::NaiveDate::parse_from_str(date, "%Y-%m-%d").is_err() {
            return Err(AppError::invalid());
        }
        let token = self.cgyy_token(false).await?;
        let day = cgyy_http::load(&self.session, "day", site_id, date, Some(&token)).await?;
        let codes =
            cgyy_http::business(&self.session, "/api/codes", BTreeMap::new(), &token).await?;
        let mut result = CgyyActionResult::message("options", "请填写用途并选择空闲时段");
        let purposes = purposes(data(&codes)?);
        if purposes.is_empty() {
            return Err(AppError::changed());
        }
        result.options = Some(BookingOptions {
            choices: choices(&day, date)?,
            purposes,
        });
        Ok(result)
    }
    async fn prepare_booking(&self, booking: BookingRequest) -> Result<CgyyActionResult, AppError> {
        validate(&booking)?;
        let token = self.cgyy_token(false).await?;
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
        let mut context = BookingContext {
            id: format!("{:032x}", rand::random::<u128>()),
            booking,
            selections: selected,
            reservation_token,
            captcha_token: String::new(),
            secret: String::new(),
            created: Instant::now(),
        };
        // Before the first POST, require review on interruption/unknown result.
        self.identity.lock().cgyy_review_required = true;
        let draft = cgyy_http::business(
            &self.session,
            "/api/reservation/order/info",
            base_form(&context),
            &token,
        )
        .await;
        if let Err(error) = draft {
            return Ok(self.booking_failure(error));
        }
        // Draft was acknowledged; a captcha failure is not a final order submission.
        self.identity.lock().cgyy_review_required = false;
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
        self.identity.lock().cgyy_booking = Some(context);
        let mut result = CgyyActionResult::message("challenge", "请手动拖动拼图完成学校验证");
        result.challenge = Some(challenge);
        Ok(result)
    }
    fn booking_failure(&self, error: AppError) -> CgyyActionResult {
        let mut identity = self.identity.lock();
        identity.cgyy_booking = None;
        if error.code == ErrorCode::BusinessRejected {
            identity.cgyy_review_required = false;
            CgyyActionResult::message(
                "rejected",
                "学校拒绝了本次操作，请检查条件后刷新；未自动重发",
            )
        } else {
            identity.cgyy_review_required = true;
            if error.code == ErrorCode::SessionExpired {
                identity.cgyy_token = None;
            }
            CgyyActionResult::message("uncertain", "结果待核实，请先到我的预约回查，勿重复提交")
        }
    }
    async fn submit_booking(&self, id: &str, x: i32) -> Result<CgyyActionResult, AppError> {
        // Consume before awaiting. Repeated callbacks cannot replay this challenge.
        let context = self
            .identity
            .lock()
            .cgyy_booking
            .take()
            .ok_or_else(AppError::invalid)?;
        if context.id != id
            || context.created.elapsed() > Duration::from_secs(120)
            || !(0..=310).contains(&x)
        {
            return Err(AppError::invalid());
        }
        let token = self.cgyy_token(false).await?;
        let point = format!("{{\"x\":{x},\"y\":5}}");
        let checked = cgyy_http::business(
            &self.session,
            "/api/captcha/check",
            BTreeMap::from([
                ("pointJson".into(), encrypt(&point, &context.secret)?),
                ("token".into(), context.captcha_token.clone()),
            ]),
            &token,
        )
        .await?;
        if data(&checked)?["success"] != true {
            return Ok(CgyyActionResult::message(
                "rejected",
                "拼图验证未通过，请返回后重新准备；未提交预约",
            ));
        }
        let latest = cgyy_http::load(
            &self.session,
            "day",
            context.booking.site_id,
            &context.booking.date,
            Some(&token),
        )
        .await?;
        if selections(&latest, &context.booking).ok().as_deref()
            != Some(context.selections.as_str())
        {
            return Ok(CgyyActionResult::message(
                "notSubmitted",
                "所选空档已变化，请重新选择；未提交预约",
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
        self.identity.lock().cgyy_review_required = true;
        let response =
            match cgyy_http::business(&self.session, "/api/reservation/order/submit", form, &token)
                .await
            {
                Ok(response) => response,
                Err(error) => return Ok(self.booking_failure(error)),
            };
        self.snapshots.cgyy.lock().clear();
        let order_id = number(&data(&response)?["orderInfo"]["id"]);
        let readback = cgyy_http::load(&self.session, "orders", 0, "", Some(&token)).await;
        if let (Some(id), Ok(readback)) = (order_id, readback) {
            if crate::features::cgyy::orders(&readback)?
                .iter()
                .any(|o| o.id == id)
            {
                self.identity.lock().cgyy_review_required = false;
                return Ok(CgyyActionResult::message(
                    "accepted",
                    "已查回预约记录，请在我的预约查看审批状态",
                ));
            }
        }
        Ok(CgyyActionResult::message(
            "uncertain",
            "学校已受理，请到我的预约核对，确认前暂停再次提交",
        ))
    }
    async fn cancel_booking(&self, order_id: i64) -> Result<CgyyActionResult, AppError> {
        if order_id <= 0 {
            return Err(AppError::invalid());
        }
        let token = self.cgyy_token(false).await?;
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
            || number(&row["checkStatus"]).is_some_and(|s| s < 0)
            || start.is_none_or(|start| now >= start - chrono::Duration::hours(4))
        {
            return Ok(CgyyActionResult::message(
                "notSubmitted",
                "当前订单不可取消或已进入开始前 4 小时，未发送请求",
            ));
        }
        self.identity.lock().cgyy_review_required = true;
        if let Err(error) = cgyy_http::business(
            &self.session,
            &format!("/api/orders/new/cancel/{order_id}"),
            BTreeMap::new(),
            &token,
        )
        .await
        {
            return Ok(self.booking_failure(error));
        }
        self.snapshots.cgyy.lock().clear();
        if let Ok(value) = cgyy_http::load(&self.session, "orders", 0, "", Some(&token)).await {
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
                self.identity.lock().cgyy_review_required = false;
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
        self.current_account()?;
        if matches!(command, CgyyCommand::Acknowledge) {
            // Explicit user acknowledgement after a successful readback only.
            let token = self.cgyy_token(false).await?;
            let value = cgyy_http::load(&self.session, "orders", 0, "", Some(&token)).await?;
            crate::features::cgyy::orders(&value)?;
            self.identity.lock().cgyy_review_required = false;
            return Ok(CgyyActionResult::message(
                "reviewed",
                "请确认没有重复预约后再操作",
            ));
        }
        if self.identity.lock().cgyy_review_required
            && !matches!(command, CgyyCommand::Options { .. })
        {
            return Ok(CgyyActionResult::message(
                "uncertain",
                "请先在我的预约核对上次结果，并手动确认已核对",
            ));
        }
        match command {
            CgyyCommand::Options { site_id, date } => self.booking_options(site_id, &date).await,
            CgyyCommand::Prepare { booking } => self.prepare_booking(booking).await,
            CgyyCommand::Submit { challenge_id, x } => self.submit_booking(&challenge_id, x).await,
            CgyyCommand::Cancel { order_id } => self.cancel_booking(order_id).await,
            CgyyCommand::Acknowledge => unreachable!(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
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
}
