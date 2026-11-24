//! Account-bound student finance income bridge. No raw school payloads or tokens cross FFI.
use super::*;

pub(super) async fn load(expected_account: String) -> FinanceIncomeResponse {
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
        s.load_finance_incomes().await
    })
    .await;
    finance_response(result)
}

fn finance_response(
    result: Result<ginkgo_core::features::finance::FinanceIncomeReport, AppError>,
) -> FinanceIncomeResponse {
    match result {
        Ok(report) => FinanceIncomeResponse {
            data: Some(FinanceIncomeReportDto {
                total: report.total,
                fetched_at: report.fetched_at,
                entries: report
                    .entries
                    .into_iter()
                    .map(|e| FinanceIncomeEntryDto {
                        id: e.id,
                        project: e.project,
                        description: e.description,
                        gross_minor: e.gross_minor,
                        tax_minor: e.tax_minor,
                        net_minor: e.net_minor,
                        tax_rate: e.tax_rate,
                        recorded_date: e.recorded_date,
                        year: e.year,
                        month: e.month,
                    })
                    .collect(),
            }),
            failure: None,
        },
        Err(error) => FinanceIncomeResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ginkgo_core::features::finance::{FinanceIncomeEntry, FinanceIncomeReport};

    #[test]
    fn finance_response_maps_whitelisted_entries_and_typed_failures() {
        let ok = finance_response(Ok(FinanceIncomeReport {
            entries: vec![FinanceIncomeEntry {
                id: "LSH-1".into(),
                project: Some("助研津贴".into()),
                description: Some("合成摘要".into()),
                gross_minor: Some(100_000),
                tax_minor: Some(0),
                net_minor: Some(100_000),
                tax_rate: Some("0%".into()),
                recorded_date: Some("2026-11-20".into()),
                year: Some("2026".into()),
                month: Some("11".into()),
            }],
            total: 1,
            fetched_at: "2026-11-23T12:00:00+08:00".into(),
        }));
        assert!(ok.failure.is_none());
        assert_eq!(ok.data.expect("report").entries[0].net_minor, Some(100_000));

        let err = finance_response(Err(AppError::module_auth_required()));
        assert!(err.data.is_none());
        assert!(matches!(err.failure, Some(FailureCode::ModuleAuthRequired)));
    }
}
