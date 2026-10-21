use super::{cache::now_shanghai, session_service::SessionService};
use crate::{
    adapters::library_http,
    auth::CredentialVault,
    features::{library::LibrarySlot, library_mutation, mutation::MutationOutcome},
    foundation::http::HttpTransport,
};
use serde_json::json;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn reserve_library_seat(
        &self,
        area_id: &str,
        seat_id: &str,
        slot: LibrarySlot,
    ) -> MutationOutcome {
        if self.current_account().is_err() {
            return MutationOutcome::not_submitted("请先登录，未提交预约");
        }
        // Revalidate the selected slot and seat from upstream before the single write.
        let Ok(slots) = self.load_library_slots(area_id).await else {
            return MutationOutcome::not_submitted("无法核对时段，未提交预约");
        };
        if !slots.contains(&slot) {
            return MutationOutcome::not_submitted("预约时段已变化，请重新选择");
        }
        let Ok(seats) = self
            .load_library_seats(area_id, &slot.id, &slot.day, &slot.start, &slot.end)
            .await
        else {
            return MutationOutcome::not_submitted("无法核对座位，未提交预约");
        };
        if !seats.iter().any(|s| s.id == seat_id && s.available) {
            return MutationOutcome::not_submitted("该座位已不可用，请重新选择");
        }
        let Some(segment) = slot.id.rsplit('/').next().filter(|s| !s.is_empty()) else {
            return MutationOutcome::not_submitted("时段无效，未提交预约");
        };
        let plain = json!({"seat_id":seat_id,"segment":segment,"day":slot.day,"start_time":"","end_time":""});
        let Ok(encrypted) = library_mutation::encrypt(&plain, &slot.day) else {
            return MutationOutcome::not_submitted("无法准备预约，未提交");
        };
        let Ok(token) = self.library_token().await else {
            return MutationOutcome::not_submitted("图书馆登录失效，未提交预约");
        };
        let result = library_http::mutate(
            &self.session,
            &token,
            "space/confirm",
            &json!({"aesjson":encrypted}),
        )
        .await;
        self.invalidate_library_after_write();
        result
    }

    pub async fn perform_library_action(&self, booking_id: &str, action: &str) -> MutationOutcome {
        let snapshot = match self.load_library_bookings(true).await {
            Ok(snapshot) if snapshot.failure.is_none() => snapshot,
            _ => return MutationOutcome::not_submitted("无法核对当前预约，未提交操作"),
        };
        let Some(booking) = snapshot.bookings.iter().find(|b| b.id == booking_id) else {
            return MutationOutcome::not_submitted("当前预约已变化，未提交操作");
        };
        let Ok(now) = chrono::DateTime::parse_from_rfc3339(&now_shanghai()) else {
            return MutationOutcome::not_submitted("本机时间无效，未提交操作");
        };
        if !booking.allows(action, now.naive_local()) {
            return MutationOutcome::not_submitted("该预约当前不支持此操作，请刷新核对");
        }
        let (path, body) = if action == "cancel" {
            let path = match booking.booking_type {
                Some(2) => "seminar/cancel",
                Some(3 | 4) => "space/studyCancel",
                _ => "space/cancel",
            };
            (path, json!({"id":booking_id}))
        } else {
            let path = match action {
                "signin" => "space/signin",
                "leave" => "space/leave",
                "checkout" => "space/checkout",
                _ => return MutationOutcome::not_submitted("操作无效，未提交"),
            };
            let Ok(encrypted) = library_mutation::encrypt(
                &json!({"id":booking_id,"points":{}}),
                &now.format("%Y-%m-%d").to_string(),
            ) else {
                return MutationOutcome::not_submitted("无法准备操作，未提交");
            };
            (path, json!({"aesjson":encrypted}))
        };
        let Ok(token) = self.library_token().await else {
            return MutationOutcome::not_submitted("图书馆登录失效，未提交操作");
        };
        let result = library_http::mutate(&self.session, &token, path, &body).await;
        self.invalidate_library_after_write();
        result
    }
    fn invalidate_library_after_write(&self) {
        self.library_bookings.lock().clear();
        self.library_history.lock().clear();
        self.library_venues.lock().clear();
    }
}
