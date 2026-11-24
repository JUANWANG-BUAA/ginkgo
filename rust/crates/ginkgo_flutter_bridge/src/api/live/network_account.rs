//! Account-bound portal metrics & campus network traffic bridge.
use super::*;

pub(super) async fn load(expected_account: String) -> NetworkAccountResponse {
    let result = with_session_read(|| async {
        let s = service()?;
        if expected_account.is_empty()
            || !s
                .status()
                .account
                .as_deref()
                .is_some_and(|a| a.eq_ignore_ascii_case(expected_account.as_str()))
        {
            return Err(AppError::session_expired());
        }
        s.load_network_account().await
    })
    .await;
    network_account_response(result)
}

fn metric_dto(m: ginkgo_core::features::network_account::PortalMetricValue) -> PortalMetricDto {
    PortalMetricDto {
        value: m.value,
        unit: m.unit,
    }
}

fn network_account_response(
    result: Result<ginkgo_core::features::network_account::NetworkAccountReport, AppError>,
) -> NetworkAccountResponse {
    match result {
        Ok(report) => NetworkAccountResponse {
            data: Some(NetworkAccountDto {
                net_fee_minor: report.net_fee_minor,
                net_fee_failure: report.net_fee_failure.map(Into::into),
                unreturned_books: report.unreturned_books.map(metric_dto),
                unread_mail: report.unread_mail.map(metric_dto),
                cloud_drive_free: report.cloud_drive_free.map(metric_dto),
                portal_failure: report.portal_failure.map(Into::into),
                traffic_products: report
                    .traffic_products
                    .into_iter()
                    .map(|p| NetworkTrafficProductDto {
                        product_name: p.product_name,
                        used_text: p.used_text,
                        free_remaining_text: p.free_remaining_text,
                        paid_remaining_text: p.paid_remaining_text,
                        package_count: p.package_count,
                    })
                    .collect(),
                traffic_failure: report.traffic_failure.map(Into::into),
                fetched_at: report.fetched_at,
            }),
            failure: None,
        },
        Err(error) => NetworkAccountResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ginkgo_core::features::network_account::{NetworkAccountReport, NetworkTrafficProduct};

    #[test]
    fn network_account_response_preserves_partial_side_failures() {
        let partial = network_account_response(Ok(NetworkAccountReport {
            net_fee_minor: None,
            net_fee_failure: Some(ginkgo_core::ErrorCode::ModuleAuthRequired),
            unreturned_books: None,
            unread_mail: None,
            cloud_drive_free: None,
            portal_failure: Some(ginkgo_core::ErrorCode::ModuleAuthRequired),
            traffic_products: vec![NetworkTrafficProduct {
                product_name: Some("学生校园网".into()),
                used_text: "12G".into(),
                free_remaining_text: "18G".into(),
                paid_remaining_text: "0G".into(),
                package_count: 1,
            }],
            traffic_failure: None,
            fetched_at: "2026-11-23T12:00:00+08:00".into(),
        }));
        assert!(partial.failure.is_none());
        let dto = partial.data.expect("partial data");
        assert!(matches!(
            dto.portal_failure,
            Some(FailureCode::ModuleAuthRequired)
        ));
        assert_eq!(dto.traffic_products.len(), 1);
    }
}
