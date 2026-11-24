//! These consumers compile without any school implementation, HTTP or vault.
use ginkgo_core::{
    application::{
        CheckInQrSource, LibraryMutationSource, NoticeSource, NoticesOutcome, RoutePreference,
        SessionOutcome, SessionSource, SessionStatus, Workspace,
    },
    features::{
        checkin::{encode_qr_matrix, CheckInQrTicket},
        library::LibrarySlot,
        mutation::{MutationOutcome, MutationState},
        notices::Notice,
    },
    session::UserProfile,
    AppError,
};
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    Arc, Mutex,
};

struct ReplacementNotices {
    calls: Arc<AtomicUsize>,
}
impl NoticeSource for ReplacementNotices {
    async fn load_notices(&self, force: bool) -> Result<NoticesOutcome, AppError> {
        self.calls.fetch_add(1, Ordering::SeqCst);
        Ok(NoticesOutcome {
            data: vec![Notice {
                title: "合成通知".into(),
                summary: String::new(),
                published_at: "2026-10-22".into(),
                url: "synthetic:notice".into(),
            }],
            fetched_at: "2026-10-28T00:00:00+08:00".into(),
            from_cache: false,
            stale: force,
            failure: force.then(AppError::unavailable),
        })
    }
}

#[tokio::test]
async fn a_single_replacement_capability_preserves_fallback_data_and_failure() {
    let calls = Arc::new(AtomicUsize::new(0));
    let app = Workspace::new(ReplacementNotices {
        calls: calls.clone(),
    });
    let result = app.load_notices(true).await.expect("old data is usable");
    assert_eq!(result.data[0].title, "合成通知");
    assert_eq!(result.failure, Some(AppError::unavailable()));
    assert_eq!(calls.load(Ordering::SeqCst), 1);
}

struct UncertainWrite {
    calls: Arc<AtomicUsize>,
}
impl LibraryMutationSource for UncertainWrite {
    async fn reserve_library_seat(&self, _: &str, _: &str, _: LibrarySlot) -> MutationOutcome {
        self.calls.fetch_add(1, Ordering::SeqCst);
        MutationOutcome::uncertain()
    }
    async fn perform_library_action(&self, _: &str, _: &str) -> MutationOutcome {
        self.calls.fetch_add(1, Ordering::SeqCst);
        MutationOutcome::uncertain()
    }
}

#[tokio::test]
async fn an_uncertain_write_is_returned_without_replaying_the_command() {
    let calls = Arc::new(AtomicUsize::new(0));
    // No read, HTTP, credential or login capability is required for this test.
    let app = Workspace::new(UncertainWrite {
        calls: calls.clone(),
    });
    let result = app
        .perform_library_action("synthetic-booking", "sign")
        .await;
    assert_eq!(result.state, MutationState::Uncertain);
    assert_eq!(calls.load(Ordering::SeqCst), 1);
}

struct SyntheticQrSource;
impl CheckInQrSource for SyntheticQrSource {
    async fn prepare_checkin_qr(
        &self,
        course_id: &str,
        revalidate_course: bool,
    ) -> Result<CheckInQrTicket, AppError> {
        let (matrix_size, modules) =
            encode_qr_matrix(&format!("synthetic:{course_id}:{revalidate_course}"))
                .map_err(|()| AppError::invalid())?;
        Ok(CheckInQrTicket {
            course_id: course_id.to_owned(),
            fetched_at: "2026-11-23T11:30:00+08:00".into(),
            refresh_seconds: 4,
            matrix_size,
            modules,
        })
    }
}

#[tokio::test]
async fn checkin_qr_port_returns_sanitized_matrix_ticket() {
    let app = Workspace::new(SyntheticQrSource);
    let ticket = app
        .prepare_checkin_qr("501", true)
        .await
        .expect("qr ticket");
    assert_eq!(ticket.course_id, "501");
    assert_eq!(
        ticket.modules.len(),
        usize::from(ticket.matrix_size) * usize::from(ticket.matrix_size)
    );
}

struct LocalIdentity {
    account: Arc<Mutex<Option<String>>>,
}
impl SessionSource for LocalIdentity {
    async fn purge_credentials(&self) {}
    fn account(&self) -> Result<String, AppError> {
        self.account
            .lock()
            .expect("identity")
            .clone()
            .ok_or_else(AppError::session_expired)
    }
    fn status(&self) -> SessionStatus {
        let account = self.account().ok();
        SessionStatus {
            profile: account.as_ref().map(|account| UserProfile {
                school_id: account.clone(),
                name: "synthetic".into(),
            }),
            account,
            route: RoutePreference::Automatic,
        }
    }
    fn set_route(&self, _: RoutePreference) {}
    async fn sign_in(
        &self,
        _: &str,
        _: &str,
        _: Option<&str>,
        _: bool,
    ) -> Result<SessionOutcome, AppError> {
        Err(AppError::unavailable())
    }
    async fn restore(&self) -> Result<SessionOutcome, AppError> {
        Ok(SessionOutcome::SignedOut)
    }
    async fn sign_out(&self) {
        *self.account.lock().expect("identity") = None;
    }
    fn clear_snapshots(&self) {}
}

#[tokio::test]
async fn local_tasks_follow_the_injected_identity_and_remain_account_isolated() {
    let root = std::env::temp_dir().join(format!("ginkgo-port-{:x}", rand::random::<u64>()));
    let account = Arc::new(Mutex::new(Some("sy2501001".into())));
    let app = Workspace::new(LocalIdentity {
        account: account.clone(),
    });
    app.edit_tasks(
        &root,
        "add",
        None,
        Some("合成待办"),
        Some("2026-10-22"),
        None,
    )
    .expect("add");
    *account.lock().expect("switch identity") = Some("sy2501002".into());
    assert!(app
        .edit_tasks(&root, "load", None, None, None, None)
        .expect("other account")
        .is_empty());
    *account.lock().expect("switch back") = Some("sy2501001".into());
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect("first account")[0]
            .title,
        "合成待办"
    );
    app.sign_out().await;
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect_err("signed out"),
        AppError::session_expired()
    );
    std::fs::remove_dir_all(root).expect("remove synthetic files");
}

/// Clearing query snapshots and signing out must never touch the task
/// document: these are the user's own records, not cached school data.
#[tokio::test]
async fn clearing_snapshots_and_signing_out_preserve_local_task_documents() {
    let root = std::env::temp_dir().join(format!("ginkgo-port-{:x}", rand::random::<u64>()));
    let account = Arc::new(Mutex::new(Some("sy2501001".into())));
    let app = Workspace::new(LocalIdentity {
        account: account.clone(),
    });
    app.edit_tasks(
        &root,
        "add",
        None,
        Some("退登后仍在的待办"),
        Some("2026-10-22"),
        None,
    )
    .expect("add");

    app.clear_snapshots();
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect("tasks survive clear_snapshots")[0]
            .title,
        "退登后仍在的待办"
    );

    app.sign_out().await;
    *account.lock().expect("sign back in") = Some("sy2501001".into());
    assert_eq!(
        app.edit_tasks(&root, "load", None, None, None, None)
            .expect("tasks survive sign_out")[0]
            .title,
        "退登后仍在的待办"
    );
    std::fs::remove_dir_all(root).expect("remove synthetic files");
}

#[tokio::test]
async fn isolated_finance_network_and_evaluation_ports_compile_and_execute_independently() {
    use ginkgo_core::{
        application::{
            FinanceIncomeSource, NetworkAccountSource, TeachingEvaluationOutcome,
            TeachingEvaluationSource,
        },
        features::{
            evaluation::{EvaluationCourseItem, EvaluationCourseStatus, TeachingEvaluationReport},
            finance::{FinanceIncomeEntry, FinanceIncomeReport},
            network_account::{NetworkAccountReport, NetworkTrafficProduct, PortalMetricValue},
        },
    };

    struct SyntheticFinance;
    impl FinanceIncomeSource for SyntheticFinance {
        async fn finance_incomes(&self) -> Result<FinanceIncomeReport, AppError> {
            Ok(FinanceIncomeReport {
                entries: vec![FinanceIncomeEntry {
                    id: "L1".into(),
                    project: Some("助研津贴".into()),
                    description: None,
                    gross_minor: Some(80_000),
                    tax_minor: Some(0),
                    net_minor: Some(80_000),
                    tax_rate: Some("0%".into()),
                    recorded_date: Some("2026-11-20".into()),
                    year: Some("2026".into()),
                    month: Some("11".into()),
                }],
                total: 1,
                fetched_at: "2026-11-23T12:00:00+08:00".into(),
            })
        }
    }

    struct SyntheticNetwork;
    impl NetworkAccountSource for SyntheticNetwork {
        async fn network_account(&self) -> Result<NetworkAccountReport, AppError> {
            Ok(NetworkAccountReport {
                net_fee_minor: Some(3000),
                net_fee_failure: None,
                unreturned_books: Some(PortalMetricValue {
                    value: "1".into(),
                    unit: None,
                }),
                unread_mail: None,
                cloud_drive_free: None,
                portal_failure: None,
                traffic_products: vec![NetworkTrafficProduct {
                    product_name: Some("学生网".into()),
                    used_text: "2G".into(),
                    free_remaining_text: "28G".into(),
                    paid_remaining_text: "0G".into(),
                    package_count: 0,
                }],
                traffic_failure: None,
                fetched_at: "2026-11-23T12:00:00+08:00".into(),
            })
        }
    }

    struct SyntheticEvaluation;
    impl TeachingEvaluationSource for SyntheticEvaluation {
        async fn load_teaching_evaluation(
            &self,
            force: bool,
        ) -> Result<TeachingEvaluationOutcome, AppError> {
            Ok(TeachingEvaluationOutcome {
                data: TeachingEvaluationReport {
                    task_id: Some("RW1".into()),
                    task_name: Some("合成评教".into()),
                    term: Some("2026-20271".into()),
                    courses: vec![EvaluationCourseItem {
                        id: "C1".into(),
                        course_name: "操作系统".into(),
                        teacher_name: Some("李文".into()),
                        questionnaire_name: Some("理论课".into()),
                        category: None,
                        status: EvaluationCourseStatus::Pending,
                    }],
                },
                fetched_at: "2026-11-23T12:00:00+08:00".into(),
                from_cache: !force,
                stale: false,
                failure: None,
            })
        }
    }

    assert_eq!(
        Workspace::new(SyntheticFinance)
            .load_finance_incomes()
            .await
            .expect("finance")
            .total,
        1
    );
    assert_eq!(
        Workspace::new(SyntheticNetwork)
            .load_network_account()
            .await
            .expect("network")
            .net_fee_minor,
        Some(3000)
    );
    assert_eq!(
        Workspace::new(SyntheticEvaluation)
            .load_teaching_evaluation(true)
            .await
            .expect("evaluation")
            .data
            .courses
            .len(),
        1
    );
}
