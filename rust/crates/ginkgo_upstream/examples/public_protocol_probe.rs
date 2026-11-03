//! Explicit anonymous protocol smoke. No credentials, private data or school writes.
use ginkgo_upstream::{
    adapters::{
        campus_activities_http, career_http, library_books_http, library_stats_http, notices_http,
        reqwest_transport::ReqwestTransport, shuttle_http,
    },
    auth::session::{RouteMode, Session},
    AppError,
};
use serde_json::json;
fn report(module: &str, result: Result<usize, AppError>) {
    match result {
        Ok(count) => println!(
            "{}",
            json!({"module":module,"status":"parsed","count":count})
        ),
        Err(error) => println!(
            "{}",
            json!({"module":module,"status":"failed","code":format!("{:?}",error.code)})
        ),
    }
}
async fn catalog(session: &Session<ReqwestTransport>) {
    match library_books_http::search(
        session,
        RouteMode::Direct,
        "计算机",
        1,
        20,
        "relevance",
        true,
    )
    .await
    {
        Ok(page) => {
            report("library_books", Ok(page.items.len()));
            if let Some(first) = page.items.first() {
                report(
                    "library_holdings",
                    library_books_http::holdings(session, RouteMode::Direct, &first.bib_id)
                        .await
                        .map(|items| items.len()),
                );
            } else {
                println!(
                    "{}",
                    json!({"module":"library_holdings","status":"not_run_empty_search"})
                );
            }
        }
        Err(error) => report("library_books", Err(error)),
    }
}

fn main() {
    if std::env::var("GINKGO_MANUAL_LIVE_NETWORK").as_deref() != Ok("1") {
        println!("{}", json!({"status":"live_opt_in_required"}));
        return;
    }
    let transport = match ReqwestTransport::new() {
        Ok(value) => value,
        Err(_) => {
            println!("{}", json!({"status":"transport_unavailable"}));
            return;
        }
    };
    let session = Session::new(transport);
    session.set_route(RouteMode::Direct);
    let seconds = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs() as i64;
    let month = chrono::DateTime::from_timestamp(seconds, 0)
        .expect("current time")
        .with_timezone(&chrono_tz::Asia::Shanghai)
        .format("%Y-%m")
        .to_string();
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("probe runtime");
    let result = runtime.block_on(async {
        tokio::time::timeout(std::time::Duration::from_secs(120), async {
            if std::env::args().any(|arg| arg == "--catalog-only") {
                catalog(&session).await;
                return;
            }
            tokio::join!(
                async {
                    report(
                        "library_stats",
                        library_stats_http::load(&session, RouteMode::Direct)
                            .await
                            .map(|value| value.len()),
                    );
                },
                async {
                    catalog(&session).await;
                },
                async {
                    report(
                        "notices",
                        notices_http::load(&session).await.map(|value| value.len()),
                    );
                },
                async {
                    report(
                        "shuttle",
                        shuttle_http::load(&session, RouteMode::Direct)
                            .await
                            .map(|value| value.tables.len()),
                    );
                },
                async {
                    report(
                        "career",
                        career_http::load(&session, &month)
                            .await
                            .map(|value| value.events.len()),
                    );
                },
                async {
                    report(
                        "campus_activities",
                        campus_activities_http::load(&session, 1)
                            .await
                            .map(|value| value.activities.len()),
                    );
                }
            );
        })
        .await
    });
    if result.is_err() {
        println!("{}", json!({"status":"timeout"}));
    }
    assert!(
        !session.direct_cookie_present() && !session.webvpn_cookie_present(),
        "anonymous probe must not import cookies"
    );
    println!("{}", json!({"cleanup":"no_authenticated_cookies"}));
}
