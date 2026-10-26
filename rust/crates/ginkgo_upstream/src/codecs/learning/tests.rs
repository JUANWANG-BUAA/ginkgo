use super::*;
use serde_json::json;

#[test]
fn learning_empty_is_success_but_missing_or_drifted_collections_fail() {
    assert!(courses(&json!({"list":[]})).unwrap().is_empty());
    assert!(announcements::list(&json!([])).unwrap().is_empty());
    assert!(assessments::list(&json!({"list":[]}), "c")
        .unwrap()
        .is_empty());
    assert!(
        resources::page(&json!({"list":[],"pageNum":1,"hasNextPage":false}), 1)
            .unwrap()
            .items
            .is_empty()
    );
    for bad in [
        json!(null),
        json!({}),
        json!({"list":{}}),
        json!({"list":[{"kcid":true,"kcmc":"course"}]}),
    ] {
        assert!(courses(&bad).is_err());
    }
    assert!(announcements::list(&json!({})).is_err());
    assert!(announcements::list(&json!([{"id":"n","bt":[]}])).is_err());
    assert!(assessments::list(&json!({"list":[{"id":"a","csmc":"test","kssj":{}}]}), "c").is_err());
    for bad in [
        json!({"list":[],"pageNum":2,"hasNextPage":false}),
        json!({"list":[],"pageNum":1,"hasNextPage":"false"}),
        json!({"list":[{"id":"r","wjmc":"file","sfwjj":"2"}],"pageNum":1,"hasNextPage":false}),
    ] {
        assert!(resources::page(&bad, 1).is_err());
    }
}

#[test]
fn learning_verified_fields_preserve_unknowns_and_attachment_identity() {
    let course = courses(&json!({"list":[{"kcid":7,"kcmc":"course","jsmc":"unverified"}]}))
        .unwrap()
        .remove(0);
    assert_eq!(course.id, "7");
    assert!(course.teacher.is_none());
    let assessment = assessments::list(
        &json!({"list":[{"id":"a","csmc":"test","mf":100,"fs":90}]}),
        "c",
    )
    .unwrap()
    .remove(0);
    assert!(assessment.score.is_none());
    let notices=announcements::list(&json!([{"id":"n","bt":"notice","fbzt":"1","zhxgsj":"published","fssj":"unverified"},{"id":"draft","bt":"draft","cjsj":"created"}])).unwrap();
    assert_eq!(notices[0].published_at.as_deref(), Some("published"));
    assert!(notices[1].published_at.is_none());
    let detail=announcements::detail(&json!({"id":"n","bt":"notice","nr":"<p>synthetic</p>","fjlist":[{"wjid":"f","wjmc":"file"}]}),"n").unwrap();
    assert_eq!(detail.attachments[0].id, "f");
    assert_eq!(detail.content.as_deref(), Some("synthetic"));
    assert!(announcements::detail(&json!({"id":"other","bt":"notice"}), "n").is_err());
    assert!(announcements::detail(&json!({"bt":"notice","fjlist":{}}), "n").is_err());
}

#[test]
fn learning_column_requires_exact_unique_bounded_tree_context() {
    let tree = json!([{"lmlxdm":"0","children":[{"lmlxdm":"01","id":"notice"}]},{"lmlxdm":"3","children":[{"lmlxdm":"31","id":"homework"},{"lmlxdm":"32","id":"assessment"}]}]);
    assert_eq!(column(&tree, "0", "01").unwrap(), "notice");
    assert_eq!(column(&tree, "3", "32").unwrap(), "assessment");
    for bad in [
        json!([]),
        json!({}),
        json!([{"lmlxdm":"3","children":[{"lmlxdm":"32","id":"a"},{"lmlxdm":"32","id":"b"}]}]),
        json!([{"lmlxdm":"0","children":{}}]),
        json!([{"lmlxdm":"0","children":[{"lmlxdm":"32","id":"wrong-parent"}]}]),
    ] {
        assert!(column(&bad, "3", "32").is_err());
    }
}

#[test]
fn learning_columns_enumerate_business_context_without_guessing_duplicate_ids() {
    let tree = serde_json::json!([{"lmlxdm":"0","children":[{"id":"a","lmlxdm":"01","lmmc2":"公告甲"},{"id":"b","lmlxdm":"01"}]},{"lmlxdm":"3","children":[{"id":"q","lmlxdm":"32"}]}]);
    let result = super::columns(&tree).unwrap();
    assert_eq!(result.len(), 3);
    assert_eq!(result[0].name, "公告甲");
    assert_eq!(
        result[1].kind,
        ginkgo_domain::ports::LearningColumnKind::Announcement
    );
    assert!(super::column(&tree, "0", "01").is_err());
    assert_eq!(super::column(&tree, "3", "32").unwrap(), "q");
    assert!(super::columns(&serde_json::json!([{"lmlxdm":"0","children":[{"id":"a","lmlxdm":"01"},{"id":"a","lmlxdm":"01"}]}])).is_err());
}
