use ginkgo_core::{application::tasks_service::edit, features::tasks::Task, AppError};
use serde_json::{json, Value};
use sha1::{Digest, Sha1};
use std::{
    path::{Path, PathBuf},
    sync::{Arc, Barrier},
};

struct Store(PathBuf);
impl Store {
    fn new() -> Self {
        Self(std::env::temp_dir().join(format!("ginkgo-homework-{:x}", rand::random::<u128>())))
    }
    fn file(&self, account: &str) -> PathBuf {
        self.0
            .join(format!("tasks-{:x}.json", Sha1::digest(account.as_bytes())))
    }
    fn seed(&self, bytes: &[u8]) {
        std::fs::create_dir_all(&self.0).unwrap();
        std::fs::write(self.file("synthetic-a"), bytes).unwrap();
    }
}
impl Drop for Store {
    fn drop(&mut self) {
        if self.0.exists() {
            std::fs::remove_dir_all(&self.0).unwrap();
        }
    }
}
fn add(root: &Path, account: &str, id: &str, title: &str, due: &str) -> Vec<Task> {
    edit(
        root,
        account,
        "add_homework",
        Some(id),
        Some(title),
        Some(due),
        Some(true),
    )
    .unwrap()
}
fn value(task: &Task) -> Value {
    serde_json::to_value(task).unwrap()
}

#[test]
fn homework_add_deduplicates_without_overwriting_local_edits_or_completion() {
    let store = Store::new();
    let first = add(&store.0, "synthetic-a", "spoc:123", "  合成作业  ", "");
    let task = &first[0];
    assert_eq!(task.title, "合成作业");
    assert_eq!(task.due, "");
    assert!(!task.completed);
    assert_eq!(
        value(task)["source"],
        json!({"kind":"homework", "assignment_id":"spoc:123"})
    );
    edit(
        &store.0,
        "synthetic-a",
        "update",
        Some(&task.id),
        Some("自己修改"),
        Some("2026-10-22T18:30:00+08:00"),
        None,
    )
    .unwrap();
    let completed = edit(
        &store.0,
        "synthetic-a",
        "toggle",
        Some(&task.id),
        None,
        None,
        Some(true),
    )
    .unwrap();
    assert_eq!(value(&completed[0])["source"], value(task)["source"]);
    let bytes = std::fs::read(store.file("synthetic-a")).unwrap();
    let repeated = add(
        &store.0,
        "synthetic-a",
        "spoc:123",
        "上游刷新后的标题",
        "2026-11-01",
    );
    assert_eq!(repeated, completed);
    assert_eq!(std::fs::read(store.file("synthetic-a")).unwrap(), bytes);
    let other_source = add(&store.0, "synthetic-a", "other:123", "自己修改", "");
    assert_eq!(other_source.len(), 2);
    let other_account = add(&store.0, "synthetic-b", "spoc:123", "另一账号", "");
    assert_eq!(other_account.len(), 1);
    assert_ne!(other_account[0].id, task.id);
    assert_eq!(
        edit(&store.0, "synthetic-a", "load", None, None, None, None)
            .unwrap()
            .len(),
        2
    );
}

#[test]
fn concurrent_homework_add_is_atomic_per_account_and_source() {
    let store = Store::new();
    let barrier = Arc::new(Barrier::new(8));
    let threads: Vec<_> = (0..8)
        .map(|_| {
            let root = store.0.clone();
            let barrier = barrier.clone();
            std::thread::spawn(move || {
                barrier.wait();
                add(&root, "synthetic-a", "spoc:concurrent", "并发添加", "")[0]
                    .id
                    .clone()
            })
        })
        .collect();
    let ids: Vec<_> = threads
        .into_iter()
        .map(|thread| thread.join().unwrap())
        .collect();
    assert!(ids.iter().all(|id| id == &ids[0]));
    assert_eq!(
        edit(&store.0, "synthetic-a", "load", None, None, None, None)
            .unwrap()
            .len(),
        1
    );
}

#[test]
fn invalid_homework_input_is_rejected_without_changing_saved_tasks() {
    let store = Store::new();
    add(
        &store.0,
        "synthetic-a",
        "spoc:123",
        "有效作业",
        "2026-10-22",
    );
    let bytes = std::fs::read(store.file("synthetic-a")).unwrap();
    for id in [None, Some(""), Some(" 	")] {
        assert_eq!(
            edit(
                &store.0,
                "synthetic-a",
                "add_homework",
                id,
                Some("作业"),
                Some(""),
                None
            ),
            Err(AppError::invalid())
        );
    }
    for due in [
        "2026-02-30",
        "2026-2-03",
        "2026-10-22T25:00:00+08:00",
        "2026-10-22T12:00:00",
        "2026-10-22T12:00:00+25:00",
        "not-a-date",
        " ",
    ] {
        // Even an already linked source must not turn invalid input into success.
        assert_eq!(
            edit(
                &store.0,
                "synthetic-a",
                "add_homework",
                Some("spoc:123"),
                Some("作业"),
                Some(due),
                None
            ),
            Err(AppError::invalid()),
            "{due}"
        );
    }
    for title in [None, Some("  ")] {
        assert!(edit(
            &store.0,
            "synthetic-a",
            "add_homework",
            Some("spoc:new"),
            title,
            Some(""),
            None
        )
        .is_err());
    }
    assert!(edit(
        &store.0,
        "synthetic-a",
        "add_homework",
        Some("spoc:new"),
        Some("作业"),
        None,
        None
    )
    .is_err());
    assert_eq!(std::fs::read(store.file("synthetic-a")).unwrap(), bytes);
}

#[test]
fn due_order_uses_instants_with_school_dates_and_missing_deadlines_last() {
    let store = Store::new();
    for (id, due) in [
        ("no-deadline", ""),
        ("late-offset", "2026-10-22T01:00:00-05:00"),
        ("early-offset", "2026-10-22T12:00:00+08:00"),
        ("day-only", "2026-10-22"),
        ("previous-day", "2026-10-21"),
        ("fraction-later", "2026-10-22T04:00:00.500Z"),
    ] {
        add(&store.0, "synthetic-a", id, id, due);
    }
    let tasks = edit(&store.0, "synthetic-a", "load", None, None, None, None).unwrap();
    let titles: Vec<_> = tasks.iter().map(|task| task.title.as_str()).collect();
    assert_eq!(
        titles,
        [
            "previous-day",
            "early-offset",
            "fraction-later",
            "late-offset",
            "day-only",
            "no-deadline"
        ]
    );
    let completed = edit(
        &store.0,
        "synthetic-a",
        "toggle",
        Some(&tasks[0].id),
        None,
        None,
        Some(true),
    )
    .unwrap();
    assert_eq!(completed.last().unwrap().title, "previous-day");
    assert_eq!(
        tasks
            .iter()
            .find(|task| task.title == "day-only")
            .unwrap()
            .due,
        "2026-10-22"
    );
}

#[test]
fn v1_tasks_load_and_survive_writes_without_fabricating_source_or_deadline() {
    let store = Store::new();
    store.seed(br#"{"version":1,"tasks":[{"id":"legacy","title":"legacy title","due":"2026-10-21","completed":true}]}"#);
    let loaded = edit(&store.0, "synthetic-a", "load", None, None, None, None).unwrap();
    let legacy = loaded[0].clone();
    let original = std::fs::read(store.file("synthetic-a")).unwrap();
    assert_eq!(legacy.due, "2026-10-21");
    assert!(value(&legacy).get("source").is_none_or(Value::is_null));
    assert!(edit(
        &store.0,
        "synthetic-a",
        "update",
        Some("legacy"),
        Some(""),
        Some(""),
        None
    )
    .is_err());
    assert_eq!(std::fs::read(store.file("synthetic-a")).unwrap(), original);
    assert_eq!(
        serde_json::from_slice::<Value>(&original).unwrap()["version"],
        1
    );
    add(&store.0, "synthetic-a", "spoc:new", "新作业", "");
    let loaded = edit(&store.0, "synthetic-a", "load", None, None, None, None).unwrap();
    assert!(loaded.contains(&legacy));
    let migrated = std::fs::read(store.file("synthetic-a")).unwrap();
    assert_eq!(
        serde_json::from_slice::<Value>(&migrated).unwrap()["version"],
        2
    );
    assert!(loaded
        .iter()
        .any(|task| task.id == "legacy" && task.completed && task.due == "2026-10-21"));
    assert!(loaded.iter().any(|task| task.due.is_empty()));
}

#[test]
fn damaged_or_unknown_documents_are_never_overwritten() {
    let store = Store::new();
    for bytes in [
        br#"broken"#.as_slice(),
        br#"{"version":1,"tasks":[],"future":true}"#,
        br#"{"version":99,"tasks":[]}"#,
        br#"{"version":99,"version":1,"tasks":[]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"invalid","due":"2026-10-22","completed":false}]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"2026-10-22","completed":false},{"id":"x","title":"other","due":"2026-10-22","completed":false}]}"#,
        br#"{"version":2,"tasks":[{"id":"x","title":"x","due":"","completed":false,"source":{"kind":"homework","assignment_id":"spoc:1"}},{"id":"y","title":"y","due":"","completed":true,"source":{"kind":"homework","assignment_id":"spoc:1"}}]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"","completed":false,"future":true}]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"","completed":false,"source":{"kind":"homework","assignment_id":"spoc:1","future":true}}]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"","completed":false,"source":{"kind":"future","assignment_id":"spoc:1"}}]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"","completed":false,"source":{"kind":"homework","assignment_id":" "}}]}"#,
        br#"{"version":1,"tasks":[{"id":"x","title":"x","due":"2026-02-30","completed":false}]}"#,
    ] {
        // Apply the same corruption/unknown-field protection to v1 and v2.
        for bytes in [bytes.to_vec(), String::from_utf8_lossy(bytes).replace("\"version\":1", "\"version\":2").into_bytes()] {
            store.seed(&bytes);
            for action in ["load", "add_homework"] {
                assert_eq!(edit(&store.0, "synthetic-a", action, Some("spoc:new"), Some("不得覆盖"), Some(""), None), Err(AppError::changed()));
                assert_eq!(std::fs::read(store.file("synthetic-a")).unwrap(), bytes);
            }
        }
    }
}

#[test]
fn failed_atomic_replacement_keeps_the_previous_document() {
    for version in [1, 2] {
        let store = Store::new();
        store.seed(serde_json::to_string(&json!({
            "version": version,
            "tasks": [{"id":"legacy", "title":"original", "due":"2026-10-21", "completed":false}]
        })).unwrap().as_bytes());
        let bytes = std::fs::read(store.file("synthetic-a")).unwrap();
        std::fs::create_dir(store.file("synthetic-a").with_extension("tmp")).unwrap();
        assert_eq!(
            edit(
                &store.0,
                "synthetic-a",
                "add_homework",
                Some("spoc:456"),
                Some("新作业"),
                Some(""),
                None
            ),
            Err(AppError::unavailable())
        );
        // A failed migration must be just as non-destructive as a failed v2 save.
        assert_eq!(std::fs::read(store.file("synthetic-a")).unwrap(), bytes);
    }
}
