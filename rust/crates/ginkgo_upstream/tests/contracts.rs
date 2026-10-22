use ginkgo_upstream::services::execute_contract;
use serde::Deserialize;
use serde_json::{json, Value};
use std::{fs, path::Path};

#[derive(Deserialize)]
struct Fixture {
    contract: String,
    version: u32,
    source: String,
    input: Value,
    expected: Value,
}

fn visit(path: &Path, count: &mut usize) {
    for entry in fs::read_dir(path).expect("fixture directory must exist") {
        let path = entry.expect("read fixture entry").path();
        if path.is_dir() {
            visit(&path, count);
            continue;
        }
        if path.extension().is_none_or(|ext| ext != "json") {
            continue;
        }
        let fixture: Fixture =
            serde_json::from_str(&fs::read_to_string(&path).expect("read fixture"))
                .expect("valid fixture envelope");
        assert!(matches!(
            fixture.source.as_str(),
            "synthetic" | "redacted-upstream"
        ));
        let result = execute_contract(&fixture.contract, fixture.version, fixture.input);
        let actual = match result {
            Ok(value) => value,
            Err(error) => json!({"error": error.code}),
        };
        assert_eq!(actual, fixture.expected, "fixture {}", path.display());
        *count += 1;
    }
}

#[test]
fn shared_versioned_fixtures_match() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../../fixtures");
    let mut count = 0;
    visit(&root, &mut count);
    assert!(count >= 28, "all initial shared contracts must run");
}
