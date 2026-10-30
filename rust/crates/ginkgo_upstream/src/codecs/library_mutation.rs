//! LibraryClient.reserve/perform/cancel and LibraryCrypto, API.md §5.
use super::mutation::{MutationOutcome, MutationState};
use crate::AppError;
use aes::{
    cipher::{BlockEncrypt, KeyInit},
    Aes128,
};
use base64::{engine::general_purpose::STANDARD, Engine};
use serde_json::Value;

pub fn encrypt(value: &Value, day: &str) -> Result<String, AppError> {
    let parsed =
        chrono::NaiveDate::parse_from_str(day, "%Y-%m-%d").map_err(|_| AppError::invalid())?;
    if parsed.format("%Y-%m-%d").to_string() != day {
        return Err(AppError::invalid());
    }
    let digits = day.replace('-', "");
    let key = format!("{digits}{}", digits.chars().rev().collect::<String>());
    let cipher = Aes128::new_from_slice(key.as_bytes()).map_err(|_| AppError::invalid())?;
    let mut bytes = serde_json::to_vec(value).map_err(|_| AppError::invalid())?;
    let padding = 16 - bytes.len() % 16;
    bytes.resize(bytes.len() + padding, padding as u8);
    let mut previous = *b"ZZWBKJ_ZHIHUAWEI";
    for block in bytes.as_chunks_mut::<16>().0 {
        for (byte, iv) in block.iter_mut().zip(previous) {
            *byte ^= iv;
        }
        cipher.encrypt_block((&mut *block).into());
        previous.copy_from_slice(block);
    }
    Ok(STANDARD.encode(bytes))
}

/// The upstream does not document what its write `code` means (API.md §5.6
/// records "看 code/message"), so the result of a booking write is decided from
/// both the numeric code and the message text.
///
/// This policy is a client-side contract, not a school protocol fact: the
/// frozen Apple reference (`LibraryClient.validate`) applies the same code set
/// and the same keyword lists, so the two platforms must keep agreeing. Any
/// change here has to change there too, and the shared rule table
/// `fixtures/rules/library-mutation-v1.json` pins the expected outcome.
const SUCCESS_CODES: [i64; 2] = [0, 1];

/// A message that says the school session is gone. The write may or may not
/// have been recorded, so the result stays uncertain: claiming either outcome
/// would be a guess, and a guessed success hides a failed booking.
const SESSION_LOST_KEYWORDS: [&str; 3] = ["登录失效", "请重新登录", "未登录"];

/// A message that explains a refusal. Only meaningful together with a code:
/// a success code carrying one of these is a contradiction, and the two
/// platforms resolve a contradiction the same conservative way.
const REFUSAL_KEYWORDS: [&str; 14] = [
    "失败",
    "不可",
    "已被",
    "不能",
    "无法",
    "不足",
    "不符合",
    "已满",
    "超过",
    "限制",
    "无效",
    "未选择",
    "请选择",
    "请输入",
];

fn mentions(message: &str, keywords: &[&str]) -> bool {
    keywords.iter().any(|keyword| message.contains(keyword))
}

/// Classify one library write answer.
///
/// Accepted means the school took the request; rejected means it refused it;
/// uncertain means the answer does not say, and the caller must not replay the
/// write.
pub fn parse_result(value: &Value) -> MutationOutcome {
    let code = value["code"]
        .as_i64()
        .or_else(|| value["code"].as_str()?.trim().parse().ok());
    let message = value
        .get("message")
        .or_else(|| value.get("msg"))
        .and_then(Value::as_str)
        .unwrap_or_default();
    if mentions(message, &SESSION_LOST_KEYWORDS) {
        return MutationOutcome::uncertain();
    }
    let refused = mentions(message, &REFUSAL_KEYWORDS);
    match code {
        Some(code) if SUCCESS_CODES.contains(&code) && !refused => MutationOutcome::new(
            MutationState::Accepted,
            "学校已受理，请核对刷新后的预约记录",
        ),
        Some(_) if refused => MutationOutcome::new(
            MutationState::Rejected,
            "学校未接受本次操作，请核对可用时段与预约规则",
        ),
        _ => MutationOutcome::uncertain(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use aes::cipher::BlockDecrypt;
    #[test]
    fn library_encryption_roundtrip_and_result_confirmation() {
        let plain = serde_json::json!({"seat_id":"s1","segment":"t1","day":"2026-10-21","start_time":"","end_time":""});
        let encoded = encrypt(&plain, "2026-10-21").unwrap();
        let mut bytes = STANDARD.decode(encoded).unwrap();
        let cipher = Aes128::new(b"2026102112016202".into());
        let mut previous = *b"ZZWBKJ_ZHIHUAWEI";
        for block in bytes.as_chunks_mut::<16>().0 {
            let encrypted: [u8; 16] = *block;
            cipher.decrypt_block((&mut *block).into());
            for (byte, iv) in block.iter_mut().zip(previous) {
                *byte ^= iv;
            }
            previous = encrypted;
        }
        let padding = usize::from(*bytes.last().unwrap());
        bytes.truncate(bytes.len() - padding);
        assert_eq!(serde_json::from_slice::<Value>(&bytes).unwrap(), plain);
        assert!(encrypt(&plain, "2026-02-30").is_err());
        assert_eq!(
            parse_result(&serde_json::json!({"code":0,"msg":"已满"})).state,
            MutationState::Rejected
        );
        assert_eq!(
            parse_result(&serde_json::json!({"code":1})).state,
            MutationState::Accepted
        );
        assert_eq!(
            parse_result(&serde_json::json!({"code":500})).state,
            MutationState::Uncertain
        );
        assert_eq!(
            parse_result(&serde_json::json!({"code":1,"msg":"请重新登录"})).state,
            MutationState::Uncertain
        );
    }
}
