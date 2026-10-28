use super::*;

fn activities_body() -> &'static str {
    r#"<ul>
      <li id="line_u14_0">
        <a href="../info/1076/8603.htm">
          <div><h4>讲座</h4><h3>合成学术活动</h3>
            <p class="sj"><span style="display:none;">2026年10月23日</span> 10月28日</p>
            <p class="dz">沙河校区合成报告厅</p>
          </div>
        </a>
      </li>
    </ul>"#
}

fn activities_response(status: u16, body: &str) -> HttpResponse {
    HttpResponse::new(status, "https://www.buaa.edu.cn/index/xswh1.htm", body)
}

#[tokio::test]
async fn campus_activities_cache_and_failure_preserves_old_snapshot() {
    let (service, transport) = build_service(
        vec![
            activities_response(200, activities_body()),
            activities_response(503, "unavailable"),
            activities_response(200, activities_body()),
        ],
        MemoryVault::default(),
    );
    let first = service
        .load_campus_activities(1, false)
        .await
        .expect("activities");
    assert!(first.failure.is_none());
    assert_eq!(first.data.activities.len(), 1);
    let activity = &first.data.activities[0];
    assert_eq!(activity.id, "xswh:0");
    assert_eq!(activity.category, "讲座");
    assert_eq!(activity.title, "合成学术活动");
    assert_eq!(activity.published_at, "2026年10月23日");
    assert_eq!(activity.activity_time, "10月28日");
    assert_eq!(activity.place, "沙河校区合成报告厅");
    assert_eq!(activity.url, "https://www.buaa.edu.cn/info/1076/8603.htm");

    let count = transport.request_count();
    let cached = service
        .load_campus_activities(1, false)
        .await
        .expect("cache");
    assert_eq!(transport.request_count(), count);
    assert_eq!(cached.data, first.data);

    let stale = service
        .load_campus_activities(1, true)
        .await
        .expect("stale");
    assert!(stale.failure.is_some());
    assert_eq!(stale.data, first.data);

    let fresh = service
        .load_campus_activities(1, true)
        .await
        .expect("refresh");
    assert!(fresh.failure.is_none());
}

#[tokio::test]
async fn campus_activities_do_not_send_parent_domain_login_cookies() {
    let (service, transport) = build_service(
        vec![
            HttpResponse::new(200, "https://sso.buaa.edu.cn/session", "seed")
                .with_set_cookie("CASTGC=synthetic-account; Domain=buaa.edu.cn; Path=/; Secure"),
            activities_response(200, activities_body())
                .with_set_cookie("public-session=synthetic; Domain=buaa.edu.cn; Path=/; Secure"),
        ],
        MemoryVault::default(),
    );
    service
        .session
        .send_direct(HttpRequest::get("https://sso.buaa.edu.cn/session"))
        .await
        .expect("seed parent-domain login cookie");

    service
        .load_campus_activities(1, false)
        .await
        .expect("public activities");

    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(requests[1].header_value("cookie"), None);
}

#[tokio::test]
async fn campus_activities_changed_markup_is_not_an_empty_result() {
    let (service, _) = build_service(
        vec![
            activities_response(200, activities_body()),
            activities_response(200, "<html>changed</html>"),
        ],
        MemoryVault::default(),
    );
    let first = service
        .load_campus_activities(1, false)
        .await
        .expect("activities");
    let changed = service
        .load_campus_activities(1, true)
        .await
        .expect("old snapshot");
    assert_eq!(
        changed.failure.map(|error| error.code),
        Some(ErrorCode::ChangedResponse)
    );
    assert_eq!(changed.data, first.data);
}

#[tokio::test]
async fn campus_activities_uses_the_current_total_for_reverse_pagination() {
    let index = format!("{}<span>/64页</span>", activities_body());
    let second = HttpResponse::new(
        200,
        "https://www.buaa.edu.cn/index/xswh1/63.htm",
        activities_body(),
    );
    let (service, transport) = build_service(
        vec![activities_response(200, &index), second],
        MemoryVault::default(),
    );

    let result = service
        .load_campus_activities(2, false)
        .await
        .expect("second page");

    assert_eq!(result.data.page, 2);
    let requests = transport.requests();
    assert_eq!(requests.len(), 2);
    assert_eq!(
        requests[1].url,
        "https://www.buaa.edu.cn/index/xswh1/63.htm"
    );
}
