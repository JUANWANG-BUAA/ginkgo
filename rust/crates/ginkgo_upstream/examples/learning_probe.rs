//! Explicitly enabled bounded read-only production-port probe. Never logs identifiers/bodies.
use ginkgo_domain::ports::*;
use ginkgo_upstream::{
    adapters::reqwest_transport::ReqwestTransport,
    auth::{session::Session, vault::MemoryVault},
    services::session_service::SchoolClient,
};
use std::io::{self, IsTerminal, Read};
fn report<T>(kind: &str, result: &Result<DataOutcome<Vec<T>>, ginkgo_upstream::AppError>) {
    match result {
        Ok(v) => println!(
            "{kind} type=array count={} failure={:?}",
            v.data.len(),
            v.failure.as_ref().map(|e| &e.code)
        ),
        Err(e) => println!("{kind} failure={:?}", e.code),
    }
}
#[tokio::main(flavor = "current_thread")]
async fn main() {
    if std::env::var("GINKGO_MANUAL_LIVE_NETWORK").as_deref() != Ok("1") {
        println!("probe failure=LiveOptInRequired");
        return;
    }
    if io::stdin().is_terminal() {
        println!("probe failure=PipeInputRequired");
        return;
    }
    let mut input = String::new();
    if io::stdin().take(8193).read_to_string(&mut input).is_err() || input.len() > 8192 {
        println!("probe failure=InvalidInput");
        return;
    }
    let mut lines = input.lines();
    let account = lines.next().unwrap_or_default().to_owned();
    let password = lines.next().unwrap_or_default().to_owned();
    if account.is_empty() || password.is_empty() || lines.next().is_some() {
        println!("probe failure=InvalidInput");
        return;
    }
    drop(input);
    let transport = match ReqwestTransport::new() {
        Ok(v) => v,
        Err(_) => {
            println!("probe failure=TransportUnavailable");
            return;
        }
    };
    let service = SchoolClient::new(Session::new(transport), MemoryVault::default());
    if std::env::args().any(|a| a == "--webvpn") {
        service.set_route(RoutePreference::WebVpn);
    }
    let outcome = tokio::time::timeout(std::time::Duration::from_secs(180), async {
        match service.sign_in(&account, &password, None, false).await {
            Ok(SessionOutcome::SignedIn { .. }) => println!("login type=SignedIn"),
            Ok(_) => {
                println!("login failure=InteractionRequired");
                return;
            }
            Err(e) => {
                println!("login failure={:?}", e.code);
                return;
            }
        }
        if std::env::args().any(|a| a == "--extended-read-only") {
            match service.library_loans(1).await {
                Ok(page) => println!(
                    "loans type=page count={} has_more={}",
                    page.items.len(),
                    page.has_more
                ),
                Err(e) => {
                    println!("loans failure={:?}", e.code);
                    if let Some(detail) = e.detail.filter(|s| {
                        s.starts_with("loans_redirect_chain_")
                            && s.len() < 160
                            && s.bytes().all(|b| b.is_ascii_lowercase() || b == b'_')
                    }) {
                        println!("loans diagnostic={detail}");
                    }
                }
            }
            match service.load_graduate_execution(true).await {
                Ok(v) => println!("graduate type=report stale={}", v.failure.is_some()),
                Err(e) => println!("graduate failure={:?}", e.code),
            }
        }
        if std::env::args().any(|a| a == "--loans-only") {
            return;
        }
        let courses = service.learning_courses(true).await;
        report("courses", &courses);
        let Ok(courses) = courses else {
            return;
        };
        let mut download_pending = std::env::args().any(|a| a == "--download-first-resource");
        for course in courses.data.iter().take(1) {
            let notices = service.course_announcements(&course.id, true).await;
            report("announcements", &notices);
            if let Ok(notices) = notices {
                if let Some(first) = notices.data.first() {
                    match service
                        .course_announcement_detail(&course.id, &first.id)
                        .await
                    {
                        Ok(v) => println!(
                            "announcement_detail type=object attachments={}",
                            v.attachments.len()
                        ),
                        Err(e) => println!("announcement_detail failure={:?}", e.code),
                    }
                }
            }
            let assessments = service.course_assessments(&course.id, true).await;
            report("assessments", &assessments);
            match service.course_resources(&course.id, None, 1, true).await {
                Ok(v) => {
                    println!(
                        "resources type=page count={} failure={:?}",
                        v.data.items.len(),
                        v.failure.as_ref().map(|e| &e.code)
                    );
                    if download_pending {
                        if let Some(file) =
                            v.data.items.iter().find(|r| !r.folder && r.downloadable)
                        {
                            download_pending = false;
                            match service
                                .course_resource_download(&course.id, None, 1, &file.id)
                                .await
                            {
                                Ok(v) => println!("download type=bytes count={}", v.bytes.len()),
                                Err(e) => println!("download failure={:?}", e.code),
                            }
                        }
                    }
                    if let Some(folder) = v.data.items.iter().find(|r| r.folder) {
                        match service
                            .course_resources(&course.id, Some(&folder.id), 1, true)
                            .await
                        {
                            Ok(v) => println!(
                                "folder type=page count={} failure={:?}",
                                v.data.items.len(),
                                v.failure.as_ref().map(|e| &e.code)
                            ),
                            Err(e) => println!("folder failure={:?}", e.code),
                        }
                    }
                }
                Err(e) => println!("resources failure={:?}", e.code),
            }
        }
    })
    .await;
    if outcome.is_err() {
        println!("probe failure=Timeout");
    }
    // Drop the in-memory session: no logout, mark-read, exam entry, upload,
    // submission or other business write request. Optional single download
    // remains in memory and uses the production 20 MiB limit.
    if tokio::task::spawn_blocking(move || drop(service))
        .await
        .is_err()
    {
        println!("probe failure=CleanupUnavailable");
    }
}
